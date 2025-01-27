return {
  {
    "yetone/avante.nvim",
    build = "make",
    config = function()
      require('avante').setup({
        transparent = true,
        -- Disable the window feature that's causing the error
        disable_window = true,
      })
    end,
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    config = function()
      require('rose-pine').setup({
        groups = {
          background = 'NONE',
          background_nc = 'NONE',
        },
      })
    end,
  },
  { 
    "sainnhe/gruvbox-material",
    config = function()
      vim.g.gruvbox_material_background = 'medium'
      vim.g.gruvbox_material_palette = 'original'
      vim.g.gruvbox_material_sign_column_background = 'none'
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_transparent_background = 1
      vim.g.gruvbox_material_diagnostic_text_highlight = 1
      vim.g.gruvbox_material_diagnostic_line_highlight = 1
    end,
  },
  { 
    "sainnhe/everforest",
    config = function()
      vim.g.everforest_background = 'hard'
    end,
  },
  { "EdenEast/nightfox.nvim" },
  { "catppuccin/nvim", name = "catppuccin" },
  { "savq/melange-nvim" },
  { "xero/miasma.nvim" },
  { "jckmgns/curtailed" },
  { "alljokecake/naysayer-theme.nvim" },
  { "lifepillar/vim-gruvbox8" },
  { "fcpg/vim-farout" },
  { "kooparse/vim-color-desert-night" },
  { "luisiacc/gruvbox-baby" },
  { "chriskempson/base16-vim" },
  { "flazz/vim-colorschemes" },
  { "utensils/colors.vim" },
  { "rafi/awesome-vim-colorschemes" },
  { "NLKNguyen/papercolor-theme" },
  { "foxbunny/vim-amber" },
  { "cideM/yui" },
  { "robertmeta/nofrils" },
  { "YorickPeterse/vim-paper" },
  { "mcchrish/zenbones.nvim" },
  { "tjdevries/colorbuddy.nvim" },
}
