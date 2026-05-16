-- CH Corporations - Loja Neon (fecha ao receber celebração de compra)
-- Revisão: PlayerGui com timeout; remove GUI duplicada; formatarNumero sem global leak;
--          UIStroke com FindFirstChildOfClass; tween de fechar com Once + cancel ao reabrir;
--          CelebracaoCompraEvent com timeout + IsA; pcall + debounce nos prompts; Activated.

print("CH Corporations - Loja Neon (revisão — fecha na compra)")

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_TIMEOUT = 60
local DEBOUNCE_COMPRA = 1.0

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", REMOTE_TIMEOUT)
if not playerGui then
	warn("[LojaNeon] PlayerGui em falta — script desativado.")
	return
end

local guiAntiga = playerGui:FindFirstChild("CH_LojaNeonUI")
if guiAntiga then
	guiAntiga:Destroy()
end

-- ==========================================
-- Dados dos produtos
-- ==========================================
local lojaDinheiro = {
	{ id = 3553695517, recompensa = 5000, emoji = "💵" },
	{ id = 3553695674, recompensa = 10000, emoji = "💵" },
	{ id = 3553695854, recompensa = 22500, emoji = "💸" },
	{ id = 3553696003, recompensa = 30000, emoji = "💸" },
	{ id = 3553696219, recompensa = 60000, emoji = "💰" },
	{ id = 3553696367, recompensa = 125000, emoji = "💰" },
	{ id = 3553696581, recompensa = 750000, emoji = "🤑" },
	{ id = 3553696802, recompensa = 1500000, emoji = "🤑" },
}

local lojaXP = {
	{ id = 3553701915, recompensa = 1000, emoji = "⭐" },
	{ id = 3553702171, recompensa = 2000, emoji = "⭐" },
	{ id = 3553702311, recompensa = 5500, emoji = "🌟" },
	{ id = 3553702429, recompensa = 12000, emoji = "🌟" },
	{ id = 3553702574, recompensa = 16000, emoji = "✨" },
	{ id = 3553702664, recompensa = 32000, emoji = "✨" },
	{ id = 3553702816, recompensa = 65000, emoji = "⚡" },
	{ id = 3553702966, recompensa = 150000, emoji = "⚡" },
}

local lojaBronze = {
	{ id = 3560842687, nivel = "Bronze", dias = 1, emoji = "🥉", cor = Color3.fromRGB(210, 105, 30) },
	{ id = 3560842783, nivel = "Bronze", dias = 7, emoji = "🥉", cor = Color3.fromRGB(210, 105, 30) },
	{ id = 3560842888, nivel = "Bronze", dias = 15, emoji = "🥉", cor = Color3.fromRGB(210, 105, 30) },
	{ id = 3560843476, nivel = "Bronze", dias = 30, emoji = "🥉", cor = Color3.fromRGB(210, 105, 30) },
}

local lojaGold = {
	{ id = 3560844035, nivel = "Gold", dias = 1, emoji = "🥇", cor = Color3.fromRGB(255, 215, 0) },
	{ id = 3560844156, nivel = "Gold", dias = 7, emoji = "🥇", cor = Color3.fromRGB(255, 215, 0) },
	{ id = 3560844290, nivel = "Gold", dias = 15, emoji = "🥇", cor = Color3.fromRGB(255, 215, 0) },
	{ id = 3560844409, nivel = "Gold", dias = 30, emoji = "🥇", cor = Color3.fromRGB(255, 215, 0) },
}

local lojaDiamante = {
	{ id = 3560844895, nivel = "Diamante", dias = 1, emoji = "💎", cor = Color3.fromRGB(0, 255, 255) },
	{ id = 3560844987, nivel = "Diamante", dias = 7, emoji = "💎", cor = Color3.fromRGB(0, 255, 255) },
	{ id = 3560845056, nivel = "Diamante", dias = 15, emoji = "💎", cor = Color3.fromRGB(0, 255, 255) },
	{ id = 3560845165, nivel = "Diamante", dias = 30, emoji = "💎", cor = Color3.fromRGB(0, 255, 255) },
}

