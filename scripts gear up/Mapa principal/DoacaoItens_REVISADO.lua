-- CH Corporations - Sistema de doação (caixa / gasolina / suspensão / tinta spray)
-- Revisão: resolve alvo por Player ou UserId; distância + humanoid vivo; ferramenta explícita ou primeira elegível;
--          spray: não duplica registo com mesma cor; Premium bloqueado; RemoteEvent com timeout.

print("CH Corporations - Sistema de Doação (Atualizado c/ Tinta Spray e Anti-Dupe de Cores)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local doarEvento = ReplicatedStorage:WaitForChild("DoarCaixaEvent", 60)
if not doarEvento then
	warn("[Doacao] DoarCaixaEvent não encontrado.")
	return
end

local RAIO_DOACAO = 25
local ANIM_GIFT_SUB = "71909281184766"
local DEBOUNCE_SEG = 0.75

local ultimoDoacao = {}

local function limparDebounce(userId)
	ultimoDoacao[userId] = nil
end

Players.PlayerRemoving:Connect(function(p)
	limparDebounce(p.UserId)
end)

local function resolverAlvo(ref)
	if typeof(ref) == "Instance" and ref:IsA("Player") then
		return ref
	end
	if type(ref) == "number" then
		return Players:GetPlayerByUserId(ref)
	end
	return nil
end

local function itemPermitidoParaDoar(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	local nome = tool.Name
	local lower = string.lower(nome)
	local temNomeCaixa = string.find(nome, "Caixa", 1, true) ~= nil
	local ehGasolina = nome == "Gasolina5l"
	local ehSuspensao = tool:GetAttribute("TipoDePeca") == "Suspensao" or string.find(lower, "suspensao", 1, true) ~= nil
	local ehSpray = nome == "TintaSpray"

	return temNomeCaixa or ehGasolina or ehSuspensao or ehSpray
end

local function obterToolDoacao(character, toolRef)
	if typeof(toolRef) == "Instance" and toolRef:IsA("Tool") and toolRef.Parent == character and itemPermitidoParaDoar(toolRef) then
		return toolRef
	end
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("Tool") and itemPermitidoParaDoar(c) then
			return c
		end
	end
	return nil
end

local function pararAnimPresente(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local anim = track.Animation
		if anim and string.find(anim.AnimationId, ANIM_GIFT_SUB, 1, true) then
			track:Stop()
		end
	end
end

local function corParaStringSave(c)
	if typeof(c) ~= "Color3" then
		return nil
	end
	return string.format("%d,%d,%d", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

doarEvento.OnServerEvent:Connect(function(player, alvoRef, toolRef)
	local uid = player.UserId
	local agora = os.clock()
	if ultimoDoacao[uid] and (agora - ultimoDoacao[uid]) < DEBOUNCE_SEG then
		return
	end

	local targetPlayer = resolverAlvo(alvoRef)
	if not targetPlayer or targetPlayer == player or not targetPlayer.Parent then
		return
	end

	local charD = player.Character
	local charR = targetPlayer.Character
	if not charD or not charR then
		return
	end

	local humD = charD:FindFirstChildOfClass("Humanoid")
	local humR = charR:FindFirstChildOfClass("Humanoid")
	if not humD or not humR or humD.Health <= 0 or humR.Health <= 0 then
		return
	end

	local rootD = charD:FindFirstChild("HumanoidRootPart")
	local rootR = charR:FindFirstChild("HumanoidRootPart")
	if not rootD or not rootR then
		return
	end
	if (rootD.Position - rootR.Position).Magnitude > RAIO_DOACAO then
		warn("⛔ Doação: " .. player.Name .. " longe demais de " .. targetPlayer.Name)
		return
	end

	local tool = obterToolDoacao(charD, toolRef)
	if not tool then
		warn("⛔ " .. player.Name .. " tentou doar sem item válido na mão/personagem.")
		return
	end

	if tool:GetAttribute("Premium") == true then
		warn("⛔ DOAÇÃO BLOQUEADA: item Premium (" .. player.Name .. " → " .. targetPlayer.Name .. ")")
		return
	end

	local humanoid = humD
	if humanoid then
		pararAnimPresente(humanoid)
		humanoid:UnequipTools()
	end

	task.wait(0.1)

	if tool.Parent ~= player.Backpack and tool.Parent ~= charD then
		return
	end

	local invDoador = player:FindFirstChild("InventarioFerramentas")
	local invRecebedor = targetPlayer:FindFirstChild("InventarioFerramentas")
	if not invRecebedor then
		return
	end

	local nomeSave = tool.Name
	local valorSaveDoador = "Comprada"
	local valorSaveRecebedor = "Recebido"

	local tipoRoda = tool:FindFirstChild("TipoDeRoda")
	local isCaixaDeRoda = string.find(tool.Name, "Caixa", 1, true) ~= nil and tipoRoda and tipoRoda:IsA("StringValue")

	if isCaixaDeRoda then
		nomeSave = string.gsub(tipoRoda.Value, " ", "_")
	elseif tool.Name == "TintaSpray" then
		local corV = tool:FindFirstChild("CorDaTinta")
		if corV and corV:IsA("Color3Value") then
			local corString = corParaStringSave(corV.Value)
			if corString then
				valorSaveDoador = corString
				valorSaveRecebedor = corString
			end
		end
	end

	if tool.Name == "TintaSpray" then
		for _, record in ipairs(invRecebedor:GetChildren()) do
			if record.Name == nomeSave and record.Value == valorSaveRecebedor then
				warn("[Doacao] " .. targetPlayer.Name .. " já tem TintaSpray com esta cor — doação cancelada.")
				return
			end
		end
	end

	if invDoador then
		for _, record in ipairs(invDoador:GetChildren()) do
			if record.Name == nomeSave then
				if tool.Name ~= "TintaSpray" or record.Value == valorSaveDoador then
					pcall(function()
						record:Destroy()
					end)
					break
				end
			end
		end
	end

	local novoRecord = Instance.new("StringValue")
	novoRecord.Name = nomeSave
	novoRecord.Value = valorSaveRecebedor
	novoRecord.Parent = invRecebedor

	local backpack = targetPlayer:FindFirstChild("Backpack") or targetPlayer:WaitForChild("Backpack", 5)
	if not backpack then
		pcall(function()
			novoRecord:Destroy()
		end)
		warn("[Doacao] Sem Backpack para " .. targetPlayer.Name)
		return
	end

	local ok = pcall(function()
		tool.Parent = backpack
	end)
	if not ok then
		pcall(function()
			novoRecord:Destroy()
		end)
		if invDoador then
			local rollback = Instance.new("StringValue")
			rollback.Name = nomeSave
			rollback.Value = (tool.Name == "TintaSpray") and valorSaveDoador or "Comprada"
			rollback.Parent = invDoador
		end
		warn("[Doacao] Falha ao parentar tool — save revertido para " .. player.Name)
		return
	end

	ultimoDoacao[uid] = agora
	print("🎁 SUCESSO! " .. player.Name .. " doou " .. tool.Name .. " para " .. targetPlayer.Name)
end)
