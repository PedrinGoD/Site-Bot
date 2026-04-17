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
    const grantType = ((a && a.getAttribute("data-grant-type")) || "vip").trim() || "vip";
    const grantDays = parseInt((a && a.getAttribute("data-grant-days")) || "0", 10) || 0;
    return {
      id: [itemName, String(amountCents), grantTier, grantType, String(grantDays)].join("|"),
      itemName,
      amountCents: Number.isNaN(amountCents) ? 100 : Math.max(50, amountCents),
      quantity: 1,
      itemImageUrl: resolveItemImageUrl(a),
      grantTier,
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

  document.addEventListener(
    "click",
    function (e) {
      const a = e.target.closest("a.js-cart-add");
      if (!a) return;
      e.preventDefault();
      e.stopPropagation();
      addToCart(readItemFromAnchor(a));
      a.textContent = "Adicionado ✓";
      setTimeout(function () {
        a.textContent = "Adicionar ao carrinho";
      }, 900);
    },
    true
  );
})();
