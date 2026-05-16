-- CH Corporations - Painel Admin Neon / doação VIP cross-server (LocalScript)
-- Revisão: remote com timeout + IsA; PlayerGui com timeout; arrasto sem Connect aninhado a cada clique;
--          Activated nos botões; trim/limite no nick; FireServer com debounce + pcall; remove GUI antiga se existir;
--          Atalho painel: F10 (e F11) via ContextActionService, prioridade 4000 — mais fiável que UserInputService.

print("CH Corporations - Painel Admin Neon (revisão — Cross-Server VIP)")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_TIMEOUT = 60
local DEBOUNCE_CONFIRMA = 1.5
local NICK_MAX_LEN = 64

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", REMOTE_TIMEOUT)
if not playerGui then
	warn("[PainelAdmin] PlayerGui em falta — script desativado.")
	return
end

local evAdmin = ReplicatedStorage:WaitForChild("DoarVipCrossServer", REMOTE_TIMEOUT)
if not evAdmin or not evAdmin:IsA("RemoteEvent") then
	warn("[PainelAdmin] DoarVipCrossServer (RemoteEvent) em falta no ReplicatedStorage.")
	return
end

local guiAntiga = playerGui:FindFirstChild("CH_PainelAdminAdminGui")
if guiAntiga then
	guiAntiga:Destroy()
end

-- ==========================================
-- Cores neon (estilo CH)
-- ==========================================
local COR_FUNDO = Color3.fromRGB(15, 15, 22)
local COR_NEON_CIANO = Color3.fromRGB(0, 255, 255)
local COR_NEON_LARANJA = Color3.fromRGB(255, 170, 0)
local COR_BRANCO = Color3.fromRGB(255, 255, 255)
local COR_FUNDO_SELECAO = Color3.fromRGB(30, 30, 40)

local vipSelecionado = "Bronze"
local diasSelecionados = 0

-- ==========================================
-- Interface
-- ==========================================
local gui = Instance.new("ScreenGui")
gui.Name = "CH_PainelAdminAdminGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- F10: BindActionAtPriority captura antes de chat/TextBox e na maior parte dos casos antes de atalhos do jogo.
local TOGGLE_ADMIN_ACTION = "CH_PainelAdmin_ToggleF10"
ContextActionService:BindActionAtPriority(
	TOGGLE_ADMIN_ACTION,
	function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			gui.Enabled = not gui.Enabled
		end
		return Enum.ContextActionResult.Sink
	end,
	false,
	4000,
	Enum.KeyCode.F10,
	Enum.KeyCode.F11 -- alternativa: no Studio o F10 é muitas vezes roubado pelo depurador (Step Over)
)

local PainelPrincipal = Instance.new("Frame")
PainelPrincipal.Name = "PainelPrincipal"
PainelPrincipal.Size = UDim2.new(0, 500, 0, 400)
PainelPrincipal.Position = UDim2.new(0.5, -250, 0.5, -200)
PainelPrincipal.BackgroundColor3 = COR_FUNDO
PainelPrincipal.BorderSizePixel = 0
PainelPrincipal.Parent = gui

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = COR_NEON_CIANO
UIStroke.Thickness = 2
UIStroke.Transparency = 0.5
UIStroke.Parent = PainelPrincipal

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = PainelPrincipal

local BarraTitulo = Instance.new("Frame")
BarraTitulo.Name = "BarraTitulo"
BarraTitulo.Size = UDim2.new(1, 0, 0, 50)
BarraTitulo.BackgroundColor3 = COR_FUNDO_SELECAO
BarraTitulo.BackgroundTransparency = 0.5
BarraTitulo.BorderSizePixel = 0
BarraTitulo.Parent = PainelPrincipal

local CornerTitulo = Instance.new("UICorner")
CornerTitulo.CornerRadius = UDim.new(0, 12)
CornerTitulo.Parent = BarraTitulo

local Titulo = Instance.new("TextLabel")
Titulo.Size = UDim2.new(1, -60, 1, 0)
Titulo.Position = UDim2.new(0, 20, 0, 0)
Titulo.BackgroundTransparency = 1
Titulo.Text = "👑 PAINEL DEVELOPER 👑"
Titulo.TextColor3 = COR_NEON_LARANJA
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

local UICornerFechar = Instance.new("UICorner")
UICornerFechar.CornerRadius = UDim.new(1, 0)
UICornerFechar.Parent = BtnFechar

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -40, 1, -70)
ContentFrame.Position = UDim2.new(0, 20, 0, 60)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = PainelPrincipal

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 15)
UIListLayout.Parent = ContentFrame

local FrameNome = Instance.new("Frame")
FrameNome.Size = UDim2.new(1, 0, 0, 60)
FrameNome.BackgroundTransparency = 1
FrameNome.LayoutOrder = 1
FrameNome.Parent = ContentFrame

