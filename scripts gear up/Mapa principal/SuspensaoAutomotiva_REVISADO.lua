-- CH Corporations - Suspensão automotiva (garagem + Save Master V2)
-- Revisão: validação de Model/Tool; AreaGaragem como BasePart; limites em Altura/Rigidez/Amortecimento;
--          debounce; RemoteEvent com timeout; animação com string.find literal.

print("CH Corporations - Sistema de Suspensão Automotiva Carregado (ATUALIZADO V2)")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local instalarEvento = ReplicatedStorage:WaitForChild("InstalarSuspensaoEvent", 60)
if not instalarEvento then
	warn("[Suspensao] InstalarSuspensaoEvent não encontrado.")
	return
end

local ANIM_GIFT_SUB = "71909281184766"
local DEBOUNCE_SEG = 0.75

local ALTURA_MIN, ALTURA_MAX = 0.3, 8
local RIGIDEZ_MIN, RIGIDEZ_MAX = 100, 80000
local AMORT_MIN, AMORT_MAX = 0, 20000

local ultimo = {}

Players.PlayerRemoving:Connect(function(p)
	ultimo[p.UserId] = nil
end)

local function obterAreaGaragemPart(casa)
	if not casa then
		return nil
	end
	local ag = casa:FindFirstChild("AreaGaragem", true)
	if ag and ag:IsA("BasePart") then
		return ag
	end
	if ag and ag:IsA("Model") then
		if ag.PrimaryPart then
			return ag.PrimaryPart
		end
		return ag:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function carroNaGaragem(player, carModel)
	local lotes = Workspace:FindFirstChild("LotesDasCasas")
	if not lotes then
		return false
	end

	local loteDoPlayer = nil
	for _, lote in ipairs(lotes:GetChildren()) do
		if lote:GetAttribute("Dono") == player.Name then
			loteDoPlayer = lote
			break
		end
	end
	if not loteDoPlayer then
		return false
	end

	local casa = loteDoPlayer:FindFirstChild("CasaDo_" .. player.Name)
	local areaGaragem = obterAreaGaragemPart(casa)
	if not areaGaragem then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { carModel }

	return #Workspace:GetPartsInPart(areaGaragem, overlapParams) > 0
end

local function obterToolSuspensao(character, toolRef)
	if typeof(toolRef) == "Instance" and toolRef:IsA("Tool") and toolRef.Parent == character then
		if toolRef:GetAttribute("TipoDePeca") == "Suspensao" then
			return toolRef
		end
	end
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute("TipoDePeca") == "Suspensao" then
			return c
		end
	end
	return nil
end

local function pararAnim(humanoid)
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

instalarEvento.OnServerEvent:Connect(function(player, carModel, toolRef)
	local uid = player.UserId
	local t = os.clock()
	if ultimo[uid] and (t - ultimo[uid]) < DEBOUNCE_SEG then
		return
	end

	if typeof(carModel) ~= "Instance" or not carModel:IsA("Model") then
		return
	end
	if not carModel:IsDescendantOf(Workspace) then
		return
	end

	local nomeEsperado = player.Name .. "sCar"
	if carModel.Name ~= nomeEsperado then
		warn("⛔ Bloqueado: " .. player.Name .. " tentou modificar o carro de outro jogador.")
		return
	end

	if not carroNaGaragem(player, carModel) then
		print("⚠️ O carro precisa estar dentro da garagem para instalar a suspensão!")
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local tool = obterToolSuspensao(character, toolRef)
	if not tool then
		return
	end

	local novaAltura = math.clamp(tonumber(tool:GetAttribute("Altura")) or 2, ALTURA_MIN, ALTURA_MAX)
	local novaRigidez = math.clamp(tonumber(tool:GetAttribute("Rigidez")) or 7000, RIGIDEZ_MIN, RIGIDEZ_MAX)
	local novoAmortecimento = math.clamp(tonumber(tool:GetAttribute("Amortecimento")) or 1200, AMORT_MIN, AMORT_MAX)

	local molasAlteradas = 0
	for _, obj in ipairs(carModel:GetDescendants()) do
		if obj:IsA("SpringConstraint") then
			obj.FreeLength = novaAltura
			obj.Stiffness = novaRigidez
			obj.Damping = novoAmortecimento
			molasAlteradas += 1
		end
	end

	if molasAlteradas == 0 then
		warn("[Suspensao] Nenhum SpringConstraint encontrado no veículo.")
		return
	end

	print("🏎️ Suspensão aplicada (" .. molasAlteradas .. " molas).")

	local inventario = player:FindFirstChild("InventarioVeiculos")
	local nomeOriginal = carModel:GetAttribute("ModeloOriginal")
	if type(nomeOriginal) ~= "string" or nomeOriginal == "" then
		warn("[Suspensao] ModeloOriginal inválido.")
	else
		local carroSave = inventario and inventario:FindFirstChild(nomeOriginal)
		if carroSave then
			carroSave:SetAttribute("SuspensaoNome", tool.Name)
			carroSave:SetAttribute("SuspensaoAltura", novaAltura)
			carroSave:SetAttribute("SuspensaoRigidez", novaRigidez)
			carroSave:SetAttribute("SuspensaoAmortecimento", novoAmortecimento)
		else
			warn("⚠️ Veículo não encontrado no inventário: " .. nomeOriginal)
		end
	end

	pararAnim(humanoid)
	humanoid:UnequipTools()

	task.wait(0.1)

	if tool.Parent ~= player.Backpack and tool.Parent ~= character then
		return
	end

	local invJogador = player:FindFirstChild("InventarioFerramentas")
	if invJogador then
		local recordUsado = invJogador:FindFirstChild(tool.Name)
		if recordUsado then
			pcall(function()
				recordUsado:Destroy()
			end)
		end
	end

	pcall(function()
		tool:Destroy()
	end)

	ultimo[uid] = os.clock()
end)
