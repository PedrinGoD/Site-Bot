const crypto = require("crypto");

/**
 * @param {string} secret
 */
function hmac(secret, data) {
  return crypto.createHmac("sha256", secret).update(data).digest("base64url");
}

/**
 * @param {object} payload
 * @param {string} secret
 */
function signPayload(payload, secret) {
  if (!secret) return "";
  const data = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const sig = hmac(secret, data);
  return `${data}.${sig}`;
}

/**
 * @param {string} token
 * @param {string} secret
 * @returns {object | null}
 */
function verifyPayload(token, secret) {
  if (!token || !secret || typeof token !== "string") return null;
  const i = token.lastIndexOf(".");
  if (i <= 0) return null;
  const data = token.slice(0, i);
  const sig = token.slice(i + 1);
  const expected = hmac(secret, data);
  if (sig.length !== expected.length) return null;
  try {
    if (!crypto.timingSafeEqual(Buffer.from(sig, "utf8"), Buffer.from(expected, "utf8"))) return null;
  } catch {
    return null;
  }
  try {
    return JSON.parse(Buffer.from(data, "base64url").toString("utf8"));
  } catch {
    return null;
  }
}

const OAUTH_STATE_MAX_AGE_MS = 10 * 60 * 1000;
const SESSION_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * @param {{ next?: string }} payload
 * @param {string} secret
 */
function signOAuthState(payload, secret) {
  return signPayload(
    {
      ...payload,
      t: Date.now(),
      n: crypto.randomBytes(8).toString("hex"),
    },
    secret
  );
}

/**
 * @param {string} token
 * @param {string} secret
 * @returns {{ next?: string } | null}
 */
function verifyOAuthState(token, secret) {
  const p = verifyPayload(token, secret);
  if (!p || typeof p.t !== "number") return null;
  if (Date.now() - p.t > OAUTH_STATE_MAX_AGE_MS) return null;
  return p;
}

/**
 * @param {{ id: string, username?: string, global_name?: string | null, avatar?: string | null }} user
 * @param {string} secret
 */
function signDiscordSession(user, secret) {
  return signPayload(
    {
      sub: user.id,
      username: user.username,
      global_name: user.global_name || null,
      avatar: user.avatar || null,
      exp: Date.now() + SESSION_MAX_AGE_MS,
    },
    secret
  );
}

/**
 * @param {string} token
 * @param {string} secret
 */
function verifyDiscordSession(token, secret) {
  const p = verifyPayload(token, secret);
  if (!p || typeof p.sub !== "string" || !/^\d{17,20}$/.test(p.sub)) return null;
  if (typeof p.exp !== "number" || Date.now() > p.exp) return null;
  return p;
}

module.exports = {
  signOAuthState,
  verifyOAuthState,
  signDiscordSession,
  verifyDiscordSession,
};
