;@Ahk2Exe-SetProductName    Ctrl增强 
;@Ahk2Exe-SetProductVersion 2021.12.16
;@Ahk2Exe-SetDescription Ctrl增强 
;@Ahk2Exe-SetFileVersion    2021.12.16
;@Ahk2Exe-SetCopyright @2021-2025
;@Ahk2Exe-SetLanguage 0x0804
;@Ahk2Exe-SetOrigFilename CtrlRich
;@Ahk2Exe-SetLegalTrademarks chaoskey
;@Ahk2Exe-SetCompanyName chaoskey
;@Ahk2Exe-SetMainIcon images\ctrl.ico

#SingleInstance, force

FileEncoding , UTF-8-RAW

#Include lib\util.ahk
#Include lib\ClipHistory.ahk
#Include lib\CustomGUI.ahk

; 托盘提示
Menu, Tray,Tip , Ctrl增强
if FileExist("images\ctrl.ico"){
    Menu, Tray, Icon, images\ctrl.ico
}

; 启动GDI+支持
startupGdip()
; Clip历史管理
global clipHist := new ClipHistory()
; 光标或鼠标跟随控件
global followList := new FollowListBox()
global follSingleLineEdit := new FollowSingleLineEdit()
global follMultiLineEdit := new FollowMultiLineEdit()
; 启动“Ctrl+命令”死循环
startCtrlCmdLoop()
return ; 自动运行段结束


/*
最终命令（RCtrl松开执行的命令）
    【系统复制】RCtrl + c
    【系统粘贴】RCtrl + v
    【系统剪切】RCtrl + x

    【截图复制】RCtrl + cc
        鼠标选择屏幕上任何矩形区域（先Ctrl+cc，后选择）
    【图片粘贴】RCtrl + vv
        鼠标选择粘贴屏幕任意位置，也可以将复制文本作为图片粘贴  （先Ctrl+cc，后选择）

Clipboard浏览管理（RCtrl未松开执行的命令）
    【下一个clip浏览】  RCtrl + vs(x)    如果以x结尾，则表示松开后也不执行（下同）
    【上一个clip浏览】  RCtrl + vf(x)
    【删除当前clip】       RCtrl + vd(x)
    【删除全部】           RCtrl + va(x)

贴图管理（Ctrl未松开执行的命令）
    【下一个贴图】  RCtrl + vvs(x)
    【上一个贴图】  RCtrl + vvf(x)
    【删除当前贴图】   RCtrl + vvd(x)
    【删除全部贴图】   RCtrl + vva(x)

组合命令（Ctrl松开后）
    RCtrl + c[a|s|d|f]*  = RCtrl + c
    RCtrl + v[a|s|d|f]*  = RCtrl + v
    RCtrl + c[a|s|d|f]*c  = RCtrl + cc
    RCtrl + v[a|s|d|f]*v  = RCtrl + vv
*/
$>^c::
$>^v::
$>^x::
$>^s::
$>^d::
$>^a::
$>^f::
$>^e::
$>^w::
$>^t::
RCtrlHandler()
return

/*  
    RCtrl+命令 拦截
*/
RCtrlHandler(){
    Critical

    global rctrlCmd ; RCtrl+命令
    if (not ctlCmd){
        ctlCmd := ""
    }
    c_ := SubStr(A_ThisHotkey, 4)
    rctrlCmd := rctrlCmd c_
    ; 等待c_对应的字母键松开（增强程序稳定性）
    KeyWait, %c_%
}

