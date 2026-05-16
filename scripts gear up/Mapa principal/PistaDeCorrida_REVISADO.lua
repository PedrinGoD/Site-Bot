-- Pista de Corrida - Spawn do veículo vindo do teleporte (lobby)
-- Revisão: um spawn por sessão de corrida (desliga CharacterAdded após sucesso); espera por HumanoidRootPart;
--          remove carro antigo no mapa; RegistroDeCarros com timeout; validação do TeleportData.

print("🏁 Pista de Corrida - Aguardando Pilotos...")

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local carrosSalvos = ServerStorage:WaitForChild("RegistroDeCarros", 120)
if not carrosSalvos then
	warn("[PistaCorrida] RegistroDeCarros não encontrado no ServerStorage.")
end

local function obterDadosCarroDoTeleporte(player)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if not teleportData then
		return nil
	end
	local bloco = teleportData[tostring(player.UserId)]
	if type(bloco) ~= "table" then
		return nil
	end
	local nome = bloco.Carro
	if type(nome) ~= "string" or nome == "" then
		return nil
	end
	return nome
end

local function destruirCarroDoJogadorNoMapa(player)
	local nomeInstancia = player.Name .. "sCar"
	local existente = Workspace:FindFirstChild(nomeInstancia)
	if existente then
		pcall(function()
			existente:Destroy()
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	if not carrosSalvos then
		return
	end

	local nomeDoCarro = obterDadosCarroDoTeleporte(player)
	if not nomeDoCarro then
		return
	end

	if nomeDoCarro == "Nenhum" then
		warn("⚠️ " .. player.Name .. " viajou sem ter um carro spawnado no lobby!")
		return
	end

	print("🏎️ " .. player.Name .. " chegou para correr com o carro: " .. nomeDoCarro)

	local modeloCarro = carrosSalvos:FindFirstChild(nomeDoCarro)
	if not modeloCarro then
		warn("[PistaCorrida] Modelo '" .. nomeDoCarro .. "' não existe em RegistroDeCarros.")
		return
	end

	local function spawnarCarroNaPista(character)
		if player:GetAttribute("PistaCarSpawnFeito") then
			return
		end
		if player:GetAttribute("_PistaSpawning") then
			return
		end
		player:SetAttribute("_PistaSpawning", true)

		local root = character:WaitForChild("HumanoidRootPart", 15)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			player:SetAttribute("_PistaSpawning", nil)
			return
		end

		task.wait(0.35)

		if player:GetAttribute("PistaCarSpawnFeito") then
			player:SetAttribute("_PistaSpawning", nil)
			return
		end

		destruirCarroDoJogadorNoMapa(player)

		local novoCarro = modeloCarro:Clone()
		novoCarro.Name = player.Name .. "sCar"

		pcall(function()
			if novoCarro:IsA("Model") then
				if not novoCarro.PrimaryPart then
					novoCarro.PrimaryPart = novoCarro:FindFirstChildWhichIsA("BasePart", true)
				end
				novoCarro:PivotTo(root.CFrame * CFrame.new(0, 2, 0))
			elseif novoCarro:IsA("BasePart") then
				novoCarro.CFrame = root.CFrame * CFrame.new(0, 2, 0)
			end
		end)

		for _, p in ipairs(novoCarro:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
			end
		end

		novoCarro.Parent = Workspace

		local banco = novoCarro:FindFirstChildWhichIsA("VehicleSeat", true)
		if banco and humanoid.Parent == character and humanoid.Health > 0 then
			pcall(function()
				banco:Sit(humanoid)
			end)
			print("✅ Piloto " .. player.Name .. " posicionado no volante!")
		end

		player:SetAttribute("PistaCarSpawnFeito", true)
		player:SetAttribute("_PistaSpawning", nil)
	end

	local conexaoChar
	conexaoChar = player.CharacterAdded:Connect(function(character)
		spawnarCarroNaPista(character)
		if conexaoChar and player:GetAttribute("PistaCarSpawnFeito") then
			conexaoChar:Disconnect()
			conexaoChar = nil
		end
	end)

	if player.Character then
		task.defer(function()
			spawnarCarroNaPista(player.Character)
			if conexaoChar and player:GetAttribute("PistaCarSpawnFeito") then
				conexaoChar:Disconnect()
				conexaoChar = nil
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	player:SetAttribute("PistaCarSpawnFeito", nil)
	player:SetAttribute("_PistaSpawning", nil)
end)
