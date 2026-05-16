print("CH Corporations - Sistema de Corrida (Com Eventos Globais e VIP)")

local partChegada = script.Parent
local checkpointMeio = workspace:WaitForChild("CheckpointMeio")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local semaforoEvent = ReplicatedStorage:FindFirstChild("SemaforoEvent")
if not semaforoEvent then
	semaforoEvent = Instance.new("RemoteEvent")
	semaforoEvent.Name = "SemaforoEvent"
	semaforoEvent.Parent = ReplicatedStorage
end

-- ⚙️ CRIAÇÃO DOS EVENTOS
local eventoVoltas = ReplicatedStorage:FindFirstChild("AtualizarVoltasEvent")
if not eventoVoltas then
	eventoVoltas = Instance.new("RemoteEvent")
	eventoVoltas.Name = "AtualizarVoltasEvent"
	eventoVoltas.Parent = ReplicatedStorage
end

local eventoTabela = ReplicatedStorage:FindFirstChild("TabelaCorridaEvent")
if not eventoTabela then
	eventoTabela = Instance.new("RemoteEvent")
	eventoTabela.Name = "TabelaCorridaEvent"
	eventoTabela.Parent = ReplicatedStorage
end

local eventoPosicao = ReplicatedStorage:FindFirstChild("AtualizarPosicaoEvent")
if not eventoPosicao then
	eventoPosicao = Instance.new("RemoteEvent")
	eventoPosicao.Name = "AtualizarPosicaoEvent"
	eventoPosicao.Parent = ReplicatedStorage
end

local ID_LOBBY_PRINCIPAL = 140001935550545 
local TOTAL_VOLTAS = 3 

local corridaDados = {}
local vencedores = {}
local corridaFinalizada = false
local timerIniciado = false

local function finalizarCorrida()
	if corridaFinalizada then return end
	corridaFinalizada = true

	print("🏁 Corrida encerrada! A teleportar de volta ao Lobby...")
	semaforoEvent:FireAllClients("FIM DE CORRIDA", Color3.fromRGB(255, 255, 255))
	task.wait(5) -- Tempo para a galera ver a tabela final

	local todosJogadores = Players:GetPlayers()
	if #todosJogadores > 0 then
		-- Mesmo padrão do lobby (Encontros): flush opcional — só corre se o GDM criou FlushPlayerSaveBF
		local flushBF = ReplicatedStorage:FindFirstChild("FlushPlayerSaveBF")
		if flushBF and flushBF:IsA("BindableFunction") then
			for _, p in ipairs(todosJogadores) do
				if p and p.Parent == Players then
					pcall(function()
						flushBF:Invoke(p)
					end)
				end
			end
			task.wait(0.75)
		end
		pcall(function()
			local teleportOptions = Instance.new("TeleportOptions")
			local dadosVip = {
				VoltandoDaCorrida = true
			}
			teleportOptions:SetTeleportData(dadosVip)

			TeleportService:TeleportAsync(ID_LOBBY_PRINCIPAL, todosJogadores, teleportOptions)
		end)
	end
end

-- =================================================================
-- 📡 O RADAR DE POSIÇÕES (AGORA COM TABELA GLOBAL)
-- =================================================================
local function calcularPosicoes()
	local ranking = {}
	local totalPilotos = 0

	for nomeDoJogador, dados in pairs(corridaDados) do
		local player = Players:FindFirstChild(nomeDoJogador)
		if player then
			totalPilotos += 1
			local score = 0

			if dados.Terminou then
				local posFinal = table.find(vencedores, player) or 99
				score = 10000000 - posFinal
			else
				local carro = workspace:FindFirstChild(nomeDoJogador .. "sCar")
				if carro and carro.PrimaryPart then
					score = dados.Volta * 100000
					local alvo = dados.PassouNoCheckpoint and partChegada or checkpointMeio
					if dados.PassouNoCheckpoint then score += 50000 end
					local distancia = (carro.PrimaryPart.Position - alvo.Position).Magnitude
					score -= distancia 
				end
			end

			table.insert(ranking, {
				Player = player, 
				Score = score,
				Volta = dados.Volta,
				Terminou = dados.Terminou,
				PremioDinheiro = dados.PremioDinheiro or 0,
				PremioXP = dados.PremioXP or 0
			})
		end
	end

	table.sort(ranking, function(a, b) return a.Score > b.Score end)

	local totalNoRanking = #ranking
	for i, rankData in ipairs(ranking) do
		eventoPosicao:FireClient(rankData.Player, i, totalNoRanking)
	end

	local tabelaFormatada = {}
	for i, rankData in ipairs(ranking) do
		table.insert(tabelaFormatada, {
			Posicao = i,
			Nome = rankData.Player.Name,
			Volta = rankData.Terminou and "FIM" or (rankData.Volta .. "/" .. TOTAL_VOLTAS),
			Terminou = rankData.Terminou,
			Dinheiro = rankData.PremioDinheiro,
			XP = rankData.PremioXP
		})
	end

	eventoTabela:FireAllClients(tabelaFormatada, corridaFinalizada)
end

task.spawn(function()
	while not corridaFinalizada do
		task.wait(0.5)
		calcularPosicoes()
	end
	calcularPosicoes()
end)

-- =================================================================

checkpointMeio.Touched:Connect(function(hit)
	local modelo = hit:FindFirstAncestorOfClass("Model")
	if modelo and string.match(modelo.Name, "sCar$") then
		local nomeDoJogador = string.gsub(modelo.Name, "sCar", "")
		if corridaDados[nomeDoJogador] and not corridaDados[nomeDoJogador].Terminou then
			corridaDados[nomeDoJogador].PassouNoCheckpoint = true
		end
	end
end)

