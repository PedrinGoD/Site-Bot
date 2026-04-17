function initCommon() {
  const CART_KEY = "gear_cart_items_v1";

  function moneyBr(cents) {
    return "R$ " + (Number(cents || 0) / 100).toFixed(2).replace(".", ",");
  }

  function loadCart() {
    try {
      const raw = sessionStorage.getItem(CART_KEY);
      const list = raw ? JSON.parse(raw) : [];
      return Array.isArray(list) ? list : [];
    } catch (_) {
      return [];
    }
  }

  function cartTotals(items) {
    return items.reduce(
      (acc, it) => {
        const qty = Math.max(1, parseInt(it.quantity, 10) || 1);
        const cents = Math.max(50, parseInt(it.amountCents, 10) || 100);
        acc.count += qty;
        acc.total += qty * cents;
        return acc;
      },
      { count: 0, total: 0 }
    );
  }

  function ensureTopCart() {
    const nav = document.querySelector(".nav");
    if (!nav) return;
    if (document.getElementById("gear-cart-top")) return;
    const wrap = document.createElement("div");
    wrap.className = "nav-cart";
    wrap.id = "gear-cart-top";
    wrap.innerHTML = `
      <a class="nav__link nav-cart__button" href="#" title="Abrir carrinho" id="gear-cart-open-btn">
        <span class="nav-cart__icon" aria-hidden="true">🛒</span>
        <span class="nav-cart__label">Carrinho</span>
        <span class="nav-cart__count" id="gear-cart-count">0</span>
      </a>
      <div class="nav-cart__preview" id="gear-cart-preview" hidden></div>
    `;
    nav.appendChild(wrap);
    wrap.addEventListener("mouseenter", refreshTopCart);
    const openBtn = document.getElementById("gear-cart-open-btn");
    if (openBtn) {
      openBtn.addEventListener("click", function (e) {
        e.preventDefault();
        openCartDrawer();
      });
    }
  }

  function ensureCartDrawer() {
    if (document.getElementById("gear-cart-drawer")) return;
    const d = document.createElement("aside");
    d.id = "gear-cart-drawer";
    d.className = "cart-drawer";
    d.setAttribute("aria-hidden", "true");
    d.innerHTML = `
      <div class="cart-drawer__backdrop" id="gear-cart-drawer-backdrop"></div>
      <div class="cart-drawer__panel">
        <div class="cart-drawer__head">
          <h3>Carrinho</h3>
          <button type="button" class="cart-drawer__close" id="gear-cart-drawer-close">×</button>
        </div>
        <div class="cart-drawer__items" id="gear-cart-drawer-items"></div>
        <div class="cart-drawer__foot">
          <p class="cart-drawer__total" id="gear-cart-drawer-total">Total: R$ 0,00</p>
          <a class="btn btn--primary" href="checkout.html">Ir para o checkout</a>
        </div>
      </div>
    `;
    document.body.appendChild(d);
    document.getElementById("gear-cart-drawer-close")?.addEventListener("click", closeCartDrawer);
    document.getElementById("gear-cart-drawer-backdrop")?.addEventListener("click", closeCartDrawer);
  }

  function closeCartDrawer() {
    const d = document.getElementById("gear-cart-drawer");
    if (!d) return;
    d.classList.remove("is-open");
    d.setAttribute("aria-hidden", "true");
  }

  function openCartDrawer() {
    ensureCartDrawer();
    refreshCartDrawer();
    const d = document.getElementById("gear-cart-drawer");
    if (!d) return;
    d.classList.add("is-open");
    d.setAttribute("aria-hidden", "false");
  }

  function saveCart(items) {
    try {
      sessionStorage.setItem(CART_KEY, JSON.stringify(items));
      window.dispatchEvent(new CustomEvent("gear-cart-updated"));
    } catch (_) {
      /* ignore */
    }
  }

  function refreshCartDrawer() {
    const list = document.getElementById("gear-cart-drawer-items");
    const totalEl = document.getElementById("gear-cart-drawer-total");
    if (!list || !totalEl) return;
    const items = loadCart();
    const t = cartTotals(items);
    if (!items.length) {
      list.innerHTML = '<p class="nav-cart__empty">Seu carrinho está vazio.</p>';
      totalEl.textContent = "Total: R$ 0,00";
      return;
    }
    list.innerHTML = items
      .map(
        (it, idx) => `
        <div class="cart-drawer__line">
          <div class="cart-drawer__meta">
            <strong>${String(it.itemName || "Item")}</strong>
            <small>${moneyBr(parseInt(it.amountCents, 10) || 100)}</small>
          </div>
          <div class="cart-drawer__actions">
            <button type="button" class="btn btn--ghost" data-cart-dec="${idx}">-</button>
            <span>${Math.max(1, parseInt(it.quantity, 10) || 1)}</span>
            <button type="button" class="btn btn--ghost" data-cart-inc="${idx}">+</button>
            <button type="button" class="btn btn--ghost" data-cart-rm="${idx}">x</button>
          </div>
        </div>`
      )
      .join("");
    totalEl.textContent = `Total: ${moneyBr(t.total)}`;
    list.querySelectorAll("[data-cart-dec]").forEach((el) =>
      el.addEventListener("click", function () {
        const i = parseInt(this.getAttribute("data-cart-dec"), 10);
        if (!items[i]) return;
        items[i].quantity = Math.max(1, (parseInt(items[i].quantity, 10) || 1) - 1);
        saveCart(items);
      })
    );
    list.querySelectorAll("[data-cart-inc]").forEach((el) =>
      el.addEventListener("click", function () {
        const i = parseInt(this.getAttribute("data-cart-inc"), 10);
        if (!items[i]) return;
        items[i].quantity = Math.max(1, (parseInt(items[i].quantity, 10) || 1) + 1);
        saveCart(items);
      })
    );
    list.querySelectorAll("[data-cart-rm]").forEach((el) =>
      el.addEventListener("click", function () {
        const i = parseInt(this.getAttribute("data-cart-rm"), 10);
        if (!items[i]) return;
        items.splice(i, 1);
        saveCart(items);
      })
    );
  }

  function refreshTopCart() {
    const wrap = document.getElementById("gear-cart-top");
    if (!wrap) return;
    const countEl = document.getElementById("gear-cart-count");
    const prev = document.getElementById("gear-cart-preview");
    const items = loadCart();
    const t = cartTotals(items);
    if (countEl) countEl.textContent = String(t.count);

    wrap.classList.toggle("has-items", t.count > 0);
    if (!prev) return;
    if (!items.length) {
      prev.hidden = false;
      prev.innerHTML = `<p class="nav-cart__empty">Carrinho vazio.</p>`;
      return;
    }
    const top2 = items.slice(0, 2);
    prev.hidden = false;
    prev.innerHTML =
      top2
        .map(
          (it) =>
            `<div class="nav-cart__line"><span>${String(it.itemName || "Item")}</span><strong>${moneyBr(
              (parseInt(it.amountCents, 10) || 100) * (parseInt(it.quantity, 10) || 1)
            )}</strong></div>`
        )
        .join("") +
      (items.length > 2 ? `<p class="nav-cart__more">+${items.length - 2} item(ns)</p>` : "") +
      `<p class="nav-cart__total">Total: <strong>${moneyBr(t.total)}</strong></p>`;
  }

  const faviconHref = "assets/gear-up-logo.png";
  let favicon = document.querySelector("link[rel='icon']");
  if (!favicon) {
    favicon = document.createElement("link");
    favicon.setAttribute("rel", "icon");
    document.head.appendChild(favicon);
  }
  favicon.setAttribute("type", "image/png");
  favicon.setAttribute("href", faviconHref);

  const y = document.getElementById("year");
  if (y) y.textContent = String(new Date().getFullYear());

  const url =
    typeof window.ROBLOX_PLACE_URL === "string"
      ? window.ROBLOX_PLACE_URL
      : "https://www.roblox.com/pt/games/140001935550545/Gear-Up";

  document.querySelectorAll(".js-roblox-link").forEach((el) => {
    el.setAttribute("href", url);
    if (!url.includes("PLACEHOLDER")) {
      el.setAttribute("target", "_blank");
      el.setAttribute("rel", "noopener noreferrer");
    }
  });

  ensureTopCart();
  ensureCartDrawer();
  refreshTopCart();
  refreshCartDrawer();
  window.addEventListener("gear-cart-updated", refreshTopCart);
  window.addEventListener("gear-cart-updated", refreshCartDrawer);
  window.addEventListener("storage", refreshTopCart);
  window.addEventListener("storage", refreshCartDrawer);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initCommon);
} else {
  initCommon();
}
