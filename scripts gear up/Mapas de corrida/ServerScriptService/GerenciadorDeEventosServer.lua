print("CH Corporations - Gerenciador de Eventos Globais Ao Vivo (Com Memória DS)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- 🗄️ A "Memória" do Evento
local EventoDS = DataStoreService:GetDataStore("CH_EventoGlobalState_V1")

-- RemoteEvents
local evEventoGlobal = ReplicatedStorage:FindFirstChild("EventoAdminCrossServer") or Instance.new("RemoteEvent", ReplicatedStorage)
evEventoGlobal.Name = "EventoAdminCrossServer"

local evNotificarTela = ReplicatedStorage:FindFirstChild("NotificarEventoClient") or Instance.new("RemoteEvent", ReplicatedStorage)
evNotificarTela.Name = "NotificarEventoClient"

-- Variáveis Globais (Acessadas pela Corrida)
_G.EventoAtivo = false
_G.EventoMultiplicador = 1
local tempoFimEvento = 0

local ADMS = {
	["CheechSC"] = true,
	["DDdaZZ26"] = true,
	["Player1"] = true 
}

-- 📡 Função que liga/desliga o evento NESTE servidor
local function aplicarEventoLocal(dados)
	_G.EventoAtivo = dados.Ativo

	if _G.EventoAtivo then
		_G.EventoMultiplicador = dados.Multiplicador
		tempoFimEvento = dados.TempoFim

		evNotificarTela:FireAllClients(true, _G.EventoMultiplicador, tempoFimEvento)
		print("🔥 EVENTO GLOBAL APLICADO: " .. _G.EventoMultiplicador .. "X")
	else
		_G.EventoMultiplicador = 1
		tempoFimEvento = 0
		evNotificarTela:FireAllClients(false, 1, 0)
		print("🛑 EVENTO GLOBAL ENCERRADO NESTE SERVIDOR.")
	end
end

-- ==========================================================
-- 1️⃣ QUANDO UM SERVIDOR NOVO NASCE (Corrida ou Lobby Vazio)
-- ==========================================================
task.spawn(function()
	-- Ele olha o Quadro de Avisos na Nuvem!
	local sucesso, dadosSalvos = pcall(function()
		return EventoDS:GetAsync("EventoAtual")
	end)

	if sucesso and dadosSalvos and dadosSalvos.Ativo then
		-- Verifica se o tempo já não acabou enquanto o servidor estava fechado
		if dadosSalvos.TempoFim == 0 or os.time() < dadosSalvos.TempoFim then
			print("✅ Servidor novo detectou um evento ativo na nuvem!")
			aplicarEventoLocal(dadosSalvos)
		else
			print("❌ Servidor novo viu o evento na nuvem, mas já estava expirado.")
			aplicarEventoLocal({Ativo = false, Multiplicador = 1, TempoFim = 0})
		end
	end
end)

-- ==========================================================
-- 2️⃣ QUANDO UM JOGADOR ENTRA NO MEIO DO EVENTO
-- ==========================================================
Players.PlayerAdded:Connect(function(player)
	-- Se o evento estiver rolando, avisa o client dele para abrir o HUD!
	if _G.EventoAtivo then
		task.delay(3, function() -- Espera 3 seg pro jogo dele carregar a UI
			evNotificarTela:FireClient(player, true, _G.EventoMultiplicador, tempoFimEvento)
		end)
	end
end)

-- ==========================================================
-- 3️⃣ COMUNICAÇÃO DE RÁDIO (Para servidores que já estão abertos)
-- ==========================================================
local sucessoRadio, erroRadio = pcall(function()
	MessagingService:SubscribeAsync("CH_CanalEventosGlobais", function(mensagem)
		aplicarEventoLocal(mensagem.Data)
	end)
end)
if not sucessoRadio then warn("Erro no Rádio de Eventos: " .. tostring(erroRadio)) end

-- ==========================================================
-- 4️⃣ QUANDO O ADMIN APERTA O BOTÃO NO PAINEL
-- ==========================================================
evEventoGlobal.OnServerEvent:Connect(function(player, acao, multiplicador, tempoEmMinutos)
	if not ADMS[player.Name] then return end

	local dadosEvento = {}

	if acao == "Iniciar" then
		local tFim = 0
		if tempoEmMinutos > 0 then tFim = os.time() + (tempoEmMinutos * 60) end
		dadosEvento = { Ativo = true, Multiplicador = tonumber(multiplicador) or 2, TempoFim = tFim }
	elseif acao == "Parar" then
		dadosEvento = { Ativo = false, Multiplicador = 1, TempoFim = 0 }
	end

	-- Passo A: Salva na Nuvem (Para os servidores de corrida que vão nascer depois)
	pcall(function()
		EventoDS:SetAsync("EventoAtual", dadosEvento)
	end)

	-- Passo B: Grita no Rádio (Para os servidores do Lobby/Pista que já estão abertos agora)
	MessagingService:PublishAsync("CH_CanalEventosGlobais", dadosEvento)
end)

-- ==========================================================
-- ⏱️ LOOP DE VERIFICAÇÃO DO TEMPO
-- ==========================================================
task.spawn(function()
	while task.wait(5) do
		if _G.EventoAtivo and tempoFimEvento > 0 then
			if os.time() >= tempoFimEvento then
				print("⏳ O tempo do Evento acabou neste servidor!")
				aplicarEventoLocal({Ativo = false, Multiplicador = 1, TempoFim = 0})
			end
		end
	end
end)
