#Include lib\Gdip_All.ahk

;-----------------------------------------------
;            通用的一些函数
;-----------------------------------------------


/*    选择屏幕上的矩形区域   
指定键 button_ 从“按下”到“松开”拉出的矩形区域（相对整个屏幕）

参数:
    button_ 按键

返回值:
    形如: “x|y|w|h”,  选定的矩形区域 左上角( x, y ) 和 长宽(w × h)

需要GDI+的支持
#Include lib\TokenGdip.ahk
startupGdip()
*/
SelectRegionFromScreen(button_){
	; 全屏模糊
	pBitmap := Gdip_BitmapFromScreen()
	hWND := pasteImageToScreen(pBitmap)
	Gdip_DisposeImage(pBitmap)

	; 区域长宽提示
	Gui, textTip:-Caption +LastFound +AlwaysOnTop +Owner +Disabled -SysMenu
	Gui, textTip:Font, s10 cFFFFFF , Verdana
	Gui, textTip:Color, 000000
	Gui, textTip:Add, Text, BackgroundTrans HwndtextTipHwnd

	; 不可的选择区域窗口
	Gui, regionGui:-Caption +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs +Border
	WinSet, Transparent, 100
	; 屏幕绝对坐标模式，作用于MouseGetPos
	CoordMode, Mouse, Screen
	; 拖拽
    MX := False, MY := False 
	Loop{
		if GetKeyState(button_, "P"){  ; button_ 按下后（松开前）
			; 鼠标当前位置
			MouseGetPos, MXend, MYend
            if (MX == False) or (MY == False){
				; 按下的起始位置
                MX := MXend
                MY := MYend
            }
			; 当前矩形: 宽，高，左上角
			W := abs(MX - MXend)
			H := abs(MY - MYend)
			X := Min(MX, MXend)
			Y := Min(MY, MYend)
			; 显示窗口
			Gui, regionGui:Show, x%X% y%Y% w%W% h%H%
			; 区域长宽提示
			str_ := "( " X " , " Y " ) " W " × " H " px"
			w_ := 10*(2+StrLen(str_))*55/70  ; 估算控件宽度（10对应字体大小:s10）
			GuiControl, Text, %textTipHwnd% , %str_%
			GuiControl, Move, %textTipHwnd%, w%w_%
			Gui, textTip:Show, % "NoActivate NA x" X " y" Y-30  " w" w_ 
		}else if (MX != False) and (MY != False) {
			; button_  按下后，再松开
			Break
        }else{
            ; 鼠标当前位置
			MouseGetPos, X_, Y_
            ; 区域长宽提示
			str_ := "( " X_ " , " Y_ " ) px"
			w_ := 10*(2+StrLen(str_))*55/70  ; 估算控件宽度（10对应字体大小:s10）
			GuiControl, Text, %textTipHwnd% , %str_%
			GuiControl, Move, %textTipHwnd%, w%w_%
			Gui, textTip:Show, % "NoActivate NA x" X_ " y" Y_-30  " w" w_ 
        }
	}
	; 销毁窗口
	Gui, regionGui:Destroy
	Gui, textTip:Destroy
	Gui, %hWND%:Destroy
	Return ( X "|" Y "|" W "|" H )
}



