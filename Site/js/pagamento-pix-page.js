(function () {
  function getApiBase() {
    const s = window.GEAR_STRIPE;
    return s && s.apiBase ? String(s.apiBase).replace(/\/$/, "") : "http://127.0.0.1:3847";
  }

  function moneyBr(cents) {
    return "R$ " + (Number(cents || 0) / 100).toFixed(2).replace(".", ",");
  }

  function chargeIdFromUrl() {
    const q = new URLSearchParams(window.location.search);
    return String(q.get("charge") || "").trim();
  }

  function isPixCopyPaste(str) {
    return /^000201/i.test(String(str || "").trim());
  }

  function renderPixQrImage(img, pixCode) {
    if (!img || !pixCode || typeof QRCode === "undefined") return;
    QRCode.toDataURL(String(pixCode), {
      width: 280,
      margin: 1,
      errorCorrectionLevel: "M",
    })
      .then(function (url) {
        img.src = url;
        img.alt = "QR Code Pix";
        img.hidden = false;
      })
      .catch(function () {
        img.removeAttribute("src");
        img.hidden = true;
      });
  }

  function showQr(data) {
    const img = document.getElementById("pix-qr-img");
    const ta = document.getElementById("pix-copy-code");
    const copyBtn = document.getElementById("pix-copy-btn");
    const linkBtn = document.getElementById("pix-open-link");
    let b64 = String(data.qrCodeBase64 || "").trim();
    let code = String(data.qrCode || "").trim();
    const checkoutLink = data.checkoutLink || "";

    if (isPixCopyPaste(b64) && !code) {
      code = b64;
      b64 = "";
    }

    if (img) {
      if (b64 && !isPixCopyPaste(b64)) {
        img.src = b64.startsWith("data:") ? b64 : "data:image/png;base64," + b64;
        img.hidden = false;
      } else if (code) {
        renderPixQrImage(img, code);
      } else {
        img.removeAttribute("src");
        img.hidden = true;
      }
    }
    if (ta && code) {
      ta.value = code;
      ta.hidden = false;
    }
    if (copyBtn) copyBtn.hidden = !code;
    if (linkBtn) {
      if (checkoutLink) {
        linkBtn.href = checkoutLink;
        linkBtn.hidden = false;
      } else {
        linkBtn.hidden = true;
      }
    }
  }

  async function poll(chargeId) {
    const statusEl = document.getElementById("pix-status");
    const doneLink = document.getElementById("pix-done-link");
    const apiBase = getApiBase();
    let tries = 0;
    const maxTries = 120;

    async function tick() {
      tries += 1;
      try {
        const r = await fetch(apiBase + "/picpay/order/" + encodeURIComponent(chargeId));
        const data = await r.json().catch(() => ({}));
        if (!r.ok) throw new Error(data.error || "Erro ao consultar pagamento");
        if (data.amountCents) {
          const amt = document.getElementById("pix-amount");
          if (amt) amt.textContent = "Valor: " + moneyBr(data.amountCents);
        }
        showQr(data);
        if (data.paid) {
          if (statusEl) {
            statusEl.textContent = "Pagamento confirmado! Redirecionando…";
            statusEl.style.color = "var(--accent, #f97316)";
          }
          if (doneLink) doneLink.hidden = false;
          setTimeout(function () {
            window.location.href = "pagamento-ok.html?picpay=" + encodeURIComponent(chargeId);
          }, 1500);
          return;
        }
        if (statusEl) {
          statusEl.textContent =
            "Aguardando pagamento no app do banco… (" + tries + "/" + maxTries + ")";
        }
      } catch (e) {
        if (statusEl) statusEl.textContent = String(e.message || e);
      }
      if (tries < maxTries) {
        setTimeout(tick, 5000);
      } else if (statusEl) {
        statusEl.textContent =
          "Ainda não confirmamos o Pix. Se já pagou, aguarde ou fale com o suporte.";
      }
    }
    tick();
  }

  function init() {
    const copyBtn = document.getElementById("pix-copy-btn");
    if (copyBtn) {
      copyBtn.addEventListener("click", function () {
        const ta = document.getElementById("pix-copy-code");
        if (!ta || !ta.value) return;
        navigator.clipboard.writeText(ta.value).then(
          function () {
            copyBtn.textContent = "Copiado!";
            setTimeout(function () {
              copyBtn.textContent = "Copiar código Pix";
            }, 2000);
          },
          function () {
            ta.select();
            document.execCommand("copy");
          }
        );
      });
    }

    let chargeId = chargeIdFromUrl();
    let cached = null;
    try {
      cached = JSON.parse(sessionStorage.getItem("gear_picpay_charge") || "null");
    } catch (_) {}
    if (!chargeId && cached && cached.merchantChargeId) {
      chargeId = cached.merchantChargeId;
    }
    if (!chargeId) {
      const st = document.getElementById("pix-status");
      if (st) st.textContent = "Pedido Pix não encontrado. Volte ao checkout.";
      return;
    }
    if (cached && cached.merchantChargeId === chargeId) {
      showQr(cached);
      const amt = document.getElementById("pix-amount");
      if (amt && cached.amountCents) amt.textContent = "Valor: " + moneyBr(cached.amountCents);
    }
    poll(chargeId);
  }

  init();
})();
