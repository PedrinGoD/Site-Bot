-- CH Corporations - Loja de Suspensao (LocalScript unico)
-- Coloque este LocalScript em StarterPlayerScripts.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TIMEOUT = 60
local COMPRA_DEBOUNCE = 0.55
local CARD_WIDTH = 210
local CARD_HEIGHT = 280

local comprarEvento = ReplicatedStorage:WaitForChild("ComprarSuspensaoEvent", TIMEOUT)
local configModule = ReplicatedStorage:WaitForChild("LojaSuspensaoConfig", TIMEOUT)
if not comprarEvento or not comprarEvento:IsA("RemoteEvent") then
	warn("[LojaSuspUI] ComprarSuspensaoEvent em falta/invalido.")
	return
end
if not configModule or not configModule:IsA("ModuleScript") then
	warn("[LojaSuspUI] LojaSuspensaoConfig em falta no ReplicatedStorage.")
	return
end

local config = require(configModule)
local uiCfg = config.UI or {}
local itens = config.Itens or {}

local ultimoClick = 0
local cards = {}
local frameTudo
local uiScale
local prompt
local menuAberto = false
local tweenAtual

local function lerLevelAtual()
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue and (levelValue:IsA("IntValue") or levelValue:IsA("NumberValue")) then
		return math.max(0, math.floor(levelValue.Value))
	end
	return 1
end

local function normalizarImagem(imageId)
	if type(imageId) == "number" and imageId > 0 then
		return "rbxassetid://" .. tostring(math.floor(imageId))
	end
	if type(imageId) == "string" and imageId ~= "" then
		if string.find(imageId, "rbxassetid://", 1, true) then
			return imageId
		end
		local num = tonumber(imageId)
		if num and num > 0 then
			return "rbxassetid://" .. tostring(math.floor(num))
		end
		return imageId
	end
	return ""
end

local function criarLabel(parent, name, text, size, pos, textSize, color, stroke)
	local lb = Instance.new("TextLabel")
	lb.Name = name
	lb.BackgroundTransparency = 1
	lb.Text = text
	lb.TextSize = textSize
	lb.Size = size
	lb.Position = pos
	lb.Font = Enum.Font.FredokaOne
	lb.TextColor3 = color
	lb.TextStrokeTransparency = stroke
	lb.Parent = parent
	return lb
end

local function pararTween()
	if tweenAtual then
		pcall(function()
			tweenAtual:Cancel()
		end)
		tweenAtual = nil
	end
end

local function abrirMenu()
	if menuAberto or not frameTudo then
		return
	end
	menuAberto = true
	frameTudo.Visible = true
	if prompt then
		prompt.Enabled = false
	end
	pararTween()
	tweenAtual = TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	tweenAtual:Play()
end

local function fecharMenu()
	if not menuAberto or not frameTudo then
		return
	end
	pararTween()
	tweenAtual = TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
	tweenAtual.Completed:Once(function()
		frameTudo.Visible = false
		menuAberto = false
		if prompt then
			prompt.Enabled = true
		end
	end)
	tweenAtual:Play()
end

local function atualizarCards()
	local levelAtual = lerLevelAtual()
	for _, item in ipairs(cards) do
		local cfg = item.cfg
		local btn = item.botao
		local precoLabel = item.precoLabel
		local tipoLabel = item.tipoLabel
		local nivelLabel = item.nivelLabel

		local levelMin = math.max(0, math.floor(tonumber(cfg.levelMin) or 1))
		local vip = cfg.vip == true
		if vip then
			precoLabel.Text = "VIP"
			tipoLabel.Text = "Acesso: Produto VIP"
			nivelLabel.Text = "Nivel " .. tostring(levelMin)
			btn.Text = "Comprar VIP"
			btn.BackgroundColor3 = Color3.fromRGB(255, 177, 36)
		else
			local preco = math.max(0, math.floor(tonumber(cfg.preco) or 0))
			precoLabel.Text = "$" .. tostring(preco)
			tipoLabel.Text = "Acesso: Dinheiro"
			nivelLabel.Text = "Nivel " .. tostring(levelMin)
			if levelAtual < levelMin then
				btn.Text = "Bloqueado"
				btn.BackgroundColor3 = Color3.fromRGB(121, 36, 36)
			else
				btn.Text = "Comprar"
				btn.BackgroundColor3 = Color3.fromRGB(76, 216, 126)
			end
		end
	end
end

local function conectarCompra(cfg, botao)
	botao.Activated:Connect(function()
		local agora = os.clock()
		if agora - ultimoClick < COMPRA_DEBOUNCE then
			return
		end

		local key = tostring(cfg.key or cfg.toolName or cfg.nome or "Suspensao_X")
		local toolName = tostring(cfg.toolName or key)
		local vip = cfg.vip == true
		local levelMin = math.max(0, math.floor(tonumber(cfg.levelMin) or 1))

		if vip then
			local produtoId = tonumber(cfg.passId)
			if not produtoId or produtoId <= 0 then
				warn("[LojaSuspUI] VIP sem id valido: " .. key)
				return
			end
			ultimoClick = agora
			if cfg.compraGamePass == true then
				MarketplaceService:PromptGamePassPurchase(player, math.floor(produtoId))
			else
				MarketplaceService:PromptProductPurchase(player, math.floor(produtoId))
			end
			return
		end

		if lerLevelAtual() < levelMin then
			return
		end

		local preco = math.max(1, math.floor(tonumber(cfg.preco) or 0))
		ultimoClick = agora
		comprarEvento:FireServer(toolName, preco, levelMin, key)
	end)
end

