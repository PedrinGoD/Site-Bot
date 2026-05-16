-- CH Corporations - CH-OS (StarterPlayerScripts / LocalScript)
-- Revisão: sem criar RemoteEvent no cliente; Workspace via GetService; remotes resolvidos com timeout;
--          AlterarTamanho resolvido uma vez; Car Meet com debounce + Activated; string.find em modo literal;
--          sem task.wait bloqueante em handlers (Bluetooth seek, confirmar tag); celularAberto declarado cedo;
--          tema claro/escuro (Ajustes + SalvarConfigCelularEvent "Tema"); grelha de apps centrada.

print("CH Corporations - CH-OS v2.1 (tema claro/escuro + home centrada)")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CaptureService = game:GetService("CaptureService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local REMOTE_TIMEOUT = 60

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local celularAberto = false

-- Tema claro/escuro (aplicarTema definido após a grelha de apps)
local aplicarTema
local corTituloAppPadrao = Color3.fromRGB(255, 255, 255)
local homeAppIconeFundos = {}
local homeAppNomeLabels = {}
local homeAppEmojiLabels = {}
local barrasSinal = {}
local btnTemaEscuroRef, btnTemaClaroRef
local corTagFundoOff = Color3.fromRGB(40, 40, 45)
local corTagTextoOff = Color3.fromRGB(255, 255, 255)
local corPlaylistItemBg = Color3.fromRGB(40, 40, 40)
local corPlaylistItemTxt = Color3.fromRGB(179, 179, 179)
local temaClaroAtivo = false

local PALETA_ESC = {
	phone = Color3.fromRGB(15, 15, 20),
	strokeP = Color3.fromRGB(80, 80, 90),
	launcher = Color3.fromRGB(20, 20, 25),
	launcherStroke = Color3.fromRGB(0, 255, 255),
	boot = Color3.fromRGB(10, 10, 15),
	bootLogo = Color3.fromRGB(0, 255, 255),
	clock = Color3.fromRGB(255, 255, 255),
	notch = Color3.fromRGB(0, 0, 0),
	lente = Color3.fromRGB(20, 25, 35),
	batCase = Color3.fromRGB(255, 255, 255),
	batFill = Color3.fromRGB(255, 255, 255),
	sinal = Color3.fromRGB(255, 255, 255),
	appPanel = Color3.fromRGB(20, 20, 25),
	voltarBg = Color3.fromRGB(40, 40, 45),
	voltarTxt = Color3.fromRGB(255, 255, 255),
	titulo = Color3.fromRGB(255, 255, 255),
	iconTile = Color3.fromRGB(40, 40, 50),
	homeLbl = Color3.fromRGB(255, 255, 255),
	configTit = Color3.fromRGB(200, 200, 200),
	configTrack = Color3.fromRGB(30, 30, 35),
	pct = Color3.fromRGB(0, 255, 255),
	musicBg = Color3.fromRGB(18, 18, 18),
	musicGray = Color3.fromRGB(40, 40, 40),
	musicTxt = Color3.fromRGB(179, 179, 179),
	musicNome = Color3.fromRGB(29, 185, 84),
	wallThumb = Color3.fromRGB(40, 40, 45),
	toastBg = Color3.fromRGB(25, 28, 35),
	toastStr = Color3.fromRGB(0, 200, 255),
	homeInd = Color3.fromRGB(255, 255, 255),
	fotoBg = Color3.fromRGB(30, 30, 35),
	statsBg = Color3.fromRGB(30, 30, 35),
	xpFundo = Color3.fromRGB(15, 15, 20),
	xpTxt = Color3.fromRGB(255, 255, 255),
	relogiosBg = Color3.fromRGB(30, 30, 35),
	bankCard2 = Color3.fromRGB(30, 30, 35),
	bankLbl = Color3.fromRGB(150, 150, 150),
	carMeetSub = Color3.fromRGB(200, 200, 200),
	guinchoInfo = Color3.fromRGB(190, 190, 200),
	tagOffBg = Color3.fromRGB(40, 40, 45),
	tagOffTxt = Color3.fromRGB(255, 255, 255),
	playlistBg = Color3.fromRGB(40, 40, 40),
	playlistTxt = Color3.fromRGB(179, 179, 179),
	guinchoBtn = Color3.fromRGB(255, 170, 60),
	guinchoBtnTxt = Color3.fromRGB(25, 20, 10),
	meetBtnVerde = Color3.fromRGB(0, 255, 127),
	meetBtnVerm = Color3.fromRGB(255, 60, 60),
	temaBtnOff = Color3.fromRGB(45, 48, 58),
	temaBtnTxt = Color3.fromRGB(255, 255, 255),
	fillAccent = Color3.fromRGB(0, 255, 255),
	meetTxtPublico = Color3.fromRGB(255, 120, 0),
}

local PALETA_CLA = {
	phone = Color3.fromRGB(248, 248, 252),
	strokeP = Color3.fromRGB(175, 178, 190),
	launcher = Color3.fromRGB(236, 237, 244),
	launcherStroke = Color3.fromRGB(0, 150, 200),
	boot = Color3.fromRGB(242, 243, 248),
	bootLogo = Color3.fromRGB(0, 140, 180),
	clock = Color3.fromRGB(38, 40, 50),
	notch = Color3.fromRGB(198, 200, 208),
	lente = Color3.fromRGB(130, 135, 145),
	batCase = Color3.fromRGB(80, 82, 92),
	batFill = Color3.fromRGB(50, 170, 95),
	sinal = Color3.fromRGB(65, 68, 78),
	appPanel = Color3.fromRGB(246, 247, 250),
	voltarBg = Color3.fromRGB(228, 230, 238),
	voltarTxt = Color3.fromRGB(35, 38, 48),
	titulo = Color3.fromRGB(28, 30, 38),
	iconTile = Color3.fromRGB(228, 230, 240),
	homeLbl = Color3.fromRGB(40, 42, 52),
	configTit = Color3.fromRGB(75, 78, 90),
	configTrack = Color3.fromRGB(210, 212, 222),
	pct = Color3.fromRGB(0, 140, 185),
	musicBg = Color3.fromRGB(236, 237, 242),
	musicGray = Color3.fromRGB(218, 220, 230),
	musicTxt = Color3.fromRGB(88, 90, 100),
	musicNome = Color3.fromRGB(22, 145, 78),
	wallThumb = Color3.fromRGB(215, 218, 228),
	toastBg = Color3.fromRGB(252, 252, 255),
	toastStr = Color3.fromRGB(0, 140, 200),
	homeInd = Color3.fromRGB(130, 135, 145),
	fotoBg = Color3.fromRGB(218, 220, 230),
	statsBg = Color3.fromRGB(230, 232, 240),
	xpFundo = Color3.fromRGB(210, 212, 220),
	xpTxt = Color3.fromRGB(35, 38, 48),
	relogiosBg = Color3.fromRGB(230, 232, 240),
	bankCard2 = Color3.fromRGB(230, 232, 240),
	bankLbl = Color3.fromRGB(100, 102, 115),
	carMeetSub = Color3.fromRGB(90, 92, 105),
	guinchoInfo = Color3.fromRGB(85, 88, 100),
	tagOffBg = Color3.fromRGB(218, 220, 230),
	tagOffTxt = Color3.fromRGB(45, 48, 58),
	playlistBg = Color3.fromRGB(218, 220, 230),
	playlistTxt = Color3.fromRGB(70, 72, 82),
	guinchoBtn = Color3.fromRGB(255, 155, 50),
	guinchoBtnTxt = Color3.fromRGB(35, 30, 15),
	meetBtnVerde = Color3.fromRGB(40, 190, 110),
	meetBtnVerm = Color3.fromRGB(230, 70, 70),
	temaBtnOff = Color3.fromRGB(220, 222, 232),
	temaBtnTxt = Color3.fromRGB(35, 38, 48),
	fillAccent = Color3.fromRGB(0, 170, 210),
	meetTxtPublico = Color3.fromRGB(200, 95, 25),
}

local function paletaAtual()
	return temaClaroAtivo and PALETA_CLA or PALETA_ESC
end

local ID_BRONZE = 1737108751
local ID_GOLD = 1746268685
local ID_DIAMANTE = 1746862603

local infosVip = {
	Diamante = { nome = "Diamante", cor = Color3.fromRGB(0, 255, 255), emoji = "💎" },
	Gold     = { nome = "Gold",     cor = Color3.fromRGB(255, 215, 0), emoji = "🥇" },
	Bronze   = { nome = "Bronze",   cor = Color3.fromRGB(210, 105, 30), emoji = "🥉" },
	Comum    = { nome = "Comum",    cor = Color3.fromRGB(180, 180, 180), emoji = "👤" }
}

local evConfigCelular = ReplicatedStorage:WaitForChild("SalvarConfigCelularEvent", REMOTE_TIMEOUT)
if not evConfigCelular or not evConfigCelular:IsA("RemoteEvent") then
	warn("[CH-OS] SalvarConfigCelularEvent em falta — brilho/wallpaper não salvam no servidor.")
	evConfigCelular = nil
end

local radioEvent = ReplicatedStorage:WaitForChild("RadioJBLEskiEvent", REMOTE_TIMEOUT)
if not radioEvent or not radioEvent:IsA("RemoteEvent") then
	warn("[CH-OS] RadioJBLEskiEvent em falta — Bluetooth/caixa de som desativados.")
	radioEvent = nil
end

-- Estado de pareamento compartilhado com MenuRadioJBLEski (ModuleScript em ReplicatedStorage).
local jbEstadoJBLEski
do
	local mod = ReplicatedStorage:WaitForChild("JBLEskiClienteEstado", 5)
	if mod and mod:IsA("ModuleScript") then
		local ok, req = pcall(require, mod)
		if ok then
			jbEstadoJBLEski = req
		end
	end
	if not jbEstadoJBLEski then
		warn("[CH-OS] Coloque o ModuleScript JBLEskiClienteEstado no ReplicatedStorage (ver arquivo JBLEskiClienteEstado.lua).")
		jbEstadoJBLEski = {
			atualizarPareamento = function() end,
			estaPareadoCom = function()
				return false
			end,
		}
	end
end

-- Canal servidor → carro (nunca criar no cliente)
local evToggleCarMeet = ReplicatedStorage:WaitForChild("ToggleCarMeetEvent", REMOTE_TIMEOUT)
if not evToggleCarMeet or not evToggleCarMeet:IsA("RemoteEvent") then
	warn("[CH-OS] ToggleCarMeetEvent em falta no ReplicatedStorage — servidor deve criar o RemoteEvent.")
	evToggleCarMeet = nil
end

local evAlterarTamanho = ReplicatedStorage:WaitForChild("AlterarTamanhoCelularEvent", REMOTE_TIMEOUT)
if not evAlterarTamanho or not evAlterarTamanho:IsA("RemoteEvent") then
	warn("[CH-OS] AlterarTamanhoCelularEvent em falta — slider de tamanho não sincroniza com o servidor.")
	evAlterarTamanho = nil
end

-- Guincho: servidor cria o RemoteEvent se usares SistemaGuincho_REVISADO.lua
local evGuincho = ReplicatedStorage:WaitForChild("GuinchoAssistenciaEvent", REMOTE_TIMEOUT)
if not evGuincho or not evGuincho:IsA("RemoteEvent") then
	warn("[CH-OS] GuinchoAssistenciaEvent em falta — coloca SistemaGuincho no ServerScriptService.")
	evGuincho = nil
end

local guiAntiga = playerGui:FindFirstChild("CH_SmartphoneOS")
if guiAntiga then guiAntiga:Destroy() end

local celularGui = Instance.new("ScreenGui")
celularGui.Name = "CH_SmartphoneOS"
celularGui.IgnoreGuiInset = true
celularGui.ResetOnSpawn = false
celularGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
celularGui.DisplayOrder = 50
celularGui.Parent = playerGui

local somLocal = Instance.new("Sound", celularGui)
somLocal.Volume = 1

-- =========================================================
-- 📱 CARCAÇA DO CELULAR
-- =========================================================
-- Botão fora do tema (sempre escuro + bem visível); ZIndex alto para ficar acima do telemóvel.
local btnAbrirCelular = Instance.new("ImageButton", celularGui)
btnAbrirCelular.Name = "BtnAbrirCelular"
btnAbrirCelular.Size = UDim2.new(0, 50, 0, 50)
btnAbrirCelular.Position = UDim2.new(0, 15, 0.5, -80)
btnAbrirCelular.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
btnAbrirCelular.Image = "rbxassetid://106548942327118"
btnAbrirCelular.ImageTransparency = 0
btnAbrirCelular.BackgroundTransparency = 0
btnAbrirCelular.ZIndex = 100
btnAbrirCelular.AutoButtonColor = true
Instance.new("UICorner", btnAbrirCelular).CornerRadius = UDim.new(0, 15)
local strokeAbrirCel = Instance.new("UIStroke", btnAbrirCelular)
strokeAbrirCel.Color = Color3.fromRGB(0, 255, 255)
strokeAbrirCel.Thickness = 1.5

local posicaoFechado = UDim2.new(1, -20, 2, 0)
local posicaoAberto = UDim2.new(1, -20, 1, -20)

local phoneFrame = Instance.new("Frame", celularGui)
phoneFrame.Name = "PhoneBody"
phoneFrame.Size = UDim2.new(0, 300, 0, 600)
phoneFrame.AnchorPoint = Vector2.new(1, 1)
phoneFrame.Position = posicaoFechado
phoneFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
phoneFrame.ClipsDescendants = true
Instance.new("UICorner", phoneFrame).CornerRadius = UDim.new(0, 35)

local uiScaleCelular = Instance.new("UIScale", phoneFrame)
uiScaleCelular.Scale = 1

local bordaMetalica = Instance.new("UIStroke", phoneFrame)
bordaMetalica.Thickness = 4
bordaMetalica.Color = Color3.fromRGB(80, 80, 90)

local wallpaper = Instance.new("ImageLabel", phoneFrame)
wallpaper.Size = UDim2.new(1, 0, 1, 0)
wallpaper.Image = "rbxassetid://101669118895000"
wallpaper.ScaleType = Enum.ScaleType.Crop
wallpaper.ZIndex = 1
Instance.new("UICorner", wallpaper).CornerRadius = UDim.new(0, 35)

local overlayBrilho = Instance.new("Frame", phoneFrame)
overlayBrilho.Size = UDim2.new(1, 0, 1, 0)
overlayBrilho.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlayBrilho.BackgroundTransparency = 1
overlayBrilho.ZIndex = 90
Instance.new("UICorner", overlayBrilho).CornerRadius = UDim.new(0, 35)

-- =========================================================
-- 🚀 TELA DE BOOT E STATUS BAR
-- =========================================================
local telaBoot = Instance.new("Frame", phoneFrame)
telaBoot.Size = UDim2.new(1, 0, 1, 0)
telaBoot.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
telaBoot.ZIndex = 200
Instance.new("UICorner", telaBoot).CornerRadius = UDim.new(0, 35)

local logoBoot = Instance.new("TextLabel", telaBoot)
logoBoot.Size = UDim2.new(1, 0, 1, 0)
logoBoot.BackgroundTransparency = 1
logoBoot.Text = "CH-OS"
logoBoot.TextColor3 = Color3.fromRGB(0, 255, 255)
logoBoot.Font = Enum.Font.GothamBlack
logoBoot.TextSize = 35
local isBooted = false

local statusBar = Instance.new("Frame", phoneFrame)
statusBar.Size = UDim2.new(1, 0, 0, 25)
statusBar.Position = UDim2.new(0, 0, 0, 5)
statusBar.BackgroundTransparency = 1
statusBar.ZIndex = 100

local notch = Instance.new("Frame", statusBar)
notch.Size = UDim2.new(0, 75, 0, 20)
notch.Position = UDim2.new(0.5, -37.5, 0, 0)
notch.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Instance.new("UICorner", notch).CornerRadius = UDim.new(1, 0)
local lenteCamera = Instance.new("Frame", notch)
lenteCamera.Size = UDim2.new(0, 8, 0, 8)
lenteCamera.Position = UDim2.new(1, -16, 0.5, -4)
lenteCamera.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
Instance.new("UICorner", lenteCamera).CornerRadius = UDim.new(1, 0)
local clockText = Instance.new("TextLabel", statusBar)
clockText.Size = UDim2.new(0.3, 0, 1, 0)
clockText.Position = UDim2.new(0.06, 0, 0, 0)
clockText.BackgroundTransparency = 1
clockText.TextColor3 = Color3.fromRGB(255, 255, 255)
clockText.Font = Enum.Font.GothamBold
clockText.TextSize = 12
clockText.TextXAlignment = Enum.TextXAlignment.Left
task.spawn(function()
	while task.wait(1) do
		local date = os.date("*t")
		clockText.Text = string.format("%02d:%02d", date.hour, date.min)
	end
end)

local iconesDireita = Instance.new("Frame", statusBar)
iconesDireita.Size = UDim2.new(0.4, 0, 1, 0)
iconesDireita.Position = UDim2.new(0.92, 0, 0, 0)
iconesDireita.AnchorPoint = Vector2.new(1, 0)
iconesDireita.BackgroundTransparency = 1
local layoutIcones = Instance.new("UIListLayout", iconesDireita)
layoutIcones.FillDirection = Enum.FillDirection.Horizontal
layoutIcones.HorizontalAlignment = Enum.HorizontalAlignment.Right
layoutIcones.VerticalAlignment = Enum.VerticalAlignment.Center
layoutIcones.Padding = UDim.new(0, 6)
local bateriaFrame = Instance.new("Frame", iconesDireita)
bateriaFrame.Size = UDim2.new(0, 22, 0, 11)
bateriaFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
bateriaFrame.BackgroundTransparency = 0.6
bateriaFrame.LayoutOrder = 2
Instance.new("UICorner", bateriaFrame).CornerRadius = UDim.new(0, 3)
local bateriaNivel = Instance.new("Frame", bateriaFrame)
bateriaNivel.Size = UDim2.new(0.75, 0, 0.65, 0)
bateriaNivel.Position = UDim2.new(0, 2, 0.5, -3.5)
bateriaNivel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", bateriaNivel).CornerRadius = UDim.new(0, 2)
local bateriaPino = Instance.new("Frame", bateriaFrame)
bateriaPino.Size = UDim2.new(0, 2, 0, 4)
bateriaPino.Position = UDim2.new(1, 0, 0.5, -2)
bateriaPino.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
bateriaPino.BackgroundTransparency = 0.6
local sinalFrame = Instance.new("Frame", iconesDireita)
sinalFrame.Size = UDim2.new(0, 16, 0, 10)
sinalFrame.BackgroundTransparency = 1
sinalFrame.LayoutOrder = 1
local layoutSinal = Instance.new("UIListLayout", sinalFrame)
layoutSinal.FillDirection = Enum.FillDirection.Horizontal
layoutSinal.VerticalAlignment = Enum.VerticalAlignment.Bottom
layoutSinal.Padding = UDim.new(0, 2)
for i = 1, 4 do
	local barra = Instance.new("Frame", sinalFrame)
	barra.Size = UDim2.new(0, 2, 0.25 * i, 0)
	barra.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	if i == 4 then
		barra.BackgroundTransparency = 0.6
	end
	table.insert(barrasSinal, barra)
end

-- =========================================================
-- 🗂️ A GAVETA DE APLICATIVOS (Home) E TELAS
-- =========================================================
local appGrid = Instance.new("Frame", phoneFrame)
appGrid.Size = UDim2.new(0.92, 0, 0.7, 0)
appGrid.AnchorPoint = Vector2.new(0.5, 0)
appGrid.Position = UDim2.new(0.5, 0, 0.1, 0)
appGrid.BackgroundTransparency = 1
appGrid.ZIndex = 5
local layout = Instance.new("UIGridLayout", appGrid)
layout.CellSize = UDim2.new(0, 60, 0, 80)
layout.CellPadding = UDim2.new(0, 20, 0, 20)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top

local telaAppAberto = Instance.new("TextButton", phoneFrame)
telaAppAberto.Text = ""
telaAppAberto.AutoButtonColor = false
telaAppAberto.Size = UDim2.new(1, 0, 1, 0)
telaAppAberto.Position = UDim2.new(1, 0, 0, 0)
telaAppAberto.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
telaAppAberto.ZIndex = 10
Instance.new("UICorner", telaAppAberto).CornerRadius = UDim.new(0, 35)

local headerApp = Instance.new("Frame", telaAppAberto)
headerApp.Size = UDim2.new(1, 0, 0, 60)
headerApp.Position = UDim2.new(0, 0, 0, 30)
headerApp.BackgroundTransparency = 1
local btnVoltarApp = Instance.new("TextButton", headerApp)
btnVoltarApp.Size = UDim2.new(0, 30, 0, 30)
btnVoltarApp.Position = UDim2.new(0, 15, 0.5, -15)
btnVoltarApp.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
btnVoltarApp.Text = "⬅️"
btnVoltarApp.TextColor3 = Color3.fromRGB(255, 255, 255)
btnVoltarApp.TextSize = 14
btnVoltarApp.Font = Enum.Font.GothamBlack
Instance.new("UICorner", btnVoltarApp).CornerRadius = UDim.new(1, 0)
local tituloApp = Instance.new("TextLabel", headerApp)
tituloApp.Size = UDim2.new(1, -100, 1, 0)
tituloApp.Position = UDim2.new(0, 50, 0, 0)
tituloApp.BackgroundTransparency = 1
tituloApp.TextColor3 = Color3.fromRGB(255, 255, 255)
tituloApp.Font = Enum.Font.GothamBlack
tituloApp.TextSize = 20
tituloApp.TextXAlignment = Enum.TextXAlignment.Center

local appContainer = Instance.new("Frame", telaAppAberto)
appContainer.Size = UDim2.new(1, 0, 1, -120)
appContainer.Position = UDim2.new(0, 0, 0, 90)
appContainer.BackgroundTransparency = 1

local appPerfil = Instance.new("Frame", appContainer)
appPerfil.Size = UDim2.new(1, 0, 1, 0)
appPerfil.BackgroundTransparency = 1
appPerfil.Visible = false
local appVIP = Instance.new("Frame", appContainer)
appVIP.Size = UDim2.new(1, 0, 1, 0)
appVIP.BackgroundTransparency = 1
appVIP.Visible = false
local appBanco = Instance.new("Frame", appContainer)
appBanco.Size = UDim2.new(1, 0, 1, 0)
appBanco.BackgroundTransparency = 1
appBanco.Visible = false
local appConfig = Instance.new("Frame", appContainer)
appConfig.Size = UDim2.new(1, 0, 1, 0)
appConfig.BackgroundTransparency = 1
appConfig.Visible = false
local appMusic = Instance.new("Frame", appContainer)
appMusic.Size = UDim2.new(1, 0, 1, 0)
appMusic.BackgroundTransparency = 1
appMusic.Visible = false
local appCarMeet = Instance.new("Frame", appContainer)
appCarMeet.Size = UDim2.new(1, 0, 1, 0)
appCarMeet.BackgroundTransparency = 1
appCarMeet.Visible = false
local appGuincho = Instance.new("Frame", appContainer)
appGuincho.Size = UDim2.new(1, 0, 1, 0)
appGuincho.BackgroundTransparency = 1
appGuincho.Visible = false

local appCamera = Instance.new("Frame", appContainer)
appCamera.Name = "AppCamera"
appCamera.Size = UDim2.new(1, 0, 1, 0)
appCamera.BackgroundTransparency = 1
appCamera.Visible = false

local appGaleria = Instance.new("Frame", appContainer)
appGaleria.Name = "AppGaleria"
appGaleria.Size = UDim2.new(1, 0, 1, 0)
appGaleria.BackgroundTransparency = 1
appGaleria.Visible = false

-- =========================================================
-- 👤 APP 1–3: Perfil + VIP + Banco (IIFE → menos registos locais no chunk)
-- =========================================================
local AppPBB = (function()
	local imgFotoCel = Instance.new("ImageLabel", appPerfil)
imgFotoCel.Size = UDim2.new(0, 100, 0, 100)
imgFotoCel.Position = UDim2.new(0.5, -50, 0, 10)
imgFotoCel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", imgFotoCel).CornerRadius = UDim.new(1, 0)
local txtNomeCel = Instance.new("TextLabel", appPerfil)
txtNomeCel.Size = UDim2.new(1, 0, 0, 30)
txtNomeCel.Position = UDim2.new(0, 0, 0, 120)
txtNomeCel.BackgroundTransparency = 1
txtNomeCel.TextColor3 = Color3.fromRGB(255, 255, 255)
txtNomeCel.Font = Enum.Font.GothamBold
txtNomeCel.TextSize = 18
local txtVipCel = Instance.new("TextLabel", appPerfil)
txtVipCel.Size = UDim2.new(1, 0, 0, 20)
txtVipCel.Position = UDim2.new(0, 0, 0, 150)
txtVipCel.BackgroundTransparency = 1
txtVipCel.Font = Enum.Font.GothamSemibold
txtVipCel.TextSize = 12

local frameStats = Instance.new("Frame", appPerfil)
frameStats.Size = UDim2.new(0.9, 0, 0, 80)
frameStats.Position = UDim2.new(0.05, 0, 0, 200)
frameStats.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", frameStats).CornerRadius = UDim.new(0, 10)
local txtLevelCel = Instance.new("TextLabel", frameStats)
txtLevelCel.Size = UDim2.new(1, -20, 0, 20)
txtLevelCel.Position = UDim2.new(0, 10, 0, 10)
txtLevelCel.BackgroundTransparency = 1
txtLevelCel.TextColor3 = Color3.fromRGB(255, 255, 255)
txtLevelCel.Font = Enum.Font.GothamMedium
txtLevelCel.TextSize = 12
txtLevelCel.TextXAlignment = Enum.TextXAlignment.Left
local fundoBarraXP = Instance.new("Frame", frameStats)
fundoBarraXP.Size = UDim2.new(1, -20, 0, 20)
fundoBarraXP.Position = UDim2.new(0, 10, 0, 40)
fundoBarraXP.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Instance.new("UICorner", fundoBarraXP).CornerRadius = UDim.new(1, 0)
local fillBarraXP = Instance.new("Frame", fundoBarraXP)
fillBarraXP.Size = UDim2.new(0, 0, 1, 0)
fillBarraXP.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
Instance.new("UICorner", fillBarraXP).CornerRadius = UDim.new(1, 0)
local txtXpProgresso = Instance.new("TextLabel", fundoBarraXP)
txtXpProgresso.Size = UDim2.new(1, 0, 1, 0)
txtXpProgresso.BackgroundTransparency = 1
txtXpProgresso.TextColor3 = Color3.fromRGB(255, 255, 255)
txtXpProgresso.Font = Enum.Font.GothamBold
txtXpProgresso.TextSize = 10

-- =========================================================
-- ⚙️ APP 2: CONFIG VIP
-- =========================================================
local uiListVIP = Instance.new("UIListLayout", appVIP)
uiListVIP.Padding = UDim.new(0, 8)
uiListVIP.HorizontalAlignment = Enum.HorizontalAlignment.Center
local frameRelogios = Instance.new("Frame", appVIP)
frameRelogios.Size = UDim2.new(0.9, 0, 0, 90)
frameRelogios.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", frameRelogios).CornerRadius = UDim.new(0, 10)
local uiListRel = Instance.new("UIListLayout", frameRelogios)
uiListRel.Padding = UDim.new(0, 3)
uiListRel.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiListRel.VerticalAlignment = Enum.VerticalAlignment.Center

local function criarLinhaVIP(nome, emoji, cor)
	local txt = Instance.new("TextLabel", frameRelogios)
	txt.Size = UDim2.new(0.9, 0, 0, 22)
	txt.BackgroundTransparency = 1
	txt.Text = emoji .. " " .. nome .. ": ❌ Não Possui"
	txt.TextColor3 = cor
	txt.Font = Enum.Font.GothamBold
	txt.TextSize = 10
	txt.TextXAlignment = Enum.TextXAlignment.Left
	return txt
end
local TxtExpDiamante = criarLinhaVIP("Diamante", "💎", Color3.fromRGB(0, 255, 255))
local TxtExpGold = criarLinhaVIP("Gold", "🥇", Color3.fromRGB(255, 215, 0))
local TxtExpBronze = criarLinhaVIP("Bronze", "🥉", Color3.fromRGB(210, 105, 30))

local TxtEscolha = Instance.new("TextLabel", appVIP)
TxtEscolha.Size = UDim2.new(0.9, 0, 0, 18)
TxtEscolha.BackgroundTransparency = 1
TxtEscolha.Text = "Escolha sua Tag:"
TxtEscolha.TextColor3 = Color3.fromRGB(255, 255, 255)
TxtEscolha.Font = Enum.Font.GothamBold
TxtEscolha.TextSize = 12
TxtEscolha.TextXAlignment = Enum.TextXAlignment.Left
local containerTags = Instance.new("Frame", appVIP)
containerTags.Size = UDim2.new(0.9, 0, 0, 40)
containerTags.BackgroundTransparency = 1
local uiListTags = Instance.new("UIListLayout", containerTags)
uiListTags.FillDirection = Enum.FillDirection.Horizontal
uiListTags.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiListTags.Padding = UDim.new(0, 5)

local function criarBotaoTag(nome, texto, emoji)
	local btn = Instance.new("TextButton", containerTags)
	btn.Name = nome
	btn.Size = UDim2.new(0.32, 0, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	btn.Text = emoji .. "\n" .. texto
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 9
	btn.Visible = false
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(0, 255, 255)
	stroke.Transparency = 1
	return btn
end
local BtnTagBronze = criarBotaoTag("Bronze", "BRONZE", "🥉")
local BtnTagGold = criarBotaoTag("Gold", "GOLD", "🥇")
local BtnTagDiamante = criarBotaoTag("Diamante", "DIAMANTE", "💎")
local botoesTags = { BtnTagBronze, BtnTagGold, BtnTagDiamante }

local BtnConfirmar = Instance.new("TextButton", appVIP)
BtnConfirmar.Size = UDim2.new(0.9, 0, 0, 40)
BtnConfirmar.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
BtnConfirmar.Text = "✅ EQUIPAR TAG"
BtnConfirmar.TextColor3 = Color3.fromRGB(15, 15, 20)
BtnConfirmar.Font = Enum.Font.GothamBlack
BtnConfirmar.TextSize = 14
Instance.new("UICorner", BtnConfirmar).CornerRadius = UDim.new(0, 8)

-- =========================================================
-- 💸 APP 3: GEAR BANK
-- =========================================================
local corInter = Color3.fromRGB(255, 122, 0)
local cartaoSaldo = Instance.new("Frame", appBanco)
cartaoSaldo.Size = UDim2.new(0.9, 0, 0, 110)
cartaoSaldo.Position = UDim2.new(0.05, 0, 0, 10)
cartaoSaldo.BackgroundColor3 = corInter
Instance.new("UICorner", cartaoSaldo).CornerRadius = UDim.new(0, 12)
local logoBank = Instance.new("TextLabel", cartaoSaldo)
logoBank.Size = UDim2.new(1, -20, 0, 20)
logoBank.Position = UDim2.new(0, 10, 0, 10)
logoBank.BackgroundTransparency = 1
logoBank.Text = "⚙️ GEAR BANK"
logoBank.TextColor3 = Color3.fromRGB(255, 255, 255)
logoBank.Font = Enum.Font.GothamBlack
logoBank.TextSize = 14
logoBank.TextXAlignment = Enum.TextXAlignment.Left
local labelSaldo = Instance.new("TextLabel", cartaoSaldo)
labelSaldo.Size = UDim2.new(1, -20, 0, 20)
labelSaldo.Position = UDim2.new(0, 10, 0, 40)
labelSaldo.BackgroundTransparency = 1
labelSaldo.Text = "Saldo disponível"
labelSaldo.TextColor3 = Color3.fromRGB(255, 230, 200)
labelSaldo.Font = Enum.Font.GothamMedium
labelSaldo.TextSize = 12
labelSaldo.TextXAlignment = Enum.TextXAlignment.Left
local txtSaldo = Instance.new("TextLabel", cartaoSaldo)
txtSaldo.Size = UDim2.new(1, -20, 0, 30)
txtSaldo.Position = UDim2.new(0, 10, 0, 60)
txtSaldo.BackgroundTransparency = 1
txtSaldo.Text = "R$ 0,00"
txtSaldo.TextColor3 = Color3.fromRGB(255, 255, 255)
txtSaldo.Font = Enum.Font.GothamBlack
txtSaldo.TextSize = 24
txtSaldo.TextXAlignment = Enum.TextXAlignment.Left

local frameAcoes = Instance.new("Frame", appBanco)
frameAcoes.Size = UDim2.new(1, 0, 0, 80)
frameAcoes.Position = UDim2.new(0, 0, 0, 140)
frameAcoes.BackgroundTransparency = 1
local layoutAcoes = Instance.new("UIListLayout", frameAcoes)
layoutAcoes.FillDirection = Enum.FillDirection.Horizontal
layoutAcoes.HorizontalAlignment = Enum.HorizontalAlignment.Center
layoutAcoes.Padding = UDim.new(0, 15)

local function criarBotaoAcaoFake(emoji, texto)
	local btn = Instance.new("Frame", frameAcoes)
	btn.Size = UDim2.new(0, 60, 0, 75)
	btn.BackgroundTransparency = 1
	local circulo = Instance.new("Frame", btn)
	circulo.Size = UDim2.new(0, 50, 0, 50)
	circulo.Position = UDim2.new(0.5, -25, 0, 0)
	circulo.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	Instance.new("UICorner", circulo).CornerRadius = UDim.new(1, 0)
	local lblEmoji = Instance.new("TextLabel", circulo)
	lblEmoji.Size = UDim2.new(1, 0, 1, 0)
	lblEmoji.BackgroundTransparency = 1
	lblEmoji.Text = emoji
	lblEmoji.TextSize = 20
	local lblTexto = Instance.new("TextLabel", btn)
	lblTexto.Size = UDim2.new(1, 0, 0, 20)
	lblTexto.Position = UDim2.new(0, 0, 0, 55)
	lblTexto.BackgroundTransparency = 1
	lblTexto.Text = texto
	lblTexto.TextColor3 = Color3.fromRGB(200, 200, 200)
	lblTexto.Font = Enum.Font.GothamMedium
	lblTexto.TextSize = 10
	lblTexto.TextScaled = true
end
criarBotaoAcaoFake("💸", "Pix")
criarBotaoAcaoFake("📄", "Pagar")
criarBotaoAcaoFake("💳", "Cartões")
criarBotaoAcaoFake("📈", "Investir")

local cartaoCredito = Instance.new("Frame", appBanco)
cartaoCredito.Size = UDim2.new(0.9, 0, 0, 90)
cartaoCredito.Position = UDim2.new(0.05, 0, 0, 240)
cartaoCredito.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", cartaoCredito).CornerRadius = UDim.new(0, 12)
local lblFatura = Instance.new("TextLabel", cartaoCredito)
lblFatura.Size = UDim2.new(1, -20, 0, 20)
lblFatura.Position = UDim2.new(0, 10, 0, 10)
lblFatura.BackgroundTransparency = 1
lblFatura.Text = "Fatura atual"
lblFatura.TextColor3 = Color3.fromRGB(150, 150, 150)
lblFatura.Font = Enum.Font.GothamMedium
lblFatura.TextSize = 12
lblFatura.TextXAlignment = Enum.TextXAlignment.Left
local txtFatura = Instance.new("TextLabel", cartaoCredito)
txtFatura.Size = UDim2.new(1, -20, 0, 25)
txtFatura.Position = UDim2.new(0, 10, 0, 35)
txtFatura.BackgroundTransparency = 1
txtFatura.Text = "R$ 0,00"
txtFatura.TextColor3 = Color3.fromRGB(85, 255, 127)
txtFatura.Font = Enum.Font.GothamBlack
txtFatura.TextSize = 20
txtFatura.TextXAlignment = Enum.TextXAlignment.Left
local lblLimite = Instance.new("TextLabel", cartaoCredito)
lblLimite.Size = UDim2.new(1, -20, 0, 20)
lblLimite.Position = UDim2.new(0, 10, 0, 65)
lblLimite.BackgroundTransparency = 1
lblLimite.Text = "Limite de Crédito: R$ 50.000,00"
lblLimite.TextColor3 = Color3.fromRGB(150, 150, 150)
lblLimite.Font = Enum.Font.Gotham
lblLimite.TextSize = 10
lblLimite.TextXAlignment = Enum.TextXAlignment.Left

	return {
		imgFotoCel = imgFotoCel,
		txtNomeCel = txtNomeCel,
		txtVipCel = txtVipCel,
		frameStats = frameStats,
		txtLevelCel = txtLevelCel,
		fundoBarraXP = fundoBarraXP,
		fillBarraXP = fillBarraXP,
		txtXpProgresso = txtXpProgresso,
		uiListVIP = uiListVIP,
		frameRelogios = frameRelogios,
		uiListRel = uiListRel,
		TxtExpDiamante = TxtExpDiamante,
		TxtExpGold = TxtExpGold,
		TxtExpBronze = TxtExpBronze,
		TxtEscolha = TxtEscolha,
		containerTags = containerTags,
		uiListTags = uiListTags,
		BtnTagBronze = BtnTagBronze,
		BtnTagGold = BtnTagGold,
		BtnTagDiamante = BtnTagDiamante,
		botoesTags = botoesTags,
		BtnConfirmar = BtnConfirmar,
		cartaoSaldo = cartaoSaldo,
		logoBank = logoBank,
		labelSaldo = labelSaldo,
		txtSaldo = txtSaldo,
		frameAcoes = frameAcoes,
		layoutAcoes = layoutAcoes,
		cartaoCredito = cartaoCredito,
		lblFatura = lblFatura,
		txtFatura = txtFatura,
		lblLimite = lblLimite,
	}
end)()

local vipSelecionadoParaEnvio = ""

-- =========================================================
-- ⚙️ APP 4: CONFIGURAÇÕES
-- =========================================================
local scrollConfig = Instance.new("ScrollingFrame", appConfig)
scrollConfig.Name = "ConfigScroll"
scrollConfig.Size = UDim2.new(1, 0, 1, 0)
scrollConfig.Position = UDim2.new(0, 0, 0, 0)
scrollConfig.BackgroundTransparency = 1
scrollConfig.BorderSizePixel = 0
scrollConfig.ScrollBarThickness = 6
scrollConfig.ScrollBarImageColor3 = Color3.fromRGB(100, 105, 120)
scrollConfig.VerticalScrollBarInset = Enum.ScrollBarInset.Always
scrollConfig.ScrollingDirection = Enum.ScrollingDirection.Y
scrollConfig.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollConfig.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollConfig.ClipsDescendants = true

local padScrollConfig = Instance.new("UIPadding", scrollConfig)
padScrollConfig.PaddingTop = UDim.new(0, 4)
padScrollConfig.PaddingBottom = UDim.new(0, 20)
padScrollConfig.PaddingRight = UDim.new(0, 4)

local listConfig = Instance.new("UIListLayout", scrollConfig)
listConfig.FillDirection = Enum.FillDirection.Vertical
listConfig.VerticalAlignment = Enum.VerticalAlignment.Top
listConfig.HorizontalAlignment = Enum.HorizontalAlignment.Center
listConfig.Padding = UDim.new(0, 15)
listConfig.SortOrder = Enum.SortOrder.LayoutOrder

local tituloBrilho = Instance.new("TextLabel", scrollConfig)
tituloBrilho.LayoutOrder = 1
tituloBrilho.Size = UDim2.new(0.9, 0, 0, 20)
tituloBrilho.BackgroundTransparency = 1
tituloBrilho.Text = "☀️ Brilho da Tela"
tituloBrilho.TextColor3 = Color3.fromRGB(200, 200, 200)
tituloBrilho.Font = Enum.Font.GothamBold
tituloBrilho.TextSize = 14
tituloBrilho.TextXAlignment = Enum.TextXAlignment.Left
local containerSliderBrilho = Instance.new("Frame", scrollConfig)
containerSliderBrilho.LayoutOrder = 2
containerSliderBrilho.Size = UDim2.new(0.9, 0, 0, 30)
containerSliderBrilho.BackgroundTransparency = 1
local fundoSliderBrilho = Instance.new("Frame", containerSliderBrilho)
fundoSliderBrilho.Size = UDim2.new(1, 0, 0, 6)
fundoSliderBrilho.Position = UDim2.new(0, 0, 0.5, -3)
fundoSliderBrilho.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", fundoSliderBrilho).CornerRadius = UDim.new(1, 0)
local fillSliderBrilho = Instance.new("Frame", fundoSliderBrilho)
fillSliderBrilho.Size = UDim2.new(1, 0, 1, 0)
fillSliderBrilho.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
Instance.new("UICorner", fillSliderBrilho).CornerRadius = UDim.new(1, 0)
local knobSliderBrilho = Instance.new("TextButton", fundoSliderBrilho)
knobSliderBrilho.Size = UDim2.new(0, 18, 0, 18)
knobSliderBrilho.Position = UDim2.new(1, -9, 0.5, -9)
knobSliderBrilho.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
knobSliderBrilho.Text = ""
Instance.new("UICorner", knobSliderBrilho).CornerRadius = UDim.new(1, 0)

local topTamanho = Instance.new("Frame", scrollConfig)
topTamanho.LayoutOrder = 3
topTamanho.Size = UDim2.new(0.9, 0, 0, 20)
topTamanho.BackgroundTransparency = 1
local tituloTamanho = Instance.new("TextLabel", topTamanho)
tituloTamanho.Size = UDim2.new(0.7, 0, 1, 0)
tituloTamanho.BackgroundTransparency = 1
tituloTamanho.Text = "📏 Tamanho da Interface"
tituloTamanho.TextColor3 = Color3.fromRGB(200, 200, 200)
tituloTamanho.Font = Enum.Font.GothamBold
tituloTamanho.TextSize = 14
tituloTamanho.TextXAlignment = Enum.TextXAlignment.Left
local txtPorcentagemTamanho = Instance.new("TextLabel", topTamanho)
txtPorcentagemTamanho.Size = UDim2.new(0.3, 0, 1, 0)
txtPorcentagemTamanho.Position = UDim2.new(0.7, 0, 0, 0)
txtPorcentagemTamanho.BackgroundTransparency = 1
txtPorcentagemTamanho.Text = "100%"
txtPorcentagemTamanho.TextColor3 = Color3.fromRGB(0, 255, 255)
txtPorcentagemTamanho.Font = Enum.Font.GothamBlack
txtPorcentagemTamanho.TextSize = 14
txtPorcentagemTamanho.TextXAlignment = Enum.TextXAlignment.Right

local containerSliderTamanho = Instance.new("Frame", scrollConfig)
containerSliderTamanho.LayoutOrder = 4
containerSliderTamanho.Size = UDim2.new(0.9, 0, 0, 30)
containerSliderTamanho.BackgroundTransparency = 1
local fundoSliderTamanho = Instance.new("Frame", containerSliderTamanho)
fundoSliderTamanho.Size = UDim2.new(1, 0, 0, 6)
fundoSliderTamanho.Position = UDim2.new(0, 0, 0.5, -3)
fundoSliderTamanho.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", fundoSliderTamanho).CornerRadius = UDim.new(1, 0)
local fillSliderTamanho = Instance.new("Frame", fundoSliderTamanho)
fillSliderTamanho.Size = UDim2.new(1, 0, 1, 0)
fillSliderTamanho.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
Instance.new("UICorner", fillSliderTamanho).CornerRadius = UDim.new(1, 0)
local knobSliderTamanho = Instance.new("TextButton", fundoSliderTamanho)
knobSliderTamanho.Size = UDim2.new(0, 18, 0, 18)
knobSliderTamanho.Position = UDim2.new(1, -9, 0.5, -9)
knobSliderTamanho.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
knobSliderTamanho.Text = ""
Instance.new("UICorner", knobSliderTamanho).CornerRadius = UDim.new(1, 0)

local tituloWall = Instance.new("TextLabel", scrollConfig)
tituloWall.LayoutOrder = 5
tituloWall.Size = UDim2.new(0.9, 0, 0, 20)
tituloWall.BackgroundTransparency = 1
tituloWall.Text = "🖼️ Papéis de Parede"
tituloWall.TextColor3 = Color3.fromRGB(200, 200, 200)
tituloWall.Font = Enum.Font.GothamBold
tituloWall.TextSize = 14
tituloWall.TextXAlignment = Enum.TextXAlignment.Left
local frameWall = Instance.new("Frame", scrollConfig)
frameWall.LayoutOrder = 6
frameWall.Size = UDim2.new(0.9, 0, 0, 0)
frameWall.AutomaticSize = Enum.AutomaticSize.Y
frameWall.BackgroundTransparency = 1
local layoutWall = Instance.new("UIGridLayout", frameWall)
layoutWall.CellSize = UDim2.new(0, 80, 0, 120)
layoutWall.CellPadding = UDim2.new(0, 15, 0, 15)
layoutWall.HorizontalAlignment = Enum.HorizontalAlignment.Center
local botoesWallpaper = {}
local function criarBtnWallpaper(idImagem)
	local btn = Instance.new("ImageButton", frameWall)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	btn.Image = idImagem
	btn.ScaleType = Enum.ScaleType.Crop
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
	btn.Activated:Connect(function()
		wallpaper.Image = idImagem
		if evConfigCelular and evConfigCelular:IsA("RemoteEvent") then
			evConfigCelular:FireServer("Wallpaper", idImagem)
		end
	end)
	table.insert(botoesWallpaper, btn)
end

criarBtnWallpaper("rbxassetid://106619934580668")
criarBtnWallpaper("rbxassetid://101669118895000")
criarBtnWallpaper("rbxassetid://87982474295929")
criarBtnWallpaper("rbxassetid://113290069851449")
criarBtnWallpaper("rbxassetid://88789731507494")
criarBtnWallpaper("rbxassetid://107438101275816")

local tituloTema = Instance.new("TextLabel", scrollConfig)
tituloTema.LayoutOrder = 7
tituloTema.Size = UDim2.new(0.9, 0, 0, 20)
tituloTema.BackgroundTransparency = 1
tituloTema.Text = "🌓 Aparência"
tituloTema.TextColor3 = Color3.fromRGB(200, 200, 200)
tituloTema.Font = Enum.Font.GothamBold
tituloTema.TextSize = 14
tituloTema.TextXAlignment = Enum.TextXAlignment.Left

local rowTema = Instance.new("Frame", scrollConfig)
rowTema.LayoutOrder = 8
rowTema.Size = UDim2.new(0.9, 0, 0, 42)
rowTema.BackgroundTransparency = 1
local layRowTema = Instance.new("UIListLayout", rowTema)
layRowTema.FillDirection = Enum.FillDirection.Horizontal
layRowTema.HorizontalAlignment = Enum.HorizontalAlignment.Center
layRowTema.VerticalAlignment = Enum.VerticalAlignment.Center
layRowTema.Padding = UDim.new(0, 12)

local btnTemaEscuro = Instance.new("TextButton", rowTema)
btnTemaEscuro.Size = UDim2.new(0, 128, 0, 36)
btnTemaEscuro.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
btnTemaEscuro.Text = "🌙 Escuro"
btnTemaEscuro.TextColor3 = Color3.fromRGB(255, 255, 255)
btnTemaEscuro.Font = Enum.Font.GothamBold
btnTemaEscuro.TextSize = 12
Instance.new("UICorner", btnTemaEscuro).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", btnTemaEscuro).Thickness = 1.5

local btnTemaClaro = Instance.new("TextButton", rowTema)
btnTemaClaro.Size = UDim2.new(0, 128, 0, 36)
btnTemaClaro.BackgroundColor3 = Color3.fromRGB(55, 58, 68)
btnTemaClaro.Text = "☀️ Claro"
btnTemaClaro.TextColor3 = Color3.fromRGB(255, 255, 255)
btnTemaClaro.Font = Enum.Font.GothamBold
btnTemaClaro.TextSize = 12
Instance.new("UICorner", btnTemaClaro).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", btnTemaClaro).Thickness = 1.5

btnTemaEscuroRef = btnTemaEscuro
btnTemaClaroRef = btnTemaClaro

btnTemaEscuro.Activated:Connect(function()
	if aplicarTema then
		aplicarTema(false)
	end
	if evConfigCelular and evConfigCelular:IsA("RemoteEvent") then
		evConfigCelular:FireServer("Tema", "Escuro")
	end
end)
btnTemaClaro.Activated:Connect(function()
	if aplicarTema then
		aplicarTema(true)
	end
	if evConfigCelular and evConfigCelular:IsA("RemoteEvent") then
		evConfigCelular:FireServer("Tema", "Claro")
	end
end)

local isDraggingBrilho = false
knobSliderBrilho.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDraggingBrilho = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if isDraggingBrilho then
			isDraggingBrilho = false
			if evConfigCelular and evConfigCelular:IsA("RemoteEvent") then
				evConfigCelular:FireServer("Brilho", overlayBrilho.BackgroundTransparency)
			end
		end
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if isDraggingBrilho and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local pctBrilho = math.clamp((input.Position.X - fundoSliderBrilho.AbsolutePosition.X) / fundoSliderBrilho.AbsoluteSize.X, 0, 1)
		fillSliderBrilho.Size = UDim2.new(pctBrilho, 0, 1, 0)
		knobSliderBrilho.Position = UDim2.new(pctBrilho, -9, 0.5, -9)
		overlayBrilho.BackgroundTransparency = 0.4 + (pctBrilho * 0.6)
	end
end)

local arrastandoTamanho = false
local MIN_SCALE, MAX_SCALE = 0.5, 1.5
local function atualizarEscalaUIScale(pct)
	local escalaReal = MIN_SCALE + (pct * (MAX_SCALE - MIN_SCALE))
	uiScaleCelular.Scale = escalaReal
	txtPorcentagemTamanho.Text = math.floor(escalaReal * 100) .. "%"
end

knobSliderTamanho.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		arrastandoTamanho = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if arrastandoTamanho then
			arrastandoTamanho = false
			if evAlterarTamanho then
				evAlterarTamanho:FireServer(uiScaleCelular.Scale)
			end
		end
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if arrastandoTamanho and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local pct = math.clamp((input.Position.X - fundoSliderTamanho.AbsolutePosition.X) / fundoSliderTamanho.AbsoluteSize.X, 0, 1)
		fillSliderTamanho.Size = UDim2.new(pct, 0, 1, 0)
		knobSliderTamanho.Position = UDim2.new(pct, -9, 0.5, -9)
		atualizarEscalaUIScale(pct)
	end
end)

