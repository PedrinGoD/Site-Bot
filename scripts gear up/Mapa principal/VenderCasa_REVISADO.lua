-- CH Corporations - Vender casa / libertar lote (servidor) — Script filho do ProximityPrompt
-- Revisão: valida ProximityPrompt e Player; sobe a hierarquia com limite de profundidade;
--          Dono por Name (string) ou UserId (number); debounce por lote; repõe terreno antes de demolir;
--          se o terreno vazio não existir no cofre nem no lote, aborta a venda; operações críticas em pcall.

local prompt = script.Parent
local ServerStorage = game:GetService("ServerStorage")

local NOME_PASTA_LOTES = "LotesDasCasas"
local PREFIXO_TERRENO_COFRE = "TerrenoVazio_"
local NOME_TERRENO_NO_MAPA = "TerrenoVazio"
local MAX_SUBIDA_HIERARQUIA = 64

-- Se false, replica o script antigo: limpa dono e demole mesmo sem terreno no cofre (mapa pode ficar inconsistente).
local EXIGIR_REPOR_TERRENO = true

if not prompt:IsA("ProximityPrompt") then
	warn("[VenderCasa] script.Parent deve ser um ProximityPrompt.")
	return
end

local function jogadorEDonoDoLote(lote, player)
	local dono = lote:GetAttribute("Dono")
	if dono == nil then
		return false
	end
	if typeof(dono) == "number" then
		return dono == player.UserId
	end
	return tostring(dono) == player.Name
end

local function encontrarLoteECasa()
	local objetoAtual = prompt
	local lote = nil
	local casa = nil
	local profundidade = 0

	while objetoAtual and objetoAtual.Parent and profundidade < MAX_SUBIDA_HIERARQUIA do
		profundidade += 1
		local pai = objetoAtual.Parent
		if pai.Name == NOME_PASTA_LOTES then
			lote = objetoAtual
			break
		end
		casa = objetoAtual
		objetoAtual = pai
	end

	if profundidade >= MAX_SUBIDA_HIERARQUIA then
		warn("[VenderCasa] Hierarquia demasiado profunda ou pasta '" .. NOME_PASTA_LOTES .. "' não encontrada.")
	end

	return lote, casa
end

local function terrenoVazioJaNoLote(lote)
	if not lote then
		return nil
	end
	local t1 = lote:FindFirstChild(NOME_TERRENO_NO_MAPA)
	if t1 then
		return t1
	end
	return lote:FindFirstChild(PREFIXO_TERRENO_COFRE .. lote.Name)
end

local function reporTerrenoVazio(lote)
	local ja = terrenoVazioJaNoLote(lote)
	if ja then
		if ja.Name ~= NOME_TERRENO_NO_MAPA then
			pcall(function()
				ja.Name = NOME_TERRENO_NO_MAPA
			end)
		end
		return true, ja
	end

	local terrenosGuardados = ServerStorage:FindFirstChild("TerrenosGuardados")
	if not terrenosGuardados then
		warn("[VenderCasa] ServerStorage.TerrenosGuardados em falta — não é possível repor o terreno.")
		return false, nil
	end

	local terrenoVazio = terrenosGuardados:FindFirstChild(PREFIXO_TERRENO_COFRE .. lote.Name)
	if not terrenoVazio then
		warn("[VenderCasa] Terreno '" .. PREFIXO_TERRENO_COFRE .. lote.Name .. "' não encontrado no cofre.")
		return false, nil
	end

	local ok = pcall(function()
		terrenoVazio.Name = NOME_TERRENO_NO_MAPA
		terrenoVazio.Parent = lote
	end)
	if not ok then
		warn("[VenderCasa] Falha ao mover o terreno vazio para o lote.")
		return false, nil
	end

	return true, terrenoVazio
end

local lotesEmVenda = {}

prompt.Triggered:Connect(function(player)
	if not player or not player:IsA("Player") then
		return
	end

	local lote, casa = encontrarLoteECasa()
	if not lote or not casa then
		warn("[VenderCasa] Não foi possível resolver o Lote ou a Casa a partir do prompt.")
		return
	end

	if lotesEmVenda[lote] then
		return
	end

	if not jogadorEDonoDoLote(lote, player) then
		warn("[VenderCasa] " .. player.Name .. " tentou vender um lote que não é seu (Dono: " .. tostring(lote:GetAttribute("Dono")) .. ").")
		return
	end

	lotesEmVenda[lote] = true

	local okRepor, _ = reporTerrenoVazio(lote)
	if EXIGIR_REPOR_TERRENO and not okRepor then
		lotesEmVenda[lote] = nil
		warn("[VenderCasa] Venda cancelada — repõe o terreno no cofre ou no lote antes de tentar de novo.")
		return
	end

	pcall(function()
		lote:SetAttribute("Dono", nil)
	end)

	pcall(function()
		if casa.Parent then
			casa:Destroy()
		end
	end)

	print("[VenderCasa] " .. player.Name .. " libertou o terreno / lote " .. lote.Name)

	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local iconeAntigo = playerGui:FindFirstChild("IconeCasaPropria")
		if iconeAntigo then
			pcall(function()
				iconeAntigo:Destroy()
			end)
		end
	end

	lotesEmVenda[lote] = nil
end)
