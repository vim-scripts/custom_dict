
if exists('loaded_custom_dict_plugin')
    finish
endif
let loaded_custom_dict_plugin = 1
if v:version < 702
    echoerr 'custom dict plugin requires vim7.2'
    finish
endif
if !has('python')
    echoerr 'custom dict plugin requires python'
    finish
endif

python <<EOF

def custom_dict_init():
    import re
    import vim
    NOUSEKIND = '_'
    TREEKIND = '>'
    try:
        if "1" == vim.eval('strdisplaywidth("\\u2023")'): TREEKIND = '''\u2023'''
    except:
        pass

    line_re = re.compile(r'''
        ^(?P<level>(?:\+-\*/)+)
        (?P<name>\S+)
        (?:\s*$
            |\s+(?P<kind1>.)\s*$
            |\s+(?P<kind>.)\s+(?P<short>\S.*)$
            |\s+(?P<short1>\S\S.*)$
        )''', re.VERBOSE)

    def tostring(result, func):
        return ','.join((func(x) for x in result))

    class Node(object):
        def __init__(self, word, kind, menu=u'', level=0, info=u''):
            self.level = level
            self.word = word
            self.kind = kind
            self.menu = menu
            self.info = info
            self.childs = []
            self.father = None
            self._s1 = ''
            self._s2 = ''

        def _kind(self):
            if self.kind == '\\':
                return '\\\\'
            if self.kind == '"':
                return '\\"'
            return self.kind

        def _tran(self, s):
            return s.decode('utf-8').encode('unicode_escape').replace('"', '\\"')

        def totreestring(self):
            if not self._s1:
                self._s1 = '{"word":"%s","kind":"%s","menu":"%s","info":"%s","dup":1}' % ( 
                        self._tran(self.word), TREEKIND if self.childs else self._kind(), 
                        self._tran(self.menu), self._tran(self.info))
            return self._s1

        def add(self, child, connect=False):
            self.childs.append(child)
            if connect:
                child.father = self

        def tostring(self):
            if not self._s2:
                x = self.father
                s = []
                while x:
                    if x.kind not in ('', NOUSEKIND):
                        s.insert(0, x.word)
                    x = x.father
                s = '.'.join(s)
                self._s2 = '{"word":"%s","kind":"%s","menu":"%s","info":"%s","dup":1}' % ( 
                        self._tran(self.word), self._kind(), 
                        self._tran(s) if s else self._tran(self.menu), 
                        self._tran(self.menu + '\n' + self.info) if s and self.menu else self._tran(self.info))
            return self._s2

        def search(self, func, getchilds=True):
            r = Node.ROOT()
            for x in self.childs:
                l = func(x)
                if l and not x.childs:
                    r.add(x)
                elif l and getchilds:
                    r.add(x)
                elif l:
                    c = Node(x.word, x.kind, x.menu, info=x.info)
                    c.father = x.father
                    c.childs = x.search(func, False).childs
                    r.add(c)
                elif x.childs and not l:
                    r.childs.extend(x.search(func, getchilds).childs)
            return r

        def filter(self, func):
            for x in self.childs:
                if func(x):
                    yield x
                if x.childs:
                    for y in x.filter(func):
                        yield y

        @staticmethod
        def ROOT():
            return Node('', '', '')

    class Complete(object):
        buffers = {}

        @staticmethod
        def getlocal(filetype=''):
            if "0" == vim.eval("exists('b:custom_dict')"):
                return False
            bfname = vim.eval('b:custom_dict')
            a = Complete.buffers[bfname]
            if filetype and a.dict.filetype != filetype:
                return False
            return a

        @staticmethod
        def setlocal(filetype):
            from uuid import uuid4
            bfname = str(uuid4())
            d = Custom_dict.get(filetype)
            Complete.buffers[bfname] = Complete(d)
            vim.command("let b:custom_dict='%s'" % bfname)
            if hasattr(d,'setup'): d.setup(Complete.buffers[bfname])
            if d.complete_method == 'free':
                vim.command(
                    "inoremap <buffer> <silent> %s <C-R>=g:Custom_dict_complete_first()<CR>" % d.keys['first'])
            else:
                vim.command(
                    "setlocal completefunc=g:Custom_dict_complete_func")
                vim.command("let b:custom_dict_status='first'")
            vim.command(
                "inoremap <buffer> <silent> %s <C-R>=g:Custom_dict_complete_kind()<CR>" % d.keys['kind'])
            vim.command(
                "inoremap <buffer> <silent> %s <C-R>=g:Custom_dict_complete_up()<CR>" % d.keys['up'])
            vim.command(
                "inoremap <buffer> <silent> %s <C-R>=g:Custom_dict_complete_down()<CR>" % d.keys['down'])

        def __init__(self, dictobj):
            self.dict = dictobj
            self.pos = -1
            self.line = ''
            self.lineno = -1
            self.result = []
            self.level = []
            self.kindno = -1

        def getbykind(self):
            self.level = []
            self.kindno += 1
            if self.kindno >= len(self.kinds):
                self.kindno = -1
                return tostring(self.result, Node.tostring)
            result = filter(lambda x: x.kind == self.kinds[self.kindno], self.result)
            if len(result)==1: result.append(Node('_______','_'))
            return tostring(result, Node.tostring)

        def getup(self):
            self.kindno = len(self.kinds)
            if self.level:
                self.level.pop()
            cur = self.dict.nodetree if not self.level else self.level[-1]
            return tostring(cur.childs, Node.totreestring)

        def getdown(self, base):
            self.kindno = len(self.kinds)
            cur = self.dict.nodetree if not self.level else self.level[-1]
            for x in cur.childs:
                if x.word == base and x.childs:
                    self.level.append(x)
                    return tostring(x.childs, Node.totreestring)
            else:
                return tostring(cur.childs, Node.totreestring)

        def complete(self):
            self.level = []
            self.pos, self.result = self.dict.completefunc(self.dict)
            kinds = set([x.kind for x in self.result])
            if NOUSEKIND in kinds:
                kinds.remove(NOUSEKIND)
            self.kinds = list(kinds)
            self.kindno = len(self.kinds)
            self.line = Custom_dict.getline(self.pos)
            self.lineno = int(vim.eval("line('.')"))

        def customcomplete(self):
            status = vim.eval('b:custom_dict_status')
            if status == 'first':
                base = Custom_dict.vimdecode(vim.eval("a:base"))
                self.result.sort(key=self.dict.sortfunc(base))
                vim.command("let item=[%s]" % self.getbykind())
            elif status == 'kind':
                vim.command("let item=[%s]" % self.getbykind())
            elif status == 'up':
                vim.command("let item=[%s]" % self.getup())
            elif status == 'down':
                base = Custom_dict.vimdecode(vim.eval("a:base"))
                vim.command("let item=[%s]" % self.getdown(base))
            vim.command("let b:custom_dict_status='first'")

        def customcompletepos(self):
            if vim.eval('b:custom_dict_status') == 'first':
                self.complete()
            vim.command("let pos=%d" % (self.pos-1))

        def completefirst(self):
            self.complete()
            base = '' if "1" == vim.eval("col('.')<=%d" % self.pos) else Custom_dict.vimdecode(
                vim.eval("getline('.')[%d-1:col('.')-2]" % self.pos))
            self.result.sort(key=self.dict.sortfunc(base))
            vim.command("call complete(%d,[%s])" % (
                self.pos, self.getbykind()))

        def completekind(self):
            if self.check():
                if self.dict.complete_method == 'free':
                    vim.command("call complete(%d,[%s])" % (
                        self.pos, self.getbykind()))
                else:
                    vim.command('''call feedkeys("\<C-X>\<C-U>",'n')''')
                    vim.command("let b:custom_dict_status = 'kind'")

        def completeup(self):
            if self.check():
                if self.dict.complete_method == 'free':
                    vim.command("call complete(%d,[%s])" % (
                        self.pos, self.getup()))
                else:
                    vim.command('''call feedkeys("\<C-X>\<C-U>",'n')''')
                    vim.command("let b:custom_dict_status = 'up'")

        def completedown(self):
            if self.check():
                if self.dict.complete_method == 'free':
                    base = '' if "1" == vim.eval("col('.')<=%d" % self.pos) else Custom_dict.vimdecode(
                        vim.eval("getline('.')[%d-1:col('.')-2]" % self.pos))
                    vim.command("call complete(%d,[%s])" % (
                        self.pos, self.getdown(base)))
                else:
                    vim.command('''call feedkeys("\<C-Y>\<C-X>\<C-U>",'n')''')
                    vim.command("let b:custom_dict_status = 'down'")

        def check(self):
            line = Custom_dict.getline(self.pos)
            lineno = int(vim.eval("line('.')"))
            pos = int(vim.eval("col('.')"))
            b = "1" == vim.eval(
                "pumvisible()") and lineno == self.lineno and self.pos <= pos and self.line == line
            print self.line
            return b

    class Custom_Error(Exception):
        pass

    class Custom_dict(object):
        filetypes = {}

        @staticmethod
        def get(filetype):
            if filetype in Custom_dict.filetypes:
                return Custom_dict.filetypes[filetype]
            files = vim.eval(
                "globpath(&runtimepath,'dicts/' . '%s.*')" % filetype)
            if files:
                files = files.split('\n')
            else:
                files = []
            dicts = filter(lambda x: x.endswith('.dict'), files)
            py = filter(lambda x: x.endswith('/%s.py' % filetype), files)
            if py:
                from imp import load_source
                from os.path import exists, isfile

                def updatedicts(dicts, configdicts):
                    for x in configdicts:
                        for y in dicts:
                            if y.endswith('/'+x):
                                yield y
                                break
                        else:
                            if exists(x) and isfile(x):
                                yield x
                config = load_source('dictconfig', py[0])
                if hasattr(config, 'dicts'):
                    try:
                        dicts = list(updatedicts(dicts, config.dicts))
                    except:
                        raise Custom_Error('wrong config: dicts')

            if not dicts:
                return False
            cu_dict = Custom_dict(filetype)
            for x in dicts:
                cu_dict.addfile(x)
            cu_dict.checkdup()
            if py:
                if hasattr(config, 'complete'):
                    if type(config.complete) == type(updatedicts) and config.complete.func_code.co_argcount == 1:
                        cu_dict.completefunc = config.complete
                    else:
                        raise Custom_Error('wrong config: complete')
                if hasattr(config, 'sortresult'):
                    if type(config.sortresult) == type(updatedicts) and config.sortresult.func_code.co_argcount == 1:
                        cu_dict.sortfunc = config.sortresult
                    else:
                        raise Custom_Error('wrong config: sortresult')
                if hasattr(config, 'complete_method'):
                    if config.complete_method in ('free', 'default'):
                        cu_dict.complete_method = config.complete_method
                    else:
                        raise Custom_Error('wrong config: complete_method')
                if hasattr(config, 'map_keys'):
                    cu_dict.keys.update(config.map_keys)
                if hasattr(config, 'setup'):
                    if type(config.setup) == type(updatedicts) and config.setup.func_code.co_argcount == 1:
                        cu_dict.setup = config.setup
                    else:
                        raise Custom_Error('wrong config: setup')
            Custom_dict.filetypes[filetype] = cu_dict
            return cu_dict

        def __init__(self, filetype):
            self.filetype = filetype
            self.complete_method = 'default'
            self.keys = {
                'kind': '<C-F>', 'up': '<C-H>', 'down': '<C-L>', 'first': '<C-T>'}
            self.completefunc = Custom_dict.sample_complete
            self.sortfunc = Custom_dict.sample_sort
            self.nodetree = Node.ROOT()

        @staticmethod
        def vimdecode(s):
            return s.decode(vim.eval("&enc")).encode('utf-8')

        def _check_line(self, line):
            x = line_re.match(line.rstrip())
            if x:
                x = x.groupdict()
                a = Node(x['name'],
                         x['kind1'] or x['kind'] or '',
                         x['short1'] or x['short'] or '',
                         level=len(x['level'])/4)
                return a
            elif line.startswith('+-*/'):
                raise Custom_Error('wrong file: error line :'+line)
            return False

        def _readfile(self, filename):
            last = None
            for x in open(filename, 'r'):
                if x.startswith('/*-+'):
                    continue
                a = self._check_line(x)
                if a:
                    if last:
                        last.info = last.info
                        yield last
                    last = a
                else:
                    if last:
                        last.info += x
                    elif x.strip():
                        raise Custom_Error('wrong file: error line :'+x)
            last.info = last.info
            yield last

        def addfile(self, filename):
            stack = [self.nodetree]
            for x in self._readfile(filename):
                l = x.level-stack[-1].level
                if l <= 1:
                    stack[l-2].add(x, True)
                    stack = stack[:len(stack)+l-1]+[x]
                else:
                    raise Custom_Error('wrong file: error level :'+filename)

        def checkdup(self):
            def checktree(root):
                a = set()
                for x in root.childs:
                    if x.childs:
                        if x.word in a:
                            raise Custom_Error('dup word:'+x.word)
                        a.add(x.word)
                        checktree(x)
                root.childs.sort(key=self.tree_sort())
                if len(root.childs) == 1: root.add(Node('______','_'))
            checktree(self.nodetree)

        @staticmethod
        def getpos():
            p = int(vim.eval("col('.')"))
            while p > 1 and "1" == vim.eval("getline('.')[%d-2]=~'\k'" % p):
                p -= 1
            return p

        @staticmethod
        def getline(pos):
            return '' if pos < 2 else Custom_dict.vimdecode(vim.eval("getline('.')[:%d-2]" % pos))

        @staticmethod
        def sample_complete(self):
            pos = self.getpos()
            result = list(self.nodetree.filter(lambda x: x.kind != NOUSEKIND))
            return pos, result

        @staticmethod
        def sample_sort(base):
            def sortkey(x):
                key = '%02d' % x.word.index(base) if base in x.word else '99'
                key += '%02d' % x.word.lower().index(
                    base.lower()) if base.lower() in x.word.lower() else '99'
                key += x.word.swapcase()
                return key
            return sortkey

        def tree_sort(self):
            def sortkey(x):
                key = "0" if x.childs else "1"
                key += self.sortfunc('')(x)
                return key
            return sortkey

    def setup():
        if "1" == vim.eval("exists('b:loaded_custom_dict') && b:loaded_custom_dict == &l:filetype"):
            return
        filetype = vim.eval('&l:filetype')
        vim.command('let b:loaded_custom_dict="%s"' % filetype)
        if filetype in ('', 'help', 'dict'):
            return
