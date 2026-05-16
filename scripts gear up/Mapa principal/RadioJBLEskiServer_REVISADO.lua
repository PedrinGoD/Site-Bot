-- CH Corporations - Rádio JBLEski (servidor) — Script no Part que usa o prompt
-- Revisão: ProximityPrompt/Som/Sound com timeout; RemoteEvent garantido; staff + VipSalvo + gamepasses;
--          OnServerEvent valida jogador e modelo; Play sanitiza asset id; Loaded com timeout; Volume/Seek clamp;
--          AddPlaylist/RemovePlaylist com tipos seguros; FireClient e Prompt com pcall.

print("CH Corporations - Rádio JBLEski servidor (VipSalvo + gamepasses — revisão)")

local partUsar = script.Parent
local WAIT_INST = 30

local prompt = partUsar:WaitForChild("ProximityPrompt", WAIT_INST)
if not prompt or not prompt:IsA("ProximityPrompt") then
	warn("[JBLEskiSrv] ProximityPrompt em falta — script desativado.")
	return
end

local modelJbleski = partUsar.Parent
if not modelJbleski or not modelJbleski:IsA("Model") then
	warn("[JBLEskiSrv] Parent do part não é um Model — script desativado.")
	return
end

local partSom = modelJbleski:WaitForChild("Som", WAIT_INST)
if not partSom or not partSom:IsA("BasePart") then
	warn("[JBLEskiSrv] Som (BasePart) em falta — script desativado.")
	return
end

local sound = partSom:WaitForChild("Sound", WAIT_INST)
if not sound or not sound:IsA("Sound") then
	warn("[JBLEskiSrv] Sound em falta — script desativado.")
	return
end

sound.RollOffMode = Enum.RollOffMode.InverseTapered

local CONFIG = {
	VOL_MIN = 0.5,
	VOL_MAX = 3.0,
	DIST_MIN = 40,
	DIST_MAX = 150,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local ID_BRONZE = 1737108751
local ID_GOLD = 1746268685
local ID_DIAMANTE = 1746862603
local GAMEPASSES_VIP = { ID_DIAMANTE, ID_GOLD, ID_BRONZE }

local WHITELIST_NAMES = {
	CheechSC = true,
	DDdaZZ26 = true,
}

local WHITELIST_USER_IDS = {
	-- [userId] = true,
}

local NOME_MUSICA_MAX = 200
local SOUND_LOAD_TIMEOUT = 15

local radioEvent = ReplicatedStorage:FindFirstChild("RadioJBLEskiEvent")
if not radioEvent then
	radioEvent = Instance.new("RemoteEvent")
	radioEvent.Name = "RadioJBLEskiEvent"
	radioEvent.Parent = ReplicatedStorage
end
if not radioEvent:IsA("RemoteEvent") then
	warn("[JBLEskiSrv] RadioJBLEskiEvent existe mas não é RemoteEvent.")
	return
end

local function jogadorTemAlgumGamePass(uid)
	local ok, resultado = pcall(function()
		for _, passId in ipairs(GAMEPASSES_VIP) do
			if MarketplaceService:UserOwnsGamePassAsync(uid, passId) then
				return true
			end
		end
		return false
	end)
	if not ok then
		warn("[JBLEskiSrv] UserOwnsGamePassAsync falhou para", uid)
		return false
	end
	return resultado == true
end

local function temAcessoRadio(player)
	if WHITELIST_USER_IDS[player.UserId] then
		return true
	end
	if WHITELIST_NAMES[player.Name] then
		return true
	end
	local vipSalvo = player:FindFirstChild("VipSalvo")
	if vipSalvo and vipSalvo:IsA("StringValue") then
		local v = vipSalvo.Value
		if v ~= "Comum" and v ~= "" then
			return true
		end
	end
	return jogadorTemAlgumGamePass(player.UserId)
end

prompt.Triggered:Connect(function(player)
	if not player or not player:IsA("Player") then
		return
	end

	if temAcessoRadio(player) then
		local ok, err = pcall(function()
			radioEvent:FireClient(player, "AbrirMenu", modelJbleski)
		end)
		if not ok then
			warn("[JBLEskiSrv] FireClient falhou:", err)
		end
	else
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, ID_BRONZE)
		end)
		if not ok then
			warn("[JBLEskiSrv] PromptGamePassPurchase falhou:", err)
		end
	end