local TxtNome = Instance.new("TextLabel")
TxtNome.Size = UDim2.new(1, 0, 0, 20)
TxtNome.BackgroundTransparency = 1
TxtNome.Text = "Nome do Piloto (Nick):"
TxtNome.TextColor3 = COR_BRANCO
TxtNome.Font = Enum.Font.GothamBold
TxtNome.TextSize = 14
TxtNome.TextXAlignment = Enum.TextXAlignment.Left
TxtNome.Parent = FrameNome

local InputNome = Instance.new("TextBox")
InputNome.Name = "InputNome"
InputNome.Size = UDim2.new(1, 0, 0, 35)
InputNome.Position = UDim2.new(0, 0, 0, 25)
InputNome.BackgroundColor3 = COR_FUNDO_SELECAO
InputNome.TextColor3 = COR_BRANCO
InputNome.Font = Enum.Font.GothamMedium
InputNome.TextSize = 14
InputNome.PlaceholderText = "Ex: CheechSC..."
InputNome.Text = ""
InputNome.ClearTextOnFocus = false
InputNome.Parent = FrameNome

local cornerNome = Instance.new("UICorner")
cornerNome.CornerRadius = UDim.new(0, 6)
cornerNome.Parent = InputNome

local strokeNome = Instance.new("UIStroke")
strokeNome.Color = COR_NEON_CIANO
strokeNome.Parent = InputNome

local FrameVIP = Instance.new("Frame")
FrameVIP.Size = UDim2.new(1, 0, 0, 70)
FrameVIP.BackgroundTransparency = 1
FrameVIP.LayoutOrder = 2
FrameVIP.Parent = ContentFrame

local TxtVIP = Instance.new("TextLabel")
TxtVIP.Size = UDim2.new(1, 0, 0, 20)
TxtVIP.BackgroundTransparency = 1
TxtVIP.Text = "Escolha o VIP 🎁:"
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

local UIPaddingVIPs = Instance.new("UIPadding")
UIPaddingVIPs.PaddingLeft = UDim.new(0, 0)
UIPaddingVIPs.PaddingRight = UDim.new(0, 0)
UIPaddingVIPs.Parent = ContainerVIPs

local function criarBotaoOpcao(pai, nome, texto, emoji, order)
	local btn = Instance.new("TextButton")
	btn.Name = nome
	btn.Size = UDim2.new(0.32, 0, 1, 0)
	btn.BackgroundColor3 = COR_FUNDO_SELECAO
	btn.Text = emoji .. " " .. texto
	btn.TextColor3 = COR_BRANCO
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
	btn.LayoutOrder = order
	btn.AutoButtonColor = true
	btn.Parent = pai

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = COR_NEON_CIANO
	stroke.Transparency = 1
	stroke.Parent = btn

	return btn
end

local UIListVIPs = Instance.new("UIListLayout")
UIListVIPs.FillDirection = Enum.FillDirection.Horizontal
UIListVIPs.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListVIPs.Padding = UDim.new(0, 10)
UIListVIPs.Parent = ContainerVIPs

local BtnBronze = criarBotaoOpcao(ContainerVIPs, "Bronze", "BRONZE", "🥉", 1)
local BtnGold = criarBotaoOpcao(ContainerVIPs, "Gold", "GOLD", "🥇", 2)
local BtnDiamante = criarBotaoOpcao(ContainerVIPs, "Diamante", "DIAMANTE", "💎", 3)

local FrameDias = Instance.new("Frame")
FrameDias.Size = UDim2.new(1, 0, 0, 70)
FrameDias.BackgroundTransparency = 1
FrameDias.LayoutOrder = 3
FrameDias.Parent = ContentFrame

local TxtDias = Instance.new("TextLabel")
TxtDias.Size = UDim2.new(1, 0, 0, 20)
TxtDias.BackgroundTransparency = 1
TxtDias.Text = "Duração (Dias) ⏳:"
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

local function criarBotaoDia(pai, dias, emoji, order)
	local btn = Instance.new("TextButton")
	btn.Name = tostring(dias)
	btn.Size = UDim2.new(0.18, 0, 1, 0)
	btn.BackgroundColor3 = COR_FUNDO_SELECAO
	if dias == 0 then
		btn.Text = emoji .. " PERM"
	else
		btn.Text = emoji .. " " .. tostring(dias)
	end
	btn.TextColor3 = COR_BRANCO
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 12
	btn.LayoutOrder = order
	btn.AutoButtonColor = true
	btn.Parent = pai

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = COR_NEON_CIANO
	stroke.Transparency = 1
	stroke.Parent = btn

	return btn
end

local UIListDias = Instance.new("UIListLayout")
UIListDias.FillDirection = Enum.FillDirection.Horizontal
UIListDias.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListDias.Padding = UDim.new(0, 8)
UIListDias.Parent = ContainerDias

