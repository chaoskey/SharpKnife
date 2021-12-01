;@Ahk2Exe-SetProductName    输入法辅助
;@Ahk2Exe-SetProductVersion 2021.12.01
;@Ahk2Exe-SetDescription 输入法辅助
;@Ahk2Exe-SetFileVersion    2021.12.01
;@Ahk2Exe-SetCopyright @2021-2025
;@Ahk2Exe-SetLanguage 0x0804
;@Ahk2Exe-SetOrigFilename IMSwitch
;@Ahk2Exe-SetLegalTrademarks chaoskey
;@Ahk2Exe-SetCompanyName chaoskey

; -----------------------------------------------
; 微软拼音输入法中英文状态同步记录
; 假设：
;	1) 输入法采用微软拼音并且默认为英文
;	2) 本脚开机启动
;	3) 管住手，禁止鼠标点击切换中英文 【除非提示和系统显示不一样】
;   4) 为每一个活动过的窗口记录中英文状态
;------------------------------------------------

#SingleInstance, force

FileEncoding , UTF-8

; IMSwitch默认配置
loadIMSwitchDefault()
return ; 自动运行段结束

; 重新映射微软拼音中英文切换的快捷

SwitchKeyHandler(){		; Ctl+空格，并且保留原始功能
    ; 确保状态切换后提示
    ; 因为仅仅是提示，所以Sleep时间故意设置长点，无关紧要
    Sleep, 100
    IMToolTip(getImState())
    return
}

; IMSwitch默认配置
loadIMSwitchDefault(){
    iniPath := A_ScriptFullPath
    if (idx := InStr(iniPath, "." , , 0) ){
        iniPath := SubStr(iniPath, 1 , idx-1) 
    }
    iniPath := iniPath ".ini"
    IniRead, switchKey, %iniPath%, ImSwitch, SwitchKey
    if (switchKey == "ERROR"){
        ; 默认用Ctrl+空格切换中英文
        Hotkey, ~^Space, SwitchKeyHandler
        IniWrite, ^Space, %iniPath%, ImSwitch, SwitchKey
        IniWrite, %A_ScriptDir%\EN.png, %iniPath%, ImSwitch, EN
        IniWrite, %A_ScriptDir%\CH.png, %iniPath%, ImSwitch, CH
    }else{
        Hotkey, ~%switchKey%, SwitchKeyHandler
    }
}

; 获取当前窗口的中英文状态
; 确保输入法的中英文状态在屏幕上显示可见
getImState()
{
    global imStateEN
    global imStateCH
    if (not imStateEN) or (not imStateCH) {
        iniPath := A_ScriptFullPath
        if (idx := InStr(iniPath, "." , , 0) ){
            iniPath := SubStr(iniPath, 1 , idx-1) 
        }
        iniPath := iniPath ".ini"
        IniRead, imStateEN, %iniPath%, ImSwitch, EN
        IniRead, imStateCH, %iniPath%, ImSwitch, CH
        if (imStateEN == "ERROR") or (imStateCH == "ERROR"){
            MsgBox 中英文状态截图不正确！截图配置在同名ini文件中。`n确保对应的图片（比如:CH.png和EN.png）存在且正确!`n`n点击“确认”后，程序将退出，请准备好后重新手工启动。
            ExitApp
        }
    }

    imState := -1
    CoordMode Pixel
    ImageSearch, X, Y, 0, 0, A_ScreenWidth, A_ScreenHeight, %imStateEN%
    if (ErrorLevel == 0) {
        imState := 0
    } else{
        ImageSearch, X, Y, 0, 0, A_ScreenWidth, A_ScreenHeight, %imStateCH%
        if (ErrorLevel == 0){
            imState := 1
        }
    }
    ; imState == -1 的情况:  ErrorLevel = 2 无法进行搜索 或 ErrorLevel = 1 在屏幕上找不到图标
    if (imState == -1){
        MsgBox 中英文状态截图不正确！截图配置在同名ini文件中。`n确保对应的图片（比如:CH.png和EN.png）存在且正确!`n`n点击“确认”后，程序将退出，请准备好后重新手工启动。
        ExitApp
    }
   return imState
}

; Markdown中准备编辑数学公式
; [英文$][中文￥]
~+4::          		; 按下$(Shift + 4)
imState := getImState()
if (imState = 1){
    ; 确保只在中文状态下动作
    SendInput ^{Space}{bs}{Text}$
    IMToolTip(0)
}
return

; Vim中回到普通模式

~Esc::         		; Esc, 并且保留原始功能
imState := getImState()
if (imState = 1){
    ; 确保只在中文状态下动作
    Send ^{Space}
    IMToolTip(0)
}
return

; Vim进入命令行模式 【+;就是冒号:】

; [中文：][英文:]
~+;::          		; 按下:(Shift + ;)
imState := getImState()
if (imState = 1){
    ; 确保只在中文状态下动作
    SendInput ^{Space}{bs}{Text}:
    IMToolTip(0)
}
return

IMToolTip(imState)
{
    if (imState = 1)
        ToolTip, 中
    else
        ToolTip, EN
    SetTimer, RemoveIMToolTip, -1000
}

RemoveIMToolTip:
ToolTip
return

