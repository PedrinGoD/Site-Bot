async function resolveRobloxUserId(input) {
  const raw = String(input || "").trim();
  if (!raw) return { error: "Informe um usuário ou ID Roblox." };
  if (/^\d{1,20}$/.test(raw)) {
    return { userId: raw };
  }
  if (!/^[a-zA-Z0-9_]{3,20}$/.test(raw)) {
    return { error: "Nome Roblox inválido. Use apenas letras, números e _." };
  }
  try {
    const r = await fetch("https://users.roblox.com/v1/usernames/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ usernames: [raw], excludeBannedUsers: true }),
      signal: AbortSignal.timeout(8000),
    });
    if (!r.ok) return { error: `Falha Roblox API (${r.status}).` };
    const j = await r.json();
    const row = j && Array.isArray(j.data) ? j.data[0] : null;
    if (!row || !row.id) return { error: "Usuário Roblox não encontrado." };
    return { userId: String(row.id), username: String(row.name || raw) };
  } catch (e) {
    return { error: `Falha ao consultar Roblox: ${String(e.message || e)}` };
  }
}

module.exports = { resolveRobloxUserId };
