-- CH Corporations - Porta-bagagens (servidor) — Script no container do porta-malas (Model/Folder no carro)
-- Revisão: descobre dono subindo até um Model NomesCar (inclui carro filho direto de Workspace);
--          ServerStorage/Guardar/Prompt com timeout; backup com nomes únicos; ClearAllChildren em pcall;
--          resgate ao destruir porta-malas ou sair o dono; AvisoInventario sem Wait infinito;
--          find literais (Caixa/ECU/anim); RGB com tonumber; debounce no prompt; clone/parent em pcall.

print("CH Corporations - Porta-bagagens (anti-dupe + resgate — revisão)")

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local WAIT_INST = 25
local WAIT_STORAGE = 20
local DEBOUNCE_PROMPT = 0.35
local ANIM_ID_SNIPPET = "71909281184766"

local portaMalas = script.Parent
if not portaMalas then
	warn("[PortaMalas] script.Parent inválido.")
	return
end

local guardarPart = portaMalas:WaitForChild("Guardar", WAIT_INST)
if not guardarPart or not guardarPart:IsA("BasePart") then
	warn("[PortaMalas] Part 'Guardar' em falta ou inválida.")
	return
end

local prompt = guardarPart:WaitForChild("ProximityPrompt", WAIT_INST)
if not prompt or not prompt:IsA("ProximityPrompt") then
	warn("[PortaMalas] ProximityPrompt em falta.")
	return
end

prompt.ActionText = "Guardar"
prompt.ObjectText = "Porta Malas"

local avisoInventarioEvent = ReplicatedStorage:WaitForChild("AvisoInventarioEvent", WAIT_INST)
if avisoInventarioEvent and not avisoInventarioEvent:IsA("RemoteEvent") then
	warn("[PortaMalas] AvisoInventarioEvent inválido.")
	avisoInventarioEvent = nil
end

local function esperarStorage(nome)
	return ServerStorage:WaitForChild(nome, WAIT_STORAGE)
end

local caixaFalsaModelo = esperarStorage("CaixaFalsaVisual")
local caixaFalsaPremium = esperarStorage("CaixaFalsaPremium")
local caixaFalsaSuspensao = esperarStorage("CaixaFalsaSuspensao")
local caixaFalsaGalao = esperarStorage("CaixaFalsaGalao")
local caixaFalsaSpray = esperarStorage("LataSpray")

if not caixaFalsaModelo then
	warn("[PortaMalas] CaixaFalsaVisual em falta — script desativado.")
	return
end

local nomeDonoCarro = nil

local function resolverNomeDonoCarro()
	local cur = portaMalas
	while cur and cur ~= game do
		if cur:IsA("Model") then
			local dono = string.match(cur.Name, "^(.+)sCar$")
			if dono then
				nomeDonoCarro = dono
				return true
			end
		end
		cur = cur.Parent
	end
	warn("[PortaMalas] Não foi encontrado Model com nome NomesCar acima de " .. portaMalas:GetFullName())
	return false
end

resolverNomeDonoCarro()

local ultimoPromptPorPlayer = {}

local function jogadorDonoAtual()
	return nomeDonoCarro and Players:FindFirstChild(nomeDonoCarro)
end

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

local slotsDoCarro = {}
for _, obj in ipairs(portaMalas:GetChildren()) do
	if obj:IsA("BasePart") and string.match(obj.Name, "^Slot%d+") then
		local slotData = obj:FindFirstChild("DadosSlot")
		if not slotData or not slotData:IsA("StringValue") then
			if slotData then
				slotData:Destroy()
			end
			slotData = Instance.new("StringValue")
			slotData.Name = "DadosSlot"
			slotData.Value = ""
			slotData.Parent = obj
		end
		table.insert(slotsDoCarro, obj)
	end
end

table.sort(slotsDoCarro, function(a, b)
	return a.Name < b.Name
end)

