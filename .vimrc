call plug#begin('~/.vim/plugged')

"" ---------- ADDITIONAL PLUGINS --------- "
Plug 'ggreer/the_silver_searcher'
Plug 'chriskempson/base16-vim'
Plug 'flazz/vim-colorschemes'
Plug 'utensils/colors.vim'
Plug 'rafi/awesome-vim-colorschemes'
Plug 'dense-analysis/ale'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'tpope/vim-fugitive'
Plug 'scrooloose/nerdtree'
Plug 'skwp/greplace.vim'
Plug 'clojure-vim/async-clj-omni'
Plug 'tpope/vim-classpath', { 'for': 'clojure' }
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
Plug 'mhinz/vim-startify'
Plug 'ryanoasis/vim-devicons'
Plug 'moll/vim-node', { 'for': 'javascript' }
Plug 'JulesWang/css.vim', { 'for': 'css' }
Plug 'tpope/vim-haml', { 'for': 'haml' }
Plug 'othree/html5.vim', { 'for': 'html' }
Plug 'alvan/vim-closetag'
Plug 'nvie/vim-flake8', { 'for': 'python' }
Plug 'Vimjas/vim-python-pep8-indent', { 'for': 'python' }
Plug 'hail2u/vim-css3-syntax' , { 'for': 'css' }
Plug 'cakebaker/scss-syntax.vim', { 'for': 'scss' }
Plug 'mxw/vim-jsx', { 'for': 'javascriptreact' }
Plug 'neoclide/vim-jsx-improve'
Plug 'yuezk/vim-js'
Plug 'HerringtonDarkholme/yats.vim'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'NLKNguyen/papercolor-theme'
Plug 'hashivim/vim-terraform'
Plug 'juliosueiras/vim-terraform-completion'
Plug 'foxbunny/vim-amber'
Plug 'Glench/Vim-Jinja2-Syntax'
Plug 'cideM/yui'
Plug 'guns/vim-clojure-static'
Plug 'luochen1990/rainbow'
Plug 'vim-test/vim-test'
Plug 'sebdah/vim-delve'
Plug 'neovim/nvim-lspconfig'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'leafgarland/typescript-vim'
Plug 'robertmeta/nofrils'
Plug 'YorickPeterse/vim-paper'
Plug 'tomlion/vim-solidity'
Plug 'tpope/vim-fugitive'
Plug 'vim-airline/vim-airline'
Plug 'mfussenegger/nvim-dap'
Plug 'theHamsta/nvim-dap-virtual-text'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.4' }
Plug 'nvim-telescope/telescope-dap.nvim'
Plug 'nvim-telescope/telescope-file-browser.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }
Plug 'ibhagwan/fzf-lua', {'branch': 'main'}
" Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all'  }
" Plug 'junegunn/fzf.vim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'BurntSushi/ripgrep'
Plug 'rcarriga/nvim-dap-ui'
Plug 'nvim-neotest/nvim-nio'
Plug 'David-Kunz/jester'
Plug 'sainnhe/sonokai'
Plug 'github/copilot.vim'
Plug 'airblade/vim-gitgutter'
Plug 'EdenEast/nightfox.nvim'
Plug 'stevearc/dressing.nvim'
Plug 'mcchrish/zenbones.nvim'
Plug 'rktjmp/lush.nvim'
Plug 'rose-pine/neovim'
Plug 'savq/melange-nvim'
Plug 'lukas-reineke/indent-blankline.nvim'
Plug 'lewis6991/gitsigns.nvim'
Plug 'Konfekt/FastFold'
Plug 'catppuccin/nvim'
Plug 'numToStr/Comment.nvim'
Plug 'nvim-lualine/lualine.nvim'
Plug 'tjdevries/colorbuddy.nvim'
Plug 'xero/miasma.nvim'
Plug 'sainnhe/everforest'
Plug 'jckmgns/curtailed'
Plug 'alljokecake/naysayer-theme.nvim'
Plug 'lifepillar/vim-gruvbox8'
Plug 'fcpg/vim-farout'
Plug 'yetone/avante.nvim'
Plug 'MunifTanjim/nui.nvim'
Plug 'folke/trouble.nvim'
Plug 'stevearc/dressing.nvim'
Plug 'HakonHarnes/img-clip.nvim'

