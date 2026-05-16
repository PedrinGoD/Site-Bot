print("CH Corporations - Menu Seleção e Câmera Cinematográfica (V3.1 - Sincronizado)")

local player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui", 30)
if not playerGui then
	warn("[SelecaoDeCarroUI] PlayerGui não carregou — script desativado.")
	return
end

-- ==========================================
-- ⚙️ CONFIGURAÇÃO DA CÂMERA CINEMATOGRÁFICA
-- ==========================================
local CONFIG_CAMERA = {
	DISTANCIA_LADO = 10,  
	ALTURA = 6,             
	DISTANCIA_FRENTE = 6,  
	OLHAR_ALTURA_OFFSET = 1.5 
}

-- Aguarda os eventos oficiais do Servidor (antes da UI, para não perder FireClient do servidor)
local eventoEscolha = ReplicatedStorage:WaitForChild("EscolherCarroCorrida", 10)
local evFocarCamera = ReplicatedStorage:WaitForChild("FocarCameraSpawnEvent", 10)
local evDadosProntos = ReplicatedStorage:WaitForChild("DadosProntosEvent", 10)

-- Referência preenchida depois: fecha menu + câmera (evita corrida: evento antes do Connect no fim do script)
local refMenu = { gui = nil :: ScreenGui? }

local function fecharMenuSelecao()
	local g = refMenu.gui
	if g and g.Parent then
		g:Destroy()
	end
	refMenu.gui = nil
end

local function aplicarCameraNaVaga(vagaPart: Instance?)
	if not vagaPart or not vagaPart:IsA("BasePart") then
		return
	end
	Camera.CameraType = Enum.CameraType.Scriptable
	local offsetPosicao = CFrame.new(
		CONFIG_CAMERA.DISTANCIA_LADO,
		CONFIG_CAMERA.ALTURA,
		CONFIG_CAMERA.DISTANCIA_FRENTE
	)
	local posicaoMundoCamera = vagaPart.CFrame * offsetPosicao
	local pontoParaOlhar = vagaPart.Position + Vector3.new(0, CONFIG_CAMERA.OLHAR_ALTURA_OFFSET, 0)
	Camera.CFrame = CFrame.new(posicaoMundoCamera.Position, pontoParaOlhar)
	fecharMenuSelecao()
end

if evFocarCamera then
	evFocarCamera.OnClientEvent:Connect(aplicarCameraNaVaga)
end

player:GetAttributeChangedSignal("CarroEscolhido"):Connect(function()
	if player:GetAttribute("CarroEscolhido") then
		fecharMenuSelecao()
	end
end)

-- 🎨 1. GERA A TELA DE ESCOLHA FULLSCREEN
local guiEscolha = Instance.new("ScreenGui")
refMenu.gui = guiEscolha
guiEscolha.Name = "MenuSelecaoCorrida"
guiEscolha.ResetOnSpawn = false
guiEscolha.IgnoreGuiInset = true 
guiEscolha.Parent = playerGui

local fundo = Instance.new("Frame")
fundo.Size = UDim2.new(1, 0, 1, 0)
fundo.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
fundo.Parent = guiEscolha

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, 0, 0.1, 0) 
titulo.Position = UDim2.new(0, 0, 0.05, 0)
titulo.BackgroundTransparency = 1
titulo.Text = "CARREGANDO GARAGEM..." 
titulo.TextColor3 = Color3.fromRGB(0, 255, 255) 
titulo.TextScaled = true
titulo.Font = Enum.Font.GothamBold
titulo.Parent = fundo

local limiteTexto = Instance.new("UITextSizeConstraint")
limiteTexto.MaxTextSize = 40
limiteTexto.Parent = titulo

local lista = Instance.new("ScrollingFrame")
lista.Size = UDim2.new(0.85, 0, 0.75, 0)
lista.Position = UDim2.new(0.075, 0, 0.2, 0)
lista.BackgroundTransparency = 1
lista.ScrollBarThickness = 6
lista.Parent = fundo

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 12)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = lista

lista.AutomaticCanvasSize = Enum.AutomaticSize.Y

-- 🚥 2. GERA O SEMÁFORO
local guiSemaforo = Instance.new("ScreenGui")
guiSemaforo.Name = "HUD_Semaforo"
guiSemaforo.ResetOnSpawn = false
guiSemaforo.IgnoreGuiInset = true 
guiSemaforo.Parent = playerGui

local textoSemaforo = Instance.new("TextLabel")
textoSemaforo.Size = UDim2.new(1, 0, 1, 0)
textoSemaforo.BackgroundTransparency = 1
textoSemaforo.Text = ""
textoSemaforo.TextColor3 = Color3.fromRGB(255, 255, 255)
textoSemaforo.TextScaled = true
textoSemaforo.Font = Enum.Font.GothamBlack
textoSemaforo.Visible = false
textoSemaforo.ZIndex = 10
textoSemaforo.Parent = guiSemaforo

