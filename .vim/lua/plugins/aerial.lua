return {
  {
    "stevearc/aerial.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "AerialToggle", "AerialOpen", "AerialNavToggle" },
    keys = {
      { "<leader>m", "<cmd>AerialToggle!<CR>", desc = "aerial: toggle symbol outline" },
    },
    opts = {
      -- Prefer native LSP symbols and fall back to Tree-sitter where a server
      -- does not implement document symbols.
      backends = { "lsp", "treesitter", "markdown", "man" },
      layout = {
        max_width = { 45, 0.25 },
        min_width = 25,
        default_direction = "left",
      },
      attach_mode = "global",
      close_on_select = false,
      show_guides = true,
      filter_kind = false,
      -- cursor move in aerial window jumps source window to that symbol,
      -- without leaving the aerial window
      autojump = true,
      highlight_on_hover = true,
    },
  },
}
