-- CH Corporations - Sistema de Limpeza de Lotes e Veículos
-- Revisão: WaitForChild com timeout; ignora join se LotesDasCasas não existir; referência à pasta revalidada no leave;
--          restauração do terreno com pcall; carro no Workspace só se o nome bater.

print("CH Corporations - Sistema de Limpeza de Lotes e Veículos Iniciado")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local TIMEOUT_LOTES = 120

local pastaLotes = Workspace:WaitForChild("LotesDasCasas", TIMEOUT_LOTES)
if not pastaLotes then
	warn("[LimpezaLotes] LotesDasCasas não encontrado no Workspace em " .. TIMEOUT_LOTES .. "s. Limpeza de lotes desativada.")
end

local function obterPastaLotes()
	if pastaLotes and pastaLotes.Parent then
		return pastaLotes
	end
	pastaLotes = Workspace:FindFirstChild("LotesDasCasas")
	return pastaLotes
end

Players.PlayerRemoving:Connect(function(player)
	local lotes = obterPastaLotes()
	if not lotes then
		return
	end

	local nomeJogador = player.Name

	for _, lote in ipairs(lotes:GetChildren()) do
		if lote:GetAttribute("Dono") == nomeJogador then
			local casaDoPlayer = lote:FindFirstChild("CasaDo_" .. nomeJogador)
			if casaDoPlayer then
				pcall(function()
					casaDoPlayer:Destroy()
				end)
				print("🏠 A casa de " .. nomeJogador .. " foi removida!")
			end

			lote:SetAttribute("Dono", nil)

			local terrenosGuardados = ServerStorage:FindFirstChild("TerrenosGuardados")
			if terrenosGuardados then
				local terrenoEscondido = terrenosGuardados:FindFirstChild("TerrenoVazio_" .. lote.Name)
				if terrenoEscondido then
					pcall(function()
						terrenoEscondido.Name = "TerrenoVazio"
						terrenoEscondido.Parent = lote
					end)
					print("📦 Terreno restaurado com sucesso no " .. lote.Name .. "!")
				else
					warn("⚠️ O terreno do " .. lote.Name .. " não foi encontrado nos TerrenosGuardados!")
				end
			end
		end
	end

	local nomeDoCarroDoDono = nomeJogador .. "sCar"
	local carroNoMapa = Workspace:FindFirstChild(nomeDoCarroDoDono)
	if carroNoMapa then
		pcall(function()
			carroNoMapa:Destroy()
		end)
		print("🚗 O carro de " .. nomeJogador .. " foi rebocado da rua!")
	end
end)
