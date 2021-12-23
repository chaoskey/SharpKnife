
/*
    估算多行文本所占像素宽高

ByRef width  返回值:  像素宽
ByRef height 返回值:  像素高
texts 多行文本
https://www.autoahk.com/help/autohotkey/zh-cn/docs/commands/Gui.htm#Font
Options := "s10"  字体选项
FontName := "Courier New"  字体名称
*/
getTextsWidthHeight(ByRef width, ByRef height, texts, Options := "s10", FontName := "Courier New"){
    global tmpedit

    rows := 0
    Loop, parse, texts, `n, `r  ; 在 `r 之前指定 `n, 这样可以同时支持对 Windows 和 Unix 文件的解析.
    {
        rows := rows + 1
    }
    if (rows = 0) or (StrLen(texts) = 0) {
        width := 0
        height := 0
        return
    }
    ; 创建一个临时控件（用于获取字符串的实际像素长宽）, 用完后立刻销毁
    Gui, TmpGui:New
    Gui, TmpGui:Font, %Options%, %FontName%
    Gui, TmpGui:Add, Edit, x0 y0 r%rows% -Wrap -VScroll -HScroll vtmpedit,  %texts%
    Gui, TmpGui:-Caption +ToolWindow +AlwaysOnTop +LastFound
    GuiControlGet, tmp, Pos , tmpedit
    width := tmpW
    height := tmpH
    Gui, TmpGui:Destroy
}

/*
    估算文本列表所占像素宽高

ByRef width  返回值:  像素宽
ByRef height 返回值:  像素高
ByRef texts 返回值:  多行文本
textList 文本列表
https://www.autoahk.com/help/autohotkey/zh-cn/docs/commands/Gui.htm#Font
Options := "s10"  字体选项
FontName := "Courier New"  字体名称
*/
getTextListWidthHeight(ByRef width, ByRef height, ByRef texts, textList , Options := "s10", FontName := "Courier New"){
    texts := ""
    for i_, v_ in textList{
        texts := texts v_ "`n"
    }
    texts := Trim(texts, "`r`n")
    getTextsWidthHeight(width, height, texts, Options, FontName)
}

/*
    光标或鼠标跟随提示

text_ 提示内容
timeout(ms) 超时消失 ，如果 <=0 表示不消失
*/
FollowToolTip(text_, timeout)
{
    ; 当前光标或鼠标位置
    CoordMode, Caret, Screen
    if (not A_CaretX){
        CoordMode, Mouse, Screen
        MouseGetPos, posX, posY
        posX := posX + 10
    }else {
        posX := A_CaretX
        posY := A_CaretY + 20
    }
    CoordMode, ToolTip, Screen
    ToolTip, %text_%, %posX%, %posY%
    if (timeout > 0){
        SetTimer, RemoveFollowToolTip, -%timeout%
    }
}

RemoveFollowToolTip(){
    ToolTip
}

/*
    光标或鼠标跟随列表框

用到此函数族的功能块： LaTeXHelper.ahk CtrlRich.ahk
*/
class FollowListBox
{
    wndGui :=           ; 窗口句柄
    wndControl :=       ; 控件句柄
    callbackFun :=      ; 回调函数
    fontOptions :=      ; 字体选项
    fontName :=         ; 字体名

