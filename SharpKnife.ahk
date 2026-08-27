; ==============================================================================
; SharpKnife —— LaTeX / Unicode / AI / TikZ 四模式补全工具
; 作者：Andrew（经 Hermes Agent 协作）
; 环境要求：AutoHotkey v2.0+（Windows 10）
; 数据源：latexs.cvs
; 触发命令：Ctrl+J（可通过配置修改）；循环切换命令：Ctrl+Shift+J（可通过配置修改）；
; 直接切换命令：Ctrl+Shift+0/1/2/3（0=latex，1=unicode，2=AI，3=tikz，前缀可通过配置修改）；
; 触发模式列表：Ctrl+Shift+\（弹出无框列表，上下键选择模式，可通过配置修改）；
; 步进执行命令：Ctrl+R（play 模式专属，可通过配置修改）
; ==============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

; 测试钩子：以 `--selftest` 参数启动时仅验证脚本可完整解析（含 #Include 的 SharpKnifeCore.ahk），
; 不做任何初始化与副作用，随即退出（退出码 0 = 解析通过）。
; 注意：AHK v2 中 A_Args 为空时索引 [1] 会抛"越界"错误，必须先用 Length 守卫。
if (A_Args.Length >= 1 && A_Args[1] = "--selftest") {
    ExitApp(0)
}

; 编译时把托盘图标嵌入 exe 作为资源 ID 1（Ahk2Exe 编译指令，运行 .ahk 时忽略）
;@Ahk2Exe-AddResource images\SharpKnife.ico, 1

KeyHistory 0
A_MaxHotkeysPerInterval := 200
SendMode("Input")
SetWorkingDir(A_ScriptDir)
#Include SharpKnifeCore.ahk   ; 纯逻辑核心（匹配 / 模板 / play 解析校验 / JSON 工具）

; ============================================================================
; 1. 配置（来自 config.ini）
; ============================================================================
configFile := A_ScriptDir "\config.ini"

trigger_hk    := IniRead(configFile, "trigger", "hotkey", "^j")
toggle_hk     := IniRead(configFile, "trigger", "toggle_hotkey", "^+j")
direct_prefix := IniRead(configFile, "trigger", "direct_prefix", "^+")  ; 直接切换前缀（+0/1/2/3）
if (direct_prefix = "")
    direct_prefix := "^+"   ; 防止前缀为空时把裸数字 0/1/2/3 注册为热键
