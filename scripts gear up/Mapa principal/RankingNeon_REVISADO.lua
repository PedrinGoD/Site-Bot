-- CH Corporations - Ranking neon (semanal/mensal) — LocalScript
-- Revisão: GUI sempre criada; ligação ao AtualizarRankingEvent em task.defer (remote atrasado não esconde o botão);
--          remove GUI duplicada; valida tabelas/dados do servidor;
--          cronómetro para quando a ScreenGui some; CanvasSize da lista via UIListLayout; tween do painel com Cancel;
--          StatsCorrida com tipos seguros; Activated nos cliques; F2 mantido;
--          botão troféu: Position UDim2.new(0, 15, 0.5, 28); título sem clone (evita texto duplicado); painel com faixa, chip tempo, lista.

print("CH Corporations - Ranking neon (revisão)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local REMOTE_TIMEOUT = 60
local INTERVALO_CRONO_SEG = 1
local TEMPO_REFRESH_PADRAO = 60
local NOME_MAX_CHARS = 32

local player = Players.LocalPlayer

local playerGui = player:WaitForChild("PlayerGui", REMOTE_TIMEOUT)
if not playerGui then
	warn("[RankingNeon] PlayerGui em falta — script desativado.")
	return
end

local COR_FUNDO = Color3.fromRGB(16, 17, 26)
local COR_FUNDO_ELEVADO = Color3.fromRGB(26, 28, 40)
local COR_FUNDO_LISTA = Color3.fromRGB(22, 24, 36)
local COR_NEON_AZUL = Color3.fromRGB(0, 255, 255)
local COR_NEON_ROXO = Color3.fromRGB(170, 0, 255)
local COR_TEXTO = Color3.fromRGB(248, 248, 252)
local COR_TEXTO_SEC = Color3.fromRGB(160, 168, 190)

local PAINEL_LARG_PADRAO = 472
local PAINEL_ALT_PADRAO = 568
local PAINEL_LARG_MIN = 320
local PAINEL_ALT_MIN = 390
local MARGEM_LATERAL = 20
local MARGEM_VERTICAL = 90

local guiAntiga = playerGui:FindFirstChild("RankingNeonGui")
if guiAntiga then
	guiAntiga:Destroy()
end

local RankingGui = Instance.new("ScreenGui")
RankingGui.Name = "RankingNeonGui"
RankingGui.ResetOnSpawn = false
RankingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
RankingGui.IgnoreGuiInset = true
RankingGui.DisplayOrder = 45
RankingGui.Parent = playerGui

local tweenPainelAtual = nil
local painelAberto = false
local painelLargAtual = PAINEL_LARG_PADRAO
local painelAltAtual = PAINEL_ALT_PADRAO

local function posPainelAberto()
	return UDim2.new(0.5, -painelLargAtual / 2, 0.5, -painelAltAtual / 2)
end

local function posPainelFechado()
	return UDim2.new(0.5, -painelLargAtual / 2, 1.5, 0)
end

local BotaoAbrir = Instance.new("TextButton")
BotaoAbrir.Name = "BotaoToggleRanking"
BotaoAbrir.Size = UDim2.new(0, 50, 0, 50)
BotaoAbrir.Position = UDim2.new(0, 15, 0.5, 28)
BotaoAbrir.ZIndex = 50
BotaoAbrir.BackgroundColor3 = COR_FUNDO
BotaoAbrir.Text = "🏆"
BotaoAbrir.TextSize = 25
BotaoAbrir.AutoButtonColor = true
BotaoAbrir.Parent = RankingGui

local CantoBtnAbrir = Instance.new("UICorner")
CantoBtnAbrir.CornerRadius = UDim.new(1, 0)
CantoBtnAbrir.Parent = BotaoAbrir

local BordaBtnAbrir = Instance.new("UIStroke")
BordaBtnAbrir.Color = COR_NEON_AZUL
BordaBtnAbrir.Thickness = 2
BordaBtnAbrir.Parent = BotaoAbrir

local Painel = Instance.new("Frame")
Painel.Name = "PainelPrincipal"
Painel.Size = UDim2.new(0, painelLargAtual, 0, painelAltAtual)
Painel.Position = posPainelFechado()
Painel.ZIndex = 1
Painel.BackgroundColor3 = COR_FUNDO
Painel.BackgroundTransparency = 0.06
Painel.BorderSizePixel = 0
Painel.Parent = RankingGui

local BordaNeon = Instance.new("UIStroke")
BordaNeon.Color = COR_NEON_AZUL
BordaNeon.Thickness = 2
BordaNeon.Transparency = 0.15
BordaNeon.Parent = Painel

local Canto = Instance.new("UICorner")
Canto.CornerRadius = UDim.new(0, 16)
Canto.Parent = Painel

local faixaTopo = Instance.new("Frame")
faixaTopo.Name = "FaixaTopo"
faixaTopo.Size = UDim2.new(1, 0, 0, 5)
faixaTopo.Position = UDim2.new(0, 0, 0, 0)
faixaTopo.BackgroundColor3 = COR_NEON_AZUL
faixaTopo.BorderSizePixel = 0
faixaTopo.Parent = Painel

local gradFaixa = Instance.new("UIGradient")
gradFaixa.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COR_NEON_AZUL),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 220, 255)),
	ColorSequenceKeypoint.new(1, COR_NEON_ROXO),
})
gradFaixa.Rotation = 0
gradFaixa.Parent = faixaTopo