local lojaPermanente = {
	{ id = 1737108751, nivel = "Bronze", emoji = "🥉", cor = Color3.fromRGB(210, 105, 30) },
	{ id = 1746268685, nivel = "Gold", emoji = "🥇", cor = Color3.fromRGB(255, 215, 0) },
	{ id = 1746862603, nivel = "Diamante", emoji = "💎", cor = Color3.fromRGB(0, 255, 255) },
}

-- ==========================================
-- Cores
-- ==========================================
local COR_FUNDO = Color3.fromRGB(15, 15, 22)
local COR_NEON_CIANO = Color3.fromRGB(0, 255, 255)
local COR_FUNDO_SELECAO = Color3.fromRGB(30, 30, 40)
local COR_BRANCO = Color3.fromRGB(255, 255, 255)
local COR_VERDE_COMPRA = Color3.fromRGB(40, 200, 80)

local PAINEL_LARG_PADRAO = 600
local PAINEL_ALT_PADRAO = 480
local PAINEL_LARG_MIN = 320
local PAINEL_ALT_MIN = 300
local MARGEM_LATERAL = 20
local MARGEM_VERTICAL = 80

-- ==========================================
-- Interface
-- ==========================================
local guiLoja = Instance.new("ScreenGui")
guiLoja.Name = "CH_LojaNeonUI"
guiLoja.ResetOnSpawn = false
guiLoja.IgnoreGuiInset = true
guiLoja.Enabled = true
guiLoja.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
guiLoja.Parent = playerGui

local BtnAbrirLoja = Instance.new("ImageButton")
BtnAbrirLoja.Size = UDim2.new(0, 50, 0, 50)
BtnAbrirLoja.Position = UDim2.new(0, 15, 0.5, -25)
BtnAbrirLoja.BackgroundColor3 = COR_FUNDO_SELECAO
BtnAbrirLoja.Image = "rbxassetid://85964789425416"
BtnAbrirLoja.ScaleType = Enum.ScaleType.Fit
BtnAbrirLoja.AutoButtonColor = true
BtnAbrirLoja.Parent = guiLoja

local cAbrir = Instance.new("UICorner")
cAbrir.CornerRadius = UDim.new(0, 12)
cAbrir.Parent = BtnAbrirLoja

local sAbrir = Instance.new("UIStroke")
sAbrir.Color = COR_NEON_CIANO
sAbrir.Thickness = 2
sAbrir.Parent = BtnAbrirLoja

local PainelPrincipal = Instance.new("Frame")
PainelPrincipal.Size = UDim2.new(0, PAINEL_LARG_PADRAO, 0, PAINEL_ALT_PADRAO)
PainelPrincipal.Position = UDim2.new(0.5, -PAINEL_LARG_PADRAO / 2, 0.5, -PAINEL_ALT_PADRAO / 2)
PainelPrincipal.BackgroundColor3 = COR_FUNDO
PainelPrincipal.BorderSizePixel = 0
PainelPrincipal.Visible = false
PainelPrincipal.Parent = guiLoja

local UiScale = Instance.new("UIScale")
UiScale.Scale = 0
UiScale.Parent = PainelPrincipal

local cPainel = Instance.new("UICorner")
cPainel.CornerRadius = UDim.new(0, 12)
cPainel.Parent = PainelPrincipal

local painelLargAtual = PAINEL_LARG_PADRAO
local painelAltAtual = PAINEL_ALT_PADRAO

local function aplicarLayoutResponsivo()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)

	local larguraMax = math.max(PAINEL_LARG_MIN, math.floor(viewport.X - MARGEM_LATERAL * 2))
	local alturaMax = math.max(PAINEL_ALT_MIN, math.floor(viewport.Y - MARGEM_VERTICAL))
	painelLargAtual = math.clamp(PAINEL_LARG_PADRAO, PAINEL_LARG_MIN, larguraMax)
	painelAltAtual = math.clamp(PAINEL_ALT_PADRAO, PAINEL_ALT_MIN, alturaMax)

	PainelPrincipal.Size = UDim2.new(0, painelLargAtual, 0, painelAltAtual)
	PainelPrincipal.Position = UDim2.new(0.5, -painelLargAtual / 2, 0.5, -painelAltAtual / 2)

	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if isMobile then
		BtnAbrirLoja.Size = UDim2.new(0, 44, 0, 44)
		BtnAbrirLoja.Position = UDim2.new(0, 12, 0.5, -22)
	else
		BtnAbrirLoja.Size = UDim2.new(0, 50, 0, 50)
		BtnAbrirLoja.Position = UDim2.new(0, 15, 0.5, -25)
	end
