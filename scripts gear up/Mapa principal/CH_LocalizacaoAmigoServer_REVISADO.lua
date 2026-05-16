-- CH Corporations - Partilha de localização entre amigos (servidor)
-- Colocar em ServerScriptService (ou pasta de scripts servidor).
-- Cria o RemoteEvent CH_LocalizacaoAmigoEvent em ReplicatedStorage se não existir.
-- Cliente: CH_OS_Smartphone_REVISADO.lua — app «Amigos» (📍).
-- Validação: posição lida no servidor (HumanoidRootPart); só envia se sender:IsFriendsWith(alvo.UserId).

print("CH Corporations - Localização amigos servidor (RemoteEvent + amizade Roblox)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ev = ReplicatedStorage:FindFirstChild("CH_LocalizacaoAmigoEvent")
if not ev then
	ev = Instance.new("RemoteEvent")
	ev.Name = "CH_LocalizacaoAmigoEvent"
	ev.Parent = ReplicatedStorage
end

if not ev:IsA("RemoteEvent") then
	warn("[LocAmigoSrv] CH_LocalizacaoAmigoEvent existe mas não é RemoteEvent — abortado.")
	return
end

local COOLDOWN_SEC = 22
local lastSend = {}

ev.OnServerEvent:Connect(function(sender, acao, targetUserId)
	if type(acao) ~= "string" or acao ~= "enviar" then
		return
	end
	if type(targetUserId) ~= "number" then
		return
	end

	local now = os.clock()
	if (lastSend[sender.UserId] or 0) > now then
		return
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == sender then
		return
	end

	local okF, amigos = pcall(function()
		return sender:IsFriendsWith(target.UserId)
	end)
	if not okF or not amigos then
		return
	end

	local char = sender.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end

	local pos = hrp.Position
	lastSend[sender.UserId] = now + COOLDOWN_SEC

	ev:FireClient(target, sender.DisplayName, sender.UserId, pos.X, pos.Y, pos.Z)
end)
