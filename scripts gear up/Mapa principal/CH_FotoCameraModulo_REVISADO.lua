-- CH Corporations - Módulo câmara livre (modo foto).
-- ReplicatedStorage > ModuleScript com nome exato: CH_FotoCameraModulo (cola este código).
-- Usado pelo CH-OS. Só cliente.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local VELOCIDADE = 28
local SENSIBILIDADE_RATO = 0.0025

local ACTION_SAIR_CAM = "CH_FreecamSair"
-- Tecla dedicada (Backspace) — Esc fica para o menu Roblox e costuma conflitar
local PRI_SAIR_CAM = Enum.ContextActionPriority.High.Value + 10000

local exitCallback = nil

local CORE_PARA_ESCONDER = {
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.EmotesMenu,
	Enum.CoreGuiType.Chat,
}

local M = {}

local ativo = false
local connRender = nil
local connViewport = nil
local viewfinderGui = nil
local vfMaskTop, vfMaskBottom, vfMaskLeft, vfMaskRight, vfBorda = nil, nil, nil, nil, nil
local coreGuiAntes = {}
local salvo = {}
local olharPitch = 0
local olharYaw = 0

local function cameraAtual()
	return Workspace.CurrentCamera
end

local function guardarCoreGui()
	coreGuiAntes = {}
	for _, tipo in ipairs(CORE_PARA_ESCONDER) do
		local ok, v = pcall(function()
			return StarterGui:GetCoreGuiEnabled(tipo)
		end)
		coreGuiAntes[tipo] = ok and v or true
	end
	for _, tipo in ipairs(CORE_PARA_ESCONDER) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(tipo, false)
		end)
	end
end

local function restaurarCoreGui()
	for tipo, estava in pairs(coreGuiAntes) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(tipo, estava)
		end)
	end
	table.clear(coreGuiAntes)
end

local function obterHum()
	local ch = player.Character
	return ch and ch:FindFirstChildOfClass("Humanoid")
end

-- Moldura 1:1 no centro (só visual); some na captura porque o CH-OS desliga todos os ScreenGui
local FRAC_MOLDURA = 0.68

local function destruirViewfinder()
	if connViewport then
		connViewport:Disconnect()
		connViewport = nil
	end
	if viewfinderGui then
		viewfinderGui:Destroy()
		viewfinderGui = nil
	end
	vfMaskTop, vfMaskBottom, vfMaskLeft, vfMaskRight, vfBorda = nil, nil, nil, nil, nil
end

local function layoutViewfinder()
	if not viewfinderGui or not vfMaskTop then
		return
	end
	local cam = cameraAtual()
	if not cam then
		return
	end
	local w = math.max(1, math.floor(cam.ViewportSize.X))
	local h = math.max(1, math.floor(cam.ViewportSize.Y))
	local side = math.floor(math.min(w, h) * FRAC_MOLDURA)
	side = math.clamp(side, 48, math.min(w, h) - 4)
	local cx = w / 2
	local cy = h / 2
	local half = side / 2
	local topH = math.max(0, math.floor(cy - half))
	vfMaskTop.Size = UDim2.fromOffset(w, topH)
	vfMaskTop.Position = UDim2.fromOffset(0, 0)
	local botY = math.ceil(cy + half)
	local botH = math.max(0, h - botY)
	vfMaskBottom.Position = UDim2.fromOffset(0, botY)
	vfMaskBottom.Size = UDim2.fromOffset(w, botH)
	local midTop = math.floor(cy - half)
	local leftW = math.max(0, math.floor(cx - half))
	vfMaskLeft.Position = UDim2.fromOffset(0, midTop)
	vfMaskLeft.Size = UDim2.fromOffset(leftW, side)
	local rightX = math.ceil(cx + half)
	local rightW = math.max(0, w - rightX)
	vfMaskRight.Position = UDim2.fromOffset(rightX, midTop)
	vfMaskRight.Size = UDim2.fromOffset(rightW, side)
	vfBorda.Position = UDim2.fromOffset(math.floor(cx - half), math.floor(cy - half))
	vfBorda.Size = UDim2.fromOffset(side, side)
end

local function criarViewfinder()
	destruirViewfinder()
	local sg = Instance.new("ScreenGui")
	sg.Name = "CH_ViewfinderMoldura"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 2147483646
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = playerGui
	viewfinderGui = sg

	local root = Instance.new("Frame", sg)
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Active = false

	local function mkMask(nome)
		local f = Instance.new("Frame", root)
		f.Name = nome
		f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		f.BackgroundTransparency = 0.52
		f.BorderSizePixel = 0
		f.Active = false
		return f
	end

	vfMaskTop = mkMask("MaskTop")
	vfMaskBottom = mkMask("MaskBottom")
	vfMaskLeft = mkMask("MaskLeft")
	vfMaskRight = mkMask("MaskRight")

	vfBorda = Instance.new("Frame", root)
	vfBorda.Name = "BordaQuadrada"
	vfBorda.BackgroundTransparency = 1
	vfBorda.BorderSizePixel = 0
	vfBorda.Active = false
	local stroke = Instance.new("UIStroke", vfBorda)
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(255, 255, 255)

	layoutViewfinder()
	local cam = cameraAtual()
	if cam then
		connViewport = cam:GetPropertyChangedSignal("ViewportSize"):Connect(layoutViewfinder)
	end
