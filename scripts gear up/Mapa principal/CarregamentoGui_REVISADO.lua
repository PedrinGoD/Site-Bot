-- CH Corporations - Loading screen (street racing + playlist + skip) — LocalScript em ReplicatedFirst
-- Revisão: TeleportData com tipo seguro; Volume do Sound 0–1; PlayerGui + dados do jogador com timeout (evita yield infinito);
--          barra de progresso sem spam de Tween (atualiza Size direto); frases com wait pelo duração do tween (spawn isolado); remove GUI duplicada;
--          ScreenGui ResetOnSpawn false + ZIndex; desliga RenderStepped/input ao sair; pcall onde faz sentido.

print("CH Corporations - Loading screen (street racing — revisão)")

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local PLAYER_GUI_TIMEOUT = 60
local WAIT_PLAYER_DATA = 180
local TEMPO_MINIMO_CARREGAMENTO = 2
local ID_DA_IMAGEM = "rbxassetid://138285533392235"

local PLAYLIST = {
	"rbxassetid://74203709922207",
	"rbxassetid://88069451234788",
}

local FRASES = {
	"Ajustando o Stage do motor...",
	"Calibrando a suspensão...",
	"Aquecendo os pneus...",
	"Abastecendo os galões...",
	"Sincronizando o banco de dados...",
	"Abrindo as portas da garagem...",
}

local COR_PRIMARIA = Color3.fromRGB(255, 60, 0)
local COR_FUNDO = Color3.fromRGB(12, 12, 12)

local player = Players.LocalPlayer

local teleportData = TeleportService:GetLocalPlayerTeleportData()
if type(teleportData) == "table" and teleportData.VoltandoDaCorrida then
	print("[Carregamento] Voltando da corrida — skip da tela.")
	ReplicatedFirst:RemoveDefaultLoadingScreen()
	script:Destroy()
	return
end

ReplicatedFirst:RemoveDefaultLoadingScreen()

local tempoInicio = os.clock()
local progressoGlobal = 0

local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_TIMEOUT)
if not playerGui then
	warn("[Carregamento] PlayerGui em falta — RemoveDefaultLoadingScreen já aplicado; script encerra.")
	script:Destroy()
	return
end

local guiAntiga = playerGui:FindFirstChild("CarregamentoGui")
if guiAntiga then
	guiAntiga:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CarregamentoGui"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local fundoFrame = Instance.new("Frame")
fundoFrame.Size = UDim2.new(1, 0, 1, 0)
fundoFrame.BackgroundColor3 = COR_FUNDO
fundoFrame.BorderSizePixel = 0
fundoFrame.Parent = gui

local clipFrame = Instance.new("Frame")
clipFrame.Size = UDim2.new(1, 0, 1, 0)
clipFrame.BackgroundTransparency = 1
clipFrame.BorderSizePixel = 0
clipFrame.ClipsDescendants = true
clipFrame.Parent = fundoFrame

local fundoImagem = Instance.new("ImageLabel")
fundoImagem.Size = UDim2.new(1.05, 0, 1.05, 0)
fundoImagem.Position = UDim2.new(0.5, 0, 0.5, 0)
fundoImagem.AnchorPoint = Vector2.new(0.5, 0.5)
fundoImagem.BackgroundTransparency = 1
fundoImagem.Image = ID_DA_IMAGEM
fundoImagem.ScaleType = Enum.ScaleType.Crop
fundoImagem.ImageTransparency = 0.5
fundoImagem.Parent = clipFrame

local txtRPM = Instance.new("TextLabel")
txtRPM.Size = UDim2.new(0.6, 0, 0, 20)
txtRPM.Position = UDim2.new(0.2, 0, 0.8, -25)
txtRPM.BackgroundTransparency = 1
txtRPM.Text = "RPM: 1000"
txtRPM.TextColor3 = COR_PRIMARIA
txtRPM.Font = Enum.Font.GothamBold
txtRPM.TextSize = 14
txtRPM.TextXAlignment = Enum.TextXAlignment.Right
txtRPM.Parent = fundoFrame