mode_list_hk := IniRead(configFile, "trigger", "mode_list_hotkey", "^+\")  ; 触发模式列表（弹出无框列表，上下键选择模式）
if (mode_list_hk = "")
    mode_list_hk := "^+\"    ; 防空守卫：配置为空时恢复默认
step_hotkey := IniRead(configFile, "trigger", "step_hotkey", "^r")  ; 步进执行命令（play 模式专属，无论处于哪个状态都有效）
if (step_hotkey = "")
    step_hotkey := "^r"    ; 防空守卫：配置为空时恢复默认
type_delay_ms := Max(IniRead(configFile, "context", "type_delay_ms", 3), 0)
max_typing    := Max(IniRead(configFile, "ui", "max_typing_chars", 2000), 10)

show_progress := (IniRead(configFile, "ui", "show_progress", "true") = "true")
progress_text := IniRead(configFile, "ui", "progress_text", "正在生成...")
ui_font_size  := Max(IniRead(configFile, "ui", "font_size", 10), 6)   ; 磅，最小 6

; 调试日志开关（config.ini 的 [debug] enabled）：默认 false，不输出调试日志
debug_enabled := (IniRead(configFile, "debug", "enabled", "false") = "true")

; ============================================================================
; 1b. 默认 AI 约束提示语（config.ini 的 [ai] system_prompt 可覆盖）
; ============================================================================
global DEFAULT_SYSTEM_PROMPT := "
(
你是数学排版补全助手。用户会给出一个上下文提示语（可能是未完成的 LaTeX 片段、符号或公式）。
请只输出补全结果，不要任何解释、不要多余文字。

补全结果必须遵守以下要求：
1. 默认情况下，结果必须是完整的 LaTeX 片段或范例，即能被 LaTeX/KaTeX/MathJax 合法渲染成数学公式或符号。
2. 若上下文提示语中明确要求 unicode 符号或由 unicode 符号组成的公式，则结果可以是 unicode 形式。
3. 若上下文提示语要求输出的内容是 Markdown 格式，则行内公式必须用一对 $ 包围（如 $x^2$），行间公式必须用一对 $$ 包围（如 $$<换行符>E=mc^2<换行符>$$），并且要求 $$ 独占一行；不要用 Markdown 代码块围栏包裹公式。
4. 若上下文提示语要求输出绘图代码，则：采用　MikTex + TikZ，并且如果输出包含 \begin{document}，必须使用 standalone 文档类（例如 \documentclass[border=5pt]{standalone}）；如果是 3D 绘图输出，优先采用 tikz-3dplot 宏包，具体根据上下文提示语涉及的任务，也可以改用 pgfplots 或纯 TikZ 的 3d 库。
5. 若满足要求的补全只有一种可能，返回只含一个字符串的 JSON 数组，例如：["\frac{a}{b}"]。
6. 若满足要求的补全有两种或多种可能，返回包含全部候选的 JSON 数组，例如：["\dfrac{a}{b}", "\tfrac{a}{b}"]。
7. JSON 数组中的每个字符串必须是可直接使用的 LaTeX、unicode 或绘图代码文本，并正确转义双引号和反斜杠。
8. 不要输出 markdown 代码块、不要解释、不要输出除 JSON 数组以外的任何内容。
)"

; ============================================================================
; 1c. AI 模式配置（仅对 AI 模式有效）
; ============================================================================
ai_key          := IniRead(configFile, "ai", "api_key", "")
ai_base_url     := IniRead(configFile, "ai", "base_url", "https://api.deepseek.com")
ai_endpoint     := IniRead(configFile, "ai", "endpoint", "/chat/completions")
ai_style        := IniRead(configFile, "ai", "api_style", "chat")        ; chat=聊天补全；completion=原生补全接口
ai_model        := IniRead(configFile, "ai", "model", "deepseek-v4-flash")
ai_temperature  := IniRead(configFile, "ai", "temperature", "0.3")   ; 保留字符串，避免浮点精度问题
ai_max_tokens   := Max(IniRead(configFile, "ai", "max_tokens", 4096), 1)
ai_timeout      := Max(IniRead(configFile, "ai", "timeout_ms", 30000), 5000)
ai_thinking        := IniRead(configFile, "ai", "thinking", "enabled")        ; 思考开关：enabled/disabled，留空则不发送
ai_reasoning_effort := IniRead(configFile, "ai", "reasoning_effort", "high")  ; 推理强度：low/medium/high，留空则不发送
ai_stream      := IniRead(configFile, "ai", "stream", "false")            ; 流式请求：true=边接收边输出思考过程；false=非流式（默认）
ai_system_prompt := IniRead(configFile, "ai", "system_prompt", DEFAULT_SYSTEM_PROMPT)

; ============================================================================
; 1d. tikz 模式配置（仅对 tikz 模式有效）
; ============================================================================
tikz_pdflatex   := IniRead(configFile, "tikz", "pdflatex_path", "")      ; pdflatex 路径（留空自动探测）
tikz_converter  := IniRead(configFile, "tikz", "converter", "auto")      ; PDF→PNG 转换器（auto=自动探测）
tikz_dpi        := Max(IniRead(configFile, "tikz", "dpi", 150), 30)      ; 渲染分辨率
tikz_border     := IniRead(configFile, "tikz", "border", "5pt")          ; standalone 边框留白
tikz_extra_pkgs := IniRead(configFile, "tikz", "extra_packages", "")     ; 附加宏包（逗号分隔）
tikz_timeout_ms := Max(IniRead(configFile, "tikz", "timeout_ms", 30000), 3000)  ; 编译超时（毫秒）
tikz_snipaste   := IniRead(configFile, "tikz", "snipaste_path", "")      ; Snipaste 路径（留空自动探测，PasteTikzImage 贴图用）

; ============================================================================
; 2b. 四模式定义：latex（默认）→ unicode → AI → tikz → latex 循环
;     mode：0=latex，1=unicode，2=AI，3=tikz
;     latex_mode：兼容旧逻辑（1=latex，0=unicode），由 mode 同步维护
; ============================================================================
MODE_LATEX := 0
MODE_UNICODE := 1
MODE_AI := 2
MODE_TIKZ := 3
mode_names := ["latex", "unicode", "AI", "tikz"]
global mode := MODE_LATEX            ; 当前模式（默认 latex）
global latex_mode := 1   ; 1 = LaTeX-command mode, 0 = Unicode mode（兼容旧逻辑）
global playScriptFile := ""   ; play 模式绑定的脚本文件（空=关闭状态，非空=开启状态）
global playScriptDir := ""    ; 绑定脚本所在目录（相对路径解析基准）
global playStepStack := []    ; 步进游标栈：每元素 {list: 动作数组, idx: 下一个待执行序号（0 基）}
global playBusy := false      ; 执行中标记：有动作尚未完成时为真（阻塞步进热键）
global playReentrant := false ; 防重入：文件选择对话框打开期间为真
global playMediaWatch := []   ; 异步媒体监视列表：{pid, hwnd, done}（wait=true 时轮询退出）
global playPasterWatch := []  ; 贴图窗口监视列表：{hwnd, done}（paste wait=true 时轮询贴图窗口销毁）
global playPins := []        ; 贴图置顶守护列表：{pinned: 贴图句柄, below: 实际贴图时已存在的贴图句柄数组}（paste pin=true）
global play_paster_hwnds := [] ; Snipaste 贴图窗口句柄收集缓冲（EnumWindows 回调写入）
global playFocusWin := 0      ; 弹窗动作前记录的焦点窗口（弹窗后恢复焦点，保证文字输出继续）

RefreshTrayMenu() {
    global mode
    A_TrayMenu.Delete()
    A_TrayMenu.Add((mode = MODE_LATEX ? "[x] " : "[ ] ") . "latex 模式", SetModeFromTray)
    A_TrayMenu.Add((mode = MODE_UNICODE ? "[x] " : "[ ] ") . "unicode 模式", SetModeFromTray)
    A_TrayMenu.Add((mode = MODE_AI ? "[x] " : "[ ] ") . "AI 模式", SetModeFromTray)
    A_TrayMenu.Add((mode = MODE_TIKZ ? "[x] " : "[ ] ") . "tikz 模式", SetModeFromTray)
    A_TrayMenu.Add()
    A_TrayMenu.Add("重新加载(&R)", (*) => Reload())
    A_TrayMenu.Add("退出(&X)", (*) => ExitApp())
}

; 从托盘菜单直接选择模式
SetModeFromTray(item, *) {
    global mode, latex_mode
    if InStr(item, "latex")
        mode := MODE_LATEX
    else if InStr(item, "unicode")
        mode := MODE_UNICODE
    else if InStr(item, "tikz")
        mode := MODE_TIKZ
    else
        mode := MODE_AI
    latex_mode := (mode = MODE_LATEX) ? 1 : 0
    ToolTip("模式：" . mode_names[mode + 1])
    SetTimer(() => ToolTip(), -1500)
    RefreshTrayMenu()
}

; 循环切换命令：latex → unicode → AI → tikz → latex 循环
ToggleMode(*) {
    global mode, latex_mode
    mode := Mod(mode + 1, 4)
    latex_mode := (mode = MODE_LATEX) ? 1 : 0
    ToolTip("模式：" . mode_names[mode + 1])
    SetTimer(() => ToolTip(), -1500)
    RefreshTrayMenu()
}

; 直接切换命令：直接切换到指定模式（newMode：0=latex，1=unicode，2=AI，3=tikz）
SetModeDirect(newMode, *) {
    global mode, latex_mode
    if (newMode < MODE_LATEX || newMode > MODE_TIKZ)
        return                      ; 非法模式号：无操作
    mode := newMode
    latex_mode := (mode = MODE_LATEX) ? 1 : 0
    DebugLog("SetModeDirect：切换到 " . mode_names[mode + 1] . " 模式")
    ToolTip("模式：" . mode_names[mode + 1])
    SetTimer(() => ToolTip(), -1500)
    RefreshTrayMenu()
}

; 触发模式列表：弹出无框列表（latex 模式（0）/ unicode 模式（1）/ AI 模式（2）/ tikz 模式（3）），
; 上下键移动选择，Enter 切换，Esc 取消（取消 → 无操作，保持当前模式）
ShowModeList(*) {
    items := ["latex 模式（0）", "unicode 模式（1）", "AI 模式（2）", "tikz 模式（3）"]
    idx := ShowList(items, "选择模式：")
    if (idx = 0) {
        DebugLog("ShowModeList：用户取消，无操作")
        return
    }
    DebugLog("ShowModeList：选中第 " . idx . " 项")
    SetModeDirect(idx - 1)   ; idx：1/2/3/4 → 模式号 0/1/2/3（SetModeDirect 内部会校验非法模式号）
}

; ============================================================================
; 11b. 步进执行命令（play 模式专属，默认 Ctrl+R）—— 无论处于哪个状态都有效
;      关闭状态（未绑定脚本文件）：弹出 JSON 脚本选择窗口，校验通过后绑定并立即执行第 1 步
;      开启状态（已绑定脚本文件）：执行下一步；执行中（busy）触发被忽略（防重入）
;      脚本为 UTF-8 JSON：根是 seq（顶层动作数组），支持 text/sleep/run/note/paste/audio/video/seq/par 九类动作
;      详见 Requirements.md 第 8 节
; ============================================================================
StepPlay(*) {
    global playScriptFile, playBusy
    if (playScriptFile = "") {
        PlayBind()
        return
    }
    if (playBusy)
        return
    PlayRunStepFrame()
}

; ---- 绑定 / 解绑 ----
PlayBind() {
    global playReentrant
    if (playReentrant)
        return
    playReentrant := true
    selected := ""
    try {
        selected := FileSelect(1, A_ScriptDir, "选择 play 脚本文件", "JSON 脚本 (*.json)")
    } catch {
        selected := ""
    }
    playReentrant := false
    if (selected = "") {
        DebugLog("play：用户取消选择脚本文件，无操作")
        return
    }
    PlayBindFile(selected)
}

; 绑定指定脚本文件（无文件选择框；供 PlayBind 与 --play-file= 测试钩子复用）。
; 加载失败记日志、不绑定；成功则绑定并立即执行第 1 步。
PlayBindFile(selected) {
    global playScriptFile, playScriptDir, playStepStack, playBusy
    root := PlayLoadScript(selected)
    if (root = "") {
        DebugLog("play：脚本加载失败，不绑定")
        return
    }
    playScriptFile := selected
    n := InStr(selected, "\", , -1)
    playScriptDir := n ? SubStr(selected, 1, n - 1) : A_ScriptDir
    playStepStack := [{list: root, idx: 0}]
    playBusy := false
    DebugLog("play：已绑定脚本 '" . selected . "'（顶层共 " . root.Length . " 个动作）")
    PlayRunStepFrame()
}

PlayUnbind() {
    global playScriptFile, playScriptDir, playStepStack, playBusy
    playScriptFile := ""
    playScriptDir := ""
    playStepStack := []
    playBusy := false
    DebugLog("play：脚本执行完毕，自动解绑，回到关闭状态")
}

; ---- 步进游标栈 ----
PlayRunStepFrame() {
    global playStepStack, playBusy
    if (playStepStack.Length = 0)
        return
    frame := playStepStack[playStepStack.Length]
    if (frame.idx >= frame.list.Length) {
        PlayPopStepFrame()
        return
    }
    action := frame.list[frame.idx + 1]
    playBusy := true
    PlayDispatchStepAction(action, frame)
}

PlayAdvanceStepFrame(frame) {
    global playBusy
    frame.idx += 1
    if (frame.idx >= frame.list.Length) {
        PlayPopStepFrame()
        return
    }
    playBusy := false
}

PlayPopStepFrame() {
    global playStepStack, playBusy
    playStepStack.Pop()
    if (playStepStack.Length = 0) {
        playBusy := false
        PlayUnbind()
        return
    }
    parent := playStepStack[playStepStack.Length]
    parent.idx += 1
    if (parent.idx >= parent.list.Length) {
        PlayPopStepFrame()
        return
    }
    playBusy := false
}

PlayPushSeqFrame(seqAction) {
    global playStepStack
    playStepStack.Push({list: seqAction["actions"], idx: 0})
}

PlayIsOneShot(seqAction) {
    return (seqAction.Has("oneshot") && seqAction["oneshot"])
}

; 记录弹窗前的焦点窗口（文字光标所在窗口），供弹窗后恢复焦点，保证后续文字输出继续
PlaySaveFocus() {
    global playFocusWin
    playFocusWin := WinExist("A")
}

; 恢复焦点到弹窗前的窗口（WinActivate 不改变编辑器内的光标位置）
PlayRestoreFocus() {
    global playFocusWin
    if (!playFocusWin)
        return
    try WinActivate("ahk_id " . playFocusWin)
    if (WinExist("A") = playFocusWin)
        return
    ; 弹窗进程可能延迟抢焦点，短暂等待后补一次激活
    loop 20 {
        Sleep 15
        if (WinExist("A") = playFocusWin)
            break
        try WinActivate("ahk_id " . playFocusWin)
    }
}

; ---- 动作调度 ----
PlayDispatchStepAction(action, frame) {
    if (action["type"] = "seq" && !PlayIsOneShot(action)) {
        ; 单步 seq：压入子帧，立即启动其第 1 个子动作
        PlayPushSeqFrame(action)
        PlayRunStepFrame()
        return
    }
    PlayExecTree(action, () => PlayAdvanceStepFrame(frame))
}

; 执行一棵动作（text/sleep/run/note/paste/audio/video/一次性 seq/par）；done 在完成时回调
PlayExecTree(action, done) {
    global playScriptDir
    t := action["type"]
    if (t = "text") {
        PlayDoText(action["value"], action.Get("delay", 0))
        done()
    } else if (t = "sleep") {
        PlayDoSleep(action["duration"], done)
    } else if (t = "run") {
        PlaySaveFocus()
        PlayDoRun(action, (*) => (PlayRestoreFocus(), done()))
    } else if (t = "note") {
        PlayDoNote(action, done)
    } else if (t = "paste") {
        PlaySaveFocus()
        ; PlayDoPaste 内部负责完成时机：
        ;   - 失败 → done() 立即跳过；
        ;   - 成功且 ttl>0 && wait=false（或缺省）→ 立即 done()；
        ;   - 成功且 ttl>0 && wait=true → 等贴图窗口销毁后 done()。
        ; 完成回调统一恢复焦点（wait=true 时销毁动作会抢焦点，完成后归还）。
        pasteDone := () => (PlayRestoreFocus(), done())
        try {
            PlayDoPaste(action, pasteDone)
        } catch as e {
            ; 贴图流程异常 → 记日志并当作失败跳过，保证 done() 一定被调用、不挂起执行标记
            PlayNoteFail("play：贴图动作异常：" . e.Message)
            DebugLog("play：PlayDoPaste 异常 @line " . e.Line . "：" . e.Message)
            pasteDone()
        }
    } else if (t = "audio" || t = "video") {
        PlaySaveFocus()
        PlayStartMedia(action, (*) => (PlayRestoreFocus(), done()))
    } else if (t = "seq") {
        PlayExecList(action["actions"], 1, done)
    } else if (t = "par") {
        PlayExecAll(action["actions"], done)
    } else {
        done()
    }
}

PlayExecList(list, idx, done) {
    if (idx > list.Length) {
        done()
        return
    }
    PlayExecTree(list[idx], () => PlayExecList(list, idx + 1, done))
}

PlayExecAll(list, done) {
    if (list.Length = 0) {
        done()
        return
    }
    holder := [list.Length]
    fin := () => PlayParChildDone(holder, done)
    for a in list
        PlayExecTree(a, fin)
}

PlayParChildDone(holder, done) {
    holder[1] := holder[1] - 1
    if (holder[1] <= 0)
        done()
}

; ---- text 动作 ----
; delayMs：字符输出间隔（毫秒），0 = 即时输出（保持原行为）
PlayDoText(value, delayMs := 0) {
    if (value is String) {
        PlaySendText(value, delayMs)
        return
    }
    first := true
    for item in value {
        if (!first)
            Send("{Enter}")
        PlaySendText(item, delayMs)
        first := false
    }
}

; 文本：支持 {Delay N} 段内延迟记号（自造扩展，非官方）：
;   - 遇到 {Delay 100} 时，后续所有字符与按键动作均按 100ms 间隔输出，直到下一个 {Delay N} 切换。
;   - delayMs 参数为整串的初始延迟（来自动作级 delay 字段，缺省 0）。
;   - 每发一个字符或一个按键动作后 Sleep(当前延迟)（字符与按键都延迟，保持均匀）。
PlaySendText(text, delayMs := 0) {
    curDelay := Max(delayMs, 0)
    lit := ""
    i := 1
    len := StrLen(text)
    while (i <= len) {
        c := SubStr(text, i, 1)
        if (c = "`n") {
            PlayFlushLiteral(&lit, curDelay)
            Send("{Enter}")
            if (curDelay > 0)
                Sleep(curDelay)
            i++
            continue
        }
        if (c = "`r") {
            PlayFlushLiteral(&lit, curDelay)
            Send("{Enter}")
            if (curDelay > 0)
                Sleep(curDelay)
            i++
            if (i <= len && SubStr(text, i, 1) = "`n")
                i++
            continue
        }
        if (c = Chr(96)) {
            ; 反引号转义：下一个字符字面输出
            i++
            if (i <= len) {
                lit .= SubStr(text, i, 1)
                i++
            }
            continue
        }
        if (c = "{") {
            j := InStr(text, "}", false, i + 1)
            if (j) {
                inner := SubStr(text, i + 1, j - i - 1)
                ; --- 段内延迟记号 {Delay N}（自造扩展）：切换当前延迟，不输出 ---
                ; 关键：先用旧 curDelay 冲刷已累积的字面符，避免前缀被新延迟带歪
                if (RegExMatch(inner, "i)^[Dd]elay[ ]*(-?\d+)$", &dm)) {
                    PlayFlushLiteral(&lit, curDelay)
                    nd := Integer(dm[1])
                    if (nd < 0)
                        nd := 0
                    curDelay := nd
                    i := j + 1
                    continue
                }
                if (inner != "" && RegExMatch(inner, "i)^[a-z0-9]+( [0-9]+)?$")) {
                    PlayFlushLiteral(&lit, curDelay)
                    Send("{" . inner . "}")
                    if (curDelay > 0)
                        Sleep(curDelay)
                    i := j + 1
                    continue
                }
            }
        }
        lit .= c
        i++
    }
    PlayFlushLiteral(&lit, curDelay)
}

; 冲刷缓冲的字面字符：delayMs>0 时逐字符输出并间隔 delayMs 毫秒
; 注意：每发出一个字符都 Sleep 一次（每字符后），末尾不再多 Sleep（由下一个字符/按键再 Sleep，保证均匀）。
PlayFlushLiteral(&lit, delayMs) {
    if (lit = "")
        return
    if (delayMs > 0) {
        loop StrLen(lit) {
            SendText(SubStr(lit, A_Index, 1))
            Sleep(delayMs)
        }
    } else {
        SendText(lit)
    }
    lit := ""
}

; ---- sleep 动作 ----
PlayDoSleep(duration, done) {
    ms := Round(duration * 1000)
    if (ms <= 0) {
        done()
        return
    }
    SetTimer(() => done(), -ms)
}

; ---- run 动作 ----
PlayDoRun(action, done) {
    path := PlayResolvePath(action["path"])
    args := action.Has("args") ? action["args"] : ""
    hide := (action.Has("hide") && action["hide"])
    isUrl := RegExMatch(path, "i)^(https?://|mailto:|www\.)")
    if (!isUrl && !FileExist(path)) {
        PlayNoteFail("play：运行目标不存在：" . path)
        done()
        return
    }
    target := isUrl ? path : ('"' path '"')
    if (args != "")
        target .= " " . args
    pid := 0
    try {
        Run(target, , hide ? "Hide" : "", &pid)
    } catch {
        PlayNoteFail("play：启动程序失败：" . path)
        done()
        return
    }
    if (action.Has("wait") && action["wait"])
        PlayWatchMedia(pid, 0, done)
    else
        done()
}

; ---- note 动作 ----
PlayDoNote(action, done) {
    ToolTip(action["text"])
    ms := Round(action["duration"] * 1000)
    if (ms <= 0)
        ms := 2500
    SetTimer(() => (ToolTip(), done()), -ms)
}

; ---- paste 动作 ----
; done：动作完成回调（贴图动作立即完成；delay>0 时延迟贴图；wait=true 时等待贴图窗口销毁后才完成）
PlayDoPaste(action, done) {
    ; delay > 0：贴图动作执行后延迟 delay 毫秒再实际贴图。
    ; 延迟期间不调用 done（playBusy 保持 true，步进阻塞、脚本不推进），
    ; 到点后执行实际贴图主体 PlayDoPasteNow，由其控制完成时机。
    delayMs := action.Get("delay", 0)
    if (delayMs > 0) {
        DebugLog("play：delay 生效，delay=" . delayMs . " 毫秒后贴图")
        SetTimer(() => PlayDoPasteNow(action, done), -delayMs)
        return
    }
    PlayDoPasteNow(action, done)
}

; 实际贴图主体（delay=0 立即执行；delay>0 由定时器延迟调用）
PlayDoPasteNow(action, done) {
    path := PlayResolvePath(action["path"])
    if (!FileExist(path)) {
        PlayNoteFail("play：粘贴图片不存在：" . path)
        done()
        return
    }
    pngPath := path
    tmpFile := ""
    ; size 和 opacity(<100) 都需要先生成临时 PNG：
    ;   size    → scale.ps1 缩放；
    ;   opacity → scale.ps1 把不透明度烘焙进 alpha 通道（不用 WinSetTransparent，
    ;             因为 Snipaste 贴图窗口由 UpdateLayeredWindow 管理，外部改窗口 alpha
    ;             会破坏其拖拽缩放交互并出现红框）。
    needScale := action.Has("size")
    needAlpha := (action.Has("opacity") && action["opacity"] < 100)
    if (needScale || needAlpha) {
        s := needScale ? action["size"] : {w: 0, h: 0}
        alphaPct := needAlpha ? action["opacity"] : 100
        tmpDir := A_Temp "\SharpKnife\play"
        DirCreate(tmpDir)
        tmpFile := tmpDir "\paste_" . A_TickCount . ".png"
        if (PlayScalePng(path, s.w, s.h, tmpFile, alphaPct))
            pngPath := tmpFile
        else
            DebugLog("play：缩放/透明失败，回退到原图")
    }
    ; 确保 Snipaste 运行
    exe := FindSnipaste()
    if (exe = "") {
        if (tmpFile != "" && FileExist(tmpFile))
            try FileDelete(tmpFile)
        PlayNoteFail("play：未找到 Snipaste，无法贴图")
        done()
        return
    }
    if (!ProcessExist("Snipaste.exe")) {
        try Run(exe)
        loop 50 {
            if (ProcessExist("Snipaste.exe"))
                break
            Sleep 100
        }
        Sleep 1500
    }
    ; 贴图命令：paste --files <无引号全路径>（不经过剪贴板/GDI+）
    ; 实测（Snipaste 2.11.3 + AHK v2 Run）：exe 与图片路径均无空格、完全无引号时
    ; paste --files 100% 可靠；Target 中任何引号都会触发 AHK 引号解析导致参数损坏。
    ; 路径含空格时依次尝试：8.3 短路径 → 复制到无空格临时目录。
    cmd := PlayBuildPasteCmd(exe, pngPath)
    if (cmd = "" && tmpFile = "") {
        ; 复制到无空格临时目录（AHK v2 FileCopy 成功返回空串而非 true，
        ; 失败抛异常 → 用 try + FileExist 判断）
        tmpDir := A_Temp "\SharpKnife\play"
        DirCreate(tmpDir)
        cpTmp := tmpDir "\paste_" . A_TickCount . ".png"
        try {
            FileCopy(pngPath, cpTmp, 1)
            if (FileExist(cpTmp)) {
                tmpFile := cpTmp
                pngPath := cpTmp
                cmd := PlayBuildPasteCmd(exe, pngPath)
            }
        }
    }
    if (cmd = "") {
        if (tmpFile != "" && FileExist(tmpFile))
            try FileDelete(tmpFile)
        PlayNoteFail("play：无法构造 Snipaste 贴图命令（exe 或图片路径含空格且无法消除，"
            . "建议图片置于无空格路径）")
        done()
        return
    }
    ; 贴图并找到新贴图窗口
    before := PlayPasterHwnds()
    newHwnd := 0
    loop 4 {
        Run(cmd, , "Hide")
        deadline := A_TickCount + 2500
        while (A_TickCount < deadline) {
            newHwnd := PlayNewPaster(before)
            if (newHwnd)
                break
            Sleep 100
        }
        if (newHwnd)
            break
        DebugLog("play：贴图窗口未出现，重试（第 " . A_Index . " 次）")
        Sleep 800
    }
    if (tmpFile != "" && FileExist(tmpFile))
        try FileDelete(tmpFile)
    if (!newHwnd) {
        PlayNoteFail("play：Snipaste 贴图失败（贴图窗口未出现）")
        done()
        return
    }
    ; 定位：
    ;  - 无 pos：主屏水平竖直都居中。
    ;  - 有 pos：默认直接移动到 [x, y]；支持负值居中语义——
    ;        x < 0（且 y >= 0）→ 水平居中、竖直位置由 y 确定；
    ;        y < 0（且 x >= 0）→ 竖直居中、水平位置由 x 确定；
    ;        x < 0 且 y < 0    → 水平竖直都居中（等效于未设置 pos）。
    ;    统一规则：x < 0 时 x 取水平居中值；y < 0 时 y 取竖直居中值。
    if (action.Has("pos")) {
        p := action["pos"]
        px := p.x
        py := p.y
        needX := (px < 0)
        needY := (py < 0)
        if (needX || needY) {
            try {
                WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . newHwnd)
                if (needX)
                    px := Max((A_ScreenWidth - ww) // 2, 0)
                if (needY)
                    py := Max((A_ScreenHeight - wh) // 2, 0)
            }
        }
        WinMove(px, py, , , "ahk_id " . newHwnd)
    } else {
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . newHwnd)
            WinMove(Max((A_ScreenWidth - ww) // 2, 0), Max((A_ScreenHeight - wh) // 2, 0), , , "ahk_id " . newHwnd)
        }
    }
    ; pin：置顶守护——该贴图存活期间始终保持"本次实际贴图时已存在的全部贴图"之上。
    ; 被压住的旧贴图被点击置前后，守护轮询会把本贴图提回最前（详见 Requirements.md 8.1）。
    if (action.Get("pin", false)) {
        DebugLog("play：pin 生效，newHwnd=" . newHwnd . "，压住先前贴图数=" . before.Length)
        PlayPinPaster(newHwnd, before)
    }
    ; 注：opacity 已在贴图前烘焙进图片 alpha 通道（见上文 needAlpha），此处不再对窗口做 WinSetTransparent，
    ; 以保持 Snipaste 贴图窗口原生可交互（拖边缩放 / 无红框）。
    ; ttl > 0：贴图经 ttl 毫秒后自动销毁该贴图窗口。
    ; 关闭方式见 PlayClosePaster：激活窗口 + Send Esc（Snipaste 官方销毁交互，
    ; 权威实测 WM_CLOSE / SC_CLOSE / DestroyWindow 均无法关闭 Paster 窗口）。
    ; ttl = 0（缺省）不自动销毁，由用户手动销毁。
    delayMs := action.Get("delay", 0)
    ttlMs := action.Get("ttl", 0)
    if (ttlMs > 0) {
        DebugLog("play：ttl 生效，newHwnd=" . newHwnd . " ttl=" . ttlMs)
        try {
            ; 注意：AHK v2 的 SetTimer 第 3+ 参数不是"传给回调的值"——
            ; SetTimer(Func, period, value) 会抛 "Invalid callback function"（实测）。
            ; 必须用 Bind 预先绑定参数，或闭包捕获。
            SetTimer(PlayClosePaster.Bind(newHwnd), -ttlMs)
        } catch as e {
            DebugLog("play：ttl SetTimer 异常：" . e.Message)
        }
    }
    ; wait：仅 delay>0 或 ttl>0 时有意义（delay=0 且 ttl=0 时 ignore，始终相当于 false）。
    ; wait=true：等待该贴图窗口关闭（ttl 到期自动销毁，或用户手动销毁）后才完成动作；
    ; wait=false（或缺省）：无须等待，立即完成（贴图窗口按 ttl 自行销毁或由用户销毁）。
    if ((delayMs > 0 || ttlMs > 0) && action.Get("wait", false)) {
        DebugLog("play：wait=true，等待贴图窗口关闭后继续，newHwnd=" . newHwnd)
        PlayWatchPaster(newHwnd, done)
        return
    }
    done()
}

; ---- audio / video 动作 ----
PlayStartMedia(action, done) {
    path := PlayResolvePath(action["path"])
    if (!FileExist(path)) {
        PlayNoteFail("play：媒体文件不存在：" . path)
        done()
        return
    }
    exe := FindToolPath("ffplay")
    if (exe = "") {
        PlayNoteFail("play：未找到 ffplay，无法播放媒体")
        done()
        return
    }
    isVideo := (action["type"] = "video")
    startSec := (action.Has("start") && action["start"] > 0) ? action["start"] : 0
    endSec := action.Has("end") ? action["end"] : -1
    volume := action.Has("volume") ? action["volume"] : 1.0

    cmd := '"' exe '" '
    cmd .= isVideo ? "-autoexit " : "-nodisp -autoexit "
    if (startSec > 0)
        cmd .= "-ss " . PlayNum(startSec) . " "
    if (endSec >= 0) {
        dur := endSec - startSec
        if (dur < 0)
            dur := 0
        cmd .= "-t " . PlayNum(dur) . " "
    }
    cmd .= "-af volume=" . PlayNum(volume) . " "
    if (isVideo) {
        posX := action.Has("pos") ? action["pos"].x : 0
        posY := action.Has("pos") ? action["pos"].y : 0
        posNegX := action.Has("pos") && posX < 0
        posNegY := action.Has("pos") && posY < 0
        if (action.Has("pos") && !posNegX && !posNegY) {
            ; 常规正坐标：启动时用 ffplay 原生 -left/-top 定位（默认行为，与历史一致）
            cmd .= "-left " . posX . " -top " . posY . " "
        } else if (action.Has("pos")) {
            ; pos 含负值（居中语义）：-left/-top 不能传负值，启动后由 PlayCenterMediaWindow 修正位置
            DebugLog("play：video pos 负值居中语义，启动后定位，pos=[" . posX . "," . posY . "]")
        }
        if (action.Has("size")) {
            if (action["size"].w > 0)
                cmd .= "-x " . action["size"].w . " "
            if (action["size"].h > 0)
                cmd .= "-y " . action["size"].h . " "
        }
    }
    cmd .= '-i "' path '"'

    ; cmd /S /C 包装 + Hide：视频窗口可见而控制台隐藏（直接 Run + Hide 会连视频窗口一起隐藏）
    fullCmd := A_ComSpec " /S /C `"" . cmd . "`" < nul > nul 2>&1"
    pid := 0
    try {
        Run(fullCmd, , "Hide", &pid)
    } catch {
        PlayNoteFail("play：启动 ffplay 失败")
        done()
        return
    }

    hwnd := 0
    if (isVideo) {
        hwnd := PlayWaitSdlWindow(path, 3000)
        ; pos 负值居中语义：x<0 → 水平居中；y<0 → 竖直居中（双负 = 双居中）
        if (hwnd && action.Has("pos")) {
            px0 := action["pos"].x
            py0 := action["pos"].y
            cx := (px0 < 0)
            cy := (py0 < 0)
            if (cx || cy) {
                try {
                    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . hwnd)
                    px := cx ? Max((A_ScreenWidth - ww) // 2, 0) : px0
                    py := cy ? Max((A_ScreenHeight - wh) // 2, 0) : py0
                    WinMove(px, py, , , "ahk_id " . hwnd)
                }
            }
        }
        if (hwnd && action.Has("opacity") && action["opacity"] < 100)
            WinSetTransparent(Round(action["opacity"] * 255 / 100), "ahk_id " . hwnd)
    }

    if (action.Has("wait") && action["wait"])
        PlayWatchMedia(pid, hwnd, done)
    else
        done()
}

PlayWaitSdlWindow(videoPath, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    while (A_TickCount < deadline) {
        for w in WinGetList("ahk_class SDL_app") {
            try {
                if (InStr(WinGetTitle(w), videoPath))
                    return w
            }
        }
        Sleep 100
    }
    return 0
}

PlayWatchMedia(pid, hwnd, done) {
    global playMediaWatch
    playMediaWatch.Push({pid: pid, hwnd: hwnd, done: done})
    SetTimer(PlayMediaPoll, 200)
}

PlayMediaPoll() {
    global playMediaWatch
    if (playMediaWatch.Length = 0) {
        SetTimer(PlayMediaPoll, 0)
        return
    }
    still := []
    for item in playMediaWatch {
        alive := ProcessExist(item.pid)
        winAlive := item.hwnd ? WinExist("ahk_id " . item.hwnd) : 1
        if (alive && winAlive) {
            still.Push(item)
        } else {
            cb := item.done
            cb()
        }
    }
    playMediaWatch := still
}

; ---- JSON 解析（play 脚本） ----
; 读取脚本文件 → 解析 + 校验（纯逻辑在 SharpKnifeCore.ahk 的 PlayParseScriptText）；失败返回 "" 并弹窗
PlayLoadScript(path) {
    txt := ""
    try {
        txt := FileRead(path, "UTF-8")
    } catch as e {
        PlayShowError("读取脚本失败：" . e.Message)
        return ""
    }
    errMsg := ""
    root := PlayParseScriptText(txt, &errMsg)
    if (!root) {
        PlayShowError(errMsg)
        return ""
    }
    return root
}

; ---- 结构校验（加载阶段） ----（实现已移至 SharpKnifeCore.ahk：PlayValidate* / PlayIs* / PlayTimeToSeconds / PlayHexToInt）

; ---- 图片缩放 / 透明度（PowerShell System.Drawing，不用 GDI+） ----
; 用户明确要求不用 GDI+（GdiplusShutdown 在本机必崩、Startup 间歇失败）。
; 改用 PowerShell System.Drawing：powershell -STA 调用 scale.ps1，
; 输出 PNG 到目标路径。失败返回 false（调用方回退原图）。
; alphaPct（0~100）：<100 时把不透明度烘焙进图片 alpha 通道（Snipaste 贴图窗口由
; UpdateLayeredWindow 管理，直接 WinSetTransparent 会破坏其缩放交互——改为烘焙到图内）。
PlayScalePng(srcPath, outW, outH, outPath, alphaPct := 100) {
    ps := A_ScriptDir "\scale.ps1"
    if (!FileExist(ps)) {
        DebugLog("play：缩放 scale.ps1 不存在：" ps)
        return false
    }
    if (FileExist(outPath))
        try FileDelete(outPath)
    cmd := 'powershell -STA -NoProfile -ExecutionPolicy Bypass -File "' ps '" -SrcPath "' srcPath '" -W ' outW ' -H ' outH ' -AlphaPct ' alphaPct ' -Out "' outPath '"'
    try {
        RunWait(cmd, , "Hide")
    } catch as e {
        DebugLog("play：缩放 RunWait 异常：" e.Message)
        return false
    }
    ok := FileExist(outPath)
    DebugLog("play：缩放保存 ok=" ok " 目标=" outPath " alpha=" alphaPct)
    return ok
}

; 构造 paste --files 贴图命令（AHK Run 无引号方式）
; 实测（Snipaste 2.11.3）：AHK Run 的 Target 只要出现引号（exe 或参数任一）就会走
; "引号解析"路径重建 lpCommandLine，导致参数损坏（Snipaste 收不到 --files）；
; 完全无引号时 AHK 把整串直接作为 lpCommandLine 传给 CreateProcess，参数正确。
; 因此返回的命令要求 exe 与文件路径都不含空格。
; 含空格的路径用 GetShortPathName 转 8.3 短路径；仍无法消除空格则返回 ""（调用方处理）。
PlayBuildPasteCmd(exe, filePath) {
    e := exe
    f := filePath
    if (InStr(e, " ") || InStr(f, " ")) {
        if (InStr(e, " "))
            e := PlayToShortPath(e)
        if (InStr(f, " "))
            f := PlayToShortPath(f)
        if (e = "" || f = "")
            return ""
    }
    if (e = "" || f = "" || InStr(e, " ") || InStr(f, " "))
        return ""
    return e " paste --files " f
}

; 转 8.3 短路径（GetShortPathNameW）；失败返回 ""
PlayToShortPath(p) {
    n := DllCall("GetShortPathNameW", "Str", p, "Ptr", 0, "UInt", 0, "UInt")
    if (n = 0)
        return ""
    buf := Buffer((n + 1) * 2)
    DllCall("GetShortPathNameW", "Str", p, "Ptr", buf, "UInt", n + 1, "UInt")
    return StrGet(buf, n, "UTF-16")
}

; Snipaste 贴图窗口枚举（Paster 是 Qt 工具窗口，WinGetList 默认排除，须 EnumWindows）
PlayPasterHwnds() {
    global play_paster_hwnds
    static cb := 0
    if (!cb)
        cb := CallbackCreate(PlayPasterEnumHwnds)
    play_paster_hwnds := []
    DllCall("EnumWindows", "Ptr", cb, "Ptr", 0)
    return play_paster_hwnds
}

PlayPasterEnumHwnds(hwnd, lParam) {
    global play_paster_hwnds
    title := Buffer(256)
    DllCall("GetWindowText", "Ptr", hwnd, "Ptr", title, "Int", 128)
    if (InStr(StrGet(title), "Paster - Snipaste"))
        play_paster_hwnds.Push(hwnd)
    return true
}

PlayNewPaster(before) {
    for h in PlayPasterHwnds() {
        found := false
        for b in before {
            if (h = b) {
                found := true
                break
            }
        }
        if (!found)
            return h
    }
    return 0
}

; ---- paste wait=true：轮询等贴图窗口销毁后完成动作 ----
; 贴图动作 ttl>0 且 wait=true 时，粘贴完成后不立即 done，而是进入监视：
; 轮询直到该贴图窗口（hwnd）消失（ttl 到期自动销毁，或用户手动销毁）才调 done。
PlayWatchPaster(hwnd, done) {
    global playPasterWatch
    playPasterWatch.Push({hwnd: hwnd, done: done})
    SetTimer(PlayPasterPoll, 200)
}

PlayPasterPoll() {
    global playPasterWatch
    if (playPasterWatch.Length = 0) {
        SetTimer(PlayPasterPoll, 0)
        return
    }
    still := []
    for item in playPasterWatch {
        if (WinExist("ahk_id " . item.hwnd)) {
            still.Push(item)
        } else {
            cb := item.done
            cb()
        }
    }
    playPasterWatch := still
}

; ---- paste pin：置顶守护（该贴图存活期间始终在"实际贴图时已存在的全部贴图"之上） ----
; 贴 B 时若 pin=true，把 B 的句柄与"贴 B 时已存在的贴图句柄集合"登记进 playPins，
; PlayPinPoll 每 100ms 沿 Z 序链检查：任一登记窗口跑到 B 上面（典型场景：被鼠标点击置前）
; 就用 PlayRaiseTop 把 B 提回最前（不抢焦点、不动位置）；B 销毁后自动解除守护。
PlayPinPaster(hwnd, below) {
    global playPins
    playPins.Push({pinned: hwnd, below: below})
    SetTimer(PlayPinPoll, 100)
}

PlayPinPoll() {
    global playPins
    if (playPins.Length = 0) {
        SetTimer(PlayPinPoll, 0)
        return
    }
    still := []
    for item in playPins {
        if (!WinExist("ahk_id " . item.pinned)) {
            DebugLog("play：pin 解除（贴图已销毁），hwnd=" . item.pinned)
            continue                     ; 守护对象已销毁：注销
        }
        ; 剪掉已销毁的"被压住"窗口，避免句柄复用导致误判
        alive := []
        for b in item.below {
            if (WinExist("ahk_id " . b))
                alive.Push(b)
        }
        if (PlayBelowAbovePinned(item.pinned, alive)) {
            DebugLog("play：pin 守护触发——先前贴图被点到上方，把 " . item.pinned . " 提回最前")
            PlayRaiseTop(item.pinned)
        }
        if (alive.Length > 0)
            still.Push({pinned: item.pinned, below: alive})
    }
    playPins := still
}

; 沿 Z 序链（GetWindow GW_HWNDPREV=3）从 pinned 向上探查：below 中任一窗口在 pinned 之上 → true
PlayBelowAbovePinned(pinned, below) {
    h := DllCall("GetWindow", "Ptr", pinned, "UInt", 3, "Ptr")
    while (h) {
        for b in below {
            if (h = b)
                return true
        }
        h := DllCall("GetWindow", "Ptr", h, "UInt", 3, "Ptr")
    }
    return false
}

; 把窗口提到置顶层最前：不抢焦点、不改位置尺寸。
; 优先 WinMoveTop（AHK v2 内置），不可用时退化为 SetWindowPos HWND_TOP + SWP_NOSIZE|NOMOVE|NOACTIVATE|SHOWWINDOW。
PlayRaiseTop(hwnd) {
    try {
        WinMoveTop("ahk_id " . hwnd)
    } catch {
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x53)
    }
}

; 销毁（关闭）指定的 Snipaste 贴图窗口（Paster）
; 实测（权威验证 test/run-close-test2.ps1）：Paster 是 Snipaste 自管理的 Qt 工具窗口，
; PostMessage WM_CLOSE / WM_SYSCOMMAND+SC_CLOSE / DestroyWindow 全部无效（窗口不消失）。
; 唯一有效方式 = Snipaste 官方销毁交互：让贴图窗口获得焦点后按 Esc（等同用户按 Esc 销毁当前贴图）。
; 因此这里：记录原焦点窗口 → WinActivate 贴图窗口 → Send Esc → 轮询确认销毁 → 恢复原焦点。
; 若 Esc 后仍未销毁（极端情况），补投 WM_CLOSE / SC_CLOSE 尽力而为，最后恢复焦点、记日志。
PlayClosePaster(hwnd) {
    DebugLog("play：PlayClosePaster 触发，hwnd=" . hwnd)
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return
    prevWin := WinExist("A")                     ; 销毁前的前台窗口（销毁后恢复焦点）
    ; 1) Snipaste 官方销毁：激活贴图窗口 → 按 Esc
    WinActivate("ahk_id " . hwnd)
    Sleep 150
    Send("{Esc}")
    loop 6 {
        Sleep 200
        if (!WinExist("ahk_id " . hwnd)) {       ; 已销毁
            PlayRestoreFocusTo(prevWin)
            return
        }
    }
    ; 2) 兜底：消息方式（权威测试证明无效，尽力尝试）
    loop 2 {
        DllCall("PostMessage", "Ptr", hwnd, "UInt", 0x0010, "Ptr", 0, "Ptr", 0)  ; WM_CLOSE
        DllCall("PostMessage", "Ptr", hwnd, "UInt", 0x0112, "Ptr", 0xF060, "Ptr", 0) ; SC_CLOSE
        Sleep 200
        if (!WinExist("ahk_id " . hwnd)) {
            PlayRestoreFocusTo(prevWin)
            return
        }
    }
    PlayRestoreFocusTo(prevWin)
    DebugLog("play：贴图窗口自动销毁未生效（ttl 到期后 Esc/关闭消息均未关闭），hwnd=" . hwnd)
}

; 恢复焦点到指定窗口（ttl 自动销毁抢焦点后归还；无效则静默）
PlayRestoreFocusTo(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return
    try WinActivate("ahk_id " . hwnd)
}

; ---- 提示与工具 ----
PlayShowError(msg) {
    DebugLog("play：错误 - " . msg)
    MsgBox(msg, "SharpKnife - play 脚本错误", "Icon!")
}

PlayNoteFail(msg) {
    DebugLog(msg)
    ToolTip(msg)
    SetTimer(() => ToolTip(), -2500)
}

; PlayResolvePath / PlayNum 实现已移至 SharpKnifeCore.ahk

; ============================================================================
; 3. 加载 latexs.cvs —— 原始条目列表（模式过滤在触发时进行）
; ============================================================================
cvsFile := A_ScriptDir "\latexs.cvs"
global cvsEntries := []   ; 每个条目：{key, f2, f3, hasF3}

; ============================================================================
; 调试日志（写入文件；由 config.ini 的 [debug] enabled 控制，默认关闭）
; ============================================================================
global debugLogFile := A_ScriptDir "\debug.log"
DebugLog(msg) {
    global debugLogFile
    if (!debug_enabled)
        return                      ; 调试开关关闭：不输出任何日志
    try
        FileAppend(msg "`n", debugLogFile, "UTF-8")   ; UTF-8 写入防中文乱码；文件被占用时静默跳过，不打断补全
}

; 启动时清空旧日志（仅调试开关开启时）
if (debug_enabled) {
    try FileDelete(debugLogFile)
    DebugLog("=== SharpKnife 调试日志开始 ===")
}

cvsEntries := LoadCvsEntries(cvsFile)   ; 实现见 SharpKnifeCore.ahk

DebugLog("cvsEntries 数量=" cvsEntries.Length)

; ============================================================================
; 4. 上下文解析 + 匹配 —— 实现已移至 SharpKnifeCore.ahk（IsValidStar / GetContextInfo / FindMatches）
; ============================================================================

; ============================================================================
; 5. 逐字输入文本（带可配置的逐字延迟）
; ============================================================================
TypeTextSlowly(text) {
    i := 0
    while (i < StrLen(text)) {
        ch := SubStr(text, i + 1, 1)
        ; 一律用 SendText 输入，避免 AHK 把 '+', '^', '{', '}' 等字符当作修饰键或动作
        SendText(ch)
        i++
        if (type_delay_ms > 0)
            Sleep(type_delay_ms)
    }
}

; ============================================================================
; 9b. 处理 LaTeX 模板：处理 {Text} 前缀与 ##{Left N} 标记（实现已移至 SharpKnifeCore.ahk）
; ============================================================================

; ============================================================================
; 11. 模式切换命令 —— 均可通过配置修改
;     循环切换：默认 Ctrl+Shift+J（latex → unicode → AI → tikz → latex）
;     直接切换：默认 Ctrl+Shift+0/1/2/3（0=latex，1=unicode，2=AI，3=tikz），前缀可配置
;     模式列表：默认 Ctrl+Shift+\（弹出无框列表，上下键选择模式，Enter 切换）
; ============================================================================
Hotkey(toggle_hk, ToggleMode)
Hotkey(direct_prefix . "0", (*) => SetModeDirect(MODE_LATEX))
Hotkey(direct_prefix . "1", (*) => SetModeDirect(MODE_UNICODE))
Hotkey(direct_prefix . "2", (*) => SetModeDirect(MODE_AI))
Hotkey(direct_prefix . "3", (*) => SetModeDirect(MODE_TIKZ))
Hotkey(mode_list_hk, ShowModeList)
Hotkey(step_hotkey, StepPlay)

; ============================================================================
; 12. 主入口 —— 触发命令（默认 Ctrl+J）
; ============================================================================
Hotkey(trigger_hk, CompleteAI)

CompleteAI(*) {
    DebugLog("CompleteAI：开始")
    ; --- AI / tikz 模式：无上下文匹配限制，直接进入各自流程（latex/unicode 逻辑保持不变）---
    if (mode = MODE_AI) {
        CompleteAI_Generate()
        return
    }
    if (mode = MODE_TIKZ) {
        CompleteTikz()
        return
    }
    if (show_progress && progress_text != "")
        ToolTip(progress_text)

    ; --- 上下文选择：优先使用触发前的人工选区，否则取光标前的非空连续字符串 ---
    ctx := GetContext()
    context := ctx.text
    fromSel := ctx.fromSelection
    DebugLog("CompleteAI：context='" context "'" . (fromSel ? "（选区）" : "（光标前）"))
    if (context = "") {
        ToolTip()
        DebugLog("CompleteAI：空上下文，无操作")
        return
    }

    ; --- 上下文校验：<前缀><非空待匹配串>；非法上下文 → 直接返回，无操作 ---
    info := GetContextInfo(context)
    if (info = 0) {
        ToolTip()
        DebugLog("CompleteAI：非法上下文，无操作")
        return
    }
    DebugLog("CompleteAI：prefix='" info.prefix "' search='" info.search "'")

    ; --- 上下文匹配 ---
    matches := FindMatches(info)
    DebugLog("CompleteAI：匹配数=" matches.Length)
    if (matches.Length = 0) {
        ToolTip()
        DebugLog("CompleteAI：无匹配，无操作")
        return
    }

    ; --- 匹配出两项或更多 → 弹出无框选择列表（最多显示10项，上下键滚动可见全部）---
    if (matches.Length > 1) {
        idx := ShowMultiSelection(matches, context)
        if (idx = 0) {
            ; 用户取消 → 无操作
            ToolTip()
            DebugLog("CompleteAI：用户取消，无操作")
            return
        }
        match := matches[idx]
    } else {
        match := matches[1]
    }
    DebugLog("CompleteAI：选定 key='" match.key "' type=" match.type)

    ; --- 删除上下文：选区直接 Delete；光标前上下文先选中再单次 Delete ---
    ; （逐个退格在 Chromium 编辑器（VSCode/Obsidian）中可能丢键，改为选中后一次删除）
    if (fromSel)
        Send("{Delete}")
    else {
        Send("{Shift down}")
        Send("{Left " StrLen(context) "}")
        Send("{Shift up}")
        Send("{Delete}")
    }

    ; --- 动作触发 ---
    leftMove := 0
    if (latex_mode) {
        if (match.hasF3) {
            ; 三个字段 → 用第三个字段解析后的字符串替换，光标左移指定格数
            processed := ProcessLatexTemplate(match.f3)
            completion := processed.text
            leftMove := processed.leftMove
        } else {
            ; 两个字段 → 用第一个字段（键）替换，尾部补一个空格
            completion := match.key . " "
        }
    } else {
        ; unicode 模式 → 用第二个字段（剔除 : 前缀）替换，尾部补一个空格
        completion := match.f2
        if (SubStr(completion, 1, 1) = ":")
            completion := SubStr(completion, 2)
        completion .= " "
    }
    DebugLog("CompleteAI：completion='" completion "' leftMove=" leftMove)

    if (StrLen(completion) > max_typing) {
        ove := SubStr(completion, 1, max_typing)
        MsgBox(
            "补全内容有 " . StrLen(completion) . " 个字符。`n"
            . "仅输入前 " . max_typing . " 个字符。`n`n按 Ctrl+Z 可撤销。",
            "SharpKnife 补全"
        )
        completion := ove
    }
    TypeTextSlowly(completion)
    if (leftMove > 0) {
        loop leftMove {
            Send("{Left}")
            Sleep(1)
        }
    }
    ToolTip()
    DebugLog("CompleteAI：完成")
}

; ============================================================================
; 12b. GetContext —— latex/unicode 模式上下文选择（与 AI 模式一致，选区优先）
;      情况1（优先）：触发前已有人工选择的内容 → 直接用选区作为上下文；
;      情况2（否则）：文字光标前的非空连续字符串。
;      返回 {text, fromSelection}；text 为空表示无可用上下文。
;
;      选区检测分两层（2026-08-11 修复“手工选整行被误判”）：
;        - 第一层：控件级 API（ControlGetFocus + EditGetSelectedText）直接读取真实选区，
;          记事本等标准 Edit/RichEdit 控件无歧义。剪贴板方案无法区分“手工选整行”与
;          “无选区 Ctrl+C 复制整行”（两者复制内容相同），会把整行选区误判为无选区，
;          导致上下文被错误截成行尾连续字符串（实测整行选区“基于 miktex 绘制 三维直角
;          坐标系 ， 为后续的 3D 绘图做准备。”被误判后上下文=“绘图做准备。”）；
;        - 第二层（回退，非标准控件如 vscode/obsidian）：剪贴板探测 + 前缀/重建验证：
;          vscode/obsidian 等编辑器在“无选区”时按 Ctrl+C 会复制整行，
;          不能仅凭剪贴板非空就判定为“手工选区”：
;           - 复制内容为多行 → 只可能是人工选区，直接信任剪贴板内容（不做重建验证：
;             重建依赖“编辑器内部字符数 = 剪贴板字符数”，而记事本/Typora 等编辑器内部
;             换行按 1 字符计、剪贴板 \r\n 按 2 字符计 → 多行重建必然偏差，实测 selLen=25 rebuildLen=29）；
;           - 复制内容为单行 → 用“^c 内容”与“+{Home}^c 行首→光标内容”的前缀关系区分：
;             互为前缀（典型为整行复制）→ 判定无手工选区，按情况2处理；
;             否则 → 重建选区并验证，确认是手工选区后整体删除。
; ============================================================================
GetContext() {
    ; 等待前台窗口稳定（GUI/菜单关闭后的窗口切换竞态期），避免后续按键注入被系统吞掉
    h := WinExist("A")
    loop 20 {
        Sleep(15)
        if (WinExist("A") != h) {
            h := WinExist("A")
            continue
        }
    }
    prevClip := ClipboardAll()

    ; --- 情况1：检测触发前已有的人工选择 ---
    ; 第一层：控件级 API 检测真实选区（记事本等标准 Edit/RichEdit 控件直接读取选中文本，
    ; 无歧义）。剪贴板方案有固有缺陷——无选区 Ctrl+C 复制整行 与 手工选整行 的复制内容
    ; 相同，“前缀关系”判断会把“手工选整行”误判为“空选区整行复制”而误走情况2，此时光标
    ; 已被折叠到行尾 → 上下文被错误截成行尾连续字符串（实测整行选区“基于 miktex 绘制
    ; 三维直角坐标系 ， 为后续的 3D 绘图做准备。”被误判后上下文=“绘图做准备。”）。
    selText := ""
    try {
        focused := ControlGetFocus("A")
        if (focused != "")
            selText := EditGetSelectedText(focused, "A")
    } catch {
        selText := ""
    }
    if (selText != "") {
        DebugLog("上下文：控件检测到手工选区，长度=" StrLen(selText))
        return {text: Trim(selText, " `t`r`n"), fromSelection: true}
    }
    ; 第二层：剪贴板探测（非标准控件如 vscode/obsidian 的回退方案）
    ; 注：全部按键注入用 SendEvent（keybd_event 模拟）——SendInput 在 GUI 关闭后的窗口切换
    ; 竞态窗口内可能被前台锁拒绝导致按键丢失（实测模式列表刚关闭立即触发时 ^c 与折叠键均会失效）
    A_Clipboard := ""
    SendEvent("^c")
    selected := ""
    if (ClipWait(0.5))
        selected := A_Clipboard

    if (selected != "") {
        selClean := RTrim(selected, "`r`n")

        ; 多行选区只可能是人工选区（空选区按 Ctrl+C 复制整行一定是单行）→ 直接信任剪贴板内容；
        ; 不做“重建验证”：重建依赖“编辑器内部字符数 = 剪贴板字符数”，而记事本/Typora 等
        ; 编辑器内部换行按 1 字符计、剪贴板 \r\n 按 2 字符计 → 多行重建必然偏差（实测
        ; selLen=25 rebuildLen=29）→ 多行必须跳过验证，直接采信选区。
        if (InStr(selClean, "`n") || InStr(selClean, "`r")) {
            DebugLog("上下文：确认手工选区，长度=" StrLen(selected))
            return {text: Trim(selected, " `t`r`n"), fromSelection: true}
        }

        ; --- 以下仅单行：才可能是“空选区整行复制”误判 ---
        ; 折叠选区（若有），使光标落在选区右端
        SendEvent("{Right}")
        Sleep(40)                       ; 等待应用处理折叠（Electron 等异步编辑器需时间处理按键）
        A_Clipboard := prevClip

        ; 读取光标前的行内容，用于与 selected 对比
        A_Clipboard := ""
        SendEvent("+{Home}^c")
        line := ""
        if (ClipWait(0.5))
            line := A_Clipboard
        SendEvent("{Right}")     ; 折叠 +{Home} 选区
        Sleep(40)
        A_Clipboard := prevClip

        ; 前缀关系 → 空选区整行复制误判 → 无手工选区，走情况2
        if (IsPrefix(selClean, line) || IsPrefix(line, selClean)) {
            ; 光标因折叠操作右移（行中场景）→ 左移恢复并重新读取行内容
            if (StrLen(selClean) > StrLen(line)) {
                SendEvent("{Left}")
                Sleep(40)
                A_Clipboard := ""
                SendEvent("+{Home}^c")
                line := ""
                if (ClipWait(0.5))
                    line := A_Clipboard
                SendEvent("{Right}")
                Sleep(40)
                A_Clipboard := prevClip
            }
            context := ""
            i := StrLen(line)
            while (i >= 1) {
                ch := SubStr(line, i, 1)
                if (ch = " " || ch = "`t" || ch = "`r" || ch = "`n")
                    break
                context := ch . context
                i--
            }
            return {text: context, fromSelection: false}
        }

        ; 单行未通过前缀判定 → 疑似手工选区：重建选区并验证（光标当前在选区右端）
        SendEvent("+{Left " StrLen(selected) "}")
        Sleep(40)                       ; 等待应用完成重建选区
        A_Clipboard := ""
        SendEvent("^c")
        rebuild := ""
        if (ClipWait(0.5))
            rebuild := A_Clipboard
        A_Clipboard := prevClip
        if (rebuild = selected) {
            DebugLog("上下文：确认手工选区，长度=" StrLen(selected))
            return {text: Trim(selected, " `t`r`n"), fromSelection: true}
        }
        ; 重建不匹配：selected 并非光标前选区（如个别编辑器复制了光标后内容）
        ; 折叠重建的选区并尽可能恢复光标，按情况2处理
        SendEvent("{Right}")
        if (StrLen(selClean) > StrLen(rebuild))
            SendEvent("{Left}")
        Sleep(30)
    }
    A_Clipboard := prevClip

    ; --- 情况2：光标前的非空连续字符串 ---
    A_Clipboard := ""
    SendEvent("+{Home}^c")
    text := ""
    hadSel := false
    if (ClipWait(0.5)) {
        text := A_Clipboard
        hadSel := true
    }
    A_Clipboard := prevClip
    if (hadSel)
        SendEvent("{Right}")
    Sleep(30)

    context := ""
    i := StrLen(text)
    while (i >= 1) {
        ch := SubStr(text, i, 1)
        if (ch = " " || ch = "`t" || ch = "`r" || ch = "`n")
            break
        context := ch . context
        i--
    }
    return {text: context, fromSelection: false}
}

; ============================================================================
; 7e2. GetCaretScreenPos —— 获取文字光标的屏幕坐标（尽力而为）。
; 尝试顺序：
;   1. CaretGetPos         （系统原生光标，AHK 内置）
;   2. GetGUIThreadInfo    （通过线程信息获取原生光标；64 位偏移已固定）
;   3. EM_POSFROMCHAR      （原生 Edit/RichEdit 控件）
;   4. UI Automation       （Chromium/Electron：VS Code、Chrome、Edge 等）
;   5. 鼠标位置            （最后兜底）
; 返回屏幕坐标对象 {x, y}。
; ============================================================================
GetCaretScreenPos() {
    CoordMode("Caret", "Screen")
    CoordMode("Mouse", "Screen")

    ; 1) AHK 内置（内部使用 GetGUIThreadInfo）
    try {
        cp := CaretGetPos()
        if (cp.x != 0 || cp.y != 0)
            return {x: cp.x, y: cp.y}
    }

    ; 获取焦点控件的窗口句柄（第 2、3 层共用）
    hwnd := 0
    try {
        focusClass := ControlGetFocus("A")
        if (focusClass != "")
            hwnd := ControlGetHwnd(focusClass, "A")
    }

    ; 2) GetGUIThreadInfo -> rcCaret（系统原生光标）
    if (hwnd) {
        try {
            hThread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
            ; GUITHREADINFO 大小 = 8 + 6*A_PtrSize + 16；rcCaret 偏移 = 8 + 6*A_PtrSize
            cbSize := 8 + 6 * A_PtrSize + 16
            gti := Buffer(cbSize, 0)
            NumPut("UInt", cbSize, gti)
            if (DllCall("GetGUIThreadInfo", "UInt", hThread, "Ptr", gti)) {
                rc := 8 + 6 * A_PtrSize
                cx := NumGet(gti, rc, "Int")
                cy := NumGet(gti, rc + 4, "Int")
                if (cx != 0 || cy != 0) {
                    pt := Buffer(8, 0)
                    NumPut("Int", cx, "Int", cy, pt)
                    if (DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt))
                        return {x: NumGet(pt, 0, "Int"), y: NumGet(pt, 4, "Int")}
                }
            }
        }
    }

    ; 3) 原生 Edit/RichEdit：EM_GETSEL + EM_POSFROMCHAR
    if (hwnd && (InStr(focusClass, "Edit") || InStr(focusClass, "RichEdit"))) {
        try {
            EM_GETSEL := 0x00B0
            EM_POSFROMCHAR := 0x00D6
            sel := SendMessage(EM_GETSEL, 0, 0, hwnd)
            caretIdx := sel & 0xFFFF
            if (caretIdx > 0)
                caretIdx -= 1
            pos := SendMessage(EM_POSFROMCHAR, caretIdx, 0, hwnd)
            px := pos & 0xFFFF
            py := (pos >> 16) & 0xFFFF
            if (px != 0 || py != 0) {
                pt := Buffer(8, 0)
                NumPut("Int", px, "Int", py, pt)
                if (DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt))
                    return {x: NumGet(pt, 0, "Int"), y: NumGet(pt, 4, "Int")}
            }
        }
    }

    ; 4) UI Automation（Chromium/Electron 及其它支持 UIA 的应用）
    uiaPos := GetCaretViaUIA()
    if (uiaPos)
        return uiaPos

    ; 5) 最后兜底：鼠标位置
    MouseGetPos(&mx, &my)
    return {x: mx, y: my}
}

