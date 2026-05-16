-- CH Corporations - Sistema de encontros / lobby + votação (servidor) — Script no Model "Encontro"
-- Revisão: WaitForChild com timeout; valida BasePart/GUIs; RemoteEvents garantidos e tipados;
--          mutex ao iniciar votação (evita duplo spawn); votos só de quem está na área e mapa válido;
--          física com pcall; loop 0,5s mais leve (só jogadores com grupo especial ou na lista); Touched com debounce;
--          limpeza em PlayerRemoving; atributos Min/Max com tonumber.

print("CH Corporations - Encontros (física + abortar votação — revisão)")

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WAIT_INST = 25
local LOOP_INTERVAL = 0.5
local TEMPO_VOTACAO = 20
local DEBOUNCE_TOQUE_BARREIRA = 0.35

local Encontro = script.Parent
if not Encontro or not Encontro:IsA("Model") then
	warn("[Encontros] script.Parent deve ser um Model.")
	return
end

local Area = Encontro:WaitForChild("Area", WAIT_INST)
local Barreira = Encontro:WaitForChild("Barreira", WAIT_INST)

if not Area or not Area:IsA("BasePart") then
	warn("[Encontros] 'Area' em falta ou não é BasePart.")
	return
end
if not Barreira or not Barreira:IsA("BasePart") then
	warn("[Encontros] 'Barreira' em falta ou não é BasePart.")
	return
end

local billboardPlayers = Area:WaitForChild("Players", WAIT_INST)
local txtQuantidade = billboardPlayers and billboardPlayers:WaitForChild("Quantidade", WAIT_INST)
local billboardAguardo = Area:WaitForChild("Aguardo", WAIT_INST)
local txtStatus = billboardAguardo and billboardAguardo:WaitForChild("TextLabel", WAIT_INST)

if not txtQuantidade or not txtQuantidade:IsA("TextLabel") then
	warn("[Encontros] Quantidade (TextLabel) em falta.")
	return
end
if not txtStatus or not txtStatus:IsA("TextLabel") then
	warn("[Encontros] Aguardo/TextLabel em falta.")
	return
end

local playersNaArea = {}
local votacaoAtiva = false
local votacaoEmExecucao = false
local votos = {}
local passeLivreFantasmas = {}
local ultimoToqueBarreira = {}

local function criarEvento(nome)
	local ev = ReplicatedStorage:FindFirstChild(nome)
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = nome
		ev.Parent = ReplicatedStorage
	elseif not ev:IsA("RemoteEvent") then
		warn("[Encontros] '" .. nome .. "' existe mas não é RemoteEvent.")
		return nil
	end
	return ev
end

local evAbrirVotacao = criarEvento("AbrirVotacaoEvent")
local evVoto = criarEvento("VotarMapaEvent")
local evResultado = criarEvento("ResultadoVotacaoEvent")
local evCancelarVotacao = criarEvento("CancelarVotacaoEvent")

if not evAbrirVotacao or not evVoto or not evResultado or not evCancelarVotacao then
	warn("[Encontros] Eventos em falta — script desativado.")
	return
end

local TODAS_AS_PISTAS = {
	Pista1 = { Nome = "Circuito Neon", Imagem = "rbxassetid://12345678", PlaceID = 118420498978743 },
	Pista2 = { Nome = "Drift na Montanha", Imagem = "rbxassetid://23456789", PlaceID = 121966200502276 },
	Pista3 = { Nome = "Cidade Subterrânea", Imagem = "rbxassetid://34567890", PlaceID = 134623064745400 },
}

local function mapaValido(idMapa)
	return typeof(idMapa) == "string" and TODAS_AS_PISTAS[idMapa] ~= nil
end

pcall(function()
	PhysicsService:RegisterCollisionGroup("CapaLobby")
end)
pcall(function()
	PhysicsService:RegisterCollisionGroup("JogadoresPermitidos")
end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable("CapaLobby", "JogadoresPermitidos", false)
end)

Barreira.CollisionGroup = "CapaLobby"
Barreira.CanCollide = true
Area.CanCollide = false

local function setCharacterCollisionGroup(character, groupName)
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.CollisionGroup = groupName
			end)
		end
	end
end

local function isPlayerEligible(player)
	local inventario = player:FindFirstChild("InventarioVeiculos")
	return inventario ~= nil and #inventario:GetChildren() > 0
end

local function jogadorNaListaArea(player)
	for _, p in ipairs(playersNaArea) do
		if p == player then
			return true
		end
	end
	return false
end

local function getJogadoresNaArea()
	local jogadoresDentro = {}
	local personagensEncontrados = {}
	local ok, partesNaArea = pcall(function()
		return Workspace:GetPartsInPart(Area)
	end)
	if not ok or not partesNaArea then
		return jogadoresDentro
	end

	for _, part in ipairs(partesNaArea) do
		local char = part.Parent
		if char and char:FindFirstChildOfClass("Humanoid") and not personagensEncontrados[char] then
			personagensEncontrados[char] = true
			local player = Players:GetPlayerFromCharacter(char)
			if player then
				table.insert(jogadoresDentro, player)
			end
		end
	end
	return jogadoresDentro
end

local function getMinPlayers()
	local mn = tonumber(Encontro:GetAttribute("MinPlayers"))
	local mx = tonumber(Encontro:GetAttribute("MaxPlayers"))
	return mn or mx or 6
end

local function getMaxPlayers()
	local mx = tonumber(Encontro:GetAttribute("MaxPlayers"))
	local mn = tonumber(Encontro:GetAttribute("MinPlayers"))
	return mx or mn or 6
end

