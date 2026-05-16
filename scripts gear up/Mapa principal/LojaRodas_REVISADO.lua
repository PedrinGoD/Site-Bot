-- CH Corporations - Loja de rodas (cash + level + multi-spawn + save)
-- Revisão: preço/level só no catálogo servidor; chave normalizada (underscore); sem debitar sem spawn OK;
--          evita recibo duplicado; WaitForChild com timeout; guia com task.defer (sem yield longo no handler).

print("CH Corporations - Sistema da Loja de Rodas (Cash + Level + Auto-Formatação + Multi-Spawns) Atualizado c/ Save")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local TIMEOUT = 90
local DEBOUNCE_SEG = 0.5

local comprarEvento = ReplicatedStorage:WaitForChild("ComprarRodaEvent", TIMEOUT)
local guiaEvent = ReplicatedStorage:WaitForChild("GuiaVisualEvent", TIMEOUT)
if not comprarEvento or not guiaEvent then
	warn("[LojaRodas] RemoteEvents em falta.")
	return
end

local caixaNormalModelo = ServerStorage:WaitForChild("CaixaFalsaVisual", TIMEOUT)
if not caixaNormalModelo then
	warn("[LojaRodas] CaixaFalsaVisual não encontrada no ServerStorage.")
	return
end

local shopR = Workspace:WaitForChild("ShopR", TIMEOUT)
if not shopR then
	warn("[LojaRodas] ShopR não encontrada no Workspace.")
	return
end

--[[
  Chaves com underscore, iguais ao atributo NomeDaRoda nas Frames da UI (ex.: "Audi_T").
  Em produção: preenche TODAS as rodas de cash aqui — é a fonte de verdade do preço/nível.

  Se uma chave NÃO existir e FALLBACK_PRECO_CLIENTE = true, o servidor usa o preço/nível
  que o cliente envia, limitados por PRECO_MAX_FALLBACK / LEVEL_MAX_FALLBACK (menos seguro).
]]
local FALLBACK_PRECO_CLIENTE = true
local PRECO_MAX_FALLBACK = 50000000
local LEVEL_MAX_FALLBACK = 500
local PERMITIR_RECOMPRA_SE_JA_POSSUI = true

local CATALOGO_RODAS = {}

local ultimo = {}
local jaAvisadoFallback = {}

Players.PlayerRemoving:Connect(function(p)
	ultimo[p.UserId] = nil
end)

local function normalizarChaveRoda(nome)
	if type(nome) ~= "string" then
		return nil
	end
	local s = string.gsub(nome, "%s+", "_")
	s = string.gsub(s, "_+", "_")
	s = string.gsub(s, "^_+", "")
	s = string.gsub(s, "_+$", "")
	if s == "" then
		return nil
	end
	return s
end

local function nomeFormatadoParaCaixa(chaveComUnderscore)
	return string.gsub(chaveComUnderscore, "_", " ")
end

local function possuiReciboDaRoda(inventarioFerramentas, chave)
	if not inventarioFerramentas or not chave then
		return false
	end
	for _, item in ipairs(inventarioFerramentas:GetChildren()) do
		local nomeNormalizado = normalizarChaveRoda(item.Name)
		if nomeNormalizado == chave then
			return true
		end
	end
	return false
end

do
	local cfgModule = ReplicatedStorage:FindFirstChild("LojaRodasConfig")
	if cfgModule and cfgModule:IsA("ModuleScript") then
		local ok, cfg = pcall(require, cfgModule)
		if ok and type(cfg) == "table" and type(cfg.Rodas) == "table" then
			for _, roda in ipairs(cfg.Rodas) do
				local key = normalizarChaveRoda(roda.key or roda.nome)
				local vip = roda.vip == true
				local preco = math.max(1, math.floor(tonumber(roda.preco) or 0))
				local level = math.max(1, math.floor(tonumber(roda.levelMin) or 1))
				if key and not vip then
					CATALOGO_RODAS[key] = {
						Preco = preco,
						LevelMin = level,
					}
				end
			end
		else
			warn("[LojaRodas] Falha ao carregar LojaRodasConfig no servidor.")
		end
	else
		warn("[LojaRodas] ModuleScript LojaRodasConfig não encontrado no ReplicatedStorage.")
	end
end

