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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

-- API_SECRET: tem de ser BYTE A BYTE igual a ROBLOX_API_SECRET no Render (.env).
-- Erro HTTP 401 no Output = secret errado ou espaço a mais/menos (ex.: faltou o prefixo "K-" no início).
local CONFIG = {
	API_BASE = "https://bot-gear.onrender.com",
	API_SECRET = "COLOQUE_O_MESMO_SECRET_DO_BOT_AQUI",
	--- Segundos entre cada GET /roblox/pending-grants (enquanto o jogador estiver no servidor).
	POLL_INTERVAL = 12,
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

--- Mesmo canal que SistemaAdminVIP; SkipCelebracao evita toast duplicado (a notificação vem de notificarCompraSiteLoja).
local function publishVipLive(userId, nivel, novaExp, isRemovendo)
	pcall(function()
		MessagingService:PublishAsync(CANAL_VIP, {
			UserId = userId,
			NovoVip = nivel,
			NovaExp = novaExp,
			IsRemovendo = isRemovendo == true,
			SkipCelebracao = true,
		})
	end)
end

--- Mesmos RemoteEvents que SistemaAdminVIP usa (CelebracaoCompraEvent + AnuncioGlobalEvent).
local function notificarCompraSiteLoja(player, titulo)
	if not player or not player.Parent then
		return
	end
	local t = type(titulo) == "string" and titulo or "Compra Gear Shop"
	pcall(function()
		local ev = ReplicatedStorage:FindFirstChild("CelebracaoCompraEvent")
		if ev and ev:IsA("RemoteEvent") then
			ev:FireClient(player, t, true)
		end
	end)
	pcall(function()
		local ev = ReplicatedStorage:FindFirstChild("AnuncioGlobalEvent")
		if ev and ev:IsA("RemoteEvent") then
			ev:FireAllClients(player.Name, t, true)
		end
	end)
end

local function nomeVeiculoLegivel(nomeInventario)
	if type(nomeInventario) ~= "string" then
		return "Veículo"
	end
	local s = string.gsub(nomeInventario, "_", " ")
	s = string.gsub(s, "%s+", " ")
	return s
end

--- Igual ao que GerenciadorDeDadosMaster grava em data.Inventario[nome]
local function defaultVehicleSaveBlock()
	return {
		CorDoCarro = "",
		MotorAtual = 0,
		CombustivelSalvo = 100,
		FL = "Padrao",
		FR = "Padrao",
		RL = "Padrao",
		RR = "Padrao",
		Suspensao = {
			Nome = "Padrao",
			Altura = 2,
			Rigidez = 4500,
			Amortecimento = 500,
		},
	}
end

local function persistVehicleInMasterStore(userId, nomeInventario)
	local ok = false
	for attempt = 1, 4 do
		local success = pcall(function()
			MasterDataStore:UpdateAsync(tostring(userId), function(dadosAntigos)
				local dados = dadosAntigos or {}
				dados.Inventario = dados.Inventario or {}
				if dados.Inventario[nomeInventario] ~= nil then
					return dados
				end
				dados.Inventario[nomeInventario] = defaultVehicleSaveBlock()
				return dados
			end)
		end)
		if success then
			ok = true
			break
		end
		task.wait(1.5)
	end
	return ok
end

local function addVehicleToPlayerInventoryFolder(player, nomeInventario)
	local inv = player:FindFirstChild("InventarioVeiculos")
	if not inv then
		return false
	end
	if inv:FindFirstChild(nomeInventario) then
		return true
	end
	local rec = Instance.new("StringValue")
	rec.Name = nomeInventario
	rec.Value = "Comprado"
	rec:SetAttribute("CorDoCarro", "")
	rec:SetAttribute("MotorAtual", 0)
	rec:SetAttribute("CombustivelSalvo", 100)
	rec:SetAttribute("FL", "Padrao")
	rec:SetAttribute("FR", "Padrao")
	rec:SetAttribute("RL", "Padrao")
	rec:SetAttribute("RR", "Padrao")
	rec:SetAttribute("SuspensaoNome", "Padrao")
	rec:SetAttribute("SuspensaoAltura", 2)
	rec:SetAttribute("SuspensaoRigidez", 4500)
	rec:SetAttribute("SuspensaoAmortecimento", 500)
	rec.Parent = inv
	return true
end

local function deliverVehicleGrant(userId, nomeInventario)
	if not persistVehicleInMasterStore(userId, nomeInventario) then
		warn("[EntregaSiteExterno] DataStore falhou ao registar veículo", nomeInventario, userId)
		return false
	end
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		addVehicleToPlayerInventoryFolder(plr, nomeInventario)
		notificarCompraSiteLoja(plr, "🛒 " .. nomeVeiculoLegivel(nomeInventario))
	end
	return true
end

--- Mesma curva de nível que GerenciadorDeDadosMaster (XP → Level).
local function levelFromTotalXp(xpTotal)
	xpTotal = math.floor(tonumber(xpTotal) or 0)
	if xpTotal < 0 then
		xpTotal = 0
	end
	local xpNecessario, multiplicador, levelCalculado, xpAcumulado = 1000, 1.3, 1, 0
	while xpTotal >= (xpAcumulado + xpNecessario) do
		xpAcumulado = xpAcumulado + xpNecessario
		levelCalculado = levelCalculado + 1
		xpNecessario = math.floor(xpNecessario * multiplicador)
	end
	return levelCalculado
end

local function persistEconomyGrant(userId, addMoney, addXp)
	addMoney = math.floor(tonumber(addMoney) or 0)
	addXp = math.floor(tonumber(addXp) or 0)
	if addMoney < 0 or addXp < 0 then
		return false
	end
	if addMoney == 0 and addXp == 0 then
		return false
	end
	local ok = false
	for attempt = 1, 4 do
		local success = pcall(function()
			MasterDataStore:UpdateAsync(tostring(userId), function(dadosAntigos)
				local dados = dadosAntigos or {}
				local d = math.floor(tonumber(dados.Dinheiro) or 0) + addMoney
				local x = math.floor(tonumber(dados.XP) or 0) + addXp
				if d < 0 then
					d = 0
				end
				if x < 0 then
					x = 0
				end
				dados.Dinheiro = d
				dados.XP = x
				dados.Level = levelFromTotalXp(x)
				return dados
			end)
		end)
		if success then
			ok = true
			break
		end
		task.wait(1.5)
	end
	return ok
end

local function applyEconomyToOnlinePlayer(player, addMoney, addXp)
	addMoney = math.floor(tonumber(addMoney) or 0)
	addXp = math.floor(tonumber(addXp) or 0)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return false
	end
	local di = ls:FindFirstChild("Dinheiro")
	local xp = ls:FindFirstChild("XP")
	if not di or not di:IsA("IntValue") then
		return false
	end
	if not xp or not xp:IsA("IntValue") then
		return false
	end
	if addMoney ~= 0 then
		di.Value = math.max(0, di.Value + addMoney)
	end
	if addXp ~= 0 then
		xp.Value = math.max(0, xp.Value + addXp)
	end
	return true
end

local function tituloNotificacaoEconomia(addMoney, addXp)
	local partes = {}
	if addMoney > 0 then
		table.insert(partes, "💰 +" .. tostring(addMoney) .. " moedas")
	end
	if addXp > 0 then
		table.insert(partes, "⭐ +" .. tostring(addXp) .. " XP")
	end
	if #partes == 0 then
		return "🛒 Compra Gear Shop"
	end
	return table.concat(partes, " · ")
end

local function deliverEconomyGrant(userId, addMoney, addXp)
	addMoney = math.floor(tonumber(addMoney) or 0)
	addXp = math.floor(tonumber(addXp) or 0)
	if not persistEconomyGrant(userId, addMoney, addXp) then
		warn("[EntregaSiteExterno] DataStore falhou (Dinheiro/XP) userId=", userId)
		return false
	end
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		applyEconomyToOnlinePlayer(plr, addMoney, addXp)
		notificarCompraSiteLoja(plr, tituloNotificacaoEconomia(addMoney, addXp))
	end
	return true
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
		local code = tonumber(res.StatusCode) or 0
		local hint = ""
		if code == 401 then
			hint = " (Bearer ≠ ROBLOX_API_SECRET no servidor — copia o secret do painel Render para aqui)"
		elseif code == 503 then
			hint = " (bot sem ROBLOX_API_SECRET no Render?)"
		end
		error("HTTP " .. tostring(res.StatusCode) .. hint .. " " .. tostring(res.Body or ""))
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
	local grantType = string.lower(tostring(g.grantType or g.grant_type or "vip"))
	local tier = g.grantTier or g.grant_tier

	if grantType == "vehicle" then
		local vid = g.grantVehicleId or g.grant_vehicle_id
		if type(vid) ~= "string" or vid == "" then
			return false
		end
		if not string.match(vid, "^[%w%-_]+$") then
			warn("[EntregaSiteExterno] grantVehicleId inválido:", vid)
			return false
		end
		local uid = player.UserId
		if deliverVehicleGrant(uid, vid) then
			print("[EntregaSiteExterno] Veículo entregue:", vid, "userId:", uid)
			return true
		end
		return false
	end

	if grantType == "currency" then
		local amt = math.floor(tonumber(g.grantMoneyAmount or g.grant_money_amount) or 0)
		if amt < 1 then
			return false
		end
		local uid = player.UserId
		if deliverEconomyGrant(uid, amt, 0) then
			print("[EntregaSiteExterno] Moedas entregues:", amt, "userId:", uid)
			return true
		end
		return false
	end

	if grantType == "xp" then
		local amt = math.floor(tonumber(g.grantXpAmount or g.grant_xp_amount) or 0)
		if amt < 1 then
			return false
		end
		local uid = player.UserId
		if deliverEconomyGrant(uid, 0, amt) then
			print("[EntregaSiteExterno] XP entregue:", amt, "userId:", uid)
			return true
		end
		return false
	end

	if grantType == "economy" then
		local addM = math.floor(tonumber(g.grantMoneyAmount or g.grant_money_amount) or 0)
		local addX = math.floor(tonumber(g.grantXpAmount or g.grant_xp_amount) or 0)
		if addM < 1 and addX < 1 then
			return false
		end
		local uid = player.UserId
		if deliverEconomyGrant(uid, addM, addX) then
			print("[EntregaSiteExterno] Economia entregue $", addM, "+XP", addX, "userId:", uid)
			return true
		end
		return false
	end

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
			notificarCompraSiteLoja(player, "👑 VIP " .. tier)
			print("[EntregaSiteExterno] VIP entregue:", tier, "dias:", dias, "userId:", uid)
			return true
		end
		warn("[EntregaSiteExterno] DataStore UpdateAsync falhou para", tier, uid)
	elseif grantType == "vip" and tier and tier ~= "" and not VIP_LEVELS[tier] then
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

	--- Antes: loop limitado (ex.: 60×12s ≈ 12 min) — depois parava e só voltava a entregar ao relogar.
	while player.Parent do
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

local function startDeliveryFor(player)
	task.spawn(function()
		runDeliveryLoop(player)
	end)
end

Players.PlayerAdded:Connect(startDeliveryFor)

--- Jogadores que já estavam no servidor quando o script iniciou (PlayerAdded não volta a disparar).
for _, p in ipairs(Players:GetPlayers()) do
	startDeliveryFor(p)
end