-- 🚗 FUNÇÃO INTELIGENTE PARA CRIAR O BOTÃO
local function criarBotaoCarro(nomeCarro)
	if lista:FindFirstChild(nomeCarro) then return end

	titulo.Text = "SELECIONE SEU CARRO"
	titulo.TextColor3 = Color3.fromRGB(255, 170, 0)

	local btn = Instance.new("TextButton")
	btn.Name = nomeCarro
	btn.Size = UDim2.new(0.8, 0, 0, 65) 
	btn.Text = string.gsub(nomeCarro, "_", " ")
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamSemibold
	btn.TextScaled = true 

	local limiteBtnTexto = Instance.new("UITextSizeConstraint")
	limiteBtnTexto.MaxTextSize = 24
	limiteBtnTexto.Parent = btn

	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 8)
	btn.Parent = lista

	btn.MouseButton1Click:Connect(function()
		if eventoEscolha then
			eventoEscolha:FireServer(nomeCarro)
			-- Não desativar aqui: se o servidor falhar antes da câmera, o menu some e o jogador fica preso.
			-- O menu some quando FocarCameraSpawnEvent destrói o ScreenGui (após carro carregar com sucesso).
		else
			warn("⚠️ Evento EscolherCarroCorrida não encontrado no servidor!")
		end
	end)
end

-- =========================================================
-- 🔍 INVENTÁRIO (sem OnClientEvent:Wait — evita perder FireClient se o servidor disparar primeiro)
-- =========================================================
local function ehEntradaDeCarro(inst: Instance): boolean
	if inst:IsA("StringValue") and inst.Name ~= "" and inst.Name ~= "Value" then
		return true
	end
	return false
end

local function atualizarListaDeCarros(inventario: Instance)
	local carros = inventario:GetChildren()
	local algum = false
	for _, carro in ipairs(carros) do
		if ehEntradaDeCarro(carro) then
			criarBotaoCarro(carro.Name)
			algum = true
		end
	end
	if algum then
		titulo.Text = "SELECIONE SEU CARRO"
		titulo.TextColor3 = Color3.fromRGB(255, 170, 0)
	else
		titulo.Text = "NENHUM CARRO ENCONTRADO!"
		titulo.TextColor3 = Color3.fromRGB(255, 50, 50)
	end
end

task.spawn(function()
	local inventario = player:WaitForChild("InventarioVeiculos", 30)
	if not inventario then
		titulo.Text = "INVENTÁRIO INDISPONÍVEL"
		titulo.TextColor3 = Color3.fromRGB(255, 50, 50)
		return
	end

	-- Atualiza já (dados podem estar prontos antes do LocalScript correr)
	atualizarListaDeCarros(inventario)

	if evDadosProntos then
		evDadosProntos.OnClientEvent:Connect(function()
			atualizarListaDeCarros(inventario)
		end)
	end

	inventario.ChildAdded:Connect(function(carro)
		if carro.Name == "Value" then
			repeat task.wait() until carro.Name ~= "Value"
		end
		if ehEntradaDeCarro(carro) then
			criarBotaoCarro(carro.Name)
			titulo.Text = "SELECIONE SEU CARRO"
			titulo.TextColor3 = Color3.fromRGB(255, 170, 0)
		end
	end)

	-- Releitura curta: replicação / DataStore por vezes chega um frame depois
	for _, delay in ipairs({ 0.15, 0.5, 1.5 }) do
		task.delay(delay, function()
			atualizarListaDeCarros(inventario)
		end)
	end
end)

-- 🎬 Câmera + fecho do menu: registado no topo (FocarCameraSpawnEvent)

-- 🛑 DEVOLVER A CÂMERA AO NORMAL QUANDO SENTAR
player.CharacterAdded:Connect(function(char)
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.Seated:Connect(function(isSeated)
		if isSeated and Camera.CameraType == Enum.CameraType.Scriptable then
			Camera.CameraType = Enum.CameraType.Custom
			print("🎬 Câmera devolvida ao normal (Jogador no DriveSeat)")
		end
	end)
end)

local char = player.Character
if char then
	local humanoid = char:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Seated:Connect(function(isSeated)
			if isSeated and Camera.CameraType == Enum.CameraType.Scriptable then
				Camera.CameraType = Enum.CameraType.Custom
				print("🎬 Câmera devolvida ao normal (Jogador no DriveSeat)")
			end
		end)
	end
end

-- 📡 Recebe o sinal do semáforo
local evSemaforo = ReplicatedStorage:WaitForChild("SemaforoEvent", 10)
if evSemaforo then
	evSemaforo.OnClientEvent:Connect(function(texto, cor)
		textoSemaforo.Visible = true
		textoSemaforo.Text = texto
		textoSemaforo.TextColor3 = cor
		if texto == "" then textoSemaforo.Visible = false end
	end)
end
