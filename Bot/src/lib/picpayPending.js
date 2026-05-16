const fs = require("fs");
const path = require("path");

const DATA_DIR = path.join(__dirname, "../../data");
const FILE = path.join(DATA_DIR, "picpay-pending-charges.json");

/** @type {Map<string, object>} */
const memory = new Map();

function load() {
  try {
    if (!fs.existsSync(FILE)) return;
    const raw = JSON.parse(fs.readFileSync(FILE, "utf8"));
    if (raw && typeof raw === "object") {
      for (const [k, v] of Object.entries(raw)) {
        if (k && v) memory.set(k, v);
      }
    }
  } catch (e) {
    console.warn("[picpay] não foi possível carregar pending charges:", e.message || e);
  }
}

function persist() {
  try {
    if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
    const obj = Object.fromEntries(memory.entries());
    fs.writeFileSync(FILE, JSON.stringify(obj, null, 0), "utf8");
  } catch (e) {
    console.warn("[picpay] não foi possível gravar pending charges:", e.message || e);
  }
}

/**
 * @param {string} merchantChargeId
 * @param {Record<string, string>} metadata
 * @param {number} amountCents
 */
function savePending(merchantChargeId, metadata, amountCents, extra) {
  if (!merchantChargeId) return;
  memory.set(merchantChargeId, {
    metadata,
    amountCents,
    createdAt: new Date().toISOString(),
    notified: false,
    ...(extra && typeof extra === "object" ? extra : {}),
  });
  persist();
}

/**
 * @param {string} paymentLinkId
 */
function findByPaymentLinkId(paymentLinkId) {
  const id = String(paymentLinkId || "").trim();
  if (!id) return null;
  for (const [merchantChargeId, row] of memory.entries()) {
    if (row && String(row.paymentLinkId || "") === id) {
      return { merchantChargeId, ...row };
    }
  }
  return null;
}

/**
 * @param {string} merchantChargeId
 */
function getPending(merchantChargeId) {
  return memory.get(merchantChargeId) || null;
}

/**
 * @param {string} merchantChargeId
 */
function markNotified(merchantChargeId) {
  const row = memory.get(merchantChargeId);
  if (!row) return;
  row.notified = true;
  memory.set(merchantChargeId, row);
  persist();
}

load();

module.exports = {
  savePending,
  getPending,
  markNotified,
  findByPaymentLinkId,
};