local cantoFaixa = Instance.new("UICorner")
cantoFaixa.CornerRadius = UDim.new(0, 4)
cantoFaixa.Parent = faixaTopo

local Titulo = Instance.new("TextLabel")
Titulo.Size = UDim2.new(1, -32, 0, 44)
Titulo.Position = UDim2.new(0, 16, 0, 18)
Titulo.BackgroundTransparency = 1
Titulo.Font = Enum.Font.GothamBlack
Titulo.Text = "🏆 RANKING DOS PILOTOS 🏆"
Titulo.TextColor3 = COR_TEXTO
Titulo.TextSize = 22
Titulo.TextXAlignment = Enum.TextXAlignment.Left
Titulo.Parent = Painel

local tituloContorno = Instance.new("UIStroke")
tituloContorno.Color = COR_NEON_AZUL
tituloContorno.Thickness = 1
tituloContorno.Transparency = 0.82
tituloContorno.Parent = Titulo

local BotaoFechar = Instance.new("TextButton")
BotaoFechar.Name = "BotaoFecharRanking"
BotaoFechar.Size = UDim2.new(0, 34, 0, 34)
BotaoFechar.Position = UDim2.new(1, -42, 0, 14)
BotaoFechar.BackgroundColor3 = Color3.fromRGB(190, 34, 34)
BotaoFechar.Text = "X"
BotaoFechar.TextColor3 = Color3.fromRGB(255, 255, 255)
BotaoFechar.TextSize = 20
BotaoFechar.Font = Enum.Font.GothamBlack
BotaoFechar.AutoButtonColor = true
BotaoFechar.ZIndex = 3
BotaoFechar.Parent = Painel

local cantoBtnFechar = Instance.new("UICorner")
cantoBtnFechar.CornerRadius = UDim.new(0, 8)
cantoBtnFechar.Parent = BotaoFechar

local bordaBtnFechar = Instance.new("UIStroke")
bordaBtnFechar.Color = Color3.fromRGB(255, 120, 120)
bordaBtnFechar.Thickness = 1
bordaBtnFechar.Transparency = 0.2
bordaBtnFechar.Parent = BotaoFechar

local SubTitulo = Instance.new("TextLabel")
SubTitulo.Size = UDim2.new(1, -32, 0, 18)
SubTitulo.Position = UDim2.new(0, 16, 0, 58)
SubTitulo.BackgroundTransparency = 1
SubTitulo.Font = Enum.Font.GothamMedium
SubTitulo.Text = "Top vitórias — escolha o período abaixo"
SubTitulo.TextColor3 = COR_TEXTO_SEC
SubTitulo.TextSize = 13
SubTitulo.TextXAlignment = Enum.TextXAlignment.Left
SubTitulo.Parent = Painel

local chipTempo = Instance.new("Frame")
chipTempo.Name = "ChipTempo"
chipTempo.Size = UDim2.new(0, 176, 0, 28)
chipTempo.Position = UDim2.new(1, -196, 0, 52)
chipTempo.BackgroundColor3 = COR_FUNDO_ELEVADO
chipTempo.BorderSizePixel = 0
chipTempo.Parent = Painel

Instance.new("UICorner", chipTempo).CornerRadius = UDim.new(0, 10)

local bordaChip = Instance.new("UIStroke")
bordaChip.Color = Color3.fromRGB(60, 70, 95)
bordaChip.Thickness = 1
bordaChip.Transparency = 0.4
bordaChip.Parent = chipTempo

