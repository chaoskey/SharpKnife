@echo off
set baseX64="D:/scoop/apps/autohotkey/current/Compiler/Unicode 64-bit.bin"
set baseX32="D:/scoop/apps/autohotkey/current/Compiler/Unicode 32-bit.bin"
if not exist released (
    md released
)
@echo on
tskill.exe SharpKnife
Ahk2Exe.exe /in SharpKnife.ahk /compress 1 /base %baseX64%
Ahk2Exe.exe /in SharpKnife.ahk /compress 1 /base %baseX64% /out released/SharpKnife_x64.exe
Ahk2Exe.exe /in SharpKnife.ahk /compress 1 /base %baseX32% /out released/SharpKnife_x32.exe
Ahk2Exe.exe /in IMSwitch.ahk /compress 1 /base %baseX64% /out released/IMSwitch_x64.exe
Ahk2Exe.exe /in IMSwitch.ahk /compress 1 /base %baseX32% /out released/IMSwitch_x32.exe
Ahk2Exe.exe /in LaTeXHelper.ahk /compress 1 /base %baseX64% /out released/LaTeXHelper_x64.exe
Ahk2Exe.exe /in LaTeXHelper.ahk /compress 1 /base %baseX32% /out released/LaTeXHelper_x32.exe
Ahk2Exe.exe /in CtrlRich.ahk /compress 1 /base %baseX64% /out released/CtrlRich_x64.exe
Ahk2Exe.exe /in CtrlRich.ahk /compress 1 /base %baseX32% /out released/CtrlRich_x32.exe
cmdow /run /hid SharpKnife.exe