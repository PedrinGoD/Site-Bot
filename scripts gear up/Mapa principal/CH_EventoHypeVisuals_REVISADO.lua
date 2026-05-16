-- CH Corporations - Hype Visuals (StarterGui / LocalScript)
-- Revisão: remotes com timeout + falha graciosa; validação de argumentos nos .OnClientEvent;
--          texto truncado para UI; debounce no voto; contagem sorteio com token anti-sobreposição;
--          HUD de evento atualiza quando o tempo chega a 0.

print("CH Corporations - Hype Visuals v6.2 (Revisão cliente)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local REMOTE_TIMEOUT = 20
local TEXTO_MAX = 500
local VOTO_DEBOUNCE = 0.6
local function truncarTexto(s, maxLen)
	if type(s) ~= "string" then
		s = tostring(s)
	end
	maxLen = maxLen or TEXTO_MAX
	if #s <= maxLen then
		return s
	end
	return string.sub(s, 1, maxLen - 1) .. "…"
end

local function obterRemote(nome)
	local r = ReplicatedStorage:WaitForChild(nome, REMOTE_TIMEOUT)
	if not r then
		warn("[HypeVisuals] Remote em falta: " .. nome)
	end
	return r
end

local evNotificarTela = obterRemote("NotificarEventoClient")
local evNotificarAnuncio = obterRemote("NotificarAnuncioClient")
local evNotificarEconomia = obterRemote("NotificarEconomiaClient")
local evNotificarSorteio = obterRemote("NotificarSorteioClient")
local evNotificarEnquete = obterRemote("NotificarEnqueteClient")
local evVotarEnquete = obterRemote("VotarEnqueteServer")
local evAtualizarEnquete = obterRemote("AtualizarEnqueteClient")

local COR_FUNDO = Color3.fromRGB(15, 15, 20)
local COR_FUNDO_HUD = Color3.fromRGB(18, 18, 24)
local COR_BOX_ICONE = Color3.fromRGB(30, 30, 40)
local COR_NEON_CIANO = Color3.fromRGB(0, 255, 255)
local COR_NEON_ROXO = Color3.fromRGB(138, 43, 226)
local COR_BRANCO = Color3.fromRGB(255, 255, 255)
local COR_ALERTA = Color3.fromRGB(255, 60, 60)
local COR_DINHEIRO = Color3.fromRGB(50, 255, 100)
local COR_LOCAL = Color3.fromRGB(255, 170, 0)
local COR_OURO = Color3.fromRGB(255, 215, 0)
local COR_OP_A = Color3.fromRGB(0, 255, 127)
local COR_OP_B = Color3.fromRGB(255, 100, 255)

local hudAtivo, multiplicadorAtual, tempoFinalUnix = false, 1, 0

local guiVelha = pGui:FindFirstChild("CH_EventoHypeGui")
if guiVelha then
	guiVelha:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CH_EventoHypeGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = pGui

-- =========================================================
-- 1. AVISOS  |  2. ECONOMIA
-- =========================================================
local AnuncioContainer = Instance.new("Frame")
AnuncioContainer.Size = UDim2.new(0, 600, 0, 110)
AnuncioContainer.Position = UDim2.new(0.5, -300, 0, -150)
AnuncioContainer.BackgroundColor3 = COR_FUNDO_HUD
AnuncioContainer.ZIndex = 100
AnuncioContainer.Parent = gui
Instance.new("UICorner", AnuncioContainer).CornerRadius = UDim.new(0, 12)
local StrokeAnuncio = Instance.new("UIStroke", AnuncioContainer)
StrokeAnuncio.Thickness = 2

local TxtAnuncioTitulo = Instance.new("TextLabel", AnuncioContainer)
TxtAnuncioTitulo.Size = UDim2.new(1, 0, 0, 25)
TxtAnuncioTitulo.Position = UDim2.new(0, 0, 0, 10)
TxtAnuncioTitulo.BackgroundTransparency = 1
TxtAnuncioTitulo.Font = Enum.Font.GothamBlack
TxtAnuncioTitulo.TextSize = 16
TxtAnuncioTitulo.ZIndex = 105

local TxtAnuncioMsg = Instance.new("TextLabel", AnuncioContainer)
TxtAnuncioMsg.Size = UDim2.new(1, -40, 1, -45)
TxtAnuncioMsg.Position = UDim2.new(0, 20, 0, 35)
TxtAnuncioMsg.BackgroundTransparency = 1
TxtAnuncioMsg.TextColor3 = COR_BRANCO
TxtAnuncioMsg.Font = Enum.Font.GothamBold
TxtAnuncioMsg.TextSize = 18
TxtAnuncioMsg.TextWrapped = true
TxtAnuncioMsg.TextScaled = true
TxtAnuncioMsg.ZIndex = 105

if evNotificarAnuncio then
	evNotificarAnuncio.OnClientEvent:Connect(function(mensagem, autor, isGlobal)
		autor = truncarTexto(autor or "?", 80)
		mensagem = truncarTexto(mensagem or "")
		if isGlobal then
			TxtAnuncioTitulo.Text = "🌍 AVISO GLOBAL DE " .. string.upper(autor) .. " 🌍"
			TxtAnuncioTitulo.TextColor3 = COR_NEON_CIANO
			StrokeAnuncio.Color = COR_NEON_CIANO
		else
			TxtAnuncioTitulo.Text = "📍 AVISO DO SERVIDOR (Por " .. string.upper(autor) .. ") 📍"
			TxtAnuncioTitulo.TextColor3 = COR_LOCAL
			StrokeAnuncio.Color = COR_LOCAL
		end
		TxtAnuncioMsg.Text = mensagem
		AnuncioContainer.Position = UDim2.new(0.5, -300, 0, -150)
		TweenService:Create(AnuncioContainer, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -300, 0, 20),
		}):Play()
		task.delay(8, function()
			if not AnuncioContainer.Parent then
				return
			end
			TweenService:Create(AnuncioContainer, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, -300, 0, -150),
			}):Play()
		end)
	end)
