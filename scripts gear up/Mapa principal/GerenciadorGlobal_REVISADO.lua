-- CH Corporations - Gerenciador Global v9.0 (Enquetes ao vivo, multi-servidor)
-- Revisão: token de geração da enquete (evita timers sobrepostos); votos sincronizados via MessagingService
--          sem duplicar no servidor de origem; validação de admin/voto/inputs; carro no inventário com Value "Comprado";
--          retries leves no DataStore; SubscribeAsync isolado por canal; multiplicador de evento limitado.

print("CH Corporations - Gerenciador Global v9.0 (Enquetes Ao Vivo!)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local EventoDS = DataStoreService:GetDataStore("CH_EventoGlobalState_V1")

local CANAL_EVENTOS = "CH_CanalEventos"
local CANAL_ANUNCIOS = "CH_CanalAnuncios"
local CANAL_ECONOMIA = "CH_CanalEconomia"
local CANAL_MUNDO = "CH_CanalMundo"
local CANAL_SORTEIO = "CH_CanalSorteio"
local CANAL_ENQUETES = "CH_CanalEnquetes"
local CANAL_ENQUETE_VOTO = "CH_CanalEnqueteVoto"

local function getOrCreateEvent(name)
	local ev = ReplicatedStorage:FindFirstChild(name)
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = ReplicatedStorage
	end
	return ev
end

local evEventoGlobal = getOrCreateEvent("EventoAdminCrossServer")
local evNotificarTela = getOrCreateEvent("NotificarEventoClient")
local evAnuncioAdmin = getOrCreateEvent("AnuncioAdminCrossServer")
local evNotificarAnuncio = getOrCreateEvent("NotificarAnuncioClient")
local evEconomiaAdmin = getOrCreateEvent("EconomiaAdminCrossServer")
local evNotificarEconomia = getOrCreateEvent("NotificarEconomiaClient")
local evMundoAdmin = getOrCreateEvent("MundoAdminCrossServer")
local evSorteioAdmin = getOrCreateEvent("SorteioAdminCrossServer")
local evNotificarSorteio = getOrCreateEvent("NotificarSorteioClient")
local evEnqueteAdmin = getOrCreateEvent("EnqueteAdminCrossServer")
local evNotificarEnquete = getOrCreateEvent("NotificarEnqueteClient")
local evVotarEnquete = getOrCreateEvent("VotarEnqueteServer")
local evAtualizarEnquete = getOrCreateEvent("AtualizarEnqueteClient")

_G.EventoAtivo = false
_G.EventoMultiplicador = 1
local tempoFimEvento = 0

-- Admins: usernames (Player.Name no servidor). Preferível completar ADM_USERIDS.
local ADMS = {
	CheechSC = true,
	DDdaZZ26 = true,
}

local ADM_USERIDS = {
	-- [123456789] = true,
}

local function isAdmin(player)
	return ADM_USERIDS[player.UserId] or ADMS[player.Name] == true
end

local function aplicarEventoLocal(d)
	_G.EventoAtivo = d.Ativo == true
	if _G.EventoAtivo then
		_G.EventoMultiplicador = tonumber(d.Multiplicador) or 2
		tempoFimEvento = tonumber(d.TempoFim) or 0
		evNotificarTela:FireAllClients(true, _G.EventoMultiplicador, tempoFimEvento)
	else
		_G.EventoMultiplicador = 1
		tempoFimEvento = 0
		evNotificarTela:FireAllClients(false, 1, 0)
	end
end

-- Carregar estado do evento (com retry leve)
task.spawn(function()
	local d = nil
	for attempt = 1, 4 do
		local ok, result = pcall(function()
			return EventoDS:GetAsync("EventoAtual")
		end)
		if ok then
			d = result
			break
		end
		task.wait(attempt)
	end

	if d and d.Ativo then
		local fim = tonumber(d.TempoFim) or 0
		if fim == 0 or os.time() < fim then
			aplicarEventoLocal(d)
		else
			aplicarEventoLocal({ Ativo = false, Multiplicador = 1, TempoFim = 0 })
		end
	end
end)

Players.PlayerAdded:Connect(function(p)
	if _G.EventoAtivo then
		task.delay(3, function()
			if p.Parent then
				evNotificarTela:FireClient(p, true, _G.EventoMultiplicador, tempoFimEvento)
			end
		end)
	end
end)

evEventoGlobal.OnServerEvent:Connect(function(p, acao, mult, tSeg)
	if not isAdmin(p) then
		return
	end

	local d = {}
	if acao == "Iniciar" then
		local m = math.clamp(tonumber(mult) or 2, 1, 50)
		local seg = math.max(0, tonumber(tSeg) or 0)
		d = {
			Ativo = true,
			Multiplicador = m,
			TempoFim = seg > 0 and (os.time() + seg) or 0,
		}
	elseif acao == "Parar" then
		d = { Ativo = false, Multiplicador = 1, TempoFim = 0 }
	else
		return
	end

	for i = 1, 3 do
		local ok = pcall(function()
			EventoDS:SetAsync("EventoAtual", d)
		end)
		if ok then
			break
		end
		task.wait(1.5)
	end

	pcall(function()
		MessagingService:PublishAsync(CANAL_EVENTOS, d)
	end)
end)

task.spawn(function()
	while true do
		task.wait(5)
		if _G.EventoAtivo and tempoFimEvento > 0 and os.time() >= tempoFimEvento then
			aplicarEventoLocal({ Ativo = false, Multiplicador = 1, TempoFim = 0 })
		end
	end
end)

evAnuncioAdmin.OnServerEvent:Connect(function(p, msg, isGlobal)
	if not isAdmin(p) then
		return
	end
	if type(msg) ~= "string" or msg == "" then
		return
	end
	if isGlobal then
		pcall(function()
			MessagingService:PublishAsync(CANAL_ANUNCIOS, { Texto = string.sub(msg, 1, 500), Autor = p.Name })
		end)
	else
		evNotificarAnuncio:FireAllClients(msg, p.Name, false)
	end
end)

evEconomiaAdmin.OnServerEvent:Connect(function(p, alvo, tipo, val)
	if not isAdmin(p) then
		return
	end
	if type(alvo) ~= "string" or alvo == "" or type(tipo) ~= "string" then
		return
	end
	pcall(function()
		MessagingService:PublishAsync(CANAL_ECONOMIA, { Alvo = alvo, Tipo = tipo, Valor = val })
	end)
end)

evMundoAdmin.OnServerEvent:Connect(function(p, acaoMundo)
	if not isAdmin(p) then
		return
	end
	if type(acaoMundo) ~= "string" then
		return
	end
	pcall(function()
		MessagingService:PublishAsync(CANAL_MUNDO, { Acao = acaoMundo })
	end)
end)

evSorteioAdmin.OnServerEvent:Connect(function(p, tipoDado, valorOuNomeCarro)
	if not isAdmin(p) then
		return
	end
	if type(tipoDado) ~= "string" then
		return
	end
	pcall(function()
		MessagingService:PublishAsync(CANAL_SORTEIO, { Tipo = tipoDado, Valor = valorOuNomeCarro })
	end)
end)

-- ==========================================================
-- ENQUETE
-- ==========================================================
local enqueteAtiva = false
local votosA = 0
local votosB = 0
local usuariosVotaram = {}
local enqueteGeracao = 0

local function aplicarVotoRemoto(userId, opcao)
	if not enqueteAtiva then
		return
	end
	if opcao ~= "A" and opcao ~= "B" then
		return
	end
	if usuariosVotaram[userId] then
		return
	end
	usuariosVotaram[userId] = true
	if opcao == "A" then
		votosA += 1
	else
		votosB += 1
	end
end

evEnqueteAdmin.OnServerEvent:Connect(function(player, pergunta, opA, opB, tempo)
	if not isAdmin(player) then
		return
	end
	if type(pergunta) ~= "string" or type(opA) ~= "string" or type(opB) ~= "string" then
		return
	end
	local t = math.clamp(tonumber(tempo) or 30, 5, 3600)
	pcall(function()
		MessagingService:PublishAsync(CANAL_ENQUETES, {
			Pergunta = string.sub(pergunta, 1, 200),
			OpA = string.sub(opA, 1, 80),
			OpB = string.sub(opB, 1, 80),
			Tempo = t,
		})
	end)
end)

-- Voto: só publica; o Subscribe aplica uma vez (inclui este servidor — sem duplicar por usuariosVotaram)
evVotarEnquete.OnServerEvent:Connect(function(player, opcao)
	if not enqueteAtiva then
		return
	end
	if opcao ~= "A" and opcao ~= "B" then
		return
	end
	if usuariosVotaram[player.UserId] then
		return
	end

	pcall(function()
		MessagingService:PublishAsync(CANAL_ENQUETE_VOTO, {
			UserId = player.UserId,
			Opcao = opcao,
		})
	end)
end)

-- ==========================================================
-- SUBSCRIBES (cada um isolado: falha num não impede os outros)
-- ==========================================================
local function sub(canal, callback)
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(canal, callback)
	end)
	if not ok then
		warn("[GerenciadorGlobal] SubscribeAsync falhou [" .. canal .. "]: " .. tostring(err))
	end
