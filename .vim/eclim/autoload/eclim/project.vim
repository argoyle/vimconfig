" Author:  Eric Van Dewoestine
" Version: $Revision: 1.9 $
"
" Description: {{{
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

" Script Variables {{{
  let s:command_create = '-command project_create -f "<folder>"'
  let s:command_create_depends = ' -d <depends>'
  let s:command_delete = '-command project_delete -n "<project>"'
  let s:command_refresh = '-command project_refresh -n "<project>"'
  let s:command_projects = '-command project_info -filter vim'
  let s:command_project_info = s:command_projects . ' -n "<project>"'
  let s:command_project_setting = s:command_project_info . ' -s <setting>'
  let s:command_update = '-command project_update -n "<project>" -s "<settings>"'
  let s:command_open = '-command project_open -n "<project>"'
  let s:command_close = '-command project_close -n "<project>"'
" }}}

" ProjectCD(scope) {{{
" Change the current working directory to the current project root.
function! eclim#project#ProjectCD (scope)
  let dir = eclim#project#GetCurrentProjectRoot()
  if a:scope == 0
    exec 'cd ' . dir
  elseif a:scope == 1
    exec 'lcd ' . dir
  endif
endfunction " }}}

" ProjectCreate(args) {{{
" Creates a project at the supplied folder
function! eclim#project#ProjectCreate (args)
  let args = eclim#util#ParseArgs(a:args)

  let folder = fnamemodify(expand(args[0]), ':p')
  let folder = substitute(folder, '\', '/', 'g')
  let command = substitute(s:command_create, '<folder>', folder, '')

  " get dependent project names.
  if len(args) > 1
    let depends = join(args[1:], ',')
    let command = command . s:command_create_depends
    let command = substitute(command, '<depends>', depends, '')
  endif

  let result = eclim#ExecuteEclim(command)
  if result != '0'
    call eclim#util#Echo(result)
  endif
endfunction " }}}

" ProjectDelete(name) {{{
" Deletes a project with the supplied name.
function! eclim#project#ProjectDelete (name)
  let command = substitute(s:command_delete, '<project>', a:name, '')
  let result = eclim#ExecuteEclim(command)
  if result != '0'
    call eclim#util#Echo(result)
  endif
endfunction " }}}

" ProjectRefresh(args) {{{
" Refresh the requested projects.
function! eclim#project#ProjectRefresh (args)
  if a:args != ''
    let projects = split(a:args)

    " validate project names.
    let valid = eclim#project#GetProjectNames()
    let message = ''
    for project in projects
      if count(valid, project) == 0
        if message != ''
          let message .= "\n"
        endif
        let message .= "Project '" . project . "' not found."
      endif
    endfor
    if message != ''
      call eclim#util#EchoError(message)
      return
    endif
  else
    let projects = eclim#project#GetProjectNames()
  endif

  for project in projects
    call eclim#util#Echo("Updating project '" . project . "'...")
    let command = substitute(s:command_refresh, '<project>', project, '')
    call eclim#util#Echo(eclim#ExecuteEclim(command))
  endfor
  call eclim#util#Echo(' ')
endfunction " }}}

" ProjectOpen(name) {{{
" Open the requested project.
function! eclim#project#ProjectOpen (name)
  let command = substitute(s:command_open, '<project>', a:name, '')
  let result = eclim#ExecuteEclim(command)
  if result != '0'
    call eclim#util#Echo(result)
  endif
endfunction " }}}

" ProjectClose(name) {{{
" Close the requested project.
function! eclim#project#ProjectClose (name)
  let command = substitute(s:command_close, '<project>', a:name, '')
  let result = eclim#ExecuteEclim(command)
  if result != '0'
    call eclim#util#Echo(result)
  endif
endfunction " }}}

" ProjectList() {{{
" Lists all the projects currently available in eclim.
function! eclim#project#ProjectList ()
  let projects = split(eclim#ExecuteEclim(s:command_projects), '\n')
  if len(projects) == 0
    call eclim#util#Echo("No projects.")
  endif
  if len(projects) == 1 && projects[0] == '0'
    return
  endif
  exec "echohl " . g:EclimInfoHighlight
  redraw
  for project in projects
    echom project
  endfor
 echohl None
endfunction " }}}

" ProjectSettings(project) {{{
" Opens a window that can be used to edit a project's settings.
function! eclim#project#ProjectSettings (project)
  let project = a:project
  if project == ''
    let project = eclim#project#GetCurrentProjectName()
  endif
  if project == ''
    call eclim#util#EchoError("Unable to determine project. " .
      \ "Please specify a project name or " .
      \ "execute from a valid project directory.")
    return
  endif

  let command = substitute(s:command_project_info, '<project>', project, '')
  if eclim#util#TempWindowCommand(command, project . "_settings")
    exec "lcd " . eclim#project#GetProjectRoot(project)
    setlocal buftype=acwrite
    setlocal filetype=jproperties
    setlocal noreadonly
    setlocal modifiable
    setlocal foldmethod=marker
    setlocal foldmarker={,}

    let b:project = project
    augroup project_settings
      autocmd! BufWriteCmd <buffer>
      autocmd BufWriteCmd <buffer> call <SID>SaveSettings()
    augroup END
  endif
endfunction " }}}

" SaveSettings() {{{
function! s:SaveSettings ()
  " don't check modified since undo seems to not set the modified flag
  "if &modified
    let settings = getline(1, line('$'))
    let result = ""
    for setting in settings
      if setting !~ '^\s*\($\|#\)'
        if result != ""
          let result = result . "|"
        endif
        let result = result . setting
      endif
    endfor

    let command = s:command_update
    let command = substitute(command, '<project>', b:project, '')
    let command = substitute(command, '<settings>', result, '')

    let result = eclim#ExecuteEclim(command)
    if result =~ '|'
      call eclim#util#EchoError
        \ ("Operation contained errors.  See quickfix for details.")
      call eclim#util#SetLocationList
        \ (eclim#util#ParseLocationEntries(split(result, '\n')))
    else
      call eclim#util#SetLocationList([], 'r')
      call eclim#util#Echo(result)
    endif

    setlocal nomodified
  "endif
endfunction " }}}

" GetCurrentProjectFile() {{{
" Gets the path to the project file for the project that the current file is in.
function! eclim#project#GetCurrentProjectFile ()
  let dir = fnamemodify(expand('%:p'), ':h')
  let dir = escape(dir, ' ')

  let projectFile = findfile('.project', dir . ';')
  while 1
    if filereadable(projectFile)
      return fnamemodify(projectFile, ':p')
    endif
    if projectFile == '' && dir != getcwd()
      let dir = getcwd()
    else
      break
    endif
  endwhile
  return ''
endfunction " }}}

" GetCurrentProjectName() {{{
" Gets the project name that the current file is in.
function! eclim#project#GetCurrentProjectName ()
  let projectName = ''
  let dir = fnamemodify(expand('%:p'), ':h')
  let dir = escape(dir, ' ')

  let projectFile = eclim#project#GetCurrentProjectFile()
  if projectFile != ''
    let cmd = winrestcmd()

    silent exec 'sview ' . escape(projectFile, ' ')
    setlocal noswapfile
    setlocal bufhidden=delete

    let line = search('<name\s*>', 'wn')
    if line != 0
      let projectName = substitute(getline(line), '.\{-}>\(.*\)<.*', '\1', '')
    endif
    silent close

    silent exec cmd

    " can potentially screw up display, like when used durring startup
    " (project/tree.vim), it causes display for :Ant, :make commands to be all
    " screwed up.
    "redraw
  endif

  return projectName
endfunction " }}}

" GetCurrentProjectRoot() {{{
" Gets the project root dir for the project that the current file is in.
function! eclim#project#GetCurrentProjectRoot ()
  return fnamemodify(eclim#project#GetCurrentProjectFile(), ':h')
endfunction " }}}

" GetProjectDirs() {{{
" Gets list of all project root directories.
function! eclim#project#GetProjectDirs ()
  let projects = split(eclim#ExecuteEclim(s:command_projects), '\n')
  if len(projects) == 1 && projects[0] == '0'
    return []
  endif

  call map(projects,
    \ "substitute(v:val, '.\\{-}\\s\\+-\\s.\\{-}\\s\\+-\\s\\(.*\\)', '\\1', '')")

  return projects
endfunction " }}}

" GetProjectNames() {{{
" Gets list of all project names.
function! eclim#project#GetProjectNames ()
  let projects = split(eclim#ExecuteEclim(s:command_projects), '\n')
  if len(projects) == 1 && projects[0] == '0'
    return []
  endif

  call map(projects, "substitute(v:val, '\\(.\\{-}\\)\\s\\+-\\s\\+.*', '\\1', '')")

  return projects
endfunction " }}}

" GetProjectRoot(project) {{{
" Gets the project root dir for the supplied project name.
function! eclim#project#GetProjectRoot (project)
  let projects = split(eclim#ExecuteEclim(s:command_projects), '\n')
  for project in projects
    if project =~ '^' . a:project . ' '
      return substitute(project, '.\{-}\s\+-\s\+.\{-}\s\+-\s\+\(.*\)', '\1', '')
    endif
  endfor

  return ""
endfunction " }}}

" GetProjectSetting(setting) {{{
function! eclim#project#GetProjectSetting (setting)
  let project = eclim#project#GetCurrentProjectName()
  if project != ""
    let command = s:command_project_setting
    let command = substitute(command, '<project>', project, '')
    let command = substitute(command, '<setting>', a:setting, '')

    let result = split(eclim#ExecuteEclim(command), '\n')
    call filter(result, 'v:val !~ "^\\s*#"')

    if len(result) == 0
      call eclim#util#EchoWarning("Setting '" . a:setting . "' does not exist.")
      return ""
    endif

    return substitute(result[0], '.\{-}=\(.*\)', '\1', '')
  endif
  return ""
endfunction " }}}

" IsCurrentFileInProject(...) {{{
" Determines if the current file is in a project directory.
" Accepts an optional arg that determines if a message is displayed to the
" user if the file is not in a project (defaults to 1, to display the
" message).
function! eclim#project#IsCurrentFileInProject (...)
  if eclim#project#GetCurrentProjectName() == ''
    if a:0 == 0 || a:1
      call eclim#util#EchoError('Unable to determine project. ' .
        \ 'Check that the current file is in a valid project.')
    endif
    return 0
  endif
  return 1
endfunction " }}}

" CommandCompleteProject(argLead, cmdLine, cursorPos) {{{
" Custom command completion for project names.
function! eclim#project#CommandCompleteProject (argLead, cmdLine, cursorPos)
  let cmdTail = strpart(a:cmdLine, a:cursorPos)
  let argLead = substitute(a:argLead, cmdTail . '$', '', '')

  let projects = eclim#project#GetProjectNames()
  call filter(projects, 'v:val =~ "^' . argLead . '"')

  return projects
endfunction " }}}

" CommandCompleteProjectCreate(argLead, cmdLine, cursorPos) {{{
" Custom command completion for ProjectCreate
function! eclim#project#CommandCompleteProjectCreate (argLead, cmdLine, cursorPos)
  let cmdLine = strpart(a:cmdLine, 0, a:cursorPos)
  let args = eclim#util#ParseArgs(cmdLine)
  let argLead = len(args) > 1 ? args[len(args) - 1] : ""

  " complete dirs for first arg
  if cmdLine =~ '^ProjectCreate\s*' . escape(argLead, '~.\') . '$'
    return eclim#util#CommandCompleteDir(argLead, a:cmdLine, a:cursorPos)
  endif

  " for remaining args, complete project name.
  return eclim#project#CommandCompleteProject(argLead, a:cmdLine, a:cursorPos)
endfunction " }}}

" vim:ft=vim:fdm=marker
