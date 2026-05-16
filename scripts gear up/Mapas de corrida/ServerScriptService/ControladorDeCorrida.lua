print("CH Corporations - Controlador de Corrida (Modo Burnout + Customização + Câmera Cinematográfica)")

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

-- Carros ativos na corrida não colidem entre si. Carros abandonados ficam em CH_RaceGhost: chão (Default) sim, outros pilotos atravessam.
local GRUPO_CARRO_CORRIDA = "CH_RaceVehicle"
local GRUPO_CARRO_FANTASMA = "CH_RaceGhost"
pcall(function()
	PhysicsService:RegisterCollisionGroup(GRUPO_CARRO_CORRIDA)
	PhysicsService:RegisterCollisionGroup(GRUPO_CARRO_FANTASMA)
	PhysicsService:CollisionGroupSetCollidable(GRUPO_CARRO_CORRIDA, GRUPO_CARRO_CORRIDA, false)
	PhysicsService:CollisionGroupSetCollidable(GRUPO_CARRO_FANTASMA, GRUPO_CARRO_CORRIDA, false)
	PhysicsService:CollisionGroupSetCollidable(GRUPO_CARRO_FANTASMA, GRUPO_CARRO_FANTASMA, false)
end)

--- Guarda CanCollide original por BasePart (restaurar ao voltar ao banco)
local colisaoSalvaPorCarro = setmetatable({}, { __mode = "k" })

local function aplicarGrupoColisaoVeiculoCorrida(modelo: Model)
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = GRUPO_CARRO_CORRIDA
		end
	end
end

local function registarESalvarColisaoOriginal(modelo: Model): { [BasePart]: boolean }
	local salvo: { [BasePart]: boolean } = {}
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("BasePart") then
			salvo[d] = d.CanCollide
		end
	end
	colisaoSalvaPorCarro[modelo] = salvo
	return salvo
end

local function carroSemCondutorFantasma(modelo: Model)
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = GRUPO_CARRO_FANTASMA
		end
	end
end

local function carroComCondutorRestaurarColisao(modelo: Model)
	local salvo = colisaoSalvaPorCarro[modelo]
	if not salvo then
		aplicarGrupoColisaoVeiculoCorrida(modelo)
		return
	end
	for parte, eraCol in pairs(salvo) do
		if parte.Parent then
			parte.CanCollide = eraCol
			parte.CollisionGroup = GRUPO_CARRO_CORRIDA
		end
	end
end

local fisicaCorridaSolta = false

-- ==========================================
-- 📡 EVENTOS DE COMUNICAÇÃO
-- ==========================================
local eventoEscolha = ReplicatedStorage:FindFirstChild("EscolherCarroCorrida")
if not eventoEscolha then
	eventoEscolha = Instance.new("RemoteEvent")
	eventoEscolha.Name = "EscolherCarroCorrida"
	eventoEscolha.Parent = ReplicatedStorage
end

local semaforoEvent = ReplicatedStorage:FindFirstChild("SemaforoEvent")
if not semaforoEvent then
	semaforoEvent = Instance.new("RemoteEvent")
	semaforoEvent.Name = "SemaforoEvent"
	semaforoEvent.Parent = ReplicatedStorage
end

local evFocarCamera = ReplicatedStorage:FindFirstChild("FocarCameraSpawnEvent")
if not evFocarCamera then
	evFocarCamera = Instance.new("RemoteEvent")
	evFocarCamera.Name = "FocarCameraSpawnEvent"
	evFocarCamera.Parent = ReplicatedStorage
end

local registroDeCarros = ServerStorage:WaitForChild("RegistroDeCarros")
local gridLargada = workspace:WaitForChild("GridLargada")
local rodasSalvas = ReplicatedStorage:WaitForChild("RodasSalvas")

--- Igual ScriptWL / JuizOlimpico: nome guardado pode ter espaços ou underscores vs pasta RodasSalvas
local function resolverModeloRodaNaPasta(nome: any): Instance?
	if type(nome) ~= "string" or nome == "" or nome == "Padrao" then
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

