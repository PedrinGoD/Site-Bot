--[[
  Gear UP — Entrega de compras do site (Stripe) no jogo.
  Coloque este Script em ServerScriptService (separado dos outros sistemas).

  Pré-requisitos:
  - Game Settings → Security → Allow HTTP requests = ON
  - Em produção use HTTPS na URL do bot (ex.: https://bot-gear.onrender.com)
  - No .env do bot: ROBLOX_API_SECRET = (mesmo valor que CONFIG.API_SECRET abaixo)

  NÃO espere um child "VipSalvo" no Player — a entrega grava no DataStore direto.
  Compatível com o teu SistemaAdminVIP / SaveGlobal_V2 / canal AtualizacaoVipAoVivo.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

local CONFIG = {
	API_BASE = "https://bot-gear.onrender.com",
	API_SECRET = "K-gwS_hGeZivSFZvfv3v4_nybguXS8iD",
	POLL_INTERVAL = 12,
	MAX_POLLS = 60,
}

local CANAL_VIP = "AtualizacaoVipAoVivo"
local MasterDataStore = DataStoreService:GetDataStore("SaveGlobal_V2")

local VIP_LEVELS = {
	Bronze = true,
	Gold = true,
	Diamante = true,
}

local function parseVipList(str)
	local t = {}
	if type(str) ~= "string" or str == "" or str == "Comum" then
		return t
	end
	for piece in string.gmatch(str, "[^,]+") do
		local tok = string.gsub(piece, "^%s*(.-)%s*$", "%1")
		if tok ~= "" and tok ~= "Comum" then
			table.insert(t, tok)
		end
	end
	return t
end

local function listContains(tokens, nivel)
	for _, v in ipairs(tokens) do
		if v == nivel then
			return true
		end
	end
	return false
end

local function listAdd(tokens, nivel)
	if listContains(tokens, nivel) then
		return tokens
	end
	local out = {}
	for _, v in ipairs(tokens) do
		table.insert(out, v)
	end
	table.insert(out, nivel)
	return out
end

local function listToVipString(tokens)
	if #tokens == 0 then
		return "Comum"
	end
	return table.concat(tokens, ",")
end

local function updateDataStoreVip(targetUserId, vipDesejado, diasDesejados)
	local novaExpiracaoCalculada = 0
	local ok = false

	for attempt = 1, 4 do
		local success = pcall(function()
			MasterDataStore:UpdateAsync(tostring(targetUserId), function(dadosAntigos)
				local dados = dadosAntigos or {}
				local tokens = parseVipList(dados.VipSalvo or "Comum")

				tokens = listAdd(tokens, vipDesejado)
				dados.VipSalvo = listToVipString(tokens)

				local expAtualDaGaveta = tonumber(dados["Exp" .. vipDesejado]) or 0

				if diasDesejados == 0 then
					dados["Exp" .. vipDesejado] = 0
					novaExpiracaoCalculada = 0
				else
					local segundosExtras = diasDesejados * 86400
					if expAtualDaGaveta > os.time() then
						dados["Exp" .. vipDesejado] = expAtualDaGaveta + segundosExtras
					else
						dados["Exp" .. vipDesejado] = os.time() + segundosExtras
					end
					novaExpiracaoCalculada = dados["Exp" .. vipDesejado]
				end

				return dados
			end)
		end)
		if success then
			ok = true
			break
		end
		task.wait(1.5)
	end

	return ok, novaExpiracaoCalculada
end

local function publishVipLive(userId, nivel, novaExp, isRemovendo)
	pcall(function()
		MessagingService:PublishAsync(CANAL_VIP, {
			UserId = userId,
			NovoVip = nivel,
			NovaExp = novaExp,
			IsRemovendo = isRemovendo == true,
		})
	end)
end

local function httpGetPending(userId)
	local url = CONFIG.API_BASE .. "/roblox/pending-grants?userId=" .. tostring(userId)
	local res = HttpService:RequestAsync({
		Url = url,
		Method = "GET",
		Headers = {
			["Authorization"] = "Bearer " .. CONFIG.API_SECRET,
		},
	})
	if not res.Success then
		error("HTTP " .. tostring(res.StatusCode) .. " " .. tostring(res.Body or ""))
	end
	local data = HttpService:JSONDecode(res.Body)
	if not data or not data.ok then
		error("resposta inválida")
	end
	return data.grants or {}
end

local function httpAckGrantIds(grantIds)
	local res = HttpService:RequestAsync({
		Url = CONFIG.API_BASE .. "/roblox/ack-grants",
		Method = "POST",
		Headers = {
			["Authorization"] = "Bearer " .. CONFIG.API_SECRET,
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode({ grantIds = grantIds }),
	})
	return res.Success
end

local function grantOne(player, g)
	local grantType = g.grantType or g.grant_type or "vip"
	local tier = g.grantTier or g.grant_tier
	if grantType == "vip" and tier and VIP_LEVELS[tier] then
		local uid = player.UserId
		local dias = tonumber(g.grantDays or g.grant_days) or 0
		if dias < 0 then
			dias = 0
		end
		if dias > 3650 then
			dias = 3650
		end

		local ok, novaExp = updateDataStoreVip(uid, tier, dias)
		if ok then
			publishVipLive(uid, tier, novaExp, false)
			print("[EntregaSiteExterno] VIP entregue:", tier, "dias:", dias, "userId:", uid)
			return true
		end
		warn("[EntregaSiteExterno] DataStore UpdateAsync falhou para", tier, uid)
	elseif tier and not VIP_LEVELS[tier] then
		warn("[EntregaSiteExterno] tier desconhecido (esperado Bronze/Gold/Diamante):", tier)
	end
	return false
end

local function runDeliveryLoop(player)
	if CONFIG.API_SECRET == "COLOQUE_O_MESMO_SECRET_DO_BOT_AQUI" then
		warn("[EntregaSiteExterno] Defina CONFIG.API_SECRET (igual ao ROBLOX_API_SECRET no bot).")
		return
	end

	task.wait(2)

	for poll = 1, CONFIG.MAX_POLLS do
		if not player.Parent then
			return
		end

		local okFetch, grantsOrErr = pcall(function()
			return httpGetPending(player.UserId)
		end)

		if not okFetch then
			warn("[EntregaSiteExterno] pedido falhou:", grantsOrErr)
		elseif type(grantsOrErr) == "table" then
			local grants = grantsOrErr
			if #grants > 0 then
				local ackIds = {}
				for _, g in ipairs(grants) do
					if grantOne(player, g) then
						table.insert(ackIds, g.id)
					end
				end
				if #ackIds > 0 then
					pcall(function()
						httpAckGrantIds(ackIds)
					end)
				end
			end
		end

		task.wait(CONFIG.POLL_INTERVAL)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		runDeliveryLoop(player)
	end)
end)
