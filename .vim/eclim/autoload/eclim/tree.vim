" Author:  Eric Van Dewoestine
" Version: $Revision: 1.9 $
"
" Description: {{{
"   Filesystem explorer.
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
  if !exists("g:TreeDirHighlight")
    let g:TreeDirHighlight = "Statement"
  endif
  if !exists("g:TreeFileHighlight")
    let g:TreeFileHighlight = "Normal"
  endif
  if !exists("g:TreeFileExecutableHighlight")
    let g:TreeFileExecutableHighlight = "Constant"
  endif
  if !exists("g:TreeActionHighlight")
    let g:TreeActionHighlight = "Statement"
  endif
" }}}

" Script Variables {{{
  let s:node_prefix = '  '

  let s:dir_opened_prefix = '- '
  let s:dir_closed_prefix = '+ '
  let s:file_prefix = '  '

  let s:indent_length = 4

  let s:node_regex = s:node_prefix .  '\(' .
    \ s:dir_opened_prefix . '\|' .
    \ s:dir_closed_prefix . '\|' .
    \ s:file_prefix . '\)'
  " \1 - indent, \2, node prefix + element prefix, \3 name
  let s:nodevalue_regex = '\(\s*\)' . s:node_regex . '\(.*\)'
  let s:root_regex = '^[/[:alpha:]]'

  " FIXME: move to buffer scope?
  let s:file_actions = []
  let s:settings_loaded = 0

  let s:tree_count = 0
  let s:refresh_nesting = 0
" }}}

" TreeHome() {{{
function eclim#tree#TreeHome ()
  let name = "Tree"
  if s:tree_count > 0
    let name .= s:tree_count
  endif
  let s:tree_count += 1

  call eclim#tree#Tree(name, [expand('$HOME')], [], 1, [])
endfunction " }}}

" TreePanes() {{{
function eclim#tree#TreePanes ()
  call eclim#tree#TreeHome()
  vertical new
  call eclim#tree#TreeHome()
endfunction " }}}

" Tree(name, roots, aliases, expand, filters) {{{
" name - The name to use for the tree buffer.
" roots - List of paths to use as tree roots.
" aliases - List of aliases for root paths, or an empty list for no aliasing.
" expand - 1 to pre expand the root directories, 0 otherwise.
" filters - List of file name patterns to include in directory listings, or an
"   empty list for no filtering.
function eclim#tree#Tree (name, roots, aliases, expand, filters)
  silent exec 'edit ' . escape(a:name, ' ')
  set modifiable

  let roots = s:NormalizeDirs(a:roots)
  let b:filters = a:filters
  let b:view_hidden = 0

  if len(a:aliases) > 0
    let b:aliases = {}
    let index = 0
    for alias in a:aliases
      if alias != ''
        let b:aliases[alias] = roots[index]
      endif
      let index += 1
    endfor

    call map(roots, 's:PathToAlias(v:val)')
  endif

  call append(line('$'), roots)

  if a:expand
    let index = len(roots)
    while index > 0
      call cursor(index + 1, 1)
      call s:ExpandDir()
      let index = index - 1
    endwhile
  endif

  call s:Editable()

  " delete empty first line.
  let saved = @"
  1,1delete
  let @" = saved

  setlocal ft=tree
  setlocal nowrap
  setlocal noswapfile
  setlocal nobuflisted
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal foldtext=getline(v:foldstart)

  call s:Uneditable()
  call s:Mappings()
  call s:Syntax()

  if exists("g:TreeSettingsFunction") && !s:settings_loaded
    let Settings = function(g:TreeSettingsFunction)
    call Settings()
    let s:settings_loaded = 1
  endif
endfunction " }}}

