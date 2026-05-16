-- CH Corporations - Guincho (celular): respawn completo do veículo à frente do jogador (via CentralVeiculosGaragem).
-- Colocar em ServerScriptService. Cria em ReplicatedStorage: GuinchoAssistenciaEvent (RemoteEvent).
-- Requer CentralVeiculosGaragem_REVISADO.lua (cria ServerStorage.GuinchoRespawnVeiculoBindable).

print("CH Corporations - Sistema Guincho (revisão)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local COOLDOWN_SEG = 45
local ATRASO_ENTREGA_SEG = 4
local WAIT_BINDABLE_SEG = 20

local guinchoEvent = ReplicatedStorage:FindFirstChild("GuinchoAssistenciaEvent")
if not guinchoEvent then
	guinchoEvent = Instance.new("RemoteEvent")
	guinchoEvent.Name = "GuinchoAssistenciaEvent"
	guinchoEvent.Parent = ReplicatedStorage
end

local ultimoUso = {}

local function nomeCarroDoDono(player)
	return player.Name .. "sCar"
end

local function mensagemParaMotivo(ok, motivo)
	if ok then
		return true, "Veículo respawnado à tua frente (estado da garagem)."
	end
	if motivo == "nochr" then
		return false, "Entrega cancelada (personagem)."
	end
	if motivo == "noveh" then
		return false, "O veículo já não está no mapa."
	end
	if motivo == "nomodel" then
		return false, "Dados do veículo em falta. Guarda e spawna de novo na garagem."
	end
	if motivo == "spawnfail" then
		return false, "Não foi possível respawnar o veículo. Tenta na garagem."
	end
	return false, "Não foi possível completar o guincho."
end

guinchoEvent.OnServerEvent:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local agora = os.clock()
	local uid = player.UserId
	if ultimoUso[uid] and (agora - ultimoUso[uid]) < COOLDOWN_SEG then
		local restam = math.ceil(COOLDOWN_SEG - (agora - ultimoUso[uid]))
		guinchoEvent:FireClient(player, "recusado", "Aguarde " .. tostring(restam) .. "s para chamar de novo.")
		return
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		guinchoEvent:FireClient(player, "recusado", "Personagem indisponível.")
		return
	end

	local nomeCarro = nomeCarroDoDono(player)
	local veiculo = Workspace:FindFirstChild(nomeCarro)
	if not veiculo or (not veiculo:IsA("Model") and not veiculo:IsA("BasePart")) then
		guinchoEvent:FireClient(player, "recusado", "Nenhum veículo teu na rua. Spawna um na garagem primeiro.")
		return
	end

	ultimoUso[uid] = agora
	guinchoEvent:FireClient(player, "aceito", "Guincho a caminho…")

	task.delay(ATRASO_ENTREGA_SEG, function()
		if not player.Parent then
			return
		end
		local bf = ServerStorage:WaitForChild("GuinchoRespawnVeiculoBindable", WAIT_BINDABLE_SEG)
		if not bf or not bf:IsA("BindableFunction") then
			guinchoEvent:FireClient(
				player,
				"recusado",
				"Guincho indisponível: confirma que CentralVeiculosGaragem está no servidor."
			)
			return
		end
		local invokeOk, ok, motivo = pcall(function()
			return bf:Invoke(player)
		end)
		if not invokeOk then
			warn("[Guincho] GuinchoRespawnVeiculoBindable: ", ok)
			guinchoEvent:FireClient(player, "recusado", "Erro interno ao respawnar o veículo.")
			return
		end
		local entregue, texto = mensagemParaMotivo(ok, motivo)
		if entregue then
			guinchoEvent:FireClient(player, "entregue", texto)
		else
			guinchoEvent:FireClient(player, "recusado", texto)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	ultimoUso[player.UserId] = nil
end)
