" No-compatible mode
set nocp

" Setup language
language C
set langmenu=none

" Make sure encodings are correct
set encoding=utf-8
set termencoding=latin1
set fileencodings=ucs-bom,utf-8,latin1
setglobal fileencoding=latin1

" Enable syntax highlighting
syntax on

" My favourite font
set gfn=DejaVu\ Sans\ Mono\ 11

" Color-setup
"colorscheme desert
colorscheme settlemyer

" Position and size for GUI
if has("gui_running")
   winpos 0 0
   set columns=120
   set lines=80
   set guioptions-=T
   set maxmem=1024
   set maxmemtot=2048
   set maxmempattern=1024
endif

set ruler
set iskeyword+=_
set iskeyword+=$
set incsearch
set hlsearch
set autoindent
set showcmd
set list
set listchars=tab:»»,trail:·
set tags=./.tags;/
set showmatch
set formatoptions+=ro
set fileformats=unix,dos
set wildmode=list:longest
set diffopt+=iwhite
set hidden
set lazyredraw
set nowrap
set nosol
set nrformats-=octal

runtime macros/matchit.vim
filetype plugin indent on
runtime! indent.vim

" Mappings for copying file and path to windows clipboard
nmap ,cs :let @*=expand("%")<CR>
nmap ,cl :let @*=expand("%:p")<CR>

nnoremap ' `
nnoremap ` '

inoreabbr \date\ <c-r>=strftime("%y%m%d")<CR>

hi Pmenu guibg=Yellow guifg=Black
hi Pmenusel guibg=DarkGray guifg=White

" Setup Cygwin
"set shell=C:/cygwin/bin/bash
"let $BASH_ENV='~/.bashrc'
"let &shellcmdflag='-c'
"set shellxquote='
"set shellslash

if has("statusline")
   set statusline=%<%f\ %h%m%r%=%y\ %k[%{(&fenc\ ==\\"\"?&enc:&fenc).(&bomb?\",BOM\":\"\")}]\ %-14.(%l,%c%V%)\ %P
endif
set laststatus=2

" Only do this part when compiled with support for autocommands.
if has("autocmd")
  " When editing a file, always jump to the last known cursor position.
  " Don't do it when the position is invalid or when inside an event handler
  " (happens when dropping a file on gvim).
  autocmd BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif
endif " has("autocmd")

if $OS =~ "Windows"
   let VCSCommandCVSExec="c:/cygwin/bin/cvs"
endif " $OS =~ "Windows"

hi Pmenu guibg=Yellow guifg=Black
hi Pmenusel guibg=DarkGray guifg=White

function s:Cursor_Moved()

  let cur_pos= line ('.')

  if g:last_pos==0
    set cul
    let g:last_pos=cur_pos
    return
  endif

let diff= g:last_pos - cur_pos

if diff > 1 || diff < -1
   set cul
  else
   set nocul
end

let g:last_pos=cur_pos
    
endfunction

autocmd CursorMoved,CursorMovedI * call s:Cursor_Moved()
let g:last_pos=0


let g:miniBufExplForceSyntaxEnable=1
