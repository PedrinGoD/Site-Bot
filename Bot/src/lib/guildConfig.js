const fs = require("fs");
const path = require("path");

const DATA_DIR = path.join(__dirname, "..", "..", "data");
const FILE = path.join(DATA_DIR, "guildConfig.json");

function ensureFile() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  if (!fs.existsSync(FILE)) {
    fs.writeFileSync(FILE, "{}", "utf8");
  }
}

/**
 * @returns {Record<string, { ticketCategoryId?: string, staffRoleId?: string, salesLogChannelId?: string, nitroLogChannelId?: string }>}
 */
function loadAll() {
  ensureFile();
  try {
    return JSON.parse(fs.readFileSync(FILE, "utf8"));
  } catch {
    return {};
  }
}

/**
 * @param {string} guildId
 */
function get(guildId) {
  const all = loadAll();
  return all[guildId] || {};
}

/**
 * @param {string} guildId
 * @param {object} patch
 */
function update(guildId, patch) {
  const all = loadAll();
  all[guildId] = { ...all[guildId], ...patch };
  fs.writeFileSync(FILE, JSON.stringify(all, null, 2), "utf8");
}

module.exports = { get, update, loadAll, DATA_DIR };
