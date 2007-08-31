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

" Color-setup
"if has("autocmd")
  "autocmd ColorScheme * hi Pmenu guibg=Yellow guifg=Black | hi Pmenusel guibg=DarkGray guifg=White | hi CursorLine guibg=Yellow guifg=Black
"endif
"colorscheme settlemyer
"colorscheme vibrantink
let g:rdark_current_line=1
colorscheme rdark
"colorscheme argoyle

" Position and size for GUI
if has("gui_running")
   " My favourite font
   set gfn=DejaVu_Sans_Mono:h9:cANSI
   "set gfn=Bitstream\ Vera\ Sans\ Mono
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
set mouse=a

runtime macros/matchit.vim
filetype plugin indent on
runtime! indent.vim

" Mappings for copying file and path to windows clipboard
nmap ,cs :let @*=expand("%")<CR>
nmap ,cl :let @*=expand("%:p")<CR>

nnoremap ' `
nnoremap ` '

imap ;d =strftime("%Y-%m-%d")

inoreabbr \date\ <c-r>=strftime("%y%m%d")<CR>

if has("gui_running")
  set shell=cmd.exe
  " Setup Cygwin
  "set shell=C:/cygwin/bin/bash
  "let $BASH_ENV='~/.bashrc'
  "let g:netrw_cygwin=1
  "let &shellcmdflag='-lc'
  let &shellcmdflag='/q /c'
  "set shellxquote='
  set shellslash
  let g:netrw_scp_cmd = 'c:/Progra~1/PuTTY/pscp.exe -q -batch'
endif

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
let g:miniBufExplForceSyntaxEnable=1

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