end

local EcoContainer = Instance.new("Frame", gui)
EcoContainer.Size = UDim2.new(0, 400, 0, 100)
EcoContainer.Position = UDim2.new(0.5, -200, 0.8, 0)
EcoContainer.BackgroundTransparency = 1
EcoContainer.Visible = false

local TxtEcoTitulo = Instance.new("TextLabel", EcoContainer)
TxtEcoTitulo.Size = UDim2.new(1, 0, 0, 30)
TxtEcoTitulo.BackgroundTransparency = 1
TxtEcoTitulo.TextColor3 = COR_BRANCO
TxtEcoTitulo.Font = Enum.Font.GothamBlack
TxtEcoTitulo.TextSize = 20
TxtEcoTitulo.TextStrokeTransparency = 0
TxtEcoTitulo.ZIndex = 105

local TxtEcoValor = Instance.new("TextLabel", EcoContainer)
TxtEcoValor.Size = UDim2.new(1, 0, 1, -30)
TxtEcoValor.Position = UDim2.new(0, 0, 0, 30)
TxtEcoValor.BackgroundTransparency = 1
TxtEcoValor.Font = Enum.Font.GothamBlack
TxtEcoValor.TextSize = 45
TxtEcoValor.TextStrokeTransparency = 0
TxtEcoValor.ZIndex = 105

