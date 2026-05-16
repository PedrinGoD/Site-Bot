-- CH Corporations - Sistema de corrida (PC + Mobile)
-- Coloque este LocalScript em StarterPlayerScripts.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WALK_SPEED = 16
local SPRINT_SPEED = 26
local ACTION_NAME = "CH_SPRINT_ACTION"

local mobileToggleAtivo = false
local shiftSegurado = false
local sentadoEmVeiculo = false
local currentHumanoid = nil
local mobileButtonGui = nil

local function sprintDeveFicarAtivo()
	if sentadoEmVeiculo then
		return false
	end
	return shiftSegurado or mobileToggleAtivo
end

local function garantirVelocidade()
	if not currentHumanoid or currentHumanoid.Health <= 0 then
		return
	end
	currentHumanoid.WalkSpeed = sprintDeveFicarAtivo() and SPRINT_SPEED or WALK_SPEED
end

local function atualizarVisibilidadeBotao()
	if not mobileButtonGui then
		return
	end
	mobileButtonGui.Enabled = not sentadoEmVeiculo
end

local function setEstadoVeiculo(humanoid)
	local seat = humanoid and humanoid.SeatPart
	sentadoEmVeiculo = seat ~= nil and seat:IsA("VehicleSeat")
	if sentadoEmVeiculo then
		mobileToggleAtivo = false
		shiftSegurado = false
	end
	atualizarVisibilidadeBotao()
	garantirVelocidade()
end

local function onSprintAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		shiftSegurado = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		shiftSegurado = false
	end
	garantirVelocidade()
	return Enum.ContextActionResult.Sink
end

local function criarBotaoMobile()
	if not UserInputService.TouchEnabled then
		return
	end

	local oldGui = playerGui:FindFirstChild("SprintMobileUI")
	if oldGui then
		oldGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SprintMobileUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	mobileButtonGui = gui

	local btn = Instance.new("TextButton")
	btn.Name = "SprintButton"
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = UDim2.new(1, -18, 1, -130)
	btn.Size = UDim2.new(0, 110, 0, 48)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 22
	btn.Font = Enum.Font.FredokaOne
	btn.Text = "Correr: OFF"
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(0, 255, 255)
	stroke.Parent = btn

	btn.Activated:Connect(function()
		if sentadoEmVeiculo then
			return
		end
		mobileToggleAtivo = not mobileToggleAtivo
		btn.Text = mobileToggleAtivo and "Correr: ON" or "Correr: OFF"
		btn.BackgroundColor3 = mobileToggleAtivo and Color3.fromRGB(35, 145, 85) or Color3.fromRGB(35, 35, 45)
		garantirVelocidade()
	end)
end

local function ligarNoCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	currentHumanoid = humanoid
	mobileToggleAtivo = false
	shiftSegurado = false

	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		setEstadoVeiculo(humanoid)
	end)
	humanoid.Died:Connect(function()
		mobileToggleAtivo = false
		shiftSegurado = false
	end)

	setEstadoVeiculo(humanoid)
	garantirVelocidade()
end

ContextActionService:BindAction(ACTION_NAME, onSprintAction, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
criarBotaoMobile()

if player.Character then
	task.defer(ligarNoCharacter, player.Character)
end
player.CharacterAdded:Connect(ligarNoCharacter)
