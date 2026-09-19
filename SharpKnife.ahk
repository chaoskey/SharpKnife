; ==============================================================================
; SharpKnife —— LaTeX / Unicode / AI / TikZ 四模式补全工具
; 作者：Andrew（经 Hermes Agent 协作）
; 环境要求：AutoHotkey v2.0+（Windows 10）
; 数据源：latexs.cvs
; 触发命令：Ctrl+J（可通过配置修改）；循环切换命令：Ctrl+Shift+J（可通过配置修改）；
; 直接切换命令：Ctrl+Shift+0/1/2/3（0=latex，1=unicode，2=AI，3=tikz，前缀可通过配置修改）；
; 触发模式列表：Ctrl+Shift+\（弹出无框列表，上下键选择 + 回车切换，或鼠标点击目标模式直接切换，可通过配置修改）；
; 步进执行命令：Ctrl+R（play 模式专属，可通过配置修改）；
; 循环提醒：Ctrl+Alt+H 启动/停止（站立/坐下/走动循环，可通过配置修改）
; ==============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

; 测试钩子 `--selftest` 与诊断开关 `--dump-runbox-prompt` 见文件下方 auto-execute 区的
; 「命令行分流」（那里全局变量已声明，A_Args 也已可用）。
; 编译时把托盘图标嵌入 exe 作为资源 ID 1（Ahk2Exe 编译指令，运行 .ahk 时忽略）
;@Ahk2Exe-AddResource images\SharpKnife.ico, 1

KeyHistory 0
A_MaxHotkeysPerInterval := 200
SendMode("Input")
; 坐标系默认改为屏幕坐标（默认是"当前激活窗口客户区"，会导致非全屏窗口下
; MouseGetPos 等返回客户区坐标、而 Gui.Show/WinMove 用屏幕坐标 → 弹出位置偏移；
; 在 script startup 设置后所有热键线程默认继承该值）
CoordMode("Mouse", "Screen")   ; MouseGetPos / Click / MouseMove 等用屏幕坐标
CoordMode("Caret", "Screen")   ; CaretGetPos 用屏幕坐标（GetCaretScreenPos 已自设，此处兜底）
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
mode_list_hk := IniRead(configFile, "trigger", "mode_list_hotkey", "^+\")  ; 触发模式列表（弹出无框列表，上下键选择 + 回车切换，或鼠标点击目标模式直接切换）
if (mode_list_hk = "")
    mode_list_hk := "^+\"    ; 防空守卫：配置为空时恢复默认
step_hotkey := IniRead(configFile, "trigger", "step_hotkey", "^r")  ; 步进执行命令（play 模式专属，无论处于哪个状态都有效）
if (step_hotkey = "")
    step_hotkey := "^r"    ; 防空守卫：配置为空时恢复默认

; 循环提醒配置（[health] 段）：循环 站立→坐下→走动，直到按热键停止
; 三步各用等长列表描述，阶段按下标对应（0=站立 1=坐下 2=走动）：
;   step_name  = [站立20分钟, 坐下8分钟, 走动2分钟]   各阶段提示/托盘/右上角文字
;   step_min   = [20, 8, 2]                          各阶段时长（分钟，可用小数）
;   step_sound = [audio\20-8-2-stand.wav, ...]       各阶段提示音频（空串元素=该阶段用默认蜂鸣）
; 三者均非空（长度>=1）即生效；step_sound / step_name 可缺省（分别回退默认蜂鸣 / 自动拼名字）。
health_hotkey := IniRead(configFile, "health", "hotkey", "^!h")  ; 启动/停止热键（默认 Ctrl+Alt+H，与默认快捷键无冲突）
if (health_hotkey = "")
    health_hotkey := "^!h"    ; 防空守卫：配置为空时恢复默认
health_sound     := (IniRead(configFile, "health", "sound", "true") = "true")         ; 阶段切换是否发声提醒
health_notify_ms := Max(Number(IniRead(configFile, "health", "notify_ms", 5000)), 500) ; 右上角提示自动消失时长（毫秒，默认 5000=5 秒）
health_durations := HealthParseMinList(IniRead(configFile, "health", "step_min", ""), "20,8,2")  ; 各阶段时长（分钟）
health_phase_names := HealthParseNameList(IniRead(configFile, "health", "step_name", ""), health_durations)  ; 各阶段提示文字
health_sounds := HealthParseStrList(IniRead(configFile, "health", "step_sound", ""))     ; 各阶段音频路径，元素空串=默认蜂鸣

; 解析 [health] step_min 列表（元素=时长分钟）：逗号分隔、各元素取 .1 下界。cfg 为空用 def 兜底。
HealthParseMinList(raw, def) {
    ; 统一规范化：去空格后若形如 [a, b, c] 则剥掉首尾方括号，再按逗号切
    items := StrSplit(HealthStripBrackets(raw), ",")
    ; 若整串为空（未配置）→ 用默认 def 串兜底（def 不带方括号）
    numItems := []
    for it in items {
        t := Trim(it)
        if (t != "")
            numItems.Push(t)
    }
    if (numItems.Length = 0)
        numItems := StrSplit(def, ",")
    arr := []
    for it in numItems {
        v := Number(Trim(it))
        arr.Push(IsNumber(v) ? Max(v, 0.1) : 20)
    }
    if (arr.Length = 0)
        arr.Push(20)
    return arr
}

; 去掉整串首尾空格并剥掉最外层的 [ ]（若有），供逗号分隔解析。
HealthStripBrackets(s) {
    t := Trim(s)
    ; 仅当整串首尾为方括号时才剥掉；取末字符用 StrLen（AHK v2 索引从 1 起，0 无效）
    if (SubStr(t, 1, 1) = "[" && SubStr(t, StrLen(t)) = "]")
        return SubStr(t, 2, -1)   ; 去掉首 [ 与尾 ]，保留中间逗号分隔内容
    return t
}

; 解析 [health] step_sound 列表（元素=音频路径，含“音频1,\…含逗号?无”按逗号分隔），元素 Trim 后保留；缺省=全空（默认蜂鸣）
HealthParseStrList(raw) {
    arr := []
    s := HealthStripBrackets(raw)              ; 剥掉外层 [ ]
    if (Trim(s) = "")
        return arr          ; 未配置：一律用默认蜂鸣
    for it in StrSplit(s, ",") {
        t := Trim(it)
        ; 空元素也是合法“该阶段用默认蜂鸣”，非空直接保留
        arr.Push(t)
    }
    return arr
}

; 解析 [health] step_name 列表：缺省（/未配/元素数为0）时按“动词+step_min 对应分钟”自动拼名字。
HealthParseNameList(raw, mins) {
    defaultVerbs := ["站立", "坐下", "走动"]
    s := HealthStripBrackets(raw)              ; 剥掉外层 [ ]
    items := (Trim(s) = "") ? [] : StrSplit(s, ",")
    arr := []
    for i, it in items {
        trimIt := Trim(it)
        if (trimIt != "") {
            arr.Push(trimIt)                     ; 显式名称
        } else if (i <= mins.Length) {
            arr.Push(defaultVerbs[Min(i, defaultVerbs.Length)] mins[i] "分钟")   ; 自动拼“站立N分钟”等
        } else {
            arr.Push("")                          ; 空占位
        }
    }
    if (arr.Length = 0) {   ; 未配置 → 按上述中文动词 + 对应时长生成默认名
        arr := []
        for i, m in mins {
            if (i > defaultVerbs.Length)
                arr.Push("阶段" i)
            else
                arr.Push(defaultVerbs[i] m "分钟")
        }
        if (arr.Length = 0)
            arr := ["站立" mins[1] "分钟", "坐下" mins[2] "分钟", "走动" mins[3] "分钟"]
    }
    return arr
}

; play 模式配置（[play] 段）：script_path = play 脚本文件全路径（可选，可设可不设）
; 留空（默认）= 未设置：关闭状态下触发时弹出文件选择框由用户选择脚本（保持原有行为）；
; 设置 = 关闭状态下触发时直接绑定该脚本并立即执行第 1 步（开启状态下仍执行下一步）。
; 两种方式仅是选择脚本的途径不同，绑定 / 步进 / 自动解绑 / 失败处理等行为完全一致。
play_script_path := Trim(IniRead(configFile, "play", "script_path", ""))
type_delay_ms := Max(IniRead(configFile, "context", "type_delay_ms", 3), 0)
max_typing    := Max(IniRead(configFile, "ui", "max_typing_chars", 2000), 10)

show_progress := (IniRead(configFile, "ui", "show_progress", "true") = "true")
progress_text := IniRead(configFile, "ui", "progress_text", "正在生成...")
ui_font_size  := Max(IniRead(configFile, "ui", "font_size", 10), 6)   ; 磅，最小 6

; 浮层文字颜色（四块小键盘 + 径向菜单共用）：#RRGGBB 或 RRGGBB（也接受少量颜色名），
; 默认亮黄色 FFFF00；非法值 / 纯黑（等于看不见）一律退回默认。
overlay_text_color := OverlayParseColor(IniRead(configFile, "ui", "overlay_text_color", ""), "FFFF00")
; 浮层文字的黑边宽度（像素，0 = 不描边，默认 1）；描边同样不受透明度影响
overlay_text_outline := Max(Min(IniRead(configFile, "ui", "overlay_text_outline", 1) + 0, 3), 0)

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
; OpenCode Go（https://opencode.ai/zen/go/...）要求每个请求携带稳定的会话 id——
; 见 https://opencode.ai/docs/go 的“Where can I use it（可以在哪里使用）”。
; 这里用 [ai] x_opencode_session 配置 x-opencode-session 请求头的值：
;   非空 => 每次请求都发送该头（每个会话应填固定值，便于路由与提示词缓存）
;   留空/未配置 => 不发送该头（适用于非 OpenCode Go 的模型）
ai_opencode_session := IniRead(configFile, "ai", "x_opencode_session", "")

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

; 径向菜单全局状态
global radialGroups := []      ; 组数组 [{name, id, items: [{name, actionType, actionValue}]}]
global radialTrigger := ""     ; 触发快捷键
global radialFontSize := 0     ; 径向菜单字体大小（磅；[radial] font_size，缺省=全局 ui_font_size）
global radialCommonMax := 6    ; 第一层【常用】周边显示的高频菜单项个数（[radial] common_max，默认 6）
global radialGui := 0          ; 当前菜单 GUI 对象
global radialTextGui := 0      ; 菜单的文字层窗口（文字始终不透明；见 10c-3）
global radialLevel := 0        ; 当前层级：0=未显示，1=常用层，2=快捷菜单(分组)层，3=分组明细层
global radialCurrentGroup := 0 ; 第二级时当前组的索引
global radialFocusWin := 0     ; 弹窗前的焦点窗口
global radialCenterX := 0      ; 菜单中心 X 坐标
global radialCenterY := 0      ; 菜单中心 Y 坐标
global radialMenuItems := []   ; 当前层菜单项 [{name, kind, gi, ii, shownName}]；kind: shortcut/group/exec/disabled
global radialHover := 0        ; 当前悬停：0=无，-1=圆心，>0=扇区索引
global radialLayout := 0       ; 当前布局 {n, cx, cy, outerR, innerR, winSize, half, startRad}
global radialMsgMove := 0      ; OnMessage 注册句柄（WM_MOUSEMOVE）
global radialMsgDown := 0      ; OnMessage 注册句柄（WM_LBUTTONDOWN）
global radialMsgUp := 0        ; OnMessage 注册句柄（WM_LBUTTONUP）
global radialMsgRDown := 0     ; OnMessage 注册句柄（WM_RBUTTONDOWN）
global radialMsgLeave := 0     ; OnMessage 注册句柄（WM_MOUSELEAVE）
; 圆心区域「点击 / 拖拽」判定状态：按下时先记录起点，抬起时按位移判定
global radialDragPending := false ; 圆心已按下、尚未判定是"点击"还是"拖拽"
global radialDragging := false    ; 已判定为拖拽（圆盘正跟随鼠标移动）
global radialDragMoved := false   ; 本次按下期间是否真的拖动过（拖动过则抬起时不触发点击）
global radialDragStartX := 0      ; 按下时的鼠标屏幕 X
global radialDragStartY := 0      ; 按下时的鼠标屏幕 Y
global radialDragWinX := 0        ; 按下时的圆盘窗口左上角 X
global radialDragWinY := 0        ; 按下时的圆盘窗口左上角 Y
global radialStatsFile := A_ScriptDir "\menu_stats.ini"  ; 快捷键执行次数统计（独立文件，不存在时自动创建）

; 屏幕小键盘（方向 / 数字 / 符号 / 字母）全局状态
; 四块面板各自独立、可同时显示：状态全部放在注册表里，键 = "arrow" / "numpad" / "symbol" / "letter"
global keypadPanels := Map()     ; 已打开的面板：kind -> {gui, keys, layout, hover, focusWin, registered, drag*}；动态键必须用 Map（普通 Object 不支持 obj[键] := 值）
global keypadArrowHotkey := "^+k"  ; 方向小键盘触发键（[keypad] arrow_hotkey）
global keypadNumpadHotkey := "^+n" ; 数字小键盘触发键（[keypad] numpad_hotkey）
global keypadSymbolHotkey := "^+y" ; 符号小键盘触发键（[keypad] symbol_hotkey）
global keypadLetterHotkey := "^+e" ; 字母小键盘触发键（[keypad] letter_hotkey）
global keypadDefs := Map()       ; 四个面板的按键定义（[keypad.<kind>] 段；缺省 = 内置默认）：kind -> {name, cols, rows, square, case, keys:[{label, action, role}]}
global overlayCaseState := Map()  ; 各浮层的大小写状态（按浮层名存，如 "letter" / "radial"）：owner -> true（大写）/ false
global keypadFontSize := 0       ; 小键盘字体大小（磅；[keypad] font_size，缺省=全局 ui_font_size）
global keypadOpacity := 1.0      ; 小键盘透明度（[keypad] opacity，默认 1 = 不透明）
; 自然语言运行框（[runbox] 段）：中文需求 → 模型解析成动作序列 → 确认后执行
global runboxHotkey := "F6"      ; 触发键（[runbox] hotkey，默认 F6）
global runboxConfirm := true     ; true = 先列出动作清单、确认后执行
global runboxModel := ""         ; 覆盖 [ai] model（空 = 沿用）
global runboxTimeout := 0        ; 覆盖 [ai] timeout_ms（0 = 沿用）
global runboxStepDelay := 120    ; 动作之间的间隔（ms）
global runboxRunWait := 800      ; run: 之后自动等待（ms）
global runboxMaxActions := 40    ; 单次最多执行多少条动作（防呆）
global runboxPromptExtra := ""   ; 追加到内置系统提示语之后（可选）
global runboxOpacity := 1.0      ; 运行框（含下方键帽排）透明度（[runbox] opacity，默认 1 = 不透明）
global runboxGui := ""           ; 运行框**面板窗口**（GDI 自绘的半透明底 + 圆角；"" = 未打开）
global runboxTextGui := ""       ; 运行框**文字层**（UpdateLayeredWindow：提示/状态/把手/日志，文字与黑边恒不透明）
global runboxInputGui := ""      ; 运行框**输入框窗口**（独立顶层窗口，整块不透明）
global runboxEdit := ""          ; 输入框 Edit（挂在 runboxInputGui 上）
global runboxLogGui := ""        ; 运行框**执行过程窗口**（独立顶层窗口、整块不透明）
global runboxLogEdit := ""       ; 执行过程的只读多行 Edit（可滚动 / 选中 / 复制）
global runboxLogOffX := 0        ; 日志窗口客户区偏移（同输入框窗口的换算）
global runboxLogOffY := 0
global runboxStatusText := ""    ; 状态行文字（画在文字层，已不是 Text 控件）
global runboxHandleText := ""    ; 底部"执行过程"小把手文字（画在文字层）
global runboxLayout := ""        ; 布局：面板 / 输入框 / 状态 / 把手 / 日志的矩形（见 RunBoxComputeLayout）
global runboxInOffX := 0         ; 输入框窗口客户区左上角相对窗口左上角的偏移（无边框时通常为 0）
global runboxInOffY := 0
global runboxExpanded := false   ; 执行过程面板是否已展开
global runboxLog := []           ; 本次需求的执行全过程日志（逐行）
global runboxStartTick := 0      ; 本次执行的起始时刻（算总耗时）
global runboxToggleTick := 0     ; 上一次展开/收起的时间（去抖）
global runboxAvoidTick := 0      ; 运行框上一次"被别人避让挪动"的时刻（防互相顶）
global runboxTextPending := false ; 文字层是否有待重绘的内容
global runboxTextTimerOn := false ; 文字层节流定时器是否已挂
global runboxTextLastTick := 0   ; 上一次文字层重绘时刻（节流用）
global runboxDragActive := false ; 面板拖动中（自实现拖动：定时器轮询光标，不依赖系统移动循环）
global runboxDragMoved := false  ; 本次按下是否真的拖动过（没拖过 = 单击，要把光标还给输入框）
global runboxDragX0 := 0         ; 拖动起点（屏幕坐标）
global runboxDragY0 := 0
global runboxDragWinX := 0       ; 拖动开始时窗口左上角
global runboxDragWinY := 0
global runboxPrevWin := 0        ; 跟踪到的"最近一次活动的窗口"（动作最终打到它上面）
global runboxPrevTitle := ""     ; 该窗口标题（喂给模型当上下文）
global runboxExecBaseWin := 0    ; 开始执行动作那一刻的目标窗口（收尾判"有没有打开新窗口"用）
global runboxActions := []       ; 本次待执行动作
global runboxDropped := []       ; 被丢弃的行（展示给用户）
global runboxRunIdx := 0         ; 执行进度
global runboxBusy := false       ; 正在解析 / 执行
global runboxState := ""         ; "" / "input" / "loading" / "confirm" / "running" / "done"
                                 ;   自适应记忆新增两态：learning（正在整理记忆）/ learnconfirm（待确认记忆变更）
; —— 自适应记忆（runbox_memory.md）：别名快路径 + 偏好/正例/反例 + 学习流水（见 11d-2 节）——
global runboxMemoryFile := "runbox_memory.md"    ; 记忆文件（相对脚本目录；**显式留空 = 关闭本功能**）
global runboxLearnConfirm := true                ; true = 记忆写盘前先看 diff、回车才落盘
global runboxMemoryMaxChars := 1600              ; 记忆块拼进提示语的字数上限（超出按优先级裁剪）
global runboxAliasMatch := "contain"             ; 别名匹配力度：exact（完全相等）/ contain（含 ≥2 字说法）
global runboxLearnModel := ""                    ; 学习用模型（空 = 沿用 [ai] model）
global runboxLearnJournal := "runbox_learn.log"  ; 运行流水（相对脚本目录；空 = 不写）
global runboxMemory := {loaded: false, path: "", mtime: "", head: [], order: [], secs: Map(), aliasIdx: Map()}
global runboxMemoryDirty := false                ; 别名命中次数有变化、待落盘
global runboxLastReq := ""                       ; 上一次需求（反馈学习时当上下文）
global runboxLastActions := []                   ; 上一次解析出的动作
global runboxLastDropped := []                   ; 上一次被丢弃的行
global runboxLastResult := ""                    ; 上一次的结局文字（成功 / 失败原因）
global runboxLastAliasHit := ""                  ; 上一次是否由别名直接命中（写流水用）
global runboxLastJournaled := false              ; 本次需求是否已写过流水（防重复）
global runboxLastErrText := ""                   ; 上一次的 ERROR 文本（写流水用，无则空）
global runboxLearnArmed := false                 ; 键帽【纠正】(self:runbox_learn) 按下后：下一次输入按反馈处理
global runboxLearnPlan := 0                      ; 待确认的记忆变更计划（"learnconfirm" 态回车才落盘）
global runboxLearnBusy := false                  ; 正在请求"记忆维护"模型
global runboxLastMemoryNote := ""                ; 上一次运行用到的记忆（流水里记下来，便于事后归因）

global keypadMsgCount := 0       ; 已打开面板数：鼠标消息钩子按引用计数注册 / 注销
global keypadMsgMove := 0        ; OnMessage 注册句柄（WM_MOUSEMOVE）
global keypadMsgDown := 0        ; OnMessage 注册句柄（WM_LBUTTONDOWN）
global keypadMsgUp := 0          ; OnMessage 注册句柄（WM_LBUTTONUP）
global keypadMsgRDown := 0       ; OnMessage 注册句柄（WM_RBUTTONDOWN）
global keypadMsgLeave := 0       ; OnMessage 注册句柄（WM_MOUSELEAVE）

; 浮层公共状态（径向菜单 + 四块屏幕小键盘）：五者互相独立，共用一套 Esc 接管
global overlayStack := []        ; 已打开浮层的打开顺序（元素 = "radial" / "arrow" / "numpad" / "symbol" / "letter"）

; 径向菜单配置加载（必须在全局变量声明后调用，否则 global 赋值会重置数据）
RadialLoadConfig()

; 统计文件初始化（不存在则自动创建并写入说明头）
RadialStatsInit()

; 屏幕小键盘配置加载（同样必须在全局变量声明之后）
KeypadLoadConfig()

; ============================================================================
; 命令行分流（**必须尽早**：放在任何配置加载 / 热键注册之前）
;   为什么这么早：脚本里一旦有 #Warn 或非法语句，AHK 在*加载期*就弹框阻塞，
;   那时脚本一行都没执行、更谈不上 ExitApp —— 从 WSL 看就是"毫无输出地卡死"（AGENTS.md §5.1）。
;   而 A_Args 要等到 auto-execute 才可用，所以这里已经是"全局变量已声明、还没干任何事"的最早位置。
;   --selftest          ：只验证脚本可完整解析（含 #Include），随即 ExitApp(0)
;   --dump-runbox-prompt[=需求] ：把"模型会收到的提示语"写进 runbox_prompt_dump.txt 后退出
;                         （供 test/runbox_eval 评测与用户自查；配置/记忆尚未加载，故延后处理）
; ============================================================================
if (A_Args.Length >= 1 && A_Args[1] = "--selftest")
    ExitApp(0)

; 自然语言运行框配置加载（同样必须在全局变量声明之后）
RunBoxLoadConfig()

; ============================================================================
; 诊断开关：--dump-runbox-prompt[=需求] 或 --dump-runbox-prompt "需求"
;   只把"模型会收到的提示语 + 别名命中情况"写进 runbox_prompt_dump.txt 然后退出。
;   放在这里是为了：配置（radial / keypad / runbox / 记忆）都已加载，但**任何 GUI / 热键都还没注册**，
;   因此可以在无桌面的 WSL 里直接跑（供 test/runbox_eval 评测与用户自查）。
; ============================================================================
if (A_Args.Length >= 1 && SubStr(A_Args[1], 1, 21) = "--dump-runbox-prompt=") {
    ; 写法一：--dump-runbox-prompt=打开知乎网址（"需求"接在等号后面；引号由命令行处理）
    RunBoxDumpPrompt(SubStr(A_Args[1], 22))
    ExitApp(0)
}
if (A_Args.Length >= 1 && A_Args[1] = "--dump-runbox-prompt") {
    ; 写法二：--dump-runbox-prompt "打开知乎网址"（需求作为独立的第二个参数）
    RunBoxDumpPrompt(A_Args.Length >= 2 ? A_Args[2] : "")
    ExitApp(0)
}

RefreshTrayMenu() {
    global mode, healthTrayStateText
    A_TrayMenu.Delete()
    A_TrayMenu.Add((mode = MODE_LATEX ? "[x] " : "[ ] ") . "latex 模式", SetModeFromTray)
    A_TrayMenu.Add((mode = MODE_UNICODE ? "[x] " : "[ ] ") . "unicode 模式", SetModeFromTray)
    A_TrayMenu.Add((mode = MODE_AI ? "[x] " : "[ ] ") . "AI 模式", SetModeFromTray)
    A_TrayMenu.Add((mode = MODE_TIKZ ? "[x] " : "[ ] ") . "tikz 模式", SetModeFromTray)
    A_TrayMenu.Add()
    A_TrayMenu.Add(HealthTrayLabel(), HealthToggle)   ; “循环提醒”状态项（点击切换启动/停止）
    A_TrayMenu.Add()
    A_TrayMenu.Add("重新加载(&R)", (*) => Reload())
    A_TrayMenu.Add("退出(&X)", (*) => ExitApp())
    healthTrayStateText := HealthTrayLabel()   ; 记录当前状态项文字，供 HealthRefreshTrayState 用 Rename 就地刷新
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
; 上下键移动选择 + Enter 切换，或鼠标点击目标模式直接切换；Esc 取消（取消 → 无操作，保持当前模式）
ShowModeList(*) {
    global mode
    items := ["latex 模式（0）", "unicode 模式（1）", "AI 模式（2）", "tikz 模式（3）"]
    ; clickSubmit=true：鼠标点击目标项即直接切换；preselect=当前模式+1：高亮落在当前模式，
    ; 点击任意其它项必然产生选择变化 → 立即切换到该模式（点击当前模式项本无操作，不提交、语义正确）
    idx := ShowList(items, "选择模式：", true, mode + 1)
    if (idx = 0) {
        DebugLog("ShowModeList：用户取消，无操作")
        return
    }
    DebugLog("ShowModeList：选中第 " . idx . " 项")
    SetModeDirect(idx - 1)   ; idx：1/2/3/4 → 模式号 0/1/2/3（SetModeDirect 内部会校验非法模式号）
}

; ============================================================================
; 11b. 步进执行命令（play 模式专属，默认 Ctrl+R）—— 无论处于哪个状态都有效
;      关闭状态（未绑定脚本文件）：若配置了 [play] script_path 则直接绑定该脚本并立即执行第 1 步，
;      否则弹出 JSON 脚本选择窗口，校验通过后绑定并立即执行第 1 步
;      开启状态（已绑定脚本文件）：执行下一步；执行中（busy）触发被忽略（防重入）
;      脚本为 UTF-8 JSON：根是 seq（顶层动作数组），支持 text/sleep/run/note/paste/audio/video/seq/par 九类动作
;      详见 Requirements.md 第 7 / 8 节
; ============================================================================
StepPlay(*) {
    global playScriptFile, playBusy, play_script_path
    if (playScriptFile = "") {
        ; 关闭状态：配置了 play 脚本全路径则直接绑定（与文件选择框选定的脚本走同一条
        ; PlayBindFile 绑定路径，行为完全一致）；配置的脚本不可用（不存在 / 加载失败）时
        ; 非阻塞提示后回退到文件选择框，保证用户仍能手动选择脚本。
        if (play_script_path != "") {
            if (PlayBindFile(play_script_path, false)) {
                DebugLog("play：按配置 [play] script_path 直接绑定脚本")
                return
            }
            PlayNoteFail("play：配置的 play 脚本不可用，回退到文件选择框：'" . play_script_path . "'")
        }
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

; 绑定指定脚本文件（无文件选择框；供 PlayBind、StepPlay 配置路径与 --play-file= 测试钩子复用）。
; 加载失败记日志、不绑定，返回 false；成功则绑定并立即执行第 1 步，返回 true。
; showErr=true（默认）时加载失败弹窗提示；false 时仅记日志（供 [play] script_path 配置路径
; 失败后静默回退到文件选择框的场景，避免错误弹窗与选择框双重打扰）。
PlayBindFile(selected, showErr := true) {
    global playScriptFile, playScriptDir, playStepStack, playBusy
    root := PlayLoadScript(selected, showErr)
    if (root = "") {
        DebugLog("play：脚本加载失败，不绑定")
        return false
    }
    playScriptFile := selected
    n := InStr(selected, "\", , -1)
    playScriptDir := n ? SubStr(selected, 1, n - 1) : A_ScriptDir
    playStepStack := [{list: root, idx: 0}]
    playBusy := false
    DebugLog("play：已绑定脚本 '" . selected . "'（顶层共 " . root.Length . " 个动作）")
    PlayRunStepFrame()
    return true
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
; 读取脚本文件 → 解析 + 校验（纯逻辑在 SharpKnifeCore.ahk 的 PlayParseScriptText）；失败返回 "" 。
; showErr=true（默认）时失败弹窗提示；false 时静默失败（仅返回空，供配置脚本路径回退场景）。
PlayLoadScript(path, showErr := true) {
    txt := ""
    try {
        txt := FileRead(path, "UTF-8")
    } catch as e {
        if (showErr)
            PlayShowError("读取脚本失败：" . e.Message)
        return ""
    }
    errMsg := ""
    root := PlayParseScriptText(txt, &errMsg)
    if (!root) {
        if (showErr)
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
; 10. 径向菜单（Radial Menu）—— 三层圆形菜单，执行预配置快捷键
; ============================================================================

; ---- 辅助：创建点击回调闭包（捕获 idx 值，避免 for 循环闭包陷阱）----
RadialMakeClickHandler(idx) {
    return (*) => RadialOnItemClick(idx)
}


; ---- 加载 config.ini 的 [radial] 段（逐行扫描，保证顺序）----
RadialLoadConfig() {
    global radialGroups, radialTrigger, configFile, radialFontSize, radialCommonMax, ui_font_size, radialOpacity
    radialGroups := []
    radialTrigger := "^+m"              ; 默认触发键
    radialFontSize := Max(ui_font_size, 6)   ; 字体大小默认 = 全局 [ui] font_size
    radialCommonMax := 6                ; 第一层【常用】高频项个数默认 6
    radialOpacity := 1.0                ; 菜单透明度（0.0~1.0），默认 1 = 不透明

    DebugLog("[radial] RadialLoadConfig 入口 configFile=" . configFile)

    if !FileExist(configFile) {
        DebugLog("[radial] 配置文件不存在，使用默认值")
        return
    }

    ; FileRead 能自动识别 UTF-16/UTF-8 BOM 编码，Loop read 不行
    txt := ""
    try {
        txt := FileRead(configFile, "UTF-16")
        DebugLog("[radial] FileRead UTF-16 成功，len=" . StrLen(txt))
    } catch {
        try {
            txt := FileRead(configFile, "UTF-8")
            DebugLog("[radial] FileRead UTF-8 成功，len=" . StrLen(txt))
        } catch Error as e {
            DebugLog("[radial] FileRead 全部失败：" . e.Message)
            return
        }
    }
    if (txt = "") {
        DebugLog("[radial] 文件内容为空")
        return
    }

    inRadial := false
    currentGroup := 0
    lineNum := 0

    Loop parse, txt, "`n", "`r"
    {
        lineNum++
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        ; 剥离行内注释（"空白+分号"起至行尾）：支持 `key = value  ; 注释` 与 `[节名]  ; 注释`；
        ; 用「空白+分号」而非裸分号，避免误伤值里紧贴的分号（如分号键 `{;}`）
        if RegExMatch(line, "\s;", &cm)
            line := Trim(SubStr(line, 1, cm.Pos - 1))
        if (line = "")
            continue

        ; 节头
        if (SubStr(line, 1, 1) = "[") {
            if (line = "[radial]") {
                inRadial := true
                currentGroup := 0
            } else if (SubStr(line, 1, 8) = "[radial." && SubStr(line, -1) = "]") {
                inRadial := true
                gid := SubStr(line, 9, StrLen(line) - 9)
                radialGroups.Push({name: "", id: gid, items: [], hidden: false})
                currentGroup := radialGroups.Length
            } else {
                inRadial := false
                currentGroup := 0
            }
            continue
        }

        if (!inRadial)
            continue

        ; 解析 key = value
        eqPos := InStr(line, "=")
        if (eqPos = 0)
            continue

        key := Trim(SubStr(line, 1, eqPos - 1))
        value := Trim(SubStr(line, eqPos + 1))

        if (currentGroup = 0) {
            ; [radial] 段
            if (key = "trigger")
                radialTrigger := value
            else if (key = "font_size") {
                ; 径向菜单字体大小（磅）；非法值忽略（沿用默认）
                if RegExMatch(value, "^\d+(\.\d+)?$")
                    radialFontSize := Max(value + 0, 6)
            }
            else if (key = "opacity") {
                ; 菜单透明度，取值 0~1（支持小数），非法值忽略
                if RegExMatch(value, "^\d*\.?\d+$") {
                    v := value + 0
                    radialOpacity := Max(0.0, Min(v, 1.0))
                }
            }
            else if (key = "common_max") {
                ; 第一层【常用】显示的高频菜单项个数（0~20，默认 6）；非法值忽略
                if RegExMatch(value, "^\d+$")
                    radialCommonMax := Max(0, Min(Integer(value), 20))
            }
        } else {
            ; [radial.xxx] 段
            if (key = "name") {
                radialGroups[currentGroup].name := value
            } else if (key = "hidden" || key = "hide") {
                ; 该分组是否在圆盘菜单里隐藏（默认 false = 显示）；非法值忽略、沿用默认
                v := StrLower(Trim(value))
                if (v = "1" || v = "true" || v = "yes" || v = "on")
                    radialGroups[currentGroup].hidden := true
                else if (v = "0" || v = "false" || v = "no" || v = "off" || v = "")
                    radialGroups[currentGroup].hidden := false
            } else if RegExMatch(key, "^\d+$") {
                pipePos := InStr(value, "|")
                if (pipePos > 0) {
                    itemName := Trim(SubStr(value, 1, pipePos - 1))
                    ; 动作统一走浮层动作层（与四块小键盘同一套：send / run / close / case / self）
                    itemAction := OverlayActionParse(SubStr(value, pipePos + 1))
                    if (itemName != "" && itemAction.type != "none")
                        radialGroups[currentGroup].items.Push({name: itemName, actionType: itemAction.type, actionValue: itemAction.value, _num: Integer(key)})
                }
            }
        }
    }

    ; 按编号排序组内功能（插入排序）
    for g in radialGroups {
        if (g.items.Length > 1) {
            sorted := []
            for item in g.items {
                inserted := false
                for i, s in sorted {
                    if (item._num < s._num) {
                        sorted.InsertAt(i, item)
                        inserted := true
                        break
                    }
                }
                if (!inserted)
                    sorted.Push(item)
            }
            g.items := sorted
        }
    }
    DebugLog("[radial] RadialLoadConfig 完成：groups=" . radialGroups.Length . " trigger=" . radialTrigger . " font_size=" . radialFontSize . " common_max=" . radialCommonMax)
}

; ---- 紧凑自适应布局：按字号与各菜单名的实际渲染宽度计算中心圆/外环半径 ----
; 三条约束取最小满足值，使圆盘尽可能紧凑：
;   ① 圆心文字（水平居中的 w×h 矩形）须完全内接于中心圆；
;   ② 内边界处每个扇区的弧长须容下文字高度（相邻扇区文字不重叠）；
;   ③ 环宽须容下最长的扇区文字（放射性排布，文字沿径向展开）。
RadialComputeLayout(n, centerText, items, sizePt) {
    PI := 3.141592653589793
    fontPx := Max(Round(sizePt * 96 / 72), 8)
    pad := Max(Round(fontPx * 0.45), 5)          ; 文字与边界的呼吸间距
    angleStep := 2 * PI / n

    ; ① 圆心文字内接约束：矩形半对角 + 间距
    cw := RadialMeasureText(centerText, sizePt).w
    needA := Sqrt((cw / 2) ** 2 + (fontPx / 2) ** 2) + pad

    ; ② 内边界弧长约束：内圈弧长足够放下字高
    needB := (fontPx * 1.15) / angleStep

    innerR := Ceil(Max(needA, needB, fontPx * 0.85))

    ; ③ 环宽：容下最长的扇区文字（先按硬上限 8 字截断再实测宽度）
    maxLen := 0
    for it in items {
        w := RadialMeasureText(RadialTruncateToWidth(it.name, sizePt, 999999), sizePt).w
        if (w > maxLen)
            maxLen := w
    }
    ringW := maxLen + 2 * pad
    outerR := innerR + ringW

    margin := Max(pad, 6)
    winSize := Round(2 * (outerR + margin))
    return {innerR: innerR, outerR: outerR, ringW: ringW, pad: pad, fontPx: fontPx
            , winSize: winSize, half: winSize // 2, margin: margin}
}

; ---- 构建并显示菜单 GUI（GDI 自绘，不用 GDI+）----
; 用经典 Win32 GDI（CreateCompatibleDC / CreateEllipticRgn / FillRgn / TextOut）
; 双缓冲绘制真正的环形扇区菜单：外环按角度均分扇区，圆心为真正的圆形按钮，
; 扇区之间用细线分隔，文字放射状排布（沿径向，正立可读）。
RadialBuildMenu() {
    global radialGroups, radialGui, radialTextGui, radialLevel, radialCurrentGroup, radialCenterX, radialCenterY
    global radialMenuItems, radialHover, radialLayout, radialFontSize, radialCommonMax

    ; 销毁旧 GUI（含文字层；文字层无条件销毁，避免主窗口异常时残留）
    if (radialGui) {
        RadialUnregisterMsg()
        RadialFreeRgns()
        radialGui.Destroy()
        radialGui := 0
    }
    OverlayTextLayerDestroy(radialTextGui)
    radialTextGui := 0
    radialHover := 0

    ; 确定菜单项（展现内容）与圆心文字：
    ;   第一层【常用】：第 1 个周边固定为【快捷菜单】，其后按统计取高频前 6 的常用菜单项
    ;   第二层【快捷菜单】：各菜单分组名
    ;   第三层【<组名>】：该组内各菜单项
    ; 第三层：若该分组已被隐藏（正常进不去），退回第二层，避免显示一个"不存在"的分组
    if (radialLevel = 3 && radialCurrentGroup >= 1 && radialCurrentGroup <= radialGroups.Length) {
        if (radialGroups[radialCurrentGroup].hidden)
            radialLevel := 2
    }

    radialMenuItems := []
    if (radialLevel = 1) {
        centerText := "常用"
        radialMenuItems.Push({name: "快捷菜单", kind: "shortcut"})
        for f in RadialTopFrequent(radialCommonMax)
            radialMenuItems.Push({name: RadialCaseShownName(f.name, RadialItemAction(f.gi, f.ii)), kind: "exec", gi: f.gi, ii: f.ii})
    } else if (radialLevel = 2) {
        centerText := "快捷菜单"
        for vg in RadialVisibleGroups()        ; 隐藏的分组不出现在这里
            radialMenuItems.Push({name: vg.g.name, kind: "group", gi: vg.gi})
    } else {
        ; 第三层：需有效的分组索引（防御越界）
        if (radialCurrentGroup < 1 || radialCurrentGroup > radialGroups.Length)
            return
        group := radialGroups[radialCurrentGroup]
        centerText := group.name
        for ii, item in group.items
            radialMenuItems.Push({name: RadialCaseShownName(item.name, item.actionValue), kind: "exec", gi: radialCurrentGroup, ii: ii})
    }

    ; 周边菜单至少 4 个：不足则补空位（无文字、禁止高亮、点击无效）
    while (radialMenuItems.Length < 4)
        radialMenuItems.Push({name: "", kind: "disabled"})

    n := radialMenuItems.Length
    if (n = 0)
        return

    ; 圆心文字先按 8 字硬上限截断（布局与绘制用同一文本，保证紧凑一致）
    centerText := RadialTruncateToWidth(centerText, radialFontSize, 999999)

    ; 布局参数：紧凑自适应（随字号与各菜单名长度变化，取满足约束的最小半径）
    PI := 3.141592653589793
    LO := RadialComputeLayout(n, centerText, radialMenuItems, radialFontSize)
    OUTER_R := LO.outerR
    INNER_R := LO.innerR
    MARGIN := LO.margin
    winSize := LO.winSize
    half := LO.half

    radialLayout := {n: n, cx: half, cy: half, outerR: OUTER_R, innerR: INNER_R
        , winSize: winSize, half: half, startRad: -PI / 2, centerText: centerText
        , pad: LO.pad, fontPx: LO.fontPx, sectorRgns: []}

    ; 预计算每个扇区的显示文本（按环宽实测截断），避免每次悬停重绘重复测量
    radialSpace := LO.ringW - 2 * LO.pad
    for it in radialMenuItems
        it.shownName := RadialTruncateToWidth(it.name, radialFontSize, radialSpace)

    ; 先构建扇区多边形区域 + 圆心区域（只需几何参数；必须在 Show 之前，
    ; 否则 Show 触发的 WM_MOUSEMOVE 会经由全局 OnMessage 钩子访问空区域而越界）
    RadialBuildRgns()

    ; 创建 GUI（纯自绘，无任何控件）
    ; +E0x08000000 = WS_EX_NOACTIVATE：点击 / 拖拽菜单**不会激活菜单窗口、不改变前台窗口**，
    ; 因此"拖拽"只会移动圆盘，不会产生焦点切换等任何连带动作。
    ; （副作用：窗口永不获得键盘焦点，Esc 改由打开期间的全局热键接管，见 RadialRegisterMsg）
    radialGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    radialGui.BackColor := "2D2D3D"
    radialGui.MarginX := 0
    radialGui.MarginY := 0
    radialGui.OnEvent("Escape", (*) => RadialClose())

    ; 显示 GUI（限制在虚拟屏幕内；多显示器下同样以鼠标所在位置为准）
    vb := RadialVirtualBounds()
    guiX := Max(vb.x, Min(radialCenterX - half, vb.x + vb.w - winSize))
    guiY := Max(vb.y, Min(radialCenterY - half, vb.y + vb.h - winSize))
    radialGui.Show("x" . guiX . " y" . guiY . " w" . winSize . " h" . winSize . " NoActivate")

    ; 应用配置的透明度（radialOpacity 取值 0.0~1.0）
    if (IsSet(radialOpacity) && (radialOpacity + 0) < 1.0) {
        GWL_EXSTYLE := -20
        WS_EX_LAYERED := 0x00080000
        getWindowLongFn := (A_PtrSize = 8) ? "GetWindowLongPtrW" : "GetWindowLongW"
        setWindowLongFn := (A_PtrSize = 8) ? "SetWindowLongPtrW" : "SetWindowLongW"
        ex := DllCall(getWindowLongFn, "Ptr", radialGui.Hwnd, "Int", GWL_EXSTYLE, "Ptr")
        ; 打开 WS_EX_LAYERED
        DllCall(setWindowLongFn, "Ptr", radialGui.Hwnd, "Int", GWL_EXSTYLE, "Ptr", ex | WS_EX_LAYERED, "Ptr")
        alpha := Round(radialOpacity * 255)
        if (alpha < 0)
            alpha := 0
        if (alpha > 255)
            alpha := 255
        ; LWA_ALPHA = 0x2
        DllCall("SetLayeredWindowAttributes", "Ptr", radialGui.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 0x2)
    }

    ; 把窗口裁剪成真正的圆形（SetWindowRgn 后系统接管区域，勿 DeleteObject）
    hRgn := DllCall("CreateEllipticRgn"
        , "Int", 0, "Int", 0
        , "Int", winSize, "Int", winSize, "Ptr")
    DllCall("SetWindowRgn", "Ptr", radialGui.Hwnd, "Ptr", hRgn, "Int", 1)

    ; 注册鼠标消息（窗口已显示，Hwnd 有效）
    RadialRegisterMsg()

    ; 文字层：文字始终不透明（不受 opacity 影响），单独一层、与圆盘完全重合
    radialTextGui := OverlayTextLayerNew(guiX, guiY, winSize, winSize)

    ; 首次绘制
    RadialDraw()

    ; 登记为已打开浮层（Esc 接管由 Overlay* 统一管理，三种浮层互相独立）
    OverlayPush("radial")

    ; 与其它已打开浮层避让（同屏时不允许重叠；圆盘刚打开，以它为准推开别人）
    OverlayAvoid("radial")

    ; 文字层内容（在避让之后绘制，保证与圆盘最终位置完全一致）
    RadialTextLayerPresent()
}

; ---- 重建 / 刷新圆盘文字层（自动取圆盘当前位置，保证完全重合）----
RadialTextLayerPresent() {
    global radialGui, radialTextGui, radialLayout
    if (!radialGui || !radialTextGui || !radialLayout)
        return
    WinGetPos(&tx, &ty, , , "ahk_id " . radialGui.Hwnd)
    OverlayTextLayerPresent(radialTextGui, tx, ty, radialLayout.winSize, radialLayout.winSize
        , (maskDC, colorDC, w, h) => RadialPaintTexts(maskDC, colorDC))
}

; ---- 布局常量 ----
RadialGetLayout() {
    global radialLayout
    return radialLayout
}

; ---- 虚拟屏幕（所有显示器合并区域）边界：把圆盘限制在可见范围内 ----
; 切勿用 A_ScreenWidth / A_ScreenHeight —— 它们只是**主显示器**的尺寸，
; 在多显示器（例如副屏在左侧、坐标为负）下会把圆盘强行拉回主屏，
; 表现为"一拖动窗口就消失 / 跑到别的地方"。
RadialVirtualBounds() {
    return {x: SysGet(76), y: SysGet(77), w: SysGet(78), h: SysGet(79)}
}

; ---- 注册鼠标消息 ----
RadialRegisterMsg() {
    global radialGui, radialMsgMove, radialMsgDown, radialMsgUp, radialMsgRDown, radialMsgLeave
    hwnd := radialGui.Hwnd
    ; 先注销可能残留的旧回调（OnMessage MaxThreads=0 注销指定回调），避免重复注册累积
    OnMessage(0x0200, RadialOnMouseMove, 0)
    OnMessage(0x0201, RadialOnLButtonDown, 0)
    OnMessage(0x0202, RadialOnLButtonUp, 0)
    OnMessage(0x0204, RadialOnRButtonDown, 0)
    OnMessage(0x02A3, RadialOnMouseLeave, 0)
    ; 注册
    radialMsgMove   := OnMessage(0x0200, RadialOnMouseMove)   ; WM_MOUSEMOVE
    radialMsgDown   := OnMessage(0x0201, RadialOnLButtonDown) ; WM_LBUTTONDOWN
    radialMsgUp     := OnMessage(0x0202, RadialOnLButtonUp)   ; WM_LBUTTONUP
    radialMsgRDown  := OnMessage(0x0204, RadialOnRButtonDown) ; WM_RBUTTONDOWN
    radialMsgLeave  := OnMessage(0x02A3, RadialOnMouseLeave)  ; WM_MOUSELEAVE
    ; 请求鼠标离开通知
    DllCall("TrackMouseEvent", "Ptr", TrackMouseEventStruct(), "Int")
}

; ---- 注销鼠标消息 ----
RadialUnregisterMsg() {
    ; OnMessage 注销：Callback 传原回调函数对象 + MaxThreads=0
    ; （传 "" 或 0 会报错：Parameter #2 requires an Object）
    OnMessage(0x0200, RadialOnMouseMove, 0)
    OnMessage(0x0201, RadialOnLButtonDown, 0)
    OnMessage(0x0202, RadialOnLButtonUp, 0)
    OnMessage(0x0204, RadialOnRButtonDown, 0)
    OnMessage(0x02A3, RadialOnMouseLeave, 0)
}

; ---- TrackMouseEvent 结构（WM_MOUSELEAVE 需要）----
TrackMouseEventStruct() {
    static tme := 0
    if (!tme) {
        tme := Buffer(16)
        NumPut("UInt", 16, tme, 0)           ; cbSize
        NumPut("UInt", 0x00000002, tme, 4)   ; TME_LEAVE
        NumPut("Ptr", 0, tme, 8)             ; hwndTrack（动态填）
    }
    global radialGui
    if (radialGui)
        NumPut("Ptr", radialGui.Hwnd, tme, 8)
    return tme
}

; ---- 绘制菜单（内存 DC 双缓冲）----
RadialDraw() {
    global radialGui, radialHover, radialLayout, radialFontSize
    if (!radialGui || !radialLayout)
        return
    hwnd := radialGui.Hwnd
    L := radialLayout

    hdc := DllCall("GetDC", "Ptr", hwnd, "Ptr")
    if (!hdc)
        return
    memDC := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", L.winSize, "Int", L.winSize, "Ptr")
    oldBmp := DllCall("SelectObject", "Ptr", memDC, "Ptr", hbm, "Ptr")

    ; 背景
    bgFillBrush := BrushSolid("2D2D3D")
    DllCall("FillRect", "Ptr", memDC, "Ptr", RectStruct(0, 0, L.winSize, L.winSize), "Ptr", bgFillBrush)
    DllCall("DeleteObject", "Ptr", bgFillBrush)

    cx := L.cx
    cy := L.cy
    n := L.n
    startRad := L.startRad
    angleStep := 2 * 3.141592653589793 / n

    ; 颜色三态：无悬停=全部常态；悬停扇区=该区高亮+其余暗；悬停圆心=全部扇区暗+圆心高亮
    COLOR_NORMAL := "3A4455"     ; 扇区常态
    COLOR_DIM := "242B38"        ; 扇区暗态（他区被悬停时）
    COLOR_HILITE := "4A90D9"     ; 高亮（悬停区）
    CK_NORMAL := "3D3D4D"        ; 圆心常态
    CK_DIM := "2A2A38"           ; 圆心暗态（悬停扇区时）
    CK_HILITE := "4A90D9"        ; 圆心高亮（悬停圆心时）

    ; 画环形扇区（FillRgn 用构建好的多边形区域，绘制位置与命中检测完全一致）
    if (L.HasOwnProp("sectorRgns") && L.sectorRgns.Length >= n) {
        Loop n {
            i := A_Index
            ; 三态着色：无悬停=全部常态；有悬停=悬停区域高亮，其余所有区域变暗
            if (radialHover = 0) {
                bgColor := COLOR_NORMAL
            } else if (radialHover = i) {
                bgColor := COLOR_HILITE
            } else {
                bgColor := COLOR_DIM
            }
            hRgn := L.sectorRgns[i]
            if (!hRgn)
                continue
            brush := BrushSolid(bgColor)
            DllCall("FillRgn", "Ptr", memDC, "Ptr", hRgn, "Ptr", brush)
            DllCall("DeleteObject", "Ptr", brush)
        }
    }

    ; 圆心圆（三态着色，FillRgn 用圆心区域；立即重建/复用 L.centerRgn）
    if (radialHover = -1)
        ckColor := CK_HILITE
    else if (radialHover > 0)
        ckColor := CK_DIM
    else
        ckColor := CK_NORMAL
    centerBrush := BrushSolid(ckColor)
    if (L.centerRgn)
        DllCall("FillRgn", "Ptr", memDC, "Ptr", L.centerRgn, "Ptr", centerBrush)
    DllCall("DeleteObject", "Ptr", centerBrush)

    ; 细线分隔扇区
    pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", 0x333333, "Ptr")
    oldPen := DllCall("SelectObject", "Ptr", memDC, "Ptr", pen, "Ptr")
    Loop n {
        i := A_Index
        a := startRad + (i - 1) * angleStep
        DllCall("MoveToEx", "Ptr", memDC, "Int", cx + Round(L.innerR * Cos(a)), "Int", cy + Round(L.innerR * Sin(a)), "Ptr", 0)
        DllCall("LineTo", "Ptr", memDC, "Int", cx + Round(L.outerR * Cos(a)), "Int", cy + Round(L.outerR * Sin(a)))
    }
    DllCall("SelectObject", "Ptr", memDC, "Ptr", oldPen, "Ptr")
    DllCall("DeleteObject", "Ptr", pen)

    ; 文字不在这里画：文字统一由独立的文字层绘制（见 RadialPaintTexts / 10c-3），
    ; 这样文字不会跟随主窗口的透明度变淡。

    ; 外环描边
    outerBrush := BrushSolid("2A2A38")
    outerRgn := DllCall("CreateEllipticRgn", "Int", cx - L.outerR, "Int", cy - L.outerR, "Int", cx + L.outerR, "Int", cy + L.outerR, "Ptr")
    DllCall("FrameRgn", "Ptr", memDC, "Ptr", outerRgn, "Ptr", outerBrush, "Int", 1, "Int", 1)
    DllCall("DeleteObject", "Ptr", outerRgn)
    DllCall("DeleteObject", "Ptr", outerBrush)

    ; 一次 BitBlt 到位
    DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", L.winSize, "Int", L.winSize, "Ptr", memDC, "Int", 0, "Int", 0, "UInt", 0x00CC0020)

    ; 清理
    DllCall("SelectObject", "Ptr", memDC, "Ptr", oldBmp, "Ptr")
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", memDC)
    DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
}

; ---- 构建扇区多边形区域 + 圆心区域（存入 radialLayout；绘制与命中共用）----
; 每个扇区 = 环形多边形：外弧细分为 RGN_SEG 段 + 内弧反向细分闭合。
; 用同一个区域句柄 FillRgn（绘制）与 PtInRegion（命中）→ 位置绝对一致，无角度歧义。
RadialBuildRgns() {
    global radialLayout
    L := radialLayout
    cx := L.cx
    cy := L.cy
    n := L.n
    startRad := L.startRad
    angleStep := 2 * 3.141592653589793 / n
    RGN_SEG := 24                     ; 每扇区弧细分段数（越大越圆滑）
    rgns := []

    Loop n {
        i := A_Index
        a0 := startRad + (i - 1) * angleStep
        a1 := a0 + angleStep
        ; 收集多边形顶点：外弧 a0→a1，内弧 a1→a0（反向闭合）
        pts := []
        ; 外弧
        Loop RGN_SEG + 1 {
            t := a0 + (a1 - a0) * (A_Index - 1) / RGN_SEG
            pts.Push(cx + Round(L.outerR * Cos(t)))
            pts.Push(cy + Round(L.outerR * Sin(t)))
        }
        ; 内弧（从 a1 回到 a0，去掉重复的 a1 外顶点起点？保留闭合）
        Loop RGN_SEG + 1 {
            t := a1 - (a1 - a0) * (A_Index - 1) / RGN_SEG
            pts.Push(cx + Round(L.innerR * Cos(t)))
            pts.Push(cy + Round(L.innerR * Sin(t)))
        }
        ; 构建 POINT 数组（x,y 交替）
        cnt := pts.Length // 2
        buf := Buffer(cnt * 8)
        Loop cnt {
            NumPut("Int", pts[(A_Index - 1) * 2 + 1], buf, (A_Index - 1) * 8)
            NumPut("Int", pts[(A_Index - 1) * 2 + 2], buf, (A_Index - 1) * 8 + 4)
        }
        ; WINDING 填充模式（=2），复杂多边形正确填充
        hRgn := DllCall("CreatePolygonRgn", "Ptr", buf, "Int", cnt, "Int", 2, "Ptr")
        rgns.Push(hRgn)
    }

    ; 圆心区域：真正的圆
    hCenter := DllCall("CreateEllipticRgn"
        , "Int", cx - L.innerR, "Int", cy - L.innerR
        , "Int", cx + L.innerR, "Int", cy + L.innerR, "Ptr")

    ; 释放旧的
    if (L.HasOwnProp("centerRgn") && L.centerRgn) {
        DllCall("DeleteObject", "Ptr", L.centerRgn)
    }
    if (L.sectorRgns) {
        for old in L.sectorRgns
            DllCall("DeleteObject", "Ptr", old)
    }

    L.sectorRgns := rgns
    L.centerRgn := hCenter
}

; ---- 释放扇区/圆心区域 ----
RadialFreeRgns() {
    global radialLayout
    if (!radialLayout)
        return
    L := radialLayout
    if (L.HasOwnProp("centerRgn") && L.centerRgn) {
        DllCall("DeleteObject", "Ptr", L.centerRgn)
        L.centerRgn := 0
    }
    if (L.HasOwnProp("sectorRgns") && L.sectorRgns) {
        for r in L.sectorRgns {
            if (r)
                DllCall("DeleteObject", "Ptr", r)
        }
        L.sectorRgns := []
    }
}

; ---- 颜色： "RRGGBB" → 0xBBGGRR（COLORREF）----
BrushColorVal(rgbHex) {
    r := Integer("0x" . SubStr(rgbHex, 1, 2))
    g := Integer("0x" . SubStr(rgbHex, 3, 2))
    b := Integer("0x" . SubStr(rgbHex, 5, 2))
    return r | (g << 8) | (b << 16)
}

; ---- 实心画刷 ----
BrushSolid(rgbHex) {
    return DllCall("CreateSolidBrush", "UInt", BrushColorVal(rgbHex), "Ptr")
}

; ---- RECT 结构 ----
RectStruct(x, y, w, h) {
    static rect := 0
    if (!rect)
        rect := Buffer(16)
    NumPut("Int", x, rect, 0)
    NumPut("Int", y, rect, 4)
    NumPut("Int", w, rect, 8)
    NumPut("Int", h, rect, 12)
    return rect
}

; ---- 创建 GDI 字体（escapement：文字旋转角度，单位 0.1 度；0=水平）----
RadialCreateFont(sizePt, face, escapement := 0) {
    ; 点 → 像素（96 DPI）
    px := Round(sizePt * 96 / 72)
    return DllCall("CreateFontW"
        , "Int", -px, "Int", 0, "Int", escapement, "Int", escapement
        , "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0
        , "UInt", 1, "UInt", 0, "UInt", 0
        ; 品质固定用 ANTIALIASED_QUALITY(4) = 灰度抗锯齿：本项目的文字现在画在
        ; 独立的透明文字层上（见 10c-3），灰度抗锯齿的像素 = 覆盖度 × 字色，
        ; 可直接当作"预乘 ARGB"用；ClearType 是次像素抗锯齿，会破坏这个前提。
        , "UInt", 4, "UInt", 0   ; ANTIALIASED_QUALITY | DEFAULT_PITCH
        , "Str", face, "Ptr")
}

; ---- 测量文字像素宽高（离屏 DC + 指定字号字体）----
; 用于径向菜单的紧凑自适应布局：按文字实际渲染尺寸算半径与截断。
RadialMeasureText(text, sizePt) {
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    if (!hdc)
        return {w: 0, h: 0}
    font := RadialCreateFont(sizePt, "Microsoft YaHei", 0)
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", font, "Ptr")
    sz := Buffer(8)
    DllCall("GetTextExtentPoint32W", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", sz)
    w := NumGet(sz, 0, "Int")
    h := NumGet(sz, 4, "Int")
    DllCall("SelectObject", "Ptr", hdc, "Ptr", old, "Ptr")
    DllCall("DeleteObject", "Ptr", font)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return {w: w, h: h}
}

; ---- 按最大像素宽度截断文字（至少 2 字、硬上限 hardMax 字，超出追加省略号）----
; 与"按字数估算"相比，此处按字体实际渲染宽度收缩，更精确也更紧凑。
RadialTruncateToWidth(text, sizePt, maxWidth, hardMax := 8) {
    if (text = "")
        return text
    ; 先按硬上限截断（截断后含省略号不超过 hardMax 个字符）
    if (StrLen(text) > hardMax)
        text := SubStr(text, 1, hardMax - 1) "…"
    if (RadialMeasureText(text, sizePt).w <= maxWidth)
        return text
    ; 逐步缩短到「正文 + 省略号」宽度放得下（至少保留 2 字）
    base := SubStr(text, 1, StrLen(text) - (SubStr(text, -1) = "…" ? 1 : 0))
    n := StrLen(base)
    while (n > 2) {
        n--
        cand := SubStr(base, 1, n) "…"
        if (RadialMeasureText(cand, sizePt).w <= maxWidth)
            return cand
    }
    return SubStr(base, 1, Min(2, StrLen(base)))
}

; ---- 绘制旋转文字（放射性排布）----
; escapementTenths：GDI 旋转角度（0.1 度单位，正=逆时针/数学角）。
; 输入 (cx,cy) 视为目标视觉中心：文字包围盒中心应落在按钮中心，
; 因此需先按字体 ascent/descent 把 TextOut 的基线锚点沿文字法线方向补偿。
; colorDC 画彩色字身；maskDC 画白色"字身 + 黑边"，其覆盖度作为最终 alpha。
RadialDrawRotatedText(maskDC, colorDC, text, cx, cy, escapementTenths) {
    global radialFontSize
    if (text = "")
        return
    font := RadialCreateFont(radialFontSize, "Microsoft YaHei", escapementTenths)

    ; 先按字体 ascent/descent 把 TextOut 的基线锚点沿文字法线方向补偿（与改造前一致）
    oldFont := DllCall("SelectObject", "Ptr", colorDC, "Ptr", font, "Ptr")
    tm := Buffer(60, 0)
    DllCall("GetTextMetricsW", "Ptr", colorDC, "Ptr", tm)
    ascent := NumGet(tm, 4, "Int")
    descent := NumGet(tm, 8, "Int")
    shift := (ascent - descent) / 2
    screenDeg := -escapementTenths / 10.0
    theta := screenDeg * 3.141592653589793 / 180.0
    baseX := Round(cx + (-Sin(theta)) * shift)
    baseY := Round(cy + Cos(theta) * shift)

    ; 彩色层：字身只画一次
    DllCall("SetBkMode", "Ptr", colorDC, "Int", 1)   ; TRANSPARENT
    DllCall("SetTextAlign", "Ptr", colorDC, "UInt", 0x0006 | 0x0008, "UInt")   ; TA_CENTER | TA_BASELINE
    DllCall("SetTextColor", "Ptr", colorDC, "UInt", OverlayTextColor())
    DllCall("TextOutW", "Ptr", colorDC, "Int", baseX, "Int", baseY, "Str", text, "Int", StrLen(text))
    DllCall("SelectObject", "Ptr", colorDC, "Ptr", oldFont, "Ptr")

    ; 掩码层：先画黑边偏移、最后画字身（保证字身覆盖度不会被偏移的低覆盖盖掉）
    oldFont := DllCall("SelectObject", "Ptr", maskDC, "Ptr", font, "Ptr")
    DllCall("SetBkMode", "Ptr", maskDC, "Int", 1)
    DllCall("SetTextAlign", "Ptr", maskDC, "UInt", 0x0006 | 0x0008, "UInt")
    DllCall("SetTextColor", "Ptr", maskDC, "UInt", 0xFFFFFF)
    for off in OverlayTextOffsets(OverlayTextOutlineWidth())
        DllCall("TextOutW", "Ptr", maskDC, "Int", baseX + off.x, "Int", baseY + off.y, "Str", text, "Int", StrLen(text))
    DllCall("TextOutW", "Ptr", maskDC, "Int", baseX, "Int", baseY, "Str", text, "Int", StrLen(text))

    DllCall("SelectObject", "Ptr", maskDC, "Ptr", oldFont, "Ptr")
    DllCall("DeleteObject", "Ptr", font)
}

; ---- 绘制文字（水平垂直双居中，圆心文字用）----
; 圆心文字：colorDC 画彩色字身；maskDC 画白色"字身 + 黑边"（决定 alpha）。
RadialDrawText(maskDC, colorDC, text, cx, cy, maxR, bgColor, isCenter) {
    global radialFontSize
    if (text = "")
        return
    font := RadialCreateFont(radialFontSize, "Microsoft YaHei")
    oldFont := DllCall("SelectObject", "Ptr", colorDC, "Ptr", font, "Ptr")
    sz := Buffer(8)
    DllCall("GetTextExtentPoint32W", "Ptr", colorDC, "Str", text, "Int", StrLen(text), "Ptr", sz)
    tw := NumGet(sz, 0, "Int")
    th := NumGet(sz, 4, "Int")
    l := cx - tw // 2
    t := cy - th // 2
    r := cx + tw // 2
    b := cy + th // 2

    ; 彩色层：字身
    OverlayDrawCenteredText(colorDC, text, l, t, r, b, OverlayTextColor())
    DllCall("SelectObject", "Ptr", colorDC, "Ptr", oldFont, "Ptr")

    ; 掩码层：先画黑边偏移、最后画字身
    oldFont := DllCall("SelectObject", "Ptr", maskDC, "Ptr", font, "Ptr")
    for off in OverlayTextOffsets(OverlayTextOutlineWidth())
        OverlayDrawCenteredText(maskDC, text, l + off.x, t + off.y, r + off.x, b + off.y, 0xFFFFFF)
    OverlayDrawCenteredText(maskDC, text, l, t, r, b, 0xFFFFFF)

    DllCall("SelectObject", "Ptr", maskDC, "Ptr", oldFont, "Ptr")
    DllCall("DeleteObject", "Ptr", font)
}

; ---- 文字层内容：圆心文字 + 各扇区放射性文字（彩色字身 + 黑色描边，画在两块纯黑底上）----
; 与改造前 RadialDraw 里的文字绘制逐行等价，只是改为画到文字层的 DC 上。
RadialPaintTexts(maskDC, colorDC) {
    global radialLayout, radialMenuItems
    if (!radialLayout)
        return
    L := radialLayout
    cx := L.cx
    cy := L.cy
    n := L.n
    startRad := L.startRad
    angleStep := 2 * 3.141592653589793 / n

    ; 圆心文字
    RadialDrawText(maskDC, colorDC, L.centerText, cx, cy, L.innerR, "3D3D4D", true)

    ; 扇区文字（放射性排布：文字沿径向，正立可读，左右横排、上下竖排、斜侧沿径向外/内）
    Loop n {
        i := A_Index
        if (i > radialMenuItems.Length)
            break
        item := radialMenuItems[i]
        aMid := startRad + (i - 0.5) * angleStep
        rMid := (L.innerR + L.outerR) / 2
        tx := cx + Round(rMid * Cos(aMid))
        ty := cy + Round(rMid * Sin(aMid))
        ; 屏幕视觉角（度，与锚点/命中一致：0=右, +90=下, -90=上）
        deg := aMid * 180 / 3.141592653589793
        ; 归一化到 (-180, 180]
        while (deg > 180)
            deg -= 360
        while (deg <= -180)
            deg += 360
        ; 文字基线目标视觉角：右半圆沿径向朝外；左半圆翻转 180° 保持正立（正左=水平）
        escVis := 0
        if (deg >= -90 && deg <= 90) {
            escVis := deg                 ; 右半圆
        } else {
            escVis := deg - 180           ; 左半圆翻转
            if (escVis < -180)            ; 规整（deg≈-180 时 -> -360→0）
                escVis += 360
        }
        ; 屏幕视觉角 → GDI 数学角（y 向上逆时针正；屏幕 y 向下 → 取负）
        gdiEsc := Round(-escVis * 10)
        ; 显示文本已在布局阶段按环宽实测截断并缓存（见 RadialBuildMenu）
        RadialDrawRotatedText(maskDC, colorDC, item.shownName, tx, ty, gdiEsc)
    }
}

; ---- 命中检测：返回 0=无，-1=圆心，i=扇区索引(1基) ----（基于区域句柄 PtInRegion，与绘制完全一致）
RadialHitTest(mx, my) {
    global radialGui, radialLayout, radialMenuItems
    if (!radialGui || !radialLayout)
        return 0
    WinGetPos(&wx, &wy, , , "ahk_id " . radialGui.Hwnd)
    L := radialLayout
    ; 转窗口客户区坐标
    lx := mx - wx
    ly := my - wy
    ; 圆心
    if (L.HasOwnProp("centerRgn") && L.centerRgn
        && DllCall("PtInRegion", "Ptr", L.centerRgn, "Int", lx, "Int", ly)) {
        return -1
    }
    ; 扇区（按序检测，区域不重叠；区域数组未就绪/为空时直接返回 0 防御越界）
    if (L.HasOwnProp("sectorRgns") && L.sectorRgns.Length >= L.n) {
        Loop L.n {
            hRgn := L.sectorRgns[A_Index]
            if (hRgn && DllCall("PtInRegion", "Ptr", hRgn, "Int", lx, "Int", ly)) {
                ; 空位扇区（disabled）：视为未命中 → 禁止高亮、点击无效
                if (A_Index <= radialMenuItems.Length && radialMenuItems[A_Index].kind = "disabled")
                    return 0
                return A_Index
            }
        }
    }
    return 0
}

; ---- ATan2 ----
ATan2(y, x) {
    if (x > 0)
        return ATan(y / x)
    if (x < 0)
        return ATan(y / x) + 3.141592653589793
    if (y >= 0)
        return 3.141592653589793 / 2
    return -3.141592653589793 / 2
}

; ---- 鼠标移动：更新悬停并重绘；圆心按下期间改为「拖拽判定 / 移动圆盘」----
; 返回空值放行消息（悬停检测不吞 WM_MOUSEMOVE，避免影响其它窗口/控件）
RadialOnMouseMove(wParam, lParam, msg, hwnd) {
    global radialGui, radialTextGui, radialHover, radialCenterX, radialCenterY
    global radialDragPending, radialDragging, radialDragMoved
    global radialDragStartX, radialDragStartY, radialDragWinX, radialDragWinY
    if (!radialGui || hwnd != radialGui.Hwnd)
        return
    OverlayTouch("radial")       ; 鼠标在圆盘上移动（含拖拽）也算"操作过"，Esc 优先关它

    ; --- 圆心按下期间：只判定拖拽并移动圆盘，绝不附加任何其它动作 ---
    if (radialDragPending || radialDragging) {
        ; 用 GetCursorPos 取屏幕坐标：窗口移动后 lParam 的客户区坐标会变化，
        ; 用「鼠标屏幕坐标 − 按下时的鼠标屏幕坐标」算位移，绝对稳定不抖动。
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        dx := NumGet(pt, 0, "Int") - radialDragStartX
        dy := NumGet(pt, 4, "Int") - radialDragStartY
        ; 位移超过阈值才认定为拖拽（否则抬起时按点击处理）
        if (!radialDragging && (Abs(dx) > 3 || Abs(dy) > 3)) {
            radialDragging := true
            radialDragMoved := true
            DebugLog("[radial] 判定为拖拽：位移=" . dx . "," . dy)
        }
        if (radialDragging) {
            WinGetPos(, , &ww, &wh, "ahk_id " . hwnd)
            ; 位移与窗口位置 1:1 对应：窗口位置 = 按下时的位置 + 鼠标位移。
            ; 只在**虚拟屏幕**（全部显示器合并区域）内夹取，避免圆盘被拖到所有屏幕之外；
            ; 绝不做"拉回主屏"之类的吸附 —— 多显示器下那会导致窗口突然跑到别处（看似消失）。
            vb := RadialVirtualBounds()
            nx := Max(vb.x, Min(radialDragWinX + dx, vb.x + vb.w - ww))
            ny := Max(vb.y, Min(radialDragWinY + dy, vb.y + vb.h - wh))
            radialGui.Move(nx, ny)
            ; 文字层跟着圆盘一起移动
            OverlayTextLayerMove(radialTextGui, nx, ny)
            ; 同步菜单中心：切层重建时仍在该位置弹出
            radialCenterX := nx + ww // 2
            radialCenterY := ny + wh // 2
            ; 拖动中以圆盘为准，把它压住的其它浮层推开
            OverlayAvoid("radial")
        }
        DllCall("TrackMouseEvent", "Ptr", TrackMouseEventStruct(), "Int")
        return
    }

    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    ; lParam 客户区坐标可能为负（鼠标被捕获时移出窗口），补 16 位有符号还原
    if (x > 32767)
        x -= 65536
    if (y > 32767)
        y -= 65536
    WinGetPos(&wx, &wy, , , "ahk_id " . hwnd)
    hit := RadialHitTest(wx + x, wy + y)
    if (hit != radialHover) {
        radialHover := hit
        RadialDraw()
    }
    ; 请求持续追踪
    DllCall("TrackMouseEvent", "Ptr", TrackMouseEventStruct(), "Int")
    return
}

; ---- 鼠标离开：清除悬停 ----
RadialOnMouseLeave(wParam, lParam, msg, hwnd) {
    global radialGui, radialHover, radialDragPending, radialDragging
    if (!radialGui || hwnd != radialGui.Hwnd)
        return
    ; 拖拽中不做悬停处理（鼠标被捕获，离开通知不代表真的移出）
    if (radialDragPending || radialDragging)
        return
    if (radialHover != 0) {
        radialHover := 0
        RadialDraw()
    }
    return
}

; ---- 左键按下 ----
; 扇区：立即执行对应动作；圆心：先只做「可能是点击」的记录，抬起时再判定
; 注意：OnMessage 回调返回「空值」（return / return ""）才放行消息让其正常流转；
; 返回整数（含 0）会被当作已回复而吞掉消息。径向菜单未打开或不属于它时务必返回空。
RadialOnLButtonDown(wParam, lParam, msg, hwnd) {
    global radialGui, radialTextGui, radialDragPending, radialDragging, radialDragMoved
    global radialDragStartX, radialDragStartY, radialDragWinX, radialDragWinY
    if (!radialGui || hwnd != radialGui.Hwnd)
        return
    OverlayTouch("radial")       ; 在圆盘上按下（含点空位扇区的无效点击）也算"操作过"
    OverlayTextLayerRaise(radialTextGui)   ; 点击会把圆盘提到最上层 → 立刻把文字层压回它上面
    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    if (x > 32767)
        x -= 65536
    if (y > 32767)
        y -= 65536
    WinGetPos(&wx, &wy, , , "ahk_id " . hwnd)
    hit := RadialHitTest(wx + x, wy + y)
    if (hit = -1) {
        ; 圆心：记录起点并捕获鼠标；是"点击"还是"拖拽"等到抬起时按位移判定
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        radialDragStartX := NumGet(pt, 0, "Int")
        radialDragStartY := NumGet(pt, 4, "Int")
        radialDragWinX := wx
        radialDragWinY := wy
        radialDragPending := true
        radialDragging := false
        radialDragMoved := false
        DebugLog("[radial] 圆心按下：鼠标=" . radialDragStartX . "," . radialDragStartY . " 窗口=" . wx . "," . wy)
        ; SetCapture：拖拽时指针移出圆盘也能持续收到 WM_MOUSEMOVE，抬起时释放
        DllCall("SetCapture", "Ptr", hwnd, "Ptr")
    } else if (hit > 0) {
        ; 扇区点击：执行功能（菜单保持打开，见 RadialOnItemClick）
        RadialOnItemClick(hit)
    }
    return
}

; ---- 左键抬起：圆心区域按位移判定「点击（返回上一层/关闭）」或「拖拽（移动圆盘）」----
; 拖拽分支**只结束拖拽**，不做任何其它事情（不切层、不关闭、不改焦点、不改激活窗口）。
RadialOnLButtonUp(wParam, lParam, msg, hwnd) {
    global radialGui, radialDragPending, radialDragging, radialDragMoved, radialLevel
    if (!radialGui || hwnd != radialGui.Hwnd)
        return
    OverlayTouch("radial")       ; 抬起同样算"操作过"（拖动过、点空位的抬起都算）
    if (!radialDragPending && !radialDragging)
        return
    radialDragPending := false
    radialDragging := false
    DllCall("ReleaseCapture")
    if (radialDragMoved) {
        ; 拖动过 → 只移动了圆盘，不触发圆心点击（也不做任何其它动作）
        radialDragMoved := false
        DebugLog("[radial] 拖拽结束：仅移动圆盘，不触发圆心点击")
        DllCall("TrackMouseEvent", "Ptr", TrackMouseEventStruct(), "Int")
        return
    }
    radialDragMoved := false
    ; 未拖动 → 视为圆心点击
    DebugLog("[radial] 圆心点击：当前层级=" . radialLevel)
    RadialOnCenterClick()
    return
}

; ---- 右键点击：关闭 ----
; 菜单打开且点击在菜单上 → 关闭并吞掉消息（防止穿透到下层窗口产生右键菜单）；
; 菜单未打开/不属于它 → 返回空放行
RadialOnRButtonDown(wParam, lParam, msg, hwnd) {
    global radialGui
    if (radialGui && hwnd = radialGui.Hwnd) {
        RadialClose()
        return 0
    }
    return
}

; ---- 触发：菜单未打开则弹出第一级；已打开则关闭（同一热键开/关切换）----
RadialShow(*) {
    global radialGroups, radialGui, radialLevel, radialCurrentGroup, radialFocusWin, radialCenterX, radialCenterY

    ; 菜单已打开 → 同一个触发键关闭菜单
    if (radialGui) {
        RadialClose()
        return
    }

    if (radialGroups.Length = 0)
        return

    ; 保存焦点窗口
    radialFocusWin := WinExist("A")

    ; 确保鼠标坐标为屏幕坐标（热键线程默认是"客户区坐标"，会导致非全屏窗口下弹出偏移）
    CoordMode("Mouse", "Screen")
    ; 获取鼠标位置作为菜单中心
    MouseGetPos(&mx, &my)
    radialCenterX := mx
    radialCenterY := my

    ; 弹出第一层【常用】（第 1 个周边为【快捷菜单】，其后为高频常用项）
    radialLevel := 1
    radialCurrentGroup := 0
    RadialBuildMenu()
}

; ---- 关闭菜单 ----
RadialClose() {
    global radialGui, radialTextGui, radialLevel, radialCurrentGroup, radialFocusWin
    global radialDragPending, radialDragging, radialDragMoved

    ; 清理拖拽状态并释放鼠标捕获（拖拽中途关闭时不留后遗症）
    radialDragPending := false
    radialDragging := false
    radialDragMoved := false
    DllCall("ReleaseCapture")

    if (radialGui) {
        RadialUnregisterMsg()
        RadialFreeRgns()
        radialGui.Destroy()
        radialGui := 0
    }
    OverlayTextLayerDestroy(radialTextGui)
    radialTextGui := 0
    radialLevel := 0
    radialCurrentGroup := 0
    ; 圆盘窗口本身不抢焦点，关闭时不应无条件把前台强拉回旧窗口，
    ; 否则用户若已主动切到其它窗口，会感知为"焦点乱跳 / 系统自己在操作"。
    radialFocusWin := 0
    ; 注销浮层登记（只影响自己，屏幕小键盘不受影响）
    OverlayRemove("radial")
}

; ---- 恢复焦点到触发菜单前的窗口（圆盘自身不应持有焦点）----
RadialRestoreFocus() {
    ; 圆盘窗口带 WS_EX_NOACTIVATE，正常情况下不会夺走前台；
    ; 当前策略要求菜单项始终作用于点击当下的前台窗口，故这里不再主动切焦点。
    return
}

; ---- 扇区点击处理（按菜单项类型分发）----
RadialOnItemClick(idx) {
    global radialLevel, radialCurrentGroup, radialGroups, radialMenuItems

    if (idx < 1 || idx > radialMenuItems.Length)
        return
    it := radialMenuItems[idx]

    if (it.kind = "shortcut") {
        ; 第一层【快捷菜单】→ 第二层（分组列表）
        radialLevel := 2
        radialCurrentGroup := 0
        RadialBuildMenu()
    } else if (it.kind = "group") {
        ; 第二层某分组 → 第三层（该组菜单项）
        radialLevel := 3
        radialCurrentGroup := it.gi
        RadialBuildMenu()
    } else if (it.kind = "exec") {
        ; 执行对应菜单项的快捷键（并按配置项统计 +1）；菜单保持打开，不关闭，
        ; 便于连续执行多个功能（关闭请用同一触发键 / 右键 / 第一层圆心）
        g := radialGroups[it.gi]
        if (it.ii >= 1 && it.ii <= g.items.Length) {
            item := g.items[it.ii]
            RadialBumpStat(g.id, item._num)
            RadialExecAction(item)
        }
    }
    ; kind = "disabled"（空位）：点击无效，直接返回
}

; ---- 圆心点击处理 ----
RadialOnCenterClick() {
    global radialLevel, radialCurrentGroup

    if (radialLevel = 1) {
        ; 第一层中心【常用】→ 关闭菜单
        RadialClose()
    } else if (radialLevel = 2) {
        ; 第二层中心【快捷菜单】→ 返回第一层
        radialLevel := 1
        radialCurrentGroup := 0
        RadialBuildMenu()
    } else if (radialLevel = 3) {
        ; 第三层中心【<组名>】→ 返回第二层
        radialLevel := 2
        radialCurrentGroup := 0
        RadialBuildMenu()
    }
}

; ---- 取某菜单项的动作文本（越界返回空串），供"大小写状态"判断用 ----
RadialItemAction(gi, ii) {
    global radialGroups
    if (gi < 1 || gi > radialGroups.Length)
        return ""
    g := radialGroups[gi]
    if (ii < 1 || ii > g.items.Length)
        return ""
    return g.items[ii].actionValue
}

; ---- 菜单项显示名：大小写状态生效时，动作是单个 a-z 字母的菜单项，名字也一起变大写 ----
RadialCaseShownName(name, action) {
    return OverlayCaseTransform("radial", name, action).label
}

; ---- 执行一个菜单项的动作：统一走浮层动作层（与四块小键盘同一套）----
RadialExecAction(item) {
    global radialFocusWin
    if (!IsObject(item) || !item.HasOwnProp("actionType") || !item.HasOwnProp("actionValue"))
        return false
    return OverlayActionExecute({type: item.actionType, value: item.actionValue}, "radial", radialFocusWin)
}



; ---- 激活本次要执行快捷键的目标前台窗口，并确认它真的成为前台 ----
; 若目标窗口已不存在、最小化、或系统前台锁导致激活失败，则放弃发送快捷键，
; 避免把系统级快捷键误发给当前其它窗口或系统壳层。
RadialActivateFocusWin(targetWin, timeoutMs := 400) {
    if (!targetWin)
        return false
    if (!WinExist("ahk_id " . targetWin))
        return false

    cur := WinExist("A")
    if (cur != targetWin) {
        try WinActivate("ahk_id " . targetWin)
        deadline := A_TickCount + timeoutMs
        while (A_TickCount < deadline) {
            if (WinExist("A") = targetWin)
                return true
            Sleep(10)
        }
    }
    return (WinExist("A") = targetWin)
}

; ---- 等待物理修饰键释放后再发送快捷键 ----
; 目的是避免圆盘触发过程或用户残留按键与待发送快捷键叠加，误形成更危险的系统组合键。
RadialWaitModifiersReleased(timeoutMs := 400) {
    deadline := A_TickCount + timeoutMs
    while (A_TickCount < deadline) {
        if (!GetKeyState("Ctrl", "P")
            && !GetKeyState("Shift", "P")
            && !GetKeyState("Alt", "P")
            && !GetKeyState("LWin", "P")
            && !GetKeyState("RWin", "P")) {
            return true
        }
        Sleep(10)
    }
    return (!GetKeyState("Ctrl", "P")
        && !GetKeyState("Shift", "P")
        && !GetKeyState("Alt", "P")
        && !GetKeyState("LWin", "P")
        && !GetKeyState("RWin", "P"))
}

; ============================================================================
; 10b. 径向菜单执行次数统计（menu_stats.ini，独立文件）
;      每执行一次菜单功能，就按「配置项标识」radial.<组标识>.<编号> 为键把计数 +1
;      并实时写入文件（如 radial.base.1 对应 [radial.base] 下编号 1 的那一项）；
;      文件不存在时自动创建。可用任意文本编辑器查看各菜单项的使用次数，
;      与 config.ini 的 [radial.*] 子节一一对应（改快捷键/改功能名不影响统计）。
; ============================================================================

; ---- 统计文件初始化：不存在则创建（写入说明头；IniWrite 会保留该注释）----
RadialStatsInit() {
    global radialStatsFile
    if FileExist(radialStatsFile)
        return
    try {
        FileAppend("; SharpKnife —— 径向菜单（快捷菜单）执行次数统计`r`n"
            . "; 键 = 配置项，与 config.ini 的 [radial.*] 一一对应：radial.<组标识>.<编号>`r`n"
            . "; 例：radial.base.1 表示 [radial.base] 下编号为 1 的那一项（改快捷键不影响其统计）`r`n"
            . "; 自动维护：每执行一次即 +1 并实时写入；删除本文件即重新开始统计`r`n"
            . "[stats]`r`n", radialStatsFile, "UTF-16")
    } catch Error as e {
        DebugLog("[radial] 统计文件创建失败：" . e.Message)
    }
}

; ---- 统计键转义：INI 键不能含 '='（会被当作键值分隔符），转义为 %3D ----
RadialStatKey(rawKey) {
    return StrReplace(Trim(rawKey), "=", "%3D")
}

; ---- 计数 +1 并实时写入 ----
; 键 = 配置项标识 radial.<组标识>.<编号>（如 radial.base.1），与 [radial.xxx] 子节一一对应；
; 某配置项此前未统计过则从 0 开始，首次记为 1。
RadialBumpStat(gid, num) {
    global radialStatsFile
    key := RadialStatKey("radial." . gid . "." . num)
    cur := 0
    try {
        cur := Integer(IniRead(radialStatsFile, "stats", key, 0))
    } catch {
        cur := 0
    }
    try {
        IniWrite(cur + 1, radialStatsFile, "stats", key)
    } catch Error as e {
        DebugLog("[radial] 统计写入失败：" . e.Message)
    }
}

; ---- 取执行次数最高的前 maxN 个菜单项（供第一层【常用】的周边使用）----
; 逐项查询 menu_stats.ini（只查 config.ini 中现存的配置项，忽略已删除项）；
; 返回 [{gi, ii, name, cnt}]，按次数降序（同次数保持配置顺序），仅含次数 > 0 的项。
; ---- 未隐藏的分组（第一层/第二层都按它过滤；隐藏分组不出现在圆盘菜单里）----
RadialVisibleGroups() {
    global radialGroups
    out := []
    for gi, g in radialGroups {
        if (!g.hidden)
            out.Push({gi: gi, g: g})
    }
    return out
}

RadialTopFrequent(maxN := 6) {
    global radialGroups, radialStatsFile
    list := []
    for gi, g in radialGroups {
        if (g.hidden)                      ; 隐藏的分组：它的项也不进【常用】
            continue
        for ii, it in g.items {
            cnt := 0
            try {
                cnt := Integer(IniRead(radialStatsFile, "stats", RadialStatKey("radial." . g.id . "." . it._num), 0))
            } catch {
                cnt := 0
            }
            if (cnt > 0)
                list.Push({gi: gi, ii: ii, name: it.name, cnt: cnt})
        }
    }
    ; 按次数降序的稳定插入排序：严格大于才前插 → 同次数保持原配置顺序
    sorted := []
    for x in list {
        inserted := false
        for i, s in sorted {
            if (x.cnt > s.cnt) {
                sorted.InsertAt(i, x)
                inserted := true
                break
            }
        }
        if (!inserted)
            sorted.Push(x)
    }
    while (sorted.Length > maxN)
        sorted.Pop()
    return sorted
}

; ============================================================================
; 10c. 浮层公共状态（Esc 接管）—— 径向菜单与四块屏幕小键盘共用
;      五个浮层（径向菜单 / 方向 / 数字 / 符号 / 字母小键盘）**互相独立**：各自的触发键只管自己，
;      打开或关闭其中一个都不会联动关闭另外几个，五者可以同时显示。
;      它们都不获得键盘焦点（WS_EX_NOACTIVATE），因此 Esc 关闭由同一套全局热键接管：
;      只要有浮层打开就注册 Esc，按下 Esc 关闭「最近操作过的那个」——打开面板、
;      在面板上移动鼠标、点击面板（含点空位等无效点击）都算一次"操作"；全部关闭后立即注销。
; ============================================================================

; ---- 查浮层在栈中的位置（1 基）；不在栈中返回 0 ----
OverlayIndex(name) {
    global overlayStack
    for i, v in overlayStack {
        if (v = name)
            return i
    }
    return 0
}

; ---- 登记一个已打开的浮层（name = "radial" / "arrow" / "numpad" / "symbol"）----
OverlayPush(name) {
    global overlayStack
    OverlayRemove(name)          ; 已登记则先移除，避免重复（同时保证"最近操作"排在末尾）
    overlayStack.Push(name)
    OverlayRegisterEscape()
}

; ---- 注销一个已关闭的浮层 ----
OverlayRemove(name) {
    global overlayStack
    idx := OverlayIndex(name)
    if (idx)
        overlayStack.RemoveAt(idx)
    if (overlayStack.Length = 0)
        OverlayUnregisterEscape()
}

; ---- 标记某个浮层为「最近操作过的」：把它移到栈末尾，从而决定 Esc 先关谁 ----
; 调用时机：在面板上移动鼠标（含拖拽中）、在面板上按下/抬起左键（含点空位、点空白的无效点击）。
; 已经在末尾时直接返回，避免鼠标移动频繁触发时的无谓搬动。
OverlayTouch(name) {
    global overlayStack
    idx := OverlayIndex(name)
    if (!idx || idx = overlayStack.Length)
        return
    overlayStack.RemoveAt(idx)
    overlayStack.Push(name)
}

; ---- Esc：关闭「最近操作过的那个」浮层（一次一个，互不牵连）----
OverlayOnEscape(*) {
    global overlayStack
    if (overlayStack.Length = 0)
        return
    name := overlayStack[overlayStack.Length]
    DebugLog("[overlay] Esc 按下 → 关闭浮层：" . name)
    if (name = "radial")
        RadialClose()
    else
        KeypadClose(name)
}

; ---- Esc 全局热键的注册 / 注销 ----
; 注意（实测坑）：Hotkey(Key,"Off") 之后，必须显式再调一次 Hotkey(Key,"On") 才会重新启用。
OverlayRegisterEscape() {
    try {
        Hotkey("Escape", OverlayOnEscape)
        Hotkey("Escape", "On")
    } catch Error as e {
        DebugLog("[overlay] Esc 全局热键注册失败：" . e.Message . " | What=" . e.What)
    }
}

OverlayUnregisterEscape() {
    try Hotkey("Escape", "Off")
}

; ============================================================================
; 10c-2. 浮层避让 —— 五块浮层（径向菜单 / 方向 / 数字 / 符号 / 字母小键盘）同屏时不允许重叠
;      规则：以「正在拖动 / 刚打开」的那块为 active，其余被它压住的块沿**最小位移方向**推开，
;            并留 GAP 像素间隙；被推的块若又压到第三块，会在同一轮/后续轮里继续被推（连锁）。
;      落点一律夹取在**虚拟屏幕**内；某个方向推不出屏幕时改试另一个方向，两个方向都不行则
;      原地不动（宁可保留少量重叠，也不要在屏幕边缘来回抖动）。
;      调用时机只有两处：拖动过程中、面板刚打开后 —— 纯位置计算，不碰任何绘制代码。
; ============================================================================

; 浮层之间的最小间隙（像素）
OverlayAvoidGap() {
    return 8
}

; 避让迭代上限：连锁推开通常 1~2 轮就收敛，这里给宽松上限兜底
OverlayAvoidMaxPass() {
    return 4
}

; ---- 取各浮层当前的窗口矩形（固定顺序 radial / arrow / numpad / symbol / letter，保证结果可预期）----
OverlayRects() {
    global keypadPanels, radialGui
    rects := []
    for name in ["radial", "arrow", "numpad", "symbol", "letter"] {
        hwnd := 0
        if (name = "radial") {
            if (radialGui)
                hwnd := radialGui.Hwnd
        } else if (keypadPanels.Has(name) && keypadPanels[name].gui) {
            hwnd := keypadPanels[name].gui.Hwnd
        }
        if (!hwnd)
            continue
        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
        if (w > 0 && h > 0)
            rects.Push({name: name, x: x, y: y, w: w, h: h})
    }
    ; 运行框（面板 + 文字层 + 输入框窗口 + 下面那排键帽）：视为**一个整体**参与避让
    ; （它们必须一起移动；文字层与面板完全重合，可以不重复计入，但面板是半透明的，
    ;   真正"占地方"的是面板窗口本身）
    if (hw := RunBoxHwnd()) {
        WinGetPos(&x, &y, &w, &h, "ahk_id " . hw)
        if (w > 0 && h > 0) {
            if (keypadPanels.Has("runkeys") && keypadPanels["runkeys"].gui) {
                kx := 0
                ky := 0
                kw := 0
                kh := 0
                WinGetPos(&kx, &ky, &kw, &kh, "ahk_id " . keypadPanels["runkeys"].gui.Hwnd)
                if (kw > 0 && kh > 0) {
                    x1 := Min(x, kx)
                    y1 := Min(y, ky)
                    x2 := Max(x + w, kx + kw)
                    y2 := Max(y + h, ky + kh)
                    x := x1
                    y := y1
                    w := x2 - x1
                    h := y2 - y1
                }
            }
            rects.Push({name: "runbox", x: x, y: y, w: w, h: h})
        }
    }
    return rects
}

; ---- 移动指定浮层；径向菜单顺带更新"中心"记录（切层重建时仍在当前位置）----
OverlayMoveTo(name, x, y) {
    global keypadPanels, radialGui, radialTextGui, radialCenterX, radialCenterY
    if (name = "radial") {
        if (!radialGui)
            return
        radialGui.Move(x, y)
        OverlayTextLayerMove(radialTextGui, x, y)      ; 文字层跟着走
        WinGetPos(, , &w, &h, "ahk_id " . radialGui.Hwnd)
        radialCenterX := x + w // 2
        radialCenterY := y + h // 2
        return
    }
    if (name = "runbox") {
        global runboxAvoidTick
        hw := RunBoxHwnd()
        if (!hw)
            return
        runboxAvoidTick := A_TickCount             ; 记下"是我们自己挪的"，避免马上反推别人
        try WinMove(x, y, , , "ahk_id " . hw)      ; 只挪位置，不改大小
        RunBoxSyncWindows()                        ; 输入框窗口 / 文字层 / 键帽排一起跟着走
        return
    }
    if (keypadPanels.Has(name) && keypadPanels[name].gui) {
        keypadPanels[name].gui.Move(x, y)
        OverlayTextLayerMove(keypadPanels[name].textGui, x, y)   ; 文字层跟着走
    }
}

; ---- 两个矩形是否重叠（把 A 按 gap 外扩后再判，等价于"间距小于 gap 也算需要让位"）----
OverlayRectsOverlap(A, B, gap) {
    return (A.x - gap < B.x + B.w) && (A.x + A.w + gap > B.x)
        && (A.y - gap < B.y + B.h) && (A.y + A.h + gap > B.y)
}

; ---- 真的把 mover 移动到 (x, y)：与 other 不再重叠才移动；返回是否移动 ----
OverlayTryMove(mover, x, y, other, gap) {
    if (x = mover.x && y = mover.y)
        return false
    if (OverlayRectsOverlap({x: x, y: y, w: mover.w, h: mover.h}, other, gap))
        return false
    OverlayMoveTo(mover.name, x, y)
    mover.x := x
    mover.y := y
    return true
}

; ---- 把 mover 推离 other：水平 / 垂直各取"贴边"候选，先试位移小的那个轴，不行再试另一个 ----
OverlayPushAway(mover, other, gap) {
    vb := RadialVirtualBounds()

    ; 四个候选：贴到 other 右侧 / 左侧 / 下方 / 上方
    hx1 := other.x + other.w + gap
    hx2 := other.x - mover.w - gap
    vy1 := other.y + other.h + gap
    vy2 := other.y - mover.h - gap

    ; 一律夹取到虚拟屏幕内（多显示器合并区域）
    hx1 := Max(vb.x, Min(hx1, vb.x + vb.w - mover.w))
    hx2 := Max(vb.x, Min(hx2, vb.x + vb.w - mover.w))
    vy1 := Max(vb.y, Min(vy1, vb.y + vb.h - mover.h))
    vy2 := Max(vb.y, Min(vy2, vb.y + vb.h - mover.h))

    ; 四个候选落点（右 / 左 / 下 / 上）按"位移最小"排序后逐个尝试，直到找到一个不重叠的位置。
    ; 不能只试"水平较近 + 垂直较近"两个：运行框这类大窗口很容易把两个近位都挡住，
    ; 那时明明远侧还有空位却推不动（2026-09-15 用户实测"运行框推不开小键盘"）。
    cand := []
    cand.Push({x: hx1, y: mover.y, d: Abs(hx1 - mover.x)})
    cand.Push({x: hx2, y: mover.y, d: Abs(hx2 - mover.x)})
    cand.Push({x: mover.x, y: vy1, d: Abs(vy1 - mover.y)})
    cand.Push({x: mover.x, y: vy2, d: Abs(vy2 - mover.y)})
    sorted := []
    for c in cand {
        inserted := false
        for i, sc in sorted {
            if (c.d < sc.d) {
                sorted.InsertAt(i, c)
                inserted := true
                break
            }
        }
        if (!inserted)
            sorted.Push(c)
    }
    for c in sorted {
        if (OverlayTryMove(mover, c.x, c.y, other, gap))
            return true
    }
    return false
}

; ---- 一轮避让：把所有重叠的"非 active"浮层各推开一次；返回本轮是否有移动 ----
; 注意：active 那一块**永远不动**（它是用户手里 / 刚弹出的那块，位置由用户或鼠标决定）。
OverlayAvoidPass(active, gap) {
    rects := OverlayRects()
    if (rects.Length < 2)
        return false
    moved := false
    for i, A in rects {
        for j, B in rects {
            if (i >= j)
                continue
            if (!OverlayRectsOverlap(A, B, gap))
                continue
            ; B = active → 让前一块让位；否则让后一块让位（连锁时向"外侧"扩散）
            did := (B.name = active) ? OverlayPushAway(A, B, gap) : OverlayPushAway(B, A, gap)
            if (did)
                moved := true
        }
    }
    return moved
}

; ---- 避让入口：以 active 为准，把其余浮层推开，直到互不重叠（或达到迭代上限）----
; 高频调用（拖动时每次 WM_MOUSEMOVE）：全部是轻量坐标计算，没有多余重绘。
OverlayAvoid(active) {
    gap := OverlayAvoidGap()
    loop OverlayAvoidMaxPass() {
        if (!OverlayAvoidPass(active, gap))
            break
    }
}

; ============================================================================
; 10c-3. 浮层文字层 —— 文字必须"始终不透明且为红色"，而主窗口整体受 opacity 参数控制
;      （整窗 LWA_ALPHA 会把文字一起变淡），所以文字单独画在第二个窗口里：
;        · 文字层用逐像素 alpha 合成（UpdateLayeredWindow + 预乘 ARGB），文字 alpha 恒为
;          255，**完全不受透明度参数影响**；背景像素 alpha=0，等于透明；
;        · 文字层点击穿透（WS_EX_TRANSPARENT）、不抢焦点（WS_EX_NOACTIVATE）、
;          永远贴在所属面板正上方，并跟着面板一起移动（拖动 / 被避让推开都要跟着动）；
;        · 逐像素合成只在"文字层创建 / 文字内容变化"时做一次（420×252 约 60ms），
;          鼠标悬停只重绘主窗口，因此不影响悬停反馈速度。
; ============================================================================

; ---- 文字颜色（COLORREF，0x00BBGGRR）：由 [ui] overlay_text_color 配置，默认 #FFFF00 亮黄 ----
OverlayTextColor() {
    global overlay_text_color
    if (IsSet(overlay_text_color) && overlay_text_color != "")
        return overlay_text_color
    return 0x00FFFF          ; 兜底：亮黄（正常情况下配置加载阶段已赋值）
}

; ---- 描边宽度（像素；[ui] overlay_text_outline，0 = 不描边，默认 1）----
OverlayTextOutlineWidth() {
    global overlay_text_outline
    if (IsSet(overlay_text_outline) && overlay_text_outline != "")
        return Max(0, Min(overlay_text_outline + 0, 3))
    return 1
}

; ---- 描边偏移表：以 (0,0) 为中心、半径 r 的整圈偏移（不含中心）----
OverlayTextOffsets(r) {
    list := []
    if (r <= 0)
        return list
    Loop r * 2 + 1 {
        dy := A_Index - 1 - r
        Loop r * 2 + 1 {
            dx := A_Index - 1 - r
            if (dx = 0 && dy = 0)
                continue
            list.Push({x: dx, y: dy})
        }
    }
    return list
}

; ---- 在指定 DC 上"水平垂直双居中"画一次文字（黑边的每次偏移也用它）----
OverlayDrawCenteredText(dc, text, l, t, r, b, color) {
    DllCall("SetBkMode", "Ptr", dc, "Int", 1)          ; TRANSPARENT
    DllCall("SetTextColor", "Ptr", dc, "UInt", color)
    rc := Buffer(16)
    NumPut("Int", l, rc, 0)
    NumPut("Int", t, rc, 4)
    NumPut("Int", r, rc, 8)
    NumPut("Int", b, rc, 12)
    DllCall("DrawTextW", "Ptr", dc, "Str", text, "Int", -1, "Ptr", rc
        , "UInt", 0x0001 | 0x0004 | 0x0020 | 0x0800)   ; DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX
}

; ---- 把"白字掩码图"的覆盖度搬进"彩字图"的 alpha 通道，得到预乘 ARGB ----
; 彩字图里 RGB 已经是预乘形式（覆盖度 × 字色，黑边处 RGB = 0），只差 alpha；
; 掩码图用白色画（含描边偏移），其 R 通道就是 (字身 ∪ 黑边) 的覆盖度 → 直接抄进 alpha。
OverlayTextMaskToAlpha(colorDib, maskDib) {
    o := 0
    total := colorDib.w * colorDib.h
    Loop total {
        NumPut("UChar", NumGet(maskDib.bits, o + 2, "UChar"), colorDib.bits, o + 3)
        o += 4
    }
}

; ---- 解析颜色文本 → COLORREF；非法 / 纯黑时用默认色（防空 + 防呆）----
; 支持 "#RRGGBB" / "RRGGBB" / 少量颜色名；颜色名与 sRGB 常见值一致。
OverlayParseColor(text, defHex) {
    static names := Map("yellow", "FFFF00", "gold", "FFD700", "orange", "FFA500"
        , "red", "FF0000", "pink", "FF80AB", "green", "00FF00", "lime", "00FF00"
        , "cyan", "00FFFF", "blue", "4A90D9", "white", "FFFFFF", "purple", "B388FF")
    hex := Trim(text)
    if (hex = "")
        hex := defHex
    else if (names.Has(StrLower(hex)))
        hex := names[StrLower(hex)]
    if (SubStr(hex, 1, 1) = "#")
        hex := SubStr(hex, 2)
    if (!RegExMatch(hex, "^[0-9A-Fa-f]{6}$"))
        hex := defHex
    rgb := Integer("0x" . hex)
    if (rgb = 0)                       ; 纯黑 = 看不见，退回默认
        rgb := Integer("0x" . defHex)
    r := (rgb >> 16) & 0xFF
    g := (rgb >> 8) & 0xFF
    b := rgb & 0xFF
    return (b << 16) | (g << 8) | r    ; RGB → COLORREF
}

; ---- 新建 32bpp DIB 段（含内存 DC）；新建时位图已被系统清零（= 全透明黑底）----
OverlayTextDibNew(w, h) {
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)          ; biSize
    NumPut("Int", w, bi, 4)
    NumPut("Int", h, bi, 8)
    NumPut("UShort", 1, bi, 12)        ; biPlanes
    NumPut("UShort", 32, bi, 14)       ; biBitCount
    NumPut("UInt", 0, bi, 16)          ; BI_RGB
    ppv := Buffer(8, 0)
    hbm := DllCall("CreateDIBSection", "Ptr", 0, "Ptr", bi, "UInt", 0, "Ptr", ppv, "Ptr", 0, "UInt", 0, "Ptr")
    hdc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")
    return {hbm: hbm, hdc: hdc, old: old, bits: NumGet(ppv, 0, "Ptr"), w: w, h: h}
}

OverlayTextDibFree(d) {
    DllCall("SelectObject", "Ptr", d.hdc, "Ptr", d.old)
    DllCall("DeleteObject", "Ptr", d.hbm)
    DllCall("DeleteDC", "Ptr", d.hdc)
}

; ---- 创建文字层窗口（分层窗口；此时还没有内容，由 Present 一次性给出位置、尺寸与像素）----
OverlayTextLayerNew(x, y, w, h) {
    GWL_EXSTYLE := -20
    WS_EX_LAYERED := 0x00080000
    getFn := (A_PtrSize = 8) ? "GetWindowLongPtrW" : "GetWindowLongW"
    setFn := (A_PtrSize = 8) ? "SetWindowLongPtrW" : "SetWindowLongW"

    ; +E0x08000000 = WS_EX_NOACTIVATE（不抢焦点）；+E0x20 = WS_EX_TRANSPARENT（点击穿透到下面的面板）
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 +E0x20")
    g.BackColor := "000000"
    g.MarginX := 0
    g.MarginY := 0
    ex := DllCall(getFn, "Ptr", g.Hwnd, "Int", GWL_EXSTYLE, "Ptr")
    DllCall(setFn, "Ptr", g.Hwnd, "Int", GWL_EXSTYLE, "Ptr", ex | WS_EX_LAYERED)
    g.Show("x" . x . " y" . y . " w" . w . " h" . h . " NoActivate")
    return g
}

; ---- 画出并呈现文字层内容 ----
; drawFn(maskDC, colorDC, w, h)：在两张纯黑底位图上各画一遍——
;   colorDC：字身用配置色画（描边不画，黑边处保持 RGB=0）；
;   maskDC ：字身 + 黑边（8 方向偏移）都用白色画，其覆盖度作为最终 alpha。
; 两者的并集 = "彩色字身 + 不透明黑边"，且黑边与字身一样**不受透明度影响**。
OverlayTextLayerPresent(g, x, y, w, h, drawFn) {
    dColor := OverlayTextDibNew(w, h)
    dMask := OverlayTextDibNew(w, h)
    drawFn(dMask.hdc, dColor.hdc, w, h)
    OverlayTextMaskToAlpha(dColor, dMask)

    ptDst := Buffer(8, 0)
    sz := Buffer(8, 0)
    ptSrc := Buffer(8, 0)
    bf := Buffer(4, 0)
    NumPut("Int", x, ptDst, 0)
    NumPut("Int", y, ptDst, 4)
    NumPut("Int", w, sz, 0)
    NumPut("Int", h, sz, 4)
    NumPut("UChar", 0, bf, 0)      ; BlendOp = AC_SRC_OVER
    NumPut("UChar", 0, bf, 1)      ; BlendFlags
    NumPut("UChar", 255, bf, 2)    ; SourceConstantAlpha
    NumPut("UChar", 1, bf, 3)      ; AlphaFormat = AC_SRC_ALPHA（使用源像素 alpha）
    ok := DllCall("UpdateLayeredWindow", "Ptr", g.Hwnd, "Ptr", 0, "Ptr", ptDst, "Ptr", sz
        , "Ptr", dColor.hdc, "Ptr", ptSrc, "UInt", 0, "Ptr", bf, "UInt", 0x2)   ; ULW_ALPHA
    if (!ok)
        DebugLog("[overlay] 文字层呈现失败（UpdateLayeredWindow 返回 0）：hwnd=" . g.Hwnd . " size=" . w . "x" . h)
    OverlayTextDibFree(dColor)
    OverlayTextDibFree(dMask)
    OverlayTextLayerRaise(g)
}

; ---- 移动文字层（与面板保持完全重合）----
; 注意：**不传 SWP_NOZORDER** —— 面板被拖动（Gui.Move）时会被系统提到最上层，
; 文字层必须跟着回到它上面，否则半透明面板会盖住文字（看起来像"文字又变淡了"）。
OverlayTextLayerMove(g, x, y) {
    if (!g)
        return
    DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0
        , "UInt", 0x0001 | 0x0010)     ; SWP_NOSIZE | SWP_NOACTIVATE（置顶）
}

; ---- 把文字层抬到最上层（面板被点击 / 移动后都会被系统提到最上层，需重新压回下面）----
OverlayTextLayerRaise(g) {
    if (!g)
        return
    DllCall("SetWindowPos", "Ptr", g.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0
        , "UInt", 0x0001 | 0x0002 | 0x0010)     ; SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE
}

; ---- 销毁文字层 ----
OverlayTextLayerDestroy(g) {
    if (g) {
        try g.Destroy()
    }
}

; ============================================================================
; 10d. 屏幕小键盘（方向 / 数字 / 符号）—— GDI 自绘的屏幕按键面板
;      四个独立触发键（[keypad] arrow_hotkey / numpad_hotkey / symbol_hotkey / letter_hotkey，默认 ^+k / ^+n / ^+y / ^+e）：
;        · 方向小键盘：3×3 十字（中心【回车】；四角 = 退格 / 删除 / 上页 / 下页）
;        · 数字小键盘：4 列 × 4 行（7 8 9 + / 4 5 6 - / 1 2 3 × / 0 . ÷ 回车）
;        · 符号小键盘：6 列 × 5 行共 30 键（标准键盘符号 + 空格 / Tab，含一个额外的正斜杠）
;        · 字母小键盘：6 列 × 5 行（a-z 顺序 + 【Aa】大小写切换键，大写时整块面板变大写）
;      四块面板与径向菜单**互相独立、可同时打开**：各自的触发键只管自己的开 / 关。
;      面向数位板 / 触屏场景：用笔点按键，就把该按键发送到**当前前台窗口**。
;      面板带 WS_EX_NOACTIVATE（点击 / 拖动都不抢焦点、不改变前台窗口）；
;      点按键后面板**保持打开**（可连续输入），按住拖动可移动面板位置。
;      关闭方式：自己的触发键、Esc（关最近操作过的那个）、鼠标右键（四套面板都没有【关】键）。
; ============================================================================

; ============================================================================
; 10c-4. 浮层动作层（四块小键盘 + 径向菜单共用）
; ============================================================================
; 配置里写的一格动作，统一解析成 {type, value}：
;   none ：空（该格不成立）
;   send ：普通按键 / 文本，按 AutoHotkey 的 Send 规则发送到当前前台窗口
;   run  ：run: 命令行 —— 启动程序 / 打开文件
;   close：close —— 关闭发起动作的那个浮层（小键盘=关该面板；圆盘=关整个菜单）
;   case ：case —— 切换发起动作那个浮层的【大小写状态】
;   self ：self: 命令 —— 调用 SharpKnife 自身功能（不模拟按键，见 OverlayRunSelf）
;
; 以后新增一类动作，只需要改 OverlayActionParse（认得它）与 OverlayActionExecute（执行它）两处，
; 四块小键盘与径向菜单会**同时**支持，不必各改一遍。
; 保留字：close / case（动作想发送这两个词本身时，目前请用 self: 扩展或改用其它形式）。
OverlayActionParse(text) {
    t := Trim(text)
    if (t = "")
        return {type: "none", value: ""}
    if RegExMatch(t, "i)^run\s*:(.*)$", &m) {
        cmd := Trim(m[1])
        return (cmd = "") ? {type: "none", value: ""} : {type: "run", value: cmd}
    }
    if RegExMatch(t, "i)^self\s*:(.*)$", &m) {
        cmd := StrLower(Trim(m[1]))
        return (cmd = "") ? {type: "none", value: ""} : {type: "self", value: cmd}
    }
    ; send: 与 hotkey: 等价：显式声明"这是一段 Send 语法"（文本 / 按键 / 组合键）
    if RegExMatch(t, "i)^(?:send|hotkey)\s*:(.*)$", &m) {
        v := Trim(m[1])
        return (v = "") ? {type: "none", value: ""} : {type: "send", value: v}
    }
    ; paste: 剪贴板粘贴（长文本比逐字发送快且稳）
    if RegExMatch(t, "i)^paste\s*:(.*)$", &m) {
        v := Trim(m[1])
        return (v = "") ? {type: "none", value: ""} : {type: "paste", value: v}
    }
    ; wait: 毫秒（夹取 0~10000；仅面板 / 菜单配置里用得到，运行框的等待由运行器自动插入）
    if RegExMatch(t, "i)^wait\s*:(.*)$", &m) {
        v := Trim(m[1])
        if (!RegExMatch(v, "^\d+$"))
            return {type: "none", value: ""}
        return {type: "wait", value: Max(0, Min(Integer(v), 10000))}
    }
    ; item: 名称 —— 按名字执行"配置里已配好的那一项"的动作
    if RegExMatch(t, "i)^item\s*:(.*)$", &m) {
        v := Trim(m[1])
        return (v = "") ? {type: "none", value: ""} : {type: "item", value: v}
    }
    low := StrLower(t)
    if (low = "close")
        return {type: "close", value: ""}
    if (low = "case")
        return {type: "case", value: ""}
    return {type: "send", value: t}
}

; ---- 执行"已配置命令表"里的条目：名称 → 动作 ----
; 供 item: 动作与自然语言运行框共用。重名时返回第一个并写日志。
OverlayLookupItem(name) {
    want := Trim(name)
    if (want = "")
        return 0
    for it in OverlayConfiguredItems() {
        if (it.name == want)              ; == 才区分大小写（= 在 AHK 里大小写不敏感，会把 A 匹配成 a）
            return it
    }
    return 0
}

; ---- 已配置命令表：四块小键盘的每个按键 + 圆盘菜单的每个菜单项 ----
; 返回 [{name, action, source}]；action 为动作文本（可再交给 OverlayActionParse）
OverlayConfiguredItems() {
    global keypadDefs, radialGroups
    list := []
    for kind in ["arrow", "numpad", "symbol", "letter"] {
        if (!keypadDefs.Has(kind))
            continue
        def := keypadDefs[kind]
        for k in def.keys {
            if (k.role = "blank" || k.label = "" || k.action = "")
                continue
            list.Push({name: k.label, action: k.action, source: def.name})
            ; case = true 的面板（字母键盘）本来就能产出大写（【Aa】键），
            ; 这里把大写变体也列出来，模型才能直接引用"大写字母"这一项
            if (def.case && RegExMatch(k.action, "^[a-z]$"))
                list.Push({name: StrUpper(k.label), action: StrUpper(k.action), source: def.name})
        }
    }
    for g in radialGroups
        for it in g.items
            list.Push({name: it.name, action: OverlayActionText(it), source: g.name})
    return list
}

; ---- 圆盘菜单项 → 动作文本（与配置里的写法一致）----
OverlayActionText(it) {
    if (it.actionType = "run")
        return "run: " . it.actionValue
    if (it.actionType = "self")
        return "self: " . it.actionValue
    if (it.actionType = "send")
        return it.actionValue
    return it.actionType        ; close / case
}

; ---- 执行动作 ----
; owner：发起动作的浮层名（"radial" 或小键盘 kind）；fallbackWin：该浮层记录的备用目标窗口
OverlayActionExecute(act, owner, fallbackWin) {
    if (!IsObject(act))
        return false
    if (act.type = "run")
        return OverlayRunCommand(act.value)
    if (act.type = "self")
        return OverlayRunSelf(act.value, owner, fallbackWin)
    if (act.type = "close")
        return OverlayCloseOwner(owner)
    if (act.type = "case")
        return OverlayCaseToggle(owner)
    if (act.type = "send") {
        t := OverlayCaseTransform(owner, "", act.value)
        return OverlaySendKey(t.action, owner, fallbackWin)
    }
    if (act.type = "paste")
        return OverlayPasteText(act.value, owner, fallbackWin)
    if (act.type = "wait") {
        ms := Max(0, Min(act.value + 0, 10000))
        DebugLog("[overlay] wait " . ms . "ms（" . owner . "）")
        Sleep(ms)
        return true
    }
    if (act.type = "item") {
        ref := OverlayLookupItem(act.value)
        if (!ref) {
            DebugLog("[overlay] item:" . act.value . " —— 配置里没有这一项，已忽略")
            return false
        }
        DebugLog("[overlay] item:" . act.value . " → 执行其动作「" . ref.action . "」（" . ref.source . "）")
        return OverlayActionExecute(OverlayActionParse(ref.action), owner, fallbackWin)
    }
    return false
}

; ---- paste：用剪贴板把文本粘到目标窗口（长文本比逐字 Send 快且稳）----
; 尽量原样备份 / 恢复剪贴板（非文本内容同样保留）。
OverlayPasteText(text, owner, fallbackWin) {
    if (text = "")
        return false
    if (!OverlayPrepareInject(owner, fallbackWin, "粘贴文本"))
        return false
    saved := ""
    try {
        saved := ClipboardAll()
    } catch {
        saved := ""
    }
    ok := true
    try {
        A_Clipboard := text
        if (!ClipWait(1)) {
            DebugLog("[overlay] 粘贴失败：剪贴板未就绪")
            ok := false
        } else {
            SendEvent("^v")
        }
    } catch Error as e {
        DebugLog("[overlay] 粘贴异常：" . e.Message)
        ok := false
    }
    ; 给目标程序一点时间取走剪贴板内容，再恢复原剪贴板
    Sleep(150)
    if (saved != "") {
        try A_Clipboard := saved
    }
    return ok
}

; ---- close：关闭发起动作的浮层 ----
OverlayCloseOwner(owner) {
    if (owner = "radial") {
        DebugLog("[overlay] close → 关闭径向菜单")
        RadialClose()
        return true
    }
    DebugLog("[overlay] close → 关闭小键盘：" . owner)
    KeypadClose(owner)
    return true
}

; ---- 大小写状态：按浮层存（owner -> true 大写 / false 小写），只影响"动作恰好是一个 a-z 字母"的键 ----
OverlayCaseUpper(owner) {
    global overlayCaseState
    return overlayCaseState.Has(owner) && overlayCaseState[owner]
}

; 标签与动作一起变大写（不满足条件时原样返回）；小键盘取键时、圆盘取菜单名时都调它
OverlayCaseTransform(owner, label, action) {
    if (!OverlayCaseUpper(owner) || !RegExMatch(action, "^[a-z]$"))
        return {label: label, action: action}
    return {label: StrUpper(label), action: StrUpper(action)}
}

OverlayCaseToggle(owner) {
    global overlayCaseState
    overlayCaseState[owner] := !OverlayCaseUpper(owner)
    DebugLog("[overlay] " . owner . " 大小写切换 → " . (overlayCaseState[owner] ? "大写" : "小写"))
    OverlayRefresh(owner)
    return true
}

; ---- 大小写切换后刷新显示：小键盘就地重建按键 + 重绘；圆盘重建菜单 ----
OverlayRefresh(owner) {
    global keypadPanels
    if (owner = "radial") {
        RadialBuildMenu()
        return
    }
    if (!keypadPanels.Has(owner))
        return
    P := keypadPanels[owner]
    P.keys := KeypadKeysFor(owner)
    KeypadDraw(owner)
    KeypadTextLayerPresent(owner)
}

; ---- 发送按键：目标窗口校验 + 物理修饰键释放等待（两个组件共用同一套守卫）----
OverlaySendKey(raw, owner, fallbackWin) {
    if (raw = "")
        return false
    if (!OverlayPrepareInject(owner, fallbackWin, "发送按键 " . raw))
        return false
    SendEvent(raw)
    return true
}

; ---- 浮层自己的窗口句柄（用于判断"前台窗口是不是被浮层自己占了"）----
; 运行框：面板窗口是 WS_EX_NOACTIVATE（永远不是前台），真正可能拿到前台的是**输入框窗口**，
; 所以 "runbox" / "runkeys" 都返回输入框窗口的句柄。
OverlayOwnerHwnd(owner) {
    global radialGui, keypadPanels, runboxInputGui
    if (owner = "radial")
        return (radialGui ? radialGui.Hwnd : 0)
    if (owner = "runbox" || owner = "runkeys") {
        if (runboxInputGui) {
            h := 0
            try h := runboxInputGui.Hwnd
            return h
        }
        return 0
    }
    if (keypadPanels.Has(owner) && keypadPanels[owner].gui)
        return keypadPanels[owner].gui.Hwnd
    return 0
}

OverlayPrepareInject(owner, fallbackWin, what) {
    target := WinExist("A")
    ; 防御：万一把浮层自己当成了前台窗口，就退回弹出浮层前记录的前台窗口。
    ; 运行框自己有**三个**顶层窗口（面板 / 输入框 / 执行过程），必须整组判，不能只比一个句柄。
    ownSelf := false
    if (owner = "runbox" || owner = "runkeys") {
        ownSelf := RunBoxIsSelfWin(target)
    } else {
        ownHwnd := OverlayOwnerHwnd(owner)
        ownSelf := (ownHwnd && target = ownHwnd)
    }
    if (ownSelf)
        target := fallbackWin
    if (!target) {
        DebugLog("[overlay] 已取消：" . what . " —— 当前前台窗口不可用（" . owner . "）")
        return false
    }
    if (!RadialActivateFocusWin(target)) {
        DebugLog("[overlay] 已取消：" . what . " —— 目标窗口未能重新获得前台（" . owner . "）")
        return false
    }
    ; ---- 修饰键闸门：**运行框执行序列例外**（2026-09-19 用户定稿）----
    ; 这道等待是为了"浮层被 Ctrl+Shift+M 之类的真实组合键唤起时，用户手指可能还按在键上"，
    ; 若此时注入按键会被系统拼成组合键（想发 {Up} 却发出 Ctrl+Up）。
    ; 但自然语言运行框的**多步序列**里，"按住修饰键"本身就是合法写法：
    ;     序列 ^{Space} / {Ctrl down} / {Up} / {Up} / {Ctrl up}
    ; 前一步 {Ctrl down} 注入后修饰键就处于按下状态，若每步都等它"先松开"，
    ; 后面每一步都会 400ms 超时被取消（用户实测：第 1 条 16ms 成功、其余全部 406ms 未执行）。
    ; 因此在运行框（owner = "runbox"）下**跳过**这道等待，让"按住修饰键的多步序列"能跑通；
    ; 浮层（radial / arrow / numpad / symbol / letter）行为**完全不变**，仍旧逐个等待。
    ; 代价（已与用户确认）：运行框执行期间若用户自己正按着修饰键，注入的键会与其拼成组合键。
    ; run: 动作走 OverlayRunCommand，那条路径**不接收 owner**，因此保持原样继续等待（选法 A）。
    if (owner = "runbox") {
        DebugLog("[overlay] 运行框序列：跳过修饰键等待（" . what . "）")
    } else if (!RadialWaitModifiersReleased()) {
        DebugLog("[overlay] 已取消：" . what . " —— 检测到物理修饰键仍按下（" . owner . "）")
        return false
    }
    return true
}

; ---- 启动程序 / 打开文件（run: 动作，两个组件共用）----
OverlayRunCommand(cmdLine) {
    if (Trim(cmdLine) = "") {
        DebugLog("[overlay] 已取消启动程序：命令行为空")
        return false
    }
    if (!RadialWaitModifiersReleased()) {
        DebugLog("[overlay] 已取消启动程序：检测到物理修饰键仍按下，cmd=" . cmdLine)
        return false
    }
    ; 依次尝试几种写法，第一个能启动成功的就用（先试原样，保证既有配置行为完全不变）
    for i, c in OverlayRunCandidates(cmdLine) {
        try {
            Run(c)
            if (i > 1)
                DebugLog("[overlay] 启动程序成功（第 " . i . " 种写法）：" . c . " ← 原配置写法：" . cmdLine)
            return true
        } catch Error as e {
            DebugLog("[overlay] 启动程序第 " . i . " 种写法失败：" . e.Message . " | cmd=" . c)
        }
    }
    return false
}

; ---- run: 命令的候选写法 ----
; AHK 的 Run() 与 cmd 不同：**整条命令用引号包起来时，它会把这整串当成一个文件路径**，
; 于是 run: "C:\x\app.exe snip --full" 会找不到文件（在 cmd 里却能跑），表现为"点了没反应"。
; 这里生成几种等价写法交给 OverlayRunCommand 逐个尝试：
;   ① 原样                              （正确写法：可执行文件带引号 + 参数，直接成功）
;   ② 整条被一对引号包住 → 拆成 "可执行文件" + 参数
;   ③ 没加引号但路径含空格 → 截到 .exe/.cmd/.bat/.com 为止加引号，其余当参数
OverlayRunCandidates(cmdLine) {
    raw := Trim(cmdLine)
    out := [raw]
    q := Chr(34)
    if (StrLen(raw) > 1 && SubStr(raw, 1, 1) = q && SubStr(raw, -1) = q) {
        inner := SubStr(raw, 2, StrLen(raw) - 2)
        sp := InStr(inner, " ")
        if (sp > 0) {
            exe := SubStr(inner, 1, sp - 1)
            rest := Trim(SubStr(inner, sp + 1))
            out.Push(q . exe . q . (rest = "" ? "" : " " . rest))
        }
    }
    if (SubStr(raw, 1, 1) != q && InStr(raw, " ") > 0) {
        if RegExMatch(raw, "i)^(.+?\.(?:exe|cmd|bat|com))(?=\s|$)", &m) {
            exe := m[1]
            rest := Trim(SubStr(raw, StrLen(exe) + 1))
            if (exe != raw)
                out.Push(q . exe . q . (rest = "" ? "" : " " . rest))
        }
    }
    return out
}

; ---- self: 命令表（两个组件共用）----
; 为什么不用发 ^j 这类做法：脚本自己发出的按键不会触发脚本自己的钩子热键（见 AGENTS 4.1 #20）。
OverlayRunSelf(cmd, owner, fallbackWin) {
    global trigger_hk
    c := StrLower(Trim(cmd))
    if (!OverlayPrepareInject(owner, fallbackWin, "self:" . c))
        return false
    if (c = "trigger") {
        DebugLog("[overlay] self:trigger → 执行补全（等同按 " . trigger_hk . "）")
        CompleteAI()
    } else if (c = "toggle_mode") {
        DebugLog("[overlay] self:toggle_mode → 循环切换模式")
        ToggleMode()
    } else if (c = "mode_latex") {
        SetModeDirect(MODE_LATEX)
    } else if (c = "mode_unicode") {
        SetModeDirect(MODE_UNICODE)
    } else if (c = "mode_ai") {
        SetModeDirect(MODE_AI)
    } else if (c = "mode_tikz") {
        SetModeDirect(MODE_TIKZ)
    } else if (c = "mode_list") {
        ShowModeList()
    } else if (c = "step") {
        StepPlay()
    } else if (c = "health") {
        HealthToggle()
    } else if (c = "radial") {
        RadialShow()
    } else if (c = "keypad_arrow") {
        KeypadToggle("arrow")
    } else if (c = "keypad_numpad") {
        KeypadToggle("numpad")
    } else if (c = "keypad_symbol") {
        KeypadToggle("symbol")
    } else if (c = "keypad_letter") {
        KeypadToggle("letter")
    } else if (SubStr(c, 1, 7) = "runbox_") {
        ; 运行框自身的命令（反馈模式 / 记忆重载 / 记忆回滚 / 查看记忆）：见 RunBoxSelfCommand
        if (!RunBoxSelfCommand(c))
            return false
    } else {
        DebugLog("[overlay] 未知的 self: 命令：" . cmd . "（owner=" . owner . "）")
        return false
    }
    return true
}

; ============================================================================
; 10c-5. 自然语言运行框（[runbox] 段）：中文需求 → 模型解析成动作序列 → 确认后执行
; ============================================================================
; 允许的动作只有两类：
;   ① 自由内容：send: / hotkey:（按键、组合键、文本）、paste:（长文本用剪贴板粘贴）
;   ② 必须命中"已配置命令表"（四块小键盘 + 圆盘菜单里配过的动作）：run: / self: / item: 名称
; 其余任何一行都**不执行**，只列进"已丢弃"清单给用户过目 ——
; 绝不按"裸行 = 普通发送"处理，否则模型多说一句解释就会被原样打进编辑器。
; 等待由运行器自动插入（动作之间 step_delay_ms、run: 之后 run_wait_ms），不让模型输出 wait:。

; ---- 读一个 [runbox] 配置值并剥离行内注释 ----
; IniRead 不会剥注释（"值  ; 注释" 会把注释一起带回来），这里按"空白 + ;"截断
RunBoxCfg(key, def, section := "runbox") {
    global configFile
    v := Trim(IniRead(configFile, section, key, def))
    if RegExMatch(v, "\s;", &m)
        v := Trim(SubStr(v, 1, m.Pos - 1))
    return (v = "") ? def : v
}

RunBoxLoadConfig() {
    global configFile, runboxHotkey, runboxConfirm, runboxModel, runboxTimeout
    global runboxStepDelay, runboxRunWait, runboxMaxActions, runboxPromptExtra
    global runboxOpacity, runboxMemoryFile, runboxLearnConfirm, runboxMemoryMaxChars
    global runboxAliasMatch, runboxLearnModel
    if !FileExist(configFile) {
        RunBoxMemoryLoad(false)          ; 配置缺失也要能加载记忆（用内置默认路径）
        return
    }
    v := RunBoxCfg("hotkey", "")
    if (v != "")
        runboxHotkey := v
    runboxConfirm := (StrLower(RunBoxCfg("confirm", "true")) = "true")
    ; 面板本体透明度（0.0~1.0）；文字与黑边不受它影响（恒不透明）。非法值沿用默认 1.0
    v := RunBoxCfg("opacity", "")
    if RegExMatch(v, "^\d*\.?\d+$")
        runboxOpacity := Max(0.0, Min(v + 0, 1.0))
    runboxModel := RunBoxCfg("model", "")
    v := RunBoxCfg("timeout_ms", "")
    if RegExMatch(v, "^\d+$")
        runboxTimeout := Max(Integer(v), 5000)
    v := RunBoxCfg("step_delay_ms", "")
    if RegExMatch(v, "^\d+$")
        runboxStepDelay := Max(0, Min(Integer(v), 5000))
    v := RunBoxCfg("run_wait_ms", "")
    if RegExMatch(v, "^\d+$")
        runboxRunWait := Max(0, Min(Integer(v), 10000))
    v := RunBoxCfg("max_actions", "")
    if RegExMatch(v, "^\d+$")
        runboxMaxActions := Max(1, Min(Integer(v), 200))
    ; prompt_extra 是自由文本，不做注释剥离（里面可能有分号）
    runboxPromptExtra := Trim(IniRead(configFile, "runbox", "prompt_extra", ""))

    ; —— 自适应记忆（[runbox] 的 5 个新键，见 11d-2 节）——
    ; memory_file 有"显式留空 = 关闭本功能"的语义，不能走 RunBoxCfg（它会把空值当缺省）。
    ; 这里用哨兵值区分"键不存在"与"键存在但为空"，并照样剥掉行内注释。
    rawMem := IniRead(configFile, "runbox", "memory_file", "@absent@")
    if (rawMem != "@absent@") {
        if RegExMatch(rawMem, "\s;", &mm)
            rawMem := SubStr(rawMem, 1, mm.Pos - 1)
        runboxMemoryFile := Trim(rawMem)
    }
    runboxLearnConfirm := (StrLower(RunBoxCfg("learn_confirm", (runboxLearnConfirm ? "true" : "false"))) = "true")
    v := RunBoxCfg("memory_max_chars", "")
    if RegExMatch(v, "^\d+$")
        runboxMemoryMaxChars := Max(0, Min(Integer(v), 20000))   ; 0 = 不拼记忆块（只留别名快路径）
    v := StrLower(RunBoxCfg("alias_match", ""))
    if (v = "exact" || v = "contain")
        runboxAliasMatch := v
    runboxLearnModel := RunBoxCfg("learn_model", "")

    ; 底部热键键帽排：独立子节 [runbox.runkeys]（键帽排在后面加载，优先于 [keypad.runkeys]）
    RunBoxLoadKeycaps()
    RunBoxMemoryLoad(false)              ; 记忆文件加载（不存在 = 空记忆，功能自然降级为原行为）
    DebugLog("[runbox] 配置：hotkey=" . runboxHotkey . " confirm=" . runboxConfirm . " model=" . runboxModel
        . " timeout=" . runboxTimeout . " step=" . runboxStepDelay . " run_wait=" . runboxRunWait
        . " max=" . runboxMaxActions . " opacity=" . runboxOpacity
        . " memory=" . (runboxMemoryFile = "" ? "(关闭)" : runboxMemoryFile)
        . " learn_confirm=" . runboxLearnConfirm . " alias_match=" . runboxAliasMatch)
}

; ---- 已配置命令表 → 紧凑文本（喂给模型；解析时另用它做白名单）----
; ============================================================================
; 危险动作识别（2026-09-19 用户定稿）——只用于**禁止被组合进序列**
; ----------------------------------------------------------------------------
; 背景（用户实测）：需求"从当前已选择的文件开始，向上同时选择三个相邻文件"，
;   表里没有现成的"向上扩选"项，模型就回 NOACTION 放弃了；而用户要的是
;   "模型用已有动作的合理组合去达成目标"——组合出的每个动作仍在表里即可。
;   因此提示语改为允许组合，但用户要求**排除危险类动作**不被组合。
;
; 界定方式（用户选定"按动作文本自动识别"）：按**配置项名 + 动作文本**里的关键词判定，
; 关键词集中在本表，改这里即可，不必改配置。
;
; 作用范围（用户明确选定 "只禁止被组合，原有行为不变"）：
;   · 用户在需求里**明确**要删除/剪切/关闭时，仍走原来的单条路径正常执行；
;   · 只是模型不得把这些动作**编进一个多步组合序列**里自作主张。
;   实现上，被判定为危险的动作**不列进"可组合"清单**，并在提示语里单独标出。
RunBoxDangerWords() {
    ; 关键词一律小写比较；中英文都收
    return ["删除", "永久删除", "剪贴", "剪切", "cut", "delete"
        , "关闭", "close", "退出", "结束", "kill", "终止"
        , "重命名", "改名", "rename"
        , "格式化", "清空", "销毁", "卸载", "卸载程序"]
}

; 动作 / 名称是否属于"危险类"（只影响能否被组合，不影响单独执行）
RunBoxIsDangerous(name, action) {
    hay := StrLower(Trim(name) . " " . Trim(action))
    ; 快捷键本身也判：^x 是剪切、{Del} 是删除、!{F4} / ^w 是关闭
    for w in RunBoxDangerWords()
        if (InStr(hay, StrLower(w)) > 0)
            return true
    ; 纯按键层面的危险写法（名称里没写"删除"二字也要拦住）
    if (action == "^x" || action == "hotkey: ^x" || action == "send: ^x")
        return true
    if (action == "{Del}" || action == "!{F4}" || action == "^w" || action == "^+{Esc}")
        return true
    return false
}

; ---- 与 RunBoxCatalogText 相同，但给"危险类"项打上 ⚠危险 标记 ----
; 喂给模型的那份用它，这样模型能一眼看出哪些不能被编进组合；
; 危险判定只按**配置项名 + 动作文本**的关键词（见 RunBoxIsDangerous），不需要额外配置。
RunBoxCatalogTextMarked() {
    txt := ""
    last := ""
    for it in OverlayConfiguredItems() {
        if (it.source != last) {
            txt .= (txt = "" ? "" : "`n") . "[" . it.source . "] "
            last := it.source
        } else
            txt .= "、"
        txt .= it.name . "=" . it.action
        if (RunBoxIsDangerous(it.name, it.action))
            txt .= " ⚠危险"
    }
    if (txt = "")
        txt := "（没有任何已配置的按键或菜单项）"
    return txt
}

RunBoxCatalogText() {
    txt := ""
    last := ""
    for it in OverlayConfiguredItems() {
        if (it.source != last) {
            txt .= (txt = "" ? "" : "`n") . "[" . it.source . "] "
            last := it.source
        } else
            txt .= "、"
        txt .= it.name . "=" . it.action
    }
    if (txt = "")
        txt := "（没有任何已配置的按键或菜单项）"
    return txt
}

; ---- 系统提示语：把中文需求翻译成动作序列 ----
; req：当前需求（可选）——只用于"记忆块"的相关度筛选（把与这条需求有关的别名排在前面），
;      不影响固定骨架的任何一行。
RunBoxBuildPrompt(req := "") {
    global runboxPromptExtra
    ; 注意：AHK v2 字符串里的双引号要用单引号字符串或 `" 转义，不能写 ""（那是 v1 的写法）
    p := '你是把中文操作需求翻译成"动作序列"的翻译器。你的输出会被程序逐行执行，必须严格遵守格式。' . "`n`n"
    p .= "【第一步：判断这条需求是“要输出文字”还是“要执行某种操作”】`n"
    p .= "  一、要输出文字（要网址、要答案、要一段内容、翻译、解释、名称…）：`n"
    p .= "      用 paste: 原文 或 send: 原文 直接输出，不需要预先配置；内容必须与用户要的完全一致。`n"
    p .= "      · 要输出**多行文字**（写诗、写一段带换行的文字）：**只写一行** paste:，`n"
    p .= "        行内换行写成字面的 \n（反斜杠 + n）。例如：`n"
    p .= "        paste: 《山居》\n空山新雨后，天气晚来秋。\n明月松间照，清泉石上流。`n"
    p .= "      这类需求**不要**用 ERROR 推脱。`n"
    p .= "  二、要执行某种操作（打开 / 启动程序、按键、切换、保存、删除、复制…要改变电脑状态）：`n"
    p .= "      · 先看【已配置动作表】里有没有能**直接**完成它的项 → 有就用 item: 名称（首选），或把表里那个动作原样照抄一行；`n"
    p .= "      · 表里**没有现成的项**时，不要立刻放弃：再想一步——能不能用表里已有的动作**组合**出这个效果？`n"
    p .= "        能 → 按先后顺序逐行写出这个组合（**每一步都必须是表里真有的动作**）；`n"
    p .= "        实在组合不出来 → 才输出一行：ERROR: NOACTION`n"
    p .= "        （无论哪种情况，都**不要自己编**表里没有的按键 / 程序 / 功能名）`n`n"
    p .= "      【关于“组合”】用户要的是“目标”（例如“从当前选中的文件开始向上选三个”），`n"
    p .= "      目标本身**不必**在表里，只要**你写出的每一个动作**都在表里即可。`n"
    p .= "      要善于用“按下/松开修饰键”+“方向键/字母键”这种已有动作，拼出表里没有的效果。`n"
    p .= "      例：需求“从当前选中项向上选择三个相邻文件”→ 表里没有现成的扩选项，`n"
    p .= "          但表里有“按下Shift”“↑”“松开Shift”→ 组合成：`n"
    p .= "            item: 按下Shift`n"
    p .= "            {Up}`n"
    p .= "            {Up}`n"
    p .= "            item: 松开Shift`n"
    p .= "      又例：需求“把光标快速移到行首并选中到行尾”→ 若表里有 Home / End / 按下Shift，`n"
    p .= "          可组合：{Home} → item: 按下Shift → {End} → item: 松开Shift`n"
    p .= "      【组合的限制】表里标着“⚠危险”的动作**不得**被编进组合里（删除 / 剪切 / 关闭 / 重命名这类）。`n"
    p .= "      用户若**明确要求**做这些事（例如直接说“删除这个文件”），就正常用 item: 引用它，那是允许的；`n"
    p .= "      但不许你在完成别的目标时“顺手”把它们编进序列。`n`n"
    p .= "【输出格式】一行一个动作；不要编号、不要解释、不要 markdown 代码块、不要空行。`n"
    p .= "只允许下面几种写法：`n"
    p .= "  item: 名称      执行表里某个功能（按名称，首选）`n"
    p .= "  动作原文         把表里某个动作原样照抄一行（例如 ^c、hotkey: ^c、{Enter}、run: xxx、self: xxx）`n"
    p .= "  paste: 文本     要输出的纯文本（推荐：任何符号都会被原样粘贴，最可靠）；多行时换行写成字面的 \n，仍只占一行`n"
    p .= "  send: 文本      要输出的纯文本；只有文本里不含 ^ ! + # { } 这些按键语法字符时才可用`n"
    p .= "  ERROR: NOACTION  操作类需求、表里没有对应动作时（只输出这一行）`n"
    p .= "  ERROR: 原因      其它确实做不了的情况（只输出这一行）`n`n"
    p .= "【规则】`n"
    p .= "1. 先按【第一步】判断类别。网址 / 链接属于“文字”：直接把网址给出来，不要当成“打开网址”的操作。`n"
    p .= "2. 信息类：有把握就给准确内容；不确定的不要编造（例如记不准的网址），那时输出 ERROR: 不确定…。`n"
    p .= "3. 操作类：**优先用现成的 item: 名称**；只有当单项完不成目标时，才用表里已有的动作组合（组合里每一步同样必须与表里某个动作**逐字一致**）。`n"
    p .= "3b. 组合时**不要**用标着“⚠危险”的动作（除非用户明确要求做那件事）；组合出的动作越少越好，够用就停。`n"
    p .= "4. 要输入文字时用 paste: 原文照抄；含 ^ ! + # { } 等符号时必须用 paste:；多行文字写成一行 paste: + 字面的 \n（不要拆成多行写，拆行只有第一行会生效）。`n"
    p .= "5. 启动程序后不用写等待，程序会自动等待。`n"
    p .= "6. 最多输出 40 行，且只输出动作行。`n"

    ; ---------- 分层（2026-09-19 定稿）：骨架 → 自动记忆 → 手写补充要求 → 已配置动作表（最后）----------
    ; 优先级：骨架 < 自动记忆（软参考）< 手写 prompt_extra < 格式契约与动作白名单（不可违背）。
    ; 动作表必须留在**最末尾**：它是唯一的权威事实，离 user 消息最近时注意力最强；
    ; 记忆块绝不能接在它后面，否则会把动作表挤远。
    memBlock := RunBoxMemoryPromptBlock(req)
    if (memBlock != "")
        p .= "`n" . memBlock . "`n"
    if (runboxPromptExtra != "")
        p .= "`n【补充要求】`n" . runboxPromptExtra . "`n"
    p .= "`n【已配置动作表】（名称=动作；动作只能用这里的）`n" . RunBoxCatalogTextMarked() . "`n"
    p .= "（标了 ⚠危险 的项：单独用可以，但**不得**被编进组合序列里）`n"
    return p
}

; ---- 兜底提示语（第二阶段）：操作类需求在动作表里找不到对应动作时，回头重新审视能不能当成"要文字" ----
; 用户要求的判定顺序：① 先判"要文字"还是"要操作"；② 操作类 → 表里有就执行；
;   表里没有则**回头再看这条需求本身**是否也能理解成"要输出文字"：能 → 走文字通道；不能 → 只报"没有对应的操作"。
RunBoxBuildFallbackPrompt() {
    p := '用户刚才提了一条需求，但程序在「已配置动作表」里没有找到能完成它的动作，所以现在请你**回头重新审视这条需求本身**。' . "`n`n"
    p .= "请判断：这条需求是不是**也可以理解成“要一段文字 / 一个信息”**？`n"
    p .= "  · 可以（例如要某个网址、某个答案、某段内容、翻译、解释）→ 只输出一行：`n"
    p .= "      paste: <满足这条需求的内容>（多行时换行写成字面的 \n，仍然只写这一行）`n"
    p .= "    内容必须照用户要的给（例如问网址就给准确的网址），不要解释、不要道歉、不要加引号。`n"
    p .= "  · 不可以（这条需求本质上是要操作电脑，例如打开程序、按键、切换、保存）→ 只输出一行：`n"
    p .= "      ERROR: 没有对应的操作`n"
    p .= "  · 内容没有把握、不想编造 → 只输出一行：`n"
    p .= "      ERROR: 不确定…`n`n"
    p .= "【输出格式】只输出一行；不要编号、不要解释、不要 markdown 代码块；不允许 item: / run: / self: / 按键。`n"
    return p
}

; ---- 动作 → 一行可读描述（确认清单 / 进度提示用）----
RunBoxActionLine(act) {
    if (act.type = "send")
        return "按键/文本：" . RunBoxBrief(act.value, 60)
    if (act.type = "paste") {
        ; 多行文字：把换行显示成 " ⏎ "，保证清单 / 状态行只占一行
        v := StrReplace(act.value, "`r`n", " ⏎ ")
        v := StrReplace(v, "`n", " ⏎ ")
        return "粘贴文本：" . (StrLen(v) > 60 ? SubStr(v, 1, 60) . "…" : v)
    }
    if (act.type = "run")
        return "启动程序：" . act.value
    if (act.type = "self")
        return "自身功能：" . act.value
    if (act.type = "item")
        return "配置项：" . act.value
    if (act.type = "wait")
        return "等待：" . act.value . " 毫秒"
    return act.type
}

; ---- 底部热键键帽排：[runbox.runkeys] 子节（与 [keypad.<kind>] 完全同一套写法与语义）----
;   [runbox.runkeys]
;   name   = 运行热键      ; 面板名（缺省用内置的"运行热键"）
;   cols   = 7             ; 列数（1~12；缺省用内置的 7）
;   rows   = 1             ; 行数（1~12；缺省用内置的 1）
;   square = false         ; 是否正方形按键
;   case   = false         ; 是否启用大小写状态
;   1 = 回车 | {Enter}     ; 编号 = 格子序号（行优先、1 起）；缺号 = 空位
;   2 = Tab  | {Tab}
;   · 写法 / 语义与小键盘面板一模一样：写了编号就整体替换键帽，缺号是空位；
;     整节不写（或一条编号都没有）→ 沿用内置默认那 7 个键。列数 / 行数以配置为准，
;     配置里不写就用内置默认值 —— 与 [keypad.<kind>] 的行为完全一致。
;   · 动作由 KeypadParseItem / KeypadRoleFor 解析，普通按键 / run: / self: / close / case / paste: 都可写。
RunBoxLoadKeycaps() {
    global configFile, keypadDefs
    if (!keypadDefs.Has("runkeys") || !FileExist(configFile))
        return
    def := keypadDefs["runkeys"]
    sec := "runbox.runkeys"

    v := RunBoxCfg("name", "", sec)
    if (v != "")
        def.name := v
    v := RunBoxCfg("cols", "", sec)
    if RegExMatch(v, "^\d+$")
        def.cols := Max(1, Min(Integer(v), 12))
    v := RunBoxCfg("rows", "", sec)
    if RegExMatch(v, "^\d+$")
        def.rows := Max(1, Min(Integer(v), 12))
    v := RunBoxCfg("square", "", sec)
    if (v != "")
        def.square := (StrLower(v) = "true")
    v := RunBoxCfg("case", "", sec)
    if (v != "")
        def.case := (StrLower(v) = "true")

    ; 编号项（上限 12×12，防呆）
    items := Map()
    Loop 144 {
        raw := RunBoxCfg(String(A_Index), "", sec)
        if (raw != "")
            items[A_Index] := raw
    }
    if (items.Count = 0) {
        DebugLog("[runbox] 未配置 [" . sec . "] 的按键，沿用内置默认（" . def.keys.Length . " 键）")
        return
    }

    ; 落地方式与 KeypadLoadConfig 完全一致：整段替换，缺号 / 越界都是空位
    total := def.cols * def.rows
    keys := []
    Loop total
        keys.Push({label: "", action: "", role: "blank"})
    n := 0
    for num, raw in items {
        if (num < 1 || num > total) {
            DebugLog("[runbox] 键帽 " . num . " 超出 " . def.cols . "×" . def.rows . " 范围，已忽略")
            continue
        }
        it := KeypadParseItem(raw)
        keys[num] := {label: it.label, action: it.action, role: KeypadRoleFor(it.action)}
        n++
    }
    def.keys := keys
    DebugLog("[runbox] 键帽排已配置：" . n . " 个键，" . def.cols . "×" . def.rows . "，名称=" . def.name)
}

; ============================================================================
; 运行框的「自适应记忆」（2026-09-19 新增）——让运行框越用越准
; ----------------------------------------------------------------------------
; 设计要点（与用户逐条定稿，务必按此维护）：
;   ① **分层，不是替换**：固定骨架（格式契约 + 安全红线）永远在代码里、不可被记忆覆盖；
;      记忆只是"软参考"，拼在骨架之后、手写 prompt_extra 之前、**动作表之前**。
;   ② **记忆不生产能力**：凡是需要新增动作类型（如"打开网址"）的都不属于这里。
;   ③ **别名快路径**先于模型：命中即不调模型 —— 0 延迟、0 token、0 幻觉。
;   ④ **只有用户显式反馈**才会改记忆；隐式信号只进流水，绝不自动改提示语
;      （程序判不出"这次到底成功了没有"，模型自认为成功不算成功）。
;   ⑤ 学习只允许 ADD / DEL **条目**，不允许模型重写整个文件；写盘前先备份，保留最近 5 份。
;   ⑥ 写入是"读-改-写并**原样保留**不认识的段落与手写注释"（`## 快捷` 就是给下一期预留的）。
;
; 文件格式（runbox_memory.md，UTF-8 带 BOM，记事本可直接编辑）：
;   # 标题 / <!-- meta: ... --> / 空行 / 注释
;   ## 别名      → 每行：- 我的说法 => 目标      （目标是配置项名，或 item:/url:/run:/self:/paste:/hotkey: 动作行）
;   ## 偏好      → 每行：- 一句自然语言
;   ## 正例      → 每行：- 需求：X → item: Y    （→ 也可写成 -> / =>）
;   ## 反例      → 每行：- 需求：X → 不要选 Z
;   ## 快捷      → 本期不实现；解析时原样保留（写入时不得丢失）
; ============================================================================

; ---- 记忆文件的绝对路径（相对脚本目录）----
RunBoxMemoryPath() {
    global runboxMemoryFile
    f := Trim(runboxMemoryFile)
    if (f = "")
        return ""
    if RegExMatch(f, "^[A-Za-z]:[\\/]") || SubStr(f, 1, 2) = "\\"
        return f                                  ; 已经是绝对路径
    return A_ScriptDir . "\" . f
}

; ---- 分节显示名 ↔ 规范化段名 ----
RunBoxMemorySectionKey(name) {
    n := Trim(name)
    if (n = "别名")
        return "alias"
    if (n = "偏好")
        return "pref"
    if (n = "正例")
        return "pos"
    if (n = "反例")
        return "neg"
    if (n = "快捷")
        return "shortcut"
    return ""                                     ; 不认识的小节 → 整块原样保留
}

RunBoxMemorySectionName(key) {
    if (key = "alias")
        return "别名"
    if (key = "pref")
        return "偏好"
    if (key = "pos")
        return "正例"
    if (key = "neg")
        return "反例"
    return "快捷"
}

RunBoxMemoryNewModel() {
    m := {loaded: false, path: "", mtime: "", head: [], order: [], secs: Map(), aliasIdx: Map(), dupSkipped: 0}
    for k in ["alias", "pref", "pos", "neg", "shortcut"] {
        m.secs[k] := []
        m.order.Push(k)
    }
    return m
}

; ---- 解析一行条目 ----
; canonical：写回文件时的规范写法（"- 说法 => 目标" / "- 需求：X → item: Y"）
; sortKey  ：排序 / 去重用的规范键
RunBoxMemoryParseItem(raw, secKey) {
    line := Trim(raw)
    if (SubStr(line, 1, 1) = "-")
        line := Trim(SubStr(line, 2))
    if (line = "")
        return 0
    if (secKey = "alias") {
        if !RegExMatch(line, "^(.*?)\s*=>\s*(.*)$", &m)
            return {left: line, right: "", text: line, canonical: "", sortKey: "", count: 0}   ; 非法：原样保留
        l := Trim(m[1]), r := Trim(m[2])
        canon := (r = "") ? "" : "- " . l . " => " . r
        return {left: l, right: r, text: line, canonical: canon, sortKey: l . "\n" . r, count: 0}
    }
    ; 正例 / 反例：需求：X → Y（箭头容忍 -> / => / →）
    if (secKey = "pos" || secKey = "neg") {
        if !RegExMatch(line, "^(.*?)\s*(?:→|->|=>)\s*(.*)$", &m)
            return {left: line, right: "", text: line, canonical: "", sortKey: "", count: 0}
        l := Trim(m[1]), r := Trim(m[2])
        l := RegExReplace(l, "^(需求|例子)\s*[:：]\s*", "")
        canon := (r = "") ? "" : "- 需求：" . l . " → " . r
        return {left: l, right: r, text: line, canonical: canon, sortKey: l . "\n" . r, count: 0}
    }
    ; 偏好（以及原样保留段的条目）：整行就是内容
    return {left: line, right: "", text: line, canonical: "- " . line, sortKey: line, count: 0}
}

; ---- 读文本文件（记忆 / 备份都要用）：**必须显式指定编码** ----
; 血泪教训（2026-09-19 实测）：`FileRead(path)` 不带编码参数时按 **ANSI** 读，
; 而我们的记忆文件是 UTF-8（用户也可能用记事本另存成 UTF-16）。
; 按 ANSI 读会把"别名"读成"鍒悕"，于是所有中文小节名都对不上、记忆整块失效
; ——而且**不报任何错**，只表现为"记忆好像没生效"。
; 这里按顺序尝试 UTF-8（含 BOM 自动识别）→ UTF-16 → 系统 ANSI，取第一个非空结果。
RunBoxReadTextFile(path) {
    for enc in ["UTF-8", "UTF-16"] {
        try {
            t := FileRead(path, enc)
            if (t != "")
                return t
        } catch {
        }
    }
    try {
        return FileRead(path)
    } catch {
        return ""
    }
}

; ---- 加载记忆文件 ----
; force = false 时按 mtime 判断是否需要重读（用户手改文件后无需重启即可生效）
RunBoxMemoryLoad(force := true) {
    global runboxMemory, runboxMemoryDirty
    m := RunBoxMemoryNewModel()
    path := RunBoxMemoryPath()
    m.path := path
    if (path = "" || !FileExist(path)) {
        runboxMemory := m
        if (path != "")
            DebugLog("[runbox] 记忆文件不存在（" . path . "）→ 以空记忆运行（功能降级为原行为）")
        return false
    }
    t := RunBoxReadTextFile(path)
    if (t = "") {
        DebugLog("[runbox] 记忆文件读取失败或为空：" . path . " → 以空记忆运行")
        runboxMemory := m
        return false
    }
    RunBoxMemoryParse(t, &m)
    m.loaded := true
    m.path := path                       ; 解析会新建模型：这几个字段必须在解析**之后**补
    m.mtime := RunBoxFileTimeStr(path)
    runboxMemory := m
    runboxMemoryDirty := false
    DebugLog("[runbox] 记忆已加载：" . path . "（别名 " . m.secs["alias"].Length . " 条，偏好 "
        . m.secs["pref"].Length . " 条，正例 " . m.secs["pos"].Length . " 条，反例 "
        . m.secs["neg"].Length . " 条，保留段 " . m.secs["shortcut"].Length . " 行）")
    return true
}

; ---- 解析记忆文本 → 记忆模型（纯函数，便于无头单测）----
; 注意：本函数会**新建**一个模型对象覆盖 out —— 所以调用方在调用前设到模型上的
; path / mtime 之类字段会被冲掉。RunBoxMemoryLoad 因此在解析之后才补 path，
; 这里是同一个坑的第二次踩（2026-09-19：path 被冲成空串，表现为"保存被跳过、返回 false"）。
RunBoxMemoryParse(t, &out) {
    m := RunBoxMemoryNewModel()
    m.loaded := true
    cur := ""                                ; 当前段（"" = 文件头 / 段外）
    started := false
    Loop parse, t, "`n", "`r" {
        line := A_LoopField
        trimmed := Trim(line)
        if (!started && trimmed = "")        ; 文件最前面若干空行归文件头
            continue
        if RegExMatch(trimmed, "^##\s*(.+?)\s*$", &hm) {
            started := true
            cur := RunBoxMemorySectionKey(hm[1])
            if (cur = "") {                  ; 不认识的小节：原样保留全部行
                if (!m.secs.Has("raw"))
                    m.secs["raw"] := [], m.order.Push("raw")
                m.secs["raw"].Push(line)
            }
            continue
        }
        if (!started) {                      ; 还没进任何小节 → 文件头（标题 / meta / 说明注释）
            m.head.Push(line)
            continue
        }
        if (cur = "") {                      ; 大小节之间的散行：并进文件头，保证写回不丢
            m.head.Push(line)
            continue
        }
        if (trimmed = "" || SubStr(trimmed, 1, 1) = ";")
            continue                         ; 段内空行 / 注释：丢弃（写回时不再保留）
        it := RunBoxMemoryParseItem(line, cur)
        if (it = 0)
            continue
        m.secs[cur].Push(it)
    }
    out := m
}

; ---- 渲染记忆文件全文（原子的"读-改-写"：不认识的段落原样写回）----
RunBoxMemoryRender(m) {
    global runboxMemoryMaxChars
    lines := []
    if (m.head.Length = 0)
        lines.Push("# 运行框记忆（由程序自动维护，也可手动编辑）"), lines.Push("")
    else
        for h in m.head
            lines.Push(h)
    ; meta 行：条目数与更新时间（不参与解析，只是给人看）。
    ; 写之前把**历史 meta 行**从文件头里剔掉 —— 否则每存一次就多一行，
    ; 用久了文件头会堆满过期的 meta（2026-09-19 自测时就堆了五行）。
    lines := RunBoxDropMetaLines(lines)
    lines.Push("<!-- meta: updated=" . RunBoxNowStamp() . " entries=" . RunBoxMemoryCount(m)
        . " max_chars=" . runboxMemoryMaxChars . " -->")
    for k in m.order {
        if (k = "raw") {
            for r in m.secs["raw"]
                lines.Push(r)
            continue
        }
        if (k = "shortcut") {
            lines.Push(""), lines.Push("## 快捷")
            lines.Push("; 本期未实现（格式已预留）：一行 = 一句话 => 动作1 / 动作2 / …；")
            lines.Push("; 当前版本**不会**使用本段，也不会删除你写在这里的内容。")
            for it in m.secs["shortcut"]
                lines.Push((it.canonical != "" ? it.canonical : "- " . it.text))
            continue
        }
        lines.Push(""), lines.Push("## " . RunBoxMemorySectionName(k))
        for it in m.secs[k]
            lines.Push((it.canonical != "" ? it.canonical : "- " . it.text))
    }
    return RunBoxJoinLines(lines)
}

RunBoxDropMetaLines(lines) {
    out := []
    for l in lines
        if !RegExMatch(Trim(l), "^<!--\s*meta\s*:")
            out.Push(l)
    return out
}

RunBoxMemoryCount(m) {
    n := 0
    for k, arr in m.secs
        n += (k = "raw" || k = "shortcut") ? 0 : arr.Length
    return n
}

RunBoxJoinLines(lines) {
    out := ""
    for l in lines
        out .= l . "`n"
    return out
}

RunBoxNowStamp() {
    return FormatTime(A_Now, "yyyy-MM-dd HH:mm")
}

RunBoxStampForFile() {
    return FormatTime(A_Now, "yyyyMMdd-HHmmss")
}

; ---- 保存记忆（备份 → 原子写 → 重载）----
RunBoxMemorySave(m, what := "") {
    global runboxMemoryDirty
    path := m.path
    if (path = "") {
        DebugLog("[runbox] 记忆保存被跳过：memory_file 为空（功能已关闭）")
        return false
    }
    if FileExist(path) {
        bak := RunBoxMemoryBackupPath(path)
        try FileCopy(path, bak, 1)
        RunBoxMemoryPruneBackups(path)
    }
    txt := RunBoxMemoryRender(m)
    tmp := path . ".tmp"
    ok := false
    try {
        FileDelete(tmp)
    } catch {
    }
    try {
        f := FileOpen(tmp, "w", "UTF-8-RAW")
        f.Write(Chr(0xFEFF))                  ; 带 BOM：记事本 / 编辑器打开不乱码
        f.Write(txt)
        f.Close()
        FileMove(tmp, path, 1)
        ok := true
    } catch Error as e {
        DebugLog("[runbox] 记忆写入失败：" . e.Message)
        try FileDelete(tmp)
    }
    if (ok) {
        m.mtime := RunBoxFileTimeStr(path)
        runboxMemoryDirty := false
        DebugLog("[runbox] 记忆已保存（" . what . "）：" . path . "，共 " . RunBoxMemoryCount(m) . " 条")
    }
    return ok
}

RunBoxFileTimeStr(path) {
    t := ""
    try t := FileGetTime(path, "M")
    return (t = "") ? "" : FormatTime(t, "yyyyMMddHHmmss")
}

; 备份文件名：<原名>.<时间戳>.bak<扩展名>，例如 runbox_memory.20260919-072335.bak.md
; 血泪教训（2026-09-19）：AHK v2 的 SplitPath 出参顺序是
;     SplitPath(路径, &文件名, &目录, &扩展名, &无扩展名的文件名)
; **扩展名在第 4 位、无扩展名在第 5 位**（v1 习惯相反）。
; 写反了不会报错，只会拼出 "md.20260919-072350.bak.runbox_memory" 这种怪文件名。
RunBoxMemoryBackupPath(path) {
    SplitPath(path, &fname, &dir, &ext, &nameNoExt)
    ts := RunBoxStampForFile()
    p := dir . "\" . nameNoExt . "." . ts . ".bak" . (ext = "" ? "" : "." . ext)
    i := 1
    while (FileExist(p)) {                    ; 同一秒内多次写也不覆盖
        p := dir . "\" . nameNoExt . "." . ts . "-" . i . ".bak" . (ext = "" ? "" : "." . ext)
        i++
        if (i > 99)
            break
    }
    return p
}

; 只保留最近 5 份备份（正则里的数字要写成 \d，AHK 没有 \D）
RunBoxMemoryPruneBackups(path) {
    SplitPath(path, &fname, &dir, &ext, &nameNoExt)
    if (dir = "")
        return
    extPat := (ext = "" ? "" : "." . ext)
    list := []
    Loop files, dir . "\" . nameNoExt . ".*.bak" . extPat . "*" {
        nm := A_LoopFileName
        if RegExMatch(nm, "\.(\d{8}-\d{6}(?:-\d+)?)\.bak", &mm)
            list.Push({name: nm, key: mm[1]})
    }
    if (list.Length <= 5)
        return
    ; 按时间戳排序（格式固定，字典序 = 时间序），删掉最旧的几份。
    ; 注意用 StrCompare：时间戳形如 20260919-072007，用 > 会被当数字比而抛异常。
    Loop list.Length - 1 {
        i := A_Index
        Loop list.Length - i {
            j := A_Index
            if (StrCompare(list[j].key, list[j + 1].key) > 0) {
                tmp := list[j], list[j] := list[j + 1], list[j + 1] := tmp
            }
        }
    }
    Loop list.Length - 5 {
        try FileDelete(dir . "\" . list[A_Index].name)
    }
}

; 找最近一份备份（撤销用）
RunBoxMemoryLatestBackup(path) {
    SplitPath(path, &fname, &dir, &ext, &nameNoExt)
    if (dir = "")
        return ""
    extPat := (ext = "" ? "" : "." . ext)
    best := "", bestKey := ""
    Loop files, dir . "\" . nameNoExt . ".*.bak" . extPat . "*" {
        nm := A_LoopFileName
        if RegExMatch(nm, "\.(\d{8}-\d{6}(?:-\d+)?)\.bak", &mm) {
            ; bestKey 初值是空串必须守卫；而且必须用 **StrCompare** 做字符串比较 ——
            ; 时间戳是"20260919-071929"这种形式，用 > 会被 AHK 当数字比而抛
            ; Expected a Number（2026-09-19 连续踩两次）。
            if (bestKey = "" || StrCompare(mm[1], bestKey) > 0)
                bestKey := mm[1], best := dir . "\" . nm
        }
    }
    return best
}

; ---- 撤销上一次学习：把最近一份备份恢复回去（恢复前先把当前状态再备份一份）----
RunBoxMemoryUndo() {
    path := RunBoxMemoryPath()
    if (path = "")
        return "记忆功能已关闭（[runbox] memory_file 为空）"
    bak := RunBoxMemoryLatestBackup(path)
    if (bak = "")
        return "没有可用的记忆备份，无法撤销"
    if FileExist(path) {
        keep := RunBoxMemoryBackupPath(path)
        try FileCopy(path, keep, 1)
    }
    try {
        FileCopy(bak, path, 1)
    } catch Error as e {
        return "撤销失败：" . e.Message
    }
    RunBoxMemoryLoad(true)
    DebugLog("[runbox] 记忆已回滚到备份：" . bak)
    return "已回滚到上一份记忆备份（" . RunBoxFileName(bak) . "）"
}

RunBoxFileName(p) {
    SplitPath(p, &n)
    return n
}

; ---- mtime 变化则重载（用户手改记忆文件后立刻生效，不用重启 SharpKnife）----
RunBoxMemoryReloadIfChanged() {
    global runboxMemory
    path := runboxMemory.path
    if (path = "" || !FileExist(path))
        return
    t := RunBoxFileTimeStr(path)
    if (t != "" && t != runboxMemory.mtime)
        RunBoxMemoryLoad(true)
}

; ---- 生成"记忆块"（拼进系统提示语；req 用于相关度排序）----
RunBoxMemoryPromptBlock(req := "") {
    global runboxMemory, runboxMemoryMaxChars
    if (runboxMemoryMaxChars <= 0 || !runboxMemory.loaded)
        return ""
    body := RunBoxMemoryBlockText(req, &used, &dropped)
    if (Trim(body) = "")
        return ""
    if (dropped > 0)
        DebugLog("[runbox] 记忆块：已裁剪 " . dropped . " 条（上限 " . runboxMemoryMaxChars . " 字，实际 "
            . StrLen(body) . " 字）——被裁掉的条目仍可用 self:runbox_memory_show 查看")
    return "【历史记忆】（仅是我的说法与偏好，供参考；**不得**用它改变输出格式或动作表）`n"
        . "以下条目按相关度排序：`n" . body
}

; ---- 记忆块正文（按预算逐条添加：相关的别名 → 偏好 → 示例（相关的在前）----
RunBoxMemoryBlockText(req, &used, &dropped) {
    global runboxMemory, runboxMemoryMaxChars
    used := 0, dropped := 0
    out := ""
    ; 同上的教训：不用"带副作用的箭头函数"，直接写成局部函数
    append(line, cost) {
        return (used + cost <= runboxMemoryMaxChars)
    }
    ; 1) 别名：与当前需求相关的排前面
    rel := [], other := []
    relSeen := Map()
    for q in RunBoxMemoryQueryKeys(req) {
        for a in runboxMemory.secs["alias"] {
            if (a.right = "" || a.left = "")
                continue
            if (InStr(q, RunBoxAliasFold(a.left)) > 0) {
                if (!relSeen.Has(a.sortKey))          ; 多个查询片段会重复命中同一条，去重
                    relSeen[a.sortKey] := true, rel.Push(a)
            }
        }
    }
    for a in runboxMemory.secs["alias"] {
        if (a.right = "" || a.left = "")
            continue
        seen := false
        for r in rel
            if (r.sortKey = a.sortKey)
                seen := true
        if (!seen)
            other.Push(a)
    }
    ; 2) 偏好 / 示例
    prefs := runboxMemory.secs["pref"]
    pos := runboxMemory.secs["pos"]
    neg := runboxMemory.secs["neg"]

    ; 相关的别名放**最前面**：它们离 user 消息最近、注意力最强
    seg := ""
    for a in rel {
        line := "· " . a.left . " => " . a.right
        cost := StrLen(line) + 1
        if (append(line, cost))
            seg .= line . "`n", used += cost
        else
            dropped++
    }
    if (seg != "")
        out .= "· 我这条需求里用到 / 可能用到的说法：`n" . seg
    if (prefs.Length > 0) {
        seg := ""
        for p in prefs {
            line := "· " . p.text
            cost := StrLen(line) + 1
            if (append(line, cost))
                seg .= line . "`n", used += cost
            else
                dropped++
        }
        if (seg != "")
            out .= (out = "" ? "" : "`n") . "· 我的偏好：`n" . seg
    }
    seg := ""
    for a in pos {
        if (a.left = "" || a.right = "")
            continue
        line := "· " . a.left . " → " . a.right
        cost := StrLen(line) + 1
        if (append(line, cost))
            seg .= line . "`n", used += cost
        else
            dropped++
    }
    if (seg != "")
        out .= (out = "" ? "" : "`n") . "· 以前这样理解过（正例）：`n" . seg
    seg := ""
    for a in neg {
        if (a.left = "" || a.right = "")
            continue
        line := "· " . a.left . " → " . a.right
        cost := StrLen(line) + 1
        if (append(line, cost))
            seg .= line . "`n", used += cost
        else
            dropped++
    }
    if (seg != "")
        out .= (out = "" ? "" : "`n") . "· 以前明确否掉过（反例）：`n" . seg
    seg := ""
    for a in other {
        line := "· " . a.left . " => " . a.right
        cost := StrLen(line) + 1
        if (append(line, cost))
            seg .= line . "`n", used += cost
        else
            dropped++
    }
    if (seg != "")
        out .= (out = "" ? "" : "`n") . "· 我其它说法的固定含义（说法 => 配置项名）：`n" . seg
    return RTrim(out, "`r`n")
}

; ---- 需求拆成若干个"查询片段"（整句 + 标点/空白切出的片段），供别名相关度匹配 ----
RunBoxMemoryQueryKeys(req) {
    keys := []
    r := Trim(req)
    if (r = "")
        return keys
    ; 整句 + 按标点/空白切出的每个片段，都折叠成小写后放进候选。
    ; 注意：这里**不要**用 `push := (s) => (...)` 这种"带副作用的箭头函数"——
    ; AHK v2 里箭头函数体 `(表达式)` 的语义容易被读成"返回值"而不是"执行"，
    ; 实测（2026-09-19）push(...) 调用后 keys 一直是空数组，表现为"记忆的相关度排序永远不生效"。
    ; 老老实实写 if + 显式 Push，反而更稳。
    q := RunBoxAliasFold(r)
    if (StrLen(q) >= 2)
        keys.Push(q)
    ; 分隔符里含双引号，故用单引号字符串拼接（AHK 源码里写 " 必须转义）
    seps := " `t`r`n,，。.、;；:：!！?？()（）[]【】<>《》" . Chr(34) . Chr(39)
    for frag in StrSplit(r, seps) {
        f := RunBoxAliasFold(frag)
        if (StrLen(f) >= 2 && !RunBoxInArray(keys, f))
            keys.Push(f)
    }
    return keys
}

RunBoxInArray(arr, v) {
    for x in arr
        if (x = v)
            return true
    return false
}

; ---- 别名折叠：只用于"用户的说法"与用户输入的比较，绝不用于目标值 ----
RunBoxAliasFold(s) {
    return StrLower(Trim(s))
}

; ---- 别名反查：目标（配置项名或动作行）→ 说法列表（"查看记忆"用）----
RunBoxMemoryAliasFor(target) {
    global runboxMemory
    out := []
    if (!runboxMemory.loaded)
        return out
    for a in runboxMemory.secs["alias"]
        if (a.right == target)
            out.Push(a.left)
    return out
}

; ============================================================================
; 别名快路径（先于模型）
; ----------------------------------------------------------------------------
; 命中规则（[runbox] alias_match）：
;   contain（默认）：完全相等，或"需求中包含该说法"且**说法 ≥ 2 字**；
;   exact          ：只认完全相等。
; 大小写折叠只作用于"用户的说法"与用户输入，**目标值一律原样**（延续 §6.5 的教训：
; 用 = 比较会把 item: A 命中成配置里先出现的 a，所以目标校验走 OverlayLookupItem 的 ==）。
; 目标解析：写法以 item:/url:/run:/self:/paste:/hotkey: 开头 → 当动作行；否则当配置项名。
; —— url: 是**为将来**预留的写法（本期不新增该动作类型）：命中后仍会走白名单校验，
;    因此现在写进记忆也不会凭空造出动作能力。
; ============================================================================
RunBoxAliasResolve(req, &hitWords, &reasons) {
    global runboxMemory, runboxAliasMatch
    hitWords := [], reasons := []
    if (!runboxMemory.loaded || runboxMemory.secs["alias"].Length = 0)
        return []
    RunBoxAllowedMaps(&allowedAct, &allowedName)
    q := RunBoxAliasFold(req)
    plan := []
    seen := Map()
    for a in runboxMemory.secs["alias"] {
        w := RunBoxAliasFold(a.left)
        if (w = "" || a.right = "")
            continue
        matched := false
        if (runboxAliasMatch = "exact")
            matched := (q = w)
        else
            matched := (q = w) || (StrLen(w) >= 2 && InStr(q, w) > 0)
        if (!matched)
            continue
        ; 同一个说法只认第一条（重复定义以文件里靠前的为准，并在日志里说明）
        if (seen.Has(a.left)) {
            DebugLog("[runbox] 别名词条重复：「" . a.left . "」→" . a.right . " 被忽略（前面已有一条）")
            continue
        }
        seen[a.left] := true
        acts := RunBoxAliasResolveTarget(a.right, allowedAct, allowedName, &why)
        if (acts.Length = 0) {
            DebugLog("[runbox] 别名「" . a.left . "」的目标当前不可用：" . why . " →" . a.right)
            continue
        }
        hitWords.Push(a.left)
        for x in acts
            plan.Push(x)
        reasons.Push("「" . a.left . "」→ " . a.right)
    }
    DebugLog("[runbox] 别名快路径：" . (plan.Length > 0 ? "命中 " . reasons.Length . " 条说法（" . RunBoxJoinList(reasons, "；") . "）" : "未命中"))
    return plan
}

; 把别名目标解析成动作（全部必须过白名单）；why 带回不可用的原因
RunBoxAliasResolveTarget(target, allowedAct, allowedName, &why) {
    out := []
    why := ""
    t := Trim(target)
    if (t = "") {
        why := "目标为空（写法应是：说法 => 配置项名 或 说法 => 动作行）"
        return out
    }
    if RegExMatch(t, "i)^(item|url|run|self|paste|send|hotkey)\s*:") {
        act := OverlayActionParse(t)
        if (act.type = "none") {
            why := "不是合法的动作写法"
            return out
        }
        k := act.type . "|" . act.value
        if (!allowedAct.Has(k)) {
            why := "动作不在「已配置动作表」里（记忆不能凭空造动作）"
            return out
        }
        out.Push(OverlayActionParse(allowedAct[k]))     ; 用配置里的原始写法执行
        return out
    }
    ; 没有前缀 → 当配置项名（精确、区分大小写，走与 item: 完全相同的查表）
    it := OverlayLookupItem(t)
    if (it = 0) {
        why := "配置里没有名为「" . t . "」的项（大小写必须一致）"
        return out
    }
    out.Push({type: "item", value: t})
    return out
}

RunBoxJoinList(arr, sep) {
    out := ""
    for i, x in arr
        out .= (i = 1 ? "" : sep) . x
    return out
}

; ---- 命中计数 +1（顺手落盘，让"常用说法"能被看见；失败不影响本次执行）----
RunBoxAliasBump(words) {
    global runboxMemory, runboxMemoryDirty
    if (!runboxMemory.loaded || runboxMemoryFileIsOff())
        return
    dirty := false
    for a in runboxMemory.secs["alias"] {
        for w in words {
            if (a.left = w) {
                a.count := RunBoxMemoryItemCount(a) + 1
                dirty := true
            }
        }
    }
    if (dirty) {
        runboxMemoryDirty := true
        DebugLog("[runbox] 别名命中计数已更新（" . RunBoxJoinList(words, "、") . "）")
    }
}

RunBoxMemoryFileIsOff() {
    global runboxMemoryFile
    return (Trim(runboxMemoryFile) = "")
}

; ============================================================================
; 学习：把用户的显式反馈（"纠正：…" / "记住：…"）整理成记忆条目
; ----------------------------------------------------------------------------
; 红线：
;   · 只有用户**显式**反馈能进入这里（隐式信号只写流水，绝不自动改提示语）；
;   · 学习流程**不执行任何动作**，返回值里不存在可执行动作数组；
;   · 模型只能 ADD / DEL **条目**，不能重写文件；写盘前先备份、保留最近 5 份；
;   · 新增条目一律过白名单校验（别名目标必须是配置里真有的项 / 动作）。
; ============================================================================
RunBoxFeedbackPrefix(text) {
    t := Trim(text)
    ; 全角冒号也认；前缀本身大小写不敏感
    for p in ["纠正", "更正", "记住", "记下", "学习"] {
        if RegExMatch(t, "i)^" . p . "\s*[:：]\s*(.*)$", &m)
            return {isFeedback: true, body: Trim(m[1]), lead: p}
    }
    return {isFeedback: false, body: t, lead: ""}
}

; ---- 学习用系统提示语：只做"更新记忆"，与运行框提示语完全分开 ----
RunBoxBuildLearnPrompt() {
    p := '你是"运行框记忆"的维护助手。用户对自然语言运行框的执行结果给出了**明确反馈**，请把它整理成对记忆文件的增删条目。' . "`n`n"
    p .= "【记忆文件的作用】它只保存两样东西：① 用户的说法 → 配置项/动作 的对应（别名）；② 用户的偏好与正/反例。`n"
    p .= "它**不能**新增动作能力、不能改变输出格式、不能执行任何动作，也不要写“默认浏览器是某某”这类会过期的环境事实。`n`n"
    p .= "【只允许输出下面四类行，一行一条；不要解释、不要编号、不要 markdown 代码块、不要空行】`n"
    p .= "ADD alias: 用户的说法 => 目标`n"
    p .= "    目标必须是下面「已配置动作表」里真有的名称，或表里真有的动作原文；表里没有就不要写这一条。`n"
    p .= "ADD pref: 一句中文偏好（描述用户希望怎么理解他的说法）`n"
    p .= "ADD example: 需求：<用户原话> → <该给的动作>`n"
    p .= "ADD counter: 需求：<用户原话> → 不要选 <错误的目标>`n"
    p .= "DEL <序号>     删除下面「当前记忆清单」里同序号的那一条（序号以清单为准）`n`n"
    p .= "【判定要求】`n"
    p .= "1. 用户说“对了 / 就是这样 / 以后都这样”→ 至少产出 ADD alias 或 ADD example（把这次的说法固化）。`n"
    p .= "2. 用户说“不对 / 应该是 X / 不是 Y”→ 产出 ADD alias（把正确目标固化），必要时再补 ADD counter。`n"
    p .= "3. 用户明确要求“忘掉 / 删除”某条 → 输出对应的 DEL。`n"
    p .= "4. 拿不准、或这条反馈与记忆无关（例如只是抱怨）→ 只输出一行：NONE`n"
    p .= "5. 一条也别编：目标必须能在「已配置动作表」里找到**逐字一致**的名字或动作。`n`n"
    p .= "【当前记忆清单】（DEL 用这里的序号）`n" . RunBoxMemoryListing() . "`n`n"
    p .= "【已配置动作表】`n" . RunBoxCatalogText() . "`n"
    return p
}

; ---- 记忆清单（带序号，供 DEL 引用与用户对照）----
RunBoxMemoryListing() {
    global runboxMemory
    out := ""
    n := 0
    for k in ["alias", "pref", "pos", "neg"] {
        arr := runboxMemory.secs[k]
        if (arr.Length = 0)
            continue
        out .= "[" . RunBoxMemorySectionName(k) . "]`n"
        for it in arr {
            n++
            out .= n . ". " . (it.canonical != "" ? it.canonical : "- " . it.text) . "`n"
        }
    }
    if (out = "")
        out := "（记忆为空）`n"
    return RTrim(out, "`r`n")
}

; 记忆条目 → 全局序号映射（DEL 用；与 RunBoxMemoryListing 的顺序必须完全一致）
RunBoxMemoryIndexMap() {
    global runboxMemory
    idx := Map()
    n := 0
    for k in ["alias", "pref", "pos", "neg"] {
        for it in runboxMemory.secs[k]
            n++, idx[String(n)] := {sec: k, item: it}
    }
    return idx
}

; ---- 解析学习回复：只认 ADD / DEL / NONE，其余一律丢弃 ----
RunBoxParseLearnReply(reply) {
    res := {adds: [], dels: [], none: false, dropped: []}
    fence := Chr(96) . Chr(96) . Chr(96)
    txt := StrReplace(reply, fence, "")
    for rawLine in StrSplit(txt, "`n", "`r") {
        s := rawLine
        if (Trim(s) = "")
            continue
        s := Trim(RegExReplace(s, "^\s*(?:\d+\s*[\.\)、]|[-*+])\s*", ""))
        if (s = "")
            continue
        if RegExMatch(s, "i)^NONE\s*$") {
            res.none := true
            continue
        }
        if RegExMatch(s, "i)^DEL\s*[:：]?\s*(\d+)\s*$", &dm) {
            res.dels.Push(Integer(dm[1]))
            continue
        }
        if RegExMatch(s, "i)^ADD\s+(alias|pref|example|counter)\s*[:：]\s*(.*)$", &am) {
            kind := StrLower(am[1])
            body := Trim(am[2])
            if (body = "") {
                res.dropped.Push(s . "   ← 内容为空")
                continue
            }
            if (kind = "alias") {
                if !RegExMatch(body, "^(.*?)\s*=>\s*(.*)$", &am2) {
                    res.dropped.Push(s . "   ← 别名必须写成：说法 => 目标")
                    continue
                }
                l := Trim(am2[1]), r := Trim(am2[2])
                if (StrLen(l) < 1 || r = "") {
                    res.dropped.Push(s . "   ← 说法或目标为空")
                    continue
                }
                res.adds.Push({kind: "alias", left: l, right: r})
                continue
            }
            if (kind = "pref") {
                res.adds.Push({kind: "pref", left: body, right: ""})
                continue
            }
            ; example / counter：需求：X → Y
            if !RegExMatch(body, "^(.*?)\s*(?:→|->|=>)\s*(.*)$", &am3) {
                res.dropped.Push(s . "   ← 示例必须写成：需求：X → Y")
                continue
            }
            l := Trim(RegExReplace(Trim(am3[1]), "^(需求|例子)\s*[:：]\s*", ""))
            r := Trim(am3[2])
            if (l = "" || r = "") {
                res.dropped.Push(s . "   ← 需求或结果为空")
                continue
            }
            res.adds.Push({kind: (kind = "counter" ? "counter" : "example"), left: l, right: r})
            continue
        }
        res.dropped.Push(s . "   ← 不是 ADD / DEL / NONE 行，已忽略")
    }
    return res
}

; ---- 校验并生成"记忆变更计划"（纯预览，不落盘）----
; 返回 {addSec, adds: [{sec, text, canonical, sortKey, note}], delSec, dels: [{sec, item, text, n}],
;        rejected: [文字], listSeq: Map}
RunBoxMemoryPlan(parsed) {
    global runboxMemory
    plan := {adds: [], dels: [], rejected: [], dup: 0}
    ; 白名单：别名目标 / 示例结果都必须能在配置里找到（记忆不能凭空造动作）
    RunBoxAllowedMaps(&allowedAct, &allowedName)
    ; 先算"现有条目"的键，用来去重（别名看 说法+目标，示例看 需求+结果）
    existing := Map()
    for k in ["alias", "pref", "pos", "neg"]
        for it in runboxMemory.secs[k]
            existing[k . "|" . it.sortKey] := true
    ; 序号映射（DEL 引用）
    idxMap := RunBoxMemoryIndexMap()

    for a in parsed.adds {
        if (a.kind = "alias") {
            why := ""
            acts := RunBoxAliasResolveTarget(a.right, allowedAct, allowedName, &why)
            if (acts.Length = 0) {
                plan.rejected.Push("别名「" . a.left . " => " . a.right . "」被拒绝：" . why)
                continue
            }
            it := RunBoxMemoryParseItem("- " . a.left . " => " . a.right, "alias")
            if (existing.Has("alias|" . it.sortKey)) {
                plan.dup++
                continue
            }
            plan.adds.Push({sec: "alias", canonical: it.canonical, sortKey: it.sortKey, text: "- " . it.text})
            continue
        }
        if (a.kind = "pref") {
            it := RunBoxMemoryParseItem("- " . a.left, "pref")
            if (existing.Has("pref|" . it.sortKey)) {
                plan.dup++
                continue
            }
            ; 偏好是自由文本，只做最基本的护栏：不许按键语法、不许过长
            if (RegExMatch(a.left, "[``\r\n]") || StrLen(a.left) > 200) {
                plan.rejected.Push("偏好条目被拒绝（含非法字符或过长）：" . SubStr(a.left, 1, 40))
                continue
            }
            plan.adds.Push({sec: "pref", canonical: it.canonical, sortKey: it.sortKey, text: "- " . it.text})
            continue
        }
        ; example / counter
        sec := (a.kind = "counter") ? "neg" : "pos"
        it := RunBoxMemoryParseItem("- 需求：" . a.left . " → " . a.right, sec)
        if (existing.Has(sec . "|" . it.sortKey)) {
            plan.dup++
            continue
        }
        ; 结果必须"可解释"：要么是配置里的名称，要么是动作行，要么是"不要选 X / 不要用 X"
        if RegExMatch(a.right, "^(不要|别|勿)") {
            ; 反例：允许，但把被否掉的目标也校验一下（校验失败只提示，不拦整条）
            bad := RegExReplace(a.right, "^(不要选|不要用|不要|别选|别|勿)\s*", "")
            bad := Trim(RegExReplace(bad, "[（(].*?[）)]", ""))
            if (bad != "") {
                w2 := ""
                if (RunBoxAliasResolveTarget(bad, allowedAct, allowedName, &w2).Length = 0)
                    plan.rejected.Push("反例里的目标「" . bad . "」当前不在动作表里（条目仍会记下，但请核对：" . w2 . "）")
            }
            plan.adds.Push({sec: sec, canonical: it.canonical, sortKey: it.sortKey, text: "- " . it.text})
            continue
        }
        if (RegExMatch(a.right, "i)^(item|url|run|self|paste|send|hotkey)\s*:")) {
            w2 := ""
            if (RunBoxAliasResolveTarget(a.right, allowedAct, allowedName, &w2).Length = 0) {
                plan.rejected.Push("示例「" . a.left . " → " . a.right . "」被拒绝：" . w2)
                continue
            }
        } else if (OverlayLookupItem(a.right) = 0) {
            ; 纯文本输出（要网址 / 要一段话）也算合法结果：只在"含按键语法"时才拒绝
            if RegExMatch(a.right, "[\^!+#{}]") {
                plan.rejected.Push("示例「" . a.left . " → " . a.right . "」被拒绝：结果含按键语法，且不在动作表里")
                continue
            }
        }
        plan.adds.Push({sec: sec, canonical: it.canonical, sortKey: it.sortKey, text: "- " . it.text})
    }

    for n in parsed.dels {
        e := idxMap.Has(String(n)) ? idxMap[String(n)] : 0
        if (e = 0) {
            plan.rejected.Push("DEL " . n . " 被拒绝：当前记忆清单里没有这个序号")
            continue
        }
        plan.dels.Push({sec: e.sec, sortKey: e.item.sortKey, n: n, text: e.item.canonical})
    }
    return plan
}

; ---- 读"命中计数"（Object 没有 .Has()，属性缺失直接读会抛异常，IsSet 也不吃属性）----
; AHK v2 里判断 Object 有没有某个属性，只能用 .HasOwnProp()；这里统一走它，别图省事直读。
RunBoxMemoryItemCount(it) {
    c := 0
    try {
        if (it.HasOwnProp("count"))
            c := (it.count = "" ? 0 : it.count)
    } catch {
        c := 0
    }
    return c
}

; ---- 安全复制一条记忆条目 ----
RunBoxMemoryItemCopy(it) {
    return {left: it.left, right: it.right, text: it.text, canonical: it.canonical
        , sortKey: it.sortKey, count: RunBoxMemoryItemCount(it)}
}

; ---- 生成变更后的一份**完整记忆模型**（不落盘、不改全局；纯函数，便于单测）----
RunBoxMemoryApplyPlan(plan) {
    global runboxMemory
    m := RunBoxMemoryNewModel()
    m.loaded := true
    m.path := runboxMemory.path
    m.head := []
    for h in runboxMemory.head
        m.head.Push(h)
    for k, arr in runboxMemory.secs {
        if (k = "raw") {
            for r in arr
                m.secs["raw"].Push(r)
            continue
        }
        for it in arr
            m.secs[k].Push(RunBoxMemoryItemCopy(it))
    }
    ; 先删（按 sortKey 精确删除，一次删一条）。
    ; **必须用"整条对象引用"来删**：RunBoxMemoryIndexMap 取到的就是数组里那个对象本身，
    ; 直接 RemoveAt 它的下标即可；用 sortKey 二次匹配反而会在"同段内有两条相同的
    ; 需求文本"时删错第一条（示例段是允许重复说法的）。
    for d in plan.dels {
        arr := m.secs[d.sec]
        Loop arr.Length {
            it := arr[A_Index]
            if (it.sortKey = d.sortKey) {
                arr.RemoveAt(A_Index)
                break
            }
        }
    }
    ; 再增（同段里已有完全相同的一条就跳过；计数写成 m.dupSkipped，避免改 plan 造成重复计数）
    m.dupSkipped := 0
    for a in plan.adds {
        dup := false
        for it in m.secs[a.sec]
            if (it.sortKey = a.sortKey)
                dup := true
        if (dup) {
            m.dupSkipped++
            continue
        }
        it := RunBoxMemoryParseItem(a.canonical, a.sec)
        m.secs[a.sec].Push(it)
    }
    return m
}

; ---- 变更清单（给人看的一行行文字，也写进"执行过程"）----
RunBoxMemoryPlanDiff(plan) {
    out := []
    for a in plan.adds
        out.Push("  + [" . RunBoxMemorySectionName(a.sec) . "] " . a.text)
    for d in plan.dels
        out.Push("  - [" . RunBoxMemorySectionName(d.sec) . "] " . d.text)
    for r in plan.rejected
        out.Push("  ✗ " . r)
    if (plan.dup > 0)
        out.Push("  （" . plan.dup . " 条重复条目已自动跳过）")
    return out
}

; ============================================================================
; 运行流水（runbox_learn.log）：只追加、不参与提示语
; ----------------------------------------------------------------------------
; 本期**只写不读** —— 先把真实数据攒起来，自动整理（隐式学习）留给下一期。
; 制表符分隔；字段里的制表符 / 换行转义成 \t / \n，保证一行一条记录。
; 字段：时间 / 需求原文 / 结果（动作序列或结局）/ 丢弃行数 / ERROR / 别名命中 / 结局说明 /
;       本次用到的记忆（"别名N条/记忆块M字" 或 "无"）
; ============================================================================
RunBoxJournalAppend(fields) {
    global runboxLearnJournal
    f := Trim(runboxLearnJournal)
    if (f = "")
        return
    path := (RegExMatch(f, "^[A-Za-z]:[\\/]") || SubStr(f, 1, 2) = "\\") ? f : A_ScriptDir . "\" . f
    row := RunBoxNowStampFull()
    for v in fields
        row .= "`t" . RunBoxJournalEscape(v)
    try FileAppend(row . "`n", path, "UTF-8")
}

RunBoxNowStampFull() {
    return FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
}

RunBoxJournalEscape(s) {
    t := StrReplace(String(s), "`t", "\t")
    t := StrReplace(t, "`r", "")
    t := StrReplace(t, "`n", "\n")
    return t
}

; 把本次需求的结局写进流水（每次需求只写一次；收尾时若还没写就补写）
RunBoxJournalFlush(finalMsg) {
    global runboxLastJournaled, runboxLastReq, runboxLastActions, runboxLastDropped
    global runboxLastAliasHit, runboxLastErrText
    if (runboxLastJournaled || runboxLastReq = "")
        return
    res := []
    for a in runboxLastActions
        res.Push(RunBoxActionLine(a))
    if (res.Length = 0)
        res.Push((finalMsg != "") ? finalMsg : "（没有动作）")
    RunBoxJournalAppend([runboxLastReq, RunBoxJoinList(res, " / "), runboxLastDropped.Length
        , runboxLastErrText, (runboxLastAliasHit != "" ? runboxLastAliasHit : "-"), finalMsg
        , runboxLastMemoryNote])
    runboxLastJournaled := true
}

; ============================================================================
; 执行：学习流程（反馈 → 模型整理条目 → 校验 → 用户确认 → 原子落盘）
; ============================================================================
RunBoxLearningStart(feedback) {
    global runboxState, runboxBusy, runboxLearnBusy, runboxLog
    global runboxLastReq, runboxLastActions, runboxLastResult, runboxLearnArmed
    global runboxPrevWin, runboxTimeout
    if (runboxLearnBusy || runboxBusy)
        return
    runboxLearnArmed := false
    runboxLog := []
    RunBoxLogAdd("[反馈] " . feedback)
    runboxLearnBusy := true
    runboxState := "learning"
    RunBoxInputVisible(false)
    RunBoxSetStatus("正在把你的反馈整理成记忆条目…（最长 " . Round(runboxTimeout / 1000) . " 秒）")
    ; 反馈请求期间把焦点还给原窗口，不占着用户的编辑器
    if (runboxPrevWin)
        RadialActivateFocusWin(runboxPrevWin)

    lastActs := []
    for a in runboxLastActions
        lastActs.Push(RunBoxActionLine(a))
    up := "用户对运行框的反馈：" . feedback . "`n"
    up .= "（上一次需求：" . (runboxLastReq = "" ? "（本次会话没有记录）" : runboxLastReq) . "）`n"
    up .= "（上一次程序理解成的动作：" . (lastActs.Length = 0 ? "（无）" : RunBoxJoinList(lastActs, " / ")) . "）`n"
    up .= "（上一次的结局：" . (runboxLastResult = "" ? "（无记录）" : runboxLastResult) . "）`n"
    up .= "请按格式输出记忆条目。"

    result := "", reasoning := "", errMsg := ""
    sysPrompt := RunBoxBuildLearnPrompt()
    ok := RunBoxAskModel(up, sysPrompt, &result, &reasoning, &errMsg, true)   ; true = 本请求用 learn_model
    runboxLearnBusy := false
    if (!ok) {
        DebugLog("[runbox] 学习请求失败：" . errMsg)
        RunBoxBackToInput("整理记忆失败：" . errMsg, "", false)
        return
    }
    RunBoxLogModelReply("记忆整理", result, reasoning)
    parsed := RunBoxParseLearnReply(result)
    for d in parsed.dropped
        RunBoxLogAdd("[忽略] " . d)
    if (parsed.none || (parsed.adds.Length = 0 && parsed.dels.Length = 0)) {
        DebugLog("[runbox] 学习：模型认为这条反馈与记忆无关")
        RunBoxBackToInput("这条反馈没有产生可用的记忆变更（详见执行过程）", "", false)
        return
    }
    plan := RunBoxMemoryPlan(parsed)
    RunBoxLearnShowDiff(plan)
}

; ---- 展示"将新增/删除哪些条目"；learn_confirm = true 时等用户回车确认 ----
RunBoxLearnShowDiff(plan) {
    global runboxState, runboxLearnConfirm, runboxLearnPlan
    diff := RunBoxMemoryPlanDiff(plan)
    RunBoxLogAdd("[记忆变更] 将新增 " . plan.adds.Length . " 条 / 删除 " . plan.dels.Length . " 条：")
    for line in diff
        RunBoxLogAdd("      " . line)
    if (plan.adds.Length = 0 && plan.dels.Length = 0) {
        DebugLog("[runbox] 学习：没有任何可用变更")
        RunBoxBackToInput("这条反馈没有产生可用的记忆变更"
            . (plan.rejected.Length > 0 ? "（" . plan.rejected.Length . " 条被拒绝，详见执行过程）" : "")
            , "", false)
        return
    }
    if (!runboxLearnConfirm) {
        RunBoxLearnApply(plan)
        return
    }
    runboxLearnPlan := plan
    runboxState := "learnconfirm"
    RunBoxSetStatus("将新增 " . plan.adds.Length . " 条、删除 " . plan.dels.Length . " 条记忆"
        . (plan.rejected.Length > 0 ? "（" . plan.rejected.Length . " 条被拒绝）" : "")
        . "：回车写入，Esc 取消；点下方把手看明细")
    RunBoxInputVisible(true)
    RunBoxFocusInput()
}

; ---- 落盘（确认后 / learn_confirm = false 时直接走这里）----
RunBoxLearnApply(plan) {
    global runboxState, runboxLearnPlan, runboxLastJournaled
    m := RunBoxMemoryApplyPlan(plan)
    okSave := RunBoxMemorySave(m, "学习")
    RunBoxInputVisible(true)
    if (!okSave) {
        runboxState := "input"
        RunBoxSetStatus("记忆写入失败（详见 debug.log）；原文件未改动")
        return
    }
    RunBoxMemoryLoad(true)                    ; 让新记忆立刻生效（含别名索引）
    runboxState := "input"
    runboxLastJournaled := true                ; 反馈本身不写运行流水
    RunBoxSetStatus("记忆已更新：新增 " . plan.adds.Length . " 条、删除 " . plan.dels.Length
        . " 条（已自动备份，可用 self:runbox_memory_undo 回滚）")
    runboxLearnPlan := 0
    DebugLog("[runbox] 学习完成：新增 " . plan.adds.Length . " 条 / 删 " . plan.dels.Length . " 条")
}

; ---- 回车在"待确认记忆变更"态 = 写入 ----
RunBoxLearnConfirmGo() {
    global runboxLearnPlan, runboxState
    if (runboxState != "learnconfirm" || !runboxLearnPlan)
        return
    RunBoxLearnApply(runboxLearnPlan)
}

; ---- 取消待确认的记忆变更 ----
RunBoxLearnCancel() {
    global runboxLearnPlan, runboxState
    runboxLearnPlan := 0
    runboxState := "input"
    RunBoxSetStatus("已取消，记忆未改动")
}

; ---- 学习态下 Esc：取消学习，不关闭运行框 ----
RunBoxLearnAbort() {
    global runboxLearnBusy, runboxLearnArmed, runboxState
    runboxLearnBusy := false
    runboxLearnArmed := false
    runboxState := "input"
    RunBoxInputVisible(true)
    RunBoxSetStatus("已取消")
}

; ---- 键帽【纠正】(self:runbox_learn)：下一次输入按反馈处理 ----
RunBoxLearnArm() {
    global runboxLearnArmed, runboxState, runboxBusy, runboxLearnBusy
    if (!RunBoxHwnd())
        return
    ; 正在解析 / 执行 / 整理记忆时不要"武装"反馈：否则这次请求的结果会被
    ; 下一次输入当成反馈内容处理，用户会看到"我说的话怎么变成改记忆了"。
    ; 与 RunBoxSubmit / RunBoxLearningStart 的守卫保持一致。
    if (runboxBusy || runboxLearnBusy) {
        DebugLog("[runbox] 反馈模式被忽略：当前正忙（state=" . runboxState . "）")
        RunBoxSetStatus("正在忙（解析 / 执行 / 整理记忆中），稍后再按【纠正】")
        return
    }
    runboxLearnArmed := true
    if (runboxState = "" || runboxState = "done")
        runboxState := "input"
    RunBoxFocusInput()
    RunBoxSetStatus("反馈模式：说一下哪里不对 / 该怎么做（例如“以后我说录屏就是 Captura”），回车提交；Esc 取消")
    DebugLog("[runbox] 已进入反馈模式（self:runbox_learn）")
}

; ---- 运行框自身的 self: 命令（由 OverlayRunSelf 分发过来）----
RunBoxSelfCommand(c) {
    if (c = "runbox_learn") {
        RunBoxLearnArm()
        return true
    }
    if (c = "runbox_memory_reload") {
        RunBoxMemoryLoad(true)
        RunBoxSetStatus("记忆已重新加载：" . RunBoxMemoryPath())
        DebugLog("[runbox] self:runbox_memory_reload")
        return true
    }
    if (c = "runbox_memory_undo") {
        msg := RunBoxMemoryUndo()
        RunBoxSetStatus(msg)
        DebugLog("[runbox] self:runbox_memory_undo → " . msg)
        return true
    }
    if (c = "runbox_memory_show") {
        RunBoxShowMemory()
        return true
    }
    return false
}

; ---- 把当前记忆塞进"执行过程"面板（self:runbox_memory_show）----
RunBoxShowMemory() {
    global runboxMemory, runboxExpanded
    if (!RunBoxHwnd()) {
        DebugLog("[runbox] self:runbox_memory_show：运行框未打开，忽略")
        return
    }
    RunBoxLogAdd("[记忆] " . RunBoxMemoryPath())
    RunBoxLogAdd("[记忆] 共 " . RunBoxMemoryCount(runboxMemory) . " 条（别名 "
        . runboxMemory.secs["alias"].Length . " / 偏好 " . runboxMemory.secs["pref"].Length
        . " / 正例 " . runboxMemory.secs["pos"].Length . " / 反例 " . runboxMemory.secs["neg"].Length . "）")
    for line in StrSplit(RunBoxMemoryListing(), "`n")
        RunBoxLogAdd("      " . line)
    if (!runboxExpanded) {
        runboxExpanded := true
        RunBoxApplyHeight()
    }
    RunBoxRenderLog()
    RunBoxSetStatus("记忆清单已写入执行过程（" . RunBoxMemoryCount(runboxMemory) . " 条）")
}

; ============================================================================
; 诊断：把"模型会收到的提示语"写到文件（--dump-runbox-prompt）
; ============================================================================
RunBoxDumpPrompt(req := "") {
    out := A_ScriptDir . "\runbox_prompt_dump.txt"
    p := RunBoxBuildPrompt(req)
    memBody := RunBoxMemoryBlockText(req, &used, &dropped)
    txt := "===== 需求 =====`n" . (req = "" ? "(未提供)" : req) . "`n`n"
    txt .= "===== 记忆块（" . StrLen(memBody) . " 字，裁剪 " . dropped . " 条）=====`n" . memBody . "`n`n"
    txt .= "===== 系统提示语（" . StrLen(p) . " 字）=====`n" . p . "`n"
    try {
        f := FileOpen(out, "w", "UTF-8-RAW")
        f.Write(Chr(0xFEFF))
        f.Write(txt)
        f.Close()
    } catch Error as e {
        try FileAppend("dump 失败：" . e.Message . "`n", out, "UTF-8")
    }
    DebugLog("[runbox] 提示语已写入 " . out)
    return out
}


; ---- 白名单表：已配置动作（圆盘菜单 + 四块小键盘）→ 两张查表 ----
;   allowedAct ："动作类型|动作内容" → 配置里的原始写法（执行时用配置的写法，保证执行的就是配置里的动作）
;   allowedName：配置项名 → 它自己（名称精确区分大小写）
; 供 RunBoxParseReply（解析模型回复）与 RunBoxAliasResolve（别名快路径）共用：
; **两处必须是同一套白名单**，否则"记忆里能命中、执行时却被丢弃"这种错法会很难查。
RunBoxAllowedMaps(&allowedAct, &allowedName) {
    allowedAct := Map()
    allowedName := Map()
    for it in OverlayConfiguredItems() {
        raw := Trim(it.action)
        if (raw != "") {
            a := OverlayActionParse(raw)
            if (a.type != "none") {
                ; 键保留原样大小写：动作必须与配置"逐字一致"（a 与 A 是不同的动作）
                k := a.type . "|" . a.value
                if (!allowedAct.Has(k))
                    allowedAct[k] := raw
            }
        }
        nm := Trim(it.name)
        if (nm != "")
            allowedName[nm] := nm          ; 名字也精确区分大小写
    }
}

; ---- 解析模型回复：纯文本放行 + 动作严格白名单 ----
; 需求分两种情况：① 要输出文字（显式 send: / paste:）→ 直接执行、照原样输出，不需要先配置；
;                 ② 要执行动作（按键 / 热键 / 键盘操作 / 程序 / 自身功能）→ 必须命中"配置里已有的动作"。
; 返回 {actions: [...], dropped: [...], error: ""}；error 非空表示模型明确说做不到
RunBoxParseReply(reply) {
    global runboxMaxActions
    actions := []
    dropped := []
    errText := ""
    contIdx := 0                     ; > 0 表示"上一行是输出文字"，随后的裸行按续行处理（见 ②-2）

    ; ---------- 白名单：只承认"配置里已有的动作"（圆盘菜单 + 四块小键盘）----------
    ; 构建逻辑抽到 RunBoxAllowedMaps()：**别名快路径与运行框解析共用同一套白名单**，
    ; 避免两处各写一份而慢慢走样（记忆同样不得凭空造动作）。
    RunBoxAllowedMaps(&allowedAct, &allowedName)

    fence := Chr(96) . Chr(96) . Chr(96)     ; markdown 代码块围栏（三个反引号）
    txt := StrReplace(reply, fence, "")      ; 容忍模型套代码块
    if RegExMatch(txt, "i)ERROR\s*[:：]\s*([^\r\n]*)", &em)
        errText := Trim(em[1])
    ; NOACTION：模型按约定表示"这是操作类需求，但动作表里没有对应动作" → 调用方转入兜底文字判定
    ; （写宽松些：NOACTION / NO ACTION / NO-ACTION 都认）
    noAction := (errText != "" && RegExMatch(errText, "i)^\s*no[\s_-]*action"))

    if (errText = "") {
        if (allowedAct.Count = 0 && allowedName.Count = 0)
            dropped.Push("（配置里没有任何可用动作，无法执行——请先在 config.ini 里配置小键盘 / 圆盘菜单项）")
        Loop parse, txt, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line = "")
                continue
            ; 容忍模型自作主张加的行首编号 / 项目符号
            line := Trim(RegExReplace(line, "^\s*(?:\d+\s*[\.\)、]|[-*+])\s*", ""))
            if (line = "")
                continue

            ; ① item: 名称 —— 名称必须是配置里有的
            if RegExMatch(line, "i)^item\s*:(.*)$", &m) {
                nm := Trim(m[1])
                if (allowedName.Has(nm))
                    actions.Push({type: "item", value: allowedName[nm]})
                else
                    dropped.Push(line . "   ← 配置里没有这个名称（名称区分大小写）")
                contIdx := 0
                continue
            }

            ; ② 纯文本输出（需求的第一种情况）：
            ;    显式写 send: / hotkey: / paste: 就是"要输出的文字"，直接执行、不需要先在配置里建项，
            ;    且必须照原样输出（模型不得改写）。其余任何情况（要按键 / 热键 / 程序 / 自身功能）
            ;    都算"动作"，必须命中下面的「已配置动作表」。
            ;    · paste: 是文本通道：内容一律原样粘贴，含 ^ ! + # { } 等符号也安全；
            ;    · send: / hotkey: 只放行"不含按键语法（^ ! + # { }）"的纯文本；
            ;      含按键语法的（如 send: ^c）算按键操作，仍须与配置里某个动作逐字一致。
            ;    · 多行文字：按提示语约定，换行写成**字面的 \n**（仍是同一行），这里还原成真换行，
            ;      于是整段文字只占一条动作、一次粘贴就输出完整内容。
            if RegExMatch(line, "i)^(?:send|hotkey|paste)\s*:(.*)$", &fm) {
                fv := Trim(fm[1])
                fv := StrReplace(fv, "\n", "`n")        ; 还原转义换行（AHK 里 "\n" 就是反斜杠 + n）
                fv := Trim(fv, " `t`r`n")               ; 还原后可能多出首尾空行，去掉
                if (fv = "") {
                    dropped.Push(line . "   ← 内容是空的")
                    contIdx := 0
                    continue
                }
                if RegExMatch(line, "i)^paste\s*:") {
                    actions.Push({type: "paste", value: fv})
                    contIdx := actions.Length           ; 后续紧跟的裸行按续行拼进来
                    continue
                }
                if (!RegExMatch(fv, "[\^!+#{}]")) {
                    actions.Push({type: "send", value: fv})
                    contIdx := actions.Length
                    continue
                }
            }

            ; ②-2 续行（多行文字的第二条通路）：紧跟在"输出文字"那一条之后、
            ;      既不是动作（没有前缀）、又不命中配置里的动作 / 名称、也不含按键语法的裸行，
            ;      当作上一段文字的续行，用换行拼进同一条 paste，保证一次粘贴、换行不丢。
            isBare := !RegExMatch(line, "i)^(?:item|paste|send|hotkey|run|self|wait)\s*:")
            if (isBare && contIdx > 0 && !RegExMatch(line, "[\^!+#{}]")
                && !allowedName.Has(line) && !allowedAct.Has("send|" . line)) {
                actions[contIdx].value .= "`n" . line
                continue
            }

            ; ③ 其余行：动作必须"逐字"等于配置里的某个动作
            act := OverlayActionParse(line)
            ; 裸写一个配置里的名称，也当 item: 处理（宽容但同样安全）
            if (isBare && allowedName.Has(line)) {
                actions.Push({type: "item", value: allowedName[line]})
                contIdx := 0
                continue
            }
            if (act.type = "none") {
                low := StrLower(line)
                if (low = "close" || low = "case")
                    dropped.Push(line . "   ← 本场景不使用 close / case")
                else
                    dropped.Push(line . "   ← 不在「已配置动作」中，未执行")
                contIdx := 0
                continue
            }
            k := act.type . "|" . act.value        ; 精确匹配（区分大小写）
            if (allowedAct.Has(k)) {
                actions.Push(OverlayActionParse(allowedAct[k]))    ; 用配置里的原始写法执行
                contIdx := 0
                continue
            }
            if (act.type = "run" || act.type = "self")
                dropped.Push(line . "   ← 不在「已配置命令表」中")
            else if (act.type = "wait")
                dropped.Push(line . "   ← 等待由程序自动插入，不需要写 wait:（它也不在配置的动作里）")
            else if (RegExMatch(line, "[\^!+#{}]"))
                dropped.Push(line . "   ← 含按键语法、且不在「已配置动作」中，未执行（纯文本请用 paste:）")
            else
                dropped.Push(line . "   ← 不在「已配置动作」中，未执行（如果是想输出的文字，请写成 paste:，或紧跟在 paste: 行后面）")
            contIdx := 0
        }
    }

    ; ---------- 危险动作"不得被组合"的**硬拦截**（2026-09-19 用户定稿）----------
    ; 为什么要有这一道（实测教训）：提示语里已经把危险项标成 ⚠危险 并要求"不得编进组合"，
    ; 但模型**会不听**——实测"清空这个文件夹"它给出 [全选 → 删除 → 回车]、
    ; "剪切并粘到上一级"给出 [剪切 → 上箭头 → 粘贴]，这些序列会被原样执行。
    ; 所以提示语只是软约束，真正的保障必须在程序里。
    ; 规则（与用户确认的边界一致）：
    ;   · 序列里**只有一条**动作时：那是用户在明确要求这件事 → 照常执行，不拦；
    ;   · 序列里**多条**动作时：其中的危险动作属于"被编进组合" → 丢弃该行并说明原因。
    ; 这样"删除这个文件"仍然可用（单条），而"顺手帮你删掉"会被拦下。
    if (actions.Length > 1) {
        kept := []
        for a in actions {
            ; item: 的话取回配置项，用它的「名称 + 动作文本」判危险；
            ; 非 item 的（send 等）直接看动作文本本身。
            ; 注意别用 OverlayActionText()：那个函数吃的是圆盘菜单项对象（actionType/actionValue），
            ; 而 OverlayConfiguredItems() 给的是 {name, action, source}——字段不同，混用会抛
            ; "has no property named actionType"（2026-09-19 实测踩到）。
            nm := "", actTxt := a.value
            if (a.type = "item") {
                ref := OverlayLookupItem(a.value)
                if (ref) {
                    nm := ref.name
                    actTxt := ref.action
                }
            }
            if (RunBoxIsDangerous(nm, actTxt)) {
                dropped.Push(RunBoxActionLine(a) . "   ← ⚠危险动作不得被编进组合（用户未明确要求做这件事）；如确需，请单独提出这一条需求")
                continue
            }
            kept.Push(a)
        }
        actions := kept
    }

    if (actions.Length > runboxMaxActions) {
        dropped.Push("（模型给出 " . actions.Length . " 条，超过上限 " . runboxMaxActions . "，只执行前 " . runboxMaxActions . " 条）")
        trimmed := []
        Loop runboxMaxActions
            trimmed.Push(actions[A_Index])
        actions := trimmed
    }
    return {actions: actions, dropped: dropped, error: errText, noAction: noAction}
}

; ============================================================================
; 运行框的窗口层（2026-09-18 改造）
; ----------------------------------------------------------------------------
; 目标：除了**输入框本身**，运行框其余部分都跟小键盘 / 圆盘 / 键帽排一样 ——
;   面板底受 [runbox] opacity 控制；面板上的文字（提示行 / 状态行 / 把手 / 执行过程日志）
;   一律"彩色字身 + 黑边"且**恒不透明**。
;
; 为什么必须拆成三个窗口（Windows 的硬约束）：
;   LWA_ALPHA 是按**整个顶层窗口**（含其所有子控件）施加的，子控件没法单独豁免。所以：
;     ① runboxGui     面板：GDI 自绘底色 + 1px 边框 + 圆角，整窗 LWA_ALPHA = opacity，**不画文字**；
;     ② runboxTextGui 文字层：UpdateLayeredWindow（与径向菜单 / 小键盘文字层同一套），
;                      逐像素 alpha：文字与黑边 255、其余 0 → 完全不受 opacity 影响；
;     ③ runboxInputGui 输入框窗口：独立顶层窗口、不带 layered → **整块不透明**（白底黑字）。
;     ④ runboxLogGui   执行过程窗口：同样独立、不透明，里面是只读多行 Edit
;                      （用户实测要求：能选中 / Ctrl+C 复制 / 滚动条翻阅）。
;   四者始终一起移动（RunBoxSyncWindows），并作为整体参与浮层避让（OverlayRects 里的 "runbox"）。
; ============================================================================

; ---- 布局：面板 / 输入框 / 状态 / 把手 / 日志的矩形（客户区坐标）----
; 只在窗口创建时算一次（缓存到 runboxLayout），后续都复用它。
; 注意函数名不能叫 RunBoxLayout —— AHK v2 变量名大小写不敏感，会和全局 runboxLayout 冲突。
RunBoxComputeLayout() {
    global runboxLayout, ui_font_size
    if (runboxLayout)
        return runboxLayout
    pad := 10
    w := 580                                  ; 与改造前一致（560 控件宽 + 两侧各 10 边距）
    innerW := w - 2 * pad
    sub := Max(ui_font_size - 2, 8)           ; 状态行字号（2026-09-18 用户反馈"看着费劲"：11pt → 13pt）
    hintH := RadialMeasureText("用中文描述你要做的操作（回车交给模型解析，Esc 取消）：", ui_font_size).h
    inputH := Max(RadialMeasureText("Ag", ui_font_size).h + 10, 24)
    statusH := RadialMeasureText("可用动作：send: / hotkey: / paste: / item: / run: / self:", sub).h
    handleH := RadialMeasureText("▼ 执行过程（点击展开）", ui_font_size).h
    lineH := RadialMeasureText("Ag", sub).h + 1
    logH := lineH * 14                        ; 与改造前 r14 的过程面板相当
    gap := 8
    y := pad
    hint := {x: pad, y: y, w: innerW, h: hintH}
    y += hintH + gap
    input := {x: pad, y: y, w: innerW, h: inputH}
    y += inputH + gap
    status := {x: pad, y: y, w: innerW, h: statusH}
    y += statusH + gap
    handle := {x: pad, y: y, w: innerW, h: handleH}
    y += handleH
    hSmall := y + pad
    y += gap
    log := {x: pad, y: y, w: innerW, h: logH}
    hBig := y + logH + pad
    runboxLayout := {w: w, hSmall: hSmall, hBig: hBig, pad: pad, gap: gap, sub: sub
        , hint: hint, input: input, status: status, handle: handle, log: log}
    return runboxLayout
}

; ---- 面板窗口当前应有的高度 ----
RunBoxPanelHeight() {
    global runboxLayout, runboxExpanded
    if (!runboxLayout)
        return 0
    return runboxExpanded ? runboxLayout.hBig : runboxLayout.hSmall
}

; ---- 面板透明度：整窗 LWA_ALPHA（文字不在这个窗口上，所以只影响底色 / 边框）----
RunBoxApplyOpacity(hwnd) {
    global runboxOpacity
    if (!hwnd)
        return
    if ((runboxOpacity + 0) >= 1.0)
        return
    GWL_EXSTYLE := -20
    WS_EX_LAYERED := 0x00080000
    getWindowLongFn := (A_PtrSize = 8) ? "GetWindowLongPtrW" : "GetWindowLongW"
    setWindowLongFn := (A_PtrSize = 8) ? "SetWindowLongPtrW" : "SetWindowLongW"
    ex := DllCall(getWindowLongFn, "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
    DllCall(setWindowLongFn, "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr", ex | WS_EX_LAYERED, "Ptr")
    alpha := Max(0, Min(Round(runboxOpacity * 255), 255))
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", alpha, "UInt", 0x2)
}

; ---- 把焦点（光标）交给输入框窗口 ----
RunBoxFocusInput() {
    global runboxInputGui, runboxEdit
    hw := 0
    if (runboxInputGui) {
        try hw := runboxInputGui.Hwnd
    }
    if (hw) {
        try WinActivate("ahk_id " . hw)
    }
    try runboxEdit.Focus()
}

; ---- 显示 / 隐藏整块输入框窗口 ----
; 解析期间原来是把 Edit 隐藏、露出深色面板底；现在输入框是白底黑字，
; 只藏 Edit 会留下一条白条，所以改成整块输入窗口一起隐藏 / 恢复。
RunBoxInputVisible(show) {
    global runboxInputGui, runboxEdit
    if (!runboxInputGui)
        return
    if (show) {
        try runboxInputGui.Show("NoActivate")      ; 恢复时不要抢焦点
        try runboxEdit.Visible := true
        RunBoxTextBoxes()                          ; 重新贴回输入框矩形
    } else {
        try runboxInputGui.Hide()
    }
}

; ---- 输入框窗口贴到面板上的"输入框矩形"（用客户区偏移换算，兼容有边框 / 阴影的情况）----
RunBoxTextBoxes() {
    global runboxGui, runboxInputGui, runboxLayout, runboxInOffX, runboxInOffY
    if (!runboxGui || !runboxInputGui || !runboxLayout)
        return
    L := runboxLayout
    runboxGui.GetPos(&wx, &wy)
    try runboxInputGui.Move(wx + L.input.x - runboxInOffX, wy + L.input.y - runboxInOffY)
}

; ---- 执行过程窗口贴到面板上的"日志矩形"（只在展开时有效）----
RunBoxLogBoxes() {
    global runboxGui, runboxLogGui, runboxLayout, runboxExpanded, runboxLogOffX, runboxLogOffY
    if (!runboxGui || !runboxLogGui || !runboxLayout || !runboxExpanded)
        return
    L := runboxLayout
    runboxGui.GetPos(&wx, &wy)
    try runboxLogGui.Move(wx + L.log.x - runboxLogOffX, wy + L.log.y - runboxLogOffY)
}

; ---- 执行过程窗口：展开就显示并贴到日志矩形，收起就隐藏 ----
RunBoxLogVisible() {
    global runboxLogGui, runboxExpanded
    if (!runboxLogGui)
        return
    if (runboxExpanded) {
        try runboxLogGui.Show("NoActivate")        ; 显示时不要抢输入框的焦点
        RunBoxLogBoxes()
    } else {
        try runboxLogGui.Hide()
    }
}

; ---- 四个窗口 + 键帽排一起对齐（面板移动 / 改高后必须调）----
RunBoxSyncWindows() {
    global runboxGui, runboxTextGui
    hw := RunBoxHwnd()
    if (!hw)
        return
    WinGetPos(&wx, &wy, , , "ahk_id " . hw)      ; 必须是面板窗口自己，不能用省略标题的写法
    RunBoxTextBoxes()
    RunBoxLogBoxes()
    OverlayTextLayerMove(runboxTextGui, wx, wy)
    RunKeysAnchor()
}

; ---- 重画文字层（文字内容 / 展开状态变化时调）----
RunBoxTextLayerPresent() {
    global runboxGui, runboxTextGui, runboxLayout
    if (!runboxGui || !runboxTextGui || !runboxLayout)
        return
    L := runboxLayout
    ; 文字层**固定只盖面板上半部分**（提示 / 状态 / 把手）：执行过程已经改回独立的不透明 Edit 窗口，
    ; 这样状态行高频刷新时不必再为整块展开区做逐像素合成。
    WinGetPos(&tx, &ty, , , "ahk_id " . runboxGui.Hwnd)
    OverlayTextLayerPresent(runboxTextGui, tx, ty, L.w, L.hSmall
        , (maskDC, colorDC, w, hh) => RunBoxPaintTexts(maskDC, colorDC))
}

; ---- 文字层"节流重绘"：状态行在执行期间更新频繁，而文字层是逐像素合成的，
;      所以做「首个请求立即重绘 + 250ms 内的后续请求合并成一次」----
RunBoxTextsChanged() {
    global runboxGui, runboxTextPending, runboxTextLastTick, runboxTextTimerOn
    if (!runboxGui)
        return
    runboxTextPending := true
    if (A_TickCount - runboxTextLastTick >= 250) {
        RunBoxTextsFlush()
    } else if (!runboxTextTimerOn) {
        runboxTextTimerOn := true
        SetTimer(RunBoxTextsFlush, -250)
    }
}

RunBoxTextsFlush() {
    global runboxGui, runboxTextPending, runboxTextLastTick, runboxTextTimerOn
    SetTimer(RunBoxTextsFlush, 0)
    runboxTextTimerOn := false
    if (!runboxGui || !runboxTextPending)
        return
    runboxTextPending := false
    runboxTextLastTick := A_TickCount
    RunBoxTextLayerPresent()
}

; ---- 状态行 / 把手文字的更新入口（原来的 Text 控件已取消）----
RunBoxSetStatus(text) {
    global runboxStatusText
    runboxStatusText := text
    RunBoxTextsChanged()
}

RunBoxSetHandle(text) {
    global runboxHandleText
    runboxHandleText := text
    RunBoxTextsChanged()
}

; ---- 画面板本体：底色 2D2D2D + 1px 浅灰边框（GDI 双缓冲；不画文字）----
RunBoxPanelDraw() {
    global runboxGui, runboxLayout
    if (!runboxGui || !runboxLayout)
        return
    hwnd := runboxGui.Hwnd
    L := runboxLayout
    h := RunBoxPanelHeight()
    if (h <= 0)
        return
    hdc := DllCall("GetDC", "Ptr", hwnd, "Ptr")
    if (!hdc)
        return
    memDC := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", L.w, "Int", h, "Ptr")
    oldBmp := DllCall("SelectObject", "Ptr", memDC, "Ptr", hbm, "Ptr")
    bgBrush := BrushSolid("2D2D2D")
    DllCall("FillRect", "Ptr", memDC, "Ptr", RectStruct(0, 0, L.w, h), "Ptr", bgBrush)
    DllCall("DeleteObject", "Ptr", bgBrush)
    bdBrush := BrushSolid("808080")
    DllCall("FrameRect", "Ptr", memDC, "Ptr", RectStruct(0, 0, L.w, h), "Ptr", bdBrush)
    DllCall("DeleteObject", "Ptr", bdBrush)
    DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", L.w, "Int", h
        , "Ptr", memDC, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("SelectObject", "Ptr", memDC, "Ptr", oldBmp, "Ptr")
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", memDC)
    DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
}

; ---- 文字层内容：提示行 / 状态行 / 把手（执行过程在独立 Edit 窗口里，不在这里画）----
; 配色 2026-09-18 按用户反馈整体提亮：提示 FFCB66→FFD98A、状态行 888888→E6E6E6、把手 88AADD→9EC8FF
RunBoxPaintTexts(maskDC, colorDC) {
    global runboxLayout, runboxStatusText, runboxHandleText, ui_font_size
    L := runboxLayout
    if (!L)
        return
    RunBoxDrawText(maskDC, colorDC, "用中文描述你要做的操作（回车交给模型解析，Esc 取消）："
        , L.hint, ui_font_size, "FFD98A", "left")
    RunBoxDrawText(maskDC, colorDC, runboxStatusText, L.status, L.sub, "E6E6E6", "left")
    RunBoxDrawText(maskDC, colorDC, runboxHandleText, L.handle, ui_font_size, "9EC8FF", "center")
}

; ---- 在 rect 内画一行文字：colorDC 画彩色字身，maskDC 画白色"字身 + 黑边" ----
RunBoxDrawText(maskDC, colorDC, text, R, sizePt, colorHex, align) {
    if (text = "")
        return
    font := RadialCreateFont(sizePt, "Microsoft YaHei")
    flags := 0x0004 | 0x0020 | 0x0800           ; DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX
    if (align = "center")
        flags |= 0x0001                         ; DT_CENTER
    ; 彩色层：字身
    old := DllCall("SelectObject", "Ptr", colorDC, "Ptr", font, "Ptr")
    DllCall("SetBkMode", "Ptr", colorDC, "Int", 1)
    DllCall("SetTextColor", "Ptr", colorDC, "UInt", BrushColorVal(colorHex))
    DllCall("DrawTextW", "Ptr", colorDC, "Str", text, "Int", -1
        , "Ptr", RectStruct(R.x, R.y, R.x + R.w, R.y + R.h), "UInt", flags)
    DllCall("SelectObject", "Ptr", colorDC, "Ptr", old, "Ptr")
    ; 掩码层：先画黑边偏移、最后画字身（保证字身覆盖度不被偏移的低覆盖盖掉）
    old := DllCall("SelectObject", "Ptr", maskDC, "Ptr", font, "Ptr")
    DllCall("SetBkMode", "Ptr", maskDC, "Int", 1)
    DllCall("SetTextColor", "Ptr", maskDC, "UInt", 0xFFFFFF)
    for off in OverlayTextOffsets(OverlayTextOutlineWidth())
        DllCall("DrawTextW", "Ptr", maskDC, "Str", text, "Int", -1
            , "Ptr", RectStruct(R.x + off.x, R.y + off.y, R.x + R.w + off.x, R.y + R.h + off.y), "UInt", flags)
    DllCall("DrawTextW", "Ptr", maskDC, "Str", text, "Int", -1
        , "Ptr", RectStruct(R.x, R.y, R.x + R.w, R.y + R.h), "UInt", flags)
    DllCall("SelectObject", "Ptr", maskDC, "Ptr", old, "Ptr")
    DllCall("DeleteObject", "Ptr", font)
}

; 执行过程从 2026-09-18 起改回**独立的不透明只读 Edit 窗口**（RunBoxLogGui / RunBoxLogEdit），
; 因为用户实测要求"能选中、能 Ctrl+C 复制、能滚动翻阅"——自绘文字做不到这些。
; 相应的自绘日志函数（RunBoxDrawLog / RunBoxDrawLogBlock / RunBoxLogTailText）已删除。

; ---- 面板拖动：自己实现（面板是 WS_EX_NOACTIVATE，交给系统 HTCAPTION 移动循环不可靠），
;      用定时器轮询光标与左键状态，不额外占用 WM_MOUSEMOVE 等公共消息 ----
RunBoxDragStart() {
    global runboxGui, runboxDragActive, runboxDragMoved, runboxDragX0, runboxDragY0
    global runboxDragWinX, runboxDragWinY
    hw := RunBoxHwnd()
    if (!hw)
        return
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    runboxDragX0 := NumGet(pt, 0, "Int")
    runboxDragY0 := NumGet(pt, 4, "Int")
    runboxGui.GetPos(&wx, &wy)
    runboxDragWinX := wx
    runboxDragWinY := wy
    runboxDragMoved := false
    runboxDragActive := true
    DllCall("SetCapture", "Ptr", hw, "Ptr")
    SetTimer(RunBoxDragTick, 20)
}

RunBoxDragTick() {
    global runboxDragActive, runboxDragMoved, runboxDragX0, runboxDragY0, runboxDragWinX, runboxDragWinY
    if (!runboxDragActive) {
        SetTimer(RunBoxDragTick, 0)
        return
    }
    ; 左键已松开 → 结束拖动（GetAsyncKeyState 最高位 = 当前按下）
    if (!(DllCall("GetAsyncKeyState", "Int", 0x01, "Short") & 0x8000)) {
        RunBoxDragEnd()
        return
    }
    hw := RunBoxHwnd()
    if (!hw) {
        RunBoxDragEnd()
        return
    }
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    dx := NumGet(pt, 0, "Int") - runboxDragX0
    dy := NumGet(pt, 4, "Int") - runboxDragY0
    if (Abs(dx) > 3 || Abs(dy) > 3)
        runboxDragMoved := true
    WinGetPos(, , &ww, &wh, "ahk_id " . hw)
    vb := RadialVirtualBounds()
    nx := Max(vb.x, Min(runboxDragWinX + dx, vb.x + vb.w - ww))
    ny := Max(vb.y, Min(runboxDragWinY + dy, vb.y + vb.h - wh))
    try WinMove(nx, ny, , , "ahk_id " . hw)     ; 触发 WM_MOVE → RunBoxMoveHandler 同步其它窗口
}

RunBoxDragEnd() {
    global runboxDragActive, runboxDragMoved, runboxBusy
    moved := runboxDragMoved
    runboxDragActive := false
    runboxDragMoved := false
    SetTimer(RunBoxDragTick, 0)
    DllCall("ReleaseCapture")
    OverlayAvoid("runbox")
    ; 面板带 WS_EX_NOACTIVATE（点它不抢焦点），所以"单击面板"要主动把光标还给输入框 ——
    ; 这样"点一下运行框再按 Esc 关闭"才成立。真拖动时不动焦点；解析 / 执行中（busy）也绝不抢焦点。
    if (!moved && !runboxBusy)
        RunBoxFocusInput()
}

; ---- 弹出运行框（触发键只负责"打开 / 聚焦"，**永不关闭**）----
; 用户要求（2026-09-18）：触发键不再是开 / 关切换。
;   · 第一次按 → 一定弹出运行框，且光标自动落在输入框里；
;   · 已经打开时再按 → **不关闭**，只把焦点（光标）拿回输入框；
;   · 要关闭运行框只有一条路：焦点在运行框上时按 **Esc**（见 RunBoxEsc）。
; 务必区分两种"取消"（本次一并写实）：
;   ① 运行框上的 Esc 键 = 对**当前窗口**（= 运行框自己）的取消 → 关闭运行框；
;   ② 正下方键帽排的【取消】键 = 对**"排除运行框之外的最近活动窗口"**的取消
;      → 把 Esc 发给目标窗口（走 OverlaySendKey，见 KeypadOnKeyPress），运行框保持打开。
RunBoxShow() {
    global runboxGui, runboxTextGui, runboxInputGui, runboxEdit, runboxLayout
    global runboxPrevWin, runboxPrevTitle, runboxState, runboxBusy, runboxLog
    global runboxExpanded, runboxStatusText, runboxHandleText, runboxOpacity
    global runboxInOffX, runboxInOffY, ui_font_size
    global runboxLogGui, runboxLogEdit, runboxLogOffX, runboxLogOffY
    if (runboxGui) {
        ; 已经打开：触发键**只把焦点（光标）拿回输入框**，绝不关闭（关闭请按 Esc）
        RunBoxFocusInput()
        DebugLog("[runbox] 触发键：只把焦点拿回运行框（关闭请按 Esc）")
        return
    }
    if (runboxBusy)
        return
    runboxPrevWin := WinExist("A")
    runboxPrevTitle := ""
    if (runboxPrevWin) {
        t := ""
        try WinGetTitle(&t, "ahk_id " . runboxPrevWin)
        runboxPrevTitle := t
    }
    runboxState := "input"
    runboxBusy := false
    runboxLearnArmed := false
    RunBoxMemoryReloadIfChanged()                ; 用户手改记忆文件后立刻生效

    L := RunBoxComputeLayout()                   ; 布局：面板 / 输入框 / 状态 / 把手 / 日志的矩形
    vb := RadialVirtualBounds()
    px := Max(vb.x, vb.x + (vb.w - L.w) // 2)
    py := Max(vb.y, vb.y + vb.h // 5)
    if (py + L.hSmall > vb.y + vb.h)
        py := Max(vb.y, vb.y + vb.h - L.hSmall)

    ; ---- ① 面板窗口：GDI 自绘的半透明底（整窗 LWA_ALPHA），**不画任何文字** ----
    ; +E0x08000000 = WS_EX_NOACTIVATE：点面板 / 拖面板都不抢输入框的焦点。
    ; 文字不能画在这里：整窗 alpha 会把它一起变淡（见 10c-3 的同一道理）。
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    g.BackColor := "2D2D2D"
    g.MarginX := 0
    g.MarginY := 0
    g.Show("x" . px . " y" . py . " w" . L.w . " h" . L.hSmall . " NoActivate")
    runboxGui := g
    RunBoxApplyOpacity(g.Hwnd)
    ; 圆角窗口（SetWindowRgn 后系统接管该区域，勿 DeleteObject）
    hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", L.w + 1, "Int", L.hSmall + 1
        , "Int", 14, "Int", 14, "Ptr")
    DllCall("SetWindowRgn", "Ptr", g.Hwnd, "Ptr", hRgn, "Int", 1)

    ; ---- ② 文字层：提示行 / 状态行 / 把手 / 执行过程日志（彩色字身 + 黑边，恒不透明）----
    runboxTextGui := OverlayTextLayerNew(px, py, L.w, L.hSmall)

    ; ---- ③ 输入框窗口：独立顶层窗口，**整块不透明**（不受 [runbox] opacity 影响）----
    ; 为什么必须独立成窗：LWA_ALPHA 是按整个顶层窗口（含其所有子控件）施加的，
    ; 输入框若挂在上面的半透明面板上，就会跟着一起变淡。用户要求"编辑框本身不透明"。
    gIn := Gui("-Caption +AlwaysOnTop +ToolWindow")
    gIn.MarginX := 0
    gIn.MarginY := 0
    gIn.BackColor := "FFFFFF"        ; 用户要求：输入框白底黑字
    gIn.SetFont("s" . ui_font_size, "Consolas")
    edit := gIn.Add("Edit", "c000000 BackgroundFFFFFF w" . L.input.w . " h" . L.input.h)
    okBtn := gIn.Add("Button", "Hidden Default", "OK")   ; 隐藏的默认按钮：Edit 里按回车即触发它
    okBtn.OnEvent("Click", (*) => RunBoxDefault())
    gIn.OnEvent("Escape", (*) => RunBoxEsc())            ; Esc 关闭运行框（面板不持焦点，挂这里最可靠）
    gIn.Show("x" . px . " y" . py . " w" . L.input.w . " h" . L.input.h . " NoActivate")
    runboxInputGui := gIn
    runboxEdit := edit
    ; 输入框窗口客户区左上角相对窗口左上角的偏移（有边框 / 阴影时非 0，定位要用它换算）
    runboxInOffX := 0
    runboxInOffY := 0
    try {
        icx := 0, icy := 0, iwx := 0, iwy := 0
        WinGetClientPos(&icx, &icy, , , "ahk_id " . gIn.Hwnd)
        gIn.GetPos(&iwx, &iwy)
        if (IsSet(icx) && IsSet(iwx))
            runboxInOffX := icx - iwx
        if (IsSet(icy) && IsSet(iwy))
            runboxInOffY := icy - iwy
    } catch {
    }

    ; ---- ④ 执行过程窗口：独立顶层窗口里的**只读多行 Edit**（整块不透明）----
    ; 用户实测要求（2026-09-18）：执行过程必须能用鼠标选中、Ctrl+C 复制、滚动条翻阅，
    ; 所以它不能再画在文字层上，而是像输入框一样单独成窗（代价：这块区域不参与 [runbox] opacity）。
    gLog := Gui("-Caption +AlwaysOnTop +ToolWindow")
    gLog.MarginX := 0
    gLog.MarginY := 0
    gLog.BackColor := "1F1F1F"
    gLog.SetFont("s" . L.sub, "Microsoft YaHei")
    logEdit := gLog.Add("Edit", "ReadOnly +Multi +VScroll cD8D8D8 Background1F1F1F w" . L.log.w . " h" . L.log.h)
    gLog.OnEvent("Escape", (*) => RunBoxEsc())    ; 焦点在日志上时 Esc 也能关运行框
    runboxLogGui := gLog                           ; 先不 Show：收起态由 RunBoxLogVisible 隐藏（默认隐藏）
    runboxLogEdit := logEdit
    runboxLogOffX := 0
    runboxLogOffY := 0
    try {
        lcx := 0, lcy := 0, lwx := 0, lwy := 0
        WinGetClientPos(&lcx, &lcy, , , "ahk_id " . gLog.Hwnd)
        gLog.GetPos(&lwx, &lwy)
        if (IsSet(lcx) && IsSet(lwx))
            runboxLogOffX := lcx - lwx
        if (IsSet(lcy) && IsSet(lwy))
            runboxLogOffY := lcy - lwy
    } catch {
    }

    runboxExpanded := false                      ; 每次打开都先收起
    runboxLog := []                              ; 过程日志也从空白开始
    runboxStatusText := "可用动作：send: / hotkey: / paste: / item: / run: / self:"
    runboxHandleText := "▼ 执行过程（点击展开）"
    RunBoxTextBoxes()                            ; 把输入框窗口贴到面板上的输入框矩形
    RunBoxPanelDraw()                            ; 画面板（底色 + 1px 浅灰边框）
    RunBoxTextLayerPresent()                     ; 画文字层

    ; 输入框自动获得焦点（运行框本来就是要抢焦点来打字的，提交后会还给原窗口）
    RunBoxFocusInput()
    ; 持续跟踪"最近一个活动窗口（排除运行框自己）"：每 400ms 看一眼，变了就记下来
    RunBoxTrackTarget()
    SetTimer(RunBoxTrackTarget, 400)
    ; 面板拖动：WM_NCHITTEST 返回 HTCAPTION，真正的拖动在 RunBoxNcLButtonDown 里自己接管
    OnMessage(0x0084, RunBoxHitTest, 0)
    OnMessage(0x0084, RunBoxHitTest)
    OnMessage(0x00A3, RunBoxNoMaximize, 0)
    OnMessage(0x00A3, RunBoxNoMaximize)
    OnMessage(0x00A1, RunBoxNcLButtonDown, 0)     ; 面板拖动 / 小把手点击
    OnMessage(0x00A1, RunBoxNcLButtonDown)
    OnMessage(0x0003, RunBoxMoveHandler, 0)       ; 面板移动 → 输入框 / 文字层 / 键帽排跟着走
    OnMessage(0x0003, RunBoxMoveHandler)
    OnMessage(0x0232, RunBoxExitSizeMove, 0)      ; 兼容：系统移动循环结束（自实现拖动时基本用不到）
    OnMessage(0x0232, RunBoxExitSizeMove)
    RunKeysShow()                                 ; 底部热键键帽（回车 / Tab / 空格 / 删除 / 退格 / 取消 / 触发）
    OverlayAvoid("runbox")                        ; 运行框也算浮层：把它压住的菜单 / 小键盘推开
    RunBoxSyncWindows()                           ; 避让之后所有窗口再对齐一次
    RunBoxTextLayerPresent()
    ; 最后再确认一次光标在输入框里：键帽排等窗口刚创建完，仍要把光标留在对话框中（用户要求）
    RunBoxFocusInput()
    DebugLog("[runbox] 已弹出运行框，目标窗口=" . runboxPrevWin . "「" . runboxPrevTitle . "」"
        . "（opacity=" . runboxOpacity . "，面板=" . L.w . "x" . L.hSmall . "，输入框=" . L.input.w . "x" . L.input.h . "）")
}

; ============ 运行框下方的热键键帽（复用第 5 个小键盘面板 runkeys）============
; 做法：直接调 KeypadShow 创建"第 5 个面板"，因此布局 / 圆角窗口 / 悬停高亮 /
; 文字层（彩色字身 + 黑边，字号取 [keypad] font_size）与小键盘、圆盘完全一致。
; 区别只有三点：
;   ① 不登记浮层栈：运行框的关闭归它自己（Gui 的 Escape 事件）管；键帽排上的【取消】
;      是"发给目标窗口的 Esc"，**不是**关闭运行框 —— 两者语义不同，别混用；
;   ② **所有键帽**（回车 / Tab / 空格 / 删除 / 退格 / 取消 / 触发）都以"排除运行框之外的
;      最近活动窗口"为目标（用户 2026-09-18 明确）：KeypadOnKeyPress 一律把动作交给
;      OverlayActionExecute(..., "runkeys", focusWin)，动作层先 OverlayPrepareInject 把前台
;      切到 keypadPanels["runkeys"].focusWin（= runboxPrevWin），再发送 / 执行；
;      所以点键帽绝不会把按键打到运行框自己身上，运行框也不会因此关闭；
;   ③ 位置永远吸附在运行框正下方（运行框一动就跟着走）。
RunKeysShow() {
    global keypadPanels, runboxPrevWin
    KeypadShow("runkeys", false)                    ; 不登记浮层栈：Esc 仍归运行框管
    if (!keypadPanels.Has("runkeys"))
        return
    keypadPanels["runkeys"].focusWin := runboxPrevWin
    RunKeysAnchor()
}

RunKeysHide() {
    global keypadPanels
    if (keypadPanels.Has("runkeys"))
        KeypadClose("runkeys")
}

RunKeysSyncTarget() {
    global keypadPanels, runboxPrevWin
    if (keypadPanels.Has("runkeys"))
        keypadPanels["runkeys"].focusWin := runboxPrevWin
}

; 把键帽排吸附到运行框正下方（水平居中、夹取在虚拟屏幕内）
RunKeysAnchor() {
    global keypadPanels
    if (!keypadPanels.Has("runkeys"))
        return
    ownHwnd := RunBoxHwnd()
    if (!ownHwnd)
        return
    P := keypadPanels["runkeys"]
    if (!P.gui)
        return
    L := P.layout
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . ownHwnd)
    if (ww <= 0 || wh <= 0)
        return
    vb := RadialVirtualBounds()
    nx := wx + (ww - L.winW) // 2
    nx := Max(vb.x, Min(nx, vb.x + vb.w - L.winW))
    ny := wy + wh + 6                              ; 紧贴运行框下沿，留 6px 缝
    if (ny + L.winH > vb.y + vb.h)
        ny := Max(vb.y, vb.y + vb.h - L.winH)      ; 下方放不下就往上收
    P.gui.Move(nx, ny)
    OverlayTextLayerMove(P.textGui, nx, ny)          ; 文字层只挪位置（尺寸与面板一致）
}

; 运行框被拖动时系统会连续发 WM_MOVE：
;   ① 让键帽排跟着走；② 顺便做避让 —— 拖动过程中就把被压住的浮层推开（用户要求"运行框也能推开它们"）。
;   防互相顶：若运行框刚刚是被**别的浮层避让**挪开的（runboxAvoidTick 刚打过），这一段 WM_MOVE 就跳过避让，
;   否则会形成"你推我、我推你"的来回抖动。运行框自己是 active 时永远不会被避让挪动，所以正常拖动不受影响。
RunBoxMoveHandler(wParam, lParam, msg, hwnd) {
    global runboxAvoidTick
    ownHwnd := RunBoxHwnd()
    if (!ownHwnd || hwnd != ownHwnd)
        return
    RunBoxSyncWindows()
    if (A_TickCount - runboxAvoidTick > 250)
        OverlayAvoid("runbox")
}

; 拖动结束（系统模态移动循环退出，WM_EXITSIZEMOVE）→ 把被运行框压住的浮层推开。
; 特意不用 WM_MOVE：避让自己挪动运行框也会触发 WM_MOVE，会造成互相触发。
RunBoxExitSizeMove(wParam, lParam, msg, hwnd) {
    ownHwnd := RunBoxHwnd()
    if (!ownHwnd || hwnd != ownHwnd)
        return
    OverlayAvoid("runbox")
}

; ---- 安全取运行框窗口句柄 ----
; Gui 对象被 Destroy() 之后再读 .Hwnd 会抛 "Gui has no window"（定时器可能正好在这期间触发），
; 所以凡是要用句柄的地方都走这里：已销毁就返回 0，绝不抛异常。
RunBoxHwnd() {
    global runboxGui
    if (!runboxGui)
        return 0
    h := 0
    try h := runboxGui.Hwnd
    return h
}

; ---- 按当前展开状态调整面板高度（收起 = hSmall；展开 = hBig），并重画 / 同步 ----
RunBoxApplyHeight() {
    global runboxGui, runboxExpanded, runboxLayout
    if (!runboxGui || !runboxLayout)
        return
    L := runboxLayout
    newH := runboxExpanded ? L.hBig : L.hSmall
    try {
        runboxGui.GetPos(&gx, &gy)
        vb := RadialVirtualBounds()
        if (gy + newH > vb.y + vb.h)
            gy := Max(vb.y, vb.y + vb.h - newH)     ; 撑开后别跑到屏幕外面去
        runboxGui.Move(gx, gy, L.w, newH)
    } catch Error as e {
        DebugLog("[runbox] 调整高度失败：" . e.Message . "（目标高度=" . newH . "）")
    }
    RunBoxPanelDraw()                              ; 高度变了要重画面板底色 / 边框
    RunBoxLogVisible()                             ; 执行过程窗口：展开显示 / 收起隐藏，并贴到日志矩形
    RunBoxSyncWindows()                            ; 四个窗口 + 键帽排重新对齐
    RunBoxTextLayerPresent()                       ; 文字层（固定只盖提示 / 状态 / 把手）
    OverlayAvoid("runbox")                         ; 撑开后若压住别的浮层，把它们推开
}

; ---- 底部小把手：展开 / 收起"执行全过程"面板 ----
RunBoxToggleDetail() {
    global runboxExpanded, runboxGui, runboxEdit, runboxToggleTick, runboxLog
    if (!runboxGui)
        return
    ; 去抖：300ms 内只认一次，避免同一击被两条路径都算上
    now := A_TickCount
    if (now - runboxToggleTick < 300)
        return
    runboxToggleTick := now
    runboxExpanded := !runboxExpanded
    RunBoxSetHandle(runboxExpanded ? "▲ 执行过程（点击收起）" : "▼ 执行过程（点击展开）")
    RunBoxApplyHeight()                            ; 高度 / 面板 / 日志窗口 / 文字层 / 键帽排一起更新
    if (runboxExpanded)
        RunBoxRenderLog()                          ; 展开时把日志灌进 Edit（收起时窗口已隐藏）
    try runboxEdit.Focus()                         ; 点完把手把光标还给输入框
    DebugLog("[runbox] 执行过程面板：" . (runboxExpanded ? "展开" : "收起")
        . "（日志行数=" . runboxLog.Length . "）")
}

; ---- 执行全过程日志：追加一行；面板开着就写进 Edit（写 Edit 很便宜，不必节流）----
RunBoxLogAdd(line) {
    global runboxLog, runboxExpanded, runboxGui
    runboxLog.Push(line)
    ; 收起状态下**不渲染**（用户要求：只有打开扩展区域才显示执行过程）
    if (!runboxGui || !runboxExpanded)
        return
    RunBoxRenderLog()
}

; ---- 展开时把日志灌进只读多行 Edit 并滚到底（与改造前一致，可滚动 / 选中 / Ctrl+C）----
RunBoxRenderLog() {
    global runboxLog, runboxLogEdit, runboxExpanded
    if (!runboxLogEdit || !runboxExpanded)
        return
    txt := ""
    for l in runboxLog
        txt .= l . "`n"
    txt := RTrim(txt, "`n")
    if (txt = "")
        txt := "（还没有执行记录：写完需求回车后，这里会显示「解析 → 清单 → 每条成败与耗时 → 结果」的全过程）"
    try runboxLogEdit.Value := txt
    try {
        SendMessage(0x00B1, -1, -1, , "ahk_id " . runboxLogEdit.Hwnd)   ; EM_SETSEL：光标移到末尾
        SendMessage(0x00B7, 0, 0, , "ahk_id " . runboxLogEdit.Hwnd)     ; EM_SCROLLCARET：滚到可见
    }
}

; ---- 面板上的鼠标左键（非客户区消息 WM_NCLBUTTONDOWN 0x00A1）----
; 为什么走 0x00A1：RunBoxHitTest 让整块面板按 HTCAPTION（可拖动）处理，点下去就会来这条消息；
; 而 0x0201 被径向菜单 / 小键盘 / 思考窗口抢（每个消息只挂一个回调），运行框不能再用它。
; 这里做两件事：
;   ① 落点在"执行过程"把手上 → 展开 / 收起（吞掉，不进入拖动）；
;   ② 其余位置 → **自己实现拖动**（面板是 WS_EX_NOACTIVATE，交给系统 HTCAPTION 移动循环不可靠）。
; 典型做法：记录起点 + SetCapture + 定时器轮询光标与左键状态（见 RunBoxDragStart / RunBoxDragTick）。
RunBoxNcLButtonDown(wParam, lParam, msg, hwnd) {
    global runboxLayout
    if (wParam != 2)                      ; 2 = HTCAPTION
        return
    ownHwnd := RunBoxHwnd()
    if (!ownHwnd || hwnd != ownHwnd)
        return
    L := runboxLayout
    if (!L)
        return
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    mx := NumGet(pt, 0, "Int")
    my := NumGet(pt, 4, "Int")
    WinGetPos(&wx, &wy, , , "ahk_id " . ownHwnd)
    R := L.handle
    if (mx >= wx + R.x && mx <= wx + R.x + R.w && my >= wy + R.y && my <= wy + R.y + R.h) {
        RunBoxToggleDetail()
        return 0                          ; 吞掉：不要进入窗口拖动
    }
    RunBoxDragStart()
    return 0                              ; 吞掉：拖动由我们自己的定时器接管
}

; ---- 面板的命中测试：整块面板按"标题栏"处理 ----
; 面板上只有自绘内容与文字层（文字层是 WS_EX_TRANSPARENT，点击穿透到面板），
; 输入框在**另一个窗口**上，根本不会走到这里，所以这里可以统一返回 HTCAPTION(2)。
; 真正的拖动由 RunBoxNcLButtonDown 自己接管（见上）。
RunBoxHitTest(wParam, lParam, msg, hwnd) {
    ownHwnd := RunBoxHwnd()
    if (!ownHwnd || hwnd != ownHwnd)
        return
    return 2                                       ; HTCAPTION
}

; 拖动时双击标题区会被系统当成"最大化"——这里吞掉它，运行框保持原尺寸
RunBoxNoMaximize(wParam, lParam, msg, hwnd) {
    ownHwnd := RunBoxHwnd()
    if (!ownHwnd)
        return
    if (DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") != ownHwnd)
        return
    return 0
}

; ---- 记录"最近一个活动的窗口"（排除运行框自己），动作最终都打到它上面 ----
; 运行框本身要抢焦点来打字，所以不能只看弹出那一刻的前台窗口：
; 用户可能在运行框开着时切到别的程序，之后连续下需求时目标就该是那个程序。
; ---- 某个窗口句柄是不是"运行框自己"（运行框主窗口 + 它下方的热键键帽排）----
; 用途：① 跟踪目标窗口时排除它们；② 收尾判"有没有打开新窗口"时排除它们。
; 用户要求：自然语言运行框（含键帽排）既可以有焦点，但**永远不能**算作动作目标窗口，
; 也不能算作"要回退到的上一个窗口"。
RunBoxIsSelfWin(hwnd) {
    global keypadPanels, runboxInputGui, runboxLogGui
    if (!hwnd)
        return true                          ; 没有前台窗口：按"没有可留下的新窗口"处理
    own := RunBoxHwnd()
    if (own && hwnd = own)
        return true
    ; 输入框 / 执行过程都是独立顶层窗口 —— 它们才是真正会拿到前台的那些"自己"
    for g in [runboxInputGui, runboxLogGui] {
        if (!g)
            continue
        gh := 0
        try gh := g.Hwnd
        if (gh && hwnd = gh)
            return true
    }
    if (keypadPanels.Has("runkeys")) {
        P := keypadPanels["runkeys"]
        if (P.gui) {
            kHwnd := 0
            try kHwnd := P.gui.Hwnd          ; Destroy() 后再读 .Hwnd 会抛，必须包 try
            if (kHwnd && hwnd = kHwnd)
                return true
        }
    }
    return false
}

RunBoxTrackTarget() {
    global runboxPrevWin, runboxPrevTitle
    cur := WinExist("A")
    if (!cur)
        return
    if (RunBoxIsSelfWin(cur))                  ; 运行框自己（含键帽排）不算目标窗口
        return
    if (!RunBoxHwnd())                         ; 极端情况：运行框已关（定时器通常已停）
        return
    if (cur = runboxPrevWin)                   ; 没变，省掉取标题的开销
        return
    runboxPrevWin := cur
    t := ""
    try WinGetTitle(&t, "ahk_id " . cur)
    runboxPrevTitle := t
    RunKeysSyncTarget()                        ; 键帽排的发送目标跟着一起变
    DebugLog("[runbox] 目标窗口更新为「" . t . "」（hwnd=" . cur . "）")
}

RunBoxClose() {
    global runboxGui, runboxTextGui, runboxInputGui, runboxEdit, runboxLogGui, runboxLogEdit
    global runboxState, runboxBusy, runboxPrevWin, runboxLayout
    global runboxExpanded, runboxDragActive, runboxTextTimerOn
    global runboxLearnArmed, runboxLearnBusy, runboxLearnPlan
    ; 顺序很重要：**先停表、先清空全局引用，最后才销毁窗口**。
    ; 否则定时器（每 400ms / 拖动 20ms）可能在 Destroy() 与清空之间插进来读 runboxGui.Hwnd，
    ; 抛 "Gui has no window"（2026-09-15 用户实测踩到）。
    SetTimer(RunBoxTrackTarget, 0)
    SetTimer(RunBoxDragTick, 0)
    SetTimer(RunBoxTextsFlush, 0)
    runboxDragActive := false
    runboxTextTimerOn := false
    OnMessage(0x0084, RunBoxHitTest, 0)
    OnMessage(0x00A3, RunBoxNoMaximize, 0)
    OnMessage(0x00A1, RunBoxNcLButtonDown, 0)
    OnMessage(0x0003, RunBoxMoveHandler, 0)
    OnMessage(0x0232, RunBoxExitSizeMove, 0)
    RunKeysHide()                                 ; 键帽排随运行框一起收掉
    runboxBusy := false
    runboxState := ""
    runboxLearnArmed := false
    runboxLearnBusy := false
    runboxLearnPlan := 0
    gPanel := runboxGui
    gText := runboxTextGui
    gInput := runboxInputGui
    gLog := runboxLogGui
    runboxGui := ""
    runboxTextGui := ""
    runboxInputGui := ""
    runboxLogGui := ""
    runboxEdit := ""
    runboxLogEdit := ""
    runboxLayout := ""
    runboxExpanded := false
    OverlayTextLayerDestroy(gText)                ; 文字层
    if (gLog) {
        try gLog.Destroy()                        ; 执行过程窗口
    }
    if (gInput) {
        try gInput.Destroy()                      ; 输入框窗口
    }
    if (gPanel) {
        try gPanel.Destroy()                      ; 面板窗口
    }
    RunBoxEscOff()
    if (runboxPrevWin)
        RadialActivateFocusWin(runboxPrevWin)
}

; ---- 回车：输入态 = 提交需求；确认态 = 开始执行 ----
RunBoxDefault() {
    global runboxState
    if (runboxState = "input")
        RunBoxSubmit()
    else if (runboxState = "confirm")
        RunBoxExecute()
    else if (runboxState = "learnconfirm")
        RunBoxLearnConfirmGo()          ; 待确认的记忆变更：回车才落盘（learn_confirm = true）
}

; ---- Esc = 对**当前窗口**（运行框自己）的取消 → 关闭运行框 ----
; 触发键不再关闭运行框（见 RunBoxShow），所以这里是关闭运行框的**唯一**入口。
; 输入 / 确认 / 结果态 → 直接关闭；执行态（busy）交给全局 Esc 热键 RunBoxEscHandler 中止。
; 注意：与正下方键帽排的【取消】键语义不同 —— 那个是把 Esc 发给"目标窗口"，不关运行框。
RunBoxEsc() {
    global runboxBusy, runboxLearnBusy, runboxState
    if (runboxBusy || runboxLearnBusy)
        return
    ; 学习相关态：Esc 只取消"学习"，**不关闭运行框**（把输入框留给用户改一改再说）
    if (runboxState = "learnconfirm") {
        RunBoxLearnCancel()
        return
    }
    if (runboxState = "learning") {
        RunBoxLearnAbort()
        return
    }
    RunBoxClose()
}

; ---- 发一次模型请求（临时套用 [runbox] 的 model / timeout 覆盖，结束后恢复）----
; learn = true 时改用 [runbox] learn_model（留空则仍用 [runbox] model / [ai] model）
RunBoxAskModel(userPrompt, sysPrompt, &result, &reasoning, &errMsg, learn := false) {
    global ai_model, ai_timeout, runboxModel, runboxTimeout, runboxLearnModel
    savedModel := ai_model
    savedTimeout := ai_timeout
    if (learn && runboxLearnModel != "")
        ai_model := runboxLearnModel
    else if (runboxModel != "")
        ai_model := runboxModel
    if (runboxTimeout > 0)
        ai_timeout := runboxTimeout
    result := "", reasoning := "", errMsg := ""
    ok := false
    try {
        ok := AIRequest(userPrompt, &result, &reasoning, &errMsg, sysPrompt)
    } catch Error as e {
        ok := false
        errMsg := "请求异常：" . e.Message
    }
    ai_model := savedModel
    ai_timeout := savedTimeout
    return ok
}

; ---- 把模型回复原文 / 思考过程写进 debug.log（压成一行、截断）----
; 排查"它为什么这么判"时最有用：能看到模型到底回了什么，而不是只看解析结果。
RunBoxLogModelReply(tag, result, reasoning) {
    DebugLog("[runbox] 模型原文（" . tag . "）：" . RunBoxBrief(result, 600))
    if (reasoning != "")
        DebugLog("[runbox] 模型思考（" . tag . "）：" . RunBoxBrief(reasoning, 300))
}

RunBoxBrief(text, maxLen := 600) {
    t := text
    if (t = "")
        return "（空）"
    t := StrReplace(t, "`r`n", " ⏎ ")
    t := StrReplace(t, "`n", " ⏎ ")
    t := StrReplace(t, "`r", " ⏎ ")
    if (StrLen(t) > maxLen)
        t := SubStr(t, 1, maxLen) . "…（已截断）"
    return t
}

; ---- 兜底阶段只认"纯文本输出"，动作一律丢弃（白名单一分不松）----
; 接受 paste:（任何内容）与"不含按键语法的 send:"（模型有时会漏写 paste: 前缀，直接给出网址/一段文字）；
; item: / run: / self: / 含 ^ ! + # { } 的按键一律不认 —— 兜底路径不可能执行动作。
RunBoxFallbackPick(acts) {
    out := []
    for a in acts {
        if (a.type = "paste") {
            out.Push(a)
        } else if (a.type = "send" && !RegExMatch(a.value, "[\^!+#{}]")) {
            out.Push({type: "paste", value: a.value})     ; 按文本粘贴，最稳妥
        }
    }
    return out
}

; ---- 提交需求 → 请求模型 → 解析 → 确认清单 ----
RunBoxSubmit() {
    global runboxGui, runboxEdit, runboxState, runboxBusy, runboxLearnArmed
    global runboxPrevWin, runboxPrevTitle, runboxActions, runboxDropped, runboxConfirm
    global runboxModel, runboxTimeout, runboxLog
    global runboxLastReq, runboxLastActions, runboxLastDropped, runboxLastResult
    global runboxLastAliasHit, runboxLastJournaled, runboxLastErrText, runboxLastMemoryNote
    if (runboxState != "input" || runboxBusy || !runboxGui)
        return
    req := Trim(runboxEdit.Value)
    if (req = "")
        return

    ; ---------- 反馈入口（显式是唯一会自动改记忆的途径）----------
    ; 两种进入方式：① 输入以「纠正：/记住：/记下：」开头；② 先按了键帽【纠正】(self:runbox_learn)。
    fb := RunBoxFeedbackPrefix(req)
    if (runboxLearnArmed || fb.isFeedback) {
        if (fb.body = "") {
            RunBoxSetStatus("反馈内容为空：请写成“纠正：以后我说X就是Y”这样的一句话")
            return
        }
        try runboxEdit.Value := ""
        RunBoxLearningStart(fb.body)
        return
    }

    DebugLog("[runbox] 需求：" . req)
    runboxLog := []                              ; 每次新需求都重开一份过程日志
    RunBoxLogAdd("[需求] " . req)
    runboxLastReq := req                         ; 反馈学习要用"上一次需求"当上下文
    runboxLastAliasHit := ""
    runboxLastErrText := ""
    runboxLastJournaled := false
    RunBoxMemoryReloadIfChanged()                ; 用户手改记忆文件后立刻生效（不必重启）

    ; ---------- 别名快路径：命中就不调模型（0 延迟、0 token、0 幻觉）----------
    hitWords := [], why := []
    aliasActs := RunBoxAliasResolve(req, &hitWords, &why)
    if (aliasActs.Length > 0) {
        runboxActions := aliasActs
        runboxDropped := []
        runboxLastActions := aliasActs
        runboxLastDropped := []
        runboxLastAliasHit := RunBoxJoinList(hitWords, "、")
        runboxLastMemoryNote := "别名" . hitWords.Length . "条（未调模型）"
        RunBoxLogAdd("[记忆] 别名命中：" . RunBoxJoinList(why, "；") . "（本次未调用模型）")
        RunBoxAliasBump(hitWords)
        RunBoxSetStatus("别名命中：" . RunBoxJoinList(hitWords, "、") . " → 共 "
            . aliasActs.Length . " 条动作")
        DebugLog("[runbox] 别名快路径命中，跳过模型调用")
        RunBoxShowConfirm()
        return
    }

    runboxBusy := true
    runboxState := "loading"
    RunBoxInputVisible(false)
    RunBoxSetStatus("正在请模型把需求解析成动作…（最长 " . Round(runboxTimeout / 1000) . " 秒，这段不能中断）")
    ; 请求期间把焦点还给原窗口，别占着用户的编辑器
    if (runboxPrevWin)
        RadialActivateFocusWin(runboxPrevWin)

    sysPrompt := RunBoxBuildPrompt(req)          ; 带上需求：记忆块按相关度排序
    memBody := RunBoxMemoryBlockText(req, &memUsed, &memDropped)
    runboxLastMemoryNote := (Trim(memBody) = "") ? "无" : ("记忆块" . StrLen(memBody) . "字/裁" . memDropped . "条")
    userPrompt := "当前前台窗口：" . (runboxPrevTitle != "" ? runboxPrevTitle : "（未知）") . "`n操作需求：" . req
    hintText := "如果你要的是文字 / 信息，可改说“请输出…”"

    ; ---------- 第一阶段：判类别 + 翻译成动作（要文字的需求也会在这一步直接给 paste:）----------
    result := "", reasoning := "", errMsg := ""
    if (!RunBoxAskModel(userPrompt, sysPrompt, &result, &reasoning, &errMsg)) {
        DebugLog("[runbox] 解析失败：" . errMsg)
        runboxLastActions := [], runboxLastDropped := []
        runboxLastResult := "解析失败：" . errMsg
        RunBoxBackToInput("解析失败：" . errMsg)
        return
    }
    RunBoxLogModelReply("动作", result, reasoning)
    parsed := RunBoxParseReply(result)
    runboxActions := parsed.actions
    runboxDropped := parsed.dropped
    runboxLastActions := runboxActions
    runboxLastDropped := runboxDropped
    runboxLastErrText := parsed.error
    DebugLog("[runbox] 第一阶段：解析出 " . runboxActions.Length . " 条动作，丢弃 " . runboxDropped.Length . " 行"
        . (parsed.error != "" ? "，ERROR：" . parsed.error : ""))

    ; ---------- 第二阶段（兜底）：操作类但没有对应动作 → 回头审视能否当成"要文字" ----------
    ; 用户要求的判定顺序：动作表里有对应动作就执行；没有则重新看这条需求是不是也能理解成"要输出文字"。
    if (parsed.error != "" || runboxActions.Length = 0) {
        DebugLog("[runbox] 第一阶段没有可用动作，转入兜底文字判定")
        RunBoxLogAdd("[模型] 动作表里没有可用的动作，正在重新判断这条需求能否按文字输出…")
        RunBoxSetStatus("动作表里没有对应动作，正在重新判断能否按文字输出…（最长 "
            . Round(runboxTimeout / 1000) . " 秒）")
        result2 := "", reasoning2 := "", errMsg2 := ""
        ok2 := RunBoxAskModel(userPrompt, RunBoxBuildFallbackPrompt(), &result2, &reasoning2, &errMsg2)
        reason := ""
        if (ok2) {
            RunBoxLogModelReply("兜底文字", result2, reasoning2)
            fb := RunBoxParseReply(result2)
            fbActs := RunBoxFallbackPick(fb.actions)
            if (fbActs.Length > 0) {
                runboxActions := fbActs
                runboxDropped := fb.dropped
                DebugLog("[runbox] 兜底文字判定：按文字输出 " . fbActs.Length . " 条")
            } else {
                reason := (fb.error != "" ? fb.error : "没有对应的操作")
                DebugLog("[runbox] 兜底文字判定：不改文字输出（" . reason . "）")
            }
        } else {
            DebugLog("[runbox] 兜底请求失败：" . errMsg2)
            reason := (parsed.error != "" && !parsed.noAction) ? parsed.error : "没有对应的操作"
        }
        if (reason != "") {
            if (reason != "没有对应的操作")
                reason := "模型认为无法完成：" . reason
            runboxLastActions := [], runboxLastDropped := []
            runboxLastResult := reason
            RunBoxBackToInput(reason, hintText)
            return
        }
    }

    DebugLog("[runbox] 解析出 " . runboxActions.Length . " 条动作，丢弃 " . runboxDropped.Length . " 行")
    RunBoxLogAdd("[模型] 解析出 " . runboxActions.Length . " 条动作，丢弃 " . runboxDropped.Length . " 行")
    RunBoxShowConfirm()
}

; ---- 解析失败 / 无动作：回到输入态并把提示写在状态栏 ----
; hint：可选的第二句出路提示（例如"如果你要的是文字 / 信息，可改说…"）
; journalIt = false 用于"学习流程"的失败路径：那次并没有跑需求，不该往运行流水里写一行
; （否则流水里会出现"上一条需求 + 整理记忆失败"这种对不上的记录，事后复盘会误导）。
RunBoxBackToInput(msg, hint := "", journalIt := true) {
    global runboxEdit, runboxState, runboxBusy, runboxLastResult
    runboxBusy := false
    runboxState := "input"
    runboxLastResult := msg                       ; 反馈学习要参考"上一次的结局"
    if (journalIt)
        RunBoxJournalFlush(msg)                   ; 没有可用动作 / 解析失败：也如实写进流水
    RunBoxInputVisible(true)
    RunBoxApplyHeight()
    RunBoxSetStatus(msg . (hint != "" ? "；" . hint : "") . "（可修改需求后重试）")
    try runboxEdit.Focus()
}

; ---- 显示"将执行"清单；confirm = false 时直接执行 ----
RunBoxShowConfirm() {
    global runboxActions, runboxDropped, runboxState, runboxBusy, runboxConfirm
    global runboxLastActions, runboxLastDropped, runboxLastResult
    runboxBusy := false
    runboxState := "confirm"
    runboxLastActions := runboxActions
    runboxLastDropped := runboxDropped
    runboxLastResult := "已交给执行器（" . runboxActions.Length . " 条动作）"
    ; 界面只有"输入框 + 可展开的执行过程"两块：清单与丢弃明细记在过程面板里，
    ; 这里只在状态行给一行摘要（想看明细就点底部把手展开）
    RunBoxSetStatus("将执行 " . runboxActions.Length . " 条动作（丢弃 " . runboxDropped.Length
        . " 行）：回车执行，Esc 取消；点下方把手可看明细")
    ; 全过程日志：把"将执行什么、丢弃了什么"也记下来
    RunBoxLogAdd("[清单] 将执行 " . runboxActions.Length . " 条：")
    for i, a in runboxActions
        RunBoxLogAdd("      " . i . ". " . RunBoxActionLine(a))
    if (runboxDropped.Length > 0) {
        RunBoxLogAdd("[丢弃] " . runboxDropped.Length . " 行（不会执行）：")
        for d in runboxDropped
            RunBoxLogAdd("      ✗ " . d)
    }
    if (!runboxConfirm)
        RunBoxExecute()
}

; ---- 开始执行（逐条、定时器推进、Esc 可中止）----
RunBoxExecute() {
    global runboxActions, runboxRunIdx, runboxPrevWin, runboxPrevTitle, runboxState, runboxBusy
    global runboxStartTick, runboxExecBaseWin
    if (runboxState = "running" || runboxActions.Length = 0)
        return
    runboxState := "running"
    runboxBusy := true
    runboxRunIdx := 0
    RunBoxEscOn()                                  ; 执行期间 Esc = 中止后续动作
    runboxExecBaseWin := runboxPrevWin             ; 记下执行前的目标窗口：收尾判"有没有打开新窗口"用
    if (runboxPrevWin)
        RadialActivateFocusWin(runboxPrevWin)      ; 动作要打到原来的前台窗口
    runboxStartTick := A_TickCount
    RunBoxLogAdd("[开始] 目标窗口：「" . (runboxPrevTitle != "" ? runboxPrevTitle : "未知") . "」")
    RunBoxSetStatus("开始执行…（Esc 可中止剩余动作）")
    SetTimer(RunBoxStep, -10)
}

RunBoxStep() {
    global runboxActions, runboxRunIdx, runboxPrevWin, runboxStepDelay, runboxRunWait
    runboxRunIdx++
    if (runboxRunIdx > runboxActions.Length) {
        RunBoxFinish("全部 " . runboxActions.Length . " 条动作已执行完毕")
        return
    }
    act := runboxActions[runboxRunIdx]
    desc := RunBoxActionLine(act)
    RunBoxSetStatus("正在执行 " . runboxRunIdx . "/" . runboxActions.Length . "：" . desc)
    ; 每条动作执行前，确保目标窗口是前台（run: 之后前台可能已经变成新程序，那时就发给新程序）
    cur := WinExist("A")
    if (!cur && runboxPrevWin)
        RadialActivateFocusWin(runboxPrevWin)
    t0 := A_TickCount
    ok := OverlayActionExecute(act, "runbox", runboxPrevWin)
    cost := A_TickCount - t0
    DebugLog("[runbox] 第 " . runboxRunIdx . "/" . runboxActions.Length . " 条" . (ok ? "完成" : "未执行") . "：" . desc)
    RunBoxLogAdd("[" . runboxRunIdx . "/" . runboxActions.Length . "] " . desc . (ok ? "    ✔ 完成  " : "    ✖ 未执行  ") . cost . "ms")
    delay := runboxStepDelay
    if (act.type = "run")
        delay += runboxRunWait                      ; 启动程序后多等一会儿
    SetTimer(RunBoxStep, -Max(delay, 10))
}

; ---- 兜底：抬起"被序列按下、却没等到松开"的修饰键 ----
; 为什么需要它（2026-09-19 与"运行框跳过修饰键闸门"一起加）：
;   序列允许 {Ctrl down} … {Ctrl up} 这种跨步写法后，一旦序列在中途被 Esc 中止、
;   或负责松开的最后一条因故没执行，修饰键就会**卡在按下状态**（用户表现为"Ctrl 好像粘住了"）。
;   这里在执行结束（正常跑完 / 被中止）时统一抬起，保证不留悬挂状态。
; 只对**逻辑上处于按下**的键发 up：没按下的键不发，避免凭空产生一次按键事件。
; 注意：它清不掉"用户故意跨需求保持修饰键"的用法（例如这次只说"按下 Ctrl"）——
;   那是这类写法的固有性质，不做超时自动松开（避免把机制搞复杂）。
RunBoxReleaseModifiers() {
    stuck := []
    for k in ["Ctrl", "Shift", "Alt", "LWin", "RWin"]
        if GetKeyState(k, "P")
            stuck.Push(k)
    if (stuck.Length = 0)
        return
    for k in stuck {
        try SendEvent("{" . k . " up}")
    }
    DebugLog("[runbox] 已抬起执行后仍按下的修饰键：" . RunBoxJoinList(stuck, "、"))
}

; ---- 收尾：停掉定时器、交还 Esc、显示结果 ----
; 收尾：回到可编辑状态；focusTarget = true（正常执行完）时把焦点还给"最近一次活动的窗口"
RunBoxFinish(msg, focusTarget := true) {
    global runboxBusy, runboxState, runboxGui, runboxEdit, runboxStartTick
    global runboxPrevWin, runboxPrevTitle, runboxExecBaseWin, runboxLastResult
    SetTimer(RunBoxStep, 0)
    runboxBusy := false
    RunBoxReleaseModifiers()                    ; 兜底：抬起序列可能留下的悬挂修饰键
    runboxLastResult := msg                     ; 反馈学习要参考"上一次的结局"
    RunBoxJournalFlush(msg)                     ; 运行流水：每次需求的结局只写一次
    RunBoxEscOff()
    DebugLog("[runbox] " . msg)
    RunBoxLogAdd("[结果] " . msg . "（本次共 " . (A_TickCount - runboxStartTick) . "ms）")
    ; 回到可编辑状态：输入框清空，方便直接接着输入下一条需求（运行框保持打开）
    runboxState := "input"
    hw := RunBoxHwnd()
    if (!hw)
        return
    try runboxEdit.Value := ""
    RunBoxInputVisible(true)

    ; 焦点去向（用户要求，"最近操作过的窗口"原则）：
    ;   · 正常执行完：
    ;       ① 动作打开了**新窗口**（执行后前台是"别的窗口"）→ 让新窗口保持焦点，绝不抢回来；
    ;       ② 没有打开新窗口 → 焦点回到执行前那个"最近活动的窗口"（例如原来在编辑的文本框）；
    ;       ③ 判定时**一律排除自然语言运行框自己**（它可以在必要时有焦点，但既不算动作目标，
    ;          也不算"要回退到的上一个窗口"）。
    ;   · 被 Esc 中止 / 没有可用目标窗口 → 焦点留在运行框，方便改一改再跑。
    keepNew := false
    if (focusTarget) {
        fg := WinExist("A")
        base := runboxExecBaseWin
        ; 前台不是运行框自己、并且不是执行前那个窗口 → 说明动作打开了新窗口
        if (!RunBoxIsSelfWin(fg) && (!base || fg != base))
            keepNew := true
    }
    if (keepNew) {
        ; ① 打开了新窗口：什么都别做，让新窗口保持焦点（绝不把焦点抢回运行框）
        fg := WinExist("A")
        t := ""
        try WinGetTitle(&t, "ahk_id " . fg)
        if (StrLen(t) > 24)
            t := SubStr(t, 1, 24) . "…"
        if (t = "")
            t := "新打开的程序"
        RunBoxSetStatus(msg . " · 焦点留在新窗口「" . t . "」（点输入框或按触发键可回到这里）")
        DebugLog("[runbox] 动作打开了新窗口，焦点留在 " . fg . "「" . t . "」")
    } else {
        ; ② 没打开新窗口 → 把焦点还给执行前那个"最近活动的窗口"；没有可用目标才留在运行框
        back := false
        if (focusTarget && runboxPrevWin && WinExist("ahk_id " . runboxPrevWin))
            back := RadialActivateFocusWin(runboxPrevWin)
        if (back) {
            t := runboxPrevTitle
            if (StrLen(t) > 24)
                t := SubStr(t, 1, 24) . "…"
            if (t = "")
                t := "目标窗口"
            RunBoxSetStatus(msg . " · 焦点已还给「" . t . "」（点输入框或按触发键可回到这里）")
            DebugLog("[runbox] 焦点已还给目标窗口 " . runboxPrevWin)
        } else {
            RunBoxFocusInput()                 ; 面板与输入框是两个窗口：激活 / 聚焦都要走这里
            RunBoxSetStatus(msg . " · 可直接输入下一个需求（Esc 关闭）")
        }
    }
}

; ---- 执行期间接管 Esc（按一次中止后续动作），结束后交还给浮层栈或系统 ----
RunBoxEscOn() {
    Hotkey("Escape", RunBoxEscHandler, "On")
}

RunBoxEscOff() {
    global overlayStack
    if (IsSet(overlayStack) && overlayStack.Length > 0) {
        OverlayRegisterEscape()        ; 还有浮层开着：把 Esc 还给它们
    } else {
        ; 必须包 try：Escape 当时没注册的话，Hotkey(...,"Off") 会抛 Nonexistent hotkey
        ; （与 OverlayUnregisterEscape 同一处理；关闭运行框但没执行过动作时就会走到这里）
        try Hotkey("Escape", "Off")
    }
}

RunBoxEscHandler(*) {
    global runboxBusy
    if (runboxBusy) {
        SetTimer(RunBoxStep, 0)
        DebugLog("[runbox] 用户按 Esc 中止了后续动作")
        RunBoxFinish("已被 Esc 中止，剩余动作不再执行", false)   ; 中止时焦点留在运行框，方便改完再跑
        return
    }
    RunBoxEsc()
}

; ---- 加载 config.ini 的 [keypad] 与 [keypad.<kind>] 段 ----
; 采用与径向菜单一致的**自定义行解析**（FileRead 自动识别 UTF-16 / UTF-8 BOM）：
;   · 以 ; 开头的整行是注释；行内注释为「空白 + ;」起至行尾（与径向菜单同一规则）；
;   · 值里的 ; 与 | 用 %3B / %7C 转义（沿用统计键 %3D 的转义约定）；
;   · 解析结果非法 / 缺失时一律沿用内置默认（防空 + 防呆）。
;
; 四个面板各自一个子段：[keypad.arrow] / [keypad.numpad] / [keypad.symbol] / [keypad.letter]
;   name   = 面板名（仅日志用，不显示在面板上）
;   cols   = 列数（1~12）；rows = 行数（1~12）
;   square = true / false：按键是否正方形（默认 false，方向键盘默认为 true）
;   case   = true / false：是否启用「大小写状态」（默认 false，字母键盘默认为 true）
;   编号   = 名称 | 动作     编号即格子序号（行优先，1 起）；缺号 = 空位（不绘制、不命中）
;
; 动作支持四种写法：
;   ① 普通 Send 字符串：{BS} / ^c / 7 / {Enter} …（发送到当前前台窗口）
;   ② run: 命令行          ：run: notepad.exe
;   ③ 内置动作             ：close = 关闭本面板；case = 切换大小写
;   ④ self: 命令           ：直接调用本脚本自身功能（见 OverlayRunSelf）
KeypadLoadConfig() {
    global configFile, keypadArrowHotkey, keypadNumpadHotkey, keypadSymbolHotkey, keypadLetterHotkey
    global keypadFontSize, keypadOpacity, keypadDefs, ui_font_size

    ; 内置默认（等于改造前写死的四套按键；配置缺失 / 非法时就用它）
    keypadArrowHotkey  := "^+k"                 ; 方向小键盘触发键（默认 Ctrl+Shift+K）
    keypadNumpadHotkey := "^+n"                 ; 数字小键盘触发键（默认 Ctrl+Shift+N）
    keypadSymbolHotkey := "^+y"                 ; 符号小键盘触发键（默认 Ctrl+Shift+Y）
    keypadLetterHotkey := "^+e"                 ; 字母小键盘触发键（默认 Ctrl+Shift+E）
    keypadFontSize     := Max(ui_font_size, 6)  ; 字体大小默认 = 全局 [ui] font_size
    keypadOpacity      := 1.0                   ; 面板透明度（0.0~1.0），默认 1 = 不透明
    keypadDefs         := KeypadDefaultDefs()

    if !FileExist(configFile)
        return

    txt := ""
    try {
        txt := FileRead(configFile, "UTF-16")
    } catch {
        try {
            txt := FileRead(configFile, "UTF-8")
        } catch {
            return
        }
    }
    if (txt = "")
        return

    section := ""      ; ""（不在小键盘段）/ "keypad" / "keypad.<kind>"
    pending := Map()   ; kind -> Map(编号 -> 原始值)：读完整份文件再落地，与字段书写顺序无关
    names := Map()     ; kind -> 段内 name

    Loop parse, txt, "`n", "`r"
    {
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        if RegExMatch(line, "\s;", &cm)
            line := Trim(SubStr(line, 1, cm.Pos - 1))
        if (line = "")
            continue

        ; 节头
        if (SubStr(line, 1, 1) = "[") {
            if (line = "[keypad]") {
                section := "keypad"
            } else if (SubStr(line, 1, 8) = "[keypad." && SubStr(line, -1) = "]") {
                k := SubStr(line, 9, StrLen(line) - 9)
                ; 只要 keypadDefs 里有这个面板就认（arrow / numpad / symbol / letter / runkeys…），
                ; 以后再加面板不必改这里；不认识的段名一律忽略
                section := keypadDefs.Has(k) ? "keypad." . k : ""
            } else {
                section := ""
            }
            continue
        }

        if (section = "")
            continue
        eqPos := InStr(line, "=")
        if (eqPos = 0)
            continue
        key := Trim(SubStr(line, 1, eqPos - 1))
        value := Trim(SubStr(line, eqPos + 1))

        if (section = "keypad") {
            ; 与原 IniRead 版语义一致：空值 / 非法值一律忽略（沿用默认）
            if (key = "arrow_hotkey" && value != "")
                keypadArrowHotkey := value
            else if (key = "numpad_hotkey" && value != "")
                keypadNumpadHotkey := value
            else if (key = "symbol_hotkey" && value != "")
                keypadSymbolHotkey := value
            else if (key = "letter_hotkey" && value != "")
                keypadLetterHotkey := value
            else if (key = "font_size" && RegExMatch(value, "^\d+(\.\d+)?$"))
                keypadFontSize := Max(value + 0, 6)
            else if (key = "opacity" && RegExMatch(value, "^\d*\.?\d+$"))
                keypadOpacity := Max(0.0, Min(value + 0, 1.0))
            continue
        }

        kind := SubStr(section, 8)          ; "keypad." 是 7 个字符
        def := keypadDefs[kind]
        if (key = "name") {
            names[kind] := value
        } else if (key = "cols" && RegExMatch(value, "^\d+$")) {
            def.cols := Max(1, Min(Integer(value), 12))
        } else if (key = "rows" && RegExMatch(value, "^\d+$")) {
            def.rows := Max(1, Min(Integer(value), 12))
        } else if (key = "square") {
            def.square := (StrLower(value) = "true")
        } else if (key = "case") {
            def.case := (StrLower(value) = "true")
        } else if RegExMatch(key, "^\d+$") {
            if (!pending.Has(kind))
                pending[kind] := Map()
            pending[kind][Integer(key)] := value
        }
    }

    ; 落地：段里写了按键就整体替换该面板的按键；一个键都没写则**保留内置默认**（防空）
    for kind, items in pending {
        def := keypadDefs[kind]
        total := def.cols * def.rows
        keys := []
        Loop total
            keys.Push({label: "", action: "", role: "blank"})
        for num, raw in items {
            if (num < 1 || num > total) {
                DebugLog("[keypad] " . kind . " 的编号 " . num . " 超出 " . def.cols . "×" . def.rows . " 范围，已忽略")
                continue
            }
            it := KeypadParseItem(raw)
            keys[num] := {label: it.label, action: it.action, role: KeypadRoleFor(it.action)}
        }
        def.keys := keys
    }
    for kind, nm in names {
        if (nm != "")
            keypadDefs[kind].name := nm
    }

    DebugLog("[keypad] 配置加载完成：arrow_hotkey=" . keypadArrowHotkey . " numpad_hotkey=" . keypadNumpadHotkey
        . " symbol_hotkey=" . keypadSymbolHotkey . " letter_hotkey=" . keypadLetterHotkey
        . " font_size=" . keypadFontSize . " opacity=" . keypadOpacity
        . " defs=" . KeypadDefsSummary())
}

; ---- 解析一个按键值："名称 | 动作"（没有 | 时整串当动作，名称留空）----
KeypadParseItem(value) {
    pipePos := InStr(value, "|")
    if (pipePos = 0) {
        label := ""
        act := Trim(value)
    } else {
        label := Trim(SubStr(value, 1, pipePos - 1))
        act := Trim(SubStr(value, pipePos + 1))
    }
    return {label: KeypadUnescape(label), action: KeypadUnescape(act)}
}

; ---- 反转义：%7C → |、%3B → ;（沿用统计键 %3D 的约定）----
KeypadUnescape(text) {
    return StrReplace(StrReplace(text, "%7C", "|"), "%3B", ";")
}

; ---- 动作 → 绘制角色：空 = 空位；close / case = 内置动作；其余 = 普通按键 ----
; 判定统一交给浮层动作层（OverlayActionParse），所以以后新增动作类型这里不用改。
KeypadRoleFor(action) {
    act := OverlayActionParse(action)
    if (act.type = "none")
        return "blank"
    if (act.type = "close" || act.type = "case")
        return act.type
    return "key"
}

; ---- 内置默认：与改造前写死的四套按键逐键一致 ----
KeypadDefaultDefs() {
    defs := Map()

    ; 方向键盘：3×3 十字（四角 = 退格 / 删除 / 上页 / 下页，中心【回车】），按键为正方形
    defs["arrow"] := {name: "方向键盘", cols: 3, rows: 3, square: true, case: false, keys: [
        {label: "退格", action: "{BS}",    role: "key"},
        {label: "↑",   action: "{Up}",    role: "key"},
        {label: "删除", action: "{Del}",   role: "key"},
        {label: "←",   action: "{Left}",  role: "key"},
        {label: "回车", action: "{Enter}", role: "key"},
        {label: "→",   action: "{Right}", role: "key"},
        {label: "上页", action: "{PgUp}",  role: "key"},
        {label: "↓",   action: "{Down}",  role: "key"},
        {label: "下页", action: "{PgDn}",  role: "key"}
    ]}

    ; 数字键盘：4 列 × 4 行（右列四则运算，末行 0 . ÷ 回车）
    defs["numpad"] := {name: "数字键盘", cols: 4, rows: 4, square: false, case: false, keys: [
        {label: "7", action: "7", role: "key"}, {label: "8", action: "8", role: "key"}, {label: "9", action: "9", role: "key"}, {label: "+", action: "{+}", role: "key"},
        {label: "4", action: "4", role: "key"}, {label: "5", action: "5", role: "key"}, {label: "6", action: "6", role: "key"}, {label: "-", action: "-", role: "key"},
        {label: "1", action: "1", role: "key"}, {label: "2", action: "2", role: "key"}, {label: "3", action: "3", role: "key"}, {label: "×", action: "*", role: "key"},
        {label: "0", action: "0", role: "key"}, {label: ".", action: ".", role: "key"}, {label: "÷", action: "/", role: "key"}, {label: "回车", action: "{Enter}", role: "key"}
    ]}

    ; 符号键盘：6 列 × 5 行共 30 键（标准键盘里其余符号 + 一个重复的 / + 空格 / Tab）
    defs["symbol"] := {name: "符号键盘", cols: 6, rows: 5, square: false, case: false, keys: [
        {label: "(", action: "(", role: "key"}, {label: ")", action: ")", role: "key"}, {label: "[", action: "[", role: "key"}, {label: "]", action: "]", role: "key"}, {label: "{", action: "{{}", role: "key"}, {label: "}", action: "{}}", role: "key"},
        {label: "<", action: "<", role: "key"}, {label: ">", action: ">", role: "key"}, {label: "\", action: "\", role: "key"}, {label: "|", action: "|", role: "key"}, {label: ";", action: ";", role: "key"}, {label: ":", action: ":", role: "key"},
        {label: "'", action: "'", role: "key"}, {label: "`"", action: "`"", role: "key"}, {label: ",", action: ",", role: "key"}, {label: "?", action: "?", role: "key"}, {label: "!", action: "{!}", role: "key"}, {label: "@", action: "@", role: "key"},
        {label: "#", action: "{#}", role: "key"}, {label: "$", action: "$", role: "key"}, {label: "%", action: "%", role: "key"}, {label: "^", action: "{^}", role: "key"}, {label: "&", action: "&", role: "key"}, {label: "_", action: "_", role: "key"},
        {label: "=", action: "=", role: "key"}, {label: "~", action: "~", role: "key"}, {label: "``", action: "``", role: "key"}, {label: "/", action: "/", role: "key"}, {label: "空格", action: "{Space}", role: "key"}, {label: "Tab", action: "{Tab}", role: "key"}
    ]}

    ; 运行框下方的热键键帽：一排 7 个（复用同一套布局 / 绘制 / 文字层，
    ; 所以字符款式、字号、黑边、颜色与小键盘完全一致）
    defs["runkeys"] := {name: "运行热键", cols: 7, rows: 1, square: false, case: false, keys: [
        {label: "回车", action: "{Enter}",      role: "key"},
        {label: "Tab",  action: "{Tab}",        role: "key"},
        {label: "空格", action: "{Space}",      role: "key"},
        {label: "删除", action: "{Del}",        role: "key"},
        {label: "退格", action: "{BS}",         role: "key"},
        {label: "取消", action: "{Esc}",        role: "key"},
        {label: "触发", action: "self:trigger", role: "key"}
    ]}

    ; 字母键盘：6 列 × 5 行（a-z + 【Aa】大小写切换 + 回车 / 反斜杠 / 【触发】）
    letterKeys := []
    Loop 26 {
        ch := Chr(96 + A_Index)                 ; 97 = "a"、122 = "z"
        letterKeys.Push({label: ch, action: ch, role: "key"})
    }
    letterKeys.Push({label: "Aa",   action: "case",         role: "case"})
    letterKeys.Push({label: "回车", action: "{Enter}",       role: "key"})
    letterKeys.Push({label: "\",   action: "\",            role: "key"})
    letterKeys.Push({label: "触发", action: "self:trigger",  role: "key"})
    defs["letter"] := {name: "字母键盘", cols: 6, rows: 5, square: false, case: true, keys: letterKeys}

    return defs
}

; ---- 供日志用的定义摘要（每块面板：列 × 行、键数与启用状态）----
KeypadDefsSummary() {
    global keypadDefs
    s := ""
    for kind in ["arrow", "numpad", "symbol", "letter"] {
        if (!keypadDefs.Has(kind))
            continue
        d := keypadDefs[kind]
        s .= (s = "" ? "" : " | ") . kind . "=" . d.cols . "x" . d.rows . "/" . d.keys.Length . "键"
            . (d.square ? "/square" : "") . (d.case ? "/case" : "")
    }
    return s
}

; ---- 按键定义：按当前大小写状态生成（仅供渲染 / 命中；定义本身不变）----
; 大小写只作用于「动作恰好是一个 ASCII 小写字母」的键：标签与发送内容一起变大写。
KeypadKeysFor(kind) {
    global keypadDefs
    if (!keypadDefs.Has(kind))
        return []
    def := keypadDefs[kind]
    ; 只有 case = true 的面板才受大小写状态影响（状态由共用动作层按浮层名保存）
    upper := (def.case ? OverlayCaseUpper(kind) : false)
    keys := []
    for k in def.keys {
        kk := {label: k.label, action: k.action, role: k.role}
        if (upper) {
            kk := OverlayCaseTransform(kind, kk.label, kk.action)   ; 只对"动作是单个 a-z 字母"的键生效
            kk.role := k.role                                       ; 该变换只返回 label/action，role 必须补回来
        }                                                           ; （否则大写状态下命中测试读 .role 会直接崩）
        keys.Push(kk)
    }
    return keys
}

; ---- 面板列数 / 行数 / 是否正方形按键 / 是否启用大小写（都来自定义表）----
KeypadColsFor(kind) {
    global keypadDefs
    return keypadDefs.Has(kind) ? keypadDefs[kind].cols : 3
}

KeypadRowsFor(kind) {
    global keypadDefs
    return keypadDefs.Has(kind) ? keypadDefs[kind].rows : 1
}

KeypadSquareFor(kind) {
    global keypadDefs
    return keypadDefs.Has(kind) ? keypadDefs[kind].square : false
}

; ---- 计算布局：按字号实测文字宽度，紧凑自适应 ----
; 返回 {cols, rows, pad, gap, winW, winH, rects:[{x, y, w, h}]}（rects 为面板客户区坐标）
KeypadComputeLayout(kind, keys, sizePt) {
    fontPx := Max(Round(sizePt * 96 / 72), 8)
    pad := Max(Round(fontPx * 0.45), 6)     ; 面板内边距
    gap := Max(Round(fontPx * 0.28), 4)     ; 按键间距
    padIn := Max(Round(fontPx * 0.55), 8)   ; 按键内文字留白
    cols := KeypadColsFor(kind)
    ; 行数取「定义里声明的行数」与「按键数推导」的较大者（声明了空位也保留行数；越界时兜底）
    rows := Max(KeypadRowsFor(kind), Ceil(keys.Length / cols))

    ; 单元尺寸：宽 = 最宽按键文字 + 左右留白；高 = 字高 + 上下留白
    maxW := fontPx
    for k in keys {
        if (k.label = "")
            continue
        w := RadialMeasureText(k.label, sizePt).w
        if (w > maxW)
            maxW := w
    }
    cellW := maxW + 2 * padIn
    cellH := fontPx + 2 * padIn
    if (KeypadSquareFor(kind)) {
        ; 方向键做成正方形（笔点更舒服）：取"文字宽度"与"2.4 倍字高"的较大者
        side := Max(cellW, Round(fontPx * 2.4))
        cellW := side
        cellH := side
    }
    winW := 2 * pad + cols * cellW + (cols - 1) * gap
    winH := 2 * pad + rows * cellH + (rows - 1) * gap

    rects := []
    for i, k in keys {
        r := (i - 1) // cols
        c := Mod(i - 1, cols)
        rects.Push({x: pad + c * (cellW + gap), y: pad + r * (cellH + gap), w: cellW, h: cellH})
    }
    return {cols: cols, rows: rows, pad: pad, gap: gap, cellW: cellW, cellH: cellH
        , winW: winW, winH: winH, rects: rects}
}

; ---- 触发键入口：只管自己这一个面板（未打开则弹出，已打开则关闭）----
; 注意：这里**不**联动关闭径向菜单或另一个小键盘——三个浮层互相独立。
KeypadToggle(kind) {
    global keypadPanels
    if (keypadPanels.Has(kind)) {
        KeypadClose(kind)
        return
    }
    KeypadShow(kind)
}

; ---- 某个面板该用的透明度 ----
; 四块普通小键盘用 [keypad] opacity；键帽排 runkeys 属于运行框的一部分，
; 用 [runbox] opacity（用户要求：运行框本体与它下方那排键帽共用一套透明度）。
KeypadOpacityOf(kind) {
    global keypadOpacity, runboxOpacity
    if (kind = "runkeys")
        return IsSet(runboxOpacity) ? runboxOpacity : 1.0
    return IsSet(keypadOpacity) ? keypadOpacity : 1.0
}

; ---- 弹出面板（在鼠标位置；限制在全部显示器合并区域内）----
; pushEscape = false：只建面板、不登记浮层栈（用于运行框下方的键帽排——它不接管 Esc）
KeypadShow(kind, pushEscape := true) {
    global keypadPanels, keypadFontSize, keypadOpacity

    if (keypadPanels.Has(kind))
        KeypadClose(kind)          ; 防御：同类型已在显示时先收起再重建

    keys := KeypadKeysFor(kind)
    layout := KeypadComputeLayout(kind, keys, keypadFontSize)
    P := {gui: 0, textGui: 0, keys: keys, layout: layout, hover: 0, focusWin: 0, registered: false
        , dragPending: false, dragging: false, dragMoved: false, dragIndex: 0
        , dragStartX: 0, dragStartY: 0, dragWinX: 0, dragWinY: 0}
    keypadPanels[kind] := P

    ; 记录弹出前的前台窗口（面板不抢焦点，正常不会改变前台窗口；发送按键时作兜底）
    P.focusWin := WinExist("A")

    ; 鼠标坐标：热键线程默认是"客户区坐标"，先显式设为屏幕坐标（否则非全屏窗口下会偏移）
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    L := P.layout
    vb := RadialVirtualBounds()
    guiX := Max(vb.x, Min(mx - L.winW // 2, vb.x + vb.w - L.winW))
    guiY := Max(vb.y, Min(my - L.winH // 2, vb.y + vb.h - L.winH))

    ; +E0x08000000 = WS_EX_NOACTIVATE：点击 / 拖动面板都不激活面板、不改变前台窗口，
    ; 因此点击按键时 Send 才能发到用户原本正在编辑的窗口。
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    g.BackColor := "2D2D3D"
    g.MarginX := 0
    g.MarginY := 0
    g.OnEvent("Escape", (*) => KeypadClose(kind))
    g.Show("x" . guiX . " y" . guiY . " w" . L.winW . " h" . L.winH . " NoActivate")
    P.gui := g

    ; 应用配置的透明度（取值 0.0~1.0）。
    ; 键帽排 runkeys 属于运行框的一部分 —— 用户要求运行框整体一套透明度，所以它用 [runbox] opacity，
    ; 其余四块面板用 [keypad] opacity。
    op := KeypadOpacityOf(kind)
    if ((op + 0) < 1.0) {
        GWL_EXSTYLE := -20
        WS_EX_LAYERED := 0x00080000
        getWindowLongFn := (A_PtrSize = 8) ? "GetWindowLongPtrW" : "GetWindowLongW"
        setWindowLongFn := (A_PtrSize = 8) ? "SetWindowLongPtrW" : "SetWindowLongW"
        ex := DllCall(getWindowLongFn, "Ptr", g.Hwnd, "Int", GWL_EXSTYLE, "Ptr")
        DllCall(setWindowLongFn, "Ptr", g.Hwnd, "Int", GWL_EXSTYLE, "Ptr", ex | WS_EX_LAYERED, "Ptr")
        alpha := Round(op * 255)
        if (alpha < 0)
            alpha := 0
        if (alpha > 255)
            alpha := 255
        DllCall("SetLayeredWindowAttributes", "Ptr", g.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 0x2)
    }

    ; 圆角矩形窗口（SetWindowRgn 后系统接管该区域，勿 DeleteObject）
    hRgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", L.winW + 1, "Int", L.winH + 1
        , "Int", 14, "Int", 14, "Ptr")
    DllCall("SetWindowRgn", "Ptr", g.Hwnd, "Ptr", hRgn, "Int", 1)

    ; 注册鼠标消息（多个面板共用同一批回调，按引用计数）并登记 Esc 接管
    KeypadRegisterMsg(g.Hwnd)
    P.registered := true
    if (pushEscape)
        OverlayPush(kind)

    ; 文字层：文字始终不透明（不受 opacity 影响），单独一层、与主面板完全重合
    P.textGui := OverlayTextLayerNew(guiX, guiY, L.winW, L.winH)

    ; 首次绘制
    KeypadDraw(kind)

    ; 与其它已打开浮层避让（同屏时不允许重叠；面板刚弹出，以它为准推开别人）
    OverlayAvoid(kind)

    ; 文字层内容（在避让之后绘制，保证与面板最终位置完全一致）
    KeypadTextLayerPresent(kind)
}

; ---- 关闭指定面板（只关这一个，不影响径向菜单与另一个小键盘）----
KeypadClose(kind) {
    global keypadPanels
    if (!keypadPanels.Has(kind))
        return
    P := keypadPanels[kind]
    keypadPanels.Delete(kind)

    ; 清理拖拽状态并释放鼠标捕获（拖动中途关闭时不留后遗症）
    P.dragPending := false
    P.dragging := false
    P.dragMoved := false
    P.dragIndex := 0
    DllCall("ReleaseCapture")

    if (P.registered) {
        KeypadUnregisterMsg()
        P.registered := false
    }
    OverlayTextLayerDestroy(P.textGui)
    P.textGui := 0
    if (P.gui) {
        P.gui.Destroy()
        P.gui := 0
    }
    OverlayRemove(kind)
}

; ---- 按窗口句柄找面板类型（消息回调分发用）；未找到返回空串 ----
KeypadKindByHwnd(hwnd) {
    global keypadPanels
    for kind, P in keypadPanels {
        if (P.gui && P.gui.Hwnd = hwnd)
            return kind
    }
    return ""
}

; ---- 命中检测：返回按键索引（1 基），0 = 未命中（空白处 / 空位）----
KeypadHitTest(kind, mx, my) {
    global keypadPanels
    if (!keypadPanels.Has(kind))
        return 0
    P := keypadPanels[kind]
    if (!P.gui || !P.layout)
        return 0
    WinGetPos(&wx, &wy, , , "ahk_id " . P.gui.Hwnd)
    lx := mx - wx
    ly := my - wy
    L := P.layout
    for i, R in L.rects {
        if (i > P.keys.Length || P.keys[i].role = "blank")
            continue
        if (lx >= R.x && lx < R.x + R.w && ly >= R.y && ly < R.y + R.h)
            return i
    }
    return 0
}

; ---- 绘制面板（经典 Win32 GDI 双缓冲，不用 GDI+）----
KeypadDraw(kind) {
    global keypadPanels, keypadFontSize
    if (!keypadPanels.Has(kind))
        return
    P := keypadPanels[kind]
    if (!P.gui || !P.layout)
        return
    hwnd := P.gui.Hwnd
    L := P.layout

    hdc := DllCall("GetDC", "Ptr", hwnd, "Ptr")
    if (!hdc)
        return
    memDC := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", L.winW, "Int", L.winH, "Ptr")
    oldBmp := DllCall("SelectObject", "Ptr", memDC, "Ptr", hbm, "Ptr")

    ; 背景（与径向菜单同色系）
    bgBrush := BrushSolid("2D2D3D")
    DllCall("FillRect", "Ptr", memDC, "Ptr", RectStruct(0, 0, L.winW, L.winH), "Ptr", bgBrush)
    DllCall("DeleteObject", "Ptr", bgBrush)

    ; 按键：常态 / 悬停高亮；回车键（方向面板中心 / 数字面板右下角）用偏蓝以作区分
    ; 字母面板的【Aa】切换键另用一种配色：大写状态偏暖色，相当于 CapsLock 指示灯
    ; （role = "close" 的暗红配色保留在代码里，当前四套按键都没有【关】键）
    Loop P.keys.Length {
        i := A_Index
        k := P.keys[i]
        if (k.role = "blank")
            continue
        if (i > L.rects.Length)
            break
        R := L.rects[i]
        if (P.hover = i)
            bg := (k.role = "close") ? "C0392B" : "4A90D9"
        else if (k.role = "close")
            bg := "5A3A3A"
        else if (k.role = "case")
            bg := OverlayCaseUpper(kind) ? "A0682A" : "3E4A6A"
        else if (k.label = "回车")
            bg := "3E5A7A"
        else
            bg := "3A4455"

        rgn := DllCall("CreateRoundRectRgn", "Int", R.x, "Int", R.y, "Int", R.x + R.w + 1, "Int", R.y + R.h + 1
            , "Int", 12, "Int", 12, "Ptr")
        brush := BrushSolid(bg)
        DllCall("FillRgn", "Ptr", memDC, "Ptr", rgn, "Ptr", brush)
        DllCall("DeleteObject", "Ptr", brush)
        DllCall("DeleteObject", "Ptr", rgn)

        ; 文字不在这里画：文字统一由独立的文字层绘制（见 KeypadPaintTexts / 10c-3），
        ; 这样文字不会跟随主窗口的透明度变淡。
    }

    ; 一次 BitBlt 到位
    DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", L.winW, "Int", L.winH
        , "Ptr", memDC, "Int", 0, "Int", 0, "UInt", 0x00CC0020)

    ; 清理
    DllCall("SelectObject", "Ptr", memDC, "Ptr", oldBmp, "Ptr")
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", memDC)
    DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
}

; ---- 绘制按键文字（水平垂直双居中）----
; colorDC 画配置色字身；maskDC 画白色"字身 + 黑边"，其覆盖度作为最终 alpha。
KeypadDrawText(maskDC, colorDC, text, cx, cy, sizePt) {
    if (text = "")
        return
    font := RadialCreateFont(sizePt, "Microsoft YaHei")
    oldFont := DllCall("SelectObject", "Ptr", colorDC, "Ptr", font, "Ptr")
    sz := Buffer(8)
    DllCall("GetTextExtentPoint32W", "Ptr", colorDC, "Str", text, "Int", StrLen(text), "Ptr", sz)
    tw := NumGet(sz, 0, "Int")
    th := NumGet(sz, 4, "Int")
    l := cx - tw // 2
    t := cy - th // 2
    r := cx + tw // 2
    b := cy + th // 2

    ; 彩色层：字身
    OverlayDrawCenteredText(colorDC, text, l, t, r, b, OverlayTextColor())
    DllCall("SelectObject", "Ptr", colorDC, "Ptr", oldFont, "Ptr")

    ; 掩码层：先画黑边偏移、最后画字身
    oldFont := DllCall("SelectObject", "Ptr", maskDC, "Ptr", font, "Ptr")
    for off in OverlayTextOffsets(OverlayTextOutlineWidth())
        OverlayDrawCenteredText(maskDC, text, l + off.x, t + off.y, r + off.x, b + off.y, 0xFFFFFF)
    OverlayDrawCenteredText(maskDC, text, l, t, r, b, 0xFFFFFF)

    DllCall("SelectObject", "Ptr", maskDC, "Ptr", oldFont, "Ptr")
    DllCall("DeleteObject", "Ptr", font)
}

; ---- 文字层内容：把面板上所有按键的文字画到给定两块 DC（彩色字身 + 黑色描边掩码）----
; 坐标与主窗口的按键矩形完全一致（同一个 KeypadComputeLayout 结果）。
KeypadPaintTexts(kind, maskDC, colorDC) {
    global keypadPanels, keypadFontSize
    if (!keypadPanels.Has(kind))
        return
    P := keypadPanels[kind]
    if (!P.layout)
        return
    L := P.layout
    for i, k in P.keys {
        if (k.role = "blank" || k.label = "")
            continue
        if (i > L.rects.Length)
            break
        R := L.rects[i]
        KeypadDrawText(maskDC, colorDC, k.label, R.x + R.w // 2, R.y + R.h // 2, keypadFontSize)
    }
}

; ---- 重建 / 刷新某个面板的文字层（自动取面板当前位置，保证与面板完全重合）----
KeypadTextLayerPresent(kind) {
    global keypadPanels
    if (!keypadPanels.Has(kind))
        return
    P := keypadPanels[kind]
    if (!P.gui || !P.textGui || !P.layout)
        return
    WinGetPos(&tx, &ty, , , "ahk_id " . P.gui.Hwnd)
    OverlayTextLayerPresent(P.textGui, tx, ty, P.layout.winW, P.layout.winH
        , (maskDC, colorDC, w, h) => KeypadPaintTexts(kind, maskDC, colorDC))
}

; ---- TrackMouseEvent 结构（WM_MOUSELEAVE 需要；hwndTrack 由调用方传入）----
KeypadTrackMouseEventStruct(hwnd) {
    static tme := 0
    if (!tme) {
        tme := Buffer(16)
        NumPut("UInt", 16, tme, 0)           ; cbSize
        NumPut("UInt", 0x00000002, tme, 4)   ; TME_LEAVE
    }
    NumPut("Ptr", hwnd, tme, 8)              ; hwndTrack
    return tme
}

; ---- 注册鼠标消息（多个面板共用同一批回调：按引用计数注册 / 注销）----
KeypadRegisterMsg(hwnd) {
    global keypadMsgCount, keypadMsgMove, keypadMsgDown, keypadMsgUp, keypadMsgRDown, keypadMsgLeave
    keypadMsgCount++
    if (keypadMsgCount = 1) {
        ; 先注销可能残留的旧回调（OnMessage MaxThreads=0 注销指定回调），避免重复注册累积
        OnMessage(0x0200, KeypadOnMouseMove, 0)
        OnMessage(0x0201, KeypadOnLButtonDown, 0)
        OnMessage(0x0202, KeypadOnLButtonUp, 0)
        OnMessage(0x0204, KeypadOnRButtonDown, 0)
        OnMessage(0x02A3, KeypadOnMouseLeave, 0)
        ; 注册
        keypadMsgMove  := OnMessage(0x0200, KeypadOnMouseMove)    ; WM_MOUSEMOVE
        keypadMsgDown  := OnMessage(0x0201, KeypadOnLButtonDown)  ; WM_LBUTTONDOWN
        keypadMsgUp    := OnMessage(0x0202, KeypadOnLButtonUp)    ; WM_LBUTTONUP
        keypadMsgRDown := OnMessage(0x0204, KeypadOnRButtonDown)  ; WM_RBUTTONDOWN
        keypadMsgLeave := OnMessage(0x02A3, KeypadOnMouseLeave)   ; WM_MOUSELEAVE
    }
    if (hwnd)
        DllCall("TrackMouseEvent", "Ptr", KeypadTrackMouseEventStruct(hwnd), "Int")
}

; ---- 注销鼠标消息（Esc 由 Overlay* 统一管理，这里不碰）----
KeypadUnregisterMsg() {
    global keypadMsgCount
    if (keypadMsgCount > 0)
        keypadMsgCount--
    if (keypadMsgCount > 0)
        return                     ; 还有别的面板打开，钩子保留
    OnMessage(0x0200, KeypadOnMouseMove, 0)
    OnMessage(0x0201, KeypadOnLButtonDown, 0)
    OnMessage(0x0202, KeypadOnLButtonUp, 0)
    OnMessage(0x0204, KeypadOnRButtonDown, 0)
    OnMessage(0x02A3, KeypadOnMouseLeave, 0)
}

; ---- 鼠标移动：更新悬停并重绘；按下期间改为「拖拽判定 / 移动面板」----
; 返回空值放行消息（悬停检测不吞 WM_MOUSEMOVE，避免影响其它窗口/控件）
KeypadOnMouseMove(wParam, lParam, msg, hwnd) {
    global keypadPanels
    kind := KeypadKindByHwnd(hwnd)
    if (kind = "")
        return
    OverlayTouch(kind)           ; 鼠标在面板上移动（含拖拽）也算"操作过"，Esc 优先关它
    P := keypadPanels[kind]

    ; --- 按下期间：只判定拖拽并移动面板，绝不触发按键 ---
    if (P.dragPending || P.dragging) {
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        dx := NumGet(pt, 0, "Int") - P.dragStartX
        dy := NumGet(pt, 4, "Int") - P.dragStartY
        ; 位移超过阈值才认定为拖拽（否则抬起时按点击处理）
        ; 注意：一旦认定为拖拽就必须置 dragMoved，否则抬起时仍会触发按键 ——
        ; 面板是 1:1 跟着光标走的，光标下面始终是同一个按键，命中判定挡不住。
        if (!P.dragging && (Abs(dx) > 3 || Abs(dy) > 3)) {
            P.dragging := true
            P.dragMoved := true
        }
        if (P.dragging) {
            WinGetPos(, , &ww, &wh, "ahk_id " . hwnd)
            ; 与鼠标位移 1:1 跟随；只在**虚拟屏幕**（全部显示器合并区域）内夹取
            vb := RadialVirtualBounds()
            nx := Max(vb.x, Min(P.dragWinX + dx, vb.x + vb.w - ww))
            ny := Max(vb.y, Min(P.dragWinY + dy, vb.y + vb.h - wh))
            P.gui.Move(nx, ny)
            ; 文字层跟着面板一起移动
            OverlayTextLayerMove(P.textGui, nx, ny)
            ; 拖动中以本面板为准，把它压住的其它浮层推开
            OverlayAvoid(kind)
            if (P.hover != 0) {
                P.hover := 0
                KeypadDraw(kind)
            }
        }
        DllCall("TrackMouseEvent", "Ptr", KeypadTrackMouseEventStruct(hwnd), "Int")
        return
    }

    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    ; lParam 客户区坐标可能为负（鼠标被捕获时移出窗口），补 16 位有符号还原
    if (x > 32767)
        x -= 65536
    if (y > 32767)
        y -= 65536
    WinGetPos(&wx, &wy, , , "ahk_id " . hwnd)
    hit := KeypadHitTest(kind, wx + x, wy + y)
    if (hit != P.hover) {
        P.hover := hit
        KeypadDraw(kind)
    }
    DllCall("TrackMouseEvent", "Ptr", KeypadTrackMouseEventStruct(hwnd), "Int")
    return
}

; ---- 鼠标离开：清除悬停 ----
KeypadOnMouseLeave(wParam, lParam, msg, hwnd) {
    global keypadPanels
    kind := KeypadKindByHwnd(hwnd)
    if (kind = "")
        return
    P := keypadPanels[kind]
    ; 拖拽中不做悬停处理（鼠标被捕获，离开通知不代表真的移出）
    if (P.dragPending || P.dragging)
        return
    if (P.hover != 0) {
        P.hover := 0
        KeypadDraw(kind)
    }
    return
}

; ---- 左键按下：只记录"可能的点击"与起点并捕获鼠标；是点击还是拖拽等抬起时按位移判定 ----
; 注意：OnMessage 回调返回「空值」才放行消息；返回整数（含 0）会被当作已回复而吞掉消息。
KeypadOnLButtonDown(wParam, lParam, msg, hwnd) {
    global keypadPanels
    kind := KeypadKindByHwnd(hwnd)
    if (kind = "")
        return
    OverlayTouch(kind)           ; 在面板上按下（含点空位 / 空白处的无效点击）也算"操作过"
    P := keypadPanels[kind]
    OverlayTextLayerRaise(P.textGui)   ; 点击会把面板提到最上层 → 立刻把文字层压回它上面
    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    if (x > 32767)
        x -= 65536
    if (y > 32767)
        y -= 65536
    WinGetPos(&wx, &wy, , , "ahk_id " . hwnd)

    pt := Buffer(8)
    DllCall("GetCursorPos", "Ptr", pt)
    P.dragStartX := NumGet(pt, 0, "Int")
    P.dragStartY := NumGet(pt, 4, "Int")
    P.dragWinX := wx
    P.dragWinY := wy
    P.dragIndex := KeypadHitTest(kind, wx + x, wy + y)
    P.dragPending := true
    P.dragging := false
    P.dragMoved := false
    ; SetCapture：拖动时指针移出面板也能持续收到 WM_MOUSEMOVE，抬起时释放
    DllCall("SetCapture", "Ptr", hwnd, "Ptr")
    return
}

; ---- 左键抬起：未拖动 → 触发按下的按键（且抬起点仍在同一按键上）；拖动过 → 只移动面板 ----
KeypadOnLButtonUp(wParam, lParam, msg, hwnd) {
    global keypadPanels
    kind := KeypadKindByHwnd(hwnd)
    if (kind = "")
        return
    OverlayTouch(kind)           ; 抬起同样算"操作过"（拖动过、点空位、点空白的抬起都算）
    P := keypadPanels[kind]
    if (!P.dragPending && !P.dragging)
        return
    P.dragPending := false
    P.dragging := false
    DllCall("ReleaseCapture")

    if (P.dragMoved) {
        ; 拖动过 → 只移动了面板，不触发按键（也不做任何其它动作）
        P.dragMoved := false
        P.dragIndex := 0
        DllCall("TrackMouseEvent", "Ptr", KeypadTrackMouseEventStruct(hwnd), "Int")
        return
    }
    P.dragMoved := false

    idx := P.dragIndex
    P.dragIndex := 0
    if (idx < 1)
        return
    ; 抬起位置仍落在同一个按键上才响应（按下后拖出按键 = 取消）
    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    if (x > 32767)
        x -= 65536
    if (y > 32767)
        y -= 65536
    WinGetPos(&wx, &wy, , , "ahk_id " . hwnd)
    if (KeypadHitTest(kind, wx + x, wy + y) = idx)
        KeypadOnKeyPress(kind, idx)
    return
}

; ---- 右键点击：关闭被点的那个面板（并吞掉消息，避免穿透到下层窗口弹出右键菜单）----
KeypadOnRButtonDown(wParam, lParam, msg, hwnd) {
    kind := KeypadKindByHwnd(hwnd)
    if (kind != "") {
        KeypadClose(kind)
        return 0
    }
    return
}

; ---- 按键响应：统一交给浮层动作层执行（close / case / run: / self: / 普通按键）----
KeypadOnKeyPress(kind, idx) {
    global keypadPanels
    if (!keypadPanels.Has(kind))
        return
    P := keypadPanels[kind]
    if (idx < 1 || idx > P.keys.Length)
        return
    k := P.keys[idx]
    if (k.role = "blank" || k.action = "")
        return
    OverlayActionExecute(OverlayActionParse(k.action), kind, P.focusWin)
    return
}

; ============================================================================
; 11. 模式切换命令 —— 均可通过配置修改
;     循环切换：默认 Ctrl+Shift+J（latex → unicode → AI → tikz → latex）
;     直接切换：默认 Ctrl+Shift+0/1/2/3（0=latex，1=unicode，2=AI，3=tikz），前缀可配置
;     模式列表：默认 Ctrl+Shift+\（弹出无框列表，上下键选择 + Enter 切换，或鼠标点击目标模式直接切换）
; ============================================================================
Hotkey(toggle_hk, ToggleMode)
Hotkey(direct_prefix . "0", (*) => SetModeDirect(MODE_LATEX))
Hotkey(direct_prefix . "1", (*) => SetModeDirect(MODE_UNICODE))
Hotkey(direct_prefix . "2", (*) => SetModeDirect(MODE_AI))
Hotkey(direct_prefix . "3", (*) => SetModeDirect(MODE_TIKZ))
Hotkey(mode_list_hk, ShowModeList)
Hotkey(step_hotkey, StepPlay)

; 径向菜单触发快捷键（[radial] trigger 配置，默认 Ctrl+Shift+M）
if (radialTrigger != "")
    Hotkey(radialTrigger, RadialShow)

; 屏幕小键盘触发快捷键（[keypad] arrow / numpad / symbol / letter _hotkey，默认 ^+k / ^+n / ^+y / ^+e）
; 同一键为开/关切换；四块面板互相独立，可同时显示
if (keypadArrowHotkey != "")
    Hotkey(keypadArrowHotkey, (*) => KeypadToggle("arrow"))
if (keypadNumpadHotkey != "")
    Hotkey(keypadNumpadHotkey, (*) => KeypadToggle("numpad"))
if (keypadSymbolHotkey != "")
    Hotkey(keypadSymbolHotkey, (*) => KeypadToggle("symbol"))
if (keypadLetterHotkey != "")
    Hotkey(keypadLetterHotkey, (*) => KeypadToggle("letter"))

; 自然语言运行框触发键（[runbox] hotkey，默认 F6）：只负责打开 / 把光标拿回输入框，
; 已打开时再按**不关闭**（关闭请在运行框上按 Esc，见 RunBoxShow / RunBoxEsc）
if (runboxHotkey != "")
    Hotkey(runboxHotkey, (*) => RunBoxShow())

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
    prevWin := WinExist("A")          ; 弹出前的原窗口：列表关闭后等焦点归还原窗口再返回
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
    lbHwnd := lb.Hwnd       ; 钩子内只认这个整数 HWND：控件销毁后访问对象的 .Hwnd 会抛异常

    ; 鼠标 / 笔点击候选行即直接选择（含当前已高亮的第一项：Change 事件对"选择未变化"不触发，
    ; 故不能用 Change，改在列表弹出期间注册全局鼠标钩子判定点击落点）。
    ; 钩子只在点击确实落在本列表框的某一行上时才提交，其余情况一律传空值放行；
    ; 上下键移动 + Enter 选择 + Esc 取消等原有能力完全不受影响。
    ; 取 WM_LBUTTONUP（抬起）而非 WM_LBUTTONDOWN（按下）提交：按下时左键还按着，
    ; 此刻隐藏列表窗口会让前台激活推迟到松开左键之后——紧接着要输入的补全按键就会发错窗口而丢失
    ; （实测现象：日志显示"点击即选"已确认，但编辑器里没有任何反应）。抬起时按键已松开，与回车等价。
    lbClickHook(wParam, lParam, msg, hwnd) {
        idx := ListClickItemIndex(lbHwnd, hwnd, lParam)
        if (idx < 0)
            return
        chosen := idx
        DebugLog("ShowMultiSelection：点击即选，第 " . (idx + 1) . " 项，直接确认")
        try {
            selGui.Submit()
        } catch {
            ; 极窄竞态：点击与 Esc 关闭同时发生、列表窗口已销毁 → 忽略
        }
    }
    OnMessage(0x0202, lbClickHook, 0)   ; 先注销同名旧钩子，防重复累积
    OnMessage(0x0202, lbClickHook)      ; WM_LBUTTONUP：仅列表弹出期间注册

    ; 提示行
    selGui.Add("Text", "c888888 x10 y+4", Chr(8593) . Chr(8595) . " 移动  Enter 选择  点击即选  Esc 取消")
    
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

    ; 列表已关闭 → 立即注销点击钩子（只有弹出无框列表期间才有该处理）
    OnMessage(0x0202, lbClickHook, 0)

    ; GUI 关闭后的窗口切换竞态：等前台窗口回到弹出前的窗口再返回（与 ShowList 一致）。
    ; 否则紧接着的上下文删除 / 补全输入（Send）会发到错误的窗口而丢失，表现为"点了/选了却没反应"。
    DebugLog("ShowMultiSelection：列表关闭，前台窗口=" . WinExist("A") . "，弹出前=" . prevWin)
    if (prevWin) {
        loop 100 {                    ; 最多约 1 秒
            if (WinExist("A") = prevWin)
                break
            Sleep(10)
        }
        ; 超时仍未恢复且原窗口仍存在 → 主动拉回焦点
        if (WinExist("A") != prevWin && WinExist("ahk_id " . prevWin)) {
            WinActivate("ahk_id " . prevWin)
            loop 50 {
                if (WinExist("A") = prevWin)
                    break
                Sleep(10)
            }
        }
        DebugLog("ShowMultiSelection：焦点归位后前台窗口=" . WinExist("A"))
    }

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
AIRequest(prompt, &result, &reasoning, &errMsg, systemPrompt := "") {
    global ai_key, ai_base_url, ai_endpoint, ai_style, ai_model
    global ai_temperature, ai_max_tokens, ai_timeout, ai_system_prompt
    global ai_thinking, ai_reasoning_effort, ai_opencode_session
    ; systemPrompt 非空时用它替代 [ai] system_prompt（自然语言运行框用它传"翻译成动作"的提示语）
    sp := (systemPrompt = "") ? ai_system_prompt : systemPrompt
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
            . K("prompt") . J(sp . "`n`n" . prompt) . ","
            . K("temperature") . ai_temperature . ","
            . K("max_tokens") . ai_max_tokens . ","
            . K("stream") . "false" . tail . "}"
    } else {
        ; chat 风格（默认）
        body := "{"
            . K("model") . J(ai_model) . ","
            . K("messages") . "["
            . "{" . K("role") . J("system") . "," . K("content") . J(sp) . "},"
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
        ; OpenCode Go 会话 id：仅在 [ai] x_opencode_session 配置非空时发送该请求头
        if (ai_opencode_session != "")
            whr.SetRequestHeader("x-opencode-session", ai_opencode_session)
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
    global ai_thinking, ai_reasoning_effort, ai_opencode_session, streamFile, streamReadOffset

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

    ; OpenCode Go 会话 id：仅在 [ai] x_opencode_session 配置非空时附加该请求头；
    ; 非 OpenCode Go 模型留空则不发送
    sessionHeader := ""
    if (ai_opencode_session != "")
        sessionHeader := " -H `"x-opencode-session: " ai_opencode_session "`""

    ; 用 curl.exe 发起流式请求：-N 禁用缓冲、--data-binary @文件 原样发送请求体，
    ; stdout 写 streamFile、stderr 写 errFile；进程以 Hide 方式启动、不抢焦点
    inner := "curl.exe -sS -N -X POST `"" url "`""
        . " -H `"Content-Type: application/json; charset=utf-8`""
        . " -H `"Authorization: Bearer " ai_key "`""
        . sessionHeader
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
;     clickSubmit（可选，默认 false）：为 true 时，鼠标点击某个列表项即直接确认该项
;       （等价于“上下键选中该项 + 回车”）；供触发模式列表使用，实现“鼠标点击目标模式直接切换”。
;     preselect（可选，默认 1）：初始高亮项（1 起）。触发模式列表传入“当前模式 + 1”，
;       使高亮落在当前模式上：点击任意其它项必产生选择变化 → Change 事件 → 立即确认；
;       点击当前模式项本身即是“无操作”（切换到当前模式无意义），不发生选择变化、不提交，语义正确。
;     clickSubmitAny（可选，默认 false）：为 true 时，**点击任意列表项（含当前已高亮项）**即直接确认；
;       供 latex/unicode/AI 的候选列表使用（点哪项就选哪项，第一项也能一点即选）。
;       与 clickSubmit 的区别：clickSubmit 依赖 Change 事件，对“点击已高亮项”不触发；本开关改用
;       仅列表弹出期间注册的鼠标抬起（WM_LBUTTONUP）钩子判定落点，故无此限制。二者可各自独立使用。
;     返回：选中项索引（1 起），取消返回 0
; ============================================================================
ShowList(items, title, clickSubmit := false, preselect := 1, clickSubmitAny := false) {
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
    lb.Choose(preselect)
    lbHwnd := lb.Hwnd       ; 钩子内只认这个整数 HWND：控件销毁后访问对象的 .Hwnd 会抛异常
    ; clickSubmit（鼠标点击项即确认）：借用 ListBox 的 Change 事件——“当前选择发生变化”时必然触发
    ; （鼠标点击某项、上下键移动某项都会引起选择变化）。Change 响起时用 ModeListChangeIsClick 判定
    ; 是否鼠标点击：↑/↓/Home/End/PgUp/PgDn 任一正物理按下 → 键盘移动引起 → 不提交（等 Enter 确认）；
    ; 否则鼠标光标此刻必位于列表控件之上（点击不移动鼠标）→ 判定为鼠标点击 → 立即提交，
    ; 走与回车/OK 按钮同一条 Submit 通道（与回车同级的原生事件可靠性，探针已验证点击可触发 Change）。
    ; 配合 preselect 预选中当前模式项：点击任意非当前模式项必然产生选择变化 → 直接切换；
    ; 点击当前模式项本无操作（不发生选择变化），不提交，语义正确。
    if (clickSubmit)
        lb.OnEvent("Change", (*) => (
            ModeListChangeIsClick(lb) ? (
                chosen := SendMessage(0x0188, 0, 0, lb),
                DebugLog("ShowList：Change 判定为鼠标点击，选中第 " . (chosen + 1) . " 项，直接确认"),
                selGui.Submit()
            ) : (
                DebugLog("ShowList：Change 判定为键盘移动（方向键物理按下或光标不在列表上），等待 Enter 确认")
            )
        ))
    ; clickSubmitAny（鼠标 / 笔点击任意项即确认，含已高亮项）：只在列表弹出期间注册全局鼠标钩子
    ; （WM_LBUTTONUP，抬起时按键已松开）——判定点击确实落在本列表框的某一行上时才提交，其余一律
    ; 传空值放行；上下键移动 + Enter 选择 + Esc 取消等原有能力完全不受影响；列表关闭后立即注销。
    lbClickHook(wParam, lParam, msg, hwnd) {
        idx := ListClickItemIndex(lbHwnd, hwnd, lParam)
        if (idx < 0)
            return
        chosen := idx
        DebugLog("ShowList：点击即选，第 " . (idx + 1) . " 项，直接确认")
        try {
            selGui.Submit()
        } catch {
            ; 极窄竞态：点击与 Esc 关闭同时发生、列表窗口已销毁 → 忽略
        }
    }
    if (clickSubmitAny) {
        OnMessage(0x0202, lbClickHook, 0)   ; 先注销同名旧钩子，防重复累积
        OnMessage(0x0202, lbClickHook)      ; WM_LBUTTONUP：仅列表弹出期间注册
    }
    selGui.Add("Text", "c888888 x10 y+4", Chr(8593) . Chr(8595) . " 移动  Enter 选择" . ((clickSubmit || clickSubmitAny) ? "  点击即选" : "") . "  Esc 取消")
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
    ; 列表已关闭 → 立即注销点击钩子（只有弹出无框列表期间才有该处理）
    if (clickSubmitAny)
        OnMessage(0x0202, lbClickHook, 0)
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

; 判定 ListBox 的 Change（选择变化）是否由鼠标点击引起（而非键盘移动选择）：
; ① 若 ↑/↓/←/→/Home/End/PgUp/PgDn 任一键此刻正物理按下（GetKeyState P 模式）→ 选择变化来自键盘 → 非点击；
; ② 否则看鼠标光标是否正位于列表控件之上（MouseGetPos 以 Flag=2 取“光标下控件 HWND”比对）——
;    鼠标点击引起的选择变化其时刻光标必然仍在列表上（点击不移动鼠标），故 ② 成立即可判定为点击。
; 两者互补：键盘移动时正按着方向键（① 拦截，即使鼠标恰好悬在列表上也不误判）；
; 鼠标点击检测不看按键时序（② 与“左键是否已松开”无关，快速点击不丢判）。
ModeListChangeIsClick(lbCtrl) {
    for k in ["Up", "Down", "Left", "Right", "Home", "End", "PgUp", "PgDn"]
        if (GetKeyState(k, "P")) {
            DebugLog("ModeListChangeIsClick：键盘键按下 " . k . " → 判为键盘移动")
            return false
        }
    MouseGetPos(, , , &mCtrl, 2)     ; Flag=2：OutputVarControl 返回控件 HWND
    DebugLog("ModeListChangeIsClick：光标下控件 HWND=" . mCtrl . " 列表控件 HWND=" . lbCtrl.Hwnd)
    return (mCtrl = lbCtrl.Hwnd)
}

; 判定全局鼠标抬起消息（WM_LBUTTONUP）是否落在指定列表框的某一行上（鼠标 / 笔点击即选用）：
;   是 → 返回该行的 0 基索引；否则返回 -1（调用方必须传空值放行消息，不要吞掉）。
; lbHwnd：列表框控件 HWND。传整数而不是控件对象——本钩子在极窄的"点击与列表关闭同时发生"
;   竞态下可能晚于销毁触发，此时访问控件对象的 .Hwnd 会抛异常，而整数 HWND 不会。
; hwnd/lParam 即 OnMessage 回调里的第 4/2 个参数：hwnd 为消息目标窗口，
; lParam 为鼠标消息的客户区坐标（低字 X、高字 Y），正是 LB_ITEMFROMPOINT 所需的格式。
; LB_ITEMFROMPOINT 返回值：低字 = 最近行的索引，高字 = 1 表示落点不在客户区内的任何行上。
ListClickItemIndex(lbHwnd, hwnd, lParam) {
    if (hwnd != lbHwnd)
        return -1
    if (!DllCall("IsWindow", "Ptr", hwnd))   ; 控件已销毁 → 不处理
        return -1
    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    r := DllCall("SendMessageW", "Ptr", lbHwnd, "UInt", 0x01A9, "Ptr", 0, "Ptr", (y << 16) | x, "Ptr")   ; LB_ITEMFROMPOINT
    if (r < 0)
        return -1
    if ((r >> 16) & 0xFFFF)     ; 高字非 0：落点不在任何列表行上（如控件空白处）
        return -1
    return r & 0xFFFF
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
    ; 先注销旧的再注册，避免重复挂载（OnMessage 注销：Callback 传函数对象 + MaxThreads=0）
    OnMessage(0x0201, ThinkingWindowDrag, 0)
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
    ; 注销思考窗口的全局 WM_LBUTTONDOWN 钩子（Call back 传函数对象 + MaxThreads=0）
    OnMessage(0x0201, ThinkingWindowDrag, 0)
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
        ; 多种可能 → 无框列表供选择（clickSubmitAny=true：鼠标 / 笔点击任意候选即直接选用，
        ; 含已高亮的第一项；上下键 + Enter / Esc 等原有能力不变）
        DebugLog("AI：候选数=" . filtered.Length)
        idx := ShowList(filtered, "AI 候选（'" . prompt . "'）", false, 1, true)
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
; 12b. “循环提醒”（健康提醒）—— 默认 Ctrl+Alt+H 启动/停止（可用配置修改）
;      启动后循环执行：站立（默认 20 分钟）→ 坐下（默认 8 分钟）→ 走动（默认 2 分钟）→ 回到站立，
;      直到再次按下同一热键停止。每个阶段切换时：
;        ① 声音提醒（各阶段音调组合不同，便于听声辨认）；
;        ② 屏幕右上角显示显著提示文字（站立20分钟/坐下8分钟/走动2分钟，随配置时长），5 秒后自动消失。
; ============================================================================
global healthActive := false      ; 循环提醒是否运行中
global healthTimer := 0           ; 滴答回调引用（= HealthTick；停表用 SetTimer(healthTimer, 0)）
global healthPhase := 0           ; 当前阶段：0=站立，1=坐下，2=走动
global healthRemainSec := 0       ; 当前阶段剩余秒数
global healthOverlay := ""        ; 右上角提示 GUI
global healthOverlayTimer := ""   ; 提示自动消失定时器
global healthTrayStateText := ""      ; 托盘菜单“循环提醒”状态项当前文字（供 Rename 就地刷新）

Hotkey(health_hotkey, HealthToggle)

; “循环提醒”托盘状态项文字：停止 / 站立20分钟 / 坐下8分钟 / 走动2分钟（随配置显示）
HealthTrayLabel() {
    global healthActive, healthPhase
    return "循环提醒：" (healthActive ? HealthPhaseName(healthPhase) : "停止")
}

; 安全获取某阶段（0 基）的提示名称：优先 health_phase_names[phase+1]；越界时回退“阶段N”
HealthPhaseName(phaseIdx) {
    global health_phase_names
    if (phaseIdx + 1 <= health_phase_names.Length && health_phase_names[phaseIdx + 1] != "")
        return health_phase_names[phaseIdx + 1]
    return "阶段" (phaseIdx + 1)
}

; 就地刷新托盘状态项（启动、停止、阶段切换时调用），避免整表重建
HealthRefreshTrayState() {
    global healthTrayStateText
    newLabel := HealthTrayLabel()
    if (healthTrayStateText != "" && newLabel != healthTrayStateText) {
        try A_TrayMenu.Rename(healthTrayStateText, newLabel)
        healthTrayStateText := newLabel
    }
}

; 启动 / 停止 循环提醒（同一热键切换）
HealthToggle(*) {
    global healthActive
    if (healthActive)
        HealthStop()
    else
        HealthStart()
}

; 启动：从“站立”阶段开始循环，直到 HealthStop
HealthStart() {
    global healthActive, healthPhase, healthRemainSec, healthTimer, health_durations
    if (healthActive)
        return
    healthActive := true
    healthPhase := 0
    healthRemainSec := health_durations[1] * 60
    HealthPhaseBegin()
    ; 注意：SetTimer 的返回值在旧版 AHK v2.0 是空串（Timer 对象自 v2.1 才有），
    ; 因此这里保存的是回调引用（函数对象），停表时用 SetTimer(healthTimer, 0) 才能真正关闭
    healthTimer := HealthTick
    SetTimer(HealthTick, 1000)
    DebugLog("health：循环提醒已启动（从" HealthPhaseName(0) "开始，时长=" health_durations[1] " 分钟）")
}

; 停止：取消滴答定时器并收起提示
HealthStop() {
    global healthActive, healthTimer, health_hotkey
    healthActive := false
    if (healthTimer) {
        SetTimer(healthTimer, 0)   ; healthTimer 保存的是 HealthTick 回调引用，置 0 即可停表
        healthTimer := 0
    }
    HealthHideOverlay()
    HealthRefreshTrayState()
    TrayTip("循环提醒已停止，可用 " health_hotkey " 再次启动", "SharpKnife")
    DebugLog("health：循环提醒已停止")
}

; 每秒滴答：倒数当前阶段剩余秒数，归零则进入下一阶段
HealthTick() {
    global healthRemainSec, healthActive
    if (!healthActive)
        return
    healthRemainSec--
    if (healthRemainSec <= 0)
        HealthNextPhase()
}

; 进入下一阶段：按配置的阶段数 N 循环（默认 站立→坐下→走动→站立 …，N 可多可少）
HealthNextPhase() {
    global healthPhase, healthRemainSec, health_durations, health_phase_names
    n := Max(health_durations.Length, 1)
    healthPhase := Mod(healthPhase + 1, n)
    ; 阶段名列表与时长列表等长对应；缺名时用默认名数组第 phase+1 项（若越界用“阶段N”兜底）
    healthRemainSec := health_durations[healthPhase + 1] * 60
    HealthPhaseBegin()
    DebugLog("health：进入 " HealthPhaseName(healthPhase))
}

; 阶段切换动作：声音提醒 + 屏幕右上角显著提示 + 刷新托盘状态项
HealthPhaseBegin() {
    global healthPhase, health_sound
    if (health_sound)
        HealthPlaySound(healthPhase)
    HealthShowOverlay(HealthPhaseName(healthPhase))
    HealthRefreshTrayState()
}

; 阶段提示声音：优先播放配置的提示音频（health_sounds[阶段]，WAV/MP3），
; 未配置（留空/注释掉）或 路径无效/播放失败 时，退回内置默认蜂鸣提示
; 默认蜂鸣：站立=上行三音（C-E-G），坐下=下行三音（G-E-C），走动=高低两音（A-D）
HealthPlaySound(phaseIdx) {
    global health_sounds
    ; 未配置 step_sound（空数组）或 该阶段超出配置元素数 → 直接用默认蜂鸣
    if (phaseIdx + 1 > health_sounds.Length)
        snd := ""
    else
        snd := health_sounds[phaseIdx + 1]
    if (snd != "") {
        path := HealthResolveSoundPath(snd)
        if (FileExist(path)) {
            try {
                SoundPlay(path)
                DebugLog("health：播放阶段提示音频 " path)
                return
            } catch as e {
                DebugLog("health：播放提示音频失败 " path "（" e.Message "），改用默认蜂鸣")
            }
        } else {
            DebugLog("health：提示音频不存在 " path "，改用默认蜂鸣")
        }
    }
    ; —— 默认蜂鸣提示（音频未配置 / 无效时的回退）——
    if (phaseIdx = 0) {
        SoundBeep(523, 130)
        SoundBeep(659, 130)
        SoundBeep(784, 180)
    } else if (phaseIdx = 1) {
        SoundBeep(784, 130)
        SoundBeep(659, 130)
        SoundBeep(523, 180)
    } else {
        SoundBeep(880, 150)
        SoundBeep(587, 200)
    }
}

; 解析提示音频路径：含盘符视为绝对路径，否则以脚本目录（A_ScriptDir）为基准拼接
HealthResolveSoundPath(snd) {
    if (SubStr(snd, 2, 1) = ":")
        return snd        ; 绝对路径（C:\xxx 或 D:\xxx）
    return A_ScriptDir "\" snd   ; 相对路径 → 脚本目录下
}

; 屏幕右上角显著提示：无框置顶窗口，显示指定阶段文字，5 秒后自动消失
HealthShowOverlay(text) {
    global healthOverlay, healthOverlayTimer, healthPhase, health_notify_ms
    if (healthOverlayTimer != "") {
        SetTimer(healthOverlayTimer, 0)   ; 清理上一阶段残留的自动消失定时器
        healthOverlayTimer := ""
    }
    if (healthOverlay != "") {
        try healthOverlay.Destroy()
        healthOverlay := ""
    }
    ; 阶段色：绿/蓝/橙对应 站立/坐下/走动；阶段数超过 3 时循环取色
    colors := ["58D68D", "5DADE2", "F5B041"]
    colorIdx := Mod(healthPhase, colors.Length)   ; 阶段数可多可少，超出循环复用
    h := Gui()
    h.Opt("-Caption +ToolWindow +AlwaysOnTop +Border")
    h.BackColor := "1F1F1F"
    h.SetFont("Bold s18 c" colors[colorIdx + 1], "Microsoft YaHei")
    h.Add("Text", "w380 Center", text)
    h.Show("NA")   ; NA=NoActivate：显示但不抢焦点
    h.GetPos(&gx, &gy, &gw, &gh)
    h.Move(A_ScreenWidth - gw - 24, 24)   ; 贴屏幕右上角（留 24 像素边距）
    healthOverlay := h
    healthOverlayTimer := SetTimer(() => HealthHideOverlay(), -health_notify_ms)   ; 负周期=单次定时，到期自动消失
}

; 收起右上角提示
HealthHideOverlay() {
    global healthOverlay, healthOverlayTimer
    if (healthOverlayTimer != "") {
        SetTimer(healthOverlayTimer, 0)
        healthOverlayTimer := ""
    }
    if (healthOverlay != "") {
        try healthOverlay.Destroy()
        healthOverlay := ""
    }
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
A_IconTip := "SharpKnife — " . trigger_hk . " 补全，" . toggle_hk . " 循环切换，" . direct_prefix . "0/1/2/3 直接切换，" . mode_list_hk . " 模式列表，" . step_hotkey . " play 步进，" . health_hotkey . " 循环提醒，" . keypadArrowHotkey . " 方向键盘，" . keypadNumpadHotkey . " 数字键盘，" . keypadSymbolHotkey . " 符号键盘，" . keypadLetterHotkey . " 字母键盘"

; ============================================================================
; 14. 启动提示
; ============================================================================
TrayTip(
    "就绪 — " . mode_names[mode + 1] . " 模式（默认）`n"
    . trigger_hk . " 补全，" . toggle_hk . " 循环切换 latex / unicode / AI / tikz`n"
    . direct_prefix . "0/1/2/3 直接切换（0=latex，1=unicode，2=AI，3=tikz）`n"
    . mode_list_hk . " 模式列表选择，" . step_hotkey . " play 步进执行`n"
    . health_hotkey . " 循环提醒（站立/坐下/走动循环，按同一键停止）`n"
    . keypadArrowHotkey . " 方向小键盘，" . keypadNumpadHotkey . " 数字小键盘，" . keypadSymbolHotkey . " 符号小键盘，"
    . keypadLetterHotkey . " 字母小键盘（再按同一键关闭）",
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