-- =========================================================
-- 🎵 APP 5: JBLEski MUSIC
-- =========================================================
appMusic.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Instance.new("UICorner", appMusic).CornerRadius = UDim.new(0, 35)

local layoutMusic = Instance.new("UIListLayout", appMusic)
layoutMusic.HorizontalAlignment = Enum.HorizontalAlignment.Center
layoutMusic.Padding = UDim.new(0, 8)
local espacoHeader = Instance.new("Frame", appMusic)
espacoHeader.Size = UDim2.new(1, 0, 0, 10)
espacoHeader.BackgroundTransparency = 1

local topMusic = Instance.new("Frame", appMusic)
topMusic.Size = UDim2.new(0.9, 0, 0, 30)
topMusic.BackgroundTransparency = 1
local btnBluetooth = Instance.new("ImageButton", topMusic)
btnBluetooth.Size = UDim2.new(0, 30, 0, 30)
btnBluetooth.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btnBluetooth.Image = "rbxassetid://131013491948143"
btnBluetooth.ScaleType = Enum.ScaleType.Fit
Instance.new("UICorner", btnBluetooth).CornerRadius = UDim.new(1, 0)
local statusBluetooth = Instance.new("TextLabel", topMusic)
statusBluetooth.Size = UDim2.new(1, -40, 1, 0)
statusBluetooth.Position = UDim2.new(0, 40, 0, 0)
statusBluetooth.BackgroundTransparency = 1
statusBluetooth.Text = "Reproduzindo no Celular"
statusBluetooth.TextColor3 = Color3.fromRGB(179, 179, 179)
statusBluetooth.Font = Enum.Font.GothamMedium
statusBluetooth.TextSize = 12
statusBluetooth.TextXAlignment = Enum.TextXAlignment.Left

