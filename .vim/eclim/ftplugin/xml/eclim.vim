" Author:  Eric Van Dewoestine
" Version: $Revision: 1.5 $
"
" Description: {{{
"   see http://eclim.sourceforge.net/vim/xml/validate.html
"
" License:
"
" Copyright (c) 2005 - 2006
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"      http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.
"
" }}}

" Global Variables {{{
if !exists("g:EclimXmlValidate")
  let g:EclimXmlValidate = 1
endif
" }}}

if g:EclimXmlValidate
  augroup eclim_xml
    autocmd! BufWritePost <buffer>
    autocmd BufWritePost <buffer> call eclim#xml#Validate('', 1)
  augroup END
endif

" Command Declarations {{{
if !exists(":Validate")
  command -nargs=? -complete=file -bang -buffer Validate
    \ :call eclim#xml#Validate('<args>', 0, '<bang>')

  command -nargs=? -buffer DtdDefinition
    \ :call eclim#xml#DtdDefinition('<args>')
  command -nargs=? -buffer XsdDefinition
    \ :call eclim#xml#XsdDefinition('<args>')
endif
" }}}

" vim:ft=vim:fdm=marker
