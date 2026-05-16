print("CH Corporations - Placar de Corrida (PC/Mobile - Override TAB)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local eventoTabela = ReplicatedStorage:WaitForChild("TabelaCorridaEvent")

-- =========================================================
-- 🚫 DESATIVA A LISTA PADRÃO DO ROBLOX (LEADERSTATS)
-- =========================================================
task.spawn(function()
	local sucesso = false
	while not sucesso do
		sucesso, _ = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		task.wait(0.5)
	end
end)

-- =========================================================
-- 🎨 CONSTRUÇÃO DA INTERFACE VISUAL
-- =========================================================
local gui = Instance.new("ScreenGui")
gui.Name = "PlacarGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local btnMobile = Instance.new("TextButton", gui)
btnMobile.Size = UDim2.new(0, 50, 0, 50)
btnMobile.Position = UDim2.new(1, -60, 0, 10)
btnMobile.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
btnMobile.BackgroundTransparency = 0.2
btnMobile.Text = "🏆"
btnMobile.TextSize = 25
Instance.new("UICorner", btnMobile).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", btnMobile).Color = Color3.fromRGB(255, 60, 0)

if UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
	btnMobile.Visible = false
end

local frameTabela = Instance.new("CanvasGroup", gui)
frameTabela.Size = UDim2.new(0, 450, 0, 350) -- Começa menorzinho pro zoom funcionar
frameTabela.Position = UDim2.new(0.5, 0, 0.5, 0)
frameTabela.AnchorPoint = Vector2.new(0.5, 0.5)
frameTabela.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
frameTabela.BackgroundTransparency = 0.1
frameTabela.ClipsDescendants = true
frameTabela.GroupTransparency = 1 
frameTabela.Visible = false -- 🌟 CORREÇÃO: Nasce totalmente desativada!
Instance.new("UICorner", frameTabela).CornerRadius = UDim.new(0, 10)

local strokeTabela = Instance.new("UIStroke", frameTabela)
strokeTabela.Color = Color3.fromRGB(255, 60, 0)
strokeTabela.Thickness = 2

local titulo = Instance.new("TextLabel", frameTabela)
titulo.Size = UDim2.new(1, 0, 0, 40)
titulo.BackgroundTransparency = 1
titulo.Text = "🏁 CLASSIFICAÇÃO EM TEMPO REAL"
titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 18

local scrollLista = Instance.new("ScrollingFrame", frameTabela)
scrollLista.Size = UDim2.new(1, -20, 1, -60)
scrollLista.Position = UDim2.new(0, 10, 0, 50)
scrollLista.BackgroundTransparency = 1
scrollLista.ScrollBarThickness = 4
scrollLista.CanvasSize = UDim2.new(0, 0, 0, 0) 

local layoutLista = Instance.new("UIListLayout", scrollLista)
layoutLista.SortOrder = Enum.SortOrder.LayoutOrder
layoutLista.Padding = UDim.new(0, 5)

-- =========================================================
-- ⚙️ LÓGICA DE ABRIR E FECHAR
-- =========================================================
local tabelaAberta = false
local corridaAcabou = false

local function alternarTabela(forcarAbertura)
	if forcarAbertura ~= nil then
		tabelaAberta = forcarAbertura
	else
		tabelaAberta = not tabelaAberta
	end

	if tabelaAberta then
		frameTabela.Visible = true
		local tweenIn = TweenService:Create(frameTabela, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {GroupTransparency = 0, Size = UDim2.new(0, 500, 0, 400)})
		tweenIn:Play()
	else
		if not corridaAcabou then
			local tweenOut = TweenService:Create(frameTabela, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1, Size = UDim2.new(0, 450, 0, 350)})
			tweenOut:Play()

			-- Só desativa a visibilidade quando a animação de sumir terminar
			tweenOut.Completed:Connect(function()
				if not tabelaAberta then frameTabela.Visible = false end
			end)
		end
	end
end

-- 🌟 CORREÇÃO: Força a leitura do TAB ignorando outros painéis do Roblox
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab then 
		alternarTabela(true) 
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab then 
		alternarTabela(false) 
	end
end)

btnMobile.MouseButton1Click:Connect(function() alternarTabela() end)

-- =========================================================
-- 🔄 ATUALIZANDO AS LINHAS (RECEBENDO DO SERVIDOR)
-- =========================================================
eventoTabela.OnClientEvent:Connect(function(dadosTabela, finalizada)
	for _, filho in ipairs(scrollLista:GetChildren()) do
		if filho:IsA("Frame") then filho:Destroy() end
	end

	if finalizada then
		corridaAcabou = true
		titulo.Text = "🏆 RESULTADOS FINAIS E PREMIAÇÃO"
		titulo.TextColor3 = Color3.fromRGB(255, 215, 0)
		strokeTabela.Color = Color3.fromRGB(255, 215, 0)
		btnMobile.Visible = false
		alternarTabela(true) 
	end

	local alturaTotal = 0
	for _, piloto in ipairs(dadosTabela) do
		local linha = Instance.new("Frame", scrollLista)
		linha.Size = UDim2.new(1, 0, 0, 40)
		linha.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		linha.BackgroundTransparency = 0.5
		linha.LayoutOrder = piloto.Posicao
		Instance.new("UICorner", linha).CornerRadius = UDim.new(0, 5)

		if piloto.Nome == player.Name then
			linha.BackgroundColor3 = Color3.fromRGB(255, 60, 0)
			linha.BackgroundTransparency = 0.2
		end

		local posTexto = Instance.new("TextLabel", linha)
		posTexto.Size = UDim2.new(0, 40, 1, 0)
		posTexto.BackgroundTransparency = 1
		posTexto.Text = piloto.Posicao .. "º"
		posTexto.TextColor3 = Color3.fromRGB(255, 255, 255)
		posTexto.Font = Enum.Font.GothamBlack
		posTexto.TextSize = 16

		local nomeTexto = Instance.new("TextLabel", linha)
		nomeTexto.Size = UDim2.new(0.5, 0, 1, 0)
		nomeTexto.Position = UDim2.new(0, 50, 0, 0)
		nomeTexto.BackgroundTransparency = 1
		nomeTexto.Text = piloto.Nome
		nomeTexto.TextColor3 = Color3.fromRGB(255, 255, 255)
		nomeTexto.Font = Enum.Font.GothamMedium
		nomeTexto.TextSize = 14
		nomeTexto.TextXAlignment = Enum.TextXAlignment.Left

		local statusTexto = Instance.new("TextLabel", linha)
		statusTexto.Size = UDim2.new(0.4, 0, 1, 0)
		statusTexto.Position = UDim2.new(0.6, -10, 0, 0)
		statusTexto.BackgroundTransparency = 1
		statusTexto.Font = Enum.Font.GothamBold
		statusTexto.TextSize = 14
		statusTexto.TextXAlignment = Enum.TextXAlignment.Right

		if finalizada and piloto.Terminou then
			statusTexto.Text = "+$" .. piloto.Dinheiro .. " | +" .. piloto.XP .. " XP"
			statusTexto.TextColor3 = Color3.fromRGB(85, 255, 127)
		else
			statusTexto.Text = "Volta: " .. piloto.Volta
			statusTexto.TextColor3 = Color3.fromRGB(200, 200, 200)
		end

		alturaTotal += 45 
	end

	scrollLista.CanvasSize = UDim2.new(0, 0, 0, alturaTotal)
end)
