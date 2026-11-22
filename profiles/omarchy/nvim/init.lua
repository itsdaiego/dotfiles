-- Enable true colors support
vim.opt.termguicolors = true
-- Set background to dark
vim.opt.background = 'dark'

-- Set Python provider (before anything else)
vim.g.loaded_python_provider = 0  -- Disable Python 2
vim.g.python3_host_prog = '/home/daiego/.local/share/nvim-python/bin/python'
-- Ensure Python host is loaded before plugins
vim.cmd([[runtime plugin/rplugin.vim]])

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Set leader key before lazy
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- Disable LazyVim checks (we're using Lazy.nvim standalone, not LazyVim)
vim.g.lazyvim_check_order = false

-- Load lazy.nvim
require("lazy").setup("plugins")

-- Theme is loaded dynamically via lua/plugins/theme.lua (controlled by omarchy)
-- If theme.lua is empty, apply default colorscheme
vim.defer_fn(function()
	local theme_spec = require("plugins.theme")
	local has_theme = false

	if type(theme_spec) == "table" then
		for _, spec in ipairs(theme_spec) do
			if spec[1] or (spec.opts and spec.opts.colorscheme) then
				has_theme = true
				break
			end
		end
	end

	-- If no theme specified in theme.lua, use default
	if not has_theme then
		pcall(vim.cmd.colorscheme, "melange")
	end

	-- Apply transparency settings
	local transparency_file = vim.fn.stdpath("config") .. "/plugin/after/transparency.lua"
	if vim.fn.filereadable(transparency_file) == 1 then
		vim.cmd.source(transparency_file)
	end
end, 100)

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.timeoutlen = 300
vim.opt.list = true
vim.opt.listchars = {
  tab = "✝ ",
  trail = "·",
  eol = "↲"
}

-- Folding settings
vim.opt.foldmethod = "expr"  -- Use Treesitter for folding
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevelstart = 99    -- Start with all folds open
vim.opt.foldenable = true      -- Enable folding

-- Autocommand to ensure folding works after file is loaded
vim.api.nvim_create_autocmd({"BufReadPost", "BufNewFile"}, {
  pattern = "*",
  callback = function()
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  end,
})

-- Keep cursor shape consistent (block) in all modes
vim.opt.guicursor = ""

-- NERDTree alias
vim.cmd([[command! NT NERDTree]])

-- Follow the quickfix cursor in a real source window rather than a preview.
-- The quickfix window retains focus, so j/k keeps moving through the list.
local quickfix_follow = vim.api.nvim_create_augroup("QuickfixFollow", { clear = true })
vim.api.nvim_create_autocmd("CursorMoved", {
  group = quickfix_follow,
  callback = function(args)
    local quickfix_win = vim.api.nvim_get_current_win()
    if vim.bo[args.buf].buftype ~= "quickfix" or vim.fn.win_gettype(quickfix_win) ~= "quickfix" then
      return
    end

    -- The quickfix-list index is only updated by jumping, so explicitly use
    -- the selected quickfix line as the :cc count.
    local entry = vim.api.nvim_win_get_cursor(quickfix_win)[1]
    vim.cmd("silent! " .. entry .. "cc")

    -- :cc can load a buffer directly from the quickfix list without a normal
    -- file-opening path. Ensure its filetype is detected and its Tree-sitter
    -- highlighter attaches before returning focus to quickfix.
    local source_win = vim.api.nvim_get_current_win()
    if source_win ~= quickfix_win then
      local source_buf = vim.api.nvim_win_get_buf(source_win)
      if vim.bo[source_buf].filetype == "" then
        local filetype = vim.filetype.match({ buf = source_buf })
        if filetype then
          vim.bo[source_buf].filetype = filetype
        end
      end
      pcall(vim.treesitter.start, source_buf)

      -- Refresh GitGutter for targets that :cc reuses without reading again.
      -- This keeps its signs and <Plug>(GitGutterNextHunk) navigation usable.
      vim.api.nvim_win_call(source_win, function()
        vim.cmd("silent! GitGutter")
      end)
      -- Also attach Gitsigns' hunk actions. Its signcolumn is disabled in
      -- the plugin config, so GitGutter remains the only gutter renderer.
      pcall(function()
        require("gitsigns.actions").attach({
          bufnr = source_buf,
          trigger = "QuickfixFollow",
        })
      end)
    end

    if vim.api.nvim_win_is_valid(quickfix_win) then
      vim.api.nvim_set_current_win(quickfix_win)
    end
  end,
})


-- Setup Telescope
local telescope = require('telescope')
telescope.setup({
  defaults = {
    file_ignore_patterns = {'node_modules', 'venv', 'deps', 'dist'},
    vimgrep_arguments = {
      'rg',
      '--color=never',
      '--no-heading',
      '--with-filename',
      '--line-number',
      '--column',
      '--smart-case',
      '-u'
    },
    mappings = {
      i = {
        ["<C-e>"] = require('telescope.actions').to_fuzzy_refine,
      },
      n = {
        ["<C-e>"] = require('telescope.actions').to_fuzzy_refine,
      },
    },
  },
  pickers = {
    colorscheme = {
      enable_preview = true
    },
    find_files = {
      path_display = { "smart" }
    }
  },
  extensions = {
    fzf = {
      fuzzy = true,                    -- false will only do exact matching
      override_generic_sorter = true,  -- override the generic sorter
      override_file_sorter = true,     -- override the file sorter
      case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
                                       -- the default case_mode is "smart_case"
    },
    file_browser = {
      theme = "ivy",
      -- disables netrw and use telescope-file-browser in its place
      hijack_netrw = true,
      mappings = {
        ["i"] = {
          -- your custom insert mode mappings
        },
        ["n"] = {
          -- your custom normal mode mappings
        },
      },
    },
  },
})

-- Load extensions
telescope.load_extension('fzf')
telescope.load_extension('file_browser')

-- Load custom keymaps
require('config.keymaps')
