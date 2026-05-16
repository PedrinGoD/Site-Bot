-- CH Corporations - Prateleira dinâmica (servidor) — Script no container da prateleira
-- Revisão: modelos no ServerStorage com timeout; dono via CasaDo_ (literal); admin por nome + UserId;
--          sincronização de slots com retentativas + PlayerAdded/ChildAdded (sem depender só de wait(2));
--          ao mudar StringValue do slot, recria o visual; ProximityPrompt validado; find/gsub literais onde faz sentido;
--          clone/parent em pcall; anti-dupe com nome do recibo antes de Destroy; debounce curto por slot.
-- REV.2: remoção de recibo idempotente (sem warn se já removido); lookup ECU com fallbacks de nome no ServerStorage;
--        debounce ligeiramente maior após guardar para evitar re-disparo imediato (pegar logo a seguir).

print("CH Corporations - Prateleira dinâmica (revisão: admin + dono + sync + ECU/recibo)")

local prateleira = script.Parent
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local WAIT_STORAGE = 20
local SYNC_RETRY_INTERVAL = 0.35
local SYNC_MAX_ATTEMPTS = 40
local DEBOUNCE_PROMPT = 0.5

local NOME_PASTA_PRATELEIRA_DATA = "PrateleiraData"
local PREFIXO_SLOT = "Slot"
local PREFIXO_CASA = "CasaDo_"
local ANIM_ID_SNIPPET = "71909281184766"

local ADMINS_PERMITIDOS = {
	CheechSC = true,
	[5085681592] = true,
}

local function esperarFilho(parent, nome, timeout)
	if not parent then
		return nil
	end
	local inst = parent:WaitForChild(nome, timeout)
	return inst
end

local caixaFalsaModelo = esperarFilho(ServerStorage, "CaixaFalsaVisual", WAIT_STORAGE)
local caixaFalsaPremium = esperarFilho(ServerStorage, "CaixaFalsaPremium", WAIT_STORAGE)
local caixaFalsaSuspensao = esperarFilho(ServerStorage, "CaixaFalsaSuspensao", WAIT_STORAGE)
local caixaFalsaGalao = esperarFilho(ServerStorage, "CaixaFalsaGalao", WAIT_STORAGE)
local caixaFalsaSpray = esperarFilho(ServerStorage, "LataSpray", WAIT_STORAGE)

local function modeloDisponivel(inst, nome)
	if inst then
		return true
	end
	warn("[Prateleira] Modelo/instância em falta no ServerStorage: " .. nome)
	return false
end

if not modeloDisponivel(caixaFalsaModelo, "CaixaFalsaVisual") then
	return
end

local function getDonoDaCasa()
	local modeloCasa = prateleira:FindFirstAncestorWhichIsA("Model")
	if not modeloCasa then
		return nil
	end
	local _, fimPrefixo = string.find(modeloCasa.Name, PREFIXO_CASA, 1, true)
	if not fimPrefixo then
		return nil
	end
	return string.sub(modeloCasa.Name, fimPrefixo + 1)
end

