/**
 * Carrinho no frontend (sem modal): adiciona produtos e salva em sessionStorage.
 * A finalização ocorre em checkout.html.
 */
(function () {
  const CART_KEY = "gear_cart_items_v1";

  function loadCart() {
    try {
      const raw = sessionStorage.getItem(CART_KEY);
      const list = raw ? JSON.parse(raw) : [];
      return Array.isArray(list) ? list : [];
    } catch (_) {
      return [];
    }
  }

  function saveCart(items) {
    try {
      sessionStorage.setItem(CART_KEY, JSON.stringify(items));
      window.dispatchEvent(new CustomEvent("gear-cart-updated"));
    } catch (_) {
      /* ignore */
    }
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

  function readItemFromAnchor(a) {
    const itemName = (a && a.getAttribute("data-checkout-item")) || "Item";
    const amountCents = parseInt((a && a.getAttribute("data-checkout-cents")) || "100", 10);
    const grantTier = ((a && a.getAttribute("data-grant-tier")) || "").trim();
    const grantVehicleId = ((a && a.getAttribute("data-grant-vehicle-id")) || "").trim();
    const grantType = ((a && a.getAttribute("data-grant-type")) || "vip").trim() || "vip";
    const grantDays = parseInt((a && a.getAttribute("data-grant-days")) || "0", 10) || 0;
    return {
      id: [itemName, String(amountCents), grantTier, grantType, String(grantDays), grantVehicleId].join("|"),
      itemName,
      amountCents: Number.isNaN(amountCents) ? 100 : Math.max(50, amountCents),
      quantity: 1,
      itemImageUrl: resolveItemImageUrl(a),
      grantTier,
      grantVehicleId,
      grantType,
      grantDays,
    };
  }

  function addToCart(item) {
    const items = loadCart();
    const found = items.find((it) => it.id === item.id);
    if (found) found.quantity = Math.max(1, (found.quantity || 1) + 1);
    else items.push(item);
    saveCart(items);
  }

  function checkoutPath() {
    try {
      return new URL("checkout.html", window.location.href).href;
    } catch (_) {
      return "checkout.html";
    }
  }

  function showGearToast(message) {
    let el = document.getElementById("gear-cart-toast");
    if (!el) {
      el = document.createElement("div");
      el.id = "gear-cart-toast";
      el.className = "gear-cart-toast";
      el.setAttribute("role", "status");
      el.setAttribute("aria-live", "polite");
      document.body.appendChild(el);
    }
    el.textContent = message;
    el.classList.add("gear-cart-toast--visible");
    clearTimeout(el._t);
    el._t = setTimeout(function () {
      el.classList.remove("gear-cart-toast--visible");
    }, 4200);
  }

  function flashGearCartPreview() {
    const wrap = document.getElementById("gear-cart-top");
    if (!wrap) return;
    wrap.classList.add("nav-cart--flash");
    clearTimeout(wrap._flashT);
    wrap._flashT = setTimeout(function () {
      wrap.classList.remove("nav-cart--flash");
    }, 4500);
  }

  function notifyCartAdded(item) {
    const name = String(item.itemName || "Item");
    const short = name.length > 48 ? name.slice(0, 45) + "…" : name;
    showGearToast("Item adicionado ao carrinho: " + short);
    flashGearCartPreview();
  }

  document.addEventListener(
    "click",
    function (e) {
      const buy = e.target.closest("a.js-cart-buy-now");
      if (buy) {
        e.preventDefault();
        e.stopPropagation();
        const item = readItemFromAnchor(buy);
        saveCart([item]);
        window.location.href = checkoutPath();
        return;
      }

      const a = e.target.closest("a.js-cart-add");
      if (!a) return;
      e.preventDefault();
      e.stopPropagation();
      if (!a.dataset.defaultLabel) a.dataset.defaultLabel = a.textContent.trim();
      const item = readItemFromAnchor(a);
      addToCart(item);
      notifyCartAdded(item);
      a.textContent = "Adicionado ✓";
      setTimeout(function () {
        a.textContent = a.dataset.defaultLabel || "Adicionar ao carrinho";
      }, 900);
    },
    true
  );
})();
