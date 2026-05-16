-- CH Corporations - Oficina no veículo (servidor) — Colocar como Script no Model do carro (ex.: ScriptWL)
-- Revisão: RemoteEvent/Folder com timeout; valida Model, Wheels, rodaPart BasePart; dono do lote por Name ou UserId;
--          AreaGaragem como Part ou Model (resolve BasePart para overlap); debounce; pcall em clone/destruir;
--          recibo anti-dupe com nome antes de Destroy; Backpack via FindFirstChild.

print("CH Corporations - Oficina alta performance (revisão VIP + física + save)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local WAIT_INST = 25
local DEBOUNCE_ACAO = 0.35
local NOME_RODA_MAX = 120

local rodasSalvas = ReplicatedStorage:WaitForChild("RodasSalvas", WAIT_INST)
local instalarEvento = ReplicatedStorage:WaitForChild("InstalarRodaEvent", WAIT_INST)

if not rodasSalvas then
	warn("[ScriptWL] RodasSalvas em falta no ReplicatedStorage.")
	return
end
if not instalarEvento or not instalarEvento:IsA("RemoteEvent") then
	warn("[ScriptWL] InstalarRodaEvent em falta ou inválido.")
	return
end

local carModel = script.Parent
if not carModel or not carModel:IsA("Model") then
	warn("[ScriptWL] script.Parent deve ser o Model do veículo.")
	return
end

local wheelsModel = carModel:WaitForChild("Wheels", WAIT_INST)
if not wheelsModel or not wheelsModel:IsA("Model") then
	warn("[ScriptWL] Wheels em falta ou não é Model.")
	return
end

local ultimaAcao = {}

Players.PlayerRemoving:Connect(function(p)
	ultimaAcao[p] = nil
end)

local function lotePertenceAoJogador(lote, player)
	local dono = lote:GetAttribute("Dono")
	if dono == nil then
		return false
	end
	if typeof(dono) == "number" then
		return dono == player.UserId
	end
	return tostring(dono) == player.Name
end

local function resolverPartAreaGaragem(areaGaragem)
	if not areaGaragem then
		return nil
	end
	if areaGaragem:IsA("BasePart") then
		return areaGaragem
	end
	if areaGaragem:IsA("Model") then
		return areaGaragem.PrimaryPart or areaGaragem:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function carroDentroDaGaragemDoJogador(player)
	local lotesDasCasas = Workspace:FindFirstChild("LotesDasCasas")
	if not lotesDasCasas then
		return false
	end

	local loteDoPlayer = nil
	for _, lote in ipairs(lotesDasCasas:GetChildren()) do
		if lotePertenceAoJogador(lote, player) then
			loteDoPlayer = lote
			break
		end
	end

	if not loteDoPlayer then
		return false
	end

	local casa = loteDoPlayer:FindFirstChild("CasaDo_" .. player.Name, true)
	local areaGaragem = casa and casa:FindFirstChild("AreaGaragem", true)
	local areaPart = resolverPartAreaGaragem(areaGaragem)
	if not areaPart then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { carModel }

	local pecasDoCarroNaGaragem = Workspace:GetPartsInPart(areaPart, overlapParams)
	return #pecasDoCarroNaGaragem > 0
end

local function nomeCarroCorrespondeAoJogador(player)
	local esperado = player.Name .. "sCar"
	return carModel.Name == esperado
end

local function obterCarroSave(player)
	local inventario = player:FindFirstChild("InventarioVeiculos")
	local nomeOriginal = carModel:GetAttribute("ModeloOriginal")
	if not inventario or not nomeOriginal or typeof(nomeOriginal) ~= "string" then
		return nil
	end
	return inventario:FindFirstChild(nomeOriginal)
end

local function propsAtuaisOuPadrao(rodaPart)
	local p = rodaPart.CustomPhysicalProperties
	if p then
		return p
	end
	return PhysicalProperties.new(0.7, 0.7, 0.5, 1, 1)
end

local function aplicarFisicaRoda(rodaPart, atritoAlvo, modeloReferencia)
	local props = propsAtuaisOuPadrao(rodaPart)
	local atrito = atritoAlvo
	if modeloReferencia then
		atrito = modeloReferencia:GetAttribute("Aderencia") or atritoAlvo
	end
	rodaPart.CustomPhysicalProperties = PhysicalProperties.new(
		props.Density,
		atrito,
		props.Elasticity,
		props.FrictionWeight,
		props.ElasticityWeight
	)
end

--- Mesma lógica da CentralVeiculos* (espaços vs underscores).
local function encontrarModeloRodaNaPasta(nome)
	if not nome or nome == "" then
		return nil
	end
	local r = rodasSalvas:FindFirstChild(nome)
	if r then
		return r
	end
	local comUnderscore = string.gsub(nome, " ", "_")
	if comUnderscore ~= nome then
		r = rodasSalvas:FindFirstChild(comUnderscore)
		if r then
			return r
		end
	end
	local comEspaco = string.gsub(nome, "_", " ")
	if comEspaco ~= nome then
		r = rodasSalvas:FindFirstChild(comEspaco)
		if r then
			return r
		end
	end
	return nil
end

local OEM_FOLDER_SERVER = "_GearUpWheelOEM"

local function obterPastaOEMServer()
	local f = ServerStorage:FindFirstChild(OEM_FOLDER_SERVER)
	if not f then
		f = Instance.new("Folder")
		f.Name = OEM_FOLDER_SERVER
		f.Parent = ServerStorage
	end
	return f
end

local function chaveBackupOEM(player, carroSave, nomePos)
	local nomeSeguro = string.gsub(carroSave.Name, "[^%w_%-]", "_")
	return string.format("U%d_%s_%s", player.UserId, nomeSeguro, nomePos)
end

local function parteForaDoModeloRoda(part, raizModelo)
	if not part or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return true
	end
	return not part:IsDescendantOf(raizModelo)
end

--- Só remove soldas que ligam a peças fora do Model (ex.: cubo FL). Mantém welds internas entre meshes da roda.
local function limparConstraintsComReferenciasExternas(raizModelo)
	for _, d in ipairs(raizModelo:GetDescendants()) do
		if d:IsA("WeldConstraint") then
			if parteForaDoModeloRoda(d.Part0, raizModelo) or parteForaDoModeloRoda(d.Part1, raizModelo) then
				pcall(function()
					d:Destroy()
				end)
			end
		elseif d:IsA("Weld") or d:IsA("ManualWeld") or d:IsA("Motor6D") then
			if parteForaDoModeloRoda(d.Part0, raizModelo) or parteForaDoModeloRoda(d.Part1, raizModelo) then
				pcall(function()
					d:Destroy()
				end)
			end
		end
	end
end

--- Clona o visual atual em Parts (prefere Model "RodaFabrica", senão o 1.º Model) para ServerStorage
--- antes da primeira troca de roda / antes da Central aplicar roda da loja — assim o OEM pode ficar só dentro de Parts.
local function garantirBackupOEMTemplateEmServerStorage(player, carroSave, rodaPart)
	if not player or not carroSave or not rodaPart then
		return
	end
	local root = obterPastaOEMServer()
	local key = chaveBackupOEM(player, carroSave, rodaPart.Name)
	if root:FindFirstChild(key) then
		return
	end
	local partsModel = rodaPart:FindFirstChild("Parts")
	if not partsModel then
		return
	end
	local src = partsModel:FindFirstChild("RodaFabrica")
	if not (src and src:IsA("Model")) then
		src = nil
		for _, c in ipairs(partsModel:GetChildren()) do
			if c:IsA("Model") then
				src = c
				break
			end
		end
	end
	if not src then
		return
	end
	pcall(function()
		local cl = src:Clone()
		cl.Name = key
		limparConstraintsComReferenciasExternas(cl)
		--- Pivot do OEM em relação ao cubo: RodasSalvas usa pivot no cubo; o teu Model pode ter pivot noutro sítio.
		local pivotRel = rodaPart.CFrame:ToObjectSpace(src:GetPivot())
		cl:SetAttribute("OEM_PivotVsCubo", pivotRel)
		cl.Parent = root
	end)
end

local function obterTemplateOEMEmServerStorage(player, carroSave, nomePos)
	if not player or not carroSave then
		return nil
	end
	local root = ServerStorage:FindFirstChild(OEM_FOLDER_SERVER)
	if not root then
		return nil
	end
	local m = root:FindFirstChild(chaveBackupOEM(player, carroSave, nomePos))
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function diametroEstimadoPelaSize(v)
	local a = { v.X, v.Y, v.Z }
	table.sort(a, function(x, y)
		return x > y
	end)
	-- Para roda: as 2 maiores dimensões tendem a representar o diâmetro visual.
	return (a[1] + a[2]) * 0.5
end

local function fatorEscalaPelaPart(rodaPart, modeloOrigem)
	if not rodaPart or not modeloOrigem then
		return nil
	end
	if not rodaPart:IsA("BasePart") or not modeloOrigem:IsA("Model") then
		return nil
	end
	local diametroAlvo = diametroEstimadoPelaSize(rodaPart.Size)
	local diametroOrigem = diametroEstimadoPelaSize(modeloOrigem:GetExtentsSize())
	if diametroAlvo <= 1e-4 or diametroOrigem <= 1e-4 then
		return nil
	end
	return math.clamp(diametroAlvo / diametroOrigem, 0.2, 5)
end

local function fatorEscalaPorTemplate(modeloOrigem, modeloAlvo)
	if not modeloOrigem or not modeloAlvo then
		return nil
	end
	if not modeloOrigem:IsA("Model") or not modeloAlvo:IsA("Model") then
		return nil
	end
	local origem = diametroEstimadoPelaSize(modeloOrigem:GetExtentsSize())
	local alvo = diametroEstimadoPelaSize(modeloAlvo:GetExtentsSize())
	if origem <= 1e-4 or alvo <= 1e-4 then
		return nil
	end
	return math.clamp(alvo / origem, 0.2, 5)
end

local PREENCHIMENTO_VISUAL_ALVO = 1.00

local function corrigirEscalaFinalParaPart(rodaPart, modeloMontado, escalaBaseAplicada)
	if not rodaPart or not modeloMontado then
		return
	end
	if not rodaPart:IsA("BasePart") or not modeloMontado:IsA("Model") then
		return
	end
	local diametroAlvo = diametroEstimadoPelaSize(rodaPart.Size) * PREENCHIMENTO_VISUAL_ALVO
	local diametroAtual = diametroEstimadoPelaSize(modeloMontado:GetExtentsSize())
	if diametroAlvo <= 1e-4 or diametroAtual <= 1e-4 then
		return
	end
	local correcao = diametroAlvo / diametroAtual
	if math.abs(correcao - 1) < 0.01 then
		return
	end
	local base = 1
	if type(escalaBaseAplicada) == "number" and escalaBaseAplicada > 0 then
		base = escalaBaseAplicada
	end
	local escalaFinal = math.clamp(base * math.clamp(correcao, 0.35, 3.5), 0.2, 12)
	modeloMontado:ScaleTo(escalaFinal)
end

local function obterTemplateReferenciaEscala(rodaPart, player, carroSave)
	if not rodaPart then
		return nil
	end
	local nomePos = rodaPart.Name
	local emServer = obterTemplateOEMEmServerStorage(player, carroSave, nomePos)
	if emServer then
		return emServer
	end

	local partsModel = rodaPart:FindFirstChild("Parts")
	if partsModel then
		local rf = partsModel:FindFirstChild("RodaFabrica")
		if rf and rf:IsA("Model") then
			return rf
		end
	end

	local embarcado = rodaPart:FindFirstChild("RodaFabrica")
	if embarcado and embarcado:IsA("Model") then
		return embarcado
	end

	return nil
end

--- Template para voltar ao save de fábrica (nil / "" / "Padrao"):
--- 0) Clone guardado em ServerStorage._GearUpWheelOEM (criado na 1.ª troca / no spawn com roda da loja)
--- 1) Model "RodaFabrica" dentro de Parts (se ainda existir)
--- 2) Model "RodaFabrica" como filho direto do cubo FL/… (irmão de Parts), se usares esse layout
--- 3) Atributos RodaFabrica_* / RodaFabrica no Model do carro (nomes em RodasSalvas)
--- 4) Wheels>OEMRodas
--- 5) RodasSalvas.Padrao
local function resolverTemplateRodaDeFabrica(rodaPart, player, carroSave)
	local nomePos = rodaPart.Name

	local emServer = obterTemplateOEMEmServerStorage(player, carroSave, nomePos)
	if emServer then
		return emServer
	end

	local partsModel = rodaPart:FindFirstChild("Parts")
	if partsModel then
		local rf = partsModel:FindFirstChild("RodaFabrica")
		if rf and rf:IsA("Model") then
			return rf
		end
	end

	local embarcado = rodaPart:FindFirstChild("RodaFabrica")
	if embarcado and embarcado:IsA("Model") then
		return embarcado
	end

	local porCanto = carModel:GetAttribute("RodaFabrica_" .. nomePos)
	if typeof(porCanto) == "string" and porCanto ~= "" then
		local m = encontrarModeloRodaNaPasta(porCanto)
		if m then
			return m
		end
	end
	local global = carModel:GetAttribute("RodaFabrica")
	if typeof(global) == "string" and global ~= "" then
		local m = encontrarModeloRodaNaPasta(global)
		if m then
			return m
		end
	end
	local oemRoot = wheelsModel:FindFirstChild("OEMRodas")
	if oemRoot then
		local cand = oemRoot:FindFirstChild(nomePos)
		if cand and cand:IsA("Model") then
			return cand
		end
	end
	return encontrarModeloRodaNaPasta("Padrao")
