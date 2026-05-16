-- CH Corporations - Loja de ECU (caixa de espera + beam guia + save)
-- Revisão: preço/level só no servidor (catálogo); whitelist de nomeTool; WaitForChild com timeout;
--          reembolso se não houver template; Workspace; AvisoInventarioEvent criado se faltar;
--          validação no BindableEvent VIP.

print("CH Corporations - Sistema Loja de ECU (Caixa de Espera + Beam Guia) Atualizado c/ Save")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local TIMEOUT = 90

local abrirEvento = ReplicatedStorage:WaitForChild("AbrirLojaECUEvent", TIMEOUT)
local comprarEvento = ReplicatedStorage:WaitForChild("ComprarECUEvent", TIMEOUT)
if not abrirEvento or not comprarEvento then
	warn("[LojaECU] RemoteEvents em falta.")
	return
end

local avisoInv = ReplicatedStorage:FindFirstChild("AvisoInventarioEvent")
if not avisoInv then
	avisoInv = Instance.new("RemoteEvent")
	avisoInv.Name = "AvisoInventarioEvent"
	avisoInv.Parent = ReplicatedStorage
end

local ecuVipEvent = ServerStorage:FindFirstChild("ComprarECUVipEvent")
if not ecuVipEvent then
	ecuVipEvent = Instance.new("BindableEvent")
	ecuVipEvent.Name = "ComprarECUVipEvent"
	ecuVipEvent.Parent = ServerStorage
end

-- Chaves extra na whitelist (além do scan do ServerStorage).
local FERRAMENTAS_ECU_EXTRA = {
	["CaixaECU_Stage4"] = true,
}

local function normalizarChave(nome)
	if type(nome) ~= "string" then
		return nil
	end
	local s = string.lower(nome)
	s = string.gsub(s, "%s+", "_")
	s = string.gsub(s, "_+", "_")
	s = string.gsub(s, "^_+", "")
	s = string.gsub(s, "_+$", "")
	return s ~= "" and s or nil
end

local function toolContaComoEcuCash(tool)
	if not tool:IsA("Tool") then
		return false
	end
	if tool:GetAttribute("TipoDePeca") == "ECU" then
		return true
	end
	return string.sub(tool.Name, 1, 9) == "CaixaECU_"
end

local MAPA_CHAVE_PARA_TOOL = {}

local function registrarMapaChave(toolName, keyOpcional)
	local k1 = normalizarChave(toolName)
	if k1 then
		MAPA_CHAVE_PARA_TOOL[k1] = toolName
	end
	local k2 = normalizarChave(keyOpcional)
	if k2 then
		MAPA_CHAVE_PARA_TOOL[k2] = toolName
	end
end

local function montarWhitelistEcu()
	local w = {}
	for nome, _ in pairs(FERRAMENTAS_ECU_EXTRA) do
		w[nome] = true
		registrarMapaChave(nome, nil)
	end
	for _, d in ipairs(ServerStorage:GetDescendants()) do
		if toolContaComoEcuCash(d) then
			w[d.Name] = true
			registrarMapaChave(d.Name, nil)
		end
	end

	local cfgModule = ReplicatedStorage:FindFirstChild("LojaECUConfig")
	if cfgModule and cfgModule:IsA("ModuleScript") then
		local ok, cfg = pcall(require, cfgModule)
		if ok and type(cfg) == "table" and type(cfg.Itens) == "table" then
			for _, item in ipairs(cfg.Itens) do
				local toolName = tostring(item.toolName or item.key or item.nome or "")
				if toolName ~= "" then
					w[toolName] = true
					registrarMapaChave(toolName, item.key)
				end
			end
		else
			warn("[LojaECU] Falha ao carregar LojaECUConfig para whitelist.")
		end
	end

	return w
end

local FERRAMENTAS_ECU_PERMITIDAS = montarWhitelistEcu()

