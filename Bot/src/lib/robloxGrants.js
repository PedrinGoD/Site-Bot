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
const MAX_ECONOMY = 2_000_000_000;

function isValidVehicleId(id) {
  return typeof id === "string" && VEHICLE_ID_RE.test(id);
}

function isValidMoneyAmount(n) {
  const x = Math.floor(Number(n) || 0);
  return x >= 1 && x <= MAX_ECONOMY;
}

function isValidXpAmount(n) {
  const x = Math.floor(Number(n) || 0);
  return x >= 1 && x <= MAX_ECONOMY;
}

function pushGrant(grant) {
  if (memoryGrants.some((g) => g.stripeSessionId === grant.stripeSessionId)) {
    return null;
  }
  memoryGrants.push(grant);
  try {
    saveFile(memoryGrants);
  } catch (e) {
    console.error("[roblox] aviso: não gravou em disco; grant só em RAM nesta instância:", e.message || e);
  }
  return grant.id;
}

/**
 * Enfileira entrega no jogo após pagamento Stripe (metadata).
 * Idempotente por stripeSessionId.
 *
 * @param {object} params
 * @param {string} params.stripeSessionId
 * @param {string} params.robloxUserId
 * @param {string} [params.grantType] — "vip" | "vehicle" | "currency" | "xp" | "economy"
 */
function queueGrantAfterPayment(params) {
  const {
    stripeSessionId,
    robloxUserId,
    grantType,
    grantTier,
    grantDays,
    grantVehicleId,
    grantMoneyAmount,
    grantXpAmount,
  } = params;
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
    const id = crypto.randomUUID();
    const grant = {
      id,
      robloxUserId: String(robloxUserId),
      grantType: "vehicle",
      grantTier: "",
      grantVehicleId: vid,
      grantMoneyAmount: 0,
      grantXpAmount: 0,
      grantDays: 0,
      stripeSessionId,
      createdAt: Date.now(),
      acknowledged: false,
    };
    const out = pushGrant(grant);
    if (out) {
      console.log(`[roblox] fila: vehicle ${id} UserId=${robloxUserId} ${vid} (sessão ${stripeSessionId.slice(0, 12)}…)`);
    }
    return out;
  }

  if (gtype === "currency") {
    const m = Math.floor(Number(grantMoneyAmount) || 0);
    if (!isValidMoneyAmount(m)) {
      console.warn("[roblox] grantMoneyAmount inválido:", grantMoneyAmount);
      return null;
    }
    const id = crypto.randomUUID();
    const grant = {
      id,
      robloxUserId: String(robloxUserId),
      grantType: "currency",
      grantTier: "",
      grantMoneyAmount: m,
      grantXpAmount: 0,
      grantDays: 0,
      stripeSessionId,
      createdAt: Date.now(),
      acknowledged: false,
    };
    const out = pushGrant(grant);
    if (out) {
      console.log(`[roblox] fila: currency ${id} UserId=${robloxUserId} $${m} (sessão ${stripeSessionId.slice(0, 12)}…)`);
    }
    return out;
  }

  if (gtype === "xp") {
    const x = Math.floor(Number(grantXpAmount) || 0);
    if (!isValidXpAmount(x)) {
      console.warn("[roblox] grantXpAmount inválido:", grantXpAmount);
      return null;
    }
    const id = crypto.randomUUID();
    const grant = {
      id,
      robloxUserId: String(robloxUserId),
      grantType: "xp",
      grantTier: "",
      grantMoneyAmount: 0,
      grantXpAmount: x,
      grantDays: 0,
      stripeSessionId,
      createdAt: Date.now(),
      acknowledged: false,
    };
    const out = pushGrant(grant);
    if (out) {
      console.log(`[roblox] fila: xp ${id} UserId=${robloxUserId} +${x} XP (sessão ${stripeSessionId.slice(0, 12)}…)`);
    }
    return out;
  }

  if (gtype === "economy") {
    let m = Math.floor(Number(grantMoneyAmount) || 0);
    let x = Math.floor(Number(grantXpAmount) || 0);
    if (m < 0 || x < 0 || m > MAX_ECONOMY || x > MAX_ECONOMY) {
      console.warn("[roblox] economy valores fora do intervalo:", grantMoneyAmount, grantXpAmount);
      return null;
    }
    if (m < 1 && x < 1) {
      console.warn("[roblox] economy sem dinheiro nem XP");
      return null;
    }
    const id = crypto.randomUUID();
    const grant = {
      id,
      robloxUserId: String(robloxUserId),
      grantType: "economy",
      grantTier: "",
      grantMoneyAmount: m,
      grantXpAmount: x,
      grantDays: 0,
      stripeSessionId,
      createdAt: Date.now(),
      acknowledged: false,
    };
    const out = pushGrant(grant);
    if (out) {
      console.log(
        `[roblox] fila: economy ${id} UserId=${robloxUserId} $${m} +${x}XP (sessão ${stripeSessionId.slice(0, 12)}…)`
      );
    }
    return out;
  }

  if (!grantTier || !VALID_TIERS[grantTier]) {
    console.warn("[roblox] grantTier inválido:", grantTier);
    return null;
  }
  const days = Math.max(0, Math.min(3650, Math.floor(Number(grantDays) || 0)));
  const id = crypto.randomUUID();
  const grant = {
    id,
    robloxUserId: String(robloxUserId),
    grantType: grantType || "vip",
    grantTier,
    grantMoneyAmount: 0,
    grantXpAmount: 0,
    grantDays: days,
    stripeSessionId,
    createdAt: Date.now(),
    acknowledged: false,
  };
  const out = pushGrant(grant);
  if (out) {
    console.log(`[roblox] fila: grant ${id} UserId=${robloxUserId} ${grantTier} ${days}d (sessão ${stripeSessionId.slice(0, 12)}…)`);
  }
  return out;
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
  isValidMoneyAmount,
  isValidXpAmount,
};
