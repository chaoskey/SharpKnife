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
最终命令（Ctrl松开执行的命令）
    【系统复制】Ctrl + c    
    【系统粘贴】Ctrl + v
    【系统剪切】Ctrl + x

    【截图复制】Ctrl + cc    
        鼠标选择屏幕上任何矩形区域（先Ctrl+cc，后选择）
    【图片粘贴】Ctrl + vv
        鼠标选择粘贴屏幕任意位置，也可以将复制文本作为图片粘贴  （先Ctrl+cc，后选择）

Clipboard浏览管理（Ctrl未松开执行的命令）
    【下一个clip浏览】  Ctrl + vs(x)    如果以x结尾，则表示松开后也不执行（下同）
    【上一个clip浏览】  Ctrl + vf(x)
    【删除当前clip】       Ctrl + vd(x)
    【删除全部】           Ctrl + va(x)

贴图管理（Ctrl未松开执行的命令）
    【下一个贴图】  Ctrl + vvs(x)
    【上一个贴图】  Ctrl + vvf(x)
    【删除当前贴图】   Ctrl + vvd(x)
    【删除全部贴图】   Ctrl + vva(x)

组合命令（Ctrl松开后）
    Ctrl + c[a|s|d|f]*  = Ctrl + c      
    Ctrl + v[a|s|d|f]*  = Ctrl + v
    Ctrl + c[a|s|d|f]*c  = Ctrl + cc
    Ctrl + v[a|s|d|f]*v  = Ctrl + vv
*/
$^c::
$^v::
$^x::
$^s::
$^d::
$^a::
$^f::
$^e::
$^w::
$^t::
CtrlHandler()
return

/*  
    Ctrl+命令 拦截
*/
CtrlHandler(){
    global ctrlCmd ; Ctrl+命令
    if (not ctlCmd){
        ctlCmd := ""
    }
    ctrlCmd := ctrlCmd SubStr(A_ThisHotkey, 3) 
}

/* 
    “Ctrl+命令”处理之死循环
*/
startCtrlCmdLoop(){
    ; Ctrl+命令
    global ctrlCmd := ""
    ; 跟随提示位置坐标（Ctrl按下和松开之间保持不变）
    global tooltipPosX
    global tooltipPosY
    ; 用于跟随提示的显示位图的句柄
    global hWNDToolTip := 0 
    global snipaste := False  ;  snipaste是否安装并启动

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
    ;       snipaste := True
    ; }
    ; }catch{}

    ; 判断Snipaste进程存在否，如果不存在尝试启动之
    Clip_Saved:=ClipboardAll
    execSnipaste := False ; 是否尝试执行过Snipaste
    Loop, 10  ; 大概10s钟内没启动Snipaste， 可认为没有安装Snipaste或不在运行路径(PATH)中
    {
        try{
            Clipboard := ""
            RunWait, %comSpec% /c "tasklist | find /i "snipaste" | CLIP",, hide
            ClipWait,2
            snipaste := (Trim(Clipboard, " `t`r`n") != "")
            if snipaste {
                break
            }
            if (not execSnipaste){
                Run, Snipaste.exe
                execSnipaste := True
            }
            Sleep, 1000
        }catch{
            break
        }
    }
	Clipboard:=Clip_Saved
    if (not snipaste) {
        FollowToolTip("Snipaste尚未安装或不在运行路径下，不支持截图和贴图的功能！", 5000)
    }

    working := False
    loop{
        if (not working){
            ; 等待CTRL按下
            KeyWait, Control, D
        }
        keyIsDown := GetKeyState("CTRL" , "P")
        if keyIsDown{
            ; 进入工作状态
            working := True
            ; Ctrl+命令 （Ctrl未松开）
            execCtrlDownCmd()
        }else if working {
            ; Ctrl+命令 （Ctrl松开）
            execCtrlDownUPCmd()
            ; 工作完成，状态复原
            working := False
            clipHist.reset()
            ctrlCmd := ""
            tooltipPosX := 
            tooltipPosY :=
        }
    }
}