    __New(fontOptions := "s10", fontName := "Courier New"){
        this.fontOptions := fontOptions
        this.fontName := fontName
        ; 将成员函数绑定成函数对象
        fnCompleteAction := ObjBindMethod(this, "CompleteAction")
        fnLButtonHandler := ObjBindMethod(this, "LButtonHandler")
        fnUpHanler := ObjBindMethod(this, "UpHanler")
        fnDownHanler := ObjBindMethod(this, "DownHanler")
        ; 创建列表窗口获取窗口和控件句柄
        Gui, New
        Gui, Font, %fontOptions%, %fontName%
        Gui, +Delimiter`n
        Gui, Add, ListBox, x0 y0 0x100 -VScroll -HScroll HwndwndControl AltSubmit  
        Gui, -Caption +ToolWindow +AlwaysOnTop +LastFound
        Gui, +HwndwndGui
        this.wndGui := wndGui
        this.wndControl := wndControl
        ; 绑定控件g函数
        GuiControl, +g, %wndControl% , % fnCompleteAction
        ; 确保窗口大小和控件大小一样
        GuiControlGet, tmp, Pos , %wndControl%
        Gui, Show, w%tmpW% h%tmpH% Hide
        Gui, %wndGui%:Hide
        ; 提示窗口热键处理
        Hotkey, IfWinExist, ahk_id %wndGui% ahk_class AutoHotkeyGUI
        Hotkey, ~LButton, % fnLButtonHandler
        Hotkey, Up, % fnUpHanler
        Hotkey, Down, % fnDownHanler
        Hotkey, Tab, % fnCompleteAction
        Hotkey, Enter, % fnCompleteAction
        Hotkey, IfWinExist
    }

    show(textList, callbackFun, obj := False, minWH := "100,20", maxWH := "600,200"){
        ; textList              ; 文本列表
        ; callbackFun(index)    ; 回调函数，index是从列表数据已选索引

        ; 参数处理
        if obj {
            this.callbackFun := ObjBindMethod(obj, callbackFun)
        }else{
            this.callbackFun := Func(callbackFun)
        }

        minWH := StrSplit(minWH, ",")
        maxWH := StrSplit(MaxWH, ",")
        ; 准备列表数据，并计算窗口的长宽
        getTextListWidthHeight(width, height, texts, textList , this.fontOptions, this.fontName)
        width := Min(Max(width,minWH[1]),maxWH[1])
        height := Min(Max(height,minWH[2]),maxWH[2])
        ; 当前光标或鼠标位置
        CoordMode, Caret, Screen
        if (not A_CaretX){
            CoordMode, Mouse, Screen
            MouseGetPos, posX, posY
            posX := posX + 10
        }else {
            posX := A_CaretX
            posY := A_CaretY + 20
        }
        if (posX + width > A_ScreenWidth) {
            posX := posX - width
        }
        if (posY + height > A_ScreenHeight) {
            posY := posY - height
        }
        ; 窗口显示
        Gui, % this.wndGui ":Default"
        if (texts = ""){
            Gui, % this.wndGui ":Hide"
            return
        }
        GuiControl,, % this.wndControl , `n%texts%
        GuiControl, Choose, % this.wndControl , 1
        GuiControl, Move, % this.wndControl , w%width% h%height% ;设置控件宽高
        Gui, Show, x%posX% y%posY% w%width% h%height% ;  NoActivate
    }

    CompleteAction(){
        Critical

        ; {enter} {tab}   或 双击匹配项  触发粘贴
        If (A_GuiEvent != "" && A_GuiEvent != "DoubleClick")
            Return

        Gui, % this.wndGui ":Default"
        Gui, % this.wndGui ":Hide"

        ; 选择项的索引
        GuiControlGet, index,, % this.wndControl
        ; 回调函数
        this.callbackFun.call(index)
        Gui, % this.wndGui ":Hide"
    }

    LButtonHandler(){
        MouseGetPos,,, Temp1
        if (Temp1 != this.wndGui){
            Gui, % this.wndGui ":Hide"
        }
    }

    UpHanler(){
        Gui, % this.wndGui ":Default"
        GuiControlGet, Temp1,, % this.wndControl
        if (Temp1 > 1) {
            GuiControl, Choose, % this.wndControl, % Temp1 - 1    
        }
    }

    DownHanler(){
        Gui, % this.wndGui ":Default"
        GuiControlGet, Temp1,, % this.wndControl
        GuiControl, Choose, % this.wndControl, % Temp1 + 1
    }
}

/*
    光标或鼠标跟随单行编辑框

用到此函数族的功能块： CtrlRich.ahk
*/
class FollowSingleLineEdit
{
    wndGui :=           ; 窗口句柄
    wndControl :=       ; 控件句柄
    callbackFun :=      ; 回调函数
    fontOptions :=      ; 字体选项
    fontName :=         ; 字体名
    minWidth := 50      ; 窗口最小宽度
    maxWidth := 200     ; 窗口最大宽度

