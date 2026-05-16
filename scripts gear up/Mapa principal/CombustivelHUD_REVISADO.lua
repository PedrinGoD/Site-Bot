-- CH Corporations - HUD de combustível (LocalScript filho do frame "Tudo")
-- Espera filhos: Barra (GuiObject), Nivel (TextLabel ou similar com .Text)
-- Revisão: WaitForChild com timeout; validação de tipos; menos escritas na UI por frame.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local guiTudo = script.Parent

local CHILD_TIMEOUT = 10

local barra = guiTudo:WaitForChild("Barra", CHILD_TIMEOUT)
local textoNivel = guiTudo:WaitForChild("Nivel", CHILD_TIMEOUT)

if not barra or not textoNivel then
	warn("[CombustivelHUD] Barra ou Nivel em falta sob " .. guiTudo:GetFullName())
	return
end

if not barra:IsA("GuiObject") then
	warn("[CombustivelHUD] Barra deve ser um GuiObject.")
	return
end

local function podeDefinirTexto(inst)
	return inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")
end

if not podeDefinirTexto(textoNivel) then
	warn("[CombustivelHUD] Nivel precisa de .Text (TextLabel/TextButton/TextBox).")
	return
end

guiTudo.Visible = false

local lastShown = false
local lastFloorPct = -1
local lastPctSmooth = -1

local EPS_BAR = 0.02

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart

	local active = false
	local pct = 0

	if seat and seat:IsA("VehicleSeat") then
		local carro = seat:FindFirstAncestorOfClass("Model")
		if carro then
			local comb = carro:GetAttribute("Combustivel")
			if type(comb) == "number" and comb == comb then
				active = true
				pct = math.clamp(comb, 0, 100)
			end
		end
	end

	if active ~= lastShown then
		guiTudo.Visible = active
		lastShown = active
	end

	if not active then
		lastFloorPct = -1
		lastPctSmooth = -1
		return
	end

	local floorPct = math.floor(pct + 1e-6)
	if floorPct ~= lastFloorPct then
		textoNivel.Text = tostring(floorPct) .. "%"
		lastFloorPct = floorPct
	end

	if lastPctSmooth < 0 or math.abs(pct - lastPctSmooth) >= EPS_BAR then
		lastPctSmooth = pct
		local porcentagem = pct / 100
		barra.Size = UDim2.new(0.008, 0, 0.206 * porcentagem, 0)
	end
end)