end

sub(CANAL_EVENTOS, function(msg)
	aplicarEventoLocal(msg.Data)
end)

sub(CANAL_ANUNCIOS, function(msg)
	local d = msg.Data
	if d and d.Texto then
		evNotificarAnuncio:FireAllClients(d.Texto, d.Autor or "Admin", true)
	end
end)

sub(CANAL_MUNDO, function(msg)
	local a = msg.Data and msg.Data.Acao
	if a == "Dia" then
		Lighting.ClockTime = 12
	elseif a == "Noite" then
		Lighting.ClockTime = 0
	elseif a == "Limpo" then
		Lighting.FogEnd = 100000
	elseif a == "Chuva" then
		Lighting.FogEnd = 200
		Lighting.FogColor = Color3.fromRGB(100, 100, 100)
	end
end)

local function darCarroNoInventario(sortudo, nomeCarro)
	local inv = sortudo:FindFirstChild("InventarioVeiculos")
	if not inv or inv:FindFirstChild(nomeCarro) then
		return
	end
	local nc = Instance.new("StringValue")
	nc.Name = nomeCarro
	nc.Value = "Comprado"
	nc.Parent = inv
	nc:SetAttribute("CombustivelSalvo", 100)
	nc:SetAttribute("MotorAtual", 0)
	nc:SetAttribute("CorDoCarro", "")
	nc:SetAttribute("FL", nil)
	nc:SetAttribute("FR", nil)
	nc:SetAttribute("RL", nil)
	nc:SetAttribute("RR", nil)
	nc:SetAttribute("SuspensaoNome", "Padrao")
	nc:SetAttribute("SuspensaoAltura", 2)
	nc:SetAttribute("SuspensaoRigidez", 4500)
	nc:SetAttribute("SuspensaoAmortecimento", 500)
