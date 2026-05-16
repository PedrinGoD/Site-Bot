print("CH Corporations - Hype Event Visuals (Animação V2 + HUD V3)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local evNotificarTela = ReplicatedStorage:WaitForChild("NotificarEventoClient", 20)
if not evNotificarTela then warn("❌ Evento 'NotificarEventoClient' não encontrado no tempo limite!") return end

-- ==========================================
-- 🎨 CORES E VARIÁVEIS
-- ==========================================
local COR_FUNDO = Color3.fromRGB(15, 15, 20) -- Para o degradê
local COR_FUNDO_HUD = Color3.fromRGB(18, 18, 24) -- Para o HUD Premium
local COR_BOX_ICONE = Color3.fromRGB(30, 30, 40)
local COR_NEON_CIANO = Color3.fromRGB(0, 255, 255)
local COR_NEON_ROXO = Color3.fromRGB(138, 43, 226)
local COR_BRANCO = Color3.fromRGB(255, 255, 255)
local COR_ALERTA = Color3.fromRGB(255, 60, 60)

local hudAtivo = false
local multiplicadorAtual = 1
local tempoFinalUnix = 0 

local guiVelha = pGui:FindFirstChild("CH_EventoHypeGui")
if guiVelha then guiVelha:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "CH_EventoHypeGui"
gui.IgnoreGuiInset = true 
gui.ResetOnSpawn = false
gui.Parent = pGui

-- ==========================================
-- 🚀 1. ANIMAÇÃO INICIAL (O HYPE ORIGINAL QUE VOCÊ GOSTOU)
-- ==========================================
local CentralContainer = Instance.new("Frame", gui) 
CentralContainer.Size = UDim2.new(1, 0, 1, 0) 
CentralContainer.BackgroundTransparency = 1 
CentralContainer.Visible = false

local CentralGradientFundo = Instance.new("Frame", CentralContainer) 
CentralGradientFundo.Size = UDim2.new(1.5, 0, 1.5, 0) 
CentralGradientFundo.Position = UDim2.new(-0.25, 0, -0.25, 0) 
CentralGradientFundo.BackgroundColor3 = COR_NEON_ROXO 
CentralGradientFundo.BackgroundTransparency = 1 
CentralContainer.ZIndex = 0

local uicg_fundo = Instance.new("UIGradient", CentralGradientFundo) 
uicg_fundo.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COR_NEON_ROXO), 
	ColorSequenceKeypoint.new(0.5, COR_FUNDO), 
	ColorSequenceKeypoint.new(1, COR_NEON_CIANO)
}) 
uicg_fundo.Rotation = 45

local TxtHypeAtivar = Instance.new("TextLabel", CentralContainer) 
TxtHypeAtivar.Size = UDim2.new(1, 0, 0, 80) 
TxtHypeAtivar.Position = UDim2.new(0, 0, 0.45, -40) 
TxtHypeAtivar.BackgroundTransparency = 1 
TxtHypeAtivar.Text = "🎉 EVENTO GLOBAL INICIADO!" 
TxtHypeAtivar.TextColor3 = COR_BRANCO 
TxtHypeAtivar.Font = Enum.Font.GothamBlack 
TxtHypeAtivar.TextSize = 35 
TxtHypeAtivar.TextTransparency = 1 
TxtHypeAtivar.ZIndex = 10

Instance.new("UIStroke", TxtHypeAtivar).Color = COR_NEON_CIANO
local uicg_hype = Instance.new("UIGradient", TxtHypeAtivar) 
uicg_hype.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COR_NEON_CIANO), 
	ColorSequenceKeypoint.new(0.5, COR_BRANCO), 
	ColorSequenceKeypoint.new(1, COR_NEON_ROXO)
})

-- ==========================================
-- 🛑 2. AVISO DE ENCERRAMENTO (ESTILO ORIGINAL)
-- ==========================================
local CentralDesativarContainer = Instance.new("Frame", gui) 
CentralDesativarContainer.Size = UDim2.new(1, 0, 1, 0) 
CentralDesativarContainer.BackgroundTransparency = 1 
CentralDesativarContainer.Visible = false

