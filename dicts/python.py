# coding:utf-8

dicts = ['python.pyparsing.dict',
         'python.stdlib.zh_CN.dict',
         'python.bs4.zh_CN.dict']

#         'python.xapian.dict',

def complete(self):
    NOUSEKIND = '_'
    import re
    WORD = r'([0-9_a-zA-Z.]+)'

    def do_from_import(line):
        t = re.match(r'\s*from\s+%s\s+import\s+$' % WORD, line)
        if t:
            words = t.groups()[0]
            if words:
                words = words.split('.')
                tree = self.nodetree
                for word in words:
                    tree = tree.search(lambda x: x.word == self.vimdecode(
                        word) and x.kind == 'p')
                result = []
                for node in tree.childs:
                    result.extend(node.filter(lambda x: x.kind != NOUSEKIND))
                return result
        return []

    def do_from(line):
        t = re.match(r'\s*from\s+%s?$' % WORD, line)
        if t:
            words = t.groups()[0]
            if words:
                words = words.split('.')[:-1]
                tree = self.nodetree
                for word in words:
                    tree = tree.search(
                        lambda x: x.word == self.vimdecode(word) and x.kind == 'p')
                result = []
                for node in tree.childs:
                    result.extend(node.search(lambda x: x.kind == 'p').childs)
                return result
            else:
                return self.nodetree.search(lambda x: x.kind == 'p').childs
        return []

    def do_import(line):
        t = re.match(r'\s*import\s+%s?$' % WORD, line)
        if t:
            words = t.groups()[0]
            if words:
                words = words.split('.')[:-1]
                tree = self.nodetree
                for word in words:
                    tree = tree.search(
                        lambda x: x.word == self.vimdecode(word) and x.kind == 'p')
                result = []
                for node in tree.childs:
                    result.extend(node.search(lambda x: x.kind == 'p').childs)
                return result
            else:
                a = self.nodetree.search(lambda x: x.kind == 'p')
                return a.childs
        return []

    def do_class(line):
        t = re.match(r'\s*class\s+\w+\($', line)
        if t:
            return list(self.nodetree.filter(lambda x: x.kind in 'cte'))
        return []

    def do_def(line):
        t = re.match(r'\s*def\s+', line)
        if t:
            return list(self.nodetree.filter(lambda x: x.kind in 'm'))
        return []

    def do_dot(line):
        t = re.match(r'(^|.*\W)%s\.$' % WORD, line)
        if t:
            words = t.groups()[1]
            if words:
                words = words.split('.')
                tree = self.nodetree
                for word in words:
                    tree = tree.search(
                        lambda x: x.word == self.vimdecode(word))
                result = []
                for node in tree.childs:
                    result.extend(node.filter(lambda x: x.kind != NOUSEKIND))
                if result:
                    return result
        if line.endswith('.'):
            return list(self.nodetree.filter(lambda x: x.kind in 'dmM'))
        return []

    pos = self.getpos()
    line = self.getline(pos)
    t = do_from_import(line)
    if t:
        return pos, t
    t = do_from(line)
    if t:
        return pos, t
    t = do_import(line)
    if t:
        return pos, t
    t = do_class(line)
    if t:
        return pos, t
    t = do_def(line)
    if t:
        return pos, t
    t = do_dot(line)
    if t:
        return pos, t
    return pos, list(self.nodetree.filter(lambda x: x.kind != NOUSEKIND))


