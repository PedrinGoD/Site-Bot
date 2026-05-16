-- CH Corporations - Menu loja de casas (LocalScript no ScreenGui)
-- Revisão: remotes e hierarquia UI com timeout; validação de atributos; debounce compra/spawn;
--          tweens com cancel + Completed:Once; inventário ChildRemoved; Activated; task.delay em vez de wait no clique.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer

local REMOTE_TIMEOUT = 60
local UI_TIMEOUT = 15
local ACAO_DEBOUNCE = 0.55

local spawnarCasaEvent = ReplicatedStorage:WaitForChild("SpawnarCasaEvent", REMOTE_TIMEOUT)
local comprarCasaEvent = ReplicatedStorage:WaitForChild("ComprarCasaEvent", REMOTE_TIMEOUT)
local abrirMenuEvent = ReplicatedStorage:WaitForChild("AbrirMenuCasaEvent", REMOTE_TIMEOUT)

if not spawnarCasaEvent or not spawnarCasaEvent:IsA("RemoteEvent") then
	warn("[CasaLoja] SpawnarCasaEvent inválido ou em falta.")
	return
end
if not comprarCasaEvent or not comprarCasaEvent:IsA("RemoteEvent") then
	warn("[CasaLoja] ComprarCasaEvent inválido ou em falta.")
	return
end
if not abrirMenuEvent or not abrirMenuEvent:IsA("RemoteEvent") then
	warn("[CasaLoja] AbrirMenuCasaEvent inválido ou em falta.")
	return
end

local gui = script.Parent
local frameTudo = gui:WaitForChild("Tudo", UI_TIMEOUT)
if not frameTudo then
	warn("[CasaLoja] Frame 'Tudo' em falta.")
	return
end

local innerFrame = frameTudo:WaitForChild("Frame", UI_TIMEOUT)
if not innerFrame then
	warn("[CasaLoja] Tudo.Frame em falta.")
	return
end

local scrollingFrame = innerFrame:WaitForChild("ScrollingFrame", UI_TIMEOUT)
if not scrollingFrame or not scrollingFrame:IsA("ScrollingFrame") then
	warn("[CasaLoja] ScrollingFrame em falta.")
	return
end

local uiScale = frameTudo:FindFirstChildOfClass("UIScale")
if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Parent = frameTudo
end
uiScale.Scale = 0
frameTudo.Visible = false

local tweenAtual = nil
local ultimoClickPorItem = setmetatable({}, { __mode = "k" })

local function pararTween()
	if tweenAtual then
		pcall(function()
			tweenAtual:Cancel()
		end)
		tweenAtual = nil
	end
end

local function fecharMenu()
	pararTween()
	local animacao = TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0,
	})
	tweenAtual = animacao
	animacao.Completed:Once(function()
		if tweenAtual ~= animacao then
			return
		end
		tweenAtual = nil
		frameTudo.Visible = false
	end)
	animacao:Play()
end

local function abrirMenuTween()
	pararTween()
	frameTudo.Visible = true
	local animacao = TweenService:Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	tweenAtual = animacao
	animacao.Completed:Once(function()
		if tweenAtual == animacao then
			tweenAtual = nil
		end
	end)
	animacao:Play()
end

local function lerNomeCasa(item)
	local v = item:GetAttribute("NomeDaCasa")
	if type(v) ~= "string" then
		return nil
	end
	v = string.gsub(v, "^%s+", "")
	v = string.gsub(v, "%s+$", "")
	if v == "" then
		return nil
	end
	return v
end

local function lerNumeroAttr(inst, nome, fallback)
	local v = inst:GetAttribute(nome)
	if type(v) == "number" and v == v then
		return v
	end
	if type(v) == "string" then
		local n = tonumber(v)
		if n then
			return n
		end
	end
	return fallback
end

local function lerPremium(item)
	local v = item:GetAttribute("Premium")
	if v == true or v == 1 then
		return true
	end
	if type(v) == "string" then
		local s = string.lower((string.gsub(string.gsub(v, "^%s+", ""), "%s+$", "")))
		return s == "true" or s == "1"
	end
	return false
end

local function lerPassId(item)
	local v = item:GetAttribute("PassID")
	if type(v) == "number" and v == v and v > 0 then
		return math.floor(v)
	end
	if type(v) == "string" then
		local n = tonumber(v)
		if n and n > 0 then
			return math.floor(n)
		end
	end
	return nil
end

local function lerLevelAtual()
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	local levelAtual = 1
	if levelValue and (levelValue:IsA("IntValue") or levelValue:IsA("NumberValue")) then
		levelAtual = levelValue.Value
	end
	if type(levelAtual) ~= "number" or levelAtual ~= levelAtual then
		levelAtual = 1
	end
	return math.max(0, math.floor(levelAtual))
