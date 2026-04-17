/**
 * Checkout: Stripe (teste/produção) ou simulação Discord (GEAR_CHECKOUT_DEMO).
 * Prioridade: GEAR_STRIPE.enabled > GEAR_CHECKOUT_DEMO.enabled > link normal.
 */
(function () {
  let pendingAnchor = null;
  let submitWired = false;
  /** Conta Roblox confirmada (userId numérico) após preview + botão Confirmar */
  let robloxConfirmedUserId = null;
  let lastRobloxLookup = null;
  function getDemoCfg() {
    return typeof window.GEAR_CHECKOUT_DEMO === "object" && window.GEAR_CHECKOUT_DEMO !== null
      ? window.GEAR_CHECKOUT_DEMO
      : null;
  }

  function getStripeCfg() {
    return typeof window.GEAR_STRIPE === "object" && window.GEAR_STRIPE !== null
      ? window.GEAR_STRIPE
      : null;
  }

  function setDialogStripeUi() {
    const t = document.getElementById("gear-demo-checkout-title");
    const h = document.getElementById("gear-demo-hint");
    const s = document.getElementById("gear-demo-submit");
    if (t) t.textContent = "Pagamento com cartão";
    if (h) {
      h.textContent =
        "Você será enviado ao Stripe (sandbox). Cartão de teste: 4242 4242 4242 4242, qualquer data futura, CVC qualquer. Depois do pagamento, o bot avisa no Discord se o webhook estiver configurado.";
    }
    if (s) s.textContent = "Continuar para o Stripe";
  }

  function setDialogDemoUi() {
    const t = document.getElementById("gear-demo-checkout-title");
    const h = document.getElementById("gear-demo-hint");
    const s = document.getElementById("gear-demo-submit");
    if (t) t.textContent = "Simular compra";
    if (h) {
      h.textContent =
        "Modo teste: nenhum pagamento real. Envia só um aviso no Discord.";
    }
    if (s) s.textContent = "Confirmar simulação";
  }

  function resolveItemImageUrl(anchor) {
    const raw = anchor && anchor.getAttribute("data-checkout-image");
    if (!raw || !String(raw).trim()) return "";
    try {
      return new URL(String(raw).trim(), window.location.origin).href;
    } catch (_) {
      return "";
    }
  }

  async function onSubmit() {
    const dlg = document.getElementById("gear-demo-checkout");
    const submit = document.getElementById("gear-demo-submit");
    const errEl = document.getElementById("gear-demo-err");
    const input = document.getElementById("gear-demo-discord-id");
    const itemName = (pendingAnchor && pendingAnchor.getAttribute("data-checkout-item")) || "Item";
    const amountCents = parseInt(
      (pendingAnchor && pendingAnchor.getAttribute("data-checkout-cents")) || "100",
      10
    );
    const itemImageUrl = resolveItemImageUrl(pendingAnchor);

    const auth = window.GearDiscordAuth;
    const sessionToken = auth && typeof auth.getToken === "function" ? auth.getToken() : null;

    const stripeCfg = getStripeCfg();
    const requireDiscordLogin = stripeCfg && stripeCfg.requireDiscordLogin !== false;

    if (stripeCfg && stripeCfg.enabled && requireDiscordLogin && !sessionToken) {
      if (errEl) {
        errEl.hidden = false;
        errEl.textContent = 'Use "Entrar com Discord" no menu (canto superior) antes de comprar.';
      }
      return;
    }

    const discordUserId = (input && input.value.trim()) || "";

    if (!sessionToken && !/^\d{17,20}$/.test(discordUserId)) {
      if (errEl) {
        errEl.hidden = false;
        errEl.textContent = "Cole um ID numérico válido (Modo desenvolvedor → Copiar ID).";
      }
      return;
    }

    if (stripeCfg && stripeCfg.enabled) {
      const apiBase = String(stripeCfg.apiBase || "http://127.0.0.1:3847").replace(/\/$/, "");
      if (submit) submit.disabled = true;
      if (errEl) errEl.hidden = true;
      try {
        const headers = { "Content-Type": "application/json" };
        if (sessionToken) {
          headers.Authorization = "Bearer " + sessionToken;
        }
        const body = {
          itemName,
          amountCents: Number.isNaN(amountCents) ? 100 : Math.max(50, amountCents),
          guildId: stripeCfg.guildId || undefined,
        };
        if (!sessionToken) {
          body.discordUserId = discordUserId;
        }
        if (itemImageUrl) {
          body.itemImageUrl = itemImageUrl;
        }
        const _sc = getStripeCfg();
        const robloxOn = _sc && _sc.robloxDeliveryEnabled !== false && pendingAnchor;
        const grantTierRaw = robloxOn && pendingAnchor.getAttribute("data-grant-tier");
        const grantTier = grantTierRaw && String(grantTierRaw).trim();
        if (grantTier) {
          if (!robloxConfirmedUserId) {
            throw new Error("Busque o seu username Roblox e confirme a conta antes de pagar.");
          }
          body.robloxUserId = String(robloxConfirmedUserId);
          body.grantTier = grantTier;
          body.grantDays = parseInt(pendingAnchor.getAttribute("data-grant-days") || "1", 10) || 1;
          body.grantType = (pendingAnchor.getAttribute("data-grant-type") || "vip").trim() || "vip";
        }
        const res = await fetch(`${apiBase}/stripe/create-checkout-session`, {
          method: "POST",
          headers,
          body: JSON.stringify(body),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok || !data.url) {
          if (data.error === "login_discord_obrigatorio") {
            throw new Error("O servidor exige login Discord. Defina DISCORD_CLIENT_SECRET no bot e entre pelo menu.");
          }
          throw new Error(data.error || res.statusText || "Falha ao criar sessão Stripe");
        }
        if (data.sessionId) {
          try {
            sessionStorage.setItem("gear_stripe_checkout_session", data.sessionId);
          } catch (_) {
            /* ignore */
          }
        }
        window.location.href = data.url;
      } catch (e) {
        if (errEl) {
          errEl.hidden = false;
          errEl.textContent =
            String(e.message || e) +
            " — Bot rodando? STRIPE_SECRET_KEY no .env? Veja js/config.js (GEAR_STRIPE).";
        }
        if (submit) submit.disabled = false;
      }
      return;
    }

    const cfg = getDemoCfg();
    if (!cfg || !cfg.enabled || !pendingAnchor) return;

    if (!cfg.demoKey || String(cfg.demoKey).trim() === "") {
      if (errEl) {
        errEl.hidden = false;
        errEl.textContent =
          "Defina GEAR_CHECKOUT_DEMO.demoKey em config.js (igual a DEMO_SALE_KEY no bot).";
      }
      return;
    }

    const apiBase = String(cfg.apiBase || "http://127.0.0.1:3847").replace(/\/$/, "");
    if (submit) submit.disabled = true;
    if (errEl) errEl.hidden = true;

    try {
      const res = await fetch(`${apiBase}/webhooks/demo-venda`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Demo-Key": String(cfg.demoKey).trim(),
        },
        body: JSON.stringify({
          guildId: cfg.guildId || undefined,
          discordUserId,
          itemName,
          orderId: "demo-site-" + Date.now(),
          quantity: 1,
          kind: "sale",
          note: "Simulação pelo site Gear UP (checkout demo)",
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(data.error || res.statusText || "Erro no servidor");
      }
      if (dlg && typeof dlg.close === "function") dlg.close();
      alert("Simulação enviada. Confira o canal de log de vendas no Discord.");
    } catch (e) {
      if (errEl) {
        errEl.hidden = false;
        errEl.textContent =
          String(e.message || e) +
          " — Bot a correr? DEMO_SALE_KEY e CORS ok? Veja comentários em config.js.";
      }
    } finally {
      if (submit) submit.disabled = false;
    }
  }

  function ensureDialog() {
    let dlg = document.getElementById("gear-demo-checkout");
    if (dlg) return dlg;

    dlg = document.createElement("dialog");
    dlg.id = "gear-demo-checkout";
    dlg.className = "gear-demo-checkout";
    dlg.setAttribute("aria-labelledby", "gear-demo-checkout-title");
    dlg.innerHTML = `
<div class="gear-demo-checkout__backdrop" aria-hidden="true"></div>
<div class="gear-demo-checkout__surface">
  <button type="button" class="gear-demo-checkout__close" aria-label="Fechar">&times;</button>
  <h2 class="gear-demo-checkout__title" id="gear-demo-checkout-title">Comprar</h2>
  <p class="gear-demo-checkout__hint" id="gear-demo-hint"></p>
  <p class="gear-demo-checkout__item" id="gear-demo-item-label"></p>
  <div id="gear-demo-discord-row">
    <label class="gear-demo-checkout__label" for="gear-demo-discord-id">Seu ID do Discord (numérico)</label>
    <input type="text" id="gear-demo-discord-id" class="gear-demo-checkout__input" placeholder="Ex.: 123456789012345678" inputmode="numeric" autocomplete="off" />
  </div>
  <div id="gear-roblox-row" class="gear-roblox-row" hidden>
    <p class="gear-demo-checkout__label">Conta Roblox (entrega no jogo)</p>
    <div class="gear-roblox-searchline">
      <input type="text" id="gear-roblox-username" class="gear-demo-checkout__input" placeholder="Username ex.: CheechSC" autocomplete="off" />
      <button type="button" class="btn btn--ghost" id="gear-roblox-search">Buscar</button>
    </div>
    <div id="gear-roblox-preview" class="gear-roblox-preview" hidden></div>
    <button type="button" class="btn btn--primary gear-roblox-confirm" id="gear-roblox-confirm" hidden>Confirmar esta conta</button>
  </div>
  <p class="gear-demo-checkout__err" id="gear-demo-err" hidden></p>
  <div class="gear-demo-checkout__actions">
    <button type="button" class="btn btn--ghost" id="gear-demo-cancel">Cancelar</button>
    <button type="button" class="btn btn--primary" id="gear-demo-submit">Continuar</button>
  </div>
</div>`;
    document.body.appendChild(dlg);

    if (!dlg.dataset.gearRobloxWired) {
      dlg.dataset.gearRobloxWired = "1";
      document.getElementById("gear-roblox-search").addEventListener("click", async function () {
        const inp = document.getElementById("gear-roblox-username");
        const prev = document.getElementById("gear-roblox-preview");
        const conf = document.getElementById("gear-roblox-confirm");
        const errEl = document.getElementById("gear-demo-err");
        const name = (inp && inp.value.trim()) || "";
        const stripeCfg = getStripeCfg();
        const apiBase = String(stripeCfg.apiBase || "http://127.0.0.1:3847").replace(/\/$/, "");
        robloxConfirmedUserId = null;
        lastRobloxLookup = null;
        if (conf) conf.hidden = true;
        if (prev) {
          prev.hidden = true;
          prev.innerHTML = "";
        }
        if (!name) {
          if (errEl) {
            errEl.hidden = false;
            errEl.textContent = "Digite o username Roblox.";
          }
          return;
        }
        if (errEl) errEl.hidden = true;
        try {
          const r = await fetch(
            apiBase + "/roblox/lookup-username?username=" + encodeURIComponent(name)
          );
          const data = await r.json().catch(() => ({}));
          if (!r.ok || !data.ok) {
            throw new Error(data.error === "not_found" ? "Usuário não encontrado." : data.error || "Falha na busca");
          }
          lastRobloxLookup = data;
          if (prev) {
            prev.innerHTML =
              (data.imageUrl
                ? '<img class="gear-roblox-avatar" src="' +
                  String(data.imageUrl).replace(/"/g, "") +
                  '" alt="" width="72" height="72" />'
                : "") +
              '<p class="gear-roblox-uname">@' +
              String(data.username || "").replace(/</g, "") +
              "</p>";
            prev.hidden = false;
          }
          if (conf) conf.hidden = false;
        } catch (e) {
          if (errEl) {
            errEl.hidden = false;
            errEl.textContent = String(e.message || e);
          }
        }
      });
      document.getElementById("gear-roblox-confirm").addEventListener("click", function () {
        if (!lastRobloxLookup || !lastRobloxLookup.userId) return;
        robloxConfirmedUserId = String(lastRobloxLookup.userId);
        const conf = document.getElementById("gear-roblox-confirm");
        const prev = document.getElementById("gear-roblox-preview");
        if (conf) {
          conf.textContent = "Conta confirmada ✓";
          conf.disabled = true;
        }
        if (prev) {
          const p = prev.querySelector(".gear-roblox-uname");
          if (p) p.textContent = p.textContent + " — confirmado para entrega";
        }
      });
    }

    dlg.querySelector(".gear-demo-checkout__backdrop").addEventListener("click", () => dlg.close());
    dlg.querySelector(".gear-demo-checkout__close").addEventListener("click", () => dlg.close());
    dlg.querySelector("#gear-demo-cancel").addEventListener("click", () => dlg.close());

    if (!submitWired) {
      submitWired = true;
      document.getElementById("gear-demo-submit").addEventListener("click", onSubmit);
    }

    return dlg;
  }

  function syncCheckoutDiscordRow(useStripe) {
    const row = document.getElementById("gear-demo-discord-row");
    if (!row) return;
    const stripeCfg = getStripeCfg();
    const requireLogin = stripeCfg && stripeCfg.requireDiscordLogin !== false;
    const auth = window.GearDiscordAuth;
    const token = auth && typeof auth.getToken === "function" ? auth.getToken() : null;
    if (useStripe && requireLogin) {
      row.hidden = true;
    } else {
      row.hidden = false;
    }
    syncCheckoutRobloxRow(useStripe);
  }

  function syncCheckoutRobloxRow(useStripe) {
    const row = document.getElementById("gear-roblox-row");
    const conf = document.getElementById("gear-roblox-confirm");
    const prev = document.getElementById("gear-roblox-preview");
    const inp = document.getElementById("gear-roblox-username");
    if (!row) return;
    const stripeCfg = getStripeCfg();
    const robloxOn = stripeCfg && stripeCfg.robloxDeliveryEnabled !== false;
    const tier =
      pendingAnchor && pendingAnchor.getAttribute("data-grant-tier") && String(pendingAnchor.getAttribute("data-grant-tier")).trim();
    if (useStripe && robloxOn && tier) {
      row.hidden = false;
    } else {
      row.hidden = true;
    }
    robloxConfirmedUserId = null;
    lastRobloxLookup = null;
    if (inp) inp.value = "";
    if (prev) {
      prev.hidden = true;
      prev.innerHTML = "";
    }
    if (conf) {
      conf.hidden = true;
      conf.disabled = false;
      conf.textContent = "Confirmar esta conta";
    }
  }

  document.addEventListener(
    "click",
    function (e) {
      const stripeCfg = getStripeCfg();
      const demoCfg = getDemoCfg();
      const useStripe = stripeCfg && stripeCfg.enabled;
      const useDemo = demoCfg && demoCfg.enabled;
      if (!useStripe && !useDemo) return;

      const a = e.target.closest("a.js-checkout-buy");
      if (!a) return;

      e.preventDefault();
      e.stopPropagation();

      pendingAnchor = a;
      if (useStripe) setDialogStripeUi();
      else setDialogDemoUi();

      const dlg = ensureDialog();
      const item = a.getAttribute("data-checkout-item") || "Item";
      const price = a.getAttribute("data-checkout-price") || "";
      const label = document.getElementById("gear-demo-item-label");
      if (label) {
        label.textContent = price ? `${item} — ${price}` : item;
      }
      const err = document.getElementById("gear-demo-err");
      if (err) {
        err.hidden = true;
        err.textContent = "";
      }
      const input = document.getElementById("gear-demo-discord-id");
      if (input) {
        input.value = "";
        input.focus();
      }
      syncCheckoutDiscordRow(useStripe);

      if (typeof dlg.showModal === "function") {
        dlg.showModal();
      }
    },
    true
  );
})();
