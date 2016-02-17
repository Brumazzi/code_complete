"==================================================
" File:         code_complete.vim
" Brief:        function parameter complete, code snippets, and much more.
" Author:       Mingbai <mbbill AT gmail DOT com>
" Last Change:  2009-06-09 00:09:03
" Version:      2.9
"
" Install:      1. Put code_complete.vim to plugin
"                  directory.
"               2. Use the command below to create tags
"                  file including signature field.
"                  ctags -R --c-kinds=+p --fields=+S .
"
" Usage:
"           hotkey:
"               "<tab>" (default value of g:completekey)
"               Do all the jobs with this key, see
"           example:
"               press <tab> after function name and (
"                 foo ( <tab>
"               becomes:
"                 foo ( `<first param>`,`<second param>` )
"               press <tab> after code template
"                 if <tab>
"               becomes:
"                 if( `<...>` )
"                 {
"                     `<...>`
"                 }
"
"
"           variables:
"
"               g:disable_codecomplete
"                   Disable code_complete, default enabled.
"
"               g:completekey
"                   the key used to complete function
"                   parameters and key words.
"
"               g:rs, g:re
"                   region start and stop
"               you can change them as you like.
"
"               g:user_defined_snippets
"                   file name of user defined snippets.
"
"           key words:
"               see "templates" section.
"==================================================

if v:version < 700
    finish
endif

if exists("g:disable_codecomplete")
    finish
endif

" Variable Definitions: {{{1
" options, define them as you like in vimrc:
if !exists("g:completekey")
    let g:completekey = "<tab>"   "hotkey
endif

if !exists("g:rs")
    let g:rs = '`<'    "region start
endif

if !exists("g:re")
    let g:re = '>`'    "region stop
endif

if !exists("g:user_defined_snippets")
    let g:user_defined_snippets = ""
endif

" ----------------------------
let s:expanded = 0  "in case of inserting char after expand
let s:signature_list = []
let s:jumppos = -1
let s:doappend = 1

" Autocommands: {{{1
autocmd BufReadPost,BufNewFile * call CodeCompleteStart()

" Menus:
menu <silent>       &Tools.Code\ Complete\ Start          :call CodeCompleteStart()<CR>
menu <silent>       &Tools.Code\ Complete\ Stop           :call CodeCompleteStop()<CR>

" Function Definitions: {{{1

function! CodeCompleteStart()
    exec "silent! iunmap  <buffer> ".g:completekey
    exec "inoremap <buffer> ".g:completekey." <c-r>=CodeComplete()<cr><c-r>=SwitchRegion()<cr>"
endfunction

function! CodeCompleteStop()
    exec "silent! iunmap <buffer> ".g:completekey
endfunction

function! FunctionComplete(fun)
    let s:signature_list=[]
    let signature_word=[]
    let ftags=taglist("^".a:fun."$")
    if type(ftags)==type(0) || ((type(ftags)==type([])) && ftags==[])
        return ''
    endif
    let tmp=''
    for i in ftags
        if match(i.cmd,'^/\^.*\(\*'.a:fun.'\)\(.*\)\;\$/')>=0
            if match(i.cmd,'(\s*void\s*)')<0 && match(i.cmd,'(\s*)')<0
                    let tmp=substitute(i.cmd,'^/\^','','')
                    let tmp=substitute(tmp,'.*\(\*'.a:fun.'\)','','')
                    let tmp=substitute(tmp,'^[\){1}]','','')
                    let tmp=substitute(tmp,';\$\/;{1}','','')
                    let tmp=substitute(tmp,'\$\/','','')
                    let tmp=substitute(tmp,';','','')
                    let tmp=substitute(tmp,',',g:re.','.g:rs,'g')
                    let tmp=substitute(tmp,'(\(.*\))',g:rs.'\1'.g:re.')','g')
            else
                    let tmp=''
            endif
            if (tmp != '') && (index(signature_word,tmp) == -1)
                let signature_word+=[tmp]
                let item={}
                let item['word']=tmp
                let item['menu']=i.filename
                let s:signature_list+=[item]
            endif
        endif
        if has_key(i,'kind') && has_key(i,'name') && has_key(i,'signature')
            if (i.kind=='p' || i.kind=='f') && i.name==a:fun  " p is declare, f is definition
                if match(i.signature,'(\s*void\s*)')<0 && match(i.signature,'(\s*)')<0
                    let tmp=substitute(i.signature,',',g:re.','.g:rs,'g')
                    let tmp=substitute(tmp,'(\(.*\))',g:rs.'\1'.g:re.')','g')
                else
                    let tmp=''
                endif
                if (tmp != '') && (index(signature_word,tmp) == -1)
                    let signature_word+=[tmp]
                    let item={}
                    let item['word']=tmp
                    let item['menu']=i.filename
                    let s:signature_list+=[item]
                endif
            endif
        endif
    endfor
    if s:signature_list==[]
        return ')'
    endif
    if len(s:signature_list)==1
        return s:signature_list[0]['word']
    else
        call  complete(col('.'),s:signature_list)
        return ''
    endif
endfunction

