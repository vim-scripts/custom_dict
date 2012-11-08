if exists("b:dictdid_ftplugin")
	finish
endif
let b:dictdid_ftplugin = 1

function! g:Dict_fold_method() "{{{
    if getline(v:lnum)[:3] == '+-*/'
        return '>' . strlen(matchstr(getline(v:lnum),'^\(+-\*\/\)*'))/4
    else
        if v:lnum > 1
            if getline(v:lnum-1)[:3] == '+-*/'
                return strlen(matchstr(getline(v:lnum-1),'^\(+-\*\/\)*'))/4 
 "            elseif getline(v:lnum+1)[:3] == '+-*/'
 "                return strlen(matchstr(getline(v:lnum+1),'^\(+-\*\/\)*'))/4 
            else
                return '='
            endif
        else
            return 0
        endif
    endif
endfunc "}}}
function! g:Dict_fold_text() "{{{
    let width = winwidth(0) - 6 - &l:foldcolumn - (&l:number ? &l:numberwidth : 0) - 2
    if width < 20 | return foldtext() | endif
    let lines = substitute(printf('%6d',v:foldend - v:foldstart + 1),' ','-','g')
    let line = getline(v:foldstart)
    let swidth = strdisplaywidth(line)
    if swidth < width
        let line = line . repeat('-',width-swidth)
    else
        let line = printf('%.'.(width-4).'s',line)
        let swidth = strdisplaywidth(line)
        if swidth < width
            let line = line . repeat('.',width-swidth-1) . '>'
        else
            " TODO ?
            return foldtext()
        endif
    endif
    return line . lines
endfunc "}}}
function! s:uplevel(...) "{{{
    if a:0 
        let firstline = a:1
        while firstline <= a:2
            if getline(firstline)[:3] == '+-*/'
                call setline(firstline,'+-*/'.getline(firstline))
            endif
            let firstline += 1
        endwhile
    else
        call setline(line('.'),'+-*/'.getline(line('.')))
    endif
endfunc "}}}
function! s:uplevel_v() range "{{{
    call s:uplevel(a:firstline,a:lastline)
endfunc "}}}
function! s:downlevel(...) "{{{
    if a:0 
        let firstline = a:1
        while firstline <= a:2
            if getline(firstline)[:3] == '+-*/'
                call setline(firstline,getline(firstline)[4:])
            endif
            let firstline += 1
        endwhile
    else
        if getline(line('.'))[:3] == '+-*/'
            call setline(line('.'),getline(line('.'))[4:])
        endif
    endif
endfunc "}}}
function! s:downlevel_v() range "{{{
    call s:downlevel(a:firstline,a:lastline)
endfunc "}}}
nnoremap <buffer> <silent> + :call <SID>uplevel()<CR>
vnoremap <buffer> <silent> + :call <SID>uplevel_v()<CR>
nnoremap <buffer> <silent> - :call <SID>downlevel()<CR>
vnoremap <buffer> <silent> - :call <SID>downlevel_v()<CR>
setlocal foldexpr=g:Dict_fold_method()
setlocal foldmethod=expr
setlocal foldtext=g:Dict_fold_text()
 "let &l:commentstring='/*-+'

