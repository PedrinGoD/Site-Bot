-- CH Corporations - Sistema de Dados Master (Sincronizado V2 c/ Entregador + CH-OS)
-- Revisão: retries em GetAsync, sem bloquear join em RodasSalvas, mochila resiliente,
--          checagem de StatsCorrida no save, autosave periódico, BindToClose com mais margem,
--          Prateleira: slots via FindFirstChild (save não quebra), load com salvo ~= nil,
--          Tools/caixas-base no ServerStorage com busca recursiva.

print("CH Corporations - GDM (mapa de corrida — mesmo fluxo SaveGlobal_V2 que o mapa principal)")

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")

local ID_BRONZE = 1737108751
local ID_GOLD = 1746268685
local ID_DIAMANTE = 1746862603

local MasterDataStore = DataStoreService:GetDataStore("SaveGlobal_V2")
local salvamentoEmAndamento = {}
local dadosCarregadosSeguros = {}

local evAtualizarRanking = ReplicatedStorage:FindFirstChild("AtualizarRankingEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
evAtualizarRanking.Name = "AtualizarRankingEvent"

local evDadosProntos = ReplicatedStorage:FindFirstChild("DadosProntosEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
evDadosProntos.Name = "DadosProntosEvent"

local cacheSemanal, cacheMensal = {}, {}

local function GetSemanaAtual()
	return tostring(math.floor(os.time() / 604800))
end

local function GetMesAtual()
	return os.date("%m_%Y")
end

-- Pasta RodasSalvas: carrega sob demanda (nunca bloqueia o join inteiro)
local rodasSalvasCache = nil
local function obterRodasSalvas()
	if rodasSalvasCache and rodasSalvasCache.Parent then
		return rodasSalvasCache
	end
	rodasSalvasCache = ReplicatedStorage:FindFirstChild("RodasSalvas")
	if rodasSalvasCache then
		return rodasSalvasCache
	end
	rodasSalvasCache = ReplicatedStorage:WaitForChild("RodasSalvas", 20)
	return rodasSalvasCache
end

-- =========================================================
-- CARREGAMENTO DE DADOS
-- =========================================================
Players.PlayerAdded:Connect(function(player)
	local joinData = player:GetJoinData()
	if joinData and joinData.TeleportData and joinData.TeleportData.VoltandoDaCorrida then
		task.wait(3.5)
	end

	salvamentoEmAndamento[player.UserId] = nil
	dadosCarregadosSeguros[player.UserId] = false

	-- GetAsync com retries (falhas transitórias são comuns)
	local data = nil
	local loadOk = false
	for attempt = 1, 5 do
		local ok, result = pcall(function()
			return MasterDataStore:GetAsync(tostring(player.UserId))
		end)
		if ok then
			loadOk = true
			data = result
			break
		end
		warn(string.format("[GerenciadorDeDadosMaster] GetAsync falhou (tentativa %d/5) UserId=%s: %s", attempt, tostring(player.UserId), tostring(result)))
		task.wait(math.min(attempt * 2, 10))
	end

	if not loadOk then
		player:Kick("Falha ao carregar seus dados. Tente entrar novamente em instantes.")
		return
	end

	dadosCarregadosSeguros[player.UserId] = true

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local dinheiro = Instance.new("IntValue")
	dinheiro.Name = "Dinheiro"
	dinheiro.Parent = leaderstats

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats

	local xp = Instance.new("IntValue")
	xp.Name = "XP"
	xp.Parent = leaderstats

	local vitoriasGlobais = Instance.new("IntValue")
	vitoriasGlobais.Name = "Vitorias"
	vitoriasGlobais.Parent = leaderstats

	local likesGlobais = Instance.new("IntValue")
	likesGlobais.Name = "Likes"
	likesGlobais.Parent = leaderstats

	local vipSalvo = Instance.new("StringValue")
	vipSalvo.Name = "VipSalvo"
	vipSalvo.Parent = player

	local expBronze = Instance.new("NumberValue")
	expBronze.Name = "ExpBronze"
	expBronze.Parent = player

	local expGold = Instance.new("NumberValue")
	expGold.Name = "ExpGold"
	expGold.Parent = player

	local expDiamante = Instance.new("NumberValue")
	expDiamante.Name = "ExpDiamante"
	expDiamante.Parent = player

	local tagPreferida = Instance.new("StringValue")
	tagPreferida.Name = "TagPreferida"
	tagPreferida.Parent = player

	local gasolinaData = Instance.new("Folder")
	gasolinaData.Name = "GasolinaData"
	gasolinaData.Parent = player

	local playlistData = Instance.new("Folder")
	playlistData.Name = "PlaylistData"
	playlistData.Parent = player

	local portaMalasBackup = Instance.new("Folder")
	portaMalasBackup.Name = "PortaMalasBackup"
	portaMalasBackup.Parent = player

	local tutorialCompleto = Instance.new("BoolValue")
	tutorialCompleto.Name = "TutorialCompleto"
	tutorialCompleto.Parent = player

	local statsCorrida = Instance.new("Folder")
	statsCorrida.Name = "StatsCorrida"
	statsCorrida.Parent = player

	local likesData = Instance.new("Folder")
	likesData.Name = "LikesData"
	likesData.Parent = player

	local wallpaperCelular = Instance.new("StringValue")
	wallpaperCelular.Name = "WallpaperCelular"
	wallpaperCelular.Parent = player

	local brilhoCelular = Instance.new("NumberValue")
	brilhoCelular.Name = "BrilhoCelular"
	brilhoCelular.Parent = player

	local vitSemana = Instance.new("IntValue")
	vitSemana.Name = "VitoriasSemanais"
	vitSemana.Parent = statsCorrida

	local semanaID = Instance.new("StringValue")
	semanaID.Name = "SemanaID"
	semanaID.Parent = statsCorrida

	local vitMes = Instance.new("IntValue")
	vitMes.Name = "VitoriasMensais"
	vitMes.Parent = statsCorrida

	local mesID = Instance.new("StringValue")
	mesID.Name = "MesID"
	mesID.Parent = statsCorrida

	local function atualizarLevel()
		local xpTotal, xpNecessario, multiplicador, levelCalculado, xpAcumulado = xp.Value, 1000, 1.3, 1, 0
		while xpTotal >= (xpAcumulado + xpNecessario) do
			xpAcumulado = xpAcumulado + xpNecessario
			levelCalculado = levelCalculado + 1
			xpNecessario = math.floor(xpNecessario * multiplicador)
		end
		if levelCalculado > level.Value then
			level.Value = levelCalculado
		end
	end
	xp:GetPropertyChangedSignal("Value"):Connect(atualizarLevel)

	local carData = Instance.new("Folder")
	carData.Name = "CarData"
	carData.Parent = player

	local carroFavorito = Instance.new("StringValue")
	carroFavorito.Name = "CarroFavorito"
	carroFavorito.Parent = carData

	local inventario = Instance.new("Folder")
	inventario.Name = "InventarioVeiculos"
	inventario.Parent = player

	local inventarioCasas = Instance.new("Folder")
	inventarioCasas.Name = "InventarioCasas"
	inventarioCasas.Parent = player

	local inventarioFerramentas = Instance.new("Folder")
	inventarioFerramentas.Name = "InventarioFerramentas"
	inventarioFerramentas.Parent = player

	local prateleiraData = Instance.new("Folder")
	prateleiraData.Name = "PrateleiraData"
	prateleiraData.Parent = player
	for i = 1, 24 do
		local slot = Instance.new("StringValue")
		slot.Name = "Slot" .. i
		slot.Parent = prateleiraData
	end

	if data then
		dinheiro.Value = data.Dinheiro or 0
		level.Value = data.Level or 1
		xp.Value = data.XP or 0
		vitoriasGlobais.Value = data.VitoriasGlobais or 0

		local totalLikes = 0
		if data.LikesPorCarro then
			for nomeCarro, qtdeLikes in pairs(data.LikesPorCarro) do
				local val = Instance.new("IntValue")
				val.Name = nomeCarro
				val.Value = qtdeLikes
				val.Parent = likesData
				totalLikes = totalLikes + qtdeLikes
			end
		end
		likesGlobais.Value = totalLikes

		local vipsAtuais = data.VipSalvo or "Comum"
		local eB, eG, eD = data.ExpBronze or 0, data.ExpGold or 0, data.ExpDiamante or 0
		local tempoHoje = os.time()

		if eB > 0 and tempoHoje > eB then
			vipsAtuais = string.gsub(vipsAtuais, "Bronze", "")
			eB = 0
		end
		if eG > 0 and tempoHoje > eG then
			vipsAtuais = string.gsub(vipsAtuais, "Gold", "")
			eG = 0
		end
		if eD > 0 and tempoHoje > eD then
			vipsAtuais = string.gsub(vipsAtuais, "Diamante", "")
			eD = 0
		end

		vipsAtuais = string.gsub(vipsAtuais, ",+", ",")
		vipsAtuais = string.gsub(vipsAtuais, "^,", "")
		vipsAtuais = string.gsub(vipsAtuais, ",$", "")
		if vipsAtuais == "" then
			vipsAtuais = "Comum"
		end

		vipSalvo.Value = vipsAtuais
		expBronze.Value = eB
		expGold.Value = eG
		expDiamante.Value = eD

		local tagCarregada = data.TagPreferida or ""
		if tagCarregada ~= "" and tagCarregada ~= "Comum" then
			if not string.find(vipsAtuais, tagCarregada) then
				local temPass = false
				pcall(function()
					if tagCarregada == "Diamante" then
						temPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_DIAMANTE)
					elseif tagCarregada == "Gold" then
						temPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_GOLD)
					elseif tagCarregada == "Bronze" then
						temPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_BRONZE)
					end
				end)
				if not temPass then
					tagCarregada = "Comum"
				end
			end
		end
		tagPreferida.Value = tagCarregada

		if data.TutorialCompleto ~= nil then
			tutorialCompleto.Value = data.TutorialCompleto
		end

		local currSemana = GetSemanaAtual()
		vitSemana.Value = (data.SemanaID == currSemana) and (data.VitoriasSemanais or 0) or 0
		semanaID.Value = currSemana

		local currMes = GetMesAtual()
		vitMes.Value = (data.MesID == currMes) and (data.VitoriasMensais or 0) or 0
		mesID.Value = currMes

		carroFavorito.Value = data.CarroFavorito or ""
		wallpaperCelular.Value = data.WallpaperCelular or "rbxassetid://101669118895000"
		brilhoCelular.Value = data.BrilhoCelular or 1

		--- nil / omitido no JSON = roda de fábrica (mesmo significado que "Padrao" antigo).
		local function attrRodaOuNilParaFabrica(configCarro, rodasLegado, chave)
			local v = configCarro[chave]
			if typeof(v) == "string" then
				local s = string.gsub(v, "^%s+", "")
				s = string.gsub(s, "%s+$", "")
				if s ~= "" and s ~= "Padrao" then
					return s
				end
			end
			local a = rodasLegado[chave]
			if typeof(a) == "string" then
				local s = string.gsub(a, "^%s+", "")
				s = string.gsub(s, "%s+$", "")
				if s ~= "" and s ~= "Padrao" then
					return a
				end
			end
			return nil
		end

		if data.Inventario then
			for k, v in pairs(data.Inventario) do
				local nomeCarro = type(k) == "number" and v or k
				local configCarro = type(v) == "table" and v or {}

				local rec = Instance.new("StringValue")
				rec.Name = nomeCarro
				rec.Value = "Comprado"
				rec.Parent = inventario

				rec:SetAttribute("CorDoCarro", configCarro.CorDoCarro or (data.CorDoCarro or ""))
				rec:SetAttribute("MotorAtual", configCarro.MotorAtual or (data.Motor or 0))
				rec:SetAttribute("CombustivelSalvo", configCarro.CombustivelSalvo or 100)

				local rodasAntigas = data.Rodas or {}
				for _, rk in ipairs({ "FL", "FR", "RL", "RR" }) do
					local rv = attrRodaOuNilParaFabrica(configCarro, rodasAntigas, rk)
					if rv ~= nil then
						rec:SetAttribute(rk, rv)
					else
						rec:SetAttribute(rk, nil)
					end
				end

				local suspAntiga = data.Suspensao or {}
				local suspCarro = configCarro.Suspensao or {}

				rec:SetAttribute("SuspensaoNome", suspCarro.Nome or (suspAntiga.Nome or "Padrao"))
				rec:SetAttribute("SuspensaoAltura", suspCarro.Altura or (suspAntiga.Altura or 2))
				rec:SetAttribute("SuspensaoRigidez", suspCarro.Rigidez or (suspAntiga.Rigidez or 4500))
				rec:SetAttribute("SuspensaoAmortecimento", suspCarro.Amortecimento or (suspAntiga.Amortecimento or 500))
			end
		end

		if data.Casas then
			for _, n in ipairs(data.Casas) do
				local rec = Instance.new("StringValue")
				rec.Name = n
				rec.Value = "Comprada"
				rec.Parent = inventarioCasas
			end
		end
		if data.Ferramentas then
			for _, s in ipairs(data.Ferramentas) do
				local p = string.split(s, "|")
				local rec = Instance.new("StringValue")
				rec.Name = p[1]
				rec.Value = p[2] or "Comprada"
				rec.Parent = inventarioFerramentas
			end
		end
		if data.Prateleira then
			for i = 1, 24 do
				local sn = "Slot" .. i
				local slotInst = prateleiraData:FindFirstChild(sn)
				local salvo = data.Prateleira[sn]
				-- ~= nil: aceita string vazia (falsy em `if salvo` pularia de forma equivalente ao default "")
				if slotInst and slotInst:IsA("StringValue") and salvo ~= nil then
					slotInst.Value = salvo
				end
			end
		end
		if data.Gasolina then
			for k, v in pairs(data.Gasolina) do
				local val = Instance.new("NumberValue")
				val.Name = k
				val.Value = v
				val.Parent = gasolinaData
			end
		end
		if data.Playlist then
			for _, s in ipairs(data.Playlist) do
				local p = string.split(s, "|")
				local rec = Instance.new("StringValue")
				rec.Name = p[1]
				rec.Value = p[2] or "Musica"
				rec.Parent = playlistData
			end
		end

		atualizarLevel()
	else
		dinheiro.Value = 0
		level.Value = 1
		xp.Value = 0
		vitoriasGlobais.Value = 0
		likesGlobais.Value = 0
		vipSalvo.Value = "Comum"
		expBronze.Value = 0
		expGold.Value = 0
		expDiamante.Value = 0
		tagPreferida.Value = ""
		tutorialCompleto.Value = false
		vitSemana.Value = 0
		semanaID.Value = GetSemanaAtual()
		vitMes.Value = 0
		mesID.Value = GetMesAtual()
		wallpaperCelular.Value = "rbxassetid://101669118895000"
		brilhoCelular.Value = 1
	end

	-- Fábrica de ferramentas / mochila (não bloqueia DadosProntos)
	local function ReconstruirMochila(character)
		if not character then
			return
		end

		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			backpack = player:WaitForChild("Backpack", 12)
		end
		if not backpack then
			return
		end

		local rodasSalvas = obterRodasSalvas()
		if not rodasSalvas then
			warn("[GerenciadorDeDadosMaster] RodasSalvas indisponível; caixas de roda serão tentadas no próximo respawn.")
		end

		for _, record in ipairs(inventarioFerramentas:GetChildren()) do
			local nomeSalvo = record.Name
			-- recursive: ECU/outras Tools podem estar em subpastas do ServerStorage
			local toolOriginal = ServerStorage:FindFirstChild(nomeSalvo, true)

			if toolOriginal and toolOriginal:IsA("Tool") then
				if not backpack:FindFirstChild(nomeSalvo) and not character:FindFirstChild(nomeSalvo) then
					local novaTool = toolOriginal:Clone()

					if nomeSalvo == "TintaSpray" and record.Value ~= "Comprada" and record.Value ~= "" then
						local rgb = string.split(record.Value, ",")
						if #rgb == 3 then
							local corValue = Instance.new("Color3Value")
							corValue.Name = "CorDaTinta"
							corValue.Value = Color3.fromRGB(tonumber(rgb[1]) or 0, tonumber(rgb[2]) or 0, tonumber(rgb[3]) or 0)
							corValue.Parent = novaTool
						end
					end
					novaTool.Parent = backpack
				end
			elseif rodasSalvas then
				local nomeFormatado = string.gsub(nomeSalvo, "_", " ")
				local nomeDaCaixaFinal = "Caixa " .. nomeFormatado

				if not backpack:FindFirstChild(nomeDaCaixaFinal) and not character:FindFirstChild(nomeDaCaixaFinal) then
					local rodaOriginalDoCarro = rodasSalvas:FindFirstChild(nomeFormatado) or rodasSalvas:FindFirstChild(nomeSalvo)

					if rodaOriginalDoCarro then
						local isPremium = rodaOriginalDoCarro:GetAttribute("Premium") or false
						local nomeDaCaixaTemplate = isPremium and "CaixaPremium" or "CaixaBase"
						local caixaTemplate = ServerStorage:FindFirstChild(nomeDaCaixaTemplate, true)

						if caixaTemplate then
							local novaCaixaRoda = caixaTemplate:Clone()
							novaCaixaRoda.Name = nomeDaCaixaFinal

							local tipoDeRodaValue = Instance.new("StringValue")
							tipoDeRodaValue.Name = "TipoDeRoda"
							tipoDeRodaValue.Value = nomeFormatado
							tipoDeRodaValue.Parent = novaCaixaRoda

							novaCaixaRoda:SetAttribute("CliquesDeInstalacao", 0)
							if isPremium then
								novaCaixaRoda:SetAttribute("Premium", true)
							end

							novaCaixaRoda.Parent = backpack
						end
					end
				end
			end
		end
	end

	player.CharacterAdded:Connect(ReconstruirMochila)
	if player.Character then
		task.spawn(ReconstruirMochila, player.Character)
	end

	evDadosProntos:FireClient(player)
	evAtualizarRanking:FireClient(player, cacheSemanal, cacheMensal)
