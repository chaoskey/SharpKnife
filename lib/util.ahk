#Include lib\Gdip_All.ahk

;-----------------------------------------------
;            通用的一些函数
;-----------------------------------------------

/*
    GDI+令牌:  global token_gdip 
*/

startupGdip(){
    global token_gdip
    if (not token_gdip){
        ; 启动GDI+
        If !token_gdip := Gdip_Startup()
        {
            MsgBox "启动GDI+启动失败，请确保您的系统中存在GDI+"
            ExitApp
        }
        OnExit("ExitFunc")
    }
    return token_gdip
}

ExitFunc(ExitReason, ExitCode)
{
    global token_gdip
    if token_gdip {
        Gdip_Shutdown(pToken)
    }
}



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
    Gui, -Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs +HwndhWND
    Gui, Show

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

