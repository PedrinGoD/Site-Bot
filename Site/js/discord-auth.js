/**
 * Sessão OAuth Discord (token assinado pelo bot). Usado por checkout-demo.js.
 */
(function () {
  var STORAGE_KEY = "gear_discord_session_token";

  function getStripeCfg() {
    return typeof window.GEAR_STRIPE === "object" && window.GEAR_STRIPE !== null ? window.GEAR_STRIPE : null;
  }

  function getApiBase() {
    var s = getStripeCfg();
    return s && s.apiBase ? String(s.apiBase).replace(/\/$/, "") : "http://127.0.0.1:3847";
  }

  function getToken() {
    try {
      return sessionStorage.getItem(STORAGE_KEY);
    } catch (_) {
      return null;
    }
  }

  function setToken(t) {
    try {
      if (t) sessionStorage.setItem(STORAGE_KEY, t);
      else sessionStorage.removeItem(STORAGE_KEY);
    } catch (_) {}
  }

  function loginUrl(nextPath) {
    var n = nextPath || "index.html";
    if (n.indexOf("..") >= 0 || n.indexOf("//") >= 0) n = "index.html";
    return getApiBase() + "/auth/discord/login?next=" + encodeURIComponent(n);
  }

  function logout() {
    setToken(null);
    if (window.GearDiscordAuth && typeof window.GearDiscordAuth._refreshNav === "function") {
      window.GearDiscordAuth._refreshNav();
    }
  }

  async function fetchMe() {
    var t = getToken();
    if (!t) return null;
    var r = await fetch(getApiBase() + "/auth/me", {
      headers: { Authorization: "Bearer " + t },
    });
    if (!r.ok) {
      if (r.status === 401) setToken(null);
      return null;
    }
    return r.json();
  }

  function initDiscordAuthNav() {
    var stripe = getStripeCfg();
    if (!stripe || !stripe.enabled || stripe.discordLogin === false) return;

    var nav = document.querySelector(".site-header .nav");
    if (!nav) return;

    var slot = document.createElement("div");
    slot.className = "nav__discord";
    slot.id = "gear-discord-auth";

    function render() {
      slot.innerHTML = "";
      var t = getToken();
      if (!t) {
        var a = document.createElement("a");
        a.className = "nav__discord-btn";
        a.href = loginUrl(currentPageName());
        a.textContent = "Entrar com Discord";
        slot.appendChild(a);
        return;
      }
      fetchMe().then(function (me) {
        slot.innerHTML = "";
        if (!me || !me.ok) {
          var a2 = document.createElement("a");
          a2.className = "nav__discord-btn";
          a2.href = loginUrl(currentPageName());
          a2.textContent = "Entrar com Discord";
          slot.appendChild(a2);
          return;
        }
        var span = document.createElement("span");
        span.className = "nav__discord-user";
        if (me.avatarUrl) {
          var img = document.createElement("img");
          img.src = me.avatarUrl;
          img.alt = "";
          img.width = 28;
          img.height = 28;
          img.className = "nav__discord-avatar";
          span.appendChild(img);
        }
        var name = document.createElement("span");
        name.className = "nav__discord-name";
        name.textContent = me.global_name || me.username || me.id;
        span.appendChild(name);
        var out = document.createElement("button");
        out.type = "button";
        out.className = "nav__discord-out";
        out.textContent = "Sair";
        out.addEventListener("click", function () {
          logout();
          render();
        });
        span.appendChild(out);
        slot.appendChild(span);
      });
    }

    function currentPageName() {
      var path = location.pathname || "";
      var i = path.lastIndexOf("/");
      return path.slice(i + 1) || "index.html";
    }

    var cta = nav.querySelector(".nav__cta");
    if (cta && cta.parentNode) {
      cta.parentNode.insertBefore(slot, cta);
    } else {
      nav.appendChild(slot);
    }

    window.GearDiscordAuth = window.GearDiscordAuth || {};
    window.GearDiscordAuth._refreshNav = render;
    render();
  }

  window.GearDiscordAuth = {
    STORAGE_KEY: STORAGE_KEY,
    getApiBase: getApiBase,
    getToken: getToken,
    setToken: setToken,
    loginUrl: loginUrl,
    logout: logout,
    fetchMe: fetchMe,
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initDiscordAuthNav);
  } else {
    initDiscordAuthNav();
  }
})();
