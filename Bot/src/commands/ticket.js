const {
  SlashCommandBuilder,
  PermissionFlagsBits,
  ChannelType,
  EmbedBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle,
} = require("discord.js");
const guildConfig = require("../lib/guildConfig");

const CLOSE_ID = "ticket_fechar";
const BTN_PREFIX = "t_ab:";

/** id → rótulo curto para botões */
const TIPOS = [
  { id: "problema", label: "Problema", emoji: "🔧", style: ButtonStyle.Primary },
  { id: "report", label: "Report", emoji: "🐛", style: ButtonStyle.Primary },
  { id: "denuncia", label: "Denúncia", emoji: "⛔", style: ButtonStyle.Danger },
  { id: "compra", label: "Compra", emoji: "🛒", style: ButtonStyle.Success },
  { id: "outro", label: "Outro", emoji: "💬", style: ButtonStyle.Secondary },
];

function labelTipo(id) {
  return TIPOS.find((t) => t.id === id)?.label || id;
}

function sanitizeChannelName(username) {
  const base = String(username || "user")
    .toLowerCase()
    .replace(/[^a-z0-9\-]/g, "-")
    .replace(/-+/g, "-")
    .slice(0, 80);
  return `ticket-${base}`.slice(0, 100);
}

/**
 * @param {import('discord.js').Guild} guild
 * @param {import('discord.js').User} user
 */
async function createTicketChannel(guild, user, tipo, desc, cfg) {
  const category = await guild.channels.fetch(cfg.ticketCategoryId).catch(() => null);
  if (!category || category.type !== ChannelType.GuildCategory) {
    throw new Error("Categoria de tickets inválida.");
  }

  const staffRoleId = cfg.staffRoleId;
  const name = `${sanitizeChannelName(user.username)}-${Date.now().toString(36)}`.slice(0, 100);

  const ticketChannel = await guild.channels.create({
    name,
    type: ChannelType.GuildText,
    parent: category.id,
    topic: `Ticket ${tipo} · ${user.tag} (${user.id})`,
    permissionOverwrites: [
      { id: guild.id, deny: [PermissionFlagsBits.ViewChannel] },
      {
        id: user.id,
        allow: [
          PermissionFlagsBits.ViewChannel,
          PermissionFlagsBits.SendMessages,
          PermissionFlagsBits.ReadMessageHistory,
          PermissionFlagsBits.AttachFiles,
          PermissionFlagsBits.EmbedLinks,
        ],
      },
      {
        id: staffRoleId,
        allow: [
          PermissionFlagsBits.ViewChannel,
          PermissionFlagsBits.SendMessages,
          PermissionFlagsBits.ReadMessageHistory,
          PermissionFlagsBits.AttachFiles,
          PermissionFlagsBits.EmbedLinks,
          PermissionFlagsBits.ManageMessages,
        ],
      },
      {
        id: guild.members.me.id,
        allow: [
          PermissionFlagsBits.ViewChannel,
          PermissionFlagsBits.SendMessages,
          PermissionFlagsBits.ManageChannels,
        ],
      },
    ],
    reason: `Ticket ${tipo} — ${user.tag}`,
  });

  const embed = new EmbedBuilder()
    .setTitle(`Ticket — ${labelTipo(tipo)}`)
    .setDescription(
      `Aberto por ${user}\n\n**Descrição:**\n${desc}\n\nEquipe: <@&${staffRoleId}>`
    )
    .setColor(0x5865f2)
    .setTimestamp();

  const row = new ActionRowBuilder().addComponents(
    new ButtonBuilder()
      .setCustomId(CLOSE_ID)
      .setLabel("Fechar ticket")
      .setStyle(ButtonStyle.Danger)
  );

  await ticketChannel.send({ embeds: [embed], components: [row] });
  return ticketChannel;
}