local function sincronizarBackup()
	local dono = jogadorDonoAtual()
	if not dono then
		return
	end
	local backupFolder = dono:FindFirstChild("PortaMalasBackup")
	if not backupFolder then
		return
	end

	pcall(function()
		backupFolder:ClearAllChildren()
	end)

	local idx = 0
	for _, slotPart in ipairs(slotsDoCarro) do
		local sd = slotPart:FindFirstChild("DadosSlot")
		if sd and sd:IsA("StringValue") and sd.Value ~= "" then
			idx += 1
			pcall(function()
				local v = Instance.new("StringValue")
				v.Name = "PM_" .. tostring(idx)
				v.Value = sd.Value
				v.Parent = backupFolder
			end)
		end
	end
	if idx > 0 then
		print("[PortaMalas] Backup sincronizado: " .. idx .. " item(ns) — " .. dono.Name)
	end
end

local function esvaziarBackupParaPrateleira(jogador)
	if not jogador or not jogador:IsA("Player") then
		return
	end

	local backupFolder = jogador:FindFirstChild("PortaMalasBackup")
	local prateleiraData = jogador:FindFirstChild("PrateleiraData")
	local inventarioFerramentas = jogador:FindFirstChild("InventarioFerramentas")

	if not backupFolder or not prateleiraData or not inventarioFerramentas then
		return
	end

	local temItem = false
	for _, itemSalvo in ipairs(backupFolder:GetChildren()) do
		if itemSalvo:IsA("StringValue") and itemSalvo.Value ~= "" then
			temItem = true
			local guardouNaPrateleira = false

			for i = 1, 24 do
				local slot = prateleiraData:FindFirstChild("Slot" .. i)
				if slot and slot:IsA("StringValue") and slot.Value == "" then
					slot.Value = itemSalvo.Value
					guardouNaPrateleira = true
					break
				end
			end

			if not guardouNaPrateleira then
				local dados = string.split(itemSalvo.Value, "|")
				local tipo = dados[1]

				pcall(function()
					local novoRecord = Instance.new("StringValue")
					if tipo == "SPRAY" then
						novoRecord.Name = "TintaSpray"
						novoRecord.Value = dados[2] or ""
					elseif tipo == "GALAO" then
						novoRecord.Name = "Gasolina5l"
						novoRecord.Value = "Comprada"
					elseif tipo == "SUSPENSAO" then
						novoRecord.Name = dados[2] or "Suspensao"
						novoRecord.Value = "Comprada"
					elseif tipo == "ECU" then
						novoRecord.Name = dados[2] or "ECU"
						novoRecord.Value = "Comprada"
					else
						local nomeRoda = string.gsub(tostring(tipo), " ", "_")
						novoRecord.Name = nomeRoda
						novoRecord.Value = "Comprada"
					end
					novoRecord.Parent = inventarioFerramentas
				end)
			end

			pcall(function()
				itemSalvo:Destroy()
			end)
		end
	end

	if temItem then
		print("[PortaMalas] Resgate automático → prateleira/inventário: " .. jogador.Name)
	end
end

portaMalas.AncestryChanged:Connect(function(_, parent)
	if parent ~= nil then
		return
	end
	local dono = jogadorDonoAtual()
	if dono then
		sincronizarBackup()
		esvaziarBackupParaPrateleira(dono)
	end
end)

Players.PlayerRemoving:Connect(function(playerSaindo)
	ultimoPromptPorPlayer[playerSaindo] = nil
	if nomeDonoCarro and playerSaindo.Name == nomeDonoCarro then
		sincronizarBackup()
		esvaziarBackupParaPrateleira(playerSaindo)
	end
end)