end

function M.IsActive()
	return ativo
end

function M.SetExitCallback(fn)
	exitCallback = fn
end

local function notificarExit()
	if type(exitCallback) == "function" then
		task.defer(exitCallback)
	end
end

function M.Exit()
	if not ativo then
		return
	end
	ativo = false
	destruirViewfinder()
	pcall(function()
		ContextActionService:UnbindAction(ACTION_SAIR_CAM)
	end)
	if connRender then
		connRender:Disconnect()
		connRender = nil
	end
	restaurarCoreGui()
	UserInputService.MouseBehavior = salvo.mouseBehavior or Enum.MouseBehavior.Default

	local cam = cameraAtual()
	if cam then
		cam.CameraType = salvo.camType or Enum.CameraType.Custom
		cam.CameraSubject = salvo.camSubject
	end

	local hum = obterHum()
	if hum then
		if salvo.walkSpeed ~= nil then
			hum.WalkSpeed = salvo.walkSpeed
		end
		if salvo.jumpPower ~= nil then
			hum.JumpPower = salvo.jumpPower
		end
		if salvo.jumpHeight ~= nil then
			hum.JumpHeight = salvo.jumpHeight
		end
		if salvo.autoRotate ~= nil then
			hum.AutoRotate = salvo.autoRotate
		end
	end
	notificarExit()
end

function M.Enter()
	if ativo then
		return true
	end
	local cam = cameraAtual()
	if not cam then
		return false
	end
	local hum = obterHum()
	if not hum then
		return false
	end
	local hrp = hum.RootPart or hum.Parent:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	ativo = true
	salvo.camType = cam.CameraType
	salvo.camSubject = cam.CameraSubject
	salvo.mouseBehavior = UserInputService.MouseBehavior
	salvo.walkSpeed = hum.WalkSpeed
	salvo.jumpPower = hum.JumpPower
	salvo.jumpHeight = hum.JumpHeight
	salvo.autoRotate = hum.AutoRotate

	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum.AutoRotate = false

	cam.CameraType = Enum.CameraType.Scriptable
	cam.CameraSubject = nil
	cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(0, 3, 8), hrp.Position + Vector3.new(0, 1.5, 0))
	local lv = cam.CFrame.LookVector
	olharYaw = math.atan2(-lv.X, -lv.Z)
	olharPitch = math.asin(math.clamp(lv.Y, -0.99, 0.99))

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	guardarCoreGui()

	ContextActionService:BindActionAtPriority(
		ACTION_SAIR_CAM,
		function(_, inputState, _)
			if inputState ~= Enum.UserInputState.Begin or not ativo then
				return Enum.ContextActionResult.Pass
			end
			M.Exit()
			return Enum.ContextActionResult.Sink
		end,
		false,
		PRI_SAIR_CAM,
		Enum.KeyCode.Backspace
	)

	connRender = RunService.RenderStepped:Connect(function(dt)
		if not ativo then
			return
		end
		cam = cameraAtual()
		if not cam then
			M.Exit()
			return
		end
		local look = Vector3.new(
			-math.sin(olharYaw) * math.cos(olharPitch),
			math.sin(olharPitch),
			-math.cos(olharYaw) * math.cos(olharPitch)
		).Unit
		local flatForward = Vector3.new(look.X, 0, look.Z)
		if flatForward.Magnitude < 0.01 then
			flatForward = -Vector3.zAxis
		else
			flatForward = flatForward.Unit
		end
		local flatRight = flatForward:Cross(Vector3.yAxis).Unit

		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move += flatForward
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move -= flatForward
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move -= flatRight
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += flatRight
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move += Vector3.yAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			move -= Vector3.yAxis
		end
		if move.Magnitude > 0.01 then
			move = move.Unit * (VELOCIDADE * dt)
			cam.CFrame = cam.CFrame + move
		end

		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			local d = UserInputService:GetMouseDelta()
			olharYaw -= d.X * SENSIBILIDADE_RATO
			olharPitch = math.clamp(olharPitch - d.Y * SENSIBILIDADE_RATO, -1.45, 1.45)
		end

		local pos = cam.CFrame.Position
		cam.CFrame = CFrame.new(pos) * CFrame.Angles(0, olharYaw, 0) * CFrame.Angles(olharPitch, 0, 0)

		-- Outros scripts (ou o menu) podem repor WalkSpeed; mantém o personagem parado enquanto o modo está ativo
		hum = obterHum()
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.JumpHeight = 0
			hum.AutoRotate = false
		end
	end)

	criarViewfinder()

	return true
end

function M.Toggle()
	if ativo then
		M.Exit()
	else
		M.Enter()
	end
end

player.CharacterRemoving:Connect(function()
	if ativo then
		M.Exit()
	end
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if ativo and not cameraAtual() then
		M.Exit()
	elseif ativo and viewfinderGui and cameraAtual() then
		if connViewport then
			connViewport:Disconnect()
			connViewport = nil
		end
		local cam = cameraAtual()
		connViewport = cam:GetPropertyChangedSignal("ViewportSize"):Connect(layoutViewfinder)
		layoutViewfinder()
	end
end)

return M
