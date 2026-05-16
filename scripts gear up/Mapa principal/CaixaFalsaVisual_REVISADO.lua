-- CH Corporations - CaixaFalsaVisual: desativa ProximityPrompt de caixas de outro dono (LocalScript)
-- Revisão: scan inicial sem bloquear (defer por caixa); filtro por nome antes de agendar;
--          re-tentativa curta se o prompt ainda não existir (replicação); pcall ao alterar Enabled;
--          opcional atributo DonoUserId (número) — tem prioridade sobre Dono (string / nome).

local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local RETRY_DELAY_SEC = 0.2

local function deveBloquear(caixa)
	local uid = caixa:GetAttribute("DonoUserId")
	if typeof(uid) == "number" and uid > 0 then
		return uid ~= player.UserId
	end
	local dono = caixa:GetAttribute("Dono")
	if typeof(dono) == "string" and dono ~= "" then
		return dono ~= player.Name
	end
	return false
end

local function desativarPrompt(caixa)
	local prompt = caixa:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		return false
	end
	local ok, err = pcall(function()
		prompt.Enabled = false
	end)
	if not ok then
		warn("[CaixaFalsaVisual] Falha ao desativar ProximityPrompt:", err)
	end
	return true
end

local function processar(caixa)
	if not caixa or not caixa.Parent or caixa.Name ~= "CaixaFalsaVisual" then
		return
	end
	if not deveBloquear(caixa) then
		return
	end
	if desativarPrompt(caixa) then
		return
	end
	task.delay(RETRY_DELAY_SEC, function()
		if not caixa.Parent or caixa.Name ~= "CaixaFalsaVisual" or not deveBloquear(caixa) then
			return
		end
		desativarPrompt(caixa)
	end)
end

local function agendar(caixa)
	task.defer(function()
		processar(caixa)
	end)
end

workspace.ChildAdded:Connect(function(child)
	if child.Name == "CaixaFalsaVisual" then
		agendar(child)
	end
end)

for _, obj in ipairs(workspace:GetChildren()) do
	if obj.Name == "CaixaFalsaVisual" then
		agendar(obj)
	end
end
