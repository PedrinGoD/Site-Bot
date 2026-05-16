-- CH Corporations - Posto de gasolina (servidor) — Script no Model do posto
-- Revisão: EventosPosto/AcaoPosto com timeout; RemoteEvent validado; prompts com debounce;
--          abastecimento em task.spawn (não tranca o handler); uma sessão por jogador;
--          valida Model, Combustivel, Dinheiro IntValue; custo em inteiros; dono ^(.+)sCar$;
--          loop verifica carro/parent; save com pcall; aviso se sentado no assento.

print("CH Corporations - Posto gasolina servidor (save — revisão)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WAIT_INST = 25
local DEBOUNCE_PROMPT = 0.4

local PRECO_POR_PERCENTUAL = 5.26
local RAIO_DE_BUSCA = 20
local VELOCIDADE_ABASTECIMENTO = 0.5
local TICK_ABASTECIMENTO = 0.1
local MAX_COMBUSTIVEL = 100

local postoModel = script.Parent
if not postoModel or not postoModel:IsA("Model") then
	warn("[Posto] script.Parent deve ser um Model.")
	return
end

local pastaEventos = ReplicatedStorage:WaitForChild("EventosPosto", WAIT_INST)
if not pastaEventos then
	warn("[Posto] EventosPosto em falta.")
	return
end

local eventoPosto = pastaEventos:WaitForChild("AcaoPosto", WAIT_INST)
if not eventoPosto or not eventoPosto:IsA("RemoteEvent") then
	warn("[Posto] AcaoPosto (RemoteEvent) em falta ou inválido.")
	return
end

local abastecimentoAtivo = {}
local ultimoPrompt = {}
local ultimaBombaPorPlayer = {}

local function extrairNomeDonoCarro(modelo)
	return string.match(modelo.Name, "^(.+)sCar$")
end

local function obterCombustivel(carro)
	local v = carro:GetAttribute("Combustivel")
	return tonumber(v) or 0
end

local function acharCarroProximo(bombaPos)
	local carroMaisProximo = nil
	local menorDistancia = math.huge

	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("Combustivel") ~= nil then
			local parteRef = obj.PrimaryPart or obj:FindFirstChild("DriveSeat") or obj:FindFirstChildWhichIsA("BasePart")
			if parteRef and parteRef:IsA("BasePart") then
				local distancia = (parteRef.Position - bombaPos).Magnitude
				if distancia <= RAIO_DE_BUSCA and distancia < menorDistancia then
					menorDistancia = distancia
					carroMaisProximo = obj
				end
			end
		end
	end
	return carroMaisProximo
end

local function obterDinheiro(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local d = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	if d and d:IsA("IntValue") then
		return d
	end
	return nil
end

local function salvarCombustivelNoInventario(carro)
	local nomeDono = extrairNomeDonoCarro(carro)
	if not nomeDono then
		return
	end
	local donoDoCarro = Players:FindFirstChild(nomeDono)
	if not donoDoCarro then
		return
	end
	local inventario = donoDoCarro:FindFirstChild("InventarioVeiculos")
	local modeloOriginal = carro:GetAttribute("ModeloOriginal")
	if typeof(modeloOriginal) ~= "string" or not inventario then
		return
	end
	local carroSave = inventario:FindFirstChild(modeloOriginal)
	if not carroSave then
		return
	end
	local nivel = obterCombustivel(carro)
	pcall(function()
		carroSave:SetAttribute("CombustivelSalvo", nivel)
	end)
	print("[Posto] CombustivelSalvo atualizado: " .. modeloOriginal .. " → " .. math.floor(nivel))
end

local function executarAbastecimento(player, carro)
	local dinheiro = obterDinheiro(player)
	if not dinheiro then
		return
	end

	local precoPorTick = PRECO_POR_PERCENTUAL * VELOCIDADE_ABASTECIMENTO
	local custoPorTick = math.max(1, math.ceil(precoPorTick))

	while carro.Parent and player.Parent do
		local comb = obterCombustivel(carro)
		if comb >= MAX_COMBUSTIVEL then
			break
		end

		if dinheiro.Value >= custoPorTick then
			local novo = math.min(comb + VELOCIDADE_ABASTECIMENTO, MAX_COMBUSTIVEL)
			local saldoAntes = dinheiro.Value
			dinheiro.Value = saldoAntes - custoPorTick
			if dinheiro.Value < 0 then
				dinheiro.Value = saldoAntes
				break
			end
			pcall(function()
				carro:SetAttribute("Combustivel", novo)
			end)
		elseif dinheiro.Value > 0 then
			local fracao = dinheiro.Value / PRECO_POR_PERCENTUAL
			pcall(function()
				dinheiro.Value = 0
				carro:SetAttribute("Combustivel", math.min(comb + fracao, MAX_COMBUSTIVEL))
			end)
			break
		else
			break
		end

		task.wait(TICK_ABASTECIMENTO)
	end

	salvarCombustivelNoInventario(carro)
end

local function carroPertoDaBomba(carro, bomba)
	if not bomba or not bomba.Parent or not bomba:IsA("BasePart") then
		return false
	end
	local parteRef = carro.PrimaryPart or carro:FindFirstChild("DriveSeat") or carro:FindFirstChildWhichIsA("BasePart")
	if not parteRef or not parteRef:IsA("BasePart") then
		return false
	end
	return (parteRef.Position - bomba.Position).Magnitude <= RAIO_DE_BUSCA + 2
end

eventoPosto.OnServerEvent:Connect(function(player, acao, carro)
	if not player or not player:IsA("Player") then
		return
	end
	if acao ~= "Iniciar" then
		return
	end
	if typeof(carro) ~= "Instance" or not carro:IsA("Model") then
		return
	end
	if carro:GetAttribute("Combustivel") == nil then
		return
	end
	if abastecimentoAtivo[player] then
		return
	end

	local bombaRef = ultimaBombaPorPlayer[player]
	if not carroPertoDaBomba(carro, bombaRef) then
		pcall(function()
			eventoPosto:FireClient(player, "Aviso", "Veículo longe da bomba.")
		end)
		return
	end

	abastecimentoAtivo[player] = true

	task.spawn(function()
		pcall(function()
			executarAbastecimento(player, carro)
		end)
		abastecimentoAtivo[player] = nil
		pcall(function()
			eventoPosto:FireClient(player, "Fechar")
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	abastecimentoAtivo[p] = nil
	ultimoPrompt[p] = nil
	ultimaBombaPorPlayer[p] = nil
end)

for _, bomba in ipairs(postoModel:GetChildren()) do
	if bomba:IsA("BasePart") then
		local prompt = bomba:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if not player or not player:IsA("Player") then
					return
				end

				local agora = os.clock()
				if ultimoPrompt[player] and (agora - ultimoPrompt[player]) < DEBOUNCE_PROMPT then
					return
				end
				ultimoPrompt[player] = agora

				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if humanoid and humanoid.SeatPart then
					pcall(function()
						eventoPosto:FireClient(player, "Aviso", "Você deve descer do veículo para abastecer!")
					end)
					return
				end

				ultimaBombaPorPlayer[player] = bomba

				local carro = acharCarroProximo(bomba.Position)
				if carro then
					pcall(function()
						eventoPosto:FireClient(player, "Abrir", carro, PRECO_POR_PERCENTUAL)
					end)
				else
					pcall(function()
						eventoPosto:FireClient(player, "Aviso", "Aproxime mais o veículo da bomba!")
					end)
				end
			end)
		end
	end
end
