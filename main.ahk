;@Ahk2Exe-SetProductName    Tab助手
;@Ahk2Exe-SetProductVersion 2021.12.01
;@Ahk2Exe-SetDescription Tab助手
;@Ahk2Exe-SetFileVersion    2021.12.01
;@Ahk2Exe-SetCopyright @2021-2025
;@Ahk2Exe-SetLanguage 0x0804
;@Ahk2Exe-SetOrigFilename TabHelper
;@Ahk2Exe-SetLegalTrademarks chaoskey
;@Ahk2Exe-SetCompanyName chaoskey

#SingleInstance, force

FileEncoding , UTF-8-RAW

; 启动GDI+支持
startupGdip()
; IMSwitch默认配置
loadIMSwitchDefault()
; 加载热LaTeX
loadHotlatex()
; 创建触发热键
loadTriggerHotKey()
; 启动“Ctrl+命令”死循环
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
#include ActionPlay.ahk