local function encontrarRegistroInventarioVeiculo(inventario: Instance?, nomeBruto: any): Instance?
	if not inventario or type(nomeBruto) ~= "string" or nomeBruto == "" then
		return nil
	end
	local comUnderscore = string.gsub(nomeBruto, " ", "_")
	local candidatos = { comUnderscore, nomeBruto, string.gsub(nomeBruto, "_", " ") }
	for _, nome in ipairs(candidatos) do
		local r = inventario:FindFirstChild(nome)
		if r and r:IsA("StringValue") then
			return r
		end
	end
	local lower = string.lower(comUnderscore)
	for _, ch in ipairs(inventario:GetChildren()) do
		if ch:IsA("StringValue") and string.lower(ch.Name) == lower then
			return ch
		end
	end
	return nil
end

local vagasOcupadas = {}
local jogadoresProntos = 0
local corridaIniciada = false

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local root = char:WaitForChild("HumanoidRootPart", 5)
		if root and not corridaIniciada then
			root.Anchored = true
		end
	end)
end)

eventoEscolha.OnServerEvent:Connect(function(player, nomeDoCarro)
	if player:GetAttribute("CarroEscolhido") then return end

	local vagaEscolhida = nil
	for i = 1, #gridLargada:GetChildren() do
		local vaga = gridLargada:FindFirstChild("Vaga" .. i)
		if vaga and not vagasOcupadas[vaga.Name] then
			vagaEscolhida = vaga
			break
		end
	end

	if not vagaEscolhida then
		warn("❌ Sem vagas no Grid!")
		return
	end

	print("⏳ Preparando o " .. nomeDoCarro .. " para " .. player.Name)

	local nomeFormatado = string.gsub(nomeDoCarro, " ", "_")
	local idDoCarro = registroDeCarros:GetAttribute(nomeFormatado)
	if not idDoCarro then
		idDoCarro = registroDeCarros:GetAttribute(nomeDoCarro)
	end
	if not idDoCarro then
		warn("❌ ID do carro não encontrado em RegistroDeCarros (atributo '" .. nomeFormatado .. "').")
		return
	end

	local assetId = tonumber(idDoCarro) or idDoCarro
	local sucesso, modeloBaixado = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not sucesso or not modeloBaixado then
		warn("❌ InsertService:LoadAsset falhou para " .. player.Name .. " (id " .. tostring(idDoCarro) .. ")")
		return
	end

	local novoCarro = modeloBaixado:GetChildren()[1]
	if not novoCarro then
		warn("❌ Asset sem modelo raiz (filho [1])")
		modeloBaixado:Destroy()
		return
	end

	vagasOcupadas[vagaEscolhida.Name] = true
	player:SetAttribute("CarroEscolhido", true)

	novoCarro.Name = player.Name .. "sCar"
	novoCarro:PivotTo(vagaEscolhida.CFrame * CFrame.new(0, 2, 0))
	novoCarro.Parent = workspace
	task.wait(1.5)

	local chassis = novoCarro:FindFirstChild("DriveSeat", true) or novoCarro:FindFirstChildWhichIsA("VehicleSeat", true)
	local rootPart = novoCarro.PrimaryPart or chassis

	if rootPart then
		local attCarro = Instance.new("Attachment", rootPart)
		attCarro.Name = "AttCarroGrid"
		local attVaga = Instance.new("Attachment", vagaEscolhida)
		attVaga.Name = "AttVagaGrid"
		attVaga.WorldCFrame = attCarro.WorldCFrame
		local travaPos = Instance.new("AlignPosition", rootPart)
		travaPos.Attachment0 = attCarro
		travaPos.Attachment1 = attVaga
		travaPos.RigidityEnabled = true
		travaPos.Name = "TravaPos"
		local travaOri = Instance.new("AlignOrientation", rootPart)
		travaOri.Attachment0 = attCarro
		travaOri.Attachment1 = attVaga
		travaOri.RigidityEnabled = true
		travaOri.Name = "TravaOri"
	end

	-- Customização: InventarioVeiculos (atributos) + fallback CarData
	local inventario = player:FindFirstChild("InventarioVeiculos")
	local recVeiculo = encontrarRegistroInventarioVeiculo(inventario, nomeDoCarro)
	local carData = player:FindFirstChild("CarData")

	local motorNivel = 0
	if recVeiculo then
		motorNivel = tonumber(recVeiculo:GetAttribute("MotorAtual")) or 0
	elseif carData then
		local motorValue = carData:FindFirstChild("MotorAtual")
		if motorValue and motorValue.Value > 0 then motorNivel = motorValue.Value end
	end
	if motorNivel > 0 then
		novoCarro:SetAttribute("NivelECU", motorNivel)
	end

	local suspNome = "Padrao"
	local pAltura, pRigidez, pAmortecimento = 2, 4500, 500
	if recVeiculo then
		suspNome = recVeiculo:GetAttribute("SuspensaoNome") or "Padrao"
		pAltura = tonumber(recVeiculo:GetAttribute("SuspensaoAltura")) or pAltura
		pRigidez = tonumber(recVeiculo:GetAttribute("SuspensaoRigidez")) or pRigidez
		pAmortecimento = tonumber(recVeiculo:GetAttribute("SuspensaoAmortecimento")) or pAmortecimento
	elseif carData then
		local suspValue = carData:FindFirstChild("SuspensaoAtual")
		if suspValue and suspValue.Value ~= "Padrao" then
			suspNome = suspValue.Value
			pAltura = suspValue:GetAttribute("Altura") or pAltura
			pRigidez = suspValue:GetAttribute("Rigidez") or pRigidez
			pAmortecimento = suspValue:GetAttribute("Amortecimento") or pAmortecimento
		end
	end
	if suspNome ~= "Padrao" then
		for _, obj in ipairs(novoCarro:GetDescendants()) do
			if obj:IsA("SpringConstraint") then
				obj.FreeLength = pAltura
				obj.Stiffness = pRigidez
				obj.Damping = pAmortecimento
			end
		end
	end

	local corStr = nil
	if recVeiculo then
		corStr = recVeiculo:GetAttribute("CorDoCarro")
	end
	if (not corStr or corStr == "") and carData then
		local corSalva = carData:FindFirstChild("CorDoCarro")
		if corSalva and corSalva:IsA("StringValue") then corStr = corSalva.Value end
	end
	if corStr and corStr ~= "" then
		local rgb = string.split(corStr, ",")
		if #rgb == 3 then
			local corRecuperada = Color3.fromRGB(tonumber(rgb[1]) or 0, tonumber(rgb[2]) or 0, tonumber(rgb[3]) or 0)
			for _, obj in ipairs(novoCarro:GetDescendants()) do
				if obj:IsA("BasePart") and obj.Name == "Paint" then
					obj.Color = corRecuperada
				end
			end
		end
	end

	local wheelsModel = novoCarro:FindFirstChild("Wheels")
	if wheelsModel then
		for _, pos in ipairs({ "FL", "FR", "RL", "RR" }) do
			local nomeRoda = nil
			if recVeiculo then
				nomeRoda = recVeiculo:GetAttribute(pos)
			end
			if (not nomeRoda or nomeRoda == "" or nomeRoda == "Padrao") and carData then
				local rv = carData:FindFirstChild(pos)
				if rv and rv:IsA("StringValue") then nomeRoda = rv.Value end
			end
			local rodaPart = wheelsModel:FindFirstChild(pos)
			if nomeRoda and rodaPart and nomeRoda ~= "Padrao" then
				local rodaOriginal = resolverModeloRodaNaPasta(nomeRoda)
				if rodaOriginal then
					local partsModel = rodaPart:FindFirstChild("Parts")
					if partsModel then
						for _, filho in ipairs(partsModel:GetChildren()) do filho:Destroy() end
						local novaRodaVisual = rodaOriginal:Clone()
						novaRodaVisual.Parent = partsModel
						novaRodaVisual:PivotTo(rodaPart.CFrame)
						for _, part in ipairs(novaRodaVisual:GetDescendants()) do
							if part:IsA("BasePart") then
								part.Anchored = false
								part.CanCollide = false
								part.Massless = true
								local solda = Instance.new("WeldConstraint", part)
								solda.Part0 = rodaPart
								solda.Part1 = part
							end
						end
					end
					local propsAtuais = rodaPart.CustomPhysicalProperties or PhysicalProperties.new(rodaPart.Material)
					rodaPart.CustomPhysicalProperties = PhysicalProperties.new(
						propsAtuais.Density,
						rodaOriginal:GetAttribute("Aderencia") or 0.7,
						propsAtuais.Elasticity,
						propsAtuais.FrictionWeight,
						propsAtuais.ElasticityWeight
					)
				end
			end
		end
	end

	aplicarGrupoColisaoVeiculoCorrida(novoCarro)
	registarESalvarColisaoOriginal(novoCarro)

	-- Menu/câmera no cliente: só depois da customização e com o carro já no mundo (evita perder o 1.º FireClient)
	evFocarCamera:FireClient(player, vagaEscolhida)

	-- Sentar + semáforo (sempre DENTRO do OnServerEvent)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	root.Anchored = false
	task.wait(0.5)
	if chassis and (chassis:IsA("VehicleSeat") or chassis:IsA("Seat")) then
		local function tentarRecolocarNoBanco()
			if not fisicaCorridaSolta or not chassis.Parent then
				return
			end
			local charAtual = player.Character
			local humAtual = charAtual and charAtual:FindFirstChildOfClass("Humanoid")
			if not humAtual or humAtual.Health <= 0 then
				carroSemCondutorFantasma(novoCarro)
				return
			end
			for _ = 1, 18 do
				if chassis.Occupant ~= nil then
					return
				end
				if not humAtual.Parent or humAtual.Health <= 0 then
					carroSemCondutorFantasma(novoCarro)
					return
				end
				pcall(function()
					chassis:Sit(humAtual)
				end)
				task.wait(0.04)
			end
			if chassis.Occupant == nil and humAtual.Parent and humAtual.Health > 0 and humAtual.RootPart and chassis:IsA("BasePart") then
				pcall(function()
					humAtual.RootPart.AssemblyLinearVelocity = Vector3.zero
					humAtual.RootPart.CFrame = chassis.CFrame * CFrame.new(0, 2.5, 0.5)
					chassis:Sit(humAtual)
				end)
			end
		end

		chassis:GetPropertyChangedSignal("Occupant"):Connect(function()
			if not fisicaCorridaSolta then
				return
			end
			if chassis.Occupant ~= nil then
				carroComCondutorRestaurarColisao(novoCarro)
				return
			end
			task.defer(tentarRecolocarNoBanco)
		end)

		humanoid.Died:Connect(function()
			task.defer(function()
				if novoCarro.Parent then
					carroSemCondutorFantasma(novoCarro)
				end
			end)
		end)
	end
	if chassis then chassis:Sit(humanoid) end
	modeloBaixado:Destroy()
	jogadoresProntos += 1
	print("✅ " .. jogadoresProntos .. "/" .. #Players:GetPlayers() .. " pilotos no Grid.")

	if jogadoresProntos >= #Players:GetPlayers() and not corridaIniciada then
		corridaIniciada = true
		task.spawn(function()
			task.wait(2)
			semaforoEvent:FireAllClients("3", Color3.fromRGB(255, 0, 0))
			task.wait(1)
			semaforoEvent:FireAllClients("2", Color3.fromRGB(255, 85, 0))
			task.wait(1)
			semaforoEvent:FireAllClients("1", Color3.fromRGB(255, 170, 0))
			task.wait(1)
			semaforoEvent:FireAllClients("GO!", Color3.fromRGB(85, 255, 127))
			fisicaCorridaSolta = true
			for _, desc in ipairs(workspace:GetDescendants()) do
				if desc.Name == "TravaPos" or desc.Name == "TravaOri" or desc.Name == "AttCarroGrid" or desc.Name == "AttVagaGrid" then
					desc:Destroy()
				end
			end
			task.wait(2)
			semaforoEvent:FireAllClients("", Color3.new())
		end)
	end
end)