local txtNomeMusica = Instance.new("TextLabel", appMusic)
txtNomeMusica.Size = UDim2.new(0.9, 0, 0, 20)
txtNomeMusica.BackgroundTransparency = 1
txtNomeMusica.Text = "🎵 Nenhuma música tocando..."
txtNomeMusica.TextColor3 = Color3.fromRGB(29, 185, 84)
txtNomeMusica.Font = Enum.Font.GothamBold
txtNomeMusica.TextSize = 14
txtNomeMusica.TextTruncate = Enum.TextTruncate.AtEnd

local inputMusicContainer = Instance.new("Frame", appMusic)
inputMusicContainer.Size = UDim2.new(0.9, 0, 0, 35)
inputMusicContainer.BackgroundTransparency = 1
local inputID = Instance.new("TextBox", inputMusicContainer)
inputID.Size = UDim2.new(0.8, -5, 1, 0)
inputID.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
inputID.TextColor3 = Color3.fromRGB(255, 255, 255)
inputID.Font = Enum.Font.Gotham
inputID.TextSize = 12
inputID.PlaceholderText = "Cole o ID da música..."
inputID.Text = ""
inputID.ClearTextOnFocus = false
Instance.new("UICorner", inputID).CornerRadius = UDim.new(0, 8)
local btnAddPlaylist = Instance.new("TextButton", inputMusicContainer)
btnAddPlaylist.Size = UDim2.new(0.2, 0, 1, 0)
btnAddPlaylist.Position = UDim2.new(0.8, 5, 0, 0)
btnAddPlaylist.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btnAddPlaylist.Text = "💚"
btnAddPlaylist.Font = Enum.Font.Gotham
btnAddPlaylist.TextSize = 16
Instance.new("UICorner", btnAddPlaylist).CornerRadius = UDim.new(0, 8)

local frameBotoesMusic = Instance.new("Frame", appMusic)
frameBotoesMusic.Size = UDim2.new(1, 0, 0, 45)
frameBotoesMusic.BackgroundTransparency = 1
local layoutBotoesMusic = Instance.new("UIListLayout", frameBotoesMusic)
layoutBotoesMusic.FillDirection = Enum.FillDirection.Horizontal
layoutBotoesMusic.HorizontalAlignment = Enum.HorizontalAlignment.Center
layoutBotoesMusic.VerticalAlignment = Enum.VerticalAlignment.Center
layoutBotoesMusic.Padding = UDim.new(0, 12)
local function criarBotaoMusic(texto, cor)
	local btn = Instance.new("TextButton", frameBotoesMusic)
	btn.Size = UDim2.new(0, 35, 0, 35)
	btn.BackgroundColor3 = cor
	btn.Text = texto
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 14
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
	return btn
end
local btnVoltarM = criarBotaoMusic("⏮", Color3.fromRGB(40, 40, 40))
local btnPlayM = criarBotaoMusic("▶", Color3.fromRGB(29, 185, 84))
local btnPauseM = criarBotaoMusic("⏸", Color3.fromRGB(40, 40, 40))
local btnStopM = criarBotaoMusic("⏹", Color3.fromRGB(180, 40, 40))
local btnPassarM = criarBotaoMusic("⏭", Color3.fromRGB(40, 40, 40))

local frameTempoM = Instance.new("Frame", appMusic)
frameTempoM.Size = UDim2.new(0.9, 0, 0, 20)
frameTempoM.BackgroundTransparency = 1
local txtTempoAtual = Instance.new("TextLabel", frameTempoM)
txtTempoAtual.Size = UDim2.new(0.2, 0, 1, -6)
txtTempoAtual.BackgroundTransparency = 1
txtTempoAtual.Text = "0:00"
txtTempoAtual.TextColor3 = Color3.fromRGB(179, 179, 179)
txtTempoAtual.Font = Enum.Font.Gotham
txtTempoAtual.TextSize = 10
txtTempoAtual.TextXAlignment = Enum.TextXAlignment.Left
local txtTempoTotal = Instance.new("TextLabel", frameTempoM)
txtTempoTotal.Size = UDim2.new(0.2, 0, 1, -6)
txtTempoTotal.Position = UDim2.new(0.8, 0, 0, 0)
txtTempoTotal.BackgroundTransparency = 1
txtTempoTotal.Text = "0:00"
txtTempoTotal.TextColor3 = Color3.fromRGB(179, 179, 179)
txtTempoTotal.Font = Enum.Font.Gotham
txtTempoTotal.TextSize = 10
txtTempoTotal.TextXAlignment = Enum.TextXAlignment.Right
local bgTempoSlider = Instance.new("Frame", frameTempoM)
bgTempoSlider.Size = UDim2.new(1, 0, 0, 4)
bgTempoSlider.Position = UDim2.new(0, 0, 1, -4)
bgTempoSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Instance.new("UICorner", bgTempoSlider).CornerRadius = UDim.new(1, 0)
local fillTempoSlider = Instance.new("Frame", bgTempoSlider)
fillTempoSlider.Size = UDim2.new(0, 0, 1, 0)
fillTempoSlider.ZIndex = 1
fillTempoSlider.BackgroundColor3 = Color3.fromRGB(29, 185, 84)
Instance.new("UICorner", fillTempoSlider).CornerRadius = UDim.new(1, 0)
-- Knob na trilha (não no fill): escala UDim2 é em relação ao comprimento total da barra.
local knobTempoSlider = Instance.new("TextButton", bgTempoSlider)
knobTempoSlider.Size = UDim2.new(0, 10, 0, 10)
knobTempoSlider.Position = UDim2.new(0, -5, 0.5, -5)
knobTempoSlider.ZIndex = 2
knobTempoSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
knobTempoSlider.Text = ""
Instance.new("UICorner", knobTempoSlider).CornerRadius = UDim.new(1, 0)

local bgVolSlider = Instance.new("Frame", appMusic)
bgVolSlider.Size = UDim2.new(0.8, 0, 0, 4)
bgVolSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Instance.new("UICorner", bgVolSlider).CornerRadius = UDim.new(1, 0)
local fillVolSlider = Instance.new("Frame", bgVolSlider)
fillVolSlider.Size = UDim2.new(0.5, 0, 1, 0)
fillVolSlider.ZIndex = 1
fillVolSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", fillVolSlider).CornerRadius = UDim.new(1, 0)
local knobVolSlider = Instance.new("TextButton", bgVolSlider)
knobVolSlider.Size = UDim2.new(0, 10, 0, 10)
knobVolSlider.Position = UDim2.new(0.5, -5, 0.5, -5)
knobVolSlider.ZIndex = 2
knobVolSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
knobVolSlider.Text = ""
Instance.new("UICorner", knobVolSlider).CornerRadius = UDim.new(1, 0)

local musicControlesCinza =
	{ btnBluetooth, inputID, btnAddPlaylist, btnVoltarM, btnPauseM, btnPassarM, bgTempoSlider, bgVolSlider }

local tituloPlaylist = Instance.new("TextLabel", appMusic)
tituloPlaylist.Size = UDim2.new(0.9, 0, 0, 20)
tituloPlaylist.BackgroundTransparency = 1
tituloPlaylist.Text = "Sua Playlist"
tituloPlaylist.TextColor3 = Color3.fromRGB(255, 255, 255)
tituloPlaylist.Font = Enum.Font.GothamBold
tituloPlaylist.TextSize = 14
tituloPlaylist.TextXAlignment = Enum.TextXAlignment.Left
local listaMusicas = Instance.new("ScrollingFrame", appMusic)
listaMusicas.Size = UDim2.new(0.9, 0, 1, -260)
listaMusicas.BackgroundTransparency = 1
listaMusicas.ScrollBarThickness = 3
listaMusicas.CanvasSize = UDim2.new(0, 0, 0, 0)
local listaLayout = Instance.new("UIListLayout", listaMusicas)
listaLayout.SortOrder = Enum.SortOrder.LayoutOrder
listaLayout.Padding = UDim.new(0, 5)

-- =========================================================
-- 🚘 APP 6: CAR MEET
-- =========================================================
local tituloCarMeet = Instance.new("TextLabel", appCarMeet)
tituloCarMeet.Size = UDim2.new(1, 0, 0, 30)
tituloCarMeet.Position = UDim2.new(0, 0, 0, 20)
tituloCarMeet.BackgroundTransparency = 1
tituloCarMeet.Text = "Controle de Exposição"
tituloCarMeet.TextColor3 = Color3.fromRGB(255, 255, 255)
tituloCarMeet.Font = Enum.Font.GothamBlack
tituloCarMeet.TextSize = 18
local emojiCarMeet = Instance.new("TextLabel", appCarMeet)
emojiCarMeet.Size = UDim2.new(1, 0, 0, 80)
emojiCarMeet.Position = UDim2.new(0, 0, 0, 60)
emojiCarMeet.BackgroundTransparency = 1
emojiCarMeet.Text = "🚘"
emojiCarMeet.TextSize = 70
local txtStatusMeet = Instance.new("TextLabel", appCarMeet)
txtStatusMeet.Size = UDim2.new(1, 0, 0, 30)
txtStatusMeet.Position = UDim2.new(0, 0, 0, 150)
txtStatusMeet.BackgroundTransparency = 1
txtStatusMeet.Text = "Status: Oculto"
txtStatusMeet.TextColor3 = Color3.fromRGB(200, 200, 200)
txtStatusMeet.Font = Enum.Font.GothamMedium
txtStatusMeet.TextSize = 14

