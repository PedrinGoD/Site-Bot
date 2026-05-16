-- CH Corporations - Concessionária: UI 100% por script + ProximityPrompt
-- StarterPlayerScripts: cria já o ScreenGui "CH_ConcessionariaUI" no PlayerGui (vês no Explorer).
-- O catálogo e o RemoteEvent carregam em background; se faltar algo, aparece mensagem de erro na UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NOME_SCREEN_GUI = "CH_ConcessionariaUI"
local TIMEOUT_MAPA = 60

local ultimoClickCompra = 0
local DEBOUNCE = 0.5

local cardsPorKey = {}
local listaCategorias = {}
local abaAtual = "A"

local menuAberto = false
local tweenAtual = nil
local promptRef = nil
local frameShell = nil
local uiScaleShell = nil
local comprarEventoRef = nil
local catalogoCarregado = nil

local function moeda(v)
	local n = math.max(0, math.floor(tonumber(v) or 0))
	local s = tostring(n)
	while true do
		local rep, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1.%2")
		s = rep
		if k == 0 then
			break
		end
	end
	return "R$ " .. s
end

local function pararTweenAtual()
	if tweenAtual then
		tweenAtual:Cancel()
		tweenAtual = nil
	end
end

local function abrirMenuLoja()
	if menuAberto or not frameShell then
		return
	end
	menuAberto = true
	frameShell.Visible = true
	if promptRef and promptRef.Parent then
		promptRef.Enabled = false
	end
	pararTweenAtual()
	local animacao = TweenService:Create(uiScaleShell, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
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

local function fecharMenuLoja()
	if not menuAberto or not frameShell then
		return
	end
	pararTweenAtual()
	local animacao = TweenService:Create(uiScaleShell, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0,
	})
	tweenAtual = animacao
	animacao.Completed:Once(function()
		if tweenAtual ~= animacao then
			return
		end
		tweenAtual = nil
		frameShell.Visible = false
		menuAberto = false
		if promptRef and promptRef.Parent then
			promptRef.Enabled = true
		end
	end)
	animacao:Play()
end

--- Cria ScreenGui de imediato (para aparecer no Explorer). Conteúdo real vem depois do bootstrap.
local function criarShellBootstrap()
	local existente = playerGui:FindFirstChild(NOME_SCREEN_GUI)
	if existente then
		existente:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = NOME_SCREEN_GUI
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = true
	screenGui.Parent = playerGui

	frameShell = Instance.new("Frame")
	frameShell.Name = "PainelConcessionaria"
	frameShell.BackgroundTransparency = 1
	frameShell.Size = UDim2.fromScale(1, 1)
	frameShell.Visible = false
	frameShell.Parent = screenGui

	uiScaleShell = Instance.new("UIScale")
	uiScaleShell.Parent = frameShell
	uiScaleShell.Scale = 0

	local boot = Instance.new("TextLabel")
	boot.Name = "BootstrapStatus"
	boot.BackgroundTransparency = 0.3
	boot.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	boot.Size = UDim2.new(0.85, 0, 0, 120)
	boot.Position = UDim2.new(0.5, 0, 0.5, 0)
	boot.AnchorPoint = Vector2.new(0.5, 0.5)
	boot.Font = Enum.Font.Gotham
	boot.TextSize = 16
	boot.TextColor3 = Color3.fromRGB(230, 230, 230)
	boot.TextWrapped = true
	boot.Text = "Concessionária: a carregar catálogo e eventos…"
	boot.Parent = frameShell

	print("[ConcessionariaUI] ScreenGui criada:", NOME_SCREEN_GUI)
	return boot
end

local function limparConteudoLoja()
	for _, ch in ipairs(frameShell:GetChildren()) do
		if ch ~= uiScaleShell and not ch:IsA("UIScale") then
			ch:Destroy()
		end
	end
end

local function jogadorJaPossui(Catalogo, nomeInventario)
	local inv = player:FindFirstChild("InventarioVeiculos")
	if not inv then
		return false
	end
	local alvo = Catalogo.NormalizarNome(nomeInventario)
	for _, item in ipairs(inv:GetChildren()) do
		local k = Catalogo.NormalizarNome(item.Name)
		if k and k == alvo then
			return true
		end
	end
	return false
