const PICPAY_API_BASE = (process.env.PICPAY_API_BASE || "https://checkout-api.picpay.com").replace(/\/$/, "");

let cachedToken = null;
let tokenExpiresAt = 0;

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
    throw new Error(data.message || data.error || `PicPay OAuth ${r.status}`);
  }
  const token = data.access_token || data.accessToken;
  if (!token) throw new Error("PicPay OAuth: resposta sem access_token");
  const expiresIn = parseInt(data.expires_in || data.expiresIn || "300", 10);
  cachedToken = token;
  tokenExpiresAt = Date.now() + Math.max(60, expiresIn) * 1000;
  return token;
}

/**
 * @param {object} params
 * @param {string} params.merchantChargeId
 * @param {number} params.amountCents
 * @param {object} params.customer
 * @param {string} [params.clientIp]
 * @param {number} [params.pixExpirationSeconds]
 */
async function createPixCharge(params) {
  const token = await getAccessToken();
  const callerOrigin = (process.env.PICPAY_CALLER_ORIGIN || process.env.SITE_BASE_URL || "").trim();
  const headers = {
    "Content-Type": "application/json",
    Accept: "application/json",
    Authorization: `Bearer ${token}`,
  };
  if (callerOrigin) headers["caller-origin"] = callerOrigin;

  const body = {
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
  };

  const r = await fetch(`${PICPAY_API_BASE}/charge/pix`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) {
    const detail =
      data.message ||
      data.error ||
      (Array.isArray(data.errors) ? data.errors.map((e) => e.message || e).join("; ") : null) ||
      JSON.stringify(data).slice(0, 400);
    throw new Error(`PicPay charge/pix ${r.status}: ${detail}`);
  }
  return data;
}

/**
 * @param {string} merchantChargeId
 */
async function getCharge(merchantChargeId) {
  const token = await getAccessToken();
  const r = await fetch(
    `${PICPAY_API_BASE}/charge/${encodeURIComponent(merchantChargeId)}`,
    {
      method: "GET",
      headers: {
        Accept: "application/json",
        Authorization: `Bearer ${token}`,
      },
    }
  );
  const data = await r.json().catch(() => ({}));
  if (!r.ok) {
    throw new Error(data.message || data.error || `PicPay GET charge ${r.status}`);
  }
  return data;
}

/**
 * Extrai QR Pix da resposta de criação/consulta.
 * @param {object} charge
 */
function extractPixFromCharge(charge) {
  const txs = charge && charge.transactions;
  if (!Array.isArray(txs)) return null;
  for (const tx of txs) {
    const pix = tx && tx.pix;
    if (pix && (pix.qrCode || pix.qrCodeBase64)) {
      return {
        qrCode: pix.qrCode || "",
        qrCodeBase64: pix.qrCodeBase64 || "",
        transactionStatus: tx.transactionStatus || "",
      };
    }
  }
  return null;
}

function isConfigured() {
  return Boolean((process.env.PICPAY_CLIENT_ID || "").trim() && (process.env.PICPAY_CLIENT_SECRET || "").trim());
}

module.exports = {
  createPixCharge,
  getCharge,
  extractPixFromCharge,
  isConfigured,
};
