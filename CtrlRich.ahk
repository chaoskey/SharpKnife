;@Ahk2Exe-SetProductName    Ctrl增强 
;@Ahk2Exe-SetProductVersion 2021.12.13
;@Ahk2Exe-SetDescription Ctrl增强 
;@Ahk2Exe-SetFileVersion    2021.12.13
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
    ; 桌面贴图及其索引 
    global screenPastes := []
    global activepaste := 0
    ; 跟随提示位置坐标(X,Y)（Ctrl按下和松开之间保持不变）
    global tooltipPosX
    global tooltipPosY
    ; 用于跟随提示的显示位图的句柄
    global hWNDToolTip := 0 

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
            clipHist.reset()
            ctrlCmd := ""
            working := False
            activepaste := 0
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
    global screenPastes ; 桌面贴图列表
    global activepaste ; 当前桌面贴图索引

    if (ctrlCmd = "vs"){
        ; 复原
        ctrlCmd := "v"
        clearToolTip()
        ; 显示下一个索引位置的clip
        clipHist.nextClip()
        showClip()
    }if (ctrlCmd = "vf"){
        ; 复原
        ctrlCmd := "v"
        clearToolTip()
        ; 显示上一个索引位置的clip
        clipHist.prevClip()
        showClip()
    }else if (ctrlCmd = "vd"){
        ; 复原
        ctrlCmd := "v"
        clearToolTip()
        ; 删除当前索引位置的clip
        clipHist.deleteClip()
    }else if (ctrlCmd = "va"){
        ; 复原
        ctrlCmd := "v"
        clearToolTip()
        ; 删除当前索引位置的clip
        clipHist.deleteClipAll()
    }else if (ctrlCmd = "vvs"){
        ; 复原
        ctrlCmd := "vv"
        clearToolTip()
        ; 闪烁下一张桌面贴图
        if (screenPastes.Length() > 1){
            activepaste := activepaste + 1
            if (activepaste > screenPastes.Length()){
                activepaste := 1
            }
            hWND := screenPastes[activepaste]
            RemoveToolTipFlash(hWND)
        }
    }else if (ctrlCmd = "vvf"){
        ; 复原
        ctrlCmd := "vv"
        clearToolTip()
        ; 闪烁上一张桌面贴图
        if (screenPastes.Length() > 1){
            activepaste := activepaste - 1
            if (activepaste < 1){
                activepaste := screenPastes.Length()
            }
            hWND := screenPastes[activepaste]
            RemoveToolTipFlash(hWND)
        }
    }else if (ctrlCmd = "vvd"){
        ; 复原
        ctrlCmd := "vv"
        clearToolTip()
        ; 删除当前桌面贴图
        hWND := screenPastes[activepaste]
        deletScreenPaste(hWND)
    }else if (ctrlCmd = "vva"){
        ; 复原
        ctrlCmd := "vv"
        clearToolTip()
        ; 清空所有桌面贴图
        clearScreenPastes()
    }

}

