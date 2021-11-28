; ----------------------------------------------
; 参考Katex，尽可能使用latex触发出对应的unicode字符
;
; https://katex.org/docs/supported.html
; 
; 只对不方便键盘输入的字符进行latex[TAB]替换， 如果没有替换说明输入错误或不支持
;
; 只支持单字符的latex触发（目前支持如下6类）
;    1.下标   _n[TAB]             ₙ   【下标触发】
;    2.上标   ^n[TAB]             ⁿ   【上标触发】
;    3.单字符  \alpha[TAB]         α   【单字符触发】
;    4.字体     \mathbbR[TAB]       ℝ   【空心字符触发】
;    4.字体     \mathfrakR[TAB]     ℜ   【Fraktur字符触发】
;    4.字体     \mathcalR[TAB]      𝓡   【花体字符触发】  
;    5.组合     R\[组合字符][TAB] 比如R\dot[TAB]          R̂   【组合字符触发】
;    6.片段搜索     \[片断字符串][TAB]       【搜索字符触发】
;
;           1) \后如果输入少于2个字符，可能是前面11类情况之一， 直接触发
;           2) 如果完全匹配，就是前面11类情况之一， 直接触发
;           3) 如果不完全匹配，但只有唯一匹配， 直接触发
;           4) 如果不完全匹配，并且不唯一，弹出菜单选择触发
;           5) 如果不匹配，不做任何处理  
; 
;  可用`Win + \`  进行 unicode模式 / latex助手模式 切换  【会有1s后消失的提示】
;       unicode模式:   输出的结果是unicode字符，比如 ⨁
;       latex助手模式: 如果输入正确的或完全不正确，没有任何反应
;                     如果输入的正确的片段（不完全正确），会弹出菜单，选择输入，比如: \bigoplus
; ----------------------------------------------

FileEncoding , UTF-8

#Include %A_ScriptDir%\lib\LaTeXs.ahk

;------------------------------------------------------------------------------------------------------
;        latex热键处理 (完全用Input接管)
;------------------------------------------------------------------------------------------------------
; 按下\键，等候输入，然后tab，可能出现如下4种情况
;     1) \后如果输入少于2个字符，尝试完全匹配，否则无任何变化
;     2) 如果完全匹配 或 不完全但唯一匹配，会自动替换成:  unicode（unicode模式） 
;                                                  或 正确的latex代码（latex助手模式）
;     3) 如果不完全且不唯一匹配，会弹出菜单选择替换，替换的结果是: unicode字符（unicode模式）
;                                                          或 正确的latex代码（latex助手模式）
;     4) 如果不匹配，不做任何处理
;
;  可用`Win + \`  进行 unicode模式 / latex助手模式 切换  【会有1s后消失的提示】
;       unicode模式:   输出的结果是unicode字符，比如 ⨁
;       latex助手模式: 如果输入正确的或完全不正确，没有任何反应
;                     如果输入的正确的片段（不完全正确），会弹出菜单，选择输入，比如: \bigoplus
;------------------------------------------------------------------------------------------------------
HotlatexHandler(prefix)
{
    ; 默认0(或未赋值): 对应latex助手模式;  0: 对应unicode模式 
    global latexMode
    if (not latexMode){
        latexMode := 0
    }

    ; 如果已经加载im_switch模块，支持在中文输入状态下直接输入，会自动切换倒英文状态
    _getImState := "getImState"
    _setImState := "setImState"
    _IMToolTip := "IMToolTip"
    if isFunc(_getImState) and (%_getImState%() = 1)
    {
        Send ^{Space}{bs 2}{text}%prefix%
        %_setImState%(0)
        %_IMToolTip%()
    }

    ;--------------------------------------------
    ;        首先解决 _ \ ^  组合的相互干扰问题
    ;--------------------------------------------

    ; 按次序记录prefix 和 search，防止类似 “_\” 的组合相互干扰
    global  prefixs
    global  searchs
    global  indexPrefix
    global  lastErrorLevel

    ; 比如: 如果输入“_abc\efg”, _先等候输入， \后等候输入
    if (not prefixs)
    {
        prefixs := []
        indexPrefix := 0
    }
    prefixs.Push(prefix)
    indexPrefix := indexPrefix + 1
    
    ; 等候输入
    Input, search, V C , {tab}{space}{enter}{esc}{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}{Up}{Down}{Home}{End}{PgUp}{PgDn}{CapsLock}{NumLock}{PrintScreen}{Pause}
    if (not lastErrorLevel)
        lastErrorLevel := ErrorLevel

    ; 比如: 前面输入“_abc\efg”, 然后tab, _先处理efg， 后处理abc\
    ; 后处理的插前面，确保和prefixs对应
    if not searchs
        searchs := []
    searchs.InsertAt(1, search)

    if (indexPrefix > 1) and (prefixs[indexPrefix] == prefix)
    {
        ; 忽略后续触发，同时确保了searchs完全填充
        indexPrefix := indexPrefix - 1
        return
    }

    ; 拼凑成完整的待处理字符串
    search := prefixs[1]
    for index, value in searchs
        search := search "" value

    ; 确定最后一个前缀-搜索对（一定会匹配）
    regStr := "O)([_\^\\]+)([^_\^\\]*)$"
    if (not latexMode)
        ; latex助手模式下，禁用 _ \ ^  组合
        regStr := "O)([_\^\\])([^_\^\\]*)$"
    RegExMatch(search, regStr, SubPat)
    prefix := SubPat.Value(1)
    search := SubPat.Value(2)

    ; 清空全局变量
    prefixs := []
    searchs := []
    indexPrefix := 0
    ; 非tab终止符触发，表示放弃
    if (lastErrorLevel != "EndKey:tab")
    {
        lastErrorLevel := ""
        return
    }
    lastErrorLevel := ""

    ;--------------------------------------------
    ;        下面是正式的逻辑流程
    ;--------------------------------------------
    latexHotstring := getLaTeXHotstring()
    unicodestring := getUnicodeString()

    ; 需要删除的字符数:  前缀数 + 输入字符数 + `t字符数
    n := StrLen(prefix) + StrLen(search) + 1

    flag := False ; 默认是不完全匹配模式
    ; 如果输入的字符数小于2然后[tab]，则要求完全匹配（防止菜单过长）
    if (n < StrLen(prefix) + 2 + 1)
        flag := True

    ; 搜索匹配
    matches := []
    for index, value in latexHotstring
    {         
        key := value
        value := unicodestring[index]

        if latexMode and InStr(value, key)
            ; Hotlatex("\mathbb", "黑板粗体 ℝ \mathbb{R}")
            ; 如果“键”在“值”中出现，表明只适用于latex助手模式. 【禁止“值”以:开头】
            Continue

        if (not latexMode) and (SubStr(value, 1, 1) == ":")
            ; Hotlatex("\mathbba", ":𝕒") 
            ; 如果"值"以:开头，表明只适用于unicode模式. 【禁止“键”在“值”中出现】
            Continue
        
        ; 剔除额外标记“:”
        value := LTrim(value, ":")

        ; 如果是完全匹配，跳过字符数过大的部分（基于已排序的情况）
        if flag and (StrLen(key) > n-1)
            Break
        
        if  (SubStr(key, 1, StrLen(prefix)) == prefix) and InStr(key, search) 
        {
            if (search == SubStr(key, StrLen(prefix)+1)) 
            {
                if (Not flag)
                {
                    ; 进入完全匹配模式
                    matches := []
                    flag := True
                }    
                ; 收集完全匹配的热LaTeX
                matches.Push(key "=" value)
            }else if (Not flag) {
                ; 在不完全匹配模式下，才能收集不完全匹配的热LaTeX
                matches.Push(key "=" value)
            }
        }    
    }

    ; 唯一匹配（可能是完全匹配，也可能是不完全匹配）
    if (matches.Length() == 1)
    {
        if flag and (not latexMode)
        {
            ; latex助手模式下的完全匹配， 只需要退1格复原
            Send, {bs}
        } else {
            ; 由于是唯一匹配，直接替换即可
            ; unicdoe模式选择等号右边输出； latex助手模式选择等号左边输出
            value := StrSplit(matches[1], "=")[latexMode+1]
            Send, {bs %n%}%value%
        }
        return
    } 

    ; 不唯一匹配（肯定是不完全匹配，需要弹出菜单，通过选择进行替换）
    if (matches.Length() > 1)
    {
        ; 弹出菜单
        for index, value in matches
        {
            ; 发现问题: 添加的菜单项不区分大小写，比如: a A 只能作为同一个菜单项。
            ; 解决方案: 加序号前缀
            itemName := index " : " value
            Menu, HotMenu, Add, %itemName%, MenuHandler
        }
        Send, {bs %n%}
        Sleep 30 ; 延迟30毫秒，确保弹出窗口前退格完成（似乎没有同步发送的API，只能这样）
        Menu, HotMenu, Show
        return
    }

    ; 不匹配， 只需要退1格复原
    Send, {bs}
}

