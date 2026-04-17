require("dotenv").config();
const { REST, Routes } = require("discord.js");
const fs = require("fs");
const path = require("path");

const token = process.env.DISCORD_TOKEN;
const clientId = process.env.CLIENT_ID;
const guildId = process.env.GUILD_ID;

if (!token || !clientId) {
  console.error("Defina DISCORD_TOKEN e CLIENT_ID no arquivo .env");
  process.exit(1);
}

const commandsPath = path.join(__dirname, "commands");
const body = fs
  .readdirSync(commandsPath)
  .filter((f) => f.endsWith(".js"))
  .map((f) => {
    const mod = require(path.join(commandsPath, f));
    return mod.data.toJSON();
  });

const rest = new REST({ version: "10" }).setToken(token);

(async () => {
  try {
    if (guildId) {
      await rest.put(Routes.applicationGuildCommands(clientId, guildId), {
        body,
      });
      console.log(
        `Comandos registrados no servidor ${guildId} (aparecem na hora).`
      );
    } else {
      await rest.put(Routes.applicationCommands(clientId), { body });
      console.log(
        "Comandos registrados globalmente (podem demorar até ~1h para aparecer)."
      );
    }
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
})();
