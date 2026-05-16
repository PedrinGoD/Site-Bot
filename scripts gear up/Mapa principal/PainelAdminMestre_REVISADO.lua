-- CH Corporations - Painel Admin Mestre (LocalScript) — VIP + Eventos + Avisos + Eco + Mundo + Sorteio + Enquete
-- Unifica o PainelAdminNeon revisado (só VIP) com o v5.0 “mestre”.
-- Revisão: lista ADMS no cliente (só UX — servidor deve validar sempre); NUNCA criar RemoteEvent no cliente;
--          remotes com WaitForChild + IsA; atalhos F5 / F4 / F10 / F11 via ContextActionService; tweens com Cancel + Once;
--          arrasto sem leak; task.delay em vez de task.wait em handlers; pcall nos FireServer; remove GUIs antigas.

print("CH Corporations - Painel Admin Mestre (revisão unificada)")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_TIMEOUT = 60
local NICK_MAX_LEN = 64
local DEBOUNCE_VIP = 1.5

-- Quem vê o painel no cliente (servidor ainda deve recusar quem não for admin)
local ADMS = {
	["CheechSC"] = true,
	["DDdaZZ26"] = true,
	["Player1"] = true,
}

local player = Players.LocalPlayer
if not ADMS[player.Name] then
	script:Destroy()
	return
end

local playerGui = player:WaitForChild("PlayerGui", REMOTE_TIMEOUT)
if not playerGui then
	warn("[PainelMestre] PlayerGui em falta.")
	return
end

local function waitRemote(name)
	local ev = ReplicatedStorage:WaitForChild(name, REMOTE_TIMEOUT)
	if ev and ev:IsA("RemoteEvent") then
		return ev
	end
	warn("[PainelMestre] RemoteEvent em falta ou inválido:", name)
	return nil
end

local evAdmin = waitRemote("DoarVipCrossServer")
local evEventoGlobal = waitRemote("EventoAdminCrossServer")
local evAnuncioAdmin = waitRemote("AnuncioAdminCrossServer")
local evEconomiaAdmin = waitRemote("EconomiaAdminCrossServer")
local evMundoAdmin = waitRemote("MundoAdminCrossServer")
local evSorteioAdmin = waitRemote("SorteioAdminCrossServer")
local evEnqueteAdmin = waitRemote("EnqueteAdminCrossServer")
-- Opcional: ajusta o nome se o teu servidor usar outro
local evNotificarTela = ReplicatedStorage:FindFirstChild("AdminEventoNotificarTela")
if evNotificarTela and not evNotificarTela:IsA("RemoteEvent") then
	evNotificarTela = nil
end

for _, nome in ipairs({ "CH_PainelAdminGui", "CH_PainelAdminAdminGui" }) do
	local antiga = playerGui:FindFirstChild(nome)
	if antiga then
		antiga:Destroy()
	end
end

local COR_FUNDO = Color3.fromRGB(15, 15, 22)
local COR_NEON_CIANO = Color3.fromRGB(0, 255, 255)
local COR_NEON_VERDE = Color3.fromRGB(0, 255, 127)
local COR_NEON_VERMELHO = Color3.fromRGB(255, 50, 50)
local COR_BRANCO = Color3.fromRGB(255, 255, 255)
local COR_FUNDO_SELECAO = Color3.fromRGB(30, 30, 40)
local COR_NEON_ROXO = Color3.fromRGB(138, 43, 226)

local vipSelecionado = "Bronze"
local diasSelecionados = 0
local eventoDoubleLigado = false
local isAvisoGlobal = true
local moedaEcoSelecionada = "Dinheiro"
local moedaSorteioSelecionada = "Dinheiro"
local painelAberto = false

local function strokeOf(inst)
	return inst:FindFirstChildOfClass("UIStroke")
end

-- ========== GUI raiz ==========
local gui = Instance.new("ScreenGui")
gui.Name = "CH_PainelAdminGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local PainelPrincipal = Instance.new("Frame")
PainelPrincipal.Name = "PainelPrincipal"
PainelPrincipal.Size = UDim2.new(0, 520, 0, 500)
PainelPrincipal.Position = UDim2.new(0.5, -260, 0.5, -250)
PainelPrincipal.BackgroundColor3 = COR_FUNDO
PainelPrincipal.BorderSizePixel = 0
PainelPrincipal.Parent = gui

local UiScale = Instance.new("UIScale")
UiScale.Scale = 0
UiScale.Parent = PainelPrincipal

local cPainel = Instance.new("UICorner")
cPainel.CornerRadius = UDim.new(0, 12)
cPainel.Parent = PainelPrincipal

local BordaNeon = Instance.new("UIStroke")
BordaNeon.Color = COR_NEON_CIANO
BordaNeon.Thickness = 2
BordaNeon.Parent = PainelPrincipal

local BarraTitulo = Instance.new("Frame")
BarraTitulo.Size = UDim2.new(1, 0, 0, 50)
BarraTitulo.BackgroundColor3 = COR_FUNDO_SELECAO
BarraTitulo.BackgroundTransparency = 0.5
BarraTitulo.BorderSizePixel = 0
BarraTitulo.Parent = PainelPrincipal

Instance.new("UICorner", BarraTitulo).CornerRadius = UDim.new(0, 12)

local Titulo = Instance.new("TextLabel")
Titulo.Size = UDim2.new(1, -60, 1, 0)
Titulo.Position = UDim2.new(0, 20, 0, 0)
Titulo.BackgroundTransparency = 1
Titulo.Text = "👑 PAINEL DE COMANDO 👑"
Titulo.TextColor3 = COR_NEON_CIANO
Titulo.Font = Enum.Font.GothamBlack
Titulo.TextSize = 22
Titulo.TextXAlignment = Enum.TextXAlignment.Left
Titulo.Parent = BarraTitulo

local BtnFechar = Instance.new("TextButton")
BtnFechar.Size = UDim2.new(0, 40, 0, 40)
BtnFechar.Position = UDim2.new(1, -45, 0, 5)
BtnFechar.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
BtnFechar.Text = "❌"
BtnFechar.TextColor3 = COR_BRANCO
BtnFechar.TextSize = 18
BtnFechar.AutoButtonColor = true
BtnFechar.Parent = BarraTitulo
Instance.new("UICorner", BtnFechar).CornerRadius = UDim.new(1, 0)

local ContainerAbas = Instance.new("ScrollingFrame")
ContainerAbas.Size = UDim2.new(1, -40, 0, 45)
ContainerAbas.Position = UDim2.new(0, 20, 0, 60)
ContainerAbas.BackgroundTransparency = 1
ContainerAbas.CanvasSize = UDim2.new(1.8, 0, 0, 0)
ContainerAbas.ScrollBarThickness = 3
ContainerAbas.ScrollBarImageColor3 = COR_NEON_CIANO
ContainerAbas.Parent = PainelPrincipal

local AbaLayout = Instance.new("UIListLayout")
AbaLayout.FillDirection = Enum.FillDirection.Horizontal
AbaLayout.VerticalAlignment = Enum.VerticalAlignment.Top
AbaLayout.Padding = UDim.new(0, 8)
AbaLayout.Parent = ContainerAbas

local function criarAba(nome, texto)
	local btn = Instance.new("TextButton")
	btn.Name = nome
	btn.Size = UDim2.new(0, 95, 0, 35)
	btn.BackgroundColor3 = COR_FUNDO_SELECAO
	btn.Text = texto
	btn.TextColor3 = COR_BRANCO
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 11
	btn.AutoButtonColor = true
	btn.Parent = ContainerAbas
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	local st = Instance.new("UIStroke")
	st.Color = COR_NEON_CIANO
	st.Transparency = 1
	st.Parent = btn
	return btn
end

