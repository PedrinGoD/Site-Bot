-- CH Corporations - Menu Rádio JBLEski (LocalScript)
-- Revisão: RadioJBLEskiEvent com timeout + IsA; PlayerGui seguro; remove GUI duplicada;
--          FireServer com pcall quando faz sentido; fechar sem Completed:Wait; task.delay na playlist;
--          só StringValue na playlist; Activated nos cliques; tween fechar com Completed:Once.

print("CH Corporations - Menu Rádio JBLEski (revisão — nome da música na tela)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local REMOTE_TIMEOUT = 60

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", REMOTE_TIMEOUT)
if not playerGui then
	warn("[JBLEskiMenu] PlayerGui em falta — script desativado.")
	return
end

local radioEvent = ReplicatedStorage:WaitForChild("RadioJBLEskiEvent", REMOTE_TIMEOUT)
if not radioEvent or not radioEvent:IsA("RemoteEvent") then
	warn("[JBLEskiMenu] RadioJBLEskiEvent em falta — script desativado.")
	return
end

local jbEstadoJBLEski
do
	local mod = ReplicatedStorage:WaitForChild("JBLEskiClienteEstado", REMOTE_TIMEOUT)
	if mod and mod:IsA("ModuleScript") then
		local ok, req = pcall(require, mod)
		if ok then
			jbEstadoJBLEski = req
		end
	end
	if not jbEstadoJBLEski then
		warn("[JBLEskiMenu] JBLEskiClienteEstado em falta no ReplicatedStorage — painel e celular podem abrir juntos.")
		jbEstadoJBLEski = {
			estaPareadoCom = function()
				return false
			end,
		}
	end
end

local guiAntiga = playerGui:FindFirstChild("RadioJBLEskiGui")
if guiAntiga then
	guiAntiga:Destroy()
end

local radioAtual = nil
local playlistLocal = {}
local indexMusica = 0
local isDJ = false
local soundConnection = nil
local tweenUiAtual = nil

local COR_FUNDO = Color3.fromRGB(18, 18, 18)
local COR_FUNDO_SECUNDARIO = Color3.fromRGB(40, 40, 40)
local COR_VERDE = Color3.fromRGB(29, 185, 84)
local COR_CINZA = Color3.fromRGB(179, 179, 179)
local COR_TEXTO = Color3.fromRGB(255, 255, 255)

local function fireRadio(...)
	-- Luau: "..." não existe dentro do closure do pcall — empacotar antes.
	local args = { ... }
	local ok, err = pcall(function()
		radioEvent:FireServer(table.unpack(args))
	end)
	if not ok then
		warn("[JBLEskiMenu] FireServer falhou:", err)
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "RadioJBLEskiGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local framePrincipal = Instance.new("Frame")
framePrincipal.Size = UDim2.new(0, 550, 0, 300)
framePrincipal.Position = UDim2.new(0.5, 0, 0.5, 0)
framePrincipal.AnchorPoint = Vector2.new(0.5, 0.5)
framePrincipal.BackgroundColor3 = COR_FUNDO
framePrincipal.Visible = false
framePrincipal.Parent = gui

Instance.new("UICorner", framePrincipal).CornerRadius = UDim.new(0, 15)

local uiScale = Instance.new("UIScale")
uiScale.Scale = 0
uiScale.Parent = framePrincipal

local btnFechar = Instance.new("TextButton")
btnFechar.Size = UDim2.new(0, 30, 0, 30)
btnFechar.Position = UDim2.new(1, -35, 0, 5)
btnFechar.BackgroundTransparency = 1
btnFechar.Text = "X"
btnFechar.TextColor3 = COR_CINZA
btnFechar.Font = Enum.Font.GothamBold
btnFechar.TextSize = 18
btnFechar.AutoButtonColor = true
btnFechar.Parent = framePrincipal

local painelEsquerdo = Instance.new("Frame")
painelEsquerdo.Size = UDim2.new(0.5, 0, 1, 0)
painelEsquerdo.BackgroundTransparency = 1
painelEsquerdo.Parent = framePrincipal

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, 0, 0, 30)
titulo.Position = UDim2.new(0, 0, 0, 5)
titulo.BackgroundTransparency = 1
titulo.Text = "RADIO JBLEski"
titulo.Font = Enum.Font.GothamBlack
titulo.TextColor3 = COR_VERDE
titulo.TextSize = 20
titulo.Parent = painelEsquerdo

