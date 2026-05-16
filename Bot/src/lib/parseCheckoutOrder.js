const robloxGrants = require("./robloxGrants");
const { resolveCouponDiscount } = require("./serverCoupons");

/**
 * Valida body do checkout (Stripe/PicPay) e monta metadata + total em centavos.
 * @param {import('express').Request} req
 * @param {object} deps
 */
function parseCheckoutOrder(req, deps) {
  const {
    defaultGuildId,
    discordClientSecret,
    allowManualDiscordId,
    verifyDiscordSession,
    sessionSigningSecret,
    extractBearer,
  } = deps;

  const bearer = extractBearer(req) || String(req.body.discordSessionToken || "").trim();
  const sess = bearer ? verifyDiscordSession(bearer, sessionSigningSecret) : null;

  let resolvedDiscordUserId = null;
  if (sess?.sub) {
    resolvedDiscordUserId = sess.sub;
  } else if (discordClientSecret && !allowManualDiscordId) {
    return { error: "login_discord_obrigatorio", status: 401 };
  } else if (req.body.discordUserId) {
    resolvedDiscordUserId = String(req.body.discordUserId);
  }

  const guildId = req.body.guildId || defaultGuildId;
  let itemImageUrl = String(req.body.itemImageUrl || "").trim();
  if (itemImageUrl.length > 500) itemImageUrl = itemImageUrl.slice(0, 500);
  if (itemImageUrl && !/^https?:\/\//i.test(itemImageUrl)) itemImageUrl = "";

  /** @type {Array<object>} */
  let items = [];
  if (Array.isArray(req.body.items) && req.body.items.length) {
    items = req.body.items.slice(0, 20).map((raw, idx) => {
      const itemName = String(raw && raw.itemName ? raw.itemName : `Item ${idx + 1}`).slice(0, 200);
      let amountCents = parseInt(raw && raw.amountCents, 10);
      if (Number.isNaN(amountCents) || amountCents < 50) amountCents = 100;
      let quantity = parseInt(raw && raw.quantity, 10);
      if (Number.isNaN(quantity) || quantity < 1) quantity = 1;
      if (quantity > 30) quantity = 30;
      const grantTier = String((raw && raw.grantTier) || "").trim();
      const grantVehicleId = String((raw && raw.grantVehicleId) || "")
        .trim()
        .slice(0, 64);
      const grantType = String((raw && raw.grantType) || "vip").trim().slice(0, 32) || "vip";
      let grantMoneyAmount = parseInt(raw && raw.grantMoneyAmount, 10);
      if (Number.isNaN(grantMoneyAmount)) grantMoneyAmount = 0;
      let grantXpAmount = parseInt(raw && raw.grantXpAmount, 10);
      if (Number.isNaN(grantXpAmount)) grantXpAmount = 0;
      let grantDays = parseInt(raw && raw.grantDays, 10);
      if (Number.isNaN(grantDays)) grantDays = 0;
      grantDays = Math.max(0, Math.min(3650, grantDays));
      let image = String((raw && raw.itemImageUrl) || "").trim();
      if (image.length > 500) image = image.slice(0, 500);
      if (image && !/^https?:\/\//i.test(image)) image = "";
      return {
        itemName,
        amountCents,
        quantity,
        itemImageUrl: image || undefined,
        grantTier: grantTier || undefined,
        grantVehicleId: grantVehicleId || undefined,
        grantType: grantType || undefined,
        grantMoneyAmount,
        grantXpAmount,
        grantDays,
      };
    });
  } else {
    let amountCents = parseInt(req.body.amountCents, 10);
    if (Number.isNaN(amountCents) || amountCents < 50) amountCents = 100;
    items = [
      {
        itemName: String(req.body.itemName || "Item").slice(0, 200),
        amountCents,
        quantity: 1,
        itemImageUrl: itemImageUrl || undefined,
        grantTier: String(req.body.grantTier || "").trim() || undefined,
        grantVehicleId: String(req.body.grantVehicleId || "").trim().slice(0, 64) || undefined,
        grantType: String(req.body.grantType || "vip").trim().slice(0, 32) || "vip",
        grantMoneyAmount: parseInt(req.body.grantMoneyAmount, 10) || 0,
        grantXpAmount: parseInt(req.body.grantXpAmount, 10) || 0,
        grantDays: Math.max(0, Math.min(3650, parseInt(req.body.grantDays, 10) || 0)),
      },
    ];
  }

  const robloxUserIdBody = String(req.body.robloxUserId || "").trim();

  function itemNeedsRobloxDelivery(it) {
    const gt = String(it.grantType || "vip").trim().toLowerCase();
    if (gt === "vehicle" && it.grantVehicleId && robloxGrants.isValidVehicleId(String(it.grantVehicleId))) {
      return true;
    }
    if (gt === "currency" && robloxGrants.isValidMoneyAmount(it.grantMoneyAmount)) return true;
    if (gt === "xp" && robloxGrants.isValidXpAmount(it.grantXpAmount)) return true;
    if (gt === "economy") {
      const m = Math.floor(Number(it.grantMoneyAmount) || 0);
      const x = Math.floor(Number(it.grantXpAmount) || 0);
      if (m < 1 && x < 1) return false;
      if (m >= 1 && !robloxGrants.isValidMoneyAmount(m)) return false;
      if (x >= 1 && !robloxGrants.isValidXpAmount(x)) return false;
      return true;
    }
    return Boolean(it.grantTier && robloxGrants.VALID_TIERS[String(it.grantTier)]);
  }

  const grantItems = items.filter(itemNeedsRobloxDelivery);
  for (const gi of grantItems) {
    const gt = String(gi.grantType || "vip").trim().toLowerCase();
    if (gt === "vehicle" && !robloxGrants.isValidVehicleId(String(gi.grantVehicleId || ""))) {
      return {
        error: "grantVehicleId inválido (use NomeInventario do catálogo: letras, números, _ e -)",
        status: 400,
      };
    }
    if (gt === "currency" && !robloxGrants.isValidMoneyAmount(gi.grantMoneyAmount)) {
      return { error: "grantMoneyAmount inválido (1 a 2e9)", status: 400 };
    }
    if (gt === "xp" && !robloxGrants.isValidXpAmount(gi.grantXpAmount)) {
      return { error: "grantXpAmount inválido (1 a 2e9)", status: 400 };
    }
    if (gt === "economy") {
      const m = Math.floor(Number(gi.grantMoneyAmount) || 0);
      const x = Math.floor(Number(gi.grantXpAmount) || 0);
      if (m < 1 && x < 1) return { error: "economy: indique dinheiro ou XP (≥1)", status: 400 };
    }
    if (gt === "vip" && !robloxGrants.VALID_TIERS[String(gi.grantTier)]) {
      return { error: "grantTier deve ser Bronze, Gold ou Diamante", status: 400 };
    }
  }
  if (grantItems.length && (!robloxUserIdBody || !/^\d{1,20}$/.test(robloxUserIdBody))) {
    return { error: "robloxUserId obrigatório para entrega no jogo", status: 400 };
  }
  if (!resolvedDiscordUserId || !/^\d{17,20}$/.test(String(resolvedDiscordUserId))) {
    return { error: "discordUserId inválido ou sessão em falta", status: 400 };
  }
  if (!guildId) {
    return { error: "missing guildId", status: 400 };
  }

  const subtotal = items.reduce((acc, it) => {
    const qty = Math.max(1, parseInt(it.quantity, 10) || 1);
    return acc + qty * Math.max(50, parseInt(it.amountCents, 10) || 100);
  }, 0);
  const couponApply = resolveCouponDiscount(req.body.couponCode, subtotal);
  if (couponApply.error) {
    return { error: couponApply.error, status: couponApply.status || 400 };
  }
  const discount = Math.max(0, couponApply.discountCents || 0);
  const totalCents = Math.max(50, subtotal - discount);

  const summaryItemName =
    items.length === 1
      ? items[0].itemName
      : `${items.length} itens no carrinho (${items.reduce((acc, it) => acc + it.quantity, 0)} unidade(s))`;

  const meta = {
    discord_user_id: String(resolvedDiscordUserId),
    item_name: summaryItemName.slice(0, 200),
    guild_id: String(guildId),
  };
  const firstImage = items.find((it) => it.itemImageUrl)?.itemImageUrl || itemImageUrl;
  if (firstImage) meta.item_image_url = firstImage;

  if (grantItems.length && robloxUserIdBody) {
    meta.roblox_user_id = robloxUserIdBody;
    if (grantItems.length === 1) {
      const g0 = grantItems[0];
      const g0t = String(g0.grantType || "vip").trim().toLowerCase();
      if (g0t === "vehicle" && g0.grantVehicleId) {
        meta.grant_type = "vehicle";
        meta.grant_vehicle_id = String(g0.grantVehicleId).slice(0, 64);
        meta.grant_days = "0";
      } else if (g0t === "currency" && robloxGrants.isValidMoneyAmount(g0.grantMoneyAmount)) {
        meta.grant_type = "currency";
        meta.grant_money_amount = String(Math.floor(Number(g0.grantMoneyAmount) || 0));
        meta.grant_days = "0";
      } else if (g0t === "xp" && robloxGrants.isValidXpAmount(g0.grantXpAmount)) {
        meta.grant_type = "xp";
        meta.grant_xp_amount = String(Math.floor(Number(g0.grantXpAmount) || 0));
        meta.grant_days = "0";
      } else if (g0t === "economy") {
        meta.grant_type = "economy";
        meta.grant_money_amount = String(Math.floor(Number(g0.grantMoneyAmount) || 0));
        meta.grant_xp_amount = String(Math.floor(Number(g0.grantXpAmount) || 0));
        meta.grant_days = "0";
      } else {
        meta.grant_type = g0.grantType || "vip";
        meta.grant_tier = g0.grantTier;
        meta.grant_days = String(g0.grantDays || 0);
      }
    } else {
      const compact = grantItems.map((g) => {
        const gt = String(g.grantType || "vip").trim().toLowerCase();
        if (gt === "vehicle" && g.grantVehicleId) {
          return { grantType: "vehicle", grantVehicleId: String(g.grantVehicleId).slice(0, 64), grantDays: 0 };
        }
        if (gt === "currency" && robloxGrants.isValidMoneyAmount(g.grantMoneyAmount)) {
          return { grantType: "currency", grantMoneyAmount: Math.floor(Number(g.grantMoneyAmount) || 0), grantDays: 0 };
        }
        if (gt === "xp" && robloxGrants.isValidXpAmount(g.grantXpAmount)) {
          return { grantType: "xp", grantXpAmount: Math.floor(Number(g.grantXpAmount) || 0), grantDays: 0 };
        }
        if (gt === "economy") {
          return {
            grantType: "economy",
            grantMoneyAmount: Math.floor(Number(g.grantMoneyAmount) || 0),
            grantXpAmount: Math.floor(Number(g.grantXpAmount) || 0),
            grantDays: 0,
          };
        }
        return { grantType: g.grantType || "vip", grantTier: g.grantTier, grantDays: g.grantDays || 0 };
      });
      const asJson = JSON.stringify(compact);
      if (asJson.length > 500) {
        return {
          error:
            "Carrinho grande demais para metadata (máx. 500 caracteres). Finalize em duas compras ou reduza itens.",
          status: 400,
        };
      }
      meta.roblox_grants_json = asJson;
    }
  }

  if (couponApply.couponCode) meta.coupon_code = couponApply.couponCode;
  if (couponApply.discountPercent > 0) {
    meta.discount_percent = String(Math.min(90, couponApply.discountPercent));
  }
  if (discount > 0) meta.discount_cents = String(discount);

  return {
    meta,
    items,
    totalCents,
    resolvedDiscordUserId,
    guildId,
    sess,
  };
}

module.exports = { parseCheckoutOrder };
