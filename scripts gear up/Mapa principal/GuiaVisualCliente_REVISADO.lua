-- CH Corporations - Guia visual (Beam laser até alvo) — LocalScript
-- Revisão: aceita Model (resolve BasePart); espera replicação do alvo; GuiaVisualEvent + timeout;
--          Character/HumanoidRootPart; limpa em CharacterRemoving; Heartbeat seguro ao desligar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local REMOTE_TIMEOUT = 60
local ROOT_TIMEOUT = 15
local DISTANCIA_DESLIGA = 8

local guiaEvent = ReplicatedStorage:WaitForChild("GuiaVisualEvent", REMOTE_TIMEOUT)
if not guiaEvent or not guiaEvent:IsA("RemoteEvent") then
	warn("[GuiaVisual] GuiaVisualEvent em falta ou inválido — script desativado.")
	return
end

local player = Players.LocalPlayer

local estado = {
	pasta = nil,
	attPlayer = nil,
	attAlvo = nil,
	heartbeat = nil,
	charConn = nil,
}

local function destruirSeguro(inst)
	if not inst then
		return
	end
	pcall(function()
		inst:Destroy()
	end)
end

local function limparGuia()
	if estado.heartbeat then
		estado.heartbeat:Disconnect()
		estado.heartbeat = nil
	end
	if estado.charConn then
		estado.charConn:Disconnect()
		estado.charConn = nil
	end

	destruirSeguro(estado.pasta)
	estado.pasta = nil

	destruirSeguro(estado.attPlayer)
	estado.attPlayer = nil

	destruirSeguro(estado.attAlvo)
	estado.attAlvo = nil

	print("[GuiaVisual] Laser desligado.")
end

local REPLICAR_TIMEOUT = 5

local function resolverParteAlvo(inst)
	if typeof(inst) ~= "Instance" then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		local p = inst.PrimaryPart
			or inst:FindFirstChildWhichIsA("VehicleSeat", true)
			or inst:FindFirstChildWhichIsA("BasePart", true)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

local function esperarAlvoReplicado(parte)
	local t0 = os.clock()
	while os.clock() - t0 < REPLICAR_TIMEOUT do
		if parte and parte.Parent and parte:IsDescendantOf(game) then
			return true
		end
		task.wait(0.08)
	end
	return parte ~= nil and parte:IsDescendantOf(game)
end

guiaEvent.OnClientEvent:Connect(function(alvoBruto)
	task.spawn(function()
		local alvo = resolverParteAlvo(alvoBruto)
		if not alvo then
			warn("[GuiaVisual] Alvo inválido (use BasePart ou Model com PrimaryPart/partes).")
			return
		end

		if not esperarAlvoReplicado(alvo) then
			warn("[GuiaVisual] Alvo ainda não replicou a tempo — guia cancelado.")
			return
		end

		limparGuia()

		local character = player.Character
		if not character or not character.Parent then
			character = player.CharacterAdded:Wait()
		end

		local rootPart = character:WaitForChild("HumanoidRootPart", ROOT_TIMEOUT)
		if not rootPart or not rootPart:IsA("BasePart") then
			warn("[GuiaVisual] HumanoidRootPart em falta — guia cancelado.")
			return
		end

		local pastaGuia = Instance.new("Folder")
		pastaGuia.Name = "GuiaAtivo"
		pastaGuia.Parent = character

		local att0 = Instance.new("Attachment")
		att0.Parent = rootPart

		local att1 = Instance.new("Attachment")
		att1.Parent = alvo

		local beam = Instance.new("Beam")
		beam.Attachment0 = att0
		beam.Attachment1 = att1
		beam.Color = ColorSequence.new(Color3.fromRGB(85, 255, 127))
		beam.LightEmission = 0
		beam.LightInfluence = 1
		beam.Texture = "rbxassetid://3371283711"
		beam.TextureLength = 20
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureSpeed = -5
		beam.FaceCamera = true
		beam.Width0 = 2
		beam.Width1 = 2
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = pastaGuia

		estado.pasta = pastaGuia
		estado.attPlayer = att0
		estado.attAlvo = att1

		estado.charConn = player.CharacterRemoving:Connect(function(removido)
			if removido == character then
				limparGuia()
			end
		end)

		print("[GuiaVisual] Laser ativo até o alvo.")

		estado.heartbeat = RunService.Heartbeat:Connect(function()
			if not alvo.Parent or not alvo:IsDescendantOf(game) then
				limparGuia()
				return
			end

			character = player.Character
			if not character or not character.Parent then
				limparGuia()
				return
			end

			rootPart = character:FindFirstChild("HumanoidRootPart")
			if not rootPart or not rootPart:IsA("BasePart") then
				limparGuia()
				return
			end

			local distancia = (rootPart.Position - alvo.Position).Magnitude
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local estaSentado = humanoid and humanoid.SeatPart ~= nil

			if distancia < DISTANCIA_DESLIGA or estaSentado then
				limparGuia()
			end
		end)
	end)
end)