if evNotificarEconomia then
	evNotificarEconomia.OnClientEvent:Connect(function(tipo, valor)
		EcoContainer.Visible = true
		EcoContainer.Position = UDim2.new(0.5, -200, 0.8, 0)
		TxtEcoTitulo.TextTransparency = 1
		TxtEcoTitulo.TextStrokeTransparency = 1
		TxtEcoValor.TextTransparency = 1
		TxtEcoValor.TextStrokeTransparency = 1

		if tipo == "Carro" then
			TxtEcoTitulo.Text = "🚗 NOVO VEÍCULO RECEBIDO!"
			TxtEcoTitulo.TextColor3 = COR_LOCAL
			TxtEcoValor.TextColor3 = COR_BRANCO
			TxtEcoValor.Text = truncarTexto(valor or "", 120)
		else
			TxtEcoTitulo.Text = "🎁 PRESENTE DO ADMIN!"
			TxtEcoTitulo.TextColor3 = COR_BRANCO
			local corFinal = (tipo == "XP") and COR_NEON_CIANO or COR_DINHEIRO
			TxtEcoValor.TextColor3 = corFinal
			local sigla = (tipo == "Dinheiro") and "$" or " XP"
			local v = valor
			if type(v) == "number" then
				v = tostring(math.clamp(math.floor(v), 0, 999999999))
			else
				v = truncarTexto(v or "0", 32)
			end
			TxtEcoValor.Text = (tipo == "Dinheiro") and ("+ " .. sigla .. v) or ("+ " .. v .. sigla)
		end

		TweenService:Create(EcoContainer, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -200, 0.65, 0),
		}):Play()
		TweenService:Create(TxtEcoTitulo, TweenInfo.new(0.5), { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
		TweenService:Create(TxtEcoValor, TweenInfo.new(0.5), { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()

		task.delay(4, function()
			if not EcoContainer.Parent then
				return
			end
			local sumir = TweenService:Create(EcoContainer, TweenInfo.new(0.8), { Position = UDim2.new(0.5, -200, 0.6, 0) })
			TweenService:Create(TxtEcoTitulo, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(TxtEcoValor, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			sumir:Play()
			sumir.Completed:Connect(function()
				EcoContainer.Visible = false
			end)
		end)
	end)
end

-- =========================================================
-- 3. HUD EVENTO  |  4. SORTEIO
-- =========================================================
local CentralContainer = Instance.new("Frame", gui)
CentralContainer.Size = UDim2.new(1, 0, 1, 0)
CentralContainer.BackgroundTransparency = 1
CentralContainer.Visible = false
CentralContainer.ZIndex = 0

local CentralGradientFundo = Instance.new("Frame", CentralContainer)
CentralGradientFundo.Size = UDim2.new(1.5, 0, 1.5, 0)
CentralGradientFundo.Position = UDim2.new(-0.25, 0, -0.25, 0)
CentralGradientFundo.BackgroundColor3 = COR_NEON_ROXO
CentralGradientFundo.BackgroundTransparency = 1

local uicg_fundo = Instance.new("UIGradient", CentralGradientFundo)
uicg_fundo.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COR_NEON_ROXO),
	ColorSequenceKeypoint.new(0.5, COR_FUNDO),
	ColorSequenceKeypoint.new(1, COR_NEON_CIANO),
})
uicg_fundo.Rotation = 45

local TxtHypeAtivar = Instance.new("TextLabel", CentralContainer)
TxtHypeAtivar.Size = UDim2.new(1, 0, 0, 80)
TxtHypeAtivar.Position = UDim2.new(0, 0, 0.45, -40)
TxtHypeAtivar.BackgroundTransparency = 1
TxtHypeAtivar.Text = "🎉 EVENTO INICIADO!"
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
	ColorSequenceKeypoint.new(1, COR_NEON_ROXO),
})

local CentralDesativarContainer = Instance.new("Frame", gui)
CentralDesativarContainer.Size = UDim2.new(1, 0, 1, 0)
CentralDesativarContainer.BackgroundTransparency = 1
CentralDesativarContainer.Visible = false

local TxtHypeDesativar = Instance.new("TextLabel", CentralDesativarContainer)
TxtHypeDesativar.Size = UDim2.new(1, 0, 0, 60)
TxtHypeDesativar.Position = UDim2.new(0, 0, 0.45, -30)
TxtHypeDesativar.BackgroundTransparency = 1
TxtHypeDesativar.Text = "🛑 Evento Finalizado."
TxtHypeDesativar.TextColor3 = COR_ALERTA
TxtHypeDesativar.Font = Enum.Font.GothamSemibold
TxtHypeDesativar.TextSize = 25
TxtHypeDesativar.TextTransparency = 1
TxtHypeDesativar.ZIndex = 10
Instance.new("UIStroke", TxtHypeDesativar).Color = Color3.fromRGB(0, 0, 0)

local HudContainer = Instance.new("Frame", gui)
HudContainer.Size = UDim2.new(0, 270, 0, 75)
HudContainer.Position = UDim2.new(1, -290, 0, 30)
HudContainer.BackgroundColor3 = COR_FUNDO_HUD
HudContainer.BorderSizePixel = 0
HudContainer.ZIndex = 50
HudContainer.Visible = false
Instance.new("UICorner", HudContainer).CornerRadius = UDim.new(0, 8)
local StrokeHud = Instance.new("UIStroke", HudContainer)
StrokeHud.Color = COR_NEON_CIANO
StrokeHud.Thickness = 1.5