local BtnAbaDoacao = criarAba("AbaDoacao", "💎 VIP")
local BtnAbaSorteio = criarAba("AbaSorteio", "🎁 SORTEIO")
local BtnAbaEnquete = criarAba("AbaEnquete", "📊 ENQUETE")
local BtnAbaEventos = criarAba("AbaEventos", "⚡ EVENTOS")
local BtnAbaAvisos = criarAba("AbaAvisos", "📣 AVISOS")
local BtnAbaEco = criarAba("AbaEco", "💸 ECO/CARS")
local BtnAbaMundo = criarAba("AbaMundo", "⛅ MUNDO")

local AreaPaginas = Instance.new("Frame")
AreaPaginas.Size = UDim2.new(1, -40, 1, -130)
AreaPaginas.Position = UDim2.new(0, 20, 0, 115)
AreaPaginas.BackgroundTransparency = 1
AreaPaginas.Parent = PainelPrincipal

-- ========== Páginas (frames) ==========
local function novaPagina(nome)
	local f = Instance.new("Frame")
	f.Name = nome
	f.Size = UDim2.new(1, 0, 1, 0)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.Parent = AreaPaginas
	return f
end

local PaginaDoacao = novaPagina("PaginaDoacao")
local PaginaSorteio = novaPagina("PaginaSorteio")
local PaginaEnquete = novaPagina("PaginaEnquete")
local PaginaEventos = novaPagina("PaginaEventos")
local PaginaAvisos = novaPagina("PaginaAvisos")
local PaginaEco = novaPagina("PaginaEco")
local PaginaMundo = novaPagina("PaginaMundo")

local UIListLayoutDoacao = Instance.new("UIListLayout")
UIListLayoutDoacao.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayoutDoacao.Padding = UDim.new(0, 12)
UIListLayoutDoacao.Parent = PaginaDoacao

-- VIP (igual mestre: inclui REMOVER -1)
local FrameNome = Instance.new("Frame")
FrameNome.Size = UDim2.new(1, 0, 0, 60)
FrameNome.BackgroundTransparency = 1
FrameNome.LayoutOrder = 1
FrameNome.Parent = PaginaDoacao

local TxtNome = Instance.new("TextLabel")
TxtNome.Size = UDim2.new(1, 0, 0, 20)
TxtNome.BackgroundTransparency = 1
TxtNome.Text = "Nome do Piloto:"
TxtNome.TextColor3 = COR_BRANCO
TxtNome.Font = Enum.Font.GothamBold
TxtNome.TextSize = 14
TxtNome.TextXAlignment = Enum.TextXAlignment.Left
TxtNome.Parent = FrameNome

local InputNomeVip = Instance.new("TextBox")
InputNomeVip.Size = UDim2.new(1, 0, 0, 35)
InputNomeVip.Position = UDim2.new(0, 0, 0, 25)
InputNomeVip.BackgroundColor3 = COR_FUNDO_SELECAO
InputNomeVip.TextColor3 = COR_BRANCO
InputNomeVip.Font = Enum.Font.GothamMedium
InputNomeVip.TextSize = 14
InputNomeVip.PlaceholderText = "Nick..."
InputNomeVip.ClearTextOnFocus = false
InputNomeVip.Parent = FrameNome
Instance.new("UICorner", InputNomeVip).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", InputNomeVip).Color = COR_NEON_CIANO

local FrameVIP = Instance.new("Frame")
FrameVIP.Size = UDim2.new(1, 0, 0, 70)
FrameVIP.BackgroundTransparency = 1
FrameVIP.LayoutOrder = 2
FrameVIP.Parent = PaginaDoacao

local TxtVIP = Instance.new("TextLabel")
TxtVIP.Size = UDim2.new(1, 0, 0, 20)
TxtVIP.BackgroundTransparency = 1
TxtVIP.Text = "VIP:"
TxtVIP.TextColor3 = COR_BRANCO
TxtVIP.Font = Enum.Font.GothamBold
TxtVIP.TextSize = 14
TxtVIP.TextXAlignment = Enum.TextXAlignment.Left
TxtVIP.Parent = FrameVIP

local ContainerVIPs = Instance.new("Frame")
ContainerVIPs.Size = UDim2.new(1, 0, 0, 45)
ContainerVIPs.Position = UDim2.new(0, 0, 0, 25)
ContainerVIPs.BackgroundTransparency = 1
ContainerVIPs.Parent = FrameVIP

local UIListVIPs = Instance.new("UIListLayout")
UIListVIPs.FillDirection = Enum.FillDirection.Horizontal
UIListVIPs.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListVIPs.Padding = UDim.new(0, 12)
UIListVIPs.Parent = ContainerVIPs

local function criarBotaoOpcao(pai, nome, texto, emoji)
	local btn = Instance.new("TextButton")
	btn.Name = nome
	btn.Size = UDim2.new(0.31, 0, 1, 0)
	btn.BackgroundColor3 = COR_FUNDO_SELECAO
	btn.Text = emoji .. " " .. texto
	btn.TextColor3 = COR_BRANCO
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
	btn.AutoButtonColor = true
	btn.Parent = pai
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COR_NEON_CIANO
	stroke.Transparency = 1
	stroke.Parent = btn
	return btn
end

local BtnBronze = criarBotaoOpcao(ContainerVIPs, "Bronze", "BRONZE", "🥉")
local BtnGold = criarBotaoOpcao(ContainerVIPs, "Gold", "GOLD", "🥇")
local BtnDiamante = criarBotaoOpcao(ContainerVIPs, "Diamante", "DIAMANTE", "💎")

local FrameDias = Instance.new("Frame")
FrameDias.Size = UDim2.new(1, 0, 0, 70)
FrameDias.BackgroundTransparency = 1
FrameDias.LayoutOrder = 3
FrameDias.Parent = PaginaDoacao

local TxtDias = Instance.new("TextLabel")
TxtDias.Size = UDim2.new(1, 0, 0, 20)
TxtDias.BackgroundTransparency = 1
TxtDias.Text = "Dias:"
TxtDias.TextColor3 = COR_BRANCO
TxtDias.Font = Enum.Font.GothamBold
TxtDias.TextSize = 14
TxtDias.TextXAlignment = Enum.TextXAlignment.Left
TxtDias.Parent = FrameDias

local ContainerDias = Instance.new("Frame")
ContainerDias.Size = UDim2.new(1, 0, 0, 45)
ContainerDias.Position = UDim2.new(0, 0, 0, 25)
ContainerDias.BackgroundTransparency = 1
ContainerDias.Parent = FrameDias

local UIListDias = Instance.new("UIListLayout")
UIListDias.FillDirection = Enum.FillDirection.Horizontal
UIListDias.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListDias.Padding = UDim.new(0, 6)
UIListDias.Parent = ContainerDias

local function criarBotaoDia(pai, dias, emoji)
	local btn = Instance.new("TextButton")
	btn.Name = tostring(dias)
	btn.Size = UDim2.new(0.15, 0, 1, 0)
	btn.BackgroundColor3 = COR_FUNDO_SELECAO
	if dias == 0 then
		btn.Text = emoji .. " PERM"
	elseif dias == -1 then
		btn.Text = emoji .. " DEL"
	else
		btn.Text = emoji .. " " .. tostring(dias)
	end
	btn.TextColor3 = COR_BRANCO
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 12
	btn.AutoButtonColor = true
	btn.Parent = pai
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COR_NEON_CIANO
	stroke.Transparency = 1
	stroke.Parent = btn
	return btn
end

local BtnRemove = criarBotaoDia(ContainerDias, -1, "🗑️")
local BtnPerm = criarBotaoDia(ContainerDias, 0, "♾️")
local BtnDay1 = criarBotaoDia(ContainerDias, 1, "📅")
local BtnDay7 = criarBotaoDia(ContainerDias, 7, "📅")
local BtnDay15 = criarBotaoDia(ContainerDias, 15, "📅")
local BtnDay30 = criarBotaoDia(ContainerDias, 30, "📅")

