-- CH Corporations - Gerenciador do Pódio Manual (V2)
-- Revisão: WaitForChild com timeout; callbacks _G à prova de nil; PivotTo/CFrame para Model ou BasePart;
--          banco que substitui VehicleSeat ancorado como o resto; ângulo de giro sem “pulo” em 360.

print("CH Corporations - Gerenciador do Pódio Manual (Iniciado)")

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local TIMEOUT_MAPA = 90

local podioModel = Workspace:WaitForChild("RankingVote", TIMEOUT_MAPA)
if not podioModel then
	error("[GerenciadorPodio] RankingVote não encontrado no Workspace em " .. TIMEOUT_MAPA .. "s.")
end

local function esperarFilho(pai, nome)
	local filho = pai:WaitForChild(nome, TIMEOUT_MAPA)
	if not filho then
		error("[GerenciadorPodio] '" .. nome .. "' não encontrado dentro de RankingVote.")
	end
	return filho
end

local partFirst = esperarFilho(podioModel, "First")
local partSecond = esperarFilho(podioModel, "Second")
local partThird = esperarFilho(podioModel, "Third")
local partTelao = esperarFilho(podioModel, "Telao")
local partTelaoGlobal = esperarFilho(podioModel, "TelaRankingGreal")

local VELOCIDADE_GIRO = 15 -- graus por segundo
local AJUSTE_ALTURA = 0.5

local COR_NEON = Color3.fromRGB(0, 255, 255)

-- =========================================================
-- 1. TELÃO DO SERVIDOR (TOP 3 LOCAL)
-- =========================================================
local sguiLocal = Instance.new("SurfaceGui")
sguiLocal.Name = "PainelServidor"
sguiLocal.Face = Enum.NormalId.Front
sguiLocal.CanvasSize = Vector2.new(1200, 600)
sguiLocal.Parent = partTelao

local mainFrameL = Instance.new("Frame")
mainFrameL.Size = UDim2.new(1, 0, 1, 0)
mainFrameL.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrameL.BackgroundTransparency = 0.2
mainFrameL.Parent = sguiLocal

local tLocal = Instance.new("TextLabel")
tLocal.Size = UDim2.new(1, 0, 0, 70)
tLocal.Position = UDim2.new(0, 0, 0, 10)
tLocal.Text = "👑 RANKING DO SERVIDOR 👑"
tLocal.TextColor3 = COR_NEON
tLocal.Font = Enum.Font.GothamBlack
tLocal.TextSize = 50
tLocal.BackgroundTransparency = 1
tLocal.Parent = mainFrameL

local paineisLocal = {}

local function criarPainelLocal(rank, textoRank, yPos, corPrincipal)
	local p = Instance.new("Frame")
	p.Size = UDim2.new(1, -40, 0, 160)
	p.Position = UDim2.new(0, 20, 0, yPos)
	p.BackgroundTransparency = 1
	p.Parent = mainFrameL

	local txtRank = Instance.new("TextLabel")
	txtRank.Size = UDim2.new(0, 100, 1, 0)
	txtRank.Text = textoRank
	txtRank.TextColor3 = corPrincipal
	txtRank.Font = Enum.Font.GothamBlack
	txtRank.TextSize = 70
	txtRank.BackgroundTransparency = 1
	txtRank.Parent = p

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -120, 1, 0)
	container.Position = UDim2.new(0, 120, 0, 0)
	container.BackgroundTransparency = 1
	container.Parent = p

	local txtInfoDono = Instance.new("TextLabel")
	txtInfoDono.Size = UDim2.new(1, 0, 0, 50)
	txtInfoDono.Text = "Aguardando Votos..."
	txtInfoDono.TextColor3 = Color3.fromRGB(255, 255, 255)
	txtInfoDono.Font = Enum.Font.GothamBold
	txtInfoDono.TextSize = 40
	txtInfoDono.TextXAlignment = Enum.TextXAlignment.Left
	txtInfoDono.BackgroundTransparency = 1
	txtInfoDono.Parent = container

	local txtInfoCarro = Instance.new("TextLabel")
	txtInfoCarro.Size = UDim2.new(1, 0, 0, 40)
	txtInfoCarro.Position = UDim2.new(0, 0, 0, 60)
	txtInfoCarro.Text = "Nave: ---"
	txtInfoCarro.TextColor3 = Color3.fromRGB(200, 200, 200)
	txtInfoCarro.Font = Enum.Font.GothamMedium
	txtInfoCarro.TextSize = 30
	txtInfoCarro.TextXAlignment = Enum.TextXAlignment.Left
	txtInfoCarro.BackgroundTransparency = 1
	txtInfoCarro.Parent = container

	local txtInfoLikes = Instance.new("TextLabel")
	txtInfoLikes.Size = UDim2.new(1, 0, 0, 40)
	txtInfoLikes.Position = UDim2.new(0, 0, 0, 110)
	txtInfoLikes.Text = "🔥 0 Likes"
	txtInfoLikes.TextColor3 = Color3.fromRGB(255, 120, 0)
	txtInfoLikes.Font = Enum.Font.GothamBlack
	txtInfoLikes.TextSize = 35
	txtInfoLikes.TextXAlignment = Enum.TextXAlignment.Left
	txtInfoLikes.BackgroundTransparency = 1
	txtInfoLikes.Parent = container

	paineisLocal[rank] = { Dono = txtInfoDono, Carro = txtInfoCarro, Likes = txtInfoLikes }
