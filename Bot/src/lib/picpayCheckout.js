const PICPAY_MODE = String(process.env.PICPAY_API_MODE || "payment-link")
  .trim()
  .toLowerCase();
const DEFAULT_BASE =
  PICPAY_MODE === "checkout"
    ? "https://checkout-api.picpay.com"
    : "https://api.picpay.com";
const PICPAY_API_BASE = (process.env.PICPAY_API_BASE || DEFAULT_BASE).replace(/\/$/, "");
const PICPAY_SANDBOX = /^(1|true|yes)$/i.test(String(process.env.PICPAY_SANDBOX || "").trim());

let cachedToken = null;
let tokenExpiresAt = 0;

function apiPath(path) {
  if (PICPAY_MODE !== "payment-link") return path;
  if (PICPAY_SANDBOX) return `/sandbox/v1${path}`;
  // Produção: rotas em /v1/... (sem /v1 → 404 "no Route matched")
  return `/v1${path}`;
}

function formatApiError(prefix, r, data) {
  let detail =
    data.message ||
    data.error ||
    (Array.isArray(data.errors) ? data.errors.map((e) => e.message || e).join("; ") : null);
  if (!detail && data.errors && typeof data.errors === "object") {
    detail = JSON.stringify(data.errors);
  }
  if (!detail) detail = JSON.stringify(data).slice(0, 400);
  return new Error(`${prefix} ${r.status}: ${detail}`);
}

function paymentLinkIdFromUrl(link) {
  if (!link || typeof link !== "string") return "";
  try {
    const parts = new URL(link).pathname.split("/").filter(Boolean);
    return parts[parts.length - 1] || "";
  } catch {
    return "";
  }
}