local BtnConfirmarVip = Instance.new("TextButton")
BtnConfirmarVip.Size = UDim2.new(1, 0, 0, 45)
BtnConfirmarVip.BackgroundColor3 = COR_NEON_CIANO
BtnConfirmarVip.Text = "🤝 DOAR"
BtnConfirmarVip.TextColor3 = COR_FUNDO
BtnConfirmarVip.Font = Enum.Font.GothamBlack
BtnConfirmarVip.TextSize = 18
BtnConfirmarVip.LayoutOrder = 4
BtnConfirmarVip.AutoButtonColor = true
BtnConfirmarVip.Parent = PaginaDoacao
Instance.new("UICorner", BtnConfirmarVip).CornerRadius = UDim.new(0, 6)

local botoesVIPs = { BtnBronze, BtnGold, BtnDiamante }
local botoesDias = { BtnRemove, BtnPerm, BtnDay1, BtnDay7, BtnDay15, BtnDay30 }

-- ========== Enquete ==========
local UILEnquete = Instance.new("UIListLayout")
UILEnquete.Padding = UDim.new(0, 10)
UILEnquete.Parent = PaginaEnquete

local TxtEnqueteHelp = Instance.new("TextLabel")
TxtEnqueteHelp.Size = UDim2.new(1, 0, 0, 35)
TxtEnqueteHelp.BackgroundTransparency = 1
TxtEnqueteHelp.Text = "📊 Pergunta e duas opções (duração em segundos):"
TxtEnqueteHelp.TextColor3 = COR_BRANCO
TxtEnqueteHelp.Font = Enum.Font.GothamMedium
TxtEnqueteHelp.TextSize = 13
TxtEnqueteHelp.TextWrapped = true
TxtEnqueteHelp.Parent = PaginaEnquete

local InputPergunta = Instance.new("TextBox")
InputPergunta.Size = UDim2.new(1, 0, 0, 40)
InputPergunta.BackgroundColor3 = COR_FUNDO_SELECAO
InputPergunta.TextColor3 = COR_BRANCO
InputPergunta.Font = Enum.Font.GothamMedium
InputPergunta.TextSize = 14
InputPergunta.PlaceholderText = "Pergunta..."
InputPergunta.Parent = PaginaEnquete
Instance.new("UICorner", InputPergunta).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", InputPergunta).Color = COR_NEON_CIANO

local FrameOps = Instance.new("Frame")
FrameOps.Size = UDim2.new(1, 0, 0, 40)
FrameOps.BackgroundTransparency = 1
FrameOps.Parent = PaginaEnquete

local InputOpA = Instance.new("TextBox")
InputOpA.Size = UDim2.new(0.48, 0, 1, 0)
InputOpA.BackgroundColor3 = COR_FUNDO_SELECAO
InputOpA.TextColor3 = COR_BRANCO
InputOpA.Font = Enum.Font.GothamMedium
InputOpA.TextSize = 14
InputOpA.PlaceholderText = "Opção A"
InputOpA.Parent = FrameOps
Instance.new("UICorner", InputOpA).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", InputOpA).Color = Color3.fromRGB(0, 255, 127)

local InputOpB = Instance.new("TextBox")
InputOpB.Size = UDim2.new(0.48, 0, 1, 0)
InputOpB.Position = UDim2.new(0.52, 0, 0, 0)
InputOpB.BackgroundColor3 = COR_FUNDO_SELECAO
InputOpB.TextColor3 = COR_BRANCO
InputOpB.Font = Enum.Font.GothamMedium
InputOpB.TextSize = 14
InputOpB.PlaceholderText = "Opção B"
InputOpB.Parent = FrameOps
Instance.new("UICorner", InputOpB).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", InputOpB).Color = Color3.fromRGB(255, 100, 255)

local InputTempoEnq = Instance.new("TextBox")
InputTempoEnq.Size = UDim2.new(1, 0, 0, 35)
InputTempoEnq.BackgroundColor3 = COR_FUNDO_SELECAO
InputTempoEnq.TextColor3 = COR_BRANCO
InputTempoEnq.Font = Enum.Font.GothamMedium
InputTempoEnq.TextSize = 14
InputTempoEnq.PlaceholderText = "Segundos (ex: 60)"
InputTempoEnq.Parent = PaginaEnquete
Instance.new("UICorner", InputTempoEnq).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", InputTempoEnq).Color = COR_NEON_CIANO

local BtnLancarEnquete = Instance.new("TextButton")
BtnLancarEnquete.Size = UDim2.new(1, 0, 0, 45)
BtnLancarEnquete.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
BtnLancarEnquete.Text = "📢 LANÇAR ENQUETE GLOBAL"
BtnLancarEnquete.TextColor3 = COR_FUNDO
BtnLancarEnquete.Font = Enum.Font.GothamBlack
BtnLancarEnquete.TextSize = 16
BtnLancarEnquete.AutoButtonColor = true
BtnLancarEnquete.Parent = PaginaEnquete
Instance.new("UICorner", BtnLancarEnquete).CornerRadius = UDim.new(0, 6)

-- ========== Eventos ==========
local UIListLayoutEventos = Instance.new("UIListLayout")
UIListLayoutEventos.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayoutEventos.Padding = UDim.new(0, 15)
UIListLayoutEventos.Parent = PaginaEventos

local InfoEvento = Instance.new("Frame")
InfoEvento.Size = UDim2.new(1, 0, 0, 60)
InfoEvento.BackgroundColor3 = COR_FUNDO_SELECAO
InfoEvento.LayoutOrder = 1
InfoEvento.Parent = PaginaEventos
Instance.new("UICorner", InfoEvento).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", InfoEvento).Color = COR_NEON_ROXO

local TxtEventoInfo = Instance.new("TextLabel")
TxtEventoInfo.Size = UDim2.new(1, -20, 1, -20)
TxtEventoInfo.Position = UDim2.new(0, 10, 0, 10)
TxtEventoInfo.BackgroundTransparency = 1
TxtEventoInfo.Text = "🎉 EVENTO GLOBAL: multiplicador e duração"
TxtEventoInfo.TextColor3 = COR_BRANCO
TxtEventoInfo.Font = Enum.Font.GothamMedium
TxtEventoInfo.TextSize = 12
TxtEventoInfo.TextWrapped = true
TxtEventoInfo.Parent = InfoEvento

local FrameInputsEvent = Instance.new("Frame")
FrameInputsEvent.Size = UDim2.new(1, 0, 0, 110)
FrameInputsEvent.BackgroundTransparency = 1
FrameInputsEvent.LayoutOrder = 2
FrameInputsEvent.Parent = PaginaEventos

local TxtMult = Instance.new("TextLabel")
TxtMult.Size = UDim2.new(1, 0, 0, 20)
TxtMult.BackgroundTransparency = 1
TxtMult.Text = "Mult:"
TxtMult.TextColor3 = COR_BRANCO
TxtMult.Font = Enum.Font.GothamBold
TxtMult.TextSize = 12
TxtMult.TextXAlignment = Enum.TextXAlignment.Left
TxtMult.Parent = FrameInputsEvent

local InputMult = Instance.new("TextBox")
InputMult.Size = UDim2.new(1, 0, 0, 30)
InputMult.Position = UDim2.new(0, 0, 0, 20)
InputMult.BackgroundColor3 = COR_FUNDO_SELECAO
InputMult.TextColor3 = COR_BRANCO
InputMult.Font = Enum.Font.GothamMedium
InputMult.TextSize = 14
InputMult.PlaceholderText = "2"
InputMult.Parent = FrameInputsEvent
Instance.new("UICorner", InputMult).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", InputMult).Color = COR_NEON_ROXO

local TxtTempoEv = Instance.new("TextLabel")
TxtTempoEv.Size = UDim2.new(1, 0, 0, 20)
TxtTempoEv.Position = UDim2.new(0, 0, 0, 60)
TxtTempoEv.BackgroundTransparency = 1
TxtTempoEv.Text = "Duração (D H M S):"
TxtTempoEv.TextColor3 = COR_BRANCO
TxtTempoEv.Font = Enum.Font.GothamBold
TxtTempoEv.TextSize = 12
TxtTempoEv.TextXAlignment = Enum.TextXAlignment.Left
TxtTempoEv.Parent = FrameInputsEvent

