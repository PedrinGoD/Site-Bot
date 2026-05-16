-- CH CORPORATIONS - Salvar tamanho celular (servidor)
-- Revisão: RemoteEvent reutilizável; um único NumberValue por jogador; retries no DataStore;
--          cooldown + número finito; loop para jogadores já no servidor sem duplicar Value.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local tamanhoDataStore = DataStoreService:GetDataStore("CH_SmartphoneTamanhoDS_v1")

local TAMANHO_PADRAO = 1
local TAMANHO_MIN = 0.5
local TAMANHO_MAX = 1.5
local COOLDOWN_SALVAR = 0.5

local remoteAlterarTamanho = ReplicatedStorage:FindFirstChild("AlterarTamanhoCelularEvent")
if not remoteAlterarTamanho then
	remoteAlterarTamanho = Instance.new("RemoteEvent")
	remoteAlterarTamanho.Name = "AlterarTamanhoCelularEvent"
	remoteAlterarTamanho.Parent = ReplicatedStorage
end

local ultimoSalvar = {}

local function numeroFinito(n)
	return type(n) == "number" and n == n and math.abs(n) ~= math.huge
end

local function getAsyncComRetry(userKey)
	local valor = nil
	for tentativa = 1, 4 do
		local ok, result = pcall(function()
			return tamanhoDataStore:GetAsync(userKey)
		end)
		if ok then
			valor = result
			break
		end
		task.wait(tentativa * 0.5)
	end
	return valor
end

local function setAsyncComRetry(userKey, v)
	for tentativa = 1, 3 do
		local ok = pcall(function()
			tamanhoDataStore:SetAsync(userKey, v)
		end)
		if ok then
			return true
		end
		task.wait(1.2)
	end
	return false
end

local function obterOuCriarValue(player)
	local existente = player:FindFirstChild("TamanhoCelularValue")
	if existente and existente:IsA("NumberValue") then
		return existente
	end
	if existente then
		existente:Destroy()
	end
	local val = Instance.new("NumberValue")
	val.Name = "TamanhoCelularValue"
	val.Parent = player
	return val
end

local function onPlayerAdded(player)
	local userKey = tostring(player.UserId)
	local tamanhoSalvo = getAsyncComRetry(userKey)

	if not numeroFinito(tamanhoSalvo) then
		tamanhoSalvo = TAMANHO_PADRAO
	else
		tamanhoSalvo = math.clamp(tamanhoSalvo, TAMANHO_MIN, TAMANHO_MAX)
	end

	local valTamanho = obterOuCriarValue(player)
	valTamanho.Value = tamanhoSalvo
end

local function onPlayerRemoving(player)
	ultimoSalvar[player.UserId] = nil
	local valTamanho = player:FindFirstChild("TamanhoCelularValue")
	if valTamanho and valTamanho:IsA("NumberValue") and numeroFinito(valTamanho.Value) then
		setAsyncComRetry(tostring(player.UserId), math.clamp(valTamanho.Value, TAMANHO_MIN, TAMANHO_MAX))
	end
end

remoteAlterarTamanho.OnServerEvent:Connect(function(player, novoTamanho)
	if not numeroFinito(novoTamanho) then
		return
	end

	local n = math.clamp(novoTamanho, TAMANHO_MIN, TAMANHO_MAX)

	local agora = os.clock()
	local uid = player.UserId
	if ultimoSalvar[uid] and (agora - ultimoSalvar[uid]) < COOLDOWN_SALVAR then
		return
	end

	local valTamanho = player:FindFirstChild("TamanhoCelularValue")
	if not valTamanho or not valTamanho:IsA("NumberValue") then
		valTamanho = obterOuCriarValue(player)
	end

	valTamanho.Value = n
	ultimoSalvar[uid] = agora

	setAsyncComRetry(tostring(uid), n)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
