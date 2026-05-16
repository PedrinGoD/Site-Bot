-- CH Corporations - Animação loja de suspensão (ProximityPrompt em ShopSusp)
-- Revisão: serviços; WaitForChild com timeout; UIScale reutilizável; tweens canceláveis + Completed:Once;
--          menuAberto só fica false após o fecho; sem Wait() no fechar; ProximityPrompt validado;
--          BotaoFechar ou Fechar com Activated.

print("CH Corporations - Animação Loja de Suspensão (revisão)")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local gui = script.Parent

local TIMEOUT_UI = 15
local TIMEOUT_MAPA = 60

local frameTudo = gui:WaitForChild("Tudo", TIMEOUT_UI)
if not frameTudo then
	warn("[AnimacaoLojaSusp] Frame 'Tudo' em falta.")
	return
end

local uiScale = frameTudo:FindFirstChildOfClass("UIScale")
if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = frameTudo
end
uiScale.Scale = 0

frameTudo.Visible = false

local lojaModel = Workspace:WaitForChild("ShopSusp", TIMEOUT_MAPA)
if not lojaModel then
	warn("[AnimacaoLojaSusp] ShopSusp não encontrada.")
	return
end

local partCompra = lojaModel:WaitForChild("Compra", TIMEOUT_MAPA)
if not partCompra then
	warn("[AnimacaoLojaSusp] ShopSusp.Compra em falta.")
	return
end

local prompt = partCompra:WaitForChild("ProximityPrompt", TIMEOUT_MAPA)
if not prompt or not prompt:IsA("ProximityPrompt") then
	warn("[AnimacaoLojaSusp] ProximityPrompt em falta.")
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

local function abrirMenu()
	if menuAberto then
		return
	end
	menuAberto = true

	frameTudo.Visible = true
	prompt.Enabled = false

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
	local animacao = TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0,
	})
	tweenAtual = animacao
	animacao.Completed:Once(function()
		if tweenAtual ~= animacao then
			return
		end
		tweenAtual = nil
		frameTudo.Visible = false
		menuAberto = false
		prompt.Enabled = true
	end)
	animacao:Play()
end

prompt.Triggered:Connect(function(jogadorQueClicou)
	if typeof(jogadorQueClicou) ~= "Instance" or not jogadorQueClicou:IsA("Player") then
		return
	end
	if jogadorQueClicou ~= player then
		return
	end
	abrirMenu()
end)

local botaoFechar = frameTudo:FindFirstChild("BotaoFechar", true)
		or frameTudo:FindFirstChild("Fechar", true)

if botaoFechar and botaoFechar:IsA("GuiButton") then
	botaoFechar.Activated:Connect(fecharMenu)
elseif botaoFechar then
	botaoFechar.MouseButton1Click:Connect(fecharMenu)
else
	warn("[AnimacaoLojaSusp] Botão de fechar não encontrado (BotaoFechar / Fechar).")
end