/* 
    “Ctrl+命令”处理之死循环
*/
startCtrlCmdLoop(){
    ; RCtrl+命令
    global rctrlCmd := ""
    ; 跟随提示位置坐标（Ctrl按下和松开之间保持不变）
    global tooltipPosX
    global tooltipPosY
    ; 用于跟随提示的显示位图的句柄
    global hWNDToolTip := 0 
    global runingSnipaste := False  ;  snipaste是否安装并启动
    global runingChrome := False     ;  谷歌浏览器是否安装并启动

    ; 【这段注释掉的代码含有如何运行PowerShell.exe中的命令? 如何启动Win商店版程序，具有参考价值】
    ; 启动Snipaste
    ; familyName := ""
    ; Clip_Saved:=ClipboardAll
    ; try{
    ;   Clipboard:=""
    ;   RunWait, PowerShell.exe -Command &{Get-AppxPackage -Name "*45479liulios*" | CLIP},, hide
    ;   ClipWait,2
    ;   familyName := Clipboard
    ;   ; PackageFamilyName : 45479liulios.17062D84F7C46_p7pnf6hceqser
    ;   if RegExMatch(familyName, "O)PackageFamilyName\s+:\s+(.+)\r?\n", SubPat) {
    ;       familyName := Trim(SubPat.Value(1))
    ;       Run, explorer shell:AppsFolder\%familyName%!Snipaste
    ;       runingSnipaste := True
    ; }
    ; }catch{}

    ; ini文件
    iniPath := A_ScriptFullPath
    if (idx := InStr(iniPath, "." , , 0) ){
        iniPath := SubStr(iniPath, 1 , idx-1)
    }
    iniPath := iniPath ".ini"
    ; 读取Snipaste.exe路径
    IniRead, snipastePath, %iniPath%, CtrlRich, snipaste
    iniError1 := (snipastePath == "ERROR")
    if iniError1 {
        snipastePath := "Snipaste.exe"
    }
    ; 读取浏览器路径
    IniRead, browserPath, %iniPath%, CtrlRich, browser
    iniError2 := (browserPath == "ERROR")
    if iniError2 {
        browserPath := "Google Chrome|Chrome.exe"
    }
    if iniError1 or iniError2 {
        IniWrite,
(
; 如果没有正确配置好，意味着对应的功能不被本程序（脚本）支持
; Snipaste.exe默认在PATH路径中，否则需要自行配置全路径 【无窗口】
snipaste=%snipastePath%
; 浏览器启动后的窗口标题|浏览器路径, 默认是谷歌浏览器并且在PATH路径中，否则需要自行配置全路径
; 目前谷歌浏览器和微软Edge浏览器已经通过测试
browser=%browserPath%
; 
), %iniPath%, CtrlRich
    }
    tmp1 := StrSplit(browserPath, "|")
    if (tmp1.Length() < 2){
        MsgBox, [CtrlRich]中的browser请按“浏览器启动后的窗口标题|浏览器路径”格式配置！
        ExitApp
    }
    browserWinTitle := tmp1[1]
    browserPath := tmp1[2]
    SplitPath, snipastePath , snipasteFileName
    SplitPath, browserPath , browserFileName

    ; 确保谷歌浏览器运行中(确保普通权限)
    Clip_Saved:=ClipboardAll
    Clipboard := ""
    Run, %comSpec% /c "tasklist | find /i "%browserFileName%" | CLIP",, hide
    ClipWait,2
    runingChrome := (Trim(Clipboard, " `t`r`n") != "")
    Clipboard:=Clip_Saved
    if (not runingChrome){
        Run, %browserPath% , , Hide UseErrorLevel
        runingChrome := (ErrorLevel != "ERROR")
        if (not runingChrome) {
            FollowToolTip(browserFileName "尚未安装或不在运行路径下，不支持其扩展功能！", 5000)
        }else {
            SetTitleMatchMode, 2 ; 临时改成部分匹配
            WinWait, %browserWinTitle%
            ; 类似于按下 Alt+F4 或点击窗口标题栏的关闭按钮的效果:
            PostMessage, 0x0112, 0xF060,,, %browserWinTitle%  ; 0x0112 = WM_SYSCOMMAND, 0xF060 = SC_CLOSE
            SetTitleMatchMode, 1 ; 恢复默认精确匹配
        }
    }

    ; 如果不是管理员身份脚本未提升，请以管理员身份终止当前实例并重新启动
    ; 之所以放这里，是因为前面的Chrome要求用普通权限运行
    full_command_line := DllCall("GetCommandLine", "str")

    if not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))
    {
        try ; 导致脚本以管理员身份重新启动
        {
            if A_IsCompiled
                Run *RunAs "%A_ScriptFullPath%" /restart
            else
                Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"
        }
        ExitApp
    }

    ; 确保Snipaste运行中(确保管理员权限)
    Clip_Saved:=ClipboardAll
    Clipboard := ""
    Run, %comSpec% /c "tasklist | find /i "%snipasteFileName%" | CLIP",, hide
    ClipWait,2
    runingSnipaste := (Trim(Clipboard, " `t`r`n") != "")
    Clipboard:=Clip_Saved
    if (not runingSnipaste){
        Run, %snipastePath% , , UseErrorLevel
        runingSnipaste := (ErrorLevel != "ERROR")
        if (not runingSnipaste) {
            FollowToolTip("Snipaste尚未安装或不在运行路径下，不支持截图和贴图的功能！", 5000)
        }
    }

    working := False
    SetBatchLines, 10ms
    loop{
        if (not working){
            ; 等待CTRL按下
            KeyWait, Control, D
        }
        keyIsDown := GetKeyState("RCTRL" , "P")
        if keyIsDown{
            if (not working){
                ; 进入工作状态
                working := True
                SetBatchLines -1
            }
            ; RCtrl+命令 （RCtrl未松开）
            execCtrlDownCmd()
        }else if working {
            ; RCtrl+命令 （RCtrl松开）
            execCtrlDownUPCmd()
            ; 工作完成，状态复原
            working := False
            clipHist.reset()
            rctrlCmd := ""
            tooltipPosX := 
            tooltipPosY :=
            SetBatchLines, 10ms
        }
    }
}

