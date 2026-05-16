-- CH Corporations - Loja galão gasolina (servidor) — Script na Part de venda (filho do Model na Workspace)
-- Revisão: ProximityPrompt com timeout; valida jogador, IntValue Dinheiro e Tool no ServerStorage;
--          inventário máx. 3 tools; debita só após checagens; reembolso se clone/parent falhar;
--          recibo em pcall; debounce; AvisoInventario resolvido uma vez.

print("CH Corporations - Loja galão gasolina (revisão c/ save)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WAIT_INST = 25
local DEBOUNCE_COMPRA = 0.6

local PRECO_GALAO = 200
local NOME_DA_TOOL = "Gasolina5l"

local vendaPart = script.Parent
if not vendaPart or not vendaPart:IsA("BasePart") then
	warn("[LojaGalao] script.Parent deve ser uma BasePart de venda.")
	return
end

local prompt = vendaPart:WaitForChild("ProximityPrompt", WAIT_INST)
if not prompt or not prompt:IsA("ProximityPrompt") then
	warn("[LojaGalao] ProximityPrompt em falta ou inválido.")
	return
end

local avisoInventarioEvent = ReplicatedStorage:WaitForChild("AvisoInventarioEvent", WAIT_INST)
if avisoInventarioEvent and not avisoInventarioEvent:IsA("RemoteEvent") then
	warn("[LojaGalao] AvisoInventarioEvent não é RemoteEvent.")
	avisoInventarioEvent = nil
end

local galaoOriginal = ServerStorage:WaitForChild(NOME_DA_TOOL, WAIT_INST)
if not galaoOriginal or not galaoOriginal:IsA("Tool") then
	warn("[LojaGalao] ServerStorage." .. NOME_DA_TOOL .. " em falta ou não é Tool — script desativado.")
	return
end

local ultimaCompra = {}

Players.PlayerRemoving:Connect(function(p)
	ultimaCompra[p] = nil
end)

local function contarTools(jogador)
	local total = 0
	local backpack = jogador:FindFirstChild("Backpack")
	local character = jogador.Character

	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				total += 1
			end
		end
	end
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") then
				total += 1
			end
		end
	end
	return total
end

local function inventarioCheio(jogador)
	return contarTools(jogador) >= 3
end

local function obterDinheiro(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local dinheiro = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	if dinheiro and (dinheiro:IsA("IntValue") or dinheiro:IsA("NumberValue")) then
		return dinheiro
	end
	return nil
end

prompt.Triggered:Connect(function(player)
	if not player or not player:IsA("Player") then
		return
	end

	local agora = os.clock()
	if ultimaCompra[player] and (agora - ultimaCompra[player]) < DEBOUNCE_COMPRA then
		return
	end

	if inventarioCheio(player) then
		if avisoInventarioEvent then
			avisoInventarioEvent:FireClient(player)
		end
		warn("[LojaGalao] Mochila cheia: " .. player.Name)
		return
	end

	local dinheiro = obterDinheiro(player)
	if not dinheiro then
		warn("[LojaGalao] leaderstats.Dinheiro (IntValue ou NumberValue) em falta: " .. player.Name)
		return
	end

	if dinheiro.Value < PRECO_GALAO then
		warn("[LojaGalao] Dinheiro insuficiente: " .. player.Name)
		return
	end

	ultimaCompra[player] = agora

	local saldoAntes = dinheiro.Value
	dinheiro.Value = saldoAntes - PRECO_GALAO
	if dinheiro.Value < 0 then
		dinheiro.Value = saldoAntes
		warn("[LojaGalao] Débito inválido — revertido.")
		return
	end

	local okClone, novoGalao = pcall(function()
		return galaoOriginal:Clone()
	end)
	if not okClone or not novoGalao then
		dinheiro.Value = saldoAntes
		warn("[LojaGalao] Falha ao clonar — reembolsado: " .. player.Name)
		return
	end

	local bp = player:FindFirstChild("Backpack")
	local okParent = false
	if bp then
		okParent = pcall(function()
			novoGalao.Parent = bp
		end)
	end
	if not okParent then
		pcall(function()
			novoGalao:Destroy()
		end)
		dinheiro.Value = saldoAntes
		warn("[LojaGalao] Backpack em falta ou parent falhou — reembolsado: " .. player.Name)
		return
	end

	local inventarioFerramentas = player:FindFirstChild("InventarioFerramentas")
	if inventarioFerramentas then
		local okRecibo, err = pcall(function()
			local novoRecord = Instance.new("StringValue")
			novoRecord.Name = NOME_DA_TOOL
			novoRecord.Value = "Comprada"
			novoRecord.Parent = inventarioFerramentas
		end)
		if okRecibo then
			print("[LojaGalao] Recibo save: " .. NOME_DA_TOOL .. " — " .. player.Name)
		else
			warn("[LojaGalao] Recibo não criado:", err)
		end
	end

	print("[LojaGalao] " .. player.Name .. " comprou galão por $" .. PRECO_GALAO)
end)