MenuHandler(){    ; 菜单选择处理
    global latexMode
    if (not latexMode){
        latexMode := 0
    }
    ; 剔除序号前缀
    idx := InStr(A_ThisMenuItem, ":")+2
    value := SubStr(A_ThisMenuItem, idx)
    ; unicdoe模式选择等号右边输出； latex助手模式选择等号左边输出
    value := StrSplit(value, "=")[latexMode+1]
    Send, %value%
    Menu, HotMenu, DeleteAll
    return
}

; ~ 表示触发热键时, 热键中按键原有的功能不会被屏蔽(对操作系统隐藏) 
~\::    ; latex命令热键
HotlatexHandler("\")
return
~+6::   ; 上标热键 Shift+6(+6 或 ^) 
HotlatexHandler("^")
return
~+-::   ; 下标热键 Shift+-(+- 或 _) 
HotlatexHandler("_")
return

;-----------------------------------------------------------------------------
;    `Win + \`  进行 unicode模式 / latex助手模式 切换
;-----------------------------------------------------------------------------

#\::    ; 模式切换热键
global latexMode
if (not latexMode){
    latexMode := 0
}
latexMode := Mod(latexMode+1,2)
if (latexMode=1)
    ToolTip, unicode模式
else
    ToolTip, latex助手模式
SetTimer, RemoveLatexToolTip, -1000
return

RemoveLatexToolTip:    ; 删除当前模式提示
ToolTip
return

