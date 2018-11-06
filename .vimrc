call plug#begin('~/.vim/plugged')

"" ---------- ADDITIONAL PLUGINS --------- "
Plug 'tpope/vim-commentary'
Plug 'ggreer/the_silver_searcher'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all'  }
Plug 'junegunn/fzf.vim'
Plug 'chriskempson/base16-vim'
Plug 'flazz/vim-colorschemes'
Plug 'rafi/awesome-vim-colorschemes'
Plug 'Shougo/deoplete.nvim'
Plug 'neomake/neomake'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'tpope/vim-fugitive'
Plug 'scrooloose/nerdtree'
Plug 'skwp/greplace.vim'
Plug 'tpope/vim-fireplace', { 'for': 'clojure' }
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
Plug 'hail2u/vim-css3-syntax' , { 'for': 'css' }
Plug 'cakebaker/scss-syntax.vim', { 'for': 'scss' }
Plug 'mxw/vim-jsx', { 'for': 'javascript' }
Plug 'majutsushi/tagbar'
Plug 'klen/python-mode', { 'for': 'python' }

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

set background=light

let g:lucius_style = "light"
let g:lucius_contrast = "high"
let g:lucius_contrast_bg = "high"

"Default colorscheme
colorscheme zenburn

let NERDTreeWinSize=60

filetype plugin indent on
"show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=2
" On pressing tab, insert 4 spaces
set expandtab


set relativenumber


"remapped keys
ino jj <esc>
command Er Errors
" Alias for syntastic plugin
command Cl lclose
" Alias for Nerdtree plugin
command NT NERDTree



"Track files that should be ignored
set wildignore=*.o,*~,*.pyc,node_modules

"disabling highlighted background bug
" set t_ut=

"line number"
:set number

"close tags will work for these files extensions
let g:closetag_filenames = "*.html.erb,*.html,*.xhtml,*.phtml"


set backspace=indent,eol,start

"Neovim
"Using mouse with neovim
set mouse=

" set ttyfast
" set lazyredraw
" set re=1

"neomake
autocmd InsertLeave,BufWritePost * update | Neomake  
" autocmd BufWritePost * update | Neomake  

let g:airline_theme='badcat'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline_section_warning = ''
let g:airline_inactive_collapse = 0
let g:airline#extensions#default#section_truncate_width = {
  \ 'a': 60,
  \ 'b': 80,
  \ 'x': 100,
  \ 'y': 100,
  \ 'z': 60,
\ }

" FZF
let $FZF_DEFAULT_COMMAND = 'ag -g ""'
nnoremap <leader>a :execute "Ag" expand("<cword>")<cr>
nnoremap <C-P> :Files<cr>
inoremap <C-f> <C-x><C-f>

" Ignore these folders 
set wildignore+=**/node_modules/**/*
set wildignore+=/build/**/*

" Buffer mapping
map gn :bn<cr>
map gp :bp<cr>
map gd :bd<cr> 

nmap <F2> :TagbarToggle<CR>
nmap <F1> :LiteDFMToggle<CR>

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
let g:deoplete#enable_at_startup = 1

set hidden

set inccommand=split

" Pymode
let g:pymode_lint_ignore = "E501, W404"


set foldmethod=indent
set foldlevel=50
set nofoldenable
nnoremap <Space> za