function! ExpandTemplate(cword)
    "let cword = substitute(getline('.')[:(col('.')-2)],'\zs.*\W\ze\w*$','','g')
    if has_key(g:template,&ft)
        if has_key(g:template[&ft],a:cword)
            let s:jumppos = line('.')
            return "\<c-w>" . g:template[&ft][a:cword]
        endif
    endif
    if has_key(g:template['_'],a:cword)
        let s:jumppos = line('.')
        return "\<c-w>" . g:template['_'][a:cword]
    endif
    return ''
endfunction

function! SwitchRegion()
    if len(s:signature_list)>1
        let s:signature_list=[]
        return ''
    endif
    if s:jumppos != -1
        call cursor(s:jumppos,0)
        let s:jumppos = -1
    endif
    if match(getline('.'),g:rs.'.*'.g:re)!=-1 || search(g:rs.'.\{-}'.g:re)!=0
        normal 0
        call search(g:rs,'c',line('.'))
        normal v
        call search(g:re,'e',line('.'))
        if &selection == "exclusive"
            exec "norm l"
        endif
        return "\<c-\>\<c-n>gvo\<c-g>"
    else
        if s:doappend == 1
            if g:completekey == "<tab>"
                return "\<tab>"
            endif
        endif
        return ''
    endif
endfunction

function! CodeComplete()
    let s:doappend = 1
    let function_name = matchstr(getline('.')[:(col('.')-2)],'\zs\w*\ze\s*(\s*$')
    if function_name != ''
        let funcres = FunctionComplete(function_name)
        if funcres != ''
            let s:doappend = 0
        endif
        return funcres
    else
        let template_name = substitute(getline('.')[:(col('.')-2)],'\zs.*\W\ze\w*$','','g')
        let tempres = ExpandTemplate(template_name)
        if tempres != ''
            let s:doappend = 0
        endif
        return tempres
    endif
endfunction


" [Get converted file name like __THIS_FILE__ ]
function! GetFileName()
    let filename=expand("%:t")
    let filename=toupper(filename)
    let _name=substitute(filename,'\.','_',"g")
    "let _name="__"._name."__"
    return _name
endfunction

" Templates: {{{1
" to add templates for new file type, see below
"
" "some new file type
" let g:template['newft'] = {}
" let g:template['newft']['keyword'] = "some abbrevation"
" let g:template['newft']['anotherkeyword'] = "another abbrevation"
" ...
"
" ---------------------------------------------
" C templates
let g:template = {}
let g:template['c'] = {}
let g:template['c']['cm'] = "/*  */".repeat("\<left>",3)
let g:template['c']['cmm'] = "/**<  */".repeat("\<left>",3)
let g:template['c']['de'] = "#define "
let g:template['c']['un'] = "#undef "
let g:template['c']['pr'] = "#pragma once"
let g:template['c']['il'] = "#include \"\"\<left>"
let g:template['c']['in'] = "#include <>\<left>"
let g:template['c']['ff'] = "#ifndef  \<c-r>=GetFileName()\<cr>\<CR>#define  \<c-r>=GetFileName()\<cr>".
            \repeat("\<cr>",5)."#endif  /*\<c-r>=GetFileName()\<cr>*/".repeat("\<up>",3)
let g:template['c']['for'] = "for(".g:rs."define".g:re."; ".g:rs."condition".g:re."; ".g:rs."increment".g:re."){\<cr>".
            \g:rs."code".g:re."\<cr>}\<cr>"
let g:template['c']['main'] = "int main(int argc, char \*argv\[\]){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['switch'] = "switch (".g:rs."input".g:re."){\<cr>case ".g:rs."comp".g:re." :\<cr>break;\<cr>case ".
            \g:rs."...".g:re." :\<cr>break;\<cr>default :\<cr>break;\<cr>}"
let g:template['c']['case'] = "case ".g:rs."...".g:re.":\<cr>break;"
let g:template['c']['if'] = "if(".g:rs."condition".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['while'] = "while(".g:rs."condition".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['elif'] = "if(".g:rs."condition".g:re."){\<cr>".g:rs."code".g:re."\<cr>} else{\<cr>".g:rs."code".
            \g:re."\<cr>}"
let g:template['c']['ts'] = "typedef struct{\<cr>\<cr>}".g:rs."type_name".g:re.";"
let g:template['c']['st'] = "struct {\<cr>\<cr>};".repeat("\<up>",2).repeat("\<right>",5)

" ---------------------------------------------
" C methods
let g:template['c']['mv'] = "void ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mpv'] = "void *".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mi'] = "int ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mli'] = "long int ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mlli'] = "long long int ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mui'] = "unsigned int ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['muli'] = "unsigned long int ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mulli'] = "unsigned long long int ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mc'] = "char ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mpc'] = "char *".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mcc'] = "const char *".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['mf'] = "float ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['md'] = "double ".g:rs."method".g:re."(".g:rs."args".g:re."){\<cr>".g:rs."code".g:re."\<cr>}"
let g:template['c']['vp'] = "void *"
let g:template['c']['ch'] = "char "
let g:template['c']['cc'] = "const char *"
let g:template['c']['cp'] = "char *"
let g:template['c']['i'] = "int "
let g:template['c']['li'] = "long int "
let g:template['c']['lli'] = "long long int "
let g:template['c']['ui'] = "unsigned int "
let g:template['c']['uli'] = "unsigned long int "
let g:template['c']['ulli'] = "unsigned long long int "
let g:template['c']['fl'] = "float "
let g:template['c']['dl'] = "double "