local BarraLateral = Instance.new("Frame", HudContainer)
BarraLateral.Size = UDim2.new(0, 5, 1, 0)
BarraLateral.BackgroundColor3 = COR_NEON_CIANO
BarraLateral.BorderSizePixel = 0
BarraLateral.ZIndex = 51
Instance.new("UICorner", BarraLateral).CornerRadius = UDim.new(0, 8)

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

local function formatarTempo(s)
	if s <= 0 then
		return "00:00:00"
	end
	local d = math.floor(s / 86400)
	local h = math.floor((s % 86400) / 3600)
	local m = math.floor((s % 3600) / 60)
	local sg = math.floor(s % 60)
	if d > 0 then
		return string.format("%dd:%02d:%02d:%02d", d, h, m, sg)
	elseif h > 0 then
		return string.format("%02d:%02d:%02d", h, m, sg)
	else
		return string.format("%02d:%02d", m, sg)
	end
end

if evNotificarTela then
	evNotificarTela.OnClientEvent:Connect(function(ativar, mult, tFimUnix)
		if type(ativar) ~= "boolean" then
			return
		end
		if ativar then
			multiplicadorAtual = (type(mult) == "number" and mult == mult and mult > 0) and mult or 1
			tempoFinalUnix = (type(tFimUnix) == "number" and tFimUnix > 0) and math.floor(tFimUnix) or 0
			hudAtivo = true
			CentralContainer.Visible = true
			TxtHypeAtivar.Text = "🎉 EVENTO " .. tostring(multiplicadorAtual) .. "X INICIADO!"
			TxtHypeAtivar.TextTransparency = 1
			CentralGradientFundo.BackgroundTransparency = 1
			TweenService:Create(TxtHypeAtivar, TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				TextTransparency = 0,
				TextSize = 45,
			}):Play()
			TweenService:Create(CentralGradientFundo, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0.5,
			}):Play()
			task.delay(4, function()
				if not TxtHypeAtivar.Parent then
					return
				end
				TweenService:Create(TxtHypeAtivar, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
				local tFundo = TweenService:Create(CentralGradientFundo, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
				tFundo:Play()
				tFundo.Completed:Connect(function()
					CentralContainer.Visible = false
				end)
				HudContainer.Visible = true
				HudContainer.Position = UDim2.new(1, 20, 0, 30)
				TweenService:Create(HudContainer, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Position = UDim2.new(1, -290, 0, 30),
				}):Play()
			end)
		else
			hudAtivo = false
			tempoFinalUnix = 0
			if HudContainer.Visible then
				local tOutHud = TweenService:Create(HudContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(1, 20, 0, 30),
				})
				tOutHud:Play()
				tOutHud.Completed:Connect(function()
					HudContainer.Visible = false
				end)
			end
			CentralDesativarContainer.Visible = true
			TxtHypeDesativar.TextTransparency = 1
			TweenService:Create(TxtHypeDesativar, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
			task.delay(2.5, function()
				if not TxtHypeDesativar.Parent then
					return
				end
				local sumir = TweenService:Create(TxtHypeDesativar, TweenInfo.new(0.5), { TextTransparency = 1 })
				sumir:Play()
				sumir.Completed:Connect(function()
					CentralDesativarContainer.Visible = false
				end)
			end)
		end
	end)
end

RunService.Heartbeat:Connect(function()
	if not hudAtivo then
		return
	end
	local freqNeon = (math.sin(os.time() * 2.5) + 1) / 2
	local corPulsante = COR_NEON_ROXO:Lerp(COR_NEON_CIANO, freqNeon)
	StrokeHud.Color = corPulsante
	BarraLateral.BackgroundColor3 = corPulsante
	local baseText = "⚡ " .. tostring(multiplicadorAtual) .. "X  |  "
	if tempoFinalUnix == 0 then
		TxtHudInfo.Text = baseText .. "⏳ PERMANENTE"
		TxtHudInfo.TextColor3 = COR_NEON_CIANO
	else
		local tr = tempoFinalUnix - os.time()
		if tr > 0 then
			TxtHudInfo.Text = baseText .. "⏳ " .. formatarTempo(tr)
			if tr <= 60 then
				if math.floor(os.clock() * 3) % 2 == 0 then
					TxtHudInfo.TextColor3 = COR_ALERTA
				else
					TxtHudInfo.TextColor3 = COR_BRANCO
				end
			else
				TxtHudInfo.TextColor3 = COR_NEON_CIANO
			end
		else
			TxtHudInfo.Text = baseText .. "⏳ FINALIZADO"
			TxtHudInfo.TextColor3 = COR_ALERTA
		end
	end
end)

