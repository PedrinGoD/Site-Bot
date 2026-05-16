-- CH Corporations - Sistema de Recompensas do Tutorial (Anti-Cheat)
-- Revisão: não acusa "hacker" se os dados ainda não existem; trava imediata para evitar duplo fire;
--          rollback se leaderstats incompleto; cooldown anti-spam; tipos validados.

print("CH Corporations - Sistema de Recompensas do Tutorial (Anti-Cheat Ativado)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RECOMPENSA_DINHEIRO = 5000
local RECOMPENSA_XP = 500
local COOLDOWN_SEG = 2

local recompensaEvent = ReplicatedStorage:FindFirstChild("TutorialRecompensaEvent")
if not recompensaEvent then
	recompensaEvent = Instance.new("RemoteEvent")
	recompensaEvent.Name = "TutorialRecompensaEvent"
	recompensaEvent.Parent = ReplicatedStorage
end

local ultimoPedido = {}

Players.PlayerRemoving:Connect(function(player)
	ultimoPedido[player.UserId] = nil
end)

recompensaEvent.OnServerEvent:Connect(function(player)
	local agora = os.clock()
	local uid = player.UserId
	if ultimoPedido[uid] and (agora - ultimoPedido[uid]) < COOLDOWN_SEG then
		return
	end
	ultimoPedido[uid] = agora

	local tutorialStatus = player:FindFirstChild("TutorialCompleto")
	if not tutorialStatus or not tutorialStatus:IsA("BoolValue") then
		return
	end

	if tutorialStatus.Value == true then
		warn("⛔ Tutorial: " .. player.Name .. " tentou reclamar recompensa já concluída.")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local dinheiro = leaderstats:FindFirstChild("Dinheiro")
	local xp = leaderstats:FindFirstChild("XP")
	if not dinheiro or not xp or not dinheiro:IsA("IntValue") or not xp:IsA("IntValue") then
		return
	end

	-- Trava antes de creditar (evita duas requisições lerem false no mesmo instante)
	tutorialStatus.Value = true

	dinheiro.Value = dinheiro.Value + RECOMPENSA_DINHEIRO
	xp.Value = xp.Value + RECOMPENSA_XP

	print("💰 Prêmio do Tutorial entregue com sucesso para: " .. player.Name)
end)
