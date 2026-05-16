-- CH Corporations - Configuração central da Loja Stage (ECU)
-- Coloque este ModuleScript no ReplicatedStorage com o nome: "LojaECUConfig"

local config = {}

config.UI = {
	ScreenGuiName = "LojaECUUI",
	Title = "Loja Stage",
	CardWidth = 180,
	CardHeight = 220,
}

-- toolName = nome exato da Tool no ServerStorage
-- VIP usa Developer Product por padrão (compraGamePass = false)
config.Itens = {
	{
		key = "Stage1",
		nome = "ECU Stage 1",
		toolName = "CaixaECU_Stage1",
		preco = 15000,
		levelMin = 1,
		vip = false,
		imageId = 0,
	},
	{
		key = "Stage2",
		nome = "ECU Stage 2",
		toolName = "CaixaECU_Stage2",
		preco = 30000,
		levelMin = 3,
		vip = false,
		imageId = 0,
	},
	{
		key = "Stage3",
		nome = "ECU Stage 3",
		toolName = "CaixaECU_Stage3",
		preco = 55000,
		levelMin = 5,
		vip = false,
		imageId = 0,
	},
	{
		key = "Stage4",
		nome = "ECU Stage 4",
		toolName = "CaixaECU_Stage4",
		preco = 0,
		levelMin = 8,
		vip = true,
		passId = 0,
		compraGamePass = false,
		imageId = 0,
	},
}

return config
