-- CH Corporations - Sistema de Casas (Atualizado c/ Auto-Spawn VIP Blindado)
-- Revisão: preço/level só no servidor (anti-exploit); WaitForChild com timeout;
--          favorito validado no inventário; spawn sem task.wait bloqueante; whitelist por UserId;
--          FireClient só se o jogador ainda estiver no jogo.

print("CH Corporations - Sistema de Casas (Atualizado c/ Auto-Spawn VIP Blindado)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ID_BRONZE = 1737108751
local ID_GOLD = 1746268685
local ID_DIAMANTE = 1746862603

-- ⚠️ Preços e levels oficiais (cliente NÃO manda valores confiáveis)
-- Adiciona aqui cada casa comprável por dinheiro (nome = StringValue.Name no inventário)
local CATALOGO_CASAS_COMPRAVEIS = {
	-- ["CasaExemplo"] = { Preco = 50000, LevelMin = 10 },
}

local spawnarCasaEvent = ReplicatedStorage:WaitForChild("SpawnarCasaEvent", 120)
if not spawnarCasaEvent then
	warn("[SistemaCasas] SpawnarCasaEvent não encontrado.")
end

local comprarCasaEvent = ReplicatedStorage:FindFirstChild("ComprarCasaEvent") or Instance.new("RemoteEvent")
comprarCasaEvent.Name = "ComprarCasaEvent"
comprarCasaEvent.Parent = ReplicatedStorage

local favoritarEvent = ReplicatedStorage:FindFirstChild("FavoritarCarroEvent") or Instance.new("RemoteEvent")
favoritarEvent.Name = "FavoritarCarroEvent"
favoritarEvent.Parent = ReplicatedStorage

local autoSpawnClientEvent = ReplicatedStorage:FindFirstChild("AutoSpawnVIPClientEvent") or Instance.new("RemoteEvent")
autoSpawnClientEvent.Name = "AutoSpawnVIPClientEvent"
autoSpawnClientEvent.Parent = ReplicatedStorage

local lotesDasCasas = Workspace:WaitForChild("LotesDasCasas", 120)
if not lotesDasCasas then
	warn("[SistemaCasas] LotesDasCasas não encontrado no Workspace.")
end

local casasSalvas = ServerStorage:WaitForChild("CasasSalvas", 120)
if not casasSalvas then
	warn("[SistemaCasas] CasasSalvas não encontrado no ServerStorage.")
end

local terrenosGuardados = ServerStorage:FindFirstChild("TerrenosGuardados")
if not terrenosGuardados then
	terrenosGuardados = Instance.new("Folder")
	terrenosGuardados.Name = "TerrenosGuardados"
	terrenosGuardados.Parent = ServerStorage
end

-- Gamepasses que concedem casa (ajusta IDs; remove placeholder quando tiver ID real)
local casasGamepass = {
	[1740782891] = "CasaBase",
	-- [987654321] = "Casa_Na_Arvore" -- placeholder
}

-- Staff: UserIds (preferido)
local WHITELIST_USERIDS = {
	-- [123456789] = true,
}

-- Staff: usernames (Player.Name no servidor = username da conta)
local WHITELIST_USERNAMES = {
	CheechSC = true,
	DDdaZZ26 = true,
}

local function jogadorTemCasaNaGamepass(inv, nomeDaCasa)
	local rec = inv:FindFirstChild(nomeDaCasa)
	return rec and (rec.Value == "Comprada_VIP" or rec.Value == "Comprada")
end

local function concederCasaSeGamepass(player, nomeDaCasa)
	local inv = player:FindFirstChild("InventarioCasas")
	if not inv or inv:FindFirstChild(nomeDaCasa) then
		return
	end
	local nova = Instance.new("StringValue")
	nova.Name = nomeDaCasa
	nova.Value = "Comprada_VIP"
	nova.Parent = inv
end

local function sincronizarCasasDeGamepass(player)
	local inv = player:FindFirstChild("InventarioCasas")
	if not inv then
		return
	end
	for passId, nomeDaCasa in pairs(casasGamepass) do
		local success, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if success and hasPass then
			concederCasaSeGamepass(player, nomeDaCasa)
		end
	end
end

-- =========================================================
-- FAVORITAR (valida nome do carro no inventário)
-- =========================================================
favoritarEvent.OnServerEvent:Connect(function(player, nomeDoCarro)
	if type(nomeDoCarro) ~= "string" or nomeDoCarro == "" then
		return
	end

	local inv = player:FindFirstChild("InventarioVeiculos")
	if not inv or not inv:FindFirstChild(nomeDoCarro) then
		return
	end

	local carData = player:FindFirstChild("CarData")
	if not carData then
		return
	end
	local fav = carData:FindFirstChild("CarroFavorito")
	if not fav then
		return
	end

	if fav.Value == nomeDoCarro then
		fav.Value = ""
		print("⭐ " .. player.Name .. " removeu o favorito.")
	else
		fav.Value = nomeDoCarro
		print("⭐ " .. player.Name .. " favoritou: " .. nomeDoCarro)
	end
end)

-- =========================================================
-- PLAYER ADDED — inventário + gamepasses de casa
-- =========================================================
Players.PlayerAdded:Connect(function(player)
	local inventarioCasas = player:WaitForChild("InventarioCasas", 30)
	if inventarioCasas then
		sincronizarCasasDeGamepass(player)
	else
		task.spawn(function()
			local inv = player:WaitForChild("InventarioCasas", 60)
			if inv then
				sincronizarCasasDeGamepass(player)
			end
		end)
	end
end)

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(sincronizarCasasDeGamepass, p)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then
		return
	end
	local nomeDaCasa = casasGamepass[gamePassId]
	if not nomeDaCasa then
		return
	end
	concederCasaSeGamepass(player, nomeDaCasa)
end)

