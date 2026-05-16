-- CH Corporations - Banco Central de Robux (Atualizado c/ Sistema de Doações e Pódio)
-- Revisão: retries em doações (só concede se gravar), sem yield longo no ProcessReceipt,
--          referências com timeout / lazy, ECU sem bloquear o receipt.

print("CH Corporations - Banco Central de Robux (Atualizado c/ Sistema de Doações e Pódio)")

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local function GetSemanaAtual()
	return tostring(math.floor(os.time() / 604800))
end

local function GetMesAtual()
	return os.date("%m_%Y")
end

-- =========================================================
-- RemoteEvents
-- =========================================================
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

-- =========================================================
-- Referências (timeout no arranque — não bloquear o servidor para sempre)
-- =========================================================
local caixaPremiumModelo = ServerStorage:WaitForChild("CaixaFalsaPremium", 60)
if not caixaPremiumModelo then
	warn("[BancoCentralRobux] CaixaFalsaPremium não encontrada no ServerStorage em 60s.")
end

local guiaEvent = ReplicatedStorage:WaitForChild("GuiaVisualEvent", 60)
if not guiaEvent then
	warn("[BancoCentralRobux] GuiaVisualEvent não encontrado no ReplicatedStorage em 60s.")
end

-- Bindable/Event para ECU: resolve uma vez (evita WaitForChild longo dentro do ProcessReceipt)
local comprarECUEvent = ServerStorage:WaitForChild("ComprarECUVipEvent", 120)
if not comprarECUEvent then
	warn("[BancoCentralRobux] ComprarECUVipEvent não encontrado; compra de ECU pode falhar até existir.")
end

local function obterShopR()
	local shop = Workspace:FindFirstChild("ShopR")
	if shop then
		return shop
	end
	return Workspace:WaitForChild("ShopR", 8)
end