end

local function saveIndicaRodaDeFabrica(carroSave, nomePos)
	local v = carroSave:GetAttribute(nomePos)
	if v == nil then
		return true
	end
	if typeof(v) ~= "string" then
		return false
	end
	local s = string.gsub(v, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s == "" or s == "Padrao"
end

local function relNoCuboEhValido(rodaPart, rel)
	if not rodaPart or not rodaPart:IsA("BasePart") then
		return false
	end
	if typeof(rel) ~= "CFrame" then
		return false
	end
	local limite = math.max(rodaPart.Size.X, rodaPart.Size.Y, rodaPart.Size.Z) * 1.6
	return rel.Position.Magnitude <= limite
end

local function obterRelPosicaoConfiavelNoCubo(rodaPart, player, carroSave, modeloRodaTemplate)
	local templateRef = obterTemplateReferenciaEscala(rodaPart, player, carroSave)
	if templateRef and templateRef:IsA("Model") then
		local relRef = templateRef:GetAttribute("OEM_PivotVsCubo")
		if relNoCuboEhValido(rodaPart, relRef) then
			return relRef
		end
	end
	if modeloRodaTemplate and modeloRodaTemplate:IsA("Model") then
		local relTemplate = modeloRodaTemplate:GetAttribute("OEM_PivotVsCubo")
		if relNoCuboEhValido(rodaPart, relTemplate) then
			return relTemplate
		end
	end
	return nil
end

local function pivotarModeloRodaNoCubo(rodaPart, modeloTemplate, instanciaMontada, relOverride, forcarRelOverride)
	local rel = relOverride
	if forcarRelOverride and typeof(rel) == "CFrame" then
		instanciaMontada:PivotTo(rodaPart.CFrame * rel)
		return
	end
	if not relNoCuboEhValido(rodaPart, rel) then
		rel = modeloTemplate:GetAttribute("OEM_PivotVsCubo")
	end
	if relNoCuboEhValido(rodaPart, rel) then
		instanciaMontada:PivotTo(rodaPart.CFrame * rel)
	else
		instanciaMontada:PivotTo(rodaPart.CFrame)
	end
end

local function limparPartsEMontarVisual(rodaPart, modeloRodaTemplate, fatorEscala, relPosicao, forcarRelPosicao, aplicarAjusteVisual)
	local partsModel = rodaPart:FindFirstChild("Parts")
	if not partsModel or not modeloRodaTemplate then
		return false
	end
	if aplicarAjusteVisual == nil then
		aplicarAjusteVisual = true
	end

	for _, filho in ipairs(partsModel:GetChildren()) do
		pcall(function()
			filho:Destroy()
		end)
	end

	local novaRodaVisual
	local ok = pcall(function()
		novaRodaVisual = modeloRodaTemplate:Clone()
		novaRodaVisual.Parent = partsModel
		local escalaBase = 1
		if typeof(fatorEscala) == "number" and fatorEscala > 0 and math.abs(fatorEscala - 1) > 1e-3 then
			novaRodaVisual:ScaleTo(fatorEscala)
			escalaBase = fatorEscala
		end
		pivotarModeloRodaNoCubo(rodaPart, modeloRodaTemplate, novaRodaVisual, relPosicao, forcarRelPosicao)
		if aplicarAjusteVisual then
			corrigirEscalaFinalParaPart(rodaPart, novaRodaVisual, escalaBase)
			pivotarModeloRodaNoCubo(rodaPart, modeloRodaTemplate, novaRodaVisual, relPosicao, forcarRelPosicao)
		end
	end)
	if not ok or not novaRodaVisual then
		return false
	end

	for _, part in ipairs(novaRodaVisual:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			local solda = Instance.new("WeldConstraint")
			solda.Part0 = rodaPart
			solda.Part1 = part
			solda.Parent = part
		end
	end

	return true
end

instalarEvento.OnServerEvent:Connect(function(player, rodaPart)
	if not player or not player:IsA("Player") then
		return
	end
	if typeof(rodaPart) ~= "Instance" or not rodaPart:IsA("BasePart") then
		return
	end
	if not rodaPart:IsDescendantOf(wheelsModel) then
		return
	end
	if not nomeCarroCorrespondeAoJogador(player) then
		return
	end
	if not carroDentroDaGaragemDoJogador(player) then
		return
	end

	local agora = os.clock()
	local mapa = ultimaAcao[player]
	if mapa and mapa[rodaPart] and (agora - mapa[rodaPart]) < DEBOUNCE_ACAO then
		return
	end
	if not mapa then
		mapa = {}
		ultimaAcao[player] = mapa
	end
	mapa[rodaPart] = agora

	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return
	end

	local carroSave = obterCarroSave(player)
	if not carroSave then
		warn("[ScriptWL] Veículo não encontrado em InventarioVeiculos / ModeloOriginal.")
		return
	end

	-- === Instalar roda (caixa com TipoDeRoda) ===
	local tipoDeRodaValue = tool:FindFirstChild("TipoDeRoda")
	if tipoDeRodaValue and tipoDeRodaValue:IsA("StringValue") then
		local nomeDaNovaRoda = tipoDeRodaValue.Value
		if typeof(nomeDaNovaRoda) ~= "string" or #nomeDaNovaRoda == 0 or #nomeDaNovaRoda > NOME_RODA_MAX then
			return
		end

		local partsModel = rodaPart:FindFirstChild("Parts")
		if not partsModel then
			return
		end

		if partsModel:FindFirstChild(nomeDaNovaRoda) then
			return
		end

		local rodaOriginal = encontrarModeloRodaNaPasta(nomeDaNovaRoda)
		if not rodaOriginal then
			return
		end

		if saveIndicaRodaDeFabrica(carroSave, rodaPart.Name) then
			garantirBackupOEMTemplateEmServerStorage(player, carroSave, rodaPart)
		end

		-- Instalação de roda MOD: usa referência da própria roda nova (ou centro do cubo),
		-- evitando herdar offset OEM que pode deslocar visual em alguns carros.
		local relPosicao = nil
		local fatorEscala = fatorEscalaPelaPart(rodaPart, rodaOriginal)
		if not fatorEscala then
			local templateEscala = obterTemplateReferenciaEscala(rodaPart, player, carroSave)
			fatorEscala = fatorEscalaPorTemplate(rodaOriginal, templateEscala)
		end
		if not limparPartsEMontarVisual(rodaPart, rodaOriginal, fatorEscala, relPosicao) then
			return
		end

		local novaAderencia = rodaOriginal:GetAttribute("Aderencia") or 0.7
		aplicarFisicaRoda(rodaPart, novaAderencia, nil)

		pcall(function()
			carroSave:SetAttribute(rodaPart.Name, nomeDaNovaRoda)
		end)

		local cliques = tonumber(tool:GetAttribute("CliquesDeInstalacao")) or 0
		cliques += 1
		tool:SetAttribute("CliquesDeInstalacao", cliques)

		if cliques >= 4 then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				pcall(function()
					humanoid:UnequipTools()
				end)
			end
			task.wait(0.1)

			local invJogador = player:FindFirstChild("InventarioFerramentas")
			if invJogador then
				local nomeUnderline = string.gsub(nomeDaNovaRoda, " ", "_")
				local recordUsado = invJogador:FindFirstChild(nomeDaNovaRoda) or invJogador:FindFirstChild(nomeUnderline)
				if recordUsado then
					local nomeRecibo = recordUsado.Name
					pcall(function()
						recordUsado:Destroy()
					end)
					print("[ScriptWL] Recibo de roda removido: " .. nomeRecibo)
				end
			end

			pcall(function()
				tool:Destroy()
			end)
		end

		print("[ScriptWL] Roda instalada: " .. nomeDaNovaRoda .. " | aderência " .. tostring(novaAderencia))
		return
	end

	-- === Desparafusar (ChaveDeRoda) ===
	if tool.Name ~= "ChaveDeRoda" then
		return
	end

	local nomeDaRodaAtual = carroSave:GetAttribute(rodaPart.Name)
	if nomeDaRodaAtual == nil then
		return
	end
	if typeof(nomeDaRodaAtual) ~= "string" then
		return
	end
	local nomeTrim = string.gsub(nomeDaRodaAtual, "^%s+", "")
	nomeTrim = string.gsub(nomeTrim, "%s+$", "")
	if nomeTrim == "" or nomeTrim == "Padrao" or #nomeTrim > NOME_RODA_MAX then
		return
	end
	nomeDaRodaAtual = nomeTrim

	local partsModel = rodaPart:FindFirstChild("Parts")
	if not partsModel then
		return
	end

	for _, filho in ipairs(partsModel:GetChildren()) do
		pcall(function()
			filho:Destroy()
		end)
	end

	local templateFabrica = resolverTemplateRodaDeFabrica(rodaPart, player, carroSave)
	if templateFabrica then
		local relPosicaoOEM = templateFabrica:GetAttribute("OEM_PivotVsCubo")
		if limparPartsEMontarVisual(rodaPart, templateFabrica, nil, relPosicaoOEM, true, false) then
			local aderenciaFabrica = tonumber(templateFabrica:GetAttribute("Aderencia")) or 0.7
			aplicarFisicaRoda(rodaPart, aderenciaFabrica, nil)
		end
	else
		warn(
			"[ScriptWL] Sem template de roda de fábrica para "
				.. rodaPart.Name
				.. " (carro "
				.. carModel.Name
				.. "). Instala uma vez com o OEM em Parts, ou usa RodasSalvas / atributos RodaFabrica_*."
		)
	end

	pcall(function()
		carroSave:SetAttribute(rodaPart.Name, nil)
	end)

	local rodaOriginalDoCarro = encontrarModeloRodaNaPasta(nomeDaRodaAtual)
	local isPremium = rodaOriginalDoCarro and rodaOriginalDoCarro:GetAttribute("Premium") == true

	local nomeDaCaixa = "Caixa " .. nomeDaRodaAtual
	local bp = player:FindFirstChild("Backpack")
	local caixaExistente = (bp and bp:FindFirstChild(nomeDaCaixa)) or character:FindFirstChild(nomeDaCaixa)

	if caixaExistente then
		local cliquesAtuais = tonumber(caixaExistente:GetAttribute("CliquesDeInstalacao")) or 3
		if cliquesAtuais > 0 then
			caixaExistente:SetAttribute("CliquesDeInstalacao", cliquesAtuais - 1)
		end
	else
		local nomeDaFerramenta = isPremium and "CaixaPremium" or "CaixaBase"
		local toolOriginal = ServerStorage:FindFirstChild(nomeDaFerramenta)
		if toolOriginal and toolOriginal:IsA("Tool") then
			local novaTool
			local okClone = pcall(function()
				novaTool = toolOriginal:Clone()
			end)
			if okClone and novaTool then
				novaTool.Name = nomeDaCaixa
				local novoValorRoda = Instance.new("StringValue")
				novoValorRoda.Name = "TipoDeRoda"
				novoValorRoda.Value = nomeDaRodaAtual
				novoValorRoda.Parent = novaTool
				novaTool:SetAttribute("CliquesDeInstalacao", 3)
				if isPremium then
					novaTool:SetAttribute("Premium", true)
				end

				if bp then
					pcall(function()
						novaTool.Parent = bp
					end)
				else
					pcall(function()
						novaTool.Parent = player
					end)
				end

				local invJogador = player:FindFirstChild("InventarioFerramentas")
				if invJogador then
					local nomeUnderline = string.gsub(nomeDaRodaAtual, " ", "_")
					if not invJogador:FindFirstChild(nomeUnderline) and not invJogador:FindFirstChild(nomeDaRodaAtual) then
						pcall(function()
							local novoRecord = Instance.new("StringValue")
							novoRecord.Name = nomeUnderline
							novoRecord.Value = "Desinstalada"
							novoRecord.Parent = invJogador
						end)
						print("[ScriptWL] Recibo recriado: " .. nomeUnderline)
					end
				end
			end
		end
	end
end)
