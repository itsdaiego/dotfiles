"" Vundle
set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

"" ---------- ADDITIONAL PLUGINS --------- "
Plugin 'Valloric/YouCompleteMe'
Plugin 'Shougo/deoplete.nvim'
Plugin 'tpope/vim-vinegar'
Plugin 'vim-airline/vim-airline'
Plugin 'scrooloose/nerdcommenter'
Plugin 'easymotion/vim-easymotion'
Plugin 'tpope/vim-surround'
Plugin 'jiangmiao/auto-pairs'
Plugin 'rking/ag.vim'
Plugin 'mileszs/ack.vim'
Plugin 'ggreer/the_silver_searcher'
Plugin 'cakebaker/scss-syntax.vim'
Plugin 'JulesWang/css.vim'
Plugin 'tpope/vim-haml'
Plugin 'jpo/vim-railscasts-theme'
Plugin 'pangloss/vim-javascript'
Plugin 'othree/html5.vim'
Plugin 'Shougo/unite.vim'
Plugin 'Rip-Rip/clang_complete'
Plugin 'hail2u/vim-css3-syntax'
Plugin 'kien/ctrlp.vim'
Plugin 'tpope/vim-fugitive'
Plugin 'scrooloose/nerdtree'
Plugin 'scrooloose/syntastic'
Plugin 'flazz/vim-colorschemes'
Plugin 'alvan/vim-closetag'
Plugin 'joonty/vdebug'
Plugin 'powerline/powerline'
" Plugin 'xolox/vim-easytags'
Plugin 'xolox/vim-misc'
Plugin 'nvie/vim-flake8'
Plugin 'Shutnik/jshint2.vim'
Plugin 'lambdalisue/vim-fullscreen'
Plugin 'vim-scripts/CSApprox'
Plugin 'hynek/vim-python-pep8-indent'
Plugin 'hdima/python-syntax'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'gotcha/vimpdb'
Plugin 'tpope/vim-commentary'
Plugin 'vim-addon-mw-utils'
Plugin 'tomtom/tlib_vim'
Plugin 'honza/vim-snippets'
Plugin 'garbas/vim-snipmate'
Plugin 'kien/rainbow_parentheses.vim'
Plugin 'klen/python-mode'



call vundle#end()

filetype plugin indent on
"" ------ Personal Configuration --------- "
"sem t_Co=256

"enables true colors
let $NVIM_TUI_ENABLE_TRUE_COLOR=1


let g:solarized_termcolors=256

set termguicolors

"Default colorscheme
colorscheme gruvbox
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

"async linting
"autocmd! BufWritePost,BufEnter * Neomake

"syntastic
let g:syntastic_enable_highlighting = 1
let g:syntastic_echo_current_error = 1
let g:syntastic_enable_signs = 1
let g:syntastic_enable_balloons = 0
let g:syntastic_enable_highlighting = 0

" vim-airline
if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

if !exists('g:airline_powerline_fonts')
  let g:airline#extensions#tabline#left_sep = ' '
  let g:airline#extensions#tabline#left_alt_sep = '|'
  let g:airline_left_sep          = '▶'
  let g:airline_left_alt_sep      = '»'
  let g:airline_right_sep         = '◀'
  let g:airline_right_alt_sep     = '«'
  let g:airline#extensions#branch#prefix     = '⤴' "➔, ➥, ⎇
  let g:airline#extensions#readonly#symbol   = '⊘'
  let g:airline#extensions#linecolumn#prefix = '¶'
  let g:airline#extensions#paste#symbol      = 'ρ'
  let g:airline_symbols.linenr    = '␊'
  let g:airline_symbols.branch    = '⎇'
  let g:airline_symbols.paste     = 'ρ'
  let g:airline_symbols.paste     = 'Þ'
  let g:airline_symbols.paste     = '∥'
  let g:airline_symbols.whitespace = 'Ξ'
else
  let g:airline#extensions#tabline#left_sep = ''
  let g:airline#extensions#tabline#left_alt_sep = ''

  " powerline symbols
  let g:airline_left_sep = ''
  let g:airline_left_alt_sep = ''
  let g:airline_right_sep = ''
  let g:airline_right_alt_sep = ''
  let g:airline_symbols.branch = ''
  let g:airline_symbols.readonly = ''
  let g:airline_symbols.linenr = ''
endif



