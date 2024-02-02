call plug#begin('~/.vim/plugged')

"" ---------- ADDITIONAL PLUGINS --------- "
Plug 'tpope/vim-commentary'
Plug 'ggreer/the_silver_searcher'
Plug 'chriskempson/base16-vim'
Plug 'flazz/vim-colorschemes'
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
Plug 'nvim-tree/nvim-web-devicons'
Plug 'BurntSushi/ripgrep'
Plug 'rcarriga/nvim-dap-ui'
Plug 'David-Kunz/jester'
Plug 'sainnhe/sonokai'
Plug 'github/copilot.vim', { 'tag': 'v1.12.0' }
Plug 'airblade/vim-gitgutter'
Plug 'jackMort/ChatGPT.nvim'
Plug 'EdenEast/nightfox.nvim'
Plug 'stevearc/dressing.nvim'
Plug 'mcchrish/zenbones.nvim'
Plug 'rktjmp/lush.nvim'
Plug 'rose-pine/neovim'
Plug 'savq/melange-nvim'
Plug 'lukas-reineke/indent-blankline.nvim'

call plug#end()
"enables true colors
let $NVIM_TUI_ENABLE_TRUE_COLOR=1

"neovim terminal 
tnoremap jj <C-\><C-n>

"leader key
let mapleader=","
set listchars=tab:▸\ ,trail:·,eol:↲
set list

" autocmd TextChanged,TextChangedI <buffer> silent write

set termguicolors
set colorcolumn=80

syntax enable

set background=dark

let g:go_highlight_functions = 1
let g:go_highlight_types = 1

" indenting rules

lua << EOF
require("ibl").setup({
   indent = { char = "→" },
   whitespace = { highlight = { "Whitespace", "NonText" } },
   scope = { exclude = { language = { "lua" } } },
})
EOF

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
" colorscheme darkdevel

colorscheme melange

hi Normal guibg=NONE ctermbg=NONE
"

lua << EOF
require('rose-pine').setup({
    groups = {
        background = 'NONE',
        background_nc = 'NONE',
    },
})
EOF
" vim.cmd('colorscheme rose-pine')


let NERDTreeWinSize=40

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
" command NT NERDTree



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
nmap gd <Plug>(coc-definition)

" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction


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
nnoremap <Space> za

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

nnoremap <Leader>g :Git blame<CR>

let g:airline_theme='github'

lua << EOF
local dap = require('dap')
require("nvim-dap-virtual-text").setup()
require('telescope').load_extension('dap')
require("dapui").setup()

local dap = require('dap')
dap.adapters.lldb = {
  type = 'executable',
  command = '/usr/bin/lldb-vscode', -- adjust as needed, must be absolute path
  name = 'lldb'
}

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

local dap = require('dap')
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
nnoremap <S-l> :lua require'dap'.step_out()<CR>
nnoremap <S-l> :lua require'dap'.step_into()<CR>
nnoremap <S-j> :lua require'dap'.step_over()<CR>
nnoremap <leader>ds :lua require'dap'.stop()<CR>
nnoremap <leader>dn :lua require'dap'.continue()<CR>
nnoremap <leader>dk :lua require'dap'.up()<CR>
nnoremap <leader>dj :lua require'dap'.down()<CR>
nnoremap <leader>d_ :lua require'dap'.disconnect();require'dap'.stop();require'dap'.run_last()<CR>
nnoremap <leader>dr :lua require'dap'.repl.open({}, 'vsplit')<CR><C-w>l
nnoremap <leader>di :lua require'dap.ui.widgets'.hover()<CR>
vnoremap <leader>di :lua require'dap.ui.variables'.visual_hover()<CR>
snoremap <leader>d? :lua require'dap.ui.variables'.scopes()<CR>
" nnoremap <leader>de :lua require'dap'.set_exception_breakpoints({"all"})<CR>
nnoremap <leader>da :lua require'debugHelper'.attach()<CR>
nnoremap <leader>dA :lua require'debugHelper'.attachToRemote()<CR>
nnoremap <leader>di :lua require'dap.ui.widgets'.hover()<CR>
nnoremap <leader>d? :lua local widgets=require'dap.ui.widgets';widgets.centered_float(widgets.scopes)<CR>


" Jester

nnoremap <leader>tt :lua require"jester".run()<CR>
nnoremap <leader>tf :lua require"jester".run_file()<CR>
nnoremap <leader>tr :lua require"jester".run_last()<CR>
nnoremap <leader>td :lua require"jester".debug()<CR>

let g:dap_virtual_text = v:true

nnoremap <leader>df :Telescope dap frames<CR>
nnoremap <leader>db :Telescope dap list_breakpoints<CR>
nnoremap <leader>dq :lua require('dapui').toggle()<CR>

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

    -- chatGpt
    use({
      "jackMort/ChatGPT.nvim",
      config = function() require("chatgpt").setup({
       chat = {
          keymaps = {
            close = "<C-c>",
            yank_last = "<C-y>",
            scroll_up = "<C-u>",
            scroll_down = "<C-d>",
            toggle_settings = "<C-o>",
            new_session = "<C-s>",
            cycle_windows = "<Tab>",
            select_session = "<C-g>",
          },
        },

        -- actions_paths = { "/home/dylan/.config/lvim/correct_french.json" },
        popup_input = {
          submit = "<CR>",
        },
      }) end,
      requires = {
        "MunifTanjim/nui.nvim",
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
      },
    })

    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if PACKER_BOOTSTRAP then
      require("packer").sync()
    end
  end)
EOF


" Telescope config

lua << EOF
require('telescope').setup({ 
  defaults = {
        file_ignore_patterns = {'node_modules', 'builds'} 
  }, 
  pickers = {
    find_files = {
      path_display = { "smart" }
    }
  }
})
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>f', builtin.find_files, {})
vim.keymap.set('n', '<leader>g', builtin.live_grep, {})
vim.keymap.set('n', '<leader>b', builtin.buffers, {})
vim.keymap.set('n', '<leader>h', builtin.help_tags, {})

EOF

lua << EOF
require("telescope").setup {
  extensions = {
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
-- To get telescope-file-browser loaded and working with telescope,
-- you need to call load_extension, somewhere after setup function:
require("telescope").load_extension "file_browser"

vim.api.nvim_set_keymap(
  "n",
  "<leader>t",
  ":Telescope file_browser path=%:p:h select_buffer=true<CR>",
  { noremap = true }
)
EOF

" LSP autocomplete