local TextoTempo = Instance.new("TextLabel")
TextoTempo.Size = UDim2.new(1, -12, 1, 0)
TextoTempo.Position = UDim2.new(0, 6, 0, 0)
TextoTempo.BackgroundTransparency = 1
TextoTempo.Font = Enum.Font.GothamBold
TextoTempo.Text = "⏱️ Atualiza em: 60s"
TextoTempo.TextColor3 = Color3.fromRGB(255, 190, 90)
TextoTempo.TextSize = 12
TextoTempo.TextXAlignment = Enum.TextXAlignment.Center
TextoTempo.Parent = chipTempo

local ListaScroll = Instance.new("ScrollingFrame")
ListaScroll.Size = UDim2.new(1, -40, 1, -248)
ListaScroll.Position = UDim2.new(0, 20, 0, 132)
ListaScroll.BackgroundColor3 = COR_FUNDO_LISTA
ListaScroll.BackgroundTransparency = 0.35
ListaScroll.BorderSizePixel = 0
ListaScroll.ScrollBarThickness = 5
ListaScroll.ScrollBarImageColor3 = COR_NEON_AZUL
ListaScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ListaScroll.ClipsDescendants = true
ListaScroll.Parent = Painel

Instance.new("UICorner", ListaScroll).CornerRadius = UDim.new(0, 12)

local padLista = Instance.new("UIPadding")
padLista.PaddingTop = UDim.new(0, 10)
padLista.PaddingBottom = UDim.new(0, 10)
padLista.PaddingLeft = UDim.new(0, 8)
padLista.PaddingRight = UDim.new(0, 8)
padLista.Parent = ListaScroll

local LayoutLista = Instance.new("UIListLayout")
LayoutLista.SortOrder = Enum.SortOrder.LayoutOrder
LayoutLista.Padding = UDim.new(0, 10)
LayoutLista.Parent = ListaScroll

local function atualizarCanvasLista()
	ListaScroll.CanvasSize = UDim2.new(0, 0, 0, LayoutLista.AbsoluteContentSize.Y + 16)
end

LayoutLista:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(atualizarCanvasLista)

local lblMinhaPos = Instance.new("TextLabel")
lblMinhaPos.Name = "LabelMinhaPosicao"
lblMinhaPos.Size = UDim2.new(0, 200, 0, 14)
lblMinhaPos.Position = UDim2.new(0, 24, 1, -118)
lblMinhaPos.BackgroundTransparency = 1
lblMinhaPos.Font = Enum.Font.GothamBold
lblMinhaPos.Text = "⭐ Minha posição"
lblMinhaPos.TextColor3 = COR_TEXTO_SEC
lblMinhaPos.TextSize = 11
lblMinhaPos.TextXAlignment = Enum.TextXAlignment.Left
lblMinhaPos.Parent = Painel

local BarraPessoal = Instance.new("Frame")
BarraPessoal.Size = UDim2.new(1, -40, 0, 54)
BarraPessoal.Position = UDim2.new(0, 20, 1, -100)
BarraPessoal.BackgroundColor3 = COR_FUNDO_ELEVADO
BarraPessoal.BackgroundTransparency = 0.2
BarraPessoal.BorderSizePixel = 0
BarraPessoal.Parent = Painel

local CantoPessoal = Instance.new("UICorner")
CantoPessoal.CornerRadius = UDim.new(0, 12)
CantoPessoal.Parent = BarraPessoal

local BordaPessoal = Instance.new("UIStroke")
BordaPessoal.Color = COR_TEXTO
BordaPessoal.Thickness = 1
BordaPessoal.Transparency = 0.5
BordaPessoal.Parent = BarraPessoal

local TxtPosPessoal = Instance.new("TextLabel")
TxtPosPessoal.Size = UDim2.new(0, 50, 1, 0)
TxtPosPessoal.BackgroundTransparency = 1
TxtPosPessoal.Font = Enum.Font.GothamBold
TxtPosPessoal.Text = "#11+"
TxtPosPessoal.TextColor3 = COR_TEXTO
TxtPosPessoal.TextSize = 20
TxtPosPessoal.Parent = BarraPessoal

local TxtNomePessoal = Instance.new("TextLabel")
TxtNomePessoal.Size = UDim2.new(1, -150, 1, 0)
TxtNomePessoal.Position = UDim2.new(0, 50, 0, 0)
TxtNomePessoal.BackgroundTransparency = 1
TxtNomePessoal.Font = Enum.Font.GothamSemibold
TxtNomePessoal.Text = player.Name .. " (Você)"
TxtNomePessoal.TextColor3 = COR_TEXTO
TxtNomePessoal.TextSize = 17
TxtNomePessoal.TextTruncate = Enum.TextTruncate.AtEnd
TxtNomePessoal.TextXAlignment = Enum.TextXAlignment.Left
TxtNomePessoal.Parent = BarraPessoal

