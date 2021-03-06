#SingleInstance, force

FileEncoding , UTF-8-RAW

; 托盘提示
Menu, Tray,Tip , SharpKnife（利刃）
icoName := "images\" StrReplace(A_ScriptName, ".ahk" , ".ico")
if FileExist(icoName){
    Menu, Tray, Icon, %icoName%
}

; 启动GDI+支持
startupGdip()
; IMSwitch默认配置
loadIMSwitchDefault()
; 加载热LaTeX
loadHotlatex()
; 创建触发热键
loadTriggerHotKey()
; Clip历史管理
global clipHist := new ClipHistory()
; 光标或鼠标跟随控件
global followList := new FollowListBox()
global follSingleLineEdit := new FollowSingleLineEdit()
global follMultiLineEdit := new FollowMultiLineEdit()
; 启动“Ctrl+命令”死循环(务必放最后)
startCtrlCmdLoop()
return ; 自动运行段结束

;---------------------------------------------------
; 输入法辅助 （IMSwitch）
; --------------------------------------------------
#include IMSwitch.ahk

;---------------------------------------------------
; Latex对应的Unicode （LaTeXHelper）
; ----------------------------------------------
#include LaTeXHelper.ahk

; -----------------------------------------------
; Ctrl功能增强（CtrlRich）
;------------------------------------------------
#include CtrlRich.ahk

; -----------------------------------------------
; 动作播放（完善中...）
;------------------------------------------------
;@Ahk2Exe-IgnoreBegin
#include ActionPlay.ahk
;@Ahk2Exe-IgnoreEnd

;@Ahk2Exe-SetProductName    SharpKnife(利刃) 
;@Ahk2Exe-SetProductVersion 2021.12.30
;@Ahk2Exe-SetDescription SharpKnife(利刃) 
;@Ahk2Exe-SetFileVersion    2021.12.30
;@Ahk2Exe-SetCopyright @2021-2025
;@Ahk2Exe-SetLanguage 0x0804
;@Ahk2Exe-SetOrigFilename SharpKnife
;@Ahk2Exe-SetLegalTrademarks chaoskey
;@Ahk2Exe-SetCompanyName chaoskey
;@Ahk2Exe-SetMainIcon images\SharpKnife.ico