local btnToggleMeet = Instance.new("TextButton", appCarMeet)
btnToggleMeet.Size = UDim2.new(0.8, 0, 0, 50)
btnToggleMeet.Position = UDim2.new(0.1, 0, 0, 200)
btnToggleMeet.BackgroundColor3 = Color3.fromRGB(0, 255, 127)
btnToggleMeet.Text = "ATIVAR VOTAÇÃO"
btnToggleMeet.TextColor3 = Color3.fromRGB(15, 15, 20)
btnToggleMeet.Font = Enum.Font.GothamBlack
btnToggleMeet.TextSize = 16
Instance.new("UICorner", btnToggleMeet).CornerRadius = UDim.new(0, 12)

if not evToggleCarMeet then
	btnToggleMeet.AutoButtonColor = false
	btnToggleMeet.Interactable = false
	btnToggleMeet.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	btnToggleMeet.Text = "REMOTO INDISPONÍVEL"
	txtStatusMeet.Text = "Servidor sem ToggleCarMeetEvent"
	txtStatusMeet.TextColor3 = Color3.fromRGB(255, 120, 100)
end

local exposicaoAtivaCelular = false
local debounceToggleMeet = false
btnToggleMeet.Activated:Connect(function()
	if not evToggleCarMeet then
		return
	end
	if debounceToggleMeet then
		return
	end
	debounceToggleMeet = true
	task.delay(0.35, function()
		debounceToggleMeet = false
	end)

	exposicaoAtivaCelular = not exposicaoAtivaCelular
	local cp = paletaAtual()
	if exposicaoAtivaCelular then
		btnToggleMeet.BackgroundColor3 = cp.meetBtnVerm
		btnToggleMeet.Text = "DESATIVAR VOTAÇÃO"
		txtStatusMeet.Text = "Status: 🔥 Público"
		txtStatusMeet.TextColor3 = cp.meetTxtPublico
	else
		btnToggleMeet.BackgroundColor3 = cp.meetBtnVerde
		btnToggleMeet.Text = "ATIVAR VOTAÇÃO"
		txtStatusMeet.Text = "Status: Oculto"
		txtStatusMeet.TextColor3 = cp.carMeetSub
	end
	btnToggleMeet.TextColor3 = temaClaroAtivo and Color3.fromRGB(22, 24, 32) or Color3.fromRGB(15, 15, 20)
	evToggleCarMeet:FireServer(exposicaoAtivaCelular)
end)

-- =========================================================
-- 🚛 APP 7: GUINCHO
-- =========================================================
local tituloGuincho = Instance.new("TextLabel", appGuincho)
tituloGuincho.Size = UDim2.new(1, -20, 0, 28)
tituloGuincho.Position = UDim2.new(0, 10, 0, 18)
tituloGuincho.BackgroundTransparency = 1
tituloGuincho.Text = "Assistência na estrada"
tituloGuincho.TextColor3 = Color3.fromRGB(255, 255, 255)
tituloGuincho.Font = Enum.Font.GothamBlack
tituloGuincho.TextSize = 17
tituloGuincho.TextXAlignment = Enum.TextXAlignment.Center

local emojiGuincho = Instance.new("TextLabel", appGuincho)
emojiGuincho.Size = UDim2.new(1, 0, 0, 72)
emojiGuincho.Position = UDim2.new(0, 0, 0, 52)
emojiGuincho.BackgroundTransparency = 1
emojiGuincho.Text = "🚛"
emojiGuincho.TextSize = 56

local txtGuinchoInfo = Instance.new("TextLabel", appGuincho)
txtGuinchoInfo.Size = UDim2.new(0.92, 0, 0, 72)
txtGuinchoInfo.Position = UDim2.new(0.04, 0, 0, 128)
txtGuinchoInfo.BackgroundTransparency = 1
txtGuinchoInfo.Text = "Respawn completo do teu carro que está na rua, à tua frente — corrige preso/rodas/suspensão. Tens de ter o veículo já spawnado."
txtGuinchoInfo.TextColor3 = Color3.fromRGB(190, 190, 200)
txtGuinchoInfo.Font = Enum.Font.GothamMedium
txtGuinchoInfo.TextSize = 12
txtGuinchoInfo.TextWrapped = true
txtGuinchoInfo.TextYAlignment = Enum.TextYAlignment.Top

local txtGuinchoStatus = Instance.new("TextLabel", appGuincho)
txtGuinchoStatus.Size = UDim2.new(1, -20, 0, 22)
txtGuinchoStatus.Position = UDim2.new(0, 10, 0, 210)
txtGuinchoStatus.BackgroundTransparency = 1
txtGuinchoStatus.Text = ""
txtGuinchoStatus.TextColor3 = Color3.fromRGB(120, 220, 160)
txtGuinchoStatus.Font = Enum.Font.GothamSemibold
txtGuinchoStatus.TextSize = 12
txtGuinchoStatus.TextXAlignment = Enum.TextXAlignment.Center

local btnChamarGuincho = Instance.new("TextButton", appGuincho)
btnChamarGuincho.Size = UDim2.new(0.86, 0, 0, 50)
btnChamarGuincho.Position = UDim2.new(0.07, 0, 0, 248)
btnChamarGuincho.BackgroundColor3 = Color3.fromRGB(255, 170, 60)
btnChamarGuincho.Text = "CHAMAR GUINCHO"
btnChamarGuincho.TextColor3 = Color3.fromRGB(25, 20, 10)
btnChamarGuincho.Font = Enum.Font.GothamBlack
btnChamarGuincho.TextSize = 15
Instance.new("UICorner", btnChamarGuincho).CornerRadius = UDim.new(0, 12)

if not evGuincho then
	btnChamarGuincho.AutoButtonColor = false
	btnChamarGuincho.Interactable = false
	btnChamarGuincho.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	btnChamarGuincho.Text = "SERVIÇO INDISPONÍVEL"
	txtGuinchoInfo.Text = "O servidor não tem GuinchoAssistenciaEvent. Adiciona o script SistemaGuincho_REVISADO."
	txtGuinchoInfo.TextColor3 = Color3.fromRGB(255, 140, 120)
end

-- =========================================================
-- APP: CÂMARA LIVRE + GALERIA (IIFE → não conta ~80 locais no chunk principal; limite Luau 200)
-- ReplicatedStorage: ModuleScript CH_FotoCameraModulo (= CH_FotoCameraModulo_REVISADO.lua)
-- =========================================================
local AppFotoGaleria = (function()
	local moduloFotoRef = nil
	local fotosSessao = {}
	local ultimaCapturaId = nil
	local idFotoPendente = nil
	-- forward: dispararCaptura vem antes no ficheiro; sem isto o nome resolve para global (nil)
	local reconstruirGaleria
	local fecharPreviewFoto
	local atualizarBotoesCam

	local function obterModuloFoto()
		if moduloFotoRef then
			return moduloFotoRef
		end
		local m = ReplicatedStorage:FindFirstChild("CH_FotoCameraModulo")
		if m and m:IsA("ModuleScript") then
			local ok, r = pcall(function()
				return require(m)
			end)
			if ok and type(r) == "table" then
				moduloFotoRef = r
			end
		end
		return moduloFotoRef
	end

	local tweenFoto = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

	local function fecharCelularParaFoto()
		if celularAberto then
			celularAberto = false
			TweenService:Create(phoneFrame, tweenFoto, { Position = posicaoFechado }):Play()
		end
		TweenService:Create(telaAppAberto, tweenFoto, { Position = UDim2.new(1, 0, 0, 0) }):Play()
	end

	local tituloCam = Instance.new("TextLabel", appCamera)
tituloCam.Size = UDim2.new(1, -20, 0, 24)
tituloCam.Position = UDim2.new(0, 10, 0, 14)
tituloCam.BackgroundTransparency = 1
tituloCam.Font = Enum.Font.GothamBlack
tituloCam.TextSize = 17
tituloCam.TextColor3 = Color3.fromRGB(255, 255, 255)
tituloCam.TextXAlignment = Enum.TextXAlignment.Center
tituloCam.Text = "Câmara livre"

local txtCamInfo = Instance.new("TextLabel", appCamera)
txtCamInfo.Size = UDim2.new(0.92, 0, 0, 0)
txtCamInfo.Position = UDim2.new(0.04, 0, 0, 44)
txtCamInfo.BackgroundTransparency = 1
txtCamInfo.Font = Enum.Font.GothamMedium
txtCamInfo.TextSize = 11
txtCamInfo.TextColor3 = Color3.fromRGB(190, 195, 210)
txtCamInfo.TextWrapped = true
txtCamInfo.TextYAlignment = Enum.TextYAlignment.Top
txtCamInfo.TextXAlignment = Enum.TextXAlignment.Center
txtCamInfo.Text = ""
txtCamInfo.Visible = false

local txtCamStatus = Instance.new("TextLabel", appCamera)
txtCamStatus.Size = UDim2.new(1, -20, 0, 22)
txtCamStatus.Position = UDim2.new(0, 10, 0, 44)
txtCamStatus.BackgroundTransparency = 1
txtCamStatus.Font = Enum.Font.GothamSemibold
txtCamStatus.TextSize = 12
txtCamStatus.TextColor3 = Color3.fromRGB(120, 220, 160)
txtCamStatus.TextXAlignment = Enum.TextXAlignment.Center
txtCamStatus.Text = ""

local btnCamEntrar = Instance.new("TextButton", appCamera)
btnCamEntrar.Size = UDim2.new(0.88, 0, 0, 44)
btnCamEntrar.Position = UDim2.new(0.06, 0, 0, 76)
btnCamEntrar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
btnCamEntrar.Text = "Abrir Camera"
btnCamEntrar.TextColor3 = Color3.fromRGB(20, 20, 25)
btnCamEntrar.Font = Enum.Font.GothamBlack
btnCamEntrar.TextSize = 13
Instance.new("UICorner", btnCamEntrar).CornerRadius = UDim.new(0, 12)

local btnCamSair = Instance.new("TextButton", appCamera)
btnCamSair.Size = UDim2.new(0.88, 0, 0, 40)
btnCamSair.Position = UDim2.new(0.06, 0, 0, 130)
btnCamSair.BackgroundColor3 = Color3.fromRGB(55, 58, 68)
btnCamSair.Text = "SAIR DO MODO CÂMARA"
btnCamSair.TextColor3 = Color3.fromRGB(255, 255, 255)
btnCamSair.Font = Enum.Font.GothamBold
btnCamSair.TextSize = 12
Instance.new("UICorner", btnCamSair).CornerRadius = UDim.new(0, 12)

local btnCamCapturar = Instance.new("TextButton", appCamera)
btnCamCapturar.Size = UDim2.new(0.88, 0, 0, 40)
btnCamCapturar.Position = UDim2.new(0.06, 0, 0, 180)
btnCamCapturar.BackgroundColor3 = Color3.fromRGB(90, 85, 120)
btnCamCapturar.Text = "CAPTURAR ECRÃ"
btnCamCapturar.TextColor3 = Color3.fromRGB(255, 255, 255)
btnCamCapturar.Font = Enum.Font.GothamBold
btnCamCapturar.TextSize = 12
Instance.new("UICorner", btnCamCapturar).CornerRadius = UDim.new(0, 12)

local btnCamGuardar = Instance.new("TextButton", appCamera)
btnCamGuardar.Size = UDim2.new(0.88, 0, 0, 40)
btnCamGuardar.Position = UDim2.new(0.06, 0, 0, 230)
btnCamGuardar.BackgroundColor3 = Color3.fromRGB(52, 140, 90)
btnCamGuardar.Text = "GUARDAR ÚLTIMA NA GALERIA ROBLOX"
btnCamGuardar.TextColor3 = Color3.fromRGB(255, 255, 255)
btnCamGuardar.Font = Enum.Font.GothamBold
btnCamGuardar.TextSize = 11
Instance.new("UICorner", btnCamGuardar).CornerRadius = UDim.new(0, 12)

	local painelPosCaptura = Instance.new("Frame", appCamera)
	painelPosCaptura.Name = "PainelPosCaptura"
	painelPosCaptura.Size = UDim2.new(1, 0, 1, -72)
	painelPosCaptura.Position = UDim2.new(0, 0, 0, 72)
	painelPosCaptura.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	painelPosCaptura.BackgroundTransparency = 0.08
	painelPosCaptura.Visible = false
	painelPosCaptura.ZIndex = 25
	Instance.new("UICorner", painelPosCaptura).CornerRadius = UDim.new(0, 14)

	local lblPend = Instance.new("TextLabel", painelPosCaptura)
	lblPend.Size = UDim2.new(1, -20, 0, 22)
	lblPend.Position = UDim2.new(0, 10, 0, 10)
	lblPend.BackgroundTransparency = 1
	lblPend.Font = Enum.Font.GothamBlack
	lblPend.TextSize = 14
	lblPend.TextColor3 = Color3.fromRGB(255, 255, 255)
	lblPend.TextXAlignment = Enum.TextXAlignment.Center
	lblPend.Text = "Pré-visualização"
	lblPend.ZIndex = 26

	local imgPendente = Instance.new("ImageLabel", painelPosCaptura)
	imgPendente.Name = "ImgPendente"
	imgPendente.AnchorPoint = Vector2.new(0.5, 0)
	imgPendente.Position = UDim2.new(0.5, 0, 0, 38)
	imgPendente.Size = UDim2.new(0.88, 0, 0, 200)
	imgPendente.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
	imgPendente.BorderSizePixel = 0
	imgPendente.ScaleType = Enum.ScaleType.Fit
	imgPendente.ZIndex = 26
	Instance.new("UICorner", imgPendente).CornerRadius = UDim.new(0, 10)

	local txtPendLegenda = Instance.new("TextLabel", painelPosCaptura)
	txtPendLegenda.Size = UDim2.new(0.9, 0, 0, 36)
	txtPendLegenda.Position = UDim2.new(0.05, 0, 0, 248)
	txtPendLegenda.BackgroundTransparency = 1
	txtPendLegenda.Font = Enum.Font.GothamMedium
	txtPendLegenda.TextSize = 10
	txtPendLegenda.TextColor3 = Color3.fromRGB(175, 180, 195)
	txtPendLegenda.TextWrapped = true
	txtPendLegenda.TextXAlignment = Enum.TextXAlignment.Center
	txtPendLegenda.Text = "Confirmar: entra na galeria desta sessão. Excluir: apaga e volta ao modo câmara (telemóvel fecha)."
	txtPendLegenda.ZIndex = 26

	local btnConfFoto = Instance.new("TextButton", painelPosCaptura)
	btnConfFoto.Size = UDim2.new(0.88, 0, 0, 42)
	btnConfFoto.Position = UDim2.new(0.06, 0, 0, 292)
	btnConfFoto.BackgroundColor3 = Color3.fromRGB(52, 140, 90)
	btnConfFoto.Text = "CONFIRMAR NA GALERIA"
	btnConfFoto.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnConfFoto.Font = Enum.Font.GothamBlack
	btnConfFoto.TextSize = 12
	btnConfFoto.ZIndex = 26
	Instance.new("UICorner", btnConfFoto).CornerRadius = UDim.new(0, 12)

	local btnExcFoto = Instance.new("TextButton", painelPosCaptura)
	btnExcFoto.Size = UDim2.new(0.88, 0, 0, 40)
	btnExcFoto.Position = UDim2.new(0.06, 0, 0, 342)
	btnExcFoto.BackgroundColor3 = Color3.fromRGB(90, 55, 60)
	btnExcFoto.Text = "EXCLUIR E VOLTAR À CÂMARA"
	btnExcFoto.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnExcFoto.Font = Enum.Font.GothamBold
	btnExcFoto.TextSize = 11
	btnExcFoto.ZIndex = 26
	Instance.new("UICorner", btnExcFoto).CornerRadius = UDim.new(0, 12)

local function atualizarStatusCam(msg, cor)
	txtCamStatus.Text = msg or ""
	txtCamStatus.TextColor3 = cor or Color3.fromRGB(120, 220, 160)
end

	local function focarTelefoneNaAppCamara()
		if fecharPreviewFoto then
			fecharPreviewFoto()
		end
		tituloApp.Text = "Câmara"
		tituloApp.TextColor3 = corTituloAppPadrao
		appPerfil.Visible = false
		appVIP.Visible = false
		appBanco.Visible = false
		appConfig.Visible = false
		appMusic.Visible = false
		appCarMeet.Visible = false
		appGuincho.Visible = false
		appGaleria.Visible = false
		LocAmigosApp.Frame.Visible = false
		local mapFr = appContainer:FindFirstChild("AppMapaWaypoints")
		if mapFr and mapFr:IsA("GuiObject") then
			mapFr.Visible = false
		end
		appCamera.Visible = true
		celularAberto = true
		TweenService:Create(phoneFrame, tweenFoto, { Position = posicaoAberto }):Play()
		TweenService:Create(telaAppAberto, tweenFoto, { Position = UDim2.new(0, 0, 0, 0) }):Play()
	end

	local function executarConfirmarFotoPendente()
		if not idFotoPendente then
			return
		end
		local id = idFotoPendente
		idFotoPendente = nil
		painelPosCaptura.Visible = false
		tituloCam.Visible = true
		ultimaCapturaId = id
		table.insert(fotosSessao, { id = id, t = os.time() })
		if reconstruirGaleria then
			reconstruirGaleria()
		end
		atualizarBotoesCam()
		atualizarStatusCam("Foto na galeria da sessão. Podes usar «Guardar na Galeria Roblox».", Color3.fromRGB(120, 220, 160))
	end

	local function executarExcluirFotoPendente()
		if not idFotoPendente then
			return
		end
		idFotoPendente = nil
		painelPosCaptura.Visible = false
		tituloCam.Visible = true
		local mod = obterModuloFoto()
		fecharCelularParaFoto()
		task.defer(function()
			if mod and mod.Enter then
				mod.Enter()
			end
			atualizarBotoesCam()
			atualizarStatusCam("Modo câmara ativo. Usa a moldura para enquadrar; Backspace sai (PC).", Color3.fromRGB(120, 220, 160))
		end)
	end

	btnConfFoto.Activated:Connect(executarConfirmarFotoPendente)
	btnExcFoto.Activated:Connect(executarExcluirFotoPendente)

	local function tratarVoltarComFotoPendenteCamera()
		if not idFotoPendente then
			return false
		end
		executarExcluirFotoPendente()
		return true
	end

atualizarBotoesCam = function()
	if idFotoPendente then
		btnCamEntrar.Visible = false
		btnCamSair.Visible = false
		btnCamCapturar.Visible = false
		btnCamGuardar.Visible = false
		tituloCam.Visible = false
		painelPosCaptura.Visible = true
		return
	end
	painelPosCaptura.Visible = false
	tituloCam.Visible = true
	local mod = obterModuloFoto()
	local on = mod and mod.IsActive and mod.IsActive() or false
	btnCamEntrar.Visible = not on
	btnCamSair.Visible = on
	btnCamCapturar.Visible = on
	btnCamGuardar.Visible = on and ultimaCapturaId ~= nil
end

task.defer(function()
	local ms = ReplicatedStorage:FindFirstChild("CH_FotoCameraModulo")
	if not ms or not ms:IsA("ModuleScript") then
		return
	end
	local ok, mod = pcall(require, ms)
	if ok and type(mod) == "table" and mod.SetExitCallback then
		mod.SetExitCallback(function()
			atualizarStatusCam("Modo câmara desligado.", Color3.fromRGB(160, 200, 255))
			atualizarBotoesCam()
		end)
	end
end)

local proximaCapturaLivreEm = 0

local function salvarEstadoHudParaCaptura()
	local estado = { sgs = {}, core = {} }
	for _, ch in ipairs(playerGui:GetChildren()) do
		if ch:IsA("ScreenGui") then
			table.insert(estado.sgs, { ch, ch.Enabled })
			ch.Enabled = false
		end
	end
	for _, tipo in ipairs(Enum.CoreGuiType:GetEnumItems()) do
		local ok, en = pcall(function()
			return StarterGui:GetCoreGuiEnabled(tipo)
		end)
		if ok then
			table.insert(estado.core, { tipo, en })
			pcall(function()
				StarterGui:SetCoreGuiEnabled(tipo, false)
			end)
		end
	end
	return estado
end

local function restaurarEstadoHudCaptura(estado)
	if not estado then
		return
	end
	for _, row in ipairs(estado.sgs) do
		local sg, was = row[1], row[2]
		if sg and sg.Parent then
			sg.Enabled = was
		end
	end
	for _, row in ipairs(estado.core) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(row[1], row[2])
		end)
	end