-- Sobrescreve preço/nível do catálogo automático (opcional).
local CATALOGO_ECU_PRECO_MANUAL = {
	-- ["CaixaECU_Stage4"] = { Preco = 50000, LevelMin = 10 },
}

local function montarCatalogoEcuCash()
	local cat = {}
	for nome, _ in pairs(FERRAMENTAS_ECU_PERMITIDAS) do
		local tool = ServerStorage:FindFirstChild(nome)
		local p = tool and tonumber(tool:GetAttribute("PrecoLoja"))
		local l = tool and tonumber(tool:GetAttribute("LevelMin"))
		cat[nome] = {
			Preco = (type(p) == "number" and p >= 0) and math.floor(p) or 45000,
			LevelMin = (type(l) == "number" and l >= 0) and math.floor(l) or 1,
		}
	end
	for nome, cfg in pairs(CATALOGO_ECU_PRECO_MANUAL) do
		if FERRAMENTAS_ECU_PERMITIDAS[nome] then
			cat[nome] = cfg
		end
	end

	local cfgModule = ReplicatedStorage:FindFirstChild("LojaECUConfig")
	if cfgModule and cfgModule:IsA("ModuleScript") then
		local ok, cfg = pcall(require, cfgModule)
		if ok and type(cfg) == "table" and type(cfg.Itens) == "table" then
			for _, item in ipairs(cfg.Itens) do
				local vip = item.vip == true
				local toolName = tostring(item.toolName or item.key or item.nome or "")
				if not vip and toolName ~= "" and FERRAMENTAS_ECU_PERMITIDAS[toolName] then
					cat[toolName] = {
						Preco = math.max(1, math.floor(tonumber(item.preco) or 0)),
						LevelMin = math.max(1, math.floor(tonumber(item.levelMin) or 1)),
					}
				end
			end
		else
			warn("[LojaECU] Falha ao carregar LojaECUConfig para catálogo.")
		end
	end

	return cat
end

local CATALOGO_ECU_CASH = montarCatalogoEcuCash()
do
	local n = 0
	for _ in pairs(CATALOGO_ECU_CASH) do
		n += 1
	end
	print("[LojaECU] Catálogo cash: " .. tostring(n) .. " item(ns). Tools: prefixo CaixaECU_ ou TipoDePeca=ECU; PrecoLoja/LevelMin opcionais.")
end

local shopStage = Workspace:WaitForChild("ShopStage", TIMEOUT)
if not shopStage then
	warn("[LojaECU] ShopStage não encontrado.")
	return
end

local compraFolder = shopStage:WaitForChild("Compra", 30)
local promptAbrir = compraFolder and compraFolder:WaitForChild("ProximityPrompt", 30)
if not promptAbrir or not promptAbrir:IsA("ProximityPrompt") then
	warn("[LojaECU] ProximityPrompt de abrir loja não encontrado.")
	return
end

local MAX_TOOLS_MAO = 3
local DEBOUNCE_COMPRA = 0.6
local ultimoCompra = {}

Players.PlayerRemoving:Connect(function(p)
	ultimoCompra[p.UserId] = nil
end)

promptAbrir.Triggered:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	abrirEvento:FireClient(player)
end)

local function verificarInventarioCheio(jogador)
	local totalTools = 0
	local backpack = jogador:FindFirstChild("Backpack")
	local character = jogador.Character

	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				totalTools += 1
			end
		end
	end

	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") then
				totalTools += 1
			end
		end
	end

	return totalTools >= MAX_TOOLS_MAO
end

local function criarGuiaVisual(jogador, caixa)
	local character = jogador.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local pecaPrincipal = caixa:IsA("Model") and (caixa.PrimaryPart or caixa:FindFirstChildWhichIsA("BasePart")) or caixa

	if not hrp or not pecaPrincipal or not pecaPrincipal:IsA("BasePart") then
		return
	end

	local attCaixa = Instance.new("Attachment")
	attCaixa.Parent = pecaPrincipal

	local attPlayer = Instance.new("Attachment")
	attPlayer.Parent = hrp

	local beam = Instance.new("Beam")
	beam.Attachment0 = attPlayer
	beam.Attachment1 = attCaixa
	beam.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255))
	beam.FaceCamera = true
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.Transparency = NumberSequence.new(0.5)
	beam.Parent = pecaPrincipal

	caixa.Destroying:Connect(function()
		if attPlayer.Parent then
			attPlayer:Destroy()
		end
	end)
