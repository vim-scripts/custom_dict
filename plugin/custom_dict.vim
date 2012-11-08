
if exists('loaded_custom_dict') "{{{
    finish
endif
let loaded_custom_dict = 1
if v:version < 702
    echoerr 'custom dict plugin requires vim7.2'
    finish
endif 
""ubuntu可以用这个
"let s:DISPLAYCHILDKIND = "\u2023" 
let s:DISPLAYCHILDKIND = ">"
let s:VIRTUALKIND='_'
if v:lang =~ '^zh_CN' && &enc == 'utf-8'
    let s:MESSAGE_NOFILE = "文件不存在"
    let s:MESSAGE_CANTREADFILE = "无法读取文件"
    let s:MESSAGE_WRONGLINE = "格式不对"
    let s:MESSAGE_DUP_WORD_IS_IGNORE = "重复的词条"
else
    let s:MESSAGE_NOFILE = "NO FILE"
    let s:MESSAGE_CANTREADFILE = "FILE READ ERROR"
    let s:MESSAGE_WRONGLINE = "WRONG LINE"
    let s:MESSAGE_DUP_WORD_IS_IGNORE = "DUP WORD"
endif "}}}
let s:DEBUG = 0
function! s:find_rtp_file(filename, ...) "{{{
    if s:DEBUG | echom 'infunc find_rtp_file' | endif
    let files = split(globpath(&runtimepath,'dicts/' . a:filename),'\n')
    if ! empty(files) 
        return files[0]
    elseif filereadable(a:filename)
        return a:filename
    elseif a:0 && a:1 == 1
        if a:0 == 2
            throw a:2
        else
            throw s:MESSAGE_NOFILE . ':' . a:filename
        endif
    else
        return ''
    endif
endfunc "}}}
function! s:find_dict_files(filetype) "{{{
    if s:DEBUG | echom 'infunc find_dict_files' | endif
    let files = split(globpath(&runtimepath,'dicts/*.dict'),'\n')
    let r = []
    for filename in files
        if fnamemodify(filename,':t:r') =~? '\(^\|\.\)'.a:filetype.'\A' 
            call add(r,filename)
        endif
    endfor
    return r
endfunc "}}}
function! s:trim(str) "{{{
    return substitute(substitute(a:str,'^[ \t\n\r]*','',''),'[ \t\n\r]*$','','')
endfunc "}}}
function! s:parse_line(line, wordline) "{{{
    let s = matchstr(a:line, '^\(' . escape(a:wordline, '*') . '\)*')
    let level = strlen(s) / strlen(a:wordline)
    if level == 0 | return {'level':0} | endif
    let word = matchstr(strpart(a:line,strlen(s)),'^\S*')
    let other = s:trim(strpart(a:line,strlen(s)+strlen(word)))
    " kind只有一个字符，如果在word后发现有一个字符，则这个字符是kind
    if strlen(other) > 1 
        if other[1] == ' ' || other[1] == "\t"
            let kind = other[0]
            let menu = s:trim(strpart(other,1))
        else
            let kind = ''
            let menu = other
        endif
    else
        let kind = other
        let menu = ''
    endif
    return {'level':level,'word':word,'kind':kind,'menu':menu}
endfunc "}}}
" config {{{
let s:config_obj = {'filetype':'',
            \'dictfiles':[], 
            \'modeline':'', 
            \'usemenu':0, 
            \'complete_method':'completefunc',
            \'complete_kind_key':'<C-F>',
            \'complete_up_key':'<C-H>',
            \'complete_down_key':'<C-L>',
            \'complete_first_key':'<C-T>',
            \'WORDLINE':'+-*/', 
            \'COMMENTLINE':'/*-+', 
            \'DISPLAYSPLITSEP':'.'} 