comprarEvento.OnServerEvent:Connect(function(player, nomeDaRoda, precoCliente, levelCliente)
	local uid = player.UserId
	local t = os.clock()
	if ultimo[uid] and (t - ultimo[uid]) < DEBOUNCE_SEG then
		return
	end

	local chave = normalizarChaveRoda(nomeDaRoda)
	if not chave then
		return
	end

	local cfgCatalogo = CATALOGO_RODAS[chave]
	local cfg

	if cfgCatalogo then
		cfg = cfgCatalogo
		if precoCliente ~= nil and precoCliente ~= cfg.Preco then
			return
		end
		if levelCliente ~= nil and levelCliente ~= cfg.LevelMin then
			return
		end
	elseif FALLBACK_PRECO_CLIENTE then
		local p = precoCliente
		local lv = levelCliente
		if type(p) ~= "number" or p ~= p or type(lv) ~= "number" or lv ~= lv then
			warn("[LojaRodas] Fallback: preço/nível inválidos para " .. chave)
			return
		end
		p = math.clamp(math.floor(p), 1, PRECO_MAX_FALLBACK)
		lv = math.clamp(math.floor(lv), 1, LEVEL_MAX_FALLBACK)
		cfg = { Preco = p, LevelMin = lv }
		if not jaAvisadoFallback[chave] then
			jaAvisadoFallback[chave] = true
			warn("[LojaRodas] Compra em fallback (UI) para '" .. chave .. "'. Coloca esta chave em CATALOGO_RODAS com Preco/LevelMin fixos no servidor.")
		end
	else
		warn("[LojaRodas] Roda não catalogada e fallback desligado: " .. chave)
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local dinheiro = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	local level = leaderstats and leaderstats:FindFirstChild("Level")
	if not dinheiro or not level then
		warn("[LojaRodas] leaderstats/Dinheiro/Level em falta: " .. player.Name)
		return
	end
	if not dinheiro:IsA("IntValue") and not dinheiro:IsA("NumberValue") then
		warn("[LojaRodas] Dinheiro não é IntValue/NumberValue: " .. player.Name)
		return
	end
	if not level:IsA("IntValue") and not level:IsA("NumberValue") then
		warn("[LojaRodas] Level não é IntValue/NumberValue: " .. player.Name)
		return
	end

	if level.Value < cfg.LevelMin then
		warn("❌ " .. player.Name .. " sem level para esta roda (mín. " .. cfg.LevelMin .. ").")
		return
	end

	if dinheiro.Value < cfg.Preco then
		warn("❌ " .. player.Name .. " sem dinheiro suficiente para a roda.")
		return
	end

	local inventarioFerramentas = player:FindFirstChild("InventarioFerramentas")
	local jaTemRecibo = possuiReciboDaRoda(inventarioFerramentas, chave)
	if jaTemRecibo and not PERMITIR_RECOMPRA_SE_JA_POSSUI then
		warn("❌ " .. player.Name .. " já possui recibo desta roda: " .. chave)
		return
	end

	dinheiro.Value = dinheiro.Value - cfg.Preco
	ultimo[uid] = t

	local nomeFormatado = nomeFormatadoParaCaixa(chave)
	local novaCaixa

	local spawnOk, err = pcall(function()
		novaCaixa = caixaNormalModelo:Clone()

		local rodaValue = Instance.new("StringValue")
		rodaValue.Name = "TipoDeRoda"
		rodaValue.Value = nomeFormatado
		rodaValue.Parent = novaCaixa

		novaCaixa:SetAttribute("Dono", player.Name)
		novaCaixa:SetAttribute("PrecoPago", cfg.Preco)

		local spawnsDisponiveis = {}
		for _, item in ipairs(shopR:GetDescendants()) do
			if item:IsA("BasePart") and string.match(item.Name, "^LocalSpawn") then
				table.insert(spawnsDisponiveis, item)
			end
		end

		if #spawnsDisponiveis > 0 then
			local indexSorteado = math.random(1, #spawnsDisponiveis)
			local spawnEscolhido = spawnsDisponiveis[indexSorteado]
			if novaCaixa:IsA("Model") then
				novaCaixa:PivotTo(spawnEscolhido.CFrame * CFrame.new(0, 1.5, 0))
			elseif novaCaixa:IsA("BasePart") then
				novaCaixa.CFrame = spawnEscolhido.CFrame * CFrame.new(0, 1.5, 0)
			end
		else
			warn("⚠️ Nenhum LocalSpawn na ShopR; usando pivot da loja.")
			if novaCaixa:IsA("Model") then
				novaCaixa:PivotTo(shopR:GetPivot() * CFrame.new(0, 1.5, 0))
			elseif novaCaixa:IsA("BasePart") then
				novaCaixa.Position = shopR:GetPivot().Position + Vector3.new(0, 1.5, 0)
			end
		end

		novaCaixa.Parent = Workspace
	end)

	if not spawnOk then
		dinheiro.Value = dinheiro.Value + cfg.Preco
		if novaCaixa then
			pcall(function()
				novaCaixa:Destroy()
			end)
		end
		warn("[LojaRodas] Falha ao gerar caixa; dinheiro devolvido. " .. tostring(err))
		return
	end

	if inventarioFerramentas and not jaTemRecibo then
		local novoRecord = Instance.new("StringValue")
		novoRecord.Name = chave
		novoRecord.Value = "Comprada"
		novoRecord.Parent = inventarioFerramentas
		print("💾 Recibo criado para a roda: " .. chave)
	end

	print("🛒 " .. player.Name .. " comprou a roda " .. nomeFormatado)

	task.defer(function()
		if not player.Parent or not novaCaixa or not novaCaixa.Parent then
			return
		end
		local alvoDoBeam = novaCaixa:IsA("BasePart") and novaCaixa
			or novaCaixa.PrimaryPart
			or novaCaixa:FindFirstChildWhichIsA("BasePart", true)
		if alvoDoBeam and alvoDoBeam.Parent then
			guiaEvent:FireClient(player, alvoDoBeam)
		end
	end)
end)