end)

local function sanitizarAssetId(valor)
	local n = tonumber(valor)
	if not n then
		return nil
	end
	n = math.floor(n)
	if n < 1 or n > 1e20 then
		return nil
	end
	return n
end

local function esperarSoundCarregar()
	local t0 = os.clock()
	while not sound.IsLoaded and sound.Parent and (os.clock() - t0) < SOUND_LOAD_TIMEOUT do
		task.wait(0.1)
	end
	return sound.IsLoaded
end

radioEvent.OnServerEvent:Connect(function(player, acao, alvoModel, valor, extra)
	if not player or not player:IsA("Player") then
		return
	end
	if alvoModel ~= modelJbleski then
		return
	end
	if type(acao) ~= "string" then
		return
	end

	if acao == "Play" then
		local id = sanitizarAssetId(valor)
		if not id then
			return
		end
		local ok, err = pcall(function()
			sound.SoundId = "rbxassetid://" .. tostring(id)
			sound.Looped = false
			if not esperarSoundCarregar() then
				return
			end
			sound.TimePosition = 0
			sound:Play()
		end)
		if not ok then
			warn("[JBLEskiSrv] Play falhou:", err)
		end

	elseif acao == "Pause" then
		pcall(function()
			sound:Pause()
		end)

	elseif acao == "Resume" then
		pcall(function()
			sound:Resume()
		end)

	elseif acao == "Stop" then
		pcall(function()
			sound:Stop()
		end)

	elseif acao == "Seek" then
		local tempoDesejado = tonumber(valor) or 0
		tempoDesejado = math.max(0, tempoDesejado)
		pcall(function()
			local len = sound.TimeLength
			if len > 0 and tempoDesejado <= len then
				sound.TimePosition = tempoDesejado
			end
		end)

	elseif acao == "Volume" then
		local vol = tonumber(valor) or CONFIG.VOL_MIN
		vol = math.clamp(vol, CONFIG.VOL_MIN, CONFIG.VOL_MAX)
		pcall(function()
			sound.Volume = vol
			local porcentagem = (vol - CONFIG.VOL_MIN) / (CONFIG.VOL_MAX - CONFIG.VOL_MIN)
			local distanciaReal = CONFIG.DIST_MIN + (porcentagem * (CONFIG.DIST_MAX - CONFIG.DIST_MIN))
			sound.RollOffMaxDistance = distanciaReal
		end)

	elseif acao == "AddPlaylist" then
		local idStr = tostring(valor or "")
		if idStr == "" or #idStr > 32 then
			return
		end
		local nome = tostring(extra or "Música")
		if #nome > NOME_MUSICA_MAX then
			nome = string.sub(nome, 1, NOME_MUSICA_MAX)
		end
		local playlistData = player:FindFirstChild("PlaylistData")
		if not playlistData then
			return
		end
		if playlistData:FindFirstChild(idStr) then
			return
		end
		local novaMusica = Instance.new("StringValue")
		novaMusica.Name = idStr
		novaMusica.Value = nome
		novaMusica.Parent = playlistData

	elseif acao == "RemovePlaylist" then
		local idStr = tostring(valor or "")
		if idStr == "" then
			return
		end
		local playlistData = player:FindFirstChild("PlaylistData")
		if not playlistData then
			return
		end
		local musica = playlistData:FindFirstChild(idStr)
		if musica then
			musica:Destroy()
		end
	end
end)
