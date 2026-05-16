function normalizeCode(code) {
  return String(code || "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9_-]/g, "")
    .slice(0, 50);
}

function toInt(value, fallback = 0) {
  const n = parseInt(value, 10);
  return Number.isFinite(n) ? n : fallback;
}

function toBool(value, fallback = true) {
  if (value == null || value === "") return fallback;
  const v = String(value).trim().toLowerCase();
  if (["1", "true", "yes", "on", "enabled", "enable"].includes(v)) return true;
  if (["0", "false", "no", "off", "disabled", "disable"].includes(v)) return false;
  return fallback;
}

function parseSingleCouponFromEnv() {
  const raw = String(process.env.GEAR_SINGLE_COUPON || "").trim();
  if (!raw) return null;

  const enabledByFlag = toBool(process.env.GEAR_SINGLE_COUPON_ENABLED, true);
  const parts = raw.split(":");
  if (parts.length < 2) {
    console.warn("[coupon] GEAR_SINGLE_COUPON inválido. Use formato CODE:10 ou CODE:10:true");
    return null;
  }

  const code = normalizeCode(parts[0]);
  const pct = Math.max(1, Math.min(90, toInt(parts[1], 0)));
  const enabledByInline = toBool(parts[2], true);

  if (!code || pct < 1) {
    console.warn("[coupon] GEAR_SINGLE_COUPON inválido. Exemplo: CUPOM10:10");
    return null;
  }
  if (!enabledByFlag || !enabledByInline) return null;

  return { code, rule: { type: "percent", value: pct } };
}

function parseRulesFromEnv() {
  const raw = String(process.env.GEAR_SERVER_COUPONS_JSON || "").trim();
  const rules = {};
  const single = parseSingleCouponFromEnv();

  if (!raw) {
    if (single) {
      rules[single.code] = single.rule;
    }
    return rules;
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    console.warn("[coupon] GEAR_SERVER_COUPONS_JSON inválido:", e.message || e);
    return rules;
  }
  if (!parsed || typeof parsed !== "object") return rules;
  for (const [rawCode, rawRule] of Object.entries(parsed)) {
    const code = normalizeCode(rawCode);
    if (!code) continue;

    // Atalho: {"GEAR10": 10}
    if (typeof rawRule === "number" || typeof rawRule === "string") {
      const pct = Math.max(1, Math.min(90, toInt(rawRule, 0)));
      if (pct > 0) rules[code] = { type: "percent", value: pct };
      continue;
    }

    if (!rawRule || typeof rawRule !== "object") continue;
    if (rawRule.enabled === false) continue;

    const type = String(rawRule.type || "percent").trim().toLowerCase();
    const value = toInt(rawRule.value, 0);
    if (type === "fixed") {
      const cents = Math.max(1, Math.min(99999999, value));
      rules[code] = { type: "fixed", value: cents };
      continue;
    }

    const pct = Math.max(1, Math.min(90, value));
    rules[code] = { type: "percent", value: pct };
  }

  if (single) {
    // O cupom simples tem prioridade quando coexistir com JSON.
    rules[single.code] = single.rule;
  }

  return rules;
}

function resolveCouponDiscount(couponCode, subtotalCents) {
  const code = normalizeCode(couponCode);
  if (!code) {
    return { couponCode: "", discountCents: 0, discountPercent: 0 };
  }

  const rules = parseRulesFromEnv();
  const rule = rules[code];
  if (!rule) return { error: "cupom inválido ou expirado", status: 400 };

  const subtotal = Math.max(0, toInt(subtotalCents, 0));
  if (rule.type === "fixed") {
    const discount = Math.min(subtotal, Math.max(0, toInt(rule.value, 0)));
    return { couponCode: code, discountCents: discount, discountPercent: 0 };
  }

  const pct = Math.max(0, Math.min(90, toInt(rule.value, 0)));
  const discount = Math.floor((subtotal * pct) / 100);
  return { couponCode: code, discountCents: discount, discountPercent: pct };
}

module.exports = {
  resolveCouponDiscount,
};