call plug#end()
"enables true colors
let $NVIM_TUI_ENABLE_TRUE_COLOR=1

"neovim terminal
tnoremap jj <C-\><C-n>

"leader key
let mapleader=","
set timeoutlen=1000

set listchars=tab:▸\ ,trail:·,eol:↲
set list

" autocmd TextChanged,TextChangedI <buffer> silent write

set termguicolors
"set colorcolumn=80

syntax enable

set background=dark

let g:go_highlight_functions = 1
let g:go_highlight_types = 1

" indenting rules

" lua << EOF
" require("ibl").setup({
"  indent = { char = "→" },
"  whitespace = { highlight = { "Whitespace", "NonText" } },
"  scope = { enabled = true },
" })
" EOF

lua << EOF
  require('nightfox').setup({
    options = {
      transparent = true,
    }
  })
EOF


"Default colorscheme
" colorscheme jammy
" colorscheme rdark
" colorscheme dante
" colorscheme hemisu

" set background=dark
" colorscheme ego
" colorscheme fahrenheit
" colorscheme monochrome
" colorscheme quagmire
" colorscheme blueshift
" colorscheme off
" colorscheme scheakur
" colorscheme loogica
" colorscheme darth
" colorscheme monoacc
" colorscheme photon
" colorscheme earthburn



let g:everforest_background = 'hard'

" colorscheme miasma
" colorscheme farout
colorscheme base16-black-metal-burzum


"hi Normal guibg=NONE ctermbg=NONE
"

lua << EOF
require('rose-pine').setup({
    groups = {
        background = 'NONE',
        background_nc = 'NONE',
    },
    styles = { transparency = true },
    --vim.cmd('colorscheme rose-pine')
})
EOF

" lua  << EOF
" require("catppuccin").setup({
"   flavour = "macchiato",
"   transparent = true,
"   term_colors = true
" })

" vim.cmd('colorscheme catppuccin')
" EOF


let NERDTreeWinSize=50

filetype plugin indent on
"show existing tab with 4 spaces width
set tabstop=2
" when indenting with '>', use 4 spaces width
set shiftwidth=2
" On pressing tab, insert 4 spaces
set expandtab


set relativenumber


"remapped keys
ino jj <esc>
" command Er Errors
" Alias for syntastic plugin
" command Cl lclose
" Alias for Nerdtree plugin
command NT NERDTree
command NTF NERDTreeFind
let g:NERDTreeWinPos = "right"




"Track files that should be ignored
set wildignore=*.o,*~,*.pyc,node_modules

"disabling highlighted background bug
" set t_ut=

"line number"
set number

"close tags will work for these files extensions
let g:closetag_filenames = "*.html.erb,*.html,*.xhtml,*.phtml"


set backspace=indent,eol,start

" let g:ycm_register_as_syntastic_checker = 0


"vim-javascript config
" let g:javascript_plugin_ngdoc = 1
" let g:javascript_plugin_jsdoc = 1

"JSX for files ending with .js
" let g:jsx_ext_required = 0


"Neovim
"Using mouse with neovim
set mouse=ar

" set ttyfast
" set lazyredraw
" set re=1
"
"ale
let g:ale_cache_executable_check_failures = 1
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '⚠'
highlight ALEErrorSign ctermbg=NONE ctermfg=red
highlight ALEWarningSign ctermbg=NONE ctermfg=yellow


"neomake
" autocmd InsertLeave,BufWritePost * update | Neomake  
" autocmd BufWritePost * update | Neomake  

" let g:airline_theme='minimalist'
" let g:airline_powerline_fonts = 1
" let g:airline#extensions#tabline#enabled = 1
" let g:airline_section_warning = ''
" let g:airline_inactive_collapse = 0
" let g:airline#extensions#default#section_truncate_width = {
"   \ 'a': 60,
"   \ 'b': 80,
"   \ 'x': 100,
"   \ 'y': 100,
"   \ 'z': 60,
" \ }


" Buffer mapping
" map gn :bn<cr>
" map gp :bp<cr>
" map gd :bd<cr>
"

" coc-nvim definition
" nmap <silent> <C-]> <Plug>(coc-definition)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

