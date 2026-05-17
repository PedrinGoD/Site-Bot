const { EmbedBuilder } = require("discord.js");
const guildConfig = require("./guildConfig");
const robloxGrants = require("./robloxGrants");
const boosterState = require("./boosterRewardsState");

function normalizeVipTier(raw) {
  const v = String(raw || "").trim().toLowerCase();
  if (v === "bronze") return "Bronze";
  if (v === "gold") return "Gold";
  if (v === "diamante") return "Diamante";
  return "";
}

function parseRewardConfig(cfg) {
  const vipTier = normalizeVipTier(cfg.nitroRewardVipTier);
  const vipDays = Math.max(0, Math.min(3650, parseInt(cfg.nitroRewardVipDays || "0", 10) || 0));
  const money = Math.max(0, parseInt(cfg.nitroRewardMoney || "0", 10) || 0);
  const xp = Math.max(0, parseInt(cfg.nitroRewardXp || "0", 10) || 0);
  return { vipTier, vipDays, money, xp };
}

function hasAnyGameReward(reward) {
  return Boolean((reward.vipTier && reward.vipDays > 0) || reward.money > 0 || reward.xp > 0);
}

function buildBoostKey(member) {
  return String(member.premiumSinceTimestamp || "");
}

function resolveLogChannelId(member, cfg) {
  const envId = String(process.env.NITRO_LOG_CHANNEL_ID || process.env.GEAR_NITRO_LOG_CHANNEL_ID || "").trim();
  return cfg.nitroLogChannelId || envId || cfg.salesLogChannelId || "";
}

async function sendNitroLog(member, cfg, title, description, color = 0xf47fff) {
  const channelId = resolveLogChannelId(member, cfg);
  if (!channelId) return;
  try {
    const ch = await member.client.channels.fetch(channelId);
    if (!ch || !ch.isTextBased()) return;
    const embed = new EmbedBuilder()
      .setColor(color)
      .setTitle(title)
      .setDescription(description.slice(0, 4000))
      .setTimestamp();
    await ch.send({
      content: `<@${member.id}>`,
      embeds: [embed],
      allowedMentions: { users: [member.id] },
    });
  } catch (e) {
    console.error("[nitro] erro ao enviar log:", e);
  }
}

async function ensureBoosterRole(member, cfg) {
  const roleId = String(cfg.boosterRoleId || "").trim();
  if (!roleId) return { ok: true, skipped: true };
  if (member.roles.cache.has(roleId)) return { ok: true, already: true };
  try {
    await member.roles.add(roleId, "Membro impulsionou o servidor (Nitro)");
    return { ok: true, applied: true };
  } catch (e) {
    console.error("[nitro] erro ao aplicar cargo booster:", e);
    return { ok: false, error: String(e.message || e) };
  }
}

async function tryDm(member, text) {
  try {
    await member.send(text.slice(0, 1900));
  } catch {
    // ignora DM bloqueada
  }
}

function queueRewardGrants({ guildId, discordUserId, robloxUserId, reward, boostKey }) {
  const refs = [];

  if (reward.vipTier && reward.vipDays > 0) {
    const ref = robloxGrants.queueGrantAfterPayment({
      stripeSessionId: `nitro:${guildId}:${discordUserId}:${boostKey}:vip`,
      robloxUserId,
      grantType: "vip",
      grantTier: reward.vipTier,
      grantDays: reward.vipDays,
    });
    if (ref) refs.push(ref);
  }

  if (reward.money > 0 || reward.xp > 0) {
    if (reward.money > 0 && reward.xp > 0) {
      const ref = robloxGrants.queueGrantAfterPayment({
        stripeSessionId: `nitro:${guildId}:${discordUserId}:${boostKey}:economy`,
        robloxUserId,
        grantType: "economy",
        grantMoneyAmount: reward.money,
        grantXpAmount: reward.xp,
      });
      if (ref) refs.push(ref);
    } else if (reward.money > 0) {
      const ref = robloxGrants.queueGrantAfterPayment({
        stripeSessionId: `nitro:${guildId}:${discordUserId}:${boostKey}:money`,
        robloxUserId,
        grantType: "currency",
        grantMoneyAmount: reward.money,
      });
      if (ref) refs.push(ref);
    } else if (reward.xp > 0) {
      const ref = robloxGrants.queueGrantAfterPayment({
        stripeSessionId: `nitro:${guildId}:${discordUserId}:${boostKey}:xp`,
        robloxUserId,
        grantType: "xp",
        grantXpAmount: reward.xp,
      });
      if (ref) refs.push(ref);
    }
  }

  return refs;
}

