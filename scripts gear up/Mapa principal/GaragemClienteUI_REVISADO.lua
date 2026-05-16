-- CH Corporations - Garagem (UI 100% por script)
-- Abas: AA+, A, B, C, D (por cfg.Categoria) + Diamante / Gold / Bronze (GaragemVip no catálogo; acesso por VipSalvo + gamepasses).
-- StarterPlayerScripts. Compatível com SpawnVeiculosPessoais / Central de veículos.
-- Prompt: liga automaticamente a ProximityPrompt cujo Model ancestral tenha "Garagem" no nome (ou atributo Model.GaragemUI=true).
--         Se o modelo tiver outro nome (ex.: só CasaDo_*), no ProximityPrompt cria Attribute bool CH_GaragemMenu = true.
-- RemoteEvents: SpawnarVeiculoGaragemEvent, GuardarVeiculoGaragemEvent, AbrirMenuGaragemEvent, AutoSpawnVIPClientEvent
-- Opcional: FavoritarCarroEvent, ConcessionariaCatalogo (thumbnails por nome do carro)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local NOME_SCREEN_GUI = "CH_GaragemUI"
local DEBOUNCE = 0.55
local imgFavOff = "rbxassetid://76044547083692"
local imgFavOn = "rbxassetid://83178015608452"

local localAtual = "Estacionamento"
-- Abas da lista: categorias AA+…D ou garagem VIP (Diamante / Gold / Bronze)
local abaListaAtual = "AA+"
local tierVipJogador = 0 -- 0=nenhum, 1=Bronze, 2=Gold, 3=Diamante (maior nível ganha)
local CATEGORIAS_ABA = { "AA+", "A", "B", "C", "D" }
local ABAS_VIP_GARAGEM = { "Diamante", "Gold", "Bronze" }
-- IDs dos gamepasses (manter iguais a GaragemVIP_REVISADO.lua)
local GP_VIP_DIAMANTE = 1746862603
local GP_VIP_GOLD = 1746268685
local GP_VIP_BRONZE = 1737108751
local botoesAba = {}
local menuAberto = false
local tweenAtual = nil
--- Todos os ProximityPrompts da garagem (pode haver mais de um; desativamos ao abrir o menu)
local promptsGaragem = {}
local promptsJaRegistrados = {}
local frameShell = nil
local uiScaleShell = nil
local scrollLista = nil
local labelContexto = nil

local spawnEv, guardarEv, abrirEv, autoEv
local favoritarEv = nil
local catalogoMod = nil
local mapaCatalogo = {}
local resolverImagem = nil

local ultimoAcao = 0
local linhasPorNome = {}
local carregandoLista = false
local listaPendente = false
--- Declarado antes de selecionarAbaGaragem (evita "attempt to call a nil value" ao clicar na aba)
local carregarListaCarros

local invConns = {}

-- Botões ficam em Row > ColDir > BtnAcao / BtnFavorito (não são filhos diretos da linha)
local function btnAcaoNaLinha(row)
	return row and row:FindFirstChild("BtnAcao", true)
end

local function btnFavoritoNaLinha(row)
	return row and row:FindFirstChild("BtnFavorito", true)
end

local function pararTween()
	if tweenAtual then
		tweenAtual:Cancel()
		tweenAtual = nil
	end
end

local function nomeCarroValido(nome)
	return type(nome) == "string" and nome ~= "" and #nome <= 120
end

local function lerCarroFavoritoSalvo()
	local carData = player:FindFirstChild("CarData")
	local favVal = carData and carData:FindFirstChild("CarroFavorito")
	if favVal and favVal:IsA("StringValue") then
		return favVal.Value
	end
	return ""
end

local function nomeModeloSpawnadoNoMundo()
	local m = Workspace:FindFirstChild(player.Name .. "sCar")
	if not m then
		return ""
	end
	local attr = m:GetAttribute("ModeloOriginal")
	return type(attr) == "string" and attr or ""
end

local function chaveCatalogo(nome)
	if resolverImagem and catalogoMod and type(catalogoMod.NormalizarNome) == "function" then
		return catalogoMod.NormalizarNome(nome)
	end
	local s = string.gsub(nome or "", "%s+", "_")
	s = string.gsub(s, "_+", "_")
	return s
end