/*  
    Ctrl+命令 （Ctrl未松开）
*/
execCtrlDownCmd(){
    global ctrlCmd ; Ctrl+命令

    if (ctrlCmd = "vs") or (ctrlCmd = "vvs"){  ; 显示下一个clip
        ctrlCmd := SubStr(ctrlCmd, 1 , -1)
        clearToolTip()
        clipHist.nextClip()
        showClip()
    }if (ctrlCmd = "vf")  or (ctrlCmd = "vvf"){  ; 显示上一个clip
        ctrlCmd := SubStr(ctrlCmd, 1 , -1)
        clearToolTip()
        clipHist.prevClip()
        showClip()
    }else if (ctrlCmd = "vd")  or (ctrlCmd = "vvd"){  ; 删除当前clip
        ctrlCmd := SubStr(ctrlCmd, 1 , -1)
        clearToolTip()
        clipHist.deleteClip()
    }else if (ctrlCmd = "va")  or (ctrlCmd = "vva"){ ; 删除所有clip
        ctrlCmd := SubStr(ctrlCmd, 1 , -1)
        clearToolTip()
        clipHist.deleteClipAll()
    }
}

/*  
    Ctrl+命令 （Ctrl松开）
*/
execCtrlDownUPCmd(){
    global ctrlCmd ; Ctrl+命令
    global snipaste  ;  snipaste是否安装并启动

    if (ctrlCmd = "vx") or (ctrlCmd = "vvx"){ ; 控制命令执行后补敲字符X，表示放弃系统粘贴或贴图
        clearToolTip()
    } else if (ctrlCmd = "tt"){  ; 修改当前剪切板标签
        clearToolTip()
        follSingleLineEdit.show(clipHist.getClipTag(), "setClipTag", clipHist)
    }  else if (ctrlCmd = "ww"){  ; 进入白板模式
        clearToolTip()
        if snipaste {
            SnipasteWhiteboard()
        }
    } else if (ctrlCmd = "ve"){  ; 进入当前剪切板编辑(只对文本内容进行编辑)
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
    } else if (ctrlCmd = "ss"){  ; 进入搜索粘贴模式
        clearToolTip()
        follSingleLineEdit.show("", "searchTextClipForPaste")
    } else if (ctrlCmd = "cc"){ ; Ctrl+cc 截图复制
        clearToolTip()
        if snipaste {
            SnipasteS()
        }
    }else if (ctrlCmd = "vv"){  ; Ctrl+vv 粘贴到屏幕
        clearToolTip()
        if snipaste {
            SnipasteP()
        }
    }else if (ctrlCmd = "cv"){  ; Ctrl+cv 先截图然后直接粘贴到屏幕上
        clearToolTip()
        if snipaste {
            SnipasteSP()
        }
    }else if (StrLen(ctrlCmd) = 1) {  ; 保证拦截的“Ctrl+单字符命令”的系统原生功能不变
        if (ctrlCmd = "c") or (ctrlCmd = "x"){  ; 复制剪切前清空剪贴板，方便后续判定
            clip1:=ClipboardAll
            clipboard := ""
        }else if (ctrlCmd = "v"){
            clearToolTip()
        }
        Send, ^%ctrlCmd%
        if (ctrlCmd = "c")  or (ctrlCmd = "x") { ; 如果新内容，则新加一条历史记录
            ClipWait, 1 , 1  ; 等待剪贴板中出现数据.
            if (ErrorLevel = 1) {
                return
            }
            clip2 := ClipboardAll
            IF clip1 <> %clip2%
            {
                clipHist.addClip()
            }
        }else if (ctrlCmd = "v"){ ; 粘贴后的记录作为最新记录
            clipHist.moveClip()       
        }
    }
    ; 其它的情况无动作
}

