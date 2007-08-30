" Author:  Eric Van Dewoestine
" Version: $Revision: 1.2 $

if exists("current_compiler")
  finish
endif
let current_compiler = "eclim_xmllint"

CompilerSet makeprg=xmllint\ --valid\ --noout\ $*

CompilerSet errorformat=
  \%E%f:%l:\ %.%#\ error\ :\ %m,
  \%W%f:%l:\ %.%#\ warning\ :\ %m,
  \%-Z%p^,
  \%-C%.%#,
  \%-G%.%#

" vim:ft=vim:fdm=marker