end

local function atualizarVisuais(Catalogo, MAPA_CARROS)
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	local levelAtual = (levelValue and tonumber(levelValue.Value)) or 0
	levelAtual = math.max(0, math.floor(levelAtual))

	for key, card in pairs(cardsPorKey) do
		local cfg = MAPA_CARROS[key]
		if cfg then
			local colDir = card:FindFirstChild("ColunaDireita")
			local btn = colDir and colDir:FindFirstChild("BuyButton")
			local valorLbl = colDir and colDir:FindFirstChild("ValorLabel")
			local detalhes = card:FindFirstChild("Mid") and card.Mid:FindFirstChild("Detalhes")
				or card:FindFirstChild("Detalhes")
			if btn and detalhes and valorLbl then
				local levelMin = math.max(0, math.floor(tonumber(cfg.LevelMin) or 0))
				local possui = jogadorJaPossui(Catalogo, cfg.NomeInventario)
				detalhes.Text = "Categoria " .. tostring(cfg.Categoria or "-") .. "  |  Nível " .. tostring(levelMin)

				valorLbl.Text = cfg.Premium and "VIP" or moeda(cfg.Preco)

				if possui then
					btn.Text = "Comprado"
					btn.BackgroundColor3 = Color3.fromRGB(151, 94, 42)
					btn.Interactable = false
				elseif cfg.Premium then
					btn.Text = "Comprar VIP"
					btn.BackgroundColor3 = Color3.fromRGB(218, 140, 44)
					btn.Interactable = true
				elseif levelAtual < levelMin then
					btn.Text = "Nv. " .. tostring(levelMin)
					btn.BackgroundColor3 = Color3.fromRGB(90, 47, 47)
					btn.Interactable = true
				else
					btn.Text = "Comprar"
					btn.BackgroundColor3 = Color3.fromRGB(60, 151, 83)
					btn.Interactable = true
				end
			end
			card.Visible = (card:GetAttribute("CategoriaCard") == abaAtual)
		end
	end
end