" ---------------------------------------------
" C++ templates
let g:template['cpp'] = g:template['c']
let g:template['hpp'] = g:template['cpp']
let g:template['cpp']['ci'] = "class ".g:rs."class_name".g:re."{\<cr>public:\<cr>private:\<cr>protected:\<cr>};"
let g:template['cpp']['cl'] = "class ".g:rs."class_name".g:re."{\<cr>public:\<cr>".g:rs."class_name".g:re."(){\<cr>}\<cr>~".g:rs."class_name".g:re."(){\<cr>}\<cr>private:\<cr>protected:\<cr>};"

" ---------------------------------------------
" C header
let g:template['h'] = {}
let g:template['h']['cm'] = g:template['c']['cm']
let g:template['h']['cmm'] = g:template['c']['cmm']
let g:template['h']['de'] = g:template['c']['de']
let g:template['h']['un'] = g:template['c']['un']
let g:template['h']['pr'] = g:template['c']['pr']
let g:template['h']['in'] = g:template['c']['in']
let g:template['h']['il'] = g:template['c']['il']
let g:template['h']['ff'] = g:template['c']['ff']
let g:template['h']['ci'] = "class ".g:rs."class_name".g:re."{\<cr>public:\<cr>private:\<cr>protected:\<cr>};"
let g:template['h']['cl'] = "class ".g:rs."class_name".g:re."{\<cr>public:\<cr>".g:rs."class_name".g:re."();\<cr>~".g:rs."class_name".g:re."();\<cr>private:\<cr>protected:\<cr>};"
let g:template['h']['mv'] = "void ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mpv'] = "void *".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mi'] = "int ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mli'] = "long int ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mlli'] = "long long int ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mui'] = "unsigned int ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['muli'] = "unsigned long int ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mulli'] = "unsigned long long int ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mc'] = "char ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mpc'] = "char *".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mcc'] = "const char *".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['mf'] = "float ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['md'] = "double ".g:rs."method".g:re."(".g:rs."args".g:re.");"
let g:template['h']['ts'] = g:template['c']['ts']
let g:template['h']['st'] = g:template['c']['st']
let g:template['h']['vp'] = g:template['c']['vp']
let g:template['h']['ch'] = g:template['c']['ch']
let g:template['h']['cc'] = g:template['c']['cc']
let g:template['h']['cp'] = g:template['c']['cp']
let g:template['h']['i'] = g:template['c']['i']
let g:template['h']['li'] = g:template['c']['li']
let g:template['h']['lli'] = g:template['c']['lli']
let g:template['h']['ui'] = g:template['c']['ui']
let g:template['h']['uli'] = g:template['c']['uli']
let g:template['h']['ulli'] = g:template['c']['ulli']
let g:template['h']['fl'] = g:template['c']['fl']
let g:template['h']['dl'] = g:template['c']['dl']

" ---------------------------------------------
" common templates
let g:template['_'] = {}
let g:template['_']['xt'] = "\<c-r>=strftime(\"%Y-%m-%d %H:%M:%S\")\<cr>"

" ---------------------------------------------
" project_description
let $division = " ===================================================="
let $card  = "\<cr>"
let $card .= "   FILE NAME:  ".expand("%")
let $card .= "\<cr>"
let $card .= "\<cr>".repeat("\<backspace>",3)
let $card .= " DESCRIPTION:  `<Description>`"
let $card .= "\<cr>".repeat("\<backspace>",1)
let $card .= "\<cr>"
let $card .= "     VERSION:  1.0"
let $card .= "\<cr>"
let $card .= "CREATED:  \<c-r>=strftime(\"%Y-%m-%d %H:%M:%S\")\<cr>"
let $card .= "\<cr>"
let $card .= "REVISON:  `<Revision>`"
let $card .= "\<cr>".repeat("\<backspace>",1)
let $card .= "COMPILER:  GCC/G++"
let $card .= "\<cr>"
let $card .= "\<cr>"
let $card .= "  AUTHOR:  `<Author>`"
let $card .= "\<cr>"
let $card .= "E-MAIL:  `<Mail>`"
let $card .= "\<cr>"
let $card .= "\<cr>".repeat("\<backspace>",6)
let $card .= "ORGANIZATION:  `<ORG>`"
let $card .= "\<cr>".repeat("\<backspace>",1)
let g:template['c']['info'] = "//".$division."\<cr>".$card."\<cr>".$division."<\<cr>".repeat("\<backspace>",3)."\<cr>`<code>`"
let g:template['h']['info'] = g:template['c']['info']

" ---------------------------------------------
" load user defined snippets
exec "silent! runtime plugin/my_snippets.vim"
exec "silent! source ".g:user_defined_snippets


" vim: set fdm=marker et :