local function chaveFlex(nome)
	local s = string.lower(tostring(nome or ""))
	s = string.gsub(s, "[%s_%-%./]+", "")
	s = string.gsub(s, "[^%w]", "")
	return s
end

local function cfgCatalogoPorNomeInventario(nomeInventario)
	local k = chaveCatalogo(nomeInventario)
	local cfg = k and mapaCatalogo[k]
	if cfg then
		return cfg
	end
	local alvo = chaveFlex(nomeInventario)
	if alvo == "" or not catalogoMod or type(catalogoMod.CARROS) ~= "table" then
		return nil
	end
	for _, item in ipairs(catalogoMod.CARROS) do
		local nInv = chaveFlex(item.NomeInventario)
		local nExb = chaveFlex(item.NomeExibicao)
		if alvo == nInv or alvo == nExb then
			return item
		end
	end
	return nil
end

local function isAbaVipNome(nome)
	return nome == "Diamante" or nome == "Gold" or nome == "Bronze"
end

local function normalizarGaragemVipDoCfg(cfg)
	if not cfg or type(cfg) ~= "table" then
		return nil
	end
	local raw = cfg.GaragemVip or cfg.VipGaragem or cfg.GaragemVIP
	if type(raw) ~= "string" then
		return nil
	end
	local l = string.lower(string.gsub(raw, "%s+", ""))
	if l == "diamante" then
		return "Diamante"
	end
	if l == "gold" then
		return "Gold"
	end
	if l == "bronze" then
		return "Bronze"
	end
	return nil
end

local function categoriaListaDoCfg(cfg)
	if cfg and type(cfg.Categoria) == "string" and cfg.Categoria ~= "" then
		return cfg.Categoria
	end
	return "D"
end

local function tierVipDeVipSalvo()
	local sv = player:FindFirstChild("VipSalvo")
	if not sv or not sv:IsA("StringValue") then
		return 0
	end
	local s = string.lower(sv.Value)
	local best = 0
	if string.find(s, "diamante", 1, true) then
		best = 3
	end
	if string.find(s, "gold", 1, true) then
		best = math.max(best, 2)
	end
	if string.find(s, "bronze", 1, true) then
		best = math.max(best, 1)
	end
	return best
end

local function tierVipComGamePasses()
	local best = tierVipDeVipSalvo()
	local function owns(id)
		local ok, r = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		return ok and r == true
	end
	if owns(GP_VIP_DIAMANTE) then
		best = math.max(best, 3)
	end
	if owns(GP_VIP_GOLD) then
		best = math.max(best, 2)
	end
	if owns(GP_VIP_BRONZE) then
		best = math.max(best, 1)
	end
	return best
end

local function tierMinimoParaAbaVip(aba)
	if aba == "Diamante" then
		return 3
	end
	if aba == "Gold" then
		return 2
	end
	if aba == "Bronze" then
		return 1
	end
	return 99
end

local function podeVerAbaVip(aba)
	return tierVipJogador >= tierMinimoParaAbaVip(aba)
end

local function atualizarAparenciaAbas()
	for _, btn in pairs(botoesAba) do
		if btn and btn.Parent then
			local id = btn:GetAttribute("AbaId")
			if type(id) == "string" then
				local vipAba = isAbaVipNome(id)
				local locked = vipAba and not podeVerAbaVip(id)
				local sel = id == abaListaAtual
				if locked then
					btn.BackgroundColor3 = Color3.fromRGB(38, 40, 52)
					btn.TextColor3 = Color3.fromRGB(100, 105, 120)
					btn.Active = false
				elseif sel then
					btn.BackgroundColor3 = Color3.fromRGB(70, 140, 255)
					btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					btn.Active = true
				else
					btn.BackgroundColor3 = Color3.fromRGB(34, 40, 58)
					btn.TextColor3 = Color3.fromRGB(200, 210, 230)
					btn.Active = true
				end
			end
		end
	end
end

local function selecionarAbaGaragem(novoId)
	if isAbaVipNome(novoId) and not podeVerAbaVip(novoId) then
		return
	end
	abaListaAtual = novoId
	atualizarAparenciaAbas()
	carregarListaCarros()
end

local function urlThumbDoCarro(nomeInventario)
	local cfg = cfgCatalogoPorNomeInventario(nomeInventario)
	if cfg and type(resolverImagem) == "function" then
		return resolverImagem(cfg) or ""
	end
	return ""
