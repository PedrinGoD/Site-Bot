const {
  SlashCommandBuilder,
  PermissionFlagsBits,
  ChannelType,
  EmbedBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
} = require("discord.js");
const guildConfig = require("../lib/guildConfig");
const { normalizeVipTier, parseRewardConfig, rewardToText } = require("../lib/boosterRewards");

module.exports = {
  data: new SlashCommandBuilder()
    .setName("setup")
    .setDescription("Configura tickets, log de vendas e log de Nitro neste servidor")
    .addSubcommand((sc) =>
      sc
        .setName("tickets")
        .setDescription("Categoria onde abrir canais de ticket + cargo da equipe")
        .addChannelOption((o) =>
          o
            .setName("categoria")
            .setDescription("Arraste a categoria de tickets")
            .addChannelTypes(ChannelType.GuildCategory)
            .setRequired(true)
        )
        .addRoleOption((o) =>
          o
            .setName("staff")
            .setDescription("Cargo que pode ver e responder tickets")
            .setRequired(true)
        )
    )
    .addSubcommand((sc) =>
      sc
        .setName("vendas")
        .setDescription("Canal onde o site envia log de compras")
        .addChannelOption((o) =>
          o
            .setName("canal")
            .setDescription("Canal de texto para logs de venda")
            .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement)
            .setRequired(true)
        )
    )
    .addSubcommand((sc) =>
      sc
        .setName("nitro")
        .setDescription("Canal para logs de Nitro / presentes (opcional)")
        .addChannelOption((o) =>
          o
            .setName("canal")
            .setDescription("Canal de texto")
            .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement)
            .setRequired(true)
        )
        .addRoleOption((o) =>
          o
            .setName("cargo_booster")
            .setDescription("Cargo personalizado de Booster (opcional)")
            .setRequired(false)
        )
        .addStringOption((o) =>
          o
            .setName("vip")
            .setDescription("Tier VIP da recompensa Nitro (opcional)")
            .setRequired(false)
            .addChoices(
              { name: "Bronze", value: "Bronze" },
              { name: "Gold", value: "Gold" },
              { name: "Diamante", value: "Diamante" },
              { name: "Sem VIP", value: "none" }
            )
        )
        .addIntegerOption((o) =>
          o
            .setName("dias_vip")
            .setDescription("Dias de VIP por boost (opcional)")
            .setRequired(false)
            .setMinValue(0)
            .setMaxValue(3650)
        )
        .addIntegerOption((o) =>
          o
            .setName("dinheiro")
            .setDescription("Dinheiro in-game por boost (opcional)")
            .setRequired(false)
            .setMinValue(0)
            .setMaxValue(2000000000)
        )
        .addIntegerOption((o) =>
          o
            .setName("xp")
            .setDescription("XP por boost (opcional)")
            .setRequired(false)
            .setMinValue(0)
            .setMaxValue(2000000000)
        )
    )
    .addSubcommand((sc) =>
      sc
        .setName("log_detalhado")
        .setDescription(
          "Canal privado (staff/CEO): transação Stripe completa — bloqueie o acesso no Discord"
        )
        .addChannelOption((o) =>
          o
            .setName("canal")
            .setDescription("Canal de texto só para a equipa")
            .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement)
            .setRequired(true)
        )
    )
    .addSubcommand((sc) =>
      sc
        .setName("verificacao")
        .setDescription("Configura canal e cargos da verificação (Visitante -> Jogador)")
        .addChannelOption((o) =>
          o
            .setName("canal")
            .setDescription("Canal onde ficará a mensagem de verificação")
            .addChannelTypes(ChannelType.GuildText, ChannelType.GuildAnnouncement)
            .setRequired(true)
        )
        .addRoleOption((o) =>
          o
            .setName("visitante")
            .setDescription("Cargo inicial aplicado quando o usuário entra")
            .setRequired(true)
        )
        .addRoleOption((o) =>
          o
            .setName("jogador")
            .setDescription("Cargo após concluir verificação")
            .setRequired(true)
        )
    )
    .addSubcommand((sc) =>
      sc.setName("ver").setDescription("Mostra o que já foi configurado aqui")
    )
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator),

  async execute(interaction) {
    const sub = interaction.options.getSubcommand();
    const gid = interaction.guildId;

    if (sub === "tickets") {
      const cat = interaction.options.getChannel("categoria", true);
      const staff = interaction.options.getRole("staff", true);
      guildConfig.update(gid, {
        ticketCategoryId: cat.id,
        staffRoleId: staff.id,
      });
      await interaction.reply({
        ephemeral: true,
        content: `✅ Tickets: categoria **${cat.name}**, equipe **${staff.name}**.`,
      });
      return;
    }

    if (sub === "vendas") {
      const ch = interaction.options.getChannel("canal", true);
      guildConfig.update(gid, { salesLogChannelId: ch.id });
      await interaction.reply({
        ephemeral: true,
        content: `✅ Log de vendas: ${ch}. O site deve chamar o webhook HTTP (veja .env.example).`,
      });
      return;
    }

    if (sub === "nitro") {
      const ch = interaction.options.getChannel("canal", true);
      const patch = { nitroLogChannelId: ch.id };

      const role = interaction.options.getRole("cargo_booster");
      if (role) patch.boosterRoleId = role.id;

      const vipOpt = interaction.options.getString("vip");
      if (vipOpt != null) {
        patch.nitroRewardVipTier = vipOpt === "none" ? "" : normalizeVipTier(vipOpt);
      }

      const vipDays = interaction.options.getInteger("dias_vip");
      if (vipDays != null) patch.nitroRewardVipDays = vipDays;

      const money = interaction.options.getInteger("dinheiro");
      if (money != null) patch.nitroRewardMoney = money;

      const xp = interaction.options.getInteger("xp");
      if (xp != null) patch.nitroRewardXp = xp;

      guildConfig.update(gid, patch);
      const updatedCfg = guildConfig.get(gid);
      const reward = parseRewardConfig(updatedCfg);
      const boosterRoleLine = updatedCfg.boosterRoleId
        ? `\n• Cargo Booster: <@&${updatedCfg.boosterRoleId}>`
        : "\n• Cargo Booster: não configurado";
      await interaction.reply({
        ephemeral: true,
        content:
          `✅ Log Nitro/eventos: ${ch}.${boosterRoleLine}\n` +
          `• Recompensa Nitro: ${rewardToText(reward)}\n` +
          "Use `/booster vincular` para os jogadores vincularem o Roblox.",
      });
      return;
    }

    if (sub === "log_detalhado") {
      const ch = interaction.options.getChannel("canal", true);
      guildConfig.update(gid, { fullTransactionLogChannelId: ch.id });
      await interaction.reply({
        ephemeral: true,
        content:
          `✅ Log detalhado (staff): ${ch}.\n` +
          `**Importante:** no Discord, edita as permissões do canal — só CEO/staff veem mensagens. ` +
          `O Stripe **não** envia o nome do banco em todos os métodos (cartão costuma ser bandeira + últimos 4 + país). ` +
          `Opcional no Render: \`FULL_TRANSACTION_LOG_CHANNEL_ID\` (este servidor usa o canal do /setup).`,
      });
      return;
    }

    if (sub === "verificacao") {
      await interaction.deferReply({ ephemeral: true });

      const ch = interaction.options.getChannel("canal", true);
      const visitante = interaction.options.getRole("visitante", true);
      const jogador = interaction.options.getRole("jogador", true);

      const row = new ActionRowBuilder().addComponents(
        new ButtonBuilder()
          .setCustomId("verify_accept")
          .setStyle(ButtonStyle.Success)
          .setEmoji("✅")
          .setLabel("Verificar acesso")
      );

      const msg = await ch.send({
        content:
          "## Verificação de acesso\n" +
          "Clique no botão abaixo, informe como deseja aparecer no servidor e conclua sua verificação para liberar os canais.",
        components: [row],
      });

      guildConfig.update(gid, {
        verificationChannelId: ch.id,
        visitorRoleId: visitante.id,
        playerRoleId: jogador.id,
        verificationMessageId: msg.id,
      });

      await interaction.editReply({
        content:
          `✅ Verificação configurada em ${ch}.\n` +
          `• Cargo inicial: <@&${visitante.id}>\n` +
          `• Cargo liberado: <@&${jogador.id}>`,
      });
      return;
    }

    if (sub === "ver") {
      const c = guildConfig.get(gid);
      const nitroReward = parseRewardConfig(c);
      const embed = new EmbedBuilder()
        .setTitle("Configuração deste servidor")
        .addFields(
          {
            name: "Tickets",
            value: c.ticketCategoryId
              ? `Categoria: <#${c.ticketCategoryId}>\nStaff: <@&${c.staffRoleId}>`
              : "Não configurado (`/setup tickets`)",
          },
          {
            name: "Vendas (site)",
            value: c.salesLogChannelId
              ? `<#${c.salesLogChannelId}>`
              : "Não configurado (`/setup vendas`)",
          },
          {
            name: "Nitro / extras",
            value:
              (c.nitroLogChannelId ? `Canal: <#${c.nitroLogChannelId}>` : "Canal: não configurado") +
              `\nCargo Booster: ${c.boosterRoleId ? `<@&${c.boosterRoleId}>` : "não configurado"}` +
              `\nRecompensa: ${rewardToText(nitroReward)}`,
          },
          {
            name: "Log detalhado (staff / Stripe)",
            value: c.fullTransactionLogChannelId
              ? `<#${c.fullTransactionLogChannelId}>`
              : "Não configurado (`/setup log_detalhado`) — opcional",
          },
          {
            name: "Verificação",
            value:
              c.verificationChannelId && c.visitorRoleId && c.playerRoleId
                ? `Canal: <#${c.verificationChannelId}>\nVisitante: <@&${c.visitorRoleId}>\nJogador: <@&${c.playerRoleId}>`
                : "Não configurado (`/setup verificacao`)",
          }
        );
      await interaction.reply({ ephemeral: true, embeds: [embed] });
    }
  },
};
