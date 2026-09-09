return {
  -- LSP and Completion
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

      -- Auto-installed coc extensions: JS/TS, Go, Rust, C/C++, JSON/YAML/HTML/CSS
      -- (Python uses the manual "ty" languageserver entry in coc-settings.json instead)
      vim.g.coc_global_extensions = {
        "coc-json",
        "coc-tsserver",
        "coc-go",
        "coc-rust-analyzer",
        "coc-clangd",
        "coc-html",
        "coc-css",
        "coc-yaml",
        "coc-snippets",
      }
    end,
    config = function()
      -- Insert-mode completion: <Tab>/<S-Tab> navigate the coc popup menu when
      -- visible, otherwise jump UltiSnips snippets, otherwise send a real Tab.
      local function coc_or_snippet_tab(direction)
        local key = direction == "next" and "<Tab>" or "<S-Tab>"
        if vim.fn["coc#pum#visible"]() == 1 then
          return direction == "next" and vim.fn["coc#pum#next"](1) or vim.fn["coc#pum#prev"](1)
        end
        local jump = direction == "next" and "UltiSnips#CanJumpForwards" or "UltiSnips#CanJumpBackwards"
        if vim.fn[jump]() == 1 then
          return vim.fn.feedkeys(vim.api.nvim_replace_termcodes(
            direction == "next" and "<C-r>=UltiSnips#JumpForwards()<CR>" or "<C-r>=UltiSnips#JumpBackwards()<CR>",
            true, true, true), "")
        end
        return key
      end
      vim.keymap.set("i", "<Tab>", function() return coc_or_snippet_tab("next") end, { expr = true, silent = true })
      vim.keymap.set("i", "<S-Tab>", function() return coc_or_snippet_tab("prev") end, { expr = true, silent = true })

      -- Confirm the selected completion, or insert a newline if the menu isn't open.
      -- Must be a string rhs, not a Lua callback: auto-pairs' AutoPairsTryInit (runs on
      -- every BufEnter) reads maparg('<CR>', 'i', 0, 1).rhs to chain its own bracket-aware
      -- <CR> behavior. Callback-mapped keys have no 'rhs' key on this Neovim build, which
      -- throws E716 there and breaks coc's nvim_command batching.
      vim.keymap.set("i", "<CR>", [[coc#pum#visible() ? coc#pum#confirm() : "\<CR>"]], { expr = true, silent = true })

      -- Manually trigger completion
      vim.keymap.set("i", "<C-space>", "coc#refresh()", { silent = true, expr = true })

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

  -- Treesitter: Neovim 0.12 requires nvim-treesitter's rewritten main branch.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    dependencies = { "nvim-treesitter/nvim-treesitter-context" },
    config = function()
      local languages = {
        "lua", "vim", "vimdoc", "markdown", "markdown_inline",
        "javascript", "typescript", "tsx", "python", "go", "rust", "c", "cpp",
        "json", "yaml", "bash",
      }
      require("nvim-treesitter").setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
      })
      require("nvim-treesitter").install(languages)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
        callback = function(args)
          -- Avante manages its own markdown parser; attaching another highlighter causes
          -- the Tree-sitter `node:range()` error while its buffer is being rewritten.
          if vim.bo[args.buf].filetype ~= "Avante" then
            pcall(vim.treesitter.start, args.buf)
          end
        end,
      })

      require("treesitter-context").setup({
        multiwindow = false,
        max_lines = 10,
        min_window_height = 5,
        line_numbers = true,
        multiline_threshold = 1000,
        trim_scope = "outer",
        mode = "cursor",
        zindex = 20,
        on_attach = function(bufnr)
          return vim.bo[bufnr].filetype ~= "Avante"
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
  },

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
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>gg", "<cmd>Telescope live_grep<cr>", desc = "Live Grep" },
      { "<leader>bb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
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
  -- GitGutter owns the change signs and <Plug>(GitGutter*Hunk) mappings.
  -- It must be available before quickfix opens a target source buffer.
  { "airblade/vim-gitgutter", lazy = false },
  {
    "lewis6991/gitsigns.nvim",
    lazy = false,
    opts = {
      -- Let GitGutter be the sole provider of gutter signs; retain Gitsigns'
      -- hunk preview and other actions without the competing orange pipes.
      signcolumn = false,
      numhl = false,
      linehl = false,
      on_attach = function(bufnr)
        vim.keymap.set("n", "<leader>sp", require("gitsigns").preview_hunk, {
          buffer = bufnr,
          desc = "Preview Hunk",
        })
      end,
    },
  },
  {
    "sindrets/diffview.nvim",
    -- Load at startup so the guarded :DiffviewOpen command is always available.
    -- Diffview normally uses Neovim's cwd, which can be outside the project even
    -- when the current buffer belongs to a Git repository.
    lazy = false,
    opts = {
      file_panel = {
        listing_style = "tree",             -- One of 'list' or 'tree'
        tree_options = {                    -- Only applies when listing_style is 'tree'
          flatten_dirs = true,              -- Flatten dirs that only contain one single dir
          folder_statuses = "only_folded",  -- One of 'never', 'only_folded' or 'always'.
        },
        win_config = {                      -- See |diffview-config-win_config|
          position = "right",
          width = 20,
          win_opts = {},
        },
      },
    },
    config = function(_, opts)
      require("diffview").setup(opts)

      -- Diffview labels its two-way panes A (old) and B (new), but creates
      -- them as A-left/B-right. Keep B (the added/current version) on the
      -- left and A (the removed/previous version) on the right. Merge layouts
      -- are deliberately unchanged: their panes have different semantics.
      local async = require("diffview.async")
      local Window = require("diffview.scene.window").Window
      local Diff2Hor = require("diffview.scene.layouts.diff_2_hor").Diff2Hor
      local api = vim.api
      local await = async.await

      Diff2Hor.create = async.void(function(self, pivot)
        self:create_pre()
        pivot = pivot or self:find_pivot()
        assert(api.nvim_win_is_valid(pivot), "Layout creation requires a valid window pivot!")

        for _, win in ipairs(self.windows) do
          if win.id ~= pivot then
            win:close(true)
          end
        end

        -- Create B first so it is the left pane, then create A immediately
        -- before the pivot; closing the pivot leaves B-left/A-right.
        api.nvim_win_call(pivot, function()
          vim.cmd("aboveleft vsp")
          local winid = api.nvim_get_current_win()
          if self.b then self.b:set_id(winid) else self.b = Window({ id = winid }) end
        end)
        api.nvim_win_call(pivot, function()
          vim.cmd("aboveleft vsp")
          local winid = api.nvim_get_current_win()
          if self.a then self.a:set_id(winid) else self.a = Window({ id = winid }) end
        end)

        api.nvim_win_close(pivot, true)
        self.windows = { self.a, self.b }
        await(self:create_post())
      end)

      local function repo_root(path)
        local git_root = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--show-toplevel" })
        if vim.v.shell_error == 0 and git_root[1] then
          return git_root[1]
        end

        if vim.fn.executable("hg") == 1 then
          local hg_root = vim.fn.systemlist({ "hg", "--cwd", path, "root" })
          if vim.v.shell_error == 0 and hg_root[1] then
            return hg_root[1]
          end
        end
      end

      local function current_repo_root()
        local buffer_name = vim.api.nvim_buf_get_name(0)
        local candidates = { vim.fn.getcwd() }
        if buffer_name ~= "" then
          table.insert(candidates, 1, vim.fs.dirname(vim.fs.normalize(buffer_name)))
        end

        for _, path in ipairs(candidates) do
          local root = repo_root(path)
          if root then
            return root
          end
        end
      end

      vim.api.nvim_create_user_command("DiffviewOpen", function(ctx)
        -- Preserve Diffview's handling of explicit directories and path lists.
        -- Otherwise, anchor the view to the current buffer's repository instead
        -- of an unrelated Neovim working directory.
        local has_explicit_location = false
        for _, arg in ipairs(ctx.fargs) do
          if arg == "--" or arg == "-C" or arg:sub(1, 2) == "-C" then
            has_explicit_location = true
            break
          end
        end

        if not has_explicit_location then
          local root = current_repo_root()
          if not root then
            vim.notify(
              "Diffview needs a Git or Mercurial repository. Open a project file first.",
              vim.log.levels.WARN,
              { title = "Diffview" }
            )
            return
          end
          local args = vim.list_extend({ "-C" .. root }, ctx.fargs)
          require("diffview").open(args)
          return
        end

        require("diffview").open(ctx.fargs)
      end, { nargs = "*", complete = "customlist,v:lua.require'diffview'.completion", force = true })
    end,
    keys = {
      { "<leader>sdo", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
      { "<leader>sdc", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown" },
    opts = {},
  },

  -- UI Enhancements
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      require('lualine').setup({
        options = {
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
        }
      })
    end,
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
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    opts = {
      auto_resize_height = true,
      preview = {
        -- Preview the entry beneath the quickfix cursor, including filetype
        -- syntax highlighting, without jumping away from the quickfix list.
        -- Actual source buffers are opened by the quickfix CursorMoved hook
        -- in init.lua. Keep bqf's floating preview available manually via `p`.
        auto_preview = false,
        -- bqf accepts rows rather than a percentage; calculate 90% at startup.
        win_height = math.max(1, math.floor(vim.o.lines * 0.9)),
        win_vheight = math.max(1, math.floor(vim.o.lines * 0.9)),
        delay_syntax = 50,
      },
    },
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
  {
    "github/copilot.vim",
    event = "InsertEnter",
    config = function()
      vim.g.copilot_no_tab_map = true
      vim.keymap.set('i', '<C-j>', 'copilot#Accept("")', {
        expr = true,
        replace_keycodes = false,
        silent = true
      })
    end
  },
  { "skwp/greplace.vim", cmd = "Greplace" },
  {
    "dense-analysis/ale",
    event = { "BufReadPost", "BufNewFile" },
    init = function()
      -- Diffview buffers contain Git snapshots, not filesystem paths. Never
      -- pass their `diffview://` names to ALE's LSP linters.
      vim.g.ale_pattern_options = vim.tbl_extend("force", vim.g.ale_pattern_options or {}, {
        ["^diffview://"] = { ale_enabled = 0 },
      })

      -- Set this before ALE's BufWinEnter lint hook as an extra safeguard.
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        group = vim.api.nvim_create_augroup("DisableAleForDiffview", { clear = true }),
        pattern = "diffview://*",
        callback = function(args)
          vim.b[args.buf].ale_enabled = false
        end,
      })
    end,
  },
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
        provider = "openai",
        windows = {
          position = "left",
          width = 50
        },
        providers = {
          openai = {
            endpoint = "https://api.openai.com/v1",
            model = "gpt-4.1-mini",
            timeout = 30000,
            extra_request_body = {
              temperature = 0,
              max_completion_tokens = 8192,
            },
          },
        }
      })
      -- clear persisted chat history so every nvim session starts fresh
      require("avante.path").clear()
      vim.keymap.set({ "n", "v" }, "<leader>aa", function()
        require("avante.api").ask({ floating = true, new_chat = true })
      end, { desc = "avante: ask inline", noremap = true, silent = true })
      vim.keymap.set("n", "<leader>aq", function()
        require("avante").close_sidebar()
      end, { desc = "avante: close", noremap = true, silent = true })
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
