@echo off

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
