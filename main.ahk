#SingleInstance, force

FileEncoding , UTF-8

; 启动GDI+支持
startupGdip()
; 加载热LaTeX
loadHotlatex()
; 创建触发热键
loadTriggerHotKey()
return ; 自动运行段结束

;---------------------------------------------------
; 微软拼音输入法辅助 （im_switch）
; --------------------------------------------------
#include %A_ScriptDir%\im_switch.ahk

;---------------------------------------------------
; Latex对应的Unicode （LaTeXHelper）
; ----------------------------------------------
#include %A_ScriptDir%\LaTeXHelper.ahk

; -----------------------------------------------
; 动作播放（完善中...）
;------------------------------------------------
#include %A_ScriptDir%\action_play.ahk

