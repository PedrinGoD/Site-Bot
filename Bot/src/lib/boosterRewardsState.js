const fs = require("fs");
const path = require("path");

const DATA_DIR = path.join(__dirname, "..", "..", "data");
const FILE = path.join(DATA_DIR, "boosterRewardsState.json");

function ensureFile() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  if (!fs.existsSync(FILE)) {
    fs.writeFileSync(FILE, "{}", "utf8");
  }
}

function loadAll() {
  ensureFile();
  try {
    return JSON.parse(fs.readFileSync(FILE, "utf8"));
  } catch {
    return {};
  }
}

function saveAll(data) {
  ensureFile();
  fs.writeFileSync(FILE, JSON.stringify(data, null, 2), "utf8");
}

function ensureGuildAndUser(data, guildId, discordUserId) {
  if (!data[guildId]) data[guildId] = {};
  if (!data[guildId][discordUserId]) {
    data[guildId][discordUserId] = {};
  }
  return data[guildId][discordUserId];
}

function getUserState(guildId, discordUserId) {
  const all = loadAll();
  return (all[guildId] && all[guildId][discordUserId]) || {};
}

function setLinkedRobloxUserId(guildId, discordUserId, robloxUserId) {
  const all = loadAll();
  const row = ensureGuildAndUser(all, guildId, discordUserId);
  row.robloxUserId = String(robloxUserId);
  row.updatedAt = Date.now();
  saveAll(all);
}

function unlinkRobloxUserId(guildId, discordUserId) {
  const all = loadAll();
  const row = ensureGuildAndUser(all, guildId, discordUserId);
  delete row.robloxUserId;
  row.updatedAt = Date.now();
  saveAll(all);
}

function getLinkedRobloxUserId(guildId, discordUserId) {
  const row = getUserState(guildId, discordUserId);
  const id = String(row.robloxUserId || "").trim();
  return /^\d{1,20}$/.test(id) ? id : "";
}

function hasRewardForBoost(guildId, discordUserId, boostKey) {
  if (!boostKey) return false;
  const row = getUserState(guildId, discordUserId);
  const sameBoost = String(row.lastRewardBoostKey || "") === String(boostKey);
  if (!sameBoost) return false;
  const refs = Array.isArray(row.lastGrantRefs) ? row.lastGrantRefs : [];
  return refs.length > 0;
}

function markRewardedForBoost(guildId, discordUserId, boostKey, grantRefs) {
  if (!boostKey) return;
  const all = loadAll();
  const row = ensureGuildAndUser(all, guildId, discordUserId);
  row.lastRewardBoostKey = String(boostKey);
  row.lastRewardAt = Date.now();
  if (Array.isArray(grantRefs) && grantRefs.length) {
    row.lastGrantRefs = grantRefs.slice(0, 10).map((x) => String(x));
  }
  saveAll(all);
}

function clearRewardMark(guildId, discordUserId) {
  const all = loadAll();
  const row = ensureGuildAndUser(all, guildId, discordUserId);
  delete row.lastRewardBoostKey;
  delete row.lastRewardAt;
  delete row.lastGrantRefs;
  row.updatedAt = Date.now();
  saveAll(all);
}

module.exports = {
  getUserState,
  setLinkedRobloxUserId,
  unlinkRobloxUserId,
  getLinkedRobloxUserId,
  hasRewardForBoost,
  markRewardedForBoost,
  clearRewardMark,
};
