call plug#begin('~/.vim/plugged')

"" ---------- ADDITIONAL PLUGINS --------- "
Plug 'tpope/vim-commentary'
Plug 'ggreer/the_silver_searcher'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all'  }
Plug 'junegunn/fzf.vim'
Plug 'chriskempson/base16-vim'
Plug 'flazz/vim-colorschemes'
Plug 'rafi/awesome-vim-colorschemes'
" Plug 'Shougo/deoplete.nvim'
" Plug 'w0rp/ale'
Plug 'dense-analysis/ale'
" Plug 'vim-airline/vim-airline'
" Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'tpope/vim-fugitive'
Plug 'scrooloose/nerdtree'
Plug 'skwp/greplace.vim'
" Plug 'tpope/vim-fireplace', { 'for': 'clojure' }
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
Plug 'mxw/vim-jsx', { 'for': 'javascript' }
" Plug 'neoclide/vim-jsx-improve'
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
Plug 'zivyangll/git-blame.vim'
Plug 'vim-airline/vim-airline'
Plug 'mfussenegger/nvim-dap'
Plug 'theHamsta/nvim-dap-virtual-text'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.0' }
Plug 'nvim-telescope/telescope-dap.nvim'
Plug 'rcarriga/nvim-dap-ui'

call plug#end()
"enables true colors
let $NVIM_TUI_ENABLE_TRUE_COLOR=1

"neovim terminal 
tnoremap jj <C-\><C-n>

"leader key
let mapleader=","

" autocmd TextChanged,TextChangedI <buffer> silent write

set termguicolors


syntax enable

set background=dark

let g:go_highlight_functions = 1
let g:go_highlight_types = 1

"Default colorscheme
" colorscheme jammy
" colorscheme rdark
" colorscheme dante
" colorscheme hemisu

" set background=light
" colorscheme ego
" colorscheme fahrenheit
" colorscheme monochrome
" colorscheme quagmire
" colorscheme blueshift
" colorscheme off
" colorscheme scheakur
" colorscheme loogica
" colorscheme darth
" colorscheme amber
" colorscheme monoacc
" colorscheme photon
" colorscheme earthburn
" colorscheme chlordane
" colorscheme colorsbox-faff

"http://www.vimninjas.com/2012/09/14/10-light-colors/
" colorscheme earthsong
colorscheme jitterbug
" colorscheme helios
" colorscheme dogrun
" colorscheme handmade-hero
" colorscheme photon


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
command NT NERDTree



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

" FZF
let $FZF_DEFAULT_COMMAND = 'ag -g ""'
nnoremap <leader>a :execute "Ag" expand("<cword>")<cr>
nnoremap <C-P> :Files<cr>
inoremap <C-f> <C-x><C-f>

" Ignore these folders 
set wildignore+=**/node_modules/**/*
set wildignore+=/build/**/*

" Buffer mapping
" map gn :bn<cr>
" map gp :bp<cr>
" map gd :bd<cr> 
"

" coc-nvim definition
nmap <silent> <C-]> <Plug>(coc-definition)


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


let t:is_transparent = 1
" Transparent
hi Normal guibg=NONE ctermbg=NONE
function! Toggle_transparent()
    if t:is_transparent == 0
        hi Normal guibg=NONE ctermbg=NONE
        let t:is_transparent = 1
    else
        set background=light
        hi Normal guibg=NONE ctermbg=NONE
        let t:is_tranparent = 0
    endif
endfunction

let g:markdown_fenced_languages = [
      \ 'vim',
      \ 'help'
      \]

" vim-test
let test#python#runner = 'pytest'

" typescript
" let g:typescript_indent_disable = 1

let g:closetag_xhtml_filetypes = 'js,jsx'

nnoremap <Leader>s :<C-u>call gitblame#echo()<CR>

let g:airline_theme='github'

lua << EOF
local dap = require('dap')
require("nvim-dap-virtual-text").setup()
require('telescope').load_extension('dap')
require("dapui").setup()

dap.adapters.chrome = {
    type = "executable",
    command = "node",
    args = {os.getenv("HOME") .. "/dap/vscode-chrome-debug/out/src/chromeDebug.js"}
}

local dap = require('dap')
dap.adapters.firefox = {
  type = 'executable',
  command = 'node',
  args = {os.getenv('HOME') .. '/dap/vscode-firefox-debug/dist/adapter.bundle.js'},
}

dap.configurations.typescript = {
  name = 'Debug with Firefox',
  type = 'firefox',
  request = 'launch',
  reAttach = true,
  url = 'http://localhost:3000',
  webRoot = '${workspaceFolder}',
  firefoxExecutable = '/usr/bin/firefox'
}

dap.configurations.javascriptreact = { -- change this to javascript if needed
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

dap.configurations.typescriptreact = { -- change to typescript if needed
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
}
vim.fn.sign_define('DapBreakpoint', {text='👉', texthl='', linehl='', numhl=''})
vim.fn.sign_define('DapStopped', {text='🔥', texthl='', linehl='', numhl=''})
EOF

nnoremap <leader>dh :lua require'dap'.toggle_breakpoint()<CR>
nnoremap <S-k> :lua require'dap'.step_out()<CR>
nnoremap <S-l> :lua require'dap'.step_into()<CR>
nnoremap <S-j> :lua require'dap'.step_over()<CR>
nnoremap <leader>ds :lua require'dap'.stop()<CR>
nnoremap <leader>dn :lua require'dap'.continue()<CR>
nnoremap <leader>dk :lua require'dap'.up()<CR>
nnoremap <leader>dj :lua require'dap'.down()<CR>
nnoremap <leader>d_ :lua require'dap'.disconnect();require'dap'.stop();require'dap'.run_last()<CR>
nnoremap <F1> :lua require'dap'.repl.open({}, 'vsplit')<CR><C-w>l
nnoremap <leader>di :lua require'dap.ui.widgets'.hover()<CR>
vnoremap <leader>di :lua require'dap.ui.variables'.visual_hover()<CR>
snoremap <leader>d? :lua require'dap.ui.variables'.scopes()<CR>
" nnoremap <leader>de :lua require'dap'.set_exception_breakpoints({"all"})<CR>
nnoremap <leader>da :lua require'debugHelper'.attach()<CR>
nnoremap <leader>dA :lua require'debugHelper'.attachToRemote()<CR>
nnoremap <leader>di :lua require'dap.ui.widgets'.hover()<CR>
nnoremap <leader>d? :lua local widgets=require'dap.ui.widgets';widgets.centered_float(widgets.scopes)<CR>

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
