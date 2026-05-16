-- CH Corporations - Sistema Anti-Invasão (barreiras locais por casa) — LocalScript
-- Revisão: LotesDasCasas com timeout + aviso; novos lotes no folder passam a ser vigiados;
--          sem duplicar AttributeChanged por casa nem ChildAdded por lote; string.find sem regex;
--          barreira Part/MeshPart ou Model (colisão em todos os BaseParts); pcall em CanCollide;
--          staff por nome e opcionalmente por UserId.

print("CH Corporations - Sistema Anti-Invasão (barreiras locais — revisão)")

local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")

local WAIT_LOTES = 60

local player = Players.LocalPlayer

-- Staff por nome (como no original)
local WHITELIST_NAMES = {
	CheechSC = true,
	DDdaZZ26 = true,
}

-- Acrescenta UserIds de staff aqui (mais seguro que só o nome)
local WHITELIST_USER_IDS = {
	-- [123456789] = true,
}

local lotesDasCasas = workspace:WaitForChild("LotesDasCasas", WAIT_LOTES)
if not lotesDasCasas then
	warn("[AntiInvasão] LotesDasCasas não encontrado em", WAIT_LOTES, "s — script desativado.")
	return
end

local casasMonitoradas = setmetatable({}, { __mode = "k" })
local lotesRegistados = setmetatable({}, { __mode = "k" })

local function temPermissao(casa)
	if WHITELIST_USER_IDS[player.UserId] then
		return true
	end
	if WHITELIST_NAMES[player.Name] then
		return true
	end
	if casa.Name == "CasaDo_" .. player.Name then
		return true
	end
	if casa:GetAttribute("Dono") == player.Name then
		return true
	end
	return false
end

local function definirColisaoBarreira(barreira, colidir)
	local function um(inst)
		if inst:IsA("BasePart") then
			local ok, err = pcall(function()
				inst.CanCollide = colidir
			end)
			if not ok then
				warn("[AntiInvasão] CanCollide falhou:", err)
			end
		end
	end

	if barreira:IsA("BasePart") then
		um(barreira)
	elseif barreira:IsA("Model") then
		for _, d in ipairs(barreira:GetDescendants()) do
			um(d)
		end
	end
end

local function atualizarBarreira(casa)
	local barreira = casa:FindFirstChild("BarreiraInvisivel", true)
	if not barreira then
		return
	end

	local estaTrancada = casa:GetAttribute("Trancada")

	if estaTrancada then
		if temPermissao(casa) then
			definirColisaoBarreira(barreira, false)
		else
			definirColisaoBarreira(barreira, true)
		end
	else
		definirColisaoBarreira(barreira, false)
	end
end

local function eCasaRelevante(casa)
	if not casa:IsA("Model") then
		return false
	end
	if casa.Name == "CasaBase" then
		return true
	end
	return string.find(casa.Name, "CasaDo_", 1, true) ~= nil
end

local function monitorarCasa(casa)
	if not eCasaRelevante(casa) then
		return
	end
	if casasMonitoradas[casa] then
		return
	end
	casasMonitoradas[casa] = true

	atualizarBarreira(casa)

	casa:GetAttributeChangedSignal("Trancada"):Connect(function()
		atualizarBarreira(casa)
	end)

	casa.DescendantAdded:Connect(function(desc)
		if desc.Name == "BarreiraInvisivel" then
			atualizarBarreira(casa)
		end
	end)
end

local function registarLote(lote)
	if lotesRegistados[lote] then
		return
	end
	lotesRegistados[lote] = true

	for _, obj in ipairs(lote:GetChildren()) do
		monitorarCasa(obj)
	end

	lote.ChildAdded:Connect(monitorarCasa)
end

for _, lote in ipairs(lotesDasCasas:GetChildren()) do
	registarLote(lote)
end

lotesDasCasas.ChildAdded:Connect(registarLote)
