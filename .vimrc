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
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-surround'
Plug 'jiangmiao/auto-pairs'
Plug 'ggreer/the_silver_searcher'
Plug 'cakebaker/scss-syntax.vim', { 'for': 'scss' }
Plug 'JulesWang/css.vim', { 'for': 'css' }
Plug 'tpope/vim-haml', { 'for': 'haml' }
Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
Plug 'othree/html5.vim', { 'for': 'html' }
Plug 'Shougo/unite.vim'
Plug 'Rip-Rip/clang_complete'
Plug 'hail2u/vim-css3-syntax' , { 'for': 'css' }
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
Plug 'airblade/vim-gitgutter'
Plug 'mhinz/vim-startify'
Plug 'flazz/vim-colorschemes'
Plug 'Konfekt/FastFold'
Plug 'tpope/vim-rails'
Plug 'python-rope/ropevim'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all'  }
Plug 'junegunn/fzf.vim'
Plug 'majutsushi/tagbar'
Plug 'ryanoasis/vim-devicons'
Plug 'bilalq/lite-dfm'
Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'ahayman/vim-nodejs-complete', { 'for': 'javascript' }
Plug 'jelera/vim-javascript-syntax', { 'for': 'javascript' }
Plug 'moll/vim-node', { 'for': 'javascript' }
Plug 'rafi/awesome-vim-colorschemes'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'Yggdroot/indentLine'

call plug#end()
"call vundle#end()

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

syntax enable

set background=dark
"Default colorscheme
colorscheme solarized8_light
let NERDTreeWinSize=25

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
set wildignore=*.o,*~,*.pyc

"disabling highlighted background bug
set t_ut=

"line number"
:set number

"close tags will work for these files extensions
let g:closetag_filenames = "*.html.erb,*.html,*.xhtml,*.phtml"


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
let $FZF_DEFAULT_COMMAND = 'ag -g ""'
nnoremap <leader>a :execute "Ag" expand("<cword>")<cr>
nnoremap <C-P> :Files<cr>
inoremap <C-f> <C-x><C-f>

" Ignore these folders 
set wildignore+=**/node_modules/**/*

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
let g:indentLine_char = '▸'