local function criarCaixaVisual(slotPart, nomeDaPeca, cliques, isPremium, isSuspensao, isECU, isGalao, isSpray)
	local modeloParaClonar = caixaFalsaModelo

	if isSpray then
		modeloParaClonar = caixaFalsaSpray
	elseif isGalao then
		modeloParaClonar = caixaFalsaGalao
	elseif isSuspensao then
		modeloParaClonar = caixaFalsaSuspensao
	elseif isECU then
		local findECU = ServerStorage:FindFirstChild("CaixaFalsa" .. nomeDaPeca)
		if findECU then
			modeloParaClonar = findECU
		else
			warn("[PortaMalas] ECU visual em falta: CaixaFalsa" .. nomeDaPeca)
			return false
		end
	elseif isPremium then
		modeloParaClonar = caixaFalsaPremium
	end

	if not modeloParaClonar then
		warn("[PortaMalas] Modelo visual em falta.")
		return false
	end

	local novaCaixa
	local ok = pcall(function()
		novaCaixa = modeloParaClonar:Clone()
	end)
	if not ok or not novaCaixa then
		return false
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

	local montou = false
	if novaCaixa:IsA("BasePart") then
		montou = pcall(function()
			novaCaixa.CFrame = slotPart.CFrame * CFrame.new(0, (novaCaixa.Size.Y / 2 + slotPart.Size.Y / 2), 0)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = slotPart
			weld.Part1 = novaCaixa
			weld.Parent = slotPart
			novaCaixa.Anchored = false
			novaCaixa.CanCollide = false
			novaCaixa.Parent = slotPart
		end)
	elseif novaCaixa:IsA("Model") then
		if not novaCaixa.PrimaryPart then
			novaCaixa.PrimaryPart = novaCaixa:FindFirstChildWhichIsA("BasePart")
		end
		if not novaCaixa.PrimaryPart then
			pcall(function()
				novaCaixa:Destroy()
			end)
			return false
		end
		montou = pcall(function()
			local alturaOffset = (novaCaixa.PrimaryPart.Size.Y / 2) + (slotPart.Size.Y / 2)
			if isGalao then
				alturaOffset = alturaOffset + 0.1
			end
			if isSpray then
				alturaOffset = alturaOffset + 0.3
			end
			novaCaixa:PivotTo(slotPart.CFrame * CFrame.new(0, alturaOffset, 0))
			for _, obj in ipairs(novaCaixa:GetDescendants()) do
				if obj:IsA("BasePart") then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = slotPart
					weld.Part1 = obj
					weld.Parent = slotPart
					obj.Anchored = false
					obj.CanCollide = false
				end
			end
			novaCaixa.Parent = slotPart
		end)
	else
		montou = pcall(function()
			novaCaixa.Parent = slotPart
		end)
	end

	if not montou then
		pcall(function()
			novaCaixa:Destroy()
		end)
		return false
	end

	return true
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
				pcall(function()
					record:Destroy()
				end)
				break
			end
		end
	end
end

local function parentTool(player, tool)
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

