-- CH Corporations - Inventário custom (3 slots) + bloqueio do backpack nativo
-- Revisão: CoreGui com timeout (sem loop infinito); ordem sem SetAttribute no cliente
--          (atributo só lido se o servidor definir; senão mapa local por instância);
--          desliga conexões ao trocar de Character; AvisoInventario com timeout;
--          Equip/Unequip em pcall; teclas ignoradas com TextBox focado; nomes truncados.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local MAX_SLOTS = 3
local NOME_TOOL_MAX = 48
local COREGUI_RETRY_SEG = 30
local AVISO_REMOTE_TIMEOUT = 60
local TECLA_DEBOUNCE = 0.12

-- Ordem só local (weak keys): não replica nem depende de SetAttribute no cliente.
local ordemLocal = setmetatable({}, { __mode = "k" })

-- =========================================================
-- 1. Backpack nativo desativado
-- =========================================================
task.spawn(function()
	local limite = os.clock() + COREGUI_RETRY_SEG
	while os.clock() < limite do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			break
		end
		task.wait(0.1)
	end
end)

-- Reaplica de vez em quando (alguns sistemas voltam a ligar o CoreGui).
task.spawn(function()
	while task.wait(3) do
		if not player.Parent then
			break
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
	end
end)

-- =========================================================
-- 2. Interface
-- =========================================================
local gui = Instance.new("ScreenGui")
gui.Name = "InventarioCH"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 400, 0, 110)
container.Position = UDim2.new(0, 20, 0.95, 0)
container.AnchorPoint = Vector2.new(0, 1)
container.BackgroundTransparency = 1
container.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 15)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local corFundo = Color3.fromRGB(30, 30, 35)
local corBorda = Color3.fromRGB(60, 60, 70)
local corEquipado = Color3.fromRGB(0, 170, 255)
local corBordaEquipado = Color3.fromRGB(100, 200, 255)

-- Tamanhos responsivos (mobile / tela estreita): recalculados em atualizarMetricasLayout.
local layoutSlotSize = 90
local layoutPadding = 15
local layoutBadge = 24
local layoutNumTextSize = 14
local layoutCornerSlot = 12
local layoutHoverExtra = 5

local function atualizarMetricasLayout()
	local camera = Workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local estreita = vp.X < 640
	local mobileLike = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or estreita

	if mobileLike then
		local margemLateral = 24
		local larguraDisponivel = math.max(180, vp.X - margemLateral)
		layoutPadding = vp.X < 400 and 6 or 8
		layoutSlotSize = math.clamp(
			math.floor((larguraDisponivel - (MAX_SLOTS - 1) * layoutPadding) / MAX_SLOTS),
			52,
			74
		)
		layoutBadge = math.max(18, math.floor(layoutSlotSize * 0.28))
		layoutNumTextSize = math.max(10, layoutBadge - 8)
		layoutCornerSlot = math.max(8, math.floor(layoutSlotSize * 0.14))
		layoutHoverExtra = math.max(3, math.floor(layoutSlotSize * 0.06))
		container.Size = UDim2.new(
			0,
			layoutSlotSize * MAX_SLOTS + layoutPadding * (MAX_SLOTS - 1) + 8,
			0,
			layoutSlotSize + 20
		)
		container.Position = UDim2.new(0, math.max(6, math.floor(vp.X * 0.02)), 0.95, -4)
	else
		layoutSlotSize = 90
		layoutPadding = 15
		layoutBadge = 24
		layoutNumTextSize = 14
		layoutCornerSlot = 12
		layoutHoverExtra = 5
		container.Size = UDim2.new(0, 400, 0, 110)
		container.Position = UDim2.new(0, 20, 0.95, 0)
	end

	layout.Padding = UDim.new(0, layoutPadding)
end

local function truncarNome(nome)
	if type(nome) ~= "string" then
		nome = tostring(nome)
	end
	if #nome <= NOME_TOOL_MAX then
		return nome
	end
	return string.sub(nome, 1, NOME_TOOL_MAX - 1) .. "…"
end

