-- Enable true colors support
vim.opt.termguicolors = true
-- Set background to dark
vim.opt.background = 'dark'
-- Legacy Tree-sitter highlighting is disabled below for Neovim 0.12
-- compatibility; retain syntax coloring through Vim's syntax engine.
vim.cmd('syntax enable')

vim.opt.foldmethod = 'indent'
vim.opt.foldlevel = 50
vim.opt.foldenable = false


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

vim.g.avante = {
  log_level = "WARN",
}

-- Load lazy.nvim
require("lazy").setup("plugins")

-- Set colorscheme
-- vim.g.gruvbox_material_palette = 'gruvbox'
-- vim.cmd.colorscheme('duotone-darkdesert')
local theme_switcher_current = vim.fn.expand('~/.config/theme-switcher/nvim/current.lua')
if vim.fn.filereadable(theme_switcher_current) == 1 then
  dofile(theme_switcher_current)
else
  vim.cmd.colorscheme('melange')
end
-- vim.cmd.colorscheme('zenbones')
-- vim.cmd.colorscheme('monotone')
-- Enable transparent background
-- vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
-- vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.timeoutlen = 1000
vim.opt.list = true
vim.opt.listchars = {
  trail = " ",
  eol = "↵",
  tab = "✝ ",
  tab = "  ",

}

-- Keep cursor shape consistent (block) in all modes
vim.opt.guicursor = ""

-- NERDTree alias
vim.cmd([[command! NT NERDTree]])

require("git.setup").setup()

-- Spawn ClaudeCode by pressing leader cc
vim.keymap.set("n", "<leader>cc", ":ClaudeCode<CR>", {silent = true, noremap = true})

-- run "Git Blame" by running <leader>qq
vim.cmd([[command! -nargs=0 GitBlame :Gitsigns blame]])

-- Key mappings
vim.keymap.set('i', 'jj', '<Esc>')
vim.keymap.set('t', 'jj', '<C-\\><C-n>')
vim.keymap.set('n', '<leader>sp', function()
  require('gitsigns').preview_hunk()
end, { desc = 'Preview Git hunk' })
vim.keymap.set('n', '<leader>gs', function()
  require('telescope.builtin').git_status()
end, { desc = 'Git status' })

require("git_commit_history").setup()

local function navigate_git_change(direction)
  if require("git.branch_diff_quickfix").nav_hunk(direction) then
    return
  end
  if vim.wo.diff then
    vim.cmd("normal! " .. (direction == "next" and "]c" or "[c"))
    vim.cmd("normal! zz")
    return
  end

  require("gitsigns").nav_hunk(direction, { target = "all", wrap = true }, function(err)
    if not err then
      vim.cmd("normal! zz")
    end
  end)
end

vim.keymap.set("n", "]c", function()
  navigate_git_change("next")
end, { desc = "Next Git change" })
vim.keymap.set("n", "[c", function()
  navigate_git_change("prev")
end, { desc = "Previous Git change" })

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

vim.g.copilot_no_tab_map = true
vim.api.nvim_set_keymap("i", "<C-j>", 'copilot#Accept("<Tab>")', { expr = true, silent = true, replace_keycodes = false })