    __New(fontOptions := "s10", fontName := "Courier New"){
        this.fontOptions := fontOptions
        this.fontName := fontName
        ; 将成员函数绑定成函数对象
        fnUpdateAction := ObjBindMethod(this, "UpdateAction")
        fnLButtonHandler := ObjBindMethod(this, "LButtonHandler")
        fnEnterHandler := ObjBindMethod(this, "EnterHandler")
        ; 创建列表窗口获取窗口和控件句柄
        Gui, New
        Gui, Font, %fontOptions%, %fontName%
        Gui, Add, Edit, x0 y0 w50 HwndwndControl
        Gui, -Caption +ToolWindow +AlwaysOnTop +LastFound
        Gui, +HwndwndGui
        this.wndGui := wndGui
        this.wndControl := wndControl
        ; 绑定控件g函数
        GuiControl, +g, %wndControl% , % fnUpdateAction     
        ; 确保窗口大小和控件大小一样
        GuiControlGet, tmp, Pos , %wndControl%
        Gui, Show, w%tmpW% h%tmpH% Hide
        Gui, %wndGui%:Hide
        ; 提示窗口热键处理
        Hotkey, IfWinExist, ahk_id %wndGui% ahk_class AutoHotkeyGUI
        Hotkey, ~LButton, % fnLButtonHandler
        Hotkey, Enter, % fnEnterHandler
        Hotkey, IfWinExist
    }

    show(text_, callbackFun, obj := False, minWidth := 50, maxWidth := 200){
        ; textList              ; 文本列表
        ; callbackFun(varText)    ; 回调函数，varText是编辑控件内容

        ; 参数处理
        if obj {
            this.callbackFun := ObjBindMethod(obj, callbackFun)
        }else{
            this.callbackFun := Func(callbackFun)
        }
        this.minWidth := minWidth
        this.maxWidth := maxWidth
        ; 编辑框的宽高
        getTextsWidthHeight(width, height, text_, this.fontOptions, this.fontName)
        width := Min(Max(width + 10,this.minWidth),this.maxWidth)
        ; 当前光标或鼠标位置
        CoordMode, Caret, Screen
        if (not A_CaretX){
            CoordMode, Mouse, Screen
            MouseGetPos, posX, posY
            posX := posX + 10
        }else {
            posX := A_CaretX
            posY := A_CaretY + 20
        }
        GuiControlGet, tmp, Pos , %wndControl%
        if (posX + %tmpW% > A_ScreenWidth) {
            posX := posX - %tmpW%
        }
        if (posY + %tmpH% > A_ScreenHeight) {
            posY := posY - %tmpH%
        }
        ; 窗口显示
        Gui, % this.wndGui ":Default"
        GuiControl,, % this.wndControl, %text_%
        GuiControl, Move, % this.wndControl , w%width% ;设置控件宽
        Gui, Show, x%posX% y%posY% w%width% ;  NoActivate
    }

    ; 动态更新搜索框的长度
    UpdateAction(){
        ; 搜索框的宽
        GuiControlGet, varText , , % this.wndControl
        getTextsWidthHeight(width, height, varText, this.fontOptions, this.fontName)
        width := Min(Max(width + 10, this.minWidth),this.maxWidth)
        ; 按指定宽重新显示窗口
        Gui, % this.wndGui ":Default"
        GuiControl, Move, % this.wndControl, w%width% ;设置搜索框控件宽
        Gui, Show, w%width%
    }
    
    LButtonHandler(){
        MouseGetPos,,, Temp1
        if (Temp1 != this.wndGui){
            Gui, % this.wndGui ":Hide"
        }
    }
    
    EnterHandler(){
        Critical

        GuiControlGet, varText , , % this.wndControl

        Gui, % this.wndGui ":Default"
        Gui, % this.wndGui ":Hide"

        ; 触发的动作函数
        if (StrLen(Trim(varText)) > 0) {
            this.callbackFun.call(varText)
        }
    }
}


/*
    光标或鼠标跟随多行编辑框

用到此函数族的功能块： CtrlRich.ahk
*/
class FollowMultiLineEdit
{
    wndGui :=           ; 窗口句柄
    wndControl :=       ; 控件句柄
    callbackFun :=      ; 回调函数
    fontOptions :=      ; 字体选项
    fontName :=         ; 字体名
    minWidth := 100     ; 窗口最小宽度
    maxWidth := 600     ; 窗口最大宽度
    minHeight := 20     ; 窗口最小高度
    maxHeight := 200    ; 窗口最大高度