prompt.Triggered:Connect(function(player)
	if not player or not player:IsA("Player") then
		return
	end

	local agora = os.clock()
	local ult = ultimoPromptPorPlayer[player] or 0
	if agora - ult < DEBOUNCE_PROMPT then
		return
	end
	ultimoPromptPorPlayer[player] = agora

	local character = player.Character
	if not character then
		return
	end

	local isDonoDoCarro = nomeDonoCarro ~= nil and player.Name == nomeDonoCarro
	local toolNaMao = character:FindFirstChildOfClass("Tool")

	if toolNaMao then
		local isPremium = toolNaMao:GetAttribute("Premium") == true

		if isPremium and not isDonoDoCarro then
			warn("[PortaMalas] Premium só pode ser guardado pelo dono do carro.")
			return
		end

		local isSuspensao = toolNaMao:GetAttribute("TipoDePeca") == "Suspensao"
		local isECU = string.find(toolNaMao.Name, "CaixaECU", 1, true) ~= nil
		local isCaixaDeRoda = string.find(toolNaMao.Name, "Caixa", 1, true) ~= nil
			and toolNaMao:FindFirstChild("TipoDeRoda") ~= nil
		local isGalao = toolNaMao.Name == "Gasolina5l"
		local isSpray = toolNaMao.Name == "TintaSpray"

		if isSuspensao or isECU or isCaixaDeRoda or isGalao or isSpray then
			local slotVazioEncontrado = nil
			for _, slotPart in ipairs(slotsDoCarro) do
				local slotData = slotPart:FindFirstChild("DadosSlot")
				if slotData and slotData:IsA("StringValue") and slotData.Value == "" then
					slotVazioEncontrado = slotPart
					break
				end
			end

			if not slotVazioEncontrado then
				warn("[PortaMalas] Porta-bagagens cheio.")
				return
			end

			local slotData = slotVazioEncontrado:FindFirstChild("DadosSlot")
			if not slotData or not slotData:IsA("StringValue") then
				return
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if animator then
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
						local anim = track.Animation
						if anim and string.find(anim.AnimationId, ANIM_ID_SNIPPET, 1, true) then
							track:Stop()
						end
					end
				end
				pcall(function()
					humanoid:UnequipTools()
				end)
			end

			task.wait(0.1)

			if isSpray then
				local corV = toolNaMao:FindFirstChild("CorDaTinta")
				local corString = "255,255,255"
				if corV and corV:IsA("Color3Value") then
					local c = corV.Value
					corString = math.floor(c.R * 255) .. "," .. math.floor(c.G * 255) .. "," .. math.floor(c.B * 255)
				end
				if criarCaixaVisual(slotVazioEncontrado, corString, 0, false, false, false, false, true) then
					slotData.Value = "SPRAY|" .. corString
					removerReciboSave(player, "TintaSpray", corString)
					pcall(function()
						toolNaMao:Destroy()
					end)
				else
					warn("[PortaMalas] Falha ao criar visual do spray — tool não consumida.")
				end
			elseif isGalao then
				if criarCaixaVisual(slotVazioEncontrado, "Gasolina5l", 0, false, false, false, true, false) then
					slotData.Value = "GALAO|Gasolina5l"
					removerReciboSave(player, "Gasolina5l")
					pcall(function()
						toolNaMao:Destroy()
					end)
				else
					warn("[PortaMalas] Falha ao criar visual do galão — tool não consumida.")
				end
			elseif isSuspensao then
				local nomeDaSuspensao = toolNaMao.Name
				if criarCaixaVisual(slotVazioEncontrado, nomeDaSuspensao, 0, false, true, false, false, false) then
					slotData.Value = "SUSPENSAO|" .. nomeDaSuspensao
					removerReciboSave(player, nomeDaSuspensao)
					pcall(function()
						toolNaMao:Destroy()
					end)
				else
					warn("[PortaMalas] Falha ao criar visual da suspensão — tool não consumida.")
				end
			elseif isECU then
				local nomeDaECU = toolNaMao.Name
				if criarCaixaVisual(slotVazioEncontrado, nomeDaECU, 0, false, false, true, false, false) then
					slotData.Value = "ECU|" .. nomeDaECU
					removerReciboSave(player, nomeDaECU)
					pcall(function()
						toolNaMao:Destroy()
					end)
				else
					warn("[PortaMalas] Falha ao criar visual da ECU — tool não consumida.")
				end
			elseif isCaixaDeRoda then
				local tipoRodaVal = toolNaMao:FindFirstChild("TipoDeRoda")
				if not tipoRodaVal or not tipoRodaVal:IsA("StringValue") then
					return
				end
				local tipoRoda = tipoRodaVal.Value
				local cliquesGastos = toolNaMao:GetAttribute("CliquesDeInstalacao") or 0
				local strPremium = isPremium and "true" or "false"
				local nomeRodaGuardar = string.gsub(tipoRoda, " ", "_")
				if criarCaixaVisual(slotVazioEncontrado, tipoRoda, cliquesGastos, isPremium, false, false, false, false) then
					slotData.Value = tipoRoda .. "|" .. cliquesGastos .. "|" .. strPremium
					removerReciboSave(player, nomeRodaGuardar)
					pcall(function()
						toolNaMao:Destroy()
					end)
				else
					warn("[PortaMalas] Falha ao criar visual da roda — tool não consumida.")
				end
			end

			sincronizarBackup()
		else
			warn("[PortaMalas] Item inválido para guardar.")
		end
		return
	end

	-- Pegar do porta-malas
	if inventarioCheio(player) then
		if avisoInventarioEvent then
			avisoInventarioEvent:FireClient(player)
		end
		return
	end

	local slotCheioEncontrado = nil
	for i = #slotsDoCarro, 1, -1 do
		local slotPart = slotsDoCarro[i]
		local slotData = slotPart:FindFirstChild("DadosSlot")
		if slotData and slotData:IsA("StringValue") and slotData.Value ~= "" then
			slotCheioEncontrado = slotPart
			break
		end
	end

	if not slotCheioEncontrado then
		warn("[PortaMalas] Porta-bagagens vazio.")
		return
	end

	local slotData = slotCheioEncontrado:FindFirstChild("DadosSlot")
	local caixaVisual = slotCheioEncontrado:FindFirstChild("CaixaVisual")
	if not slotData or not caixaVisual then
		return
	end

	local isItemPremium = caixaVisual:GetAttribute("Premium") == true
	if isItemPremium and not isDonoDoCarro then
		warn("[PortaMalas] Premium só pode ser retirado pelo dono.")
		return
	end

	local isSuspensao = caixaVisual:GetAttribute("TipoDePeca") == "Suspensao"
	local isECU = caixaVisual:GetAttribute("TipoDePeca") == "ECU"
	local isGalao = caixaVisual:GetAttribute("TipoDePeca") == "Galao"
	local isSpray = caixaVisual:GetAttribute("TipoDePeca") == "Spray"

	if isSpray then
		local corSalva = caixaVisual:FindFirstChild("CorSalva")
		if corSalva then
			local toolOriginal = ServerStorage:FindFirstChild("TintaSpray")
			if toolOriginal then
				local novaTool
				pcall(function()
					novaTool = toolOriginal:Clone()
				end)
				if novaTool then
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
					parentTool(player, novaTool)
					adicionarReciboSave(player, "TintaSpray", corSalva.Value)
					pcall(function()
						caixaVisual:Destroy()
					end)
					slotData.Value = ""
				end
			end
		end
	elseif isGalao then
		local toolOriginal = ServerStorage:FindFirstChild("Gasolina5l")
		if toolOriginal then
			local novaTool
			pcall(function()
				novaTool = toolOriginal:Clone()
			end)
			if novaTool then
				parentTool(player, novaTool)
				adicionarReciboSave(player, "Gasolina5l")
				pcall(function()
					caixaVisual:Destroy()
				end)
				slotData.Value = ""
			end
		end
	elseif isSuspensao then
		local nomeValue = caixaVisual:FindFirstChild("NomeDaSuspensao")
		if nomeValue then
			local toolOriginal = ServerStorage:FindFirstChild(nomeValue.Value)
			if toolOriginal then
				local novaTool
				pcall(function()
					novaTool = toolOriginal:Clone()
				end)
				if novaTool then
					parentTool(player, novaTool)
					adicionarReciboSave(player, nomeValue.Value)
					pcall(function()
						caixaVisual:Destroy()
					end)
					slotData.Value = ""
				end
			end
		end
	elseif isECU then
		local nomeValue = caixaVisual:FindFirstChild("NomeDaECU")
		if nomeValue then
			local toolOriginal = ServerStorage:FindFirstChild(nomeValue.Value)
			if toolOriginal then
				local novaTool
				pcall(function()
					novaTool = toolOriginal:Clone()
				end)
				if novaTool then
					parentTool(player, novaTool)
					adicionarReciboSave(player, nomeValue.Value)
					pcall(function()
						caixaVisual:Destroy()
					end)
					slotData.Value = ""
				end
			end
		end
	else
		local tipoRoda = caixaVisual:FindFirstChild("TipoDeRoda")
		local cliquesValue = caixaVisual:FindFirstChild("CliquesSalvos")
		if tipoRoda and tipoRoda:IsA("StringValue") then
			local nomeDaFerramenta = isItemPremium and "CaixaPremium" or "CaixaBase"
			local toolOriginal = ServerStorage:FindFirstChild(nomeDaFerramenta)
			if toolOriginal then
				local novaTool
				pcall(function()
					novaTool = toolOriginal:Clone()
				end)
				if novaTool then
					novaTool.Name = "Caixa " .. tipoRoda.Value
					local valorParaCarro = tipoRoda:Clone()
					valorParaCarro.Parent = novaTool
					if isItemPremium then
						novaTool:SetAttribute("Premium", true)
					end
					novaTool:SetAttribute("CliquesDeInstalacao", cliquesValue and cliquesValue.Value or 0)
					parentTool(player, novaTool)
					local nomeRodaPegar = string.gsub(tipoRoda.Value, " ", "_")
					adicionarReciboSave(player, nomeRodaPegar)
					pcall(function()
						caixaVisual:Destroy()
					end)
					slotData.Value = ""
				end
			end
		end
	end

	sincronizarBackup()
end)
