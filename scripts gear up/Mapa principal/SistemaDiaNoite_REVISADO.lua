-- CH Corporations - Ciclo dia / noite contínuo (transições suaves; velocidade = DURACAO_CICLO_SEG).
-- Colocar em ServerScriptService. Ajusta Lighting.ClockTime + brilho / ambientes (replicado aos clientes).
-- Compatível com LuzesSpotNoite_REVISADO.lua (usa ClockTime < 6 ou > 18).

print("CH Corporations - Sistema Dia/Noite (revisão)")

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

--- Segundos REAIS para uma volta completa de 24 h no jogo (menor = ciclo mais rápido).
--- Ex.: 300 = 5 min | 180 = 3 min | 600 = 10 min.
local DURACAO_CICLO_SEG = 5 * 60

--- Hora inicial (0–24). Ex.: 12 = meio-dia.
local HORA_INICIAL = 12

--- Brilho máximo (Lighting.Brightness não passa disto).
local BRILHO_MAX = 2

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpCor(ca, cb, t)
	return Color3.new(
		lerp(ca.R, cb.R, t),
		lerp(ca.G, cb.G, t),
		lerp(ca.B, cb.B, t)
	)
end

--[[
	Pontos-chave (hora decimal 0–24). Primeiro e último iguais = ciclo sem salto.
	0 meia-noite → ~6 nascer → 12 meio-dia → ~18 pôr → noite.
]]
local CHAVES = {
	{ h = 0, brilho = 0.55, ambiente = Color3.fromRGB(28, 32, 58), outdoor = Color3.fromRGB(22, 28, 52) },
	{ h = 4, brilho = 0.65, ambiente = Color3.fromRGB(40, 38, 70), outdoor = Color3.fromRGB(35, 40, 75) },
	{ h = 5.5, brilho = 1.15, ambiente = Color3.fromRGB(90, 75, 95), outdoor = Color3.fromRGB(120, 85, 70) },
	{ h = 7, brilho = 2, ambiente = Color3.fromRGB(128, 128, 138), outdoor = Color3.fromRGB(150, 158, 175) },
	{ h = 12, brilho = 2, ambiente = Color3.fromRGB(138, 138, 145), outdoor = Color3.fromRGB(170, 180, 198) },
	{ h = 16, brilho = 2, ambiente = Color3.fromRGB(135, 130, 125), outdoor = Color3.fromRGB(165, 155, 140) },
	{ h = 18, brilho = 1.35, ambiente = Color3.fromRGB(120, 88, 72), outdoor = Color3.fromRGB(200, 120, 70) },
	{ h = 19.5, brilho = 0.95, ambiente = Color3.fromRGB(75, 62, 88), outdoor = Color3.fromRGB(110, 72, 95) },
	{ h = 21, brilho = 0.72, ambiente = Color3.fromRGB(45, 48, 72), outdoor = Color3.fromRGB(38, 42, 68) },
	{ h = 24, brilho = 0.55, ambiente = Color3.fromRGB(28, 32, 58), outdoor = Color3.fromRGB(22, 28, 52) },
}

local velocidadeHorasPorSegundo = 24 / math.max(DURACAO_CICLO_SEG, 60)

local function acharSegmento(hora)
	hora = hora % 24
	if hora < 0 then
		hora = hora + 24
	end
	for i = 1, #CHAVES - 1 do
		local a, b = CHAVES[i], CHAVES[i + 1]
		if hora >= a.h and hora <= b.h then
			local span = b.h - a.h
			local t = span > 0 and (hora - a.h) / span or 0
			return hora, a, b, t
		end
	end
	local a, b = CHAVES[#CHAVES - 1], CHAVES[#CHAVES]
	return hora, a, b, 1
end

local function aplicarIluminacao(hora)
	local hNorm, a, b, t = acharSegmento(hora)
	local br = math.min(lerp(a.brilho, b.brilho, t), BRILHO_MAX)
	local amb = lerpCor(a.ambiente, b.ambiente, t)
	local outd = lerpCor(a.outdoor, b.outdoor, t)

	Lighting.ClockTime = hNorm
	Lighting.Brightness = br
	Lighting.Ambient = amb
	Lighting.OutdoorAmbient = outd

	local diaMix = math.clamp(br / math.max(BRILHO_MAX, 0.01), 0, 1)
	local shiftTop = lerpCor(Color3.fromRGB(170, 190, 255), Color3.fromRGB(255, 245, 230), diaMix)
	Lighting.ColorShift_Top = shiftTop
	Lighting.ColorShift_Bottom = lerpCor(shiftTop, Color3.fromRGB(40, 45, 70), 0.35)
end

local horaAtual = HORA_INICIAL % 24
aplicarIluminacao(horaAtual)

RunService.Heartbeat:Connect(function(dt)
	if dt > 1 then
		dt = 1 / 30
	end
	horaAtual = (horaAtual + dt * velocidadeHorasPorSegundo) % 24
	aplicarIluminacao(horaAtual)
end)