local TxtVitPessoal = Instance.new("TextLabel")
TxtVitPessoal.Size = UDim2.new(0, 100, 1, 0)
TxtVitPessoal.Position = UDim2.new(1, -100, 0, 0)
TxtVitPessoal.BackgroundTransparency = 1
TxtVitPessoal.Font = Enum.Font.GothamBold
TxtVitPessoal.Text = "0 Vit."
TxtVitPessoal.TextColor3 = COR_TEXTO
TxtVitPessoal.TextSize = 18
TxtVitPessoal.Parent = BarraPessoal

local function criarBotaoAba(nome, pos, corNeon)
	local Botao = Instance.new("TextButton")
	Botao.Size = UDim2.new(0.5, -34, 0, 40)
	Botao.Position = pos
	Botao.BackgroundColor3 = Color3.fromRGB(28, 30, 44)
	Botao.Font = Enum.Font.GothamBold
	Botao.Text = nome
	Botao.TextColor3 = COR_TEXTO
	Botao.TextSize = 15
	Botao.AutoButtonColor = true
	Botao.Parent = Painel

	local CantoBtn = Instance.new("UICorner")
	CantoBtn.CornerRadius = UDim.new(0, 10)
	CantoBtn.Parent = Botao

	local BordaBtn = Instance.new("UIStroke")
	BordaBtn.Color = corNeon
	BordaBtn.Thickness = 1
	BordaBtn.Transparency = 0.35
	BordaBtn.Parent = Botao
	return Botao
end

local BotaoSemanal = criarBotaoAba("📅 SEMANAL", UDim2.new(0, 22, 0, 86), COR_NEON_AZUL)
local BotaoMensal = criarBotaoAba("📆 MENSAL", UDim2.new(0.5, 12, 0, 86), COR_NEON_ROXO)

local dadosAtuaisSemanais = {}
local dadosAtuaisMensais = {}
local abaAtiva = "Semanal"
local tempoRestante = TEMPO_REFRESH_PADRAO

local function aplicarLayoutResponsivo()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local larguraMax = math.max(PAINEL_LARG_MIN, math.floor(viewport.X - MARGEM_LATERAL * 2))
	local alturaMax = math.max(PAINEL_ALT_MIN, math.floor(viewport.Y - MARGEM_VERTICAL))

	painelLargAtual = math.clamp(PAINEL_LARG_PADRAO, PAINEL_LARG_MIN, larguraMax)
	painelAltAtual = math.clamp(PAINEL_ALT_PADRAO, PAINEL_ALT_MIN, alturaMax)

	Painel.Size = UDim2.new(0, painelLargAtual, 0, painelAltAtual)
	Painel.Position = painelAberto and posPainelAberto() or posPainelFechado()

	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if isMobile then
		BotaoAbrir.Size = UDim2.new(0, 44, 0, 44)
		BotaoAbrir.TextSize = 22
		BotaoAbrir.Position = UDim2.new(0, 12, 0.5, 20)
	else
		BotaoAbrir.Size = UDim2.new(0, 50, 0, 50)
		BotaoAbrir.TextSize = 25
		BotaoAbrir.Position = UDim2.new(0, 15, 0.5, 28)
	end
end

local function sanitizarEntradaRanking(t)
	if type(t) ~= "table" then
		return {}
	end
	local out = {}
	for _, entrada in ipairs(t) do
		if type(entrada) == "table" then
			local nome = entrada.Nome
			local vit = entrada.Vitorias
			if type(nome) == "string" and nome ~= "" then
				if #nome > NOME_MAX_CHARS then
					nome = string.sub(nome, 1, NOME_MAX_CHARS) .. "…"
				end
				local nVit = 0
				if type(vit) == "number" then
					nVit = math.clamp(math.floor(vit), 0, 1e9)
				elseif type(vit) == "string" then
					nVit = math.clamp(tonumber(vit) or 0, 0, 1e9)
				end
				table.insert(out, { Nome = nome, Vitorias = nVit })
			end
		end
	end
	return out
end