end

local function desligarWatchInv()
	for _, c in ipairs(invConns) do
		if c and c.Connected then
			c:Disconnect()
		end
	end
	table.clear(invConns)
end

local function atualizarContextoTexto()
	if labelContexto then
		local s = localAtual
		if s == "Casa" then
			labelContexto.Text = "Spawn: garagem da casa"
		else
			labelContexto.Text = "Spawn: estacionamento público"
		end
	end
end

local function atualizarBotoesLinhas()
	local modeloAtual = nomeModeloSpawnadoNoMundo()
	local favSalvo = lerCarroFavoritoSalvo()

	for nomeCarro, row in pairs(linhasPorNome) do
		if row and row.Parent then
			local btn = btnAcaoNaLinha(row)
			local fav = btnFavoritoNaLinha(row)
			if btn and btn:IsA("GuiButton") then
				if nomeCarro == modeloAtual then
					btn.Text = "Guardar"
					btn.BackgroundColor3 = Color3.fromRGB(170, 45, 55)
				else
					btn.Text = "Spawnar"
					btn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
				end
			end
			if fav and fav:IsA("ImageButton") then
				fav.Image = (nomeCarro == favSalvo) and imgFavOn or imgFavOff
			end
		end
	end
end

carregarListaCarros = function()
	if carregandoLista then
		listaPendente = true
		return
	end
	carregandoLista = true

	for _, ch in ipairs(scrollLista:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
	table.clear(linhasPorNome)

	local inv = player:FindFirstChild("InventarioVeiculos") or player:WaitForChild("InventarioVeiculos", 15)
	if not inv then
		carregandoLista = false
		if listaPendente then
			listaPendente = false
			task.defer(carregarListaCarros)
		end
		return
	end

	desligarWatchInv()
	invConns[#invConns + 1] = inv.ChildAdded:Connect(function()
		if menuAberto then
			task.defer(carregarListaCarros)
		end
	end)
	invConns[#invConns + 1] = inv.ChildRemoved:Connect(function()
		if menuAberto then
			task.defer(carregarListaCarros)
		end
	end)

	local totalInvValidos = 0
	for _, carro in ipairs(inv:GetChildren()) do
		if nomeCarroValido(carro.Name) then
			totalInvValidos += 1
		end
	end

	local count = 0
	for _, carro in ipairs(inv:GetChildren()) do
		if nomeCarroValido(carro.Name) then
			local nomeCarro = carro.Name
			local cfgInv = cfgCatalogoPorNomeInventario(nomeCarro)
			local vCar = normalizarGaragemVipDoCfg(cfgInv)
			local cCar = categoriaListaDoCfg(cfgInv)
			local inAba = false
			if isAbaVipNome(abaListaAtual) then
				inAba = (vCar == abaListaAtual)
			else
				inAba = (vCar == nil) and (cCar == abaListaAtual)
			end
			if inAba then
				count += 1

				local row = Instance.new("Frame")
				row.Name = "Row_" .. nomeCarro
				row.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
				row.BorderSizePixel = 0
				row.Size = UDim2.new(1, 0, 0, 96)
				row.Parent = scrollLista
				linhasPorNome[nomeCarro] = row

				local rc = Instance.new("UICorner")
				rc.CornerRadius = UDim.new(0, 10)
				rc.Parent = row
				local rs = Instance.new("UIStroke")
				rs.Color = Color3.fromRGB(100, 200, 255)
				rs.Transparency = 0.75
				rs.Thickness = 1
				rs.Parent = row

				local thumb = Instance.new("ImageLabel")
			thumb.Name = "Thumb"
			thumb.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
			thumb.BorderSizePixel = 0
			thumb.Size = UDim2.fromOffset(132, 78)
			thumb.Position = UDim2.new(0, 10, 0.5, -39)
			thumb.ScaleType = Enum.ScaleType.Crop
			thumb.Image = urlThumbDoCarro(nomeCarro)
			thumb.Parent = row
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(0, 8)
			tc.Parent = thumb

			local mid = Instance.new("Frame")
			mid.Name = "Mid"
			mid.BackgroundTransparency = 1
			mid.Position = UDim2.new(0, 152, 0, 10)
			mid.Size = UDim2.new(1, -320, 1, -20)
			mid.Parent = row

			local nomeLbl = Instance.new("TextLabel")
			nomeLbl.Name = "NomeC"
			nomeLbl.BackgroundTransparency = 1
			nomeLbl.Size = UDim2.new(1, 0, 0, 22)
			nomeLbl.Font = Enum.Font.GothamBold
			nomeLbl.TextSize = 17
			nomeLbl.TextXAlignment = Enum.TextXAlignment.Left
			nomeLbl.TextColor3 = Color3.fromRGB(245, 248, 255)
			nomeLbl.Text = string.gsub(nomeCarro, "_", " ")
			nomeLbl.Parent = mid

			local sub = Instance.new("TextLabel")
			sub.Name = "Sub"
			sub.BackgroundTransparency = 1
			sub.Position = UDim2.new(0, 0, 0, 28)
			sub.Size = UDim2.new(1, 0, 0, 18)
			sub.Font = Enum.Font.Gotham
			sub.TextSize = 13
			sub.TextXAlignment = Enum.TextXAlignment.Left
			sub.TextColor3 = Color3.fromRGB(150, 175, 205)
			sub.Text = nomeCarro
			sub.Parent = mid

			local colDir = Instance.new("Frame")
			colDir.Name = "ColDir"
			colDir.BackgroundTransparency = 1
			colDir.AnchorPoint = Vector2.new(1, 0.5)
			colDir.Position = UDim2.new(1, -12, 0.5, 0)
			colDir.Size = UDim2.fromOffset(168, 0)
			colDir.AutomaticSize = Enum.AutomaticSize.Y
			colDir.Parent = row

			local vLay = Instance.new("UIListLayout")
			vLay.FillDirection = Enum.FillDirection.Vertical
			vLay.HorizontalAlignment = Enum.HorizontalAlignment.Right
			vLay.Padding = UDim.new(0, 8)
			vLay.Parent = colDir

			local btn = Instance.new("TextButton")
			btn.Name = "BtnAcao"
			btn.Text = "Spawnar"
			btn.AutoButtonColor = true
			btn.Size = UDim2.new(1, 0, 0, 36)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 14
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.BorderSizePixel = 0
			btn.Parent = colDir
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 8)
			bc.Parent = btn

			btn.Activated:Connect(function()
				local agora = os.clock()
				if agora - ultimoAcao < DEBOUNCE then
					return
				end
				local s = spawnEv or ReplicatedStorage:FindFirstChild("SpawnarVeiculoGaragemEvent")
				local g = guardarEv or ReplicatedStorage:FindFirstChild("GuardarVeiculoGaragemEvent")
				if not s or not g then
					return
				end
				ultimoAcao = agora

				if btn.Text == "Spawnar" then
					s:FireServer(nomeCarro, localAtual)
				else
					g:FireServer()
				end
				btn.Text = "..."
				task.delay(0.45, atualizarBotoesLinhas)
			end)

			local fav = Instance.new("ImageButton")
			fav.Name = "BtnFavorito"
			fav.Size = UDim2.fromOffset(36, 36)
			fav.BackgroundTransparency = 1
			fav.Image = imgFavOff
			fav.Parent = colDir

			fav.Activated:Connect(function()
				local agora = os.clock()
				if agora - ultimoAcao < DEBOUNCE then
					return
				end
				if not favoritarEv then
					return
				end
				ultimoAcao = agora
				favoritarEv:FireServer(nomeCarro)

				local estava = fav.Image == imgFavOn
				for _, r in pairs(linhasPorNome) do
					local f = btnFavoritoNaLinha(r)
					if f and f:IsA("ImageButton") then
						f.Image = imgFavOff
					end
				end
				if not estava then
					fav.Image = imgFavOn
				end
				task.defer(atualizarBotoesLinhas)
			end)
			end
		end
	end

	if count == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "Empty"
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 15
		empty.TextColor3 = Color3.fromRGB(160, 170, 190)
		if totalInvValidos == 0 then
			empty.Text = "Ainda não tens veículos. Compra na Gear Shop."
		elseif isAbaVipNome(abaListaAtual) then
			empty.Text = "Nenhum veículo nesta garagem VIP."
		else
			empty.Text = "Nenhum veículo nesta categoria."
		end
		empty.Parent = scrollLista
	end

	atualizarBotoesLinhas()
	carregandoLista = false
	if listaPendente then
		listaPendente = false
		task.defer(carregarListaCarros)
	end