module.exports = {
  data: new SlashCommandBuilder()
    .setName("ticket")
    .setDescription("Tickets de suporte (painel com botões ou comandos)")
    .addSubcommand((sc) =>
      sc
        .setName("painel")
        .setDescription("Publica neste canal a mensagem com botões para abrir ticket")
    )
    .addSubcommand((sc) =>
      sc
        .setName("abrir")
        .setDescription("Abre ticket pelo comando (alternativa ao painel)")
        .addStringOption((o) =>
          o
            .setName("tipo")
            .setDescription("Tipo de ticket")
            .setRequired(true)
            .addChoices(
              { name: "Problema técnico", value: "problema" },
              { name: "Report / bug", value: "report" },
              { name: "Denúncia", value: "denuncia" },
              { name: "Compra / loja", value: "compra" },
              { name: "Outro", value: "outro" }
            )
        )
        .addStringOption((o) =>
          o
            .setName("descricao")
            .setDescription("Resumo (opcional)")
            .setMaxLength(500)
        )
    )
    .addSubcommand((sc) =>
      sc
        .setName("fechar")
        .setDescription("Fecha o ticket atual (só equipe, dentro do canal do ticket)")
    ),

  async execute(interaction) {
    const sub = interaction.options.getSubcommand();

    if (sub === "painel") {
      if (!interaction.memberPermissions?.has(PermissionFlagsBits.Administrator)) {
        await interaction.reply({
          ephemeral: true,
          content: "❌ Só administradores podem publicar o painel.",
        });
        return;
      }

      const embed = new EmbedBuilder()
        .setTitle("Central de tickets")
        .setDescription(
          "Escolha o **tipo** do ticket abaixo. Vai abrir uma **janela** para você descrever o caso.\n\n" +
            "A equipe responde no canal privado que será criado. Use **Fechar ticket** quando terminar."
        )
        .setColor(0x5865f2)
        .setFooter({ text: "Gear Hub · Suporte" });

      const row = new ActionRowBuilder().addComponents(
        TIPOS.map((t) =>
          new ButtonBuilder()
            .setCustomId(`${BTN_PREFIX}${t.id}`)
            .setLabel(t.label)
            .setEmoji(t.emoji)
            .setStyle(t.style)
        )
      );

      await interaction.reply({ content: "✅ Painel publicado.", ephemeral: true });
      await interaction.channel.send({ embeds: [embed], components: [row] });
      return;
    }

    if (sub === "abrir") {
      const cfg = guildConfig.get(interaction.guildId);
      if (!cfg.ticketCategoryId || !cfg.staffRoleId) {
        await interaction.reply({
          ephemeral: true,
          content:
            "❌ Configure antes: **`/setup tickets`** (categoria + cargo staff).",
        });
        return;
      }

      const tipo = interaction.options.getString("tipo", true);
      const desc = interaction.options.getString("descricao")?.trim() || "*sem descrição*";

      await interaction.deferReply({ ephemeral: true });

      try {
        const ch = await createTicketChannel(interaction.guild, interaction.user, tipo, desc, cfg);
        await interaction.editReply({ content: `✅ Ticket criado: ${ch}` });
      } catch (e) {
        await interaction.editReply({ content: `❌ ${e.message || e}` });
      }
      return;
    }

    if (sub === "fechar") {
      const cfg = guildConfig.get(interaction.guildId);
      const isStaff =
        interaction.member?.permissions?.has(PermissionFlagsBits.Administrator) ||
        (cfg.staffRoleId && interaction.member?.roles?.cache?.has(cfg.staffRoleId));

      const isTicketChannel =
        interaction.channel?.type === ChannelType.GuildText &&
        interaction.channel.name?.startsWith("ticket-");

      if (!isStaff) {
        await interaction.reply({
          ephemeral: true,
          content: "❌ Só a equipe pode usar `/ticket fechar`.",
        });
        return;
      }

      if (!isTicketChannel) {
        await interaction.reply({
          ephemeral: true,
          content: "❌ Use dentro de um canal de ticket.",
        });
        return;
      }

      await interaction.reply({ content: "🔒 Fechando ticket em 3s…" });
      setTimeout(() => interaction.channel.delete("Ticket fechado").catch(() => {}), 3000);
    }
  },

  /** Botão do painel → abre modal */
  async handleOpenButton(interaction) {
    if (!interaction.customId.startsWith(BTN_PREFIX)) {
      return;
    }
    const tipo = interaction.customId.slice(BTN_PREFIX.length);
    if (!TIPOS.some((t) => t.id === tipo)) {
      return;
    }

    const cfg = guildConfig.get(interaction.guildId);
    if (!cfg.ticketCategoryId || !cfg.staffRoleId) {
      await interaction.reply({
        ephemeral: true,
        content: "❌ Tickets ainda não configurados. Um admin deve usar **`/setup tickets`**.",
      });
      return;
    }

    const titulo = `Ticket — ${labelTipo(tipo)}`;

    const modal = new ModalBuilder()
      .setCustomId(`ticket_m:${tipo}`)
      .setTitle(titulo.slice(0, 45));

    const input = new TextInputBuilder()
      .setCustomId("desc")
      .setLabel("O que aconteceu?")
      .setStyle(TextInputStyle.Paragraph)
      .setRequired(false)
      .setMaxLength(1000)
      .setPlaceholder("Descreva com calma. Você pode enviar prints depois no canal do ticket.");

    modal.addComponents(new ActionRowBuilder().addComponents(input));

    await interaction.showModal(modal);
  },

  /** Envio do modal → cria canal */
  async handleModalSubmit(interaction) {
    if (!interaction.customId.startsWith("ticket_m:")) {
      return;
    }
    const tipo = interaction.customId.replace("ticket_m:", "");
    const desc =
      interaction.fields.getTextInputValue("desc")?.trim() || "*sem descrição*";

    const cfg = guildConfig.get(interaction.guildId);
    if (!cfg.ticketCategoryId || !cfg.staffRoleId) {
      await interaction.reply({
        ephemeral: true,
        content: "❌ Configuração de tickets ausente.",
      });
      return;
    }

    await interaction.deferReply({ ephemeral: true });

    try {
      const ch = await createTicketChannel(interaction.guild, interaction.user, tipo, desc, cfg);
      await interaction.editReply({
        content: `✅ Ticket aberto: ${ch}\nSó você e a equipe veem esse canal.`,
      });
    } catch (e) {
      await interaction.editReply({ content: `❌ ${e.message || e}` });
    }
  },

  async handleCloseButton(interaction) {
    if (interaction.customId !== CLOSE_ID) {
      return;
    }
    const cfg = guildConfig.get(interaction.guildId);
    const isStaff =
      interaction.member?.permissions?.has(PermissionFlagsBits.Administrator) ||
      (cfg.staffRoleId && interaction.member?.roles?.cache?.has(cfg.staffRoleId));

    if (!isStaff) {
      await interaction.reply({
        ephemeral: true,
        content: "❌ Só a equipe pode fechar.",
      });
      return;
    }

    await interaction.reply({ content: "🔒 Fechando…" });
    setTimeout(() => interaction.channel.delete("Ticket fechado (botão)").catch(() => {}), 2000);
  },
};
