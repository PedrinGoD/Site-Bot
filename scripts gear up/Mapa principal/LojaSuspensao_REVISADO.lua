-- CH Corporations - Loja de suspensão (caixa de espera + beam + save na recolha)
-- Revisão: preço/level só no catálogo; nomes de Tool validados; spawn em pcall + reembolso se falhar;
--          save só ao recolher (igual ao teu fluxo); AvisoInventario criado se faltar; debounce.

print("CH Corporations - Sistema da Loja de Suspensão (Caixa de Espera + Beam Guia) Atualizado c/ Save")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local TIMEOUT = 90
local MAX_TOOLS = 3
local DEBOUNCE_SEG = 0.6

local comprarEvento = ReplicatedStorage:WaitForChild("ComprarSuspensaoEvent", TIMEOUT)
if not comprarEvento then
	warn("[LojaSusp] ComprarSuspensaoEvent não encontrado.")
	return
end

local caixaFalsaModelo = ServerStorage:WaitForChild("CaixaFalsaSuspensao", TIMEOUT)
if not caixaFalsaModelo then
	warn("[LojaSusp] CaixaFalsaSuspensao não encontrada.")
	return
end

local shopSusp = Workspace:WaitForChild("ShopSusp", TIMEOUT)
if not shopSusp then
	warn("[LojaSusp] ShopSusp não encontrada.")
	return
end

local avisoInv = ReplicatedStorage:FindFirstChild("AvisoInventarioEvent")
if not avisoInv then
	avisoInv = Instance.new("RemoteEvent")
	avisoInv.Name = "AvisoInventarioEvent"
	avisoInv.Parent = ReplicatedStorage
end

-- Entradas manuais (opcional): sobrescrevem preço/level da Tool e entram mesmo sem scan.
-- Chave = nome exato da Tool no ServerStorage.
local CATALOGO_SUSPENSAO_MANUAL = {}

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

local function toolEhSuspensao(tool)
	if not tool:IsA("Tool") then
		return false
	end
	if tool:GetAttribute("TipoDePeca") == "Suspensao" then
		return true
	end
	local n = string.lower(tool.Name)
	return string.find(n, "suspensao", 1, true) ~= nil
end

-- Monta o catálogo a partir das Tools no ServerStorage + overrides manuais.
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

local function montarCatalogoSuspensao()
	local cat = {}
	for _, child in ipairs(ServerStorage:GetDescendants()) do
		if toolEhSuspensao(child) then
			local nome = child.Name
			local p = tonumber(child:GetAttribute("PrecoLoja"))
			local l = tonumber(child:GetAttribute("LevelMin"))
			cat[nome] = {
				Preco = (type(p) == "number" and p >= 0) and math.floor(p) or 35000,
				LevelMin = (type(l) == "number" and l >= 0) and math.floor(l) or 1,
			}
			registrarMapaChave(nome, nil)
		end
	end

	local cfgModule = ReplicatedStorage:FindFirstChild("LojaSuspensaoConfig")
	if cfgModule and cfgModule:IsA("ModuleScript") then
		local ok, cfg = pcall(require, cfgModule)
		if ok and type(cfg) == "table" and type(cfg.Itens) == "table" then
			for _, item in ipairs(cfg.Itens) do
				local vip = item.vip == true
				local toolName = tostring(item.toolName or item.key or item.nome or "")
				if toolName ~= "" then
					registrarMapaChave(toolName, item.key)
					if not vip then
						cat[toolName] = {
							Preco = math.max(1, math.floor(tonumber(item.preco) or 0)),
							LevelMin = math.max(1, math.floor(tonumber(item.levelMin) or 1)),
						}
					end
				end
			end
		else
			warn("[LojaSusp] Falha ao ler LojaSuspensaoConfig.")
		end
	end

	for nome, cfg in pairs(CATALOGO_SUSPENSAO_MANUAL) do
		cat[nome] = cfg
		registrarMapaChave(nome, nil)
	end
	return cat
end

local CATALOGO_SUSPENSAO = montarCatalogoSuspensao()
local FERRAMENTAS_SUSP = {}
for nome, _ in pairs(CATALOGO_SUSPENSAO) do
	FERRAMENTAS_SUSP[nome] = true
end

local nItens = 0
for _ in pairs(CATALOGO_SUSPENSAO) do
	nItens += 1
end
print("[LojaSusp] Catálogo de suspensão: " .. tostring(nItens) .. " item(ns). (Tools: TipoDePeca=Suspensao ou nome contém 'suspensao'; PrecoLoja/LevelMin opcionais; pastas no ServerStorage ok.)")
if nItens == 0 then
	warn("[LojaSusp] Catálogo vazio — nenhuma Tool de suspensão encontrada no ServerStorage. Marque as Tools com atributo TipoDePeca=Suspensao ou use CATALOGO_SUSPENSAO_MANUAL.")
end

local ultimo = {}

Players.PlayerRemoving:Connect(function(p)
	ultimo[p.UserId] = nil
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

	return totalTools >= MAX_TOOLS
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
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 200, 0))
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