; ---------------------------------------------------------------------------
; GetCaretViaUIA —— 通过 UI Automation TextPattern 获取光标屏幕坐标。
; 成功返回 {x, y}，失败返回 0。
; 适用于 Chromium/Electron 应用（VS Code、Chrome、Edge 等），
; 即使系统原生光标被隐藏，也能通过 UI Automation 拿到原生光标。
; ---------------------------------------------------------------------------
GetCaretViaUIA() {
    static uia := ""
    if (uia = "") {
        try
            uia := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
        catch
            return 0
    }
    try {
        ; IUIAutomation.GetFocusedElement —— vtable 8 -> ComCall 9
        ComCall(9, uia, "ptr*", &elPtr)
        if (!elPtr)
            return 0
        el := ComValue(13, elPtr)

        ; IUIAutomationElement.GetCurrentPattern(UIA_TextPatternId=10014) —— vtable 13 -> ComCall 14
        ComCall(14, el, "int", 10014, "ptr*", &tpPtr)
        if (!tpPtr)
            return 0
        tp := ComValue(13, tpPtr)

        ; IUIAutomationTextPattern.GetCaretRange —— vtable 9 -> ComCall 10
        ComCall(10, tp, "int*", &isActive, "ptr*", &rangePtr)
        if (!rangePtr)
            return 0
        range := ComValue(13, rangePtr)

        ; IUIAutomationTextRange.GetBoundingRectangles —— vtable 10 -> ComCall 11
        ComCall(11, range, "ptr*", &saPtr)
        if (!saPtr)
            return 0

        ; 读取 doubles 组成的 SAFEARRAY：[left, top, width, height, ...]
        DllCall("oleaut32\SafeArrayGetLBound", "ptr", saPtr, "uint", 1, "long*", &lb)
        DllCall("oleaut32\SafeArrayGetUBound", "ptr", saPtr, "uint", 1, "long*", &ub)
        vals := []
        loop (ub - lb + 1) {
            idx := Buffer(4)
            NumPut("int", lb + A_Index - 1, idx)
            v := Buffer(8)
            DllCall("oleaut32\SafeArrayGetElement", "ptr", saPtr, "ptr", idx, "ptr", v)
            vals.Push(NumGet(v, 0, "double"))
        }
        DllCall("oleaut32\SafeArrayDestroy", "ptr", saPtr)

        if (vals.Length >= 4) {
            left := Round(vals[1])
            top := Round(vals[2])
            if (left != 0 || top != 0)
                return {x: left, y: top}
        }
    }
    return 0
}