end

local function atualizarVisuais()
	local levelAtual = lerLevelAtual()
	local inventarioCasas = player:FindFirstChild("InventarioCasas")

	for _, item in ipairs(scrollingFrame:GetChildren()) do
		if item:IsA("Frame") then
			local btn = item:FindFirstChild("Spawn")
			if not btn or not btn:IsA("GuiButton") then
				continue
			end

			local nomeDaCasa = lerNomeCasa(item)
			local premium = lerPremium(item)
			local levelNecessario = math.max(0, math.floor(lerNumeroAttr(item, "LevelNecessario", 1)))

			local jaPossui = inventarioCasas ~= nil and nomeDaCasa ~= nil and inventarioCasas:FindFirstChild(nomeDaCasa) ~= nil

			if jaPossui then
				btn.Text = "Spawnar Casa"
				btn.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
			elseif premium then
				btn.Text = "Comprar VIP"
				btn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
			elseif levelAtual < levelNecessario then
				btn.Text = "🔒 Nível " .. tostring(levelNecessario)
				btn.BackgroundColor3 = Color3.fromRGB(85, 0, 0)
			else
				local preco = math.max(0, math.floor(lerNumeroAttr(item, "Preco", 0)))
				btn.Text = "Comprar: $" .. tostring(preco)
				btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
			end
		end
	end
end

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if leaderstats then
		local levelValue = leaderstats:WaitForChild("Level", 15)
		if levelValue then
			levelValue.Changed:Connect(atualizarVisuais)
		end
	end

	local inv = player:WaitForChild("InventarioCasas", 30)
	if inv then
		inv.ChildAdded:Connect(atualizarVisuais)
		inv.ChildRemoved:Connect(atualizarVisuais)
	end

	atualizarVisuais()
end)

frameTudo:GetPropertyChangedSignal("Visible"):Connect(function()
	if frameTudo.Visible then
		atualizarVisuais()
	end
end)

local botaoFechar = frameTudo:FindFirstChild("BotaoFechar")
if botaoFechar and botaoFechar:IsA("GuiButton") then
	botaoFechar.Activated:Connect(fecharMenu)
elseif botaoFechar then
	botaoFechar.MouseButton1Click:Connect(fecharMenu)
else
	warn("[CasaLoja] BotaoFechar não encontrado.")
end

for _, item in ipairs(scrollingFrame:GetChildren()) do
	if item:IsA("Frame") then
		local btn = item:FindFirstChild("Spawn")
		if btn and btn:IsA("GuiButton") then
			btn.Activated:Connect(function()
				local agora = os.clock()
				local ult = ultimoClickPorItem[item]
				if ult and agora - ult < ACAO_DEBOUNCE then
					return
				end

				local nomeDaCasa = lerNomeCasa(item)
				if not nomeDaCasa then
					return
				end

				local premium = lerPremium(item)
				local preco = math.max(0, math.floor(lerNumeroAttr(item, "Preco", 0)))
				local levelNecessario = math.max(0, math.floor(lerNumeroAttr(item, "LevelNecessario", 1)))
				local passId = lerPassId(item)

				local inventarioCasas = player:FindFirstChild("InventarioCasas")
				local jaPossui = inventarioCasas and inventarioCasas:FindFirstChild(nomeDaCasa)

				if jaPossui then
					local loteAtual = frameTudo:GetAttribute("LoteAtual")
					if type(loteAtual) ~= "string" or loteAtual == "" then
						return
					end

					ultimoClickPorItem[item] = agora
					spawnarCasaEvent:FireServer(nomeDaCasa, loteAtual)
					btn.Text = "Spawnando..."
					fecharMenu()
					task.delay(1, atualizarVisuais)
				else
					local levelAtual = lerLevelAtual()

					if premium then
						if passId then
							ultimoClickPorItem[item] = agora
							MarketplaceService:PromptGamePassPurchase(player, passId)
						end
						return
					end

					if levelAtual < levelNecessario then
						return
					end

					ultimoClickPorItem[item] = agora
					comprarCasaEvent:FireServer(nomeDaCasa, preco, levelNecessario)
				end
			end)
		end
	end
end

abrirMenuEvent.OnClientEvent:Connect(function(nomeDoLote)
	if type(nomeDoLote) ~= "string" or nomeDoLote == "" then
		return
	end
	frameTudo:SetAttribute("LoteAtual", nomeDoLote)
	abrirMenuTween()
	atualizarVisuais()
end)