local function atualizarTexto()
	local minPlayers = getMinPlayers()
	txtQuantidade.Text = tostring(#playersNaArea) .. "/" .. tostring(minPlayers)

	if votacaoAtiva then
		txtStatus.Text = "VOTAÇÃO EM ANDAMENTO"
		txtStatus.TextColor3 = Color3.fromRGB(0, 255, 255)
	else
		txtStatus.Text = "Aguardando Jogadores..."
		txtStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function finalizarVotacaoEstado()
	votacaoAtiva = false
	votacaoEmExecucao = false
	table.clear(votos)
	atualizarTexto()
end

local function iniciarVotacao()
	if votacaoAtiva or votacaoEmExecucao then
		return
	end
	votacaoEmExecucao = true
	votacaoAtiva = true
	table.clear(votos)
	atualizarTexto()

	for _, p in ipairs(playersNaArea) do
		evAbrirVotacao:FireClient(p, TODAS_AS_PISTAS, TEMPO_VOTACAO)
	end

	for _ = TEMPO_VOTACAO, 0, -1 do
		playersNaArea = getJogadoresNaArea()
		local minPlayers = getMinPlayers()

		if #playersNaArea < minPlayers then
			finalizarVotacaoEstado()
			evCancelarVotacao:FireAllClients()
			print("[Encontros] Votação cancelada — abaixo do mínimo na área.")
			return
		end

		local totalVotos = 0
		for _ in pairs(votos) do
			totalVotos += 1
		end
		if totalVotos > 0 and totalVotos >= #playersNaArea then
			break
		end

		task.wait(1)
	end

	local placar = {}
	for _, idMapa in pairs(votos) do
		if mapaValido(idMapa) then
			placar[idMapa] = (placar[idMapa] or 0) + 1
		end
	end

	local vencedorID = nil
	local maiorVoto = -1
	for idMapa, qtdVotos in pairs(placar) do
		if qtdVotos > maiorVoto then
			maiorVoto = qtdVotos
			vencedorID = idMapa
		end
	end

	if not vencedorID then
		local chaves = {}
		for k in pairs(TODAS_AS_PISTAS) do
			table.insert(chaves, k)
		end
		if #chaves > 0 then
			vencedorID = chaves[math.random(1, #chaves)]
		end
	end

	local mapaVencedor = vencedorID and TODAS_AS_PISTAS[vencedorID]
	if not mapaVencedor or type(mapaVencedor.PlaceID) ~= "number" then
		warn("[Encontros] Mapa vencedor inválido.")
		finalizarVotacaoEstado()
		return
	end

	for _, p in ipairs(playersNaArea) do
		evResultado:FireClient(p, mapaVencedor)
	end

	txtStatus.Text = "TELEPORTANDO..."
	txtStatus.TextColor3 = Color3.fromRGB(85, 255, 127)
	task.wait(3.5)

	playersNaArea = getJogadoresNaArea()
	if #playersNaArea > 0 then
		local flushBF = ReplicatedStorage:FindFirstChild("FlushPlayerSaveBF")
		if flushBF and flushBF:IsA("BindableFunction") then
			for _, p in ipairs(playersNaArea) do
				if p and p.Parent == Players then
					pcall(function()
						flushBF:Invoke(p)
					end)
				end
			end
			task.wait(0.75)
		end
		pcall(function()
			local code = TeleportService:ReserveServer(mapaVencedor.PlaceID)
			TeleportService:TeleportToPrivateServer(mapaVencedor.PlaceID, code, playersNaArea)
		end)
	end

	task.wait(2)
	finalizarVotacaoEstado()
end

evVoto.OnServerEvent:Connect(function(player, idMapa)
	if not player or not player:IsA("Player") then
		return
	end
	if not votacaoAtiva or not mapaValido(idMapa) then
		return
	end
	if not jogadorNaListaArea(player) then
		return
	end
	votos[player.UserId] = idMapa
end)

Barreira.Touched:Connect(function(hit)
	local char = hit.Parent
	if not char or not char:IsA("Model") then
		return
	end
	local player = Players:GetPlayerFromCharacter(char)
	if not player then
		return
	end

	local agora = os.clock()
	local ult = ultimoToqueBarreira[player] or 0
	if agora - ult < DEBOUNCE_TOQUE_BARREIRA then
		return
	end
	ultimoToqueBarreira[player] = agora

	local maxPlayers = getMaxPlayers()
	local qtdAtual = #playersNaArea
	local jaEstaDentro = jogadorNaListaArea(player)

	if isPlayerEligible(player) and (jaEstaDentro or qtdAtual < maxPlayers) then
		setCharacterCollisionGroup(char, "JogadoresPermitidos")
		passeLivreFantasmas[player.UserId] = os.time() + 3
	end
end)

Players.PlayerRemoving:Connect(function(p)
	votos[p.UserId] = nil
	passeLivreFantasmas[p.UserId] = nil
	ultimoToqueBarreira[p] = nil
end)

task.spawn(function()
	while task.wait(LOOP_INTERVAL) do
		if not votacaoAtiva and not votacaoEmExecucao then
			playersNaArea = getJogadoresNaArea()
			atualizarTexto()

			local minPlayers = getMinPlayers()
			if #playersNaArea >= minPlayers then
				task.spawn(iniciarVotacao)
			end
		end

		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				local taDentroDoMiolo = jogadorNaListaArea(p)
				local expira = passeLivreFantasmas[p.UserId]
				local temPasseLivre = expira ~= nil and os.time() <= expira

				if not taDentroDoMiolo and not temPasseLivre then
					if hrp.CollisionGroup == "JogadoresPermitidos" then
						setCharacterCollisionGroup(char, "Default")
					end
				end
			end
		end
	end
end)
