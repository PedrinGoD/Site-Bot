const express = require("express");
const cors = require("cors");
const Stripe = require("stripe");
const { EmbedBuilder } = require("discord.js");
const guildConfig = require("../lib/guildConfig");
const {
  signOAuthState,
  verifyOAuthState,
  signDiscordSession,
  verifyDiscordSession,
} = require("../lib/sessionToken");
const robloxGrants = require("../lib/robloxGrants");

let botPackageVersion = "0.0.0";
try {
  botPackageVersion = require("../../package.json").version;
} catch (_) {
  /* ignore */
}

/**
 * @param {import('discord.js').Client} client
 */
function startHttpServer(client) {
  const app = express();

  const secret = process.env.WEBHOOK_SECRET || "";
  const port = Number(process.env.PORT || 3847);
  const defaultGuildId = process.env.GUILD_ID || "";
  const demoSaleKey = (process.env.DEMO_SALE_KEY || "").trim();
  const stripeSecretKey = (process.env.STRIPE_SECRET_KEY || "").trim();
  const stripeWebhookSecret = (process.env.STRIPE_WEBHOOK_SECRET || "").trim();
  const siteBaseUrl = (process.env.SITE_BASE_URL || "http://127.0.0.1:5500").replace(/\/$/, "");
  const discordClientId = (process.env.CLIENT_ID || process.env.DISCORD_CLIENT_ID || "").trim();
  const discordClientSecret = (process.env.DISCORD_CLIENT_SECRET || "").trim();
  const oauthRedirectUri = (
    process.env.OAUTH_REDIRECT_URI || `http://127.0.0.1:${port}/auth/discord/callback`
  ).trim();
  const sessionSigningSecret = (process.env.SESSION_SIGNING_SECRET || secret || "gear-session-dev").trim();
  const allowManualDiscordId = process.env.ALLOW_MANUAL_DISCORD_ID === "true";
  const robloxApiSecret = (process.env.ROBLOX_API_SECRET || "").trim();

  /** Normaliza ID de canal Discord (aspas, espaços, menção tipo <#123456789012345678>). */
  function normalizeDiscordChannelId(raw) {
    if (raw == null) return "";
    let s = String(raw).trim();
    if (!s) return "";
    s = s.replace(/^[\s"'`]+|[\s"'`]+$/g, "");
    const mention = s.match(/^<#(\d{17,22})>$/);
    if (mention) return mention[1];
    const digits = s.replace(/\D/g, "");
    if (digits.length >= 17 && digits.length <= 22) return digits;
    return "";
  }

  /**
   * Lido em cada uso — Render injeta variáveis no processo (não confundir .env local com o painel do host).
   * Aliases: GEAR_SALES_LOG_CHANNEL_ID, DISCORD_SALES_CHANNEL_ID.
   */
  function getSalesLogChannelIdFromEnv() {
    const keys = [
      "SALES_LOG_CHANNEL_ID",
      "GEAR_SALES_LOG_CHANNEL_ID",
      "DISCORD_SALES_CHANNEL_ID",
    ];
    for (const k of keys) {
      const id = normalizeDiscordChannelId(process.env[k]);
      if (id) return id;
    }
    return "";
  }

  function getNitroLogChannelIdFromEnv() {
    const keys = ["NITRO_LOG_CHANNEL_ID", "GEAR_NITRO_LOG_CHANNEL_ID"];
    for (const k of keys) {
      const id = normalizeDiscordChannelId(process.env[k]);
      if (id) return id;
    }
    return "";
  }

  function getFullStaffLogChannelIdFromEnv() {
    const keys = [
      "FULL_TRANSACTION_LOG_CHANNEL_ID",
      "GEAR_FULL_TRANSACTION_LOG_CHANNEL_ID",
      "STAFF_SALES_DETAIL_CHANNEL_ID",
    ];
    for (const k of keys) {
      const id = normalizeDiscordChannelId(process.env[k]);
      if (id) return id;
    }
    return "";
  }

  /** `/setup log_detalhado` no servidor, ou env global (Render). */
  function resolveFullStaffLogChannelId(guildId) {
    const fromGuild = guildId
      ? normalizeDiscordChannelId(guildConfig.get(guildId).fullTransactionLogChannelId)
      : "";
    return fromGuild || getFullStaffLogChannelIdFromEnv();
  }

  /** Evita dois avisos no Discord (webhook + página de sucesso) para o mesmo checkout */
  const notifiedStripeSessions = new Set();
  /** Uma mensagem detalhada (staff) por sessão Stripe */
  const staffFullLogSent = new Set();

  /** @type {import('stripe').Stripe | null} */
  let stripe = null;
  if (stripeSecretKey) {
    stripe = new Stripe(stripeSecretKey);
    console.log("[stripe] API configurada (Checkout + webhook)");
  }

  if (stripe && !stripeWebhookSecret) {
    console.warn(
      "\n[AVISO] STRIPE_WEBHOOK_SECRET está vazio — o endpoint /webhooks/stripe não valida eventos.\n" +
        "         Para o CLI: rode `stripe listen --forward-to localhost:" +
        port +
        "/webhooks/stripe` e copie o whsec_ para o .env.\n" +
        "         Alternativa: ao abrir pagamento-ok.html o site chama /stripe/notify-from-session (confirmação direta).\n"
    );
  }

  const demoOrigins = (process.env.DEMO_CORS_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const defaultDemoOrigins = [
    "http://127.0.0.1:5500",
    "http://localhost:5500",
    "http://127.0.0.1:8080",
    "http://localhost:8080",
    "http://127.0.0.1:3000",
    "http://localhost:3000",
    "http://127.0.0.1:4173",
    "http://localhost:4173",
  ];
  const corsOrigins = [...(demoOrigins.length ? demoOrigins : defaultDemoOrigins)];
  /** Site em produção (Render, domínio próprio): mesma origem que SITE_BASE_URL */
  if (siteBaseUrl && !corsOrigins.includes(siteBaseUrl)) {
    corsOrigins.push(siteBaseUrl);
  }

  function corsAllowOrigin(origin) {
    if (!origin || origin === "null") return true;
    return corsOrigins.includes(origin);
  }

  if (demoSaleKey || stripeSecretKey || discordClientSecret || robloxApiSecret) {
    app.use(
      cors({
        origin: (origin, callback) => callback(null, corsAllowOrigin(origin)),
        methods: ["POST", "OPTIONS", "GET"],
        allowedHeaders: ["Content-Type", "X-Demo-Key", "Authorization"],
      })
    );
  }

  /**
   * @param {import('discord.js').Client} client
   * @param {object} body
   * @param {boolean} isDemo
   */
  async function deliverSaleToDiscord(client, body, isDemo) {
    const guildId = body.guildId || defaultGuildId;
    if (!guildId) {
      throw Object.assign(new Error("missing guildId (body ou GUILD_ID no .env)"), { status: 400 });
    }

    const discordUserId = body.discordUserId;
    const itemName = body.itemName || "Item";
    const orderId = body.orderId || "—";
    const quantity = body.quantity ?? 1;
    const kind = body.kind === "nitro" ? "nitro" : "sale";
    const note = body.note || "";
    const itemImageUrl = body.itemImageUrl && String(body.itemImageUrl).trim();
    /** Compra via Stripe Checkout — embed curto, sem IDs técnicos no canal */
    const stripeCheckout = body.stripeCheckout === true;

    if (!discordUserId) {
      throw Object.assign(new Error("missing discordUserId"), { status: 400 });
    }

    const cfg = guildConfig.get(guildId);
    const envSales = getSalesLogChannelIdFromEnv();
    const envNitro = getNitroLogChannelIdFromEnv();
    const channelId =
      kind === "nitro"
        ? cfg.nitroLogChannelId || envNitro || cfg.salesLogChannelId || envSales
        : cfg.salesLogChannelId || envSales;

    if (!channelId) {
      throw Object.assign(
        new Error(
          "Canal de log não configurado. No Render: Environment → SALES_LOG_CHANNEL_ID = ID do canal (sem espaços). Ficheiro .env local não é enviado ao Git."
        ),
        { status: 400 }
      );
    }

    const ch = await client.channels.fetch(channelId);
    if (!ch?.isTextBased()) {
      throw Object.assign(new Error("canal inválido"), { status: 500 });
    }

    let title;
    let color;
    if (isDemo) {
      title = kind === "nitro" ? "🧪 Simulação — Nitro / evento" : "🧪 Simulação de compra (site)";
      color = kind === "nitro" ? 0xf47fff : 0xfee75c;
    } else if (stripeCheckout) {
      title = kind === "nitro" ? "🎁 Confirmação — evento" : "✅ Compra confirmada";
      color = kind === "nitro" ? 0xf47fff : 0x3ba55d;
    } else {
      title = kind === "nitro" ? "🎁 Evento / Nitro" : "🛒 Nova venda";
      color = kind === "nitro" ? 0xf47fff : 0x57f287;
    }

    const buyerLine = `<@${discordUserId}>`;
    const itemLine = String(itemName).slice(0, 1024);

    const embed = new EmbedBuilder().setColor(color).setTimestamp();

    if (stripeCheckout && !isDemo) {
      embed
        .setTitle(title)
        .setDescription(`**${itemLine}**`)
        .addFields({ name: "Comprador", value: buyerLine, inline: false });
      if (itemImageUrl && /^https?:\/\//i.test(itemImageUrl)) {
        embed.setThumbnail(itemImageUrl.slice(0, 2048));
      }
    } else {
      embed.setTitle(title).addFields(
        { name: "Comprador", value: buyerLine, inline: false },
        { name: "Produto", value: itemLine, inline: true }
      );
      if (quantity !== 1) {
        embed.addFields({ name: "Qtd", value: String(quantity), inline: true });
      }
      const oid = String(orderId);
      const hideOrder =
        oid.startsWith("cs_") || oid.length > 40 || oid === "—";
      if (!hideOrder) {
        embed.addFields({ name: "Ref. pedido", value: oid.slice(0, 80), inline: true });
      }
      if (itemImageUrl && /^https?:\/\//i.test(itemImageUrl)) {
        embed.setThumbnail(itemImageUrl.slice(0, 2048));
      }
      if (note && !stripeCheckout) {
        embed.addFields({ name: "Obs", value: String(note).slice(0, 500) });
      }
      if (isDemo) {
        embed.addFields({
          name: "Tipo",
          value: "Teste pelo site (não é pagamento real).",
          inline: false,
        });
      }
    }

    await ch.send({
      content: `<@${discordUserId}>`,
      embeds: [embed],
      allowedMentions: { users: [discordUserId] },
    });
  }

  /**
   * @param {string} robloxUserId
   * @returns {Promise<{ id: string, name?: string, displayName?: string, error?: string } | null>}
   */
  async function fetchRobloxProfilePublic(robloxUserId) {
    const id = String(robloxUserId || "").replace(/\D/g, "");
    if (!id) return null;
    try {
      const r = await fetch(`https://users.roblox.com/v1/users/${id}`, {
        signal: AbortSignal.timeout(8000),
      });
      if (!r.ok) return { id, error: `HTTP ${r.status}` };
      const j = await r.json();
      return { id, name: j.name, displayName: j.displayName };
    } catch (e) {
      return { id, error: String(e.message || e) };
    }
  }

  /** Resumo curto do meio de pagamento (sem IDs longos do Stripe). */
  function formatStripePaymentShort(s) {
    const pi = typeof s.payment_intent === "object" && s.payment_intent ? s.payment_intent : null;
    if (!pi) return "—";
    const pm = typeof pi.payment_method === "object" && pi.payment_method ? pi.payment_method : null;
    if (!pm) return "Cartão / método (detalhe indisponível)";
    const bits = [];
    if (pm.card) {
      const c = pm.card;
      bits.push(
        `${(c.brand || "?").toUpperCase()} ····${c.last4 || "????"} · ${c.funding || "?"} · país ${c.country || "?"}`
      );
      if (c.wallet?.type) bits.push(`Carteira: ${c.wallet.type}`);
    } else if (pm.type === "pix" || pm.pix) {
      bits.push("Pix");
    } else if (pm.type === "boleto" || pm.boleto) {
      bits.push("Boleto");
    } else {
      bits.push(String(pm.type || "?"));
    }
    if (pm.us_bank_account) {
      const u = pm.us_bank_account;
      bits.push(`${u.bank_name || "Banco US"} ····${u.last4 || ""}`);
    }
    if (pm.sepa_debit) bits.push(`SEPA · ${pm.sepa_debit.country || "?"}`);
    return bits.join("\n").slice(0, 500);
  }

  function prettyGrantTypePt(v) {
    const m = {
      vip: "VIP",
      vehicle: "Veículo",
      currency: "Dinheiro",
      xp: "XP",
      economy: "Economia (dinheiro + XP)",
    };
    return m[String(v || "").trim().toLowerCase()] || String(v || "—");
  }

  /** Carrinho `roblox_grants_json` em linhas curtas. */
  function prettyRobloxGrantsJson(raw) {
    try {
      const a = JSON.parse(String(raw));
      if (!Array.isArray(a)) return String(raw).slice(0, 240);
      return a
        .map((g) => {
          const gt = String(g?.grantType || "vip").toLowerCase();
          if (gt === "vehicle") return `- Veículo ID \`${g.grantVehicleId || "?"}\``;
          if (gt === "currency") return `- Dinheiro R$ ${g.grantMoneyAmount ?? "?"}`;
          if (gt === "xp") return `- +${g.grantXpAmount ?? "?"} XP`;
          if (gt === "economy")
            return `- Economia R$ ${g.grantMoneyAmount ?? 0} + ${g.grantXpAmount ?? 0} XP`;
          return `- VIP **${g.grantTier || "?"}** · ${g.grantDays ?? "?"} dia(s)`;
        })
        .join("\n")
        .slice(0, 900);
    } catch {
      return String(raw).slice(0, 240);
    }
  }

  /**
   * Metadados do Checkout em português (sem chaves técnicas `grant_*`).
   * @param {Record<string, string>} md
   */
  function formatCheckoutMetadataFriendly(md) {
    const skip = new Set([
      "item_name",
      "item_image_url",
      "discord_user_id",
      "roblox_user_id",
      "guild_id",
    ]);
    const lines = [];

    const push = (label, val) => {
      if (val == null || val === "") return;
      lines.push(`**${label}:** ${String(val).slice(0, 400)}`);
    };

    const gt = md.grant_type != null ? prettyGrantTypePt(md.grant_type) : "";
    if (md.grant_type) push("Tipo de entrega", gt);
    if (md.grant_tier != null && String(md.grant_tier).trim()) push("VIP", String(md.grant_tier).trim());
    if (md.grant_days != null && String(md.grant_days).trim() !== "") {
      const d = String(md.grant_days).trim();
      const gtl = String(md.grant_type || "").toLowerCase();
      if (!(d === "0" && gtl && gtl !== "vip")) push("Dias", d);
    }
    if (md.grant_vehicle_id) push("Veículo (ID)", `\`${md.grant_vehicle_id}\``);
    if (md.grant_money_amount != null && String(md.grant_money_amount).trim() !== "")
      push("Dinheiro (jogo)", `R$ ${String(md.grant_money_amount).trim()}`);
    if (md.grant_xp_amount != null && String(md.grant_xp_amount).trim() !== "")
      push("XP (jogo)", String(md.grant_xp_amount).trim());
    if (md.roblox_grants_json) push("Itens no carrinho", prettyRobloxGrantsJson(md.roblox_grants_json));
    if (md.coupon_code) push("Cupom", String(md.coupon_code));
    if (md.discount_percent) push("Desconto", `${md.discount_percent}%`);
    if (md.discount_cents) push("Desconto (fixo)", `${(Number(md.discount_cents) / 100).toFixed(2)} (moeda sessão)`);

    const known = new Set([
      "grant_type",
      "grant_tier",
      "grant_days",
      "grant_vehicle_id",
      "grant_money_amount",
      "grant_xp_amount",
      "roblox_grants_json",
      "coupon_code",
      "discount_percent",
      "discount_cents",
    ]);
    for (const k of Object.keys(md).sort()) {
      if (skip.has(k) || known.has(k)) continue;
      const v = md[k];
      if (v == null || v === "") continue;
      push(k.replace(/_/g, " "), String(v).slice(0, 200));
    }

    return lines.length ? lines.join("\n").slice(0, 1900) : "— *(só dados já mostrados acima)*";
  }

  /**
   * @param {import('discord.js').Client} client
   * @param {import('stripe').Stripe.Checkout.Session} session
   * @param {string} contextLabel
   */
  async function trySendStaffFullTransactionLog(client, session, contextLabel) {
    if (!stripe) return { ok: true, skipped: true };
    const md = session.metadata || {};
    const guildId = md.guild_id || md.guildId || defaultGuildId;
    const channelId = resolveFullStaffLogChannelId(guildId);
    if (!channelId) return { ok: true, skipped: true };
    if (staffFullLogSent.has(session.id)) return { ok: true, duplicate: true };

    let s = session;
    try {
      s = await stripe.checkout.sessions.retrieve(session.id, {
        expand: ["line_items", "payment_intent", "payment_intent.payment_method"],
      });
    } catch (e) {
      console.error(`[stripe] staff log retrieve:`, e.message || e);
    }

    const currency = (s.currency || "usd").toUpperCase();
    const total =
      s.amount_total != null ? `${(s.amount_total / 100).toFixed(2)} ${currency}` : "—";
    const sub =
      s.amount_subtotal != null ? `${(s.amount_subtotal / 100).toFixed(2)} ${currency}` : "—";
    const itemName = md.item_name || md.itemName || "—";

    const cust = s.customer_details;
    const custBits = [cust?.email, cust?.name, cust?.address?.country].filter(Boolean);
    const custBlock = custBits.length ? custBits.join(" · ").slice(0, 500) : "—";

    const rid = md.roblox_user_id || md.robloxUserId;
    let robloxBlock = "—";
    if (rid) {
      const prof = await fetchRobloxProfilePublic(rid);
      if (prof?.name) {
        robloxBlock = `**@${prof.name}** (${prof.displayName || prof.name})\n\`${prof.id}\``;
      } else if (prof) {
        robloxBlock = `\`${prof.id}\`${prof.error ? ` (${prof.error})` : ""}`;
      } else {
        robloxBlock = `\`${String(rid).trim()}\``;
      }
    }

    const discordUserId = md.discord_user_id || md.discordUserId;
    const discordBlock = discordUserId ? `<@${discordUserId}> · \`${discordUserId}\`` : "—";

    const pagoPt = String(s.payment_status || "") === "paid" ? "Pago" : String(s.payment_status || "—");
    const valorLinha =
      sub !== total && sub !== "—"
        ? `**${total}** (subtotal ${sub}) · ${pagoPt}`
        : `**${total}** · ${pagoPt}`;

    const payBlock = formatStripePaymentShort(s);
    const detalhesPedido = formatCheckoutMetadataFriendly(md);

    const sid = String(s.id || "");

    const embed = new EmbedBuilder()
      .setColor(0x5865f2)
      .setTitle("Transação (staff)")
      .setDescription(`**${String(itemName).slice(0, 250)}**`)
      .addFields(
        { name: "Valor", value: valorLinha.slice(0, 256), inline: false },
        { name: "Cliente (email / nome / país)", value: custBlock.slice(0, 1024), inline: false },
        { name: "Meio de pagamento", value: (payBlock || "—").slice(0, 1024), inline: false },
        {
          name: "Roblox & Discord",
          value: `${robloxBlock}\n${discordBlock}`.slice(0, 1024),
          inline: false,
        },
        { name: "Detalhes do pedido", value: detalhesPedido.slice(0, 1024), inline: false }
      )
      .setFooter({ text: `${contextLabel} · ${sid}`.slice(0, 450) })
      .setTimestamp(new Date());

    try {
      const ch = await client.channels.fetch(channelId);
      if (!ch?.isTextBased()) throw new Error("canal log detalhado inválido");
      await ch.send({
        embeds: [embed],
        allowedMentions: { parse: [] },
      });
      staffFullLogSent.add(session.id);
      console.log(`[discord] ✓ log detalhado staff — ${session.id}`);
      return { ok: true };
    } catch (e) {
      console.error(`[discord] log detalhado staff:`, e.message || e);
      return { ok: false, error: String(e.message || e) };
    }
  }

  /**
   * @param {import('discord.js').Client} client
   * @param {import('stripe').Stripe.Checkout.Session} session
   * @param {string} contextLabel
   */
  async function tryNotifyDiscordFromCheckoutSession(client, session, contextLabel) {
    if (session.payment_status !== "paid") {
      console.log(
        `[stripe] ${contextLabel}: sessão ${session.id} payment_status=${session.payment_status} (só notificamos se for "paid")`
      );
      return { ok: false, reason: "not_paid", payment_status: session.payment_status };
    }

    const md = session.metadata || {};
    const guildId = md.guild_id || md.guildId || defaultGuildId;
    const hasStaffChannel = Boolean(resolveFullStaffLogChannelId(guildId));
    const doneShort = notifiedStripeSessions.has(session.id);
    const doneStaff = !hasStaffChannel || staffFullLogSent.has(session.id);
    if (doneShort && doneStaff) {
      console.log(`[stripe] ${contextLabel}: sessão ${session.id} já processada (Discord) — duplicado`);
      return { ok: true, duplicate: true };
    }

    const discordUserId = md.discord_user_id || md.discordUserId;
    const itemName = md.item_name || md.itemName || "Item";

    /** Entrega no jogo não depende do Discord; idempotente por stripeSessionId em robloxGrants. */
    try {
      maybeQueueRobloxGrant(session);
    } catch (qe) {
      console.error(`[roblox] fila pós-pagamento:`, qe.message || qe);
    }

    if (!doneStaff) {
      try {
        await trySendStaffFullTransactionLog(client, session, contextLabel);
      } catch (e) {
        console.error(`[discord] staff log inesperado:`, e.message || e);
      }
    }

    if (!discordUserId) {
      console.warn(`[stripe] ${contextLabel}: metadata sem discord_user_id`);
      return { ok: false, reason: "no_discord_in_metadata" };
    }

    if (doneShort) {
      return { ok: true, duplicatePartial: true, reason: "short_already_sent" };
    }

    const img = md.item_image_url || md.itemImageUrl;
    const itemImageUrl =
      img && String(img).trim() && /^https?:\/\//i.test(String(img).trim()) ? String(img).trim() : undefined;

    try {
      await deliverSaleToDiscord(
        client,
        {
          guildId,
          discordUserId,
          itemName,
          orderId: session.id,
          quantity: 1,
          kind: "sale",
          note: "",
          itemImageUrl,
          stripeCheckout: true,
        },
        false
      );
      notifiedStripeSessions.add(session.id);
      console.log(`[stripe] ✓ Log enviado ao Discord (${contextLabel}) — ${session.id}`);
      return { ok: true };
    } catch (e) {
      console.error(`[stripe] ${contextLabel}: erro ao enviar Discord:`, e.message || e);
      return { ok: false, error: String(e.message || e) };
    }
  }

  /* Stripe webhook: corpo RAW (antes do express.json) */
  app.post(
    "/webhooks/stripe",
    express.raw({ type: "application/json", limit: "256kb" }),
    async (req, res) => {
      if (!stripe) {
        return res.status(503).send("Stripe não configurado");
      }
      if (!stripeWebhookSecret) {
        console.warn("[stripe] POST /webhooks/stripe recusado: STRIPE_WEBHOOK_SECRET vazio");
        return res.status(503).send("Defina STRIPE_WEBHOOK_SECRET no .env (whsec_ do stripe listen)");
      }

      const sig = req.headers["stripe-signature"];
      let event;
      try {
        event = stripe.webhooks.constructEvent(req.body, sig, stripeWebhookSecret);
      } catch (err) {
        console.error("[stripe] Assinatura webhook inválida:", err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
      }

      console.log(`[stripe] Webhook Stripe: tipo=${event.type}`);

      if (event.type === "checkout.session.completed") {
        const session = event.data.object;
        await tryNotifyDiscordFromCheckoutSession(client, session, "webhook");
      }

      return res.json({ received: true });
    }
  );

  app.use(express.json({ limit: "48kb" }));

  function unauthorized(res) {
    res.status(401).json({ ok: false, error: "unauthorized" });
  }

  function checkAuth(req) {
    if (!secret) {
      return false;
    }
    const h = req.headers.authorization || "";
    const bearer = h.startsWith("Bearer ") ? h.slice(7).trim() : req.body?.secret;
    return bearer === secret;
  }

  function extractBearer(req) {
    const h = req.headers.authorization || "";
    return h.startsWith("Bearer ") ? h.slice(7).trim() : "";
  }

  function safeNextPath(s) {
    if (typeof s !== "string") return "index.html";
    let u = s.trim();
    if (!u || u.includes("..") || u.includes("//")) return "index.html";
    if (u.startsWith("/")) u = u.slice(1);
    if (!/^[a-zA-Z0-9._?=&%-]+$/.test(u)) return "index.html";
    return u.slice(0, 120);
  }

  async function exchangeDiscordOAuthCode(code) {
    const body = new URLSearchParams({
      client_id: discordClientId,
      client_secret: discordClientSecret,
      grant_type: "authorization_code",
      code,
      redirect_uri: oauthRedirectUri,
    });
    const r = await fetch("https://discord.com/api/oauth2/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });
    if (!r.ok) {
      const t = await r.text();
      throw new Error(`OAuth token: ${r.status} ${t}`);
    }
    return r.json();
  }

  async function discordFetchMe(accessToken) {
    const r = await fetch("https://discord.com/api/users/@me", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!r.ok) {
      throw new Error(`@me failed ${r.status}`);
    }
    return r.json();
  }

  function maybeQueueRobloxGrant(session) {
    const md = session.metadata || {};
    const rid = md.roblox_user_id || md.robloxUserId;
    if (!rid) {
      console.log("[roblox] metadata sem roblox_user_id — entrega no jogo ignorada");
      return;
    }

    const grantsJson = String(md.roblox_grants_json || "").trim();
    if (grantsJson) {
      try {
        const grants = JSON.parse(grantsJson);
        if (Array.isArray(grants)) {
          grants.forEach((g, idx) => {
            const days = parseInt(String(g && g.grantDays != null ? g.grantDays : "0"), 10);
            const gtype = String((g && g.grantType) || "vip")
              .trim()
              .toLowerCase();
            const vid = g && g.grantVehicleId ? String(g.grantVehicleId).trim() : "";
            const tier = g && g.grantTier ? String(g.grantTier).trim() : "";
            if (gtype === "vehicle" && vid) {
              robloxGrants.queueGrantAfterPayment({
                stripeSessionId: `${session.id}:${idx}`,
                robloxUserId: String(rid),
                grantType: "vehicle",
                grantTier: "",
                grantDays: 0,
                grantVehicleId: vid,
              });
              return;
            }
            if (gtype === "currency") {
              const m = parseInt(String(g.grantMoneyAmount ?? g.grant_money_amount ?? "0"), 10);
              if (robloxGrants.isValidMoneyAmount(m)) {
                robloxGrants.queueGrantAfterPayment({
                  stripeSessionId: `${session.id}:${idx}`,
                  robloxUserId: String(rid),
                  grantType: "currency",
                  grantMoneyAmount: m,
                });
              }
              return;
            }
            if (gtype === "xp") {
              const xp = parseInt(String(g.grantXpAmount ?? g.grant_xp_amount ?? "0"), 10);
              if (robloxGrants.isValidXpAmount(xp)) {
                robloxGrants.queueGrantAfterPayment({
                  stripeSessionId: `${session.id}:${idx}`,
                  robloxUserId: String(rid),
                  grantType: "xp",
                  grantXpAmount: xp,
                });
              }
              return;
            }
            if (gtype === "economy") {
              const m = parseInt(String(g.grantMoneyAmount ?? g.grant_money_amount ?? "0"), 10);
              const xp = parseInt(String(g.grantXpAmount ?? g.grant_xp_amount ?? "0"), 10);
              if (m >= 0 && xp >= 0 && m <= 2e9 && xp <= 2e9 && (m >= 1 || xp >= 1)) {
                robloxGrants.queueGrantAfterPayment({
                  stripeSessionId: `${session.id}:${idx}`,
                  robloxUserId: String(rid),
                  grantType: "economy",
                  grantMoneyAmount: m,
                  grantXpAmount: xp,
                });
              }
              return;
            }
            if (!tier) return;
            robloxGrants.queueGrantAfterPayment({
              stripeSessionId: `${session.id}:${idx}`,
              robloxUserId: String(rid),
              grantType: gtype || "vip",
              grantTier: tier,
              grantDays: days,
            });
          });
          return;
        }
      } catch (e) {
        console.warn("[roblox] roblox_grants_json inválido:", e.message || e);
      }
    }

    const gtypeSingle = String(md.grant_type || md.grantType || "vip")
      .trim()
      .toLowerCase();
    const vidSingle = String(md.grant_vehicle_id || md.grantVehicleId || "").trim();
    if (gtypeSingle === "vehicle" && vidSingle) {
      robloxGrants.queueGrantAfterPayment({
        stripeSessionId: session.id,
        robloxUserId: String(rid),
        grantType: "vehicle",
        grantTier: "",
        grantDays: 0,
        grantVehicleId: vidSingle,
      });
      return;
    }
    if (gtypeSingle === "currency") {
      const m = parseInt(String(md.grant_money_amount || md.grantMoneyAmount || "0"), 10);
      if (robloxGrants.isValidMoneyAmount(m)) {
        robloxGrants.queueGrantAfterPayment({
          stripeSessionId: session.id,
          robloxUserId: String(rid),
          grantType: "currency",
          grantMoneyAmount: m,
        });
      }
      return;
    }
    if (gtypeSingle === "xp") {
      const xp = parseInt(String(md.grant_xp_amount || md.grantXpAmount || "0"), 10);
      if (robloxGrants.isValidXpAmount(xp)) {
        robloxGrants.queueGrantAfterPayment({
          stripeSessionId: session.id,
          robloxUserId: String(rid),
          grantType: "xp",
          grantXpAmount: xp,
        });
      }
      return;
    }
    if (gtypeSingle === "economy") {
      const m = parseInt(String(md.grant_money_amount || md.grantMoneyAmount || "0"), 10);
      const xp = parseInt(String(md.grant_xp_amount || md.grantXpAmount || "0"), 10);
      if (m >= 0 && xp >= 0 && m <= 2e9 && xp <= 2e9 && (m >= 1 || xp >= 1)) {
        robloxGrants.queueGrantAfterPayment({
          stripeSessionId: session.id,
          robloxUserId: String(rid),
          grantType: "economy",
          grantMoneyAmount: m,
          grantXpAmount: xp,
        });
      }
      return;
    }

    const tier = md.grant_tier || md.grantTier;
    if (!tier) {
      console.log("[roblox] sessão paga com roblox_user_id mas sem grant_tier / grant_vehicle_id — nada enfileirado");
      return;
    }
    const days = parseInt(String(md.grant_days || md.grantDays || "0"), 10);
    robloxGrants.queueGrantAfterPayment({
      stripeSessionId: session.id,
      robloxUserId: String(rid),
      grantType: gtypeSingle || "vip",
      grantTier: String(tier),
      grantDays: days,
    });
  }

  /**
   * GET /roblox/lookup-username?username= — API pública Roblox (preview no site)
   */
  app.get("/roblox/lookup-username", async (req, res) => {
    const raw = String(req.query.username || "").trim();
    if (!raw || raw.length > 40) {
      return res.status(400).json({ ok: false, error: "username inválido" });
    }
    try {
      const r = await fetch("https://users.roblox.com/v1/usernames/users", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ usernames: [raw], excludeBannedUsers: true }),
      });
      const j = await r.json();
      const row = j.data && j.data[0];
      if (!row) {
        return res.json({ ok: false, error: "not_found" });
      }
      const userId = row.id;
      const username = row.name;
      let imageUrl = null;
      const tr = await fetch(
        `https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${userId}&size=150x150&format=Png&isCircular=true`
      );
      const tj = await tr.json();
      if (tj.data && tj.data[0] && tj.data[0].imageUrl) {
        imageUrl = tj.data[0].imageUrl;
      }
      return res.json({
        ok: true,
        userId,
        username,
        imageUrl,
      });
    } catch (e) {
      console.error("[roblox] lookup:", e);
      return res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });

  /**
   * GET /roblox/pending-grants?userId= — só o servidor do jogo (Bearer ROBLOX_API_SECRET)
   */
  app.get("/roblox/pending-grants", (req, res) => {
    if (!robloxApiSecret) {
      return res.status(503).json({ ok: false, error: "ROBLOX_API_SECRET não configurado no bot" });
    }
    const bearer = extractBearer(req);
    if (bearer !== robloxApiSecret) {
      return res.status(401).json({ ok: false, error: "unauthorized" });
    }
    const uid = req.query.userId;
    if (!uid || !/^\d{1,20}$/.test(String(uid))) {
      return res.status(400).json({ ok: false, error: "userId inválido" });
    }
    const grants = robloxGrants.getPendingForRobloxUser(uid).map((g) => ({
      id: g.id,
      grantType: g.grantType,
      grantTier: g.grantTier,
      grantDays: g.grantDays,
      grantVehicleId: g.grantVehicleId || undefined,
      grantMoneyAmount: g.grantMoneyAmount != null ? g.grantMoneyAmount : undefined,
      grantXpAmount: g.grantXpAmount != null ? g.grantXpAmount : undefined,
    }));
    if (grants.length) {
      console.log(`[roblox] pending-grants userId=${uid} → ${grants.length} pendente(s)`);
    }
    return res.json({ ok: true, grants });
  });

  /**
   * POST /roblox/ack-grants — body: { grantIds: string[] }
   */
  app.post("/roblox/ack-grants", (req, res) => {
    if (!robloxApiSecret) {
      return res.status(503).json({ ok: false, error: "ROBLOX_API_SECRET não configurado no bot" });
    }
    const bearer = extractBearer(req);
    if (bearer !== robloxApiSecret) {
      return res.status(401).json({ ok: false, error: "unauthorized" });
    }
    const ids = req.body && Array.isArray(req.body.grantIds) ? req.body.grantIds : [];
    const n = robloxGrants.acknowledgeByIds(ids);
    return res.json({ ok: true, acknowledged: n });
  });

  /**
   * POST /roblox/requeue-from-stripe-session — recuperação manual da fila VIP (ex.: Render apagou data/roblox-pending-grants.json).
   * Header: Authorization: Bearer ROBLOX_API_SECRET
   * Body: { sessionId: "cs_..." }
   */
  app.post("/roblox/requeue-from-stripe-session", async (req, res) => {
    if (!robloxApiSecret) {
      return res.status(503).json({ ok: false, error: "ROBLOX_API_SECRET não configurado no bot" });
    }
    const bearer = extractBearer(req);
    if (bearer !== robloxApiSecret) {
      return res.status(401).json({ ok: false, error: "unauthorized" });
    }
    if (!stripe) {
      return res.status(503).json({ ok: false, error: "STRIPE_SECRET_KEY não configurada" });
    }
    const sessionId = req.body && req.body.sessionId;
    if (!sessionId || typeof sessionId !== "string" || !sessionId.startsWith("cs_")) {
      return res.status(400).json({ ok: false, error: "sessionId inválido" });
    }
    try {
      const session = await stripe.checkout.sessions.retrieve(sessionId);
      if (session.payment_status !== "paid") {
        return res.json({ ok: false, reason: "not_paid", payment_status: session.payment_status });
      }
      maybeQueueRobloxGrant(session);
      console.log(`[roblox] requeue-from-stripe-session: ${sessionId.slice(0, 14)}…`);
      return res.json({ ok: true });
    } catch (e) {
      console.error("[roblox] requeue-from-stripe-session:", e);
      return res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });

  /**
   * Confirmação pela página pagamento-ok (não depende do webhook / whsec).
   * POST /stripe/notify-from-session  Body: { sessionId: "cs_test_..." }
   */
  app.post("/stripe/notify-from-session", async (req, res) => {
    if (!stripe) {
      return res.status(503).json({ ok: false, error: "STRIPE_SECRET_KEY não configurada" });
    }
    const sessionId = req.body && req.body.sessionId;
    if (!sessionId || typeof sessionId !== "string" || !sessionId.startsWith("cs_")) {
      return res.status(400).json({ ok: false, error: "sessionId inválido" });
    }
    console.log(`[stripe] notify-from-session: ${sessionId.slice(0, 14)}…`);
    try {
      const session = await stripe.checkout.sessions.retrieve(sessionId);
      const result = await tryNotifyDiscordFromCheckoutSession(client, session, "pagamento-ok");
      // Não misturar { ok: true } com result: result já traz ok/reason e sobrescrever quebrava o cliente.
      return res.json(result);
    } catch (e) {
      console.error("[stripe] notify-from-session:", e);
      return res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });

  /**
   * GET /auth/me — valida Bearer (sessão OAuth do site)
   */
  app.get("/auth/me", (req, res) => {
    const bearer = extractBearer(req);
    if (!bearer) {
      return res.status(401).json({ ok: false, error: "no_session" });
    }
    const sess = verifyDiscordSession(bearer, sessionSigningSecret);
    if (!sess) {
      return res.status(401).json({ ok: false, error: "invalid_session" });
    }
    const avatarUrl = sess.avatar
      ? `https://cdn.discordapp.com/avatars/${sess.sub}/${sess.avatar}.png?size=64`
      : null;
    return res.json({
      ok: true,
      id: sess.sub,
      username: sess.username,
      global_name: sess.global_name,
      avatarUrl,
    });
  });

  /**
   * GET /auth/discord/login?next=vip.html — redireciona para Discord OAuth2
   */
  app.get("/auth/discord/login", (req, res) => {
    if (!discordClientId || !discordClientSecret) {
      return res
        .status(503)
        .send("Defina DISCORD_CLIENT_SECRET e CLIENT_ID no .env para login com Discord.");
    }
    const nextRaw = typeof req.query.next === "string" ? req.query.next : "index.html";
    const state = signOAuthState({ next: safeNextPath(nextRaw) }, sessionSigningSecret);
    const url =
      "https://discord.com/api/oauth2/authorize?client_id=" +
      encodeURIComponent(discordClientId) +
      "&redirect_uri=" +
      encodeURIComponent(oauthRedirectUri) +
      "&response_type=code&scope=identify&state=" +
      encodeURIComponent(state);
    res.redirect(302, url);
  });

  /**
   * GET /auth/discord/callback — troca code por sessão e redireciona ao site com #token=
   */
  app.get("/auth/discord/callback", async (req, res) => {
    const err = req.query.error;
    if (err) {
      console.warn("[auth] Discord OAuth error:", err);
      return res.status(400).send(`Discord OAuth: ${err}`);
    }
    const code = req.query.code;
    const stateQ = req.query.state;
    if (!code || typeof code !== "string" || !stateQ || typeof stateQ !== "string") {
      return res.status(400).send("Parâmetros OAuth em falta.");
    }
    const state = verifyOAuthState(stateQ, sessionSigningSecret);
    if (!state) {
      return res.status(400).send("Estado OAuth inválido ou expirado.");
    }
    if (!discordClientId || !discordClientSecret) {
      return res.status(503).send("OAuth não configurado.");
    }
    try {
      const tok = await exchangeDiscordOAuthCode(code);
      const user = await discordFetchMe(tok.access_token);
      const token = signDiscordSession(user, sessionSigningSecret);
      const next = safeNextPath(state.next || "index.html");
      const hash = "#token=" + encodeURIComponent(token);
      res.redirect(302, `${siteBaseUrl}/auth-callback.html?next=${encodeURIComponent(next)}${hash}`);
    } catch (e) {
      console.error("[auth] callback:", e);
      res.status(500).send(String(e.message || e));
    }
  });

  /**
   * POST /stripe/create-checkout-session
   * Body: { discordUserId?, itemName, amountCents?, guildId?, itemImageUrl?, discordSessionToken? }
   * Header: Authorization: Bearer <sessão> (preferido)
   * amountCents = valor em centavos BRL (mín. 50)
   */
  app.post("/stripe/create-checkout-session", async (req, res) => {
    if (!stripe) {
      return res.status(503).json({ ok: false, error: "STRIPE_SECRET_KEY não configurada no .env" });
    }

    const bearer = extractBearer(req) || String(req.body.discordSessionToken || "").trim();
    const sess = bearer ? verifyDiscordSession(bearer, sessionSigningSecret) : null;

    let resolvedDiscordUserId = null;
    if (sess?.sub) {
      resolvedDiscordUserId = sess.sub;
    } else if (discordClientSecret && !allowManualDiscordId) {
      return res.status(401).json({ ok: false, error: "login_discord_obrigatorio" });
    } else if (req.body.discordUserId) {
      resolvedDiscordUserId = String(req.body.discordUserId);
    }

    const guildId = req.body.guildId || defaultGuildId;
    let itemImageUrl = String(req.body.itemImageUrl || "").trim();
    if (itemImageUrl.length > 500) itemImageUrl = itemImageUrl.slice(0, 500);
    if (itemImageUrl && !/^https?:\/\//i.test(itemImageUrl)) itemImageUrl = "";

    /** @type {Array<{ itemName: string, amountCents: number, quantity: number, itemImageUrl?: string, grantTier?: string, grantType?: string, grantDays?: number }>} */
    let items = [];
    if (Array.isArray(req.body.items) && req.body.items.length) {
      items = req.body.items.slice(0, 20).map((raw, idx) => {
        const itemName = String(raw && raw.itemName ? raw.itemName : `Item ${idx + 1}`).slice(0, 200);
        let amountCents = parseInt(raw && raw.amountCents, 10);
        if (Number.isNaN(amountCents) || amountCents < 50) amountCents = 100;
        let quantity = parseInt(raw && raw.quantity, 10);
        if (Number.isNaN(quantity) || quantity < 1) quantity = 1;
        if (quantity > 30) quantity = 30;
        const grantTier = String((raw && raw.grantTier) || "").trim();
        const grantVehicleId = String((raw && raw.grantVehicleId) || "")
          .trim()
          .slice(0, 64);
        const grantType = String((raw && raw.grantType) || "vip").trim().slice(0, 32) || "vip";
        let grantMoneyAmount = parseInt(raw && raw.grantMoneyAmount, 10);
        if (Number.isNaN(grantMoneyAmount)) grantMoneyAmount = 0;
        let grantXpAmount = parseInt(raw && raw.grantXpAmount, 10);
        if (Number.isNaN(grantXpAmount)) grantXpAmount = 0;
        let grantDays = parseInt(raw && raw.grantDays, 10);
        if (Number.isNaN(grantDays)) grantDays = 0;
        grantDays = Math.max(0, Math.min(3650, grantDays));
        let image = String((raw && raw.itemImageUrl) || "").trim();
        if (image.length > 500) image = image.slice(0, 500);
        if (image && !/^https?:\/\//i.test(image)) image = "";
        return {
          itemName,
          amountCents,
          quantity,
          itemImageUrl: image || undefined,
          grantTier: grantTier || undefined,
          grantVehicleId: grantVehicleId || undefined,
          grantType: grantType || undefined,
          grantMoneyAmount,
          grantXpAmount,
          grantDays,
        };
      });
    } else {
      let amountCents = parseInt(req.body.amountCents, 10);
      if (Number.isNaN(amountCents) || amountCents < 50) amountCents = 100;
      const grantTierRaw = String(req.body.grantTier || "").trim();
      const grantVehicleRaw = String(req.body.grantVehicleId || "")
        .trim()
        .slice(0, 64);
      const grantTypeRaw = String(req.body.grantType || "vip").trim().slice(0, 32);
      let grantMoneyRaw = parseInt(req.body.grantMoneyAmount, 10);
      if (Number.isNaN(grantMoneyRaw)) grantMoneyRaw = 0;
      let grantXpRaw = parseInt(req.body.grantXpAmount, 10);
      if (Number.isNaN(grantXpRaw)) grantXpRaw = 0;
      let grantDaysRaw = parseInt(req.body.grantDays, 10);
      if (Number.isNaN(grantDaysRaw)) grantDaysRaw = 0;
      grantDaysRaw = Math.max(0, Math.min(3650, grantDaysRaw));
      items = [
        {
          itemName: String(req.body.itemName || "Item").slice(0, 200),
          amountCents,
          quantity: 1,
          itemImageUrl: itemImageUrl || undefined,
          grantTier: grantTierRaw || undefined,
          grantVehicleId: grantVehicleRaw || undefined,
          grantType: grantTypeRaw || undefined,
          grantMoneyAmount: grantMoneyRaw,
          grantXpAmount: grantXpRaw,
          grantDays: grantDaysRaw,
        },
      ];
    }

    const robloxUserIdBody = String(req.body.robloxUserId || "").trim();
    function itemNeedsRobloxDelivery(it) {
      const gt = String(it.grantType || "vip").trim().toLowerCase();
      if (gt === "vehicle" && it.grantVehicleId && robloxGrants.isValidVehicleId(String(it.grantVehicleId))) {
        return true;
      }
      if (gt === "currency" && robloxGrants.isValidMoneyAmount(it.grantMoneyAmount)) {
        return true;
      }
      if (gt === "xp" && robloxGrants.isValidXpAmount(it.grantXpAmount)) {
        return true;
      }
      if (gt === "economy") {
        const m = Math.floor(Number(it.grantMoneyAmount) || 0);
        const x = Math.floor(Number(it.grantXpAmount) || 0);
        if (m < 1 && x < 1) return false;
        if (m >= 1 && !robloxGrants.isValidMoneyAmount(m)) return false;
        if (x >= 1 && !robloxGrants.isValidXpAmount(x)) return false;
        return true;
      }
      return Boolean(it.grantTier && robloxGrants.VALID_TIERS[String(it.grantTier)]);
    }
    const grantItems = items.filter(itemNeedsRobloxDelivery);
    for (const gi of grantItems) {
      const gt = String(gi.grantType || "vip").trim().toLowerCase();
      if (gt === "vehicle") {
        if (!robloxGrants.isValidVehicleId(String(gi.grantVehicleId || ""))) {
          return res.status(400).json({
            ok: false,
            error: "grantVehicleId inválido (use NomeInventario do catálogo: letras, números, _ e -)",
          });
        }
      } else if (gt === "currency") {
        if (!robloxGrants.isValidMoneyAmount(gi.grantMoneyAmount)) {
          return res.status(400).json({ ok: false, error: "grantMoneyAmount inválido (1 a 2e9)" });
        }
      } else if (gt === "xp") {
        if (!robloxGrants.isValidXpAmount(gi.grantXpAmount)) {
          return res.status(400).json({ ok: false, error: "grantXpAmount inválido (1 a 2e9)" });
        }
      } else if (gt === "economy") {
        const m = Math.floor(Number(gi.grantMoneyAmount) || 0);
        const x = Math.floor(Number(gi.grantXpAmount) || 0);
        if (m < 0 || x < 0 || m > 2e9 || x > 2e9) {
          return res.status(400).json({ ok: false, error: "economy: valores fora do intervalo" });
        }
        if (m < 1 && x < 1) {
          return res.status(400).json({ ok: false, error: "economy: indique dinheiro ou XP (≥1)" });
        }
        if (m >= 1 && !robloxGrants.isValidMoneyAmount(m)) {
          return res.status(400).json({ ok: false, error: "grantMoneyAmount inválido" });
        }
        if (x >= 1 && !robloxGrants.isValidXpAmount(x)) {
          return res.status(400).json({ ok: false, error: "grantXpAmount inválido" });
        }
      } else if (!robloxGrants.VALID_TIERS[String(gi.grantTier)]) {
        return res.status(400).json({ ok: false, error: "grantTier deve ser Bronze, Gold ou Diamante" });
      }
    }
    if (grantItems.length && (!robloxUserIdBody || !/^\d{1,20}$/.test(robloxUserIdBody))) {
      return res.status(400).json({ ok: false, error: "robloxUserId obrigatório para entrega no jogo" });
    }

    if (!resolvedDiscordUserId || !/^\d{17,20}$/.test(String(resolvedDiscordUserId))) {
      return res.status(400).json({ ok: false, error: "discordUserId inválido ou sessão em falta" });
    }
    if (!guildId) {
      return res.status(400).json({ ok: false, error: "missing guildId" });
    }

    try {
      const summaryItemName =
        items.length === 1
          ? items[0].itemName
          : `${items.length} itens no carrinho (${items.reduce((acc, it) => acc + it.quantity, 0)} unidade(s))`;
      const meta = {
        discord_user_id: String(resolvedDiscordUserId),
        item_name: summaryItemName.slice(0, 200),
        guild_id: String(guildId),
      };
      const firstImage = items.find((it) => it.itemImageUrl)?.itemImageUrl || itemImageUrl;
      if (firstImage) {
        meta.item_image_url = firstImage;
      }
      if (grantItems.length && robloxUserIdBody) {
        meta.roblox_user_id = robloxUserIdBody;
        if (grantItems.length === 1) {
          const g0 = grantItems[0];
          const g0t = String(g0.grantType || "vip").trim().toLowerCase();
          if (g0t === "vehicle" && g0.grantVehicleId) {
            meta.grant_type = "vehicle";
            meta.grant_vehicle_id = String(g0.grantVehicleId).slice(0, 64);
            meta.grant_days = "0";
          } else if (g0t === "currency" && robloxGrants.isValidMoneyAmount(g0.grantMoneyAmount)) {
            meta.grant_type = "currency";
            meta.grant_money_amount = String(Math.floor(Number(g0.grantMoneyAmount) || 0));
            meta.grant_days = "0";
          } else if (g0t === "xp" && robloxGrants.isValidXpAmount(g0.grantXpAmount)) {
            meta.grant_type = "xp";
            meta.grant_xp_amount = String(Math.floor(Number(g0.grantXpAmount) || 0));
            meta.grant_days = "0";
          } else if (g0t === "economy") {
            meta.grant_type = "economy";
            meta.grant_money_amount = String(Math.floor(Number(g0.grantMoneyAmount) || 0));
            meta.grant_xp_amount = String(Math.floor(Number(g0.grantXpAmount) || 0));
            meta.grant_days = "0";
          } else {
            meta.grant_type = g0.grantType || "vip";
            meta.grant_tier = g0.grantTier;
            meta.grant_days = String(g0.grantDays || 0);
          }
        } else {
          const compact = grantItems.map((g) => {
            const gt = String(g.grantType || "vip").trim().toLowerCase();
            if (gt === "vehicle" && g.grantVehicleId) {
              return { grantType: "vehicle", grantVehicleId: String(g.grantVehicleId).slice(0, 64), grantDays: 0 };
            }
            if (gt === "currency" && robloxGrants.isValidMoneyAmount(g.grantMoneyAmount)) {
              return { grantType: "currency", grantMoneyAmount: Math.floor(Number(g.grantMoneyAmount) || 0), grantDays: 0 };
            }
            if (gt === "xp" && robloxGrants.isValidXpAmount(g.grantXpAmount)) {
              return { grantType: "xp", grantXpAmount: Math.floor(Number(g.grantXpAmount) || 0), grantDays: 0 };
            }
            if (gt === "economy") {
              return {
                grantType: "economy",
                grantMoneyAmount: Math.floor(Number(g.grantMoneyAmount) || 0),
                grantXpAmount: Math.floor(Number(g.grantXpAmount) || 0),
                grantDays: 0,
              };
            }
            return {
              grantType: g.grantType || "vip",
              grantTier: g.grantTier,
              grantDays: g.grantDays || 0,
            };
          });
          const asJson = JSON.stringify(compact);
          if (asJson.length > 500) {
            return res.status(400).json({
              ok: false,
              error:
                "Carrinho grande demais para metadata Stripe (máx. 500 caracteres). Finalize em duas compras ou reduza itens.",
            });
          }
          meta.roblox_grants_json = asJson;
        }
      }
      const couponCode = String(req.body.couponCode || "").trim().toUpperCase();
      const discountPercent = parseInt(req.body.discountPercent, 10);
      const discountCents = parseInt(req.body.discountCents, 10);
      if (couponCode) {
        meta.coupon_code = couponCode.slice(0, 50);
      }
      if (!Number.isNaN(discountPercent) && discountPercent > 0) {
        meta.discount_percent = String(Math.min(90, discountPercent));
      }
      if (!Number.isNaN(discountCents) && discountCents > 0) {
        meta.discount_cents = String(Math.min(99999999, discountCents));
      }

      const session = await stripe.checkout.sessions.create({
        mode: "payment",
        payment_method_types: ["card"],
        line_items: items.map((it) => ({
          price_data: {
            currency: "brl",
            product_data: {
              name: String(it.itemName || "Item").slice(0, 120),
            },
            unit_amount: it.amountCents,
          },
          quantity: it.quantity,
        })),
        metadata: meta,
        // URL sem ".html" evita redirect 301 do servidor estático que costuma perder ?session_id=...
        success_url: `${siteBaseUrl}/pagamento-ok?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${siteBaseUrl}/pagamento-cancelado`,
      });

      return res.json({ ok: true, url: session.url, sessionId: session.id });
    } catch (e) {
      console.error("[stripe] create session:", e);
      return res.status(500).json({ ok: false, error: String(e.message || e) });
    }
  });

  /**
   * POST /webhooks/venda
   * Body: { guildId?, discordUserId, itemName, orderId?, quantity?, kind?: "sale"|"nitro", note? }
   */
  app.post("/webhooks/venda", async (req, res) => {
    if (!checkAuth(req)) {
      return unauthorized(res);
    }

    try {
      await deliverSaleToDiscord(client, req.body, false);
      return res.json({ ok: true });
    } catch (e) {
      const status = e.status || 500;
      if (status >= 500) {
        console.error("webhook venda:", e);
      }
      return res.status(status).json({ ok: false, error: String(e.message || e) });
    }
  });

  /**
   * POST /webhooks/demo-venda — simulação sem Stripe
   */
  app.post("/webhooks/demo-venda", async (req, res) => {
    if (!demoSaleKey) {
      return res.status(404).json({ ok: false, error: "demo disabled (defina DEMO_SALE_KEY no .env)" });
    }
    const k = String(req.headers["x-demo-key"] || "").trim();
    if (k !== demoSaleKey) {
      return res.status(401).json({ ok: false, error: "invalid X-Demo-Key" });
    }

    try {
      await deliverSaleToDiscord(client, req.body, true);
      return res.json({ ok: true });
    } catch (e) {
      const status = e.status || 500;
      if (status >= 500) {
        console.error("webhook demo-venda:", e);
      }
      return res.status(status).json({ ok: false, error: String(e.message || e) });
    }
  });

  app.get("/health", (_req, res) => {
    res.json({
      ok: true,
      time: new Date().toISOString(),
      uptimeSeconds: Math.floor(process.uptime()),
      version: String(process.env.GEAR_BOT_VERSION || botPackageVersion || "unknown"),
      bot: client.user?.tag || "starting",
      demo: Boolean(demoSaleKey),
      stripe: Boolean(stripeSecretKey),
      stripeWebhook: Boolean(stripeWebhookSecret),
      discordOAuth: Boolean(discordClientSecret && discordClientId),
      robloxGrantsApi: Boolean(robloxApiSecret),
      salesLogChannelFromEnv: Boolean(getSalesLogChannelIdFromEnv()),
      fullStaffLogChannelFromEnv: Boolean(getFullStaffLogChannelIdFromEnv()),
    });
  });

  const server = app.listen(port, () => {
    const salesCh = getSalesLogChannelIdFromEnv();
    if (salesCh) {
      console.log(`[discord] SALES_LOG_CHANNEL_ID ativo (termina …${salesCh.slice(-4)})`);
    } else {
      console.warn(
        "[discord] SALES_LOG_CHANNEL_ID vazio — vendas Stripe não têm canal. No Render: Environment (o .env local não sobe no deploy)."
      );
    }
    const fullStaffCh = getFullStaffLogChannelIdFromEnv();
    if (fullStaffCh) {
      console.log(`[discord] FULL_TRANSACTION_LOG_CHANNEL_ID ativo (termina …${fullStaffCh.slice(-4)})`);
    }
    console.log(`HTTP webhook em http://0.0.0.0:${port}  (GET /health  |  POST /webhooks/venda)`);
    if (demoSaleKey) {
      console.log(`  + demo: POST /webhooks/demo-venda  (header X-Demo-Key)`);
    }
    if (stripe) {
      console.log(`  + stripe: POST /stripe/create-checkout-session`);
      console.log(`  + stripe: POST /stripe/notify-from-session  (fallback quando webhook falha)`);
      console.log(`  + stripe: POST /webhooks/stripe  (precisa STRIPE_WEBHOOK_SECRET = whsec_...)`);
    }
    if (discordClientSecret && discordClientId) {
      console.log(`  + auth: GET /auth/discord/login  (adicione redirect no Discord: ${oauthRedirectUri})`);
    } else if (stripe) {
      console.log(
        `  [aviso] Sem DISCORD_CLIENT_SECRET — checkout aceita ID manual no modal. Para exigir login OAuth, defina o secret.`
      );
    }
    if (robloxApiSecret) {
      console.log(
        `  + roblox: GET /roblox/lookup-username  |  GET/POST /roblox/pending-grants + /roblox/ack-grants  |  POST /roblox/requeue-from-stripe-session (Bearer ROBLOX_API_SECRET)`
      );
    }
  });

  return server;
}

module.exports = { startHttpServer };