local function animarCardsDaAba(cardsPorKey, cat)
	for _, card in pairs(cardsPorKey) do
		local match = card:GetAttribute("CategoriaCard") == cat
		card.Visible = match
		if match then
			local us = card:FindFirstChildOfClass("UIScale")
			if not us then
				us = Instance.new("UIScale")
				us.Parent = card
			end
			us.Scale = 0.9
			TweenService:Create(us, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end
end

local function montarCatalogoUI(Catalogo, MAPA_CARROS)
	cardsPorKey = {}
	listaCategorias = {}
	abaAtual = Catalogo.CATEGORIAS[1] or "A"

	local tituloLoja = (type(Catalogo.TITULO_LOJA) == "string" and Catalogo.TITULO_LOJA ~= "") and Catalogo.TITULO_LOJA
		or "Gear Shop"
	local subtituloLoja = (type(Catalogo.SUBTITULO_LOJA) == "string") and Catalogo.SUBTITULO_LOJA
		or "Catálogo por categoria"

	limparConteudoLoja()

	local root = Instance.new("Frame")
	root.Name = "ConcessionariaCategoriasRoot"
	root.BackgroundColor3 = Color3.fromRGB(14, 16, 28)
	root.BorderSizePixel = 0
	root.Size = UDim2.new(0.92, 0, 0.88, 0)
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Parent = frameShell

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = root

	local gradRoot = Instance.new("UIGradient")
	gradRoot.Rotation = 125
	gradRoot.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 14, 32)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(28, 16, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 22, 38)),
	})
	gradRoot.Parent = root

	local strokeRoot = Instance.new("UIStroke")
	strokeRoot.Color = Color3.fromRGB(120, 220, 255)
	strokeRoot.Thickness = 1.8
	strokeRoot.Transparency = 0.25
	strokeRoot.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	strokeRoot.Parent = root

	local topo = Instance.new("Frame")
	topo.Name = "TopoCategorias"
	topo.BackgroundColor3 = Color3.fromRGB(26, 30, 39)
	topo.BackgroundTransparency = 0.15
	topo.BorderSizePixel = 0
	topo.Size = UDim2.new(1, 0, 0, 88)
	topo.Parent = root

	local topoCorner = Instance.new("UICorner")
	topoCorner.CornerRadius = UDim.new(0, 14)
	topoCorner.Parent = topo

	local titulo = Instance.new("TextLabel")
	titulo.Name = "Titulo"
	titulo.BackgroundTransparency = 1
	titulo.Position = UDim2.new(0, 14, 0, 8)
	titulo.Size = UDim2.new(1, -130, 0, 22)
	titulo.Font = Enum.Font.GothamBold
	titulo.Text = tituloLoja
	titulo.TextColor3 = Color3.fromRGB(245, 250, 255)
	titulo.TextSize = 20
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.Parent = topo

	local subtitulo = Instance.new("TextLabel")
	subtitulo.Name = "Subtitulo"
	subtitulo.BackgroundTransparency = 1
	subtitulo.Position = UDim2.new(0, 14, 0, 32)
	subtitulo.Size = UDim2.new(1, -130, 0, 16)
	subtitulo.Font = Enum.Font.Gotham
	subtitulo.Text = subtituloLoja
	subtitulo.TextColor3 = Color3.fromRGB(150, 190, 220)
	subtitulo.TextSize = 13
	subtitulo.TextXAlignment = Enum.TextXAlignment.Left
	subtitulo.Parent = topo

	local btnFechar = Instance.new("TextButton")
	btnFechar.Name = "BotaoFechar"
	btnFechar.Text = "X"
	btnFechar.Font = Enum.Font.GothamBold
	btnFechar.TextSize = 18
	btnFechar.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnFechar.BackgroundColor3 = Color3.fromRGB(200, 60, 80)
	btnFechar.Size = UDim2.fromOffset(36, 36)
	btnFechar.Position = UDim2.new(1, -44, 0, 11)
	btnFechar.AutoButtonColor = true
	btnFechar.Parent = root
	local fecharCorner = Instance.new("UICorner")
	fecharCorner.CornerRadius = UDim.new(1, 0)
	fecharCorner.Parent = btnFechar
	local fecharStroke = Instance.new("UIStroke")
	fecharStroke.Color = Color3.fromRGB(255, 140, 170)
	fecharStroke.Thickness = 1
	fecharStroke.Transparency = 0.4
	fecharStroke.Parent = btnFechar
	btnFechar.Activated:Connect(fecharMenuLoja)

	local categoriasHolder = Instance.new("Frame")
	categoriasHolder.Name = "CategoriasHolder"
	categoriasHolder.BackgroundTransparency = 1
	categoriasHolder.Position = UDim2.new(0, 14, 0, 50)
	categoriasHolder.Size = UDim2.new(1, -28, 0, 0)
	categoriasHolder.AutomaticSize = Enum.AutomaticSize.Y
	categoriasHolder.Parent = topo

	local catLayout = Instance.new("UIListLayout")
	catLayout.FillDirection = Enum.FillDirection.Horizontal
	catLayout.Padding = UDim.new(0, 8)
	catLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	catLayout.Parent = categoriasHolder

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ListaCarros"
	scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	scroll.BackgroundTransparency = 0.35
	scroll.Position = UDim2.new(0, 12, 0, 98)
	scroll.Size = UDim2.new(1, -24, 1, -110)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 200, 255)
	scroll.ScrollBarImageTransparency = 0.3
	scroll.BorderSizePixel = 0
	scroll.Parent = root

	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 10)
	scrollCorner.Parent = scroll

	local scrollStroke = Instance.new("UIStroke")
	scrollStroke.Color = Color3.fromRGB(80, 180, 255)
	scrollStroke.Transparency = 0.65
	scrollStroke.Thickness = 1
	scrollStroke.Parent = scroll

	local padScroll = Instance.new("UIPadding")
	padScroll.PaddingTop = UDim.new(0, 8)
	padScroll.PaddingBottom = UDim.new(0, 8)
	padScroll.PaddingLeft = UDim.new(0, 8)
	padScroll.PaddingRight = UDim.new(0, 8)
	padScroll.Parent = scroll

	local cardsLayout = Instance.new("UIListLayout")
	cardsLayout.Padding = UDim.new(0, 10)
	cardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardsLayout.Parent = scroll

	local function estiloAbaSelecionada(btn, selecionado)
		local st = btn:FindFirstChildOfClass("UIStroke")
		if not st then
			st = Instance.new("UIStroke")
			st.Parent = btn
		end
		if selecionado then
			btn.BackgroundColor3 = Color3.fromRGB(40, 90, 180)
			st.Color = Color3.fromRGB(120, 220, 255)
			st.Thickness = 1.5
			st.Transparency = 0.2
			TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
				BackgroundColor3 = Color3.fromRGB(55, 110, 220),
			}):Play()
		else
			btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
			st.Color = Color3.fromRGB(70, 90, 120)
			st.Thickness = 1
			st.Transparency = 0.5
		end
	end

	for _, cat in ipairs(Catalogo.CATEGORIAS) do
		local b = Instance.new("TextButton")
		b.Name = "Cat_" .. cat
		b.AutoButtonColor = true
		b.Size = UDim2.fromOffset(math.max(52, 7 + #cat * 6), 28)
		b.Font = Enum.Font.GothamBold
		b.Text = cat
		b.TextSize = 13
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Parent = categoriasHolder
		listaCategorias[cat] = b
		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 6)
		bCorner.Parent = b

		b.Activated:Connect(function()
			abaAtual = cat
			for nomeCat, btn in pairs(listaCategorias) do
				estiloAbaSelecionada(btn, nomeCat == abaAtual)
			end
			scroll.CanvasPosition = Vector2.new(0, 0)
			animarCardsDaAba(cardsPorKey, cat)
		end)
	end

	for _, cfg in ipairs(Catalogo.CARROS) do
		local key = Catalogo.NormalizarNome(cfg.NomeInventario or cfg.NomeExibicao)
		if key then
			local card = Instance.new("Frame")
			card.Name = "Carro_" .. key
			card.Size = UDim2.new(1, 0, 0, 104)
			card.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
			card.BorderSizePixel = 0
			card.Parent = scroll
			card:SetAttribute("CategoriaCard", cfg.Categoria or "")

			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 10)
			cardCorner.Parent = card

			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = Color3.fromRGB(60, 140, 200)
			cardStroke.Transparency = 0.7
			cardStroke.Thickness = 1
			cardStroke.Parent = card

			local thumb = Instance.new("ImageLabel")
			thumb.Name = "Thumb"
			thumb.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
			thumb.BorderSizePixel = 0
			thumb.Size = UDim2.fromOffset(132, 80)
			thumb.Position = UDim2.new(0, 10, 0.5, -40)
			thumb.ScaleType = Enum.ScaleType.Crop
			local imgUrl = ""
			if type(Catalogo.ResolverImagem) == "function" then
				imgUrl = Catalogo.ResolverImagem(cfg) or ""
			end
			thumb.Image = imgUrl
			thumb.Parent = card
			local thumbC = Instance.new("UICorner")
			thumbC.CornerRadius = UDim.new(0, 8)
			thumbC.Parent = thumb
			local thumbS = Instance.new("UIStroke")
			thumbS.Color = Color3.fromRGB(100, 200, 255)
			thumbS.Transparency = 0.6
			thumbS.Thickness = 1
			thumbS.Parent = thumb

			local mid = Instance.new("Frame")
			mid.Name = "Mid"
			mid.BackgroundTransparency = 1
			mid.Position = UDim2.new(0, 152, 0, 10)
			mid.Size = UDim2.new(1, -300, 1, -20)
			mid.Parent = card

			local nome = Instance.new("TextLabel")
			nome.Name = "Nome"
			nome.BackgroundTransparency = 1
			nome.Position = UDim2.new(0, 0, 0, 0)
			nome.Size = UDim2.new(1, 0, 0, 22)
			nome.Font = Enum.Font.GothamBold
			nome.TextSize = 17
			nome.TextXAlignment = Enum.TextXAlignment.Left
			nome.TextColor3 = Color3.fromRGB(245, 248, 255)
			nome.Text = cfg.NomeExibicao or string.gsub(cfg.NomeInventario or key, "_", " ")
			nome.Parent = mid

			local detalhes = Instance.new("TextLabel")
			detalhes.Name = "Detalhes"
			detalhes.BackgroundTransparency = 1
			detalhes.Position = UDim2.new(0, 0, 0, 26)
			detalhes.Size = UDim2.new(1, 0, 0, 18)
			detalhes.Font = Enum.Font.Gotham
			detalhes.TextSize = 13
			detalhes.TextXAlignment = Enum.TextXAlignment.Left
			detalhes.TextColor3 = Color3.fromRGB(160, 185, 210)
			detalhes.Text = "Categoria " .. tostring(cfg.Categoria or "-")
			detalhes.Parent = mid

			local colDir = Instance.new("Frame")
			colDir.Name = "ColunaDireita"
			colDir.BackgroundTransparency = 1
			colDir.AnchorPoint = Vector2.new(1, 0.5)
			colDir.Position = UDim2.new(1, -12, 0.5, 0)
			colDir.Size = UDim2.fromOffset(160, 0)
			colDir.AutomaticSize = Enum.AutomaticSize.Y
			colDir.Parent = card

			local listDir = Instance.new("UIListLayout")
			listDir.FillDirection = Enum.FillDirection.Vertical
			listDir.HorizontalAlignment = Enum.HorizontalAlignment.Right
			listDir.VerticalAlignment = Enum.VerticalAlignment.Center
			listDir.SortOrder = Enum.SortOrder.LayoutOrder
			listDir.Padding = UDim.new(0, 10)
			listDir.Parent = colDir

			local valor = Instance.new("TextLabel")
			valor.Name = "ValorLabel"
			valor.BackgroundTransparency = 1
			valor.Size = UDim2.new(1, 0, 0, 0)
			valor.AutomaticSize = Enum.AutomaticSize.Y
			valor.Font = Enum.Font.GothamBold
			valor.TextSize = 15
			valor.TextXAlignment = Enum.TextXAlignment.Right
			valor.TextYAlignment = Enum.TextYAlignment.Top
			valor.TextWrapped = true
			valor.TextColor3 = Color3.fromRGB(255, 230, 140)
			valor.Text = cfg.Premium and "VIP" or moeda(cfg.Preco)
			valor.LayoutOrder = 1
			valor.Parent = colDir

			local btn = Instance.new("TextButton")
			btn.Name = "BuyButton"
			btn.Size = UDim2.new(1, 0, 0, 36)
			btn.LayoutOrder = 2
			btn.AutoButtonColor = true
			btn.Font = Enum.Font.GothamBold
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.TextSize = 14
			btn.BorderSizePixel = 0
			btn.Parent = colDir
			local btnC = Instance.new("UICorner")
			btnC.CornerRadius = UDim.new(0, 8)
			btnC.Parent = btn

			local scale = Instance.new("UIScale")
			scale.Scale = 1
			scale.Parent = card

			btn.Activated:Connect(function()
				local agora = os.clock()
				if (agora - ultimoClickCompra) < DEBOUNCE then
					return
				end
				if jogadorJaPossui(Catalogo, cfg.NomeInventario) then
					return
				end

				local leaderstats = player:FindFirstChild("leaderstats")
				local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
				local levelAtual = (levelValue and tonumber(levelValue.Value)) or 0
				local levelMin = math.max(0, math.floor(tonumber(cfg.LevelMin) or 0))

				if cfg.Premium then
					local passId = tonumber(cfg.PassID)
					if passId and passId > 0 then
						ultimoClickCompra = agora
						MarketplaceService:PromptGamePassPurchase(player, passId)
					end
					return
				end

				if levelAtual < levelMin then
					return
				end

				if not comprarEventoRef then
					warn("[ConcessionariaUI] ComprarVeiculoEvent ainda não disponível.")
					return
				end

				ultimoClickCompra = agora
				comprarEventoRef:FireServer(cfg.NomeInventario)
			end)

			cardsPorKey[key] = card
		end
	end

	for nomeCat, btn in pairs(listaCategorias) do
		estiloAbaSelecionada(btn, nomeCat == abaAtual)
	end

	atualizarVisuais(Catalogo, MAPA_CARROS)
	animarCardsDaAba(cardsPorKey, abaAtual)
	print("[ConcessionariaUI] Catálogo montado com", #(Catalogo.CARROS), "veículo(s).")
end

--- 1) Shell já existe no Explorer
local bootstrapLabel = criarShellBootstrap()