end

local function dispararCaptura()
	if idFotoPendente then
		return
	end
	local mod = obterModuloFoto()
	if not mod or not mod.IsActive or not mod.IsActive() then
		return
	end
	if tick() < proximaCapturaLivreEm then
		return
	end
	proximaCapturaLivreEm = tick() + 1.1
	atualizarStatusCam("A capturar…", Color3.fromRGB(200, 200, 120))
	local estadoHud = salvarEstadoHudParaCaptura()
	local restaurado = false
	local function garantirRestaurarHud()
		if restaurado then
			return
		end
		restaurado = true
		restaurarEstadoHudCaptura(estadoHud)
	end
	task.delay(5, garantirRestaurarHud)
	for _ = 1, 3 do
		RunService.RenderStepped:Wait()
	end
	local ok = pcall(function()
		CaptureService:CaptureScreenshot(function(contentId)
			garantirRestaurarHud()
			if type(contentId) == "string" and contentId ~= "" then
				idFotoPendente = contentId
				imgPendente.Image = contentId
				local mod2 = obterModuloFoto()
				if mod2 and mod2.Exit then
					mod2.Exit()
				end
				focarTelefoneNaAppCamara()
				atualizarBotoesCam()
				atualizarStatusCam("Confirma na galeria da sessão ou exclui e volta à câmara.", Color3.fromRGB(200, 210, 255))
			else
				atualizarStatusCam("Captura sem ID (API indisponível ou bloqueada).", Color3.fromRGB(255, 140, 120))
				atualizarBotoesCam()
			end
		end)
	end)
	if not ok then
		garantirRestaurarHud()
		atualizarStatusCam("CaptureService indisponível nesta sessão/plataforma.", Color3.fromRGB(255, 140, 120))
		atualizarBotoesCam()
	end
end

local function contarGuiJogadorNoPixel(px, py)
	local inset = GuiService:GetGuiInset()
	local x = px - inset.X
	local y = py - inset.Y
	local ok, list = pcall(function()
		return playerGui:GetGuiObjectsAtPosition(x, y)
	end)
	if not ok or type(list) ~= "table" then
		return 0
	end
	local n = 0
	for _, g in ipairs(list) do
		local sg = g:FindFirstAncestorWhichIsA("ScreenGui")
		-- Moldura do modo câmara (CH_FotoCameraModulo): não deve bloquear clique para capturar
		if sg and sg.Name == "CH_ViewfinderMoldura" then
			continue
		end
		n += 1
	end
	return n
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local mod = obterModuloFoto()
	if not mod or not mod.IsActive or not mod.IsActive() then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local px, py
	if input.UserInputType == Enum.UserInputType.Touch then
		px = input.Position.X
		py = input.Position.Y
	else
		local m = UserInputService:GetMouseLocation()
		px, py = m.X, m.Y
	end
	if contarGuiJogadorNoPixel(px, py) > 0 then
		return
	end
	dispararCaptura()
end)

btnCamEntrar.Activated:Connect(function()
	local mod = obterModuloFoto()
	if not mod then
		atualizarStatusCam("Falta o ModuleScript CH_FotoCameraModulo no ReplicatedStorage.", Color3.fromRGB(255, 140, 120))
		return
	end
	fecharCelularParaFoto()
	task.defer(function()
		local ok = mod.Enter and mod.Enter()
		if ok then
			atualizarStatusCam("Modo câmara ativo. Usa a moldura para enquadrar; ao tirar foto o ecrã fica limpo. Backspace sai (PC).", Color3.fromRGB(120, 220, 160))
		else
			atualizarStatusCam("Não foi possível (personagem?).", Color3.fromRGB(255, 140, 120))
		end
		atualizarBotoesCam()
	end)
end)

btnCamSair.Activated:Connect(function()
	local mod = obterModuloFoto()
	if mod and mod.Exit then
		mod.Exit()
	end
end)

btnCamCapturar.Activated:Connect(dispararCaptura)

btnCamGuardar.Activated:Connect(function()
	if not ultimaCapturaId then
		atualizarStatusCam("Captura primeiro.", Color3.fromRGB(255, 200, 120))
		return
	end
	pcall(function()
		CaptureService:PromptSaveCapturesToGallery({ ultimaCapturaId }, function(_map)
			atualizarStatusCam("Pedido de guardar enviado (resposta no menu Roblox).", Color3.fromRGB(160, 200, 255))
		end)
	end)
end)

--- Galeria (miniaturas desta sessão)
local tituloGal = Instance.new("TextLabel", appGaleria)
tituloGal.Size = UDim2.new(1, -20, 0, 24)
tituloGal.Position = UDim2.new(0, 10, 0, 14)
tituloGal.BackgroundTransparency = 1
tituloGal.Font = Enum.Font.GothamBlack
tituloGal.TextSize = 17
tituloGal.TextColor3 = Color3.fromRGB(255, 255, 255)
tituloGal.TextXAlignment = Enum.TextXAlignment.Center
tituloGal.Text = "Galeria (sessão)"

local txtGalInfo = Instance.new("TextLabel", appGaleria)
txtGalInfo.Size = UDim2.new(0.92, 0, 0, 44)
txtGalInfo.Position = UDim2.new(0.04, 0, 0, 40)
txtGalInfo.BackgroundTransparency = 1
txtGalInfo.Font = Enum.Font.GothamMedium
txtGalInfo.TextSize = 10
txtGalInfo.TextColor3 = Color3.fromRGB(170, 175, 190)
txtGalInfo.TextWrapped = true
txtGalInfo.TextYAlignment = Enum.TextYAlignment.Top
txtGalInfo.TextXAlignment = Enum.TextXAlignment.Center
txtGalInfo.Text =
	"Toca na miniatura para ver maior; × remove da sessão. A galeria oficial Roblox fica no menu Esc → Capturas (conforme a plataforma)."

local scrollGal = Instance.new("ScrollingFrame", appGaleria)
scrollGal.Name = "ScrollGaleria"
scrollGal.Size = UDim2.new(1, -16, 1, -110)
scrollGal.Position = UDim2.new(0, 8, 0, 88)
scrollGal.BackgroundTransparency = 1
scrollGal.BorderSizePixel = 0
scrollGal.ScrollBarThickness = 5
scrollGal.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollGal.CanvasSize = UDim2.new(0, 0, 0, 0)

local gridGal = Instance.new("UIGridLayout", scrollGal)
gridGal.CellSize = UDim2.new(0, 76, 0, 76)
gridGal.CellPadding = UDim2.new(0, 8, 0, 8)
gridGal.SortOrder = Enum.SortOrder.LayoutOrder

local overlayPreview = Instance.new("Frame", appGaleria)
overlayPreview.Name = "OverlayPreviewFoto"
overlayPreview.Size = UDim2.new(1, 0, 1, 0)
overlayPreview.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
overlayPreview.BackgroundTransparency = 0.15
overlayPreview.Visible = false
overlayPreview.ZIndex = 40
overlayPreview.Active = true

local fundoFecharPreview = Instance.new("TextButton", overlayPreview)
fundoFecharPreview.Name = "FundoFechar"
fundoFecharPreview.Size = UDim2.new(1, 0, 1, 0)
fundoFecharPreview.Position = UDim2.new(0, 0, 0, 0)
fundoFecharPreview.BackgroundTransparency = 1
fundoFecharPreview.Text = ""
fundoFecharPreview.AutoButtonColor = false
fundoFecharPreview.ZIndex = 39

local imgPreviewGrande = Instance.new("ImageButton", overlayPreview)
imgPreviewGrande.Name = "ImgGrande"
imgPreviewGrande.AnchorPoint = Vector2.new(0.5, 0.5)
imgPreviewGrande.Position = UDim2.new(0.5, 0, 0.48, 0)
imgPreviewGrande.Size = UDim2.new(0.9, 0, 0.62, 0)
imgPreviewGrande.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
imgPreviewGrande.BackgroundTransparency = 0
imgPreviewGrande.BorderSizePixel = 0
imgPreviewGrande.ScaleType = Enum.ScaleType.Fit
imgPreviewGrande.AutoButtonColor = false
imgPreviewGrande.ZIndex = 42
imgPreviewGrande.Active = true
Instance.new("UICorner", imgPreviewGrande).CornerRadius = UDim.new(0, 12)

local btnFecharPreview = Instance.new("TextButton", overlayPreview)
btnFecharPreview.Name = "BtnFecharPreview"
btnFecharPreview.AnchorPoint = Vector2.new(0.5, 1)
btnFecharPreview.Position = UDim2.new(0.5, 0, 0.98, -6)
btnFecharPreview.Size = UDim2.new(0.72, 0, 0, 40)
btnFecharPreview.BackgroundColor3 = Color3.fromRGB(55, 58, 72)
btnFecharPreview.Text = "Fechar"
btnFecharPreview.TextColor3 = Color3.fromRGB(255, 255, 255)
btnFecharPreview.Font = Enum.Font.GothamBold
btnFecharPreview.TextSize = 14
btnFecharPreview.ZIndex = 43
Instance.new("UICorner", btnFecharPreview).CornerRadius = UDim.new(0, 10)

fecharPreviewFoto = function()
	overlayPreview.Visible = false
end

local function abrirPreviewFoto(assetId)
	if type(assetId) ~= "string" or assetId == "" then
		return
	end
	imgPreviewGrande.Image = assetId
	overlayPreview.Visible = true
end

fundoFecharPreview.Activated:Connect(fecharPreviewFoto)
btnFecharPreview.Activated:Connect(fecharPreviewFoto)

reconstruirGaleria = function()
	for _, ch in ipairs(scrollGal:GetChildren()) do
		if not ch:IsA("UIGridLayout") then
			ch:Destroy()
		end
	end
	local n = #fotosSessao
	if n == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -8, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.TextColor3 = Color3.fromRGB(140, 145, 160)
		empty.Text = "Ainda sem fotos nesta sessão."
		empty.LayoutOrder = 1
		empty.Parent = scrollGal
		return
	end
	for i, entry in ipairs(fotosSessao) do
		local entryId = entry.id
		local cell = Instance.new("Frame")
		cell.Size = UDim2.new(0, 76, 0, 76)
		cell.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
		cell.LayoutOrder = i
		cell.Parent = scrollGal
		cell.ClipsDescendants = true
		Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 8)

		local imgBtn = Instance.new("ImageButton", cell)
		imgBtn.Name = "Thumb"
		imgBtn.Size = UDim2.new(1, -6, 1, -6)
		imgBtn.Position = UDim2.new(0, 3, 0, 3)
		imgBtn.BackgroundTransparency = 1
		imgBtn.AutoButtonColor = false
		imgBtn.ScaleType = Enum.ScaleType.Crop
		imgBtn.Image = entryId
		imgBtn.ZIndex = 1
		Instance.new("UICorner", imgBtn).CornerRadius = UDim.new(0, 6)
		imgBtn.Activated:Connect(function()
			abrirPreviewFoto(entryId)
		end)

		local btnRem = Instance.new("TextButton", cell)
		btnRem.Name = "BtnRemover"
		btnRem.Size = UDim2.new(0, 22, 0, 22)
		btnRem.Position = UDim2.new(1, -26, 0, 4)
		btnRem.BackgroundColor3 = Color3.fromRGB(190, 55, 65)
		btnRem.Text = "×"
		btnRem.TextColor3 = Color3.fromRGB(255, 255, 255)
		btnRem.Font = Enum.Font.GothamBlack
		btnRem.TextSize = 16
		btnRem.AutoButtonColor = true
		btnRem.ZIndex = 5
		Instance.new("UICorner", btnRem).CornerRadius = UDim.new(1, 0)
		btnRem.Activated:Connect(function()
			if overlayPreview.Visible and imgPreviewGrande.Image == entryId then
				fecharPreviewFoto()
			end
			for j = #fotosSessao, 1, -1 do
				if fotosSessao[j].id == entryId then
					table.remove(fotosSessao, j)
					break
				end
			end
			if ultimaCapturaId == entryId then
				ultimaCapturaId = fotosSessao[#fotosSessao] and fotosSessao[#fotosSessao].id or nil
			end
			reconstruirGaleria()
			atualizarBotoesCam()
		end)
	end
end

	return {
		reconstruirGaleria = reconstruirGaleria,
		atualizarBotoesCam = atualizarBotoesCam,
		fecharPreviewGaleria = fecharPreviewFoto,
		tratarVoltarComFotoPendenteCamera = tratarVoltarComFotoPendenteCamera,
	}
end)()

-- Minimiza o telemóvel (mesmo gesto que fechar o painel de app) — usado ao «Ver pin» na app Amigos.
local tweenMinimizarCel = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local function minimizarCelularParaJogo()
	celularAberto = false
	if AppFotoGaleria.fecharPreviewGaleria then
		AppFotoGaleria.fecharPreviewGaleria()
	end
	TweenService:Create(phoneFrame, tweenMinimizarCel, { Position = posicaoFechado }):Play()
	TweenService:Create(telaAppAberto, tweenMinimizarCel, { Position = UDim2.new(1, 0, 0, 0) }):Play()
end

