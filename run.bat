@echo off

%1 mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c %~s0 ::","","runas",1)(window.close)&&exit
cd /d "%~dp0"

tasklist | find /i "autohotkey.exe" > NUL
if "%errorlevel%"=="0"  (
    tskill autohotkey
)
tasklist | find /i "AutoHotkeyU64" > NUL
if "%errorlevel%"=="0" (
    tskill AutoHotkeyU64
)
tasklist | find /i "SharpKnife" > NUL
if "%errorlevel%"=="0" (
    tskill SharpKnife
)
cmdow /run /hid autohotkey SharpKnife.ahk
REM cmdow /run /hid autohotkey SharpKnife.exe

