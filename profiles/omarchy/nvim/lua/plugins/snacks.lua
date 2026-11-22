return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		scroll = {
			enabled = false,
		},
	},
	keys = function()
		-- Disable all default keymaps by returning empty table
		return {}
	end,
}