local TxtHypeDesativar = Instance.new("TextLabel", CentralDesativarContainer) 
TxtHypeDesativar.Size = UDim2.new(1, 0, 0, 60) 
TxtHypeDesativar.Position = UDim2.new(0, 0, 0.45, -30) 
TxtHypeDesativar.BackgroundTransparency = 1 
TxtHypeDesativar.Text = "🛑 O Evento Global Acabou." 
TxtHypeDesativar.TextColor3 = COR_ALERTA 
TxtHypeDesativar.Font = Enum.Font.GothamSemibold 
TxtHypeDesativar.TextSize = 25 
TxtHypeDesativar.TextTransparency = 1 
TxtHypeDesativar.ZIndex = 10 
Instance.new("UIStroke", TxtHypeDesativar).Color = Color3.fromRGB(0,0,0)

-- ==========================================
-- ⚡ 3. O NOVO HUD SOFISTICADO (CANTO DA TELA)
-- ==========================================
local HudContainer = Instance.new("Frame", gui)
HudContainer.Name = "HUD_EventoActive"
HudContainer.Size = UDim2.new(0, 270, 0, 75)
HudContainer.Position = UDim2.new(1, -290, 0, 30)
HudContainer.BackgroundColor3 = COR_FUNDO_HUD
HudContainer.BorderSizePixel = 0
HudContainer.ZIndex = 50
HudContainer.Visible = false
Instance.new("UICorner", HudContainer).CornerRadius = UDim.new(0, 8)

-- Borda Externa Pulsante
local StrokeHud = Instance.new("UIStroke", HudContainer) 
StrokeHud.Color = COR_NEON_CIANO 
StrokeHud.Thickness = 1.5

-- Barra Lateral Neon
local BarraLateral = Instance.new("Frame", HudContainer)
BarraLateral.Size = UDim2.new(0, 5, 1, 0)
BarraLateral.BackgroundColor3 = COR_NEON_CIANO
BarraLateral.BorderSizePixel = 0
BarraLateral.ZIndex = 51
Instance.new("UICorner", BarraLateral).CornerRadius = UDim.new(0, 8)

-- Box do Ícone
local FundoIcone = Instance.new("Frame", HudContainer)
FundoIcone.Size = UDim2.new(0, 45, 0, 45)
FundoIcone.Position = UDim2.new(0, 15, 0.5, -22.5)
FundoIcone.BackgroundColor3 = COR_BOX_ICONE
FundoIcone.ZIndex = 51
Instance.new("UICorner", FundoIcone).CornerRadius = UDim.new(0, 8)

local TxtIcone = Instance.new("TextLabel", FundoIcone)
TxtIcone.Size = UDim2.new(1, 0, 1, 0)
TxtIcone.BackgroundTransparency = 1
TxtIcone.Text = "🚀" 
TxtIcone.TextSize = 25
TxtIcone.ZIndex = 52

-- Textos do HUD
local TxtHudTitulo = Instance.new("TextLabel", HudContainer) 
TxtHudTitulo.Size = UDim2.new(1, -80, 0, 25) 
TxtHudTitulo.Position = UDim2.new(0, 70, 0, 12) 
TxtHudTitulo.BackgroundTransparency = 1 
TxtHudTitulo.Text = "BOOST GLOBAL ATIVO" 
TxtHudTitulo.TextColor3 = COR_BRANCO 
TxtHudTitulo.Font = Enum.Font.GothamBlack 
TxtHudTitulo.TextSize = 14 
TxtHudTitulo.TextXAlignment = Enum.TextXAlignment.Left
TxtHudTitulo.ZIndex = 52

local TxtHudInfo = Instance.new("TextLabel", HudContainer) 
TxtHudInfo.Size = UDim2.new(1, -80, 0, 20) 
TxtHudInfo.Position = UDim2.new(0, 70, 0, 38) 
TxtHudInfo.BackgroundTransparency = 1 
TxtHudInfo.Text = "⚡ 2X | ⏳ 00:00:00" 
TxtHudInfo.TextColor3 = COR_NEON_CIANO 
TxtHudInfo.Font = Enum.Font.GothamBold 
TxtHudInfo.TextSize = 14 
TxtHudInfo.TextXAlignment = Enum.TextXAlignment.Left
TxtHudInfo.ZIndex = 52

-- ==========================================
-- 🛠️ FUNÇÕES DE TEMPO E TWEENS
-- ==========================================
local function formatarTempo(segundos)
	if segundos <= 0 then return "00:00:00" end
	local horas = math.floor(segundos / 3600)
	local minutos = math.floor((segundos % 3600) / 60)
	local segs = math.floor(segundos % 60)
	if horas > 0 then return string.format("%02d:%02d:%02d", horas, minutos, segs) else return string.format("%02d:%02d", minutos, segs) end
