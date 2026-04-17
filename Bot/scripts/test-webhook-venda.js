/**
 * Testa se o log de venda chega no Discord.
 * Pré-requisitos: bot rodando (`npm start`), WEBHOOK_SECRET e GUILD_ID no .env,
 * e /setup vendas já executado no servidor (canal de log configurado).
 *
 * Uso:
 *   node scripts/test-webhook-venda.js <discord_user_id>
 *   ou defina TEST_DISCORD_USER_ID no .env
 */
require("dotenv").config();
const http = require("http");

const port = Number(process.env.PORT || 3847);
const secret = process.env.WEBHOOK_SECRET;
const guildId = process.env.GUILD_ID;
const discordUserId = process.argv[2] || process.env.TEST_DISCORD_USER_ID;

if (!secret) {
  console.error("Defina WEBHOOK_SECRET no .env");
  process.exit(1);
}
if (!guildId) {
  console.error("Defina GUILD_ID no .env (ID do servidor Discord onde usou /setup vendas)");
  process.exit(1);
}
if (!discordUserId) {
  console.error(
    "Passe o ID do usuário: node scripts/test-webhook-venda.js <discord_user_id>\n" +
      "Ou defina TEST_DISCORD_USER_ID no .env (Modo desenvolvedor → clique direito no perfil → Copiar ID)"
  );
  process.exit(1);
}

const payload = {
  guildId,
  discordUserId,
  itemName: "Teste manual — webhook de venda",
  orderId: `test-${Date.now()}`,
  quantity: 1,
  kind: "sale",
  note: "Ignorar — disparo do script scripts/test-webhook-venda.js",
};

const body = JSON.stringify(payload);

const req = http.request(
  {
    hostname: "127.0.0.1",
    port,
    path: "/webhooks/venda",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body),
      Authorization: `Bearer ${secret}`,
    },
  },
  (res) => {
    let data = "";
    res.on("data", (c) => {
      data += c;
    });
    res.on("end", () => {
      console.log(`HTTP ${res.statusCode}`, data || "(vazio)");
      if (res.statusCode === 200) {
        console.log("OK — verifique o canal de log de vendas no Discord.");
      }
    });
  }
);

req.on("error", (e) => {
  console.error("Falha ao conectar. O bot está rodando? (npm start na pasta Bot)", e.message);
  process.exit(1);
});

req.write(body);
req.end();
