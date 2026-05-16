-- Luzes SpotLight01: ligadas à noite (ClockTime < 6 ou > 18), desligadas de dia.
-- Revisão: cache de instâncias (sem varrer o Workspace inteiro a cada tick); só atualiza quando dia/noite mudam;
--          regista novos descendentes; Workspace via GetService.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local NOME_LUZ = "SpotLight01"

local cache = {}
local ultimoENoite = nil

local function ePeriodoNoite(hora)
	return hora < 6 or hora > 18
end

local function adicionarSeForAlvo(inst)
	if inst:IsA("SpotLight") and inst.Name == NOME_LUZ then
		table.insert(cache, inst)
		if ultimoENoite ~= nil then
			inst.Enabled = ultimoENoite
		end
	end
end

local function removerDaCache(inst)
	if not inst:IsA("SpotLight") or inst.Name ~= NOME_LUZ then
		return
	end
	for i = #cache, 1, -1 do
		if cache[i] == inst then
			table.remove(cache, i)
		end
	end
end

local function reconstruirCache()
	for i = #cache, 1, -1 do
		cache[i] = nil
	end
	for _, d in ipairs(Workspace:GetDescendants()) do
		adicionarSeForAlvo(d)
	end
end

local function atualizarLuzes()
	local hora = Lighting.ClockTime
	local eNoite = ePeriodoNoite(hora)
	if ultimoENoite == eNoite then
		return
	end
	ultimoENoite = eNoite

	for i = #cache, 1, -1 do
		local spot = cache[i]
		if spot.Parent then
			spot.Enabled = eNoite
		else
			table.remove(cache, i)
		end
	end
end

reconstruirCache()
ultimoENoite = ePeriodoNoite(Lighting.ClockTime)
for _, spot in ipairs(cache) do
	spot.Enabled = ultimoENoite
end

Workspace.DescendantAdded:Connect(adicionarSeForAlvo)
Workspace.DescendantRemoving:Connect(removerDaCache)

Lighting:GetPropertyChangedSignal("ClockTime"):Connect(atualizarLuzes)