local ContainerTempo = Instance.new("Frame")
ContainerTempo.Size = UDim2.new(1, 0, 0, 30)
ContainerTempo.Position = UDim2.new(0, 0, 0, 80)
ContainerTempo.BackgroundTransparency = 1
ContainerTempo.Parent = FrameInputsEvent

local LayoutTempo = Instance.new("UIListLayout")
LayoutTempo.FillDirection = Enum.FillDirection.Horizontal
LayoutTempo.Padding = UDim.new(0, 8)
LayoutTempo.Parent = ContainerTempo

local function criarInputTempo(nome, placeholder)
	local input = Instance.new("TextBox")
	input.Name = nome
	input.Size = UDim2.new(0.23, 0, 1, 0)
	input.BackgroundColor3 = COR_FUNDO_SELECAO
	input.TextColor3 = COR_BRANCO
	input.Font = Enum.Font.GothamMedium
	input.TextSize = 12
	input.PlaceholderText = placeholder
	input.Parent = ContainerTempo
	Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", input).Color = COR_NEON_ROXO
	return input
end

local InputDias = criarInputTempo("Dias", "Dias")
local InputHoras = criarInputTempo("Horas", "Horas")
local InputMinutos = criarInputTempo("Minutos", "Min")
local InputSegundos = criarInputTempo("Segundos", "Seg")

local BtnToggleEvento = Instance.new("TextButton")
BtnToggleEvento.Size = UDim2.new(1, 0, 0, 50)
BtnToggleEvento.BackgroundColor3 = COR_NEON_VERDE
BtnToggleEvento.Text = "🚀 INICIAR EVENTO"
BtnToggleEvento.TextColor3 = COR_FUNDO
BtnToggleEvento.Font = Enum.Font.GothamBlack
BtnToggleEvento.TextSize = 18
BtnToggleEvento.LayoutOrder = 3
BtnToggleEvento.AutoButtonColor = true
BtnToggleEvento.Parent = PaginaEventos
Instance.new("UICorner", BtnToggleEvento).CornerRadius = UDim.new(0, 8)

-- ========== Avisos ==========
local UILAvisos = Instance.new("UIListLayout")
UILAvisos.Padding = UDim.new(0, 12)
UILAvisos.Parent = PaginaAvisos

local TxtAvisoHelp = Instance.new("TextLabel")
TxtAvisoHelp.Size = UDim2.new(1, 0, 0, 40)
TxtAvisoHelp.BackgroundTransparency = 1
TxtAvisoHelp.Text = "📣 GLOBAL ou LOCAL:"
TxtAvisoHelp.TextColor3 = COR_BRANCO
TxtAvisoHelp.Font = Enum.Font.GothamMedium
TxtAvisoHelp.TextSize = 13
TxtAvisoHelp.TextWrapped = true
TxtAvisoHelp.Parent = PaginaAvisos

local FrameTipoAviso = Instance.new("Frame")
FrameTipoAviso.Size = UDim2.new(1, 0, 0, 45)
FrameTipoAviso.BackgroundTransparency = 1
FrameTipoAviso.Parent = PaginaAvisos

local BtnAvisoGlobal = Instance.new("TextButton")
BtnAvisoGlobal.Size = UDim2.new(0.48, 0, 1, 0)
BtnAvisoGlobal.BackgroundColor3 = COR_NEON_CIANO
BtnAvisoGlobal.Text = "🌍 GLOBAL"
BtnAvisoGlobal.TextColor3 = COR_FUNDO
BtnAvisoGlobal.Font = Enum.Font.GothamBlack
BtnAvisoGlobal.TextSize = 14
BtnAvisoGlobal.AutoButtonColor = true
BtnAvisoGlobal.Parent = FrameTipoAviso
Instance.new("UICorner", BtnAvisoGlobal).CornerRadius = UDim.new(0, 6)
local StrAG = Instance.new("UIStroke", BtnAvisoGlobal)
StrAG.Color = COR_NEON_CIANO
StrAG.Transparency = 0

local BtnAvisoLocal = Instance.new("TextButton")
BtnAvisoLocal.Size = UDim2.new(0.48, 0, 1, 0)
BtnAvisoLocal.Position = UDim2.new(0.52, 0, 0, 0)
BtnAvisoLocal.BackgroundColor3 = COR_FUNDO_SELECAO
BtnAvisoLocal.Text = "📍 LOCAL"
BtnAvisoLocal.TextColor3 = COR_BRANCO
BtnAvisoLocal.Font = Enum.Font.GothamBlack
BtnAvisoLocal.TextSize = 14
BtnAvisoLocal.AutoButtonColor = true
BtnAvisoLocal.Parent = FrameTipoAviso
Instance.new("UICorner", BtnAvisoLocal).CornerRadius = UDim.new(0, 6)
local StrAL = Instance.new("UIStroke", BtnAvisoLocal)
StrAL.Color = Color3.fromRGB(255, 170, 0)
StrAL.Transparency = 1

local InputAviso = Instance.new("TextBox")
InputAviso.Size = UDim2.new(1, 0, 0, 90)
InputAviso.BackgroundColor3 = COR_FUNDO_SELECAO
InputAviso.TextColor3 = COR_BRANCO
InputAviso.Font = Enum.Font.GothamMedium
InputAviso.TextSize = 16
InputAviso.PlaceholderText = "Aviso..."
InputAviso.TextWrapped = true
InputAviso.TextYAlignment = Enum.TextYAlignment.Top
InputAviso.ClearTextOnFocus = false
InputAviso.Parent = PaginaAvisos
Instance.new("UICorner", InputAviso).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", InputAviso).Color = COR_NEON_CIANO

local BtnEnviarAviso = Instance.new("TextButton")
BtnEnviarAviso.Size = UDim2.new(1, 0, 0, 50)
BtnEnviarAviso.BackgroundColor3 = COR_NEON_CIANO
BtnEnviarAviso.Text = "📣 ENVIAR"
BtnEnviarAviso.TextColor3 = COR_FUNDO
BtnEnviarAviso.Font = Enum.Font.GothamBlack
BtnEnviarAviso.TextSize = 18
BtnEnviarAviso.AutoButtonColor = true
BtnEnviarAviso.Parent = PaginaAvisos
Instance.new("UICorner", BtnEnviarAviso).CornerRadius = UDim.new(0, 8)

-- ========== Eco ==========
local UILEco = Instance.new("UIListLayout")
UILEco.Padding = UDim.new(0, 15)
UILEco.Parent = PaginaEco

local FrameNomeEco = Instance.new("Frame")
FrameNomeEco.Size = UDim2.new(1, 0, 0, 60)
FrameNomeEco.BackgroundTransparency = 1
FrameNomeEco.Parent = PaginaEco

local TxtNomeEco = Instance.new("TextLabel")
TxtNomeEco.Size = UDim2.new(1, 0, 0, 20)
TxtNomeEco.BackgroundTransparency = 1
TxtNomeEco.Text = "Nick:"
TxtNomeEco.TextColor3 = COR_BRANCO
TxtNomeEco.Font = Enum.Font.GothamBold
TxtNomeEco.TextSize = 14
TxtNomeEco.TextXAlignment = Enum.TextXAlignment.Left
TxtNomeEco.Parent = FrameNomeEco

local InputNomeEco = Instance.new("TextBox")
InputNomeEco.Size = UDim2.new(1, 0, 0, 35)
InputNomeEco.Position = UDim2.new(0, 0, 0, 25)
InputNomeEco.BackgroundColor3 = COR_FUNDO_SELECAO
InputNomeEco.TextColor3 = COR_BRANCO
InputNomeEco.Font = Enum.Font.GothamMedium
InputNomeEco.TextSize = 14
InputNomeEco.PlaceholderText = "Nick"
InputNomeEco.Parent = FrameNomeEco
Instance.new("UICorner", InputNomeEco).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", InputNomeEco).Color = Color3.fromRGB(50, 255, 100)

local FrameTipoEco = Instance.new("Frame")
FrameTipoEco.Size = UDim2.new(1, 0, 0, 60)
FrameTipoEco.BackgroundTransparency = 1
FrameTipoEco.Parent = PaginaEco

