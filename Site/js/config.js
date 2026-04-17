/** Cole aqui o link direto da experiência Roblox */
window.ROBLOX_PLACE_URL = "https://www.roblox.com/pt/games/PLACEHOLDER";

/**
 * Stripe Checkout (chave secreta só no servidor do bot — .env STRIPE_SECRET_KEY).
 * Chave publicável (pk_test_...) não é obrigatória neste fluxo (redirecionamento ao Stripe).
 */
window.GEAR_STRIPE = {
  /** Ative para abrir checkout ao clicar em Comprar (bot precisa estar rodando). */
  enabled: true,
  /** Use o mesmo host que SITE_BASE_URL no .env do bot (127.0.0.1 e localhost são origens diferentes). */
  apiBase: "http://127.0.0.1:3847",
  /** Mesmo que GUILD_ID do .env do bot (opcional se já estiver no servidor) */
  guildId: "1494479868174270576",
  /**
   * Login OAuth no Discord (requer DISCORD_CLIENT_SECRET no .env do bot + redirect URI no portal).
   * Se false, esconde o botão "Entrar com Discord" no menu.
   */
  discordLogin: true,
  /**
   * Se true, o checkout só usa a sessão Discord (sem colar ID). Requer DISCORD_CLIENT_SECRET no bot.
   * Se false, o modal pede ID manual (útil antes de configurar OAuth).
   */
  requireDiscordLogin: true,
  /**
   * Se true, produtos com data-grant-tier pedem confirmação Roblox (preview) antes do Stripe.
   * Defina false para desativar sem remover atributos nos cards.
   */
  robloxDeliveryEnabled: true,
};

/**
 * Simulação sem pagamento (só Discord). Desative se usar só Stripe.
 */
window.GEAR_CHECKOUT_DEMO = {
  enabled: false,
  apiBase: "http://127.0.0.1:3847",
  guildId: "",
  demoKey: "",
};
