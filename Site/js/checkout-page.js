(function () {
  const CART_KEY = "gear_cart_items_v1";
  const COUPON_KEY = "gear_cart_coupon_v1";
  let cartItems = [];
  let robloxConfirmedUserId = null;
  let couponCode = "";
  /** @type {"card"|"pix"} */
  let selectedPaymentMethod = "card";

  function getStripeCfg() {
    return typeof window.GEAR_STRIPE === "object" && window.GEAR_STRIPE !== null ? window.GEAR_STRIPE : null;
  }

  function getPicPayCfg() {
    return typeof window.GEAR_PICPAY === "object" && window.GEAR_PICPAY !== null ? window.GEAR_PICPAY : null;
  }

  function getCouponsCfg() {
    return typeof window.GEAR_COUPONS === "object" && window.GEAR_COUPONS !== null ? window.GEAR_COUPONS : {};
  }

  function moneyBr(cents) {
    return "R$ " + (Number(cents || 0) / 100).toFixed(2).replace(".", ",");
  }

  function loadState() {
    try {
      const raw = sessionStorage.getItem(CART_KEY);
      const list = raw ? JSON.parse(raw) : [];
      cartItems = Array.isArray(list) ? list : [];
      couponCode = String(sessionStorage.getItem(COUPON_KEY) || "").trim().toUpperCase();
    } catch (_) {
      cartItems = [];
      couponCode = "";
    }
  }

  function saveState() {
    try {
      sessionStorage.setItem(CART_KEY, JSON.stringify(cartItems));
      sessionStorage.setItem(COUPON_KEY, couponCode);
      window.dispatchEvent(new CustomEvent("gear-cart-updated"));
    } catch (_) {
      /* ignore */
    }
  }

  function couponPercent(code) {
    const pct = parseInt(getCouponsCfg()[String(code || "").trim().toUpperCase()], 10);
    if (Number.isNaN(pct)) return 0;
    return Math.max(0, Math.min(90, pct));
  }

  function lineUnitCents(item, method) {
    const fallback = Math.max(50, parseInt(item.amountCents, 10) || 100);
    const card = Math.max(50, parseInt(item.cardAmountCents, 10) || fallback);
    const base = Math.max(50, parseInt(item.baseAmountCents, 10) || fallback);
    return method === "pix" ? base : card;
  }

  function totalsFor(method) {
    const subtotal = cartItems.reduce((acc, it) => {
      const qty = Math.max(1, parseInt(it.quantity, 10) || 1);
      const cents = lineUnitCents(it, method);
      return acc + qty * cents;
    }, 0);
    const pct = couponPercent(couponCode);
    const discount = Math.floor((subtotal * pct) / 100);
    return { subtotal, pct, discount, total: Math.max(0, subtotal - discount) };
  }

  function totals() {
    return totalsFor(selectedPaymentMethod);
  }

  function render() {
    const list = document.getElementById("checkout-cart-list");
    const total = document.getElementById("checkout-total");
    const couponStatus = document.getElementById("checkout-coupon-status");
    const t = totals();
    if (list) {
      if (!cartItems.length) {
        list.innerHTML = '<p class="checkout-note">Seu carrinho está vazio. Volte à loja para adicionar itens.</p>';
      } else {
        list.innerHTML = cartItems
          .map(
            (it, idx) => {
              const unit = lineUnitCents(it, selectedPaymentMethod);
              const pixUnit = lineUnitCents(it, "pix");
              const cardUnit = lineUnitCents(it, "card");
              const methodHint =
                selectedPaymentMethod === "card" && pixUnit < cardUnit
                  ? `<small>Pix: ${moneyBr(pixUnit)}</small>`
                  : "";
              return (
              `<div class="checkout-line">
                <div><strong>${it.itemName}</strong><br/><small>${moneyBr(unit)} x ${it.quantity}</small>${methodHint}</div>
                <div class="checkout-line__actions">
                  <button type="button" class="btn btn--ghost" data-dec="${idx}">-</button>
                  <button type="button" class="btn btn--ghost" data-inc="${idx}">+</button>
                  <button type="button" class="btn btn--ghost" data-rm="${idx}">x</button>
                </div>
              </div>`
              );
            }
          )
          .join("");
        list.querySelectorAll("[data-dec]").forEach((el) =>
          el.addEventListener("click", function () {
            const i = parseInt(this.getAttribute("data-dec"), 10);
            if (!cartItems[i]) return;
            cartItems[i].quantity = Math.max(1, (parseInt(cartItems[i].quantity, 10) || 1) - 1);
            saveState();
            render();
          })
        );
        list.querySelectorAll("[data-inc]").forEach((el) =>
          el.addEventListener("click", function () {
            const i = parseInt(this.getAttribute("data-inc"), 10);
            if (!cartItems[i]) return;
            cartItems[i].quantity = Math.max(1, (parseInt(cartItems[i].quantity, 10) || 1) + 1);
            saveState();
            render();
          })
        );
        list.querySelectorAll("[data-rm]").forEach((el) =>
          el.addEventListener("click", function () {
            const i = parseInt(this.getAttribute("data-rm"), 10);
            if (!cartItems[i]) return;
            cartItems.splice(i, 1);
            saveState();
            render();
          })
        );
      }
    }
    if (total) {
      const cardTotals = totalsFor("card");
      const pixTotals = totalsFor("pix");
      const pixDiscount = Math.max(0, cardTotals.total - pixTotals.total);
      if (selectedPaymentMethod === "pix") {
        total.textContent =
          t.discount > 0
            ? `Total no Pix: ${moneyBr(t.total)} — cupom ${t.pct}% aplicado`
            : `Total no Pix: ${moneyBr(t.total)}`;
        if (pixDiscount > 0) {
          total.textContent += ` (Desconto Pix aplicado: ${moneyBr(pixDiscount)})`;
        }
      } else {
        total.textContent =
          t.discount > 0
            ? `Total no cartão: ${moneyBr(t.total)} — cupom ${t.pct}% aplicado`
            : `Total no cartão: ${moneyBr(t.total)}`;
        if (pixTotals.total < cardTotals.total) {
          total.textContent += ` — no Pix fica ${moneyBr(pixTotals.total)}`;
        }
      }
    }
    if (couponStatus) {
      couponStatus.textContent =
        couponCode && t.pct === 0
          ? "Cupom inválido."
          : t.pct > 0
          ? `Cupom ${couponCode} aplicado (${t.pct}% off).`
          : "Sem cupom aplicado.";
    }
    const cInp = document.getElementById("checkout-coupon");
    if (cInp) cInp.value = couponCode;
  }

  async function refreshDiscordStatus() {
    const status = document.getElementById("checkout-discord-status");
    const btn = document.getElementById("checkout-discord-login");
    const userBox = document.getElementById("checkout-discord-user");
    const avatarEl = document.getElementById("checkout-discord-avatar");
    const nameEl = document.getElementById("checkout-discord-name");
    const auth = window.GearDiscordAuth;
    const token = auth && typeof auth.getToken === "function" ? auth.getToken() : null;
    if (!token) {
      if (status) status.textContent = "Você ainda não está logado no Discord.";
      if (btn) btn.hidden = false;
      if (userBox) userBox.hidden = true;
      return null;
    }
    try {
      const me = await auth.fetchMe();
      if (status) status.textContent = `Logado como ${me.username}.`;
      if (userBox) userBox.hidden = false;
      if (avatarEl && me.avatarUrl) {
        avatarEl.src = me.avatarUrl;
        avatarEl.alt = `Avatar de ${me.username}`;
      }
      if (nameEl) {
        nameEl.textContent = me.global_name || me.username || "Usuário";
      }
      if (btn) btn.hidden = true;
      return me;
    } catch (_) {
      if (status) status.textContent = "Sessão expirada. Faça login novamente.";
      if (btn) btn.hidden = false;
      if (userBox) userBox.hidden = true;
      return null;
    }
  }

  function requiresRobloxConfirmation() {
    return cartItems.some((it) => {
      const gt = String(it.grantType || "").trim().toLowerCase();
      if (gt === "currency" || gt === "xp" || gt === "economy") return true;
      return String(it.grantTier || "").trim() !== "" || String(it.grantVehicleId || "").trim() !== "";
    });
  }

  async function submitCheckout() {
    const errEl = document.getElementById("checkout-err");
    if (errEl) {
      errEl.hidden = true;
      errEl.textContent = "";
    }
    const stripeCfg = getStripeCfg();
    if (!stripeCfg || !stripeCfg.enabled) {
      if (errEl) {
        errEl.hidden = false;
        errEl.textContent = "O pagamento está indisponível no momento. Tente mais tarde ou fale com o suporte.";
      }
      return;
    }
    if (!cartItems.length) {
      if (errEl) {
        errEl.hidden = false;
        errEl.textContent = "Seu carrinho está vazio.";
      }
      return;
    }
    const auth = window.GearDiscordAuth;
    const token = auth && typeof auth.getToken === "function" ? auth.getToken() : null;
    if (!token) {
      if (confirm("Para finalizar, você precisa logar com Discord. Entrar agora?")) {
        const apiBase = String(stripeCfg.apiBase || "http://127.0.0.1:3847").replace(/\/$/, "");
        window.location.href = `${apiBase}/auth/discord/login?next=${encodeURIComponent("checkout.html")}`;
      }
      return;
    }
    if (requiresRobloxConfirmation() && !robloxConfirmedUserId) {
      if (errEl) {
        errEl.hidden = false;
        errEl.textContent = "Confirme a conta Roblox que vai receber a entrega (VIP, veículo, moedas ou XP).";
      }
      return;
    }
    const t = totals();
    const apiBase = String(stripeCfg.apiBase || "http://127.0.0.1:3847").replace(/\/$/, "");
    const payload = {
      guildId: stripeCfg.guildId || undefined,
      itemName: `Carrinho (${cartItems.length} item(ns))`,
      amountCents: t.total,
      items: cartItems.map((it) => ({
        itemName: it.itemName,
        amountCents: lineUnitCents(it, selectedPaymentMethod),
        quantity: Math.max(1, parseInt(it.quantity, 10) || 1),
        itemImageUrl: it.itemImageUrl || undefined,
        grantTier: it.grantTier || undefined,
        grantVehicleId: it.grantVehicleId || undefined,
        grantType: it.grantType || undefined,
        grantDays: parseInt(it.grantDays, 10) || 0,
        grantMoneyAmount: parseInt(it.grantMoneyAmount, 10) || 0,
        grantXpAmount: parseInt(it.grantXpAmount, 10) || 0,
      })),
      couponCode: couponCode || undefined,
      discountPercent: t.pct || undefined,
      discountCents: t.discount || undefined,
      paymentMethod: selectedPaymentMethod,
    };
    if (robloxConfirmedUserId) payload.robloxUserId = robloxConfirmedUserId;

    const picpayCfg = getPicPayCfg();
    if (selectedPaymentMethod === "pix") {
      if (!picpayCfg || !picpayCfg.enabled) {
        if (errEl) {
          errEl.hidden = false;
          errEl.textContent = "Pagamento Pix não está ativo no site. Use cartão de crédito.";
        }
        return;
      }
    }
    if (selectedPaymentMethod === "pix" && picpayCfg && picpayCfg.enabled) {
      const emailEl = document.getElementById("checkout-pix-email");
      const cpfEl = document.getElementById("checkout-pix-cpf");
      payload.customerEmail = String((emailEl && emailEl.value) || "").trim();
      payload.customerDocument = String((cpfEl && cpfEl.value) || "").replace(/\D/g, "");
      const me = await refreshDiscordStatus();
      if (me) {
        payload.customerName = me.global_name || me.username || "Cliente";
      }
      try {
        const r = await fetch(`${apiBase}/picpay/create-pix-charge`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: "Bearer " + token,
          },
          body: JSON.stringify(payload),
        });
        const data = await r.json().catch(() => ({}));
        if (!r.ok || !data.merchantChargeId) throw new Error(data.error || "Falha ao criar cobrança Pix.");
        try {
          sessionStorage.setItem(
            "gear_picpay_charge",
            JSON.stringify({
              merchantChargeId: data.merchantChargeId,
              qrCode: data.qrCode || "",
              qrCodeBase64: data.qrCodeBase64 || "",
              checkoutLink: data.checkoutLink || "",
              amountCents: data.amountCents,
            })
          );
        } catch (_) {}
        cartItems = [];
        couponCode = "";
        saveState();
        window.location.href =
          data.redirectUrl ||
          "pagamento-pix.html?charge=" + encodeURIComponent(data.merchantChargeId);
        return;
      } catch (e) {
        if (errEl) {
          errEl.hidden = false;
          errEl.textContent = String(e.message || e);
        }
        return;
      }
    }

    try {
      const r = await fetch(`${apiBase}/stripe/create-checkout-session`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + token,
        },
        body: JSON.stringify(payload),
      });
      const data = await r.json().catch(() => ({}));
      if (!r.ok || !data.url) throw new Error(data.error || "Falha ao iniciar checkout.");
      if (data.sessionId) sessionStorage.setItem("gear_stripe_checkout_session", data.sessionId);
      cartItems = [];
      couponCode = "";
      saveState();
      window.location.href = data.url;
    } catch (e) {
      if (errEl) {
        errEl.hidden = false;
        errEl.textContent = String(e.message || e);
      }
    }
  }

  async function setupRobloxLookup() {
    const b = document.getElementById("checkout-roblox-search");
    const c = document.getElementById("checkout-roblox-confirm");
    const prev = document.getElementById("checkout-roblox-preview");
    const errEl = document.getElementById("checkout-err");
    let found = null;
    if (!b || !c || !prev) return;
    b.addEventListener("click", async function () {
      if (errEl) errEl.hidden = true;
      const inp = document.getElementById("checkout-roblox-username");
      const name = String((inp && inp.value) || "").trim();
      if (!name) return;
      const stripeCfg = getStripeCfg();
      const apiBase = String(stripeCfg.apiBase || "http://127.0.0.1:3847").replace(/\/$/, "");
      try {
        const r = await fetch(`${apiBase}/roblox/lookup-username?username=${encodeURIComponent(name)}`);
        const data = await r.json().catch(() => ({}));
        if (!r.ok || !data.ok) throw new Error(data.error || "Usuário não encontrado.");
        found = data;
        prev.hidden = false;
        prev.innerHTML =
          (data.imageUrl ? `<img class="gear-roblox-avatar" src="${data.imageUrl}" alt="" width="72" height="72" />` : "") +
          `<p class="gear-roblox-uname">@${data.username}</p>`;
        c.hidden = false;
        c.disabled = false;
        c.textContent = "Confirmar esta conta";
      } catch (e) {
        if (errEl) {
          errEl.hidden = false;
          errEl.textContent = String(e.message || e);
        }
      }
    });
    c.addEventListener("click", function () {
      if (!found || !found.userId) return;
      robloxConfirmedUserId = String(found.userId);
      c.disabled = true;
      c.textContent = "Conta confirmada ✓";
    });
  }

  function wirePaymentMethodOptions() {
    const pixFields = document.getElementById("checkout-pix-fields");
    const submitBtn = document.getElementById("checkout-submit");
    function syncPixFields() {
      if (pixFields) pixFields.hidden = selectedPaymentMethod !== "pix";
      if (submitBtn) {
        submitBtn.textContent = selectedPaymentMethod === "pix" ? "Pagar com Pix" : "Pagar com cartão";
      }
    }
    document.querySelectorAll(".checkout-pay-option[data-pay]").forEach((btn) => {
      btn.addEventListener("click", function () {
        const pay = String(this.getAttribute("data-pay") || "").trim().toLowerCase();
        if (pay !== "card" && pay !== "pix") return;
        selectedPaymentMethod = pay;
        document.querySelectorAll(".checkout-pay-option[data-pay]").forEach((b) => {
          b.classList.toggle("is-active", b === btn);
        });
        syncPixFields();
        render();
      });
    });
    syncPixFields();
  }

  function wireUi() {
    wirePaymentMethodOptions();
    const dBtn = document.getElementById("checkout-discord-login");
    if (dBtn) {
      dBtn.addEventListener("click", function () {
        const stripeCfg = getStripeCfg();
        const apiBase = String((stripeCfg && stripeCfg.apiBase) || "http://127.0.0.1:3847").replace(/\/$/, "");
        window.location.href = `${apiBase}/auth/discord/login?next=${encodeURIComponent("checkout.html")}`;
      });
    }
    const cp = document.getElementById("checkout-coupon-apply");
    if (cp) {
      cp.addEventListener("click", function () {
        const inp = document.getElementById("checkout-coupon");
        couponCode = String((inp && inp.value) || "").trim().toUpperCase();
        saveState();
        render();
      });
    }
    const clearBtn = document.getElementById("checkout-clear-cart");
    if (clearBtn) {
      clearBtn.addEventListener("click", function () {
        cartItems = [];
        couponCode = "";
        saveState();
        render();
      });
    }
    const submitBtn = document.getElementById("checkout-submit");
    if (submitBtn) submitBtn.addEventListener("click", submitCheckout);
  }

  loadState();
  render();
  wireUi();
  setupRobloxLookup();
  refreshDiscordStatus();
})();
