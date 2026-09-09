return {
  {
    "stevearc/aerial.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "AerialToggle", "AerialOpen", "AerialNavToggle" },
    keys = {
      { "<leader>m", "<cmd>AerialToggle!<CR>", desc = "aerial: toggle symbol outline" },
    },
    opts = {
      -- coc.nvim is the LSP client here, and it does not register with vim.lsp,
      -- so aerial's "lsp" backend never receives symbols. Treesitter parsers in
      -- ~/.local/share/nvim/site/parser cover the languages used in this config.
      backends = { "treesitter", "markdown", "man" },
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
