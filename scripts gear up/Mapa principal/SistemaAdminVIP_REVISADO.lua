-- CH Corporations - Sistema Admin VIP (Animação de doação + anúncio global)
-- Revisão: lista de VIPs por tokens (sem gsub perigoso); validação de admin/nível/dias;
--          UpdateAsync com retry; Subscribe com dados validados; AnuncioGlobalEvent ao conceder VIP.
--          SkipCelebracao: quando EntregaSiteExterno envia VIP da loja site (toast já dispara lá; evita duplicar).

print("CH Corporations - Sistema Admin VIP (Atualizado c/ Anúncio Global)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")

local MasterDataStore = DataStoreService:GetDataStore("SaveGlobal_V2")
local CANAL_VIP = "AtualizacaoVipAoVivo"

local VIP_LEVELS = {
	Bronze = true,
	Gold = true,
	Diamante = true,
}

local eventoCelebracao = ReplicatedStorage:FindFirstChild("CelebracaoCompraEvent")
if not eventoCelebracao then
	eventoCelebracao = Instance.new("RemoteEvent")
	eventoCelebracao.Name = "CelebracaoCompraEvent"
	eventoCelebracao.Parent = ReplicatedStorage
end

local eventoAnuncio = ReplicatedStorage:FindFirstChild("AnuncioGlobalEvent")
if not eventoAnuncio then
	eventoAnuncio = Instance.new("RemoteEvent")
	eventoAnuncio.Name = "AnuncioGlobalEvent"
	eventoAnuncio.Parent = ReplicatedStorage
end

local ADMS = {
	CheechSC = true,
	DDdaZZ26 = true,
}

local ADM_USERIDS = {
	-- [123456789] = true,
}

local function isAdmin(player)
	return ADM_USERIDS[player.UserId] == true or ADMS[player.Name] == true
end

local eventoAdmin = ReplicatedStorage:FindFirstChild("DoarVipCrossServer")
if not eventoAdmin then
	eventoAdmin = Instance.new("RemoteEvent")
	eventoAdmin.Name = "DoarVipCrossServer"
	eventoAdmin.Parent = ReplicatedStorage
end

-- --- VIP string como lista de tokens (vírgula) ---
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

local function listToVipString(tokens)
	if #tokens == 0 then
		return "Comum"
	end
	return table.concat(tokens, ",")
end

local function listContains(tokens, nivel)
	for _, v in ipairs(tokens) do
		if v == nivel then
			return true
		end
	end
	return false
end

local function listRemove(tokens, nivel)
	local out = {}
	for _, v in ipairs(tokens) do
		if v ~= nivel then
			table.insert(out, v)
		end
	end
	return out
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

local function resolverUserIdAlvo(nomeAlvo)
	if type(nomeAlvo) ~= "string" or nomeAlvo == "" then
		return nil
	end
	local alvoLower = string.lower(nomeAlvo)
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == alvoLower or string.lower(p.DisplayName) == alvoLower then
			return p.UserId
		end
	end
	local uid = nil
	pcall(function()
		uid = Players:GetUserIdFromNameAsync(nomeAlvo)
	end)
	return uid
end