end

local function abrirPainel()
	if menuAberto or not frameShell then
		return
	end
	menuAberto = true
	frameShell.Visible = true
	for _, p in ipairs(promptsGaragem) do
		if p and p.Parent then
			p.Enabled = false
		end
	end
	pararTween()
	local anim = TweenService:Create(uiScaleShell, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	tweenAtual = anim
	anim:Play()
	atualizarContextoTexto()
	tierVipJogador = tierVipComGamePasses()
	if isAbaVipNome(abaListaAtual) and not podeVerAbaVip(abaListaAtual) then
		abaListaAtual = "AA+"
	end
	atualizarAparenciaAbas()
	carregarListaCarros()
end

local function fecharPainel()
	if not menuAberto or not frameShell then
		return
	end
	pararTween()
	desligarWatchInv()
	local anim = TweenService:Create(uiScaleShell, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0,
	})
	tweenAtual = anim
	anim.Completed:Once(function()
		if tweenAtual ~= anim then
			return
		end
		tweenAtual = nil
		frameShell.Visible = false
		menuAberto = false
		localAtual = "Estacionamento"
		abaListaAtual = "AA+"
		atualizarAparenciaAbas()
		for _, p in ipairs(promptsGaragem) do
			if p and p.Parent then
				p.Enabled = true
			end
		end
	end)
	anim:Play()
