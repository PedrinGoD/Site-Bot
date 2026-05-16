-- CH Corporations - Script no ProximityPrompt da caixa falsa na esteira (rodas)
-- Colocar como filho do ProximityPrompt (script.Parent = prompt).
-- Revisão: validação de Player; debounce; checagem de distância no servidor;
--          AvisoInventarioEvent criado se faltar (igual LojaSusp / LojaECU);
--          staff por tabela UserId; nome da roda validado; Tool verificada;
--          entrega via Backpack + EquipTool; Destroy em pcall.
-- Opcional na caixa: atributo DonoUserId (número) — mais seguro que só o nome.

local prompt = script.Parent
local caixaFalsa = prompt.Parent

if not prompt:IsA("ProximityPrompt") then
	warn("[RecolherCaixaRoda] script.Parent deve ser um ProximityPrompt.")
	script:Destroy()
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MAX_TOOLS = 3
local DEBOUNCE_SEG = 0.6
local NOME_RODA_MAX_LEN = 80

-- UserIds que podem recolher caixas de outros jogadores (mod/dev). Acrescenta aqui.
local STAFF_USER_IDS = {
	[5085681592] = true,
}

local function obterAvisoInventario()
	local ev = ReplicatedStorage:FindFirstChild("AvisoInventarioEvent")
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = "AvisoInventarioEvent"
		ev.Parent = ReplicatedStorage
	end
	return ev
end

local avisoInv = obterAvisoInventario()

local ultimoTick = 0

local function inventarioCheio(jogador)
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

	return total >= MAX_TOOLS
end

local function nomeRodaSanitizado(raw)
	if type(raw) ~= "string" then
		return nil
	end
	local s = string.gsub(raw, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	if s == "" or #s > NOME_RODA_MAX_LEN then
		return nil
	end
	for i = 1, #s do
		local b = string.byte(s, i)
		if b < 32 then
			return nil
		end
	end
	return s
end

local function pecaReferenciaCaixa()
	if caixaFalsa:IsA("Model") then
		return caixaFalsa.PrimaryPart or caixaFalsa:FindFirstChildWhichIsA("BasePart", true)
	end
	if caixaFalsa:IsA("BasePart") then
		return caixaFalsa
	end
	return nil
end

local function distanciaOk(jogador, margemExtra)
	local char = jogador.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local root = pecaReferenciaCaixa()
	if not hrp or not root then
		return false
	end
	local maxDist = prompt.MaxActivationDistance + margemExtra
	return (hrp.Position - root.Position).Magnitude <= maxDist
end

local function podeRecolher(jogador)
	if STAFF_USER_IDS[jogador.UserId] then
		return true
	end
	local donoNome = caixaFalsa:GetAttribute("Dono")
	local donoUid = caixaFalsa:GetAttribute("DonoUserId")

	if type(donoUid) == "number" and donoUid ~= jogador.UserId then
		return false
	end

	if type(donoNome) == "string" and donoNome ~= "" and donoNome ~= jogador.Name then
		if type(donoUid) ~= "number" or donoUid ~= jogador.UserId then
			return false
		end
	end

	return true
end

prompt.Triggered:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local agora = os.clock()
	if agora - ultimoTick < DEBOUNCE_SEG then
		return
	end
	ultimoTick = agora

	if not caixaFalsa.Parent then
		return
	end

	if not distanciaOk(player, 10) then
		return
	end

	if inventarioCheio(player) then
		avisoInv:FireClient(player)
		return
	end

	if not podeRecolher(player) then
		warn("[RecolherCaixaRoda] Bloqueado: " .. player.Name .. " tentou caixa de outro jogador.")
		return
	end

	local tipoDeRodaValue = caixaFalsa:FindFirstChild("TipoDeRoda")
	if not tipoDeRodaValue or not tipoDeRodaValue:IsA("StringValue") then
		return
	end

	local nomeDaRoda = nomeRodaSanitizado(tipoDeRodaValue.Value)
	if not nomeDaRoda then
		warn("[RecolherCaixaRoda] TipoDeRoda inválido na caixa.")
		return
	end

	-- Mesmo critério do original: qualquer valor “truthy” no atributo Premium.
	local isPremium = caixaFalsa:GetAttribute("Premium")
	local nomeTemplate = isPremium and "CaixaPremium" or "CaixaBase"
	local toolOriginal = ServerStorage:FindFirstChild(nomeTemplate)

	if not toolOriginal or not toolOriginal:IsA("Tool") then
		warn("[RecolherCaixaRoda] Tool em falta no ServerStorage: " .. nomeTemplate)
		return
	end

	local precoAttr = caixaFalsa:GetAttribute("PrecoPago")
	local precoPago = 0
	if type(precoAttr) == "number" then
		precoPago = math.clamp(math.floor(precoAttr), 0, 2_000_000_000)
	end

	local novaTool = toolOriginal:Clone()
	novaTool.Name = "Caixa " .. nomeDaRoda

	local valorParaCarro = tipoDeRodaValue:Clone()
	valorParaCarro.Parent = novaTool

	novaTool:SetAttribute("Preco", precoPago)
	if isPremium then
		novaTool:SetAttribute("Premium", true)
	end

	local bp = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 5)
	if not bp then
		novaTool:Destroy()
		return
	end

	novaTool.Parent = bp

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid:EquipTool(novaTool)
		end)
	end

	pcall(function()
		caixaFalsa:Destroy()
	end)

	print("[RecolherCaixaRoda] " .. player.Name .. " recolheu " .. nomeTemplate .. " (" .. nomeDaRoda .. ").")
end)