/*  
    Ctrl+命令 （Ctrl松开）
 
*/
execCtrlDownUPCmd(){
    global ctrlCmd ; Ctrl+命令

    if (ctrlCmd = "ve"){
        ; 消除已有提示信息
        clearToolTip()
        clipHist.moveClip()
        clip := Trim(clipboard, "`r`n")
        if (clip != "") {
            ; 进入当前剪切板编辑(只对文本内容进行编辑)
            tag := clipHist.getClipTag()
            if (tag != ""){
                tag := "[" tag "]"
            }
            follMultiLineEdit.show(tag clip, "saveTextToClipAndPaste")

        }
    } else if (ctrlCmd = "ss"){
        ; 消除已有提示信息
        clearToolTip()
        ; 进入搜索粘贴模式
        ; 只搜索剪切板中的文本内容
        ; 凡是搜索过的内容，都不会被“全部删除命令a”删除
        follSingleLineEdit.show("searchTextClipForPaste")
    } else if (ctrlCmd = "cc"){
        ; 消除已有提示信息
        clearToolTip()
        ; Ctrl+cc 截图复制（会出现跟随鼠标的坐标提示，鼠标左键“按下-移动-松开”完成截图复制）
        screenShot()
        clipHist.addClip()
    } else if (ctrlCmd = "vv"){
        ; 消除已有提示信息
        clearToolTip()
        ; Ctrl+vv 粘贴到屏幕(待贴图的内容会跟随鼠标移动，点击鼠标左键完成屏幕贴图)
        screenPaste() 
        clipHist.moveClip() 
    }else if (StrLen(ctrlCmd) = 1) {
        if (ctrlCmd = "c") or (ctrlCmd = "x"){
            clip1:=ClipboardAll ; 备份
            clipboard := ""   ; 清空剪贴板.
        }
        ; 保证拦截的“Ctrl+单字符命令”的系统原生功能不变
        Send, ^%ctrlCmd%
        if (ctrlCmd = "c")  or (ctrlCmd = "x") {
            ClipWait, 1 , 1  ; 等待剪贴板中出现数据.
            if (ErrorLevel = 1) {
                return
            }
            clip2 := ClipboardAll
            IF clip1 <> %clip2%
            {
                clipHist.addClip()
            }
        }else if (ctrlCmd = "v"){
            ; 消除已有提示信息
            clearToolTip()
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
    if hWNDToolTip {
        Gui, %hWNDToolTip%:Destroy
        hWNDToolTip := 0
    }
    ToolTip
}

/*
    显示当前clip 【无需同步】
*/
showClip(){
    pBitmap := Gdip_CreateBitmapFromClipboard()
    if (pBitmap < 0) {
        toolTipClip(Clipboard)
    }else{
        toolTipImage(pBitmap)
    }
}    

/*
    （文本）clip浏览提示
*/
toolTipClip(tooltip_){
    global tooltipPosX ; 跟随提示位置坐标X（Ctrl按下和松开之间保持不变）
    global tooltipPosY ; 跟随提示位置坐标Y（Ctrl按下和松开之间保持不变）
    
    tag := clipHist.getClipTag()
    if (tag != ""){
        tag := "[" tag "]"
    }
    tooltip_ := tag tooltip_
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
    ToolTip, %tooltip_%, %tooltipPosX%, %tooltipPosY%
}

/*
    （图片）clip浏览提示
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

/*
    桌面贴图闪动提示
*/
RemoveToolTipFlash(_hWND_){
    Loop 3
    {
        Gui, %_hWND_%:Hide
        Sleep 50
        Gui, %_hWND_%:Show
        Sleep 50
    }
}

/*
    截图复制
*/
screenShot(){
    ; 按住鼠标左键-移动鼠标-松开: 选择截图区域
    screen_ := SelectRegionFromScreen("LButton")
    ; 获取区域截图
    pBitmap := Gdip_BitmapFromScreen(screen_)
    ; 获取到Clipboard
    Gdip_SetBitmapToClipboard(pBitmap)
    ; 删除内存位图
    Gdip_DisposeImage(pBitmap)
    return 
}

/*
    粘贴到屏幕
*/
screenPaste(){
    global screenPastes ; 用于临时存储屏幕贴图的句柄列表

    ; 从Clipboard获取位图
    pBitmap := Gdip_CreateBitmapFromClipboard()
    if (pBitmap < 0 ){
        return -1
    }
    ; 贴图
	CoordMode, Mouse, Screen
    MouseGetPos, X, Y
    hWND := pasteImageToScreen(pBitmap, , X "," Y)
    screenPastes.Push(hWND)
    ; 删除内存位图
    Gdip_DisposeImage(pBitmap)
    ; 定位
    down_ := False
    loop{
        keyIsDown := GetKeyState("LButton" , "P")
        if keyIsDown {
            down_ := True
        } else if down_{
            break
        }
        MouseGetPos, X, Y
        ; 移动贴图
        WinMove, ahk_id %hWND%, , %X%, %Y%  
    }
    return hWND
}

/*
    清空所有屏幕贴图
*/
clearScreenPastes(){
    global screenPastes ; 桌面贴图列表
    global activepaste :=0 ; 当前桌面贴图索引

    if (not (not screenPastes)){
        for idx_, value_ in screenPastes {
            Gui, %value_%:Destroy
        }
    }
    screenPastes := []
}

/*
    删除指定屏幕贴图
*/
deletScreenPaste(hWND){
    global screenPastes ; 桌面贴图列表
    global activepaste ; 当前桌面贴图索引
    if (not (not screenPastes)){
        for idx_, value_ in screenPastes {
            if (value_ == hWND){
                Gui, %value_%:Destroy
                screenPastes.RemoveAt(idx_)
                Break
            }
        }
    }
    if (screenPaste.Length()==0){
        activepaste := 0
    }else if (activepaste > screenPaste.Length()){
        activepaste := 1
    }
}

; 进入搜索粘贴模式
; 只搜索单行文本剪切板内容，因为常用需要粘贴都是单行的
; 凡是搜索过的内容，都不会被“全部删除命令a”删除，但可以被“删除命令d”删除
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

; 搜索后选择后的粘贴处理
SearchPasteHandler(index){
    ; index 提示列表栏选择的序号
    global matchedSingleLineClipIndex ; 匹配到的所有单行文本在cliparray中的索引 
    
    ; 凡是搜索选择过的内容，都认为是比较重要的，所以特别添加到.clip\clip.tag中标记之 
    aclip := matchedSingleLineClipIndex[index]
    clipHist.setClipTag(aclip)
    ; 读入到剪切板
    clipHist.readClip(aclip)
    ; 主动将剪切板的内容粘贴
    Send, ^v
    ; 将选择的clip移到最新(并且读入到剪切板)
    clipHist.moveClip(aclip)
}

; 将文本内容保存到当前粘贴板，然后粘贴
saveTextToClipAndPaste(saveText){
    if clipHist.saveClip(saveText){
        ; 主动将剪切板的内容粘贴
        Send, ^v
        ; 将选择的clip移到最新(并且读入到剪切板)
        clipHist.moveClip()
    }
}