local txtNomeMusica = Instance.new("TextLabel")
txtNomeMusica.Size = UDim2.new(1, 0, 0, 20)
txtNomeMusica.Position = UDim2.new(0, 0, 0, 35)
txtNomeMusica.BackgroundTransparency = 1
txtNomeMusica.Text = "🎵 Nenhuma música tocando..."
txtNomeMusica.TextColor3 = COR_CINZA
txtNomeMusica.Font = Enum.Font.Gotham
txtNomeMusica.TextSize = 12
txtNomeMusica.TextTruncate = Enum.TextTruncate.AtEnd
txtNomeMusica.Parent = painelEsquerdo

local inputContainer = Instance.new("Frame")
inputContainer.Size = UDim2.new(0.9, 0, 0, 35)
inputContainer.Position = UDim2.new(0.05, 0, 0.22, 0)
inputContainer.BackgroundTransparency = 1
inputContainer.Parent = painelEsquerdo

local inputID = Instance.new("TextBox")
inputID.Size = UDim2.new(0.8, -5, 1, 0)
inputID.BackgroundColor3 = COR_FUNDO_SECUNDARIO
inputID.TextColor3 = COR_TEXTO
inputID.Font = Enum.Font.Gotham
inputID.TextSize = 14
inputID.PlaceholderText = "Cole o ID da música..."
inputID.Text = ""
inputID.ClearTextOnFocus = false
inputID.Parent = inputContainer
Instance.new("UICorner", inputID).CornerRadius = UDim.new(0, 8)

local btnAddPlaylist = Instance.new("TextButton")
btnAddPlaylist.Size = UDim2.new(0.2, 0, 1, 0)
btnAddPlaylist.Position = UDim2.new(0.8, 5, 0, 0)
btnAddPlaylist.BackgroundColor3 = COR_FUNDO_SECUNDARIO
btnAddPlaylist.Text = "💚"
btnAddPlaylist.Font = Enum.Font.Gotham
btnAddPlaylist.TextSize = 18
btnAddPlaylist.AutoButtonColor = true
btnAddPlaylist.Parent = inputContainer
Instance.new("UICorner", btnAddPlaylist).CornerRadius = UDim.new(0, 8)

local frameBotoes = Instance.new("Frame")
frameBotoes.Size = UDim2.new(1, 0, 0, 50)
frameBotoes.Position = UDim2.new(0, 0, 0.38, 0)
frameBotoes.BackgroundTransparency = 1
frameBotoes.Parent = painelEsquerdo

local layoutBotoes = Instance.new("UIListLayout")
layoutBotoes.FillDirection = Enum.FillDirection.Horizontal
layoutBotoes.HorizontalAlignment = Enum.HorizontalAlignment.Center
layoutBotoes.VerticalAlignment = Enum.VerticalAlignment.Center
layoutBotoes.Padding = UDim.new(0, 10)
layoutBotoes.Parent = frameBotoes

local function criarBotao(texto, cor)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 35, 0, 35)
	btn.BackgroundColor3 = cor
	btn.Text = texto
	btn.TextColor3 = COR_TEXTO
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 14
	btn.AutoButtonColor = true
	btn.Parent = frameBotoes
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
	return btn
end

local btnVoltar = criarBotao("⏮", COR_FUNDO_SECUNDARIO)
local btnPlay = criarBotao("▶", COR_VERDE)
local btnPause = criarBotao("⏸", COR_FUNDO_SECUNDARIO)
local btnStop = criarBotao("⏹", Color3.fromRGB(180, 40, 40))
local btnPassar = criarBotao("⏭", COR_FUNDO_SECUNDARIO)

local frameTempo = Instance.new("Frame")
frameTempo.Size = UDim2.new(0.8, 0, 0, 25)
frameTempo.Position = UDim2.new(0.1, 0, 0.60, 0)
frameTempo.BackgroundTransparency = 1
frameTempo.Parent = painelEsquerdo

