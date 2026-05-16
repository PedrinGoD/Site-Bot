-- CH Corporations - Gerenciador de NameTags VIP (TagPreferida + Gamepass)
-- Revisão: tags só de lista fechada; VIP na gaveta por tokens (vírgula), não substring;
--          um único listener em TagPreferida por jogador; WaitForChild com timeout;
--          limpeza em PlayerRemoving.

print("CH Corporations - Gerenciador de NameTags VIP (Atualizado: TagPreferida + Gamepass) Carregado")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local ID_BRONZE = 1737108751
local ID_GOLD = 1746268685
local ID_DIAMANTE = 1746862603

local TAGS_VALIDAS = {
	Comum = true,
	Bronze = true,
	Gold = true,
	Diamante = true,
}

local configVIP = {
	Diamante = { cor = Color3.fromRGB(0, 255, 255), icone = "rbxassetid://136874155469759" },
	Gold = { cor = Color3.fromRGB(255, 215, 0), icone = "rbxassetid://138965871941573" },
	Bronze = { cor = Color3.fromRGB(210, 105, 30), icone = "rbxassetid://70919802180942" },
	Comum = { cor = Color3.fromRGB(255, 255, 255), icone = "" },
}

local function listaVipsNaGaveta(vipSalvoStr)
	local t = {}
	if type(vipSalvoStr) ~= "string" or vipSalvoStr == "" then
		return t
	end
	for piece in string.gmatch(vipSalvoStr, "[^,]+") do
		local nivel = string.gsub(piece, "^%s*(.-)%s*$", "%1")
		if nivel ~= "" then
			t[nivel] = true
		end
	end
	return t
end

local function jogadorPodeUsarTag(player, novaTag)
	if novaTag == "Comum" then
		return true
	end

	local naGaveta = listaVipsNaGaveta(player:FindFirstChild("VipSalvo") and player.VipSalvo.Value or "")
	if naGaveta[novaTag] then
		return true
	end

	local ok, tem = pcall(function()
		if novaTag == "Diamante" then
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_DIAMANTE)
		elseif novaTag == "Gold" then
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_GOLD)
		elseif novaTag == "Bronze" then
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_BRONZE)
		end
		return false
	end)
	return ok and tem == true
end

local eventoAlterarVip = ReplicatedStorage:FindFirstChild("AlterarVipEvent")
if not eventoAlterarVip then
	eventoAlterarVip = Instance.new("RemoteEvent")
	eventoAlterarVip.Name = "AlterarVipEvent"
	eventoAlterarVip.Parent = ReplicatedStorage
end

eventoAlterarVip.OnServerEvent:Connect(function(player, novaTag)
	if type(novaTag) ~= "string" or not TAGS_VALIDAS[novaTag] then
		return
	end

	local tagPreferida = player:FindFirstChild("TagPreferida")
	local vipSalvo = player:FindFirstChild("VipSalvo")
	if not tagPreferida or not vipSalvo then
		return
	end

	if jogadorPodeUsarTag(player, novaTag) then
		tagPreferida.Value = novaTag
		print("✅ " .. player.Name .. " equipou a tag: " .. novaTag)
	else
		warn("⚠️ " .. player.Name .. " tentou equipar a tag '" .. novaTag .. "' sem ter o VIP!")
	end
end)

-- Um listener de TagPreferida por jogador (evita acumular a cada respawn)
local conexoesTagPreferida = {}

local function desligarListenerTag(player)
	local c = conexoesTagPreferida[player]
	if c then
		c:Disconnect()
		conexoesTagPreferida[player] = nil
	end
end

local function atualizarNametagDoJogador(player)
	local char = player.Character
	if not char then
		return
	end
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	local novaTagGui = head:FindFirstChild("NameTagVIP")
	if not novaTagGui or not novaTagGui:IsA("BillboardGui") then
		return
	end
	local frame = novaTagGui:FindFirstChild("Frame")
	if not frame then
		return
	end
	local txtNome = frame:FindFirstChild("Nome")
	local imgIcone = frame:FindFirstChild("Icone")
	if not txtNome or not imgIcone then
		return
	end

	txtNome.Text = player.DisplayName

	local tagPref = player:FindFirstChild("TagPreferida")
	local nivelVip = (tagPref and tagPref.Value ~= "") and tagPref.Value or "Comum"
	local config = configVIP[nivelVip] or configVIP.Comum

	txtNome.TextColor3 = config.cor

	if config.icone ~= "" then
		imgIcone.Image = config.icone
		imgIcone.Visible = true
	else
		imgIcone.Visible = false
	end
end

local function garantirListenerTagPreferida(player)
	if conexoesTagPreferida[player] then
		return
	end
	local tagPref = player:FindFirstChild("TagPreferida")
	if not tagPref then
		return
	end
	conexoesTagPreferida[player] = tagPref:GetPropertyChangedSignal("Value"):Connect(function()
		atualizarNametagDoJogador(player)
	end)
end

Players.PlayerAdded:Connect(function(player)
	if player:FindFirstChild("TagPreferida") then
		garantirListenerTagPreferida(player)
	end

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 15)
		local head = character:WaitForChild("Head", 15)
		if not humanoid or not head then
			return
		end

		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		local tagBase = ReplicatedStorage:WaitForChild("NameTagVIP", 30)
		if not tagBase then
			warn("[NameTagsVIP] NameTagVIP não encontrado no ReplicatedStorage.")
			return
		end

		local billboard = tagBase:Clone()
		billboard.Name = "NameTagVIP"
		billboard.Parent = head
		billboard.Adornee = head

		local frame = billboard:WaitForChild("Frame", 10)
		if not frame then
			billboard:Destroy()
			return
		end
		if not frame:FindFirstChild("Nome") or not frame:FindFirstChild("Icone") then
			billboard:Destroy()
			warn("[NameTagsVIP] Frame sem Nome/Icone.")
			return
		end

		garantirListenerTagPreferida(player)
		atualizarNametagDoJogador(player)
	end)

	player:GetPropertyChangedSignal("DisplayName"):Connect(function()
		atualizarNametagDoJogador(player)
	end)

	-- Se TagPreferida for criada depois (DataStore), liga o listener
	player.ChildAdded:Connect(function(child)
		if child.Name == "TagPreferida" then
			garantirListenerTagPreferida(player)
			atualizarNametagDoJogador(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	desligarListenerTag(player)
end)
