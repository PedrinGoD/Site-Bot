-- CH Corporations - Central de veículos (garagem + meet + anti-farm likes)
-- Revisão V5: rodas custom; suspensão salva com retry + heartbeats (SpringConstraint após LoadAsset);
--          detecta kit por SuspensaoNome ou por altura/rigidez/amort ≠ stock (2 / 4500 / 500).

print("Ch Corporations - Central de Veículos (Híbrido — revisão V5: spawn rodas loja)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local TIMEOUT = 120
local DEBOUNCE_SPAWN_SEG = 1
local HEARTBEATS_ANTES_SUSPENSAO = 2
local TENTATIVAS_APLICAR_SUSPENSAO = 30
local HEARTBEATS_ANTES_RODAS = 3
local EXTRA_WAIT_SEG_ANTES_RODAS = 0.25
local REMOUNT_DELAY_RODAS_CUSTOM = 0.45
local DELAY_MINIMO_ENTRAR_CARRO = 1.35

-- Valores “de concessionária” no save (GerenciadorDeDadosMaster) — abaixo disso = não há kit custom.
local STOCK_SUSP_ALTURA = 2
local STOCK_SUSP_RIGIDEZ = 4500
local STOCK_SUSP_AMORT = 500

local SPAWN_CASA = "Casa"

local spawnarEvento = ReplicatedStorage:WaitForChild("SpawnarVeiculoGaragemEvent", TIMEOUT)
local guardarEvento = ReplicatedStorage:WaitForChild("GuardarVeiculoGaragemEvent", TIMEOUT)
local guiaEvent = ReplicatedStorage:WaitForChild("GuiaVisualEvent", TIMEOUT)

if not spawnarEvento or not spawnarEvento:IsA("RemoteEvent") then
	warn("[CentralVeiculos] SpawnarVeiculoGaragemEvent em falta ou inválido.")
	return
end
if not guardarEvento or not guardarEvento:IsA("RemoteEvent") then
	warn("[CentralVeiculos] GuardarVeiculoGaragemEvent em falta ou inválido.")
	return
end
if not guiaEvent or not guiaEvent:IsA("RemoteEvent") then
	warn("[CentralVeiculos] GuiaVisualEvent em falta ou inválido.")
	return
end

local registroDeCarros = ServerStorage:WaitForChild("RegistroDeCarros", TIMEOUT)
local estacionamentoModel = Workspace:WaitForChild("EstacionamentoG", TIMEOUT)
local rodasSalvas = ReplicatedStorage:WaitForChild("RodasSalvas", TIMEOUT)
if not registroDeCarros or not estacionamentoModel or not rodasSalvas then
	warn("[CentralVeiculos] RegistroDeCarros, EstacionamentoG ou RodasSalvas em falta.")
	return
end

local historicoDeCurtidas = {}
local ultimoSpawn = {}

Players.PlayerRemoving:Connect(function(player)
	historicoDeCurtidas[player.UserId] = nil
	ultimoSpawn[player.UserId] = nil
end)

local function cframeDePonto(alvo)
	if not alvo then
		return nil
	end
	if alvo:IsA("BasePart") then
		return alvo.CFrame
	end
	if alvo:IsA("Model") then
		return alvo:GetPivot()
	end
	return nil
end

local function aplicarPoseNoMundo(instancia, cf)
	if not cf then
		return
	end
	if instancia:IsA("Model") then
		instancia:PivotTo(cf)
	elseif instancia:IsA("BasePart") then
		instancia.CFrame = cf
	end
end

local function propsAtuaisOuPadrao(rodaPart)
	local p = rodaPart.CustomPhysicalProperties
	if p then
		return p
	end
	return PhysicalProperties.new(0.7, 0.7, 0.5, 1, 1)
end

local function deveAplicarSuspensaoSalva(carroSave)
	local suspNome = carroSave:GetAttribute("SuspensaoNome")
	if typeof(suspNome) == "string" and suspNome ~= "" and suspNome ~= "Padrao" then
		return true
	end
	local a = tonumber(carroSave:GetAttribute("SuspensaoAltura"))
	local r = tonumber(carroSave:GetAttribute("SuspensaoRigidez"))
	local d = tonumber(carroSave:GetAttribute("SuspensaoAmortecimento"))
	if a and math.abs(a - STOCK_SUSP_ALTURA) > 1e-2 then
		return true
	end
	if r and math.abs(r - STOCK_SUSP_RIGIDEZ) > 1e-2 then
		return true
	end
	if d and math.abs(d - STOCK_SUSP_AMORT) > 1e-2 then
		return true
	end
	return false
end

--- Ajusta SpringConstraints; devolve quantas molas foram alteradas.
local function aplicarSuspensaoSalva(novoCarro, carroSave)
	if not deveAplicarSuspensaoSalva(carroSave) then
		return 0
	end
	local pAltura = tonumber(carroSave:GetAttribute("SuspensaoAltura")) or STOCK_SUSP_ALTURA
	local pRigidez = tonumber(carroSave:GetAttribute("SuspensaoRigidez")) or STOCK_SUSP_RIGIDEZ
	local pAmortecimento = tonumber(carroSave:GetAttribute("SuspensaoAmortecimento")) or STOCK_SUSP_AMORT
	pAltura = math.clamp(pAltura, 0.1, 20)
	pRigidez = math.clamp(pRigidez, 0, 100000)
	pAmortecimento = math.clamp(pAmortecimento, 0, 50000)
	local n = 0
	for _, obj in ipairs(novoCarro:GetDescendants()) do
		if obj:IsA("SpringConstraint") then
			obj.FreeLength = pAltura
			obj.Stiffness = pRigidez
			obj.Damping = pAmortecimento
			n += 1
		end
	end
	return n
end

--- LoadAsset pode demorar a instanciar constraints; tenta durante alguns frames.
local function aplicarSuspensaoSalvaComRetry(novoCarro, carroSave)
	if not deveAplicarSuspensaoSalva(carroSave) then
		return
	end
	for _ = 1, TENTATIVAS_APLICAR_SUSPENSAO do
		if not novoCarro.Parent then
			return
		end
		if aplicarSuspensaoSalva(novoCarro, carroSave) > 0 then
			return
		end
		RunService.Heartbeat:Wait()
	end
	warn("[CentralVeiculosGaragem] Suspensão salva não aplicada: nenhum SpringConstraint no modelo (verifica o asset do carro).")
end

local function normalizarNomeRodaSalvo(valorBruto)
	if typeof(valorBruto) ~= "string" then
		return nil
	end
	local s = valorBruto
	if string.find(s, "|", 1, true) then
		local partes = string.split(s, "|")
		s = partes[1] or s
	end
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	if s == "" or s == "Padrao" then
		return nil
	end
	return s
end

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

local function jogadorDonoDoCarroSaveGaragem(carroSave)
	local inv = carroSave and carroSave.Parent
	if inv and inv:IsA("Folder") and inv.Name == "InventarioVeiculos" then
		local pl = inv.Parent
		if pl and pl:IsA("Player") then
			return pl
		end
	end
	return nil
end

local function obterPastaOEMServerGaragem()
	local f = ServerStorage:FindFirstChild(OEM_FOLDER_SERVER)
	if not f then
		f = Instance.new("Folder")
		f.Name = OEM_FOLDER_SERVER
		f.Parent = ServerStorage
	end
	return f
end

local function chaveBackupOEMGaragem(player, carroSave, nomePos)
	local nomeSeguro = string.gsub(carroSave.Name, "[^%w_%-]", "_")
	return string.format("U%d_%s_%s", player.UserId, nomeSeguro, nomePos)
end

local function obterTemplateOEMEmServerStorageGaragem(player, carroSave, nomePos)
	if not player or not carroSave then
		return nil
	end
	local root = ServerStorage:FindFirstChild(OEM_FOLDER_SERVER)
	if not root then
		return nil
	end
	local m = root:FindFirstChild(chaveBackupOEMGaragem(player, carroSave, nomePos))
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function parteForaDoModeloRodaGaragem(part, raizModelo)
	if not part or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return true
	end
	return not part:IsDescendantOf(raizModelo)
end

local function diametroEstimadoPelaSizeGaragem(v)
	local a = { v.X, v.Y, v.Z }
	table.sort(a, function(x, y)
		return x > y
	end)
	return (a[1] + a[2]) * 0.5
end

local function fatorEscalaPelaPartGaragem(rodaPart, modeloOrigem)
	if not rodaPart or not modeloOrigem then
		return nil
	end
	if not rodaPart:IsA("BasePart") or not modeloOrigem:IsA("Model") then
		return nil
	end
	local diametroAlvo = diametroEstimadoPelaSizeGaragem(rodaPart.Size)
	local diametroOrigem = diametroEstimadoPelaSizeGaragem(modeloOrigem:GetExtentsSize())
	if diametroAlvo <= 1e-4 or diametroOrigem <= 1e-4 then
		return nil
	end
	return math.clamp(diametroAlvo / diametroOrigem, 0.2, 5)
end

local function fatorEscalaPorTemplateGaragem(modeloOrigem, modeloAlvo)
	if not modeloOrigem or not modeloAlvo then
		return nil
	end
	if not modeloOrigem:IsA("Model") or not modeloAlvo:IsA("Model") then
		return nil
	end
	local origem = diametroEstimadoPelaSizeGaragem(modeloOrigem:GetExtentsSize())
	local alvo = diametroEstimadoPelaSizeGaragem(modeloAlvo:GetExtentsSize())
	if origem <= 1e-4 or alvo <= 1e-4 then
		return nil
	end
	return math.clamp(alvo / origem, 0.2, 5)
end

local PREENCHIMENTO_VISUAL_ALVO_GARAGEM = 1.00

local function corrigirEscalaFinalParaPartGaragem(rodaPart, modeloMontado, escalaBaseAplicada)
	if not rodaPart or not modeloMontado then
		return
	end
	if not rodaPart:IsA("BasePart") or not modeloMontado:IsA("Model") then
		return
	end
	local diametroAlvo = diametroEstimadoPelaSizeGaragem(rodaPart.Size) * PREENCHIMENTO_VISUAL_ALVO_GARAGEM
	local diametroAtual = diametroEstimadoPelaSizeGaragem(modeloMontado:GetExtentsSize())
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

local function obterTemplateReferenciaEscalaGaragem(rodaPart, player, carroSave)
	if not rodaPart then
		return nil
	end
	local emServer = obterTemplateOEMEmServerStorageGaragem(player, carroSave, rodaPart.Name)
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

local function relNoCuboEhValidoGaragem(rodaPart, rel)
	if not rodaPart or not rodaPart:IsA("BasePart") then
		return false
	end
	if typeof(rel) ~= "CFrame" then
		return false
	end
	local limite = math.max(rodaPart.Size.X, rodaPart.Size.Y, rodaPart.Size.Z) * 1.6
	return rel.Position.Magnitude <= limite
end

local function obterRelPosicaoConfiavelNoCuboGaragem(rodaPart, player, carroSave, modeloRodaTemplate)
	local templateRef = obterTemplateReferenciaEscalaGaragem(rodaPart, player, carroSave)
	if templateRef and templateRef:IsA("Model") then
		local relRef = templateRef:GetAttribute("OEM_PivotVsCubo")
		if relNoCuboEhValidoGaragem(rodaPart, relRef) then
			return relRef
		end
	end
	if modeloRodaTemplate and modeloRodaTemplate:IsA("Model") then
		local relTemplate = modeloRodaTemplate:GetAttribute("OEM_PivotVsCubo")
		if relNoCuboEhValidoGaragem(rodaPart, relTemplate) then
			return relTemplate
		end
	end
	return nil
end

local function limparConstraintsComReferenciasExternasGaragem(raizModelo)
	for _, d in ipairs(raizModelo:GetDescendants()) do
		if d:IsA("WeldConstraint") then
			if parteForaDoModeloRodaGaragem(d.Part0, raizModelo) or parteForaDoModeloRodaGaragem(d.Part1, raizModelo) then
				pcall(function()
					d:Destroy()
				end)
			end
		elseif d:IsA("Weld") or d:IsA("ManualWeld") or d:IsA("Motor6D") then
			if parteForaDoModeloRodaGaragem(d.Part0, raizModelo) or parteForaDoModeloRodaGaragem(d.Part1, raizModelo) then
				pcall(function()
					d:Destroy()
				end)
			end
		end
	end
end

local function garantirBackupOEMTemplateEmServerStorageGaragem(player, carroSave, rodaPart)
	if not player or not carroSave or not rodaPart then
		return
	end
	local root = obterPastaOEMServerGaragem()
	local key = chaveBackupOEMGaragem(player, carroSave, rodaPart.Name)
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
		limparConstraintsComReferenciasExternasGaragem(cl)
		local pivotRel = rodaPart.CFrame:ToObjectSpace(src:GetPivot())
		cl:SetAttribute("OEM_PivotVsCubo", pivotRel)
		cl.Parent = root
	end)
