*custom_dict.txt*		自定义补全字典		最近更新:2013年04月04日

							*custom_dict_plugin*
简介			|custom_dict_plugin_intro|
相关文件		|custom_dict_plugin_files|
使用方法		|custom_dict_plugin_usage|
字典格式		|custom_dict_plugin_dict|
参数说明		|custom_dict_plugin_setup|
python补全		|custom_dict_plugin_python|

===========================================================================
简介						*custom_dict_plugin_intro*

动态语言的补全一部分是即时解析文件，像python-jedi，不过因为是动态语言，
有些时候是无法得到提示的。所以还有一部分像pydiction之类的是收集整理出
所有可能单词的。本插件可以代替后者，增加了树状结构，这样补全提示的时候
就有层次，对于遗忘的单词可以更为方便的搜索到。

===========================================================================
相关文件					*custom_dict_plugin_files*

plugin/custom_dict.vim		插件
ftplugin/dict.vim		dict文件相关的插件
syntax/dict.vim			dict文件相关的插件
dicts/				存放dict文件的目录
dicts/XX.py			XX类型的设置
doc/custom_dict.txt		help文件

如果没有编写某文件类型的设置，插件会自动查找 dicts/ 目录下的文件
例如vim的文档只要命名为vim.dict并放入dicts/目录下，不需要相应的vim.py也可以
使用。文件名称遵从 $filetype...dict 格式，如vim.zh_CN.dict或vim.en.dict

===========================================================================
使用方法					*custom_dict_plugin_usage*

以下按默认设置情况说明

补全					*custom_dict_plugin_usage_complete*
在插入模式下按<C-X><C-U>进入补全模式
在补全模式下按<C-F>，补全菜单将按照同一类型显示，连续按<C-F>可切换遍历各种类
型。按<C-H>进入层次模式显示，按<C-N>或<C-P>选择层次模式显示里类型标记为‣或>
的词条，再按<C-L>将进入到该词条的下一层次里，再按<C-H>返回上一层次。

字典文件				*custom_dict_plugin_usage_dict*
编辑dict文件时，在词条行按+将增加层次深度，按-减少层次。可以用V模式选择多行
同时操作。

===========================================================================
字典格式					*custom_dict_plugin_dict*

字典必须使用utf-8编码

样例~
>
	+-*/word1 c 这是词条行，类型为c
	更为详细的说明内容
	...
	+-*/word2 C 这是词条行，类型为C，这一行的内容是短注释
	更为详细的说明内容
	+-*/+-*/word3 _ 这是虚拟词条行，是word2的子层次
	更为详细的说明内容
	+-*/+-*/+-*/word4 C 这是词条行，类型为C，是word3的子层次
	更为详细的说明内容
	+-*/+-*/word5 这是词条行，没有类型，是word2的子层次
	更为详细的说明内容
	/*-+ 这是注释行，通常用于说明类型的含义

<
+-*/是标记词条的，每多一个就多一个层次，子层次的深度不能比父层次的深度多出超于
一个的+-*/。在+-*/后紧跟的就是用于补全的单词，其后可以加上类型，用空白分割，类
型只能是一个英文字符，如果是'_'类型则表示为虚拟的词条，只会出现在层次模式显示里
。一般用于建立虚拟的划分层次。也可以没有类型，词条行的剩余内容为短注释，直接出
现在补全菜单里。详细说明在使用<C-P>或<C-N>或<UP><DOWN>键选择到词条时会出现提示
窗口里。注释行通常来说明文档里各类型字符所代表的含义，通常使用的规范为 >
	/*-+ c	class
	/*-+ m	object method
	/*-+ M	class method
	/*-+ d	object data
	/*-+ f	function
	/*-+ p	module or pack
<
NOTE: +-*/和/*-+都要在行的开头才有效，前面不能有空白。同一子层次里带有孙层次的
	词条不能有重复的，如有重复的视为同一个。同一子层次里不能有同名同类型的
	词条。以下是错误样例 >
	+-*/classA c 
	+-*/+-*/classB c
	+-*/+-*/+-*/method1 m
	+-*/+-*/+-*/method1 m   这是错误的行，不能同名同类型
	+-*/+-*/classC c
	+-*/+-*/+-*/method1 m   这是可以的，因为和以上的method1不是同一子层次
	+-*/+-*/classB c        这里将该词条视为同第二行的词条
	+-*/+-*/+-*/+-*/method2 m   这是错误行，子层次只能比父层次多一个+-*/

