-- CH Corporations - Tags de chat VIP (TagPreferida + RichText) — LocalScript (StarterPlayerScripts)
-- Revisão: handler em pcall (erro não quebra o chat); TagPreferida só StringValue; só tags whitelisted;
--          prefixo montado com dados da config (menos injeção RichText); hex validado; avisos discretos.

print("CH Corporations - Tags de chat VIP (TagPreferida + emojis — revisão)")

local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

-- Chave = valor exato de TagPreferida (StringValue). Não uses texto livre do jogador no HTML sem whitelist.
local configVIP = {
	Diamante = { hex = "#00FFFF", emoji = "💎", rotulo = "Diamante" },
	Gold = { hex = "#FFD700", emoji = "🥇", rotulo = "Gold" },
	Bronze = { hex = "#D2691E", emoji = "🥉", rotulo = "Bronze" },
}

local function hexValido(hex)
	return type(hex) == "string" and string.match(hex, "^#%x%x%x%x%x%x$") ~= nil
end

TextChatService.OnIncomingMessage = function(message)
	local properties = Instance.new("TextChatMessageProperties")

	local ok, err = pcall(function()
		if not message.TextSource then
			return
		end

		local remetente = Players:GetPlayerByUserId(message.TextSource.UserId)
		if not remetente then
			return
		end

		local tagPreferida = remetente:FindFirstChild("TagPreferida")
		if not tagPreferida or not tagPreferida:IsA("StringValue") then
			return
		end

		local nomeTag = tagPreferida.Value
		if nomeTag == "" or nomeTag == "Comum" then
			return
		end

		local config = configVIP[nomeTag]
		if not config then
			return
		end

		local cor = config.hex
		if not hexValido(cor) then
			warn("[ChatVIP] Cor inválida para tag", nomeTag)
			return
		end

		local emoji = type(config.emoji) == "string" and config.emoji or ""
		local rotulo = type(config.rotulo) == "string" and config.rotulo or nomeTag

		local blocoTag = string.format(
			"<font color='%s'><b>[%s %s]</b></font> ",
			cor,
			emoji,
			rotulo
		)

		local prefixoAnterior = message.PrefixText
		if type(prefixoAnterior) ~= "string" then
			prefixoAnterior = ""
		end

		properties.PrefixText = blocoTag .. prefixoAnterior
		if message.Text ~= nil then
			properties.Text = message.Text
		end
	end)

	if not ok then
		warn("[ChatVIP] OnIncomingMessage:", err)
	end

	return properties
end
