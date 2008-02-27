au BufRead,BufNewFile *.cpy	set ft=plsql
au BufRead,BufNewFile *		if &ft == 'sql' | set ft=plsql | endif