    __New(fontOptions := "s10", fontName := "Courier New"){
        this.fontOptions := fontOptions
        this.fontName := fontName
        ; 将成员函数绑定成函数对象
        fnUpdateAction := ObjBindMethod(this, "UpdateAction")
        fnLButtonHandler := ObjBindMethod(this, "LButtonHandler")
        fnCtrlSHandler := ObjBindMethod(this, "CtrlSHandler")
        ; 创建列表窗口获取窗口和控件句柄
        Gui, New
        Gui, Font, %fontOptions%, %fontName%
        Gui, Add, Edit, x0 y0 r3 WantTab -Wrap -VScroll -HScroll HwndwndControl
        Gui, -Caption +ToolWindow +AlwaysOnTop +LastFound
        Gui, +HwndwndGui
        this.wndGui := wndGui
        this.wndControl := wndControl
        ; 绑定控件g函数
        GuiControl, +g, %wndControl% , % fnUpdateAction     
        ; 确保窗口大小和控件大小一样
        GuiControlGet, tmp, Pos , %wndControl%
        Gui, Show, w%tmpW% h%tmpH% Hide
        Gui, %wndGui%:Hide
        ; 提示窗口热键处理
        Hotkey, IfWinExist, ahk_id %wndGui% ahk_class AutoHotkeyGUI
        Hotkey, ~LButton, % fnLButtonHandler
        Hotkey, >^s, % fnCtrlSHandler
        Hotkey, IfWinExist
    }

    show(texts, callbackFun, obj := False, minWH := "100,20", maxWH := "600,200"){
        ; textList              ; 文本列表
        ; callbackFun(varText)    ; 回调函数，varText是编辑控件内容

        ; 参数处理
        if obj {
            this.callbackFun := ObjBindMethod(obj, callbackFun)
        }else{
            this.callbackFun := Func(callbackFun)
        }
        minWH := StrSplit(minWH, ",")
        maxWH := StrSplit(maxWH, ",")
        this.minWidth := minWH[1]
        this.maxWidth := maxWH[1]
        this.minHeight := minWH[2]
        this.maxHeight := maxWH[2]
        ; 编辑框的宽高
        getTextsWidthHeight(width, height, texts, this.fontOptions, this.fontName)
        width := Min(Max(width + 10,this.minWidth),this.maxWidth)
        height := Min(Max(height,this.minHeight),this.maxHeight)
        ; 当前光标或鼠标位置
        CoordMode, Caret, Screen
        if (not A_CaretX){
            CoordMode, Mouse, Screen
            MouseGetPos, posX, posY
            posX := posX + 10
        }else {
            posX := A_CaretX
            posY := A_CaretY + 20
        }
        if (posX + width > A_ScreenWidth) {
            posX := posX - width
        }
        if (posY + height > A_ScreenHeight) {
            posY := posY - height
        }
        ; 窗口显示
        Gui, % this.wndGui ":Default"
        GuiControl,, % this.wndControl, %texts%
        GuiControl, Move, % this.wndControl , w%width% h%height% ;设置控件宽高
        Gui, Show, x%posX% y%posY% w%width% h%height% ;  NoActivate

    }

    ; 动态更新搜索框的长度
    UpdateAction(){
        ; 搜索框的宽
        GuiControlGet, varText , , % this.wndControl
        getTextsWidthHeight(width, height, varText, this.fontOptions, this.fontName)
        width := Min(Max(width + 10,this.minWidth),this.maxWidth)
        height := Min(Max(height,this.minHeight),this.maxHeight)
        ; 按指定宽重新显示窗口
        Gui, % this.wndGui ":Default"
        GuiControl, Move, % this.wndControl, w%width% h%height% ;设置搜索框控件宽
        Gui, Show, w%width% h%height%
    }
    
    LButtonHandler(){
        MouseGetPos,,, Temp1
        if (Temp1 != this.wndGui){
            Gui, % this.wndGui ":Hide"
        }
    }
    
    CtrlSHandler(){
        Critical

        Gui, % this.wndGui ":Default"
        Gui, % this.wndGui ":Hide"

        ; 触发的动作函数
        GuiControlGet, varText , , % this.wndControl
        if (StrLen(Trim(varText)) > 0) {
            this.callbackFun.call(varText)
        }
    }
}
