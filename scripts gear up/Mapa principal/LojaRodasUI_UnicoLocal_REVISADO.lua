-- CH Corporations - Loja de Rodas (LocalScript unico)
-- Coloque este LocalScript em StarterPlayerScripts.
-- Ele cria a UI do zero, abre/fecha via ProximityPrompt e processa compra.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TIMEOUT = 60
local COMPRA_DEBOUNCE = 0.55

local comprarEvento = ReplicatedStorage:WaitForChild("ComprarRodaEvent", TIMEOUT)
local guiaEvent = ReplicatedStorage:WaitForChild("GuiaVisualEvent", TIMEOUT)
local configModule = ReplicatedStorage:WaitForChild("LojaRodasConfig", TIMEOUT)
if not comprarEvento or not comprarEvento:IsA("RemoteEvent") then
	warn("[LojaRodasUI] ComprarRodaEvent em falta/invalido.")
	return
end
if not configModule or not configModule:IsA("ModuleScript") then
	warn("[LojaRodasUI] LojaRodasConfig em falta no ReplicatedStorage.")
	return
end
if not guiaEvent or not guiaEvent:IsA("RemoteEvent") then
	warn("[LojaRodasUI] GuiaVisualEvent em falta/invalido (beam desativado).")
end

local config = require(configModule)
local uiCfg = config.UI or {}
local rodas = config.Rodas or {}

local ultimoClick = 0
local cards = {}
local frameTudo
local uiScale
local prompt
local menuAberto = false
local tweenAtual
local guiaEstado = {
	pasta = nil,
	a0 = nil,
	a1 = nil,
	hb = nil,
}

local function limparGuia()
	if guiaEstado.hb then
		guiaEstado.hb:Disconnect()
		guiaEstado.hb = nil
	end
	if guiaEstado.pasta then
		guiaEstado.pasta:Destroy()
		guiaEstado.pasta = nil
	end
	if guiaEstado.a0 then
		guiaEstado.a0:Destroy()
		guiaEstado.a0 = nil
	end
	if guiaEstado.a1 then
		guiaEstado.a1:Destroy()
		guiaEstado.a1 = nil
	end
end

local function lerLevelAtual()
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue and (levelValue:IsA("IntValue") or levelValue:IsA("NumberValue")) then
		return math.max(0, math.floor(levelValue.Value))
	end
	return 0
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
	tweenAtual = TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	tweenAtual:Play()
end

local function fecharMenu()
	if not menuAberto or not frameTudo then
		return
	end
	pararTween()
	tweenAtual = TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0,
	})
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
		local roda = item.roda
		local botao = item.botao
		local price = item.precoLabel
		local tipo = item.tipoLabel

		local levelMin = math.max(0, math.floor(tonumber(roda.levelMin) or 1))
		local vip = roda.vip == true
		if vip then
			price.Text = "VIP"
			tipo.Text = "Acesso: Produto VIP"
			botao.Text = "Comprar VIP"
			botao.BackgroundColor3 = Color3.fromRGB(255, 177, 36)
		else
			local preco = math.max(0, math.floor(tonumber(roda.preco) or 0))
			price.Text = "$" .. tostring(preco)
			tipo.Text = "Acesso: Dinheiro"
			if levelAtual < levelMin then
				botao.Text = "Nivel " .. tostring(levelMin)
				botao.BackgroundColor3 = Color3.fromRGB(121, 36, 36)
			else
				botao.Text = "Comprar"
				botao.BackgroundColor3 = Color3.fromRGB(76, 216, 126)
			end
		end
	end
end

local function conectarCompra(roda, botao)
	botao.Activated:Connect(function()
		local agora = os.clock()
		if agora - ultimoClick < COMPRA_DEBOUNCE then
			return
		end

		local key = roda.key or "Roda_X"
		local vip = roda.vip == true
		local levelMin = math.max(0, math.floor(tonumber(roda.levelMin) or 1))

		if vip then
			local produtoId = tonumber(roda.passId)
			if not produtoId or produtoId <= 0 then
				warn("[LojaRodasUI] VIP sem id valido: " .. tostring(key))
				return
			end
			ultimoClick = agora
			-- Por padrao VIP usa Developer Product.
			if roda.compraGamePass == true then
				MarketplaceService:PromptGamePassPurchase(player, math.floor(produtoId))
			else
				MarketplaceService:PromptProductPurchase(player, math.floor(produtoId))
			end
			return
		end

		if lerLevelAtual() < levelMin then
			return
		end

		local preco = math.max(1, math.floor(tonumber(roda.preco) or 0))
		ultimoClick = agora
		comprarEvento:FireServer(key, preco, levelMin)
	end)
end

