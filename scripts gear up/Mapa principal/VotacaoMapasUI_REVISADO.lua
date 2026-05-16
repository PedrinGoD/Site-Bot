-- CH Corporations - UI de votação de mapas (fullscreen) — LocalScript
-- Revisão: remotes com timeout + IsA; PlayerGui seguro; remove CH_VotacaoUI duplicada;
--          sessão numérica cancela countdowns sobrepostos; sem task.wait longo no resultado;
--          valida mapas/tempo; FireServer com pcall; Activated; nil-safe em TextLabel/UIStroke.

print("CH Corporations - UI de votação de mapas (revisão — anti-overlap)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_TIMEOUT = 60
local RESULTADO_VISIVEL_SEG = 4
local NOME_MAPA_MAX = 48
local TEMPO_MAX = 120

local player = Players.LocalPlayer

local playerGui = player:WaitForChild("PlayerGui", REMOTE_TIMEOUT)
if not playerGui then
	warn("[VotacaoUI] PlayerGui em falta — script desativado.")
	return
end

local function esperarRemote(nome)
	local ev = ReplicatedStorage:WaitForChild(nome, REMOTE_TIMEOUT)
	if not ev or not ev:IsA("RemoteEvent") then
		warn("[VotacaoUI]", nome, "em falta ou inválido.")
		return nil
	end
	return ev
end

local evAbrirVotacao = esperarRemote("AbrirVotacaoEvent")
local evVoto = esperarRemote("VotarMapaEvent")
local evResultado = esperarRemote("ResultadoVotacaoEvent")
local evCancelar = esperarRemote("CancelarVotacaoEvent")

if not evAbrirVotacao or not evVoto or not evResultado then
	warn("[VotacaoUI] Eventos obrigatórios em falta — script desativado.")
	return
end

local guiAntiga = playerGui:FindFirstChild("CH_VotacaoUI")
if guiAntiga then
	guiAntiga:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CH_VotacaoUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = playerGui

local FundoEscuro = Instance.new("Frame")
FundoEscuro.Size = UDim2.new(1, 0, 1, 0)
FundoEscuro.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
FundoEscuro.BackgroundTransparency = 0.1
FundoEscuro.BorderSizePixel = 0
FundoEscuro.Parent = gui

local Titulo = Instance.new("TextLabel")
Titulo.Size = UDim2.new(1, 0, 0, 80)
Titulo.Position = UDim2.new(0, 0, 0.05, 0)
Titulo.BackgroundTransparency = 1
Titulo.Text = "🗺️ ESCOLHA A PISTA"
Titulo.TextColor3 = Color3.fromRGB(0, 255, 255)
Titulo.Font = Enum.Font.GothamBlack
Titulo.TextSize = 40
Titulo.Parent = FundoEscuro

local TxtTempo = Instance.new("TextLabel")
TxtTempo.Size = UDim2.new(1, 0, 0, 40)
TxtTempo.Position = UDim2.new(0, 0, 0.15, 0)
TxtTempo.BackgroundTransparency = 1
TxtTempo.Text = "⏱️ Tempo restante: 20s"
TxtTempo.TextColor3 = Color3.fromRGB(255, 170, 0)
TxtTempo.Font = Enum.Font.GothamBold
TxtTempo.TextSize = 24
TxtTempo.Parent = FundoEscuro

local ContainerMapas = Instance.new("Frame")
ContainerMapas.Size = UDim2.new(0.8, 0, 0.6, 0)
ContainerMapas.Position = UDim2.new(0.1, 0, 0.25, 0)
ContainerMapas.BackgroundTransparency = 1
ContainerMapas.BorderSizePixel = 0
ContainerMapas.Parent = FundoEscuro

local GridMapas = Instance.new("UIGridLayout")
GridMapas.CellSize = UDim2.new(0.3, 0, 0.8, 0)
GridMapas.CellPadding = UDim2.new(0.03, 0, 0, 0)
GridMapas.HorizontalAlignment = Enum.HorizontalAlignment.Center
GridMapas.Parent = ContainerMapas

local botoesAtuais = {}
local votoConfirmado = false
local sessaoVotacao = 0

local function bumpSessao()
	sessaoVotacao += 1
	return sessaoVotacao
end

local function sanitizarMapas(mapasDisponiveis)
	if type(mapasDisponiveis) ~= "table" then
		return {}
	end
	local out = {}
	for idMapa, dadosMapa in pairs(mapasDisponiveis) do
		if type(dadosMapa) == "table" then
			local nome = dadosMapa.Nome
			local imagem = dadosMapa.Imagem
			if type(nome) == "string" and nome ~= "" and type(imagem) == "string" and imagem ~= "" then
				if #nome > NOME_MAPA_MAX then
					nome = string.sub(nome, 1, NOME_MAPA_MAX) .. "…"
				end
				out[idMapa] = { Nome = nome, Imagem = imagem }
			end
		end
	end
	return out
end

local function limparBotoes()
	for _, btn in ipairs(botoesAtuais) do
		if btn and btn.Parent then
			btn:Destroy()
		end
	end
	table.clear(botoesAtuais)
end

if evCancelar then
	evCancelar.OnClientEvent:Connect(function()
		bumpSessao()
		votoConfirmado = false
		limparBotoes()
		gui.Enabled = false
		Titulo.TextColor3 = Color3.fromRGB(0, 255, 255)
	end)
end

evAbrirVotacao.OnClientEvent:Connect(function(mapasDisponiveis, tempo)
	local sid = bumpSessao()
	votoConfirmado = false
	Titulo.Text = "🗺️ ESCOLHA A PISTA"
	Titulo.TextColor3 = Color3.fromRGB(0, 255, 255)

	local t = math.clamp(math.floor(tonumber(tempo) or 20), 0, TEMPO_MAX)
	TxtTempo.Text = "⏱️ Tempo restante: " .. tostring(t) .. "s"

	limparBotoes()

	local mapas = sanitizarMapas(mapasDisponiveis)
	for idMapa, dadosMapa in pairs(mapas) do
		local btnMapa = Instance.new("ImageButton")
		btnMapa.Name = "Mapa_" .. tostring(idMapa)
		btnMapa.Image = dadosMapa.Imagem
		btnMapa.ScaleType = Enum.ScaleType.Crop
		btnMapa.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		btnMapa.AutoButtonColor = true
		btnMapa.Parent = ContainerMapas

		local cantoBtn = Instance.new("UICorner")
		cantoBtn.CornerRadius = UDim.new(0, 16)
		cantoBtn.Parent = btnMapa

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 255, 255)
		stroke.Thickness = 0
		stroke.Parent = btnMapa

		local gradiente = Instance.new("UIGradient")
		gradiente.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 100, 100)),
		})
		gradiente.Rotation = 90
		gradiente.Parent = btnMapa

		local nomeMapa = Instance.new("TextLabel")
		nomeMapa.Size = UDim2.new(1, 0, 0.2, 0)
		nomeMapa.Position = UDim2.new(0, 0, 0.8, 0)
		nomeMapa.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		nomeMapa.BackgroundTransparency = 0.4
		nomeMapa.Text = dadosMapa.Nome
		nomeMapa.TextColor3 = Color3.fromRGB(255, 255, 255)
		nomeMapa.Font = Enum.Font.GothamBlack
		nomeMapa.TextSize = 22
		nomeMapa.Parent = btnMapa

		local cantoNome = Instance.new("UICorner")
		cantoNome.CornerRadius = UDim.new(0, 8)
		cantoNome.Parent = nomeMapa

		btnMapa.Activated:Connect(function()
			if votoConfirmado or sid ~= sessaoVotacao then
				return
			end
			votoConfirmado = true

			stroke.Thickness = 5
			stroke.Color = Color3.fromRGB(85, 255, 127)

			local ok, err = pcall(function()
				evVoto:FireServer(idMapa)
			end)
			if not ok then
				warn("[VotacaoUI] FireServer VotarMapaEvent:", err)
				votoConfirmado = false
				stroke.Thickness = 0
				stroke.Color = Color3.fromRGB(0, 255, 255)
				return
			end

			for _, outroBtn in ipairs(botoesAtuais) do
				if outroBtn ~= btnMapa and outroBtn.Parent then
					outroBtn.ImageColor3 = Color3.fromRGB(100, 100, 100)
				end
			end
		end)

		table.insert(botoesAtuais, btnMapa)
	end

	gui.Enabled = true

	task.spawn(function()
		for i = t, 0, -1 do
			if sid ~= sessaoVotacao or not gui.Enabled or not gui.Parent then
				return
			end
			TxtTempo.Text = "⏱️ Tempo restante: " .. tostring(i) .. "s"
			if i > 0 then
				task.wait(1)
			end
		end
	end)