end

local function nomeTemplateCaixa(nomeDaTool)
	return "CaixaFalsa" .. nomeDaTool
end

local function gerarCaixaNaEsteira(player, nomeDaTool, precoPago, isPremium)
	if type(nomeDaTool) ~= "string" or not FERRAMENTAS_ECU_PERMITIDAS[nomeDaTool] then
		return false
	end

	local templateName = nomeTemplateCaixa(nomeDaTool)
	local caixaFalsa = ServerStorage:FindFirstChild(templateName)
	if not caixaFalsa then
		warn("[LojaECU] Template em falta: " .. templateName)
		return false
	end

	local novaCaixaFalsa = caixaFalsa:Clone()
	local pecaPrincipal = novaCaixaFalsa.PrimaryPart
		or novaCaixaFalsa:FindFirstChild("Caixa")
		or novaCaixaFalsa:FindFirstChildWhichIsA("BasePart")

	for _, obj in ipairs(novaCaixaFalsa:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = false
			if pecaPrincipal and obj ~= pecaPrincipal and pecaPrincipal:IsA("BasePart") then
				local solda = Instance.new("WeldConstraint")
				solda.Part0 = pecaPrincipal
				solda.Part1 = obj
				solda.Parent = pecaPrincipal
			end
		end
	end

	local spawnsDisponiveis = {}
	for _, item in ipairs(shopStage:GetChildren()) do
		if item:IsA("BasePart") and string.match(item.Name, "^LocalSpawn") then
			table.insert(spawnsDisponiveis, item)
		end
	end

	local cframeEscolhido
	if #spawnsDisponiveis > 0 then
		local indexSorteado = math.random(1, #spawnsDisponiveis)
		cframeEscolhido = spawnsDisponiveis[indexSorteado].CFrame * CFrame.new(0, 1.5, 0)
	else
		cframeEscolhido = shopStage:GetPivot() * CFrame.new(0, 1.5, 0)
	end

	if novaCaixaFalsa:IsA("Model") then
		novaCaixaFalsa:PivotTo(cframeEscolhido)
	elseif novaCaixaFalsa:IsA("BasePart") then
		novaCaixaFalsa.CFrame = cframeEscolhido
	end

	novaCaixaFalsa.Parent = Workspace

	criarGuiaVisual(player, novaCaixaFalsa)

	local promptPegar = novaCaixaFalsa:FindFirstChildWhichIsA("ProximityPrompt", true)
	if promptPegar then
		promptPegar.Triggered:Connect(function(jogadorQueClicou)
			if typeof(jogadorQueClicou) ~= "Instance" or not jogadorQueClicou:IsA("Player") then
				return
			end
			if jogadorQueClicou.UserId ~= player.UserId then
				return
			end

			if verificarInventarioCheio(jogadorQueClicou) then
				avisoInv:FireClient(jogadorQueClicou)
				return
			end

			local ferramentaReal = ServerStorage:FindFirstChild(nomeDaTool)
			if not ferramentaReal or not ferramentaReal:IsA("Tool") then
				warn("[LojaECU] Tool real em falta: " .. nomeDaTool)
				return
			end

			local cloneReal = ferramentaReal:Clone()
			if precoPago and precoPago > 0 then
				cloneReal:SetAttribute("PrecoPago", precoPago)
			end
			if isPremium then
				cloneReal:SetAttribute("Premium", true)
			end

			local bp = jogadorQueClicou:FindFirstChild("Backpack") or jogadorQueClicou:WaitForChild("Backpack", 5)
			if not bp then
				return
			end
			cloneReal.Parent = bp

			local inventarioFerramentas = jogadorQueClicou:FindFirstChild("InventarioFerramentas")
			if inventarioFerramentas and not inventarioFerramentas:FindFirstChild(nomeDaTool) then
				local novoRecord = Instance.new("StringValue")
				novoRecord.Name = nomeDaTool
				novoRecord.Value = "Comprada"
				novoRecord.Parent = inventarioFerramentas
				print("💾 Recibo de save criado para ECU: " .. nomeDaTool)
			end

			local char = jogadorQueClicou.Character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				pcall(function()
					humanoid:EquipTool(cloneReal)
				end)
			end

			pcall(function()
				novaCaixaFalsa:Destroy()
			end)
		end)
	end

	return true
end

comprarEvento.OnServerEvent:Connect(function(player, nomeTool, precoCliente, levelCliente, keyOpcional)
	local uid = player.UserId
	local agora = os.clock()
	if ultimoCompra[uid] and (agora - ultimoCompra[uid]) < DEBOUNCE_COMPRA then
		return
	end

	if type(nomeTool) ~= "string" or nomeTool == "" then
		return
	end

	local nomeResolvido = nomeTool
	if not FERRAMENTAS_ECU_PERMITIDAS[nomeResolvido] then
		nomeResolvido = MAPA_CHAVE_PARA_TOOL[normalizarChave(nomeTool)] or nomeResolvido
	end
	if not FERRAMENTAS_ECU_PERMITIDAS[nomeResolvido] and type(keyOpcional) == "string" then
		nomeResolvido = MAPA_CHAVE_PARA_TOOL[normalizarChave(keyOpcional)] or nomeResolvido
	end
	if not FERRAMENTAS_ECU_PERMITIDAS[nomeResolvido] then
		return
	end

	local cfg = CATALOGO_ECU_CASH[nomeResolvido]
	if not cfg then
		return
	end

	-- Se true, a UI tem de enviar exatamente o Preco/LevelMin do catálogo (senão a compra falha).
	-- Deixe false para o servidor ser a fonte de verdade e a UI só mostrar o preço.
	local EXIGIR_UI_IGUAL_CATALOGO = false
	if EXIGIR_UI_IGUAL_CATALOGO then
		if precoCliente ~= nil and precoCliente ~= cfg.Preco then
			return
		end
		if levelCliente ~= nil and levelCliente ~= cfg.LevelMin then
			return
		end
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local dinheiro = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	local level = leaderstats and leaderstats:FindFirstChild("Level")
	local temDinheiro = dinheiro and (dinheiro:IsA("IntValue") or dinheiro:IsA("NumberValue"))
	local temLevel = level and (level:IsA("IntValue") or level:IsA("NumberValue"))
	if not temDinheiro or not temLevel then
		warn("[LojaECU] leaderstats.Dinheiro/Level em falta ou tipo inválido (use IntValue ou NumberValue): " .. player.Name)
		return
	end

	if level.Value < cfg.LevelMin then
		warn("❌ " .. player.Name .. " sem level para " .. nomeResolvido .. " (mín. " .. cfg.LevelMin .. ").")
		return
	end

	if dinheiro.Value < cfg.Preco then
		warn("❌ " .. player.Name .. " sem dinheiro para " .. nomeResolvido .. ".")
		return
	end

	dinheiro.Value = dinheiro.Value - cfg.Preco
	ultimoCompra[uid] = agora

	if not gerarCaixaNaEsteira(player, nomeResolvido, cfg.Preco, false) then
		dinheiro.Value = dinheiro.Value + cfg.Preco
		warn("[LojaECU] Compra revertida (sem template) para " .. player.Name)
	end
end)

ecuVipEvent.Event:Connect(function(player, nomeTool)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if type(nomeTool) ~= "string" or not FERRAMENTAS_ECU_PERMITIDAS[nomeTool] then
		return
	end
	gerarCaixaNaEsteira(player, nomeTool, 0, true)
end)