/*  
    RCtrl+命令 （RCtrl未松开）
*/
execCtrlDownCmd(){
    global rctrlCmd ; RCtrl+命令

    if (rctrlCmd = "vs") or (rctrlCmd = "vvs"){  ; 显示下一个clip
        rctrlCmd := SubStr(rctrlCmd, 1 , -1)
        clearToolTip()
        clipHist.nextClip()
        showClip()
        return
    }
    if (rctrlCmd = "vf")  or (rctrlCmd = "vvf"){  ; 显示上一个clip
        rctrlCmd := SubStr(rctrlCmd, 1 , -1)
        clearToolTip()
        clipHist.prevClip()
        showClip()
        return
    }
    if (rctrlCmd = "vd")  or (rctrlCmd = "vvd"){  ; 删除当前clip
        rctrlCmd := SubStr(rctrlCmd, 1 , -1)
        clearToolTip()
        clipHist.deleteClip()
        return
    }
    if (rctrlCmd = "va")  or (rctrlCmd = "vva"){ ; 删除所有clip
        rctrlCmd := SubStr(rctrlCmd, 1 , -1)
        clearToolTip()
        clipHist.deleteClipAll()
        return
    }
}

/*  
    RCtrl+命令 （RCtrl松开）
*/
execCtrlDownUPCmd(){
    global rctrlCmd ; RCtrl+命令
    global runingSnipaste  ;  snipaste是否安装并启动
    global runingChrome  ;  Chrome是否安装并启动

    ; 沙拉查词-独立查词窗口， 命令不妨取 RCtrl-wf
    ; 如果没有选择，则弹出空的查词窗口
    ; 如果选择了，则对当前所选内容查词
    if (rctrlCmd = "wf"){
        clearToolTip()
        if runingChrome{
            ; 先复制
            clip1 := ClipboardAll
            Clipboard := ""
            Send, ^c
            ClipWait, 1 , 1  ; 等待剪贴板中出现数据.
            if (ErrorLevel = 0) {
                StringReplace, clipboard, clipboard, `r, , All
                StringReplace, clipboard, clipboard, `n, , All
                clip2 :=  ClipboardAll
                IF clip1 <> %clip2%
                {
                    clipHist.addClip()
                }
                Send, ^+2
            }else{
                Send, ^+2
                WinWaitActive, 沙拉查词-独立查词窗口
                Clipboard := clip1
            }
        }
        return
    }
    ; 独立翻译窗口 - 划词翻译， 命令不妨取 RCtrl-ff
    ; 如果没有选择，则弹出空的翻译窗口
    ; 如果选择了，则翻译当前所选内容
    if (rctrlCmd = "ff"){
        clearToolTip()
        if runingChrome{
            ; 先复制
            clip1 := ClipboardAll
            Clipboard := ""
            Send, ^c
            ClipWait, 1 , 1  ; 等待剪贴板中出现数据.
            if (ErrorLevel = 0) {
                StringReplace, clipboard, clipboard, `r, , All
                StringReplace, clipboard, clipboard, `n, , All
                clip2 :=  ClipboardAll
                IF clip1 <> %clip2%
                {
                    clipHist.addClip()
                }
                Send, ^+1
            }else{
                Send, ^+1
                WinWaitActive, 独立翻译窗口 - 划词翻译
                Clipboard := clip1
            }
        }
        return
    }
    if (rctrlCmd = "ct"){  ; 修改当前剪切板(c)标签(t) , 所以命令取: RCtrl-ct
        clearToolTip()
        follSingleLineEdit.show(clipHist.getClipTag(), "setClipTag", clipHist)
        return
    }
    if (rctrlCmd = "ww"){  ; 进入白板(w)模式, 所以命令取: RCtrl-ww
        clearToolTip()
        if runingSnipaste {
            SnipasteWhiteboard()
        }
        return
    }
    if (rctrlCmd = "ce"){  ; 只对文本剪切板(c)编辑(e), 所以命令取: RCtrl-ce
        clearToolTip()
        clipHist.moveClip()
        clip := Trim(clipboard, "`r`n")
        if (clip != "") {
            tag := clipHist.getClipTag()
            if (tag != ""){
                tag := "[" tag "]"
            }
            follMultiLineEdit.show(tag clip, "saveTextToClipAndPaste")
        }
        return
    }
    if (rctrlCmd = "sv"){  ; 进入搜索(s)粘贴(v)模式, 所以命令取: RCtrl-sv
        clearToolTip()
        follSingleLineEdit.show("", "searchTextClipForPaste")
        return
    }
    if (rctrlCmd = "cc"){ ; RCtrl+cc 截图复制, 命令取: RCtrl-cc 表示加强版复制
        clearToolTip()
        if runingSnipaste {
            SnipasteS()
        }
        return
    }
    if (rctrlCmd = "vv"){  ; RCtrl+vv 粘贴到屏幕, 命令取: RCtrl-vv 表示加强版复制粘贴
        clearToolTip()
        if runingSnipaste {
            SnipasteP()
        }
        return
    }
    if (rctrlCmd = "cv"){  ; RCtrl+cv 先截图复制(c)然后直接粘贴(v)到屏幕上, 所以命令取: RCtrl-cv 
        clearToolTip()
        if runingSnipaste {
            SnipasteSP()
        }
        return
    }
    if (StrLen(rctrlCmd) = 1) {  ; 保证拦截的“Ctrl+单字符命令”的系统原生功能不变
        if (rctrlCmd = "c") or (rctrlCmd = "x"){  ; 复制剪切前清空剪贴板，方便后续判定
            clip1:=ClipboardAll
            clipboard := ""
        }else if (rctrlCmd = "v"){
            clearToolTip()
        }
        Send, ^%rctrlCmd%
        if (rctrlCmd = "c")  or (rctrlCmd = "x") { ; 如果新内容，则新加一条历史记录
            ClipWait, 1 , 1  ; 等待剪贴板中出现数据.
            if (ErrorLevel = 1) {
                return
            }
            clip2 := ClipboardAll
            IF clip1 <> %clip2%
            {
                clipHist.addClip()
            }
            return
        }if (rctrlCmd = "v"){ ; 粘贴后的记录作为最新记录
            clipHist.moveClip()
            return
        }
        return
    }
    if (SubStr(rctrlCmd, 0) = "x"){ ; 放弃(x)原本的动作，所以: RCtrl-[cvxsdafewt]+x 表示放弃
        clearToolTip()
        return
    }
    ; 其它的情况无动作
}

