;@Ahk2Exe-SetProductName    LaTex助手
;@Ahk2Exe-SetProductVersion 2021.12.30
;@Ahk2Exe-SetDescription LaTex助手
;@Ahk2Exe-SetFileVersion    2021.12.30
;@Ahk2Exe-SetCopyright @2021-2025
;@Ahk2Exe-SetLanguage 0x0804
;@Ahk2Exe-SetOrigFilename LaTexHelper
;@Ahk2Exe-SetLegalTrademarks chaoskey
;@Ahk2Exe-SetCompanyName chaoskey
;@Ahk2Exe-SetMainIcon images\LaTeXHelper.ico

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
; ----------------------------------------------
#SingleInstance, force

FileEncoding , UTF-8-RAW

#Include lib\LaTeXs.ahk
#Include lib\util.ahk
#Include lib\CustomGUI.ahk

; 托盘提示
Menu, Tray,Tip , LaTeX助手
icoName := "images\" StrReplace(A_ScriptName, ".ahk" , ".ico")
if FileExist(icoName){
    Menu, Tray, Icon, %icoName%
}

; 加载热LaTeX
loadHotlatex()
; 创建触发热键
loadTriggerHotKey()
; 光标或鼠标跟随控件
global followList := new FollowListBox()
return ; 自动运行段结束

; 如果是在输入状态中，禁用系统Tab快捷键(转义成一个肯定用不到的虚拟键{vkFFscFFF})
IsWaitInputComplete(){
    global  waitInputComplete ; 等候输入完成的过程中
    if not waitInputComplete{
        waitInputComplete := False
    }
    return waitInputComplete
}
#if IsWaitInputComplete()
Tab::Send {vkFFscFFF}
#if

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
HotlatexHandler()
{
    prefix := A_ThisHotkey

    ; 默认0(或未赋值): 对应latex助手模式;  1: 对应unicode模式 
    global unicodeMode
    if (not unicodeMode){
        unicodeMode := 0
    }

    ; 如果已经加载IMSwitch模块，则可控制只在英文状态下有效，中文状态下无效
    _getImState := "getImState"
    if isFunc(_getImState)
    {
        imState := %_getImState%()
        if (imState = 1){
            return
        }
    }

    ;--------------------------------------------
    ;        首先解决触发热键组合的相互干扰问题
    ;--------------------------------------------

    ; 按次序记录prefix 和 search，防止类似 “_\” 的组合相互干扰
    global  prefixs
    global  searchs
    global  indexPrefix
    global  lastErrorLevel
    global  waitInputComplete ; 等候输入完成的过程中

    ; 比如: 如果输入“_abc\efg”, _先等候输入， \后等候输入
    if (not prefixs)
    {
        prefixs := []
        indexPrefix := 0
    }
    if (prefixs.Length() = 0){
        ; 进入等候状态
        waitInputComplete := True ;  等候输入
    }
    prefixs.Push(prefix)
    indexPrefix := indexPrefix + 1
    
    ; 等候输入
    Input, search, V C , {tab}{space}{enter}{esc}{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}{Up}{Down}{Home}{End}{PgUp}{PgDn}{CapsLock}{NumLock}{PrintScreen}{Pause}{LCtrl}{RCtrl}{LAlt}{RAlt}{LWin}{RWin}{vkFF}
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

    ; 为后面的正则表达式准备
    trigStr := ""
    for i_, v_ in getTriggerFirstChar(){
        trigStr := trigStr "\" v_
    }
    ; 确定最后一个前缀-搜索对（一定会匹配）
    regStr := "O)([" trigStr "]+)([^" trigStr "]*)$"
    if (not unicodeMode)
        ; latex助手模式下，禁用组合触发
        regStr := "O)([" trigStr "])([^" trigStr "]*)$"
    RegExMatch(search, regStr, SubPat)
    prefix := SubPat.Value(1)
    search := SubPat.Value(2)

    ; 清空全局变量
    prefixs := []
    searchs := []
    indexPrefix := 0
    waitInputComplete := False ;  输入完成
    ; 非tab终止符触发，表示放弃
    ; 为了防止系统Tab的干扰，在输入完全前将Tab转义成一个肯定用不到的虚拟键{vkFFscFFF}
    ; 所以非{vkFF}也就是非tab终止符
    if (lastErrorLevel != "EndKey:vkFF"){
        lastErrorLevel := ""
        return
    }
    lastErrorLevel := ""

    ;--------------------------------------------
    ;        下面是正式的逻辑流程
    ;--------------------------------------------
    latexHotstring := getLaTeXHotstring() 

    ; 需要删除的字符数:  前缀数 + 输入字符数
    n := StrLen(prefix) + StrLen(search)

    flag := False ; 默认是不完全匹配模式
    ; 如果输入的字符数小于2，则要求完全匹配（防止菜单过长）
    if (StrLen(search) < 2)
        flag := True
    ; 搜索匹配的索引
    global matches := []
    for index, value in latexHotstring
    {
        ; 前缀不匹配，直接跳过
        if (InStr(value, prefix) != 1) {
            Continue
        }

        ; 剔除前缀后的部分作为“键”
        key := SubStr(value, StrLen(prefix)+1) 
        value := getUnicode(index)

        if unicodeMode and InStr(value, key)
            ; Hotlatex("\mathbb", "黑板粗体 ℝ \mathbb{R}")
            ; 如果“键”在“值”中出现，表明只适用于latex助手模式. 【禁止“值”以:开头】
            Continue

        if (not unicodeMode) and (SubStr(value, 1, 1) == ":")
            ; Hotlatex("\mathbba", ":𝕒") 
            ; 如果"值"以:开头，表明只适用于unicode模式. 【禁止“键”在“值”中出现】
            Continue
        

        ; 如果是完全匹配，跳过字符数过大的部分（基于已排序的情况）
        if flag and (StrLen(key) > StrLen(search))
            Break
        
        if  InStr(key, search) {
            if (search == key) {
                if (Not flag)
                {
                    ; 进入完全匹配模式
                    matches := []
                    flag := True
                }    
                ; 收集完全匹配的热LaTeX索引
                matches.Push(index)
            }else if (Not flag) {
                ; 在不完全匹配模式下，才能收集不完全匹配的热LaTeX索引
                matches.Push(index)
            }
        }    
    }

    ; 唯一匹配（可能是完全匹配，也可能是不完全匹配）
    if (matches.Length() == 1)
    {
        latexBlock := getLaTeXBlock(matches[1])
        if (not unicodeMode) and (latexBlock=="") {
            ; latex助手模式 and 非letex块
            if (not flag) {
                ; 不完全匹配
                value := getLaTeXHot(matches[1])
                Send, {bs %n%}%value%
            }
            return
        }
        if (not unicodeMode) and latexBlock {
            ; latex助手模式 and letex块
            latexBlock := "{bs " n "}" latexBlock  
            for i_, v_ in StrSplit(latexBlock, "##") {
                Send, %v_%
            }
            return
        }
        ; unicode模式, 剔除额外标记“:”
        value := LTrim(getUnicode(matches[1]), ":")
        Send, {bs %n%}%value%        
        return
    } 

    ; 不唯一匹配（肯定是不完全匹配，需要弹出菜单，通过选择进行替换）
    if (matches.Length() > 1)
    {
        Send, {bs %n%}
        Sleep 30 ; 延迟30毫秒，确保弹出提示窗口前退格完成（似乎没有同步发送的API，只能这样）
        ; 准备列表数据，并计算提示窗口的长宽
        maxWidth := 100
        maxHeight := Min(Max(Ceil(20*matches.Length()),40),200)
        suggList := []
        for index, value in matches
        {
            ; 通过添加后缀来表示热LaTeX索引,  Unicode剔除额外标记“:”
            itemName := getLaTeXHot(value) "=" LTrim(getUnicode(value), ":")
            maxWidth := Max(Ceil(10*StrLen(itemName)),maxWidth)
            suggList.Push(itemName)
        }
        ; 弹出提示窗口
        followList.show(suggList, "SelectHandler")
        return
    }
}