end

local function montarInterfaceCompleta()
	local existente = playerGui:FindFirstChild(NOME_SCREEN_GUI)
	if existente then
		existente:Destroy()
	end
	table.clear(botoesAba)

	local sg = Instance.new("ScreenGui")
	sg.Name = NOME_SCREEN_GUI
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 50
	sg.Enabled = true
	sg.Parent = playerGui

	frameShell = Instance.new("Frame")
	frameShell.Name = "PainelGaragem"
	frameShell.BackgroundTransparency = 1
	frameShell.Size = UDim2.fromScale(1, 1)
	frameShell.Visible = false
	frameShell.Parent = sg

	uiScaleShell = Instance.new("UIScale")
	uiScaleShell.Parent = frameShell
	uiScaleShell.Scale = 0

	local root = Instance.new("Frame")
	root.Name = "GaragemRoot"
	root.BackgroundColor3 = Color3.fromRGB(14, 16, 28)
	root.BorderSizePixel = 0
	root.Size = UDim2.new(0.9, 0, 0.85, 0)
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Parent = frameShell

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = root

	local grad = Instance.new("UIGradient")
	grad.Rotation = 120
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 14, 32)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(24, 14, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 22, 38)),
	})
	grad.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 220, 255)
	stroke.Thickness = 1.8
	stroke.Transparency = 0.28
	stroke.Parent = root

	local topo = Instance.new("Frame")
	topo.Name = "Topo"
	topo.BackgroundTransparency = 0.2
	topo.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	topo.Size = UDim2.new(1, 0, 0, 96)
	topo.Parent = root
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 14)
	tc.Parent = topo

	local titulo = Instance.new("TextLabel")
	titulo.BackgroundTransparency = 1
	titulo.Position = UDim2.new(0, 14, 0, 10)
	titulo.Size = UDim2.new(1, -120, 0, 26)
	titulo.Font = Enum.Font.GothamBold
	titulo.TextSize = 22
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.TextColor3 = Color3.fromRGB(245, 250, 255)
	titulo.Text = "Garagem"
	titulo.Parent = topo

	labelContexto = Instance.new("TextLabel")
	labelContexto.Name = "ContextoSpawn"
	labelContexto.BackgroundTransparency = 1
	labelContexto.Position = UDim2.new(0, 14, 0, 40)
	labelContexto.Size = UDim2.new(1, -120, 0, 18)
	labelContexto.Font = Enum.Font.Gotham
	labelContexto.TextSize = 13
	labelContexto.TextXAlignment = Enum.TextXAlignment.Left
	labelContexto.TextColor3 = Color3.fromRGB(160, 200, 230)
	labelContexto.Text = "Spawn: estacionamento público"
	labelContexto.Parent = topo

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 14, 0, 62)
	sub.Size = UDim2.new(1, -120, 0, 16)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 12
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Color3.fromRGB(130, 150, 175)
	sub.Text = "Sincronizado com o inventário e a Gear Shop."
	sub.Parent = topo

	local btnX = Instance.new("TextButton")
	btnX.Name = "Fechar"
	btnX.Text = "X"
	btnX.Font = Enum.Font.GothamBold
	btnX.TextSize = 18
	btnX.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnX.BackgroundColor3 = Color3.fromRGB(200, 60, 80)
	btnX.Size = UDim2.fromOffset(36, 36)
	btnX.Position = UDim2.new(1, -44, 0, 14)
	btnX.Parent = root
	local xc = Instance.new("UICorner")
	xc.CornerRadius = UDim.new(1, 0)
	xc.Parent = btnX
	btnX.Activated:Connect(fecharPainel)

	local abaHolder = Instance.new("Frame")
	abaHolder.Name = "AbaCarros"
	abaHolder.BackgroundTransparency = 1
	abaHolder.Position = UDim2.new(0, 12, 0, 100)
	abaHolder.Size = UDim2.new(1, -24, 0, 44)
	abaHolder.Parent = root

	local scrollTabs = Instance.new("ScrollingFrame")
	scrollTabs.Name = "BarraAbas"
	scrollTabs.BackgroundColor3 = Color3.fromRGB(14, 16, 26)
	scrollTabs.BackgroundTransparency = 0.25
	scrollTabs.BorderSizePixel = 0
	scrollTabs.Size = UDim2.new(1, 0, 1, 0)
	scrollTabs.ScrollBarThickness = 4
	scrollTabs.ScrollBarImageColor3 = Color3.fromRGB(120, 180, 255)
	scrollTabs.AutomaticCanvasSize = Enum.AutomaticSize.X
	scrollTabs.CanvasSize = UDim2.new()
	scrollTabs.Parent = abaHolder
	local stcTabs = Instance.new("UICorner")
	stcTabs.CornerRadius = UDim.new(0, 8)
	stcTabs.Parent = scrollTabs
	local padTabsBar = Instance.new("UIPadding")
	padTabsBar.PaddingLeft = UDim.new(0, 8)
	padTabsBar.PaddingRight = UDim.new(0, 8)
	padTabsBar.PaddingTop = UDim.new(0, 6)
	padTabsBar.PaddingBottom = UDim.new(0, 6)
	padTabsBar.Parent = scrollTabs
	local layTabsBar = Instance.new("UIListLayout")
	layTabsBar.FillDirection = Enum.FillDirection.Horizontal
	layTabsBar.Padding = UDim.new(0, 8)
	layTabsBar.VerticalAlignment = Enum.VerticalAlignment.Center
	layTabsBar.SortOrder = Enum.SortOrder.LayoutOrder
	layTabsBar.Parent = scrollTabs

	local ordAba = 0
	local function criarBotaoAba(idStr)
		ordAba += 1
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. idStr
		b:SetAttribute("AbaId", idStr)
		b.AutoButtonColor = true
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.Text = idStr
		b.Size = UDim2.fromOffset(0, 30)
		b.AutomaticSize = Enum.AutomaticSize.X
		b.BorderSizePixel = 0
		b.LayoutOrder = ordAba
		local pb = Instance.new("UIPadding")
		pb.PaddingLeft = UDim.new(0, 12)
		pb.PaddingRight = UDim.new(0, 12)
		pb.Parent = b
		local uic = Instance.new("UICorner")
		uic.CornerRadius = UDim.new(0, 8)
		uic.Parent = b
		b.Parent = scrollTabs
		botoesAba[idStr] = b
		b.Activated:Connect(function()
			selecionarAbaGaragem(idStr)
		end)
	end

	for _, id in ipairs(CATEGORIAS_ABA) do
		criarBotaoAba(id)
	end

	ordAba += 1
	local labVip = Instance.new("TextLabel")
	labVip.BackgroundTransparency = 1
	labVip.Font = Enum.Font.GothamBold
	labVip.TextSize = 12
	labVip.TextColor3 = Color3.fromRGB(200, 175, 90)
	labVip.Text = "│ VIP"
	labVip.AutomaticSize = Enum.AutomaticSize.X
	labVip.Size = UDim2.fromOffset(0, 30)
	labVip.LayoutOrder = ordAba
	labVip.Parent = scrollTabs

	for _, id in ipairs(ABAS_VIP_GARAGEM) do
		criarBotaoAba(id)
	end

	tierVipJogador = tierVipComGamePasses()
	atualizarAparenciaAbas()

	scrollLista = Instance.new("ScrollingFrame")
	scrollLista.Name = "ListaCarros"
	scrollLista.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	scrollLista.BackgroundTransparency = 0.35
	scrollLista.Position = UDim2.new(0, 12, 0, 152)
	scrollLista.Size = UDim2.new(1, -24, 1, -164)
	scrollLista.ScrollBarThickness = 6
	scrollLista.ScrollBarImageColor3 = Color3.fromRGB(100, 200, 255)
	scrollLista.BorderSizePixel = 0
	scrollLista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollLista.CanvasSize = UDim2.new()
	scrollLista.Parent = root

	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 10)
	sc.Parent = scrollLista

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scrollLista

	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 10)
	lay.Parent = scrollLista