local SorteioContainer = Instance.new("Frame", gui)
SorteioContainer.Size = UDim2.new(0, 500, 0, 150)
SorteioContainer.Position = UDim2.new(0.5, -250, 0.5, -75)
SorteioContainer.BackgroundColor3 = COR_FUNDO_HUD
SorteioContainer.ZIndex = 200
SorteioContainer.Visible = false
Instance.new("UICorner", SorteioContainer).CornerRadius = UDim.new(0, 16)
local StrokeSorteio = Instance.new("UIStroke", SorteioContainer)
StrokeSorteio.Color = COR_OURO
StrokeSorteio.Thickness = 3

local TxtSorteioTitulo = Instance.new("TextLabel", SorteioContainer)
TxtSorteioTitulo.Size = UDim2.new(1, 0, 0, 30)
TxtSorteioTitulo.Position = UDim2.new(0, 0, 0, 15)
TxtSorteioTitulo.BackgroundTransparency = 1
TxtSorteioTitulo.Text = "🎁 SORTEIO GLOBAL INICIADO!"
TxtSorteioTitulo.TextColor3 = COR_OURO
TxtSorteioTitulo.Font = Enum.Font.GothamBlack
TxtSorteioTitulo.TextSize = 22
TxtSorteioTitulo.ZIndex = 205

local TxtSorteioPremio = Instance.new("TextLabel", SorteioContainer)
TxtSorteioPremio.Size = UDim2.new(1, 0, 0, 30)
TxtSorteioPremio.Position = UDim2.new(0, 0, 0, 45)
TxtSorteioPremio.BackgroundTransparency = 1
TxtSorteioPremio.Text = "Prêmio: ..."
TxtSorteioPremio.TextColor3 = COR_BRANCO
TxtSorteioPremio.Font = Enum.Font.GothamMedium
TxtSorteioPremio.TextSize = 18
TxtSorteioPremio.ZIndex = 205

local TxtSorteioContador = Instance.new("TextLabel", SorteioContainer)
TxtSorteioContador.Size = UDim2.new(1, 0, 0, 60)
TxtSorteioContador.Position = UDim2.new(0, 0, 0, 80)
TxtSorteioContador.BackgroundTransparency = 1
TxtSorteioContador.Text = "10"
TxtSorteioContador.TextColor3 = COR_NEON_CIANO
TxtSorteioContador.Font = Enum.Font.GothamBlack
TxtSorteioContador.TextSize = 50
TxtSorteioContador.ZIndex = 205

local sorteioContagemToken = 0

