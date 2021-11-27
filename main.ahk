
;---------------------------------------------------
; 自动执行段
; --------------------------------------------------

FileEncoding , UTF-8
; 加载热latex
loadHotlatex()

; 启动GDI+
#Include %A_ScriptDir%\lib\Gdip_All.ahk
If !pToken := Gdip_Startup()
{
	MsgBox "启动GDI+启动失败，请确保您的系统中存在GDI+"
	ExitApp
}
OnExit("ExitMainFunc")

ExitMainFunc(ExitReason, ExitCode)
{
   global
   Gdip_Shutdown(pToken)
}

; 会屏蔽掉后面 #include 的所有自动执行段
Return


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

