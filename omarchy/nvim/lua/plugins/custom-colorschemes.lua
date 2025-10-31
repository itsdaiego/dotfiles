return {
	{
		dir = vim.fn.stdpath("config") .. "/colors",
		name = "custom-colorschemes",
		lazy = false,
		priority = 900,
		config = function()
			vim.opt.runtimepath:append(vim.fn.stdpath("config") .. "/colors")
		end,
	},
}