end

criarPainelLocal(1, "1º", 90, Color3.fromRGB(255, 215, 0))
criarPainelLocal(2, "2º", 260, Color3.fromRGB(192, 192, 192))
criarPainelLocal(3, "3º", 430, Color3.fromRGB(205, 127, 50))

-- =========================================================
-- 2. TELÃO GLOBAL (TOP 10)
-- =========================================================
local sguiGlobal = Instance.new("SurfaceGui")
sguiGlobal.Name = "PainelGlobal"
sguiGlobal.Face = Enum.NormalId.Front
sguiGlobal.CanvasSize = Vector2.new(800, 1000)
sguiGlobal.Parent = partTelaoGlobal

local mainFrameG = Instance.new("Frame")
mainFrameG.Size = UDim2.new(1, 0, 1, 0)
mainFrameG.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
mainFrameG.BackgroundTransparency = 0.1
mainFrameG.Parent = sguiGlobal

local tGlobal = Instance.new("TextLabel")
tGlobal.Size = UDim2.new(1, 0, 0, 80)
tGlobal.Position = UDim2.new(0, 0, 0, 10)
tGlobal.Text = "🌎 TOP 10 MUNDIAL 🌎"
tGlobal.TextColor3 = Color3.fromRGB(255, 100, 100)
tGlobal.Font = Enum.Font.GothamBlack
tGlobal.TextSize = 55
tGlobal.BackgroundTransparency = 1
tGlobal.Parent = mainFrameG

local listaGlobalUI = {}
for i = 1, 10 do
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -40, 0, 80)
	f.Position = UDim2.new(0, 20, 0, 20 + (i * 85))
	f.BackgroundTransparency = 0.8
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.Parent = mainFrameG

	local corRank = Color3.fromRGB(200, 200, 200)
	if i == 1 then
		corRank = Color3.fromRGB(255, 215, 0)
	elseif i == 2 then
		corRank = Color3.fromRGB(192, 192, 192)
	elseif i == 3 then
		corRank = Color3.fromRGB(205, 127, 50)
	end

	local txtPos = Instance.new("TextLabel")
	txtPos.Size = UDim2.new(0, 60, 1, 0)
	txtPos.Text = i .. "º"
	txtPos.TextColor3 = corRank
	txtPos.Font = Enum.Font.GothamBlack
	txtPos.TextSize = 40
	txtPos.BackgroundTransparency = 1
	txtPos.Parent = f

	local txtNome = Instance.new("TextLabel")
	txtNome.Size = UDim2.new(0.6, 0, 1, 0)
	txtNome.Position = UDim2.new(0, 70, 0, 0)
	txtNome.Text = "Carregando..."
	txtNome.TextColor3 = Color3.fromRGB(255, 255, 255)
	txtNome.Font = Enum.Font.GothamBold
	txtNome.TextSize = 25
	txtNome.TextXAlignment = Enum.TextXAlignment.Left
	txtNome.BackgroundTransparency = 1
	txtNome.Parent = f

	local txtFogo = Instance.new("TextLabel")
	txtFogo.Size = UDim2.new(0.3, 0, 1, 0)
	txtFogo.Position = UDim2.new(0.7, 0, 0, 0)
	txtFogo.Text = "🔥 0"
	txtFogo.TextColor3 = Color3.fromRGB(255, 120, 0)
	txtFogo.Font = Enum.Font.GothamBlack
	txtFogo.TextSize = 35
	txtFogo.TextXAlignment = Enum.TextXAlignment.Right
	txtFogo.BackgroundTransparency = 1
	txtFogo.Parent = f

	listaGlobalUI[i] = { Nome = txtNome, Fogo = txtFogo }
end

-- =========================================================
-- PÓDIO: clones e UI
-- =========================================================
local bases = { partFirst, partSecond, partThird }