-- =========================================================
-- 🗺️ APP: MAPA / WAYPOINTS (Workspace.Points + Minha casa)
-- =========================================================
local MapaApp = (function()
	local appMapa = Instance.new("Frame", appContainer)
	appMapa.Name = "AppMapaWaypoints"
	appMapa.Size = UDim2.new(1, 0, 1, 0)
	appMapa.BackgroundTransparency = 1
	appMapa.Visible = false

	local tituloMapa = Instance.new("TextLabel", appMapa)
	tituloMapa.Name = "TituloMapa"
	tituloMapa.Size = UDim2.new(1, -20, 0, 22)
	tituloMapa.Position = UDim2.new(0, 10, 0, 8)
	tituloMapa.BackgroundTransparency = 1
	tituloMapa.Font = Enum.Font.GothamBlack
	tituloMapa.TextSize = 16
	tituloMapa.TextXAlignment = Enum.TextXAlignment.Center
	tituloMapa.Text = "Locais do mapa"

	local txtMapaSub = Instance.new("TextLabel", appMapa)
	txtMapaSub.Size = UDim2.new(1, -20, 0, 36)
	txtMapaSub.Position = UDim2.new(0, 10, 0, 30)
	txtMapaSub.BackgroundTransparency = 1
	txtMapaSub.Font = Enum.Font.GothamMedium
	txtMapaSub.TextSize = 11
	txtMapaSub.TextWrapped = true
	txtMapaSub.TextXAlignment = Enum.TextXAlignment.Center
	txtMapaSub.TextYAlignment = Enum.TextYAlignment.Top
	txtMapaSub.Text = "Toque num local: aparece um marcador no mapa onde deves ir. 🏠 = a tua casa (quando já tiveres escolhido lote)."

	local txtMapaStatus = Instance.new("TextLabel", appMapa)
	txtMapaStatus.Size = UDim2.new(1, -20, 0, 26)
	txtMapaStatus.Position = UDim2.new(0, 10, 0, 66)
	txtMapaStatus.BackgroundTransparency = 1
	txtMapaStatus.Font = Enum.Font.GothamBold
	txtMapaStatus.TextSize = 12
	txtMapaStatus.TextXAlignment = Enum.TextXAlignment.Center
	txtMapaStatus.Text = ""
	txtMapaStatus.TextColor3 = Color3.fromRGB(0, 255, 200)

	local btnRemoverMarcacao = Instance.new("TextButton", appMapa)
	btnRemoverMarcacao.Name = "RemoverMarcacao"
	btnRemoverMarcacao.Size = UDim2.new(0, 200, 0, 30)
	btnRemoverMarcacao.Position = UDim2.new(0.5, -100, 0, 94)
	btnRemoverMarcacao.BackgroundColor3 = Color3.fromRGB(180, 55, 55)
	btnRemoverMarcacao.Text = "✕ Remover marcação"
	btnRemoverMarcacao.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnRemoverMarcacao.Font = Enum.Font.GothamBold
	btnRemoverMarcacao.TextSize = 11
	btnRemoverMarcacao.Visible = false
	btnRemoverMarcacao.AutoButtonColor = true
	Instance.new("UICorner", btnRemoverMarcacao).CornerRadius = UDim.new(0, 8)

	local scrollMapa = Instance.new("ScrollingFrame", appMapa)
	scrollMapa.Name = "ScrollMapa"
	scrollMapa.Size = UDim2.new(1, -16, 1, -138)
	scrollMapa.Position = UDim2.new(0, 8, 0, 130)
	scrollMapa.BackgroundTransparency = 1
	scrollMapa.BorderSizePixel = 0
	scrollMapa.ScrollBarThickness = 5
	scrollMapa.ScrollBarImageColor3 = Color3.fromRGB(90, 95, 110)
	scrollMapa.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scrollMapa.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollMapa.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollMapa.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollMapa.ClipsDescendants = true

	local listMapa = Instance.new("UIListLayout", scrollMapa)
	listMapa.Padding = UDim.new(0, 8)
	listMapa.SortOrder = Enum.SortOrder.LayoutOrder
	listMapa.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local padScrollMapa = Instance.new("UIPadding", scrollMapa)
	padScrollMapa.PaddingBottom = UDim.new(0, 12)
	padScrollMapa.PaddingRight = UDim.new(0, 4)

	local mapaLinhasTema = {}
	local mapaAlvoMundo = nil :: Vector3?
	local mapaNomeAlvo = ""
	local mapaConnRender = nil :: RBXScriptConnection?
	local mapaBillboard = nil :: BillboardGui?
	local mapaMarcadorImg = nil :: ImageLabel?
	local mapaHostPart = nil :: BasePart?
	-- Opções extra (ex.: pin de amigo): seguir HRP ao vivo + callback ao chegar.
	local mapaRotOpts = nil :: { aoChegar: (() -> ())?, seguirUserId: number? }?
	-- Distância em studs para esconder o marcador (≈ «10 m» no teu HUD de distância).
	local MAPA_DIST_CHEGADA = 10
	local MAPA_DIST_CHEGADA_AMIGO = 22

	local function prettyNomeMapa(raw: string): string
		if raw == "" then
			return "?"
		end
		local s = raw:gsub("_", " ")
		s = s:gsub("(%l)(%u)", "%1 %2")
		return s
	end

	local function posicaoNoMundo(inst: Instance): Vector3?
		if inst:IsA("BasePart") then
			return inst.Position
		end
		if inst:IsA("Model") then
			return inst:GetPivot().Position
		end
		if inst:IsA("Attachment") then
			return inst.WorldPosition
		end
		return nil
	end

	-- LotesDasCasas: modelo CasaDo_<Player.Name> no lote; marcador no PontoDeDespawn se existir.
	local function obterPosicaoMinhaCasa(): (Vector3?, string, Instance?)
		local lotesFolder = Workspace:FindFirstChild("LotesDasCasas")
		if lotesFolder then
			local nomeCasa = "CasaDo_" .. player.Name
			for _, lote in ipairs(lotesFolder:GetChildren()) do
				local casaModel = lote:FindFirstChild(nomeCasa)
				if casaModel then
					local pd = lote:FindFirstChild("PontoDeDespawn")
					if pd and pd:IsA("BasePart") then
						return pd.Position, "🏠 Minha casa", pd
					end
					local p = posicaoNoMundo(casaModel)
					if p then
						return p, "🏠 Minha casa", casaModel
					end
				end
			end
		end

		local ovNames = { "MinhaCasa", "CasaPlot", "PlotReferencia", "HouseModel", "CasaReferencia" }
		for _, nome in ipairs(ovNames) do
			local ov = player:FindFirstChild(nome)
			if ov and ov:IsA("ObjectValue") and ov.Value then
				local p = posicaoNoMundo(ov.Value)
				if p then
					return p, "🏠 Minha casa", ov.Value
				end
			end
		end
		local pastas = { "Casas", "Houses", "Plots", "PlayerHouses", "Homes" }
		for _, nomePasta in ipairs(pastas) do
			local pasta = Workspace:FindFirstChild(nomePasta)
			if pasta then
				local m = pasta:FindFirstChild(player.Name) or pasta:FindFirstChild(tostring(player.UserId))
				if m then
					local p = posicaoNoMundo(m)
					if p then
						return p, "🏠 Minha casa", m
					end
				end
				for _, ch in ipairs(pasta:GetChildren()) do
					if ch:GetAttribute("OwnerUserId") == player.UserId or ch:GetAttribute("Dono") == player.UserId then
						local p = posicaoNoMundo(ch)
						if p then
							return p, "🏠 Minha casa", ch
						end
					end
				end
			end
		end
		local rl = player.RespawnLocation
		if rl and rl:IsA("SpawnLocation") then
			return rl.Position, "🏠 Minha casa", rl
		end
		return nil, "", nil
	end

	local function destruirSetaVisual()
		if mapaConnRender then
			mapaConnRender:Disconnect()
			mapaConnRender = nil
		end
		if mapaBillboard then
			mapaBillboard:Destroy()
			mapaBillboard = nil
		end
		if mapaHostPart then
			mapaHostPart:Destroy()
			mapaHostPart = nil
		end
		mapaMarcadorImg = nil
	end

	local function pararSetaMapa()
		mapaRotOpts = nil
		destruirSetaVisual()
		mapaAlvoMundo = nil
		mapaNomeAlvo = ""
		txtMapaStatus.Text = ""
		btnRemoverMarcacao.Visible = false
	end

	-- Marcador 3D no destino (Part de Points ou part invisível na posição). Atualiza só a distância no telemóvel.
	local function iniciarRotaPara(
		pos: Vector3,
		nomeExibicao: string,
		instAlvo: Instance?,
		opts: { aoChegar: (() -> ())?, seguirUserId: number? }?
	)
		destruirSetaVisual()
		mapaRotOpts = opts
		mapaAlvoMundo = pos
		mapaNomeAlvo = nomeExibicao

		local alvoPart: BasePart? = nil
		if instAlvo and instAlvo:IsA("BasePart") then
			alvoPart = instAlvo
		elseif instAlvo and instAlvo:IsA("Model") then
			if instAlvo.PrimaryPart then
				alvoPart = instAlvo.PrimaryPart
			else
				alvoPart = instAlvo:FindFirstChildWhichIsA("BasePart", true)
			end
		end

		local bb = Instance.new("BillboardGui")
		bb.Name = "CHOS_MapMarcador"
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Size = UDim2.new(0, 76, 0, 92)
		bb.StudsOffset = Vector3.new(0, 4, 0)

		local img = Instance.new("ImageLabel", bb)
		img.Name = "Pin"
		img.Size = UDim2.new(0.55, 0, 0.5, 0)
		img.Position = UDim2.new(0.225, 0, 0.06, 0)
		img.BackgroundTransparency = 1
		img.Image = "rbxassetid://6034818372"
		img.ImageColor3 = Color3.fromRGB(0, 255, 200)
		img.Rotation = 0

		local distLbl = Instance.new("TextLabel", bb)
		distLbl.Name = "DistHint"
		distLbl.Size = UDim2.new(1, 0, 0.32, 0)
		distLbl.Position = UDim2.new(0, 0, 0.62, 0)
		distLbl.BackgroundTransparency = 1
		distLbl.Font = Enum.Font.GothamBold
		distLbl.TextSize = 11
		distLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		distLbl.TextStrokeTransparency = 0.45
		distLbl.Text = ""

		if alvoPart then
			bb.Adornee = alvoPart
			bb.Parent = alvoPart
		else
			local host = Instance.new("Part")
			host.Name = "CHOS_MapWaypointHost"
			host.Anchored = true
			host.CanCollide = false
			host.CanQuery = false
			host.Transparency = 1
			host.Size = Vector3.new(0.4, 0.4, 0.4)
			host.Position = pos
			host.Parent = Workspace
			mapaHostPart = host
			bb.Adornee = host
			bb.Parent = host
		end

		mapaBillboard = bb
		mapaMarcadorImg = img

		if mapaConnRender then
			mapaConnRender:Disconnect()
			mapaConnRender = nil
		end
		btnRemoverMarcacao.Visible = true

		mapaConnRender = RunService.RenderStepped:Connect(function()
			if not mapaAlvoMundo then
				return
			end
			if not mapaBillboard or not mapaBillboard.Parent then
				pararSetaMapa()
				return
			end
			local charNow = player.Character
			local hrpNow = charNow and charNow:FindFirstChild("HumanoidRootPart") :: BasePart?
			local pontoAlvo: Vector3 = mapaAlvoMundo
			if mapaRotOpts and mapaRotOpts.seguirUserId then
				local op = Players:GetPlayerByUserId(mapaRotOpts.seguirUserId)
				local h = op and op.Character and op.Character:FindFirstChild("HumanoidRootPart")
				if h and h:IsA("BasePart") then
					pontoAlvo = h.Position
					if mapaHostPart then
						mapaHostPart.CFrame = h.CFrame
					end
				end
			end
			local distLimite = (mapaRotOpts and mapaRotOpts.seguirUserId) and MAPA_DIST_CHEGADA_AMIGO or MAPA_DIST_CHEGADA
			local dist = 0
			if hrpNow then
				dist = (hrpNow.Position - pontoAlvo).Magnitude
			end
			if hrpNow and dist <= distLimite then
				local cb = mapaRotOpts and mapaRotOpts.aoChegar
				mapaRotOpts = nil
				destruirSetaVisual()
				mapaAlvoMundo = nil
				mapaNomeAlvo = ""
				btnRemoverMarcacao.Visible = false
				txtMapaStatus.Text = "✅ Chegaste ao local!"
				txtMapaStatus.TextColor3 = Color3.fromRGB(120, 255, 160)
				if cb then
					task.defer(cb)
				end
				return
			end
			txtMapaStatus.TextColor3 = Color3.fromRGB(0, 255, 200)
			txtMapaStatus.Text = string.format("%s — %.0f m", mapaNomeAlvo, dist)
			local dh = mapaBillboard:FindFirstChild("DistHint")
			if dh and dh:IsA("TextLabel") then
				dh.Text = string.format("%.0f m", dist)
			end
		end)
	end

	btnRemoverMarcacao.Activated:Connect(function()
		pararSetaMapa()
	end)

	appMapa:GetPropertyChangedSignal("Visible"):Connect(function()
		if not appMapa.Visible then
			pararSetaMapa()
		end
	end)

	local function limparLinhasLista()
		for _, ch in ipairs(scrollMapa:GetChildren()) do
			if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
				ch:Destroy()
			end
		end
		table.clear(mapaLinhasTema)
	end

	local function criarLinhaMapa(layoutOrder: number, textoBotao: string, alvoPos: Vector3, nomeRota: string, instNoMundo: Instance?)
		local btn = Instance.new("TextButton", scrollMapa)
		btn.LayoutOrder = layoutOrder
		btn.Size = UDim2.new(0.94, 0, 0, 40)
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		btn.Text = ""
		btn.AutoButtonColor = true
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
		local lbl = Instance.new("TextLabel", btn)
		lbl.Size = UDim2.new(1, -12, 1, 0)
		lbl.Position = UDim2.new(0, 6, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamSemibold
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = textoBotao
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		table.insert(mapaLinhasTema, { btn = btn, lbl = lbl })
		btn.Activated:Connect(function()
			iniciarRotaPara(alvoPos, nomeRota, instNoMundo, nil)
		end)
	end

	local function reconstruirListaMapa()
		limparLinhasLista()
		local ordem = 0

		local casaPos, _, casaInst = obterPosicaoMinhaCasa()
		if casaPos then
			ordem += 1
			criarLinhaMapa(ordem, "🏠 Minha casa", casaPos, "🏠 Minha casa", casaInst)
		else
			ordem += 1
			local aviso = Instance.new("TextLabel", scrollMapa)
			aviso.LayoutOrder = ordem
			aviso.Size = UDim2.new(0.94, 0, 0, 40)
			aviso.BackgroundTransparency = 1
			aviso.Font = Enum.Font.GothamMedium
			aviso.TextSize = 10
			aviso.TextWrapped = true
			aviso.TextXAlignment = Enum.TextXAlignment.Center
			aviso.TextColor3 = Color3.fromRGB(255, 200, 120)
			aviso.Text = "🏠 Ainda não tens casa no mapa. Escolhe um lote no jogo — depois abre o Mapa outra vez."
			table.insert(mapaLinhasTema, { btn = aviso, lbl = aviso })
		end

		local points = Workspace:FindFirstChild("Points")
		if not points then
			ordem += 1
			local err = Instance.new("TextLabel", scrollMapa)
			err.LayoutOrder = ordem
			err.Size = UDim2.new(0.94, 0, 0, 36)
			err.BackgroundTransparency = 1
			err.Font = Enum.Font.GothamBold
			err.TextSize = 11
			err.TextColor3 = Color3.fromRGB(255, 120, 100)
			err.Text = "Mapa de locais indisponível neste servidor."
			table.insert(mapaLinhasTema, { btn = err, lbl = err })
			return
		end

		local filhos = points:GetChildren()
		table.sort(filhos, function(a, b)
			return a.Name:lower() < b.Name:lower()
		end)
		for _, ch in ipairs(filhos) do
			local p = posicaoNoMundo(ch)
			if p then
				ordem += 1
				local bonito = prettyNomeMapa(ch.Name)
				criarLinhaMapa(ordem, "📍 " .. bonito, p, "📍 " .. bonito, ch)
			end
		end
	end

	local function aplicarTemaMapa(c)
		tituloMapa.TextColor3 = c.titulo
		txtMapaSub.TextColor3 = c.carMeetSub
		txtMapaStatus.TextColor3 = c.pct
		btnRemoverMarcacao.BackgroundColor3 = c.meetBtnVerm
		btnRemoverMarcacao.TextColor3 = Color3.fromRGB(255, 255, 255)
		scrollMapa.ScrollBarImageColor3 = c.strokeP
		for _, row in ipairs(mapaLinhasTema) do
			if row.btn:IsA("TextButton") then
				row.btn.BackgroundColor3 = c.iconTile
				row.lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			elseif row.lbl then
				row.lbl.TextColor3 = c.carMeetSub
			end
		end
	end

	local function aoAbrirMapa()
		if not mapaAlvoMundo and not mapaConnRender then
			txtMapaStatus.Text = ""
		end
		reconstruirListaMapa()
		aplicarTemaMapa(paletaAtual())
	end

	return {
		Frame = appMapa,
		aoAbrir = aoAbrirMapa,
		aplicarTema = aplicarTemaMapa,
		pararRota = pararSetaMapa,
		-- Ping no mundo (mesmo sistema do Mapa); usado pela app «Amigos» (opts: aoChegar, seguirUserId).
		marcarAlvoExterno = function(pos: Vector3, nomeExibicao: string, opts: { aoChegar: (() -> ())?, seguirUserId: number? }?)
			iniciarRotaPara(pos, nomeExibicao, nil, opts)
		end,
	}
end)()

-- =========================================================
-- 👥 APP: AMIGOS — partilhar localização (só amigos Roblox no mesmo servidor)
-- Servidor: Script com CH_LocalizacaoAmigoServer_REVISADO.lua + RemoteEvent CH_LocalizacaoAmigoEvent no ReplicatedStorage
-- =========================================================
local LocAmigosApp = (function()
	local appLoc = Instance.new("Frame", appContainer)
	appLoc.Name = "AppLocAmigos"
	appLoc.Size = UDim2.new(1, 0, 1, 0)
	appLoc.BackgroundTransparency = 1
	appLoc.Visible = false

	local titulo = Instance.new("TextLabel", appLoc)
	titulo.Size = UDim2.new(1, -20, 0, 22)
	titulo.Position = UDim2.new(0, 10, 0, 8)
	titulo.BackgroundTransparency = 1
	titulo.Font = Enum.Font.GothamBlack
	titulo.TextSize = 16
	titulo.TextXAlignment = Enum.TextXAlignment.Center
	titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
	titulo.Text = "Amigos no servidor"

	local sub = Instance.new("TextLabel", appLoc)
	sub.Size = UDim2.new(1, -20, 0, 52)
	sub.Position = UDim2.new(0, 10, 0, 30)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamMedium
	sub.TextSize = 10
	sub.TextWrapped = true
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.TextYAlignment = Enum.TextYAlignment.Top
	sub.TextColor3 = Color3.fromRGB(200, 200, 200)
	sub.Text =
		"Lista só jogadores no mapa que são teus amigos Roblox. «Enviar» manda a tua posição atual a esse amigo. Quando recebes, aparece aqui embaixo — toca em «Ver pin» para o mesmo marcador do app Mapa."

	local scroll = Instance.new("ScrollingFrame", appLoc)
	scroll.Name = "ScrollLocAmigos"
	scroll.Size = UDim2.new(1, -16, 1, -92)
	scroll.Position = UDim2.new(0, 8, 0, 88)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ClipsDescendants = true

	local listLay = Instance.new("UIListLayout", scroll)
	listLay.Padding = UDim.new(0, 8)
	listLay.SortOrder = Enum.SortOrder.LayoutOrder
	listLay.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local recebidas = {} -- { id, nome, uid, pos, t }
	local nextLocAmigoId = 0

	local evLoc = ReplicatedStorage:FindFirstChild("CH_LocalizacaoAmigoEvent")

	local function limparScroll()
		for _, ch in ipairs(scroll:GetChildren()) do
			if not ch:IsA("UIListLayout") then
				ch:Destroy()
			end
		end
	end

	local function reconstruirUI()
		evLoc = ReplicatedStorage:FindFirstChild("CH_LocalizacaoAmigoEvent")
		limparScroll()
		local ordem = 0

		if not evLoc or not evLoc:IsA("RemoteEvent") then
			ordem += 1
			local err = Instance.new("TextLabel", scroll)
			err.LayoutOrder = ordem
			err.Size = UDim2.new(0.94, 0, 0, 48)
			err.BackgroundTransparency = 1
			err.Font = Enum.Font.GothamBold
			err.TextSize = 11
			err.TextWrapped = true
			err.TextColor3 = Color3.fromRGB(255, 140, 120)
			err.TextXAlignment = Enum.TextXAlignment.Center
			err.Text =
				"Falta o RemoteEvent CH_LocalizacaoAmigoEvent no ReplicatedStorage e o script servidor CH_LocalizacaoAmigoServer_REVISADO.lua."
			return
		end

		local amigosNoServidor = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local ok, amigo = pcall(function()
					return player:IsFriendsWith(p.UserId)
				end)
				if ok and amigo then
					table.insert(amigosNoServidor, p)
				end
			end
		end

		if #amigosNoServidor == 0 then
			ordem += 1
			local av = Instance.new("TextLabel", scroll)
			av.LayoutOrder = ordem
			av.Size = UDim2.new(0.94, 0, 0, 40)
			av.BackgroundTransparency = 1
			av.Font = Enum.Font.GothamMedium
			av.TextSize = 11
			av.TextWrapped = true
			av.TextColor3 = Color3.fromRGB(200, 200, 210)
			av.TextXAlignment = Enum.TextXAlignment.Center
			av.Text = "Nenhum amigo Roblox teu neste servidor neste momento."
		else
			ordem += 1
			local sec = Instance.new("TextLabel", scroll)
			sec.LayoutOrder = ordem
			sec.Size = UDim2.new(0.94, 0, 0, 18)
			sec.BackgroundTransparency = 1
			sec.Font = Enum.Font.GothamBlack
			sec.TextSize = 11
			sec.TextXAlignment = Enum.TextXAlignment.Left
			sec.TextColor3 = Color3.fromRGB(0, 200, 255)
			sec.Text = "Enviar a tua localização"

			for _, alvo in ipairs(amigosNoServidor) do
				ordem += 1
				local row = Instance.new("TextButton", scroll)
				row.LayoutOrder = ordem
				row.Size = UDim2.new(0.94, 0, 0, 40)
				row.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
				row.Text = ""
				row.AutoButtonColor = true
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
				local lbl = Instance.new("TextLabel", row)
				lbl.Size = UDim2.new(1, -100, 1, 0)
				lbl.Position = UDim2.new(0, 10, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamSemibold
				lbl.TextSize = 12
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.TextTruncate = Enum.TextTruncate.AtEnd
				lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
				lbl.Text = alvo.DisplayName
				local btnE = Instance.new("TextButton", row)
				btnE.Size = UDim2.new(0, 82, 0, 28)
				btnE.Position = UDim2.new(1, -90, 0.5, -14)
				btnE.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
				btnE.Text = "Enviar"
				btnE.TextColor3 = Color3.fromRGB(255, 255, 255)
				btnE.Font = Enum.Font.GothamBold
				btnE.TextSize = 11
				Instance.new("UICorner", btnE).CornerRadius = UDim.new(0, 8)
				btnE.Activated:Connect(function()
					evLoc:FireServer("enviar", alvo.UserId)
					mostrarToastGuincho("📍 Localização enviada a " .. alvo.DisplayName, Color3.fromRGB(0, 200, 255))
				end)
			end
		end

		if #recebidas > 0 then
			ordem += 1
			local sec2 = Instance.new("TextLabel", scroll)
			sec2.LayoutOrder = ordem
			sec2.Size = UDim2.new(0.94, 0, 0, 18)
			sec2.BackgroundTransparency = 1
			sec2.Font = Enum.Font.GothamBlack
			sec2.TextSize = 11
			sec2.TextXAlignment = Enum.TextXAlignment.Left
			sec2.TextColor3 = Color3.fromRGB(120, 255, 180)
			sec2.Text = "Recebidas (últimas)"
			for i, r in ipairs(recebidas) do
				if not r.id then
					nextLocAmigoId += 1
					r.id = nextLocAmigoId
				end
				ordem += 1
				local row = Instance.new("TextButton", scroll)
				row.LayoutOrder = ordem
				row.Size = UDim2.new(0.94, 0, 0, 42)
				row.BackgroundColor3 = Color3.fromRGB(38, 42, 52)
				row.Text = ""
				row.AutoButtonColor = true
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
				local lbl = Instance.new("TextLabel", row)
				lbl.Size = UDim2.new(1, -100, 1, 0)
				lbl.Position = UDim2.new(0, 10, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamSemibold
				lbl.TextSize = 11
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.TextWrapped = true
				lbl.TextColor3 = Color3.fromRGB(230, 230, 240)
				lbl.Text = "👤 " .. r.nome .. " — toca «Ver pin»"
				local btnV = Instance.new("TextButton", row)
				btnV.Size = UDim2.new(0, 78, 0, 28)
				btnV.Position = UDim2.new(1, -86, 0.5, -14)
				btnV.BackgroundColor3 = Color3.fromRGB(52, 140, 90)
				btnV.Text = "Ver pin"
				btnV.TextColor3 = Color3.fromRGB(255, 255, 255)
				btnV.Font = Enum.Font.GothamBold
				btnV.TextSize = 10
				Instance.new("UICorner", btnV).CornerRadius = UDim.new(0, 8)
				local posSnap = r.pos
				local nomeSnap = r.nome
				local idLoc = r.id
				local uidSnap = r.uid
				btnV.Activated:Connect(function()
					local seguir = (type(uidSnap) == "number" and uidSnap > 0) and uidSnap or nil
					MapaApp.marcarAlvoExterno(posSnap, "👤 " .. nomeSnap, {
						seguirUserId = seguir,
						aoChegar = function()
							for j = #recebidas, 1, -1 do
								if recebidas[j].id == idLoc then
									table.remove(recebidas, j)
									break
								end
							end
							reconstruirUI()
						end,
					})
					minimizarCelularParaJogo()
					mostrarToastGuincho("📍 A seguir o pin — telemóvel minimizado.", Color3.fromRGB(0, 255, 200))
				end)
			end
		end
	end

	local locAmigosEventoConectado = false
	task.spawn(function()
		local w = ReplicatedStorage:WaitForChild("CH_LocalizacaoAmigoEvent", REMOTE_TIMEOUT)
		if not w or not w:IsA("RemoteEvent") then
			return
		end
		evLoc = w
		if locAmigosEventoConectado then
			return
		end
		locAmigosEventoConectado = true
		w.OnClientEvent:Connect(function(nomeRemet, uidRemet, x, y, z)
			if type(nomeRemet) ~= "string" or type(x) ~= "number" then
				return
			end
			local pos = Vector3.new(x, y, z)
			nextLocAmigoId += 1
			table.insert(recebidas, 1, {
				id = nextLocAmigoId,
				nome = nomeRemet,
				uid = uidRemet or 0,
				pos = pos,
				t = os.time(),
			})
			while #recebidas > 15 do
				table.remove(recebidas)
			end
			reconstruirUI()
			mostrarToastGuincho("📍 " .. nomeRemet .. " partilhou a localização.", Color3.fromRGB(120, 255, 180))
		end)
	end)

	local function aoAbrir()
		reconstruirUI()
	end

	local function aplicarTemaLoc(c)
		titulo.TextColor3 = c.titulo
		sub.TextColor3 = c.carMeetSub
	end

	return {
		Frame = appLoc,
		aoAbrir = aoAbrir,
		aplicarTema = aplicarTemaLoc,
	}
end)()

-- Notificação estilo toast (sobre o ecrã do telemóvel)
local toastGuincho = Instance.new("Frame", phoneFrame)
toastGuincho.Name = "ToastGuincho"
toastGuincho.Size = UDim2.new(0.92, 0, 0, 52)
toastGuincho.Position = UDim2.new(0.04, 0, 0, 36)
toastGuincho.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
toastGuincho.BackgroundTransparency = 0.15
toastGuincho.ZIndex = 150
toastGuincho.Visible = false
Instance.new("UICorner", toastGuincho).CornerRadius = UDim.new(0, 14)
local strokeToastG = Instance.new("UIStroke", toastGuincho)
strokeToastG.Thickness = 1
strokeToastG.Color = Color3.fromRGB(0, 200, 255)
strokeToastG.Transparency = 0.3
local txtToastGuincho = Instance.new("TextLabel", toastGuincho)
txtToastGuincho.Size = UDim2.new(1, -16, 1, -8)
txtToastGuincho.Position = UDim2.new(0, 8, 0, 4)
txtToastGuincho.BackgroundTransparency = 1
txtToastGuincho.Font = Enum.Font.GothamSemibold
txtToastGuincho.TextSize = 12
txtToastGuincho.TextColor3 = Color3.fromRGB(255, 255, 255)
txtToastGuincho.TextWrapped = true
txtToastGuincho.TextXAlignment = Enum.TextXAlignment.Center
txtToastGuincho.TextYAlignment = Enum.TextYAlignment.Center

local tweenToastIn = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenToastOut = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local toastVisivel = false
local tokenToast = 0

local function mostrarToastGuincho(mensagem, corStroke)
	tokenToast += 1
	local meu = tokenToast
	txtToastGuincho.Text = mensagem
	if corStroke then
		strokeToastG.Color = corStroke
	end
	toastGuincho.BackgroundTransparency = 1
	txtToastGuincho.TextTransparency = 1
	toastGuincho.Visible = true
	toastVisivel = true
	TweenService:Create(toastGuincho, tweenToastIn, { BackgroundTransparency = 0.15 }):Play()
	TweenService:Create(txtToastGuincho, tweenToastIn, { TextTransparency = 0 }):Play()
	task.delay(3.2, function()
		if tokenToast ~= meu or not toastVisivel then
			return
		end
		local tw = TweenService:Create(toastGuincho, tweenToastOut, { BackgroundTransparency = 1 })
		local twT = TweenService:Create(txtToastGuincho, tweenToastOut, { TextTransparency = 1 })
		tw:Play()
		twT:Play()
		tw.Completed:Once(function()
			if tokenToast == meu then
				toastGuincho.Visible = false
				toastVisivel = false
			end
		end)
	end)
end

local debounceGuincho = false
btnChamarGuincho.Activated:Connect(function()
	if not evGuincho or debounceGuincho then
		return
	end
	debounceGuincho = true
	task.delay(0.6, function()
		debounceGuincho = false
	end)
	txtGuinchoStatus.Text = ""
	evGuincho:FireServer()
end)

if evGuincho then
	evGuincho.OnClientEvent:Connect(function(fase, mensagem)
		if type(mensagem) ~= "string" then
			mensagem = ""
		end
		if fase == "aceito" then
			mostrarToastGuincho("🚛 " .. mensagem, Color3.fromRGB(100, 200, 255))
			txtGuinchoStatus.Text = mensagem
			txtGuinchoStatus.TextColor3 = Color3.fromRGB(120, 200, 255)
		elseif fase == "entregue" then
			mostrarToastGuincho("✅ " .. mensagem, Color3.fromRGB(85, 255, 127))
			txtGuinchoStatus.Text = mensagem
			txtGuinchoStatus.TextColor3 = Color3.fromRGB(85, 255, 127)
		elseif fase == "recusado" then
			mostrarToastGuincho("⚠️ " .. mensagem, Color3.fromRGB(255, 120, 100))
			txtGuinchoStatus.Text = mensagem
			txtGuinchoStatus.TextColor3 = Color3.fromRGB(255, 140, 120)
		end
	end)
end

-- =========================================================
-- 🌟 FUNÇÕES DE ATUALIZAÇÃO
-- =========================================================
local function getInfoDoNivel(levelAtual)
	local xpTotalNec, xpProximo, mult = 0, 1000, 1.3
	if levelAtual > 1 then
		for _ = 1, (levelAtual - 1) do
			xpTotalNec = xpTotalNec + xpProximo
			xpProximo = math.floor(xpProximo * mult)
		end
	end
	return xpTotalNec, xpProximo
end

local function atualizarCelularStats()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		return
	end

	local intXP = leaderstats:WaitForChild("XP", 5)
	local intLevel = leaderstats:WaitForChild("Level", 5)
	local intDinheiro = leaderstats:WaitForChild("Dinheiro", 5)
	if not intXP or not intLevel or not intDinheiro then
		return
	end

	AppPBB.txtSaldo.Text = "R$ " .. tostring(intDinheiro.Value) .. ",00"
	AppPBB.txtLevelCel.Text = "⭐ Nível: " .. tostring(intLevel.Value) .. "  >>  Próximo: " .. tostring(intLevel.Value + 1)

	local xpBase, xpNesteNivel = getInfoDoNivel(intLevel.Value)
	local xpProgresso = math.max(0, intXP.Value - xpBase)

	AppPBB.txtXpProgresso.Text = tostring(xpProgresso) .. " / " .. tostring(xpNesteNivel)

	local porcentagem = math.clamp(xpProgresso / xpNesteNivel, 0, 1)
	TweenService:Create(AppPBB.fillBarraXP, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(porcentagem, 0, 1, 0) }):Play()
end

local function formatarTempoRestante(dataExpiracao, temPass)
	if temPass or dataExpiracao == 0 then
		return "⏳ Permanente"
	end
	local segs = dataExpiracao - os.time()
	if segs <= 0 then
		return "❌ Expirado"
	end
	local dias = math.floor(segs / 86400)
	local horas = math.floor((segs % 86400) / 3600)
	return (dias > 0) and ("⏳ " .. dias .. "d e " .. horas .. "h") or ("⏳ Restam: " .. horas .. "h")
end

local function atualizarCelularVip()
	local vipSalvo = player:FindFirstChild("VipSalvo")
	if not vipSalvo or not vipSalvo:IsA("StringValue") then
		return
	end

	local expB = player:FindFirstChild("ExpBronze")
	local expG = player:FindFirstChild("ExpGold")
	local expD = player:FindFirstChild("ExpDiamante")
	local passDia, passGold, passBro = false, false, false
	pcall(function()
		passDia = MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_DIAMANTE)
		passGold = MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_GOLD)
		passBro = MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_BRONZE)
	end)

	local v = vipSalvo.Value
	local temDia = passDia or (string.find(v, "Diamante", 1, true) ~= nil)
	local temGold = passGold or (string.find(v, "Gold", 1, true) ~= nil)
	local temBro = passBro or (string.find(v, "Bronze", 1, true) ~= nil)

	AppPBB.TxtExpDiamante.Text = "💎 Dia: " .. (temDia and formatarTempoRestante(expD and expD.Value or 0, passDia) or "❌ Não")
	AppPBB.TxtExpGold.Text = "🥇 Gold: " .. (temGold and formatarTempoRestante(expG and expG.Value or 0, passGold) or "❌ Não")
	AppPBB.TxtExpBronze.Text = "🥉 Bro: " .. (temBro and formatarTempoRestante(expB and expB.Value or 0, passBro) or "❌ Não")

	AppPBB.BtnTagDiamante.Visible = temDia
	AppPBB.BtnTagGold.Visible = temGold
	AppPBB.BtnTagBronze.Visible = temBro

	local tagPreferida = player:FindFirstChild("TagPreferida")
	if tagPreferida and tagPreferida:IsA("StringValue") then
		local nomeTag = (tagPreferida.Value == "") and "Comum" or tagPreferida.Value
		local infoExibir = infosVip[nomeTag] or infosVip.Comum
		AppPBB.txtVipCel.Text = "VIP " .. infoExibir.nome
		AppPBB.txtVipCel.TextColor3 = infoExibir.cor
	end
