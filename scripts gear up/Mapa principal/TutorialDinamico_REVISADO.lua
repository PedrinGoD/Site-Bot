-- CH Corporations - Tutorial dinâmico (missão + laser GPS) — LocalScript
-- Revisão: PlayerGui/remotes com timeout + IsA; remove TutorialGui duplicada; sem task.wait longos no fluxo principal;
--          finalização com task.delay + tween Completed:Once; rastreadores só após dados existirem; limpa TutoAtt1 ao trocar alvo;
--          alvo fase 6 pode ser Model (usa PrimaryPart/BasePart); CarData opcional com timeout por filho; FireServer com pcall.

print("CH Corporations - Tutorial dinâmico (V2 — sincronizado, revisão)")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local REMOTE_TIMEOUT = 60
local WAIT_ALVOS = 60
local MAX_ESPERA_LOADING = 120
local DELAY_APOS_FIM_SEG = 5

local player = Players.LocalPlayer

local MODO_TESTE = false
local DISTANCIA_DESLIGAR_LASER = 20

local playerGui = player:WaitForChild("PlayerGui", REMOTE_TIMEOUT)
if not playerGui then
	warn("[Tutorial] PlayerGui em falta — script desativado.")
	return
end

local guiAntiga = playerGui:FindFirstChild("TutorialGui")
if guiAntiga then
	guiAntiga:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local frameMissao = Instance.new("TextButton")
frameMissao.Size = UDim2.new(0, 300, 0, 100)
frameMissao.Position = UDim2.new(1, 350, 0.5, -50)
frameMissao.AnchorPoint = Vector2.new(1, 0.5)
frameMissao.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frameMissao.BackgroundTransparency = 0.1
frameMissao.Text = ""
frameMissao.AutoButtonColor = false
frameMissao.Visible = false
frameMissao.Parent = gui

Instance.new("UICorner", frameMissao).CornerRadius = UDim.new(0, 10)

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 60, 0)
uiStroke.Thickness = 2
uiStroke.Parent = frameMissao

local tituloMissao = Instance.new("TextLabel")
tituloMissao.Size = UDim2.new(1, -20, 0, 30)
tituloMissao.Position = UDim2.new(0, 10, 0, 10)
tituloMissao.BackgroundTransparency = 1
tituloMissao.Text = "🏁 OBJETIVO ATUAL (1/6)"
tituloMissao.TextColor3 = Color3.fromRGB(255, 60, 0)
tituloMissao.Font = Enum.Font.GothamBlack
tituloMissao.TextSize = 14
tituloMissao.TextXAlignment = Enum.TextXAlignment.Left
tituloMissao.Parent = frameMissao

local descMissao = Instance.new("TextLabel")
descMissao.Size = UDim2.new(1, -20, 0, 50)
descMissao.Position = UDim2.new(0, 10, 0, 40)
descMissao.BackgroundTransparency = 1
descMissao.Text = "Pegue um carro gratuito na cabine inicial para se locomover pela cidade."
descMissao.TextColor3 = Color3.fromRGB(255, 255, 255)
descMissao.Font = Enum.Font.GothamMedium
descMissao.TextSize = 13
descMissao.TextWrapped = true
descMissao.TextXAlignment = Enum.TextXAlignment.Left
descMissao.TextYAlignment = Enum.TextYAlignment.Top
descMissao.Parent = frameMissao

local somNovaMissao = Instance.new("Sound")
somNovaMissao.SoundId = "rbxassetid://112633011754970"
somNovaMissao.Volume = 0.5
somNovaMissao.Parent = gui

local alvoAtualPart = nil
local tutorialAtivo = false
local missaoAtual = 1
local conexoes = {}
local tweenPuloAtual = nil
local jaProcessouDadosProntos = false

local function tocarSomMissao()
	pcall(function()
		somNovaMissao:Play()
	end)
end

local function removerAttAlvoEm(instancia)
	if not instancia or not instancia.Parent then
		return
	end
	local a = instancia:FindFirstChild("TutoAtt1")
	if a then
		a:Destroy()
	end
