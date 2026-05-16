-- CH Corporations - Juiz Olímpico & Global (V10 - Carregamento imediato + inventário V2)
-- Revisão: primeiro tick sem esperar 15s; WaitForChild com timeout; retries no SetAsync global;
--          cor e rodas lidas de InventarioVeiculos (atributos) com fallback em CarData (legado);
--          limpeza de cache ao sair; parse seguro da chave ODS.

print("CH Corporations - Juiz Olímpico & Global (V10 - Carregamento imediato + inventário V2)")

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local DataStoreService = game:GetService("DataStoreService")

local registroDeCarros = ServerStorage:WaitForChild("RegistroDeCarros", 120)
if not registroDeCarros then
	warn("[JuizOlimpico] RegistroDeCarros não encontrado no ServerStorage.")
end

local rodasSalvas = ReplicatedStorage:WaitForChild("RodasSalvas", 120)
if not rodasSalvas then
	warn("[JuizOlimpico] RodasSalvas não encontrado no ReplicatedStorage.")
end

local ODS_CarrosGlobais = DataStoreService:GetOrderedDataStore("GearUp_GlobalCarLikes_V1")
local cacheUltimosSalvos = {}

-- Chave global: "NomeDono|NomeCarro" (igual à versão antiga para não invalidar o ODS existente)
local function chaveGlobal(player, nomeCarro)
	return player.Name .. "|" .. nomeCarro
end

