setlocal ts=2 sw=2

" Use the open source tool to veryify XML/XSL
compiler xmllint

" Use the open source tool to reformat the document
" Double quote the filename if on windows
if has('win32')
	vnoremap <buffer> <Leader>xf :!xmllint --format "-"<CR>
	nnoremap <buffer> <Leader>xf :1,$!xmllint --format "-"<CR>
else
	vnoremap <buffer> <Leader>xf :!xmllint --format -<CR>
	nnoremap <buffer> <Leader>xf :1,$!xmllint --format -<CR>
endif
