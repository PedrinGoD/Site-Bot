-- CH Corporations - Construtor de botões de doação (SurfaceGui + lista vertical com scroll)
-- Revisão: sem task.wait inicial nem varredura global a cada 2s; Workspace via GetService;
--          criação em DonList novo + scan único; pcall na compra; debounce; limpeza se DonList sumir;
--          Instance.Parent definido por último.

print("CH Corporations - Construtor de Botões (revisão — lista vertical com scroll)")

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PLAYER_GUI_TIMEOUT = 60
local DEBOUNCE_COMPRA = 1.2

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_TIMEOUT)
if not playerGui then
	warn("[ConstrutorDoacao] PlayerGui em falta — script desativado.")
	return
end

local IDs_DOACAO = {
	{ Valor = 5, ID = 3562739639, Cor = Color3.fromRGB(170, 255, 127) },
	{ Valor = 10, ID = 3562739803, Cor = Color3.fromRGB(85, 255, 127) },
	{ Valor = 15, ID = 3562739923, Cor = Color3.fromRGB(0, 255, 127) },
	{ Valor = 20, ID = 3562740059, Cor = Color3.fromRGB(0, 255, 255) },
	{ Valor = 25, ID = 3562740201, Cor = Color3.fromRGB(0, 170, 255) },
	{ Valor = 50, ID = 3562740299, Cor = Color3.fromRGB(170, 85, 255) },
	{ Valor = 75, ID = 3562740391, Cor = Color3.fromRGB(255, 85, 255) },
	{ Valor = 100, ID = 3562740504, Cor = Color3.fromRGB(255, 170, 0) },
	{ Valor = 150, ID = 3562740623, Cor = Color3.fromRGB(255, 215, 0) },
}

local function nomeGuiParaModelo(model)
	return "CH_BotoesDoacao_" .. model.Name
end

local function criarInterfaceDoacao(model, partDonList)
	if not model or not partDonList or not partDonList.Parent then
		return
	end
	if not partDonList:IsA("BasePart") then
		warn("[ConstrutorDoacao] DonList não é BasePart — Adornee inválido:", partDonList:GetFullName())
		return
	end

	local nomeDaUi = nomeGuiParaModelo(model)
	if playerGui:FindFirstChild(nomeDaUi) then
		return
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = nomeDaUi
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Adornee = partDonList

	local fundo = Instance.new("Frame")
	fundo.Size = UDim2.new(1, 0, 1, 0)
	fundo.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	fundo.Parent = gui

	local titulo = Instance.new("TextLabel")
	titulo.Size = UDim2.new(1, 0, 0.12, 0)
	titulo.BackgroundTransparency = 1
	titulo.Text = "💖 APOIE O JOGO 💖"
	titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
	titulo.Font = Enum.Font.GothamBlack
	titulo.TextScaled = true
	titulo.Parent = fundo

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ListaDeBotoes"
	scrollFrame.Size = UDim2.new(0.95, 0, 0.85, 0)
	scrollFrame.Position = UDim2.new(0.025, 0, 0.13, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 12
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.Parent = fundo

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollFrame

	local paddingBottom = Instance.new("UIPadding")
	paddingBottom.PaddingBottom = UDim.new(0, 10)
	paddingBottom.PaddingTop = UDim.new(0, 5)
	paddingBottom.Parent = scrollFrame

	for index, config in ipairs(IDs_DOACAO) do
		local btn = Instance.new("TextButton")
		btn.Name = "Btn_" .. config.Valor
		btn.Size = UDim2.new(0.9, 0, 0, 65)
		btn.BackgroundColor3 = config.Cor
		btn.Text = "R$ " .. config.Valor
		btn.TextColor3 = Color3.fromRGB(0, 0, 0)
		btn.Font = Enum.Font.GothamBlack
		btn.TextSize = 35
		btn.LayoutOrder = index
		btn.AutoButtonColor = true
		btn.Parent = scrollFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = btn

		local bloqueado = false
		btn.Activated:Connect(function()
			if bloqueado then
				return
			end
			bloqueado = true
			task.delay(DEBOUNCE_COMPRA, function()
				bloqueado = false
			end)

			local ok, err = pcall(function()
				MarketplaceService:PromptProductPurchase(player, config.ID)
			end)
			if not ok then
				warn("[ConstrutorDoacao] PromptProductPurchase falhou:", err)
			end
		end)
	end

	gui.Parent = playerGui

	partDonList.Destroying:Once(function()
		local existente = playerGui:FindFirstChild(nomeDaUi)
		if existente then
			existente:Destroy()
		end
	end)
end

local function tentarDonList(inst)
	if inst.Name ~= "DonList" or not inst:IsA("BasePart") then
		return
	end

	local model = inst:FindFirstAncestorWhichIsA("Model")
	if not model then
		return
	end

	-- Garante que DonList é filho direto do Model (como no teu mapa original)
	if inst.Parent ~= model then
		return
	end

	task.defer(function()
		if inst.Parent == model and inst:IsDescendantOf(Workspace) then
			criarInterfaceDoacao(model, inst)
		end
	end)
end

for _, objeto in ipairs(Workspace:GetDescendants()) do
	tentarDonList(objeto)
end

Workspace.DescendantAdded:Connect(tentarDonList)