partChegada.Touched:Connect(function(hit)
	if corridaFinalizada then return end

	local modelo = hit:FindFirstAncestorOfClass("Model")
	if not modelo then return end

	if string.match(modelo.Name, "sCar$") then
		local nomeDoJogador = string.gsub(modelo.Name, "sCar", "")
		local player = Players:FindFirstChild(nomeDoJogador)

		if player then
			if not corridaDados[nomeDoJogador] then
				corridaDados[nomeDoJogador] = {Volta = 1, PassouNoCheckpoint = false, Terminou = false}
				eventoVoltas:FireClient(player, 1, TOTAL_VOLTAS)
				return
			end

			local dados = corridaDados[nomeDoJogador]
			if dados.Terminou then return end

			if dados.PassouNoCheckpoint then
				dados.Volta += 1
				dados.PassouNoCheckpoint = false 

				if dados.Volta > TOTAL_VOLTAS then
					dados.Terminou = true
					eventoVoltas:FireClient(player, TOTAL_VOLTAS, TOTAL_VOLTAS)

					table.insert(vencedores, player)
					local posicao = #vencedores

					print("🏎️ " .. player.Name .. " cruzou a linha em " .. posicao .. "º lugar!")

					local leaderstats = player:FindFirstChild("leaderstats")
					local statsCorrida = player:FindFirstChild("StatsCorrida")
					local corPosicao = Color3.fromRGB(255, 255, 255)

					local granaGanhou = 0
					local xpGanhou = 0

					if leaderstats then
						local dinheiro = leaderstats:FindFirstChild("Dinheiro")
						local xp = leaderstats:FindFirstChild("XP")

						-- 🌟 LÓGICA DE MULTIPLICADORES (Quantidade de Pilotos + VIP + Evento Global)
						local totalPilotos = #Players:GetPlayers()
						local multPilotos = 1

						-- Multiplicador por quantidade de pessoas na sala
						if totalPilotos == 1 then multPilotos = 0.5
						elseif totalPilotos > 2 then multPilotos = 1 + ((totalPilotos - 2) * 0.2) end

						-- Multiplicador do Evento Global (Puxa lá do GerenciadorDeEventosServer)
						local multEvento = _G.EventoMultiplicador or 1

						-- Multiplicador do VIP do Jogador
						local multVip = 1
						local vipSalvo = player:FindFirstChild("VipSalvo")
						if vipSalvo then
							if string.find(vipSalvo.Value, "Diamante") then
								multVip = 2.0 -- 💎 VIP Diamante ganha 2x
							elseif string.find(vipSalvo.Value, "Gold") then
								multVip = 1.5 -- 🥇 VIP Gold ganha 1.5x
							elseif string.find(vipSalvo.Value, "Bronze") then
								multVip = 1.2 -- 🥉 VIP Bronze ganha 1.2x
							end
						end

						-- O MULTIPLICADOR FINAL É A SOMA DE TODOS OS BUFFS!
						local multiplicadorFinal = multPilotos * multEvento * multVip

						if posicao == 1 then
							granaGanhou = math.floor(1500 * multiplicadorFinal)
							xpGanhou = math.floor(500 * multiplicadorFinal)
							corPosicao = Color3.fromRGB(255, 215, 0)

							-- 🏆 SISTEMA DE RANKING
							if totalPilotos > 1 then
								local vitoriasGlobais = leaderstats:FindFirstChild("Vitorias")
								if vitoriasGlobais then vitoriasGlobais.Value += 1 end

								if statsCorrida then
									local vitSemana = statsCorrida:FindFirstChild("VitoriasSemanais")
									if vitSemana then vitSemana.Value += 1 end

									local vitMes = statsCorrida:FindFirstChild("VitoriasMensais")
									if vitMes then vitMes.Value += 1 end
								end
								print("🏆 +1 Vitória computada no Ranking para " .. player.Name)
							else
								print("⚠️ " .. player.Name .. " venceu, mas estava correndo sozinho. Pontos de Ranking não contabilizados.")
							end

							if not timerIniciado then
								timerIniciado = true
								task.spawn(function()
									task.wait(15) 
									finalizarCorrida()
								end)
							end
						elseif posicao == 2 then
							granaGanhou = math.floor(800 * multiplicadorFinal)
							xpGanhou = math.floor(250 * multiplicadorFinal)
							corPosicao = Color3.fromRGB(192, 192, 192)
						elseif posicao == 3 then
							granaGanhou = math.floor(400 * multiplicadorFinal)
							xpGanhou = math.floor(100 * multiplicadorFinal)
							corPosicao = Color3.fromRGB(205, 127, 50)
						else
							granaGanhou = math.floor(100 * multiplicadorFinal)
							xpGanhou = math.floor(50 * multiplicadorFinal)
						end

						if dinheiro and xp then
							dinheiro.Value += granaGanhou
							xp.Value += xpGanhou
						end
					end

					dados.PremioDinheiro = granaGanhou
					dados.PremioXP = xpGanhou

					semaforoEvent:FireClient(player, posicao .. "º LUGAR!", corPosicao)

					if #vencedores >= #Players:GetPlayers() then finalizarCorrida() end
				else
					eventoVoltas:FireClient(player, dados.Volta, TOTAL_VOLTAS)
					semaforoEvent:FireClient(player, "VOLTA " .. dados.Volta .. "/" .. TOTAL_VOLTAS, Color3.fromRGB(255, 170, 0))
					task.delay(2, function() semaforoEvent:FireClient(player, "", Color3.new()) end)
				end
			end
		end
	end
end)