local function gerarCaixaNaLoja(player, nomeDaSuspensao, precoServidor)
	local novaCaixaFalsa
	local ok, err = pcall(function()
		novaCaixaFalsa = caixaFalsaModelo:Clone()

		local spawnsDisponiveis = {}
		for _, item in ipairs(shopSusp:GetChildren()) do
			if item:IsA("BasePart") and string.match(item.Name, "^LocalSpawn") then
				table.insert(spawnsDisponiveis, item)
			end
		end

		local cframeEscolhido
		if #spawnsDisponiveis > 0 then
			local indexSorteado = math.random(1, #spawnsDisponiveis)
			cframeEscolhido = spawnsDisponiveis[indexSorteado].CFrame * CFrame.new(0, 1.5, 0)
		else
			cframeEscolhido = shopSusp:GetPivot() * CFrame.new(0, 1.5, 0)
		end

		if novaCaixaFalsa:IsA("Model") then
			novaCaixaFalsa:PivotTo(cframeEscolhido)
		elseif novaCaixaFalsa:IsA("BasePart") then
			novaCaixaFalsa.CFrame = cframeEscolhido
		end

		novaCaixaFalsa.Parent = Workspace
	end)

	if not ok then
		if novaCaixaFalsa then
			pcall(function()
				novaCaixaFalsa:Destroy()
			end)
		end
		return false, err
	end

	criarGuiaVisual(player, novaCaixaFalsa)

	local compradorUserId = player.UserId
	local prompt = novaCaixaFalsa:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(jogadorQueClicou)
			if typeof(jogadorQueClicou) ~= "Instance" or not jogadorQueClicou:IsA("Player") then
				return
			end
			if jogadorQueClicou.UserId ~= compradorUserId then
				return
			end

			if verificarInventarioCheio(jogadorQueClicou) then
				avisoInv:FireClient(jogadorQueClicou)
				return
			end

			local ferramentaReal = ServerStorage:FindFirstChild(nomeDaSuspensao)
			if not ferramentaReal or not ferramentaReal:IsA("Tool") then
				warn("[LojaSusp] Tool em falta: " .. tostring(nomeDaSuspensao))
				return
			end

			local cloneReal = ferramentaReal:Clone()
			if precoServidor and precoServidor > 0 then
				cloneReal:SetAttribute("PrecoPago", precoServidor)
			end

			local bp = jogadorQueClicou:FindFirstChild("Backpack") or jogadorQueClicou:WaitForChild("Backpack", 5)
			if not bp then
				return
			end
			cloneReal.Parent = bp

			local inventarioFerramentas = jogadorQueClicou:FindFirstChild("InventarioFerramentas")
			if inventarioFerramentas and not inventarioFerramentas:FindFirstChild(nomeDaSuspensao) then
				local novoRecord = Instance.new("StringValue")
				novoRecord.Name = nomeDaSuspensao
				novoRecord.Value = "Comprada"
				novoRecord.Parent = inventarioFerramentas
				print("💾 Recibo criado para: " .. nomeDaSuspensao)
			end

			local character = jogadorQueClicou.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
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

comprarEvento.OnServerEvent:Connect(function(player, nomeDaSuspensao, precoCliente, levelCliente, keyOpcional)
	local uid = player.UserId
	local t = os.clock()
	if ultimo[uid] and (t - ultimo[uid]) < DEBOUNCE_SEG then
		return
	end

	if type(nomeDaSuspensao) ~= "string" or nomeDaSuspensao == "" then
		return
	end

	local nomeResolvido = nomeDaSuspensao
	if not FERRAMENTAS_SUSP[nomeResolvido] then
		nomeResolvido = MAPA_CHAVE_PARA_TOOL[normalizarChave(nomeDaSuspensao)] or nomeResolvido
	end
	if not FERRAMENTAS_SUSP[nomeResolvido] and type(keyOpcional) == "string" then
		nomeResolvido = MAPA_CHAVE_PARA_TOOL[normalizarChave(keyOpcional)] or nomeResolvido
	end
	if not FERRAMENTAS_SUSP[nomeResolvido] then
		return
	end

	local cfg = CATALOGO_SUSPENSAO[nomeResolvido]
	if not cfg then
		return
	end

	-- Se true, o preço/nível enviados pela UI têm de bater com o catálogo (senão falha silenciosa).
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
		warn("[LojaSusp] leaderstats.Dinheiro/Level em falta ou tipo inválido (IntValue/NumberValue): " .. player.Name)
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
	ultimo[uid] = t

	local spawnOk, err = gerarCaixaNaLoja(player, nomeResolvido, cfg.Preco)
	if not spawnOk then
		dinheiro.Value = dinheiro.Value + cfg.Preco
		warn("[LojaSusp] Compra revertida: " .. tostring(err))
		return
	end

	print("💰 " .. player.Name .. " comprou a suspensão: " .. nomeResolvido)
end)
