"" Vundle
set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

"" ---------- ADDITIONAL PLUGINS --------- "
Plugin 'Valloric/YouCompleteMe'
Plugin 'tpope/vim-vinegar'
Plugin 'vim-airline/vim-airline'
Plugin 'scrooloose/nerdcommenter'
Plugin 'easymotion/vim-easymotion'
Plugin 'tpope/vim-surround'
Plugin 'jiangmiao/auto-pairs'
Plugin 'mileszs/ack.vim'
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

call vundle#end()

filetype plugin indent on
"" ------ Personal Configuration --------- "
if $COLORTERM == 'gnome-terminal'
  set t_Co=256
endif

"Default colorscheme
colorscheme onedark
let NERDTreeWinSize=25

filetype plugin indent on
"show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

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
let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|\platforms\|git'

"disabling highlighted background bug
set t_ut=

"line number"
:set number
