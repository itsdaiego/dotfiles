return {
  -- LSP and Completion
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
  },
  {
    "neoclide/coc.nvim",
    branch = "release",
    event = { "BufReadPre", "BufNewFile" },
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "vim", "vimdoc" },
        auto_install = true,
        highlight = { enable = true },
      })
    end,
  },
  { "nvim-treesitter/nvim-treesitter-textobjects", dependencies = { "nvim-treesitter/nvim-treesitter" } },

  -- Telescope and dependencies
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-telescope/telescope-file-browser.nvim",
      "nvim-telescope/telescope-dap.nvim",
    },
    cmd = "Telescope",
    keys = {
      { "<leader>f", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>g", "<cmd>Telescope live_grep<cr>", desc = "Live Grep" },
      { "<leader>b", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    },
  },
  { "ibhagwan/fzf-lua", branch = "main" },

  -- File Explorer
  {
    "scrooloose/nerdtree",
    cmd = { "NERDTree", "NERDTreeFind", "NERDTreeToggle" },
    keys = {
      { "<leader>nt", "<cmd>NERDTreeToggle<cr>", desc = "Toggle NERDTree" },
      { "<leader>nf", "<cmd>NERDTreeFind<cr>", desc = "NERDTree Find" },
    },
    init = function()
      vim.g.NERDTreeWinPos = "left"
      vim.g.NERDTreeWinSize = 25
    end,
  },

  -- Git
  { "tpope/vim-fugitive", cmd = { "Git", "Gstatus", "Gblame", "Gpush", "Gpull" } },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = true,
  },
  { "airblade/vim-gitgutter", event = { "BufReadPre", "BufNewFile" } },
  { "sindrets/diffview.nvim", cmd = { "DiffviewOpen", "DiffviewFileHistory" } },

  -- UI Enhancements
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = true,
  },
  -- {
  --   "lukas-reineke/indent-blankline.nvim",
  --   main = "ibl",
  --   config = function()
  --     require("ibl").setup({
  --       indent = { char = "✝" },
  --       whitespace = { highlight = { "Whitespace", "NonText" } },
  --       scope = { enabled = true },
  --     })
  --   end,
  -- },
  { "stevearc/dressing.nvim", event = "VeryLazy" },
  { "MunifTanjim/nui.nvim" },
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "Trouble", "TroubleToggle" },
  },
  { "mhinz/vim-startify" },
  { "ryanoasis/vim-devicons" },
  { "norcalli/nvim-colorizer.lua", config = true },
  { "HakonHarnes/img-clip.nvim" },

  -- Editor Enhancements
  { "tpope/vim-surround", event = "VeryLazy" },
  { "jiangmiao/auto-pairs", event = "InsertEnter" },
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = true,
  },
  { "Konfekt/FastFold", event = "VeryLazy" },
  { "github/copilot.vim", event = "InsertEnter" },
  { "skwp/greplace.vim", cmd = "Greplace" },
  { "dense-analysis/ale", event = { "BufReadPost", "BufNewFile" } },
  { "ggreer/the_silver_searcher", cmd = "Ag" },
  { "vim-test/vim-test", cmd = { "TestNearest", "TestFile", "TestSuite" } },
  
  -- Snippets
  {
    "SirVer/ultisnips",
    dependencies = { "honza/vim-snippets" },
    event = "InsertEnter",
    init = function()
      vim.g.UltiSnipsExpandTrigger = "<tab>"
      vim.g.UltiSnipsJumpForwardTrigger = "<tab>"
      vim.g.UltiSnipsJumpBackwardTrigger = "<s-tab>"
      vim.g.UltiSnipsEditSplit = "vertical"
      vim.g.UltiSnipsSnippetDirectories = { "UltiSnips", "snips" }
      -- Ensure Python 3 is used
      vim.g.python3_host_prog = "/Users/daiego/.pyenv/versions/3.10.0/bin/python3"
      -- Disable Python 2
      vim.g.loaded_python_provider = 0
    end,
    config = function()
      -- Delay UltiSnips loading until after Neovim's Python host is ready
      vim.defer_fn(function()
        vim.cmd([[
          if has('python3')
            silent! call UltiSnips#bootstrap#Bootstrap()
          endif
        ]])
      end, 100)
    end,
  },

  -- Debug Adapter Protocol
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "theHamsta/nvim-dap-virtual-text",
      "nvim-telescope/telescope-dap.nvim",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    cmd = { "DapToggleBreakpoint", "DapContinue" },
  },
} 