end

local sPainel = Instance.new("UIStroke")
sPainel.Color = COR_NEON_CIANO
sPainel.Thickness = 2
sPainel.Parent = PainelPrincipal

local BarraTitulo = Instance.new("Frame")
BarraTitulo.Size = UDim2.new(1, 0, 0, 50)
BarraTitulo.BackgroundColor3 = COR_FUNDO_SELECAO
BarraTitulo.BackgroundTransparency = 0.5
BarraTitulo.BorderSizePixel = 0
BarraTitulo.Parent = PainelPrincipal

local cBarra = Instance.new("UICorner")
cBarra.CornerRadius = UDim.new(0, 12)
cBarra.Parent = BarraTitulo

local Titulo = Instance.new("TextLabel")
Titulo.Size = UDim2.new(1, -60, 1, 0)
Titulo.Position = UDim2.new(0, 20, 0, 0)
Titulo.BackgroundTransparency = 1
Titulo.Text = "🛒 LOJA OFICIAL"
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

local cFechar = Instance.new("UICorner")
cFechar.CornerRadius = UDim.new(1, 0)
cFechar.Parent = BtnFechar

local SidebarMenu = Instance.new("ScrollingFrame")
SidebarMenu.Size = UDim2.new(0, 140, 1, -80)
SidebarMenu.Position = UDim2.new(0, 15, 0, 65)
SidebarMenu.BackgroundTransparency = 1
SidebarMenu.ScrollBarThickness = 2
SidebarMenu.ScrollBarImageColor3 = COR_NEON_CIANO
SidebarMenu.AutomaticCanvasSize = Enum.AutomaticSize.Y
SidebarMenu.CanvasSize = UDim2.new(0, 0, 0, 0)
SidebarMenu.Parent = PainelPrincipal

local UIListTabs = Instance.new("UIListLayout")
UIListTabs.FillDirection = Enum.FillDirection.Vertical
UIListTabs.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListTabs.Padding = UDim.new(0, 10)
UIListTabs.SortOrder = Enum.SortOrder.LayoutOrder
UIListTabs.Parent = SidebarMenu

local function criarAba(nome, texto, ordem)
	local btn = Instance.new("TextButton")
	btn.Name = nome
	btn.LayoutOrder = ordem
	btn.Size = UDim2.new(1, -10, 0, 40)
	btn.BackgroundColor3 = COR_FUNDO_SELECAO
	btn.Text = texto
	btn.TextColor3 = COR_BRANCO
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.AutoButtonColor = true
	btn.Parent = SidebarMenu

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = COR_NEON_CIANO
	stroke.Transparency = 1
	stroke.Parent = btn

	return btn
end

local AbaPerm = criarAba("Perm", "♾️ PERM", 1)
local AbaDiamante = criarAba("Diamante", "💎 DIAMANTE", 2)
local AbaGold = criarAba("Gold", "🥇 GOLD", 3)
local AbaBronze = criarAba("Bronze", "🥉 BRONZE", 4)
local AbaXP = criarAba("XP", "🌟 XP", 5)
local AbaDinheiro = criarAba("Dinheiro", "💰 DINHEIRO", 6)

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -170, 1, -80)
ContentArea.Position = UDim2.new(0, 160, 0, 65)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = PainelPrincipal

local function criarScrollList(nome)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = nome
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = COR_NEON_CIANO
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Visible = false
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = ContentArea

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.46, 0, 0, 120)
	grid.CellPadding = UDim2.new(0, 15, 0, 15)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.Parent = scroll

	return scroll
end

local ScrollDinheiro = criarScrollList("ScrollDinheiro")
local ScrollXP = criarScrollList("ScrollXP")
local ScrollBronze = criarScrollList("ScrollBronze")
local ScrollGold = criarScrollList("ScrollGold")
local ScrollDiamante = criarScrollList("ScrollDiamante")
local ScrollPerm = criarScrollList("ScrollPerm")

