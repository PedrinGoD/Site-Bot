-- CH Corporations - Recebedor de Configs do CH-OS
-- Revisão: validação no servidor (tipo + valor); timeout no RemoteEvent; brilho limitado e numérico;
--          wallpaper só em formato rbxasset / rbxthumb / string curta.

print("CH Corporations - Recebedor de Configs do CH-OS iniciado")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local evConfigCelular = ReplicatedStorage:WaitForChild("SalvarConfigCelularEvent", 60)
if not evConfigCelular then
	warn("[CH-OS Config] SalvarConfigCelularEvent não encontrado no ReplicatedStorage.")
	return
end

local MAX_WALLPAPER_LEN = 200
local BRILHO_MIN = 0
local BRILHO_MAX = 2

local function wallpaperValido(s)
	if type(s) ~= "string" then
		return false
	end
	if #s > MAX_WALLPAPER_LEN then
		return false
	end
	-- Aceita ids oficiais Roblox e http(s) curto (se no futuro usares CDN)
	if string.match(s, "^rbxassetid://%d+$")
		or string.match(s, "^rbxasset://")
		or string.match(s, "^rbxthumb://")
	then
		return true
	end
	if string.match(s, "^https?://") and #s <= MAX_WALLPAPER_LEN then
		return true
	end
	return false
end

local ultimoSalvamento = {}
local COOLDOWN_SEG = 0.35

evConfigCelular.OnServerEvent:Connect(function(player, tipo, valor)
	if type(tipo) ~= "string" then
		return
	end

	local agora = os.clock()
	local uid = player.UserId
	if ultimoSalvamento[uid] and (agora - ultimoSalvamento[uid]) < COOLDOWN_SEG then
		return
	end

	if tipo == "Wallpaper" then
		if not wallpaperValido(valor) then
			return
		end
		local wallValue = player:FindFirstChild("WallpaperCelular")
		if wallValue and wallValue:IsA("StringValue") then
			wallValue.Value = valor
			ultimoSalvamento[uid] = agora
		end
	elseif tipo == "Brilho" then
		local n = tonumber(valor)
		if not n then
			return
		end
		n = math.clamp(n, BRILHO_MIN, BRILHO_MAX)
		local brilhoValue = player:FindFirstChild("BrilhoCelular")
		if brilhoValue and brilhoValue:IsA("NumberValue") then
			brilhoValue.Value = n
			ultimoSalvamento[uid] = agora
		end
	elseif tipo == "Tema" then
		if valor ~= "Claro" and valor ~= "Escuro" then
			return
		end
		local temaVal = player:FindFirstChild("TemaCHOS")
		if not temaVal then
			temaVal = Instance.new("StringValue")
			temaVal.Name = "TemaCHOS"
			temaVal.Parent = player
		end
		if temaVal:IsA("StringValue") then
			temaVal.Value = valor
			ultimoSalvamento[uid] = agora
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ultimoSalvamento[player.UserId] = nil
end)