end

-- =========================================================
-- 🗂️ GERAÇÃO DOS BOTÕES DE APPS NA HOME (IIFE → limite de 200 registos no chunk principal)
-- =========================================================
local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

;(function()
	local meusApps = {
		{ Nome = "Meu Perfil", Icone = "rbxassetid://128466381375519", Frame = appPerfil, RequerVIP = false },
		{ Nome = "Tags & VIP", Icone = "rbxassetid://85964789425416", Frame = appVIP, RequerVIP = false },
		{ Nome = "Gear Bank", Icone = "rbxassetid://129015103954182", Frame = appBanco, RequerVIP = false },
		{ Nome = "Ajustes", Icone = "rbxassetid://119869530491479", Frame = appConfig, RequerVIP = false },
		{ Nome = "JBLEski", Icone = "rbxassetid://71573319016517", Frame = appMusic, RequerVIP = true },
		{ Nome = "Car Meet", Icone = "rbxassetid://0", Frame = appCarMeet, RequerVIP = false },
		{ Nome = "Guincho", Icone = "rbxassetid://0", Frame = appGuincho, RequerVIP = false, EmojiIcone = "🚛" },
		{ Nome = "Câmara", Icone = "rbxassetid://0", Frame = appCamera, RequerVIP = false, EmojiIcone = "📷" },
		{ Nome = "Galeria", Icone = "rbxassetid://0", Frame = appGaleria, RequerVIP = false, EmojiIcone = "🖼️" },
		{ Nome = "Mapa", Icone = "rbxassetid://0", Frame = MapaApp.Frame, RequerVIP = false, EmojiIcone = "🗺️" },
		{ Nome = "Amigos", Icone = "rbxassetid://0", Frame = LocAmigosApp.Frame, RequerVIP = false, EmojiIcone = "📍" },
	}

	for i, app in ipairs(meusApps) do
		local appBtn = Instance.new("ImageButton", appGrid)
		appBtn.BackgroundTransparency = 1
		appBtn.LayoutOrder = i

		local iconeFundo = Instance.new("Frame", appBtn)
		iconeFundo.Size = UDim2.new(1, 0, 0, 60)
		iconeFundo.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		Instance.new("UICorner", iconeFundo).CornerRadius = UDim.new(0, 15)
		table.insert(homeAppIconeFundos, iconeFundo)

		local img = Instance.new("ImageLabel", iconeFundo)
		img.Size = UDim2.new(0.6, 0, 0.6, 0)
		img.Position = UDim2.new(0.2, 0, 0.2, 0)
		img.BackgroundTransparency = 1
		img.Image = app.Icone
		img.ScaleType = Enum.ScaleType.Fit
		if app.Icone == "rbxassetid://0" then
			img.Image = "rbxassetid://3926305904"
			img.ImageRectOffset = Vector2.new(124, 204)
			img.ImageRectSize = Vector2.new(36, 36)
		end
		if app.EmojiIcone then
			img.Visible = false
			local em = Instance.new("TextLabel", iconeFundo)
			em.Size = UDim2.new(1, 0, 1, 0)
			em.BackgroundTransparency = 1
			em.Text = app.EmojiIcone
			em.TextSize = 34
			em.TextColor3 = Color3.fromRGB(255, 255, 255)
			table.insert(homeAppEmojiLabels, em)
		end

		local txt = Instance.new("TextLabel", appBtn)
		txt.Size = UDim2.new(1, -4, 0, 20)
		txt.Position = UDim2.new(0, 2, 0, 60)
		txt.BackgroundTransparency = 1
		txt.Text = app.Nome
		txt.TextColor3 = Color3.fromRGB(255, 255, 255)
		txt.Font = Enum.Font.GothamMedium
		txt.TextSize = 12
		txt.TextXAlignment = Enum.TextXAlignment.Center
		table.insert(homeAppNomeLabels, txt)

		appBtn.Activated:Connect(function()
			if app.RequerVIP then
				local vip = player:FindFirstChild("VipSalvo")
				local vipVal = (vip and vip:IsA("StringValue")) and vip.Value or ""
				local vipDoadoGold = string.find(vipVal, "Gold", 1, true) ~= nil
				local vipDoadoDia = string.find(vipVal, "Diamante", 1, true) ~= nil
				local gamepassGold, gamepassDia = false, false
				pcall(function()
					gamepassGold = MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_GOLD)
					gamepassDia = MarketplaceService:UserOwnsGamePassAsync(player.UserId, ID_DIAMANTE)
				end)

				if not vipDoadoGold and not vipDoadoDia and not gamepassGold and not gamepassDia then
					tituloApp.Text = "💎 Requer VIP Gold+"
					tituloApp.TextColor3 = Color3.fromRGB(255, 215, 0)
					task.delay(2, function()
						if tituloApp.Text == "💎 Requer VIP Gold+" then
							tituloApp.Text = "CH-OS"
							tituloApp.TextColor3 = corTituloAppPadrao
						end
					end)
					return
				end
			end

			tituloApp.Text = app.Nome
			tituloApp.TextColor3 = corTituloAppPadrao

			if AppFotoGaleria.fecharPreviewGaleria then
				AppFotoGaleria.fecharPreviewGaleria()
			end

			appPerfil.Visible = false
			appVIP.Visible = false
			appBanco.Visible = false
			appConfig.Visible = false
			appMusic.Visible = false
			appCarMeet.Visible = false
			appGuincho.Visible = false
			appCamera.Visible = false
			appGaleria.Visible = false
			MapaApp.Frame.Visible = false
			LocAmigosApp.Frame.Visible = false
			app.Frame.Visible = true

			TweenService:Create(telaAppAberto, tweenInfo, { Position = UDim2.new(0, 0, 0, 0) }):Play()

			if app.Nome == "Meu Perfil" or app.Nome == "Gear Bank" then
				atualizarCelularStats()
			elseif app.Nome == "Tags & VIP" then
				atualizarCelularVip()
			elseif app.Nome == "Mapa" then
				MapaApp.aoAbrir()
			elseif app.Nome == "Amigos" then
				LocAmigosApp.aoAbrir()
			elseif app.Nome == "Galeria" then
				AppFotoGaleria.reconstruirGaleria()
			elseif app.Nome == "Câmara" then
				AppFotoGaleria.atualizarBotoesCam()
			end
		end)
	end
end)()

-- =========================================================
-- 🎧 JBLEski — estado e lógica
-- =========================================================
local radioAtual = nil
local playlistLocal = {}
local indexMusica = 0
local isDJ = false
local soundConnection = nil
local isBluetoothOn = false

local function formatarTempo(segundos)
	if not segundos or segundos < 0 then
		segundos = 0
	end
	return string.format("%d:%02d", math.floor(segundos / 60), math.floor(segundos % 60))
end

local function tocarMusicaPorID(id)
	if id and id ~= "" then
		local nomeDaMusica = "Faixa " .. id
		local pData = player:FindFirstChild("PlaylistData")
		if pData and pData:FindFirstChild(tostring(id)) then
			nomeDaMusica = pData:FindFirstChild(tostring(id)).Value
		end
		txtNomeMusica.Text = "🎵 " .. nomeDaMusica

		if isBluetoothOn and radioAtual and radioEvent then
			radioEvent:FireServer("Play", radioAtual, id)
			somLocal:Stop()
		else
			somLocal.SoundId = "rbxassetid://" .. id
			somLocal:Play()
		end
		isDJ = true
	end
end

