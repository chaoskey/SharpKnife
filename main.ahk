
FileEncoding , UTF-8

; 启动GDI+支持
startupGdip()
; 加载热LaTeX
loadHotlatex()
return ; 自动运行段结束

;---------------------------------------------------
; 微软拼音输入法辅助 （im_switch）
; --------------------------------------------------
#include %A_ScriptDir%\im_switch.ahk

;---------------------------------------------------
; Latex对应的Unicode （latex2unicode）
; ----------------------------------------------
#include %A_ScriptDir%\latex2unicode.ahk

; -----------------------------------------------
; 动作播放（完善中...）
;------------------------------------------------
#include %A_ScriptDir%\action_play.ahk