-- Mesma lógica que LojaRodas: posiciona na esteira sobre um LocalSpawn aleatório (ShopR).
local function cframeSpawnCaixaNaShopR(shopR)
	local spawns = {}
	for _, item in ipairs(shopR:GetDescendants()) do
		if item:IsA("BasePart") and string.match(item.Name, "^LocalSpawn") then
			table.insert(spawns, item)
		end
	end
	if #spawns > 0 then
		local escolhido = spawns[math.random(1, #spawns)]
		return escolhido.CFrame * CFrame.new(0, 1.5, 0)
	end
	warn("[BancoCentralRobux] Nenhum LocalSpawn* em ShopR; a caixa VIP usa o pivot da loja.")
	return shopR:GetPivot() * CFrame.new(0, 1.5, 0)
end

-- =========================================================
-- DICIONÁRIOS DE PRODUTOS
-- =========================================================
-- Ajuste/remova o placeholder 987654321 quando tiver o ProductId real
local catalogoVip = {
	[3550796245] = "Roda_Nivus",
	[987654321] = "Volk_Neon",
}

local pacotesDinheiro = {
	[3553695517] = 5000,
	[3553695674] = 10000,
	[3553695854] = 22500,
	[3553696003] = 30000,
	[3553696219] = 60000,
	[3553696367] = 125000,
	[3553696581] = 750000,
	[3553696802] = 1500000,
}

local pacotesXP = {
	[3553701915] = 1000,
	[3553702171] = 2000,
	[3553702311] = 5500,
	[3553702429] = 12000,
	[3553702574] = 16000,
	[3553702664] = 32000,
	[3553702816] = 65000,
	[3553702966] = 150000,
}

local pacotesVipTemporario = {
	[3560842687] = { Nivel = "Bronze", Dias = 1 },
	[3560842783] = { Nivel = "Bronze", Dias = 7 },
	[3560842888] = { Nivel = "Bronze", Dias = 15 },
	[3560843476] = { Nivel = "Bronze", Dias = 30 },
	[3560844035] = { Nivel = "Gold", Dias = 1 },
	[3560844156] = { Nivel = "Gold", Dias = 7 },
	[3560844290] = { Nivel = "Gold", Dias = 15 },
	[3560844409] = { Nivel = "Gold", Dias = 30 },
	[3560844895] = { Nivel = "Diamante", Dias = 1 },
	[3560844987] = { Nivel = "Diamante", Dias = 7 },
	[3560845056] = { Nivel = "Diamante", Dias = 15 },
	[3560845165] = { Nivel = "Diamante", Dias = 30 },
}

local pacotesDoacao = {
	[3562739639] = 5,
	[3562739803] = 10,
	[3562739923] = 15,
	[3562740059] = 20,
	[3562740201] = 25,
	[3562740299] = 50,
	[3562740391] = 75,
	[3562740504] = 100,
	[3562740623] = 150,
}

-- Doação: grava nos ODS; só retorna true quando ambos estão OK.
-- Só chama IncrementAsync de novo no store que ainda falhou (evita dobrar a semana se só o mês falhou).
local function registrarDoacaoNoPodio(userId, valorDoacao)
	local semanaKey = GetSemanaAtual()
	local mesKey = GetMesAtual()
	local uid = tostring(userId)
	local ODS_Semana = DataStoreService:GetOrderedDataStore("DonationsSemanal_" .. semanaKey)
	local ODS_Mes = DataStoreService:GetOrderedDataStore("DonationsMensal_" .. mesKey)

	local okSem, okMes = false, false

	for attempt = 1, 6 do
		if not okSem then
			okSem = pcall(function()
				ODS_Semana:IncrementAsync(uid, valorDoacao)
			end)
		end
		if not okMes then
			okMes = pcall(function()
				ODS_Mes:IncrementAsync(uid, valorDoacao)
			end)
		end

		if okSem and okMes then
			return true
		end

		warn(string.format(
			"[BancoCentralRobux] IncrementAsync doação falhou (tentativa %d/6) user=%s okSem=%s okMes=%s",
			attempt,
			uid,
			tostring(okSem),
			tostring(okMes)
		))
		task.wait(math.min(attempt * 2, 8))
	end

	return false
end

-- =========================================================
-- GERENCIADOR DE COMPRAS DE PRODUTOS
-- =========================================================
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	-- 0) Doação — só concede se o pódio gravar (senão Roblox reenvia o recibo)
	local valorDoacao = pacotesDoacao[productId]
	if valorDoacao then
		if not registrarDoacaoNoPodio(player.UserId, valorDoacao) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		eventoCelebracao:FireClient(player, "💖 Você doou R$ " .. valorDoacao .. "!", false)
		eventoAnuncio:FireAllClients(player.Name, "💖 Fez uma doação de R$ " .. valorDoacao .. " Robux!", false)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 1) Dinheiro
	local recompensaCash = pacotesDinheiro[productId]
	if recompensaCash then
		local leaderstats = player:FindFirstChild("leaderstats")
		local din = leaderstats and leaderstats:FindFirstChild("Dinheiro")
		if din then
			din.Value = din.Value + recompensaCash
			eventoCelebracao:FireClient(player, "💰 $" .. recompensaCash, false)
			eventoAnuncio:FireAllClients(player.Name, "💰 $" .. recompensaCash, false)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 2) XP
	local recompensaXP = pacotesXP[productId]
	if recompensaXP then
		local leaderstats = player:FindFirstChild("leaderstats")
		local xp = leaderstats and leaderstats:FindFirstChild("XP")
		if xp then
			xp.Value = xp.Value + recompensaXP
			eventoCelebracao:FireClient(player, "🌟 " .. recompensaXP .. " XP", false)
			eventoAnuncio:FireAllClients(player.Name, "🌟 " .. recompensaXP .. " XP", false)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 3) VIP temporário
	local vipComprado = pacotesVipTemporario[productId]
	if vipComprado then
		local vipSalvo = player:FindFirstChild("VipSalvo")
		local nivelVIP = vipComprado.Nivel
		local expGaveta = player:FindFirstChild("Exp" .. nivelVIP)

		if vipSalvo and expGaveta then
			local diasVIP = vipComprado.Dias
			local segundosExtras = diasVIP * 86400

			if expGaveta.Value > os.time() then
				expGaveta.Value = expGaveta.Value + segundosExtras
			else
				expGaveta.Value = os.time() + segundosExtras
			end

			local vipAtual = vipSalvo.Value
			if not string.find(vipAtual, nivelVIP, 1, true) then
				if vipAtual == "Comum" or vipAtual == "" then
					vipSalvo.Value = nivelVIP
				else
					vipSalvo.Value = vipAtual .. "," .. nivelVIP
				end
			end

			eventoCelebracao:FireClient(player, "👑 VIP " .. nivelVIP .. " (" .. diasVIP .. " Dias)", false)
			eventoAnuncio:FireAllClients(player.Name, "👑 VIP " .. nivelVIP .. " (" .. diasVIP .. " Dias)", false)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 4) Motor ECU
	if productId == 3552427862 then
		if comprarECUEvent then
			comprarECUEvent:Fire(player, "CaixaECU_Stage4")
		else
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		eventoCelebracao:FireClient(player, "🏎️ Motor Stage 4", false)
		eventoAnuncio:FireAllClients(player.Name, "🏎️ Motor Stage 4", false)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 5) Rodas VIP (catálogo)
	local nomeDaRoda = catalogoVip[productId]
	if nomeDaRoda then
		if not caixaPremiumModelo or not caixaPremiumModelo.Parent then
			caixaPremiumModelo = ServerStorage:FindFirstChild("CaixaFalsaPremium")
		end
		if not caixaPremiumModelo then
			warn("[BancoCentralRobux] CaixaFalsaPremium ausente; devolvendo NotProcessedYet para productId=" .. tostring(productId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local shopR = obterShopR()
		if not shopR then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local pivot = cframeSpawnCaixaNaShopR(shopR)
		local novaCaixa = caixaPremiumModelo:Clone()
		local nomeFormatado = string.gsub(nomeDaRoda, "_", " ")

		local rodaValue = Instance.new("StringValue")
		rodaValue.Name = "TipoDeRoda"
		rodaValue.Value = nomeFormatado
		rodaValue.Parent = novaCaixa

		novaCaixa:SetAttribute("Dono", player.Name)
		novaCaixa:SetAttribute("Premium", true)

		if novaCaixa:IsA("Model") then
			novaCaixa:PivotTo(pivot)
		elseif novaCaixa:IsA("BasePart") then
			novaCaixa.CFrame = pivot
		end
		novaCaixa.Parent = Workspace

		-- Não usar task.wait no ProcessReceipt; guia dispara depois no próximo frame
		if guiaEvent then
			task.defer(function()
				local alvoDoBeam = novaCaixa:IsA("BasePart") and novaCaixa
					or novaCaixa.PrimaryPart
					or novaCaixa:FindFirstChildWhichIsA("BasePart", true)
				if alvoDoBeam and alvoDoBeam.Parent and player.Parent then
					guiaEvent:FireClient(player, alvoDoBeam)
				end
			end)
		end

		eventoCelebracao:FireClient(player, "🛞 Roda " .. nomeFormatado, false)
		eventoAnuncio:FireAllClients(player.Name, "🛞 Roda Especial", false)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- =========================================================
-- GAMEPASSES (VIP permanente)
-- =========================================================
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then
		return
	end

	local nivelVIP = nil
	if gamePassId == 1737108751 then
		nivelVIP = "Bronze"
	elseif gamePassId == 1746268685 then
		nivelVIP = "Gold"
	elseif gamePassId == 1746862603 then
		nivelVIP = "Diamante"
	end

	if not nivelVIP then
		return
	end

	local vipSalvo = player:FindFirstChild("VipSalvo")
	local expGaveta = player:FindFirstChild("Exp" .. nivelVIP)

	if not vipSalvo or not expGaveta then
		-- Dados ainda não criados pelo GerenciadorDeDadosMaster — re-tenta por alguns segundos
		task.spawn(function()
			for _ = 1, 24 do
				task.wait(0.5)
				if not player.Parent then
					return
				end
				vipSalvo = player:FindFirstChild("VipSalvo")
				expGaveta = player:FindFirstChild("Exp" .. nivelVIP)
				if vipSalvo and expGaveta then
					expGaveta.Value = 0
					local vipAtual = vipSalvo.Value
					if not string.find(vipAtual, nivelVIP, 1, true) then
						if vipAtual == "Comum" or vipAtual == "" then
							vipSalvo.Value = nivelVIP
						else
							vipSalvo.Value = vipAtual .. "," .. nivelVIP
						end
					end
					eventoCelebracao:FireClient(player, "👑 VIP " .. nivelVIP .. " (Permanente)", false)
					eventoAnuncio:FireAllClients(player.Name, "👑 VIP " .. nivelVIP .. " (Permanente)", false)
					return
				end
			end
			warn("[BancoCentralRobux] GamePass permanente: VipSalvo/Exp não encontrados após ~12s para " .. player.Name)
		end)
		return
	end

	expGaveta.Value = 0
	local vipAtual = vipSalvo.Value
	if not string.find(vipAtual, nivelVIP, 1, true) then
		if vipAtual == "Comum" or vipAtual == "" then
			vipSalvo.Value = nivelVIP
		else
			vipSalvo.Value = vipAtual .. "," .. nivelVIP
		end
	end

	eventoCelebracao:FireClient(player, "👑 VIP " .. nivelVIP .. " (Permanente)", false)
	eventoAnuncio:FireAllClients(player.Name, "👑 VIP " .. nivelVIP .. " (Permanente)", false)
end)