/* 
清空已有提示 
*/
clearToolTip(){
    global hWNDToolTip ; 用于跟随提示的显示位图的句柄
    global runingSnipaste  ;  snipaste是否安装并启动

    if (not hWNDToolTip) {
        ToolTip
        return
    }
    if (not runingSnipaste){
        Gui, %hWNDToolTip%:Destroy
        hWNDToolTip := 0
        return
    }

    ; 关闭贴图（确保贴图在激活状态下发送Snipaste内置快捷键`Shift+ESC`销毁贴图）
    WinActivate , ahk_id %hWNDToolTip%
    WinWaitActive , ahk_id %hWNDToolTip%
    hWND := WinExist("A")
    Send +{ESC}
    WinWaitNotActive, ahk_id %hWND%
    hWNDToolTip := 0
}

/*
    显示当前剪切板内容
*/
showClip(){
    global runingSnipaste  ;  snipaste是否安装并启动

    if runingSnipaste {
        toolTipSnipaste()
    }else {
        pBitmap := Gdip_CreateBitmapFromClipboard()
        if (pBitmap < 0) {
            toolTipClip(Clipboard)
        }else{
            toolTipImage(pBitmap)
        }
    }
}    

/*
    文本跟随提示
*/
toolTipClip(tooltip_){
    global tooltipPosX ; 跟随提示位置坐标X（Ctrl按下和松开之间保持不变）
    global tooltipPosY ; 跟随提示位置坐标Y（Ctrl按下和松开之间保持不变）
    
    tag := clipHist.getClipTag()
    if (tag != ""){
        tag := "[" tag "]"
    }
    clip := tag tooltip_
    if (not tooltipPosX){
        ; 当前光标或鼠标位置
        CoordMode, Caret, Screen
        if (not A_CaretX){
            CoordMode, Mouse, Screen
            MouseGetPos, tooltipPosX, tooltipPosY
            tooltipPosX := tooltipPosX + 10
        }else {
            tooltipPosX := A_CaretX
            tooltipPosY := A_CaretY + 20
        }
    }
    CoordMode, ToolTip, Screen
    ToolTip, %clip%, %tooltipPosX%, %tooltipPosY%
}