local function updateDataStoreVip(targetUserId, vipDesejado, diasDesejados, isRemovendo)
	local novaExpiracaoCalculada = 0
	local ok = false

	for attempt = 1, 4 do
		local success = pcall(function()
			MasterDataStore:UpdateAsync(tostring(targetUserId), function(dadosAntigos)
				local dados = dadosAntigos or {}
				local tokens = parseVipList(dados.VipSalvo or "Comum")

				if isRemovendo then
					tokens = listRemove(tokens, vipDesejado)
					dados.VipSalvo = listToVipString(tokens)
					dados["Exp" .. vipDesejado] = 0
					novaExpiracaoCalculada = 0
				else
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

local function obterExpGaveta(jogador, nivel, timeoutSec)
	local nome = "Exp" .. nivel
	local t0 = os.clock()
	repeat
		local g = jogador:FindFirstChild(nome)
		if g and g:IsA("NumberValue") then
			return g
		end
		task.wait(0.25)
	until os.clock() - t0 > (timeoutSec or 8)
	return jogador:FindFirstChild(nome)
end

local function aplicarMensagemNoJogadorOnline(dados)
	if type(dados) ~= "table" or type(dados.UserId) ~= "number" then
		return
	end
	local nivel = dados.NovoVip
	if type(nivel) ~= "string" or not VIP_LEVELS[nivel] then
		return
	end

	local jogadorSortudo = Players:GetPlayerByUserId(dados.UserId)
	if not jogadorSortudo then
		return
	end

	local vipSalvo = jogadorSortudo:FindFirstChild("VipSalvo")
	if not vipSalvo then
		return
	end

	local expGaveta = obterExpGaveta(jogadorSortudo, nivel, 10)
	if not expGaveta or not expGaveta:IsA("NumberValue") then
		warn("[SistemaAdminVIP] Sem Exp" .. nivel .. " para " .. jogadorSortudo.Name .. "; dados em nuvem já atualizados.")
		return
	end

	if dados.IsRemovendo == true then
		local tokens = parseVipList(vipSalvo.Value)
		tokens = listRemove(tokens, nivel)
		vipSalvo.Value = listToVipString(tokens)
		expGaveta.Value = 0

		local tagPreferida = jogadorSortudo:FindFirstChild("TagPreferida")
		if tagPreferida and tagPreferida.Value == nivel then
			tagPreferida.Value = "Comum"
		end
	else
		local tokens = parseVipList(vipSalvo.Value)
		tokens = listAdd(tokens, nivel)
		vipSalvo.Value = listToVipString(tokens)
		expGaveta.Value = tonumber(dados.NovaExp) or 0

		-- EntregaSiteExterno (loja site) envia SkipCelebracao; o toast já dispara lá (CelebracaoCompraEvent).
		if not dados.SkipCelebracao then
			eventoCelebracao:FireClient(jogadorSortudo, "👑 VIP " .. nivel, true)
			if eventoAnuncio then
				eventoAnuncio:FireAllClients(jogadorSortudo.Name, "👑 VIP " .. nivel, true)
			end
		end
	end
end

eventoAdmin.OnServerEvent:Connect(function(adminPlayer, nomeAlvo, vipDesejado, diasDesejados)
	if not isAdmin(adminPlayer) then
		return
	end
	if type(nomeAlvo) ~= "string" or nomeAlvo == "" then
		return
	end
	if type(vipDesejado) ~= "string" or not VIP_LEVELS[vipDesejado] then
		return
	end

	diasDesejados = tonumber(diasDesejados) or 0
	local isRemovendo = diasDesejados == -1

	if not isRemovendo then
		if diasDesejados < 0 then
			return
		end
		if diasDesejados > 3650 then
			diasDesejados = 3650
		end
	end

	local targetUserId = resolverUserIdAlvo(nomeAlvo)
	if not targetUserId then
		return
	end

	local successUpdate, novaExpiracaoCalculada = updateDataStoreVip(targetUserId, vipDesejado, diasDesejados, isRemovendo)

	if successUpdate then
		pcall(function()
			MessagingService:PublishAsync(CANAL_VIP, {
				UserId = targetUserId,
				NovoVip = vipDesejado,
				NovaExp = novaExpiracaoCalculada,
				IsRemovendo = isRemovendo,
			})
		end)
		-- Aplicação ao jogador online fica só no Subscribe (inclui este servidor) — evita animação duplicada
	end
end)

local okSub, errSub = pcall(function()
	MessagingService:SubscribeAsync(CANAL_VIP, function(message)
		local dados = message and message.Data
		aplicarMensagemNoJogadorOnline(dados)
	end)
end)
if not okSub then
	warn("[SistemaAdminVIP] SubscribeAsync falhou: " .. tostring(errSub))
end
