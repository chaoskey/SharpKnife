;@Ahk2Exe-SetProductName    输入法辅助
;@Ahk2Exe-SetProductVersion 2021.12.01
;@Ahk2Exe-SetDescription 输入法辅助
;@Ahk2Exe-SetFileVersion    2021.12.01
;@Ahk2Exe-SetCopyright @2021-2025
;@Ahk2Exe-SetLanguage 0x0804
;@Ahk2Exe-SetOrigFilename IMSwitch
;@Ahk2Exe-SetLegalTrademarks chaoskey
;@Ahk2Exe-SetCompanyName chaoskey
;@Ahk2Exe-SetMainIcon images\im.ico

; -----------------------------------------------
; 中英文切换辅助
;
; 关于当前上下文的特定输入法的内部中英文状态，现状是不存在可用的API获取方法。 
; 上一个版本，通过主动拦截记录中英文状态。缺点是有时存在记录中英文状态和实际的中英文状态不同步。 
; 最新版本，分别对中英文两种状态进行截图，然后根据屏幕搜图的方法获取当前上下文的中英文状态
; 优点是，通用性极强，适用于任意输入法内部中英文切换，也适用于两个输入法的切换（比如中文键盘和英文键盘间的切换）。
; 缺点是，第一次切换前需要截图，如果截图不正确，会提示重新截图。
;------------------------------------------------

#SingleInstance, force

FileEncoding , UTF-8-RAW

#Include lib\util.ahk
#Include lib\CustomGUI.ahk

; 托盘提示
Menu, Tray,Tip , 输入法助手
if FileExist("images\im.ico"){
    Menu, Tray, Icon, images\im.ico
}


; 启动GDI+支持
startupGdip()
; IMSwitch默认配置
loadIMSwitchDefault()
return ; 自动运行段结束

; 重新映射微软拼音中英文切换的快捷

SwitchKeyHandler(){		; Ctl+空格，并且保留原始功能
    ; 确保状态切换后提示
    Sleep, 50
    IMToolTip(getImState())
    return
}

writeIMSwitchIni(){
    iniPath := A_ScriptFullPath
    if (idx := InStr(iniPath, "." , , 0) ){
        iniPath := SubStr(iniPath, 1 , idx-1)  
    }
    iniPath := iniPath ".ini"
    IniWrite, 
(
; 中英文切换快捷键
SwitchKey=^Space
;
; *50 表示每个像素颜色红/绿/蓝通道强度在每个方向上允许的渐变值
; 更多设置，参考ImageSearch方法的参数ImageFile说明
; https://www.autoahk.com/help/autohotkey/zh-cn/docs/commands/ImageSearch.htm
; 
; 英文状态截图
EN=*50 %A_ScriptDir%\EN.png
; 中文状态截图
CH=*50 %A_ScriptDir%\CH.png
;
; key部分以HotKey开头，表示热键
; value中##前的部分：执行的动作，
; value中##后的部分：1表示中文时执行切换，0表示英文时执行切换，-1表示不进行中英文切换
; 确保下面的中英文切换快捷键^{Space}和前面SwitchKey的设置一致
HotKey~+4=^{Space}{bs}{Text}$##1
HotKey~Esc=^{Space}##1
HotKey~+;=^{Space}{bs}{Text}:##1
;
; key部分以HotStr开头，表示热字串，要求和前面的规则一致
HotStr:*?:;zh=^{Space}##0
HotStr:*?:;en=^{Space}##1
; 
), %iniPath%, ImSwitch

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
        writeIMSwitchIni()
    }else{
        Hotkey, ~%switchKey%, SwitchKeyHandler
    }
    ; 根据配置，启动热键和热字串
    IniRead, varSect, %iniPath%, ImSwitch
    if varSect {
        for i_ , v_ in StrSplit(varSect, "`n"){
            v_ := Trim(v_)
            if (InStr(v_, "HotKey")==1) or (InStr(v_, "HotStr")==1){
                hot_ := SubStr(v_, 1, 6)
                v_ := SubStr(v_, 7)
                pos_ := InStr(v_, "=")
                key_ := Trim(SubStr(v_, 1, pos_-1))
                value_ := Trim(SubStr(v_, pos_+1))
                fn := Func("imHotHandler").Bind(value_)
                if (hot_ == "HotKey"){
                    Hotkey, %key_% , % fn 
                } else{
                    Hotstring(key_ , fn)
                }              
            }
        }
    }
}

; 输入法切换之热键或热字串的处理
imHotHandler(value_){ 
    pos_ := InStr(value_, "##", ,0)  
    state_ := Trim(SubStr(value_, pos_+2))       
    value_ := Trim(SubStr(value_, 1, pos_-1))
    if (state_ ==-1){
        Send % value_
        return
    }
    imState := getImState()
    if (imState = state_){
        ; 确保在指定状态下动作
        Send % value_
        IMToolTip(not state_)
    }
    return
}