/*
    图片跟随提示
*/
toolTipImage(pBitmap){
    global tooltipPosX ; 跟随提示位置坐标X（Ctrl按下和松开之间保持不变）
    global tooltipPosY ; 跟随提示位置坐标Y（Ctrl按下和松开之间保持不变）
    global hWNDToolTip ; 用于跟随提示的显示位图的句柄

    if (not tooltipPosX){
        ; 当前光标或鼠标位置
        CoordMode, Caret, Screen
        if (not A_CaretX){
            CoordMode, Mouse, Screen
            MouseGetPos, tooltipPosX, tooltipPosY
            tooltipPosX := tooltipPosX + 10
        }else {
            tooltipPosX := A_CaretX
            tooltipPosY := A_CaretY + 20
        }
    }
    ; 贴图
    ;scale := "h" A_ScreenHeight*0.2
    hWNDToolTip := pasteImageToScreen(pBitmap, , tooltipPosX "," tooltipPosY) ;, , scale)
    Gdip_DisposeImage(pBitmap)
}

; 利用Snipaste进行剪切板浏览
toolTipSnipaste(){
    global tooltipPosX ; 跟随提示位置坐标X（Ctrl按下和松开之间保持不变）
    global tooltipPosY ; 跟随提示位置坐标Y（Ctrl按下和松开之间保持不变）
    global hWNDToolTip ; 用于跟随提示的显示位图的句柄

    if (not tooltipPosX){
        ; 当前光标或鼠标位置
        CoordMode, Caret, Screen
        if (not A_CaretX){
            CoordMode, Mouse, Screen
            MouseGetPos, tooltipPosX, tooltipPosY
            tooltipPosX := tooltipPosX + 10
        }else {
            tooltipPosX := A_CaretX
            tooltipPosY := A_CaretY + 20
        }
    }
    tag := clipHist.getClipTag()
    if (tag != ""){
        tag := "[" tag "]"
    }
    ; 判断剪切板是否是文本
    isText := False
    if (tag != "") {
        Ptr := A_PtrSize ? "UPtr" : "UInt"
        if DllCall("IsClipboardFormatAvailable", "uint", 1){
            DllCall("OpenClipboard", Ptr, 0)
            isText := (not (not DllCall("GetClipboardData", "uint", 1, Ptr)))
            DllCall("CloseClipboard")
        }
    }
    ; 贴图，确保获取贴图句柄
    oldclip := ClipboardAll
    if (tag != "") and isText{
        Clipboard := tag Clipboard
    }
    RunWait, % "Snipaste paste --clipboard --pos " tooltipPosX " " tooltipPosY
    ; 如果被浏览的clip和桌面已有贴图内容重复，会闪烁后处于非激活状态
    ; 所以必须设置超时时间，假设2s等待激活超时，就是遇到了这种情况
    WinWaitActive, Paster - Snipaste , , 2
    ; 无论是否超时，这个贴图对应的窗口已经存在，所以可以直接获取窗口句柄
    ; 并且这个贴图是最近激活过的，所以不会错误获取桌面其它已有的无关贴图窗口句柄
    hWNDToolTip := WinExist("Paster - Snipaste")
    Clipboard := oldclip
}