end

local function resolverParteAlvo(instancia)
	if not instancia then
		return nil
	end
	if instancia:IsA("BasePart") then
		return instancia
	end
	if instancia:IsA("Model") then
		if instancia.PrimaryPart then
			return instancia.PrimaryPart
		end
		return instancia:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function atualizarGPS()
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end

	local att0 = hrp:FindFirstChild("TutoAtt0")
	if not att0 then
		att0 = Instance.new("Attachment")
		att0.Name = "TutoAtt0"
		att0.Position = Vector3.new(0, 0, -1)
		att0.Parent = hrp
	end

	local beam = hrp:FindFirstChild("TutoBeam")
	if not beam or not beam:IsA("Beam") then
		if beam then
			beam:Destroy()
		end
		beam = Instance.new("Beam")
		beam.Name = "TutoBeam"
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 60, 0))
		beam.FaceCamera = true
		beam.Width0 = 1.0
		beam.Width1 = 1.0
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new(0)
		beam.Parent = hrp
	end

	beam.Attachment0 = att0

	if alvoAtualPart and alvoAtualPart.Parent then
		local att1 = alvoAtualPart:FindFirstChild("TutoAtt1")
		if not att1 then
			att1 = Instance.new("Attachment")
			att1.Name = "TutoAtt1"
			att1.Parent = alvoAtualPart
		end
		beam.Attachment1 = att1
		beam.Enabled = true
	else
		beam.Attachment1 = nil
		beam.Enabled = false
	end
end

RunService.Heartbeat:Connect(function()
	if not tutorialAtivo or not alvoAtualPart or not alvoAtualPart.Parent then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local beam = hrp and hrp:FindFirstChild("TutoBeam")
	if hrp and beam and beam:IsA("Beam") and beam.Attachment1 then
		local distancia = (hrp.Position - alvoAtualPart.Position).Magnitude
		beam.Enabled = distancia > DISTANCIA_DESLIGAR_LASER
	end
end)

player.CharacterAdded:Connect(function()
	task.delay(1, function()
		if tutorialAtivo then
			atualizarGPS()
		end
	end)
end)

local function definirAlvoGPS(fase)
	local alvoAntes = alvoAtualPart

	local novoAlvo = nil
	local pastaAlvos = workspace:FindFirstChild("AlvosTutorial")
	if not pastaAlvos then
		pastaAlvos = workspace:WaitForChild("AlvosTutorial", WAIT_ALVOS)
	end

	if fase == 1 and pastaAlvos then
		novoAlvo = resolverParteAlvo(pastaAlvos:FindFirstChild("Cabine"))
	elseif fase == 2 and pastaAlvos then
		novoAlvo = resolverParteAlvo(pastaAlvos:FindFirstChild("Concessionaria"))
	elseif fase == 3 and pastaAlvos then
		novoAlvo = resolverParteAlvo(pastaAlvos:FindFirstChild("GaragemPublica"))
	elseif fase == 4 then
		novoAlvo = nil
	elseif fase == 5 and pastaAlvos then
		novoAlvo = resolverParteAlvo(pastaAlvos:FindFirstChild("AutoPeca"))
	elseif fase == 6 then
		local lotes = workspace:FindFirstChild("LotesDasCasas")
		if lotes then
			for _, lote in ipairs(lotes:GetChildren()) do
				if lote:GetAttribute("Dono") == player.Name then
					local candidato = lote:FindFirstChild("PontoSpawnCarro", true) or lote:FindFirstChild("CasaDo_" .. player.Name)
					novoAlvo = resolverParteAlvo(candidato)
					break
				end
			end
		end
	else
		novoAlvo = nil
	end

	if alvoAntes and alvoAntes ~= novoAlvo then
		removerAttAlvoEm(alvoAntes)
	end

	alvoAtualPart = novoAlvo
	atualizarGPS()
end

local function desligarRastreadores()
	for _, c in ipairs(conexoes) do
		if c and c.Disconnect then
			c:Disconnect()
		end
	end
	table.clear(conexoes)
end