; ============================================================================
; 7f. ShowMultiSelection —— latex/unicode 多匹配时的无框候选列表
;     各项内容格式：<匹配类型> <第一个字段> <第二字段（剔除 : 前缀）>
;     最多显示 10 行，上下键滚动可查看全部；Enter 选择，Esc 取消
;     返回：选中项索引（1 起），取消返回 0
; ============================================================================
ShowMultiSelection(matches, partialCommand) {
    global ui_font_size
    ; 构建显示项：<匹配类型> <第一个字段> <第二字段（剔除 : 前缀）>
    menuItems := []
    for m in matches {
        f2show := m.f2
        if (SubStr(f2show, 1, 1) = ":")
            f2show := SubStr(f2show, 2)
        menuItems.Push(m.type . " " . m.key . " " . f2show)
    }
    
    ; 获取光标屏幕坐标，把弹窗定位在光标附近（原生 → UIA → 鼠标）
    cp := GetCaretScreenPos()
    caretX := cp.x
    caretY := cp.y
    
    ; 构建 GUI
    selGui := Gui()
    selGui.Opt("-Caption +ToolWindow +AlwaysOnTop +Border")
    selGui.SetFont("s" ui_font_size, "Consolas")
    selGui.BackColor := "2D2D2D"
    
    ; 标题行
    selGui.Add("Text", "cAAAAAA x10 y6", "匹配 '" partialCommand "':")
    
    ; 列表框 —— 最多显示 10 行；上下键滚动可查看全部匹配项
    rows := Min(matches.Length, 10)
    lb := selGui.Add("ListBox", "x10 y+4 w480 r" rows " cFFFFFF Background2D2D2D vSelectedItem", menuItems)
    lb.Choose(1)
    
    ; 提示行
    selGui.Add("Text", "c888888 x10 y+4", Chr(8593) . Chr(8595) . " 移动  Enter 选择  Esc 取消")
    
    ; 隐藏的默认按钮用于捕获回车
    okBtn := selGui.Add("Button", "Hidden Default", "OK")
    okBtn.OnEvent("Click", (*) => (
        chosen := SendMessage(0x0188, 0, 0, lb),
        selGui.Submit()
    ))
    
    ; Esc 取消
    selGui.OnEvent("Escape", (*) => (
        chosen := -1,
        selGui.Destroy()
    ))
    
    ; 显示并定位到光标附近
    selGui.Show("AutoSize Hide")
    selGui.GetPos(&gx, &gy, &gw, &gh)
    newX := caretX
    newY := caretY
    if (newY + gh > A_ScreenHeight)
        newY := caretY - gh
    if (newX + gw > A_ScreenWidth)
        newX := A_ScreenWidth - gw
    if (newX < 0)
        newX := 0
    if (newY < 0)
        newY := 0
    selGui.Move(newX, newY)
    selGui.Show()
    
    ; 等待 GUI 关闭；chosen 由上面的闭包捕获
    chosen := -1
    WinWaitClose("ahk_id " . selGui.Hwnd)
    
    ; LB_GETCURSEL 返回 0 基索引；取消返回 0
    if (chosen < 0)
        return 0
    return chosen + 1
}

