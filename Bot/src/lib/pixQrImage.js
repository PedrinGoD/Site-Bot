const QRCode = require("qrcode");

/**
 * Gera PNG em data URL a partir do Pix copia e cola (EMV).
 * @param {string} pixCode
 * @returns {Promise<string>}
 */
async function pixCodeToDataUrl(pixCode) {
  const code = String(pixCode || "").trim();
  if (!code || !/^000201/i.test(code)) return "";
  try {
    return await QRCode.toDataURL(code, {
      width: 280,
      margin: 1,
      errorCorrectionLevel: "M",
    });
  } catch (e) {
    console.warn("[pix-qr] falha ao gerar QR:", e.message || e);
    return "";
  }
}

module.exports = { pixCodeToDataUrl };
