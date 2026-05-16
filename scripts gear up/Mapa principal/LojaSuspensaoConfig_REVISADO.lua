-- CH Corporations - Configuração central da Loja de Suspensão
-- Coloque este ModuleScript no ReplicatedStorage com o nome: "LojaSuspensaoConfig"

local config = {}

config.UI = {
	ScreenGuiName = "LojaSuspensaoUI",
	Title = "Loja De Suspensao",
}

-- toolName = nome exato da Tool no ServerStorage
-- key = identificador da UI (pode repetir toolName)
-- VIP usa Developer Product por padrão (compraGamePass=false)
config.Itens = {
	{
		key = "Suspensao_Baixa",
		nome = "Suspensao Baixa",
		toolName = "Suspensao_Baixa",
		preco = 35000,
		levelMin = 1,
		vip = false,
		imageId = 0,
	},
	{
		key = "Suspensao_Sport",
		nome = "Suspensao Sport",
		toolName = "Suspensao_Sport",
		preco = 0,
		levelMin = 5,
		vip = true,
		passId = 0,
		compraGamePass = false,
		imageId = 0,
	},
}

return config
