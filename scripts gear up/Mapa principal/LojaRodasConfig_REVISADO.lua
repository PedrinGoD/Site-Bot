-- CH Corporations - Configuração central da Loja de Rodas
-- Coloque este ModuleScript no ReplicatedStorage com o nome: "LojaRodasConfig"
-- Edite somente esta tabela para adicionar/remover/ajustar rodas.

local config = {}

config.UI = {
	ScreenGuiName = "LojaRodasUI",
	Title = "Loja De Rodas",
}

-- imageId pode ser:
-- 1) número: 1234567890
-- 2) string já pronta: "rbxassetid://1234567890"
config.Rodas = {
	{
		key = "Audi_T",
		nome = "Audi T",
		preco = 50000,
		levelMin = 1,
		vip = false,
		imageId = 0,
	},
	{
		key = "Roda_Nivus",
		nome = "Roda Nivus",
		preco = 0,
		levelMin = 5,
		vip = true,
		passId = 3550796245,
		compraGamePass = false,
		imageId = 0,
	},
	{
		key = "Roda_RS",
		nome = "Roda RS",
		preco = 95000,
		levelMin = 3,
		vip = false,
		imageId = 0,
	},
	{
		key = "Porsche",
		nome = "Roda Porsche",
		preco = 0,
		levelMin = 8,
		vip = true,
		passId = 3575925764,
		compraGamePass = false,
		imageId = 0,
	},
	{
		key = "BMW01",
		nome = "Roda BMW",
		preco = 0,
		levelMin = 7,
		vip = true,
		passId = 3576003329,
		compraGamePass = false,
		imageId = 0,
	},
}

return config