local function monitorarFimDaMusica()
	if soundConnection then
		soundConnection:Disconnect()
	end
	local currentSound = (isBluetoothOn and radioAtual and radioAtual:FindFirstChild("Som")) and radioAtual.Som:FindFirstChild("Sound") or somLocal

	if currentSound then
		soundConnection = currentSound.Ended:Connect(function()
			if isDJ and #playlistLocal > 0 then
				indexMusica = (indexMusica < #playlistLocal) and (indexMusica + 1) or 1
				inputID.Text = playlistLocal[indexMusica]
				tocarMusicaPorID(playlistLocal[indexMusica])
			end
		end)
	end
end

somLocal:GetPropertyChangedSignal("IsPlaying"):Connect(monitorarFimDaMusica)

local function atualizarPlaylistUI()
	for _, item in ipairs(listaMusicas:GetChildren()) do
		if item:IsA("Frame") then
			item:Destroy()
		end
	end
	playlistLocal = {}
	local pData = player:WaitForChild("PlaylistData", 5)
	if not pData then
		return
	end

	local count = 0
	for _, record in ipairs(pData:GetChildren()) do
		if record:IsA("StringValue") then
		table.insert(playlistLocal, record.Name)
		count = count + 1

		local itemFrame = Instance.new("Frame", listaMusicas)
		itemFrame.Size = UDim2.new(1, -5, 0, 30)
		itemFrame.BackgroundColor3 = corPlaylistItemBg
		Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 6)
		local btnTocar = Instance.new("TextButton", itemFrame)
		btnTocar.Size = UDim2.new(0.85, 0, 1, 0)
		btnTocar.BackgroundTransparency = 1
		btnTocar.Text = "  " .. record.Value
		btnTocar.TextColor3 = corPlaylistItemTxt
		btnTocar.TextXAlignment = Enum.TextXAlignment.Left
		btnTocar.Font = Enum.Font.Gotham
		btnTocar.TextSize = 12
		btnTocar.TextTruncate = Enum.TextTruncate.AtEnd
		local btnRemover = Instance.new("TextButton", itemFrame)
		btnRemover.Size = UDim2.new(0.15, 0, 1, 0)
		btnRemover.Position = UDim2.new(0.85, 0, 0, 0)
		btnRemover.BackgroundTransparency = 1
		btnRemover.Text = "🗑️"
		btnRemover.TextSize = 12

		btnTocar.Activated:Connect(function()
			inputID.Text = record.Name
			tocarMusicaPorID(record.Name)
		end)
		btnRemover.Activated:Connect(function()
			if radioEvent then
				radioEvent:FireServer("RemovePlaylist", radioAtual, record.Name)
			end
			itemFrame:Destroy()
			listaMusicas.CanvasSize = UDim2.new(0, 0, 0, #listaMusicas:GetChildren() * 35)
		end)
		end
	end
	listaMusicas.CanvasSize = UDim2.new(0, 0, 0, count * 35)
end

local function buscarRadioProxima()
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	local pos = char.HumanoidRootPart.Position

	local radioMaisProxima = nil
	local menorDistancia = 25

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:FindFirstChild("Som") and obj.Som:FindFirstChild("Sound") then
			local dist = (obj.Som.Position - pos).Magnitude
			if dist < menorDistancia then
				menorDistancia = dist
				radioMaisProxima = obj
			end
		end
	end
	return radioMaisProxima
end

btnBluetooth.Activated:Connect(function()
	if not radioEvent then
		statusBluetooth.Text = "⚠️ RadioJBLEskiEvent em falta"
		statusBluetooth.TextColor3 = Color3.fromRGB(255, 100, 100)
		task.delay(2, function()
			statusBluetooth.Text = "Reproduzindo no Celular"
			statusBluetooth.TextColor3 = Color3.fromRGB(179, 179, 179)
		end)
		return
	end

	isBluetoothOn = not isBluetoothOn

	if radioAtual and not radioAtual.Parent then
		radioAtual = nil
	end

	if isBluetoothOn then
		if not radioAtual then
			radioAtual = buscarRadioProxima()
		end

		if not radioAtual then
			isBluetoothOn = false
			jbEstadoJBLEski.atualizarPareamento(false, nil)
			statusBluetooth.Text = "⚠️ Nenhuma Caixa de Som próxima!"
			statusBluetooth.TextColor3 = Color3.fromRGB(255, 100, 100)
			task.delay(2, function()
				statusBluetooth.Text = "Reproduzindo no Celular"
				statusBluetooth.TextColor3 = Color3.fromRGB(179, 179, 179)
			end)
			return
		end

		jbEstadoJBLEski.atualizarPareamento(true, radioAtual)
		btnBluetooth.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
		statusBluetooth.Text = "Conectado à Caixa de Som"
		statusBluetooth.TextColor3 = Color3.fromRGB(29, 185, 84)

		if somLocal.IsPlaying then
			local tPos = somLocal.TimePosition
			local idSom = string.gsub(somLocal.SoundId, "rbxassetid://", "")
			somLocal:Stop()
			radioEvent:FireServer("Play", radioAtual, idSom)
			task.delay(0.5, function()
				if radioAtual and radioAtual.Parent and radioEvent then
					radioEvent:FireServer("Seek", radioAtual, tPos)
				end
			end)
		end
	else
		btnBluetooth.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		statusBluetooth.Text = "Reproduzindo no Celular"
		statusBluetooth.TextColor3 = Color3.fromRGB(179, 179, 179)
		if radioAtual and radioAtual.Parent then
			radioEvent:FireServer("Stop", radioAtual)
		end
		radioAtual = nil
		jbEstadoJBLEski.atualizarPareamento(false, nil)
	end
	monitorarFimDaMusica()
end)

btnAddPlaylist.Activated:Connect(function()
	local id = inputID.Text
	if id == "" or not radioEvent then
		return
	end
	btnAddPlaylist.Text = "⏳"
	task.spawn(function()
		local sucesso, info = pcall(function()
			return MarketplaceService:GetProductInfo(tonumber(id), Enum.InfoType.Asset)
		end)
		radioEvent:FireServer("AddPlaylist", radioAtual, id, (sucesso and info) and info.Name or ("Música " .. id))
		task.wait(0.5)
		atualizarPlaylistUI()
		btnAddPlaylist.Text = "💚"
	end)
end)

btnPlayM.Activated:Connect(function()
	if inputID.Text ~= "" then
		tocarMusicaPorID(inputID.Text)
	else
		if isBluetoothOn and radioAtual and radioEvent then
			radioEvent:FireServer("Resume", radioAtual)
		else
			somLocal:Resume()
		end
		isDJ = true
	end
end)
btnPauseM.Activated:Connect(function()
	if isBluetoothOn and radioAtual and radioEvent then
		local s = radioAtual.Som:FindFirstChild("Sound")
		if s then
			if s.IsPlaying then
				radioEvent:FireServer("Pause", radioAtual)
			else
				radioEvent:FireServer("Resume", radioAtual)
			end
		end
	else
		if somLocal.IsPlaying then
			somLocal:Pause()
		else
			somLocal:Resume()
		end
	end
end)
btnStopM.Activated:Connect(function()
	if isBluetoothOn and radioAtual and radioEvent then
		radioEvent:FireServer("Stop", radioAtual)
	else
		somLocal:Stop()
	end
	isDJ = false
	txtNomeMusica.Text = "🎵 Nenhuma música tocando..."
end)
btnPassarM.Activated:Connect(function()
	indexMusica = (indexMusica < #playlistLocal) and (indexMusica + 1) or 1
	if playlistLocal[indexMusica] then
		inputID.Text = playlistLocal[indexMusica]
		tocarMusicaPorID(playlistLocal[indexMusica])
	end
end)
btnVoltarM.Activated:Connect(function()
	indexMusica = (indexMusica > 1) and (indexMusica - 1) or #playlistLocal
	if playlistLocal[indexMusica] then
		inputID.Text = playlistLocal[indexMusica]
		tocarMusicaPorID(playlistLocal[indexMusica])
	end
end)

local arrastandoVolM, arrastandoTempoM = false, false

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

local function aplicarSliderVolume(pct)
	fillVolSlider.Size = UDim2.new(pct, 0, 1, 0)
	knobVolSlider.Position = UDim2.new(pct, -5, 0.5, -5)
	if isBluetoothOn and radioEvent and radioAtual then
		radioEvent:FireServer("Volume", radioAtual, 0.5 + (pct * 2.5))
	else
		somLocal.Volume = pct
	end
end

local function aplicarSliderTempoVisual(pct)
	fillTempoSlider.Size = UDim2.new(pct, 0, 1, 0)
	knobTempoSlider.Position = UDim2.new(pct, -5, 0.5, -5)
end

knobVolSlider.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		arrastandoVolM = true
	end
end)
knobTempoSlider.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		arrastandoTempoM = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local eraTempo = arrastandoTempoM
		arrastandoVolM = false
		if eraTempo then
			arrastandoTempoM = false
			local posX = ponteiroXNoInput(input)
			local pct = percentualNaTrilha(bgTempoSlider, posX)
			local cSound = (isBluetoothOn and radioAtual and radioAtual:FindFirstChild("Som")) and radioAtual.Som:FindFirstChild("Sound") or somLocal
			if cSound and cSound.TimeLength > 0 then
				if isBluetoothOn and radioEvent and radioAtual then
					radioEvent:FireServer("Seek", radioAtual, pct * cSound.TimeLength)
				else
					somLocal.TimePosition = pct * cSound.TimeLength
				end
			end
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local posX = ponteiroXNoInput(input)
		if arrastandoVolM then
			local pct = percentualNaTrilha(bgVolSlider, posX)
			aplicarSliderVolume(pct)
		elseif arrastandoTempoM then
			local pct = percentualNaTrilha(bgTempoSlider, posX)
			aplicarSliderTempoVisual(pct)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if not appMusic.Visible then
		return
	end
	local currentSound = (isBluetoothOn and radioAtual and radioAtual:FindFirstChild("Som")) and radioAtual.Som:FindFirstChild("Sound") or somLocal
	if currentSound and currentSound.IsLoaded and currentSound.TimeLength > 0 then
		if not arrastandoTempoM then
			local progresso = currentSound.TimePosition / currentSound.TimeLength
			aplicarSliderTempoVisual(progresso)
			txtTempoAtual.Text = formatarTempo(currentSound.TimePosition)
		end
		txtTempoTotal.Text = formatarTempo(currentSound.TimeLength)
	end
end)

if radioEvent then
	radioEvent.OnClientEvent:Connect(function(acao, alvoModel)
		if acao == "AbrirMenu" then
			-- Só abre o celular no prompt se o jogador já ligou o Bluetooth no app e está pareado com ESTA caixa.
			-- Sem isso, só o painel da rádio (MenuRadioJBLEski) responde ao evento.
			if not jbEstadoJBLEski.estaPareadoCom(alvoModel) then
				return
			end

			if not celularAberto then
				celularAberto = true
				TweenService:Create(phoneFrame, tweenInfo, { Position = posicaoAberto }):Play()
				if not isBooted then
					isBooted = true
					task.spawn(function()
						task.wait(0.5)
						local tweenLogo = TweenService:Create(logoBoot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { TextSize = 55, TextTransparency = 1 })
						tweenLogo:Play()
						task.wait(0.6)
						TweenService:Create(telaBoot, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
						task.wait(0.5)
						telaBoot.Visible = false
					end)
				end
			end
			tituloApp.Text = "JBLEski"
			appPerfil.Visible = false
			appVIP.Visible = false
			appBanco.Visible = false
			appConfig.Visible = false
			appCarMeet.Visible = false
			appGuincho.Visible = false
			appCamera.Visible = false
			appGaleria.Visible = false
			MapaApp.Frame.Visible = false
			LocAmigosApp.Frame.Visible = false
			appMusic.Visible = true
			TweenService:Create(telaAppAberto, tweenInfo, { Position = UDim2.new(0, 0, 0, 0) }):Play()

			atualizarPlaylistUI()
			monitorarFimDaMusica()
		end
	end)
end

-- =========================================================
-- 🖱️ NAVEGAÇÃO GERAL
-- =========================================================
local function fecharApp()
	if AppFotoGaleria.fecharPreviewGaleria then
		AppFotoGaleria.fecharPreviewGaleria()
	end
	if AppFotoGaleria.tratarVoltarComFotoPendenteCamera and AppFotoGaleria.tratarVoltarComFotoPendenteCamera() then
		return
	end
	TweenService:Create(telaAppAberto, tweenInfo, { Position = UDim2.new(1, 0, 0, 0) }):Play()
end

btnVoltarApp.Activated:Connect(fecharApp)

btnAbrirCelular.Activated:Connect(function()
	celularAberto = not celularAberto
	if celularAberto then
		TweenService:Create(phoneFrame, tweenInfo, { Position = posicaoAberto }):Play()
		if not isBooted then
			isBooted = true
			task.spawn(function()
				task.wait(0.5)
				local tweenLogo = TweenService:Create(logoBoot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { TextSize = 55, TextTransparency = 1 })
				tweenLogo:Play()
				task.wait(0.6)
				TweenService:Create(telaBoot, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				task.wait(0.5)
				telaBoot.Visible = false
			end)
		end
	else
		TweenService:Create(phoneFrame, tweenInfo, { Position = posicaoFechado }):Play()
		fecharApp()
	end
end)

local homeBar = Instance.new("Frame", phoneFrame)
homeBar.Size = UDim2.new(1, 0, 0, 30)
homeBar.Position = UDim2.new(0, 0, 1, -30)
homeBar.BackgroundTransparency = 1
homeBar.ZIndex = 100
local homeBtn = Instance.new("TextButton", homeBar)
homeBtn.Size = UDim2.new(0.4, 0, 0, 5)
homeBtn.Position = UDim2.new(0.3, 0, 0.5, -2.5)
homeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
homeBtn.Text = ""
Instance.new("UICorner", homeBtn).CornerRadius = UDim.new(1, 0)
homeBtn.Activated:Connect(fecharApp)

-- Garante que o atalho fica por cima de tudo no ScreenGui e no fim da lista de filhos.
btnAbrirCelular.Parent = celularGui

local function atualizarEstiloTags()
	for _, btn in ipairs(AppPBB.botoesTags) do
		local stroke = btn:FindFirstChild("UIStroke")
		if btn.Name == vipSelecionadoParaEnvio then
			btn.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
			btn.TextColor3 = Color3.fromRGB(15, 15, 20)
			if stroke then
				stroke.Transparency = 0
			end
		else
			btn.BackgroundColor3 = corTagFundoOff
			btn.TextColor3 = corTagTextoOff
			if stroke then
				stroke.Transparency = 1
			end
		end
	end
end

for _, btn in ipairs(AppPBB.botoesTags) do
	btn.Activated:Connect(function()
		vipSelecionadoParaEnvio = btn.Name
		atualizarEstiloTags()
	end)
end

AppPBB.BtnConfirmar.Activated:Connect(function()
	if vipSelecionadoParaEnvio == "" then
		return
	end
	local eventoAlterarVip = ReplicatedStorage:WaitForChild("AlterarVipEvent", REMOTE_TIMEOUT)
	if not eventoAlterarVip or not eventoAlterarVip:IsA("RemoteEvent") then
		warn("[CH-OS] AlterarVipEvent em falta.")
		return
	end

	AppPBB.BtnConfirmar.Text = "⏳ Equipando..."
	AppPBB.BtnConfirmar.Interactable = false
	eventoAlterarVip:FireServer(vipSelecionadoParaEnvio)

	task.delay(1, function()
		AppPBB.BtnConfirmar.Text = "✅ TAG EQUIPADA!"
		AppPBB.BtnConfirmar.BackgroundColor3 = Color3.fromRGB(0, 255, 127)
	end)
	task.delay(2.5, function()
		AppPBB.BtnConfirmar.Text = "✅ EQUIPAR TAG"
		AppPBB.BtnConfirmar.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
		AppPBB.BtnConfirmar.Interactable = true
		vipSelecionadoParaEnvio = ""
		atualizarEstiloTags()
	end)
end)

aplicarTema = function(claro)
	temaClaroAtivo = claro
	local c = claro and PALETA_CLA or PALETA_ESC
	corTituloAppPadrao = c.titulo
	corTagFundoOff = c.tagOffBg
	corTagTextoOff = c.tagOffTxt
	corPlaylistItemBg = c.playlistBg
	corPlaylistItemTxt = c.playlistTxt

	phoneFrame.BackgroundColor3 = c.phone
	bordaMetalica.Color = c.strokeP
	telaBoot.BackgroundColor3 = c.boot
	logoBoot.TextColor3 = c.bootLogo
	clockText.TextColor3 = c.clock
	notch.BackgroundColor3 = c.notch
	lenteCamera.BackgroundColor3 = c.lente
	bateriaFrame.BackgroundColor3 = c.batCase
	bateriaNivel.BackgroundColor3 = c.batFill
	bateriaPino.BackgroundColor3 = c.batCase
	for _, barra in ipairs(barrasSinal) do
		barra.BackgroundColor3 = c.sinal
	end
	telaAppAberto.BackgroundColor3 = c.appPanel
	btnVoltarApp.BackgroundColor3 = c.voltarBg
	btnVoltarApp.TextColor3 = c.voltarTxt
	tituloApp.TextColor3 = c.titulo
	for _, f in ipairs(homeAppIconeFundos) do
		f.BackgroundColor3 = c.iconTile
	end
	for _, lbl in ipairs(homeAppNomeLabels) do
		lbl.TextColor3 = c.homeLbl
	end
	for _, lbl in ipairs(homeAppEmojiLabels) do
		lbl.TextColor3 = c.homeLbl
	end
	tituloBrilho.TextColor3 = c.configTit
	tituloTamanho.TextColor3 = c.configTit
	txtPorcentagemTamanho.TextColor3 = c.pct
	tituloWall.TextColor3 = c.configTit
	tituloTema.TextColor3 = c.configTit
	fundoSliderBrilho.BackgroundColor3 = c.configTrack
	fundoSliderTamanho.BackgroundColor3 = c.configTrack
	fillSliderBrilho.BackgroundColor3 = c.fillAccent
	fillSliderTamanho.BackgroundColor3 = c.fillAccent
	for _, w in ipairs(botoesWallpaper) do
		w.BackgroundColor3 = c.wallThumb
	end
	appMusic.BackgroundColor3 = c.musicBg
	for _, inst in ipairs(musicControlesCinza) do
		if inst and inst.Parent then
			inst.BackgroundColor3 = c.musicGray
		end
	end
	txtNomeMusica.TextColor3 = c.musicNome
	statusBluetooth.TextColor3 = c.musicTxt
	txtTempoAtual.TextColor3 = c.musicTxt
	txtTempoTotal.TextColor3 = c.musicTxt
	tituloPlaylist.TextColor3 = c.titulo
	toastGuincho.BackgroundColor3 = c.toastBg
	strokeToastG.Color = c.toastStr
	txtToastGuincho.TextColor3 = c.titulo
	homeBtn.BackgroundColor3 = c.homeInd
	AppPBB.imgFotoCel.BackgroundColor3 = c.fotoBg
	AppPBB.txtNomeCel.TextColor3 = c.titulo
	AppPBB.txtLevelCel.TextColor3 = c.titulo
	AppPBB.frameStats.BackgroundColor3 = c.statsBg
	AppPBB.fundoBarraXP.BackgroundColor3 = c.xpFundo
	AppPBB.txtXpProgresso.TextColor3 = c.xpTxt
	AppPBB.fillBarraXP.BackgroundColor3 = c.fillAccent
	AppPBB.frameRelogios.BackgroundColor3 = c.relogiosBg
	AppPBB.TxtEscolha.TextColor3 = c.titulo
	AppPBB.cartaoCredito.BackgroundColor3 = c.bankCard2
	AppPBB.lblFatura.TextColor3 = c.bankLbl
	AppPBB.txtFatura.TextColor3 = Color3.fromRGB(40, 160, 90)
	AppPBB.lblLimite.TextColor3 = c.bankLbl
	tituloCarMeet.TextColor3 = c.titulo
	if exposicaoAtivaCelular then
		txtStatusMeet.TextColor3 = c.meetTxtPublico
	else
		txtStatusMeet.TextColor3 = c.carMeetSub
	end
	tituloGuincho.TextColor3 = c.titulo
	txtGuinchoInfo.TextColor3 = c.guinchoInfo
	txtGuinchoStatus.TextColor3 = c.carMeetSub
	btnChamarGuincho.BackgroundColor3 = c.guinchoBtn
	btnChamarGuincho.TextColor3 = c.guinchoBtnTxt
	MapaApp.aplicarTema(c)
	LocAmigosApp.aplicarTema(c)
	if evToggleCarMeet then
		if exposicaoAtivaCelular then
			btnToggleMeet.BackgroundColor3 = c.meetBtnVerm
		else
			btnToggleMeet.BackgroundColor3 = c.meetBtnVerde
		end
		btnToggleMeet.TextColor3 = claro and Color3.fromRGB(22, 24, 32) or Color3.fromRGB(15, 15, 20)
	end
	local strokeE = btnTemaEscuroRef and btnTemaEscuroRef:FindFirstChild("UIStroke")
	local strokeC = btnTemaClaroRef and btnTemaClaroRef:FindFirstChild("UIStroke")
	if btnTemaEscuroRef and btnTemaClaroRef then
		if claro then
			btnTemaEscuroRef.BackgroundColor3 = c.temaBtnOff
			btnTemaEscuroRef.TextColor3 = c.temaBtnTxt
			btnTemaClaroRef.BackgroundColor3 = c.fillAccent
			btnTemaClaroRef.TextColor3 = Color3.fromRGB(255, 255, 255)
			if strokeE then
				strokeE.Color = c.strokeP
				strokeE.Transparency = 0.5
			end
			if strokeC then
				strokeC.Color = Color3.fromRGB(0, 100, 130)
				strokeC.Transparency = 0
			end
		else
			btnTemaClaroRef.BackgroundColor3 = c.temaBtnOff
			btnTemaClaroRef.TextColor3 = c.temaBtnTxt
			btnTemaEscuroRef.BackgroundColor3 = Color3.fromRGB(55, 58, 72)
			btnTemaEscuroRef.TextColor3 = Color3.fromRGB(255, 255, 255)
			if strokeC then
				strokeC.Color = c.strokeP
				strokeC.Transparency = 0.5
			end
			if strokeE then
				strokeE.Color = c.launcherStroke
				strokeE.Transparency = 0
			end
		end
	end
	atualizarEstiloTags()
	atualizarCelularVip()
	pcall(atualizarPlaylistUI)
end

task.spawn(function()
	AppPBB.txtNomeCel.Text = player.DisplayName
	local sucesso, urlDaImagem, estaPronta = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if sucesso and estaPronta then
		AppPBB.imgFotoCel.Image = urlDaImagem
	end

	local valTamanhoServer = player:WaitForChild("TamanhoCelularValue", 10)
	if valTamanhoServer and valTamanhoServer:IsA("NumberValue") then
		local tamanhoSalvo = valTamanhoServer.Value
		uiScaleCelular.Scale = tamanhoSalvo
		txtPorcentagemTamanho.Text = math.floor(tamanhoSalvo * 100) .. "%"
		local pctVisual = math.clamp((tamanhoSalvo - 0.5) / (1.5 - 0.5), 0, 1)
		fillSliderTamanho.Size = UDim2.new(pctVisual, 0, 1, 0)
		knobSliderTamanho.Position = UDim2.new(pctVisual, -9, 0.5, -9)
	end

	local wallServer = player:WaitForChild("WallpaperCelular", 10)
	if wallServer and wallServer:IsA("StringValue") then
		wallpaper.Image = wallServer.Value
		wallServer.Changed:Connect(function(newVal)
			wallpaper.Image = newVal
		end)
	end

	local brilhoServer = player:WaitForChild("BrilhoCelular", 10)
	if brilhoServer and brilhoServer:IsA("NumberValue") then
		overlayBrilho.BackgroundTransparency = brilhoServer.Value
		local pctB = math.clamp((brilhoServer.Value - 0.4) / 0.6, 0, 1)
		fillSliderBrilho.Size = UDim2.new(pctB, 0, 1, 0)
		knobSliderBrilho.Position = UDim2.new(pctB, -9, 0.5, -9)
		brilhoServer.Changed:Connect(function(newVal)
			overlayBrilho.BackgroundTransparency = newVal
		end)
	end

	local function aplicarTemaDoServidor()
		local t = player:FindFirstChild("TemaCHOS")
		if t and t:IsA("StringValue") and t.Value == "Claro" then
			aplicarTema(true)
		else
			aplicarTema(false)
		end
	end
	aplicarTemaDoServidor()
	player.ChildAdded:Connect(function(ch)
		if ch.Name == "TemaCHOS" and ch:IsA("StringValue") then
			ch.Changed:Connect(aplicarTemaDoServidor)
			aplicarTemaDoServidor()
		end
	end)
	local temaJa = player:FindFirstChild("TemaCHOS")
	if temaJa and temaJa:IsA("StringValue") then
		temaJa.Changed:Connect(aplicarTemaDoServidor)
	end

	atualizarPlaylistUI()
	local pData = player:WaitForChild("PlaylistData", 10)
	if pData then
		pData.ChildAdded:Connect(atualizarPlaylistUI)
		pData.ChildRemoved:Connect(atualizarPlaylistUI)
	end
end)