; ============================================================================
; 15. JSON 工具（用于 AI 接口）—— 实现已移至 SharpKnifeCore.ahk
;     （JsonEscape / J / K / ParseJsonStringAt / JsonFieldString / ParseJsonStringArray / ParseCandidates）
; ============================================================================

; ============================================================================
; 16b. HttpResponseUtf8 —— 将 WinHttp 响应体（字节数组）按 UTF-8 解码为文本
;      避免 ResponseText 在响应头缺少 charset 时把 UTF-8 中文解码成乱码。
; ============================================================================
HttpResponseUtf8(whr) {
    try {
        bytes := whr.ResponseBody
        n := bytes.MaxIndex() + 1
        if (n <= 0)
            return ""
        buf := Buffer(n)
        loop n
            NumPut("UChar", bytes[A_Index - 1], buf, A_Index - 1)
        return StrGet(buf, n, "UTF-8")
    } catch {
        return ""
    }
}

; ============================================================================
; 16. AIRequest —— 调用 AI 模型
;     风格 chat：聊天补全接口（DeepSeek 官方默认，OpenAI 兼容）
;     风格 completion：原生补全接口（若所用服务支持，可通过 config 切换）
;     成功返回 true，result 为最终补全文本、reasoning 为思考过程（思考模式开启时非空）；
;     失败返回 false 且 errMsg 说明原因。
; ============================================================================
AIRequest(prompt, &result, &reasoning, &errMsg) {
    global ai_key, ai_base_url, ai_endpoint, ai_style, ai_model
    global ai_temperature, ai_max_tokens, ai_timeout, ai_system_prompt
    global ai_thinking, ai_reasoning_effort
    if (ai_key = "") {
        errMsg := "未配置 API 密钥（config.ini → [ai] api_key）"
        return false
    }
    url := ai_base_url . ai_endpoint
    ; 附加参数：思考开关 "thinking":{"type":"..."} 与推理强度 "reasoning_effort":"..."
    ; 仅在对应配置非空时才发送，避免对不支持这些参数的接口造成影响
    tail := ""
    if (ai_thinking != "")
        tail .= "," . K("thinking") . "{" . K("type") . J(ai_thinking) . "}"
    if (ai_reasoning_effort != "")
        tail .= "," . K("reasoning_effort") . J(ai_reasoning_effort)

    if (ai_style = "completion") {
        body := "{"
            . K("model") . J(ai_model) . ","
            . K("prompt") . J(ai_system_prompt . "`n`n" . prompt) . ","
            . K("temperature") . ai_temperature . ","
            . K("max_tokens") . ai_max_tokens . ","
            . K("stream") . "false" . tail . "}"
    } else {
        ; chat 风格（默认）
        body := "{"
            . K("model") . J(ai_model) . ","
            . K("messages") . "["
            . "{" . K("role") . J("system") . "," . K("content") . J(ai_system_prompt) . "},"
            . "{" . K("role") . J("user") . "," . K("content") . J(prompt) . "}"
            . "],"
            . K("temperature") . ai_temperature . ","
            . K("max_tokens") . ai_max_tokens . ","
            . K("stream") . "false" . tail . "}"
    }
    DebugLog("AI：POST " . url . "（超时=" . ai_timeout . "ms ×4：解析/连接/发送/接收）")
    t0 := A_TickCount
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", url, false)
        whr.SetTimeouts(ai_timeout, ai_timeout, ai_timeout, ai_timeout)
        whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        whr.SetRequestHeader("Authorization", "Bearer " . ai_key)
        DebugLog("AI：已 Open，开始 Send（t=" . (A_TickCount - t0) . "ms）")
        whr.Send(body)
        status := whr.Status
        ; 响应体按 UTF-8 字节解码，确保返回的中文不乱码
        resp := HttpResponseUtf8(whr)
        if (StrLen(resp) = 0)
            resp := whr.ResponseText    ; 兜底：解码失败时退回 ResponseText
        DebugLog("AI：HTTP " . status . "，耗时=" . (A_TickCount - t0) . "ms，结束原因=" . JsonFieldString(resp, "finish_reason"))
        if (status < 200 || status >= 300) {
            errMsg := "HTTP " . status . "：" . SubStr(resp, 1, 400)
            return false
        }
        reasoning := ""
        if (ai_style = "completion") {
            result := JsonFieldString(resp, "text")
        } else {
            result := JsonFieldString(resp, "content")
            reasoning := JsonFieldString(resp, "reasoning_content")  ; 思考过程（思考模式开启时模型返回）
        }
        ; 推理型模型（如 deepseek-v4-flash）可能把最终结果放在 reasoning_content 字段、
        ; 而 content 为空；此时回退读取 reasoning_content
        if (StrLen(result) = 0 && ai_style != "completion") {
            if (StrLen(reasoning) > 0)
                result := reasoning
        }
        if (StrLen(result) = 0) {
            errMsg := "响应中未找到结果字段：" . SubStr(resp, 1, 400)
            return false
        }
        return true
    } catch as e {
        ; 详细错误日志（定位网络/代理/超时问题用）：耗时 + COM 错误号（十六进制）+ 附加信息
        lastErr := A_LastError
        elapsed := A_TickCount - t0
        errNum := ""
        try
            errNum := Format("0x{:08X}", e.Number & 0xFFFFFFFF)
        errExtra := ""
        try
            errExtra := e.Extra
        winCode := ""
        try
            winCode := e.WinCode
        DebugLog("AI：请求失败，耗时=" . elapsed . "ms，Number=" . errNum
            . "，Message=" . e.Message
            . "，Extra=" . errExtra
            . "，WinCode=" . winCode
            . "，LastError=" . lastErr)
        errMsg := "请求异常（" . elapsed . "ms）：" . e.Message
        return false
    }
}

; ============================================================================
; 16c. AIRequestStream —— 流式调用 AI 模型（chat 风格，SSE 增量解析）
;      采用 curl.exe 发起流式请求（stream=true），边接收边解析 SSE 增量：
;        - 思考增量（reasoning_content / reasoning）→ 实时追加到思考窗口（showThinking=true）；
;        - 内容增量（content）→ 累积为最终 result。
;      成功返回 true，result 为完整补全文本、reasoning 为完整思考过程；
;      失败返回 false 且 errMsg 说明原因。
;      说明：流式仅支持 chat 接口风格（completion 原生补全接口无标准 SSE 流式）。
; ============================================================================
global streamFile := ""        ; 当前流式响应文件路径
global streamReadOffset := 0   ; 流式响应文件中已处理到的字节偏移

AIRequestStream(prompt, showThinking, &result, &reasoning, &errMsg) {
    global ai_key, ai_base_url, ai_endpoint, ai_style, ai_model
    global ai_temperature, ai_max_tokens, ai_timeout, ai_system_prompt
    global ai_thinking, ai_reasoning_effort, streamFile, streamReadOffset

    if (ai_key = "") {
        errMsg := "未配置 API 密钥（config.ini → [ai] api_key）"
        return false
    }
    if (ai_style = "completion") {
        errMsg := "流式请求仅支持 chat 接口风格（config.ini → [ai] api_style = chat）"
        return false
    }
    url := ai_base_url . ai_endpoint

    ; 构造请求体（stream=true，其余附加参数与非流式一致）
    tail := ""
    if (ai_thinking != "")
        tail .= "," . K("thinking") . "{" . K("type") . J(ai_thinking) . "}"
    if (ai_reasoning_effort != "")
        tail .= "," . K("reasoning_effort") . J(ai_reasoning_effort)
    body := "{"
        . K("model") . J(ai_model) . ","
        . K("messages") . "["
        . "{" . K("role") . J("system") . "," . K("content") . J(ai_system_prompt) . "},"
        . "{" . K("role") . J("user") . "," . K("content") . J(prompt) . "}"
        . "],"
        . K("temperature") . ai_temperature . ","
        . K("max_tokens") . ai_max_tokens . ","
        . K("stream") . "true" . tail . "}"

    ; 临时文件：请求体 / 流式响应 / 错误输出（写入临时目录，用文件传请求体避免命令行转义问题）
    tmpDir := A_Temp "\SharpKnife"
    if (!DirExist(tmpDir))
        DirCreate(tmpDir)
    tag := A_TickCount
    bodyFile   := tmpDir "\ai_body_"   . tag . ".txt"
    streamFile := tmpDir "\ai_stream_" . tag . ".txt"
    errFile    := tmpDir "\ai_err_"    . tag . ".txt"
    ; 必须用 "UTF-8-RAW"（不带 BOM）：AHK 的 "UTF-8" 会写入 BOM 头，
    ; curl --data-binary 原样发送后 BOM 成为 JSON 开头 → 服务端解析失败返回 500 Internal server error
    try FileAppend(body, bodyFile, "UTF-8-RAW")

    ; 思考模式：先弹出思考窗口（实时滚动呈现），并清掉进度提示避免遮挡
    if (showThinking) {
        ToolTip()
        ShowThinkingWindow()
    }

    ; 用 curl.exe 发起流式请求：-N 禁用缓冲、--data-binary @文件 原样发送请求体，
    ; stdout 写 streamFile、stderr 写 errFile；进程以 Hide 方式启动、不抢焦点
    inner := "curl.exe -sS -N -X POST `"" url "`""
        . " -H `"Content-Type: application/json; charset=utf-8`""
        . " -H `"Authorization: Bearer " ai_key "`""
        . " --data-binary @`"" bodyFile "`""
        . " -o `"" streamFile "`""
        . " 2> `"" errFile "`""
    cmd := A_ComSpec " /S /C `"" inner "`""
    DebugLog("AI流式：启动 curl（超时=" . ai_timeout . "ms）")
    try {
        Run(cmd, , "Hide", &pid)
    } catch as e {
        ; 极端情况：连 cmd 都启动失败（curl 缺失时通常 cmd 能启动、错误经 stderr 落到 errFile，
        ; 此处仅兜底"连命令解释器都不可用"的崩溃，保证不抛出异常中断补全）
        if (showThinking)
            CloseThinkingWindow()
        try FileDelete(bodyFile)
        try FileDelete(streamFile)
        try FileDelete(errFile)
        errMsg := "无法启动流式请求（curl.exe）：" . e.Message
        return false
    }

    ; 轮询读取流式响应：边接收边解析 SSE 增量，思考增量实时追加到思考窗口
    result := ""
    reasoning := ""
    streamReadOffset := 0
    deadline := A_TickCount + ai_timeout
    while (ProcessExist(pid) && A_TickCount < deadline) {
        StreamProcessFile(showThinking, &result, &reasoning)
        Sleep(80)
    }
    ; 超时保护：强制结束仍运行的 curl（及包装它的 cmd）
    if (ProcessExist(pid))
        ProcessClose(pid)
    StreamProcessFile(showThinking, &result, &reasoning)

    ; 思考完毕：先等打字机把剩余缓冲逐字吐完，稍作停留后“自动离开”思考窗口
    ; （保留窗口不关闭，焦点还给原编辑器继续输出正式结果；用户可按 Esc 关闭）
    if (showThinking) {
        ; 动态超时：思考内容完整展示完（打字机吐空缓冲）再离开，避免思考展示被截断、
        ; 正式结果抢在思考过程还在滚动呈现时就输出（reasoning 为完整思考文本，按 15ms/字
        ; 留足余量，WaitThinkingDrain 会在缓冲吐空时提前返回，不会真正等满上限）
        WaitThinkingDrain(Max(3000, StrLen(reasoning) * 20 + 2000))
        Sleep(400)
        LeaveThinkingWindow()
    }

    ; 未解析到结果时，先从 errFile 读取错误信息（必须在清理删除前读取）；
    ; errFile 为空时（curl 未写 stderr），再从 streamFile 兜底提取 API 返回的错误
    if (StrLen(result) = 0) {
        errText := ""
        if FileExist(errFile)
            try errText := FileRead(errFile, "UTF-8")
        if (Trim(errText) = "" && FileExist(streamFile)) {
            try {
                raw := FileRead(streamFile, "UTF-8")
                if (InStr(raw, "error")) {
                    m := JsonFieldString(raw, "message")
                    errText := (m != "") ? m : SubStr(Trim(raw), 1, 400)
                }
            }
        }
        if (Trim(errText) != "")
            errMsg := "流式请求失败：" . SubStr(Trim(errText), 1, 400)
        else
            errMsg := "流式响应中未找到结果内容"
    }

    ; 清理临时文件
    try FileDelete(bodyFile)
    try FileDelete(streamFile)
    try FileDelete(errFile)

    if (StrLen(result) = 0) {
        DebugLog("AI流式：请求失败，" . errMsg)
        return false
    }
    DebugLog("AI流式：完成，结果长度=" . StrLen(result) . "，思考长度=" . StrLen(reasoning))
    return true
}

; 读取流式响应文件的新增字节，解析 SSE 数据行，累积 content / reasoning_content 增量
; 只处理"以换行结尾的完整行"：换行字节(0x0A)不会是 UTF-8 多字节字符的一部分，因此
; 以换行为处理边界，绝不会在多字节字符中间截断（半字符/半行问题自动规避）。
StreamProcessFile(showThinking, &contentAcc, &reasoningAcc) {
    global streamFile, streamReadOffset
    ; curl 首次写入 streamFile 是异步的（Run 返回后 cmd 尚未创建重定向文件），
    ; 且 FileOpen "r" 对不存在文件会抛 OSError（而非返回 0），故先 FileExist 兜底再 try 包裹
    if (!FileExist(streamFile))
        return
    f := ""
    try f := FileOpen(streamFile, "r")   ; 二进制读
    catch
        return
    if (!f)
        return
    try {
        total := f.Length
        if (total <= streamReadOffset) {
            f.Close()
            return
        }
        f.Pos := streamReadOffset
        ; AHK v2 的 File.RawRead 参数是"目标 Buffer"（读入其中），返回实际读到的字节数；
        ; 传整数会抛 "Parameter #1 ... is invalid"（旧代码把字节数当参数传，被 catch 静默吞掉，
        ; 导致 streamReadOffset 永不前进、结果始终为空）
        chunk := Buffer(total - streamReadOffset, 0)
        n := f.RawRead(chunk)
        f.Close()
        if (n <= 0)
            return
        ; 找最后一个换行字节 0x0A 的位置
        lastNl := -1
        Loop n {
            if (NumGet(chunk, A_Index - 1, "UChar") = 0x0A)
                lastNl := A_Index - 1
        }
        if (lastNl < 0)
            return   ; 尚无完整行，等下次再读
        ; 解码 [0, lastNl]（若干完整行，含末尾换行）为 UTF-8 文本；补 null 终止防越界
        buf := Buffer(lastNl + 2, 0)
        DllCall("RtlMoveMemory", "Ptr", buf.Ptr, "Ptr", chunk.Ptr, "UPtr", lastNl + 1)
        text := StrGet(buf.Ptr, "UTF-8")
        streamReadOffset += lastNl + 1
        ; 逐行解析 SSE
        for line in StrSplit(text, "`n") {
            line := RTrim(line, "`r")
            if (SubStr(line, 1, 5) = "data:") {
                payload := Trim(SubStr(line, 6), " `t")
                if (payload = "[DONE]")
                    continue
                dc := JsonFieldString(payload, "content")
                dr := JsonFieldString(payload, "reasoning_content")
                if (StrLen(dr) = 0)
                    dr := JsonFieldString(payload, "reasoning")
                ; 用 StrLen 而非 `!= ""`：AHK 的 `!=` 会按数值比较，
                ; 当增量恰为字符串 "0"（数字 0 常是独立 token）时会被误判为空而丢弃 → 结果漏字。
                if (StrLen(dc) > 0)
                    contentAcc .= dc
                if (StrLen(dr) > 0) {
                    reasoningAcc .= dr
                    if (showThinking)
                        AppendThinkingText(dr)
                }
            }
        }
    } catch {
        try f.Close()
    }
}

; ============================================================================
; 17. ShowList —— 通用无框候选列表（最多显示 10 行，上下键滚动查看全部）
;     items：显示字符串数组；title：标题
;     返回：选中项索引（1 起），取消返回 0
; ============================================================================
ShowList(items, title) {
    global ui_font_size
    prevWin := WinExist("A")          ; 记录当前前台窗口，GUI 关闭后等待焦点归还
    cp := GetCaretScreenPos()
    selGui := Gui()
    selGui.Opt("-Caption +ToolWindow +AlwaysOnTop +Border")
    selGui.SetFont("s" ui_font_size, "Consolas")
    selGui.BackColor := "2D2D2D"
    selGui.Add("Text", "cAAAAAA x10 y6", title)
    rows := Min(items.Length, 10)
    lb := selGui.Add("ListBox", "x10 y+4 w480 r" rows " cFFFFFF Background2D2D2D vSelectedItem", items)
    lb.Choose(1)
    selGui.Add("Text", "c888888 x10 y+4", Chr(8593) . Chr(8595) . " 移动  Enter 选择  Esc 取消")
    okBtn := selGui.Add("Button", "Hidden Default", "OK")
    okBtn.OnEvent("Click", (*) => (
        chosen := SendMessage(0x0188, 0, 0, lb),
        selGui.Submit()
    ))
    selGui.OnEvent("Escape", (*) => (
        chosen := -1,
        selGui.Destroy()
    ))
    selGui.Show("AutoSize Hide")
    selGui.GetPos(&gx, &gy, &gw, &gh)
    newX := cp.x
    newY := cp.y
    if (newY + gh > A_ScreenHeight)
        newY := cp.y - gh
    if (newX + gw > A_ScreenWidth)
        newX := A_ScreenWidth - gw
    if (newX < 0)
        newX := 0
    if (newY < 0)
        newY := 0
    selGui.Move(newX, newY)
    selGui.Show()
    chosen := -1
    WinWaitClose("ahk_id " . selGui.Hwnd)
    ; GUI 关闭后的窗口切换竞态：等待焦点归还原窗口（原窗口可能为 0=桌面/无前台）
    ; 否则紧接着的触发（如 Ctrl+J）在竞态窗口内按键注入会被系统吞掉
    if (prevWin) {
        loop 100 {                    ; 最多约 1 秒
            if (WinExist("A") = prevWin)
                break
            Sleep(10)
        }
        ; 超时仍未恢复且原窗口仍存在 → 主动拉回焦点（AHK 此时有用户输入前台权，WinActivate 有效）
        if (WinExist("A") != prevWin && WinExist("ahk_id " . prevWin)) {
            WinActivate("ahk_id " . prevWin)
            loop 50 {
                if (WinExist("A") = prevWin)
                    break
                Sleep(10)
            }
        }
    }
    if (chosen < 0)
        return 0
    return chosen + 1
}

