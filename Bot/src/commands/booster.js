const { SlashCommandBuilder } = require("discord.js");
const boosterState = require("../lib/boosterRewardsState");
const guildConfig = require("../lib/guildConfig");
const {
  parseRewardConfig,
  rewardToText,
  processNitroBoostStart,
} = require("../lib/boosterRewards");

async function resolveRobloxUserId(input) {
  const raw = String(input || "").trim();
  if (!raw) return { error: "Informe um usuário ou ID Roblox." };
  if (/^\d{1,20}$/.test(raw)) {
    return { userId: raw };
  }
  if (!/^[a-zA-Z0-9_]{3,20}$/.test(raw)) {
    return { error: "Nome Roblox inválido. Use apenas letras, números e _." };
  }
  try {
    const r = await fetch("https://users.roblox.com/v1/usernames/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ usernames: [raw], excludeBannedUsers: true }),
      signal: AbortSignal.timeout(8000),
    });
    if (!r.ok) return { error: `Falha Roblox API (${r.status}).` };
    const j = await r.json();
    const row = j && Array.isArray(j.data) ? j.data[0] : null;
    if (!row || !row.id) return { error: "Usuário Roblox não encontrado." };
    return { userId: String(row.id), username: String(row.name || raw) };
  } catch (e) {
    return { error: `Falha ao consultar Roblox: ${String(e.message || e)}` };
  }
}

module.exports = {
  data: new SlashCommandBuilder()
    .setName("booster")
    .setDescription("Vincular Roblox e resgatar recompensa de Nitro Booster")
    .addSubcommand((sc) =>
      sc
        .setName("vincular")
        .setDescription("Vincula seu Discord ao Roblox para receber recompensa Nitro")
        .addStringOption((o) =>
          o
            .setName("usuario_ou_id")
            .setDescription("Seu @usuario ou ID Roblox numérico")
            .setRequired(true)
        )
    )
    .addSubcommand((sc) => sc.setName("resgatar").setDescription("Resgata sua recompensa atual de Nitro"))
    .addSubcommand((sc) => sc.setName("status").setDescription("Mostra seu vínculo e status de recompensa")),

  async execute(interaction) {
    const sub = interaction.options.getSubcommand();
    const gid = interaction.guildId;
    const uid = interaction.user.id;
    const cfg = guildConfig.get(gid);
    const reward = parseRewardConfig(cfg);

    if (sub === "vincular") {
      await interaction.deferReply({ ephemeral: true });
      const input = interaction.options.getString("usuario_ou_id", true);
      const resolved = await resolveRobloxUserId(input);
      if (resolved.error) {
        await interaction.editReply(`❌ ${resolved.error}`);
        return;
      }
      boosterState.setLinkedRobloxUserId(gid, uid, resolved.userId);
      const namePart = resolved.username ? ` (@${resolved.username})` : "";
      await interaction.editReply(
        `✅ Roblox vinculado com sucesso: \`${resolved.userId}\`${namePart}.\n` +
          `Recompensa Nitro configurada: ${rewardToText(reward)}.\n` +
          "Se você já impulsiona o servidor, use `/booster resgatar` agora."
      );
      return;
    }

    if (sub === "resgatar") {
      await interaction.deferReply({ ephemeral: true });
      const member = await interaction.guild.members.fetch(uid);
      if (!member.premiumSinceTimestamp) {
        await interaction.editReply("❌ Você não está impulsionando o servidor no momento.");
        return;
      }
      const linked = boosterState.getLinkedRobloxUserId(gid, uid);
      if (!linked) {
        await interaction.editReply(
          "❌ Você ainda não vinculou seu Roblox. Use `/booster vincular usuario_ou_id:<seu usuario>`."
        );
        return;
      }

      const result = await processNitroBoostStart(member, "comando /booster resgatar");
      if (result.duplicate) {
        await interaction.editReply(
          `✅ Sua recompensa deste impulso já foi registrada anteriormente.\nRecompensa atual: ${rewardToText(
            reward
          )}.`
        );
        return;
      }
      if (result.rewarded) {
        await interaction.editReply(
          `✅ Recompensa enviada para a fila do jogo com sucesso.\nRecompensa: ${rewardToText(reward)}.`
        );
        return;
      }
      if (result.noRewardConfigured) {
        await interaction.editReply("⚠️ O servidor ainda não configurou recompensa Nitro in-game.");
        return;
      }
      if (result.missingLink) {
        await interaction.editReply("❌ Roblox não vinculado. Use `/booster vincular`.");
        return;
      }
      await interaction.editReply("❌ Não consegui resgatar agora. Tente novamente em alguns segundos.");
      return;
    }

    if (sub === "status") {
      const linked = boosterState.getLinkedRobloxUserId(gid, uid);
      const member = await interaction.guild.members.fetch(uid);
      const isBoosting = Boolean(member.premiumSinceTimestamp);
      await interaction.reply({
        ephemeral: true,
        content:
          `💠 Impulsionando agora: **${isBoosting ? "Sim" : "Não"}**\n` +
          `🎮 Roblox vinculado: ${linked ? `\`${linked}\`` : "Não"}\n` +
          `🎁 Recompensa configurada: ${rewardToText(reward)}`,
      });
    }
  },
};
