-- CH Corporations - UI cliente do posto (abastecimento)
-- Revisão: remotes/UI com timeout; validação de carro/preço/combustível; tween da barra cancelável;
--          Fechar sem task.wait no handler; Activated + debounce; notificação em pcall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local REMOTE_TIMEOUT = 60
local UI_TIMEOUT = 15
local FECHAR_DELAY = 1
local ENCHER_DEBOUNCE = 0.6

local eventosPostoFolder = ReplicatedStorage:WaitForChild("EventosPosto", REMOTE_TIMEOUT)
if not eventosPostoFolder then
	warn("[PostoCliente] EventosPosto em falta.")
	return
end

local eventoPosto = eventosPostoFolder:WaitForChild("AcaoPosto", REMOTE_TIMEOUT)
if not eventoPosto or not eventoPosto:IsA("RemoteEvent") then
	warn("[PostoCliente] AcaoPosto inválido ou em falta.")
	return
end

local guiTudo = script.Parent
local framePrincipal = guiTudo:WaitForChild("Frame", UI_TIMEOUT)
if not framePrincipal then
	warn("[PostoCliente] Frame principal em falta.")
	return
end

local barra = framePrincipal:WaitForChild("Barra", UI_TIMEOUT)
local textoNivel = framePrincipal:WaitForChild("Nivel", UI_TIMEOUT)
local textoBase = framePrincipal:WaitForChild("Base", UI_TIMEOUT)
local textoTotal = framePrincipal:WaitForChild("Total", UI_TIMEOUT)
local botaoEncher = framePrincipal:WaitForChild("Encher", UI_TIMEOUT)

if not barra or not textoNivel or not textoBase or not textoTotal or not botaoEncher then
	warn("[PostoCliente] Algum controlo da UI (Barra/Nivel/Base/Total/Encher) em falta.")
	return
end

guiTudo.Visible = false

local carroAtual = nil
local precoBase = 0
local conexaoGasolina = nil
local tweenBarra = nil
local ultimoEncher = 0
-- Incrementado em cada "Abrir"; o Fechar agendado só esconde se a geração não mudou.
local geracaoUI = 0

local function desligarGasolina()
	if conexaoGasolina then
		conexaoGasolina:Disconnect()
		conexaoGasolina = nil
	end
end

local function cancelarTweenBarra()
	if tweenBarra then
		pcall(function()
			tweenBarra:Cancel()
		end)
		tweenBarra = nil
	end
end

local function lerCombustivel(modelo)
	if not modelo or not modelo.Parent then
		return 0
	end
	local v = modelo:GetAttribute("Combustivel")
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(v, 0, 100)
end

local function atualizarUI(combustivel)
	local c = combustivel
	if type(c) ~= "number" or c ~= c then
		c = 0
	end
	c = math.clamp(c, 0, 100)
	local porcentagem = c / 100

	local tamanhoFinal = UDim2.new(0.175, 0, -0.921 * porcentagem, 0)
	cancelarTweenBarra()
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tw = TweenService:Create(barra, tweenInfo, { Size = tamanhoFinal })
	tweenBarra = tw
	tw.Completed:Once(function()
		if tweenBarra == tw then
			tweenBarra = nil
		end
	end)
	tw:Play()

	if textoNivel:IsA("TextLabel") or textoNivel:IsA("TextButton") then
		textoNivel.Text = tostring(math.floor(c)) .. "%"
	end

	local pb = precoBase
	if type(pb) ~= "number" or pb ~= pb then
		pb = 0
	end
	pb = math.max(0, pb)

	if textoBase:IsA("TextLabel") or textoBase:IsA("TextButton") then
		textoBase.Text = "$: " .. string.gsub(tostring(pb), "%.", ",")
	end

	local gasolinaFaltando = 100 - c
	local custoTotal = math.ceil(math.max(0, gasolinaFaltando) * pb)

	if textoTotal:IsA("TextLabel") or textoTotal:IsA("TextButton") then
		if custoTotal <= 0 then
			textoTotal.Text = "$0 (Cheio)"
			textoTotal.TextColor3 = Color3.fromRGB(0, 255, 100)
		else
			textoTotal.Text = "$" .. tostring(custoTotal)
			textoTotal.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
end

local function mostrarAviso(texto)
	if type(texto) ~= "string" then
		texto = tostring(texto)
	end
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "⛽ Posto de Gasolina",
			Text = texto,
			Duration = 4,
		})
	end)
end

eventoPosto.OnClientEvent:Connect(function(acao, parametro1, parametro2)
	if acao == "Abrir" then
		if typeof(parametro1) ~= "Instance" or not parametro1:IsA("Model") then
			return
		end
		geracaoUI += 1
		carroAtual = parametro1
		if type(parametro2) == "number" and parametro2 == parametro2 then
			precoBase = math.max(0, parametro2)
		else
			precoBase = 0
		end

		guiTudo.Visible = true
		botaoEncher.Visible = true

		atualizarUI(lerCombustivel(carroAtual))

		desligarGasolina()
		conexaoGasolina = carroAtual:GetAttributeChangedSignal("Combustivel"):Connect(function()
			if carroAtual and carroAtual.Parent then
				atualizarUI(lerCombustivel(carroAtual))
			end
		end)

	elseif acao == "Fechar" then
		desligarGasolina()
		carroAtual = nil
		local geracaoNoFechar = geracaoUI
		task.delay(FECHAR_DELAY, function()
			if geracaoUI ~= geracaoNoFechar then
				return
			end
			guiTudo.Visible = false
			cancelarTweenBarra()
		end)

	elseif acao == "Aviso" then
		mostrarAviso(parametro1)
	end
end)

local function clicarEncher()
	local agora = os.clock()
	if agora - ultimoEncher < ENCHER_DEBOUNCE then
		return
	end
	if not carroAtual or not carroAtual.Parent then
		return
	end
	ultimoEncher = agora
	botaoEncher.Visible = false
	eventoPosto:FireServer("Iniciar", carroAtual)
end

if botaoEncher:IsA("GuiButton") then
	botaoEncher.Activated:Connect(clicarEncher)
else
	botaoEncher.MouseButton1Click:Connect(clicarEncher)
end