===========================================================================
参数说明					*custom_dict_plugin_setup*

全局~
通常写在vimrc配置里 >
	let loaded_custom_dict = 1	 "屏蔽此插件
	let g:custom_dict_pumheight = 20  "设置提示的条数,避免遮挡预览窗口
        let g:custom_dict_autoclose_preview = 1 
	     " 设置是否自动关闭预览窗口，可在命令行设置此参数
<

某类型的设置~
通常写在dicts/目录里XX.py里
这里用文件类型XX作例子 >

	#该类型所使用到的字典文件，此参数是数组类型，每一项是dicts/目录里对应
	#的一个文件
	dicts = ['python.pyparsing.dict', 'python.stdlib.zh_CN.dict',
		 'python.bs4.zh_CN.dict']

	"这一项指名在非层次模式显示里是否直接使用文档里词条行的短注释作提示
	"一般有时会有多个同名的单词，如果将此项设为0，短注释里将用层次结构
	"来代替，如classA.classB，设为1，将还是使用文档里原先的短注释
	let g:custom_XX_dict_usemenu = 1

	#这一项的值有两种，'free'或'default'
	#两种略有不同，free调出的菜单一般只用于选择
	#default则是使用<C-X><C-U>补全方式，此方式里可以通过键入字符来筛选
	#不过本插件有对结果进行排序，在已键入的字符后面调出补全菜单时
	#显示的内容会将相似的结果排在前面
        complete_method = 'default'

        #这是按键设定
	#free方式将使用first键来调出补全菜单，
	#在补全模式下用kind键轮换不同类型
	#在补全模式下用up键调用层次模式显示或返回上一层次
	#在补全模式下用down键进入下一层或进入层次模式显示
        map_keys = {'kind':'<C-F>','up':'<C-H>','down':'<C-L>','first':'<C-T>'}

	#可以设定智能补全,需定义complete函数
	#默认为显示字典里所有条目，可以通过此函数来根据不同情况筛选所需条目
        #函数有一个参数，为存放字典条目的对象
        #该对象常用方法可在编写时用此插件调出补全的层次菜单里的"语言>vim"里察看
        #函数应该返回两个值，一个是位置，一个是结果条目列表
        def complete(self):
            pos = self.getpos()
            result = list(self.nodetree.filter(lambda x: x.kind != '_'))
            return pos, result

        #可以设定补全菜单的排序方式,需定义sortresult函数
	#sortresult函数有一个参数，为补全时已敲入的字符
        #默认如敲入xxx.base这时调出的补全菜单里，以base打头的条目排在最前面
	#包含base的条目排在其次，其它排在最后，大写排在小写之后
        #函数应该返回一个索引函数
        def sortresult(base):
            def sortkey(x):
                key = '%02d' % x.word.index(base) if base in x.word else '99'
                key += '%02d' % x.word.lower().index(
                    base.lower()) if base.lower() in x.word.lower() else '99'
                key += x.word.swapcase()
                return key
            return sortkey

<

===========================================================================
python补全					*custom_dict_plugin_python*

在编辑python文件时，可以在命令行输入:CUSTOMdictpythonload xxx来增加字典内容
xxx为模块名称(不得含有'.')。执行命令后可以在层次菜单里的_now_load条目里看到
该模块。
python所使用的字典文件里,kind类型如下 >

	p 模块（或包）
	c 类
	t 抽象类或类型
	e 异常
	f 函数
	m 方法
	d 值或属性
	M 类方法或静态方法

<	

===========================================================================
补充说明~

已知此插件与dbext.vim插件有冲突，如装有dbext本插件可能不能正常使用。

对于普通模式查看某单词注释，可自定义快捷键来实现此操作,如 >
	nmap <F1> hea<C-X><C-U><C-N>
不过由于词典里单词不一定全是字母形式，而且同名的可能会很多，所以需自行根据不同
情况来实现此功能。


 vim:tw=78:ts=8:ft=help:norl:
