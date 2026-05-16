-- CH Corporations - Pintura automotiva (trava de garagem + Save Master V2)
-- Revisão: car/model validados; AreaGaragem como BasePart; sem task.wait longo no handler (task.delay + checagens);
--          debounce; RemoteEvent com timeout; Workspace via serviço.

print("CH Corporations - Sistema de Pintura Automotiva (Atualizado c/ Trava de Garagem V2) Carregado")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local pintarEvento = ReplicatedStorage:WaitForChild("PintarCarroEvent", 60)
if not pintarEvento then
	warn("[Pintura] PintarCarroEvent não encontrado.")
	return
end

local TEMPO_PINTURA = 3.5
local DEBOUNCE_SEG = TEMPO_PINTURA + 0.5
local PAUSA_ANTES_CONSUMIR = 0.5

local ultimoPintura = {}

Players.PlayerRemoving:Connect(function(p)
	ultimoPintura[p.UserId] = nil
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

local function carroDentroDaGaragemDoJogador(player, carModel)
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

pintarEvento.OnServerEvent:Connect(function(player, carro)
	local uid = player.UserId
	local agora = os.clock()
	if ultimoPintura[uid] and (agora - ultimoPintura[uid]) < DEBOUNCE_SEG then
		return
	end

	if typeof(carro) ~= "Instance" or not carro:IsA("Model") then
		warn("⛔ Pintura: modelo inválido.")
		return
	end
	if not carro:IsDescendantOf(Workspace) then
		return
	end

	local nomeEsperado = player.Name .. "sCar"
	if carro.Name ~= nomeEsperado then
		warn("⛔ Você só pode pintar o seu próprio veículo!")
		return
	end

	if not carroDentroDaGaragemDoJogador(player, carro) then
		warn("⛔ " .. player.Name .. ": carro tem de estar na garagem da tua casa.")
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChild("TintaSpray")
	if not tool or not tool:IsA("Tool") or tool.Parent ~= character then
		return
	end

	local corValue = tool:FindFirstChild("CorDaTinta")
	local corFinal = Color3.fromRGB(255, 50, 50)
	if corValue and corValue:IsA("Color3Value") and typeof(corValue.Value) == "Color3" then
		corFinal = corValue.Value
	end

	local partsParaPintar = {}
	for _, obj in ipairs(carro:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "Paint" then
			table.insert(partsParaPintar, obj)
		end
	end

	if #partsParaPintar == 0 then
		warn("[Pintura] Nenhuma peça 'Paint' no veículo.")
		return
	end

	ultimoPintura[uid] = os.clock()

	local partSmoke = tool:FindFirstChild("Smoke")
	local particle = partSmoke and partSmoke:FindFirstChildWhichIsA("ParticleEmitter")
	local spraySound = partSmoke and partSmoke:FindFirstChildWhichIsA("Sound")

	if particle then
		particle.Color = ColorSequence.new(corFinal)
		particle.Enabled = true
	end
	if spraySound then
		spraySound:Play()
	end

	local tweenInfo = TweenInfo.new(TEMPO_PINTURA, Enum.EasingStyle.Linear)
	local tweens = {}
	for _, part in ipairs(partsParaPintar) do
		local tw = TweenService:Create(part, tweenInfo, { Color = corFinal })
		table.insert(tweens, tw)
		tw:Play()
	end

	print("🎨 " .. player.Name .. " está a pintar o carro na garagem...")

	local userId = player.UserId
	local toolRef = tool
	local carroRef = carro
	local nomeOriginalEsperado = carro:GetAttribute("ModeloOriginal")

	task.delay(TEMPO_PINTURA, function()
		if particle then
			particle.Enabled = false
		end
		if spraySound then
			spraySound:Stop()
		end

		local plr = Players:GetPlayerByUserId(userId)
		if not plr then
			return
		end

		if not carroRef.Parent or carroRef.Name ~= plr.Name .. "sCar" then
			return
		end

		if not carroDentroDaGaragemDoJogador(plr, carroRef) then
			warn("[Pintura] Carro saiu da garagem antes de concluir; save não aplicado.")
			return
		end

		local r = math.floor(corFinal.R * 255)
		local g = math.floor(corFinal.G * 255)
		local b = math.floor(corFinal.B * 255)
		local stringCor = r .. "," .. g .. "," .. b

		local inventario = plr:FindFirstChild("InventarioVeiculos")
		local nomeOriginal = type(nomeOriginalEsperado) == "string" and nomeOriginalEsperado ~= "" and nomeOriginalEsperado
			or carroRef:GetAttribute("ModeloOriginal")

		if type(nomeOriginal) == "string" and nomeOriginal ~= "" and inventario then
			local carroSave = inventario:FindFirstChild(nomeOriginal)
			if carroSave then
				carroSave:SetAttribute("CorDoCarro", stringCor)
				print("💾 Cor salva no veículo: " .. nomeOriginal)
			else
				warn("⚠️ Veículo não encontrado no inventário: " .. nomeOriginal)
			end
		else
			warn("⚠️ Inventário ou ModeloOriginal inválido após pintura.")
		end

		task.wait(PAUSA_ANTES_CONSUMIR)

		plr = Players:GetPlayerByUserId(userId)
		if not plr then
			return
		end

		local invJogador = plr:FindFirstChild("InventarioFerramentas")
		if invJogador then
			for _, record in ipairs(invJogador:GetChildren()) do
				if record.Name == "TintaSpray" and record.Value == stringCor then
					pcall(function()
						record:Destroy()
					end)
					print("🔥 Recibo do Spray (" .. stringCor .. ") removido.")
					break
				end
			end
		end

		if toolRef.Parent then
			pcall(function()
				toolRef:Destroy()
			end)
		end

		print("✅ Pintura concluída na garagem!")
	end)
end)