local txtTempoAtual = Instance.new("TextLabel")
txtTempoAtual.Size = UDim2.new(0.2, 0, 1, -8)
txtTempoAtual.BackgroundTransparency = 1
txtTempoAtual.Text = "0:00"
txtTempoAtual.TextColor3 = COR_CINZA
txtTempoAtual.Font = Enum.Font.Gotham
txtTempoAtual.TextSize = 10
txtTempoAtual.TextXAlignment = Enum.TextXAlignment.Left
txtTempoAtual.Parent = frameTempo

local txtTempoTotal = Instance.new("TextLabel")
txtTempoTotal.Size = UDim2.new(0.2, 0, 1, -8)
txtTempoTotal.Position = UDim2.new(0.8, 0, 0, 0)
txtTempoTotal.BackgroundTransparency = 1
txtTempoTotal.Text = "0:00"
txtTempoTotal.TextColor3 = COR_CINZA
txtTempoTotal.Font = Enum.Font.Gotham
txtTempoTotal.TextSize = 10
txtTempoTotal.TextXAlignment = Enum.TextXAlignment.Right
txtTempoTotal.Parent = frameTempo

local bgTempoSlider = Instance.new("Frame")
bgTempoSlider.Size = UDim2.new(1, 0, 0, 4)
bgTempoSlider.Position = UDim2.new(0, 0, 1, -4)
bgTempoSlider.BackgroundColor3 = COR_FUNDO_SECUNDARIO
bgTempoSlider.Parent = frameTempo
Instance.new("UICorner", bgTempoSlider).CornerRadius = UDim.new(1, 0)

local fillTempoSlider = Instance.new("Frame")
fillTempoSlider.Size = UDim2.new(0, 0, 1, 0)
fillTempoSlider.ZIndex = 1
fillTempoSlider.BackgroundColor3 = COR_VERDE
fillTempoSlider.Parent = bgTempoSlider
Instance.new("UICorner", fillTempoSlider).CornerRadius = UDim.new(1, 0)

local knobTempoSlider = Instance.new("TextButton")
knobTempoSlider.Size = UDim2.new(0, 10, 0, 10)
knobTempoSlider.Position = UDim2.new(0, -5, 0.5, -5)
knobTempoSlider.ZIndex = 2
knobTempoSlider.BackgroundColor3 = COR_TEXTO
knobTempoSlider.Text = ""
knobTempoSlider.AutoButtonColor = false
knobTempoSlider.Parent = bgTempoSlider
Instance.new("UICorner", knobTempoSlider).CornerRadius = UDim.new(1, 0)

local txtVol = Instance.new("TextLabel")
txtVol.Size = UDim2.new(1, 0, 0, 20)
txtVol.Position = UDim2.new(0, 0, 0.75, 0)
txtVol.BackgroundTransparency = 1
txtVol.Text = "Volume"
txtVol.TextColor3 = COR_CINZA
txtVol.Font = Enum.Font.GothamBold
txtVol.Parent = painelEsquerdo

local bgSlider = Instance.new("Frame")
bgSlider.Size = UDim2.new(0.8, 0, 0, 6)
bgSlider.Position = UDim2.new(0.1, 0, 0.85, 0)
bgSlider.BackgroundColor3 = COR_FUNDO_SECUNDARIO
bgSlider.Parent = painelEsquerdo
Instance.new("UICorner", bgSlider).CornerRadius = UDim.new(1, 0)

local fillSlider = Instance.new("Frame")
fillSlider.Size = UDim2.new(0.5, 0, 1, 0)
fillSlider.ZIndex = 1
fillSlider.BackgroundColor3 = COR_VERDE
fillSlider.Parent = bgSlider
Instance.new("UICorner", fillSlider).CornerRadius = UDim.new(1, 0)

local knobSlider = Instance.new("TextButton")
knobSlider.Size = UDim2.new(0, 12, 0, 12)
knobSlider.Position = UDim2.new(0.5, -6, 0.5, -6)
knobSlider.ZIndex = 2
knobSlider.BackgroundColor3 = COR_TEXTO
knobSlider.Text = ""
knobSlider.AutoButtonColor = false
knobSlider.Parent = bgSlider
Instance.new("UICorner", knobSlider).CornerRadius = UDim.new(1, 0)

