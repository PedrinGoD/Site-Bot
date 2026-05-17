require("dotenv").config();
const fs = require("fs");
const path = require("path");
const {
  Client,
  Collection,
  GatewayIntentBits,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle,
  ActionRowBuilder,
  PermissionFlagsBits,
} = require("discord.js");
const { startHttpServer } = require("./server/http");
const guildConfig = require("./lib/guildConfig");
const { processNitroBoostStart } = require("./lib/boosterRewards");
const boosterState = require("./lib/boosterRewardsState");
const { resolveRobloxUserId } = require("./lib/resolveRobloxUser");

const token = process.env.DISCORD_TOKEN;
if (!token) {
  console.error("Defina DISCORD_TOKEN no .env");
  process.exit(1);
}

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMembers],
});

/** @type {Collection<string, object>} */
client.commands = new Collection();

const commandsPath = path.join(__dirname, "commands");
for (const file of fs.readdirSync(commandsPath).filter((f) => f.endsWith(".js"))) {
  const cmd = require(path.join(commandsPath, file));
  client.commands.set(cmd.data.name, cmd);
}

client.once("clientReady", () => {
  console.log(`Logado como ${client.user.tag}`);
  if (!process.env.WEBHOOK_SECRET) {
    console.warn(
      "[aviso] WEBHOOK_SECRET vazio — POST /webhooks/venda (API do bot, não é o Stripe) responderá 401. " +
        "Defina WEBHOOK_SECRET no .env (string à tua escolha). Isto é diferente de STRIPE_WEBHOOK_SECRET (whsec_)."
    );
  }
  startHttpServer(client);
});

