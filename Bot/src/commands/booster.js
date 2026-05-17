const { SlashCommandBuilder, PermissionFlagsBits } = require("discord.js");
const boosterState = require("../lib/boosterRewardsState");
const guildConfig = require("../lib/guildConfig");
const { resolveRobloxUserId } = require("../lib/resolveRobloxUser");
const {
  parseRewardConfig,
  rewardToText,
  processNitroBoostStart,
} = require("../lib/boosterRewards");

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
    .addSubcommand((sc) => sc.setName("status").setDescription("Mostra seu vínculo e status de recompensa"))
    .addSubcommand((sc) =>
      sc
        .setName("forcar_resgate")
        .setDescription("STAFF: força reprocessamento do resgate de um booster")
        .addUserOption((o) =>
          o
            .setName("usuario")
            .setDescription("Usuário que está impulsionando e precisa reprocessar")
            .setRequired(true)
        )
    ),

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
      return;
    }

    if (sub === "forcar_resgate") {
      if (!interaction.memberPermissions?.has(PermissionFlagsBits.Administrator)) {
        await interaction.reply({
          ephemeral: true,
          content: "❌ Apenas administradores podem usar este comando.",
        });
        return;
      }

      await interaction.deferReply({ ephemeral: true });
      const targetUser = interaction.options.getUser("usuario", true);
      const targetMember = await interaction.guild.members.fetch(targetUser.id).catch(() => null);
      if (!targetMember) {
        await interaction.editReply("❌ Não consegui encontrar este usuário no servidor.");
        return;
      }
      if (!targetMember.premiumSinceTimestamp) {
        await interaction.editReply("❌ Este usuário não está impulsionando o servidor no momento.");
        return;
      }

      const linked = boosterState.getLinkedRobloxUserId(gid, targetUser.id);
      if (!linked) {
        await interaction.editReply("❌ Este usuário ainda não vinculou o Roblox.");
        return;
      }

      boosterState.clearRewardMark(gid, targetUser.id);
      const result = await processNitroBoostStart(
        targetMember,
        `forcado por ${interaction.user.id}`,
        { force: true }
      );
      if (result.rewarded) {
        await interaction.editReply(
          `✅ Reprocessado com sucesso para <@${targetUser.id}>.\nRoblox: \`${linked}\`.\nRecompensa: ${rewardToText(
            reward
          )}.`
        );
        return;
      }
      if (result.duplicate) {
        await interaction.editReply(
          "⚠️ Ainda retornou como duplicado. Se continuar, me avise para eu adicionar um bypass administrativo direto na fila."
        );
        return;
      }
      await interaction.editReply(
        `❌ Não consegui reprocessar agora (${result.reason || "erro_desconhecido"}). Tente novamente em alguns segundos.`
      );
    }
  },
};