end)

-- =========================================================
-- SALVAMENTO DE DADOS E RANKING
-- =========================================================
local function SalvarDados(player)
	if not dadosCarregadosSeguros[player.UserId] or salvamentoEmAndamento[player.UserId] then
		return
	end
	salvamentoEmAndamento[player.UserId] = true

	local ls = player:FindFirstChild("leaderstats")
	local cd = player:FindFirstChild("CarData")
	local inv = player:FindFirstChild("InventarioVeiculos")
	local invC = player:FindFirstChild("InventarioCasas")
	local invF = player:FindFirstChild("InventarioFerramentas")
	local prat = player:FindFirstChild("PrateleiraData")
	local gas = player:FindFirstChild("GasolinaData")
	local play = player:FindFirstChild("PlaylistData")
	local stat = player:FindFirstChild("StatsCorrida")
	local lkData = player:FindFirstChild("LikesData")

	if not ls or not cd or not inv or not prat or not invC or not stat then
		salvamentoEmAndamento[player.UserId] = nil
		return
	end

	local function serializarAtributoRoda(recVeiculo, chave)
		local a = recVeiculo:GetAttribute(chave)
		if typeof(a) ~= "string" then
			return nil
		end
		local s = string.gsub(a, "^%s+", "")
		s = string.gsub(s, "%s+$", "")
		if s == "" or s == "Padrao" then
			return nil
		end
		return a
	end

	local cSalvos, caSalvas, fSalvas, pSave, gSave, plSave, lkSave = {}, {}, {}, {}, {}, {}, {}

	for _, v in ipairs(inv:GetChildren()) do
		cSalvos[v.Name] = {
			CorDoCarro = v:GetAttribute("CorDoCarro") or "",
			MotorAtual = v:GetAttribute("MotorAtual") or 0,
			CombustivelSalvo = v:GetAttribute("CombustivelSalvo") or 100,
			FL = serializarAtributoRoda(v, "FL"),
			FR = serializarAtributoRoda(v, "FR"),
			RL = serializarAtributoRoda(v, "RL"),
			RR = serializarAtributoRoda(v, "RR"),
			Suspensao = {
				Nome = v:GetAttribute("SuspensaoNome") or "Padrao",
				Altura = v:GetAttribute("SuspensaoAltura") or 2,
				Rigidez = v:GetAttribute("SuspensaoRigidez") or 4500,
				Amortecimento = v:GetAttribute("SuspensaoAmortecimento") or 500,
			},
		}
	end

	for _, v in ipairs(invC:GetChildren()) do
		table.insert(caSalvas, v.Name)
	end
	if invF then
		for _, v in ipairs(invF:GetChildren()) do
			table.insert(fSalvas, v.Name .. "|" .. v.Value)
		end
	end
	for i = 1, 24 do
		local sn = "Slot" .. i
		local slotInst = prat:FindFirstChild(sn)
		pSave[sn] = (slotInst and slotInst:IsA("StringValue")) and slotInst.Value or ""
	end
	if gas then
		for _, v in ipairs(gas:GetChildren()) do
			gSave[v.Name] = v.Value
		end
	end
	if play then
		for _, v in ipairs(play:GetChildren()) do
			table.insert(plSave, v.Name .. "|" .. v.Value)
		end
	end
	if lkData then
		for _, v in ipairs(lkData:GetChildren()) do
			lkSave[v.Name] = v.Value
		end
	end

	local dataToSave = {
		Dinheiro = ls.Dinheiro.Value,
		Level = ls.Level.Value,
		XP = ls.XP.Value,
		VitoriasGlobais = ls.Vitorias.Value,
		LikesPorCarro = lkSave,
		VitoriasSemanais = stat.VitoriasSemanais.Value,
		SemanaID = stat.SemanaID.Value,
		VitoriasMensais = stat.VitoriasMensais.Value,
		MesID = stat.MesID.Value,
		VipSalvo = player.VipSalvo.Value,
		ExpBronze = player.ExpBronze.Value,
		ExpGold = player.ExpGold.Value,
		ExpDiamante = player.ExpDiamante.Value,
		TagPreferida = player.TagPreferida.Value,
		Inventario = cSalvos,
		Casas = caSalvas,
		Ferramentas = fSalvas,
		Prateleira = pSave,
		Gasolina = gSave,
		CarroFavorito = cd.CarroFavorito.Value,
		Playlist = plSave,
		TutorialCompleto = player.TutorialCompleto.Value,
		WallpaperCelular = player.WallpaperCelular.Value,
		BrilhoCelular = player.BrilhoCelular.Value,
	}

	local tentativas, success = 0, false
	repeat
		success = pcall(function()
			MasterDataStore:SetAsync(tostring(player.UserId), dataToSave)
		end)
		tentativas += 1
		if not success then
			task.wait(2)
		end
	until success or tentativas >= 3

	task.spawn(function()
		for odsAttempt = 1, 3 do
			local ok = pcall(function()
				local ODS_Semana = DataStoreService:GetOrderedDataStore("RankingSemanal_" .. stat.SemanaID.Value)
				local ODS_Mes = DataStoreService:GetOrderedDataStore("RankingMensal_" .. stat.MesID.Value)
				ODS_Semana:SetAsync(tostring(player.UserId), stat.VitoriasSemanais.Value)
				ODS_Mes:SetAsync(tostring(player.UserId), stat.VitoriasMensais.Value)
			end)
			if ok then
				break
			end
			task.wait(1.5)
		end
	end)

	salvamentoEmAndamento[player.UserId] = nil
