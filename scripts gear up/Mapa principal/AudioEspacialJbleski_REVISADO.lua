-- CH Corporations - Áudio espacial / abafamento atrás de paredes (vários "jbleski") — LocalScript
-- Revisão: lista de rádios mantida com DescendantAdded/Removing + scan inicial (sem GetDescendants por frame);
--          lógica a ~10 Hz; repõe equalizador quando > raio, som parado ou modelo inválido;
--          cancela tween anterior por rádio; valida EqualizerSoundEffect; CurrentCamera atualizado.

print("CH Corporations - Áudio espacial jbleski (revisão — múltiplas casas)")

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local INTERVALO_SEG = 0.1
local RAIO_STUDS = 150
local infoTransicao = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local EQ_ABAFADO = { LowGain = 5, MidGain = -25, HighGain = -50 }
local EQ_NORMAL = { LowGain = 0, MidGain = 0, HighGain = 0 }

-- [Model jbleski] = { abafado = bool?, tween = Tween? }
local estadoPorRadio = setmetatable({}, { __mode = "k" })

local radios = {}
local indiceRadio = {}
local function adicionarRadio(m)
	if not m:IsA("Model") or m.Name ~= "jbleski" or indiceRadio[m] then
		return
	end
	indiceRadio[m] = true
	table.insert(radios, m)
end

local function removerRadio(m)
	if not indiceRadio[m] then
		return
	end
	indiceRadio[m] = nil
	local i = table.find(radios, m)
	if i then
		table.remove(radios, i)
	end
	estadoPorRadio[m] = nil
end

for _, inst in ipairs(workspace:GetDescendants()) do
	adicionarRadio(inst)
end

workspace.DescendantAdded:Connect(function(inst)
	adicionarRadio(inst)
end)

workspace.DescendantRemoving:Connect(function(inst)
	if inst:IsA("Model") and inst.Name == "jbleski" then
		removerRadio(inst)
	end
end)

local function cancelarTweenDoModelo(modelo)
	local st = estadoPorRadio[modelo]
	if st and st.tween then
		pcall(function()
			st.tween:Cancel()
		end)
		st.tween = nil
	end
end

local function aplicarEqualizador(modelo, eq, deveAbafar)
	local st = estadoPorRadio[modelo]
	local prev = st and st.abafado
	if prev == deveAbafar then
		return
	end

	cancelarTweenDoModelo(modelo)
	st = estadoPorRadio[modelo]
	if not st then
		st = {}
		estadoPorRadio[modelo] = st
	end
	st.abafado = deveAbafar

	local alvo = deveAbafar and EQ_ABAFADO or EQ_NORMAL
	local tween = TweenService:Create(eq, infoTransicao, alvo)
	st.tween = tween
	tween:Play()
end

local function limparEstadoSemEqualizador(modelo)
	cancelarTweenDoModelo(modelo)
	estadoPorRadio[modelo] = nil
end

local acumulador = 0

RunService.Heartbeat:Connect(function(dt)
	acumulador += dt
	if acumulador < INTERVALO_SEG then
		return
	end
	acumulador = 0

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local char = player.Character

	for i = #radios, 1, -1 do
		local modelo = radios[i]
		if not modelo.Parent then
			removerRadio(modelo)
		else
			local partSom = modelo:FindFirstChild("Som")
			if partSom and partSom:IsA("BasePart") then
				local sound = partSom:FindFirstChild("Sound")
				local eq = sound and sound:FindFirstChildOfClass("EqualizerSoundEffect")
				if sound and sound:IsA("Sound") and eq then
					if sound.IsPlaying then
						local distancia = (camera.CFrame.Position - partSom.Position).Magnitude
						if distancia < RAIO_STUDS then
							local parametrosRaio = RaycastParams.new()
							parametrosRaio.FilterType = Enum.RaycastFilterType.Exclude
							local listaIgnorar = { modelo }
							if char then
								table.insert(listaIgnorar, char)
							end
							parametrosRaio.FilterDescendantsInstances = listaIgnorar

							local direcao = partSom.Position - camera.CFrame.Position
							local resultadoRaio = workspace:Raycast(camera.CFrame.Position, direcao, parametrosRaio)

							local deveAbafar = false
							if resultadoRaio and resultadoRaio.Instance then
								local peca = resultadoRaio.Instance
								if peca:IsA("BasePart") and peca.Transparency < 0.9 and peca.CanCollide then
									deveAbafar = true
								end
							end

							aplicarEqualizador(modelo, eq, deveAbafar)
						else
							aplicarEqualizador(modelo, eq, false)
						end
					else
						aplicarEqualizador(modelo, eq, false)
					end
				else
					limparEstadoSemEqualizador(modelo)
				end
			end
		end
	end
end)