local function limparBeamEAttachments()
	local alvoParaLimpar = alvoAtualPart
	alvoAtualPart = nil
	removerAttAlvoEm(alvoParaLimpar)

	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local b = hrp:FindFirstChild("TutoBeam")
			if b then
				b:Destroy()
			end
			local a = hrp:FindFirstChild("TutoAtt0")
			if a then
				a:Destroy()
			end
		end
	end
end

local function atualizarTela(numero, texto)
	tituloMissao.Text = "🏁 OBJETIVO ATUAL (" .. numero .. "/6)"
	descMissao.Text = texto
	tocarSomMissao()
	definirAlvoGPS(numero)

	if tweenPuloAtual then
		tweenPuloAtual:Cancel()
	end
	tweenPuloAtual = TweenService:Create(
		frameMissao,
		TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true),
		{ Position = UDim2.new(1, -30, 0.5, -50) }
	)
	tweenPuloAtual:Play()
end

local function finalizarTutorial()
	tutorialAtivo = false
	desligarRastreadores()
	limparBeamEAttachments()

	tituloMissao.Text = "🏆 TUTORIAL CONCLUÍDO!"
	descMissao.Text = "Você ganhou 500 XP e $5.000 de bônus inicial! Bom jogo."
	tocarSomMissao()

	local recompensaEvent = ReplicatedStorage:WaitForChild("TutorialRecompensaEvent", REMOTE_TIMEOUT)
	if recompensaEvent and recompensaEvent:IsA("RemoteEvent") then
		local ok, err = pcall(function()
			recompensaEvent:FireServer()
		end)
		if not ok then
			warn("[Tutorial] FireServer TutorialRecompensaEvent falhou:", err)
		end
	else
		warn("[Tutorial] TutorialRecompensaEvent em falta — recompensa não pedida ao servidor.")
	end

	task.delay(DELAY_APOS_FIM_SEG, function()
		if not gui.Parent then
			return
		end
		local tw = TweenService:Create(
			frameMissao,
			TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 350, 0.5, -50) }
		)
		tw:Play()
		tw.Completed:Once(function()
			if gui.Parent then
				gui:Destroy()
			end
			if script.Parent then
				script:Destroy()
			end
		end)
	end)
end

frameMissao.MouseButton1Click:Connect(function()
	if not MODO_TESTE or not tutorialAtivo then
		return
	end
	print("[Tutorial] Dev skip — missão", missaoAtual)

	if missaoAtual == 1 then
		missaoAtual = 2
		atualizarTela(2, "Vá até a Concessionária e compre o seu primeiro veículo próprio.")
	elseif missaoAtual == 2 then
		missaoAtual = 3
		atualizarTela(3, "Vá até a Garagem Pública e spawne o veículo que você acabou de comprar.")
	elseif missaoAtual == 3 then
		missaoAtual = 4
		atualizarTela(4, "Compre uma casa em qualquer um dos lotes residenciais disponíveis.")
	elseif missaoAtual == 4 then
		missaoAtual = 5
		atualizarTela(5, "Vá à loja de auto peças e compre tinta, suspensão, ou upgrade de motor (ECU).")
	elseif missaoAtual == 5 then
		missaoAtual = 6
		atualizarTela(6, "Vá para a garagem da sua casa, abra o capô/painel e instale a peça nova no carro.")
	elseif missaoAtual == 6 then
		finalizarTutorial()
	end
end)

local function verificarInstalacao()
	if missaoAtual == 6 then
		finalizarTutorial()
	end
end

