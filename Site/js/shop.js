(function () {
  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function escapeAttr(s) {
    return escapeHtml(s).replace(/'/g, "&#39;");
  }

  function safeId(s) {
    return String(s).replace(/[^a-z0-9-_]/gi, "");
  }

  function variantClass(v) {
    if (!v || !/^[a-z0-9-]+$/i.test(v)) return "";
    return ` product-card__badge--${v}`;
  }

  /**
   * @param {object} p
   * @param {{ showBadge?: boolean }} [opts]
   */
  function productCardHtml(p, opts) {
    const showBadge = opts?.showBadge !== false && p.badge != null && String(p.badge).trim() !== "";
    const badgeLine = showBadge
      ? `<span class="product-card__badge${variantClass(p.badgeVariant)}">${escapeHtml(p.badge)}</span>`
      : "";
    const imgSrc = p.image && String(p.image).trim();
    const imgAlt =
      p.imageAlt != null && String(p.imageAlt).trim() !== "" ? String(p.imageAlt).trim() : p.title;
    const mediaLine = imgSrc
      ? `<div class="product-card__media">
      <img class="product-card__thumb" src="${escapeAttr(imgSrc)}" alt="${escapeAttr(imgAlt)}" width="400" height="250" loading="lazy" decoding="async" />
    </div>`
      : "";
    const cardMod = imgSrc ? " product-card--has-media" : "";
    return `
    <article class="product-card${cardMod}">
      ${badgeLine}
      ${mediaLine}
      <h3>${escapeHtml(p.title)}</h3>
      <p class="product-card__desc">${escapeHtml(p.desc)}</p>
      <div class="product-card__price">${escapeHtml(p.price)}</div>
      ${p.note ? `<p class="product-card__note">${escapeHtml(p.note)}</p>` : ""}
      <a class="btn btn--primary js-cart-add" href="${escapeAttr(p.href)}" data-checkout-item="${escapeAttr(p.title)}" data-checkout-price="${escapeAttr(p.price)}" data-checkout-cents="${escapeAttr(String(p.stripeAmountCents != null ? p.stripeAmountCents : 100))}" data-checkout-image="${imgSrc ? escapeAttr(imgSrc) : ""}" data-grant-type="${p.grantType ? escapeAttr(p.grantType) : ""}" data-grant-tier="${p.grantTier ? escapeAttr(p.grantTier) : ""}" data-grant-days="${p.grantDays != null ? escapeAttr(String(p.grantDays)) : ""}">Adicionar ao carrinho</a>
    </article>`;
  }

  /**
   * @param {object} p
   * @param {{ id: string, title: string, image?: string, imageAlt?: string }} sec
   * @param {number} index
   */
  function vipProductCardHtml(p, sec, index) {
    const sid = safeId(sec.id);
    const dlgId = `vip-dialog-${sid}-${index}`;
    const titleId = `vip-dialog-title-${sid}-${index}`;
    const imgSrc = sec.image && String(sec.image).trim();
    const imgAlt = sec.imageAlt || sec.title;
    const thumb = imgSrc
      ? `<div class="product-card__vip-media">
      <img class="product-card__vip-thumb" src="${escapeAttr(imgSrc)}" alt="${escapeAttr(imgAlt)}" width="320" height="180" loading="lazy" decoding="async" />
    </div>`
      : "";
    const noteBlock = p.note
      ? `<p class="vip-detail-dialog__note">${escapeHtml(p.note)}</p>`
      : "";
    const tierMap = { diamante: "Diamante", gold: "Gold", bronze: "Bronze" };
    const grantTier =
      p.grantTier && String(p.grantTier).trim() !== ""
        ? String(p.grantTier).trim()
        : tierMap[sec.id] || "";
    const grantDays = p.grantDays != null ? p.grantDays : 1;
    const grantType = p.grantType && String(p.grantType).trim() !== "" ? String(p.grantType).trim() : "vip";
    return `
    <article class="product-card product-card--vip">
      <button type="button" class="product-card__vip-trigger" aria-haspopup="dialog" aria-controls="${escapeAttr(dlgId)}">
        ${thumb}
        <span class="product-card__vip-trigger-text">
          <span class="product-card__vip-title">${escapeHtml(p.title)}</span>
          <span class="product-card__price product-card__price--vip">${escapeHtml(p.price)}</span>
          <span class="product-card__vip-hint">Clique para ver a descrição</span>
        </span>
      </button>
      <a class="btn btn--primary js-cart-add" href="${escapeAttr(p.href)}" data-checkout-item="${escapeAttr(sec.title + " — " + p.title)}" data-checkout-price="${escapeAttr(p.price)}" data-checkout-cents="${escapeAttr(String(p.stripeAmountCents != null ? p.stripeAmountCents : 100))}" data-checkout-image="${imgSrc ? escapeAttr(imgSrc) : ""}" data-grant-type="${escapeAttr(grantType)}" data-grant-tier="${grantTier ? escapeAttr(grantTier) : ""}" data-grant-days="${escapeAttr(String(grantDays))}">Adicionar ao carrinho</a>
      <dialog class="vip-detail-dialog" id="${escapeAttr(dlgId)}" aria-labelledby="${escapeAttr(titleId)}">
        <div class="vip-detail-dialog__backdrop" aria-hidden="true"></div>
        <div class="vip-detail-dialog__surface">
          <button type="button" class="vip-detail-dialog__close" aria-label="Fechar">&times;</button>
          <h4 class="vip-detail-dialog__title" id="${escapeAttr(titleId)}">${escapeHtml(sec.title)} — ${escapeHtml(p.title)}</h4>
          <p class="vip-detail-dialog__body">${escapeHtml(p.desc)}</p>
          ${noteBlock}
        </div>
      </dialog>
    </article>`;
  }

  function bindVipDialogHandlers(root) {
    if (!root) return;

    root.addEventListener("click", function (e) {
      const trigger = e.target.closest(".product-card__vip-trigger");
      if (!trigger || !root.contains(trigger)) return;
      const card = trigger.closest(".product-card--vip");
      const dlg = card && card.querySelector("dialog.vip-detail-dialog");
      if (dlg) dlg.showModal();
    });

    root.querySelectorAll("dialog.vip-detail-dialog").forEach(function (dlg) {
      dlg.querySelector(".vip-detail-dialog__close")?.addEventListener("click", function () {
        dlg.close();
      });
      dlg.querySelector(".vip-detail-dialog__backdrop")?.addEventListener("click", function () {
        dlg.close();
      });
    });
  }

  /**
   * @param {string} containerId
   * @param {Array<{ badge: string, title: string, desc: string, price: string, note?: string, href: string, badgeVariant?: string, image?: string, imageAlt?: string }>} items
   */
  function render(containerId, items) {
    const root = document.getElementById(containerId);
    if (!root || !items?.length) return;
    root.innerHTML = items.map((p) => productCardHtml(p, { showBadge: true })).join("");
  }

  /**
   * VIP: blocos separados por tier; cada card com imagem do tier e descrição no dialog.
   * @param {string} containerId
   * @param {Array<{ id: string, title: string, lead?: string, image?: string, imageAlt?: string, items: Array<{ title: string, desc: string, price: string, note?: string, href: string }> }>} sections
   */
  function renderVipSections(containerId, sections) {
    const root = document.getElementById(containerId);
    if (!root || !sections?.length) return;

    root.innerHTML = `<div class="vip-sections">${sections
      .map((sec) => {
        const sid = safeId(sec.id);
        const headingId = `vip-niche-${sid}-title`;
        const cards = (sec.items || []).map((p, i) => vipProductCardHtml(p, sec, i)).join("");
        const lead = sec.lead
          ? `<p class="vip-niche__lead">${escapeHtml(sec.lead)}</p>`
          : "";
        return `
<section class="vip-niche vip-niche--${escapeAttr(sid)}" aria-labelledby="${escapeAttr(headingId)}">
  <div class="vip-niche__inner">
    <header class="vip-niche__head">
      <h2 class="vip-niche__title" id="${escapeAttr(headingId)}">${escapeHtml(sec.title)}</h2>
      ${lead}
    </header>
    <div class="products vip-niche__products">${cards}</div>
  </div>
</section>`;
      })
      .join("")}</div>`;

    bindVipDialogHandlers(root);
  }

  /**
   * Loja em seções (ex.: Pacotes) — cards padrão com badge, imagem opcional, descrição.
   * @param {string} containerId
   * @param {Array<{ id: string, title: string, lead?: string, items: Array<{ badge: string, title: string, desc: string, price: string, note?: string, href: string, badgeVariant?: string, image?: string, imageAlt?: string }> }>} sections
   */
  function renderShopSections(containerId, sections) {
    const root = document.getElementById(containerId);
    if (!root || !sections?.length) return;

    root.innerHTML = `<div class="shop-sections">${sections
      .map((sec) => {
        const sid = safeId(sec.id);
        const headingId = `shop-block-${sid}-title`;
        const cards = (sec.items || []).map((p) => productCardHtml(p, { showBadge: true })).join("");
        const lead = sec.lead
          ? `<p class="shop-block__lead">${escapeHtml(sec.lead)}</p>`
          : "";
        return `
<section class="shop-block shop-block--${escapeAttr(sid)}" aria-labelledby="${escapeAttr(headingId)}">
  <div class="shop-block__inner">
    <header class="shop-block__head">
      <h2 class="shop-block__title" id="${escapeAttr(headingId)}">${escapeHtml(sec.title)}</h2>
      ${lead}
    </header>
    <div class="products shop-block__products">${cards}</div>
  </div>
</section>`;
      })
      .join("")}</div>`;
  }

  window.GearShop = { render, renderVipSections, renderShopSections };
})();