end

-- Shell imediato
montarInterfaceCompleta()

-- Dependências
task.spawn(function()
	spawnEv = ReplicatedStorage:WaitForChild("SpawnarVeiculoGaragemEvent", 120)
	guardarEv = ReplicatedStorage:WaitForChild("GuardarVeiculoGaragemEvent", 120)
	abrirEv = ReplicatedStorage:WaitForChild("AbrirMenuGaragemEvent", 120)
	autoEv = ReplicatedStorage:WaitForChild("AutoSpawnVIPClientEvent", 120)

	if not spawnEv or not guardarEv or not abrirEv or not autoEv then
		warn("[GaragemUI] RemoteEvents essenciais em falta.")
		return
	end

	local fav = ReplicatedStorage:FindFirstChild("FavoritarCarroEvent")
	if fav and fav:IsA("RemoteEvent") then
		favoritarEv = fav
	end

	local mod = ReplicatedStorage:FindFirstChild("ConcessionariaCatalogo")
	if mod and mod:IsA("ModuleScript") then
		local ok, cat = pcall(require, mod)
		if ok and cat then
			catalogoMod = cat
			if type(cat.MapaPorNome) == "function" then
				mapaCatalogo = cat.MapaPorNome()
			end
			if type(cat.ResolverImagem) == "function" then
				resolverImagem = cat.ResolverImagem
			end
			if menuAberto then
				task.defer(carregarListaCarros)
			end
		end
	end

	autoEv.OnClientEvent:Connect(function(carroFav)
		if type(carroFav) ~= "string" or carroFav == "" then
			return
		end
		spawnEv:FireServer(carroFav, "Casa", true)
	end)

	abrirEv.OnClientEvent:Connect(function(localDeSpawn)
		if type(localDeSpawn) == "string" and localDeSpawn ~= "" then
			localAtual = localDeSpawn
		elseif type(localDeSpawn) == "number" and localDeSpawn == localDeSpawn then
			localAtual = tostring(math.floor(localDeSpawn))
		else
			localAtual = "Estacionamento"
		end
		atualizarContextoTexto()
		abrirPainel()
	end)
end)

