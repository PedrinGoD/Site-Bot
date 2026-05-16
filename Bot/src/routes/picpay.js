const crypto = require("crypto");
const QRCode = require("qrcode");
const picpayCheckout = require("../lib/picpayCheckout");
const picpayPending = require("../lib/picpayPending");
const { pixCodeToDataUrl } = require("../lib/pixQrImage");

/**
 * @param {import('express').Express} app
 * @param {object} ctx
 */
function registerPicPayRoutes(app, ctx) {
  const {
    client,
    defaultGuildId,
    discordClientSecret,
    allowManualDiscordId,
    sessionSigningSecret,
    verifyDiscordSession,
    extractBearer,
    robloxGrants,
    maybeQueueRobloxGrant,
    deliverSaleToDiscord,
  } = ctx;

  const notifiedPicPay = new Set();
  const picpayWebhookToken = (process.env.PICPAY_WEBHOOK_TOKEN || "").trim();

  async function buildPixClientFields(pix, charge) {
    const qrCode = String(pix?.qrCode || charge?.qrCode || "").trim();
    let qrCodeBase64 = String(pix?.qrCodeBase64 || charge?.qrCodeBase64 || "").trim();
    if (qrCode && !qrCodeBase64) {
      qrCodeBase64 = await pixCodeToDataUrl(qrCode);
    }
    return {
      qrCode,
      qrCodeBase64,
      checkoutLink: pix?.checkoutLink || charge?.checkoutLink || "",
    };
  }

  /** GET /picpay/qr-image?text=000201... — PNG do QR (fallback para o site) */
  app.get("/picpay/qr-image", async (req, res) => {
    const text = String(req.query.text || "").trim();
    if (!text || !/^000201/i.test(text)) {
      return res.status(400).send("invalid pix code");
    }
    try {
      const buf = await QRCode.toBuffer(text, {
        width: 280,
        margin: 1,
        errorCorrectionLevel: "M",
      });
      res.set("Cache-Control", "private, max-age=3600");
      res.type("png").send(buf);
    } catch (e) {
      console.error("[picpay] qr-image:", e.message || e);
      return res.status(500).send("qr error");
    }
  });

  function clientIp(req) {
    const xf = req.headers["x-forwarded-for"];
    if (typeof xf === "string" && xf.length) return xf.split(",")[0].trim();
    return req.socket?.remoteAddress || "127.0.0.1";
  }

  function buildPicPayCustomer(body, sess) {
    const name = String(body.customerName || sess?.global_name || sess?.username || "Cliente")
      .trim()
      .slice(0, 255);
    const email = String(body.customerEmail || "").trim();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return { error: "Informe um e-mail válido para pagamento Pix." };
    }
    const doc = String(body.customerDocument || body.customerCpf || "").replace(/\D/g, "");
    if (doc.length !== 11) {
      return { error: "Informe o CPF (11 dígitos) para pagamento Pix." };
    }
    const phone = body.customerPhone && typeof body.customerPhone === "object" ? body.customerPhone : {};
    const areaCode = String(phone.areaCode || process.env.PICPAY_DEFAULT_AREA_CODE || "47")
      .replace(/\D/g, "")
      .slice(0, 3);
    const number = String(phone.number || process.env.PICPAY_DEFAULT_PHONE || "999999999")
      .replace(/\D/g, "")
      .slice(0, 11);
    return {
      customer: {
        name,
        email,
        documentType: "CPF",
        document: doc,
        phone: {
          countryCode: "55",
          areaCode: areaCode || "47",
          number,
          type: "MOBILE",
        },
      },
    };
  }

  /**
   * @param {string} merchantChargeId
   * @param {Record<string, string>} md
   * @param {string} contextLabel
   */
  async function tryFulfillPicPayCharge(merchantChargeId, md, contextLabel) {
    if (!merchantChargeId) return { ok: false, reason: "no_id" };
    const key = `picpay:${merchantChargeId}`;
    if (notifiedPicPay.has(key)) {
      return { ok: true, duplicate: true };
    }

    const fakeSession = {
      id: key,
      payment_status: "paid",
      metadata: md,
    };

    try {
      maybeQueueRobloxGrant(fakeSession);
    } catch (e) {
      console.error(`[picpay] fila roblox (${contextLabel}):`, e.message || e);
    }

    const discordUserId = md.discord_user_id || md.discordUserId;
    const guildId = md.guild_id || md.guildId || defaultGuildId;
    const itemName = md.item_name || md.itemName || "Item";
    const img = md.item_image_url || md.itemImageUrl;
    const itemImageUrl =
      img && String(img).trim() && /^https?:\/\//i.test(String(img).trim()) ? String(img).trim() : undefined;

    if (discordUserId) {
      try {
        await deliverSaleToDiscord(
          client,
          {
            guildId,
            discordUserId,
            itemName,
            orderId: merchantChargeId,
            quantity: 1,
            kind: "sale",
            note: "Pix PicPay",
            itemImageUrl,
            stripeCheckout: true,
          },
          false
        );
      } catch (e) {
        console.error(`[picpay] Discord (${contextLabel}):`, e.message || e);
        return { ok: false, error: String(e.message || e) };
      }
    }

    notifiedPicPay.add(key);
    picpayPending.markNotified(merchantChargeId);
    console.log(`[picpay] ✓ Pedido processado (${contextLabel}) — ${merchantChargeId}`);
    return { ok: true };
  }

  /**
   * POST /picpay/create-pix-charge — mesmo body do Stripe + customerEmail, customerDocument (CPF)
   */
  app.post("/picpay/create-pix-charge", async (req, res) => {
    if (!picpayCheckout.isConfigured()) {
      return res.status(503).json({
        ok: false,
        error: "PicPay não configurado (PICPAY_CLIENT_ID e PICPAY_CLIENT_SECRET no .env)",
      });
    }

    const parsed = ctx.parseCheckoutOrder(req);
    if (parsed.error) {
      return res.status(parsed.status || 400).json({ ok: false, error: parsed.error });
    }

    const bearer = extractBearer(req) || String(req.body.discordSessionToken || "").trim();
    const sess = bearer ? verifyDiscordSession(bearer, sessionSigningSecret) : null;
    const cust = buildPicPayCustomer(req.body, sess);
    if (cust.error) {
      return res.status(400).json({ ok: false, error: cust.error });
    }

    const orderNumber = crypto.randomBytes(6).toString("hex").slice(0, 12);
    const merchantChargeId = `gear-${orderNumber}`;
    const amountCents = parsed.totalCents;

    try {
      const charge = await picpayCheckout.createPixCharge({
        merchantChargeId,
        amountCents,
        customer: cust.customer,
        clientIp: clientIp(req),
        description: parsed.meta?.item_name || "Compra Gear UP",
      });
      const paymentLinkId = charge.paymentLinkId || "";
      picpayPending.savePending(merchantChargeId, parsed.meta, amountCents, {
        paymentLinkId: paymentLinkId || undefined,
      });
      const pix = picpayCheckout.extractPixFromCharge(charge);
      const pixFields = await buildPixClientFields(pix, charge);
      return res.json({
        ok: true,
        merchantChargeId,
        amountCents,
        chargeStatus: charge.chargeStatus,
        ...pixFields,
        redirectUrl: `${ctx.siteBaseUrl}/pagamento-pix.html?charge=${encodeURIComponent(merchantChargeId)}`,
      });
    } catch (e) {
      console.error("[picpay] create-pix-charge:", e);
      return res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });

  /** GET /picpay/order/:merchantChargeId — status + QR (consulta PicPay) */
  app.get("/picpay/order/:merchantChargeId", async (req, res) => {
    const merchantChargeId = String(req.params.merchantChargeId || "").trim();
    if (!merchantChargeId || !/^gear-[a-zA-Z0-9-]+$/.test(merchantChargeId)) {
      return res.status(400).json({ ok: false, error: "charge inválido" });
    }
    if (!picpayCheckout.isConfigured()) {
      return res.status(503).json({ ok: false, error: "PicPay não configurado" });
    }
    try {
      const pending = picpayPending.getPending(merchantChargeId);
      const charge = await picpayCheckout.getCharge(
        merchantChargeId,
        pending?.paymentLinkId
      );
      const pix = picpayCheckout.extractPixFromCharge(charge);
      const paid = picpayCheckout.isChargePaid(charge);
      const pixFields = await buildPixClientFields(pix, charge);

      if (paid && pending?.metadata) {
        await tryFulfillPicPayCharge(merchantChargeId, pending.metadata, "poll");
      }

      return res.json({
        ok: true,
        merchantChargeId,
        chargeStatus: charge.chargeStatus,
        paid,
        amountCents: charge.amount ?? pending?.amountCents,
        ...pixFields,
        itemName: pending?.metadata?.item_name || "",
      });
    } catch (e) {
      console.error("[picpay] order status:", e);
      return res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });

  /** POST /webhooks/picpay — configure URL no painel PicPay (HTTPS, sem query string) */
  app.post("/webhooks/picpay", async (req, res) => {
    if (picpayWebhookToken) {
      const auth = String(req.headers.authorization || "").trim();
      const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : auth;
      if (token !== picpayWebhookToken) {
        console.warn("[picpay] webhook: token inválido");
        return res.status(401).send("unauthorized");
      }
    }

    const body = req.body || {};
    const data = body.data && typeof body.data === "object" ? body.data : body;
    const chargeBlock = data.charge && typeof data.charge === "object" ? data.charge : {};
    const txBlock = data.transaction && typeof data.transaction === "object" ? data.transaction : {};
    const paymentLinkId =
      chargeBlock.paymentLinkId ||
      chargeBlock.payment_link_id ||
      data.paymentLinkId ||
      data.payment_link_id;
    let merchantChargeId =
      data.merchantChargeId ||
      data.merchant_charge_id ||
      chargeBlock.referenceId ||
      chargeBlock.reference_id ||
      body.merchantChargeId ||
      body.merchant_charge_id ||
      body.referenceId ||
      body.reference_id;

    if (paymentLinkId && !merchantChargeId) {
      const found = picpayPending.findByPaymentLinkId(String(paymentLinkId));
      if (found) merchantChargeId = found.merchantChargeId;
    }

    if (!merchantChargeId && paymentLinkId) {
      merchantChargeId = String(paymentLinkId);
    }

    if (!merchantChargeId) {
      return res.status(400).json({ ok: false, error: "merchantChargeId em falta" });
    }

    console.log(`[picpay] webhook recebido — ${merchantChargeId}`);

    try {
      const txStatus = String(txBlock.status || data.status || "").toUpperCase();
      const webhookPaid = txStatus === "PAID" || txStatus === "PAYED";
      const pending = picpayPending.getPending(String(merchantChargeId));
      const charge = await picpayCheckout.getCharge(
        String(merchantChargeId),
        pending?.paymentLinkId || paymentLinkId
      );
      const paid = webhookPaid || picpayCheckout.isChargePaid(charge);
      if (!paid) {
        return res.json({ received: true, paid: false });
      }
      let md = pending?.metadata;
      if (!md) md = {};
      await tryFulfillPicPayCharge(String(merchantChargeId), md, "webhook");
      return res.json({ received: true, paid: true });
    } catch (e) {
      console.error("[picpay] webhook:", e);
      return res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });

  return { tryFulfillPicPayCharge };
}

module.exports = { registerPicPayRoutes };
