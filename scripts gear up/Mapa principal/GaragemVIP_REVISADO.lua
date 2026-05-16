-- CH Corporations - Garagem VIP (servidor) — Script filho do ProximityPrompt
-- Revisão: valida ProximityPrompt; AbrirMenuGaragemEvent com timeout + IsA; staff por nome + UserId;
--          VipSalvo só StringValue; gamepasses num único pcall em cadeia; FireClient e Prompt com pcall;
--          intrusos com warn (sem spam de print).

print("CH Corporations - Garagem VIP (VipSalvo + gamepasses — revisão)")

local prompt = script.Parent
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_TIMEOUT = 60

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

if not prompt:IsA("ProximityPrompt") then
	warn("[GaragemVIP] script.Parent deve ser um ProximityPrompt.")
	return
end

local abrirMenuGaragem = ReplicatedStorage:WaitForChild("AbrirMenuGaragemEvent", REMOTE_TIMEOUT)
if not abrirMenuGaragem or not abrirMenuGaragem:IsA("RemoteEvent") then
	warn("[GaragemVIP] AbrirMenuGaragemEvent em falta ou inválido — script desativado.")
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
		warn("[GaragemVIP] UserOwnsGamePassAsync falhou para", uid)
		return false
	end
	return resultado == true
end

prompt.Triggered:Connect(function(player)
	if not player or not player:IsA("Player") then
		return
	end

	local nomeEsperado = "CasaDo_" .. player.Name
	local taNaPropriaCasa = prompt:FindFirstAncestor(nomeEsperado)
	if not taNaPropriaCasa then
		warn("[GaragemVIP]", player.Name, "tentou usar garagem VIP fora da própria casa.")
		return
	end

	local temAcesso = WHITELIST_USER_IDS[player.UserId] == true or WHITELIST_NAMES[player.Name] == true

	if not temAcesso then
		local vipSalvo = player:FindFirstChild("VipSalvo")
		if vipSalvo and vipSalvo:IsA("StringValue") then
			local v = vipSalvo.Value
			if v ~= "Comum" and v ~= "" then
				temAcesso = true
			end
		end
	end

	if not temAcesso then
		temAcesso = jogadorTemAlgumGamePass(player.UserId)
	end

	if temAcesso then
		local ok, err = pcall(function()
			abrirMenuGaragem:FireClient(player, "Casa")
		end)
		if not ok then
			warn("[GaragemVIP] FireClient falhou:", err)
		end
	else
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, ID_BRONZE)
		end)
		if not ok then
			warn("[GaragemVIP] PromptGamePassPurchase falhou:", err)
		end
	end
end)