local function criarCard(parent, cfg, index)
	local card = Instance.new("Frame")
	card.Name = tostring(cfg.key or ("Suspensao_" .. index))
	card.LayoutOrder = index
	card.BackgroundColor3 = Color3.fromRGB(31, 33, 43)
	card.BorderSizePixel = 0
	card.Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 255, 255)
	stroke.Thickness = 1.5
	stroke.Parent = card

	local img = Instance.new("ImageLabel")
	img.Name = "Preview"
	img.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	img.BorderSizePixel = 0
	img.Size = UDim2.new(1, -18, 0, 92)
	img.Position = UDim2.new(0, 9, 0, 8)
	img.Image = normalizarImagem(cfg.imageId)
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = card

	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = UDim.new(0, 8)
	imgCorner.Parent = img

	local nomeLabel = criarLabel(card, "NomeItem", tostring(cfg.nome or cfg.toolName or cfg.key or "Suspensao"), UDim2.new(1, -12, 0, 40), UDim2.new(0, 6, 0, 104), 22, Color3.fromRGB(255, 255, 255), 0.45)
	nomeLabel.TextScaled = true
	nomeLabel.TextWrapped = true
	nomeLabel.TextXAlignment = Enum.TextXAlignment.Left
	local precoLabel = criarLabel(card, "PrecoLabel", "", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0, 146), 20, Color3.fromRGB(255, 200, 70), 0.55)
	local tipoLabel = criarLabel(card, "TipoLabel", "", UDim2.new(1, -12, 0, 16), UDim2.new(0, 6, 0, 166), 16, Color3.fromRGB(205, 235, 255), 0.8)
	local nivelLabel = criarLabel(card, "NivelLabel", "", UDim2.new(1, -12, 0, 16), UDim2.new(0, 6, 0, 182), 16, Color3.fromRGB(255, 255, 255), 0.75)

	local btn = Instance.new("TextButton")
	btn.Name = "Comprar"
	btn.Size = UDim2.new(1, -12, 0, 34)
	btn.Position = UDim2.new(0, 6, 1, -40)
	btn.BackgroundColor3 = Color3.fromRGB(76, 216, 126)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 24
	btn.Text = "Comprar"
	btn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	conectarCompra(cfg, btn)
	table.insert(cards, { cfg = cfg, botao = btn, precoLabel = precoLabel, tipoLabel = tipoLabel, nivelLabel = nivelLabel })
end

local function construirUI()
	local guiName = uiCfg.ScreenGuiName or "LojaSuspensaoUI"
	local old = playerGui:FindFirstChild(guiName)
	if old then
		old:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = guiName
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	frameTudo = Instance.new("Frame")
	frameTudo.Name = "MainFrame"
	frameTudo.AnchorPoint = Vector2.new(0.5, 0.5)
	frameTudo.Position = UDim2.fromScale(0.5, 0.5)
	frameTudo.Size = UDim2.fromScale(0.78, 0.62)
	frameTudo.BackgroundColor3 = Color3.fromRGB(28, 31, 43)
	frameTudo.BackgroundTransparency = 0.08
	frameTudo.BorderSizePixel = 0
	frameTudo.Visible = false
	frameTudo.Parent = screenGui

	local cornerMain = Instance.new("UICorner")
	cornerMain.CornerRadius = UDim.new(0, 12)
	cornerMain.Parent = frameTudo

	local strokeMain = Instance.new("UIStroke")
	strokeMain.Color = Color3.fromRGB(0, 255, 255)
	strokeMain.Thickness = 2
	strokeMain.Parent = frameTudo

	uiScale = Instance.new("UIScale")
	uiScale.Scale = 0
	uiScale.Parent = frameTudo

	local title = criarLabel(frameTudo, "Title", uiCfg.Title or "Loja De Suspensao", UDim2.new(1, -70, 0, 44), UDim2.new(0, 14, 0, 8), 34, Color3.fromRGB(255, 255, 255), 0.65)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "BotaoFechar"
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -10, 0, 8)
	closeBtn.Size = UDim2.new(0, 42, 0, 42)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 35, 35)
	closeBtn.Text = "X"
	closeBtn.TextSize = 24
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Parent = frameTudo

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn
	closeBtn.Activated:Connect(fecharMenu)

	local list = Instance.new("ScrollingFrame")
	list.Name = "ItemList"
	list.Size = UDim2.new(1, -20, 1, -68)
	list.Position = UDim2.new(0, 10, 0, 56)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frameTudo

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingLeft = UDim.new(0, 8)
	listPadding.PaddingTop = UDim.new(0, 8)
	listPadding.PaddingRight = UDim.new(0, 8)
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.Parent = list

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	for index, cfg in ipairs(itens) do
		criarCard(list, cfg, index)
	end
end

local function conectarPrompt()
	local shopSusp = Workspace:WaitForChild("ShopSusp", TIMEOUT)
	if not shopSusp then
		warn("[LojaSuspUI] ShopSusp nao encontrada.")
		return
	end
	local partCompra = shopSusp:WaitForChild("Compra", TIMEOUT)
	if not partCompra then
		warn("[LojaSuspUI] ShopSusp.Compra em falta.")
		return
	end
	prompt = partCompra:WaitForChild("ProximityPrompt", TIMEOUT)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		warn("[LojaSuspUI] ProximityPrompt em falta.")
		return
	end

	prompt.Triggered:Connect(function(who)
		if who == player then
			abrirMenu()
		end
	end)
end

construirUI()
conectarPrompt()
atualizarCards()

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then
		return
	end
	local levelValue = leaderstats:WaitForChild("Level", 15)
	if levelValue then
		levelValue.Changed:Connect(atualizarCards)
		atualizarCards()
	end
end)