local function formatarNumero(numero)
	local formatado = tostring(math.floor(tonumber(numero) or 0))
	local count
	while true do
		formatado, count = string.gsub(formatado, "^(-?%d+)(%d%d%d)", "%1,%2")
		if count == 0 then
			break
		end
	end
	return formatado
end

local compraBloqueada = false

local function gerarCartao(pai, id, titulo, emoji, corTema, subtitulo, isGamepass)
	local cartao = Instance.new("Frame")
	cartao.BackgroundColor3 = COR_FUNDO_SELECAO
	cartao.BorderSizePixel = 0
	cartao.Parent = pai

	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = cartao

	local stroke = Instance.new("UIStroke")
	stroke.Color = corTema
	stroke.Thickness = 1.5
	stroke.Parent = cartao

	local txtEmoji = Instance.new("TextLabel")
	txtEmoji.Size = UDim2.new(1, 0, 0, 35)
	txtEmoji.Position = UDim2.new(0, 0, 0, 5)
	txtEmoji.BackgroundTransparency = 1
	txtEmoji.Text = emoji
	txtEmoji.TextSize = 30
	txtEmoji.Parent = cartao

	local txtTitulo = Instance.new("TextLabel")
	txtTitulo.Size = UDim2.new(1, 0, 0, 20)
	txtTitulo.Position = UDim2.new(0, 0, 0, 45)
	txtTitulo.BackgroundTransparency = 1
	txtTitulo.Text = titulo
	txtTitulo.TextColor3 = corTema
	txtTitulo.Font = Enum.Font.GothamBold
	txtTitulo.TextSize = 16
	txtTitulo.Parent = cartao

	if subtitulo then
		local txtSub = Instance.new("TextLabel")
		txtSub.Size = UDim2.new(1, 0, 0, 15)
		txtSub.Position = UDim2.new(0, 0, 0, 65)
		txtSub.BackgroundTransparency = 1
		txtSub.Text = subtitulo
		txtSub.TextColor3 = COR_BRANCO
		txtSub.Font = Enum.Font.GothamMedium
		txtSub.TextSize = 12
		txtSub.Parent = cartao
	end

	local btnComprar = Instance.new("TextButton")
	btnComprar.Size = UDim2.new(0.8, 0, 0, 25)
	btnComprar.Position = UDim2.new(0.1, 0, 1, -30)
	btnComprar.BackgroundColor3 = COR_VERDE_COMPRA
	btnComprar.Text = "🛒 COMPRAR"
	btnComprar.TextColor3 = COR_BRANCO
	btnComprar.Font = Enum.Font.GothamBold
	btnComprar.TextSize = 12
	btnComprar.AutoButtonColor = true
	btnComprar.Parent = cartao

	local cBtn = Instance.new("UICorner")
	cBtn.CornerRadius = UDim.new(0, 6)
	cBtn.Parent = btnComprar

	btnComprar.Activated:Connect(function()
		if compraBloqueada then
			return
		end
		compraBloqueada = true
		task.delay(DEBOUNCE_COMPRA, function()
			compraBloqueada = false
		end)

		local ok, err = pcall(function()
			if isGamepass then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
		if not ok then
			warn("[LojaNeon] Prompt de compra falhou:", err)
		end
	end)
end

for _, item in ipairs(lojaDinheiro) do
	gerarCartao(ScrollDinheiro, item.id, "$ " .. formatarNumero(item.recompensa), item.emoji, Color3.fromRGB(85, 255, 127))
end
for _, item in ipairs(lojaXP) do
	gerarCartao(ScrollXP, item.id, formatarNumero(item.recompensa) .. " XP", item.emoji, Color3.fromRGB(255, 170, 0))
end
for _, item in ipairs(lojaBronze) do
	gerarCartao(ScrollBronze, item.id, "VIP " .. item.nivel, item.emoji, item.cor, item.dias .. " Dias")
end
for _, item in ipairs(lojaGold) do
	gerarCartao(ScrollGold, item.id, "VIP " .. item.nivel, item.emoji, item.cor, item.dias .. " Dias")
end
for _, item in ipairs(lojaDiamante) do
	gerarCartao(ScrollDiamante, item.id, "VIP " .. item.nivel, item.emoji, item.cor, item.dias .. " Dias")
end
for _, item in ipairs(lojaPermanente) do
	gerarCartao(ScrollPerm, item.id, "VIP " .. item.nivel, item.emoji, item.cor, "Permanente ♾️", true)
end

-- ==========================================
-- Navegação
-- ==========================================
local todasAsAbas = { AbaDinheiro, AbaXP, AbaBronze, AbaGold, AbaDiamante, AbaPerm }
local todosOsScrolls = { ScrollDinheiro, ScrollXP, ScrollBronze, ScrollGold, ScrollDiamante, ScrollPerm }

local function mudarAba(abaAtiva)
	for _, btn in ipairs(todasAsAbas) do
		btn.BackgroundColor3 = COR_FUNDO_SELECAO
		btn.TextColor3 = COR_BRANCO
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1
		end
	end

	for _, scroll in ipairs(todosOsScrolls) do
		scroll.Visible = false
	end

	abaAtiva.BackgroundColor3 = COR_NEON_CIANO
	abaAtiva.TextColor3 = COR_FUNDO
	local strokeAtivo = abaAtiva:FindFirstChildOfClass("UIStroke")
	if strokeAtivo then
		strokeAtivo.Transparency = 0
	end

	if abaAtiva == AbaDinheiro then
		ScrollDinheiro.Visible = true
	elseif abaAtiva == AbaXP then
		ScrollXP.Visible = true
	elseif abaAtiva == AbaBronze then
		ScrollBronze.Visible = true
	elseif abaAtiva == AbaGold then
		ScrollGold.Visible = true
	elseif abaAtiva == AbaDiamante then
		ScrollDiamante.Visible = true
	elseif abaAtiva == AbaPerm then
		ScrollPerm.Visible = true
	end
end

for _, aba in ipairs(todasAsAbas) do
	aba.Activated:Connect(function()
		mudarAba(aba)
	end)
end

-- ==========================================
-- Abrir / fechar
-- ==========================================
local lojaAberta = false
local tweenUiAtual = nil

local function alternarLoja()
	if tweenUiAtual then
		tweenUiAtual:Cancel()
		tweenUiAtual = nil
	end

	lojaAberta = not lojaAberta
	if lojaAberta then
		PainelPrincipal.Visible = true
		UiScale.Scale = 0
		mudarAba(AbaPerm)
		tweenUiAtual = TweenService:Create(UiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		tweenUiAtual:Play()
		tweenUiAtual.Completed:Once(function()
			tweenUiAtual = nil
		end)
	else
		tweenUiAtual = TweenService:Create(UiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		tweenUiAtual:Play()
		tweenUiAtual.Completed:Once(function()
			if not lojaAberta then
				PainelPrincipal.Visible = false
			end
			tweenUiAtual = nil
		end)
	end
end

local function fecharLojaSeAberta()
	if lojaAberta then
		alternarLoja()
	end
end

BtnFechar.Activated:Connect(alternarLoja)
BtnAbrirLoja.Activated:Connect(alternarLoja)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F3 then
		alternarLoja()
	end
end)

-- ==========================================
-- Fecha a loja quando o servidor confirma compra (celebração)
-- ==========================================
local eventoCelebracao = ReplicatedStorage:WaitForChild("CelebracaoCompraEvent", REMOTE_TIMEOUT)
if not eventoCelebracao or not eventoCelebracao:IsA("RemoteEvent") then
	warn("[LojaNeon] CelebracaoCompraEvent em falta — loja não fecha automaticamente na compra.")
else
	eventoCelebracao.OnClientEvent:Connect(function()
		fecharLojaSeAberta()
	end)
end

local function ligarResizeResponsivo()
	aplicarLayoutResponsivo()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(aplicarLayoutResponsivo)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local nova = workspace.CurrentCamera
		if nova then
			nova:GetPropertyChangedSignal("ViewportSize"):Connect(aplicarLayoutResponsivo)
			aplicarLayoutResponsivo()
		end
	end)
end

ligarResizeResponsivo()
