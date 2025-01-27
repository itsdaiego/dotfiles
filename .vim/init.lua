-- Enable true colors support
vim.opt.termguicolors = false
-- Set background to dark
vim.opt.background = 'dark'

-- Set Python provider (before anything else)
vim.g.loaded_python_provider = 0  -- Disable Python 2
vim.g.python3_host_prog = '/Users/daiego/.pyenv/versions/3.10.0/bin/python3'
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

-- Load lazy.nvim
require("lazy").setup("plugins")

-- Set colorscheme
vim.cmd.colorscheme('handmadehero')
-- Enable transparent background
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.timeoutlen = 1000
vim.opt.list = true
vim.opt.listchars = {
  tab = "✝ ",
  trail = "·",
  eol = "↲"
}

-- Keep cursor shape consistent (block) in all modes
vim.opt.guicursor = ""

-- NERDTree alias
vim.cmd([[command! NT NERDTree]])

-- Key mappings
vim.keymap.set('i', 'jj', '<Esc>')
vim.keymap.set('t', 'jj', '<C-\\><C-n>')

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