local function prepararCloneParaPodio(cloneDoCarro, nomeInstancia)
	cloneDoCarro.Name = nomeInstancia

	local lixo = {}
	for _, obj in ipairs(cloneDoCarro:GetDescendants()) do
		if obj.Name == "Lights" or obj.Name == "ExhaustSmoke" then
			table.insert(lixo, obj)
		elseif
			obj:IsA("Script")
			or obj:IsA("LocalScript")
			or obj:IsA("ModuleScript")
			or obj:IsA("Constraint")
			or obj:IsA("Attachment")
			or obj:IsA("BodyMover")
			or obj:IsA("AlignPosition")
			or obj:IsA("AlignOrientation")
		then
			table.insert(lixo, obj)
		elseif obj:IsA("VehicleSeat") then
			local bancoFalso = Instance.new("Part")
			bancoFalso.Name = "SeatPlaceholder"
			bancoFalso.Size = obj.Size
			bancoFalso.CFrame = obj.CFrame
			bancoFalso.Color = obj.Color
			bancoFalso.Material = obj.Material
			bancoFalso.Transparency = obj.Transparency
			bancoFalso.Anchored = true
			bancoFalso.CanCollide = false
			bancoFalso.Massless = true
			bancoFalso.Parent = obj.Parent
			table.insert(lixo, obj)
		end
	end

	for _, objLixo in ipairs(lixo) do
		pcall(function()
			objLixo:Destroy()
		end)
	end

	for _, obj in ipairs(cloneDoCarro:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.CanCollide = false
			obj.Massless = true
			obj.Anchored = true
		end
	end
end

local function aplicarPoseNoPodio(carro, basePart, anguloRad)
	local alvo = CFrame.new(basePart.Position + Vector3.new(0, AJUSTE_ALTURA, 0)) * CFrame.Angles(0, anguloRad, 0)
	if carro:IsA("Model") then
		carro:PivotTo(alvo)
	elseif carro:IsA("BasePart") then
		carro.CFrame = alvo
	else
		warn("[GerenciadorPodio] Clone do top não é Model nem BasePart: " .. carro:GetFullName())
	end
end

_G.AtualizarPodioTop3 = function(tabelaVencedores)
	if type(tabelaVencedores) ~= "table" then
		tabelaVencedores = {}
	end

	for i = 1, 3 do
		local infoVencedor = tabelaVencedores[i]
		local ui = paineisLocal[i]
		local baseAtual = bases[i]

		local carroAntigo = baseAtual:FindFirstChild("CarroVencedor_Rank" .. i)
		if carroAntigo then
			carroAntigo:Destroy()
		end

		if infoVencedor then
			ui.Dono.Text = infoVencedor.Dono or "---"
			ui.Carro.Text = "Nave: " .. string.gsub(tostring(infoVencedor.Carro or "---"), "_", " ")
			ui.Likes.Text = "🔥 " .. tostring(infoVencedor.Likes or 0) .. " Likes"

			local cloneDoCarro = infoVencedor.Clone
			if cloneDoCarro and cloneDoCarro.Parent == nil then
				prepararCloneParaPodio(cloneDoCarro, "CarroVencedor_Rank" .. i)
				cloneDoCarro.Parent = baseAtual
				aplicarPoseNoPodio(cloneDoCarro, baseAtual, 0)
			elseif cloneDoCarro and cloneDoCarro.Parent ~= nil then
				warn("[GerenciadorPodio] Clone do rank " .. i .. " já tinha Parent; ignorado para evitar duplicar.")
			end
		else
			ui.Dono.Text = "Aguardando Votos..."
			ui.Carro.Text = "Nave: ---"
			ui.Likes.Text = "🔥 0 Likes"
		end
	end
end

_G.AtualizarRankingGlobalUI = function(tabelaTop10)
	if type(tabelaTop10) ~= "table" then
		tabelaTop10 = {}
	end

	for i = 1, 10 do
		local slot = listaGlobalUI[i]
		local dados = tabelaTop10[i]
		if dados then
			slot.Nome.Text = tostring(dados.Dono or "---")
				.. " ("
				.. string.gsub(tostring(dados.Carro or ""), "_", " ")
				.. ")"
			slot.Fogo.Text = "🔥 " .. tostring(dados.Likes or 0)
		else
			slot.Nome.Text = "---"
			slot.Fogo.Text = "🔥 0"
		end
	end
end

-- =========================================================
-- ROTAÇÃO (Heartbeat)
-- =========================================================
local anguloRad = 0

RunService.Heartbeat:Connect(function(dt)
	anguloRad = (anguloRad + math.rad(VELOCIDADE_GIRO) * dt) % (2 * math.pi)

	for i, basePart in ipairs(bases) do
		local carro = basePart:FindFirstChild("CarroVencedor_Rank" .. i)
		if carro then
			pcall(function()
				aplicarPoseNoPodio(carro, basePart, anguloRad)
			end)
		end
	end
end)
