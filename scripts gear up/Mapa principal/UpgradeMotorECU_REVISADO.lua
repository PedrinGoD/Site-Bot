-- CH Corporations - Upgrade de motor (ECU) alinhado ao Save Master V2
-- Revisão: valida Model/Tool no servidor; garagem com BasePart para GetPartsInPart; nível ECU limitado;
--          ferramenta explícita ou primeira ECU válida; debounce; Workspace via serviço.

print("CH Corporations - Sistema de Upgrade de Motor (Atualizado c/ Save Master V2) Carregado")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local instalarEvento = ReplicatedStorage:WaitForChild("InstalarECUEvent", 60)
if not instalarEvento then
	warn("[UpgradeMotor] InstalarECUEvent não encontrado.")
	return
end

local ANIM_GIFT_SUB = "71909281184766"
local NIVEL_ECU_MIN = 1
local NIVEL_ECU_MAX = 10
local DEBOUNCE_SEG = 0.75

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

local function carroNaGaragemDoJogador(player, carModel)
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

	local dentro = Workspace:GetPartsInPart(areaGaragem, overlapParams)
	return #dentro > 0
end

local function obterToolECU(character, toolRef)
	if typeof(toolRef) == "Instance" and toolRef:IsA("Tool") and toolRef.Parent == character then
		if toolRef:GetAttribute("TipoDePeca") == "ECU" then
			return toolRef
		end
	end
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute("TipoDePeca") == "ECU" then
			return c
		end
	end
	return nil
end

local function pararAnimECU(humanoid)
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
		return
	end

	if not carroNaGaragemDoJogador(player, carModel) then
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

	local tool = obterToolECU(character, toolRef)
	if not tool then
		return
	end

	local nivelAttr = tool:GetAttribute("NivelECU")
	local nivelECU = math.clamp(math.floor(tonumber(nivelAttr) or 1), NIVEL_ECU_MIN, NIVEL_ECU_MAX)

	carModel:SetAttribute("NivelECU", nivelECU)
	print("🚀 Upgrade de Motor Stage " .. nivelECU .. " instalado.")

	local inventario = player:FindFirstChild("InventarioVeiculos")
	local nomeOriginal = carModel:GetAttribute("ModeloOriginal")
	if type(nomeOriginal) ~= "string" or nomeOriginal == "" then
		warn("[UpgradeMotor] ModeloOriginal inválido no carro.")
	else
		local carroSave = inventario and inventario:FindFirstChild(nomeOriginal)
		if carroSave then
			carroSave:SetAttribute("MotorAtual", nivelECU)
			print("💾 Motor salvo no veículo: " .. nomeOriginal)
		else
			warn("[UpgradeMotor] Veículo não encontrado no inventário: " .. nomeOriginal)
		end
	end

	pararAnimECU(humanoid)
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
			print("🔥 Recibo da ECU removido do save.")
		end
	end

	pcall(function()
		tool:Destroy()
	end)

	ultimo[uid] = os.clock()
end)