local painelDireito = Instance.new("Frame")
painelDireito.Size = UDim2.new(0.5, -20, 1, -40)
painelDireito.Position = UDim2.new(0.5, 0, 0, 20)
painelDireito.BackgroundColor3 = COR_FUNDO_SECUNDARIO
painelDireito.Parent = framePrincipal
Instance.new("UICorner", painelDireito).CornerRadius = UDim.new(0, 10)

local tituloPlaylist = Instance.new("TextLabel")
tituloPlaylist.Size = UDim2.new(1, 0, 0, 30)
tituloPlaylist.BackgroundTransparency = 1
tituloPlaylist.Text = "Sua Playlist"
tituloPlaylist.TextColor3 = COR_TEXTO
tituloPlaylist.Font = Enum.Font.GothamBold
tituloPlaylist.TextSize = 16
tituloPlaylist.Parent = painelDireito

local listaMusicas = Instance.new("ScrollingFrame")
listaMusicas.Size = UDim2.new(1, -10, 1, -40)
listaMusicas.Position = UDim2.new(0, 5, 0, 35)
listaMusicas.BackgroundTransparency = 1
listaMusicas.ScrollBarThickness = 4
listaMusicas.CanvasSize = UDim2.new(0, 0, 0, 0)
listaMusicas.Parent = painelDireito

local listaLayout = Instance.new("UIListLayout")
listaLayout.SortOrder = Enum.SortOrder.LayoutOrder
listaLayout.Padding = UDim.new(0, 5)
listaLayout.Parent = listaMusicas

local function formatarTempo(segundos)
	if not segundos or segundos < 0 then
		segundos = 0
	end
	local min = math.floor(segundos / 60)
	local seg = math.floor(segundos % 60)
	return string.format("%d:%02d", min, seg)
end

local function somAtual()
	if not radioAtual or not radioAtual.Parent then
		return nil
	end
	local som = radioAtual:FindFirstChild("Som")
	if not som then
		return nil
	end
	return som:FindFirstChild("Sound")
end

local function tocarMusicaPorID(id)
	if not id or id == "" or not radioAtual then
		return
	end
	fireRadio("Play", radioAtual, id)
	isDJ = true

	local nomeDaMusica = "Faixa " .. id
	local playlistData = player:FindFirstChild("PlaylistData")
	if playlistData then
		local somSalvo = playlistData:FindFirstChild(tostring(id))
		if somSalvo and somSalvo:IsA("StringValue") then
			nomeDaMusica = somSalvo.Value
		end
	end
	txtNomeMusica.Text = "🎵 " .. nomeDaMusica
end

