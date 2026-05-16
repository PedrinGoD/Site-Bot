-- CH Corporations - Concessionária (catálogo por categorias + validação 100% servidor)

print("CH Corporations - Concessionária (Categorias + Catálogo Central) Carregado")

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local comprarEvento = ReplicatedStorage:WaitForChild("ComprarVeiculoEvent", 90)
local catalogoModule = ReplicatedStorage:WaitForChild("ConcessionariaCatalogo", 90)
local registroDeCarros = ServerStorage:WaitForChild("RegistroDeCarros", 90)

if not comprarEvento or not catalogoModule then
	warn("[Concessionaria] Recursos principais em falta.")
	return
end
if not registroDeCarros then
	warn("[Concessionaria] RegistroDeCarros em falta; compra cancelada.")
	return
end

local Catalogo = require(catalogoModule)
local MAPA_CARROS = Catalogo.MapaPorNome()

local PASS_TO_CARRO = {}
for _, carro in ipairs(Catalogo.CARROS) do
	if carro.Premium and type(carro.PassID) == "number" and carro.PassID > 0 then
		local key = Catalogo.NormalizarNome(carro.NomeInventario or carro.NomeExibicao)
		if key then
			PASS_TO_CARRO[carro.PassID] = key
		end
	end
end

local function aplicarAtributosPadraoVeiculo(rec)
	rec:SetAttribute("CorDoCarro", "")
	rec:SetAttribute("MotorAtual", 0)
	rec:SetAttribute("CombustivelSalvo", 100)
	rec:SetAttribute("FL", nil)
	rec:SetAttribute("FR", nil)
	rec:SetAttribute("RL", nil)
	rec:SetAttribute("RR", nil)
	rec:SetAttribute("SuspensaoNome", "Padrao")
	rec:SetAttribute("SuspensaoAltura", 2)
	rec:SetAttribute("SuspensaoRigidez", 4500)
	rec:SetAttribute("SuspensaoAmortecimento", 500)
end

local function jaPossuiCarro(inventario, nomeInventario)
	if not inventario then
		return false
	end
	if inventario:FindFirstChild(nomeInventario) then
		return true
	end
	local alvo = Catalogo.NormalizarNome(nomeInventario)
	for _, item in ipairs(inventario:GetChildren()) do
		local k = Catalogo.NormalizarNome(item.Name)
		if k and k == alvo then
			return true
		end
	end
	return false
end

local function concederVeiculo(player, nomeCarro, valorTag)
	local inventario = player:FindFirstChild("InventarioVeiculos")
	if not inventario or jaPossuiCarro(inventario, nomeCarro) then
		return false
	end
	local novo = Instance.new("StringValue")
	novo.Name = nomeCarro
	novo.Value = valorTag
	novo.Parent = inventario
	aplicarAtributosPadraoVeiculo(novo)
	return true
end

local function validarNoRegistro(nomeInventario, modelIdEsperado)
	local chave = Catalogo.NormalizarNome(nomeInventario)
	if not chave then
		return false
	end
	local valorRegistro = registroDeCarros:GetAttribute(chave)
	if valorRegistro == nil then
		return false
	end

	if type(modelIdEsperado) == "number" and modelIdEsperado > 0 then
		local registroNumero = tonumber(valorRegistro)
		if not registroNumero or registroNumero ~= modelIdEsperado then
			return false
		end
	end

	return true
end

local function sincronizarGamepasses(player)
	for passId, key in pairs(PASS_TO_CARRO) do
		local ok, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and hasPass then
			local cfg = MAPA_CARROS[key]
			if cfg and validarNoRegistro(cfg.NomeInventario, cfg.ModelId) then
				concederVeiculo(player, cfg.NomeInventario, "Comprado_VIP")
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	local inventario = player:WaitForChild("InventarioVeiculos", 30)
	if inventario then
		sincronizarGamepasses(player)
	end
end)

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(sincronizarGamepasses, p)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then
		return
	end

	local key = PASS_TO_CARRO[gamePassId]
	local cfg = key and MAPA_CARROS[key]
	if not cfg then
		return
	end
	if not validarNoRegistro(cfg.NomeInventario, cfg.ModelId) then
		warn("[Concessionaria] Compra VIP bloqueada: carro não confere com RegistroDeCarros.")
		return
	end
	if concederVeiculo(player, cfg.NomeInventario, "Comprado_VIP") then
		print("💎 COMPRA VIP APROVADA! " .. player.Name .. " destravou " .. cfg.NomeInventario)
	end
end)

comprarEvento.OnServerEvent:Connect(function(player, nomeCarroEnviado)
	if type(nomeCarroEnviado) ~= "string" or nomeCarroEnviado == "" then
		return
	end

	local key = Catalogo.NormalizarNome(nomeCarroEnviado)
	local cfg = key and MAPA_CARROS[key]
	if not cfg then
		warn("[Concessionaria] Carro fora do catálogo: " .. tostring(nomeCarroEnviado))
		return
	end
	if cfg.Premium then
		return
	end
	if not validarNoRegistro(cfg.NomeInventario, cfg.ModelId) then
		warn("[Concessionaria] Compra bloqueada: carro não confere com RegistroDeCarros.")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local dinheiro = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	local level = leaderstats and leaderstats:FindFirstChild("Level")
	local inventario = player:FindFirstChild("InventarioVeiculos")

	if not dinheiro or not level or not inventario then
		return
	end
	if not (dinheiro:IsA("IntValue") or dinheiro:IsA("NumberValue")) then
		return
	end
	if not (level:IsA("IntValue") or level:IsA("NumberValue")) then
		return
	end
	if jaPossuiCarro(inventario, cfg.NomeInventario) then
		return
	end

	local preco = math.max(0, math.floor(tonumber(cfg.Preco) or 0))
	local levelMin = math.max(0, math.floor(tonumber(cfg.LevelMin) or 0))

	if level.Value < levelMin then
		return
	end
	if dinheiro.Value < preco then
		return
	end

	dinheiro.Value -= preco
	if concederVeiculo(player, cfg.NomeInventario, "Comprado") then
		print("🚗 COMPRA CASH APROVADA: " .. player.Name .. " comprou " .. cfg.NomeInventario)
	else
		dinheiro.Value += preco
	end
end)
