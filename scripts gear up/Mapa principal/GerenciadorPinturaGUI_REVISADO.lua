-- CH Corporations - Pintura automotiva V5 (cliente: picker + preços + animação)
-- Revisão: remotes/UI com timeout; TweenService no frame (cancelável); brilho sem .InputBegan em nil;
--          Activated; debounce comprar; Players via serviço; gradiente e texto protegidos.

print("CH Corporations - Pintura Automotiva V5 (revisão cliente)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local REMOTE_TIMEOUT = 60
local UI_TIMEOUT = 15
local COMPRA_DEBOUNCE = 0.55

local comprarEvento = ReplicatedStorage:WaitForChild("ComprarTintaEvent", REMOTE_TIMEOUT)
local abrirEvento = ReplicatedStorage:WaitForChild("AbrirLojaTintasEvent", REMOTE_TIMEOUT)

if not comprarEvento or not comprarEvento:IsA("RemoteEvent") then
	warn("[PinturaGUI] ComprarTintaEvent inválido.")
	return
end
if not abrirEvento or not abrirEvento:IsA("RemoteEvent") then
	warn("[PinturaGUI] AbrirLojaTintasEvent inválido.")
	return
end

local gui = script.Parent
local frameTudo = gui:WaitForChild("Tudo", UI_TIMEOUT)
if not frameTudo then
	warn("[PinturaGUI] Tudo em falta.")
	return
end

local frameBase = frameTudo:WaitForChild("Frame", UI_TIMEOUT)
if not frameBase then
	warn("[PinturaGUI] Frame em falta.")
	return
end

local colorButtonsFolder = frameBase:WaitForChild("ColorButtons", UI_TIMEOUT)
local frameCor = frameBase:WaitForChild("Cor", UI_TIMEOUT)
local textTotal = frameBase:WaitForChild("Total", UI_TIMEOUT)
local btnComprar = frameBase:WaitForChild("Comprar", UI_TIMEOUT)
local btnFechar = frameTudo:WaitForChild("FecharButton", UI_TIMEOUT)

local imgColors = frameBase:WaitForChild("Colors", UI_TIMEOUT)
local imgPickerColors = imgColors:WaitForChild("Picker", UI_TIMEOUT)
local imgBrightness = frameBase:WaitForChild("Brightness", UI_TIMEOUT)
local imgPickerBrightness = imgBrightness:WaitForChild("Picker", UI_TIMEOUT)

-- Animação do frame
local tamanhoOriginal = frameTudo.Size
frameTudo.Size = UDim2.new(0, 0, 0, 0)
frameTudo.Visible = false

local tweenFrame = nil

local function cancelarTweenFrame()
	if tweenFrame then
		pcall(function()
			tweenFrame:Cancel()
		end)
		tweenFrame = nil
	end
end

local function abrirMenuAnimado()
	cancelarTweenFrame()
	frameTudo.Visible = true
	frameTudo.Size = UDim2.new(0, 0, 0, 0)
	local tw = TweenService:Create(frameTudo, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = tamanhoOriginal,
	})
	tweenFrame = tw
	tw.Completed:Once(function()
		if tweenFrame == tw then
			tweenFrame = nil
		end
	end)
	tw:Play()
end

local function fecharMenuAnimado()
	cancelarTweenFrame()
	local tw = TweenService:Create(frameTudo, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
	})
	tweenFrame = tw
	tw.Completed:Once(function()
		if tweenFrame ~= tw then
			return
		end
		tweenFrame = nil
		frameTudo.Visible = false
	end)
	tw:Play()
end

abrirEvento.OnClientEvent:Connect(function()
	if not frameTudo.Visible then
		abrirMenuAnimado()
	else
		cancelarTweenFrame()
		frameTudo.Size = tamanhoOriginal
	end
end)

if btnFechar:IsA("GuiButton") then
	btnFechar.Activated:Connect(fecharMenuAnimado)
else
	btnFechar.MouseButton1Click:Connect(fecharMenuAnimado)
end

-- Preços e picker
local PRECO_COMUM = 100
local PRECO_CUSTOM = 350

local H_atual, S_atual, V_atual = 1, 1, 1
local corFinal = Color3.fromHSV(H_atual, S_atual, V_atual)
local precoAtual = PRECO_COMUM
local ehCorCustomizada = false

local draggingPickerColors = false
local draggingPickerBrightness = false

local gradientBrightness = imgBrightness:FindFirstChildWhichIsA("UIGradient")
if not gradientBrightness then
	gradientBrightness = Instance.new("UIGradient")
	gradientBrightness.Rotation = 90
	gradientBrightness.Parent = imgBrightness
end

