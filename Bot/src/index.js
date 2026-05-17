require("dotenv").config();
const fs = require("fs");
const path = require("path");
const { Client, Collection, GatewayIntentBits } = require("discord.js");
const { startHttpServer } = require("./server/http");
const guildConfig = require("./lib/guildConfig");

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
      const ticket = client.commands.get("ticket");
      if (interaction.customId.startsWith("ticket_m:") && ticket?.handleModalSubmit) {
        await ticket.handleModalSubmit(interaction);
      }
      return;
    }

    if (interaction.isButton()) {
      if (interaction.customId === "verify_accept") {
        const cfg = guildConfig.get(interaction.guildId);
        if (!cfg.visitorRoleId || !cfg.playerRoleId) {
          await interaction.reply({
            ephemeral: true,
            content: "❌ Verificação não configurada. Um admin deve usar `/setup verificacao`.",
          });
          return;
        }

        const member = await interaction.guild.members.fetch(interaction.user.id);
        if (!member || !member.roles) {
          await interaction.reply({
            ephemeral: true,
            content: "❌ Não consegui identificar seu membro no servidor.",
          });
          return;
        }

        try {
          if (!member.roles.cache.has(cfg.playerRoleId)) {
            await member.roles.add(cfg.playerRoleId, "Verificação concluída");
          }
          if (member.roles.cache.has(cfg.visitorRoleId)) {
            await member.roles.remove(cfg.visitorRoleId, "Verificação concluída");
          }
          await interaction.reply({
            ephemeral: true,
            content: "✅ Verificação concluída! Seu acesso foi liberado.",
          });
        } catch (e) {
          console.error("[verify] erro ao trocar cargos:", e);
          await interaction.reply({
            ephemeral: true,
            content:
              "❌ Não consegui atualizar seus cargos. Verifique se o cargo do bot está acima dos cargos de Visitante/Jogador.",
          });
        }
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

client.login(token);
