@echo off
set baseX64="D:/scoop/apps/autohotkey/current/Compiler/Unicode 64-bit.bin"
set baseX32="D:/scoop/apps/autohotkey/current/Compiler/Unicode 32-bit.bin"
if not exist %baseX64% (
    echo "找不到基文件，请在批处理文件(build.bat)中修改为正确基文件路径"
    exit
)
if not exist %baseX32% (
    echo "找不到基文件，请在批处理文件(build.bat)中修改为正确基文件路径"
    exit
)
if not exist released (
    md released
)
tasklist | find /i "autohotkey.exe" > NUL
if "%errorlevel%"=="0"  (
    tskill autohotkey
)
tasklist | find /i "AutoHotkeyU64" > NUL
if "%errorlevel%"=="0" (
    tskill AutoHotkeyU64
)
@echo on
Ahk2Exe.exe /in SharpKnife.ahk /compress 1 /base %baseX64%
Ahk2Exe.exe /in SharpKnife.ahk /compress 1 /base %baseX64% /out released/SharpKnife_x64.exe
Ahk2Exe.exe /in SharpKnife.ahk /compress 1 /base %baseX32% /out released/SharpKnife_x32.exe
Ahk2Exe.exe /in IMSwitch.ahk /compress 1 /base %baseX64% /out released/IMSwitch_x64.exe
Ahk2Exe.exe /in IMSwitch.ahk /compress 1 /base %baseX32% /out released/IMSwitch_x32.exe
Ahk2Exe.exe /in LaTeXHelper.ahk /compress 1 /base %baseX64% /out released/LaTeXHelper_x64.exe
Ahk2Exe.exe /in LaTeXHelper.ahk /compress 1 /base %baseX32% /out released/LaTeXHelper_x32.exe
Ahk2Exe.exe /in CtrlRich.ahk /compress 1 /base %baseX64% /out released/CtrlRich_x64.exe
Ahk2Exe.exe /in CtrlRich.ahk /compress 1 /base %baseX32% /out released/CtrlRich_x32.exe

.\SharpKnife.exe