local function eSlotPart(inst)
	return inst:IsA("BasePart") and string.sub(inst.Name, 1, #PREFIXO_SLOT) == PREFIXO_SLOT
end

-- ServerStorage: convénio «CaixaFalsa» + nome da Tool guardada (ex. Tool CaixaECU_Stage4 → Model CaixaFalsaCaixaECU_Stage4).
-- Fallbacks cobrem nomes alternativos (só sufixo StageN, etc.).
local function encontrarModeloVisualECU(nomeDaPeca: string): Instance?
	if nomeDaPeca == "" then
		return nil
	end
	local candidatos = {
		"CaixaFalsa" .. nomeDaPeca, -- ex.: CaixaFalsaCaixaECU_Stage4
		nomeDaPeca,
		"CaixaFalsa" .. string.gsub(nomeDaPeca, "^CaixaECU_", "", 1),
		"CaixaFalsa_" .. string.gsub(nomeDaPeca, "^CaixaECU_", "", 1),
	}
	local vistos = {}
	for _, nome in ipairs(candidatos) do
		if nome ~= "" and not vistos[nome] then
			vistos[nome] = true
			local m = ServerStorage:FindFirstChild(nome)
			if m then
				return m
			end
		end
	end
	return nil
end

local function criarCaixaVisual(slotPart, nomeDaPeca, cliques, isPremium, isSuspensao, isECU, isGalao, isSpray)
	local modeloParaClonar = caixaFalsaModelo

	if isSpray then
		modeloParaClonar = caixaFalsaSpray
	elseif isGalao then
		modeloParaClonar = caixaFalsaGalao
	elseif isSuspensao then
		modeloParaClonar = caixaFalsaSuspensao
	elseif isECU then
		modeloParaClonar = encontrarModeloVisualECU(nomeDaPeca)
		if not modeloParaClonar then
			warn("[Prateleira] ECU visual em falta no ServerStorage para: " .. nomeDaPeca .. " (tentei CaixaFalsa+nome, nome direto, etc.)")
			return
		end
	elseif isPremium then
		modeloParaClonar = caixaFalsaPremium
	end

	if not modeloParaClonar then
		warn("[Prateleira] Nenhum modelo base para clonar.")
		return
	end

	local okClone, novaCaixa = pcall(function()
		return modeloParaClonar:Clone()
	end)
	if not okClone or not novaCaixa then
		warn("[Prateleira] Falha ao clonar caixa visual.")
		return
	end

	novaCaixa.Name = "CaixaVisual"

	for _, obj in ipairs(novaCaixa:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			obj:Destroy()
		end
	end

	if isSpray then
		novaCaixa:SetAttribute("TipoDePeca", "Spray")
		local corValue = Instance.new("StringValue")
		corValue.Name = "CorSalva"
		corValue.Value = nomeDaPeca
		corValue.Parent = novaCaixa
	elseif isGalao then
		novaCaixa:SetAttribute("TipoDePeca", "Galao")
	elseif isSuspensao then
		novaCaixa:SetAttribute("TipoDePeca", "Suspensao")
		local nomeValue = Instance.new("StringValue")
		nomeValue.Name = "NomeDaSuspensao"
		nomeValue.Value = nomeDaPeca
		nomeValue.Parent = novaCaixa
	elseif isECU then
		novaCaixa:SetAttribute("TipoDePeca", "ECU")
		local nomeValue = Instance.new("StringValue")
		nomeValue.Name = "NomeDaECU"
		nomeValue.Value = nomeDaPeca
		nomeValue.Parent = novaCaixa
	else
		novaCaixa:SetAttribute("TipoDePeca", "Roda")
		local rodaValue = Instance.new("StringValue")
		rodaValue.Name = "TipoDeRoda"
		rodaValue.Value = nomeDaPeca
		rodaValue.Parent = novaCaixa
		local cliquesValue = Instance.new("IntValue")
		cliquesValue.Name = "CliquesSalvos"
		cliquesValue.Value = cliques or 0
		cliquesValue.Parent = novaCaixa
		if isPremium then
			novaCaixa:SetAttribute("Premium", true)
		end
	end

	if novaCaixa:IsA("BasePart") then
		novaCaixa.CFrame = slotPart.CFrame * CFrame.new(0, (novaCaixa.Size.Y / 2 + slotPart.Size.Y / 2), 0)
		novaCaixa.Anchored = true
		novaCaixa.CanCollide = false
	else
		local alturaOffset = 0
		if novaCaixa.PrimaryPart then
			alturaOffset = (novaCaixa.PrimaryPart.Size.Y / 2) + (slotPart.Size.Y / 2)
		end
		if isGalao then
			alturaOffset = alturaOffset + 0.8
		end
		if isSpray then
			alturaOffset = alturaOffset + 0.5
		end

		pcall(function()
			novaCaixa:PivotTo(slotPart.CFrame * CFrame.new(0, alturaOffset, 0))
		end)

		for _, obj in ipairs(novaCaixa:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = true
				obj.CanCollide = false
			end
		end
	end

	pcall(function()
		novaCaixa.Parent = slotPart
	end)
end

local function atualizarSlotVisual(slotPart, slotData, prompt)
	if not slotPart or not slotData or not slotData:IsA("StringValue") then
		return
	end

	local rawData = slotData.Value
	local caixaVisual = slotPart:FindFirstChild("CaixaVisual")

	if rawData ~= "" then
		if caixaVisual then
			pcall(function()
				caixaVisual:Destroy()
			end)
		end

		if string.find(rawData, "SPRAY|", 1, true) then
			local partes = string.split(rawData, "|")
			local corString = partes[2] or ""
			criarCaixaVisual(slotPart, corString, 0, false, false, false, false, true)
			if prompt then
				prompt.ActionText = "Pegar Tinta Spray"
			end
		elseif rawData == "GALAO|Gasolina5l" then
			criarCaixaVisual(slotPart, "Gasolina5l", 0, false, false, false, true, false)
			if prompt then
				prompt.ActionText = "Pegar Galão de Gasolina"
			end
		elseif string.find(rawData, "SUSPENSAO|", 1, true) then
			local partes = string.split(rawData, "|")
			local nomeSuspensao = partes[2] or ""
			criarCaixaVisual(slotPart, nomeSuspensao, 0, false, true, false, false, false)
			if prompt then
				prompt.ActionText = "Pegar " .. nomeSuspensao
			end
		elseif string.find(rawData, "ECU|", 1, true) then
			local partes = string.split(rawData, "|")
			local nomeECU = partes[2] or ""
			criarCaixaVisual(slotPart, nomeECU, 0, false, false, true, false, false)
			if prompt then
				prompt.ActionText = "Pegar " .. string.gsub(nomeECU, "CaixaECU_", "", 1)
			end
		else
			local nomeDaRoda = rawData
			local cliquesGastos = 0
			local isPremium = false

			if string.find(rawData, "|", 1, true) then
				local partes = string.split(rawData, "|")
				nomeDaRoda = partes[1] or rawData
				cliquesGastos = tonumber(partes[2]) or 0
				if partes[3] == "true" then
					isPremium = true
				end
			end

			criarCaixaVisual(slotPart, nomeDaRoda, cliquesGastos, isPremium, false, false, false, false)
			if prompt then
				prompt.ActionText = "Pegar " .. nomeDaRoda .. " (" .. (4 - cliquesGastos) .. "/4)"
			end
		end
	else
		if caixaVisual then
			pcall(function()
				caixaVisual:Destroy()
			end)
		end
		if prompt then
			prompt.ActionText = "Guardar Caixa"
		end
	end
end

local slotsJaLigados = {}

local function ligarSlotAosDados(slotPart, slotData, prompt)
	if slotsJaLigados[slotPart] or not slotData or not slotData:IsA("StringValue") then
		return
	end
	slotsJaLigados[slotPart] = true

	atualizarSlotVisual(slotPart, slotData, prompt)
	slotData:GetPropertyChangedSignal("Value"):Connect(function()
		atualizarSlotVisual(slotPart, slotData, prompt)
	end)
end

local function tentarLigarTodosSlots(player)
	local prateleiraData = player:FindFirstChild(NOME_PASTA_PRATELEIRA_DATA)
	if not prateleiraData then
		return false
	end

	for _, slotPart in ipairs(prateleira:GetChildren()) do
		if eSlotPart(slotPart) then
			local slotData = prateleiraData:FindFirstChild(slotPart.Name)
			if slotData and slotData:IsA("StringValue") then
				local prompt = slotPart:FindFirstChildWhichIsA("ProximityPrompt")
				ligarSlotAosDados(slotPart, slotData, prompt)
			end
		end
	end
	return true
end

local donoNomeFixo = getDonoDaCasa()
if not donoNomeFixo then
	warn("[Prateleira] Casa sem prefixo '" .. PREFIXO_CASA .. "' na hierarquia — sync desativada.")
end

task.spawn(function()
	for _ = 1, SYNC_MAX_ATTEMPTS do
		if not donoNomeFixo then
			break
		end
		local player = Players:FindFirstChild(donoNomeFixo)
		if player and tentarLigarTodosSlots(player) then
			break
		end
		task.wait(SYNC_RETRY_INTERVAL)
	end
end)

if donoNomeFixo then
	local function anexarOuvirPrateleiraData(player)
		player.ChildAdded:Connect(function(child)
			if child.Name == NOME_PASTA_PRATELEIRA_DATA then
				task.defer(function()
					tentarLigarTodosSlots(player)
				end)
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		if player.Name ~= donoNomeFixo then
			return
		end
		task.defer(function()
			tentarLigarTodosSlots(player)
		end)
		anexarOuvirPrateleiraData(player)
	end)

	local donoAtual = Players:FindFirstChild(donoNomeFixo)
	if donoAtual then
		anexarOuvirPrateleiraData(donoAtual)
	end
end

local function adicionarReciboSave(player, nomeDoItem, valorOpcional)
	local invJogador = player:FindFirstChild("InventarioFerramentas")
	if not invJogador then
		return
	end
	pcall(function()
		local novoRecord = Instance.new("StringValue")
		novoRecord.Name = nomeDoItem
		novoRecord.Value = valorOpcional or "Comprada"
		novoRecord.Parent = invJogador
	end)
end

-- Remove no máximo um recibo correspondente. Se já não existir, não é erro (idempotente).
local function removerReciboSave(player, nomeDoItem, valorOpcional)
	local invJogador = player:FindFirstChild("InventarioFerramentas")
	if not invJogador then
		return
	end

	local nomeUnderline = string.gsub(nomeDoItem, " ", "_")
	local nomeEspaco = string.gsub(nomeDoItem, "_", " ")

	for _, record in ipairs(invJogador:GetChildren()) do
		if record.Name == nomeDoItem or record.Name == nomeUnderline or record.Name == nomeEspaco then
			if not valorOpcional or record.Value == valorOpcional then
				local nomeRecibo = record.Name
				pcall(function()
					record:Destroy()
				end)
				print("[Prateleira] Recibo removido (anti-dupe): " .. nomeRecibo)
				return
			end
		end
	end
	-- Segunda chamada ou recibo já consumido — comportamento esperado, sem warn.
end

local function jogadorEAdmin(player)
	return ADMINS_PERMITIDOS[player.Name] == true or ADMINS_PERMITIDOS[player.UserId] == true
end

local function parentToolParaJogador(player, tool)
	if not tool or not player then
		return
	end
	local char = player.Character
	if char then
		tool.Parent = char
	else
		local bp = player:FindFirstChild("Backpack")
		if bp then
			tool.Parent = bp
		end
	end
end

local ultimoUsoSlot = {}

for _, slotPart in ipairs(prateleira:GetChildren()) do
	if eSlotPart(slotPart) then
		local prompt = slotPart:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(playerClicou)
				if not playerClicou or not playerClicou:IsA("Player") then
					return
				end

				local agora = os.clock()
				if ultimoUsoSlot[slotPart] and (agora - ultimoUsoSlot[slotPart]) < DEBOUNCE_PROMPT then
					return
				end
				ultimoUsoSlot[slotPart] = agora

				local donoNome = getDonoDaCasa()
				local isAdmin = jogadorEAdmin(playerClicou)
				local isDono = donoNome and (playerClicou.Name == donoNome)

				if not isDono and not isAdmin then
					warn("[Prateleira] Bloqueado: só o dono ou admin pode usar esta prateleira.")
					return
				end

				if not donoNome then
					warn("[Prateleira] Dono da casa não identificado.")
					return
				end

				local donoDaCasaPlayer = Players:FindFirstChild(donoNome)
				if not donoDaCasaPlayer then
					warn("[Prateleira] O dono desta casa não está no servidor.")
					return
				end

				local prateleiraData = donoDaCasaPlayer:FindFirstChild(NOME_PASTA_PRATELEIRA_DATA)
				if not prateleiraData then
					return
				end

				local slotData = prateleiraData:FindFirstChild(slotPart.Name)
				if not slotData or not slotData:IsA("StringValue") then
					return
				end

				local caixaVisual = slotPart:FindFirstChild("CaixaVisual")

				if caixaVisual then
					local tipoDePeca = caixaVisual:GetAttribute("TipoDePeca")

					if tipoDePeca == "Spray" then
						local corSalva = caixaVisual:FindFirstChild("CorSalva")
						if corSalva then
							local toolOriginal = ServerStorage:FindFirstChild("TintaSpray")
							if toolOriginal then
								local ok, novaTool = pcall(function()
									return toolOriginal:Clone()
								end)
								if ok and novaTool then
									local rgb = string.split(corSalva.Value, ",")
									if #rgb == 3 then
										local r, g, b = tonumber(rgb[1]), tonumber(rgb[2]), tonumber(rgb[3])
										if r and g and b then
											local corValue = Instance.new("Color3Value")
											corValue.Name = "CorDaTinta"
											corValue.Value = Color3.fromRGB(r, g, b)
											corValue.Parent = novaTool
										end
									end
									parentToolParaJogador(playerClicou, novaTool)
									adicionarReciboSave(playerClicou, "TintaSpray", corSalva.Value)
									slotData.Value = ""
									ultimoUsoSlot[slotPart] = os.clock()
								end
							end
						end
					elseif tipoDePeca == "Galao" then
						local toolOriginal = ServerStorage:FindFirstChild("Gasolina5l")
						if toolOriginal then
							local ok, novaTool = pcall(function()
								return toolOriginal:Clone()
							end)
							if ok and novaTool then
								parentToolParaJogador(playerClicou, novaTool)
								adicionarReciboSave(playerClicou, "Gasolina5l")
								slotData.Value = ""
								ultimoUsoSlot[slotPart] = os.clock()
							end
						end
					elseif tipoDePeca == "Suspensao" then
						local nomeValue = caixaVisual:FindFirstChild("NomeDaSuspensao")
						if nomeValue then
							local toolOriginal = ServerStorage:FindFirstChild(nomeValue.Value)
							if toolOriginal then
								local ok, novaTool = pcall(function()
									return toolOriginal:Clone()
								end)
								if ok and novaTool then
									parentToolParaJogador(playerClicou, novaTool)
									adicionarReciboSave(playerClicou, nomeValue.Value)
									slotData.Value = ""
									ultimoUsoSlot[slotPart] = os.clock()
								end
							end
						end
					elseif tipoDePeca == "ECU" then
						local nomeValue = caixaVisual:FindFirstChild("NomeDaECU")
						if nomeValue then
							local toolOriginal = ServerStorage:FindFirstChild(nomeValue.Value)
							if toolOriginal then
								local ok, novaTool = pcall(function()
									return toolOriginal:Clone()
								end)
								if ok and novaTool then
									parentToolParaJogador(playerClicou, novaTool)
									adicionarReciboSave(playerClicou, nomeValue.Value)
									slotData.Value = ""
									ultimoUsoSlot[slotPart] = os.clock()
								end
							end
						end
					else
						local tipoRoda = caixaVisual:FindFirstChild("TipoDeRoda")
						local cliquesValue = caixaVisual:FindFirstChild("CliquesSalvos")
						local isPremium = caixaVisual:GetAttribute("Premium") == true

						if tipoRoda then
							local nomeDaFerramenta = isPremium and "CaixaPremium" or "CaixaBase"
							local toolOriginal = ServerStorage:FindFirstChild(nomeDaFerramenta)
							if toolOriginal then
								local ok, novaTool = pcall(function()
									return toolOriginal:Clone()
								end)
								if ok and novaTool then
									novaTool.Name = "Caixa " .. tipoRoda.Value
									local valorParaCarro = tipoRoda:Clone()
									valorParaCarro.Parent = novaTool
									if isPremium then
										novaTool:SetAttribute("Premium", true)
									end
									novaTool:SetAttribute("CliquesDeInstalacao", cliquesValue and cliquesValue.Value or 0)
									parentToolParaJogador(playerClicou, novaTool)

									local nomeRodaPegar = string.gsub(tipoRoda.Value, " ", "_")
									adicionarReciboSave(playerClicou, nomeRodaPegar)
									slotData.Value = ""
									ultimoUsoSlot[slotPart] = os.clock()
								end
							end
						end
					end
				else
					local character = playerClicou.Character
					if not character then
						return
					end

					local toolNaMao = character:FindFirstChildOfClass("Tool")
					if not toolNaMao then
						return
					end

					local isSuspensao = toolNaMao:GetAttribute("TipoDePeca") == "Suspensao"
					local isECU = string.find(toolNaMao.Name, "CaixaECU", 1, true) ~= nil
					local isCaixaDeRoda = string.find(toolNaMao.Name, "Caixa", 1, true) ~= nil
						and toolNaMao:FindFirstChild("TipoDeRoda") ~= nil
					local isGalao = toolNaMao.Name == "Gasolina5l"
					local isSpray = toolNaMao.Name == "TintaSpray"

					local humanoid = character:FindFirstChildOfClass("Humanoid")

					if isSpray then
						local corV = toolNaMao:FindFirstChild("CorDaTinta")
						local corString = "255,255,255"
						if corV and corV:IsA("Color3Value") then
							local c = corV.Value
							corString = math.floor(c.R * 255) .. "," .. math.floor(c.G * 255) .. "," .. math.floor(c.B * 255)
						end
						removerReciboSave(playerClicou, "TintaSpray", corString)
						if humanoid then
							humanoid:UnequipTools()
						end
						task.wait(0.1)
						pcall(function()
							toolNaMao:Destroy()
						end)
						slotData.Value = "SPRAY|" .. corString
						ultimoUsoSlot[slotPart] = os.clock()
					elseif isGalao then
						removerReciboSave(playerClicou, "Gasolina5l")
						if humanoid then
							humanoid:UnequipTools()
						end
						task.wait(0.1)
						pcall(function()
							toolNaMao:Destroy()
						end)
						slotData.Value = "GALAO|Gasolina5l"
						ultimoUsoSlot[slotPart] = os.clock()
					elseif isSuspensao then
						removerReciboSave(playerClicou, toolNaMao.Name)
						if humanoid then
							humanoid:UnequipTools()
						end
						task.wait(0.1)
						slotData.Value = "SUSPENSAO|" .. toolNaMao.Name
						pcall(function()
							toolNaMao:Destroy()
						end)
						ultimoUsoSlot[slotPart] = os.clock()
					elseif isECU then
						removerReciboSave(playerClicou, toolNaMao.Name)
						if humanoid then
							humanoid:UnequipTools()
						end
						task.wait(0.1)
						slotData.Value = "ECU|" .. toolNaMao.Name
						pcall(function()
							toolNaMao:Destroy()
						end)
						ultimoUsoSlot[slotPart] = os.clock()
					elseif isCaixaDeRoda then
						local tipoRodaVal = toolNaMao:FindFirstChild("TipoDeRoda")
						if not tipoRodaVal or not tipoRodaVal:IsA("StringValue") then
							warn("[Prateleira] Caixa sem TipoDeRoda válido.")
							return
						end
						local tipoRoda = tipoRodaVal.Value
						local cliquesGastos = toolNaMao:GetAttribute("CliquesDeInstalacao") or 0
						local isPremiumRoda = toolNaMao:GetAttribute("Premium") == true

						local nomeRodaGuardar = string.gsub(tipoRoda, " ", "_")
						removerReciboSave(playerClicou, nomeRodaGuardar)

						local hum = humanoid
						local animator = hum and hum:FindFirstChildOfClass("Animator")
						if animator then
							for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
								local anim = track.Animation
								if anim and string.find(anim.AnimationId, ANIM_ID_SNIPPET, 1, true) then
									track:Stop()
								end
							end
						end
						if hum then
							hum:UnequipTools()
						end
						task.wait(0.1)
						pcall(function()
							toolNaMao:Destroy()
						end)

						slotData.Value = tipoRoda .. "|" .. cliquesGastos .. "|" .. (isPremiumRoda and "true" or "false")
						ultimoUsoSlot[slotPart] = os.clock()
					else
						warn("[Prateleira] Segura uma caixa de rodas, suspensão, ECU, galão ou spray para guardar.")
					end
				end
			end)
		end
	end
end
