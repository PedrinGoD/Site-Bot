-- CH Corporations - Chave de rodas (Tool > LocalScript)
-- Ativação: raio da câmera (centro do rato / toque) + fallback Mouse.Target no desktop.
-- Revisão: Workspace/serviços; InstalarRodaEvent com timeout; raycast com filtro; debounce;
--          sobe a hierarquia até FL/FR/RL/RR (BasePart ou Model).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local tool = script.Parent

if not tool:IsA("Tool") then
	warn("[ChaveRodas] script.Parent deve ser uma Tool.")
	return
end

local REMOTE_TIMEOUT = 60
local RAYCAST_MAX = 120
local DEBOUNCE = 0.35

local instalarEvento = ReplicatedStorage:WaitForChild("InstalarRodaEvent", REMOTE_TIMEOUT)
if not instalarEvento or not instalarEvento:IsA("RemoteEvent") then
	warn("[ChaveRodas] InstalarRodaEvent inválido ou em falta.")
	return
end

local ultimoUso = 0

local NOMES_RODA = { FL = true, FR = true, RL = true, RR = true }

local function encontrarNoAscendente(instancia)
	local atual = instancia
	while atual and atual ~= Workspace do
		if NOMES_RODA[atual.Name] then
			return atual
		end
		atual = atual.Parent
	end
	return nil
end

local function obterAlvoSobMira()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	-- Rato e toque: posição em coordenadas do viewport
	local loc = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(loc.X, loc.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if player.Character then
		params.FilterDescendantsInstances = { player.Character }
	else
		params.FilterDescendantsInstances = {}
	end
	params.IgnoreWater = true

	local resultado = Workspace:Raycast(unitRay.Origin, unitRay.Direction * RAYCAST_MAX, params)
	if resultado and resultado.Instance then
		return resultado.Instance
	end

	-- Fallback só desktop: Mouse.Target (útil se o ray não apanhar a malha)
	if UserInputService.MouseEnabled then
		local ok, mouse = pcall(function()
			return player:GetMouse()
		end)
		if ok and mouse and mouse.Target then
			return mouse.Target
		end
	end

	return nil
end

tool.Activated:Connect(function()
	local agora = os.clock()
	if agora - ultimoUso < DEBOUNCE then
		return
	end

	local alvo = obterAlvoSobMira()
	if not alvo then
		return
	end

	local rodaPart = encontrarNoAscendente(alvo)
	if not rodaPart then
		return
	end

	ultimoUso = agora
	instalarEvento:FireServer(rodaPart)
end)