" Highlight the symbol and its references when holding the cursor
autocmd CursorHold * silent call CocActionAsync('highlight')

" Symbol renaming
nmap <leader>rn <Plug>(coc-rename)

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s)
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Applying code actions to the selected code block
" Example: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap keys for applying code actions at the cursor position
nmap <leader>ac  <Plug>(coc-codeaction-cursor)
" Remap keys for apply code actions affect whole buffer
nmap <leader>as  <Plug>(coc-codeaction-source)
" Apply the most preferred quickfix action to fix diagnostic on the current line
nmap <leader>qf  <Plug>(coc-fix-current)

" Remap keys for applying refactor code actions
nmap <silent> <leader>re <Plug>(coc-codeaction-refactor)
xmap <silent> <leader>r  <Plug>(coc-codeaction-refactor-selected)
nmap <silent> <leader>r  <Plug>(coc-codeaction-refactor-selected)

" Run the Code Lens action on the current line
nmap <leader>cl  <Plug>(coc-codelens-action)


" Add `:Format` command to format current buffer
command! -nargs=0 Format :call CocActionAsync('format')

" Add `:OR` command for organize imports of the current buffer
command! -nargs=0 OR   :call     CocActionAsync('runCommand', 'editor.action.organizeImport')

" Add (Neo)Vim's native statusline support
" NOTE: Please see `:h coc-status` for integrations with external plugins that
" provide custom statusline: lightline.vim, vim-airline
" set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

" Mappings for CoCList
" Show all diagnostics
nnoremap <silent><nowait> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent><nowait> <space>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent><nowait> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent><nowait> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item
nnoremap <silent><nowait> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item
nnoremap <silent><nowait> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent><nowait> <space>p  :<C-u>CocListResume<CR>


" Clojure
nmap rr :Require<CR>
nmap re :Require!<CR>

" disable guicursor
set guicursor=

" indent config
set nocindent
set nosmartindent
set noautoindent
filetype plugin indent on

" change indent line char
" let g:indentLine_char = '▸'

" Use deoplete.
" let g:deoplete#enable_at_startup = 1

set hidden

set inccommand=split

" Pymode
let g:pymode_lint_ignore = "E501, W404"


set foldmethod=indent
set foldlevel=50
set nofoldenable

" Terraform
let g:terraform_align=1
let g:terraform_fmt_on_save=1


let t:is_transparent = 0
hi Normal guibg=NONE ctermbg=NONE


let g:markdown_fenced_languages = [
      \ 'vim',
      \ 'help'
      \]

" vim-test
let test#python#runner = 'pytest'

" typescript
" let g:typescript_indent_disable = 1

let g:closetag_xhtml_filetypes = 'js,jsx'

nnoremap <Leader>q :Git blame<CR>

let g:airline_theme='github'

lua << EOF
local dap = require('dap')
require("nvim-dap-virtual-text").setup()
require('telescope').load_extension('dap')
require("dapui").setup({
   -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      }
})

dap.adapters.lldb = {
  type = 'executable',
  command = '/usr/bin/lldb-vscode',
  name = 'lldb'
}

-- dap.adapters.lldb = {
--   type = "server",
--   port = "${port}",
--   executable = {
--     command = "/Users/daiego/.local/codelldb/adapter/codelldb",
--     args = { "--port", "${port}" },
--     -- On windows you may have to uncomment this:
--     -- detached = false,
--   },
-- }

dap.configurations.cpp = {
  {
    name = 'Launch',
    type = 'lldb',
    request = 'launch',
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
    args = {},

    -- 💀
    -- if you change `runInTerminal` to true, you might need to change the yama/ptrace_scope setting:
    --
    --    echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
    --
    -- Otherwise you might get the following error:
    --
    --    Error on launch: Failed to attach to the target process
    --
    -- But you should be aware of the implications:
    -- https://www.kernel.org/doc/html/latest/admin-guide/LSM/Yama.html
    -- runInTerminal = false,
  },
}

-- If you want to use this for Rust and C, add something like this:

dap.configurations.c = dap.configurations.cpp
dap.configurations.rust = dap.configurations.cpp

dap.adapters.chrome = {
    type = "executable",
    command = "node",
    args = {os.getenv("HOME") .. "/dap/vscode-chrome-debug/out/src/chromeDebug.js"}
}

