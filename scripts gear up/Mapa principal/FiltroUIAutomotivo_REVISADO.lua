-- CH Corporations - Filtro de UI Automotivo (StarterPlayerScripts / LocalScript)
-- Revisão: varredura inicial sem 1 coroutine por descendente; atraso com task.delay (não task.wait no callback);
--          string.find literal para "sCar"; validações de tipo/Parent; ignora prompt já removido após o atraso.

print("CH Corporations - Filtro de UI Automotivo (revisão — modo aniquilação)")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local NOME_PROMPT = "PromptVoto"
local MARCA_CARRO = "sCar"
-- Folga para o servidor batizar o Model antes de ler o nome (ajusta se o teu spawn for mais lento)
local ATRASO_VERIFICACAO = 0.1

local function processarPromptVoto(prompt)
	if not prompt or not prompt.Parent then
		return
	end
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= NOME_PROMPT then
		return
	end

	local carro = prompt:FindFirstAncestorWhichIsA("Model")
	if not carro then
		return
	end

	local nomeModel = carro.Name
	if string.find(nomeModel, MARCA_CARRO, 1, true) == nil then
		return
	end

	local nomeDono = (string.gsub(nomeModel, MARCA_CARRO, ""))
	if nomeDono == LocalPlayer.Name then
		prompt:Destroy()
	end
end

--- Agenda verificação após ATRASO_VERIFICACAO (evita task.wait bloqueante e N threads na varredura inicial).
local function agendarSeForPromptVoto(instancia)
	if not instancia:IsA("ProximityPrompt") or instancia.Name ~= NOME_PROMPT then
		return
	end

	local alvo = instancia
	task.delay(ATRASO_VERIFICACAO, function()
		if alvo.Parent == nil or not alvo:IsDescendantOf(Workspace) then
			return
		end
		processarPromptVoto(alvo)
	end)
end

-- 1. Varre o mapa: só reage a ProximityPrompt "PromptVoto" (sem task.spawn por cada peça)
for _, objeto in ipairs(Workspace:GetDescendants()) do
	agendarSeForPromptVoto(objeto)
end

-- 2. Novos descendentes (carros / prompts criados depois)
Workspace.DescendantAdded:Connect(agendarSeForPromptVoto)