-- =========================================================
-- 3. Ferramentas + ordenação
-- =========================================================
local function getTodasAsTools()
	local char = player.Character
	local backpack = player:FindFirstChild("Backpack")
	local tools = {}

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	local maiorAttr = 0
	for _, tool in ipairs(tools) do
		local ordem = tool:GetAttribute("OrdemInventario")
		if type(ordem) == "number" and ordem == ordem and ordem >= 0 then
			maiorAttr = math.max(maiorAttr, math.floor(ordem))
		end
	end

	-- Ordem local estável: não depende de Backpack vs Character (evita “rodízio” ao equipar).
	local semAttr = {}
	for _, tool in ipairs(tools) do
		local ordem = tool:GetAttribute("OrdemInventario")
		if type(ordem) ~= "number" or ordem ~= ordem then
			table.insert(semAttr, tool)
		end
	end
	table.sort(semAttr, function(a, b)
		return a.Name < b.Name
	end)
	for _, tool in ipairs(semAttr) do
		if not ordemLocal[tool] then
			maiorAttr += 1
			ordemLocal[tool] = maiorAttr
		end
	end

	table.sort(tools, function(a, b)
		local oa = a:GetAttribute("OrdemInventario")
		local ob = b:GetAttribute("OrdemInventario")
		local na = (type(oa) == "number" and oa == oa) and math.floor(oa) or ordemLocal[a] or 0
		local nb = (type(ob) == "number" and ob == ob) and math.floor(ob) or ordemLocal[b] or 0
		if na ~= nb then
			return na < nb
		end
		return a.Name < b.Name
	end)

	return tools
end

local function obterToolNoSlot(indiceSlot)
	local tools = getTodasAsTools()
	return tools[indiceSlot]
end

-- Forward: alternarEquipSlot chama isto antes da definição abaixo; sem isto resolve a global (nil).
local atualizarUI

local function alternarEquipSlot(indiceSlot)
	local tool = obterToolNoSlot(indiceSlot)
	if not tool then
		return
	end

	local char = player.Character
	if not char then
		return
	end
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if tool.Parent == char then
		pcall(function()
			humanoid:UnequipTools()
		end)
	else
		pcall(function()
			humanoid:EquipTool(tool)
		end)
	end
	atualizarUI()
end

-- =========================================================
-- 4. UI + atualização
-- =========================================================
local atualizando = false

atualizarUI = function()
	if atualizando then
		return
	end
	atualizando = true

	task.defer(function()
		atualizarMetricasLayout()

		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		local char = player.Character
		if not char then
			atualizando = false
			return
		end

		local humanoid = char:FindFirstChild("Humanoid")
		local backpack = player:FindFirstChild("Backpack")

		if not humanoid or humanoid.Health <= 0 or not backpack then
			atualizando = false
			return
		end

		local tools = getTodasAsTools()

		for i, tool in ipairs(tools) do
			if i <= MAX_SLOTS then
				local estaEquipado = tool.Parent == char

				local btn = Instance.new("TextButton")
				btn.Name = "Slot_" .. tostring(i)
				btn.Size = UDim2.new(0, layoutSlotSize, 0, layoutSlotSize)
				btn.BackgroundColor3 = estaEquipado and corEquipado or corFundo
				btn.Text = ""
				btn.AutoButtonColor = false
				btn.LayoutOrder = i
				btn.Parent = container

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, layoutCornerSlot)
				corner.Parent = btn

				local stroke = Instance.new("UIStroke")
				stroke.Thickness = 2
				stroke.Color = estaEquipado and corBordaEquipado or corBorda
				stroke.Parent = btn

				local txtNome = Instance.new("TextLabel")
				txtNome.Size = UDim2.new(1, -10, 1, -25)
				txtNome.Position = UDim2.new(0.5, 0, 0.55, 0)
				txtNome.AnchorPoint = Vector2.new(0.5, 0.5)
				txtNome.BackgroundTransparency = 1
				txtNome.Text = truncarNome(tool.Name)
				txtNome.TextColor3 = Color3.fromRGB(255, 255, 255)
				txtNome.Font = Enum.Font.GothamBold
				txtNome.TextScaled = true
				txtNome.TextWrapped = true
				txtNome.Parent = btn

				local numBadge = Instance.new("Frame")
				numBadge.Size = UDim2.new(0, layoutBadge, 0, layoutBadge)
				numBadge.Position = UDim2.new(0, -4, 0, -4)
				numBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
				numBadge.Parent = btn

				local numCorner = Instance.new("UICorner")
				numCorner.CornerRadius = UDim.new(1, 0)
				numCorner.Parent = numBadge

				local numStroke = Instance.new("UIStroke")
				numStroke.Thickness = 1
				numStroke.Color = Color3.fromRGB(100, 100, 100)
				numStroke.Parent = numBadge

				local txtNum = Instance.new("TextLabel")
				txtNum.Size = UDim2.new(1, 0, 1, 0)
				txtNum.BackgroundTransparency = 1
				txtNum.Text = tostring(i)
				txtNum.TextColor3 = Color3.fromRGB(255, 255, 255)
				txtNum.Font = Enum.Font.GothamBlack
				txtNum.TextSize = layoutNumTextSize
				txtNum.Parent = numBadge

				local hoverSize = layoutSlotSize + layoutHoverExtra
				btn.MouseEnter:Connect(function()
					if btn.Parent then
						TweenService:Create(btn, TweenInfo.new(0.15), { Size = UDim2.new(0, hoverSize, 0, hoverSize) }):Play()
					end
				end)
				btn.MouseLeave:Connect(function()
					if btn.Parent then
						TweenService:Create(btn, TweenInfo.new(0.15), { Size = UDim2.new(0, layoutSlotSize, 0, layoutSlotSize) }):Play()
					end
				end)

				btn.Activated:Connect(function()
					alternarEquipSlot(i)
				end)
			end
		end
		atualizando = false
	end)