def setup(self):
    import vim
    vim.command(
        "command! -nargs=1 -buffer CUSTOMdictpythonload py custom_dict_load().dict.load('<args>')")
    self = self.dict
    if hasattr(self, 'load'):
        return
    def yieldmodule(node,name=''):
        for x in node.search(lambda y:y.kind=='p',True).childs:
            if name:
                yield name+'.'+x.word
            else:
                yield x.word
            for z in yieldmodule(x,x.word):
                yield z

    self.loadmodules = set(yieldmodule(self.nodetree))
    Node = self.nodetree.__class__

    from pkgutil import iter_modules
    from inspect import isfunction, ismethod, isbuiltin, isclass, isabstract, ismodule, isroutine, classify_class_attrs, getdoc, getcomments, getclasstree, getmembers, formatargspec, getargspec

    def getinfo(obj):
        s = getdoc(obj) or getcomments(obj) or ''
        if isinstance(s, type(u'')):
            s = s.encode('utf-8')
        else:
            try:
                s.decode('utf-8')
            except:
                s = ''
        return s

    def get_func(word, func):
        f = func
        if ismethod(func):
            f = func.im_func
        if isfunction(f):
            info = word+formatargspec(*getargspec(f))
        else:
            info = word+'(...)'
        info = info + '\n' + getinfo(func)
        return Node(word, 'f', info=info)

    def get_class(word, cls):
        if issubclass(cls, Exception):
            node = Node(word, 'e')
        elif isabstract(cls):
            node = Node(word, 't')
        else:
            node = Node(word, 'c')
        if hasattr(cls, '__init__'):
            v = cls.__init__
            if ismethod(v) and hasattr(v, 'im_class') and v.im_class is cls:
                n = get_func(word, v.im_func)
                node.info = n.info
        node.info = node.info+'\n'+getinfo(cls)
        for x in classify_class_attrs(cls):
            if x.name.startswith('_'):
                continue
            if x.defining_class != cls:
                continue
            if x.kind == 'property':
                node.add(Node(x.name, 'd', info=getinfo(x.object)), True)
                continue
            elif x.kind == 'data':
                node.add(Node(x.name, 'd'), True)
                continue
            elif x.kind == 'class method' or x.kind == 'static method':
                kind = 'M'
            else:
                kind = 'm'
            n = get_func(x.name, x.object)
            n.kind = kind
            node.add(n, True)
        return node

    def get_module(word, module):
        from importlib import import_module
        node = Node(word, 'p', info=getinfo(module))
        members = {}
        for name, obj in getmembers(module):
            if hasattr(module, '__all__') and name not in module.__all__:
                continue
            if isbuiltin(obj):
                continue
            if name.startswith('_'):
                continue
            if hasattr(obj, '__module__') and obj.__module__ != module.__name__:
                continue
            members[name] = obj
        if hasattr(module, '__path__'):
            for _, name, ispkg in iter_modules(module.__path__):
                if hasattr(module, '__all__') and name not in module.__all__:
                    continue
                try:
                    obj = import_module(module.__name__ + '.' + name)
                except:
                    continue
                members[name] = obj
        classes = {}
        for name, obj in members.items():
            if isclass(obj) or isabstract(obj):
                classes[obj] = name
                continue
            if ismodule(obj):
                if obj.__name__ not in self.loadmodules:
                    self.loadmodules.add(obj.__name__)
                    n = get_module(name, obj)
                    if n:
                        node.add(n, True)
                continue
            if isroutine(obj):
                node.add(get_func(name, obj), True)
                continue
            node.add(Node(name, 'd'), True)

        def yieldtree(tree):
            for x in tree:
                if isinstance(x, type(())):
                    yield x
                else:
                    for y in yieldtree(x):
                        yield y
        for a, b in yieldtree(getclasstree(classes, True)):
            if a in classes:
                b = filter(lambda x: x in classes, b)
                if not isinstance(classes[a], type('')):
                    continue
                n = get_class(classes[a], a)
                if len(b) == 1:
                    classes[b[0]].add(n, True)
                else:
                    node.add(n, True)
                classes[a] = n
        return node if node.childs else None

    def load(name):
        if '.' in name:
            vim.command('echoerr "%s has dot !"' % name)
            return
        if name in self.loadmodules:
            vim.command('echom "%s is load."' % name)
            return
        try:
            a = __import__(name)
        except:
            vim.command('echoerr "%s not is module!"' % name)
            return
        node = get_module(name, a)
        if not node:
            vim.command('echom "%s no content."' % name)
            return
        for x in self.nodetree.childs:
            if x.word == '_now_load':
                break
        else:
            x = Node('_now_load', '_')
            self.nodetree.add(x, True)
        x.add(node, True)
        self.checkdup()
    self.load = load



