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

"http://www.vimninjas.com/2012/09/14/10-light-colors/
" colorscheme earthsong
colorscheme heroku-terminal
" colorscheme grayorange
" colorscheme photon


let NERDTreeWinSize=40

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
:set number

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
set mouse=

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

nmap <F2> :TagbarToggle<CR>
nmap <F1> :LiteDFMToggle<CR>


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