end

-- =========================================================
-- 5. Ligações por personagem (sem leak em respawn)
-- =========================================================
local charConnections = {}

local function limparLigacoesPersonagem()
	for _, conn in ipairs(charConnections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(charConnections)
end

local function ligar(conn)
	table.insert(charConnections, conn)
end

local function conectarEventos(char)
	limparLigacoesPersonagem()

	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	local humanoid = char:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	ligar(backpack.ChildAdded:Connect(function()
		atualizarUI()
	end))
	ligar(backpack.ChildRemoved:Connect(function()
		atualizarUI()
	end))
	ligar(char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			atualizarUI()
		end
	end))
	ligar(char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			atualizarUI()
		end
	end))

	ligar(humanoid.Died:Connect(function()
		atualizarUI()
	end))

	ligar(humanoid.Seated:Connect(function(estaSentado, _banco)
		if estaSentado then
			container.Visible = false
			task.defer(function()
				local hum = char:FindFirstChild("Humanoid")
				if hum then
					pcall(function()
						hum:UnequipTools()
					end)
				end
			end)
		else
			container.Visible = true
			atualizarUI()
		end
	end))
end

player.CharacterAdded:Connect(function(novoCharacter)
	conectarEventos(novoCharacter)
	atualizarUI()
end)

if player.Character then
	conectarEventos(player.Character)
	atualizarUI()
end

local viewportSizeConn = nil
task.defer(function()
	local function ligarViewport(cam)
		if viewportSizeConn then
			viewportSizeConn:Disconnect()
			viewportSizeConn = nil
		end
		if not cam then
			return
		end
		viewportSizeConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			atualizarUI()
		end)
	end
	ligarViewport(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		ligarViewport(Workspace.CurrentCamera)
		atualizarUI()
	end)
end)

-- =========================================================
-- 6. Teclas 1–3
-- =========================================================
local debounceTeclas = false

UserInputService.InputBegan:Connect(function(input, processado)
	if processado or debounceTeclas then
		return
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return
	end

	local numeroClicado = 0
	if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.KeypadOne then
		numeroClicado = 1
	elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.KeypadTwo then
		numeroClicado = 2
	elseif input.KeyCode == Enum.KeyCode.Three or input.KeyCode == Enum.KeyCode.KeypadThree then
		numeroClicado = 3
	end

	if numeroClicado == 0 then
		return
	end

	debounceTeclas = true
	task.delay(TECLA_DEBOUNCE, function()
		debounceTeclas = false
	end)

	alternarEquipSlot(numeroClicado)
end)

-- =========================================================
-- 7. Aviso inventário cheio
-- =========================================================
local avisoEvent = ReplicatedStorage:WaitForChild("AvisoInventarioEvent", AVISO_REMOTE_TIMEOUT)
if not avisoEvent then
	warn("[InventarioCH] AvisoInventarioEvent não encontrado em " .. AVISO_REMOTE_TIMEOUT .. "s.")
else
	avisoEvent.OnClientEvent:Connect(function()
		if gui:FindFirstChild("AvisoCheio") then
			return
		end

		local aviso = Instance.new("TextLabel")
		aviso.Name = "AvisoCheio"
		aviso.Size = UDim2.new(0, 300, 0, 45)
		aviso.Position = UDim2.new(0.5, 0, 0.75, 0)
		aviso.AnchorPoint = Vector2.new(0.5, 0.5)
		aviso.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
		aviso.BackgroundTransparency = 0.1
		aviso.Text = "⚠️ INVENTÁRIO CHEIO! ⚠️"
		aviso.TextColor3 = Color3.fromRGB(255, 255, 255)
		aviso.Font = Enum.Font.GothamBlack
		aviso.TextSize = 20
		aviso.ZIndex = 50
		aviso.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = aviso

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(150, 0, 0)
		stroke.Parent = aviso

		task.delay(1.5, function()
			if not aviso.Parent then
				return
			end
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()
			local tween = TweenService:Create(aviso, tweenInfo, { TextTransparency = 1, BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Once(function()
				if aviso.Parent then
					aviso:Destroy()
				end
			end)
		end)
	end)
end