local function iniciarRastreadores()
	local inventarioVeiculos = player:WaitForChild("InventarioVeiculos", REMOTE_TIMEOUT)
	local inventarioCasas = player:WaitForChild("InventarioCasas", REMOTE_TIMEOUT)
	local inventarioFerramentas = player:WaitForChild("InventarioFerramentas", REMOTE_TIMEOUT)
	local carData = player:WaitForChild("CarData", REMOTE_TIMEOUT)

	if not inventarioVeiculos then
		warn("[Tutorial] InventarioVeiculos em falta.")
	end
	if not inventarioCasas then
		warn("[Tutorial] InventarioCasas em falta.")
	end
	if not inventarioFerramentas then
		warn("[Tutorial] InventarioFerramentas em falta.")
	end

	local con1
	con1 = workspace.ChildAdded:Connect(function(obj)
		if missaoAtual == 1 and obj.Name == player.Name .. "sCar" then
			missaoAtual = 2
			atualizarTela(2, "Vá até a Concessionária e compre o seu primeiro veículo próprio.")
		end
		if missaoAtual == 3 and obj.Name == player.Name .. "sCar" then
			missaoAtual = 4
			atualizarTela(4, "Compre uma casa em qualquer um dos lotes residenciais disponíveis.")
		end
	end)
	table.insert(conexoes, con1)

	if inventarioVeiculos then
		local con2 = inventarioVeiculos.ChildAdded:Connect(function()
			if missaoAtual == 2 then
				missaoAtual = 3
				atualizarTela(3, "Vá até a Garagem Pública e spawne o veículo que você acabou de comprar.")
			end
		end)
		table.insert(conexoes, con2)
	end

	if inventarioCasas then
		local con3 = inventarioCasas.ChildAdded:Connect(function()
			if missaoAtual == 4 then
				missaoAtual = 5
				atualizarTela(5, "Vá à loja de auto peças e compre tinta, suspensão, ou upgrade de motor (Stages).")
			end
		end)
		table.insert(conexoes, con3)
	end

	if inventarioFerramentas then
		local con4 = inventarioFerramentas.ChildAdded:Connect(function()
			if missaoAtual == 5 then
				missaoAtual = 6
				atualizarTela(6, "Vá para a garagem da sua casa e instale a peça nova no carro.")
			end
		end)
		table.insert(conexoes, con4)
	end

	if carData then
		local nomesCarData = { "CorDoCarro", "MotorAtual", "SuspensaoAtual", "FL" }
		for _, nome in ipairs(nomesCarData) do
			local ch = carData:WaitForChild(nome, REMOTE_TIMEOUT)
			if ch and ch:GetPropertyChangedSignal("Value") then
				table.insert(conexoes, ch:GetPropertyChangedSignal("Value"):Connect(verificarInstalacao))
			else
				warn("[Tutorial] CarData." .. nome .. " em falta — sinal de fim da missão 6 pode não disparar.")
			end
		end
	else
		warn("[Tutorial] CarData em falta — missão 6 não deteta instalação por valores.")
	end
end

local dadosProntos = ReplicatedStorage:WaitForChild("DadosProntosEvent", REMOTE_TIMEOUT)
if not dadosProntos or not dadosProntos:IsA("RemoteEvent") then
	warn("[Tutorial] DadosProntosEvent em falta — script desativado.")
	gui:Destroy()
	return
end

dadosProntos.OnClientEvent:Connect(function()
	if jaProcessouDadosProntos then
		return
	end

	local statusTutorial = player:WaitForChild("TutorialCompleto", REMOTE_TIMEOUT)
	if not statusTutorial or not statusTutorial:IsA("BoolValue") then
		warn("[Tutorial] TutorialCompleto inválido ou em falta.")
		return
	end

	if statusTutorial.Value == true and not MODO_TESTE then
		gui:Destroy()
		if script.Parent then
			script:Destroy()
		end
		return
	end

	jaProcessouDadosProntos = true

	local telaCarregamento = playerGui:FindFirstChild("CarregamentoGui")
	if telaCarregamento and telaCarregamento.Parent then
		local t0 = os.clock()
		while telaCarregamento.Parent and (os.clock() - t0) < MAX_ESPERA_LOADING do
			task.wait(0.25)
		end
	end

	tutorialAtivo = true
	iniciarRastreadores()

	task.delay(1, function()
		if not gui.Parent then
			return
		end
		frameMissao.Visible = true
		definirAlvoGPS(1)
		TweenService:Create(frameMissao, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, -20, 0.5, -50),
		}):Play()
		tocarSomMissao()
	end)
end)
