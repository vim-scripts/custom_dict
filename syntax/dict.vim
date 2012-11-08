
if exists('b:current_syntax') && b:current_syntax == 'dict'
    finish
endif

syn match WordLine /^\(+-\*\/\)\+\S.*$/ contains=WordFlag,WordName,WordNoStandName,WordKind
syn match WordFlag /^\(+-\*\/\)\+/ contained
syn match WordName /\(^\(+-\*\/\)\+\)\@<=\S\+/ contained
syn match WordKind /\(^\(+-\*\/\)\+\S\+\s\+\)\@<=\S\($\|\s\)\@=/ contained
syn match DictComment /^\/\*-+.*$/ 
syn match EnglishLine /^[^+\/][[:graph:] ]\+$/
syn match WordTab /\t/

hi def link DictComment Special
hi def link WordTab Error
hi def link EnglishLine Identifier
hi def link WordLine Statement
hi def link WordFlag Type
hi def link WordName NonText
hi def link WordKind VisualNOS

let b:current_syntax = 'dict'