; ============================================================================
; 17b. 思考窗口 —— 思考模式（[ai] thinking=enabled）且流式请求时，实时滚动呈现 AI 思考过程
;      ShowThinkingWindow：弹出无框窗口（空内容，定位光标附近，不抢焦点）；
;      AppendThinkingText：把思考过程的增量文本追加到窗口并滚动到底（流式边接收边追加）；
;      LeaveThinkingWindow：思考完毕后自动离开窗口（保留窗口不关闭，焦点还给原编辑器）；
;      CloseThinkingWindow：真正销毁思考窗口（用户按 Esc 关闭，或下次触发时销毁旧的）。
; ============================================================================
global thinkingGui := ""      ; 思考窗口 GUI 对象
global thinkingEdit := ""     ; 思考窗口的只读多行编辑框控件
global thinkingPrevWin := 0   ; 思考窗口弹出前的原编辑器窗口句柄（用于恢复焦点）
global thinkingPending := ""  ; 待逐字符输出的缓冲（打字机队列）
global thinkingTimer := ""    ; 打字机定时器对象（SetTimer 返回）
global thinkingLineCount := 0 ; 已追加进 Edit 的换行数（用于"填满后滚 5 行"）
global thinkingScrollMark := 0 ; 已滚动过的行数基准
global thinkingVisibleLines := 16 ; 思考窗口可视行数（与 ShowThinkingWindow 的 r16 对应）

; 弹出思考窗口（初始为空内容；流式请求过程中由 AppendThinkingText 实时追加）
ShowThinkingWindow() {
    global ui_font_size, thinkingGui, thinkingEdit, thinkingPrevWin
    global thinkingPending, thinkingTimer, thinkingLineCount, thinkingScrollMark
    ; 若已有思考窗口尚未关闭（快速重复触发），先销毁旧的，避免窗口泄漏
    if (thinkingGui != "") {
        try thinkingGui.Destroy()
        thinkingGui := ""
        thinkingEdit := ""
    }
    thinkingPending := ""
    thinkingTimer := ""
    thinkingLineCount := 0
    thinkingScrollMark := 0
    thinkingPrevWin := WinExist("A")    ; 记录原编辑器窗口：思考窗口绝不能抢走焦点，
                                        ; 否则后续追加结果的按键会发错窗口（误删上下文、漏输结果）
    cp := GetCaretScreenPos()
    thinkingGui := Gui()
    ; 去掉 +ToolWindow：让窗口出现在任务栏/Alt+Tab，便于“随时人工回到”窗口；
    ; 思考过程中保留 +AlwaysOnTop 置顶确保可见，思考完毕离开时再取消置顶（见 LeaveThinkingWindow）
    thinkingGui.Opt("-Caption +AlwaysOnTop +Border")
    thinkingGui.Title := "AI 思考过程"
    thinkingGui.BackColor := "2D2D2D"
    thinkingGui.SetFont("s" ui_font_size, "Consolas")
    thinkingGui.Add("Text", "cFFCB66 w560", "AI 思考过程：")
    thinkingEdit := thinkingGui.Add("Edit", "ReadOnly +Multi +VScroll cFFFFFF Background2D2D2D w560 r16")
    thinkingGui.Add("Text", "c888888", "思考完毕后自动离开，按 Esc 关闭")
    ; 用户可随时点击思考窗口（激活）后按 Esc 键关闭它
    thinkingGui.OnEvent("Escape", (*) => CloseThinkingWindow())
    ; 无边框窗口默认不可拖动：注册 WM_LBUTTONDOWN 处理，按住窗口空白处（Edit 之外）可拖动
    OnMessage(0x0201, ThinkingWindowDrag)
    thinkingGui.Show("AutoSize Hide")
    thinkingGui.GetPos(&gx, &gy, &gw, &gh)
    newX := cp.x
    newY := cp.y + 20
    if (newY + gh > A_ScreenHeight)
        newY := cp.y - gh - 20
    if (newX + gw > A_ScreenWidth)
        newX := A_ScreenWidth - gw
    if (newX < 0)
        newX := 0
    if (newY < 0)
        newY := 0
    thinkingGui.Move(newX, newY)
    thinkingGui.Show("NA")   ; “NA”=NoActivate：显示但不激活、不抢焦点，
                             ; 保证后续追加结果的按键仍发往原编辑器
}

; 追加思考过程增量文本：先放入打字机缓冲，由定时器逐字符输出（见 TypeThinking）。
; 不再整段重设 Edit.Value（那会触发整个控件重绘 → 闪烁），改为增量追加。
AppendThinkingText(delta) {
    global thinkingGui, thinkingEdit, thinkingPending, thinkingTimer
    if (thinkingGui = "" || delta = "")
        return
    thinkingPending .= delta
    ; 若打字机定时器未运行，启动它
    if (thinkingTimer = "")
        thinkingTimer := SetTimer(TypeThinking, 15)
}

; 打字机回调：每 15ms 从缓冲取一个字符，增量追加到 Edit 末尾（无闪烁），
; 当内容填满可视区后，每多出 5 行就向下滚动 5 行（EM_LINESCROLL），如此往复。
TypeThinking() {
    global thinkingGui, thinkingEdit, thinkingPending, thinkingTimer
    global thinkingLineCount, thinkingScrollMark, thinkingVisibleLines
    ; 窗口已被销毁 → 停表并清空
    if (thinkingGui = "") {
        StopThinkingTicker()
        return
    }
    ; 缓冲吐空 → 停表（下次 AppendThinkingText 会重新启动）
    if (thinkingPending = "") {
        StopThinkingTicker()
        return
    }
    ; 取一个字符（BMP 字符占 1 个码元；思考文本几乎不含 emoji 等代理对，按码元取即可）
    ch := SubStr(thinkingPending, 1, 1)
    thinkingPending := SubStr(thinkingPending, 2)
    ; 多行 Edit 只认 CRLF 换行，单独的 LF 不会产生新行 → 遇到 \n 时插入 \r\n
    ins := ch
    if (ch = "`n")
        ins := "`r`n"

    try {
        ; 定位插入点到末尾：EM_SETSEL(len, len)，len 取 WM_GETTEXTLENGTH（不含多行 Edit 隐藏的 CR）
        len := SendMessage(0x000E, 0, 0, thinkingEdit.Hwnd)      ; WM_GETTEXTLENGTH
        SendMessage(0x00B1, len, len, thinkingEdit.Hwnd)          ; EM_SETSEL
        SendMessage(0x00C2, 0, StrPtr(ins), thinkingEdit.Hwnd)    ; EM_REPLACESEL 增量插入（不重绘整段）
        ; 换行计数（与 Edit 物理行对齐：每个 LF 对应一个 CRLF 行）
        if (ch = "`n")
            thinkingLineCount++
        ; 填满可视区后再多出 5 行 → 向下滚 5 行（相对滚动，符合"满了滚 5 行再继续"）
        if (thinkingLineCount - thinkingScrollMark - thinkingVisibleLines >= 5) {
            SendMessage(0x00B6, 0, 5, thinkingEdit.Hwnd)          ; EM_LINESCROLL 向下 5 行
            thinkingScrollMark += 5
        }
    }
}

; 停止打字机定时器（仅停表，不清空缓冲；缓冲由 CloseThinkingWindow 或下一次触发时清空）
StopThinkingTicker() {
    global thinkingTimer, thinkingPending
    if (thinkingTimer != "") {
        try SetTimer(thinkingTimer, 0)
        thinkingTimer := ""
    }
}

; 等待打字机把缓冲吐完（最多等 maxMs 毫秒），用于关闭窗口前确保不丢尾字符
WaitThinkingDrain(maxMs) {
    global thinkingPending
    deadline := A_TickCount + maxMs
    while (thinkingPending != "" && A_TickCount < deadline)
        Sleep(20)
}