end

local function TweenOutCentralHype()
	local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	TweenService:Create(TxtHypeAtivar, tweenInfo, {TextTransparency = 1}):Play()
	local tFundo = TweenService:Create(CentralGradientFundo, tweenInfo, {BackgroundTransparency = 1})
	tFundo:Play() 
	tFundo.Completed:Connect(function() CentralContainer.Visible = false end)
end

local function TweenInHUD()
	HudContainer.Visible = true 
	HudContainer.Position = UDim2.new(1, 20, 0, 30) -- Fora pra direita
	TweenService:Create(HudContainer, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(1, -290, 0, 30)}):Play()
end

-- ==========================================
-- 📡 RECEBENDO A ORDEM DO SERVIDOR
-- ==========================================
evNotificarTela.OnClientEvent:Connect(function(ativar, multiplicador, tFimUnix)
	if ativar then
		multiplicadorAtual = multiplicador
		tempoFinalUnix = tFimUnix or 0
		hudAtivo = true

		CentralContainer.Visible = true
		TxtHypeAtivar.Text = "🎉 EVENTO " .. multiplicadorAtual .. "X INICIADO!"
		TxtHypeAtivar.TextTransparency = 1
		CentralGradientFundo.BackgroundTransparency = 1

		-- Animação Original
		TweenService:Create(TxtHypeAtivar, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {TextTransparency = 0, TextSize = 45}):Play()
		TweenService:Create(CentralGradientFundo, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 0.5}):Play()

		-- Deixa o Hype na tela por 4 segundos e puxa o HUD
		task.delay(4, function() TweenOutCentralHype() TweenInHUD() end)
	else
		hudAtivo = false
		tempoFinalUnix = 0

		-- Esconde o HUD
		if HudContainer.Visible then
			local tOutHud = TweenService:Create(HudContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(1, 20, 0, 30)})
			tOutHud:Play() 
			tOutHud.Completed:Connect(function() HudContainer.Visible = false end)
		end

		-- Mostra a notificação final rápida (estilo original)
		CentralDesativarContainer.Visible = true 
		TxtHypeDesativar.TextTransparency = 1
		TweenService:Create(TxtHypeDesativar, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()

		task.delay(2.5, function() 
			local sumir = TweenService:Create(TxtHypeDesativar, TweenInfo.new(0.5), {TextTransparency = 1})
			sumir:Play()
			sumir.Completed:Connect(function() CentralDesativarContainer.Visible = false end) 
		end)
	end
end)

-- ==========================================
-- ⏱️ LOOP DE ATUALIZAÇÃO (CRONÔMETRO E NEON)
-- ==========================================
RunService.Heartbeat:Connect(function()
	if not hudAtivo then return end

	-- Faz a borda e a barra lateral pulsarem entre Ciano e Roxo suavemente
	local freqNeon = (math.sin(os.time() * 2.5) + 1) / 2
	local corPulsante = COR_NEON_ROXO:Lerp(COR_NEON_CIANO, freqNeon)
	StrokeHud.Color = corPulsante
	BarraLateral.BackgroundColor3 = corPulsante

	-- Lógica do Texto Base
	local baseText = "⚡ " .. multiplicadorAtual .. "X  |  "

	if tempoFinalUnix == 0 then
		TxtHudInfo.Text = baseText .. "⏳ PERMANENTE"
		TxtHudInfo.TextColor3 = COR_NEON_CIANO
	else
		local tempoRestanteSegundos = tempoFinalUnix - os.time()

		if tempoRestanteSegundos > 0 then
			TxtHudInfo.Text = baseText .. "⏳ " .. formatarTempo(tempoRestanteSegundos)

			-- Pisca vermelho forte nos últimos 60 segundos
			if tempoRestanteSegundos <= 60 then
				if math.floor(os.clock() * 3) % 2 == 0 then
					TxtHudInfo.TextColor3 = COR_ALERTA 
				else
					TxtHudInfo.TextColor3 = COR_BRANCO
				end
			else
				TxtHudInfo.TextColor3 = COR_NEON_CIANO
			end
		end
	end
end)
