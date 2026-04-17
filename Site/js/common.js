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
      <a class="nav__link nav-cart__button" href="checkout.html" title="Abrir carrinho">
        <span class="nav-cart__icon" aria-hidden="true">🛒</span>
        <span class="nav-cart__label">Carrinho</span>
        <span class="nav-cart__count" id="gear-cart-count">0</span>
      </a>
      <div class="nav-cart__preview" id="gear-cart-preview" hidden></div>
    `;
    nav.appendChild(wrap);
    wrap.addEventListener("mouseenter", refreshTopCart);
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
  refreshTopCart();
  window.addEventListener("gear-cart-updated", refreshTopCart);
  window.addEventListener("storage", refreshTopCart);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initCommon);
} else {
  initCommon();
}