dap.configurations.javascriptreact = {
    {
        type = "chrome",
        request = "attach",
        program = "${file}",
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
        protocol = "inspector",
        port = 9222,
        webRoot = "${workspaceFolder}"
    }
}

dap.adapters.firefox = {
  type = 'executable',
  command = 'node',
  args = {os.getenv('HOME') .. '/dap/vscode-firefox-debug/dist/adapter.bundle.js'},
}

dap.configurations.typescriptreact = { -- change to typescript if needed
    {
        type = "chrome",
        request = "attach",
        program = "${file}",
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
        protocol = "inspector",
        port = 9222,
        webRoot = "${workspaceFolder}",
        outFiles = "${workspaceRoot}/compiled/**/*.js"
    }
}
dap.adapters.node2 = {
  type = 'executable',
  command = 'node',
  args = {os.getenv('HOME') .. '/dev/microsoft/vscode-node-debug2/out/src/nodeDebug.js'},
}

dap.configurations.javascript = {
  {
      name = 'Launch',
      type = 'node2',
      request = 'launch',
      program = '${file}',
      cwd = vim.fn.getcwd(),
      sourceMaps = true,
      protocol = 'inspector',
      console = 'integratedTerminal',
  },
  {
      -- For this to work you need to make sure the node process is started with the `--inspect` flag.
      name = 'Attach to process',
      type = 'node2',
      request = 'attach',
      processId = require'dap.utils'.pick_process,
  },
  {
      type = "chrome",
      request = "attach",
      program = "${file}",
      cwd = vim.fn.getcwd(),
      sourceMaps = true,
      protocol = "inspector",
      port = 9222,
      webRoot = "${workspaceFolder}"
  }
}

dap.configurations["javascript.jsx"] = dap.configurations.javascript

dap.configurations.typescript = {
  {
      name = 'Launch',
      type = 'node2',
      request = 'launch',
      program = '${file}',
      cwd = vim.fn.getcwd(),
      sourceMaps = true,
      protocol = 'inspector',
      console = 'integratedTerminal',
  },
  {
      -- For this to work you need to make sure the node process is started with the `--inspect` flag.
      name = 'Attach to process',
      type = 'node2',
      request = 'attach',
      processId = require'dap.utils'.pick_process,
  },
  {
      type = "chrome",
      request = "attach",
      program = "${file}",
      cwd = vim.fn.getcwd(),
      sourceMaps = true,
      protocol = "inspector",
      port = 9222,
      webRoot = "${workspaceFolder}"
  }
}

vim.fn.sign_define('DapBreakpoint', {text='👉', texthl='', linehl='', numhl=''})
vim.fn.sign_define('DapStopped', {text='🔥', texthl='', linehl='', numhl=''})
EOF

nnoremap <leader>dh :lua require'dap'.toggle_breakpoint()<CR>
nnoremap <S-j> :lua require'dap'.step_over()<CR>
nnoremap <leader>ds :lua require'dap'.stop()<CR>
nnoremap <leader>dn :lua require'dap'.continue()<CR>
nnoremap <leader>dk :lua require'dap'.up()<CR>
nnoremap <leader>dj :lua require'dap'.down()<CR>
nnoremap <leader>d_ :lua require'dap'.disconnect();require'dap'.stop();require'dap'.run_last()<CR>
nnoremap <leader>dr :lua require'dap'.repl.open({}, 'vsplit')<CR><C-w>l
nnoremap <leader>dw :lua require'dap.ui.widgets'.hover()<CR>
vnoremap <leader>di :lua require'dap.ui.variables'.visual_hover()<CR>
snoremap <leader>d? :lua require'dap.ui.variables'.scopes()<CR>
" nnoremap <leader>de :lua require'dap'.set_exception_breakpoints({"all"})<CR>
nnoremap <leader>da :lua require'debugHelper'.attach()<CR>
nnoremap <leader>dA :lua require'debugHelper'.attachToRemote()<CR>
nnoremap <leader>dw :lua require'dap.ui.widgets'.hover()<CR>
nnoremap <leader>d? :lua local widgets=require'dap.ui.widgets';widgets.centered_float(widgets.scopes)<CR>


let g:dap_virtual_text = v:true