/*    贴图
参数:
	pBitmap, 位图
	crop，位图的特定区域（默认位图全区域）
	position, 贴图位置（默认居中布局）
	alpha， 贴图的透明度（默认255不透明）

返回:
	hWND, 贴图窗口句柄

需要GDI+的支持
#Include lib\TokenGdip.ahk
startupGdip()

scale 可能是 1(缩放比) w100（固定宽） h100（固定高）
*/
pasteImageToScreen(pBitmap, crop := False, position := False, alpha := 255, scale := 1){
    ; http://yfvb.com/help/gdiplus/index.htm
    ; https://www.autoahk.com/archives/34920

    Gui, New ; 必须开新窗口，才能开新图
    ; E0x80000  WS_EX_LAYERED   分层窗口 https://docs.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles
    ; 创建一个分层窗口（+E0x80000 ：UpdateLayeredWindow必须用这个才能工作！）它总是在顶部（+AlwaysOnTop），没有任务栏条目或标题
    Gui, -Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs
    Gui, Show
    ; 获取窗口句柄
    hWND := WinExist()

    ; 获取位图的长宽
    Width := Gdip_GetImageWidth(pBitmap)
    Height := Gdip_GetImageHeight(pBitmap)
    sx := 0, sy := 0, sw := Width, sh := Height ; 位图指定区域的位置尺寸（相对位图），默认位图
    dx := 0, dy := 0, dw := Width, dh := Height ; 画布指定区域的位置尺寸（相对画布），默认画布
    if crop {
        crops := StrSplit(crop, ",")
        if (crops.Length() == 4) {
            sx := crops[1], sy := crops[2], sw := crops[3], sh := crops[4]
            dw := crops[3], dh := crops[4]
        }
    }

    if (SubStr(scale, 1 , 1) = "w"){
        scale := SubStr(scale, 2)/dw
    }else if (SubStr(scale, 1 , 1) = "h"){
        scale := SubStr(scale, 2)/dh
    }
    dw := dw*scale
    dh := dh*scale

    ; DC :  设备上下文
    ; GDI : 图形设备接口
    ; DIB : 设备无关位图

    ; 获取DC（hdc）
    hdc := CreateCompatibleDC()
    ; 创建GDI对象（hbm）
    ; 这里具体为DIB，并设置画布尺寸
    hbm := CreateDIBSection(dw, dh)
    ; 将GDI对象（hbm）写入DC（hdc）
    ; 返回hdc老的对象obm
    obm := SelectObject(hdc, hbm)
    ; 从DC（hdc）创建画布（G）
    G := Gdip_GraphicsFromHDC(hdc)

    ; 设置图像对象G的插值模式。插值模式确定当图像缩放或旋转时使用的算法。
    ; 7:  高品质双三次
    Gdip_SetInterpolationMode(G, 7)
    ; 将位图GID对象（pBitmap）的指定部分绘制到画布（G）
    Gdip_DrawImage(G, pBitmap, dx, dy, dw, dh, sx, sy, sw, sh)
    ; 删除位图GID对象（pBitmap）
    ;Gdip_DisposeImage(pBitmap) 
    ; 将图像对象G的世界变换矩阵设置为单位矩阵。
    ; 如果图像对象的世界变换矩阵是单位矩阵，则不会将世界变换应用于由图像对象绘制的项目。
    Gdip_ResetWorldTransform(G)
    ; ---------------------------
    ; 使用GDI位图的设备上下文句柄hdc更新分层窗口hwnd1 
    xpos := (A_ScreenWidth-dw)//2
    ypos := (A_ScreenHeight-dh)//2
    if position{
        pos_ := StrSplit(position, ",")
        if (pos_.Length() == 2) {
            xpos := pos_[1]
            ypos := pos_[2]
        }
    } 
    UpdateLayeredWindow(hwnd, hdc, xpos, ypos, dw, dh, alpha)

    ; 删除画布（G）
    Gdip_DeleteGraphics(G)
    ; 恢复DC（hdc）原来的GDI对象（obm）
    SelectObject(hdc, obm)
    ; 释放删除创建的GDI对象（hbm）
    DeleteObject(hbm)
    ; 释放删除DC（hdc）
    DeleteDC(hdc)

	return hWND
}


/*
    基于简单列表的跟随提示
    
用到此函数族的功能块： LaTeXHelper.ahk CtrlRich.ahk
下面这族函数，用户只需要调用ShowSuggestionsGui(...)
*/

; 显示列表提示窗口
ShowSuggestionsGui(_suggList_, _actionFun_, maxSize_ := "200,20"){ 
    ; _suggList_   ; 提示列表数据（用`n分割的字符串）
    ; _actionFun_(index) ; 实际触发的动作函数，index是已选项的索引

    global suggMatchedID ; 提示窗口匹配项的控件ID
    global suggActionFun := _actionFun_

    ; 创建显示列表提示窗口(如果已创建，则利用已创建的窗口)
    SetupSuggestionsGui()

    Gui, Suggestions:Default
    if (_suggList_ = ""){
        Gui, Suggestions:Hide
        return
    }

    maxSize_ := StrSplit(maxSize_, ",")
    maxWidth := maxSize_[1]
    maxHeight := maxSize_[2] 
    GuiControl,, suggMatchedID, `n%_suggList_%
    GuiControl, Choose, suggMatchedID, 1
    GuiControl, Move, suggMatchedID, w%maxWidth% h%maxHeight% ;设置控件宽高

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
    if (posX + maxWidth > A_ScreenWidth) {
        posX := posX - maxWidth
    }
    if (posY + maxHeight > A_ScreenHeight) {
        posY := posY - maxHeight
    }
    Gui, Show, x%posX% y%posY% w%maxWidth% h%maxHeight% NoActivate
}

