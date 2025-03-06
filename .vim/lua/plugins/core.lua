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
    init = function()
      -- Some servers have issues with backup files
      vim.opt.backup = false
      vim.opt.writebackup = false
      
      -- Having longer updatetime (default is 4000 ms = 4s) leads to noticeable delays
      vim.opt.updatetime = 300
      
      -- Always show the signcolumn
      vim.opt.signcolumn = "yes"
    end,
    config = function()
      -- GoTo code navigation
      vim.keymap.set("n", "gd", "<Plug>(coc-definition)", {silent = true})
      vim.keymap.set("n", "gy", "<Plug>(coc-type-definition)", {silent = true})
      vim.keymap.set("n", "gi", "<Plug>(coc-implementation)", {silent = true})
      vim.keymap.set("n", "gr", "<Plug>(coc-references)", {silent = true})

      -- Use K to show documentation in preview window
      vim.keymap.set("n", "K", ":call v:lua.ShowDocumentation()<CR>", {silent = true})
      
      _G.ShowDocumentation = function()
        if vim.fn.CocAction('hasProvider', 'hover') then
          vim.fn.CocActionAsync('doHover')
        else
          vim.fn.feedkeys('K', 'in')
        end
      end

      -- Highlight the symbol and its references when holding the cursor
      vim.api.nvim_create_autocmd("CursorHold", {
        pattern = "*",
        callback = function()
          vim.fn.CocActionAsync('highlight')
        end
      })

      -- Symbol renaming
      vim.keymap.set("n", "<leader>rn", "<Plug>(coc-rename)", {silent = true})

      -- Setup formatexpr for specific filetypes
      vim.api.nvim_create_augroup("CocGroup", {})
      vim.api.nvim_create_autocmd("FileType", {
        group = "CocGroup",
        pattern = {"typescript", "json"},
        command = "setl formatexpr=CocAction('formatSelected')"
      })

      -- Update signature help on jump placeholder
      vim.api.nvim_create_autocmd("User", {
        group = "CocGroup",
        pattern = "CocJumpPlaceholder",
        command = "call CocActionAsync('showSignatureHelp')"
      })

      -- Applying code actions
      vim.keymap.set("x", "<leader>a", "<Plug>(coc-codeaction-selected)", {silent = true})
      vim.keymap.set("n", "<leader>a", "<Plug>(coc-codeaction-selected)", {silent = true})
      vim.keymap.set("n", "<leader>ac", "<Plug>(coc-codeaction-cursor)", {silent = true})
      vim.keymap.set("n", "<leader>as", "<Plug>(coc-codeaction-source)", {silent = true})
      vim.keymap.set("n", "<leader>qf", "<Plug>(coc-fix-current)", {silent = true})
      
      -- Refactor code actions
      vim.keymap.set("n", "<leader>re", "<Plug>(coc-codeaction-refactor)", {silent = true})
      vim.keymap.set("x", "<leader>r", "<Plug>(coc-codeaction-refactor-selected)", {silent = true})
      vim.keymap.set("n", "<leader>r", "<Plug>(coc-codeaction-refactor-selected)", {silent = true})
      
      -- Run the Code Lens action on the current line
      vim.keymap.set("n", "<leader>cl", "<Plug>(coc-codelens-action)", {silent = true})

      -- Add commands
      vim.api.nvim_create_user_command("Format", "call CocAction('format')", {})
      vim.api.nvim_create_user_command("OR", "call CocActionAsync('runCommand', 'editor.action.organizeImport')", {})

      -- CoCList mappings
      vim.keymap.set("n", "<space>a", ":<C-u>CocList diagnostics<cr>", {silent = true, nowait = true})
      vim.keymap.set("n", "<space>e", ":<C-u>CocList extensions<cr>", {silent = true, nowait = true})
      vim.keymap.set("n", "<space>c", ":<C-u>CocList commands<cr>", {silent = true, nowait = true})
      vim.keymap.set("n", "<space>o", ":<C-u>CocList outline<cr>", {silent = true, nowait = true})
      vim.keymap.set("n", "<space>s", ":<C-u>CocList -I symbols<cr>", {silent = true, nowait = true})
      vim.keymap.set("n", "<space>j", ":<C-u>CocNext<CR>", {silent = true, nowait = true})
      vim.keymap.set("n", "<space>k", ":<C-u>CocPrev<CR>", {silent = true, nowait = true})
      vim.keymap.set("n", "<space>p", ":<C-u>CocListResume<CR>", {silent = true, nowait = true})
    end
  },

  -- Treesitter
  {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      event = { "BufReadPost", "BufNewFile" },
      dependencies = {
        "nvim-treesitter/nvim-treesitter-context",
      },
      config = function()
        require("nvim-treesitter.configs").setup({
          ensure_installed = { "lua", "vim", "vimdoc" },
          auto_install = true,
          highlight = { enable = true },
        })
        require('treesitter-context').setup{
          enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
          multiwindow = false, -- Enable multiwindow support.
          max_lines = 10, -- How many lines the window should span. Values <= 0 mean no limit.
          min_window_height = 5, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
          line_numbers = true,
          multiline_threshold = 1000, -- Maximum number of lines to show for a single context
          trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
          mode = 'cursor',  -- Line used to calculate context. Choices: 'cursor', 'topline'
          -- Separator between context and content. Should be a single character string, like '-'.
          -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
          separator = nil,
          zindex = 20, -- The Z-index of the context window
          on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching
        }
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
      { "<leader>tt", "<cmd>Telescope file_browser path=%:p:h<cr>", desc = "File Browser (current dir)" },
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

  -- Debug Adapter Protocol configuration has been moved to lua/plugins/dap.lua
  {
    "yetone/avante.nvim",
    build = "make",
    config = function()
      require('avante').setup({
        transparent = true,
        -- Disable the window feature that's causing the error
        -- disable_window = true,
        windows = {
          width = 50
        }
      })
    end,
  },
  {
    "hat0uma/csvview.nvim",
    ---@module "csvview"
    ---@type CsvView.Options
    opts = {
      parser = { comments = { "#", "//" } },
      keymaps = {
        -- Text objects for selecting fields
        textobject_field_inner = { "if", mode = { "o", "x" } },
        textobject_field_outer = { "af", mode = { "o", "x" } },
        -- Excel-like navigation:
        -- Use <Tab> and <S-Tab> to move horizontally between fields.
        -- Use <Enter> and <S-Enter> to move vertically between rows and place the cursor at the end of the field.
        -- Note: In terminals, you may need to enable CSI-u mode to use <S-Tab> and <S-Enter>.
        jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
        jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
        jump_next_row = { "<Enter>", mode = { "n", "v" } },
        jump_prev_row = { "<S-Enter>", mode = { "n", "v" } },
      },
    },
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
  },
} 
