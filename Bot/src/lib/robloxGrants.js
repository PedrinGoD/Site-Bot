const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const dataDir = path.join(__dirname, "../../data");
const filePath = path.join(dataDir, "roblox-pending-grants.json");

function load() {
  try {
    const raw = fs.readFileSync(filePath, "utf8");
    const j = JSON.parse(raw);
    if (!Array.isArray(j.grants)) {
      return { grants: [] };
    }
    return j;
  } catch {
    return { grants: [] };
  }
}

function save(data) {
  fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), "utf8");
}

const VALID_TIERS = { Bronze: true, Gold: true, Diamante: true };

/**
 * Enfileira entrega no jogo após pagamento Stripe (metadata).
 * Idempotente por stripeSessionId.
 *
 * @param {object} params
 * @param {string} params.stripeSessionId
 * @param {string} params.robloxUserId
 * @param {string} params.grantType — ex.: "vip"
 * @param {string} params.grantTier — Bronze | Gold | Diamante
 * @param {number} params.grantDays
 */
function queueGrantAfterPayment(params) {
  const { stripeSessionId, robloxUserId, grantType, grantTier, grantDays } = params;
  if (!stripeSessionId || !robloxUserId || !grantTier) {
    return null;
  }
  if (!VALID_TIERS[grantTier]) {
    console.warn("[roblox] grantTier inválido:", grantTier);
    return null;
  }
  const days = Math.max(0, Math.min(3650, Math.floor(Number(grantDays) || 0)));
  const data = load();
  if (data.grants.some((g) => g.stripeSessionId === stripeSessionId)) {
    return null;
  }
  const id = crypto.randomUUID();
  data.grants.push({
    id,
    robloxUserId: String(robloxUserId),
    grantType: grantType || "vip",
    grantTier,
    grantDays: days,
    stripeSessionId,
    createdAt: Date.now(),
    acknowledged: false,
  });
  save(data);
  console.log(`[roblox] fila: grant ${id} UserId=${robloxUserId} ${grantTier} ${days}d (sessão ${stripeSessionId.slice(0, 12)}…)`);
  return id;
}

function getPendingForRobloxUser(userId) {
  const uid = String(userId);
  const data = load();
  return data.grants.filter((g) => g.robloxUserId === uid && !g.acknowledged);
}

function acknowledgeByIds(ids) {
  if (!Array.isArray(ids) || ids.length === 0) {
    return 0;
  }
  const set = new Set(ids.map(String));
  const data = load();
  let n = 0;
  for (const g of data.grants) {
    if (set.has(g.id) && !g.acknowledged) {
      g.acknowledged = true;
      n += 1;
    }
  }
  save(data);
  return n;
}

module.exports = {
  queueGrantAfterPayment,
  getPendingForRobloxUser,
  acknowledgeByIds,
  VALID_TIERS,
};