local function lerVitoriasStats(semanal)
	local stats = player:FindFirstChild("StatsCorrida")
	if not stats then
		return 0
	end
	local nomeValor = semanal and "VitoriasSemanais" or "VitoriasMensais"
	local v = stats:FindFirstChild(nomeValor)
	if v and v:IsA("IntValue") then
		return math.max(0, v.Value)
	end
	if v and v:IsA("NumberValue") then
		return math.max(0, math.floor(v.Value))
	end
	return 0
end

task.spawn(function()
	while RankingGui.Parent do
		task.wait(INTERVALO_CRONO_SEG)
		if tempoRestante > 0 then
			tempoRestante -= 1
			TextoTempo.Text = "⏱️ Atualiza em: " .. tempoRestante .. "s"
		else
			TextoTempo.Text = "⏱️ Atualizando..."
		end
	end
end)

local function atualizarBarraPessoal()
	local rank = "11+"
	local vitorias = 0
	local lista = (abaAtiva == "Semanal") and dadosAtuaisSemanais or dadosAtuaisMensais

	vitorias = lerVitoriasStats(abaAtiva == "Semanal")

	for i, dados in ipairs(lista) do
		if dados.Nome == player.Name then
			rank = tostring(i)
			vitorias = dados.Vitorias
			break
		end
	end

	TxtPosPessoal.Text = "#" .. rank
	TxtVitPessoal.Text = tostring(vitorias) .. " Vit."

	if abaAtiva == "Semanal" then
		BordaPessoal.Color = COR_NEON_AZUL
		TxtVitPessoal.TextColor3 = COR_NEON_AZUL
		TxtPosPessoal.TextColor3 = COR_NEON_AZUL
	else
		BordaPessoal.Color = COR_NEON_ROXO
		TxtVitPessoal.TextColor3 = COR_NEON_ROXO
		TxtPosPessoal.TextColor3 = COR_NEON_ROXO
	end
end

local function adicionarLinhaRanking(posicao, nomeJogador, vitorias)
	local Linha = Instance.new("Frame")
	Linha.Size = UDim2.new(1, -6, 0, 50)
	Linha.BackgroundColor3 = Color3.fromRGB(34, 36, 52)
	Linha.BackgroundTransparency = 0.15
	Linha.BorderSizePixel = 0
	Linha.LayoutOrder = posicao
	Linha.Parent = ListaScroll

	local CantoLinha = Instance.new("UICorner")
	CantoLinha.CornerRadius = UDim.new(0, 10)
	CantoLinha.Parent = Linha

	local textoPosicao = "#" .. posicao
	local corBorda = Color3.fromRGB(55, 60, 82)
	local corTextoPos = COR_TEXTO_SEC

	if posicao == 1 then
		textoPosicao = "🏆 1"
		corBorda = Color3.fromRGB(255, 215, 0)
		corTextoPos = Color3.fromRGB(255, 230, 120)
	elseif posicao == 2 then
		textoPosicao = "🥈 2"
		corBorda = Color3.fromRGB(200, 210, 225)
		corTextoPos = Color3.fromRGB(210, 218, 235)
	elseif posicao == 3 then
		textoPosicao = "🥉 3"
		corBorda = Color3.fromRGB(212, 145, 75)
		corTextoPos = Color3.fromRGB(235, 175, 115)
	end

	local BordaLinha = Instance.new("UIStroke")
	BordaLinha.Color = corBorda
	BordaLinha.Thickness = posicao <= 3 and 2 or 1
	BordaLinha.Transparency = posicao <= 3 and 0.15 or 0.55
	BordaLinha.Parent = Linha

	local TxtPos = Instance.new("TextLabel")
	TxtPos.Size = UDim2.new(0, 56, 1, 0)
	TxtPos.Position = UDim2.new(0, 6, 0, 0)
	TxtPos.BackgroundTransparency = 1
	TxtPos.Font = Enum.Font.GothamBold
	TxtPos.Text = textoPosicao
	TxtPos.TextColor3 = corTextoPos
	TxtPos.TextSize = 18
	TxtPos.Parent = Linha

	local TxtNome = Instance.new("TextLabel")
	TxtNome.Size = UDim2.new(1, -176, 1, 0)
	TxtNome.Position = UDim2.new(0, 62, 0, 0)
	TxtNome.BackgroundTransparency = 1
	TxtNome.Font = Enum.Font.GothamSemibold
	TxtNome.Text = nomeJogador
	if nomeJogador == player.Name then
		TxtNome.TextColor3 = Color3.fromRGB(255, 235, 120)
	else
		TxtNome.TextColor3 = COR_TEXTO
	end
	TxtNome.TextSize = 17
	TxtNome.TextXAlignment = Enum.TextXAlignment.Left
	TxtNome.TextTruncate = Enum.TextTruncate.AtEnd
	TxtNome.Parent = Linha

	local TxtVitorias = Instance.new("TextLabel")
	TxtVitorias.Size = UDim2.new(0, 108, 1, 0)
	TxtVitorias.Position = UDim2.new(1, -114, 0, 0)
	TxtVitorias.BackgroundTransparency = 1
	TxtVitorias.Font = Enum.Font.GothamBold
	TxtVitorias.Text = tostring(vitorias) .. " Vit."
	TxtVitorias.TextColor3 = (abaAtiva == "Semanal") and COR_NEON_AZUL or COR_NEON_ROXO
	TxtVitorias.TextSize = 16
	TxtVitorias.TextXAlignment = Enum.TextXAlignment.Right
	TxtVitorias.Parent = Linha
