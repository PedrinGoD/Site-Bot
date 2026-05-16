-- CH Corporations - Painel trancar/destrancar casa (servidor) — Script filho do ProximityPrompt
-- Revisão: valida ProximityPrompt; sobe hierarquia até Model CasaDo_* / CasaBase (nunca fica workspace);
--          Trancada default só em modelo válido; staff por hash + UserId opcional; string.find literal;
--          player e casa verificados no Triggered; prints reduzidos a warn em intrusão.

local prompt = script.Parent
local painel = prompt.Parent

local WHITELIST_NAMES = {
	CheechSC = true,
	NomeDoSeuAmigo = true,
}

local WHITELIST_USER_IDS = {
	-- [userId] = true,
}

if not prompt:IsA("ProximityPrompt") then
	warn("[PainelTranca] script.Parent deve ser um ProximityPrompt.")
	return
end

local function encontrarModeloCasa(aPartirDe)
	local cur = aPartirDe
	while cur and cur ~= game do
		if cur:IsA("Model") then
			if cur.Name == "CasaBase" or string.find(cur.Name, "CasaDo_", 1, true) then
				return cur
			end
		end
		cur = cur.Parent
	end
	return nil
end

local casa = encontrarModeloCasa(painel)
if not casa then
	warn("[PainelTranca] Não foi encontrado modelo CasaDo_* ou CasaBase acima do painel — script desativado.")
	return
end

if casa:GetAttribute("Trancada") == nil then
	casa:SetAttribute("Trancada", false)
end

local function atualizarTextoPrompt(trancada)
	if trancada then
		prompt.ActionText = "Destrancar Casa"
	else
		prompt.ActionText = "Trancar Casa"
	end
end

atualizarTextoPrompt(casa:GetAttribute("Trancada") == true)

local function temPermissao(player)
	if not player or not player:IsA("Player") then
		return false
	end
	if WHITELIST_USER_IDS[player.UserId] then
		return true
	end
	if WHITELIST_NAMES[player.Name] then
		return true
	end
	if casa:GetAttribute("Dono") == player.Name then
		return true
	end
	if string.find(casa.Name, "CasaDo_" .. player.Name, 1, true) then
		return true
	end
	return false
end

prompt.Triggered:Connect(function(player)
	if not player or not player:IsA("Player") then
		return
	end
	if not casa.Parent then
		warn("[PainelTranca] Modelo da casa foi removido.")
		return
	end

	if not temPermissao(player) then
		warn("[PainelTranca] Acesso negado:", player.Name)
		return
	end

	local estadoAtual = casa:GetAttribute("Trancada")
	local novoEstado = estadoAtual ~= true

	casa:SetAttribute("Trancada", novoEstado)
	atualizarTextoPrompt(novoEstado)
end)