local function monitorarFimDaMusica()
	if soundConnection then
		soundConnection:Disconnect()
		soundConnection = nil
	end
	if not radioAtual then
		return
	end
	local sound = somAtual()
	if sound then
		soundConnection = sound.Ended:Connect(function()
			if isDJ and #playlistLocal > 0 then
				indexMusica = (indexMusica < #playlistLocal) and (indexMusica + 1) or 1
				inputID.Text = playlistLocal[indexMusica]
				tocarMusicaPorID(playlistLocal[indexMusica])
			end
		end)
	end
end

local function contarLinhasPlaylist()
	local n = 0
	for _, ch in ipairs(listaMusicas:GetChildren()) do
		if ch:IsA("Frame") then
			n = n + 1
		end
	end
	return n
end

local function atualizarPlaylistUI()
	for _, item in ipairs(listaMusicas:GetChildren()) do
		if item:IsA("Frame") then
			item:Destroy()
		end
	end
	playlistLocal = {}

	local playlistData = player:WaitForChild("PlaylistData", REMOTE_TIMEOUT)
	if not playlistData then
		return
	end

	local count = 0
	for _, musicaRecord in ipairs(playlistData:GetChildren()) do
		if musicaRecord:IsA("StringValue") then
			local id = musicaRecord.Name
			local nomeMusica = musicaRecord.Value

			table.insert(playlistLocal, id)
			count = count + 1

			local itemFrame = Instance.new("Frame")
			itemFrame.Size = UDim2.new(1, -5, 0, 35)
			itemFrame.BackgroundColor3 = COR_FUNDO
			itemFrame.Parent = listaMusicas
			Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 6)

			local btnTocar = Instance.new("TextButton")
			btnTocar.Size = UDim2.new(0.85, 0, 1, 0)
			btnTocar.BackgroundTransparency = 1
			btnTocar.Text = "  " .. nomeMusica
			btnTocar.TextColor3 = COR_CINZA
			btnTocar.TextXAlignment = Enum.TextXAlignment.Left
			btnTocar.Font = Enum.Font.Gotham
			btnTocar.TextSize = 12
			btnTocar.TextTruncate = Enum.TextTruncate.AtEnd
			btnTocar.AutoButtonColor = true
			btnTocar.Parent = itemFrame

			local btnRemover = Instance.new("TextButton")
			btnRemover.Size = UDim2.new(0.15, 0, 1, 0)
			btnRemover.Position = UDim2.new(0.85, 0, 0, 0)
			btnRemover.BackgroundTransparency = 1
			btnRemover.Text = "🗑️"
			btnRemover.TextSize = 14
			btnRemover.AutoButtonColor = true
			btnRemover.Parent = itemFrame

			btnTocar.Activated:Connect(function()
				inputID.Text = id
				tocarMusicaPorID(id)
			end)

			btnRemover.Activated:Connect(function()
				fireRadio("RemovePlaylist", radioAtual, id)
				itemFrame:Destroy()
				listaMusicas.CanvasSize = UDim2.new(0, 0, 0, contarLinhasPlaylist() * 40)
			end)
		end
	end

	listaMusicas.CanvasSize = UDim2.new(0, 0, 0, count * 40)
end

local VOL_MIN = 0.5
local VOL_MAX = 3.0

local function fecharMenu()
	if tweenUiAtual then
		tweenUiAtual:Cancel()
		tweenUiAtual = nil
	end
	tweenUiAtual = TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	tweenUiAtual:Play()
	tweenUiAtual.Completed:Once(function()
		framePrincipal.Visible = false
		tweenUiAtual = nil
	end)
end

btnFechar.Activated:Connect(fecharMenu)

btnAddPlaylist.Activated:Connect(function()
	local id = inputID.Text
	if id == "" then
		return
	end
	btnAddPlaylist.Text = "⏳"
	btnAddPlaylist.Interactable = false
	task.spawn(function()
		local sucesso, info = pcall(function()
			return MarketplaceService:GetProductInfo(tonumber(id), Enum.InfoType.Asset)
		end)
		local nomeDaMusica = "Música " .. id
		if sucesso and info then
			nomeDaMusica = info.Name
		end
		fireRadio("AddPlaylist", radioAtual, id, nomeDaMusica)
		task.delay(0.5, function()
			atualizarPlaylistUI()
			btnAddPlaylist.Text = "💚"
			btnAddPlaylist.Interactable = true
		end)
	end)
end)

btnPlay.Activated:Connect(function()
	if inputID.Text ~= "" then
		tocarMusicaPorID(inputID.Text)
	else
		local s = somAtual()
		if radioAtual and s and s.TimePosition > 0 then
			fireRadio("Resume", radioAtual)
			isDJ = true
		end
	end
end)

btnPause.Activated:Connect(function()
	if not radioAtual then
		return
	end
	local sound = somAtual()
	if sound then
		if sound.IsPlaying then
			fireRadio("Pause", radioAtual)
		else
			fireRadio("Resume", radioAtual)
		end
	end
end)

btnStop.Activated:Connect(function()
	fireRadio("Stop", radioAtual)
	isDJ = false
	txtNomeMusica.Text = "🎵 Nenhuma música tocando..."
end)

