-- CH Corporations - Shop tintas físico (servidor) — Script no Model da loja na Workspace
-- Revisão: WaitForChild com timeout; RemoteEvents validados; OnServerEvent checa tipos e jogador;
--          dinheiro com IntValue e sem negativar; reembolso se spawn falhar; AvisoInventario sem Wait infinito;
--          beam: limpa Attachment no HRP ao destruir a lata; mesas: só latas relevantes (nome + raio);
--          clone/parent em pcall; debounce curto por jogador na compra.

print("CH Corporations - Shop tintas físico (revisão: limites, auto-equipar, beam)")

local lojaModel = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local WAIT_INST = 25
local DEBOUNCE_COMPRA = 0.6
local RAIO_MESA_OCUPADA = 3

local PRECO_COMUM = 100
local PRECO_CUSTOM = 350

local NOME_LATA_WORKSPACE = "LataFisicaSpawnada"
local NOME_PART_LATA = "Lata"

if not lojaModel or not lojaModel:IsA("Model") then
	warn("[ShopTintas] script.Parent deve ser um Model da loja.")
	return
end

local comprarEvento = ReplicatedStorage:WaitForChild("ComprarTintaEvent", WAIT_INST)
local abrirEvento = ReplicatedStorage:WaitForChild("AbrirLojaTintasEvent", WAIT_INST)

if not comprarEvento or not comprarEvento:IsA("RemoteEvent") then
	warn("[ShopTintas] ComprarTintaEvent em falta ou inválido.")
	return
end
if not abrirEvento or not abrirEvento:IsA("RemoteEvent") then
	warn("[ShopTintas] AbrirLojaTintasEvent em falta ou inválido.")
	return
end

local avisoInventarioEvent = ReplicatedStorage:WaitForChild("AvisoInventarioEvent", WAIT_INST)
if avisoInventarioEvent and not avisoInventarioEvent:IsA("RemoteEvent") then
	warn("[ShopTintas] AvisoInventarioEvent existe mas não é RemoteEvent.")
	avisoInventarioEvent = nil
end

local compraPart = lojaModel:WaitForChild("Compra", WAIT_INST)
if not compraPart or not compraPart:IsA("BasePart") then
	warn("[ShopTintas] Part 'Compra' em falta ou inválida.")
	return
end

local promptBalcao = compraPart:WaitForChild("ProximityPrompt", WAIT_INST)
if not promptBalcao or not promptBalcao:IsA("ProximityPrompt") then
	warn("[ShopTintas] ProximityPrompt do balcão em falta.")
	return
end

local spawnsDeMesa = {}
for _, nome in ipairs({ "LocalSpawn1", "LocalSpawn2", "LocalSpawn3" }) do
	local p = lojaModel:WaitForChild(nome, WAIT_INST)
	if p and p:IsA("BasePart") then
		table.insert(spawnsDeMesa, p)
	else
		warn("[ShopTintas] Spawn em falta ou não é BasePart: " .. nome)
	end
end

if #spawnsDeMesa == 0 then
	warn("[ShopTintas] Nenhum LocalSpawn válido — script desativado.")
	return
end

local lataTemplate = ServerStorage:WaitForChild("LataSpray", WAIT_INST)
if not lataTemplate then
	warn("[ShopTintas] ServerStorage.LataSpray em falta.")
	return
end

local toolTemplate = ServerStorage:FindFirstChild("TintaSpray")
if not toolTemplate then
	warn("[ShopTintas] ServerStorage.TintaSpray em falta — pegar na mesa pode falhar.")
end

local ultimaCompra = {}

Players.PlayerRemoving:Connect(function(p)
	ultimaCompra[p] = nil
end)

local function contarToolsNoJogador(jogador)
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
	return contarToolsNoJogador(jogador) >= 3
end

local function posicaoLataNoObj(obj)
	local lataMesh = obj:FindFirstChild(NOME_PART_LATA)
	if lataMesh and lataMesh:IsA("BasePart") then
		return lataMesh.Position
	end
	local any = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
	if any and any:IsA("BasePart") then
		return any.Position
	end
	return nil