Workspace.ChildAdded:Connect(function(ch)
	if ch.Name == player.Name .. "sCar" then
		task.delay(0.2, atualizarBotoesLinhas)
	end
end)

Workspace.ChildRemoved:Connect(function(ch)
	if ch.Name == player.Name .. "sCar" then
		atualizarBotoesLinhas()
	end
end)

local function ligarCarDataFavorito()
	local cd = player:FindFirstChild("CarData")
	if cd then
		local fv = cd:FindFirstChild("CarroFavorito")
		if fv and fv:IsA("StringValue") then
			fv.Changed:Connect(function()
				if menuAberto then
					atualizarBotoesLinhas()
				end
			end)
		end
	else
		player.ChildAdded:Connect(function(ch)
			if ch.Name == "CarData" then
				local fv = ch:WaitForChild("CarroFavorito", 30)
				if fv and fv:IsA("StringValue") then
					fv.Changed:Connect(function()
						if menuAberto then
							atualizarBotoesLinhas()
						end
					end)
				end
			end
		end)
	end
end
ligarCarDataFavorito()

local function ligarVipSalvoGaragem()
	local function aoMudarVip()
		tierVipJogador = tierVipComGamePasses()
		if isAbaVipNome(abaListaAtual) and not podeVerAbaVip(abaListaAtual) then
			abaListaAtual = "AA+"
		end
		atualizarAparenciaAbas()
		if menuAberto then
			carregarListaCarros()
		end
	end
	local sv = player:FindFirstChild("VipSalvo")
	if sv and sv:IsA("StringValue") then
		sv.Changed:Connect(aoMudarVip)
	else
		player.ChildAdded:Connect(function(ch)
			if ch.Name == "VipSalvo" and ch:IsA("StringValue") then
				ch.Changed:Connect(aoMudarVip)
			end
		end)
	end