if evNotificarSorteio then
	evNotificarSorteio.OnClientEvent:Connect(function(estado, tipo, valor, vencedorNome)
		if estado == "Iniciar" then
			sorteioContagemToken += 1
			local meuToken = sorteioContagemToken
			SorteioContainer.Visible = true
			SorteioContainer.Position = UDim2.new(0.5, -250, 0.3, 0)
			StrokeSorteio.Color = COR_OURO
			local premioTexto
			if tipo == "Carro" then
				premioTexto = "Veículo " .. truncarTexto(valor or "?", 80)
			elseif tipo == "Dinheiro" then
				premioTexto = "$" .. truncarTexto(tostring(valor or 0), 40)
			else
				premioTexto = truncarTexto(tostring(valor or 0), 40) .. " XP"
			end
			TxtSorteioTitulo.Text = "🎁 SORTEIO GLOBAL!"
			TxtSorteioTitulo.TextColor3 = COR_OURO
			TxtSorteioPremio.Text = "Valendo: " .. premioTexto
			TxtSorteioContador.TextColor3 = COR_NEON_CIANO
			TweenService:Create(SorteioContainer, TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, -250, 0.5, -75),
			}):Play()
			task.spawn(function()
				for i = 10, 1, -1 do
					if meuToken ~= sorteioContagemToken or not SorteioContainer.Visible then
						break
					end
					TxtSorteioContador.Text = tostring(i)
					TxtSorteioContador.TextSize = 30
					TweenService:Create(TxtSorteioContador, TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { TextSize = 60 }):Play()
					task.wait(1)
				end
			end)
		elseif estado == "Vencedor" then
			sorteioContagemToken += 1
			vencedorNome = truncarTexto(vencedorNome or "?", 48)
			TxtSorteioContador.Text = "👑 " .. string.upper(vencedorNome) .. " 👑"
			TxtSorteioContador.TextSize = 40
			TxtSorteioContador.TextColor3 = COR_DINHEIRO
			TxtSorteioTitulo.Text = "🎉 TEMOS UM VENCEDOR!"
			StrokeSorteio.Color = COR_DINHEIRO
			task.spawn(function()
				for i = 1, 5 do
					StrokeSorteio.Color = COR_BRANCO
					TxtSorteioContador.TextColor3 = COR_BRANCO
					task.wait(0.1)
					StrokeSorteio.Color = COR_DINHEIRO
					TxtSorteioContador.TextColor3 = COR_DINHEIRO
					task.wait(0.1)
				end
			end)
			task.delay(5, function()
				if not SorteioContainer.Parent then
					return
				end
				local sumir = TweenService:Create(SorteioContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, -250, 0.8, 0),
				})
				sumir:Play()
				sumir.Completed:Connect(function()
					SorteioContainer.Visible = false
				end)
			end)
		end
	end)
end

-- =========================================================
-- 5. ENQUETE (ZIndex)
-- =========================================================
local EnqueteContainer = Instance.new("Frame", gui)
EnqueteContainer.Size = UDim2.new(0, 300, 0, 160)
EnqueteContainer.Position = UDim2.new(1, 20, 0.5, -80)
EnqueteContainer.BackgroundColor3 = COR_FUNDO_HUD
EnqueteContainer.ZIndex = 150
EnqueteContainer.Visible = false
Instance.new("UICorner", EnqueteContainer).CornerRadius = UDim.new(0, 12)
local StrokeEnquete = Instance.new("UIStroke", EnqueteContainer)
StrokeEnquete.Color = COR_NEON_CIANO
StrokeEnquete.Thickness = 2

local TxtEnquetePergunta = Instance.new("TextLabel", EnqueteContainer)
TxtEnquetePergunta.Size = UDim2.new(1, -20, 0, 40)
TxtEnquetePergunta.Position = UDim2.new(0, 10, 0, 10)
TxtEnquetePergunta.BackgroundTransparency = 1
TxtEnquetePergunta.Text = "Pergunta Aqui?"
TxtEnquetePergunta.TextColor3 = COR_BRANCO
TxtEnquetePergunta.Font = Enum.Font.GothamBold
TxtEnquetePergunta.TextSize = 16
TxtEnquetePergunta.TextScaled = true
TxtEnquetePergunta.TextWrapped = true
TxtEnquetePergunta.ZIndex = 155

local ultimoVoto = 0