end

local mesasReservadas = {}

local function mesaTemLataNoMapa(spot)
	if not spot or not spot:IsA("BasePart") then
		return true
	end
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj.Name == NOME_LATA_WORKSPACE then
			local pos = posicaoLataNoObj(obj)
			if pos and (pos - spot.Position).Magnitude < RAIO_MESA_OCUPADA then
				return true
			end
		end
	end
	return false
end

local function mesaEstaOcupada(spot)
	if mesasReservadas[spot] then
		return true
	end
	return mesaTemLataNoMapa(spot)
end

local function libertarMesa(spot)
	mesasReservadas[spot] = nil
end

local function acharMesaLivre()
	for _, spot in ipairs(spawnsDeMesa) do
		if not mesaEstaOcupada(spot) then
			mesasReservadas[spot] = true
			return spot
		end
	end
	return nil
end

local function obterDinheiro(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local dinheiro = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	if dinheiro and dinheiro:IsA("IntValue") then
		return dinheiro
	end
	return nil
end

--- Beam guia: Attachment0 no HRP, Attachment1 na lata; ao destruir a lata, remove o que ficou no personagem.
local function criarGuiaVisualColorido(jogador, caixa, cor)
	local character = jogador.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local pecaPrincipal = caixa:IsA("Model") and (caixa.PrimaryPart or caixa:FindFirstChildWhichIsA("BasePart")) or caixa

	if not hrp or not pecaPrincipal or not pecaPrincipal:IsA("BasePart") then
		return
	end

	local attCaixa = Instance.new("Attachment")
	attCaixa.Name = "ShopTintas_AttCaixa"
	attCaixa.Parent = pecaPrincipal

	local attPlayer = Instance.new("Attachment")
	attPlayer.Name = "ShopTintas_AttPlayer"
	attPlayer.Parent = hrp

	local beam = Instance.new("Beam")
	beam.Name = "ShopTintas_Beam"
	beam.Attachment0 = attPlayer
	beam.Attachment1 = attCaixa
	beam.Color = ColorSequence.new(cor)
	beam.FaceCamera = true
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.Transparency = NumberSequence.new(0.5)
	beam.Parent = pecaPrincipal

	local function limparDoPersonagem()
		if attPlayer and attPlayer.Parent then
			pcall(function()
				attPlayer:Destroy()
			end)
		end
	end

	caixa.Destroying:Connect(limparDoPersonagem)
end

promptBalcao.Triggered:Connect(function(player)
	if not player or not player:IsA("Player") then
		return
	end
	abrirEvento:FireClient(player)
end)

comprarEvento.OnServerEvent:Connect(function(player, corEscolhida, ehCorCustomizada)
	if not player or not player:IsA("Player") then
		return
	end

	local agora = os.clock()
	if ultimaCompra[player] and (agora - ultimaCompra[player]) < DEBOUNCE_COMPRA then
		return
	end

	if typeof(corEscolhida) ~= "Color3" then
		return
	end

	local corCustomizada = ehCorCustomizada == true

	ultimaCompra[player] = agora

	local mesaLivre = acharMesaLivre()
	if not mesaLivre then
		warn("[ShopTintas] Mesas de entrega cheias — " .. player.Name)
		return
	end

	local function abortarComReserva()
		libertarMesa(mesaLivre)
	end

	local dinheiro = obterDinheiro(player)
	if not dinheiro then
		warn("[ShopTintas] leaderstats.Dinheiro em falta para " .. player.Name)
		return
	end

	local precoCobrado = corCustomizada and PRECO_CUSTOM or PRECO_COMUM
	if dinheiro.Value < precoCobrado then
		abortarComReserva()
		warn("[ShopTintas] Dinheiro insuficiente: " .. player.Name)
		return
	end

	local saldoAntes = dinheiro.Value
	dinheiro.Value = saldoAntes - precoCobrado
	if dinheiro.Value < 0 then
		dinheiro.Value = saldoAntes
		abortarComReserva()
		warn("[ShopTintas] Valor inválido ao debitar — revertido.")
		return
	end

	local okClone, novaLataFisica = pcall(function()
		return lataTemplate:Clone()
	end)

	if not okClone or not novaLataFisica then
		dinheiro.Value = saldoAntes
		abortarComReserva()
		warn("[ShopTintas] Falha ao clonar LataSpray — reembolsado " .. player.Name)
		return
	end

	novaLataFisica.Name = NOME_LATA_WORKSPACE

	local lataMesh = novaLataFisica:FindFirstChild(NOME_PART_LATA)
	local alturaLata = (lataMesh and lataMesh:IsA("BasePart")) and (lataMesh.Size.Y / 2) or 1

	local okPivot = pcall(function()
		novaLataFisica:PivotTo(mesaLivre.CFrame * CFrame.new(0, alturaLata + (mesaLivre.Size.Y / 2), 0))
	end)
	if not okPivot then
		pcall(function()
			novaLataFisica:Destroy()
		end)
		dinheiro.Value = saldoAntes
		abortarComReserva()
		warn("[ShopTintas] Falha no PivotTo — reembolsado " .. player.Name)
		return
	end

	pcall(function()
		novaLataFisica.Parent = Workspace
	end)

	criarGuiaVisualColorido(player, novaLataFisica, corEscolhida)

	local promptPegar = lataMesh and lataMesh:FindFirstChildWhichIsA("ProximityPrompt")
	if not promptPegar then
		warn("[ShopTintas] ProximityPrompt na lata em falta — devolvendo dinheiro.")
		pcall(function()
			novaLataFisica:Destroy()
		end)
		dinheiro.Value = saldoAntes
		abortarComReserva()
		return
	end

	novaLataFisica.Destroying:Connect(function()
		libertarMesa(mesaLivre)
	end)

	promptPegar.ActionText = "Pegar Tinta"
	promptPegar.ObjectText = "TintaSpray"

	promptPegar.Triggered:Connect(function(playerQuePegou)
		if not playerQuePegou or not playerQuePegou:IsA("Player") then
			return
		end
		if playerQuePegou.UserId ~= player.UserId then
			warn("[ShopTintas] Lata de outro jogador — comprador: " .. player.Name)
			return
		end

		if inventarioCheio(playerQuePegou) then
			if avisoInventarioEvent then
				avisoInventarioEvent:FireClient(playerQuePegou)
			end
			return
		end

		if not toolTemplate then
			return
		end

		local okTool, novaTool = pcall(function()
			return toolTemplate:Clone()
		end)
		if not okTool or not novaTool then
			return
		end

		local corValue = Instance.new("Color3Value")
		corValue.Name = "CorDaTinta"
		corValue.Value = corEscolhida
		corValue.Parent = novaTool

		local bp = playerQuePegou:FindFirstChild("Backpack")
		if bp then
			novaTool.Parent = bp
		else
			novaTool.Parent = playerQuePegou
		end

		local invJogador = playerQuePegou:FindFirstChild("InventarioFerramentas")
		if invJogador then
			local r = math.floor(corEscolhida.R * 255)
			local g = math.floor(corEscolhida.G * 255)
			local b = math.floor(corEscolhida.B * 255)
			local corString = r .. "," .. g .. "," .. b

			pcall(function()
				local novoRecord = Instance.new("StringValue")
				novoRecord.Name = "TintaSpray"
				novoRecord.Value = corString
				novoRecord.Parent = invJogador
			end)
		end

		local character = playerQuePegou.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				pcall(function()
					humanoid:EquipTool(novaTool)
				end)
			end
		end

		pcall(function()
			novaLataFisica:Destroy()
		end)

		print("[ShopTintas] " .. playerQuePegou.Name .. " pegou a lata (equipada se possível).")
	end)

	print("[ShopTintas] Lata na mesa para " .. player.Name)
end)