nnoremap <leader>df :Telescope dap frames<CR>
nnoremap <leader>db :Telescope dap list_breakpoints<CR>
nnoremap <leader>du :lua require('dapui').toggle()<CR>

function! ClearBreakpoints()
    exec "lua require'dap'.list_breakpoints()"
    for item in getqflist()
        exec "exe " . item.lnum . "|lua require'dap'.toggle_breakpoint()"
    endfor
endfunction


lua << EOF
  local fn = vim.fn
  local autocmd = vim.api.nvim_create_autocmd

  -- Automatically install packer
  local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
  if fn.empty(fn.glob(install_path)) > 0 then
    PACKER_BOOTSTRAP = fn.system({
      "git",
      "clone",
      "--depth",
      "1",
      "https://github.com/wbthomason/packer.nvim",
      install_path,
    })
    print("Installing packer close and reopen Neovim...")
    vim.cmd([[packadd packer.nvim]])
  end

  require('packer').init({
    display = {
      open_fn = function()
        return require("packer.util").float({ border = "rounded" })
      end,
    },
  })

  return require('packer').startup(function(use)
    -- My plugins here

    use({ "wbthomason/packer.nvim" })

    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if PACKER_BOOTSTRAP then
      require("packer").sync()
    end
  end)
EOF


" Telescope config
lua << EOF
require("telescope").setup {
  defaults = {
    file_ignore_patterns = {'node_modules', 'deps', 'dist'},
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
  },
  pickers = {
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
}
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>f', builtin.find_files, {})
vim.keymap.set('n', '<leader>g', builtin.live_grep, {})
vim.keymap.set('n', '<leader>s', builtin.git_status, {})
vim.keymap.set('n', '<leader>b', builtin.buffers, {})
vim.keymap.set('n', '<leader>h', builtin.help_tags, {})


-- To get telescope-file-browser loaded and working with telescope,
-- you need to call load_extension, somewhere after setup function:
require("telescope").load_extension "file_browser"
require("telescope").load_extension "fzf"


vim.api.nvim_set_keymap(
  "n",
  "<leader>t",
  ":Telescope file_browser path=%:p:h select_buffer=true<CR>",
  { noremap = true }
)
EOF


" FZF

" nnoremap <C-P> :FzfLua files<cr>
" nnoremap <C-F> :FzfLua live_grep<cr>
" nnoremap <C-S> :FzfLua git_status<cr>
" nnoremap <C-B> :FzfLua buffers<cr>


" Commenter

lua << EOF
require("Comment").setup()
EOF

" LuaLine
lua << END
require('lualine').setup({
  sections = { lualine_a = { 'g:coc_status', 'bo:filetype' } },
  options = {
    component_separators = { left = '', right = ''},
    section_separators = {},
  }
})
END

let g:python3_host_prog = expand('~/.neovim-venv/bin/python3')


" Avante

lua << EOF
local avante = require('avante')

avante.setup {
  provider = "claude", -- Only recommend using Claude
  claude = {
    endpoint = "https://api.anthropic.com",
    model = "claude-3-5-sonnet-20240620",
    temperature = 0,
    max_tokens = 4096,
  },
  mappings = {
    ask = "<leader>aa",
    edit = "<leader>ae",
    refresh = "<leader>ar",
    ---@class AvanteConflictMappings
    diff = {
      ours = "co",
      theirs = "ct",
      both = "cb",
      next = "]x",
      prev = "[x",
    },
    jump = {
      next = "]]",
      prev = "[[",
    },
    submit = {
      normal = "<CR>",
      insert = "<C-s>",
    },
    toggle = {
      debug = "<leader>ad",
      hint = "<leader>ah",
    },
  },
  hints = { enabled = true },
  windows = {
    wrap = true, -- similar to vim.o.wrap
    width = 30, -- default % based on available width
    sidebar_header = {
      align = "center", -- left, center, right for title
      rounded = true,
    },
  },
  highlights = {
    ---@type AvanteConflictHighlights
    diff = {
      current = "DiffText",
      incoming = "DiffAdd",
    },
  },
  --- @class AvanteConflictUserConfig
  diff = {
    debug = false,
    autojump = true,
    ---@type string | fun(): any
    list_opener = "copen",
  },
}
EOF