function rewardToText(reward) {
  const parts = [];
  if (reward.vipTier && reward.vipDays > 0) {
    parts.push(`VIP ${reward.vipTier} por ${reward.vipDays} dia(s)`);
  }
  if (reward.money > 0) {
    parts.push(`$${reward.money} no jogo`);
  }
  if (reward.xp > 0) {
    parts.push(`+${reward.xp} XP`);
  }
  return parts.length ? parts.join(" + ") : "Sem recompensa in-game configurada";
}

async function processNitroBoostStart(member, reason = "evento") {
  if (!member || !member.guild || member.user?.bot) return { ok: false, reason: "invalid_member" };
  if (!member.premiumSinceTimestamp) return { ok: false, reason: "not_boosting" };

  const guildId = member.guild.id;
  const discordUserId = member.id;
  const cfg = guildConfig.get(guildId);
  const boostKey = buildBoostKey(member);
  const reward = parseRewardConfig(cfg);

  await ensureBoosterRole(member, cfg);

  if (boosterState.hasRewardForBoost(guildId, discordUserId, boostKey)) {
    return { ok: true, duplicate: true };
  }

  if (!hasAnyGameReward(reward)) {
    boosterState.markRewardedForBoost(guildId, discordUserId, boostKey, []);
    await sendNitroLog(
      member,
      cfg,
      "🚀 Novo booster detectado",
      `<@${discordUserId}> impulsionou o servidor.\nNenhuma recompensa in-game configurada.\nOrigem: ${reason}.`
    );
    return { ok: true, noRewardConfigured: true };
  }

  const robloxUserId = boosterState.getLinkedRobloxUserId(guildId, discordUserId);
  if (!robloxUserId) {
    await sendNitroLog(
      member,
      cfg,
      "⚠️ Booster sem vínculo Roblox",
      `<@${discordUserId}> impulsionou o servidor, mas não possui Roblox ID vinculado.\nUse \`/booster vincular\` para liberar: ${rewardToText(reward)}.`
    );
    await tryDm(
      member,
      `Obrigado por impulsionar o servidor! Para receber sua recompensa no jogo (${rewardToText(reward)}), use no servidor:\n` +
        "`/booster vincular` e informe seu usuário/ID Roblox."
    );
    return { ok: true, missingLink: true };
  }

  const refs = queueRewardGrants({ guildId, discordUserId, robloxUserId, reward, boostKey });
  if (!refs.length) {
    return { ok: false, reason: "queue_failed" };
  }

  boosterState.markRewardedForBoost(guildId, discordUserId, boostKey, refs);
  await sendNitroLog(
    member,
    cfg,
    "🎁 Recompensa Nitro enfileirada",
    `<@${discordUserId}> impulsionou o servidor.\nRoblox ID: \`${robloxUserId}\`\nRecompensa: ${rewardToText(reward)}.`
  );
  await tryDm(member, `Sua recompensa de Nitro foi enviada para o jogo: ${rewardToText(reward)}.`);
  return { ok: true, rewarded: true, refs };
}

module.exports = {
  normalizeVipTier,
  parseRewardConfig,
  rewardToText,
  processNitroBoostStart,
};