local TxtTipoEco = Instance.new("TextLabel")
TxtTipoEco.Size = UDim2.new(1, 0, 0, 20)
TxtTipoEco.BackgroundTransparency = 1
TxtTipoEco.Text = "Tipo:"
TxtTipoEco.TextColor3 = COR_BRANCO
TxtTipoEco.Font = Enum.Font.GothamBold
TxtTipoEco.TextSize = 14
TxtTipoEco.TextXAlignment = Enum.TextXAlignment.Left
TxtTipoEco.Parent = FrameTipoEco

local ContainerTipoEco = Instance.new("Frame")
ContainerTipoEco.Size = UDim2.new(1, 0, 0, 35)
ContainerTipoEco.Position = UDim2.new(0, 0, 0, 25)
ContainerTipoEco.BackgroundTransparency = 1
ContainerTipoEco.Parent = FrameTipoEco

local BtnDinheiro = Instance.new("TextButton")
BtnDinheiro.Size = UDim2.new(0.32, 0, 1, 0)
BtnDinheiro.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
BtnDinheiro.Text = "💵 DINHEIRO"
BtnDinheiro.TextColor3 = COR_FUNDO
BtnDinheiro.Font = Enum.Font.GothamBlack
BtnDinheiro.TextSize = 12
BtnDinheiro.AutoButtonColor = true
BtnDinheiro.Parent = ContainerTipoEco
Instance.new("UICorner", BtnDinheiro).CornerRadius = UDim.new(0, 6)
local StrD = Instance.new("UIStroke", BtnDinheiro)
StrD.Color = Color3.fromRGB(50, 255, 100)
StrD.Transparency = 0

local BtnXP = Instance.new("TextButton")
BtnXP.Size = UDim2.new(0.32, 0, 1, 0)
BtnXP.Position = UDim2.new(0.34, 0, 0, 0)
BtnXP.BackgroundColor3 = COR_FUNDO_SELECAO
BtnXP.Text = "⭐ XP"
BtnXP.TextColor3 = COR_BRANCO
BtnXP.Font = Enum.Font.GothamBlack
BtnXP.TextSize = 12
BtnXP.AutoButtonColor = true
BtnXP.Parent = ContainerTipoEco
Instance.new("UICorner", BtnXP).CornerRadius = UDim.new(0, 6)
local StrX = Instance.new("UIStroke", BtnXP)
StrX.Color = COR_NEON_CIANO
StrX.Transparency = 1

local BtnCarro = Instance.new("TextButton")
BtnCarro.Size = UDim2.new(0.32, 0, 1, 0)
BtnCarro.Position = UDim2.new(0.68, 0, 0, 0)
BtnCarro.BackgroundColor3 = COR_FUNDO_SELECAO
BtnCarro.Text = "🚗 CARRO"
BtnCarro.TextColor3 = COR_BRANCO
BtnCarro.Font = Enum.Font.GothamBlack
BtnCarro.TextSize = 12
BtnCarro.AutoButtonColor = true
BtnCarro.Parent = ContainerTipoEco
Instance.new("UICorner", BtnCarro).CornerRadius = UDim.new(0, 6)
local StrC = Instance.new("UIStroke", BtnCarro)
StrC.Color = Color3.fromRGB(255, 150, 0)
StrC.Transparency = 1

local FrameValorEco = Instance.new("Frame")
FrameValorEco.Size = UDim2.new(1, 0, 0, 60)
FrameValorEco.BackgroundTransparency = 1
FrameValorEco.Parent = PaginaEco

local TxtValorEco = Instance.new("TextLabel")
TxtValorEco.Size = UDim2.new(1, 0, 0, 20)
TxtValorEco.BackgroundTransparency = 1
TxtValorEco.Text = "Valor:"
TxtValorEco.TextColor3 = COR_BRANCO
TxtValorEco.Font = Enum.Font.GothamBold
TxtValorEco.TextSize = 14
TxtValorEco.TextXAlignment = Enum.TextXAlignment.Left
TxtValorEco.Parent = FrameValorEco

local InputValorEco = Instance.new("TextBox")
InputValorEco.Size = UDim2.new(1, 0, 0, 35)
InputValorEco.Position = UDim2.new(0, 0, 0, 25)
InputValorEco.BackgroundColor3 = COR_FUNDO_SELECAO
InputValorEco.TextColor3 = COR_BRANCO
InputValorEco.Font = Enum.Font.GothamBlack
InputValorEco.TextSize = 16
InputValorEco.PlaceholderText = "50000"
InputValorEco.Parent = FrameValorEco
Instance.new("UICorner", InputValorEco).CornerRadius = UDim.new(0, 6)
local strokeValorEco = Instance.new("UIStroke", InputValorEco)
strokeValorEco.Color = Color3.fromRGB(50, 255, 100)

local BtnEnviarEco = Instance.new("TextButton")
BtnEnviarEco.Size = UDim2.new(1, 0, 0, 45)
BtnEnviarEco.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
BtnEnviarEco.Text = "💸 DEPOSITAR"
BtnEnviarEco.TextColor3 = COR_FUNDO
BtnEnviarEco.Font = Enum.Font.GothamBlack
BtnEnviarEco.TextSize = 18
BtnEnviarEco.AutoButtonColor = true
BtnEnviarEco.Parent = PaginaEco
Instance.new("UICorner", BtnEnviarEco).CornerRadius = UDim.new(0, 6)

-- ========== Mundo ==========
local UILMundo = Instance.new("UIListLayout")
UILMundo.Padding = UDim.new(0, 15)
UILMundo.Parent = PaginaMundo

local TxtMundoHelp = Instance.new("TextLabel")
TxtMundoHelp.Size = UDim2.new(1, 0, 0, 40)
TxtMundoHelp.BackgroundTransparency = 1
TxtMundoHelp.Text = "⛅ Clima global:"
TxtMundoHelp.TextColor3 = COR_BRANCO
TxtMundoHelp.Font = Enum.Font.GothamMedium
TxtMundoHelp.TextSize = 13
TxtMundoHelp.TextWrapped = true
TxtMundoHelp.Parent = PaginaMundo

local GridMundo = Instance.new("Frame")
GridMundo.Size = UDim2.new(1, 0, 0, 150)
GridMundo.BackgroundTransparency = 1
GridMundo.Parent = PaginaMundo

local UIGridMundo = Instance.new("UIGridLayout")
UIGridMundo.CellSize = UDim2.new(0.48, 0, 0, 65)
UIGridMundo.CellPadding = UDim2.new(0, 10, 0, 15)
UIGridMundo.Parent = GridMundo

local function criarBtnClima(pai, nome, icone, cor)
	local btn = Instance.new("TextButton")
	btn.Name = nome
	btn.BackgroundColor3 = COR_FUNDO_SELECAO
	btn.Text = icone .. " " .. nome
	btn.TextColor3 = cor
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 16
	btn.AutoButtonColor = true
	btn.Parent = pai
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	local str = Instance.new("UIStroke", btn)
	str.Color = cor
	str.Thickness = 1.5
	btn.Activated:Connect(function()
		if not evMundoAdmin then
			return
		end
		local txt = icone .. " " .. nome
		btn.Text = "⏳..."
		pcall(function()
			evMundoAdmin:FireServer(nome)
		end)
		task.delay(1, function()
			btn.Text = "✅"
		end)
		task.delay(2.5, function()
			btn.Text = txt
		end)
	end)
	return btn
end

criarBtnClima(GridMundo, "Dia", "☀️", Color3.fromRGB(255, 200, 0))
criarBtnClima(GridMundo, "Noite", "🌙", Color3.fromRGB(150, 150, 255))
criarBtnClima(GridMundo, "Limpo", "🌤️", Color3.fromRGB(0, 255, 255))
criarBtnClima(GridMundo, "Chuva", "🌧️", Color3.fromRGB(100, 100, 150))

-- ========== Sorteio ==========
local UILSorteio = Instance.new("UIListLayout")
UILSorteio.Padding = UDim.new(0, 15)
UILSorteio.Parent = PaginaSorteio