-- =========================================================
-- COMPRAR CASA — valores só do CATALOGO_CASAS_COMPRAVEIS
-- Cliente pode ainda enviar (nome, preco, level); preco/level têm de bater com o catálogo
-- =========================================================
comprarCasaEvent.OnServerEvent:Connect(function(player, nomeDaCasa, precoCliente, levelCliente)
	if type(nomeDaCasa) ~= "string" then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local dinheiro = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	local level = leaderstats and leaderstats:FindFirstChild("Level")
	local inv = player:FindFirstChild("InventarioCasas")

	if not dinheiro or not level or not inv or inv:FindFirstChild(nomeDaCasa) then
		return
	end

	local cfg = CATALOGO_CASAS_COMPRAVEIS[nomeDaCasa]
	if not cfg then
		return
	end

	-- Opcional: exige que o cliente não minta (compatível com UI antiga que manda preço/level)
	if precoCliente ~= nil and precoCliente ~= cfg.Preco then
		return
	end
	if levelCliente ~= nil and levelCliente ~= cfg.LevelMin then
		return
	end

	if level.Value < cfg.LevelMin then
		return
	end
	if dinheiro.Value < cfg.Preco then
		return
	end

	dinheiro.Value = dinheiro.Value - cfg.Preco
	local nova = Instance.new("StringValue")
	nova.Name = nomeDaCasa
	nova.Value = "Comprada"
	nova.Parent = inv
end)

-- =========================================================
-- VIP — cache por sessão (menos chamadas ao Marketplace)
-- =========================================================
local cacheGamePassVip = {}

local function jogadorEhVipOficial(player)
	local uid = player.UserId
	if cacheGamePassVip[uid] ~= nil then
		return cacheGamePassVip[uid]
	end
	local tem = false
	pcall(function()
		if MarketplaceService:UserOwnsGamePassAsync(uid, ID_DIAMANTE)
			or MarketplaceService:UserOwnsGamePassAsync(uid, ID_GOLD)
			or MarketplaceService:UserOwnsGamePassAsync(uid, ID_BRONZE)
		then
			tem = true
		end
	end)
	cacheGamePassVip[uid] = tem
	return tem
end

local function jogadorEhVipParaAutospawn(player)
	if WHITELIST_USERIDS[player.UserId] or WHITELIST_USERNAMES[player.Name] then
		return true
	end

	local vipSalvo = player:FindFirstChild("VipSalvo")
	if vipSalvo and vipSalvo.Value ~= "Comum" and vipSalvo.Value ~= "" then
		return true
	end

	return jogadorEhVipOficial(player)
end