end
ligarVipSalvoGaragem()

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and menuAberto then
		fecharPainel()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F5 then
		if menuAberto then
			fecharPainel()
		else
			localAtual = "Estacionamento"
			atualizarContextoTexto()
			abrirPainel()
		end
	end
end)

-- Garagem pública: bind explícito em Workspace.EstacionamentoG.AcessoGaragem.ProximityPrompt
local function registarPromptGaragem(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	if promptsJaRegistrados[prompt] then
		return
	end

	promptsJaRegistrados[prompt] = true
	table.insert(promptsGaragem, prompt)

	prompt.Triggered:Connect(function(quem)
		if typeof(quem) ~= "Instance" or not quem:IsA("Player") or quem ~= player then
			return
		end
		local ok, err = pcall(function()
			localAtual = "Estacionamento"
			atualizarContextoTexto()
			abrirPainel()
		end)
		if not ok then
			warn("[GaragemUI] Erro ao abrir painel:", err)
		end
	end)
end

local function containerValidoEstacionamento(inst)
	-- No mapa pode ser Model, Folder ou até Part com filhos — não forçar só Model
	return inst and (inst:IsA("Model") or inst:IsA("Folder") or inst:IsA("BasePart"))
end

local function tentarLigarGaragemPublica()
	local est = Workspace:FindFirstChild("EstacionamentoG")
	if not est then
		return false
	end
	if not containerValidoEstacionamento(est) then
		return false
	end
	local acesso = est:FindFirstChild("AcessoGaragem")
	local prompt = nil
	if acesso then
		prompt = acesso:FindFirstChildWhichIsA("ProximityPrompt", true)
	end
	-- Sem AcessoGaragem ou prompt noutro sítio: qualquer ProximityPrompt dentro do estacionamento
	if not prompt then
		prompt = est:FindFirstChildWhichIsA("ProximityPrompt", true)
	end
	if not prompt then
		return false
	end

	registarPromptGaragem(prompt)
	return true
end

task.defer(function()
	-- Sempre escutar novos descendentes (streaming / replicação tardia)
	Workspace.DescendantAdded:Connect(function(d)
		if
			d.Name == "EstacionamentoG"
			or d.Name == "AcessoGaragem"
			or d:IsA("ProximityPrompt")
		then
			task.defer(tentarLigarGaragemPublica)
		end
	end)

	-- 1) tentativa imediata
	if tentarLigarGaragemPublica() then
		return
	end

	-- 2) EstacionamentoG pode ainda não existir no cliente (streaming)
	task.spawn(function()
		local est = Workspace:FindFirstChild("EstacionamentoG")
		if not est then
			local ok, resultado = pcall(function()
				return Workspace:WaitForChild("EstacionamentoG", 90)
			end)
			if ok and resultado and containerValidoEstacionamento(resultado) then
				est = resultado
			end
		end
		if est then
			if tentarLigarGaragemPublica() then
				return
			end
			-- AcessoGaragem pode aparecer depois do model raiz
			est.ChildAdded:Connect(function()
				task.defer(tentarLigarGaragemPublica)
			end)
		end

		for _ = 1, 20 do
			task.wait(0.5)
			if tentarLigarGaragemPublica() then
				return
			end
		end
		warn(
			"[GaragemUI] Não encontrei ProximityPrompt em Workspace.EstacionamentoG (nem em AcessoGaragem). "
				.. "Confirma EstacionamentoG (Model/Folder), AcessoGaragem e um ProximityPrompt dentro."
		)
	end)
end)