local TxtSorteioHelp = Instance.new("TextLabel")
TxtSorteioHelp.Size = UDim2.new(1, 0, 0, 40)
TxtSorteioHelp.BackgroundTransparency = 1
TxtSorteioHelp.Text = "🎁 Prêmio aleatório para jogadores:"
TxtSorteioHelp.TextColor3 = COR_BRANCO
TxtSorteioHelp.Font = Enum.Font.GothamMedium
TxtSorteioHelp.TextSize = 13
TxtSorteioHelp.TextWrapped = true
TxtSorteioHelp.Parent = PaginaSorteio

local FrameTipoSort = Instance.new("Frame")
FrameTipoSort.Size = UDim2.new(1, 0, 0, 60)
FrameTipoSort.BackgroundTransparency = 1
FrameTipoSort.Parent = PaginaSorteio

local TxtTipoSort = Instance.new("TextLabel")
TxtTipoSort.Size = UDim2.new(1, 0, 0, 20)
TxtTipoSort.BackgroundTransparency = 1
TxtTipoSort.Text = "Tipo de prêmio:"
TxtTipoSort.TextColor3 = COR_BRANCO
TxtTipoSort.Font = Enum.Font.GothamBold
TxtTipoSort.TextSize = 14
TxtTipoSort.TextXAlignment = Enum.TextXAlignment.Left
TxtTipoSort.Parent = FrameTipoSort

local ContainerTipoSort = Instance.new("Frame")
ContainerTipoSort.Size = UDim2.new(1, 0, 0, 35)
ContainerTipoSort.Position = UDim2.new(0, 0, 0, 25)
ContainerTipoSort.BackgroundTransparency = 1
ContainerTipoSort.Parent = FrameTipoSort

local BtnSortDinheiro = Instance.new("TextButton")
BtnSortDinheiro.Size = UDim2.new(0.32, 0, 1, 0)
BtnSortDinheiro.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
BtnSortDinheiro.Text = "💵 DINHEIRO"
BtnSortDinheiro.TextColor3 = COR_FUNDO
BtnSortDinheiro.Font = Enum.Font.GothamBlack
BtnSortDinheiro.TextSize = 12
BtnSortDinheiro.AutoButtonColor = true
BtnSortDinheiro.Parent = ContainerTipoSort
Instance.new("UICorner", BtnSortDinheiro).CornerRadius = UDim.new(0, 6)
local StrSD = Instance.new("UIStroke", BtnSortDinheiro)
StrSD.Color = Color3.fromRGB(50, 255, 100)
StrSD.Transparency = 0

local BtnSortXP = Instance.new("TextButton")
BtnSortXP.Size = UDim2.new(0.32, 0, 1, 0)
BtnSortXP.Position = UDim2.new(0.34, 0, 0, 0)
BtnSortXP.BackgroundColor3 = COR_FUNDO_SELECAO
BtnSortXP.Text = "⭐ XP"
BtnSortXP.TextColor3 = COR_BRANCO
BtnSortXP.Font = Enum.Font.GothamBlack
BtnSortXP.TextSize = 12
BtnSortXP.AutoButtonColor = true
BtnSortXP.Parent = ContainerTipoSort
Instance.new("UICorner", BtnSortXP).CornerRadius = UDim.new(0, 6)
local StrSX = Instance.new("UIStroke", BtnSortXP)
StrSX.Color = COR_NEON_CIANO
StrSX.Transparency = 1

local BtnSortCarro = Instance.new("TextButton")
BtnSortCarro.Size = UDim2.new(0.32, 0, 1, 0)
BtnSortCarro.Position = UDim2.new(0.68, 0, 0, 0)
BtnSortCarro.BackgroundColor3 = COR_FUNDO_SELECAO
BtnSortCarro.Text = "🚗 VEÍCULO"
BtnSortCarro.TextColor3 = COR_BRANCO
BtnSortCarro.Font = Enum.Font.GothamBlack
BtnSortCarro.TextSize = 12
BtnSortCarro.AutoButtonColor = true
BtnSortCarro.Parent = ContainerTipoSort
Instance.new("UICorner", BtnSortCarro).CornerRadius = UDim.new(0, 6)
local StrSC = Instance.new("UIStroke", BtnSortCarro)
StrSC.Color = Color3.fromRGB(255, 150, 0)
StrSC.Transparency = 1

local FrameValorSort = Instance.new("Frame")
FrameValorSort.Size = UDim2.new(1, 0, 0, 60)
FrameValorSort.BackgroundTransparency = 1
FrameValorSort.Parent = PaginaSorteio

local TxtValorSort = Instance.new("TextLabel")
TxtValorSort.Size = UDim2.new(1, 0, 0, 20)
TxtValorSort.BackgroundTransparency = 1
TxtValorSort.Text = "Valor do prêmio:"
TxtValorSort.TextColor3 = COR_BRANCO
TxtValorSort.Font = Enum.Font.GothamBold
TxtValorSort.TextSize = 14
TxtValorSort.TextXAlignment = Enum.TextXAlignment.Left
TxtValorSort.Parent = FrameValorSort

local InputValorSort = Instance.new("TextBox")
InputValorSort.Size = UDim2.new(1, 0, 0, 35)
InputValorSort.Position = UDim2.new(0, 0, 0, 25)
InputValorSort.BackgroundColor3 = COR_FUNDO_SELECAO
InputValorSort.TextColor3 = COR_BRANCO
InputValorSort.Font = Enum.Font.GothamBlack
InputValorSort.TextSize = 16
InputValorSort.PlaceholderText = "Ex: 50000"
InputValorSort.Parent = FrameValorSort
Instance.new("UICorner", InputValorSort).CornerRadius = UDim.new(0, 6)
local strokeValorSort = Instance.new("UIStroke", InputValorSort)
strokeValorSort.Color = Color3.fromRGB(50, 255, 100)

local BtnIniciarSorteio = Instance.new("TextButton")
BtnIniciarSorteio.Size = UDim2.new(1, 0, 0, 45)
BtnIniciarSorteio.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
BtnIniciarSorteio.Text = "🎲 INICIAR SORTEIO"
BtnIniciarSorteio.TextColor3 = COR_FUNDO
BtnIniciarSorteio.Font = Enum.Font.GothamBlack
BtnIniciarSorteio.TextSize = 18
BtnIniciarSorteio.AutoButtonColor = true
BtnIniciarSorteio.Parent = PaginaSorteio
Instance.new("UICorner", BtnIniciarSorteio).CornerRadius = UDim.new(0, 6)

-- ========== Navegação abas ==========
local abasInfo = {
	{ btn = BtnAbaDoacao, pag = PaginaDoacao, corSel = COR_NEON_CIANO, textoEscuro = true },
	{ btn = BtnAbaSorteio, pag = PaginaSorteio, corSel = Color3.fromRGB(255, 215, 0), textoEscuro = true },
	{ btn = BtnAbaEnquete, pag = PaginaEnquete, corSel = Color3.fromRGB(0, 150, 255), textoEscuro = true },
	{ btn = BtnAbaEventos, pag = PaginaEventos, corSel = COR_NEON_ROXO, textoEscuro = false },
	{ btn = BtnAbaAvisos, pag = PaginaAvisos, corSel = Color3.fromRGB(255, 150, 0), textoEscuro = true },
	{ btn = BtnAbaEco, pag = PaginaEco, corSel = Color3.fromRGB(50, 255, 100), textoEscuro = true },
	{ btn = BtnAbaMundo, pag = PaginaMundo, corSel = Color3.fromRGB(0, 150, 255), textoEscuro = false },
}

local function esconderTodasPaginas()
	PaginaDoacao.Visible = false
	PaginaSorteio.Visible = false
	PaginaEnquete.Visible = false
	PaginaEventos.Visible = false
	PaginaAvisos.Visible = false
	PaginaEco.Visible = false
	PaginaMundo.Visible = false
	for _, info in ipairs(abasInfo) do
		info.btn.BackgroundColor3 = COR_FUNDO_SELECAO
		info.btn.TextColor3 = COR_BRANCO
		local s = strokeOf(info.btn)
		if s then
			s.Transparency = 1
		end
	end
