;-----------------------------------------------
;            GDI+令牌:  global token_gdip 
;-----------------------------------------------

#Include lib\Gdip_All.ahk

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