SelectHandler(index){    ; 菜单选择处理
    ; index 提示列表选择的索引
    global matches
    global unicodeMode

    ; 获取对应菜单项相对热latex数组的索引
    index := matches[index]
    ; 热LaTeX LaTeX块 Unicode
    latex := getLaTeXHot(index)
    unicdoe := LTrim(getUnicode(index), ":")  ; 剔除额外标记“:”
    latexBlock := getLaTeXBlock(index)
    
    if unicodeMode {
        Send, %unicdoe%
    }else if latexBlock {
        ; 通过“##”将{text}和非{text}分成不同部分，然后连续执行
        for i_, v_ in StrSplit(latexBlock, "##") {
            Send, %v_%
        }
    }else{
        Send, %latex%
    }
    return
}

loadTriggerHotKey()
{
    ; 动态创建触发热键
    ; https://www.autoahk.com/help/autohotkey/zh-cn/docs/commands/Hotkey.htm
    for i_ , v_ in getTriggerFirstChar() {
        ; ~ 表示触发热键时, 热键中按键原有的功能不会被屏蔽(对操作系统隐藏)
        Hotkey, ~%v_%, HotlatexHandler
    }
}

;-----------------------------------------------------------------------------
;    `Win + \`  进行 unicode模式 / latex助手模式 切换
;-----------------------------------------------------------------------------

#\::    ; 模式切换热键
global unicodeMode
if (not unicodeMode){
    unicodeMode := 0
}
unicodeMode := Mod(unicodeMode+1,2)
if unicodeMode {
    FollowToolTip("unicode模式", 1000)
}else{
    FollowToolTip("latex助手模式", 1000)
}
return