/*
 进入搜索粘贴模式
 只搜索单行文本剪切板内容，因为常用需要粘贴都是单行的
 凡是搜索过的内容，都不会被“全部删除命令a”删除，但可以被“删除命令d”删除
*/
searchTextClipForPaste(search){
    global matchedSingleLineClip := [] ; 匹配到的所有单行文本
    global matchedSingleLineClipIndex :=[] ; 匹配到的所有单行文本在cliparray中的索引

    ; 空值无动作
    if (Trim(search) == ""){
        return
    }
    ; 搜索
    clipHist.searchClip(matchedSingleLineClip, matchedSingleLineClipIndex, search)
    ; 弹出建议窗口
    if (matchedSingleLineClip.Length() > 0)
    {
        ; 弹出提示窗口
        followList.show(matchedSingleLineClip, "SearchPasteHandler")
    }
}

/*
 搜索后选择后的粘贴处理
*/
SearchPasteHandler(index){
    ; index 提示列表栏选择的序号
    global matchedSingleLineClipIndex ; 匹配到的所有单行文本在cliparray中的索引 
    
    ; 凡是搜索选择过的内容，都认为是比较重要的，所以特别添加到.clip\clip.tag中标记之 
    aclip := matchedSingleLineClipIndex[index]
    tag := clipHist.getClipTag(aclip)
    if (tag = ""){
        tag := "★"
    }
    clipHist.setClipTag(tag, aclip)
    ; 读入到剪切板
    clipHist.readClip(aclip)
    ; 主动将剪切板的内容粘贴
    Send, ^v
    ; 将选择的clip移到最新(并且读入到剪切板)
    clipHist.moveClip(aclip)
}

/*
 将文本内容保存到当前粘贴板，然后粘贴
*/
saveTextToClipAndPaste(saveText){
    if clipHist.saveClip(saveText){
        ; 主动将剪切板的内容粘贴
        Send, ^v
        ; 将选择的clip移到最新(并且读入到剪切板)
        clipHist.moveClip()
    }
}

; 【基于Snipaste】鼠标选择截图 或 点击窗口截图  到 剪切板
SnipasteS(){
    oldClip := clipboardAll
    Run, % "Snipaste snip -o clipboard"
    ; 先等待操作窗口激活，再等待该窗口消失，这个动作才算完成
    ; 无论什么情况返回，如果剪切板有变化，则添加到clip历史记录中
    WinWaitActive, Snipper - Snipaste
    hWND := WinExist("A")
    WinWaitNotActive, ahk_id %hWND%
    newClip := clipboardAll
    IF oldClip <> %newClip%
    {
        clipHist.addClip()
    }
}

; 【基于Snipaste】鼠标选择截图 或 点击窗口截图  到 剪切板
SnipasteP(){
    Run, % "Snipaste paste --clipboard"
    clipHist.moveClip()
}

; 【基于Snipaste】截图后直接贴图
SnipasteSP(){
    oldClip := clipboardAll
    Run, % "Snipaste snip -o clipboard"
    ; 先等待操作窗口激活，再等待该窗口消失，这个动作才算完成
    ; 无论什么情况返回，如果剪切板有变化，则添加到clip历史记录中
    WinWaitActive, Snipper - Snipaste
    hWND := WinExist("A")
    WinWaitNotActive, ahk_id %hWND%
    newClip := clipboardAll
    IF oldClip <> %newClip%
    {
        clipHist.addClip()
        Run, % "Snipaste paste --clipboard"
    }
}

; 【基于Snipaste】启动白板
SnipasteWhiteboard(){
    oldClip := clipboardAll
    Run, Snipaste whiteboard
    ; 先等待操作窗口激活，再等待该窗口消失，这个动作才算完成
    ; 无论什么情况返回，如果剪切板有变化，则添加到clip历史记录中
    WinWaitActive, Snipper - Snipaste
    hWND := WinExist("A")
    WinWaitNotActive, ahk_id %hWND%
    newClip := clipboardAll
    IF oldClip <> %newClip%
    {
        clipHist.addClip()
    }
}

