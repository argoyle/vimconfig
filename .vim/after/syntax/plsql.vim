setlocal ts=3 sw=3 ai et
setlocal iskeyword+=$
setlocal iskeyword+=_

setlocal formatoptions+=crowan
setlocal comments=sr:/*,mb:*,ex:*/,b:--,:--
setlocal ignorecase

abbr anon DECLARE<CR>BEGIN<CR>END;<CR>/<UP><UP><UP><END>

let b:match_words = '\<IF\>:\<ELSIF\>:\<END IF\>,\<LOOP\>:\<END LOOP\>,\<DECLARE\>:\<BEGIN\>:\<EXCEPTION\>:\<END\(\sIF\|\sLOOP\)\@!\>;'
let b:match_ignorecase = 1

