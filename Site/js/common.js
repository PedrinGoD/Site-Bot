function initCommon() {
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
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initCommon);
} else {
  initCommon();
}
