print("CH Corporations - HUD de Corrida (Posição e Voltas)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- =========================================================
-- 📡 CONECTANDO AOS EVENTOS DO SERVIDOR
-- =========================================================
local eventoVoltas = ReplicatedStorage:WaitForChild("AtualizarVoltasEvent")
local eventoPosicao = ReplicatedStorage:WaitForChild("AtualizarPosicaoEvent", 30)

-- =========================================================
-- 🎨 CONSTRUINDO A HUD DE CORRIDA
-- =========================================================
local gui = Instance.new("ScreenGui")
gui.Name = "HUDCorridaGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Container Principal (Fica no canto superior direito)
local container = Instance.new("Frame", gui)
container.Size = UDim2.new(0, 240, 0, 80)
container.Position = UDim2.new(1, -260, 0, 20)
container.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
container.BackgroundTransparency = 0.2
container.Visible = false -- Nasce invisível, só aparece quando a corrida mandar!
Instance.new("UICorner", container).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", container)
stroke.Color = Color3.fromRGB(255, 60, 0)
stroke.Thickness = 2

-- 🏆 TEXTO DA POSIÇÃO (Lado Esquerdo do Painel)
local txtPosicao = Instance.new("TextLabel", container)
txtPosicao.Size = UDim2.new(0.5, -10, 1, 0)
txtPosicao.Position = UDim2.new(0, 15, 0, 0)
txtPosicao.BackgroundTransparency = 1
txtPosicao.Text = "1º / 1"
txtPosicao.TextColor3 = Color3.fromRGB(255, 255, 255)
txtPosicao.Font = Enum.Font.GothamBlack
txtPosicao.TextSize = 32
txtPosicao.TextXAlignment = Enum.TextXAlignment.Left

-- 🏁 TEXTO DAS VOLTAS (Lado Direito do Painel)
local txtVolta = Instance.new("TextLabel", container)
txtVolta.Size = UDim2.new(0.5, -15, 1, 0)
txtVolta.Position = UDim2.new(0.5, 0, 0, 0)
txtVolta.BackgroundTransparency = 1
txtVolta.Text = "VOLTA\n1/3"
txtVolta.TextColor3 = Color3.fromRGB(200, 200, 200)
txtVolta.Font = Enum.Font.GothamBold
txtVolta.TextSize = 18
txtVolta.TextXAlignment = Enum.TextXAlignment.Right

-- ⚡ LINHA DIVISÓRIA (Estilo Racing)
local divisor = Instance.new("Frame", container)
divisor.Size = UDim2.new(0, 2, 0.6, 0)
divisor.Position = UDim2.new(0.5, 0, 0.2, 0)
divisor.BackgroundColor3 = Color3.fromRGB(255, 60, 0)
divisor.BackgroundTransparency = 0.4
Instance.new("UICorner", divisor).CornerRadius = UDim.new(1, 0)

-- =========================================================
-- ⚙️ ATUALIZAÇÕES EM TEMPO REAL
-- =========================================================

-- Efeito visual de pulsar quando muda de volta
local function pulsarTexto(label)
	local tweenGrow = TweenService:Create(label, TweenInfo.new(0.1, Enum.EasingStyle.Bounce), {TextSize = label.TextSize + 5})
	local tweenShrink = TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {TextSize = label.TextSize})

	tweenGrow:Play()
	tweenGrow.Completed:Connect(function() tweenShrink:Play() end)
end

eventoVoltas.OnClientEvent:Connect(function(voltaAtual, totalVoltas)
	container.Visible = true

	local textoNovo = "VOLTA\n" .. voltaAtual .. "/" .. totalVoltas
	if txtVolta.Text ~= textoNovo then
		txtVolta.Text = textoNovo
		pulsarTexto(txtVolta)
	end
end)

if eventoPosicao then
	eventoPosicao.OnClientEvent:Connect(function(posAtual, totalPilotos)
		container.Visible = true

		local textoNovo = posAtual .. "º / " .. totalPilotos
		if txtPosicao.Text ~= textoNovo then
			txtPosicao.Text = textoNovo
			pulsarTexto(txtPosicao)
		end

		if posAtual == 1 then
			txtPosicao.TextColor3 = Color3.fromRGB(255, 215, 0)
		else
			txtPosicao.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end)
else
	warn("[HUD Corrida] AtualizarPosicaoEvent não encontrado — só as voltas serão atualizadas.")
end