if not spawnarCasaEvent or not lotesDasCasas or not casasSalvas then
	warn("[SistemaCasas] SpawnarCasaEvent, LotesDasCasas ou CasasSalvas em falta — evento de spawn não ligado.")
end

-- =========================================================
-- SPAWNAR CASA
-- =========================================================
if spawnarCasaEvent and lotesDasCasas and casasSalvas then
	spawnarCasaEvent.OnServerEvent:Connect(function(player, nomeDaCasa, nomeDoLote)
		if type(nomeDaCasa) ~= "string" or type(nomeDoLote) ~= "string" then
			return
		end

		local inv = player:FindFirstChild("InventarioCasas")
		if not inv or not inv:FindFirstChild(nomeDaCasa) or not nomeDoLote then
			return
		end

		local lote = lotesDasCasas:FindFirstChild(nomeDoLote)
		if not lote then
			return
		end

		local donoAttr = lote:GetAttribute("Dono")
		if donoAttr and donoAttr ~= player.Name then
			return
		end

		for _, outroLote in ipairs(lotesDasCasas:GetChildren()) do
			if outroLote ~= lote and outroLote:GetAttribute("Dono") == player.Name then
				return
			end
		end

		local casaOriginal = casasSalvas:FindFirstChild(nomeDaCasa)
		if not casaOriginal then
			return
		end

		local casaAntiga = lote:FindFirstChild("CasaDo_" .. player.Name)
		if casaAntiga then
			casaAntiga:Destroy()
		end

		local terrenoVazio = lote:FindFirstChild("TerrenoVazio")
		if terrenoVazio then
			terrenoVazio.Name = "TerrenoVazio_" .. nomeDoLote
			terrenoVazio.Parent = terrenosGuardados
		end

		local novaCasa = casaOriginal:Clone()
		novaCasa.Name = "CasaDo_" .. player.Name
		local pontoDeSpawn = lote:FindFirstChild("PontoDeSpawn")
		if pontoDeSpawn and pontoDeSpawn:IsA("BasePart") then
			if novaCasa:IsA("Model") then
				novaCasa:PivotTo(pontoDeSpawn.CFrame)
			elseif novaCasa:IsA("BasePart") then
				novaCasa.CFrame = pontoDeSpawn.CFrame
			end
		end

		novaCasa.Parent = lote
		lote:SetAttribute("Dono", player.Name)

		-- Auto-spawn carro favorito (VIP)
		if jogadorEhVipParaAutospawn(player) then
			local carData = player:FindFirstChild("CarData")
			local fav = carData and carData:FindFirstChild("CarroFavorito")
			if fav and fav.Value ~= "" then
				local carroFav = fav.Value
				local carroAntigo = Workspace:FindFirstChild(player.Name .. "sCar")
				if carroAntigo then
					carroAntigo:Destroy()
				end

				task.delay(1, function()
					if not player.Parent then
						return
					end
					print("👑 Ping-Pong! Auto-Spawn VIP: " .. carroFav)
					autoSpawnClientEvent:FireClient(player, carroFav)
				end)
			end
		end

		-- Ícone da casa (não bloquear o handler com task.wait)
		if pontoDeSpawn and pontoDeSpawn:IsA("BasePart") then
			task.delay(1.5, function()
				if not player.Parent then
					return
				end
				local playerGui = player:FindFirstChild("PlayerGui")
				if not playerGui then
					return
				end

				local iconeAntigo = playerGui:FindFirstChild("IconeCasaPropria")
				if iconeAntigo then
					iconeAntigo:Destroy()
				end

				if not pontoDeSpawn.Parent then
					return
				end

				local placa = Instance.new("BillboardGui")
				placa.Name = "IconeCasaPropria"
				placa.Adornee = pontoDeSpawn
				placa.Size = UDim2.new(0, 80, 0, 80)
				placa.StudsOffset = Vector3.new(0, 25, 0)
				placa.AlwaysOnTop = true
				placa.Parent = playerGui

				local imagem = Instance.new("ImageLabel")
				imagem.Size = UDim2.new(1, 0, 1, 0)
				imagem.BackgroundTransparency = 1
				imagem.Image = "rbxassetid://136846519625099"
				imagem.Parent = placa
			end)
		end
	end)
end
