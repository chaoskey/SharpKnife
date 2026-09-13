#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; 触摸键盘切换（COM 接口版）
;
; 原理：资源管理器在响应任务栏右下角“触摸键盘”按钮时，内部并不是点图标，
;       而是创建未公开的 COM 组件 UIHostNoLaunch 并调用其
;       ITipInvocation::Toggle(HWND) 方法（参数传桌面窗口）。
;       本工具复刻同一调用：不移动鼠标、不模拟点击，任务栏上的触摸键盘
;       图标是否可见都不影响；也不会碰数位板笔的光标吸附问题。
;
; 关键点：ITipInvocation 的 COM 服务器就是 TabTip.exe。
;         - 若 TabTip.exe 没在运行，CoCreateInstance 会返回
;           0x80040154 (REGDB_E_CLASSNOTREG)，此时先启动它（这一步本身
;           就是“显示触摸键盘”），再决定要不要补一次切换。
;         - 若 TabTip.exe 已在运行，直接 Toggle 即可开/关。
;
; 本文件与 apps\TouchKeyboardToggle.ahk（模拟点击版）互不影响，
; 两个工具可同时保留、按需选用。
; ============================================================

global TIP_CLSID_NO_LAUNCH := "{4ce576fa-83dc-4F88-951c-9d0782b4e376}"   ; UIHostNoLaunch：与 explorer 同款
global TIP_CLSID_UIHOST := "{054AAE20-4BEA-4347-8A35-64A533254A9D}"      ; UIHost：注册了 LocalServer32，可由 COM 自行拉起
global TIP_IID := "{37c994e7-432b-4834-a2f7-dce1f13b834b}"               ; IID_ITipInvocation
global TIP_CLSCTX := 0x6                                                  ; CLSCTX_INPROC_HANDLER | CLSCTX_LOCAL_SERVER
global HR_S_OK := 0
global HR_E_INVALIDARG := 0x80070057
global HR_REGDB_E_CLASSNOTREG := 0x80040154
global TIP_LAUNCH_WAIT_MS := 1500

exitCode := Main()
ExitApp(exitCode)

Main() {
    global TIP_CLSID_NO_LAUNCH, TIP_CLSID_UIHOST, HR_S_OK, HR_REGDB_E_CLASSNOTREG, TIP_LAUNCH_WAIT_MS

    ; 首选与 explorer 完全一致的 CLSID
    hr := TipToggleViaCom(TIP_CLSID_NO_LAUNCH)
    if (hr = HR_S_OK)
        return 0
    if (hr != HR_REGDB_E_CLASSNOTREG)
        return TipFail(hr)

    ; 键盘进程没起来：先拉起来（起进程本身就会把键盘显示出来）
    if !TipStartServer()
        return TipFail(hr)
    if TipWaitVisible(TIP_LAUNCH_WAIT_MS)
        return 0

    ; 个别机型启动进程不会自动弹出键盘，再补一次 COM 切换
    hr := TipToggleViaCom(TIP_CLSID_NO_LAUNCH)
    if (hr = HR_S_OK)
        return 0
    if (hr = HR_REGDB_E_CLASSNOTREG)
        hr := TipToggleViaCom(TIP_CLSID_UIHOST)
    if (hr = HR_S_OK)
        return 0
    return TipFail(hr)
}

; 创建 ITipInvocation 并切换一次；返回 HRESULT（统一成 32 位无符号）
TipToggleViaCom(clsidStr) {
    global TIP_IID, TIP_CLSCTX, HR_S_OK, HR_E_INVALIDARG

    clsid := TipGuidBuffer(clsidStr)
    iid := TipGuidBuffer(TIP_IID)
    if (!clsid || !iid)
        return HR_E_INVALIDARG

    p := 0
    hr := DllCall("ole32\CoCreateInstance", "Ptr", clsid.Ptr, "Ptr", 0, "UInt", TIP_CLSCTX,
        "Ptr", iid.Ptr, "Ptr*", &p, "Int")
    hr &= 0xFFFFFFFF
    if (hr != HR_S_OK || !p)
        return hr

    hr := HR_S_OK
    try {
        ; IUnknown 占 0/1/2，ITipInvocation 第一个方法 Toggle 即索引 3
        hr := ComCall(3, p, "Ptr", TipDesktopWindow(), "Int")
        hr &= 0xFFFFFFFF
    } finally {
        ComCall(2, p)   ; Release
    }
    return hr
}

; 启动 TabTip.exe（ITipInvocation 的 COM 服务器）
TipStartServer() {
    exePath := EnvGet("CommonProgramFiles") "\microsoft shared\ink\TabTip.exe"
    if !FileExist(exePath)
        exePath := "C:\Program Files\Common Files\microsoft shared\ink\TabTip.exe"
    if !FileExist(exePath)
        return false
    try {
        Run('"' exePath '"')
    } catch {
        return false
    }
    return true
}

; 等待触摸键盘变为可见（避免“起进程已弹出键盘、又被 Toggle 关掉”）
TipWaitVisible(timeoutMs) {
    startTick := A_TickCount
    loop {
        if TipKeyboardVisible()
            return true
        if (A_TickCount - startTick >= timeoutMs)
            return false
        Sleep(80)
    }
}

; 触摸键盘当前是否可见（新/旧两代窗口都判一下）
TipKeyboardVisible() {
    ; 新版键盘（Win10 1709+）：TextInputHost.exe 托管的 CoreWindow，隐藏时会被 DWM cloak
    try {
        for hwnd in WinGetList("ahk_class Windows.UI.Core.CoreWindow ahk_exe TextInputHost.exe") {
            if DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int") && !TipWindowCloaked(hwnd)
                return true
        }
    } catch {
    }

    ; 旧版键盘
    try {
        hwnd := WinExist("ahk_class IPTip_Main_Window")
        if hwnd && DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
            return true
    } catch {
    }

    return false
}

TipWindowCloaked(hwnd) {
    cloaked := 0
    hr := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14, "Int*", &cloaked, "UInt", 4, "Int")
    return (hr = 0 && cloaked != 0)
}

TipDesktopWindow() {
    return DllCall("user32\GetDesktopWindow", "Ptr")
}

TipGuidBuffer(guidStr) {
    buf := Buffer(16, 0)
    if (DllCall("ole32\CLSIDFromString", "Str", guidStr, "Ptr", buf.Ptr, "Int") != 0)
        return 0
    return buf
}

TipFail(hr) {
    MsgBox("调用触摸键盘 COM 接口失败。`n`n错误码：0x" Format("{:08X}", hr) "`n`n"
        . "可能原因：`n"
        . "1) TabTip.exe 无法启动（可先手动打开一次触摸键盘再试）；`n"
        . "2) 安全软件/组策略拦截了该 COM 组件；`n"
        . "3) 当前系统版本不提供 ITipInvocation 接口。`n`n"
        . "可改用模拟点击版：apps\TouchKeyboardToggle.exe",
        "触摸键盘切换(COM)", "Iconx")
    return 1
}
