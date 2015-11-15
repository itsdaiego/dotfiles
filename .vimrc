""
"" Janus setup
""

" Define paths
if has('win32') || has('win64') || has('win32unix')
  let g:janus_path = expand("~/.vim/janus/vim")
  let g:janus_vim_path = expand("~/.vim/janus/vim")
else
  let g:janus_path = escape(fnamemodify(resolve(expand("<sfile>:p")), ":h"), ' ')
  let g:janus_vim_path = escape(fnamemodify(resolve(expand("<sfile>:p" . "vim")), ":h"), ' ')
endif
let g:janus_custom_path = expand("~/.janus")

" Source janus's core
exe 'source ' . g:janus_vim_path . '/core/before/plugin/janus.vim'

" You should note that groups will be processed by Pathogen in reverse
" order they were added.
call janus#add_group("tools")
call janus#add_group("langs")
call janus#add_group("colors")

""
"" Customisations
""

if filereadable(expand("~/.vimrc.before"))
  source ~/.vimrc.before
endif


" Disable plugins prior to loading pathogen
exe 'source ' . g:janus_vim_path . '/core/plugins.vim'

""
"" Pathogen setup
""

" Load all groups, custom dir, and janus core
call janus#load_pathogen()

" .vimrc.after is loaded after the plugins have loaded
"set runtimepath^=~/.vim/bundle/ctrlp.vim


"From now on it's my personal config (not Janus related)



let NERDTreeWinSize=25

filetype plugin indent on
"show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

" Alias for syntastic plugin
command Er Errors
command Cl lclose
" Alias for Nerdtree plugin
command NT NERDTree