function! s:config_obj.read_dict(lines,dictobj) dict "{{{
    if s:DEBUG | echom 'infunc config_obj.read_dict' | endif
    let number = 0
    let lastword = {}
    let infos = []
    let father = a:dictobj.treeitems
    let stacks = []
    call add(a:lines,self.WORDLINE . 'end')
    for line in a:lines
        let number += 1
        if stridx(line,self.COMMENTLINE) == 0 | continue | endif
        let obj = s:parse_line(line,self.WORDLINE)
        if obj.level == 0
            call add(infos,line)
            continue
        endif
        if obj.word == ''
            throw s:MESSAGE_WRONGLINE . ':lineno:' . number
        endif
        if !empty(lastword)
            " info
            if self.modeline != '' | call add(infos,self.modeline) | endif
            if !self.usemenu && lastword.menu != ''
                call insert(infos,lastword.menu)
            endif
            let lastword.info = join(infos,"\n")
            let infos = []
            if lastword.level != len(stacks) + 1
                call remove(stacks, lastword.level-1, -1)
                let father = a:dictobj.treeitems
                for name in stacks
                    let father = father.childs[name]
                endfor
            endif
            let i =  lastword.level - obj.level
            if i == -1
                " not isleaf "{{{
                if has_key(father.childs, lastword.word) 
                    let item = father.childs[lastword.word]
                    if item.menu == '' && lastword.menu != ''
                        let item.menu = lastword.menu
                    endif
                    if strlen(item.info) <  strlen(lastword.info)
                        let item.info = lastword.info
                    endif
                else
                    let item = {'word':lastword.word,'kind':s:DISPLAYCHILDKIND,'menu':lastword.menu,'items':[],'childs':{},'dup':1,'info':lastword.info}
                    let father.childs[lastword.word] = item
                    call add(father.items,item)
                endif
                let father = item
                call add(stacks,father.word) "}}}
            elseif i >= 0
                " leaf "{{{
                "check dup word
                for item in father.items
                    if item.word ==# lastword.word && item.kind ==# lastword.kind
                        echoerr s:MESSAGE_DUP_WORD_IS_IGNORE . ':' item.word . '---' . item.kind
                        let lastword = obj
                        continue
                    endif
                endfor
                let item = {'word':lastword.word,'kind':lastword.kind,'menu':lastword.menu,'dup':1,'info':lastword.info}
                call add(father.items,item) "}}}
            else
                throw s:MESSAGE_WRONGLINE . ':' . repeat(self.WORDLINE,lastword.level) . lastword.word
            endif
            if lastword.kind != s:VIRTUALKIND
                call add(a:dictobj.allitems,
                        \{'word':item.word,'kind':lastword.kind,
                        \'menu':self.usemenu || empty(stacks) ? item.menu : 
                                \join(stacks,self.DISPLAYSPLITSEP),
                        \'info':item.info,'dup':1})
            endif
        endif
        let lastword = obj
    endfor
endfunc "}}}
function! s:config_init() "{{{
    if s:DEBUG | echom 'infunc config_init' | endif
" return config_obj
    if &l:filetype == '' | return {} | endif
    let configfile = s:find_rtp_file(&l:filetype . '.vim')
    if configfile != '' | execute 'source ' . fnameescape(configfile) | endif
    if exists('g:custom_'.&l:filetype.'_dict_disable') | return {} | endif
    let config = deepcopy(s:config_obj)
    if !exists('g:custom_dict_pumheight')
        let g:custom_dict_pumheight = 15
    endif
    if exists('g:custom_'.&l:filetype.'_dict_files')
        for filename in g:custom_{&l:filetype}_dict_files
            call add(config.dictfiles,s:find_rtp_file(filename,1))
        endfor
    endif
    if exists('g:custom_'.&l:filetype.'_dict_modeline')
        let config.modeline = g:custom_{&l:filetype}_dict_modeline
    endif
    if exists('g:custom_'.&l:filetype.'_dict_usemenu')
        let config.usemenu = g:custom_{&l:filetype}_dict_usemenu == 1 ? 1 : 0
    endif
    if exists('g:custom_'.&l:filetype.'_dict_complete_method')
        let config.complete_method = g:custom_{&l:filetype}_dict_complete_method == 'free' ? 'free' : 'completefunc'
    endif
    if exists('g:custom_'.&l:filetype.'_dict_complete_kind_key')
        let config.complete_kind_key = g:custom_{&l:filetype}_dict_complete_kind_key
    endif
    if exists('g:custom_'.&l:filetype.'_dict_complete_up_key')
        let config.complete_up_key = g:custom_{&l:filetype}_dict_complete_up_key
    endif
    if exists('g:custom_'.&l:filetype.'_dict_complete_down_key')
        let config.complete_down_key = g:custom_{&l:filetype}_dict_complete_down_key
    endif
    if config.complete_method == 'free'
        if exists('g:custom_'.&l:filetype.'_dict_complete_first_key')
            let config.complete_first_key = g:custom_{&l:filetype}_dict_complete_first_key
        endif
    endif
    if empty(config.dictfiles) 
        let config.dictfiles = s:find_dict_files(&l:filetype)
        if empty(config.dictfiles) 
            return {}
        endif
    endif
    let config.filetype = &l:filetype
    return config
endfunc "}}} 
"}}}
" runtime {{{
let s:dict_obj = {'filetype':'',
            \'allitems':[], 
            \'treeitems':{'items':[],'childs':{}}, 
            \'kinds':[], 
            \'linenr':0, 
            \'pos':0, 
            \'linestr':'', 
            \'word':'', 
            \'treestack':[], 
            \'lastkind':0, 
            \'status':'first'}
function! s:sort_tree(x,y) "{{{
    if a:x.kind == s:DISPLAYCHILDKIND && a:y.kind != s:DISPLAYCHILDKIND
        return -1
    elseif a:x.kind != s:DISPLAYCHILDKIND && a:y.kind == s:DISPLAYCHILDKIND
        return 1
    endif
    let w1 = tr(a:x.word, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz')
    let w2 = tr(a:y.word, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz')
    return w1 ==# w2 ? 0 : w1 ># w2 ? 1 : -1
endfunc "}}}
function! s:sort_allitem(x,y) "{{{
    if a:x.sortlevel > a:y.sortlevel
        return 1
    elseif  a:x.sortlevel < a:y.sortlevel
        return -1
    endif
    return a:x.word ==# a:y.word ? 0 : a:x.word ># a:y.word ? 1 : -1
endfunc "}}}
function! s:dict_obj.treesort(treeitems) dict "{{{
    for x in items(a:treeitems.childs)
        let a:treeitems.childs[x[0]] = self.treesort(x[1])
    endfor
    let a:treeitems.items = sort(a:treeitems.items,function('s:sort_tree'))
    return a:treeitems
endfunc "}}}
function! s:dict_obj.sort() dict "{{{
    if s:DEBUG | echom 'infunc dict_obj.sort' | endif
    for item in self.allitems
        if item.word =~ '^\A'
            let item.sortlevel = 20
        elseif item.word =~# '^[A-Z0-9_]\+$'
            let item.sortlevel = 15
        elseif item.word =~# '^[a-z0-9_]\+$'
            let item.sortlevel = 0
        elseif item.word =~# '^\l'
            let item.sortlevel = 5
        else
            let item.sortlevel = 10
        endif
    endfor
    let self.allitems = sort(self.allitems,function('s:sort_allitem'))
endfunc "}}}
function! s:dict_obj.process() dict "{{{
    if s:DEBUG | echom 'infunc dict_obj.process' | endif
    let kinds = {}
    let emptykind = 0
    for item in self.allitems
        if item.kind == ''
            let emptykind = 1
        else
            let kinds[item.kind] = 1
        endif
    endfor
    let self.kinds = keys(kinds)
    if emptykind | call add(self.kinds,'') | endif
    if s:DEBUG | echom 'infunc dict_obj.treesort' | endif
    let self.treeitems = self.treesort(self.treeitems)
    call self.sort()
endfunc "}}}
function! s:dict_obj.get_by_kind(...) dict "{{{
    if s:DEBUG | echom 'infunc dict_obj.get_by_kind' | endif
    if a:0 
        if a:1 <= 0 || a:1 > len(self.kinds)
            let self.lastkind = 0
        else
            let self.lastkind = a:1
        endif
    else
        let self.lastkind += 1
        if self.lastkind > len(self.kinds) | let self.lastkind = 0 | endif
    endif
    let self.treestack = []
    if self.lastkind == 0 && self.word == '' | return self.allitems | endif
    if self.lastkind | let kind = self.kinds[self.lastkind-1] | endif
    let items = []
    let items_startswith = []
    let items_instr = []
    let items_startswith_ignorecase = []
    let items_instr_ignorecase = []
    for item in self.allitems
        if self.lastkind && item.kind !=# kind 
            continue
        endif
        if self.word == '' 
            call add(items,item)
            continue
        endif
        let i = stridx(item.word,self.word)
        if i == 0 
            call add(items_startswith,item)
        elseif i > 0 
            call add(items_instr,item)
        else
            let i = stridx(tolower(item.word),tolower(self.word))
            if i == 0
                call add(items_startswith_ignorecase,item)
            elseif i > 0
                call add(items_instr_ignorecase,item)
            else
                call add(items,item)
            endif
        endif
    endfor
    return items_startswith + items_startswith_ignorecase + items_instr + items_instr_ignorecase + items
endfunc "}}}
function! s:dict_obj.get_by_tree(...) dict "{{{
    if s:DEBUG | echom 'infunc dict_obj.get_by_tree' | endif
    let self.lastkind = -1
    if a:0 && !empty(self.treestack)
        if has_key(self.treestack[-1].childs,a:1)
            let item = self.treestack[-1].childs[a:1]
            call add(self.treestack,item)
            return item.items
        else
            return self.treestack[-1].items
        endif
    else
        call add(self.treestack,self.treeitems)
        return self.treeitems.items
    endif
endfunc "}}}
function! s:dict_obj.get_up_tree() dict "{{{
    if s:DEBUG | echom 'infunc dict_obj.get_up_tree' | endif
    let self.lastkind = -1
    if len(self.treestack) > 1
        call remove(self.treestack, -1)
        return self.treestack[-1].items
    else
        let self.treestack = [self.treeitems]
        return self.treeitems.items
    endif
endfunc "}}}
function! s:dict_obj.get_pos() dict  "{{{
    if s:DEBUG | echom 'infunc dict_obj.get_pos' | endif
    let pos = col('.')
    let line = getline('.')
    while pos > 1 && line[pos-2] =~ '\k'
        let pos -= 1
    endwhile
    let self.linenr = line('.')
    let self.pos = pos
    let self.linestr = pos > 1 ? line[:pos-2] : ''
    let self.lastkind = -1
    let self.treestack = []
    return pos
endfunc "}}}
function! s:dict_obj.check_pos() dict "{{{
    if pumvisible() && self.linenr == line('.') && self.pos <= col('.') &&
            \ (self.pos > 1 ? getline('.')[:self.pos-2] : '') ==# self.linestr
        return 1
    else
        if s:DEBUG 
            echom 'pos:' . string(self.pos)
            echom 'linenr:' . string(self.linenr)
            echom 'linestr:' . string(self.linestr)
            echom 'word:' . string(self.word)
        endif
        return 0
    endif
endfunc "}}}
function! s:dict_obj.get_base() dict "{{{
    if col('.') > self.pos
        return getline('.')[self.pos-1:col('.')-2]
    else
        return ''
    endif
endfunc "}}}
function! s:dict_obj.complete_first() dict "{{{
    let pos = self.get_pos()
    let self.word = self.get_base()
    let self.treestack = []
    call complete(pos,self.get_by_kind(0))
    return ''
endfunc "}}}
function! s:dict_obj.complete_kind() dict "{{{
    if self.check_pos()
        if self.complete_method == 'free'
            call complete(self.pos,self.get_by_kind())
        else
            call feedkeys("\<C-X>\<C-U>",'n')
            let self.status = 'kind'
        endif
    endif
    return ''
endfunc "}}}
function! s:dict_obj.complete_up() dict "{{{
    if self.check_pos()
        if self.complete_method == 'free'
            call complete(self.pos,self.get_up_tree())
        else
            call feedkeys("\<C-X>\<C-U>",'n')
            let self.status = 'up'
        endif
    endif
    return ''
endfunc "}}}
function! s:dict_obj.complete_down() dict "{{{
    if self.check_pos() 
        if self.complete_method == 'free'
            call complete(self.pos,self.get_by_tree(self.get_base()))
        else
            call feedkeys("\<C-Y>\<C-X>\<C-U>",'n')
            let self.status = 'down'
        endif
    endif
    return ''
endfunc "}}}
function! s:dict_init(config) "{{{
    if s:DEBUG | echom 'infunc dict_init' | endif
    let obj = deepcopy(s:dict_obj)
    for filename in a:config.dictfiles
        if filereadable(filename)
            let lines = readfile(filename)
            call map(lines,"iconv(v:val,'utf-8',&enc)")
            try 
                call a:config.read_dict(lines,obj)
            catch /.*/
                throw filename . ':' . v:exception
            endtry
        else
            throw s:MESSAGE_CANTREADFILE . ':' . filename
        endif
    endfor
    if empty(obj.allitems) | return {} | endif
    let obj.filetype = a:config.filetype
    let obj.complete_method = a:config.complete_method
    let obj.complete_kind_key = a:config.complete_kind_key
    let obj.complete_up_key = a:config.complete_up_key
    let obj.complete_down_key = a:config.complete_down_key
    let obj.complete_first_key = a:config.complete_first_key
    call obj.process()
    return obj
endfunc "}}}
function! g:custom_dict_complete_func(findstart,base) "{{{
    if a:findstart
        if b:custom_dict.status == 'first'
            call b:custom_dict.get_pos()
            let b:custom_dict.treestack = []
        endif
        return b:custom_dict.pos-1
    else
        if b:custom_dict.status == 'first' 
            let b:custom_dict.word = a:base
            let items = b:custom_dict.get_by_kind(0)
        elseif b:custom_dict.status == 'kind'
            let items = b:custom_dict.get_by_kind()
        elseif b:custom_dict.status == 'up'
            let items = b:custom_dict.get_up_tree()
        elseif b:custom_dict.status == 'down'
            let items = b:custom_dict.get_by_tree(a:base)
        endif
        let b:custom_dict.status = 'first'
        return items
    endif
endfunc "}}}
 "}}}
function! s:setup_buff() "{{{
    if s:DEBUG | echom 'infunc setup_buff' | endif
    if exists('b:loaded_custom_dict') && b:loaded_custom_dict == &l:filetype
        return
    endif
    let b:loaded_custom_dict = &l:filetype
    if &l:filetype == '' || &l:filetype == 'help'|| &l:filetype == 'dict'
        return
    endif
    if exists('b:custom_dict') && b:custom_dict.filetype == &l:filetype
        return
    endif
    if exists('g:custom_' . &l:filetype . '_dict')
        let b:custom_dict = g:custom_{&l:filetype}_dict
    else
        let config = s:config_init()
        if config == {} | return | endif
 "        profile start /tmp/test.log
 "        profile func *
        let dict = s:dict_init(config)
 "        profile pause
        if dict == {} | return | endif
        let g:custom_{&l:filetype}_dict = dict
        let b:custom_dict = g:custom_{&l:filetype}_dict
        if !s:DEBUG | echo ' ' | endif
    endif
    if ! exists('b:custom_dict_maped')
        let &pumheight=g:custom_dict_pumheight
        set completeopt=menuone,longest,preview
        if b:custom_dict.complete_method == 'free'
            call s:setup_map_free()
        else
            call s:setup_map_completefunc()
        endif
        let b:custom_dict_maped = 1
    endif
    if s:DEBUG  
        set verbose=14 
    endif
endfunc "}}}
function! s:setup_map_free() "{{{
    if s:DEBUG | echom 'infunc setup_map_free' | endif
    execute 'inoremap <buffer> <unique> <silent> ' . b:custom_dict.complete_first_key . ' <C-R>=b:custom_dict.complete_first()<CR>'
    execute 'inoremap <buffer> <unique> <silent> ' . b:custom_dict.complete_kind_key . ' <C-R>=b:custom_dict.complete_kind()<CR>'
    execute 'inoremap <buffer> <unique> <silent> ' . b:custom_dict.complete_up_key . ' <C-R>=b:custom_dict.complete_up()<CR>'
    execute 'inoremap <buffer> <unique> <silent> ' . b:custom_dict.complete_down_key . ' <C-R>=b:custom_dict.complete_down()<CR>'
 "    inoremap <expr> <C-J>	   pumvisible()?"\<PageDown>":"\<C-X><C-O>"
 "    inoremap <expr> <C-K>	   pumvisible()?"\<PageUp>":"\<C-X><C-K>"
endfunc "}}}
function! s:setup_map_completefunc() "{{{
    if s:DEBUG | echom 'infunc setup_map_completefunc' | endif
    execute 'inoremap <buffer> <unique> <silent>' . b:custom_dict.complete_kind_key . ' <C-R>=b:custom_dict.complete_kind()<CR>'
    execute 'inoremap <buffer> <unique> <silent>' . b:custom_dict.complete_up_key . ' <C-R>=b:custom_dict.complete_up()<CR>'
    execute 'inoremap <buffer> <unique> <silent>' . b:custom_dict.complete_down_key . ' <C-R>=b:custom_dict.complete_down()<CR>'
"    inoremap <expr> <C-J>	   pumvisible()?"\<PageDown>":"\<C-X><C-O>"
"    inoremap <expr> <C-K>	   pumvisible()?"\<PageUp>":"\<C-X><C-K>"
    setlocal completefunc=g:custom_dict_complete_func
endfunc "}}}

augroup filetypedetect
    au! BufNewFile,BufRead *.dict setfiletype dict
augroup END
autocmd! FileType * call s:setup_buff()

