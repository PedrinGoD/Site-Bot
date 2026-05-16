-- CH Corporations - Catálogo da Gear Shop
-- Coloque como ModuleScript em ReplicatedStorage com o nome: ConcessionariaCatalogo

local Catalogo = {}

-- Título e subtítulo da janela (a UI usa estes valores)
Catalogo.TITULO_LOJA = "Gear Shop"
Catalogo.SUBTITULO_LOJA = "Catálogo por categoria"

Catalogo.CATEGORIAS = {
	"AA+",
	"A",
	"B",
	"C",
	"D",
}

-- NomeInventario: nome salvo em InventarioVeiculos e chave usada no RegistroDeCarros.
-- NomeExibicao: texto mostrado na UI.
-- Categoria: sempre AA+, A, B, C ou D (Gear Shop + abas normais da garagem).
-- GaragemVip (opcional): "Diamante" | "Gold" | "Bronze" — carro aparece só na aba VIP correspondente
--   na GaragemClienteUI (não nas abas AA+…D). Sem este campo = só nas abas de categoria.
-- Preco / LevelMin / Premium / PassID / ModelId: como antes.
-- ImagemId: número ou "rbxassetid://..." — thumbnail na lista.

Catalogo.CARROS = {

	-- Carros VIP (gamepass / premium — sem GaragemVip = aparecem nas abas AA+…D)

	{
		NomeInventario = "Ferrari_F50",
		NomeExibicao = "Ferrari F-50",
		Categoria = "AA+",
		Premium = true,
		PassID = 105157618547638,
		Preco = 0,
		LevelMin = 1,
		ModelId = 0,
		ImagemId = 105157618547638,
	},
	{
		NomeInventario = "McLaren_Senna",
		NomeExibicao = "McLaren Senna",
		Categoria = "AA+",
		Premium = true,
		PassID = 1798886829,
		Preco = 0,
		LevelMin = 16,
		ModelId = 0,
		ImagemId = 97991041840621,
	},
	{
		NomeInventario = "Koenigsegg_Jesko",
		NomeExibicao = "Koenigsegg Jesko",
		Categoria = "AA+",
		Premium = true,
		PassID = 1797768412,
		Preco = 0,
		LevelMin = 25,
		ModelId = 0,
		ImagemId = 98382211761480,
	},
	{
		NomeInventario = "Porsche_911_GT3",
		NomeExibicao = "Porsche 911 GT3",
		Categoria = "A",
		Premium = true,
		PassID = 1797643510,
		Preco = 0,
		LevelMin = 15,
		ModelId = 0,
		ImagemId = 122565698348531,
	},
	{
		NomeInventario = "Ferrari_SF90",
		NomeExibicao = "Ferrari SF90",
		Categoria = "A",
		Premium = true,
		PassID = 1797633742,
		Preco = 0,
		LevelMin = 18,
		ModelId = 0,
		ImagemId = 72655098156565,
	},
	{
		NomeInventario = "BMW_M4CS_2018",
		NomeExibicao = "BMW M4 CS",
		Categoria = "B",
		Premium = true,
		PassID = 1794648644,
		Preco = 0,
		LevelMin = 10,
		ModelId = 0,
		ImagemId = 95285313218876,
	},

	-- Carros com dinheiro do jogo

	{
		NomeInventario = "Golf_R_-_Black",
		NomeExibicao = "Golf R-Black",
		Categoria = "C",
		Premium = false,
		Preco = 850000,
		LevelMin = 2,
		ModelId = 0,
		ImagemId = 108324196357329,
	},
	{
		NomeInventario = "Gol_CL",
		NomeExibicao = "Gol CL",
		Categoria = "D",
		Premium = false,
		Preco = 85000,
		LevelMin = 1,
		ModelId = 0,
		ImagemId = 101852677994463,
	},

	--[[
		=== Carros só na garagem VIP (aba Diamante / Gold / Bronze) ===
		- Categoria: usa sempre AA+, A, B, C ou D (referência interna / loja).
		- GaragemVip: "Diamante" | "Gold" | "Bronze" — define em que aba VIP da garagem o carro lista.

		Exemplo Gold (copia e preenche):
		{
			NomeInventario = "Teu_Carro_Gold",
			NomeExibicao = "Nome bonito",
			Categoria = "A",
			GaragemVip = "Gold",
			Premium = true,
			PassID = 0,
			Preco = 0,
			LevelMin = 1,
			ModelId = 0,
			ImagemId = 0,
		},

		Exemplo Bronze:
		{
			NomeInventario = "Teu_Carro_Bronze",
			NomeExibicao = "Nome bonito",
			Categoria = "B",
			GaragemVip = "Bronze",
			Premium = true,
			PassID = 0,
			Preco = 0,
			LevelMin = 1,
			ModelId = 0,
			ImagemId = 0,
		},
	]]

	-- Exemplo ativo: aba VIP Diamante (remove ou substitui quando tiveres carro real)
	{
		NomeInventario = "Carro_Exemplo",
		NomeExibicao = "Carro Exemplo (VIP Diamante)",
		Categoria = "AA+",
		GaragemVip = "Diamante",
		Premium = true,
		PassID = 123456789,
		Preco = 0,
		LevelMin = 1,
		ModelId = 0,
		ImagemId = 101852677994463,
	},
}

local function normalizarNome(nome)
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

function Catalogo.NormalizarNome(nome)
	return normalizarNome(nome)
end

--- Resolve ImagemId para ImageLabel.Image (string rbxassetid)
function Catalogo.ResolverImagem(cfg)
	local id = cfg and (cfg.ImagemId or cfg.ThumbnailId or cfg.Icone)
	if id == nil or id == "" or id == 0 then
		return ""
	end
	if type(id) == "number" then
		if id <= 0 then
			return ""
		end
		return "rbxassetid://" .. tostring(math.floor(id))
	end
	if type(id) == "string" then
		local s = string.gsub(id, "^%s+", "")
		s = string.gsub(s, "%s+$", "")
		if s == "" then
			return ""
		end
		if string.sub(s, 1, 13) == "rbxassetid://" then
			return s
		end
		return "rbxassetid://" .. s
	end
	return ""
end

function Catalogo.MapaPorNome()
	local mapa = {}
	for _, item in ipairs(Catalogo.CARROS) do
		local k = normalizarNome(item.NomeInventario or item.NomeExibicao)
		if k then
			mapa[k] = item
		end
	end
	return mapa
end

return Catalogo
