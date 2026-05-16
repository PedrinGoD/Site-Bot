-- CH Corporations - Consumo de combustível (servidor) — Script no Model do veículo (ex.: SistemaCombustivel)
-- Revisão: espera ModeloOriginal (poll + GetAttributeChanged); aviso só se estiver no Workspace;
--          dono NomesCar; DriveSeat; vincula InventarioVeiculos com retentativas; clamp 0..max; Destroying limpa sinais.

print("CH Corporations - Sistema combustível (save inventário — revisão)")

local Players = game:GetService("Players")

local carro = script.Parent
if not carro or not carro:IsA("Model") then
	warn("[Combustivel] script.Parent deve ser o Model do carro.")
	return
end

local WAIT_DRIVE_SEAT = 30
local WAIT_MODELO_ATTR = 45
local POLL_ATTR = 0.1
local RETRY_VINCULAR = 0.5
local MAX_TENTATIVAS_VINCULAR = 120

local maxCombustivel = 100
local consumoPorSegundo = 0.2
local VELOCIDADE_MINIMA = 5

local driveSeat = carro:WaitForChild("DriveSeat", WAIT_DRIVE_SEAT)
if not driveSeat or (not driveSeat:IsA("VehicleSeat") and not driveSeat:IsA("Seat")) then
	warn("[Combustivel] DriveSeat em falta ou não é VehicleSeat/Seat.")
	return
end

local function extrairNomeDono()
	local nome = carro.Name
	local dono = string.match(nome, "^(.+)sCar$")
	return dono
end

local function lerModeloOriginalOK()
	local m = carro:GetAttribute("ModeloOriginal")
	if typeof(m) == "string" and #m > 0 then
		return m
	end
	return nil
end

-- Espera o atributo (o spawn costuma SetAttribute no mesmo frame em que parenta; LoadAsset pode correr este script antes).
local function esperarModeloOriginal()
	local limite = os.clock() + WAIT_MODELO_ATTR
	while carro.Parent and os.clock() < limite do
		if lerModeloOriginalOK() then
			return lerModeloOriginalOK()
		end
		task.wait(POLL_ATTR)
	end
	return lerModeloOriginalOK()
end

esperarModeloOriginal()

-- Templates em ServerStorage/ReplicatedStorage nunca têm ModeloOriginal: não avisar (evita spam por cópia do modelo).
if not lerModeloOriginalOK() and carro:IsDescendantOf(Workspace) then
	warn(
		"[Combustivel] ModeloOriginal não definido a tempo — tanque só no veículo (não sincroniza com InventarioVeiculos). "
			.. "O spawn deve fazer SetAttribute(\"ModeloOriginal\", nomeDaStringValueDoCarro) no Model antes ou logo após Parent = Workspace."
	)
end

local conexaoCombustivel = nil
local saveJaVinculado = false

local function desligarEscutaCombustivel()
	if conexaoCombustivel then
		pcall(function()
			conexaoCombustivel:Disconnect()
		end)
		conexaoCombustivel = nil
	end
	saveJaVinculado = false
end

carro.Destroying:Connect(function()
	desligarEscutaCombustivel()
end)

local function vincularSave(player, carroSave, nomeModeloLog)
	if saveJaVinculado or not carroSave or not carro.Parent then
		return
	end

	saveJaVinculado = true

	local salvo = tonumber(carroSave:GetAttribute("CombustivelSalvo"))
	if salvo == nil then
		salvo = maxCombustivel
	end
	salvo = math.clamp(salvo, 0, maxCombustivel)
	carro:SetAttribute("Combustivel", salvo)

	print("[Combustivel] Tanque " .. tostring(nomeModeloLog) .. " → " .. math.floor(salvo) .. "% (" .. player.Name .. ")")

	conexaoCombustivel = carro:GetAttributeChangedSignal("Combustivel"):Connect(function()
		if not carro.Parent or not carroSave.Parent then
			return
		end
		local nivelAtual = tonumber(carro:GetAttribute("Combustivel"))
		if nivelAtual == nil then
			return
		end
		nivelAtual = math.clamp(nivelAtual, 0, maxCombustivel)
		pcall(function()
			carroSave:SetAttribute("CombustivelSalvo", nivelAtual)
		end)
	end)
end

local function tentarVincular()
	if saveJaVinculado then
		return false
	end

	local modeloAlvo = lerModeloOriginalOK()
	if not modeloAlvo then
		return false
	end

	local nomeDono = extrairNomeDono()
	if not nomeDono then
		warn("[Combustivel] Nome do carro não segue o padrão NomesCar: " .. carro.Name)
		return false
	end

	local player = Players:FindFirstChild(nomeDono)
	if not player or not player:IsA("Player") then
		return false
	end

	local inventario = player:FindFirstChild("InventarioVeiculos")
	if not inventario then
		return false
	end

	local carroSave = inventario:FindFirstChild(modeloAlvo)
	if not carroSave then
		return false
	end

	vincularSave(player, carroSave, modeloAlvo)
	return true
end

carro:GetAttributeChangedSignal("ModeloOriginal"):Connect(function()
	task.defer(tentarVincular)
end)

if not tentarVincular() then
	if not carro:GetAttribute("Combustivel") then
		carro:SetAttribute("Combustivel", maxCombustivel)
	end
	local nomeDono = extrairNomeDono()
	if nomeDono then
		Players.PlayerAdded:Connect(function(p)
			if p.Name ~= nomeDono then
				return
			end
			p.ChildAdded:Connect(function(ch)
				if ch.Name == "InventarioVeiculos" then
					task.defer(tentarVincular)
				end
			end)
			task.defer(tentarVincular)
		end)

		local existente = Players:FindFirstChild(nomeDono)
		if existente then
			existente.ChildAdded:Connect(function(ch)
				if ch.Name == "InventarioVeiculos" then
					task.defer(tentarVincular)
				end
			end)
		end

		task.spawn(function()
			for _ = 1, MAX_TENTATIVAS_VINCULAR do
				if not carro.Parent then
					return
				end
				if tentarVincular() then
					return
				end
				task.wait(RETRY_VINCULAR)
			end
			if lerModeloOriginalOK() and carro:IsDescendantOf(Workspace) then
				warn("[Combustivel] Não foi possível vincular ao inventário a tempo: " .. tostring(carro.Name))
			end
		end)
	end
end

while carro.Parent do
	task.wait(1)

	local combustivelAtual = tonumber(carro:GetAttribute("Combustivel")) or 0
	combustivelAtual = math.clamp(combustivelAtual, 0, maxCombustivel)

	local ocupante = driveSeat.Occupant
	if ocupante and combustivelAtual > 0 then
		local velocidade = driveSeat.AssemblyLinearVelocity.Magnitude
		if velocidade > VELOCIDADE_MINIMA then
			local novo = math.clamp(combustivelAtual - consumoPorSegundo, 0, maxCombustivel)
			carro:SetAttribute("Combustivel", novo)
		end
	end
end