local txtStatus = Instance.new("TextLabel")
txtStatus.Size = UDim2.new(0.6, 0, 0, 30)
txtStatus.Position = UDim2.new(0.2, 0, 0.8, -35)
txtStatus.BackgroundTransparency = 1
txtStatus.Text = "Preparando as ruas..."
txtStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
txtStatus.Font = Enum.Font.GothamMedium
txtStatus.TextSize = 16
txtStatus.TextXAlignment = Enum.TextXAlignment.Left
txtStatus.Parent = fundoFrame

local bgBarra = Instance.new("Frame")
bgBarra.Size = UDim2.new(0.6, 0, 0, 8)
bgBarra.Position = UDim2.new(0.2, 0, 0.8, 5)
bgBarra.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
bgBarra.BorderSizePixel = 0
bgBarra.Parent = fundoFrame
Instance.new("UICorner", bgBarra).CornerRadius = UDim.new(1, 0)

local fillBarra = Instance.new("Frame")
fillBarra.Size = UDim2.new(0, 0, 1, 0)
fillBarra.BackgroundColor3 = COR_PRIMARIA
fillBarra.BorderSizePixel = 0
fillBarra.Parent = bgBarra
Instance.new("UICorner", fillBarra).CornerRadius = UDim.new(1, 0)

local glow = Instance.new("UIStroke")
glow.Color = COR_PRIMARIA
glow.Thickness = 2
glow.Transparency = 0.3
glow.Parent = fillBarra

local txtStart = Instance.new("TextLabel")
txtStart.Size = UDim2.new(1, 0, 0, 50)
txtStart.Position = UDim2.new(0, 0, 0.8, -10)
txtStart.BackgroundTransparency = 1
txtStart.Text = "PRESSIONE QUALQUER TECLA PARA LIGAR O MOTOR"
txtStart.TextColor3 = Color3.fromRGB(255, 255, 255)
txtStart.Font = Enum.Font.GothamBlack
txtStart.TextSize = 22
txtStart.Visible = false
txtStart.Parent = fundoFrame

local musica = Instance.new("Sound")
musica.Volume = 0.65
musica.Looped = false
musica.Parent = gui

local indexMusica = 1

local function tocarProximaMusica()
	if #PLAYLIST == 0 then
		return
	end
	local id = PLAYLIST[indexMusica]
	if id then
		musica.SoundId = id
		musica:Play()
	end
end

musica.Ended:Connect(function()
	if #PLAYLIST == 0 then
		return
	end
	indexMusica += 1
	if indexMusica > #PLAYLIST then
		indexMusica = 1
	end
	tocarProximaMusica()
end)

tocarProximaMusica()

local isLoaded = false
local aguardandoIgnicao = false

TweenService:Create(
	fundoImagem,
	TweenInfo.new(TEMPO_MINIMO_CARREGAMENTO + 10, Enum.EasingStyle.Linear),
	{ Size = UDim2.new(1.2, 0, 1.2, 0) }
):Play()

local conexaoEfeitos = RunService.RenderStepped:Connect(function()
	if not fundoImagem.Parent then
		return
	end
	if not aguardandoIgnicao then
		local anguloSway = math.sin(os.clock() * 1.5) * 2
		fundoImagem.Rotation = anguloSway
		local intensidadeTremo = 0.001 + (0.005 * progressoGlobal)
		local tremeX = (math.random() - 0.5) * intensidadeTremo
		local tremeY = (math.random() - 0.5) * intensidadeTremo
		fundoImagem.Position = UDim2.new(0.5 + tremeX, 0, 0.5 + tremeY, 0)
	else
		fundoImagem.Rotation = math.sin(os.clock() * 1) * 1
		local tremeLenta = 0.001
		fundoImagem.Position = UDim2.new(0.5 + (math.random() - 0.5) * tremeLenta, 0, 0.5 + (math.random() - 0.5) * tremeLenta, 0)
	end
end)

