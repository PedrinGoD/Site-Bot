-- CH Corporations - Servidor de uso de galões (Save Master V2)
-- Revisão: timeout no RemoteEvent; validação de instâncias; distância e dono; loop de ancestral com limite;
--          debounce; combustível tipado; destruir tool/registo com pcall.

print("CH Corporations - Servidor de Uso de Galões (Atualizado c/ Save Master V2) Carregado")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local usarEvento = ReplicatedStorage:WaitForChild("UsarGalaoEvent", 60)
if not usarEvento then
	warn("[UsarGalao] UsarGalaoEvent não encontrado.")
	return
end

local NOME_TOOL = "Gasolina5l"
local QUANTIDADE_LITROS = 5
local RAIO_ABASTECIMENTO = 15
local MAX_PROFUNDIDADE_ANCESTRAL = 40
local DEBOUNCE_SEG = 0.4

local ultimoUso = {}

local function numeroValido(n)
	return type(n) == "number" and n == n and math.abs(n) ~= math.huge
end

local function comoNumeroCombustivel(v)
	if v == nil then
		return nil
	end
	if type(v) == "number" then
		return v
	end
	return tonumber(v)
end

local function encontrarCarroComTanque(parteInicial)
	local atual = parteInicial
	local prof = 0
	while atual and atual ~= Workspace and prof < MAX_PROFUNDIDADE_ANCESTRAL do
		if atual:IsA("Model") then
			local comb = comoNumeroCombustivel(atual:GetAttribute("Combustivel"))
			if comb ~= nil and numeroValido(comb) then
				return atual
			end
		end
		atual = atual.Parent
		prof += 1
	end
	return nil
end

local function referenciaDistancia(carro, alvoClicado)
	if carro:IsA("Model") then
		if carro.PrimaryPart then
			return carro.PrimaryPart
		end
		local seat = carro:FindFirstChildWhichIsA("VehicleSeat", true)
		if seat then
			return seat
		end
	end
	if alvoClicado:IsA("BasePart") then
		return alvoClicado
	end
	return carro:FindFirstChildWhichIsA("BasePart", true)
end

usarEvento.OnServerEvent:Connect(function(player, alvoClicado, tool)
	local uid = player.UserId
	local agora = os.clock()
	if ultimoUso[uid] and (agora - ultimoUso[uid]) < DEBOUNCE_SEG then
		return
	end

	local char = player.Character
	if not char then
		return
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if typeof(alvoClicado) ~= "Instance" or not alvoClicado:IsDescendantOf(Workspace) then
		return
	end
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return
	end
	if tool.Name ~= NOME_TOOL then
		return
	end
	if tool.Parent ~= char then
		return
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local carroClicado = encontrarCarroComTanque(alvoClicado)
	if not carroClicado then
		warn("⚠️ Clique na lataria do seu carro para abastecer!")
		return
	end

	local parteRef = referenciaDistancia(carroClicado, alvoClicado)
	if parteRef and parteRef:IsA("BasePart") then
		local distancia = (parteRef.Position - hrp.Position).Magnitude
		if distancia > RAIO_ABASTECIMENTO then
			warn("⚠️ " .. player.Name .. ", chegue mais perto do veículo para usar o galão!")
			return
		end
	end

	local nomeDoCarroEsperado = player.Name .. "sCar"
	if carroClicado.Name ~= nomeDoCarroEsperado then
		warn("⛔ Você só pode abastecer o seu próprio veículo (" .. nomeDoCarroEsperado .. ")!")
		return
	end

	local combustivelAtual = comoNumeroCombustivel(carroClicado:GetAttribute("Combustivel"))
	if not numeroValido(combustivelAtual) then
		return
	end

	local maxCombustivel = 100
	local novoCombustivel = math.clamp(combustivelAtual + QUANTIDADE_LITROS, 0, maxCombustivel)
	carroClicado:SetAttribute("Combustivel", novoCombustivel)

	ultimoUso[uid] = agora

	print("🛢️ " .. player.Name .. " abasteceu " .. QUANTIDADE_LITROS .. "L no próprio carro.")

	local inventario = player:FindFirstChild("InventarioVeiculos")
	local modeloOriginal = carroClicado:GetAttribute("ModeloOriginal")
	if type(modeloOriginal) == "string" and modeloOriginal ~= "" and inventario then
		local carroSave = inventario:FindFirstChild(modeloOriginal)
		if carroSave then
			carroSave:SetAttribute("CombustivelSalvo", novoCombustivel)
		end
	end

	local invFerramentas = player:FindFirstChild("InventarioFerramentas")
	if invFerramentas then
		local recordUsado = invFerramentas:FindFirstChild(NOME_TOOL)
		if recordUsado then
			pcall(function()
				recordUsado:Destroy()
			end)
			print("🔥 Recibo do galão removido do inventário salvo.")
		end
	end

	pcall(function()
		tool:Destroy()
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	ultimoUso[player.UserId] = nil
end)