local function limparCacheDoJogador(player)
	local prefixo = player.Name .. "|"
	for k in pairs(cacheUltimosSalvos) do
		if string.sub(k, 1, #prefixo) == prefixo then
			cacheUltimosSalvos[k] = nil
		end
	end
end

Players.PlayerRemoving:Connect(limparCacheDoJogador)

-- Cor e rodas: V2 no inventário (atributos); fallback CarData (filhos legado)
local function aplicarVisualDoCarroNoClone(player, nomeCarro, novoCarro)
	local carData = player:FindFirstChild("CarData")
	local inventario = player:FindFirstChild("InventarioVeiculos")
	local recVeiculo = inventario and inventario:FindFirstChild(nomeCarro)

	local corStr = nil
	if recVeiculo then
		corStr = recVeiculo:GetAttribute("CorDoCarro")
	end
	if (not corStr or corStr == "") and carData then
		local corSalva = carData:FindFirstChild("CorDoCarro")
		if corSalva and corSalva:IsA("StringValue") then
			corStr = corSalva.Value
		end
	end

	if corStr and corStr ~= "" then
		local rgb = string.split(corStr, ",")
		if #rgb == 3 then
			local corRecuperada = Color3.fromRGB(
				tonumber(rgb[1]) or 0,
				tonumber(rgb[2]) or 0,
				tonumber(rgb[3]) or 0
			)
			for _, obj in ipairs(novoCarro:GetDescendants()) do
				if obj:IsA("BasePart") and obj.Name == "Paint" then
					obj.Color = corRecuperada
				end
			end
		end
	end

	local wheelsModel = novoCarro:FindFirstChild("Wheels")
	if not wheelsModel then
		return
	end

	local function nomeRodaParaPos(pos)
		if recVeiculo then
			local a = recVeiculo:GetAttribute(pos)
			if type(a) == "string" and a ~= "" and a ~= "Padrao" then
				return a
			end
		end
		if carData then
			local rv = carData:FindFirstChild(pos)
			if rv and rv:IsA("StringValue") and rv.Value ~= "" and rv.Value ~= "Padrao" then
				return rv.Value
			end
		end
		return nil
	end

	for _, pos in ipairs({ "FL", "FR", "RL", "RR" }) do
		local nomeRoda = nomeRodaParaPos(pos)
		if nomeRoda and rodasSalvas then
			local rodaOriginal = rodasSalvas:FindFirstChild(nomeRoda)
			local rodaPart = wheelsModel:FindFirstChild(pos)
			if rodaOriginal and rodaPart then
				local partsModel = rodaPart:FindFirstChild("Parts")
				if partsModel then
					for _, f in ipairs(partsModel:GetChildren()) do
						f:Destroy()
					end
					local nova = rodaOriginal:Clone()
					nova.Parent = partsModel
					nova:PivotTo(rodaPart.CFrame)
				end
			end
		end
	end
end

local function salvarLikesGlobalComRetry(chaveUnica, likesAtuais)
	for tentativa = 1, 4 do
		local sucesso, erro = pcall(function()
			ODS_CarrosGlobais:SetAsync(chaveUnica, likesAtuais)
		end)
		if sucesso then
			return true
		end
		warn(string.format(
			"[JuizOlimpico] SetAsync ranking global falhou (%d/4) chave=%s: %s",
			tentativa,
			chaveUnica,
			tostring(erro)
		))
		task.wait(math.min(tentativa * 2, 6))
	end
	return false
end

-- =========================================================
-- 1. ATUALIZAÇÃO DO SERVIDOR LOCAL (a cada 15s)
-- =========================================================
local function AtualizarRankingOlimpico()
	if not registroDeCarros or not registroDeCarros.Parent then
		return
	end

	local rankingGeral = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local likesDataFolder = player:FindFirstChild("LikesData")
		if likesDataFolder then
			for _, carroLikeInfo in ipairs(likesDataFolder:GetChildren()) do
				if carroLikeInfo:IsA("IntValue") and carroLikeInfo.Value > 0 then
					local chaveUnica = chaveGlobal(player, carroLikeInfo.Name)
					local likesAtuais = carroLikeInfo.Value

					if likesAtuais > (cacheUltimosSalvos[chaveUnica] or 0) then
						cacheUltimosSalvos[chaveUnica] = likesAtuais
						task.spawn(function()
							salvarLikesGlobalComRetry(chaveUnica, likesAtuais)
						end)
					end

					table.insert(rankingGeral, {
						DonoObj = player,
						NomeDono = player.Name,
						NomeCarro = carroLikeInfo.Name,
						Likes = likesAtuais,
					})
				end
			end
		end
	end

	table.sort(rankingGeral, function(a, b)
		return a.Likes > b.Likes
	end)

	local tabelaVencedores = {}
	for i = 1, 3 do
		local info = rankingGeral[i]
		if info then
			local nomeFormatado = string.gsub(info.NomeCarro, " ", "_")
			local idDoCarro = registroDeCarros:GetAttribute(nomeFormatado)

			if idDoCarro then
				local sucesso, modeloBaixado = pcall(function()
					return InsertService:LoadAsset(idDoCarro)
				end)
				if sucesso and modeloBaixado then
					local filhos = modeloBaixado:GetChildren()
					local novoCarro = filhos[1]
					if novoCarro then
						novoCarro.Parent = nil

						aplicarVisualDoCarroNoClone(info.DonoObj, info.NomeCarro, novoCarro)

						table.insert(tabelaVencedores, {
							Dono = info.NomeDono,
							Carro = info.NomeCarro,
							Likes = info.Likes,
							Clone = novoCarro,
						})
					end
					modeloBaixado:Destroy()
				end
			end
		end
	end

	if _G.AtualizarPodioTop3 then
		_G.AtualizarPodioTop3(tabelaVencedores)
	end
end

-- =========================================================
-- 2. BUSCADOR DO RANKING MUNDIAL
-- =========================================================
local function PuxarRankingGlobal()
	local sucesso, erro = pcall(function()
		local pages = ODS_CarrosGlobais:GetSortedAsync(false, 10)
		local data = pages:GetCurrentPage()

		local tabelaTop10 = {}
		for _, v in ipairs(data) do
			local chave = v.key
			local sep = string.find(chave, "|", 1, true)
			local dono, carroNome
			if sep then
				dono = string.sub(chave, 1, sep - 1)
				carroNome = string.sub(chave, sep + 1)
			else
				dono = chave
				carroNome = "Carro"
			end
			table.insert(tabelaTop10, {
				Dono = dono,
				Carro = carroNome,
				Likes = v.value,
			})
		end

		if _G.AtualizarRankingGlobalUI then
			_G.AtualizarRankingGlobalUI(tabelaTop10)
		end
	end)

	if not sucesso then
		warn("[JuizOlimpico] Erro ao ler Ranking Global (API Services / limites): " .. tostring(erro))
	end
end

-- =========================================================
-- LOOPS DE EXECUÇÃO
-- =========================================================
task.spawn(function()
	while true do
		AtualizarRankingOlimpico()
		task.wait(15)
	end
end)

task.spawn(function()
	PuxarRankingGlobal()
	while true do
		task.wait(90)
		PuxarRankingGlobal()
	end
end)