local BtnPerm = criarBotaoDia(ContainerDias, 0, "♾️", 1)
local BtnDay1 = criarBotaoDia(ContainerDias, 1, "📅", 2)
local BtnDay7 = criarBotaoDia(ContainerDias, 7, "📅", 3)
local BtnDay15 = criarBotaoDia(ContainerDias, 15, "📅", 4)
local BtnDay30 = criarBotaoDia(ContainerDias, 30, "📅", 5)

local BtnConfirmar = Instance.new("TextButton")
BtnConfirmar.Name = "BtnConfirmar"
BtnConfirmar.Size = UDim2.new(1, 0, 0, 45)
BtnConfirmar.BackgroundColor3 = COR_NEON_LARANJA
BtnConfirmar.Text = "🤝 CONFIRMAR DOAÇÃO"
BtnConfirmar.TextColor3 = COR_FUNDO
BtnConfirmar.Font = Enum.Font.GothamBlack
BtnConfirmar.TextSize = 18
BtnConfirmar.LayoutOrder = 4
BtnConfirmar.AutoButtonColor = true
BtnConfirmar.Parent = ContentFrame

local CornerConfirmar = Instance.new("UICorner")
CornerConfirmar.CornerRadius = UDim.new(0, 6)
CornerConfirmar.Parent = BtnConfirmar

local botoesVIPs = { BtnBronze, BtnGold, BtnDiamante }
local botoesDias = { BtnPerm, BtnDay1, BtnDay7, BtnDay15, BtnDay30 }

-- ==========================================
-- Seleção / estilo
-- ==========================================
local function atualizarEstiloBotoes(listaBotoes, valorSelecionado)
	local alvo = tostring(valorSelecionado)
	for _, btn in ipairs(listaBotoes) do
		local stroke = btn:FindFirstChild("UIStroke")
		if btn.Name == alvo then
			btn.BackgroundColor3 = COR_NEON_CIANO
			btn.TextColor3 = COR_FUNDO
			if stroke then
				stroke.Transparency = 0
			end
		else
			btn.BackgroundColor3 = COR_FUNDO_SELECAO
			btn.TextColor3 = COR_BRANCO
			if stroke then
				stroke.Transparency = 1
			end
		end
	end
end

atualizarEstiloBotoes(botoesVIPs, vipSelecionado)
atualizarEstiloBotoes(botoesDias, tostring(diasSelecionados))

for _, btn in ipairs(botoesVIPs) do
	btn.Activated:Connect(function()
		vipSelecionado = btn.Name
		atualizarEstiloBotoes(botoesVIPs, vipSelecionado)
	end)
end

for _, btn in ipairs(botoesDias) do
	btn.Activated:Connect(function()
		diasSelecionados = tonumber(btn.Name) or 0
		atualizarEstiloBotoes(botoesDias, tostring(diasSelecionados))
	end)
end

BtnFechar.Activated:Connect(function()
	gui.Enabled = false
end)

-- ==========================================
-- Arrastar (sem Connect extra dentro de cada InputBegan)
-- ==========================================
local dragging = false
local dragStart
local startPos

BarraTitulo.InputBegan:Connect(function(input)
	if not gui.Enabled then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = PainelPrincipal.Position
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging or not gui.Enabled then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local delta = input.Position - dragStart
	PainelPrincipal.Position = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)
end)

-- ==========================================
-- Servidor
-- ==========================================
local confirmarBloqueado = false
BtnConfirmar.Activated:Connect(function()
	if confirmarBloqueado then
		return
	end

	local nomeAlvo = InputNome.Text
	nomeAlvo = nomeAlvo:gsub("^%s+", ""):gsub("%s+$", "")
	if nomeAlvo == "" then
		warn("[PainelAdmin] Digite o nome do piloto.")
		return
	end
	if #nomeAlvo > NICK_MAX_LEN then
		nomeAlvo = string.sub(nomeAlvo, 1, NICK_MAX_LEN)
		InputNome.Text = nomeAlvo
	end

	confirmarBloqueado = true
	BtnConfirmar.Text = "⏳ Enviando..."
	BtnConfirmar.AutoButtonColor = false
	BtnConfirmar.Interactable = false

	local ok, err = pcall(function()
		evAdmin:FireServer(nomeAlvo, vipSelecionado, diasSelecionados)
	end)

	if not ok then
		warn("[PainelAdmin] FireServer falhou:", err)
		BtnConfirmar.Text = "❌ Erro — tentar de novo"
	else
		print("[PainelAdmin] Pedido enviado: VIP", vipSelecionado, "dias", diasSelecionados, "→", nomeAlvo)
		BtnConfirmar.Text = "✅ Pedido enviado"
	end

	task.delay(DEBOUNCE_CONFIRMA, function()
		confirmarBloqueado = false
		BtnConfirmar.Text = "🤝 CONFIRMAR DOAÇÃO"
		BtnConfirmar.AutoButtonColor = true
		BtnConfirmar.Interactable = true
	end)
end)