#        if Complete.getlocal(filetype): return
        if Custom_dict.get(filetype):
            Complete.setlocal(filetype)
    return Complete.getlocal, setup

import sys
import vim
if sys.version_info[0] < 2 or sys.version_info[1] < 7:
    print 'custom dict plugin requires python2.7'
    vim.command('let s:finished=1')
else:
    custom_dict_load, custom_dict_setup = custom_dict_init()
    vim.command('let s:finished=0')

EOF

augroup filetypedetect
    au! BufNewFile,BufRead *.dict setfiletype dict
augroup END

if s:finished
    finish
endif

set completeopt=menu,longest,preview   
autocmd! FileType * python custom_dict_setup()

if !exists('g:custom_dict_autoclose_preview')
    let g:custom_dict_autoclose_preview=0
endif
au InsertLeave * if !pumvisible() && g:custom_dict_autoclose_preview | silent! pclose | endif

if !exists('g:custom_dict_pumheight')
    let g:custom_dict_pumheight = 20
endif
if str2nr(g:custom_dict_pumheight)>0
    let &pumheight=str2nr(g:custom_dict_pumheight)
endif

function! g:Custom_dict_complete_func(findstart,base) "{{{
    if a:findstart
        python custom_dict_load().customcompletepos()
        return pos
    else
        python custom_dict_load().customcomplete()
        return item
    endif
endfunc
function! g:Custom_dict_complete_first()
    python custom_dict_load().completefirst()
    return ''
endfunc
function! g:Custom_dict_complete_kind()
    python custom_dict_load().completekind()
    return ''
endfunc
function! g:Custom_dict_complete_up()
    python custom_dict_load().completeup()
    return ''
endfunc
function! g:Custom_dict_complete_down()
    python custom_dict_load().completedown()
    return ''
endfunc "}}}
