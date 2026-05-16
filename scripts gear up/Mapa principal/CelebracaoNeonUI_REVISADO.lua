-- CH Corporations - Celebração Neon + barra de tempo (StarterPlayerScripts)
-- Revisão: remotes/canais com timeout; sem task.wait no OnClientEvent; tweens canceláveis + token de geração;
--          texto truncado; não cria RemoteEvent no cliente; som e chat em pcall.

print("CH Corporations - Sistema de Celebração Neon (revisão cliente)")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer

local REMOTE_TIMEOUT = 60
local CHAT_TIMEOUT = 8
local TEMPO_EXIBICAO = 6
local TEXTO_ITEM_MAX = 120
local NOME_JOGADOR_MAX = 50

local eventoCelebracao = ReplicatedStorage:WaitForChild("CelebracaoCompraEvent", REMOTE_TIMEOUT)
if not eventoCelebracao or not eventoCelebracao:IsA("RemoteEvent") then
	warn("[CelebracaoUI] CelebracaoCompraEvent em falta.")
	return
end

local eventoAnuncio = ReplicatedStorage:FindFirstChild("AnuncioGlobalEvent")
if not eventoAnuncio or not eventoAnuncio:IsA("RemoteEvent") then
	warn("[CelebracaoUI] AnuncioGlobalEvent em falta no servidor — anúncios no chat desativados.")
	eventoAnuncio = nil
end

local function truncar(s, maxLen)
	if type(s) ~= "string" then
		s = tostring(s)
	end
	maxLen = maxLen or 80
	if #s <= maxLen then
		return s
	end
	return string.sub(s, 1, maxLen - 1) .. "…"
end

local function escaparHtmlBasico(s, maxLen)
	s = truncar(s, maxLen or TEXTO_ITEM_MAX)
	s = string.gsub(s, "&", "&amp;")
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	return s
end

local pGui = player:WaitForChild("PlayerGui", 30)
if not pGui then
	warn("[CelebracaoUI] PlayerGui em falta.")
	return
end

local guiVelha = pGui:FindFirstChild("CH_CelebracaoUI")
if guiVelha then
	guiVelha:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CH_CelebracaoUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = pGui

local Banner = Instance.new("Frame")
Banner.Size = UDim2.new(0, 400, 0, 90)
Banner.Position = UDim2.new(0.5, -200, 0, -120)
Banner.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
Banner.Parent = gui

local cornerBanner = Instance.new("UICorner")
cornerBanner.CornerRadius = UDim.new(0, 12)
cornerBanner.Parent = Banner

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(85, 255, 127)
Stroke.Thickness = 3
Stroke.Parent = Banner

local TxtTitulo = Instance.new("TextLabel")
TxtTitulo.Size = UDim2.new(1, 0, 0.4, 0)
TxtTitulo.Position = UDim2.new(0, 0, 0.05, 0)
TxtTitulo.BackgroundTransparency = 1
TxtTitulo.Text = "🎉 SUCESSO!"
TxtTitulo.TextColor3 = Color3.fromRGB(85, 255, 127)
TxtTitulo.Font = Enum.Font.GothamBlack
TxtTitulo.TextSize = 22
TxtTitulo.Parent = Banner

local TxtItem = Instance.new("TextLabel")
TxtItem.Size = UDim2.new(1, 0, 0.4, 0)
TxtItem.Position = UDim2.new(0, 0, 0.45, 0)
TxtItem.BackgroundTransparency = 1
TxtItem.Text = "Você recebeu: Item"
TxtItem.TextColor3 = Color3.fromRGB(255, 255, 255)
TxtItem.Font = Enum.Font.GothamBold
TxtItem.TextSize = 16
TxtItem.TextWrapped = true
TxtItem.Parent = Banner

local FundoBarra = Instance.new("Frame")
FundoBarra.Size = UDim2.new(1, -40, 0, 6)
FundoBarra.Position = UDim2.new(0, 20, 1, -15)
FundoBarra.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FundoBarra.Parent = Banner

local cornerFundo = Instance.new("UICorner")
cornerFundo.CornerRadius = UDim.new(1, 0)
cornerFundo.Parent = FundoBarra