" ToggleCollapsedDir() {{{
function eclim#tree#ToggleCollapsedDir ()
  if eclim#tree#GetPath() =~ '/$'
    if getline('.') =~ '\s*' . s:node_prefix . s:dir_closed_prefix ||
        \ (getline('.') =~ s:root_regex && eclim#tree#GetLastChildPosition() == line('.'))
      call s:ExpandDir()
    else
      call s:CollapseDir()
    endif
  endif
endfunction " }}}

" ToggleFoldedDir() {{{
function eclim#tree#ToggleFoldedDir ()
  if eclim#tree#GetPath() =~ '/$'
    if foldclosed(line('.')) != -1
      call s:UnfoldDir()
    elseif getline('.') =~ '\s*' . s:node_prefix . s:dir_opened_prefix ||
        \ (getline('.') =~ s:root_regex && eclim#tree#GetLastChildPosition() != line('.'))
      call s:FoldDir()
    else
      call s:ExpandDir()
    endif
  endif
endfunction " }}}

" ToggleViewHidden() {{{
function eclim#tree#ToggleViewHidden ()
  let b:view_hidden = (b:view_hidden + 1) % 2

  let line = getline('.')
  let path = eclim#tree#GetPath()
  call cursor(1, 1)
  call eclim#tree#Refresh()
  while search(s:root_regex, 'W') != 0
    call eclim#tree#Refresh()
  endwhile

  call cursor(1, 1)
  while search(line, 'W') != 0 && eclim#tree#GetPath() != path
  endwhile
  call eclim#tree#Cursor(line)
endfunction " }}}

" GetFileInfo(file) {{{
function eclim#tree#GetFileInfo (file)
  if executable('ls')
    return split(system('ls -ld ' . a:file), '\n')[0]
  endif
  return ''
endfunction "}}}

" GetPath() {{{
function eclim#tree#GetPath ()
  let line = getline('.')
  let node = substitute(line, s:nodevalue_regex, '\3', '')

  let lnum = line('.')
  let cnum = col('.')
  let node = eclim#tree#GetParent() . node
  call cursor(lnum, cnum)

  let path = s:AliasToPath(node)

  " handle symbolic links
  if path =~ '->'
    let path = substitute(path, '\(.*\) -> .*', '\1', '')
    if node =~ '/$'
      let path .= '/'
    endif
  endif

  " handle executable files.
  if path =~ '\*$'
    let path = strpart(path, 0, len(path) - 1)
  endif

  return path
endfunction "}}}

" GetParent() {{{
function eclim#tree#GetParent ()
  let parent = ''

  let lnum = eclim#tree#GetParentPosition()
  if lnum
    call cursor(lnum, 1)
    let parent = eclim#tree#GetPath()
  endif

  return parent
endfunction " }}}

" GetParentPosition() {{{
function eclim#tree#GetParentPosition ()
  let lnum = 0
  let line = getline('.')
  if line =~ '\s*' . s:node_prefix
    if line =~ '^' . s:node_regex . '[.[:alnum:]_]'
      let search = s:root_regex
    else
      let search = '^'
      let index = 0
      let indent = s:GetIndent(line('.'))
      while index < indent - s:indent_length
        let search .= ' '
        let index += 1
      endwhile
      let search .= s:node_prefix .  s:dir_opened_prefix
    endif

    let lnum = search(search, 'bnW')
  endif

  return lnum
endfunction " }}}

" GetLastChildPosition() {{{
function eclim#tree#GetLastChildPosition ()
  let line = getline('.')

  " a root node
  if line =~ s:root_regex
    let lnum = search(s:root_regex, 'nW')
    return lnum > 0 ? lnum  - 1 : line('$')
  endif

  " non root node
  let sibling = '^' .
    \ substitute(line, s:nodevalue_regex, '\1' . escape(s:node_regex. '[.[:alnum:]_]', '\'), '')
  let lnum = line('.') + 1
  let indent = s:GetIndent(line('.'))
  while getline(lnum) !~ sibling && s:GetIndent(lnum) >= indent && lnum != line('$')
    let lnum += 1
  endwhile

  " back up one if on a node of equal or less depth
  if s:GetIndent(lnum) <= indent
    let lnum -= 1
  endif

  " no sibling below, use parent's value
  if lnum == line('.') && getline(lnum + 1) !~ sibling
    let clnum = line('.')
    let ccnum = col('.')

    call cursor(eclim#tree#GetParentPosition(), 1)
    let lnum = eclim#tree#GetLastChildPosition()

    call cursor(clnum, ccnum)
  endif

  return lnum
endfunction " }}}

" Execute(alt) {{{
function eclim#tree#Execute (alt)
  let path = eclim#tree#GetPath()

  " execute action on dir
  if path =~ '/$'
    if a:alt || foldclosed(line('.')) != -1
      call eclim#tree#ToggleFoldedDir()
    else
      call eclim#tree#ToggleCollapsedDir()
    endif

  " execute action on file
  else
    if !filereadable(path)
      echo "File is not readable or has been deleted."
    endif

    let actions = eclim#tree#GetFileActions(path)
    if len(actions) == 0
      echo "No registered actions for file: " . path
      return
    endif

    if a:alt
      call s:DisplayActionChooser(path, actions)
    else
      call eclim#tree#ExecuteAction(path, actions[0].action)
    endif
  endif
endfunction " }}}

" ExecuteAction(file, command) {{{
function eclim#tree#ExecuteAction (file, command)
  let path = fnamemodify(a:file, ':h')
  let path = substitute(path, '\', '/', 'g')

  let file = fnamemodify(a:file, ':t')
  let file = escape(file, ' &')
  let file = escape(file, ' &') " need to double escape
  let file = escape(file, '&') " '&' needs to be escaped 3 times.

  let cwd = substitute(getcwd(), '\', '/', 'g')
  " not using lcd, because the executed command may change windows.
  silent exec 'cd ' . escape(path, ' &')

  let command = a:command
  let command = substitute(command, '<file>', file, 'g')
  let command = substitute(command, '<cwd>', cwd, 'g')
  silent exec command

  redraw!
  silent exec 'cd ' . escape(cwd, ' &')
endfunction " }}}

" RegisterFileAction(regex,name,action) {{{
" regex - Pattern to match the file name against.
" name - Name of the action used for display purposes.
" action - The action to execute where <file> is replaced with the filename.
function eclim#tree#RegisterFileAction (regex, name, action)
  let entry = {}
  for e in s:file_actions
    if e.regex == a:regex
      let entry = e
      break
    endif
  endfor

  if len(entry) == 0
    let entry = {'regex': a:regex, 'actions': []}
    call add(s:file_actions, entry)
  endif

  call add(entry.actions, {'name': a:name, 'action': a:action})
endfunction " }}}

" GetFileActions(file) {{{
" Returns a list of dictionaries with keys 'name' and 'action'.
function eclim#tree#GetFileActions (file)
  let actions = []
  for entry in s:file_actions
    if a:file =~ entry.regex
      let actions += entry.actions
    endif
  endfor

  return actions
endfunction " }}}

" Shell(external) {{{
" Opens a shell either in the current vim session or externally.
function eclim#tree#Shell (external)
  let path = eclim#tree#GetPath()
  if !isdirectory(path)
    let path = fnamemodify(path, ':h')
  endif

  let cwd = getcwd()
  silent exec "lcd " . escape(path, ' &')
  if a:external
    if !exists("g:TreeExternalShell")
      echo "No external shell configured via 'g:TreeExternalShell' variable."
    else
      echo g:TreeExternalShell
      silent exec g:TreeExternalShell
      redraw!
    endif
  else
    shell
  endif
  silent exec "lcd " . escape(cwd, ' &')
endfunction " }}}

" Cursor(line) {{{
function eclim#tree#Cursor (line)
  let lnum = a:line
  let line = getline(lnum)

  call cursor(lnum, 1)
  if line !~ s:root_regex
    call search('[.[:alnum:]_]', 'W', lnum)
    if line =~ s:node_prefix . s:dir_closed_prefix
      let offset = len(s:dir_closed_prefix)
    elseif line =~ s:node_prefix . s:dir_closed_prefix
      let offset = len(s:dir_opened_prefix)
    else
      let offset = len(s:file_prefix)
    endif

    " attempt to keep the content in view when not wrapping
    if !&wrap
      normal zs
      exec 'normal ' . (winwidth(winnr()) / 2). 'zh'
    endif

    call cursor(lnum, col('.') - offset)
  endif
endfunction " }}}

" GetRoot() {{{
function eclim#tree#GetRoot ()
  if getline('.') =~ s:root_regex
    return s:AliasToPath(getline('.'))
  endif
  let start = search(s:root_regex, 'bcnW')
  return s:AliasToPath(getline(start))
endfunction " }}}

" SetRoot(path) {{{
function eclim#tree#SetRoot (path)
  let path = s:NormalizeDirs([fnamemodify(a:path, ':p')])[0]
  if !isdirectory(path)
    echo 'Directory does not exist or may have been deleted.'
    return
  endif

  let path = s:PathToAlias(path)

  " if on a root node
  if getline('.') =~ s:root_regex
    let start = line('.')

  " not on a root node
  else
    let start = search(s:root_regex, 'bW')
  endif
  let end = eclim#tree#GetLastChildPosition()

  call s:Editable()
  silent exec start . ',' . end . 'delete'

  let line = line('.')
  if line == 1
    let line = 0
  endif
  call append(line, path)

  " delete blank first line if any
  if getline(1) =~ '^$'
    silent 1,1delete
  endif
  " delete blank last line if any
  if getline('$') =~ '^$'
    silent exec line('$') . ',' . line('$') . 'delete'
  endif

  call cursor(line + 1, 1)
  call s:ExpandDir()
  call s:Uneditable()
endfunction " }}}

" Refresh() {{{
function eclim#tree#Refresh ()
  let clnum = line('.')
  let ccnum = col('.')

  let startpath = eclim#tree#GetPath()
  if s:refresh_nesting == 0
    let s:startpath = startpath
    " let vim track shifts in line numbers with a mark
    mark Z
  endif

  " if on a file or closed directory, refresh it's parent
  if startpath !~ '/$' ||
      \ getline('.') =~ '^\s*' . s:node_prefix . s:dir_closed_prefix
    call cursor(eclim#tree#GetParentPosition(), 1)
    let startpath = eclim#tree#GetPath()
  endif

  let start = line('.')
  let end = eclim#tree#GetLastChildPosition()

  call s:Editable()

  " first check the node we are on
  if (!isdirectory(startpath) && !filereadable(startpath)) ||
      \ (getline('.') !~ s:root_regex && s:IsHidden(startpath))
    silent exec start . ',' . end . 'delete'
    if s:refresh_nesting == 0
      call s:Uneditable()
    endif
    return
  endif

  if s:refresh_nesting == 0
    call eclim#util#Echo('Refreshing...')
  endif
  let s:refresh_nesting += 1

  " move cursor to first child
  call cursor(start + 1, 1)
  " get pattern to use to match children.
  let match = substitute(getline('.'), '^' . s:nodevalue_regex, '\1', '')
  let match = '^' . match . s:node_regex . '[.[:alnum:]_]'

  " walk the tree
  let lnum = line('.')
  while lnum <= end && lnum <= line('$')

    let line = getline('.')

    " open dir that needs to be refreshed as well.
    if line =~ '\s*' . s:node_prefix . s:dir_opened_prefix
      call eclim#tree#Refresh()
      let lnum = eclim#tree#GetLastChildPosition()
      let ldiff = lnum - line('.')
      let end += ldiff
      call cursor(lnum, 1)
    endif

    let path = eclim#tree#GetPath()

    " delete files, and dirs that do not exist, or are hidden.
    if (!isdirectory(path) && !filereadable(path)) || s:IsHidden(path)
      let last = eclim#tree#GetLastChildPosition()
      silent exec lnum . ',' . last . 'delete'
      let end -= (last - lnum) + 1
      continue
    endif

    let lnum += 1
    call cursor(lnum, 1)
  endwhile
  call cursor(start + 1, ccnum)

  " merge in any dirs that have been added
  let contents = split(globpath(escape(startpath, ','), '*'), '\n')
  if b:view_hidden
    let contents = split(globpath(escape(startpath, ','), '.*'), '\n') + contents
  endif
  let contents = s:NormalizeDirs(contents)
  let indent = s:GetChildIndent(start)
  let lnum = line('.')
  for entry in contents
    if eclim#tree#GetPath() != entry
      if s:MatchesFilter(entry)
        let rewrote = s:RewriteSpecial(entry)
        if isdirectory(entry)
          let entry = indent . s:node_prefix . s:dir_closed_prefix .
            \ fnamemodify(rewrote, ':h:t') . '/'
        else
          let entry = indent . s:node_prefix . s:file_prefix .
            \ fnamemodify(rewrote, ':t')
        endif
        if lnum <= line('$')
          call append(lnum - 1, entry)
        else
          call append(line('$'), entry)
        endif
        let lnum += 1
      endif
    else
      if getline(lnum) =~ '\s*' . s:node_prefix . s:dir_opened_prefix
        call cursor(eclim#tree#GetLastChildPosition() + 1, 1)
        let lnum = line('.')
      else
        let lnum += 1
        call cursor(lnum, 1)
      endif
    endif
  endfor

  call cursor(clnum, ccnum)
  let s:refresh_nesting -= 1

  if s:refresh_nesting == 0
    call s:Uneditable()
    call eclim#util#Echo(' ')
    " return to marked position.
    call cursor(line("'Z"), col("`Z"))
    " if the entry that we started on is gone, move the cursor up a line.
    if s:startpath != eclim#tree#GetPath()
      call cursor(line('.') - 1, col('.'))
    endif
  endif
endfunction " }}}

" MoveToLastChild() {{{
function eclim#tree#MoveToLastChild ()
  mark '
  if getline('.') !~ '^\s*' . s:node_prefix . s:dir_opened_prefix . '[.[:alnum:]_]'
    call cursor(eclim#tree#GetParentPosition(), 1)
  endif
  call eclim#tree#Cursor(eclim#tree#GetLastChildPosition())
endfunction " }}}

" MoveToParent() {{{
function eclim#tree#MoveToParent ()
  mark '
  call eclim#tree#Cursor(eclim#tree#GetParentPosition())
endfunction " }}}

" AliasToPath(alias) {{{
function s:AliasToPath (alias)
  if exists('b:aliases')
    let alias = ''
    for alias in keys(b:aliases)
      if alias != '' && a:alias =~ '^' . alias
        return substitute(a:alias, '^' . alias . '/', b:aliases[alias], '')
      endif
    endfor
  endif
  return a:alias
endfunction " }}}

" PathToAlias(path) {{{
function s:PathToAlias (path)
  if exists('b:aliases')
    let path = ''
    for alias in keys(b:aliases)
      let path = b:aliases[alias]
      if alias != '' && a:path =~ '^' . path
        return substitute(a:path, '^' . path, alias . '/', '')
      endif
    endfor
  endif
  return a:path
endfunction " }}}

" ExpandDir() {{{
function s:ExpandDir ()
  let dir = eclim#tree#GetPath()

  if !isdirectory(dir)
    echo "Not a directory or directory may have been removed."
    return
  endif

  let contents = split(globpath(escape(dir, ','), '*'), '\n')
  if b:view_hidden
    let contents = split(globpath(escape(dir, ','), '.*'), '\n') + contents
  endif
  let contents = s:NormalizeDirs(contents)

  let dirs = filter(copy(contents), 'isdirectory(v:val)')
  let files = filter(copy(contents), '!isdirectory(v:val)')

  " filter files
  let filtered = []
  for file in files
    if s:MatchesFilter(file)
      call add(filtered, file)
    endif
  endfor
  let files = filtered

  " rewrite any special files (executables, symbolic links, etc).
  call map(dirs, 's:RewriteSpecial(v:val)')
  call map(files, 's:RewriteSpecial(v:val)')

  let indent = s:GetChildIndent(line('.'))
  call map(dirs, 'substitute(v:val, dir, indent . s:node_prefix . s:dir_closed_prefix, "")')
  call map(files, 'substitute(v:val, dir, indent . s:node_prefix . s:file_prefix, "")')

  " update current line
  call s:UpdateLine(s:node_prefix . s:dir_closed_prefix,
    \ s:node_prefix . s:dir_opened_prefix)

  call s:Editable()
  call append(line('.'), dirs + files)
  call s:Uneditable()
endfunction " }}}

" RewriteSpecial(file) {{{
function s:RewriteSpecial (file)
  let file = a:file
  if executable('ls')
    let info = ''

    " executable files
    if s:IsFileExecutable(file)
      let file .= '*'
    endif

    " symbolic links
    let tmpfile = file =~ '/$' ? strpart(file, 0, len(file) - 1) : file
    if getftype(tmpfile) == 'link'
      if info == ''
        let info = system('ls -ldF ' . tmpfile)
      endif
      let linkto = substitute(info, '.*-> \(.*\)\n', '\1', '')

      if linkto =~ '//$'
        let linkto = strpart(linkto, 0, len(linkto) - 1)
      endif

      if s:IsFileExecutable(linkto =~ '^/' ? linkto : fnamemodify(tmpfile, ':h') . linkto)
        let linkto .= '*'
      endif

      let file = tmpfile . ' -> ' . linkto
    endif
  endif
  return file
endfunction " }}}

" IsFileExecutable(file) {{{
" Determines if the supplied file is executable, ignoring links and
" directories.
function s:IsFileExecutable (file)
  if !isdirectory(a:file)
    let info = system('ls -l ' . a:file)
    if info[3] =~ '[sx]' && info[0] != 'l'
      return 1
    endif
  endif
  return 0
endfunction " }}}

" CollapseDir() {{{
function s:CollapseDir ()
  " update current line
  call s:UpdateLine(s:node_prefix . s:dir_opened_prefix,
    \ s:node_prefix . s:dir_closed_prefix)

  let lnum = line('.')
  let cnum = col('.')
  let start = lnum + 1
  let end = eclim#tree#GetLastChildPosition()

  if start > end
    return
  endif

  call s:Editable()
  silent exec start . ',' . end . 'delete'
  call s:Uneditable()

  call cursor(lnum, cnum)
endfunction " }}}

" UnfoldDir() {{{
function s:UnfoldDir ()
  foldopen
endfunction " }}}

" FoldDir() {{{
function s:FoldDir ()
  let start = line('.')
  let end = eclim#tree#GetLastChildPosition()

  exec start . ',' . end . 'fold'
endfunction " }}}

" GetIndent() {{{
function s:GetIndent (line)
  let indent = indent(a:line)
  if getline(a:line) =~ s:file_prefix . '[.[:alnum:]_]' && s:file_prefix =~ '^\s*$'
    let indent -= len(s:file_prefix)
  endif
  if s:node_prefix =~ '^\s*$'
    let indent -= len(s:node_prefix)
  endif

  return indent
endfunction " }}}

" GetChildIndent() {{{
function s:GetChildIndent (line)
  let indent = ''
  if getline(a:line) =~ '\s*' . s:node_prefix
    let num = indent(a:line)

    if s:node_prefix =~ '^\s*$'
      let num -= len(s:node_prefix)
    endif

    let index = 0
    while index < num + s:indent_length
      let indent .= ' '
      let index += 1
    endwhile
  endif

  return indent
endfunction " }}}

" MatchesFilter(file) {{{
function s:MatchesFilter (file)
  if len(b:filters) > 0
    for filter in b:filters
      if entry =~ filter
        return 1
      endif
    endfor
    return 0
  endif

  return 1
endfunction " }}}

" IsHidden(path) {{{
function s:IsHidden (path)
  if !b:view_hidden
    let path = a:path
    if isdirectory(path)
      let path = fnamemodify(path, ':h')
    endif
    let path = fnamemodify(path, ':t')
    return path =~ '^\.'
  endif
  return 0
endfunction " }}}

" NormalizeDirs(dirs) {{{
function s:NormalizeDirs (dirs)
  " normalize path separators
  call map(a:dirs, 'substitute(v:val, "\\\\", "/", "g")')

  let dirs = filter(copy(a:dirs),
    \ 'isdirectory(v:val) && v:val !~ "/\\(\\.\\|\\.\\.\\)$"')
  let files = filter(copy(a:dirs), '!isdirectory(v:val)')

  " append trailing '/' to dirs if necessary
  call map(dirs, 'substitute(v:val, "\\(.\\{-}\\)\\(/$\\|$\\)", "\\1/", "")')

  return dirs + files
endfunction " }}}

" UpdateLine(pattern, substitution) {{{
function s:UpdateLine (pattern, substitution)
  let lnum = line('.')
  let line = getline(lnum)
  let line = substitute(line, a:pattern, a:substitution, '')

  call s:Editable()
  call append(lnum, line)
  silent exec lnum . ',' . lnum . 'delete'
  call s:Uneditable()
endfunction " }}}

" DisplayActionChooser(file, actions) {{{
function s:DisplayActionChooser (file, actions)
  new
  exec "resize " . (len(a:actions) + 1)

  let b:actions = a:actions
  let b:file = a:file
  for action in a:actions
    call append(line('$'), action.name)
  endfor

  nmap <buffer> <silent> <cr> :call eclim#tree#ActionExecute()<cr>

  exec "hi link TreeAction " . g:TreeActionHighlight
  syntax match TreeAction /.*/

  call s:Editable()
  1,1delete
  call s:Uneditable()
  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=delete
endfunction "}}}

" ActionExecute() {{{
function eclim#tree#ActionExecute ()
  let command = ''
  let line = getline('.')
  for action in b:actions
    if action.name == line
      let command = action.action
      break
    endif
  endfor

  let file = b:file
  close
  call eclim#tree#ExecuteAction(file, command)

endfunction "}}}

" Editable() {{{
function s:Editable ()
  let b:saved = @"
  setlocal noreadonly
  setlocal modifiable
endfunction " }}}

" Uneditable() {{{
function s:Uneditable ()
  setlocal nomodifiable
  let @" = b:saved
endfunction " }}}

" Mappings() {{{
function s:Mappings ()
  nmap <buffer> <silent> <cr> :call eclim#tree#Execute(0)<cr>
  nmap <buffer> <silent> o    :call eclim#tree#Execute(1)<cr>

  nmap <buffer> <silent> i    :echo eclim#tree#GetFileInfo(eclim#tree#GetPath())<cr>
  nmap <buffer> <silent> I    :echo eclim#tree#GetFileInfo(eclim#tree#GetPath())<cr>

  nmap <buffer> <silent> s    :call eclim#tree#Shell(0)<cr>
  nmap <buffer> <silent> S    :call eclim#tree#Shell(1)<cr>

  nmap <buffer> <silent> R    :call eclim#tree#Refresh()<cr>

  nmap <buffer> <silent> A    :call eclim#tree#ToggleViewHidden()<cr>

  nmap <buffer> <silent> H    :call eclim#tree#SetRoot(expand('$HOME'))<cr>
  nmap <buffer> <silent> C    :call eclim#tree#SetRoot(eclim#tree#GetPath())<cr>
  nmap <buffer> <silent> B
    \ :call eclim#tree#SetRoot(fnamemodify(eclim#tree#GetRoot(), ':h:h'))<cr>

  nmap <buffer> <silent> j    j:call eclim#tree#Cursor(line('.'))<cr>
  nmap <buffer> <silent> k    k:call eclim#tree#Cursor(line('.'))<cr>
  nmap <buffer> <silent> p    :call eclim#tree#MoveToParent()<cr>
  nmap <buffer> <silent> P    :call eclim#tree#MoveToLastChild()<cr>

  command! -nargs=1 -complete=dir -buffer CD :call eclim#tree#SetRoot('<args>')
endfunction " }}}

" Syntax() {{{
function s:Syntax ()
  exec "hi link TreeDir " . g:TreeDirHighlight
  exec "hi link TreeFile " . g:TreeFileHighlight
  exec "hi link TreeFileExecutable " . g:TreeFileExecutableHighlight
  syntax match TreeDir /\([[:alpha:]]\?:\?[\/]\?[.[:alnum:]_]\+.*\/$\|^\/$\)/
  syntax match TreeFile /[.[:alnum:]_].*[^\/\*]$/
  syntax match TreeFileExecutable /[.[:alnum:]_].*[^\/]\*$/
endfunction " }}}

" vim:ft=vim:fdm=marker