; 获取当前窗口的中英文状态
; 确保输入法的中英文状态在屏幕上显示可见
getImState()
{
    global imStateSearchRegion ; 中英文状态搜图区域
    global imStateEN
    global imStateCH

    if (not imStateEN) or (not imStateCH) {
        ; 获取截图路径（可能含额外选项）
        iniPath := A_ScriptFullPath
        if (idx := InStr(iniPath, "." , , 0) ){
            iniPath := SubStr(iniPath, 1 , idx-1) 
        }
        iniPath := iniPath ".ini"            
    
        IniRead, imStateEN, %iniPath%, ImSwitch, EN
        IniRead, imStateCH, %iniPath%, ImSwitch, CH
        if (imStateEN == "ERROR") or (imStateCH == "ERROR"){
            writeIMSwitchIni()
            ; 英文状态截图
            imStateEN := "*50 " A_ScriptDir "\EN.png"
            ; 中文状态截图
            imStateCH := "*50 " A_ScriptDir "\CH.png"
        }
    }

    ; 为了加快搜图速度，尽可能在特定小区域中搜索
    if (not imStateSearchRegion){
        ; 默认全屏幕搜索，也就是说第一次获取中英文状态会稍微慢些
        imStateSearchRegion := [0,0,A_ScreenWidth, A_ScreenHeight]
    }

    ; 搜图
    CoordMode Pixel
    ; 0, 0, A_ScreenWidth, A_ScreenHeight
    ImageSearch, X, Y, % imStateSearchRegion[1]
                , % imStateSearchRegion[2]
                , % imStateSearchRegion[3]
                , % imStateSearchRegion[4], %imStateEN%
    ; 中英文状态，-1表示无法获状态，将退出程序
    imState := -1
    if (ErrorLevel == 0) {
        imState := 0
    } else{
        ImageSearch, X, Y
                , % imStateSearchRegion[1]
                , % imStateSearchRegion[2]
                , % imStateSearchRegion[3]
                , % imStateSearchRegion[4], %imStateCH%
        if (ErrorLevel == 0){
            imState := 1
        }
    }

    ; imState == -1 的情况:  ErrorLevel = 2 无法进行搜索 或 ErrorLevel = 1 在屏幕上找不到图标
    if (imState == -1){
        ; 如果搜图不成功，说明截图配置有问题，将退出程序
        iniName := A_ScriptName
        if (idx := InStr(iniName, "." , , 0) ){
            iniName := SubStr(iniName, 1 , idx-1)  
        }
        iniName := iniName ".ini"
        MsgBox, 
(
配置文件（%iniName%）已存在，点击“确认”，将退出程序！`n
--------------------------------------------------------------`n
检查中英文状态是否被遮挡，不要隐藏任务栏；`n
检查配置文件（%iniName%）的中英文状态图的路径和内容是否正确；`n
初次使用务必仔细看配置文件（%iniName%）内容，确保和实际情况一致!`n
--------------------------------------------------------------
)
        ExitApp
    }

    
    ; 搜图成功, 可尽可能缩小搜索范围，加快以后的搜图速度
    ; 可合理假设中英文状态不可能出现屏幕左上角
    if (imStateSearchRegion[1]==0) and (imStateSearchRegion[2]==0){
        ; 定位文件路径起始位置（注意:全路径中可能会有空格）
        idx_ :=  InStr(imStateEN, "\")
        if (idx_ == 0){
            idx_ :=  InStr(imStateEN, "/")
        }
        if (idx_ > 0){
            tmp_ := SubStr(imStateEN, 1 , idx_)
            idx1_ := InStr(tmp_, A_Space , , 0)
            idx2_ := InStr(tmp_, A_Tab , , 0)
            idx_ := Max(1, idx1_, idx2_)
        }
        ; 从图片创建位图句柄
        pBitmap := Gdip_CreateBitmapFromFile(Trim(SubStr(imStateEN , idx_)))
        ; 获取位图的长宽
        Width := Gdip_GetImageWidth(pBitmap)
        Height := Gdip_GetImageHeight(pBitmap)
        ; 删除位图GID对象（pBitmap）
        Gdip_DisposeImage(pBitmap)

        idx_ :=  InStr(imStateCH, "\")
        if (idx_ == 0){
            idx_ :=  InStr(imStateCH, "/")
        }
        if (idx_ > 0){
            tmp_ := SubStr(imStateCH, 1 , idx_)
            idx1_ := InStr(tmp_, A_Space , , 0)
            idx2_ := InStr(tmp_, A_Tab , , 0)
            idx_ := Max(1, idx1_, idx2_)
        }
        pBitmap := Gdip_CreateBitmapFromFile(Trim(SubStr(imStateCH , idx)))
        Width := Max(Width , Gdip_GetImageWidth(pBitmap))
        Height := Max(Height , Gdip_GetImageHeight(pBitmap))
        Gdip_DisposeImage(pBitmap)

        imStateSearchRegion := [X, Y, X + Width, Y + Height]
        ; 下面是容错性处理: 将搜索区域扩大到中英文状态区域的2倍
        imStateSearchRegion := [Max(0,imStateSearchRegion[1]-(Width//2))
                                , Max(0,imStateSearchRegion[2]-(Height//2))
                                , Min(A_ScreenWidth,imStateSearchRegion[3]+(Width//2))
                                , Min(A_ScreenHeight,imStateSearchRegion[4]+(Height//2))]
    }
   return imState
}

IMToolTip(imState)
{
    ; 1秒钟后消失
    if (imState = 1)
        FollowToolTip("中", 1000)
    else
        FollowToolTip("EN", 1000)
}