; 无边框思考窗口拖动：客户区空白处（标题/底部文字、背景，Edit 之外）按住左键即可拖动；
; 点住只读 Edit 本身不拖动，保留滚动/选择思考文本的能力。
ThinkingWindowDrag(wParam, lParam, msg, hwnd) {
    global thinkingGui, thinkingEdit
    if (thinkingGui = "" || thinkingEdit = "")
        return
    ; 仅处理思考窗口及其子控件的消息（OnMessage 为全局，须过滤其他窗口）
    if (DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") != thinkingGui.Hwnd)  ; GA_ROOT
        return
    ; 点击落在只读 Edit 上 → 不启动拖动（让用户能滚动/选择文本）
    if (hwnd = thinkingEdit.Hwnd)
        return
    ; 向窗口发送 WM_NCLBUTTONDOWN + HTCAPTION，让系统接管拖动
    PostMessage(0x00A1, 2, 0, , "ahk_id " . hwnd)
}

; 思考完毕后自动离开思考窗口（不关闭）：窗口保留在屏幕上供随时查看，
; 焦点还给原编辑器以继续输出正式结果；用户可随时点击窗口后按 Esc 关闭。
LeaveThinkingWindow() {
    global thinkingGui, thinkingPrevWin
    StopThinkingTicker()
    if (thinkingGui = "")
        return
    ; 思考结束：取消置顶——窗口不再总在最前，焦点回到编辑器时被编辑器盖住
    ; （不可见但仍存在，用户可随时通过任务栏回到窗口按 Esc 关闭）
    try WinSetAlwaysOnTop(0, "ahk_id " . thinkingGui.Hwnd)
    ; 思考窗口以 NoActivate 显示、一般不抢焦点，此处兜底把焦点还给原编辑器
    if (thinkingPrevWin != 0 && WinExist("ahk_id " . thinkingPrevWin)) {
        if (WinExist("A") != thinkingPrevWin)
            WinActivate("ahk_id " . thinkingPrevWin)
        loop 50 {
            if (WinExist("A") = thinkingPrevWin)
                break
            Sleep(10)
        }
    }
}

; 关闭思考窗口（用户按 Esc 关闭，或下次触发时销毁旧窗口）
CloseThinkingWindow() {
    global thinkingGui, thinkingEdit, thinkingPending, thinkingTimer
    StopThinkingTicker()
    thinkingPending := ""
    if (thinkingGui != "") {
        try thinkingGui.Destroy()
        thinkingGui := ""
        thinkingEdit := ""
    }
}

; ============================================================================
; 18. GetContextAI —— AI 模式上下文选择（AI/tikz 共用）
;     情况1（优先）：触发前已有人工选择的内容 → 直接用选区作为上下文；
;     情况2（否则）：文字光标前的非空连续字符串。
;     返回 {text, fromSelection}；text 为空表示无可用上下文。
;
;     选区检测分两层（2026-08-11 修复“手工选整行被误判”）：
;       - 第一层：控件级 API（ControlGetFocus + EditGetSelectedText）直接读取真实选区，
;         记事本等标准 Edit/RichEdit 控件无歧义。剪贴板方案无法区分“手工选整行”与
;         “无选区 Ctrl+C 复制整行”（两者复制内容相同），会把整行选区误判为无选区，
;         导致上下文被错误截成行尾连续字符串（实测整行选区“基于 miktex 绘制 三维直角
;         坐标系 ， 为后续的 3D 绘图做准备。”被误判后上下文=“绘图做准备。”）；
;       - 第二层（回退，非标准控件如 vscode/obsidian）：剪贴板探测 + 前缀/重建验证：
;         vscode/obsidian 等编辑器在“无选区”时按 Ctrl+C 会复制整行，
;         不能仅凭剪贴板非空就判定为“手工选区”：
;          - 复制内容为多行 → 只可能是人工选区，直接信任剪贴板内容（不做重建验证：
;            重建依赖“编辑器内部字符数 = 剪贴板字符数”，而记事本/Typora 等编辑器内部
;            换行按 1 字符计、剪贴板 \r\n 按 2 字符计 → 多行重建必然偏差，实测 selLen=25 rebuildLen=29）；
;          - 复制内容为单行 → 用“^c 内容”与“+{Home}^c 行首→光标内容”的前缀关系区分：
;            互为前缀（典型为整行复制）→ 判定无手工选区，按情况2处理；
;            否则 → 重建选区并验证，确认是手工选区后整体删除。
; ============================================================================
GetContextAI() {
    ; 等待前台窗口稳定（GUI/菜单关闭后的窗口切换竞态期），避免后续按键注入被系统吞掉
    h := WinExist("A")
    loop 20 {
        Sleep(15)
        if (WinExist("A") != h) {
            h := WinExist("A")
            continue
        }
    }
    prevClip := ClipboardAll()

    ; --- 情况1：检测触发前已有的人工选择 ---
    ; 第一层：控件级 API 检测真实选区（记事本等标准 Edit/RichEdit 控件直接读取选中文本，
    ; 无歧义）。剪贴板方案有固有缺陷——无选区 Ctrl+C 复制整行 与 手工选整行 的复制内容
    ; 相同，“前缀关系”判断会把“手工选整行”误判为“空选区整行复制”而误走情况2，此时光标
    ; 已被折叠到行尾 → 上下文被错误截成行尾连续字符串（实测整行选区“基于 miktex 绘制
    ; 三维直角坐标系 ， 为后续的 3D 绘图做准备。”被误判后上下文=“绘图做准备。”）。
    selText := ""
    try {
        focused := ControlGetFocus("A")
        if (focused != "")
            selText := EditGetSelectedText(focused, "A")
    } catch {
        selText := ""
    }
    if (selText != "") {
        DebugLog("上下文：控件检测到手工选区，长度=" StrLen(selText))
        return {text: Trim(selText, " `t`r`n"), fromSelection: true}
    }
    ; 第二层：剪贴板探测（非标准控件如 vscode/obsidian 的回退方案）
    ; 注：全部按键注入用 SendEvent（keybd_event 模拟）——SendInput 在 GUI 关闭后的窗口切换
    ; 竞态窗口内可能被前台锁拒绝导致按键丢失（实测模式列表刚关闭立即触发时 ^c 与折叠键均会失效）
    A_Clipboard := ""
    SendEvent("^c")
    selected := ""
    if (ClipWait(0.5))
        selected := A_Clipboard
    ; tikz 模式诊断：^c 未检测到选区（便于定位是焦点问题还是编辑器处理慢）
    if (selected = "" && mode = MODE_TIKZ)
        DebugLog("  ^c 未检测到选区，走情况2；前台窗口=[" WinGetTitle("A") "] class=" WinGetClass("A"))

    if (selected != "") {
        selClean := RTrim(selected, "`r`n")

        ; 多行选区只可能是人工选区（空选区按 Ctrl+C 复制整行一定是单行）→ 直接信任剪贴板内容；
        ; 不做“重建验证”：重建依赖“编辑器内部字符数 = 剪贴板字符数”，而记事本/Typora 等
        ; 编辑器内部换行按 1 字符计、剪贴板 \r\n 按 2 字符计 → 多行重建必然偏差（实测
        ; selLen=25 rebuildLen=29）→ 多行必须跳过验证，直接采信选区。
        if (InStr(selClean, "`n") || InStr(selClean, "`r")) {
            DebugLog("上下文：确认手工选区，长度=" StrLen(selected))
            return {text: Trim(selected, " `t`r`n"), fromSelection: true}
        }

        ; --- 以下仅单行：才可能是“空选区整行复制”误判 ---
        ; 折叠选区（若有），使光标落在选区右端
        SendEvent("{Right}")
        Sleep(40)                       ; 等待应用处理折叠（Electron 等异步编辑器需时间处理按键）
        A_Clipboard := prevClip

        ; 读取光标前的行内容，用于与 selected 对比
        A_Clipboard := ""
        SendEvent("+{Home}^c")
        line := ""
        if (ClipWait(0.5))
            line := A_Clipboard
        SendEvent("{Right}")     ; 折叠 +{Home} 选区
        Sleep(40)
        A_Clipboard := prevClip

        ; 前缀关系 → 空选区整行复制误判 → 无手工选区，走情况2
        if (IsPrefix(selClean, line) || IsPrefix(line, selClean)) {
            ; 光标因折叠操作右移（行中场景）→ 左移恢复并重新读取行内容
            if (StrLen(selClean) > StrLen(line)) {
                SendEvent("{Left}")
                Sleep(40)
                A_Clipboard := ""
                SendEvent("+{Home}^c")
                line := ""
                if (ClipWait(0.5))
                    line := A_Clipboard
                SendEvent("{Right}")
                Sleep(40)
                A_Clipboard := prevClip
            }
            context := ""
            i := StrLen(line)
            while (i >= 1) {
                ch := SubStr(line, i, 1)
                if (ch = " " || ch = "`t" || ch = "`r" || ch = "`n")
                    break
                context := ch . context
                i--
            }
            return {text: context, fromSelection: false}
        }

        ; 单行未通过前缀判定 → 疑似手工选区：重建选区并验证（光标当前在选区右端）
        SendEvent("+{Left " StrLen(selected) "}")
        Sleep(40)                       ; 等待应用完成重建选区
        A_Clipboard := ""
        SendEvent("^c")
        rebuild := ""
        if (ClipWait(0.5))
            rebuild := A_Clipboard
        A_Clipboard := prevClip
        if (rebuild = selected) {
            DebugLog("上下文：确认手工选区，长度=" StrLen(selected))
            return {text: Trim(selected, " `t`r`n"), fromSelection: true}
        }
        ; tikz 模式诊断：重建失败（单行场景，折叠/重建时序问题或编辑器未同步处理）
        if (mode = MODE_TIKZ)
            DebugLog("  重建失败：selLen=" StrLen(selected) " rebuildLen=" StrLen(rebuild) "，回退情况2")
        ; 重建不匹配：selected 并非光标前选区（如个别编辑器复制了光标后内容）
        ; 折叠重建的选区并尽可能恢复光标，按情况2处理
        SendEvent("{Right}")
        if (StrLen(selClean) > StrLen(rebuild))
            SendEvent("{Left}")
        Sleep(30)
    }
    A_Clipboard := prevClip

    ; --- 情况2：光标前的非空连续字符串 ---
    A_Clipboard := ""
    SendEvent("+{Home}^c")
    text := ""
    hadSel := false
    if (ClipWait(0.5)) {
        text := A_Clipboard
        hadSel := true
    }
    A_Clipboard := prevClip
    if (hadSel)
        SendEvent("{Right}")
    Sleep(30)

    context := ""
    i := StrLen(text)
    while (i >= 1) {
        ch := SubStr(text, i, 1)
        if (ch = " " || ch = "`t" || ch = "`r" || ch = "`n")
            break
        context := ch . context
        i--
    }
    return {text: context, fromSelection: false}
}

; 判断 a 是否为 b 的前缀（空字符串视为任意字符串的前缀）—— 实现已移至 SharpKnifeCore.ahk

; ============================================================================
; 19. CompleteAI_Generate —— AI 模式主流程
;     上下文选择（选区优先）→ AI 请求 → 解析候选 → 多候选列表 → 追加到上下文之后（隔一行）
;     空上下文 / 请求失败 / 解析失败 / 用户取消 → 无操作（保持原状）
; ============================================================================
CompleteAI_Generate() {
    global show_progress, progress_text, ai_thinking, ai_stream, thinkingPrevWin
    if (show_progress && progress_text != "")
        ToolTip(progress_text)

    ctx := GetContextAI()
    prompt := ctx.text
    fromSel := ctx.fromSelection
    DebugLog("AI：上下文='" . prompt . "'（" . (fromSel ? "选区" : "光标前") . "）")
    if (prompt = "") {
        ToolTip()
        DebugLog("AI：空上下文，无操作")
        return
    }
    DebugLog("AI：请求中，提示语='" . prompt . "'")

    ok := false
    result := ""
    reasoning := ""
    errMsg := ""
    useStream := (ai_stream = "true")
    try {
        ; 流式（[ai] stream=true）：思考模式下边接收边在无框窗口实时滚动呈现思考过程；
        ; 非流式（默认）：一次性请求返回完整结果（不弹思考窗口）。
        if (useStream) {
            ok := AIRequestStream(prompt, ai_thinking = "enabled", &result, &reasoning, &errMsg)
        } else {
            ok := AIRequest(prompt, &result, &reasoning, &errMsg)
        }
    } catch as e {
        errMsg := "异常：" . e.Message
    }
    if (!ok) {
        DebugLog("AI：请求失败，" . errMsg)
        ToolTip("AI 请求失败：" . errMsg)
        SetTimer(() => ToolTip(), -6000)
        return
    }
    DebugLog("AI：原始响应='" . SubStr(result, 1, 200) . "'")

    candidates := ParseCandidates(result)
    if (candidates = 0) {
        DebugLog("AI：结果解析为空")
        ToolTip("AI 结果解析失败")
        SetTimer(() => ToolTip(), -6000)
        return
    }
    ; 剔除空白候选
    filtered := []
    for c in candidates {
        t := Trim(c)
        if (t != "")
            filtered.Push(t)
    }
    if (filtered.Length = 0) {
        DebugLog("AI：候选为空")
        ToolTip("AI 结果为空")
        SetTimer(() => ToolTip(), -6000)
        return
    }

    chosen := ""
    if (filtered.Length = 1) {
        chosen := filtered[1]
    } else {
        ; 多种可能 → 无框列表供选择
        DebugLog("AI：候选数=" . filtered.Length)
        idx := ShowList(filtered, "AI 候选（'" . prompt . "'）")
        if (idx = 0) {
            ToolTip()
            DebugLog("AI：用户取消，无操作")
            return
        }
        chosen := filtered[idx]
    }
    DebugLog("AI：选定结果='" . chosen . "'")

    ; 恢复焦点到原编辑器（兜底保险）：思考窗口以 NoActivate 显示、理论上不抢焦点，但为绝对可靠，
    ; 在插入结果前若前台窗口不是原编辑器，主动拉回焦点——否则后续按键发错窗口会导致
    ; “误删上下文”（选区未被 Right 折叠而被后续字符替换）与“结果漏输/不完整”。
    if (thinkingPrevWin != 0 && WinExist("A") != thinkingPrevWin && WinExist("ahk_id " . thinkingPrevWin)) {
        WinActivate("ahk_id " . thinkingPrevWin)
        loop 50 {
            if (WinExist("A") = thinkingPrevWin)
                break
            Sleep(10)
        }
    }

    ; 追加结果（需求 2026-08-11：AI 模式由“替换上下文”改为“追加到上下文之后，隔一行”）：
    ; 上下文保持不变；先把光标定位到上下文末尾——选区场景按 Right 折叠选区（活动端在右端时
    ; 仅取消选区、光标不动，在左端时光标落到选区右端，两种情况光标都落在上下文末尾之后），
    ; 光标前上下文场景光标本来就在上下文末尾；然后回车两次隔一行（结束上下文所在行 +
    ; 产生一个空行），最后插入 AI 生成的结果。
    if (fromSel)
        Send("{Right}")
    Sleep(30)
    Send("{Enter}")
    Sleep(30)
    Send("{Enter}")
    Sleep(30)
    TypeTextSlowly(chosen)
    ToolTip()
    DebugLog("AI：完成")
}

; ============================================================================
; 20. CompleteTikz —— tikz 模式主流程
;     上下文选择（选区优先，与 AI 模式一致）→ 无上下文匹配限制（任何非空上下文都合法）
;     → 把上下文视为 TikZ 绘图代码：包装为最小可编译文档 → pdflatex 编译
;     → PDF 转 PNG → 复制到剪贴板并通过 Snipaste 贴图展示
;     编译 / 转换失败 → 无框窗口显示错误信息；空上下文 → 无操作
; ============================================================================
CompleteTikz() {
    ctx := GetContextAI()
    context := ctx.text
    DebugLog("tikz：上下文='" . context . "'（" . (ctx.fromSelection ? "选区" : "光标前") . "）")
    if (context = "") {
        DebugLog("tikz：空上下文，无操作")
        return
    }
    DebugLog("tikz：开始渲染，上下文长度=" StrLen(context))

    ; 编译期间显示进度提示
    ToolTip("正在编译 TikZ 并渲染图片...")

    ; 创建临时工作目录（每次触发使用独立目录，避免并发冲突）
    workDir := A_Temp "\SharpKnife\tikz\" FormatTime(, "yyyyMMddHHmmss") "_" Random(1000, 9999)
    try DirCreate(workDir)
    catch {
        ToolTip()
        DebugLog("tikz：创建临时目录失败")
        return
    }

    ; 组装最小可编译 LaTeX 文档并写入 main.tex
    texCode := WrapTikzDocument(context)
    texPath := workDir "\main.tex"
    try {
        FileAppend(texCode, texPath, "UTF-8")
    } catch {
        ToolTip()
        DebugLog("tikz：写入 main.tex 失败")
        TikzCleanup(workDir)
        return
    }
    DebugLog("tikz：已写入 " texPath)

    ; pdflatex 编译（带超时保护）；失败返回错误信息
    pdfPath := workDir "\main.pdf"
    errMsg := CompileTikz(workDir, texPath)
    if (errMsg != "") {
        ToolTip()
        DebugLog("tikz：编译失败，" errMsg)
        ShowTikzError(errMsg, workDir)
        return
    }
    if (!FileExist(pdfPath)) {
        ToolTip()
        DebugLog("tikz：编译结束但未生成 PDF")
        ShowTikzError("编译结束但未生成 PDF 文件。", workDir)
        return
    }
    DebugLog("tikz：编译成功")

    ; PDF → PNG
    pngPath := ConvertPdfToPng(pdfPath, workDir)
    if (pngPath = "") {
        ToolTip()
        DebugLog("tikz：PDF 转 PNG 失败")
        ShowTikzError("PDF 已生成，但转 PNG 失败。请在 config.ini 的 [tikz] 段配置 converter"
            . "（pdftoppm / mutool / gswin64c / magick），并确保对应工具已安装。", workDir)
        return
    }
    ToolTip()
    DebugLog("tikz：渲染成功，图片='" pngPath "'")

    ; 通过 Snipaste 贴图展示（内部负责临时目录清理）
    PasteTikzImage(pngPath, workDir)
}

; ============================================================================
; 20a. WrapTikzDocument —— 把选中内容包装成最小可编译 LaTeX 文档
;      形态判断（自动）：
;        1) 含 \begin{document}    → 完整文档，原样返回；
;        2) 含 \begin{tikzpicture} → standalone 文档类 + \usepackage{tikz} 包装；
;        3) 仅裸绘图语句           → 额外包一层 \begin{tikzpicture}...\end{tikzpicture}。
;      形如 \usepackage / \usetikzlibrary / \tikzset / \pgfplotsset 开头的行
;      会被自动提取到导言区（避免写在 document 体内编译报错）。
; ============================================================================
WrapTikzDocument(code) {
    global tikz_border, tikz_extra_pkgs

    ; 形态 1：完整文档 → 原样返回
    if (RegExMatch(code, "\\begin\{document\}"))
        return code

    ; 提取导言区命令行（\usepackage / \usetikzlibrary / \tikzset / \pgfplotsset 开头的行）
    preamble := ""
    bodyLines := []
    loop parse code, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        if (RegExMatch(line, "^\\(usepackage|usetikzlibrary|tikzset|pgfplotsset)"))
            preamble .= line . "`n"
        else
            bodyLines.Push(line)
    }
    body := ""
    for l in bodyLines
        body .= l . "`n"

    extraPkgs := ""
    if (tikz_extra_pkgs != "")
        extraPkgs := "\usepackage{" . tikz_extra_pkgs . "}`n"

    ; 形态 2：含 tikzpicture 环境 → 直接放入 document 体
    if (RegExMatch(code, "\\begin\{tikzpicture\}"))
        return "\documentclass[border=" . tikz_border . "]{standalone}`n"
            . "\usepackage{tikz}`n" . extraPkgs . preamble
            . "\begin{document}`n" . body . "\end{document}"

    ; 形态 3：裸绘图语句 → 包一层 tikzpicture
    return "\documentclass[border=" . tikz_border . "]{standalone}`n"
        . "\usepackage{tikz}`n" . extraPkgs . preamble
        . "\begin{document}`n"
        . "\begin{tikzpicture}`n" . body
        . "\end{tikzpicture}`n"
        . "\end{document}"
}

; ============================================================================
; 20b. CompileTikz —— 调用 pdflatex 编译 TikZ 文档（带超时保护）
;      成功返回空字符串；失败返回错误信息（取自 main.log 的错误行）
; ============================================================================
CompileTikz(workDir, texPath) {
    global tikz_pdflatex, tikz_timeout_ms
    exe := tikz_pdflatex
    if (exe = "")
        exe := FindToolPath("pdflatex")
    if (exe = "")
        return "未找到 pdflatex。请安装 MiKTeX / TeX Live，或在 config.ini 的 [tikz] 段配置 pdflatex_path。"

    ; 清理上一次编译产物，避免误判成功
    try FileDelete(workDir "\main.log")
    try FileDelete(workDir "\main.pdf")
    try FileDelete(workDir "\pdflatex.out")

    ; 用 cmd /S /C 包装并在 Hide 下运行：
    ;  - cmd 的 /S /C 让内部引号原样传给子进程（普通 /c 会剥离首尾引号，
    ;    导致 "文件名、目录名或卷标语法不正确"）；
    ;  - < nul 给 stdin 提供有效句柄（AHK 隐藏运行时无有效 stdin，MiKTeX
    ;    wrapper 探测 stdin 可能挂起）；
    ;  - stdout/stderr 重定向到 pdflatex.out，超时/失败时能看出卡在哪个宏包。
    inner := "`"" exe "`" -interaction=nonstopmode -halt-on-error `"" texPath "`" < nul > pdflatex.out 2>&1"
    cmd := A_ComSpec " /S /C `"" inner "`""
    try {
        Run(cmd, workDir, "Hide", &pid)
    } catch as e {
        return "启动 pdflatex 失败：" . e.Message
    }

    ; 等待编译进程退出。
    ; 注意：不能用 ProcessWaitClose —— AHK v2 对"已退出的进程"会等待满超时后
    ; 返回 false（实测进程已退出、ProcessExist 已为 0，ProcessWaitClose 仍超时），
    ; 导致编译永远被判为超时。改用 ProcessExist 轮询。
    deadline := A_TickCount + tikz_timeout_ms
    while (ProcessExist(pid) && A_TickCount < deadline)
        Sleep 100
    if (ProcessExist(pid)) {
        ; 超时 → 杀进程树（cmd → pdflatex wrapper → miktex 引擎），避免残留进程锁住宏包数据库
        try RunWait("taskkill /PID " . pid . " /T /F", , "Hide")
        return "编译超时（" . tikz_timeout_ms . " 毫秒）。可能是所需宏包缺失导致卡住，"
            . "请先手动用 MiKTeX 控制台安装所需宏包后重试。`n`n"
            . ReadTikzConsoleTail(workDir)
    }
    if (FileExist(workDir "\main.pdf"))
        return ""

    ; 编译失败 → 从 main.log 提取错误行
    return ReadTikzLogError(workDir "\main.log")
}

; ============================================================================
; 20b2. ReadTikzConsoleTail —— 读取 pdflatex 控制台输出尾部（超时/失败诊断）
; ============================================================================
ReadTikzConsoleTail(workDir) {
    p := workDir "\pdflatex.out"
    if (!FileExist(p))
        return "（无 pdflatex 控制台输出）"
    out := FileRead(p)
    lines := StrSplit(out, "`n")
    tail := ""
    start := Max(1, lines.Length - 6)
    loop lines.Length - start + 1 {
        t := Trim(lines[start + A_Index - 1])
        if (t != "")
            tail .= t . "`n"
    }
    if (tail = "")
        return "（pdflatex 控制台输出为空）"
    return "pdflatex 输出尾部（可看到卡在哪个宏包）：`n" . tail
}

; ============================================================================
; 20c. ReadTikzLogError —— 从 pdflatex 日志提取错误信息（显示给用户）
; ============================================================================
ReadTikzLogError(logPath) {
    if (!FileExist(logPath))
        return "编译失败（未生成日志）。"
    log := FileRead(logPath)

    ; 提取以 ! 开头的错误行（pdflatex 的错误标记）
    errs := []
    loop parse log, "`n", "`r" {
        line := Trim(A_LoopField)
        if (SubStr(line, 1, 1) = "!")
            errs.Push(line)
    }
    if (errs.Length > 0) {
        msg := ""
        n := Min(errs.Length, 10)
        loop n
            msg .= errs[A_Index] . "`n"
        return "编译失败：`n" . msg
    }

    ; 没有 ! 行 → 取日志尾部几行作为线索
    lines := StrSplit(log, "`n")
    tail := ""
    start := Max(1, lines.Length - 8)
    loop lines.Length - start + 1
        tail .= Trim(lines[start + A_Index - 1]) . "`n"
    return "编译失败（日志尾部）：`n" . tail
}