local BarraTempo = Instance.new("Frame")
BarraTempo.Size = UDim2.new(1, 0, 1, 0)
BarraTempo.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
BarraTempo.Parent = FundoBarra

local cornerBarra = Instance.new("UICorner")
cornerBarra.CornerRadius = UDim.new(1, 0)
cornerBarra.Parent = BarraTempo

local SomSucesso = Instance.new("Sound")
SomSucesso.SoundId = "rbxassetid://2865227271"
SomSucesso.Volume = 1
SomSucesso.Parent = Banner

local geracaoAnim = 0
local tweenDescer, tweenSubir, tweenBarra

local function cancelarTweensCelebracao()
	if tweenDescer then
		pcall(function()
			tweenDescer:Cancel()
		end)
		tweenDescer = nil
	end
	if tweenSubir then
		pcall(function()
			tweenSubir:Cancel()
		end)
		tweenSubir = nil
	end
	if tweenBarra then
		pcall(function()
			tweenBarra:Cancel()
		end)
		tweenBarra = nil
	end
end

eventoCelebracao.OnClientEvent:Connect(function(nomeDoItem, isDoacao)
	geracaoAnim += 1
	local minhaGeracao = geracaoAnim

	cancelarTweensCelebracao()

	local itemTxt = truncar(nomeDoItem or "?", TEXTO_ITEM_MAX)

	if isDoacao == true then
		TxtTitulo.Text = "🎁 PRESENTE VIP!"
		Stroke.Color = Color3.fromRGB(0, 255, 255)
		TxtTitulo.TextColor3 = Color3.fromRGB(0, 255, 255)
		BarraTempo.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	else
		TxtTitulo.Text = "🎉 COMPRA APROVADA!"
		Stroke.Color = Color3.fromRGB(85, 255, 127)
		TxtTitulo.TextColor3 = Color3.fromRGB(85, 255, 127)
		BarraTempo.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
	end

	TxtItem.Text = "Você recebeu: " .. itemTxt
	BarraTempo.Size = UDim2.new(1, 0, 1, 0)
	Banner.Position = UDim2.new(0.5, -200, 0, -120)

	pcall(function()
		SomSucesso:Play()
	end)

	tweenDescer = TweenService:Create(Banner, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -200, 0, 50),
	})
	tweenBarra = TweenService:Create(BarraTempo, TweenInfo.new(TEMPO_EXIBICAO, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 1, 0),
	})

	tweenDescer:Play()
	tweenBarra:Play()

	tweenBarra.Completed:Once(function()
		if minhaGeracao ~= geracaoAnim then
			return
		end
		tweenSubir = TweenService:Create(Banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -200, 0, -120),
		})
		tweenSubir.Completed:Once(function()
			if minhaGeracao ~= geracaoAnim then
				return
			end
			tweenSubir = nil
		end)
		tweenSubir:Play()
	end)
end)

if eventoAnuncio then
	eventoAnuncio.OnClientEvent:Connect(function(nomeDoJogador, nomeDoItem, isDoacao)
		local canais = TextChatService:WaitForChild("TextChannels", CHAT_TIMEOUT)
		if not canais then
			return
		end
		local channel = canais:FindFirstChild("RBXGeneral") or canais:FindFirstChild("RBXSystem")
		if not channel then
			return
		end

		local nj = escaparHtmlBasico(nomeDoJogador or "?", NOME_JOGADOR_MAX)
		local ni = escaparHtmlBasico(nomeDoItem or "?", TEXTO_ITEM_MAX)

		local mensagem
		if isDoacao == true then
			mensagem = "<font color='#00FFFF'><b>[🎁 EVENTO]</b> O jogador <b>"
				.. nj
				.. "</b> acabou de receber: <b>"
				.. ni
				.. "</b>! ✨</font>"
		else
			mensagem = "<font color='#28C850'><b>[🛒 LOJA]</b> O jogador <b>"
				.. nj
				.. "</b> acabou de adquirir: <b>"
				.. ni
				.. "</b>! 🎉</font>"
		end

		pcall(function()
			channel:DisplaySystemMessage(mensagem)
		end)
	end)
end
