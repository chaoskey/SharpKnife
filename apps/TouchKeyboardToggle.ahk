#Requires AutoHotkey v2.0
#SingleInstance Force

global tipBandStrongMatch := 0
global tipBandWeakMatch := 0

exitCode := Main()
ExitApp(exitCode)

Main() {
    GetCursorPosEx(&origX, &origY)

    hwnd := FindTouchKeyboardButton(&trayHwnd)
    if !hwnd {
        MsgBox("未找到任务栏中的触摸键盘图标。`n`n请先确认右下角任务栏里确实显示了该图标。", "触摸键盘切换", "Iconx")
        return 1
    }

    if IsTrayAutoHideEnabled() {
        RevealTrayForButton(trayHwnd, hwnd)

        hwnd := FindTouchKeyboardButton(&trayHwnd)
        if !hwnd {
            MsgBox("任务栏已唤出，但重新定位触摸键盘图标失败。", "触摸键盘切换", "Iconx")
            return 1
        }
    }

    if !GetWindowRectEx(hwnd, &left, &top, &right, &bottom) {
        MsgBox("无法读取触摸键盘图标的位置。", "触摸键盘切换", "Iconx")
        return 1
    }

    clickX := Floor((left + right) / 2)
    clickY := Floor((top + bottom) / 2)
    if !ClickScreenPoint(clickX, clickY, origX, origY) {
        MsgBox("模拟点击触摸键盘图标失败。", "触摸键盘切换", "Iconx")
        return 1
    }

    return 0
}

FindTouchKeyboardButton(&foundTrayHwnd := 0) {
    foundTrayHwnd := 0
    for trayClass in ["Shell_TrayWnd", "Shell_SecondaryTrayWnd"] {
        for trayHwnd in WinGetList("ahk_class " trayClass) {
            if tipBandHwnd := EnumFindTipBand(trayHwnd) {
                foundTrayHwnd := trayHwnd
                return tipBandHwnd
            }
        }
    }
    return 0
}

EnumFindTipBand(parentHwnd) {
    global tipBandStrongMatch, tipBandWeakMatch

    tipBandStrongMatch := 0
    tipBandWeakMatch := 0
    callback := CallbackCreate(EnumTipBandProc, "Fast")
    try {
        DllCall("user32\EnumChildWindows", "ptr", parentHwnd, "ptr", callback, "ptr", 0, "int")
    } finally {
        CallbackFree(callback)
    }
    return tipBandStrongMatch ? tipBandStrongMatch : tipBandWeakMatch
}

EnumTipBandProc(hwnd, lParam) {
    global tipBandStrongMatch, tipBandWeakMatch

    try className := WinGetClass("ahk_id " hwnd)
    catch
        return true

    if (className != "TIPBand")
        return true

    title := ""
    try title := WinGetTitle("ahk_id " hwnd)
    catch
        title := ""

    if (title != "" && (InStr(title, "触摸键盘") || InStr(title, "Touch Keyboard"))) {
        tipBandStrongMatch := hwnd
        return false
    }

    if !tipBandWeakMatch
        tipBandWeakMatch := hwnd
    return true
}

GetWindowRectEx(hwnd, &left, &top, &right, &bottom) {
    rect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "ptr", hwnd, "ptr", rect.Ptr, "int")
        return false

    left := NumGet(rect, 0, "int")
    top := NumGet(rect, 4, "int")
    right := NumGet(rect, 8, "int")
    bottom := NumGet(rect, 12, "int")
    return true
}

IsTrayAutoHideEnabled() {
    abd := Buffer(A_PtrSize = 8 ? 48 : 36, 0)
    NumPut("uint", abd.Size, abd, 0)
    state := DllCall("shell32\SHAppBarMessage", "uint", 0x00000004, "ptr", abd.Ptr, "uint")
    return (state & 0x1) != 0
}

RevealTrayForButton(trayHwnd, buttonHwnd) {
    if !trayHwnd
        return false
    if !GetWindowRectEx(trayHwnd, &trayLeft, &trayTop, &trayRight, &trayBottom)
        return false
    if !GetWindowRectEx(buttonHwnd, &btnLeft, &btnTop, &btnRight, &btnBottom)
        return false
    edge := DetectTrayEdge(trayLeft, trayTop, trayRight, trayBottom)
    targetX := Floor((btnLeft + btnRight) / 2)
    targetY := Floor((btnTop + btnBottom) / 2)
    if (edge = "bottom")
        targetY := VirtualScreenBottom() - 1
    else if (edge = "top")
        targetY := VirtualScreenTop() + 1
    else if (edge = "left")
        targetX := VirtualScreenLeft() + 1
    else if (edge = "right")
        targetX := VirtualScreenRight() - 1
    DllCall("user32\SetCursorPos", "int", targetX, "int", targetY, "int")
    Sleep(180)
    return true
}

DetectTrayEdge(left, top, right, bottom) {
    vLeft := VirtualScreenLeft()
    vTop := VirtualScreenTop()
    vRight := VirtualScreenRight()
    vBottom := VirtualScreenBottom()
    dLeft := Abs(left - vLeft)
    dTop := Abs(top - vTop)
    dRight := Abs(vRight - right)
    dBottom := Abs(vBottom - bottom)
    best := dLeft
    edge := "left"
    if (dTop < best)
        best := dTop, edge := "top"
    if (dRight < best)
        best := dRight, edge := "right"
    if (dBottom < best)
        best := dBottom, edge := "bottom"
    return edge
}

VirtualScreenLeft() {
    return SysGet(76)
}

VirtualScreenTop() {
    return SysGet(77)
}

VirtualScreenWidth() {
    return SysGet(78)
}

VirtualScreenHeight() {
    return SysGet(79)
}

VirtualScreenRight() {
    return VirtualScreenLeft() + VirtualScreenWidth() - 1
}

VirtualScreenBottom() {
    return VirtualScreenTop() + VirtualScreenHeight() - 1
}

GetCursorPosEx(&x, &y) {
    point := Buffer(8, 0)
    if !DllCall("user32\GetCursorPos", "ptr", point.Ptr, "int") {
        x := 0
        y := 0
        return false
    }
    x := NumGet(point, 0, "int")
    y := NumGet(point, 4, "int")
    return true
}

ClickScreenPoint(x, y, restoreX, restoreY) {
    if !DllCall("user32\SetCursorPos", "int", x, "int", y, "int")
        return false

    DllCall("user32\mouse_event", "uint", 0x0002, "uint", 0, "uint", 0, "uint", 0, "uptr", 0)
    Sleep(60)
    DllCall("user32\mouse_event", "uint", 0x0004, "uint", 0, "uint", 0, "uint", 0, "uptr", 0)
    Sleep(80)
    DllCall("user32\SetCursorPos", "int", restoreX, "int", restoreY, "int")
    return true
}