end

-- Lobby / scripts externos: força SetAsync antes de TeleportService (evita corrida ler dados antigos)
local flushSaveBF = ReplicatedStorage:FindFirstChild("FlushPlayerSaveBF")
if not flushSaveBF or not flushSaveBF:IsA("BindableFunction") then
	flushSaveBF = Instance.new("BindableFunction")
	flushSaveBF.Name = "FlushPlayerSaveBF"
	flushSaveBF.Parent = ReplicatedStorage
end
flushSaveBF.OnInvoke = function(plr)
	if plr and plr:IsA("Player") and plr.Parent == Players then
		SalvarDados(plr)
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(SalvarDados)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(SalvarDados, p)
	end
	-- Margem maior para SetAsync de vários jogadores (ajuste se necessário)
	task.wait(25)
end)

-- Autosave periódico (reduz perda se o servidor cair sem PlayerRemoving)
task.spawn(function()
	while true do
		task.wait(300)
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(SalvarDados, p)
		end
	end
end)

-- =========================================================
-- MOTOR DO RANKING (CACHE)
-- =========================================================
local cacheDeNomes = {}

local function AtualizarPlacares()
	pcall(function()
		local ODS_Semana = DataStoreService:GetOrderedDataStore("RankingSemanal_" .. GetSemanaAtual())
		local ODS_Mes = DataStoreService:GetOrderedDataStore("RankingMensal_" .. GetMesAtual())

		local function obterTop50(ods)
			local top = {}
			local pages = ods:GetSortedAsync(false, 50)
			local data = pages:GetCurrentPage()
			for _, v in ipairs(data) do
				local userId = tonumber(v.key)
				local nome = "Desconhecido"

				if cacheDeNomes[userId] then
					nome = cacheDeNomes[userId]
				else
					pcall(function()
						nome = Players:GetNameFromUserIdAsync(userId)
						cacheDeNomes[userId] = nome
					end)
				end

				table.insert(top, { Nome = nome, Vitorias = v.value, UserId = userId })
			end
			return top
		end

		cacheSemanal = obterTop50(ODS_Semana)
		cacheMensal = obterTop50(ODS_Mes)

		evAtualizarRanking:FireAllClients(cacheSemanal, cacheMensal)
	end)
end

task.spawn(function()
	AtualizarPlacares()
	while true do
		task.wait(120)
		AtualizarPlacares()
	end
end)