end

local function mostrarAba(info)
	esconderTodasPaginas()
	info.pag.Visible = true
	info.btn.BackgroundColor3 = info.corSel
	info.btn.TextColor3 = info.textoEscuro and COR_FUNDO or COR_BRANCO
	local s = strokeOf(info.btn)
	if s then
		s.Transparency = 0
	end
end

for _, info in ipairs(abasInfo) do
	info.btn.Activated:Connect(function()
		mostrarAba(info)
	end)
end

mostrarAba(abasInfo[1])

-- ========== VIP estilo + ações ==========
local function atualizarEstiloVIPeDias(lista, vs, selCor)
	for _, b in ipairs(lista) do
		local s = strokeOf(b)
		if b.Name == tostring(vs) then
			local c = selCor
			if b.Name == "-1" then
				c = COR_NEON_VERMELHO
			end
			b.BackgroundColor3 = c
			b.TextColor3 = COR_FUNDO
			if s then
				s.Color = c
				s.Transparency = 0
			end
		else
			b.BackgroundColor3 = COR_FUNDO_SELECAO
			b.TextColor3 = COR_BRANCO
			if s then
				s.Transparency = 1
			end
		end
	end
end

atualizarEstiloVIPeDias(botoesVIPs, vipSelecionado, COR_NEON_CIANO)
atualizarEstiloVIPeDias(botoesDias, diasSelecionados, COR_NEON_CIANO)

for _, btn in ipairs(botoesVIPs) do
	btn.Activated:Connect(function()
		vipSelecionado = btn.Name
		atualizarEstiloVIPeDias(botoesVIPs, vipSelecionado, COR_NEON_CIANO)
	end)
end

for _, btn in ipairs(botoesDias) do
	btn.Activated:Connect(function()
		diasSelecionados = tonumber(btn.Name) or 0
		atualizarEstiloVIPeDias(botoesDias, diasSelecionados, COR_NEON_CIANO)
		if diasSelecionados == -1 then
			BtnConfirmarVip.Text = "🗑️ REMOVER"
			BtnConfirmarVip.BackgroundColor3 = COR_NEON_VERMELHO
			BtnConfirmarVip.TextColor3 = COR_BRANCO
		else
			BtnConfirmarVip.Text = "🤝 DOAR"
			BtnConfirmarVip.BackgroundColor3 = COR_NEON_CIANO
			BtnConfirmarVip.TextColor3 = COR_FUNDO
		end
	end)
end

local vipEnviando = false
BtnConfirmarVip.Activated:Connect(function()
	if vipEnviando then
		return
	end
	local nome = InputNomeVip.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if nome == "" then
		return
	end
	if #nome > NICK_MAX_LEN then
		nome = string.sub(nome, 1, NICK_MAX_LEN)
		InputNomeVip.Text = nome
	end
	if not evAdmin then
		warn("[PainelMestre] DoarVipCrossServer indisponível.")
		return
	end
	vipEnviando = true
	BtnConfirmarVip.Text = "⏳..."
	BtnConfirmarVip.Interactable = false
	local ok, err = pcall(function()
		evAdmin:FireServer(nome, vipSelecionado, diasSelecionados)
	end)
	if not ok then
		warn("[PainelMestre] FireServer VIP:", err)
	end
	task.delay(DEBOUNCE_VIP, function()
		vipEnviando = false
		BtnConfirmarVip.Interactable = true
		if diasSelecionados == -1 then
			BtnConfirmarVip.Text = "🗑️ REMOVER"
			BtnConfirmarVip.BackgroundColor3 = COR_NEON_VERMELHO
			BtnConfirmarVip.TextColor3 = COR_BRANCO
		else
			BtnConfirmarVip.Text = "🤝 DOAR"
			BtnConfirmarVip.BackgroundColor3 = COR_NEON_CIANO
			BtnConfirmarVip.TextColor3 = COR_FUNDO
		end
	end)
end)

if evNotificarTela then
	evNotificarTela.OnClientEvent:Connect(function(ativo, mult)
		eventoDoubleLigado = ativo
		if ativo then
			BtnToggleEvento.Text = "🛑 PARAR " .. tostring(mult or "?") .. "X"
			BtnToggleEvento.BackgroundColor3 = COR_NEON_VERMELHO
		else
			BtnToggleEvento.Text = "🚀 INICIAR EVENTO"
			BtnToggleEvento.BackgroundColor3 = COR_NEON_VERDE
		end
		BtnToggleEvento.Interactable = true
	end)
end

BtnToggleEvento.Activated:Connect(function()
	if not evEventoGlobal then
		return
	end
	BtnToggleEvento.Interactable = false
	BtnToggleEvento.Text = "⏳..."
	if eventoDoubleLigado then
		pcall(function()
			evEventoGlobal:FireServer("Parar")
		end)
	else
		local d = tonumber(InputDias.Text) or 0
		local h = tonumber(InputHoras.Text) or 0
		local m = tonumber(InputMinutos.Text) or 0
		local s = tonumber(InputSegundos.Text) or 0
		pcall(function()
			evEventoGlobal:FireServer("Iniciar", tonumber(InputMult.Text) or 2, (d * 86400) + (h * 3600) + (m * 60) + s)
		end)
	end
	task.delay(2, function()
		BtnToggleEvento.Interactable = true
		if not eventoDoubleLigado then
			BtnToggleEvento.Text = "🚀 INICIAR EVENTO"
		end
	end)
end)

BtnAvisoGlobal.Activated:Connect(function()
	isAvisoGlobal = true
	BtnAvisoGlobal.BackgroundColor3 = COR_NEON_CIANO
	BtnAvisoGlobal.TextColor3 = COR_FUNDO
	StrAG.Transparency = 0
	BtnAvisoLocal.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnAvisoLocal.TextColor3 = COR_BRANCO
	StrAL.Transparency = 1
end)

BtnAvisoLocal.Activated:Connect(function()
	isAvisoGlobal = false
	BtnAvisoLocal.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	BtnAvisoLocal.TextColor3 = COR_FUNDO
	StrAL.Transparency = 0
	BtnAvisoGlobal.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnAvisoGlobal.TextColor3 = COR_BRANCO
	StrAG.Transparency = 1
end)

BtnEnviarAviso.Activated:Connect(function()
	if InputAviso.Text == "" or not evAnuncioAdmin then
		return
	end
	BtnEnviarAviso.Text = "⏳..."
	BtnEnviarAviso.Interactable = false
	pcall(function()
		evAnuncioAdmin:FireServer(InputAviso.Text, isAvisoGlobal)
	end)
	task.delay(1, function()
		BtnEnviarAviso.Text = "✅"
		BtnEnviarAviso.BackgroundColor3 = COR_NEON_VERDE
	end)
	task.delay(3, function()
		BtnEnviarAviso.Text = "📣 ENVIAR"
		BtnEnviarAviso.BackgroundColor3 = COR_NEON_CIANO
		BtnEnviarAviso.Interactable = true
		InputAviso.Text = ""
	end)
end)

BtnDinheiro.Activated:Connect(function()
	moedaEcoSelecionada = "Dinheiro"
	InputValorEco.PlaceholderText = "Ex: 50000"
	BtnDinheiro.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
	BtnDinheiro.TextColor3 = COR_FUNDO
	StrD.Transparency = 0
	BtnXP.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnXP.TextColor3 = COR_BRANCO
	StrX.Transparency = 1
	BtnCarro.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnCarro.TextColor3 = COR_BRANCO
	StrC.Transparency = 1
	strokeValorEco.Color = Color3.fromRGB(50, 255, 100)
	BtnEnviarEco.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
	BtnEnviarEco.Text = "💸 DEPOSITAR"
end)