--- 2) Carregar dependências sem bloquear a criação do ScreenGui
task.spawn(function()
	local ev = ReplicatedStorage:WaitForChild("ComprarVeiculoEvent", 120)
	local mod = ReplicatedStorage:WaitForChild("ConcessionariaCatalogo", 120)

	if not ev or not ev:IsA("RemoteEvent") then
		if bootstrapLabel and bootstrapLabel.Parent then
			bootstrapLabel.Text = "ERRO: coloca um RemoteEvent chamado ComprarVeiculoEvent em ReplicatedStorage (servidor da concessionária)."
		end
		warn("[ConcessionariaUI] ComprarVeiculoEvent em falta após 120s.")
		return
	end
	if not mod or not mod:IsA("ModuleScript") then
		if bootstrapLabel and bootstrapLabel.Parent then
			bootstrapLabel.Text = "ERRO: coloca o ModuleScript ConcessionariaCatalogo em ReplicatedStorage."
		end
		warn("[ConcessionariaUI] ConcessionariaCatalogo (ModuleScript) em falta após 120s.")
		return
	end

	comprarEventoRef = ev

	local ok, CatalogoOrErr = pcall(function()
		return require(mod)
	end)
	if not ok then
		if bootstrapLabel and bootstrapLabel.Parent then
			bootstrapLabel.Text = "ERRO no ModuleScript ConcessionariaCatalogo:\n" .. tostring(CatalogoOrErr)
		end
		warn("[ConcessionariaUI] require falhou:", CatalogoOrErr)
		return
	end

	local Catalogo = CatalogoOrErr
	local MAPA_CARROS = Catalogo.MapaPorNome()
	catalogoCarregado = Catalogo

	if bootstrapLabel then
		bootstrapLabel:Destroy()
	end

	montarCatalogoUI(Catalogo, MAPA_CARROS)

	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 20)
		if leaderstats then
			local levelValue = leaderstats:WaitForChild("Level", 20)
			if levelValue then
				levelValue.Changed:Connect(function()
					atualizarVisuais(Catalogo, MAPA_CARROS)
				end)
			end
		end

		local inv = player:WaitForChild("InventarioVeiculos", 30)
		if inv then
			inv.ChildAdded:Connect(function()
				atualizarVisuais(Catalogo, MAPA_CARROS)
			end)
			inv.ChildRemoved:Connect(function()
				atualizarVisuais(Catalogo, MAPA_CARROS)
			end)
		end

		player.ChildAdded:Connect(function(ch)
			if ch.Name == "InventarioVeiculos" then
				ch.ChildAdded:Connect(function()
					atualizarVisuais(Catalogo, MAPA_CARROS)
				end)
				ch.ChildRemoved:Connect(function()
					atualizarVisuais(Catalogo, MAPA_CARROS)
				end)
				atualizarVisuais(Catalogo, MAPA_CARROS)
			end
		end)
	end)
end)

--- ProximityPrompt (mapa)
task.defer(function()
	local concessionariaModel = Workspace:WaitForChild("Concessionaria", TIMEOUT_MAPA)
	if not concessionariaModel then
		warn("[ConcessionariaUI] Workspace.Concessionaria não encontrada.")
		return
	end
	local partCompra = concessionariaModel:WaitForChild("Compra", TIMEOUT_MAPA)
	if not partCompra then
		warn("[ConcessionariaUI] Concessionaria.Compra em falta.")
		return
	end
	local prompt = partCompra:WaitForChild("ProximityPrompt", TIMEOUT_MAPA)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		warn("[ConcessionariaUI] ProximityPrompt em Compra em falta.")
		return
	end
	promptRef = prompt
	prompt.Triggered:Connect(function(quem)
		if typeof(quem) ~= "Instance" or not quem:IsA("Player") or quem ~= player then
			return
		end
		abrirMenuLoja()
	end)
end)

--- ESC fecha
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and menuAberto then
		fecharMenuLoja()
	end
end)

--- Debug: F6 abre o menu (se o prompt falhar)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F6 then
		if menuAberto then
			fecharMenuLoja()
		else
			abrirMenuLoja()
		end
	end
end)