end

sub(CANAL_ECONOMIA, function(msg)
	local d = msg.Data
	if not d or type(d.Alvo) ~= "string" then
		return
	end
	local sortudo = Players:FindFirstChild(d.Alvo)
	if not sortudo then
		return
	end

	if d.Tipo == "Carro" then
		local nome = tostring(d.Valor or "")
		if nome ~= "" then
			darCarroNoInventario(sortudo, nome)
			evNotificarEconomia:FireClient(sortudo, "Carro", nome)
		end
	else
		local ls = sortudo:FindFirstChild("leaderstats")
		local stat = ls and ls:FindFirstChild(d.Tipo)
		if stat and stat:IsA("IntValue") then
			stat.Value += math.floor(tonumber(d.Valor) or 0)
			evNotificarEconomia:FireClient(sortudo, d.Tipo, d.Valor)
		end
	end
end)

sub(CANAL_SORTEIO, function(msg)
	local tipo = msg.Data.Tipo
	local valor = msg.Data.Valor
	evNotificarSorteio:FireAllClients("Iniciar", tipo, valor)

	task.delay(10.5, function()
		local list = Players:GetPlayers()
		if #list == 0 then
			return
		end
		local vencedor = list[math.random(1, #list)]
		if tipo == "Carro" then
			local nome = tostring(valor or "")
			if nome ~= "" then
				darCarroNoInventario(vencedor, nome)
			end
		else
			local ls = vencedor:FindFirstChild("leaderstats")
			local stat = ls and ls:FindFirstChild(tipo)
			if stat and stat:IsA("IntValue") then
				stat.Value += math.floor(tonumber(valor) or 0)
			end
		end
		evNotificarSorteio:FireAllClients("Vencedor", tipo, valor, vencedor.Name)
	end)
end)

-- Eco de voto: outros servidores aplicam sem duplicar (origem já marcou usuariosVotaram)
sub(CANAL_ENQUETE_VOTO, function(msg)
	local d = msg.Data
	if not d or type(d.UserId) ~= "number" then
		return
	end
	aplicarVotoRemoto(d.UserId, d.Opcao)
end)

sub(CANAL_ENQUETES, function(msg)
	local d = msg.Data
	if not d or type(d.Pergunta) ~= "string" then
		return
	end

	enqueteGeracao += 1
	local minhaGeracao = enqueteGeracao

	enqueteAtiva = true
	votosA = 0
	votosB = 0
	usuariosVotaram = {}

	evNotificarEnquete:FireAllClients("Iniciar", d.Pergunta, d.OpA, d.OpB, d.Tempo)

	task.spawn(function()
		local t = math.clamp(tonumber(d.Tempo) or 30, 5, 3600)
		while t > 0 and enqueteAtiva and enqueteGeracao == minhaGeracao do
			task.wait(1)
			t -= 1
			local total = votosA + votosB
			local pctA = (total > 0) and math.floor((votosA / total) * 100) or 50
			local pctB = (total > 0) and math.floor((votosB / total) * 100) or 50
			evAtualizarEnquete:FireAllClients(pctA, pctB, t)
		end

		if enqueteGeracao == minhaGeracao then
			enqueteAtiva = false
			evNotificarEnquete:FireAllClients("Encerrar")
		end
	end)
end)