end

local function carroTemRodasNaoPadrao(carroSave)
	for _, pos in ipairs({ "FL", "FR", "RL", "RR" }) do
		if normalizarNomeRodaSalvo(carroSave:GetAttribute(pos)) then
			return true
		end
	end
	return false
end

--- Mesma ideia do ScriptWL: limpar Parts → clone → PivotTo(cubo) → WeldConstraint.
local function aplicarRodasDoSave(novoCarro, carroSave)
	local wheelsModel = novoCarro:FindFirstChild("Wheels")
	if not wheelsModel then
		return
	end

	local playerDono = jogadorDonoDoCarroSaveGaragem(carroSave)

	for _, pos in ipairs({ "FL", "FR", "RL", "RR" }) do
		local nomeDaRoda = normalizarNomeRodaSalvo(carroSave:GetAttribute(pos))
		local rodaPart = wheelsModel:FindFirstChild(pos)
		if nomeDaRoda and rodaPart then
			local rodaOriginal = encontrarModeloRodaNaPasta(nomeDaRoda)
			local partsModel = rodaPart and rodaPart:FindFirstChild("Parts")
			if rodaOriginal and partsModel then
				if playerDono then
					garantirBackupOEMTemplateEmServerStorageGaragem(playerDono, carroSave, rodaPart)
				end
				local relPosicao = obterRelPosicaoConfiavelNoCuboGaragem(rodaPart, playerDono, carroSave, rodaOriginal)
				local fatorEscala = fatorEscalaPelaPartGaragem(rodaPart, rodaOriginal)
				if not fatorEscala then
					local templateEscala = obterTemplateReferenciaEscalaGaragem(rodaPart, playerDono, carroSave)
					fatorEscala = fatorEscalaPorTemplateGaragem(rodaOriginal, templateEscala)
				end
				for _, filho in ipairs(partsModel:GetChildren()) do
					pcall(function()
						filho:Destroy()
					end)
				end

				local novaRodaVisual
				local okClone = pcall(function()
					novaRodaVisual = rodaOriginal:Clone()
					novaRodaVisual.Parent = partsModel
					local escalaBase = 1
					if typeof(fatorEscala) == "number" and fatorEscala > 0 and math.abs(fatorEscala - 1) > 1e-3 then
						novaRodaVisual:ScaleTo(fatorEscala)
						escalaBase = fatorEscala
					end
					local rel = relPosicao
					if not relNoCuboEhValidoGaragem(rodaPart, rel) then
						rel = rodaOriginal:GetAttribute("OEM_PivotVsCubo")
					end
					if relNoCuboEhValidoGaragem(rodaPart, rel) then
						novaRodaVisual:PivotTo(rodaPart.CFrame * rel)
					else
						novaRodaVisual:PivotTo(rodaPart.CFrame)
					end
					corrigirEscalaFinalParaPartGaragem(rodaPart, novaRodaVisual, escalaBase)
					if relNoCuboEhValidoGaragem(rodaPart, rel) then
						novaRodaVisual:PivotTo(rodaPart.CFrame * rel)
					else
						novaRodaVisual:PivotTo(rodaPart.CFrame)
					end
				end)
				if okClone and novaRodaVisual then
					for _, part in ipairs(novaRodaVisual:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Anchored = false
							part.CanCollide = false
							part.Massless = true
							pcall(function()
								local solda = Instance.new("WeldConstraint")
								solda.Part0 = rodaPart
								solda.Part1 = part
								solda.Parent = part
							end)
						end
					end

					local novaAderencia = tonumber(rodaOriginal:GetAttribute("Aderencia")) or 0.7
					local propsBase = propsAtuaisOuPadrao(rodaPart)
					pcall(function()
						rodaPart.CustomPhysicalProperties = PhysicalProperties.new(
							propsBase.Density,
							novaAderencia,
							propsBase.Elasticity,
							propsBase.FrictionWeight,
							propsBase.ElasticityWeight
						)
					end)
				end
			end
		end
	end
end

local function ResgatarItensPortaMalas(player)
	local prateleiraData = player:FindFirstChild("PrateleiraData")
	local invFerramentas = player:FindFirstChild("InventarioFerramentas")
	local backupData = player:FindFirstChild("PortaMalasBackup")

	if not prateleiraData or not invFerramentas or not backupData then
		return
	end

	for _, obj in ipairs(backupData:GetChildren()) do
		if obj:IsA("StringValue") and obj.Value ~= "" then
			local dados = obj.Value
			local partes = string.split(dados, "|")

			local isPremium = partes[#partes] == "true"
			local nomeParaInventario = partes[1]
			local valorOpcional = ""

			if partes[1] == "SPRAY" then
				nomeParaInventario = "TintaSpray"
				valorOpcional = partes[2] or ""
			elseif partes[1] == "GALAO" then
				nomeParaInventario = "Gasolina5l"
			elseif partes[1] == "SUSPENSAO" or partes[1] == "ECU" then
				nomeParaInventario = partes[2] or partes[1]
			else
				nomeParaInventario = string.gsub(partes[1], " ", "_")
			end

			local salvoNaPrateleira = false
			for i = 1, 24 do
				local slotPrateleira = prateleiraData:FindFirstChild("Slot" .. i)
				if slotPrateleira and slotPrateleira.Value == "" then
					slotPrateleira.Value = dados
					salvoNaPrateleira = true
					print("📦 RESGATE GARAGEM: Item '" .. nomeParaInventario .. "' na prateleira.")
					break
				end
			end

			if not salvoNaPrateleira and isPremium then
				if not invFerramentas:FindFirstChild(nomeParaInventario) then
					local novoRecord = Instance.new("StringValue")
					novoRecord.Name = nomeParaInventario
					novoRecord.Value = (valorOpcional ~= "") and valorOpcional or "Comprada"
					novoRecord.Parent = invFerramentas
				end
			end
		end
	end
	backupData:ClearAllChildren()
end

local function estaOcupada(vaga)
	if not vaga or not vaga:IsA("BasePart") then
		return true
	end
	local tamanhoDeteccao = vaga.Size - Vector3.new(1, 0, 1) + Vector3.new(0, 8, 0)
	local cframeDeteccao = vaga.CFrame * CFrame.new(0, 4.5, 0)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { vaga, estacionamentoModel }
	local partesEncontradas = Workspace:GetPartBoundsInBox(cframeDeteccao, tamanhoDeteccao, overlapParams)
	for _, parte in ipairs(partesEncontradas) do
		local modelo = parte:FindFirstAncestorOfClass("Model")
		if modelo and modelo ~= estacionamentoModel then
			if modelo:FindFirstChildOfClass("Humanoid") or modelo:FindFirstChildOfClass("VehicleSeat") or modelo:FindFirstChild("DriveSeat") then
				return true
			end
		end
	end
	return false
end

local function encontrarVagaLivre()
	local todasAsVagas = {}
	for _, objeto in ipairs(estacionamentoModel:GetChildren()) do
		if objeto.Name == "LocalDeSpawn" and objeto:IsA("BasePart") then
			table.insert(todasAsVagas, objeto)
		end
	end
	for _, vaga in ipairs(todasAsVagas) do
		if not estaOcupada(vaga) then
			return vaga
		end
	end
	return nil
end

local function salvarCombustivelNoInventario(player, carro)
	if not carro then
		return
	end
	local combustivelAtual = carro:GetAttribute("Combustivel")
	local nomeOriginal = carro:GetAttribute("ModeloOriginal")
	combustivelAtual = (type(combustivelAtual) == "number" and combustivelAtual) or tonumber(combustivelAtual)
	if not combustivelAtual or type(nomeOriginal) ~= "string" or nomeOriginal == "" then
		return
	end
	local inventario = player:FindFirstChild("InventarioVeiculos")
	if not inventario then
		return
	end
	local carroSave = inventario:FindFirstChild(nomeOriginal)
	if carroSave then
		pcall(function()
			carroSave:SetAttribute("CombustivelSalvo", combustivelAtual)
		end)
	end
end

guardarEvento.OnServerEvent:Connect(function(player)
	local nomeDoCarroDoDono = player.Name .. "sCar"
	local carroNoMapa = Workspace:FindFirstChild(nomeDoCarroDoDono)

	if carroNoMapa then
		ResgatarItensPortaMalas(player)
		salvarCombustivelNoInventario(player, carroNoMapa)
		pcall(function()
			carroNoMapa:Destroy()
		end)
	end
end)

--- Só para spawn manual (UI / botão). Auto-spawn VIP passa isAutoSpawn == true e não chama isto.
local function colocarJogadorNoCarroAposSpawn(player, novoCarro)
	task.defer(function()
		task.wait(DELAY_MINIMO_ENTRAR_CARRO)
		for _ = 1, 60 do
			if not novoCarro.Parent then
				return
			end
			RunService.Heartbeat:Wait()
			if not player.Parent then
				return
			end
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				return
			end
			local seat = novoCarro:FindFirstChild("DriveSeat", true)
			if not (seat and seat:IsA("VehicleSeat")) then
				seat = novoCarro:FindFirstChildWhichIsA("VehicleSeat", true)
			end
			if seat and seat:IsA("VehicleSeat") then
				local ok = pcall(function()
					seat:Sit(hum)
				end)
				if ok then
					return
				end
			end
		end
	end)
end

--- Spawn completo (LoadAsset + save cor/ECU/combustível + suspensão/rodas + UI meet). Usado pela garagem e pelo guincho (respawn).
local function spawnarVeiculoNaCFrameGaragem(player, nomeDoCarro, cfSpawn, isAutoSpawn, opts)
	opts = opts or {}
	local uid = player.UserId
	local agora = os.clock()
	if not opts.skipDebounce and ultimoSpawn[uid] and (agora - ultimoSpawn[uid]) < DEBOUNCE_SPAWN_SEG then
		return false
	end

	if type(nomeDoCarro) ~= "string" or nomeDoCarro == "" then
		return false
	end

	local inventario = player:FindFirstChild("InventarioVeiculos")
	if not inventario or not inventario:FindFirstChild(nomeDoCarro) then
		return false
	end

	local nomeFormatado = string.gsub(nomeDoCarro, " ", "_")
	local idDoCarro = registroDeCarros:GetAttribute(nomeFormatado)
	if not idDoCarro then
		return false
	end

	if not cfSpawn then
		return false
	end

	local nomeDoCarroDoDono = player.Name .. "sCar"
	local carroAntigo = Workspace:FindFirstChild(nomeDoCarroDoDono)

	if carroAntigo then
		ResgatarItensPortaMalas(player)
		salvarCombustivelNoInventario(player, carroAntigo)
		pcall(function()
			carroAntigo:Destroy()
		end)
	end

	ultimoSpawn[uid] = agora

	local sucesso, modeloBaixado = pcall(function()
		return InsertService:LoadAsset(idDoCarro)
	end)

	if not sucesso or not modeloBaixado then
		return false
	end

	local filhos = modeloBaixado:GetChildren()
	local novoCarro = filhos[1]
	if not novoCarro then
		modeloBaixado:Destroy()
		return false
	end

	novoCarro.Name = nomeDoCarroDoDono
	novoCarro:SetAttribute("ModeloOriginal", nomeDoCarro)

	local carNameTag = Instance.new("StringValue")
	carNameTag.Name = "CarName"
	carNameTag.Value = nomeDoCarro
	carNameTag.Parent = novoCarro

	local posicaoSpawn = cfSpawn * CFrame.new(0, 2, 0)
	aplicarPoseNoMundo(novoCarro, posicaoSpawn)
	novoCarro.Parent = Workspace

	local carroSave = inventario:FindFirstChild(nomeDoCarro)

	if carroSave then
		local corSalva = carroSave:GetAttribute("CorDoCarro")
		if type(corSalva) == "string" and corSalva ~= "" then
			local rgb = string.split(corSalva, ",")
			if #rgb == 3 then
				local corRecuperada = Color3.fromRGB(tonumber(rgb[1]) or 0, tonumber(rgb[2]) or 0, tonumber(rgb[3]) or 0)
				for _, obj in ipairs(novoCarro:GetDescendants()) do
					if obj:IsA("BasePart") and obj.Name == "Paint" then
						obj.Color = corRecuperada
					end
				end
			end
		end

		local combValue = carroSave:GetAttribute("CombustivelSalvo")
		combValue = (type(combValue) == "number" and combValue) or tonumber(combValue)
		novoCarro:SetAttribute("Combustivel", combValue or 100)

		local motorValue = tonumber(carroSave:GetAttribute("MotorAtual"))
		if motorValue and motorValue > 0 then
			novoCarro:SetAttribute("NivelECU", motorValue)
		end

		--- Suspensão (com espera/retry — constraints do InsertService podem aparecer 1–2 frames depois) → física → rodas.
		task.defer(function()
			if not novoCarro.Parent then
				return
			end
			for _ = 1, HEARTBEATS_ANTES_SUSPENSAO do
				RunService.Heartbeat:Wait()
				if not novoCarro.Parent then
					return
				end
			end
			aplicarSuspensaoSalvaComRetry(novoCarro, carroSave)
			for _ = 1, HEARTBEATS_ANTES_RODAS do
				RunService.Heartbeat:Wait()
			end
			if not novoCarro.Parent then
				return
			end
			task.wait(EXTRA_WAIT_SEG_ANTES_RODAS)
			if not novoCarro.Parent then
				return
			end
			aplicarRodasDoSave(novoCarro, carroSave)
			if carroTemRodasNaoPadrao(carroSave) then
				task.wait(REMOUNT_DELAY_RODAS_CUSTOM)
				if not novoCarro.Parent then
					return
				end
				aplicarRodasDoSave(novoCarro, carroSave)
			end
		end)
	else
		novoCarro:SetAttribute("Combustivel", 100)
	end

	if isAutoSpawn ~= true then
		task.defer(function()
			if not player.Parent then
				return
			end
			local alvoDoBeam = novoCarro.PrimaryPart
				or novoCarro:FindFirstChildWhichIsA("VehicleSeat", true)
				or novoCarro:FindFirstChildWhichIsA("BasePart", true)
			if alvoDoBeam then
				guiaEvent:FireClient(player, alvoDoBeam)
			end
		end)
		colocarJogadorNoCarroAposSpawn(player, novoCarro)
	end

	local rootPart = novoCarro:IsA("Model") and (novoCarro.PrimaryPart or novoCarro:FindFirstChildWhichIsA("BasePart", true))
		or (novoCarro:IsA("BasePart") and novoCarro)

	if rootPart then
		local donoId = player.UserId
		if not historicoDeCurtidas[donoId] then
			historicoDeCurtidas[donoId] = {}
		end
		if not historicoDeCurtidas[donoId][nomeDoCarro] then
			historicoDeCurtidas[donoId][nomeDoCarro] = {}
		end

		local bgui = Instance.new("BillboardGui")
		bgui.Name = "CarMeetUI"
		bgui.Size = UDim2.new(0, 150, 0, 50)
		bgui.StudsOffset = Vector3.new(0, 9, 0)
		bgui.AlwaysOnTop = true
		bgui.MaxDistance = 60
		bgui.Enabled = false
		bgui.Parent = rootPart

		local txtLike = Instance.new("TextLabel")
		txtLike.Size = UDim2.new(1, 0, 1, 0)
		txtLike.BackgroundTransparency = 1
		txtLike.Text = "🔥 0"
		txtLike.TextColor3 = Color3.fromRGB(255, 120, 0)
		txtLike.TextStrokeTransparency = 0
		txtLike.Font = Enum.Font.GothamBlack
		txtLike.TextSize = 35
		txtLike.Parent = bgui

		local promptVoto = Instance.new("ProximityPrompt")
		promptVoto.Name = "PromptVoto"
		promptVoto.ActionText = "🔥 Avaliar Nave"
		promptVoto.ObjectText = "Dono(a): " .. player.Name
		promptVoto.KeyboardKeyCode = Enum.KeyCode.F
		promptVoto.HoldDuration = 0.5
		promptVoto.MaxActivationDistance = 15
		promptVoto.RequiresLineOfSight = false
		promptVoto.Enabled = false
		promptVoto.UIOffset = Vector2.new(0, -30)
		promptVoto.Parent = rootPart

		local likesDataFolder = player:FindFirstChild("LikesData")
		local valorLikeDesteCarro = nil
		if likesDataFolder then
			valorLikeDesteCarro = likesDataFolder:FindFirstChild(nomeDoCarro)
			if not valorLikeDesteCarro then
				valorLikeDesteCarro = Instance.new("IntValue")
				valorLikeDesteCarro.Name = nomeDoCarro
				valorLikeDesteCarro.Value = 0
				valorLikeDesteCarro.Parent = likesDataFolder
			end
		end

		if valorLikeDesteCarro then
			txtLike.Text = "🔥 " .. valorLikeDesteCarro.Value
		end

		promptVoto.Triggered:Connect(function(playerQueCurtiu)
			if typeof(playerQueCurtiu) ~= "Instance" or not playerQueCurtiu:IsA("Player") then
				return
			end
			if playerQueCurtiu.UserId == player.UserId then
				return
			end

			local histCarro = historicoDeCurtidas[donoId][nomeDoCarro]
			if histCarro[playerQueCurtiu.UserId] then
				return
			end
			histCarro[playerQueCurtiu.UserId] = true

			if valorLikeDesteCarro then
				valorLikeDesteCarro.Value = valorLikeDesteCarro.Value + 1
			end

			local leaderDono = player:FindFirstChild("leaderstats")
			if leaderDono then
				local likesGlobal = leaderDono:FindFirstChild("Likes")
				if likesGlobal and likesGlobal:IsA("IntValue") then
					likesGlobal.Value = likesGlobal.Value + 1
				end
				local xpDono = leaderDono:FindFirstChild("XP")
				local granaDono = leaderDono:FindFirstChild("Dinheiro")
				if xpDono and xpDono:IsA("IntValue") then
					xpDono.Value = xpDono.Value + 25
				end
				if granaDono and granaDono:IsA("IntValue") then
					granaDono.Value = granaDono.Value + 100
				end
			end

			txtLike.TextColor3 = Color3.fromRGB(0, 255, 100)
			task.delay(0.5, function()
				if txtLike.Parent then
					txtLike.TextColor3 = Color3.fromRGB(255, 120, 0)
				end
			end)
		end)
	end

	pcall(function()
		modeloBaixado:Destroy()
	end)
	return true
end

spawnarEvento.OnServerEvent:Connect(function(player, nomeDoCarro, localSpawn, isAutoSpawn)
	local vagaLivre = nil

	if type(localSpawn) == "string" and localSpawn == SPAWN_CASA then
		local lotes = Workspace:FindFirstChild("LotesDasCasas")
		local casaDoPlayer = nil
		if lotes then
			for _, lote in ipairs(lotes:GetChildren()) do
				if lote:GetAttribute("Dono") == player.Name then
					casaDoPlayer = lote:FindFirstChild("CasaDo_" .. player.Name)
					break
				end
			end
		end
		if casaDoPlayer then
			vagaLivre = casaDoPlayer:FindFirstChild("PontoSpawnCarro", true)
		end
	else
		vagaLivre = encontrarVagaLivre()
	end

	local cfSpawn = cframeDePonto(vagaLivre)
	if not cfSpawn then
		return
	end

	spawnarVeiculoNaCFrameGaragem(player, nomeDoCarro, cfSpawn, isAutoSpawn, nil)
end)

do
	local bf = ServerStorage:FindFirstChild("GuinchoRespawnVeiculoBindable")
	if not bf or not bf:IsA("BindableFunction") then
		bf = Instance.new("BindableFunction")
		bf.Name = "GuinchoRespawnVeiculoBindable"
		bf.Parent = ServerStorage
	end
	bf.OnInvoke = function(player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return false, "invalid"
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			return false, "nochr"
		end
		local nomeCarroWs = player.Name .. "sCar"
		local veiculo = Workspace:FindFirstChild(nomeCarroWs)
		if not veiculo or (not veiculo:IsA("Model") and not veiculo:IsA("BasePart")) then
			return false, "noveh"
		end
		local nomeDoCarro = veiculo:GetAttribute("ModeloOriginal")
		if type(nomeDoCarro) ~= "string" or nomeDoCarro == "" then
			return false, "nomodel"
		end
		local DIST_FRENTE = 14
		local ALT_EXTRA = 2
		local look = hrp.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude < 0.1 then
			flatLook = Vector3.new(0, 0, -1)
		else
			flatLook = flatLook.Unit
		end
		local pos = hrp.Position + flatLook * DIST_FRENTE + Vector3.new(0, ALT_EXTRA, 0)
		local cfSpawn = CFrame.lookAt(pos, pos + flatLook)
		local ok = spawnarVeiculoNaCFrameGaragem(player, nomeDoCarro, cfSpawn, true, { skipDebounce = true })
		return ok, ok and "ok" or "spawnfail"
	end
end

local evToggleCarMeet = ReplicatedStorage:FindFirstChild("ToggleCarMeetEvent")
if not evToggleCarMeet then
	evToggleCarMeet = Instance.new("RemoteEvent")
	evToggleCarMeet.Name = "ToggleCarMeetEvent"
	evToggleCarMeet.Parent = ReplicatedStorage
elseif not evToggleCarMeet:IsA("RemoteEvent") then
	warn("[CentralVeiculos] ToggleCarMeetEvent existe mas não é RemoteEvent.")
	evToggleCarMeet = nil
end

if evToggleCarMeet then
	evToggleCarMeet.OnServerEvent:Connect(function(player, estadoAtivado)
		local ativo = estadoAtivado == true
		local carroDoPlayer = Workspace:FindFirstChild(player.Name .. "sCar")
		if not carroDoPlayer then
			return
		end
		local rootPart = carroDoPlayer:IsA("Model") and (carroDoPlayer.PrimaryPart or carroDoPlayer:FindFirstChildWhichIsA("BasePart", true))
			or (carroDoPlayer:IsA("BasePart") and carroDoPlayer)
		if not rootPart then
			return
		end
		local carMeetUI = rootPart:FindFirstChild("CarMeetUI")
		local promptVoto = rootPart:FindFirstChild("PromptVoto")
		if carMeetUI then
			carMeetUI.Enabled = ativo
		end
		if promptVoto then
			promptVoto.Enabled = ativo
		end
	end)
end