end

local function limparLista()
	for _, filho in ipairs(ListaScroll:GetChildren()) do
		if filho:IsA("Frame") then
			filho:Destroy()
		end
	end
end

local function renderizarLista(lista)
	limparLista()
	for i, dados in ipairs(lista) do
		adicionarLinhaRanking(i, dados.Nome, dados.Vitorias)
	end
	atualizarCanvasLista()
	atualizarBarraPessoal()
end

local function alternarPainel()
	painelAberto = not painelAberto
	local posFinal = painelAberto and posPainelAberto() or posPainelFechado()
	if tweenPainelAtual then
		tweenPainelAtual:Cancel()
	end
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	tweenPainelAtual = TweenService:Create(Painel, tweenInfo, { Position = posFinal })
	tweenPainelAtual:Play()
end

BotaoAbrir.Activated:Connect(alternarPainel)
BotaoFechar.Activated:Connect(function()
	if painelAberto then
		alternarPainel()
	end
end)

UserInputService.InputBegan:Connect(function(input, processado)
	if processado then
		return
	end
	if input.KeyCode == Enum.KeyCode.F2 then
		alternarPainel()
	end
end)

BotaoSemanal.Activated:Connect(function()
	abaAtiva = "Semanal"
	BotaoSemanal.BackgroundColor3 = Color3.fromRGB(38, 42, 62)
	BotaoMensal.BackgroundColor3 = Color3.fromRGB(28, 30, 44)
	BordaNeon.Color = COR_NEON_AZUL
	ListaScroll.ScrollBarImageColor3 = COR_NEON_AZUL
	renderizarLista(dadosAtuaisSemanais)
end)

BotaoMensal.Activated:Connect(function()
	abaAtiva = "Mensal"
	BotaoMensal.BackgroundColor3 = Color3.fromRGB(38, 42, 62)
	BotaoSemanal.BackgroundColor3 = Color3.fromRGB(28, 30, 44)
	BordaNeon.Color = COR_NEON_ROXO
	ListaScroll.ScrollBarImageColor3 = COR_NEON_ROXO
	renderizarLista(dadosAtuaisMensais)
end)

BotaoSemanal.BackgroundColor3 = Color3.fromRGB(38, 42, 62)
aplicarLayoutResponsivo()

local function ligarResizeResponsivo()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(aplicarLayoutResponsivo)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(aplicarLayoutResponsivo)
			aplicarLayoutResponsivo()
		end
	end)
end

ligarResizeResponsivo()

task.defer(function()
	local evAtualizarRanking = ReplicatedStorage:WaitForChild("AtualizarRankingEvent", REMOTE_TIMEOUT)
	if not evAtualizarRanking or not evAtualizarRanking:IsA("RemoteEvent") then
		warn("[RankingNeon] AtualizarRankingEvent em falta ou inválido — botão do ranking continua visível, lista não atualiza.")
		return
	end

	evAtualizarRanking.OnClientEvent:Connect(function(topSemanal, topMensal)
		local ok, err = pcall(function()
			tempoRestante = TEMPO_REFRESH_PADRAO
			dadosAtuaisSemanais = sanitizarEntradaRanking(topSemanal)
			dadosAtuaisMensais = sanitizarEntradaRanking(topMensal)

			if abaAtiva == "Semanal" then
				renderizarLista(dadosAtuaisSemanais)
			else
				renderizarLista(dadosAtuaisMensais)
			end
		end)
		if not ok then
			warn("[RankingNeon] Erro ao processar ranking:", err)
		end
	end)
end)