local function criarBotaoVoto(posY, corOpcao, nomeAcao)
	local container = Instance.new("Frame", EnqueteContainer)
	container.Size = UDim2.new(1, -20, 0, 35)
	container.Position = UDim2.new(0, 10, 0, posY)
	container.BackgroundColor3 = COR_BOX_ICONE
	container.ZIndex = 152
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)

	local barraFundo = Instance.new("Frame", container)
	barraFundo.Size = UDim2.new(0, 0, 1, 0)
	barraFundo.BackgroundColor3 = corOpcao
	barraFundo.BackgroundTransparency = 0.5
	barraFundo.ZIndex = 153
	Instance.new("UICorner", barraFundo).CornerRadius = UDim.new(0, 8)

	local btnText = Instance.new("TextButton", container)
	btnText.Size = UDim2.new(1, 0, 1, 0)
	btnText.BackgroundTransparency = 1
	btnText.Text = "Opção"
	btnText.TextColor3 = COR_BRANCO
	btnText.Font = Enum.Font.GothamBlack
	btnText.TextSize = 14
	btnText.ZIndex = 155

	local txtPct = Instance.new("TextLabel", container)
	txtPct.Size = UDim2.new(0, 40, 1, 0)
	txtPct.Position = UDim2.new(1, -50, 0, 0)
	txtPct.BackgroundTransparency = 1
	txtPct.Text = "50%"
	txtPct.TextColor3 = COR_BRANCO
	txtPct.Font = Enum.Font.GothamBold
	txtPct.TextSize = 14
	txtPct.TextXAlignment = Enum.TextXAlignment.Right
	txtPct.ZIndex = 155

	btnText.MouseButton1Click:Connect(function()
		if not evVotarEnquete then
			return
		end
		if not EnqueteContainer.Visible then
			return
		end
		local agora = os.clock()
		if agora - ultimoVoto < VOTO_DEBOUNCE then
			return
		end
		ultimoVoto = agora
		evVotarEnquete:FireServer(nomeAcao)
	end)

	return btnText, txtPct, barraFundo
end

local BtnOpA, PctOpA, BarraA = criarBotaoVoto(60, COR_OP_A, "A")
local BtnOpB, PctOpB, BarraB = criarBotaoVoto(105, COR_OP_B, "B")

local TxtTempoEnquete = Instance.new("TextLabel", EnqueteContainer)
TxtTempoEnquete.Size = UDim2.new(1, 0, 0, 15)
TxtTempoEnquete.Position = UDim2.new(0, 0, 1, -20)
TxtTempoEnquete.BackgroundTransparency = 1
TxtTempoEnquete.Text = "⏳ Restam: 30s"
TxtTempoEnquete.TextColor3 = COR_ALERTA
TxtTempoEnquete.Font = Enum.Font.GothamMedium
TxtTempoEnquete.TextSize = 12
TxtTempoEnquete.ZIndex = 155

if evNotificarEnquete then
	evNotificarEnquete.OnClientEvent:Connect(function(acao, pergunta, opA, opB, tempoMax)
		if acao == "Iniciar" then
			TxtEnquetePergunta.Text = truncarTexto(pergunta or "?", 200)
			BtnOpA.Text = truncarTexto(opA or "A", 40)
			BtnOpB.Text = truncarTexto(opB or "B", 40)
			PctOpA.Text = "50%"
			PctOpB.Text = "50%"
			BarraA.Size = UDim2.new(0.5, 0, 1, 0)
			BarraB.Size = UDim2.new(0.5, 0, 1, 0)
			EnqueteContainer.Visible = true
			EnqueteContainer.Position = UDim2.new(1, 20, 0.5, -80)
			TweenService:Create(EnqueteContainer, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(1, -320, 0.5, -80),
			}):Play()
		elseif acao == "Encerrar" then
			TxtTempoEnquete.Text = "✅ ENQUETE ENCERRADA"
			task.delay(3, function()
				if not EnqueteContainer.Parent then
					return
				end
				local out = TweenService:Create(EnqueteContainer, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(1, 20, 0.5, -80),
				})
				out:Play()
				out.Completed:Connect(function()
					EnqueteContainer.Visible = false
				end)
			end)
		end
	end)
end

if evAtualizarEnquete then
	evAtualizarEnquete.OnClientEvent:Connect(function(pctA, pctB, segundosRestantes)
		local a = (type(pctA) == "number" and pctA == pctA) and math.clamp(math.floor(pctA + 0.5), 0, 100) or 0
		local b = (type(pctB) == "number" and pctB == pctB) and math.clamp(math.floor(pctB + 0.5), 0, 100) or 0
		PctOpA.Text = a .. "%"
		PctOpB.Text = b .. "%"
		TweenService:Create(BarraA, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.new(a / 100, 0, 1, 0) }):Play()
		TweenService:Create(BarraB, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.new(b / 100, 0, 1, 0) }):Play()
		local seg = (type(segundosRestantes) == "number" and segundosRestantes == segundosRestantes) and math.max(0, math.floor(segundosRestantes)) or 0
		TxtTempoEnquete.Text = "⏳ Restam: " .. seg .. "s"
	end)
end