local function criarCard(parent, roda, index)
	local card = Instance.new("Frame")
	card.Name = tostring(roda.key or ("Roda_" .. index))
	card.LayoutOrder = index
	card.BackgroundColor3 = Color3.fromRGB(31, 33, 43)
	card.BorderSizePixel = 0
	card.Size = UDim2.new(0, 148, 0, 198)
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
	img.BackgroundColor3 = Color3.fromRGB(242, 242, 242)
	img.BorderSizePixel = 0
	img.Size = UDim2.new(1, -18, 0, 78)
	img.Position = UDim2.new(0, 9, 0, 8)
	img.Image = normalizarImagem(roda.imageId)
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = card

	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = UDim.new(0, 8)
	imgCorner.Parent = img

	criarLabel(card, "NomeRoda", tostring(roda.nome or roda.key or "Roda"), UDim2.new(1, -12, 0, 26), UDim2.new(0, 6, 0, 90), 26, Color3.fromRGB(255, 255, 255), 0.45)
	local precoLabel = criarLabel(card, "PrecoLabel", "", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0, 118), 20, Color3.fromRGB(255, 200, 70), 0.55)
	local tipoLabel = criarLabel(card, "TipoLabel", "", UDim2.new(1, -12, 0, 16), UDim2.new(0, 6, 0, 136), 16, Color3.fromRGB(205, 235, 255), 0.8)

	local btn = Instance.new("TextButton")
	btn.Name = "Comprar"
	btn.Size = UDim2.new(1, -12, 0, 36)
	btn.Position = UDim2.new(0, 6, 1, -42)
	btn.BackgroundColor3 = Color3.fromRGB(76, 216, 126)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 24
	btn.Text = "Comprar"
	btn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	conectarCompra(roda, btn)
	table.insert(cards, { roda = roda, botao = btn, precoLabel = precoLabel, tipoLabel = tipoLabel })
end

local function construirUI()
	local guiName = uiCfg.ScreenGuiName or "LojaRodasUI"
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

	local title = criarLabel(frameTudo, "Title", uiCfg.Title or "Loja De Rodas", UDim2.new(1, -70, 0, 44), UDim2.new(0, 14, 0, 8), 34, Color3.fromRGB(255, 255, 255), 0.65)
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
	list.Name = "WheelList"
	list.Size = UDim2.new(1, -20, 1, -68)
	list.Position = UDim2.new(0, 10, 0, 56)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frameTudo

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 148, 0, 198)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	for index, roda in ipairs(rodas) do
		criarCard(list, roda, index)
	end
end

local function conectarPrompt()
	local shopR = Workspace:WaitForChild("ShopR", TIMEOUT)
	if not shopR then
		warn("[LojaRodasUI] ShopR não encontrada.")
		return
	end
	local partCompra = shopR:WaitForChild("Compra", TIMEOUT)
	if not partCompra then
		warn("[LojaRodasUI] ShopR.Compra em falta.")
		return
	end
	prompt = partCompra:WaitForChild("ProximityPrompt", TIMEOUT)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		warn("[LojaRodasUI] ProximityPrompt em falta.")
		return
	end

	prompt.Triggered:Connect(function(who)
		if who == player then
			abrirMenu()
		end
	end)
end

local function resolverParteAlvo(inst)
	if typeof(inst) ~= "Instance" then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function ligarGuiaVisual()
	if not guiaEvent or not guiaEvent:IsA("RemoteEvent") then
		return
	end
	guiaEvent.OnClientEvent:Connect(function(alvoBruto)
		local alvo = resolverParteAlvo(alvoBruto)
		if not alvo or not alvo.Parent then
			return
		end
		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end

		limparGuia()

		local pasta = Instance.new("Folder")
		pasta.Name = "GuiaAtivoRodas"
		pasta.Parent = character

		local a0 = Instance.new("Attachment")
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Parent = alvo

		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(Color3.fromRGB(85, 255, 127))
		beam.Texture = "rbxassetid://3371283711"
		beam.TextureLength = 20
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureSpeed = -5
		beam.FaceCamera = true
		beam.Width0 = 2
		beam.Width1 = 2
		beam.Parent = pasta

		guiaEstado.pasta = pasta
		guiaEstado.a0 = a0
		guiaEstado.a1 = a1
		guiaEstado.hb = RunService.Heartbeat:Connect(function()
			if not root.Parent or not alvo.Parent then
				limparGuia()
				return
			end
			local dist = (root.Position - alvo.Position).Magnitude
			if dist < 8 then
				limparGuia()
			end
		end)
	end)
end

construirUI()
conectarPrompt()
ligarGuiaVisual()
atualizarCards()

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then
		return
	end
	local levelValue = leaderstats:WaitForChild("Level", 15)
	if levelValue then
		levelValue.Changed:Connect(atualizarCards)
	end
end)
