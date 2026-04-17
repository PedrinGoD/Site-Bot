const {
  SlashCommandBuilder,
  PermissionFlagsBits,
  ChannelType,
  EmbedBuilder,
} = require("discord.js");
const guildConfig = require("../lib/guildConfig");

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
      guildConfig.update(gid, { nitroLogChannelId: ch.id });
      await interaction.reply({
        ephemeral: true,
        content: `✅ Log Nitro/eventos: ${ch}.`,
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

    if (sub === "ver") {
      const c = guildConfig.get(gid);
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
            value: c.nitroLogChannelId
              ? `<#${c.nitroLogChannelId}>`
              : "Não configurado (`/setup nitro`)",
          },
          {
            name: "Log detalhado (staff / Stripe)",
            value: c.fullTransactionLogChannelId
              ? `<#${c.fullTransactionLogChannelId}>`
              : "Não configurado (`/setup log_detalhado`) — opcional",
          }
        );
      await interaction.reply({ ephemeral: true, embeds: [embed] });
    }
  },
};