/** PicPay exige YYYY-MM-DD estritamente depois de hoje. */
function picpayExpiredAtDate(expSec) {
  const target = new Date(Date.now() + (expSec || 1800) * 1000);
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);
  const use = target > tomorrow ? target : tomorrow;
  const y = use.getFullYear();
  const m = String(use.getMonth() + 1).padStart(2, "0");
  const d = String(use.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * @returns {Promise<string>}
 */
async function getAccessToken() {
  const clientId = (process.env.PICPAY_CLIENT_ID || "").trim();
  const clientSecret = (process.env.PICPAY_CLIENT_SECRET || "").trim();
  if (!clientId || !clientSecret) {
    throw new Error("PICPAY_CLIENT_ID ou PICPAY_CLIENT_SECRET não configurados no .env");
  }
  if (cachedToken && Date.now() < tokenExpiresAt - 15_000) {
    return cachedToken;
  }
  const r = await fetch(`${PICPAY_API_BASE}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify({
      grant_type: "client_credentials",
      client_id: clientId,
      client_secret: clientSecret,
    }),
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) {
    throw formatApiError("PicPay OAuth", r, data);
  }
  const token = data.access_token || data.accessToken;
  if (!token) throw new Error("PicPay OAuth: resposta sem access_token");
  const expiresIn = parseInt(data.expires_in || data.expiresIn || "300", 10);
  cachedToken = token;
  tokenExpiresAt = Date.now() + Math.max(60, expiresIn) * 1000;
  return token;
}

async function apiRequest(method, path, body, extraHeaders) {
  const token = await getAccessToken();
  const headers = {
    Accept: "application/json",
    Authorization: `Bearer ${token}`,
    ...extraHeaders,
  };
  const init = { method, headers };
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    init.body = JSON.stringify(body);
  }
  const r = await fetch(`${PICPAY_API_BASE}${apiPath(path)}`, init);
  const data = await r.json().catch(() => ({}));
  return { r, data };
}

/**
 * @param {object} params
 * @param {string} params.merchantChargeId
 * @param {number} params.amountCents
 * @param {object} params.customer
 * @param {string} [params.clientIp]
 * @param {number} [params.pixExpirationSeconds]
 * @param {string} [params.description]
 */
async function createCheckoutPixCharge(params) {
  const callerOrigin = (process.env.PICPAY_CALLER_ORIGIN || process.env.SITE_BASE_URL || "").trim();
  const headers = {};
  if (callerOrigin) headers["caller-origin"] = callerOrigin;

  const { r, data } = await apiRequest(
    "POST",
    "/charge/pix",
    {
      paymentSource: "GATEWAY",
      merchantChargeId: params.merchantChargeId,
      customer: params.customer,
      deviceInformation: {
        ip: params.clientIp || "127.0.0.1",
      },
      transactions: [
        {
          amount: params.amountCents,
          pix: {
            expiration: params.pixExpirationSeconds || 1800,
          },
        },
      ],
    },
    headers
  );
  if (!r.ok) throw formatApiError("PicPay charge/pix", r, data);
  return data;
}

/**
 * Link de Pagamento — credenciais do painel "Link de Pagamento - API".
 * @param {object} params
 */
async function createPaymentLinkPixCharge(params) {
  const desc = String(params.description || "Compra Gear UP").slice(0, 255);
  const orderNumber = String(params.merchantChargeId || "")
    .replace(/^gear-/, "")
    .slice(0, 15);
  const siteBase = (process.env.PICPAY_CALLER_ORIGIN || process.env.SITE_BASE_URL || "").trim();
  const expSec = params.pixExpirationSeconds || 1800;
  const expiredAt = picpayExpiredAtDate(expSec);

  const body = {
    charge: {
      name: desc.slice(0, 80),
      description: desc,
      order_number: orderNumber,
      ...(siteBase ? { redirect_url: `${siteBase.replace(/\/$/, "")}/pagamento-ok.html` } : {}),
      payment: {
        methods: ["BRCODE"],
        brcode_arrangements: ["PIX"],
      },
      amounts: {
        product: params.amountCents,
        delivery: 0,
      },
    },
    options: {
      allow_create_pix_key: true,
      expired_at: expiredAt,
    },
  };

  const { r, data } = await apiRequest("POST", "/paymentlink/create", body);
  if (!r.ok) throw formatApiError("PicPay paymentlink/create", r, data);
  return normalizePaymentLinkCharge(data, params.amountCents);
}

/**
 * @param {object} raw
 * @param {number} [fallbackAmount]
 */
function normalizePaymentLinkCharge(raw, fallbackAmount) {
  if (!raw || typeof raw !== "object") {
    return { apiMode: "payment-link", chargeStatus: "PENDING", amount: fallbackAmount };
  }

  if (raw.brcode || raw.link) {
    const checkoutLink = raw.link || raw.deeplink || "";
    return {
      apiMode: "payment-link",
      paymentLinkId: raw.paymentLinkId || paymentLinkIdFromUrl(checkoutLink),
      chargeStatus: String(raw.status || "active").toUpperCase(),
      amount: raw.amount ?? fallbackAmount,
      qrCode: raw.brcode || "",
      qrCodeBase64: "",
      checkoutLink,
      transactions: [],
      totalSales: 0,
    };
  }

  if (raw.paymentLinkId || raw.details) {
    const d = raw.details || {};
    const ch = d.charge || {};
    const links = ch.links || {};
    const checkoutLink = links.checkout || links.share || "";
    return {
      apiMode: "payment-link",
      paymentLinkId: String(raw.paymentLinkId || ""),
      chargeStatus: String(ch.status || "PENDING").toUpperCase(),
      amount: ch.amount ?? ch.productAmount ?? fallbackAmount,
      qrCode: ch.qrcode || ch.qrCode || "",
      qrCodeBase64: "",
      checkoutLink,
      transactions: raw.transactions || [],
      totalSales: Number(ch.totalSales || 0),
    };
  }

  const charge = raw.charge || raw.data?.charge || raw.data || raw;
  const paymentLinkId =
    charge.paymentLinkId || charge.payment_link_id || charge.id || raw.paymentLinkId || "";
  return {
    apiMode: "payment-link",
    paymentLinkId: String(paymentLinkId),
    chargeStatus: String(charge.status || raw.status || "PENDING").toUpperCase(),
    amount: charge.amount ?? raw.amount ?? fallbackAmount,
    qrCode: charge.qrCode || charge.qr_code || charge.qrcode || "",
    qrCodeBase64: charge.qrCodeBase64 || charge.qr_code_base64 || "",
    checkoutLink: charge.checkoutLink || charge.checkout_link || "",
    transactions: charge.transactions || raw.transactions || [],
    totalSales: Number(charge.totalSales || 0),
  };
}

/**
 * @param {object} params
 */
async function createPixCharge(params) {
  if (PICPAY_MODE === "checkout") {
    return createCheckoutPixCharge(params);
  }
  return createPaymentLinkPixCharge(params);
}

/**
 * @param {string} merchantChargeId
 * @param {string} [paymentLinkId]
 */
async function getCharge(merchantChargeId, paymentLinkId) {
  if (PICPAY_MODE === "checkout") {
    const { r, data } = await apiRequest(
      "GET",
      `/charge/${encodeURIComponent(merchantChargeId)}`
    );
    if (!r.ok) throw formatApiError("PicPay GET charge", r, data);
    return data;
  }

  const id = paymentLinkId || merchantChargeId;
  const { r, data } = await apiRequest("GET", `/paymentlink/${encodeURIComponent(id)}`);
  if (!r.ok) throw formatApiError("PicPay GET paymentlink", r, data);

  let normalized = normalizePaymentLinkCharge(data);
  const paid = isChargePaid(normalized);
  if (!paid && normalized.paymentLinkId) {
    try {
      const tx = await apiRequest(
        "GET",
        `/paymentlink/${encodeURIComponent(normalized.paymentLinkId)}/transactions`
      );
      if (tx.r.ok) {
        const txs =
          tx.data.transactions ||
          tx.data.data?.transactions ||
          (Array.isArray(tx.data) ? tx.data : []);
        normalized = { ...normalized, transactions: txs };
        if (isChargePaid({ ...normalized, transactions: txs })) {
          normalized.chargeStatus = "PAYED";
        }
      }
    } catch (_) {
      /* consulta de transações opcional */
    }
  }
  return normalized;
}

/**
 * @param {object} charge
 */
function isChargePaid(charge) {
  if (Number(charge.totalSales) > 0) return true;
  const status = String(charge.chargeStatus || charge.status || "").toUpperCase();
  if (status === "PAID" || status === "PAYED" || status === "AUTHORIZED") return true;
  const txs = charge.transactions;
  if (!Array.isArray(txs)) return false;
  return txs.some((t) => {
    const st = String(t.transactionStatus || t.status || "").toUpperCase();
    return st === "PAID" || st === "PAYED" || st === "CAPTURED" || st === "AUTHORIZED";
  });
}

/**
 * Extrai QR Pix da resposta de criação/consulta.
 * @param {object} charge
 */
function extractPixFromCharge(charge) {
  if (!charge) return null;
  if (charge.qrCode || charge.qrCodeBase64) {
    return {
      qrCode: charge.qrCode || "",
      qrCodeBase64: charge.qrCodeBase64 || "",
      checkoutLink: charge.checkoutLink || "",
      transactionStatus: charge.chargeStatus || "",
    };
  }
  const txs = charge.transactions;
  if (!Array.isArray(txs)) return null;
  for (const tx of txs) {
    const pix = tx && (tx.pix || (tx.paymentType === "PIX" ? tx : null));
    if (pix && (pix.qrCode || pix.qrCodeBase64)) {
      return {
        qrCode: pix.qrCode || "",
        qrCodeBase64: pix.qrCodeBase64 || "",
        checkoutLink: charge.checkoutLink || "",
        transactionStatus: tx.transactionStatus || tx.status || "",
      };
    }
  }
  return null;
}

function isConfigured() {
  return Boolean((process.env.PICPAY_CLIENT_ID || "").trim() && (process.env.PICPAY_CLIENT_SECRET || "").trim());
}

function getApiMode() {
  return PICPAY_MODE;
}

module.exports = {
  createPixCharge,
  getCharge,
  extractPixFromCharge,
  isChargePaid,
  isConfigured,
  getApiMode,
};