client.on("interactionCreate", async (interaction) => {
  try {
    if (interaction.isAutocomplete()) {
      const cmd = client.commands.get(interaction.commandName);
      if (cmd?.autocomplete) {
        await cmd.autocomplete(interaction);
      }
      return;
    }

    if (interaction.isModalSubmit()) {
      if (interaction.customId === "booster_link_modal") {
        if (!interaction.guildId) {
          await interaction.reply({
            ephemeral: true,
            content: "❌ Este resgate precisa ser feito dentro do servidor.",
          });
          return;
        }

        await interaction.deferReply({ ephemeral: true });
        const raw = String(interaction.fields.getTextInputValue("booster_roblox") || "");
        const resolved = await resolveRobloxUserId(raw);
        if (resolved.error) {
          await interaction.editReply(`❌ ${resolved.error}`);
          return;
        }

        boosterState.setLinkedRobloxUserId(interaction.guildId, interaction.user.id, resolved.userId);
        const member = await interaction.guild.members.fetch(interaction.user.id);
        const result = await processNitroBoostStart(member, "modal booster_link");

        if (result.rewarded) {
          await interaction.editReply(
            `✅ Roblox vinculado (\`${resolved.userId}\`) e recompensa enfileirada com sucesso!`
          );
        } else if (result.duplicate) {
          await interaction.editReply(
            `✅ Roblox vinculado (\`${resolved.userId}\`). Sua recompensa deste impulso já havia sido registrada.`
          );
        } else if (result.not_boosting) {
          await interaction.editReply(
            `✅ Roblox vinculado (\`${resolved.userId}\`), mas você não está impulsionando no momento.`
          );
        } else {
          await interaction.editReply(
            `✅ Roblox vinculado (\`${resolved.userId}\`). Se necessário, use \`/booster resgatar\`.`
          );
        }
        return;
      }

      if (interaction.customId === "verify_modal") {
        const cfg = guildConfig.get(interaction.guildId);
        if (!cfg.visitorRoleId || !cfg.playerRoleId) {
          await interaction.reply({
            ephemeral: true,
            content: "❌ Verificação não configurada. Um admin deve usar `/setup verificacao`.",
          });
          return;
        }

        const rawNick = String(interaction.fields.getTextInputValue("verify_nickname") || "");
        const desiredNick = rawNick
          .replace(/\r?\n/g, " ")
          .replace(/\s+/g, " ")
          .trim()
          .slice(0, 32);

        if (desiredNick.length < 2) {
          await interaction.reply({
            ephemeral: true,
            content: "❌ Escolha um nome com pelo menos 2 caracteres.",
          });
          return;
        }

        await interaction.deferReply({ ephemeral: true });

        const member = await interaction.guild.members.fetch(interaction.user.id);
        if (!member || !member.roles) {
          await interaction.editReply("❌ Não consegui identificar seu membro no servidor.");
          return;
        }

        let nickStatus = "✅ Nome atualizado.";
        try {
          const me = interaction.guild.members.me;
          const canManageNicks = Boolean(
            me?.permissions?.has(PermissionFlagsBits.ManageNicknames) && member.manageable
          );
          if (canManageNicks) {
            await member.setNickname(desiredNick, "Verificação concluída pelo usuário");
          } else {
            nickStatus =
              "⚠️ Não consegui alterar seu nome automaticamente (permissão/hierarquia).";
          }
        } catch (e) {
          console.error("[verify] erro ao alterar nickname:", e);
          nickStatus =
            "⚠️ Não consegui alterar seu nome automaticamente (permissão/hierarquia).";
        }

        try {
          if (!member.roles.cache.has(cfg.playerRoleId)) {
            await member.roles.add(cfg.playerRoleId, "Verificação concluída");
          }
          if (member.roles.cache.has(cfg.visitorRoleId)) {
            await member.roles.remove(cfg.visitorRoleId, "Verificação concluída");
          }
        } catch (e) {
          console.error("[verify] erro ao trocar cargos:", e);
          await interaction.editReply(
            "❌ Não consegui atualizar seus cargos. Verifique se o cargo do bot está acima dos cargos de Visitante/Jogador."
          );
          return;
        }

        await interaction.editReply(
          `✅ Verificação concluída! Seu acesso foi liberado.\n${nickStatus}`
        );
        return;
      }

      const ticket = client.commands.get("ticket");
      if (interaction.customId.startsWith("ticket_m:") && ticket?.handleModalSubmit) {
        await ticket.handleModalSubmit(interaction);
      }
      return;
    }

    if (interaction.isButton()) {
      if (interaction.customId === "booster_link") {
        const modal = new ModalBuilder()
          .setCustomId("booster_link_modal")
          .setTitle("Resgatar recompensa Nitro");
        const robloxInput = new TextInputBuilder()
          .setCustomId("booster_roblox")
          .setLabel("Seu usuário ou ID Roblox")
          .setStyle(TextInputStyle.Short)
          .setMinLength(3)
          .setMaxLength(24)
          .setRequired(true)
          .setPlaceholder("Ex.: Cheech ou 123456789");
        const row = new ActionRowBuilder().addComponents(robloxInput);
        modal.addComponents(row);
        await interaction.showModal(modal);
        return;
      }

      if (interaction.customId === "verify_accept") {
        const modal = new ModalBuilder()
          .setCustomId("verify_modal")
          .setTitle("Verificação de acesso");
        const nicknameInput = new TextInputBuilder()
          .setCustomId("verify_nickname")
          .setLabel("Como você quer ser chamado no servidor?")
          .setStyle(TextInputStyle.Short)
          .setMinLength(2)
          .setMaxLength(32)
          .setRequired(true)
          .setPlaceholder("Ex.: Cheech");
        const row = new ActionRowBuilder().addComponents(nicknameInput);
        modal.addComponents(row);
        await interaction.showModal(modal);
        return;
      }

      const ticket = client.commands.get("ticket");
      if (interaction.customId.startsWith("t_ab:") && ticket?.handleOpenButton) {
        await ticket.handleOpenButton(interaction);
      } else if (interaction.customId === "ticket_fechar" && ticket?.handleCloseButton) {
        await ticket.handleCloseButton(interaction);
      }
      return;
    }

    if (!interaction.isChatInputCommand()) {
      return;
    }

    const cmd = client.commands.get(interaction.commandName);
    if (!cmd) {
      return;
    }

    await cmd.execute(interaction);
  } catch (e) {
    console.error(e);
    const msg = { content: "Erro ao processar.", ephemeral: true };
    if (interaction.deferred || interaction.replied) {
      await interaction.followUp(msg).catch(() => {});
    } else {
      await interaction.reply(msg).catch(() => {});
    }
  }
});

client.on("guildMemberAdd", async (member) => {
  try {
    const cfg = guildConfig.get(member.guild.id);
    if (!cfg.visitorRoleId) return;
    if (member.user.bot) return;

    if (!member.roles.cache.has(cfg.visitorRoleId)) {
      await member.roles.add(cfg.visitorRoleId, "Cargo inicial de visitante");
    }
  } catch (e) {
    console.error("[verify] erro ao aplicar cargo visitante:", e);
  }
});

client.on("guildMemberUpdate", async (oldMember, newMember) => {
  try {
    if (newMember.user?.bot) return;
    const startedBoost =
      !oldMember.premiumSinceTimestamp && Boolean(newMember.premiumSinceTimestamp);
    if (!startedBoost) return;
    await processNitroBoostStart(newMember, "guildMemberUpdate");
  } catch (e) {
    console.error("[nitro] erro no guildMemberUpdate:", e);
  }
});

client.login(token);