; ============================================================================
; 20d. FindToolPath —— 在 PATH 中查找可执行文件（返回第一个匹配的完整路径，找不到返回空）
; ============================================================================
FindToolPath(exeName) {
    tmp := A_Temp "\SharpKnife\toolpath.tmp"
    try FileDelete(tmp)
    ; A_ComSpec 是 AHK v2 内置变量（= %ComSpec%，通常为 C:\Windows\system32\cmd.exe）；v1 的 ComSpec 写法会触发 #Warn
    RunWait(A_ComSpec " /c where " exeName " > `"" tmp "`" 2>&1", , "Hide")
    out := ""
    if (FileExist(tmp)) {
        out := FileRead(tmp)
        try FileDelete(tmp)
    }
    ; 取第一行
    n := InStr(out, "`n")
    if (n)
        out := SubStr(out, 1, n - 1)
    return Trim(out, " `t`r`n")
}

; ============================================================================
; 20e. ConvertPdfToPng —— 把 PDF 转成 PNG（返回生成的 PNG 路径；失败返回空字符串）
;      转换器探测顺序：配置指定 → auto 时依次尝试 pdftoppm / mutool / gswin64c / magick
;      （各转换器的输出命名规则不同，转换完成后扫描目录中最新的 PNG 兜底）
; ============================================================================
ConvertPdfToPng(pdfPath, workDir) {
    global tikz_converter, tikz_dpi
    outBase := workDir "\out"
    dpi := tikz_dpi

    ; 确定转换器尝试顺序
    convList := []
    if (tikz_converter != "" && tikz_converter != "auto")
        convList.Push(tikz_converter)
    else
        for name in ["pdftoppm", "mutool", "gswin64c", "magick"]
            convList.Push(name)

    for name in convList {
        exe := FindToolPath(name)
        if (exe = "")
            continue
        ok := false
        if (name = "pdftoppm")
            ok := RunTool('"' exe '" -png -r ' dpi ' "' pdfPath '" "' outBase '"', workDir)
        else if (name = "mutool")
            ok := RunTool('"' exe '" draw -o "' outBase '-%d.png" -r ' dpi ' "' pdfPath '"', workDir)
        else if (name = "gswin64c")
            ok := RunTool('"' exe '" -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r' dpi ' -o "' outBase '.png" "' pdfPath '"', workDir)
        else if (name = "magick")
            ok := RunTool('"' exe '" -density ' dpi ' "' pdfPath '" "' outBase '.png"', workDir)
        if (ok) {
            png := FindLatestPng(workDir)
            if (png != "")
                return png
        }
    }
    return ""
}

; 运行转换命令（Hide 模式），等待结束（最多 30 秒），返回是否正常结束
; 与 CompileTikz 相同：cmd /S /C 包装 + 输出重定向 + ProcessExist 轮询
;（ProcessWaitClose 对已退出进程会假超时，不能用）
RunTool(cmdLine, workDir) {
    cmd := A_ComSpec " /S /C `"" . cmdLine . "`" < nul > tool.out 2>&1"
    try {
        Run(cmd, workDir, "Hide", &pid)
    } catch
        return false
    deadline := A_TickCount + 30000
    while (ProcessExist(pid) && A_TickCount < deadline)
        Sleep 100
    if (!ProcessExist(pid))
        return true
    ; 超时 → 杀进程树，避免残留
    try RunWait("taskkill /PID " . pid . " /T /F", , "Hide")
    return false
}

; ============================================================================
; 20f. FindLatestPng —— 返回目录中最新的 PNG 文件（转换工具命名规则不同，扫描兜底）
; ============================================================================
FindLatestPng(dir) {
    latest := ""
    loop files dir "\*.png" {
        if (latest = "" || FileGetTime(A_LoopFilePath, "M") > FileGetTime(latest, "M"))
            latest := A_LoopFilePath
    }
    return latest
}

; ============================================================================
; 20g0. TikzPasterCount —— 统计 Snipaste 贴图窗口（Paster）数量
;      Snipaste 贴图窗口是 Qt 工具窗口（WS_EX_TOOLWINDOW），AHK 的
;      WinGetList / WinExist 默认排除工具窗口，必须用 EnumWindows 枚举。
;      匹配条件：窗口标题为 "Paster - Snipaste"。
;      回调函数无法直接修改局部变量，计数通过全局 tikz_paster_count 传递。
; ============================================================================
tikz_paster_count := 0

TikzPasterCount() {
    global tikz_paster_count
    static cb := 0
    if (!cb)
        cb := CallbackCreate(TikzPasterEnumProc)
    tikz_paster_count := 0
    DllCall("EnumWindows", "Ptr", cb, "Ptr", 0)
    return tikz_paster_count
}

TikzPasterEnumProc(hwnd, lParam) {
    global tikz_paster_count
    title := Buffer(256)
    DllCall("GetWindowText", "Ptr", hwnd, "Ptr", title, "Int", 128)
    if (InStr(StrGet(title), "Paster - Snipaste"))
        tikz_paster_count++
    return true
}

; ============================================================================
; 20g. PasteTikzImage —— 把渲染出的 PNG 通过 Snipaste 贴图展示
;      流程：探测 Snipaste（配置 → PATH → 常见安装路径）→ 确保已运行（未运行则启动）
;            → 复制 PNG 到剪贴板（PNG + CF_DIB 双格式）→ 调用 "snipaste paste" 贴出
;      失败（未安装 Snipaste / 剪贴板复制失败）→ 无框窗口显示错误信息
;      贴图成功后延迟清理临时目录
; ============================================================================
PasteTikzImage(pngPath, workDir) {
    global tikz_snipaste

    ; 1. 探测 Snipaste 可执行文件（配置 → PATH → 常见安装路径）
    exe := tikz_snipaste
    if (exe = "" || !FileExist(exe))
        exe := FindSnipaste()
    if (exe = "") {
        DebugLog("tikz：未找到 Snipaste")
        ShowTikzError("未找到 Snipaste，无法贴图。请在 config.ini 的 [tikz] 段配置"
            . " snipaste_path（Snipaste 官网：https://www.snipaste.com/）。", workDir)
        return
    }
    DebugLog("tikz：Snipaste 路径='" exe "'")

    ; 2. 确保 Snipaste 已在后台运行（命令行选项只在 Snipaste 运行后才有效）
    if (!ProcessExist("Snipaste.exe")) {
        try {
            Run(exe)
        } catch {
            DebugLog("tikz：启动 Snipaste 失败")
            ShowTikzError("启动 Snipaste 失败。请手动启动 Snipaste 后重试。", workDir)
            return
        }
        ; 等待 Snipaste 进程出现（最多 5 秒）
        loop 50 {
            if (ProcessExist("Snipaste.exe"))
                break
            Sleep 100
        }
        ; 冷启动后需等待 Snipaste 完成初始化、IPC 就绪（实测 0.7~1.8 秒）。
        ; 过早发送 paste 命令会丢失：第二实例无法连接尚未就绪的主实例，
        ; 日志中表现为“无 Second instance 记录”，贴图不出现。
        ; 等待 1.5 秒（下方第 4 步还有贴图验证重试兜底）。
        Sleep 1500
    }

    ; 3. 复制 PNG 到剪贴板（PNG 注册格式 + CF_DIB 双格式，供 Snipaste 读取）
    if (!TikzCopyPng(pngPath)) {
        DebugLog("tikz：复制图片到剪贴板失败")
        ShowTikzError("复制图片到剪贴板失败，无法通过 Snipaste 贴图。", workDir)
        return
    }

    ; 4. 调用 Snipaste 贴图（从剪贴板读取图片并贴出）
    ;    Snipaste 贴图后会创建标题为 "Paster - Snipaste" 的贴图窗口。
    ;    通过对比贴图前后的贴图窗口数量判断是否真正贴出；
    ;    若未出现（如冷启动 IPC 尚未就绪导致命令丢失）则等待后重发命令。
    beforeCount := TikzPasterCount()
    try {
        loop 4 {
            Run('"' exe '" paste', , "Hide")
            ; 等待贴图窗口出现（最多 2.5 秒）
            deadline := A_TickCount + 2500
            while (A_TickCount < deadline) {
                if (TikzPasterCount() > beforeCount)
                    break
                Sleep 100
            }
            if (TikzPasterCount() > beforeCount)
                break
            DebugLog("tikz：贴图窗口未出现，重试（第 " A_Index " 次）")
            Sleep 800
        }
    } catch {
        DebugLog("tikz：调用 Snipaste 贴图失败")
        ShowTikzError("调用 Snipaste 贴图失败。", workDir)
        return
    }
    if (TikzPasterCount() <= beforeCount) {
        DebugLog("tikz：贴图失败（多次重试后贴图窗口仍未出现）")
        ShowTikzError("Snipaste 贴图失败：贴图窗口未出现。请确认 Snipaste 已安装并运行。", workDir)
        return
    }
    DebugLog("tikz：已调用 Snipaste 贴图，图片='" pngPath "'")

    ; 5. 延迟清理临时目录
    if (workDir != "")
        SetTimer(() => TikzCleanup(workDir), -8000)
}

; ============================================================================
; 20g2. FindSnipaste —— 自动探测 Snipaste 可执行文件路径
;      探测顺序：PATH（where snipaste，含 scoop shim）→ %LOCALAPPDATA%\Snipaste
;              → %ProgramFiles% / %ProgramFiles(x86)% → scoop 安装路径
;              找不到返回空字符串
; ============================================================================
FindSnipaste() {
    ; 1) PATH（where snipaste；scoop 安装时 shims 目录在 PATH 中，可直接命中）
    exe := FindToolPath("snipaste")
    if (exe != "" && FileExist(exe))
        return exe
    ; 2) 常见安装路径（%LOCALAPPDATA% / %ProgramFiles% / %ProgramFiles(x86)%）
    ;    AHK v2 无 A_LocalAppData / A_ProgramFilesX86 / A_UserProfile 内置变量，
    ;    统一用 EnvGet 读取对应环境变量
    candidates := [
        EnvGet("LOCALAPPDATA") "\Snipaste\Snipaste.exe",
        A_ProgramFiles "\Snipaste\Snipaste.exe",
        EnvGet("ProgramFiles(x86)") "\Snipaste\Snipaste.exe",
        ; 3) scoop 安装（shim 与应用本体）
        EnvGet("USERPROFILE") "\scoop\shims\Snipaste.exe",
        EnvGet("USERPROFILE") "\scoop\apps\Snipaste\current\Snipaste.exe"
    ]
    for p in candidates {
        if (FileExist(p))
            return p
    }
    return ""
}

; 清理 tikz 临时目录（尽力而为，文件被占用时静默跳过）
TikzCleanup(workDir) {
    try DirDelete(workDir, true)
}

; ============================================================================
; 20g3. TikzCopyPng —— 把指定 PNG 文件复制到剪贴板（返回是否成功）
;      同时提供两种格式，保证新旧应用都能粘贴：
;        1. 注册格式 "PNG"（PNG 文件原始字节）—— 微信/QQ/Teams/新版画图/浏览器等现代应用
;        2. CF_DIB（从位图转换的设备无关位图）—— 传统应用（老版画图、Word、Office 等）
;      旧实现只放 CF_BITMAP（设备相关位图），现代应用普遍不认 → 粘贴无效
; ============================================================================
TikzCopyPng(pngPath) {
    static fmtPng := 0
    if (pngPath = "" || !FileExist(pngPath))
        return false
    ok := false
    try {
        ; 读 PNG 原始字节（用于 PNG 注册格式）
        f := FileOpen(pngPath, "r")
        f.Seek(0, 2)
        size := f.Pos
        f.Seek(0)
        buf := Buffer(size)
        f.RawRead(buf, size)
        f.Close()

        ; 位图句柄（用于生成 CF_DIB）
        hbm := LoadPicture(pngPath)
        hDib := hbm ? HbmToDib(hbm) : 0

        if (!fmtPng)
            fmtPng := DllCall("RegisterClipboardFormat", "Str", "PNG", "UInt")

        ; PNG 内存块（GlobalAlloc，供 SetClipboardData）
        hMem := DllCall("GlobalAlloc", "UInt", 0x0042, "UPtr", size, "UPtr")
        if (hMem) {
            p := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
            DllCall("RtlMoveMemory", "Ptr", p, "Ptr", buf, "UPtr", size)
            DllCall("GlobalUnlock", "Ptr", hMem)
        }

        if (DllCall("OpenClipboard", "Ptr", 0)) {
            if (DllCall("EmptyClipboard")) {
                if (hMem) {
                    ; 成功则剪贴板接管 hMem；失败自己释放
                    if (DllCall("SetClipboardData", "UInt", fmtPng, "Ptr", hMem))
                        ok := true
                    else
                        DllCall("GlobalFree", "Ptr", hMem)
                }
                if (hDib) {
                    ; CF_DIB = 8（设备无关位图剪贴板格式）
                    if (DllCall("SetClipboardData", "UInt", 8, "Ptr", hDib))
                        ok := true
                    else
                        DllCall("GlobalFree", "Ptr", hDib)
                }
            } else {
                ; EmptyClipboard 失败：剪贴板未接管，自己释放
                ; 注意：AHK v2 的 else 块内第一个语句不能用传统单行 if，必须用块形式
                if (hMem) {
                    DllCall("GlobalFree", "Ptr", hMem)
                }
                if (hDib) {
                    DllCall("GlobalFree", "Ptr", hDib)
                }
            }
            DllCall("CloseClipboard")
        } else {
            if (hMem) {
                DllCall("GlobalFree", "Ptr", hMem)
            }
            if (hDib) {
                DllCall("GlobalFree", "Ptr", hDib)
            }
        }
        ; hbm 始终由我们释放（hDib 是复制出来的另一份）
        if (hbm)
            DllCall("DeleteObject", "Ptr", hbm)
    }
    return ok
}

; ============================================================================
; 20g3b. HbmToDib —— 把 HBITMAP 转换为 DIB（BITMAPINFOHEADER + 像素数据）
;       返回 GlobalAlloc 的可移动内存句柄（供 SetClipboardData(CF_DIB) 使用）；失败返回 0
; ============================================================================
HbmToDib(hbm) {
    ; BITMAP 结构：bmType(4) bmWidth(4) bmHeight(4) bmWidthBytes(4) bmPlanes(2) bmBitsPixel(2) bmBits(Ptr)
    bm := Buffer(32)
    DllCall("GetObject", "Ptr", hbm, "Int", bm.Size, "Ptr", bm)
    width := NumGet(bm, 4, "Int")
    height := NumGet(bm, 8, "Int")   ; 正=自下而上
    bpp := NumGet(bm, 18, "UShort")
    absH := Abs(height)
    if (width <= 0 || absH = 0 || bpp = 0)
        return 0

    ; BITMAPINFOHEADER(40 字节) + 预留调色板空间
    bmi := Buffer(40 + 1024)
    NumPut("UInt", 40, bmi, 0)
    NumPut("Int", width, bmi, 4)
    NumPut("Int", absH, bmi, 8)      ; 统一自下而上
    NumPut("UShort", 1, bmi, 12)     ; 位平面数
    NumPut("UShort", bpp, bmi, 14)
    NumPut("UInt", 0, bmi, 16)       ; BI_RGB（无压缩）

    ; 兼容 DC（GetDIBits 需要与位图兼容的 DC）
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm)

    ; 第一次：算出实际像素大小（biSizeImage）
    DllCall("GetDIBits", "Ptr", hdcMem, "Ptr", hbm, "UInt", 0, "UInt", absH, "Ptr", 0, "Ptr", bmi, "UInt", 0)
    imgSize := NumGet(bmi, 20, "UInt")
    if (imgSize = 0)
        imgSize := width * absH * (bpp // 8)

    total := 40 + imgSize
    hMem := DllCall("GlobalAlloc", "UInt", 0x0042, "UPtr", total, "UPtr")
    if (!hMem) {
        DllCall("DeleteDC", "Ptr", hdcMem)
        return 0
    }
    p := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
    DllCall("RtlMoveMemory", "Ptr", p, "Ptr", bmi, "UPtr", 40)
    ; 第二次：填像素数据
    DllCall("GetDIBits", "Ptr", hdcMem, "Ptr", hbm, "UInt", 0, "UInt", absH, "Ptr", p + 40, "Ptr", bmi, "UInt", 0)
    DllCall("GlobalUnlock", "Ptr", hMem)
    DllCall("DeleteDC", "Ptr", hdcMem)
    return hMem
}

; ============================================================================
; 20h. ShowTikzError —— 无框窗口显示 tikz 渲染错误信息
;      Esc 关闭；关闭后延迟清理临时目录
; ============================================================================
ShowTikzError(errMsg, workDir) {
    global ui_font_size
    cp := GetCaretScreenPos()
    errGui := Gui()
    errGui.Opt("-Caption +ToolWindow +AlwaysOnTop +Border")
    errGui.BackColor := "2D2D2D"
    errGui.SetFont("s" ui_font_size, "Consolas")
    errGui.Add("Text", "cFF6B6B w520", "TikZ 渲染失败：")
    errGui.Add("Edit", "ReadOnly +Multi cFFCCCC Background2D2D2D w520 r12", errMsg)
    errGui.Add("Text", "c888888", "Esc 关闭")
    errGui.OnEvent("Escape", (*) => CloseTikzError(errGui, workDir))
    errGui.OnEvent("Close", (*) => CloseTikzError(errGui, workDir))
    errGui.Show("AutoSize Hide")
    errGui.GetPos(&gx, &gy, &gw, &gh)
    newX := cp.x
    newY := cp.y
    if (newY + gh > A_ScreenHeight)
        newY := cp.y - gh
    if (newX + gw > A_ScreenWidth)
        newX := A_ScreenWidth - gw
    if (newX < 0)
        newX := 0
    if (newY < 0)
        newY := 0
    errGui.Move(newX, newY)
    errGui.Show()
    ; 延迟清理临时目录
    if (workDir != "")
        SetTimer(() => TikzCleanup(workDir), -8000)
}

; 关闭 tikz 错误窗口并延迟清理临时目录
CloseTikzError(guiObj, workDir) {
    guiObj.Destroy()
    if (workDir != "")
        SetTimer(() => TikzCleanup(workDir), -8000)
}

; ============================================================================
; 13. 托盘菜单（初始构建）
; ============================================================================
RefreshTrayMenu()

; 编译版：直接从 exe 自身的内嵌资源加载图标（不依赖外部文件）
; 未编译版：从 images 文件夹加载
if (A_IsCompiled)
    TraySetIcon(A_ScriptFullPath, 1)
else
    TraySetIcon(A_ScriptDir "\images\SharpKnife.ico")
A_IconTip := "SharpKnife — " . trigger_hk . " 补全，" . toggle_hk . " 循环切换，" . direct_prefix . "0/1/2/3 直接切换，" . mode_list_hk . " 模式列表，" . step_hotkey . " play 步进"

; ============================================================================
; 14. 启动提示
; ============================================================================
TrayTip(
    "就绪 — " . mode_names[mode + 1] . " 模式（默认）`n"
    . trigger_hk . " 补全，" . toggle_hk . " 循环切换 latex / unicode / AI / tikz`n"
    . direct_prefix . "0/1/2/3 直接切换（0=latex，1=unicode，2=AI，3=tikz）`n"
    . mode_list_hk . " 模式列表选择，" . step_hotkey . " play 步进执行",
    "SharpKnife"
)

; ============================================================================
; 测试钩子：--play-file=<脚本路径> 启动即绑定该 play 脚本并立即执行第 1 步，
;           跳过文件选择框（供自动测试 / CI 使用）；正常用法不受影响。
;           注意：A_Args 为空时索引会越界，须先判 Length。
; ============================================================================
if (A_Args.Length >= 1) {
    for i, a in A_Args {
        if (SubStr(a, 1, 12) = "--play-file=")
            PlayBindFile(SubStr(a, 13))
    }
}