end)

evResultado.OnClientEvent:Connect(function(mapaVencedor)
	bumpSessao()

	if type(mapaVencedor) ~= "table" or type(mapaVencedor.Nome) ~= "string" then
		warn("[VotacaoUI] Resultado inválido.")
		return
	end

	Titulo.Text = "🚀 PREPARANDO TELEPORTE..."
	Titulo.TextColor3 = Color3.fromRGB(85, 255, 127)
	TxtTempo.Text = "Vencedor: " .. mapaVencedor.Nome

	local nomeVencedor = mapaVencedor.Nome

	for _, btn in ipairs(botoesAtuais) do
		if btn.Parent then
			local lbl = btn:FindFirstChildWhichIsA("TextLabel", true)
			local stroke = btn:FindFirstChildWhichIsA("UIStroke")
			if lbl then
				if lbl.Text ~= nomeVencedor then
					btn.Visible = false
				else
					btn.Visible = true
					btn.Size = UDim2.new(0.5, 0, 0.9, 0)
					if stroke then
						stroke.Thickness = 6
						stroke.Color = Color3.fromRGB(255, 170, 0)
					end
				end
			end
		end
	end

	task.delay(RESULTADO_VISIVEL_SEG, function()
		if gui.Parent then
			gui.Enabled = false
		end
		Titulo.TextColor3 = Color3.fromRGB(0, 255, 255)
	end)
end)
