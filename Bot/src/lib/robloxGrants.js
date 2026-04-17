const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const dataDir = path.join(__dirname, "../../data");
const filePath = path.join(dataDir, "roblox-pending-grants.json");

function loadFile() {
  try {
    const raw = fs.readFileSync(filePath, "utf8");
    const j = JSON.parse(raw);
    if (!Array.isArray(j.grants)) {
      return [];
    }
    return j.grants;
  } catch {
    return [];
  }
}

function saveFile(grants) {
  fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify({ grants }, null, 2), "utf8");
}

/** Fonte de verdade em runtime (Render: disco pode falhar ou estar vazio após deploy). */
let memoryGrants = loadFile();

const VALID_TIERS = { Bronze: true, Gold: true, Diamante: true };

const VEHICLE_ID_RE = /^[\w-]{1,64}$/;

function isValidVehicleId(id) {
  return typeof id === "string" && VEHICLE_ID_RE.test(id);
}

/**
 * Enfileira entrega no jogo após pagamento Stripe (metadata).
 * Idempotente por stripeSessionId.
 *
 * @param {object} params
 * @param {string} params.stripeSessionId
 * @param {string} params.robloxUserId
 * @param {string} [params.grantType] — "vip" | "vehicle"
 * @param {string} [params.grantTier] — Bronze | Gold | Diamante (VIP)
 * @param {number} [params.grantDays]
 * @param {string} [params.grantVehicleId] — NomeInventario do ConcessionariaCatalogo (vehicle)
 */
function queueGrantAfterPayment(params) {
  const { stripeSessionId, robloxUserId, grantType, grantTier, grantDays, grantVehicleId } = params;
  if (!stripeSessionId || !robloxUserId) {
    return null;
  }

  const gtype = String(grantType || "vip").trim().toLowerCase() || "vip";

  if (gtype === "vehicle") {
    const vid = String(grantVehicleId || "").trim();
    if (!isValidVehicleId(vid)) {
      console.warn("[roblox] grantVehicleId inválido:", grantVehicleId);
      return null;
    }
    if (memoryGrants.some((g) => g.stripeSessionId === stripeSessionId)) {
      return null;
    }
    const id = crypto.randomUUID();
    const grant = {
      id,
      robloxUserId: String(robloxUserId),
      grantType: "vehicle",
      grantTier: "",
      grantVehicleId: vid,
      grantDays: 0,
      stripeSessionId,
      createdAt: Date.now(),
      acknowledged: false,
    };
    memoryGrants.push(grant);
    try {
      saveFile(memoryGrants);
    } catch (e) {
      console.error("[roblox] aviso: não gravou em disco; grant só em RAM nesta instância:", e.message || e);
    }
    console.log(`[roblox] fila: vehicle ${id} UserId=${robloxUserId} ${vid} (sessão ${stripeSessionId.slice(0, 12)}…)`);
    return id;
  }

  if (!grantTier || !VALID_TIERS[grantTier]) {
    console.warn("[roblox] grantTier inválido:", grantTier);
    return null;
  }
  const days = Math.max(0, Math.min(3650, Math.floor(Number(grantDays) || 0)));
  if (memoryGrants.some((g) => g.stripeSessionId === stripeSessionId)) {
    return null;
  }
  const id = crypto.randomUUID();
  const grant = {
    id,
    robloxUserId: String(robloxUserId),
    grantType: grantType || "vip",
    grantTier,
    grantDays: days,
    stripeSessionId,
    createdAt: Date.now(),
    acknowledged: false,
  };
  memoryGrants.push(grant);
  try {
    saveFile(memoryGrants);
  } catch (e) {
    console.error("[roblox] aviso: não gravou em disco; grant só em RAM nesta instância:", e.message || e);
  }
  console.log(`[roblox] fila: grant ${id} UserId=${robloxUserId} ${grantTier} ${days}d (sessão ${stripeSessionId.slice(0, 12)}…)`);
  return id;
}

function getPendingForRobloxUser(userId) {
  const uid = String(userId);
  return memoryGrants.filter((g) => g.robloxUserId === uid && !g.acknowledged);
}

function acknowledgeByIds(ids) {
  if (!Array.isArray(ids) || ids.length === 0) {
    return 0;
  }
  const set = new Set(ids.map(String));
  let n = 0;
  for (const g of memoryGrants) {
    if (set.has(g.id) && !g.acknowledged) {
      g.acknowledged = true;
      n += 1;
    }
  }
  try {
    saveFile(memoryGrants);
  } catch (e) {
    console.error("[roblox] ack: falha ao gravar disco:", e.message || e);
  }
  return n;
}

module.exports = {
  queueGrantAfterPayment,
  getPendingForRobloxUser,
  acknowledgeByIds,
  VALID_TIERS,
  isValidVehicleId,
};