local function atualizarCorFinal()
	corFinal = Color3.fromHSV(H_atual, S_atual, V_atual)
	if frameCor:IsA("GuiObject") then
		frameCor.BackgroundColor3 = corFinal
	end
	if textTotal:IsA("TextLabel") or textTotal:IsA("TextButton") then
		textTotal.Text = "$: " .. tostring(precoAtual)
	end

	gradientBrightness.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(H_atual, S_atual, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(H_atual, S_atual, 0)),
	})
end

local function atualizarColorPickerColors(inputPos)
	ehCorCustomizada = true
	precoAtual = PRECO_CUSTOM
	local posAbs = imgColors.AbsolutePosition
	local sizeAbs = imgColors.AbsoluteSize
	if sizeAbs.X <= 0 or sizeAbs.Y <= 0 then
		return
	end
	local relX = math.clamp(inputPos.X - posAbs.X, 0, sizeAbs.X)
	local relY = math.clamp(inputPos.Y - posAbs.Y, 0, sizeAbs.Y)

	imgPickerColors.Position = UDim2.new(0, relX, 0, relY)
	H_atual = 1 - (relX / sizeAbs.X)
	S_atual = 1 - (relY / sizeAbs.Y)
	atualizarCorFinal()
end

local function atualizarColorPickerBrightness(inputPos)
	ehCorCustomizada = true
	precoAtual = PRECO_CUSTOM
	local posAbs = imgBrightness.AbsolutePosition
	local sizeAbs = imgBrightness.AbsoluteSize
	if sizeAbs.Y <= 0 then
		return
	end
	local relY = math.clamp(inputPos.Y - posAbs.Y, 0, sizeAbs.Y)

	imgPickerBrightness.Position = UDim2.new(0.5, 0, 0, relY)
	V_atual = 1 - (relY / sizeAbs.Y)
	atualizarCorFinal()
end

local function processarArrasto(inputPos)
	if draggingPickerColors then
		atualizarColorPickerColors(inputPos)
	elseif draggingPickerBrightness then
		atualizarColorPickerBrightness(inputPos)
	end
end

imgColors.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingPickerColors = true
		atualizarColorPickerColors(input.Position)
	end
end)

-- Área clicável do brilho: o próprio frame ou o primeiro filho GuiObject (evita o Picker como único alvo).
local function ligarInputBrilho(alvo)
	if not alvo or not alvo:IsA("GuiObject") then
		return false
	end
	alvo.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingPickerBrightness = true
			atualizarColorPickerBrightness(input.Position)
		end
	end)
	return true
end

if not ligarInputBrilho(imgBrightness) then
	local ligou = false
	for _, ch in ipairs(imgBrightness:GetChildren()) do
		if ch ~= imgPickerBrightness and ligarInputBrilho(ch) then
			ligou = true
			break
		end
	end
	if not ligou then
		warn("[PinturaGUI] Não foi possível ligar InputBegan ao brilho; confirma Active=true no ImageLabel/Frame.")
	end
end

UserInputService.InputChanged:Connect(function(input)
	if draggingPickerColors or draggingPickerBrightness then
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			processarArrasto(input.Position)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingPickerColors = false
		draggingPickerBrightness = false
	end
end)

for _, botao in ipairs(colorButtonsFolder:GetChildren()) do
	if botao:IsA("GuiButton") then
		botao.Activated:Connect(function()
			ehCorCustomizada = false
			precoAtual = PRECO_COMUM
			local corDoBotao = botao.BackgroundColor3
			H_atual, S_atual, V_atual = Color3.toHSV(corDoBotao)

			local sizeAbsColors = imgColors.AbsoluteSize
			local sizeAbsBrightness = imgBrightness.AbsoluteSize

			if sizeAbsColors.X > 0 and sizeAbsColors.Y > 0 then
				local posX_Colors = (1 - H_atual) * sizeAbsColors.X
				local posY_Colors = (1 - S_atual) * sizeAbsColors.Y
				imgPickerColors.Position = UDim2.new(0, posX_Colors, 0, posY_Colors)
			end

			if sizeAbsBrightness.Y > 0 then
				local posY_Brightness = (1 - V_atual) * sizeAbsBrightness.Y
				imgPickerBrightness.Position = UDim2.new(0.5, 0, 0, posY_Brightness)
			end
			atualizarCorFinal()
		end)
	end
end

local ultimoCompra = 0

if btnComprar:IsA("GuiButton") then
	btnComprar.Activated:Connect(function()
		local agora = os.clock()
		if agora - ultimoCompra < COMPRA_DEBOUNCE then
			return
		end
		ultimoCompra = agora

		comprarEvento:FireServer(corFinal, ehCorCustomizada)
		fecharMenuAnimado()
	end)
else
	btnComprar.MouseButton1Click:Connect(function()
		local agora = os.clock()
		if agora - ultimoCompra < COMPRA_DEBOUNCE then
			return
		end
		ultimoCompra = agora

		comprarEvento:FireServer(corFinal, ehCorCustomizada)
		fecharMenuAnimado()
	end)
end

atualizarCorFinal()