; 创建显示列表提示窗口
SetupSuggestionsGui(){

    global suggMatchedID    ; 提示窗口匹配项的控件ID
    global suggHWND         ; 提示窗口句柄

    if (not suggHWND) {
        ; 设置建议窗口
        Gui, Suggestions:Default
        Gui, Font, s10, Courier New
        Gui, +Delimiter`n
        Gui, Add, ListBox, x0 y0 h165 0x100 vsuggMatchedID gSuggCompleteAction AltSubmit
        Gui, -Caption +ToolWindow +AlwaysOnTop +LastFound
        suggHWND := WinExist()
        Gui, Show, h165 Hide, SuggCompleteWin

        ; 提示窗口热键处理
        Hotkey, IfWinExist, SuggCompleteWin ahk_class AutoHotkeyGUI
        Hotkey, ~LButton, SuggLButtonHandler
        Hotkey, Up, SuggUpHanler
        Hotkey, Down, SuggDownHanler
        Hotkey, Tab, SuggCompleteAction
        Hotkey, Enter, SuggCompleteAction
        Hotkey, IfWinExist
    }
}

; 根据提示窗口选择完成
SuggCompleteAction(){ 
    Critical

    global suggMatchedID    ; 提示窗口匹配项的控件ID
    global suggActionFun    ; suggActionFun(index), 实际触发的动作函数，index是已选项的索引

    ; {enter} {tab}   或 双击匹配项  触发粘贴
    If (A_GuiEvent != "" && A_GuiEvent != "DoubleClick")
        Return

    Gui, Suggestions:Default
    Gui, Suggestions:Hide

    ; 发送选择的内容
    GuiControlGet, index,, suggMatchedID
    ; 触发的动作函数
    %suggActionFun%(index)
    Gui, Suggestions:Hide
}

SuggUpHanler(){
    Gui, Suggestions:Default
    GuiControlGet, Temp1,, suggMatchedID
    if (Temp1 > 1) {
        GuiControl, Choose, suggMatchedID, % Temp1 - 1    
    }
}

SuggDownHanler(){
    Gui, Suggestions:Default
    GuiControlGet, Temp1,, suggMatchedID
    GuiControl, Choose, suggMatchedID, % Temp1 + 1
}

SuggLButtonHandler(){
    global suggHWND
    MouseGetPos,,, Temp1
    if (Temp1 != suggHWND){
        Gui, Suggestions:Hide
    }
}


/*
    简单的跟随搜索框
    
用到此函数族的功能块： CtrlRich.ahk
下面这族函数，用户只需要调用ShowFollowSearchBox(...)
*/

; 显示简单的跟随搜索框
ShowFollowSearchBox(_actionFun_){ 
    global searchBoxText  ; 搜索框文本内容的关联变量
    ; searchBoxActionFun(searchText) : 实际触发的动作函数，searchText是已输入的搜索关键词
    global searchBoxActionFun := _actionFun_

    ; 创建搜索框(只创建一次)
    SetupSearchBoxGui()
    ; 编辑框清空
    Gui, FollowSearchBoxWin:Default
    GuiControl,, searchBoxText, % ""
    ; 当前光标或鼠标位置
    CoordMode, Caret, Screen
    if (not A_CaretX){
        CoordMode, Mouse, Screen
        MouseGetPos, posX, posY
        posX := posX + 10
    }else {
        posX := A_CaretX
        posY := A_CaretY
    }
    if (posX + maxWidth > A_ScreenWidth) {
        posX := posX - maxWidth
    }
    if (posY + maxHeight > A_ScreenHeight) {
        posY := posY - maxHeight
    }
    ; 跟随光标显示搜索框
    Gui, Show, x%posX% y%posY%
}

; 创建搜索框(只创建一次)
SetupSearchBoxGui(){
    global searchBoxText  ; 搜索框文本内容的关联变量
    global searchBoxHWND  ; 搜索框窗口句柄

    if (not searchBoxHWND) {
        ; 设置搜索框
        Gui, FollowSearchBoxWin:Default
        Gui, Font, s10, Courier New
        Gui, Add, Edit, x0 y0 w100 vsearchBoxText gupdateSearchBoxWidth  
        Gui, -Caption +ToolWindow +AlwaysOnTop +LastFound
        searchBoxHWND := WinExist()
        GuiControlGet, tmp , Pos, searchBoxText
        Gui, Show, w%tmpW% h%tmpH% Hide, FollowSearchBoxWin
        ; 搜索框热键处理
        Hotkey, IfWinExist, FollowSearchBoxWin ahk_class AutoHotkeyGUI
        Hotkey, ~LButton, SearchBoxLButtonHandler
        Hotkey, Enter, SearchBoxEnterHandler
        Hotkey, IfWinExist
    }
}

; 动态更新搜索框的长度
updateSearchBoxWidth(){
    global searchBoxText  ; 搜索框文本内容的关联变量

    GuiControlGet, searchBoxText
    width := Max(Ceil(10*StrLen(searchBoxText)),100)
    if (width > 100){
        GuiControl, Move, searchBoxText, w%width% ;设置搜索框控件宽
        Gui, Show, w%width%
    }
}

; 搜索框回车确认
SearchBoxEnterHandler(){ 
    Critical

    global searchBoxText   ; 搜索框文本内容的关联变量
    ; searchBoxActionFun(searchText) : 实际触发的动作函数，searchText是已输入的搜索关键词
    global searchBoxActionFun

    Gui, FollowSearchBoxWin:Submit
    Gui, Hide

    ; 触发的动作函数
    if (StrLen(Trim(searchBoxText)) > 0) {
        %searchBoxActionFun%(searchBoxText)
    }
}

; 搜索框窗口外鼠标点击关闭窗口
SearchBoxLButtonHandler(){
    global searchBoxHWND ; 搜索框窗口句柄
    MouseGetPos,,, Temp1
    if (Temp1 != searchBoxHWND){
        Gui, FollowSearchBoxWin:Hide
    }
}