btnPassar.Activated:Connect(function()
	indexMusica = (indexMusica < #playlistLocal) and (indexMusica + 1) or 1
	if playlistLocal[indexMusica] then
		inputID.Text = playlistLocal[indexMusica]
		tocarMusicaPorID(playlistLocal[indexMusica])
	end
end)

btnVoltar.Activated:Connect(function()
	indexMusica = (indexMusica > 1) and (indexMusica - 1) or #playlistLocal
	if playlistLocal[indexMusica] then
		inputID.Text = playlistLocal[indexMusica]
		tocarMusicaPorID(playlistLocal[indexMusica])
	end
end)

local arrastandoVol = false
local arrastandoTempo = false

local function ponteiroXNoInput(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return input.Position.X
	end
	if
		input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.MouseButton1
	then
		return UserInputService:GetMouseLocation().X
	end
	return input.Position.X
end

local function percentualNaTrilha(trilha, posX)
	local w = trilha.AbsoluteSize.X
	if w <= 0 then
		return 0
	end
	return math.clamp((posX - trilha.AbsolutePosition.X) / w, 0, 1)
end

local function aplicarSliderVolumePainel(pct)
	fillSlider.Size = UDim2.new(pct, 0, 1, 0)
	knobSlider.Position = UDim2.new(pct, -6, 0.5, -6)
	fireRadio("Volume", radioAtual, VOL_MIN + (pct * (VOL_MAX - VOL_MIN)))
end

local function aplicarSliderTempoVisualPainel(pct)
	fillTempoSlider.Size = UDim2.new(pct, 0, 1, 0)
	knobTempoSlider.Position = UDim2.new(pct, -5, 0.5, -5)
end

knobSlider.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		arrastandoVol = true
	end
end)

knobTempoSlider.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		arrastandoTempo = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local eraTempo = arrastandoTempo
		arrastandoVol = false
		if eraTempo then
			arrastandoTempo = false
			local posX = ponteiroXNoInput(input)
			local porcentagem = percentualNaTrilha(bgTempoSlider, posX)
			local sound = somAtual()
			if sound and sound.TimeLength > 0 and radioAtual then
				fireRadio("Seek", radioAtual, porcentagem * sound.TimeLength)
			end
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local posX = ponteiroXNoInput(input)
	if arrastandoVol then
		local porcentagem = percentualNaTrilha(bgSlider, posX)
		aplicarSliderVolumePainel(porcentagem)
	elseif arrastandoTempo then
		local porcentagem = percentualNaTrilha(bgTempoSlider, posX)
		aplicarSliderTempoVisualPainel(porcentagem)
	end
end)

RunService.Heartbeat:Connect(function()
	if not framePrincipal.Visible or not radioAtual then
		return
	end
	local sound = somAtual()
	if sound and sound.IsLoaded and sound.TimeLength > 0 then
		if not arrastandoTempo then
			local progresso = sound.TimePosition / sound.TimeLength
			aplicarSliderTempoVisualPainel(progresso)
			txtTempoAtual.Text = formatarTempo(sound.TimePosition)
		end
		txtTempoTotal.Text = formatarTempo(sound.TimeLength)
	end
end)

radioEvent.OnClientEvent:Connect(function(acao, alvoModel)
	if acao == "AbrirMenu" then
		-- Com Bluetooth pareado nesta caixa: só o celular (CH-OS) reage — não abre o painel da caixa.
		if jbEstadoJBLEski.estaPareadoCom(alvoModel) then
			if framePrincipal.Visible then
				fecharMenu()
			end
			return
		end
		radioAtual = alvoModel
		if not framePrincipal.Visible then
			uiScale.Scale = 0
			framePrincipal.Visible = true
			if tweenUiAtual then
				tweenUiAtual:Cancel()
			end
			tweenUiAtual = TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			tweenUiAtual:Play()
			tweenUiAtual.Completed:Once(function()
				tweenUiAtual = nil
			end)
		end
		atualizarPlaylistUI()
		monitorarFimDaMusica()
	end
end)

task.defer(function()
	local playlistData = player:WaitForChild("PlaylistData", REMOTE_TIMEOUT)
	if playlistData then
		atualizarPlaylistUI()
		playlistData.ChildAdded:Connect(atualizarPlaylistUI)
		playlistData.ChildRemoved:Connect(atualizarPlaylistUI)
	end
end)
