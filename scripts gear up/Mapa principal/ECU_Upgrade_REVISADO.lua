-- CH Corporations - Módulo ECU (LocalScript) — Parent deve conter ObjectValue "Car" e opcionalmente "Drive"
-- Revisão: espera Car.Value com timeout; require do tune com pcall; DNA gravado uma vez por instância do módulo;
--          NivelECU com tonumber + clamp; reboot do Drive em pcall; reage a mudança de Car.Value.

print("CH Corporations - ECU Upgrade (A-Chassis — revisão)")

local interface = script.Parent
if not interface then
	return
end

local WAIT_CAR = 45
local WAIT_TUNE = 15
local REBOOT_DESLIGADO = 0.05

local carValue = interface:WaitForChild("Car", 10)
if not carValue or not carValue:IsA("ObjectValue") then
	warn("[ECU_Upgrade] ObjectValue 'Car' em falta ou inválido.")
	return
end

local function obterTuneDoCarro(car)
	if not car or not car.Parent then
		return nil
	end
	local tuneModulo = car:WaitForChild("A-Chassis Tune", WAIT_TUNE)
	if not tuneModulo or not tuneModulo:IsA("ModuleScript") then
		warn("[ECU_Upgrade] 'A-Chassis Tune' em falta no carro.")
		return nil
	end
	local ok, tune = pcall(require, tuneModulo)
	if not ok or type(tune) ~= "table" then
		warn("[ECU_Upgrade] require(A-Chassis Tune) falhou.")
		return nil
	end
	return tune
end

local function garantirDNA(tune)
	if tune.DNA_Salvo then
		return
	end
	local hp = tune.Horsepower
	local curve = tune.CurveMult
	local fd = tune.FinalDrive
	local clutch = tune.ClutchTol
	if type(hp) ~= "number" or type(curve) ~= "number" or type(fd) ~= "number" or type(clutch) ~= "number" then
		warn("[ECU_Upgrade] Valores base do tune inválidos — DNA não gravado.")
		return
	end
	tune.DNA_HP = hp
	tune.DNA_Curve = curve
	tune.DNA_FD = fd
	tune.DNA_Clutch = clutch
	tune.DNA_Salvo = true
end

local function nivelECUValido(car)
	local n = tonumber(car:GetAttribute("NivelECU"))
	if n == nil then
		return 0
	end
	return math.clamp(math.floor(n), 0, 4)
end

local function atualizarPerformance()
	local car = carValue.Value
	if not car or not car.Parent then
		return
	end

	local tune = obterTuneDoCarro(car)
	if not tune then
		return
	end

	garantirDNA(tune)
	if not tune.DNA_Salvo then
		return
	end

	local nivel = nivelECUValido(car)

	if nivel == 1 then
		tune.Horsepower = tune.DNA_HP * 1.20
		tune.CurveMult = tune.DNA_Curve * 1.20
		tune.ClutchTol = tune.DNA_Clutch * 1.20
		tune.FinalDrive = tune.DNA_FD * 0.90
	elseif nivel == 2 then
		tune.Horsepower = tune.DNA_HP * 1.60
		tune.CurveMult = tune.DNA_Curve * 1.60
		tune.ClutchTol = tune.DNA_Clutch * 1.60
		tune.FinalDrive = tune.DNA_FD * 0.85
	elseif nivel == 3 then
		tune.Horsepower = tune.DNA_HP * 1.75
		tune.CurveMult = tune.DNA_Curve * 1.75
		tune.ClutchTol = tune.DNA_Clutch * 1.75
		tune.FinalDrive = tune.DNA_FD * 0.79
	elseif nivel == 4 then
		tune.Horsepower = tune.DNA_HP * 1.90
		tune.CurveMult = tune.DNA_Curve * 1.90
		tune.ClutchTol = tune.DNA_Clutch * 1.90
		tune.FinalDrive = tune.DNA_FD * 0.75
	else
		tune.Horsepower = tune.DNA_HP
		tune.CurveMult = tune.DNA_Curve
		tune.ClutchTol = tune.DNA_Clutch
		tune.FinalDrive = tune.DNA_FD
	end

	task.defer(function()
		local driveScript = interface:FindFirstChild("Drive")
		if driveScript and driveScript:IsA("LocalScript") and driveScript.Enabled then
			pcall(function()
				driveScript.Enabled = false
				task.wait(REBOOT_DESLIGADO)
				driveScript.Enabled = true
			end)
		end
	end)
end

local ecuCon = nil

local function ligarSinalECU(car)
	if ecuCon then
		ecuCon:Disconnect()
		ecuCon = nil
	end
	if car and car.Parent then
		ecuCon = car:GetAttributeChangedSignal("NivelECU"):Connect(atualizarPerformance)
	end
end

local function sincronizarComCarro()
	local car = carValue.Value
	if not car or not car:IsA("Instance") or not car.Parent then
		return
	end
	ligarSinalECU(car)
	atualizarPerformance()
end

task.spawn(function()
	local limite = os.clock() + WAIT_CAR
	while (not carValue.Value or not carValue.Value.Parent) and os.clock() < limite do
		task.wait(0.1)
	end
	if carValue.Value and carValue.Value.Parent then
		sincronizarComCarro()
	else
		warn("[ECU_Upgrade] Car.Value ainda vazio após espera — aguardando Changed.")
	end
end)

carValue.Changed:Connect(sincronizarComCarro)

interface.AncestryChanged:Connect(function(_, parent)
	if parent == nil and ecuCon then
		ecuCon:Disconnect()
		ecuCon = nil
	end
end)