/* 
清空已有提示 
*/
clearToolTip(){
    global hWNDToolTip ; 用于跟随提示的显示位图的句柄
    global snipaste  ;  snipaste是否安装并启动
    if hWNDToolTip {
        if snipaste {
            ; 关闭贴图（确保贴图在激活状态下发送Snipaste内置快捷键`Shift+ESC`销毁贴图）
            WinActivate , ahk_id %hWNDToolTip%
            WinWaitActive , ahk_id %hWNDToolTip%, , 2
            Send +{ESC}
            WinWaitNotActive , ahk_id %hWNDToolTip%, , 5
            if (ErrorLevel = 1){
                MsgBox,
(
Snipaste以管理员状态运行，而本程序以非管理状态运行，程序无法继续！`n
要么，请将Snipaste改为非管理员状态运行；【建议】
要么，请将本程序改为管理员状态运行。
总之，必须保证本程序和Snipaste的管理员状态一致。`n
点击确认，程序将退出，务必设置好后重新启动本程序！
)
                ExitApp
            }
        }else{
            Gui, %hWNDToolTip%:Destroy
        }
        hWNDToolTip := 0
    }else if (not snipaste) {
        ToolTip
    }
}

/*
    显示当前剪切板内容
*/
showClip(){
    global snipaste  ;  snipaste是否安装并启动

    if snipaste {
        toolTipSnipaste()
    }else{
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
    ; 贴图，并在确保激活状态下获取贴图句柄
    hOldWND := WinExist("A")
    if (tag = "") or (not isText){
        RunWait, % "Snipaste paste --clipboard --pos " tooltipPosX " " tooltipPosY
    }else{
        oldclip := ClipboardAll
        Clipboard := tag Clipboard
        RunWait, % "Snipaste paste --clipboard --pos " tooltipPosX " " tooltipPosY
        Clipboard := oldclip
    }
    WinWaitNotActive , ahk_id %hOldWND%, , 2
    WinWaitActive , Paster - Snipaste, , 2
    hWNDToolTip := WinExist("A")
}

/*
 进入搜索粘贴模式
 只搜索单行文本剪切板内容，因为常用需要粘贴都是单行的
 凡是搜索过的内容，都不会被“全部删除命令a”删除，但可以被“删除命令d”删除
*/
searchTextClipForPaste(search){
    global matchedSingleLineClip := [] ; 匹配到的所有单行文本
    global matchedSingleLineClipIndex :=[] ; 匹配到的所有单行文本在cliparray中的索引
    
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
    clipboard := "" ; 清空剪贴板
    Run, % "Snipaste snip -o clipboard"
    ClipWait, , 1
    clipHist.addClip()
}

; 【基于Snipaste】鼠标选择截图 或 点击窗口截图  到 剪切板
SnipasteP(){
    Run, % "Snipaste paste --clipboard"
    clipHist.moveClip()
}

; 【基于Snipaste】截图后直接贴图
SnipasteSP(){
    ; 鼠标选择截图 或 点击窗口截图  到 剪切板
    clipboard := "" ; 清空剪贴板
    Run, % "Snipaste snip -o clipboard"
    ClipWait, , 1
    clipHist.addClip()
    ; 鼠标选择截图 或 点击窗口截图  到 剪切板
    Run, % "Snipaste paste --clipboard"
}

; 【基于Snipaste】启动白板
SnipasteWhiteboard(){
    clip1:=ClipboardAll
    clipboard := ""
    Run, Snipaste whiteboard
    ; 等候白板启动后再关闭
    WinWaitActive , Snipper - Snipaste, , 2
    WinWaitNotActive , Snipper - Snipaste, , 2
    ClipWait, 1 , 1  ; 等待剪贴板中出现数据.
    new_ := False
    if (ErrorLevel != 1) {
        clip2 := ClipboardAll
        IF clip1 <> %clip2%
        {
            ; 如果白板被复制，则作为历史保存
            clipHist.addClip()
            new_ := True
        }
    }
    if (not new_){
        ;没有新的剪切数据，则复原
        Clipboard := clip1
    }
}