task.spawn(function()
	local index = 1
	while not isLoaded and txtStatus.Parent do
		local twOut = TweenService:Create(txtStatus, TweenInfo.new(0.5), { TextTransparency = 1 })
		twOut:Play()
		task.wait(0.52)

		if isLoaded then
			break
		end

		txtStatus.Text = FRASES[index]
		index += 1
		if index > #FRASES then
			index = 1
		end

		local twIn = TweenService:Create(txtStatus, TweenInfo.new(0.5), { TextTransparency = 0 })
		twIn:Play()

		task.wait(2.5)
	end
end)

task.spawn(function()
	while not isLoaded and fillBarra.Parent do
		local tempoDecorrido = os.clock() - tempoInicio
		local progressoTempo = math.clamp(tempoDecorrido / TEMPO_MINIMO_CARREGAMENTO, 0, 1)
		progressoGlobal = progressoTempo

		fillBarra.Size = UDim2.new(progressoTempo, 0, 1, 0)

		local rpmAtual = math.floor(1000 + (progressoTempo * 7000))
		txtRPM.Text = "RPM: " .. tostring(rpmAtual)
		if rpmAtual > 7000 then
			txtRPM.TextColor3 = Color3.fromRGB(255, 0, 0)
		else
			txtRPM.TextColor3 = COR_PRIMARIA
		end

		task.wait(0.1)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local function esperarDado(nome)
	local ch = player:WaitForChild(nome, WAIT_PLAYER_DATA)
	if not ch then
		warn("[Carregamento] Timeout a aguardar", nome, "— continuação mesmo assim.")
	end
	return ch
end

esperarDado("leaderstats")
esperarDado("CarData")
esperarDado("InventarioVeiculos")

if not player.Character then
	local tChar = os.clock()
	while not player.Character and (os.clock() - tChar) < 60 do
		task.wait(0.2)
	end
	if not player.Character then
		warn("[Carregamento] Character ainda não existe após 60s — segue fluxo.")
	end
end

local tempoAtual = os.clock()
local tempoGasto = tempoAtual - tempoInicio
if tempoGasto < TEMPO_MINIMO_CARREGAMENTO then
	task.wait(TEMPO_MINIMO_CARREGAMENTO - tempoGasto)
end

isLoaded = true
aguardandoIgnicao = true

TweenService:Create(txtStatus, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
TweenService:Create(txtRPM, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
TweenService:Create(bgBarra, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
TweenService:Create(fillBarra, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
glow:Destroy()

task.wait(0.5)

txtStart.Visible = true
local tweenPiscarOut = TweenService:Create(
	txtStart,
	TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ TextTransparency = 0.6 }
)
tweenPiscarOut:Play()

local partidaDada = false
local inputConnection

inputConnection = UserInputService.InputBegan:Connect(function(input, _gameProcessed)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.Keyboard
	then
		partidaDada = true
	end
end)

while not partidaDada do
	task.wait(0.1)
end

if inputConnection then
	inputConnection:Disconnect()
end
tweenPiscarOut:Cancel()

txtStart.TextTransparency = 0
txtStart.Text = "MOTOR LIGADO!"
txtStart.TextColor3 = COR_PRIMARIA

conexaoEfeitos:Disconnect()

task.wait(0.5)

local tweenFundo = TweenService:Create(fundoFrame, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	BackgroundTransparency = 1,
})
local tweenImagem = TweenService:Create(fundoImagem, TweenInfo.new(1.2), { ImageTransparency = 1 })
local tweenStartText = TweenService:Create(txtStart, TweenInfo.new(0.5), { TextTransparency = 1 })
local tweenMusica = TweenService:Create(musica, TweenInfo.new(1.2), { Volume = 0 })

tweenFundo:Play()
tweenImagem:Play()
tweenStartText:Play()
tweenMusica:Play()

tweenFundo.Completed:Once(function()
	if gui.Parent then
		gui:Destroy()
	end
	if script.Parent then
		script:Destroy()
	end
end)
