"" Vundle
set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
"call vundle#begin()
call plug#begin('~/.vim/plugged')

"" ---------- ADDITIONAL PLUGINS --------- "
Plug 'Valloric/YouCompleteMe'
Plug 'neomake/neomake'
Plug 'easymotion/vim-easymotion'
Plug 'vim-airline/vim-airline'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'rking/ag.vim'
Plug 'mileszs/ack.vim'
Plug 'ggreer/the_silver_searcher'
Plug 'cakebaker/scss-syntax.vim', { 'for': 'scss' }
Plug 'JulesWang/css.vim', { 'for': 'css' }
Plug 'tpope/vim-haml', { 'for': 'haml' }
Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
Plug 'othree/html5.vim', { 'for': 'html' }
Plug 'Shougo/unite.vim'
Plug 'Rip-Rip/clang_complete'
Plug 'hail2u/vim-css3-syntax' , { 'for': 'css' }
Plug 'kien/ctrlp.vim'
Plug 'tpope/vim-fugitive'
Plug 'scrooloose/nerdtree'
Plug 'alvan/vim-closetag'
Plug 'joonty/vdebug'
Plug 'powerline/powerline'
Plug 'nvie/vim-flake8', { 'for': 'python' }
Plug 'hynek/vim-python-pep8-indent', { 'for': 'python' }
Plug 'hdima/python-syntax', { 'for': 'python' }
Plug 'editorconfig/editorconfig-vim'
Plug 'gotcha/vimpdb', { 'for': 'python' }
Plug 'tpope/vim-commentary'
Plug 'tomtom/tlib_vim'
Plug 'honza/vim-snippets'
Plug 'garbas/vim-snipmate'
Plug 'kien/rainbow_parentheses.vim'
Plug 'klen/python-mode', { 'for': 'python' }
Plug 'idanarye/vim-vebugger'
Plug 'vim-addon-mw-utils'
Plug 'tomtom/quickfixsigns_vim/'
Plug 'flazz/vim-colorschemes'
Plug 'Konfekt/FastFold'
Plug 'tpope/vim-rails'
Plug 'python-rope/ropevim'

call plug#end()
"call vundle#end()

filetype plugin indent on
"" ------ Personal Configuration --------- "
"sem t_Co=256

"enables true colors
let $NVIM_TUI_ENABLE_TRUE_COLOR=1


let g:solarized_termcolors=256

" set clipboard=unnamed

"neovim terminal 
tnoremap jj <C-\><C-n>

"leader key
let mapleader=","

autocmd TextChanged,TextChangedI <buffer> silent write

set termguicolors

"Default colorscheme
colorscheme molokai
let NERDTreeWinSize=25

filetype plugin indent on
"show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

syntax enable

set background=dark

set relativenumber


"remapped keys
ino jj <esc>
command Er Errors
" Alias for syntastic plugin
command Cl lclose
" Alias for Nerdtree plugin
command NT NERDTree


"CtrlP config
let g:ctrlp_working_path_mode=0

"Track files that should be ignored
set wildignore=*.o,*~,*.pyc

"ignoring certain directories
let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|\plugins\|\platforms\|git'

"disabling highlighted background bug
set t_ut=

"line number"
:set number

"close tags will work for these files extensions
let g:closetag_filenames = "*.html.erb,*.html,*.xhtml,*.phtml"


let g:ackprg = "ag --vimgrep"

set backspace=indent,eol,start



let g:ycm_register_as_syntastic_checker = 0


"vim-javascript config
let g:javascript_plugin_ngdoc = 1
let g:javascript_plugin_jsdoc = 1


"Neovim
"Using mouse with neovim
set mouse=

set ttyfast
set lazyredraw
set re=1

"neomake
autocmd InsertLeave,BufWritePost * update | Neomake  

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
nnoremap <leader>a :execute "Ag" expand("<cword>")<cr>
nnoremap <C-P> :Files<cr>
nnoremap <C-F> :Ag<space>
" Buffer mapping
map gn :bn<cr>
map gp :bp<cr>
map gd :bd<cr> 

