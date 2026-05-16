-- CH Corporations - Ícone "casa própria": fade por distância (LocalScript)
-- Revisão: PlayerGui com WaitForChild + cache (não FindFirstChild no Player a cada frame);
--          validação HumanoidRootPart / Adornee / ImageLabel; fade com math.clamp;
--          intervalo de distância validado (evita divisão por zero).

print("CH Corporations - Ícone Casa Própria por distância (revisão)")

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PLAYER_GUI_TIMEOUT = 60

-- Até esta distância (studs), o ícone fica totalmente visível (ImageTransparency = 0).
local DISTANCIA_MAXIMA_VISIVEL = 200
-- A partir desta distância, totalmente invisível (ImageTransparency = 1). Entre as duas, interpola.
local DISTANCIA_SUMIR_TOTAL = 350

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_TIMEOUT)
if not playerGui then
	warn("[IconeCasa] PlayerGui em falta — script desativado.")
	return
end

local rangeFade = DISTANCIA_SUMIR_TOTAL - DISTANCIA_MAXIMA_VISIVEL
if rangeFade <= 0 then
	warn("[IconeCasa] DISTANCIA_SUMIR_TOTAL deve ser maior que DISTANCIA_MAXIMA_VISIVEL.")
	return
end

local placaIconeRef = nil

local function obterPlaca()
	if placaIconeRef and placaIconeRef.Parent == playerGui then
		return placaIconeRef
	end
	placaIconeRef = playerGui:FindFirstChild("IconeCasaPropria")
	return placaIconeRef
end

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "IconeCasaPropria" then
		placaIconeRef = child
	end
end)

playerGui.ChildRemoved:Connect(function(child)
	if child == placaIconeRef then
		placaIconeRef = nil
	end
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local placaIcone = obterPlaca()
	if not placaIcone then
		return
	end

	local imagem = placaIcone:FindFirstChildOfClass("ImageLabel")
	local alvo = placaIcone.Adornee

	if not imagem or not imagem:IsA("ImageLabel") then
		return
	end
	if not alvo or not alvo:IsA("BasePart") then
		return
	end

	local distancia = (rootPart.Position - alvo.Position).Magnitude

	if distancia <= DISTANCIA_MAXIMA_VISIVEL then
		imagem.ImageTransparency = 0
	elseif distancia >= DISTANCIA_SUMIR_TOTAL then
		imagem.ImageTransparency = 1
	else
		local fade = (distancia - DISTANCIA_MAXIMA_VISIVEL) / rangeFade
		imagem.ImageTransparency = math.clamp(fade, 0, 1)
	end
end)
