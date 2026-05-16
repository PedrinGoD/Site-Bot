-- CH Corporations - Animação / abrir menu da garagem (LocalScript na ScreenGui ou sob "Tudo")
-- Revisão: serviços e WaitForChild com timeout; tweens canceláveis + Completed:Once; ProximityPrompt validado;
--          AbrirMenuGaragemEvent grava LocalDeSpawn no atributo do frame (se for string); Activated no fechar.

print("CH Corporations - Animação garagem (revisão)")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gui = script.Parent

local TIMEOUT_UI = 15
local TIMEOUT_MAPA = 60
local REMOTE_TIMEOUT = 60

local frameTudo = gui:WaitForChild("Tudo", TIMEOUT_UI)
if not frameTudo then
	warn("[AnimacaoGaragem] Frame 'Tudo' em falta.")
	return
end

local abrirMenuGaragem = ReplicatedStorage:WaitForChild("AbrirMenuGaragemEvent", REMOTE_TIMEOUT)
if not abrirMenuGaragem or not abrirMenuGaragem:IsA("RemoteEvent") then
	warn("[AnimacaoGaragem] AbrirMenuGaragemEvent inválido ou em falta.")
	return
end

local uiScale = frameTudo:FindFirstChildOfClass("UIScale")
if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = frameTudo
end
uiScale.Scale = 0
frameTudo.Visible = false

local estacionamentoModel = Workspace:WaitForChild("EstacionamentoG", TIMEOUT_MAPA)
if not estacionamentoModel then
	warn("[AnimacaoGaragem] EstacionamentoG não encontrado.")
	return
end

local partAcesso = estacionamentoModel:WaitForChild("AcessoGaragem", TIMEOUT_MAPA)
if not partAcesso then
	warn("[AnimacaoGaragem] AcessoGaragem em falta.")
	return
end

local promptLoja = partAcesso:WaitForChild("ProximityPrompt", TIMEOUT_MAPA)
if not promptLoja or not promptLoja:IsA("ProximityPrompt") then
	warn("[AnimacaoGaragem] ProximityPrompt em falta.")
	return
end

local menuAberto = false
local tweenAtual = nil

local function pararTween()
	if tweenAtual then
		pcall(function()
			tweenAtual:Cancel()
		end)
		tweenAtual = nil
	end
end

-- forcar = true (ex.: RemoteEvent): cancela fecho em curso e abre. Prompt usa forcar = false.
local function abrirMenu(forcar)
	if menuAberto and not forcar then
		return
	end

	pararTween()
	menuAberto = true
	frameTudo.Visible = true
	promptLoja.Enabled = false

	local animacao = TweenService:Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	tweenAtual = animacao
	animacao.Completed:Once(function()
		if tweenAtual == animacao then
			tweenAtual = nil
		end
	end)
	animacao:Play()
end

local function fecharMenu()
	if not menuAberto then
		return
	end

	pararTween()
	local anim = TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0,
	})
	tweenAtual = anim
	anim.Completed:Once(function()
		if tweenAtual ~= anim then
			return
		end
		tweenAtual = nil
		frameTudo.Visible = false
		menuAberto = false
		promptLoja.Enabled = true
	end)
	anim:Play()
end

promptLoja.Triggered:Connect(function(jogador)
	if typeof(jogador) ~= "Instance" or not jogador:IsA("Player") then
		return
	end
	if jogador ~= player then
		return
	end
	abrirMenu(false)
end)

abrirMenuGaragem.OnClientEvent:Connect(function(localDeSpawn)
	if type(localDeSpawn) == "string" and localDeSpawn ~= "" then
		frameTudo:SetAttribute("LocalDeSpawn", localDeSpawn)
	elseif type(localDeSpawn) == "number" and localDeSpawn == localDeSpawn then
		frameTudo:SetAttribute("LocalDeSpawn", tostring(math.floor(localDeSpawn)))
	end
	abrirMenu(true)
end)

local botaoFechar = frameTudo:FindFirstChild("BotaoFechar", true)
if botaoFechar and botaoFechar:IsA("GuiButton") then
	botaoFechar.Activated:Connect(fecharMenu)
elseif botaoFechar then
	botaoFechar.MouseButton1Click:Connect(fecharMenu)
else
	warn("[AnimacaoGaragem] BotaoFechar não encontrado.")
end