BtnXP.Activated:Connect(function()
	moedaEcoSelecionada = "XP"
	InputValorEco.PlaceholderText = "Ex: 5000"
	BtnXP.BackgroundColor3 = COR_NEON_CIANO
	BtnXP.TextColor3 = COR_FUNDO
	StrX.Transparency = 0
	BtnDinheiro.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnDinheiro.TextColor3 = COR_BRANCO
	StrD.Transparency = 1
	BtnCarro.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnCarro.TextColor3 = COR_BRANCO
	StrC.Transparency = 1
	strokeValorEco.Color = COR_NEON_CIANO
	BtnEnviarEco.BackgroundColor3 = COR_NEON_CIANO
	BtnEnviarEco.Text = "⭐ INJETAR XP"
end)

BtnCarro.Activated:Connect(function()
	moedaEcoSelecionada = "Carro"
	InputValorEco.PlaceholderText = "Ex: Porsche"
	BtnCarro.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
	BtnCarro.TextColor3 = COR_FUNDO
	StrC.Transparency = 0
	BtnDinheiro.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnDinheiro.TextColor3 = COR_BRANCO
	StrD.Transparency = 1
	BtnXP.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnXP.TextColor3 = COR_BRANCO
	StrX.Transparency = 1
	strokeValorEco.Color = Color3.fromRGB(255, 150, 0)
	BtnEnviarEco.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
	BtnEnviarEco.Text = "🚗 ENTREGAR VEÍCULO"
end)

BtnEnviarEco.Activated:Connect(function()
	if InputNomeEco.Text == "" or InputValorEco.Text == "" or not evEconomiaAdmin then
		return
	end
	BtnEnviarEco.Text = "⏳..."
	BtnEnviarEco.Interactable = false
	pcall(function()
		evEconomiaAdmin:FireServer(InputNomeEco.Text, moedaEcoSelecionada, InputValorEco.Text)
	end)
	task.delay(1, function()
		BtnEnviarEco.Text = "✅"
		BtnEnviarEco.BackgroundColor3 = COR_NEON_VERDE
	end)
	task.delay(3, function()
		if moedaEcoSelecionada == "Dinheiro" then
			BtnEnviarEco.Text = "💸 DEPOSITAR"
			BtnEnviarEco.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
		elseif moedaEcoSelecionada == "XP" then
			BtnEnviarEco.Text = "⭐ INJETAR XP"
			BtnEnviarEco.BackgroundColor3 = COR_NEON_CIANO
		else
			BtnEnviarEco.Text = "🚗 ENTREGAR"
			BtnEnviarEco.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
		end
		BtnEnviarEco.Interactable = true
		InputNomeEco.Text = ""
		InputValorEco.Text = ""
	end)
end)

BtnSortDinheiro.Activated:Connect(function()
	moedaSorteioSelecionada = "Dinheiro"
	InputValorSort.PlaceholderText = "Ex: 100000"
	BtnSortDinheiro.BackgroundColor3 = Color3.fromRGB(50, 255, 100)
	BtnSortDinheiro.TextColor3 = COR_FUNDO
	StrSD.Transparency = 0
	BtnSortXP.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnSortXP.TextColor3 = COR_BRANCO
	StrSX.Transparency = 1
	BtnSortCarro.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnSortCarro.TextColor3 = COR_BRANCO
	StrSC.Transparency = 1
	strokeValorSort.Color = Color3.fromRGB(50, 255, 100)
end)

BtnSortXP.Activated:Connect(function()
	moedaSorteioSelecionada = "XP"
	InputValorSort.PlaceholderText = "Ex: 5000"
	BtnSortXP.BackgroundColor3 = COR_NEON_CIANO
	BtnSortXP.TextColor3 = COR_FUNDO
	StrSX.Transparency = 0
	BtnSortDinheiro.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnSortDinheiro.TextColor3 = COR_BRANCO
	StrSD.Transparency = 1
	BtnSortCarro.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnSortCarro.TextColor3 = COR_BRANCO
	StrSC.Transparency = 1
	strokeValorSort.Color = COR_NEON_CIANO
end)

BtnSortCarro.Activated:Connect(function()
	moedaSorteioSelecionada = "Carro"
	InputValorSort.PlaceholderText = "Ex: Fusca"
	BtnSortCarro.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
	BtnSortCarro.TextColor3 = COR_FUNDO
	StrSC.Transparency = 0
	BtnSortDinheiro.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnSortDinheiro.TextColor3 = COR_BRANCO
	StrSD.Transparency = 1
	BtnSortXP.BackgroundColor3 = COR_FUNDO_SELECAO
	BtnSortXP.TextColor3 = COR_BRANCO
	StrSX.Transparency = 1
	strokeValorSort.Color = Color3.fromRGB(255, 150, 0)
end)

BtnIniciarSorteio.Activated:Connect(function()
	if InputValorSort.Text == "" or not evSorteioAdmin then
		return
	end
	BtnIniciarSorteio.Text = "⏳..."
	BtnIniciarSorteio.Interactable = false
	pcall(function()
		evSorteioAdmin:FireServer(moedaSorteioSelecionada, InputValorSort.Text)
	end)
	task.delay(1.5, function()
		BtnIniciarSorteio.Text = "✅ NO AR"
		BtnIniciarSorteio.BackgroundColor3 = COR_NEON_VERDE
	end)
	task.delay(11, function()
		BtnIniciarSorteio.Text = "🎲 INICIAR SORTEIO"
		BtnIniciarSorteio.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
		BtnIniciarSorteio.Interactable = true
		InputValorSort.Text = ""
	end)
end)

BtnLancarEnquete.Activated:Connect(function()
	if InputPergunta.Text == "" or InputOpA.Text == "" or InputOpB.Text == "" or not evEnqueteAdmin then
		return
	end
	BtnLancarEnquete.Text = "⏳..."
	BtnLancarEnquete.Interactable = false
	pcall(function()
		evEnqueteAdmin:FireServer(InputPergunta.Text, InputOpA.Text, InputOpB.Text, InputTempoEnq.Text)
	end)
	task.delay(1.5, function()
		BtnLancarEnquete.Text = "✅ NO AR"
		BtnLancarEnquete.BackgroundColor3 = COR_NEON_VERDE
	end)
	task.delay(4.5, function()
		BtnLancarEnquete.Text = "📢 LANÇAR ENQUETE GLOBAL"
		BtnLancarEnquete.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
		BtnLancarEnquete.Interactable = true
	end)
end)

-- ========== Abrir / fechar + arrastar ==========
local tweenPainel
local function alternarPainel(forcarFechar)
	if tweenPainel then
		tweenPainel:Cancel()
		tweenPainel = nil
	end
	if painelAberto or forcarFechar then
		painelAberto = false
		tweenPainel = TweenService:Create(UiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		tweenPainel:Play()
		tweenPainel.Completed:Once(function()
			if not painelAberto then
				gui.Enabled = false
			end
			tweenPainel = nil
		end)
	else
		painelAberto = true
		gui.Enabled = true
		UiScale.Scale = 0
		tweenPainel = TweenService:Create(UiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		tweenPainel:Play()
		tweenPainel.Completed:Once(function()
			tweenPainel = nil
		end)
	end
end

BtnFechar.Activated:Connect(function()
	alternarPainel(true)
end)

local dragging = false
local dragStart
local startPosDrag

BarraTitulo.InputBegan:Connect(function(input)
	if not painelAberto or not gui.Enabled then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPosDrag = PainelPrincipal.Position
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging or not painelAberto then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local delta = input.Position - dragStart
	PainelPrincipal.Position = UDim2.new(
		startPosDrag.X.Scale,
		startPosDrag.X.Offset + delta.X,
		startPosDrag.Y.Scale,
		startPosDrag.Y.Offset + delta.Y
	)
end)

ContextActionService:BindActionAtPriority(
	"CH_PainelMestre_Toggle",
	function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			alternarPainel(false)
		end
		return Enum.ContextActionResult.Sink
	end,
	false,
	4000,
	Enum.KeyCode.F5,
	Enum.KeyCode.F4,
	Enum.KeyCode.F10,
	Enum.KeyCode.F11
)

