# AGENTS.md —— 给 AI 协作者的长期约定

> **本文件的作用**：把本项目开发中形成的**约定、习惯、风格与踩过的坑**固化下来。
> 即使历史会话被删除、或换到全新会话/新模型，只要读本文件，就应当能**按同样的方式接续开发**，不必重新摸索、也不该重复犯同样的错误。
>
> 最后更新：2026-09-15

---

## 0. 一句话背景

**SharpKnife** 是一个 AutoHotkey **v2** 写的 Windows 10 桌面效率工具，由用户（中文）与 AI 反复迭代而成。
用户对**细节要求高**、会多轮实测并反馈；请保持耐心，**只改必要之处**。

---

## 1. 项目与环境

| 项目 | 值 |
|------|-----|
| 代码目录（Windows） | `E:\Working\SharpKnife` |
| 代码目录（WSL2） | `/mnt/e/Working/SharpKnife` |
| 目标运行环境 | **Win10 + AutoHotkey v2**（必须 v2，不是 v1） |
| AHK 解释器 | `D:\Program\AutoHotkey\v2\AutoHotkey64.exe` |
| AHK 编译器 | `D:\Program\AutoHotkey\Compiler\Ahk2Exe.exe` |
| Git 远端 | `git@github.com:chaoskey/SharpKnife.git`（**SSH**） |

**DSH 跑在 WSL2 里**，通过 interop 调用 Windows 程序（`cmd.exe`、AHK 解释器/编译器、`taskkill.exe` 等）。
代码目录是 WSL 与 Windows 共享的同一份文件（drvfs 挂载）。

### 关键文件

| 文件 | 说明 |
|------|------|
| `SharpKnife.ahk` | 主脚本（也是编译源） |
| `SharpKnifeCore.ahk` | 纯逻辑核心，被主脚本 `#Include` |
| `apps/TouchKeyboardToggle.ahk` | 独立触摸键盘切换 helper；编译后供径向菜单 `run:` 调用 |
| `apps/DisableHotKey.ahk` | 独立**范例**脚本：演示禁用指定热键（默认 `Esc::Return` + `RAlt & Space` 空动作）。注意 `Esc::Return` 会全局吞掉 Esc，与径向菜单/小键盘的 Esc 关闭冲突，只在需要时单独运行 |
| `latexs.cvs` | LaTeX/Unicode 触发表（Tab 分隔） |
| `config.ini` | **本地配置（已 gitignore，不入库）** |
| `config.ini.example` | 配置样例（**入库，改配置项必须同步它**） |
| `menu_stats.ini` | 径向菜单执行次数统计（**运行时产物，已 gitignore**） |
| `debug.log` | 调试日志（**运行时产物，已 gitignore**） |
| `README.md` | 用户文档 |
| `Requirements.md` | 需求文档（纯文字需求，不含实现） |
| `play-script-manual.md` | play 模式 JSON 脚本手册 |

`.gitignore`：`*.log`、`*.exe`、`test/`、`config.ini`、`audio/`、`menu_stats.ini`

---

## 2. 必须遵守的规则（不可协商）

### 2.1 编译流程

```bash
# 1) 必须先结束正在运行的实例，否则编译会失败：
#    Ahk2Exe Error: Could not move final compiled binary file to destination. (C1)
timeout 10 /mnt/c/Windows/System32/taskkill.exe /IM SharpKnife.exe /F

# 2) 编译（注意用 Windows 路径传给 Ahk2Exe）
SRC='E:\Working\SharpKnife\SharpKnife.ahk'
OUT='E:\Working\SharpKnife\SharpKnife.exe'
ICO='E:\Working\SharpKnife\images\SharpKnife.ico'
timeout 120 "/mnt/c/Users/joistw/AppData/Local/Programs/AutoHotkey/Compiler/Ahk2Exe.exe" \
    /in "$SRC" /out "$OUT" "/icon" "$ICO" /silent
# 成功输出：Successfully compiled as: "E:\Working\SharpKnife\SharpKnife.exe"
```

编译产物 `SharpKnife.exe` 与源码逻辑一致时必须重新编译后再交用户测试（用户测的是 exe）。

### 2.2 Git 提交规则（用户已明确要求，**以后不必再问、直接照做**）

用户原话要点：**提交前配代理，push 后清代理；WSL2 下要把 `127.0.0.1` 换成宿主 IP，Win10 下直接用 `127.0.0.1`。**

```bash
# ① 判定环境并取代理 IP
host_ip=$(ip route show default | awk '{print $3}')   # WSL2：取宿主 IP
# 若在 Win10 原生环境执行，则直接用 127.0.0.1

# ② 配代理
git config --global http.proxy  http://${host_ip}:10808
git config --global https.proxy http://${host_ip}:10808

# ③ 提交（见下方"提交信息"约定）
git add <files>
git commit -F <消息文件>

# ④ push
git push

# ⑤ 务必清代理（用户强调）
git config --global --unset http.proxy
git config --global --unset https.proxy
```

**提交信息约定**

- 用**中文**，风格与仓库历史一致（首行概括，正文分点说明"改了什么、为什么"）。
- **不要在提交信息里用反引号（`` ` ``）**：它是 shell 的命令替换符，会把内容吞掉。
  正确做法：把信息写入文件后用 `git commit -F 文件`（heredoc 用**单引号**定界符）：

  ```bash
  cat > /tmp/msg.txt << 'EOF'
  标题
  正文…
  EOF
  git commit -F /tmp/msg.txt
  ```
  （此坑已实际踩过：提交信息里的示例文本被 bash 吞掉，只能用 `git commit --amend` 补救。）

- `config.ini` 不入库（本地配置）；**改了配置项要同步更新 `config.ini.example`**。

### 2.3 文档同步（每次行为变更都要做）

| 改了什么 | 必须同步 |
|----------|----------|
| 用户可见的行为/操作方式 | `README.md` |
| 需求层面的增删改 | `Requirements.md` |
| 新增/修改配置项 | `config.ini.example` + `README.md` 的「配置说明」 |
| 新增运行时文件 | `.gitignore`（若非必要入库） |

`README.md` 是**用户文档**（面向使用），`Requirements.md` 是**需求文档**（纯文字、不写实现细节）——不要把实现方案塞进需求文档。

---

## 3. 代码风格与习惯

1. **注释、日志、界面文字、提示语一律中文。**
2. **配置读取必须"防空 + 防呆"**：给默认值；非法值忽略并沿用默认；数值型用 `Max/Min` 夹取范围。
   例：`if RegExMatch(value, "^\d+$") radialCommonMax := Max(0, Min(Integer(value), 20))`
3. **外科手术式改动**：只改达成目标所需的代码，不顺手重构无关部分。
4. **用户说"形式/外观不能变，只改流程或内容"时，绝不碰绘制与布局代码。**
5. 函数命名沿用项目分组前缀：`Radial*`、`Play*`、`Health*`、`Tikz*`、`AI*` 等（PascalCase）。
6. **防御性**：数组索引前判长度；可能为 0/空的索引要守卫；文件/网络操作一律 `try { } catch { }`。
7. 无第三方依赖：JSON 解析、GDI 绘制等都自己用 `DllCall` 实现（项目传统，不要引入外部库）。

---

## 4. 本项目专属的坑（血泪教训，务必避免）

### 4.1 AHK v2 语法 / 语义陷阱

| # | 坑 | 正确做法 |
|---|----|----------|
| 1 | `try X catch {`（单语句 try + 同行 catch）**是语法错误**：`Unexpected "{"` | 一律用块形式：`try { ... } catch { ... }` |
| 2 | **裸 `try X`（无 catch）不会吞异常** → 仍弹错误框并阻塞 | 需要忽略异常时必须显式 `catch` |
| 3 | `log` 是 AHK 内置函数名，**不能当变量名**（报 `This Func cannot be used as an output variable`） | 换名，如 `logf` |
| 4 | 对象字面量 `{...}`（Object）**没有 `.Has()`**（那是 `Map` 的方法） | 用 `.HasOwnProp("键")` |
| 5 | `OnMessage` 回调**返回整数（包括 0）会"回复"消息并吞掉它**，后续处理不再执行 | 不处理时用**空 `return`** 放行；只有确实要拦截才返回整数 |
| 6 | `OnMessage` 注销写法：`OnMessage(Msg, 函数对象, 0)`。传 `""` 或 `0` 当回调会报 `Parameter #2 … requires an Object` | 用**函数对象 + MaxThreads=0** 注销 |
| 7 | `CoordMode` 是**线程本地**的；每个热键线程都恢复默认（**客户区坐标**） | 在**脚本启动处**设置一次（如 `CoordMode("Mouse","Screen")`），或在函数内再设一次 |
| 8 | `Loop read` **读不了 UTF-16** 文件 | 用 `FileRead(path, "UTF-16")`（能自动识别 BOM） |
| 9 | `FileDelete` 对**不存在的文件会抛异常** | 包 try/catch，且**必须写成多行块**：`try { FileDelete(f) } catch { }` 这种"同一行内 try+catch"实测同样报 `Missing "}"`（2026-09-15 踩过），要拆成三行 |
| 10 | `IniWrite` 新建文件是 **UTF-16 LE + BOM**，且**会保留已有注释**；中文节名/键名可用 | 直接用它读写统计类文件即可 |
| 11 | INI **键名不能含 `=`**（会被当键值分隔符） | 转义为 `%3D` 后再读写 |
| 12 | 自己解析 INI 时**必须剥离行内注释**，否则 `key = 15  ; 注释` 的值校验失败被静默忽略 | 用 `RegExMatch(line, "\s;", &m)` 截断（用"空白+分号"，避免误伤 `{;}` 这类紧贴分号） |
| 13 | **全局变量声明必须早于配置加载调用**，否则 `global x := …` 会把已加载的数据覆盖掉 | 本项目的 `RadialLoadConfig()` 调用就在 radial 全局变量声明**之后**（曾因此排查很久） |
| 14 | 脚本中部的 `FileDelete(debug.log)` 会**清掉此前写入的日志** | 不要依赖该时间点之前的日志；必要时把诊断写在清空之后 |
| 15 | **v2 里没有 `FileExists`**（正确的是 `FileExist`）。名字写错时 AHK 会把 `FileExists(...)` 当成“调用同名**变量**”，并弹出**加载期 `#Warn` 警告框**阻塞脚本；`/ErrorStdOut` **抓不到**它 → 表现为“脚本毫无输出地卡死” | 用 `FileExist()`；遇到“无输出卡死”优先怀疑这类加载期弹框（读取办法见 §5） |
| 16 | AHK v2 **变量名大小写不敏感**：`CLSID := "{…}"` 与 `clsid := Buffer(16,0)` 是**同一个变量**，后者会静默覆盖前者 | 给 GUID 的字符串与 Buffer 起**不同名字**（如 `guidClsidStr` / `bufClsid`） |
| 17 | `DllCall` 的类型参数直接传 `Buffer` **对象**会报类型错误（如 `Expected a String but got a Buffer`） | 一律写 `buf.Ptr` |
| 18 | `ComObject(CLSID, IID)` 要求该类已注册，否则报 `(0x80040154) 没有注册类`；但**这个错误码不代表类真的没注册**，也可能只是当前会话拉不起服务器 | 直接调 vtable 可用 `DllCall("ole32\CoCreateInstance", …)` + `ComCall(索引, p, …)`：**裸接口指针可以直接用**，索引 0/1/2 是 IUnknown，3 起才是自定义方法 |
| 19 | 拿**对象字面量 `{}`（Object）当"动态键"字典**用时，`obj[键] := 值` 会报 `This value of type "Object" has no property named "__Item"`（`obj[键]` 走的是 `__Item`，普通 Object 没有这个属性） | 键是**运行时变量**时一律用 `Map()`（`m[k] := v` / `.Has(k)` / `.Delete(k)` / `Count`）；只有**固定属性名**才用 Object + `.HasOwnProp()`。2026-09-15 小键盘注册表 `keypadPanels` 就是这样在按 `^+k` 时直接报错的（提取函数的单测没覆盖到写入路径，所以没提前发现） |
| 20 | **脚本自己发出的按键不会触发脚本自己的热键**：AHK 的 SendLevel 默认为 0，"hook hotkeys ignore keyboard and mouse events generated by any AutoHotkey script"。所以 `SendEvent("^j")` 发 Ctrl+J **不会**执行本脚本的补全（只会落到前台程序手里）；`SendLevel(1)` + SendEvent 在文档上可行，但仍依赖输入注入 | 需要"面板上的键 = 本脚本某命令"时，**直接调用热键绑定的那个处理函数**（如【触发】键调 `CompleteAI()`）——效果完全一致且最稳。2026-09-15 做字母键盘【触发】键时确认过 |

### 4.2 消息钩子 / 输入 / 坐标

- **全局 `OnMessage` 钩子会互相干扰**：多个组件（径向菜单、思考窗口…）都注册 `WM_LBUTTONDOWN`/`WM_MOUSEMOVE` 时，任一回调返回整数就会吞掉事件（曾导致"列表鼠标点击失效"）。
  规则：**凡是不属于自己窗口的消息，一律空 `return` 放行**；并保证注册/注销成对。
- 鼠标/位置相关一律显式 `CoordMode(..., "Screen")`（见 4.1 #7）。

### 4.3 绘制 / 显示

- **本机 GDI+ 不可用**：`GdiplusShutdown` 必崩、`GdiplusStartup` 间歇失败（用户明确要求不用）。
  → 一律用**经典 Win32 GDI**：`CreateCompatibleDC` + `CreatePolygonRgn`/`CreateEllipticRgn`、`FillRgn`、`FrameRgn`、`CreateFontW`、`TextOutW`、`BitBlt` 双缓冲。
- 径向菜单的**命中与绘制共用同一批区域句柄**（`CreatePolygonRgn` → 绘制 `FillRgn` / 命中 `PtInRegion`）。
  **不要**再用"按角度算索引"的方式做命中——屏幕 y 向下会导致方向/索引错位（曾反复出错，最终靠共用区域根治）。
- 圆盘"空位扇区"的实现：**文字留空 + 命中返回未命中**（即可实现"无文字、禁止高亮、点击无效"），**不需要改绘制代码**。

- **文字必须"永远不透明"，所以文字单独成层**（2026-09-15 改造，代码见 10c-3）：主窗口继续用整窗 LWA_ALPHA 承担 `opacity`，但**不再画任何文字**；每个浮层另有一个"文字层"窗口，用 UpdateLayeredWindow + 预乘 ARGB 呈现，文字 alpha 恒为 255 → 不受透明度影响。要点：
  - 文字层窗口必须带 `WS_EX_LAYERED`（建立后再 Show）+ `WS_EX_TRANSPARENT`（点击穿透到下面的面板）+ `WS_EX_NOACTIVATE`，并且**永远跟着所属面板移动**（拖动、被避让推开都要同步移动）。
  - 生成预乘 ARGB 的做法（**两块 DIB**）：① colorDC 用配置色画字身（描边不画，黑边处保持 RGB=0）；② maskDC 用**白色**画"字身 + 黑边"（黑边 = 把同一字在 8 方向各偏移 1px 各画一遍，偏移先画、字身最后画）；③ 把 maskDC 的 R 通道（= 字身 ∪ 黑边 的覆盖度）抄进 colorDC 的 alpha 字节 → 得到"彩色字身 + 不透明黑边"的预乘 ARGB。因此字体**必须用 ANTIALIASED_QUALITY(4) 灰度抗锯齿**：ClearType 是次像素抗锯齿，通道不成比例，会破坏"RGB 即预乘值"这个前提。
  - 逐像素只在"文字层创建 / 文字内容变化"时做（420×252 约 60ms）；**悬停高亮只重绘主窗口**，别把文字层塞进悬停路径。
  - **文字层必须始终压在面板之上**：面板被拖动（Gui.Move）或被点击时都会被系统提到最上层，所以 `OverlayTextLayerMove` 一律不带 SWP_NOZORDER（置顶），并在 `KeypadOnLButtonDown` / `RadialOnLButtonDown` / `OverlayTextLayerPresent` 里再 `OverlayTextLayerRaise` 一次；漏掉就会出现"点一下 / 拖一下之后文字又随透明度变淡了"（2026-09-15 用户实测反馈过）。
  - 文字颜色来自 `[ui] overlay_text_color`（默认 FFFF00 亮黄；`OverlayParseColor` 解析，纯黑 / 非法值退回默认）；黑边宽度来自 `[ui] overlay_text_outline`（默认 1 像素，0 = 关闭，上限 3）。**黑边与字身一样在文字层里、alpha 恒 255，都不受 opacity 影响。**
  - 新增任何文字，都要画到文字层里（`RadialPaintTexts` / `KeypadPaintTexts`），不要再往主窗口上画。

### 4.4 其它

- `CreateFontW` 的 `escapement` 单位是 **0.1 度**；旋转文字用 `TextOutW`（`DrawText` 不支持旋转）。
- 本机 Windows 缩放/多显示器等环境细节未知时，优先用**相对计算**（如以鼠标为圆心、按屏幕夹取），避免硬编码坐标。

### 4.5 触摸键盘 / 数位板 / 自动隐藏任务栏（2026-09-13）

- **Win10 原生触摸键盘自动弹出并不跨应用一致**：记事本等原生编辑控件下，数位板笔点编辑区可直接触发系统原生触摸键盘；**VSCode（Electron 编辑区）下常失效**。不要把记事本的成功经验直接套到 VSCode。
- 本项目最终采用**独立 helper**：`apps/TouchKeyboardToggle.ahk`，由径向菜单 `run:` 调用；**不要把数位板/触摸键盘兼容逻辑继续塞回 `SharpKnife.ahk` 主流程**，除非 helper 路线已证明不够用。
- helper 的**最终最小可用策略**：
  1. 若任务栏开启自动隐藏，则**先唤出任务栏**；
  2. 若任务栏本就显示，则**直接点击触摸键盘图标**；
  3. 点击后恢复原光标位置。
- **自动隐藏任务栏**是可靠性分水岭：不自动隐藏时，该 helper 对鼠标点击非常可靠；自动隐藏时，必须先唤出任务栏再点击，否则常见现象是**任务栏闪一下但触摸键盘不弹出**。
- **数位板笔的核心限制在驱动层**：笔尖靠近板面时，驱动会持续接管/吸附光标，导致 helper 的 `SetCursorPos` 后续点击可能落不到目标位置。已验证的可用工作流是：**点击圆盘菜单中的“触摸键盘”后，立刻将笔远离数位板**。
- 这类问题的最终判定标准应以**用户桌面手测**为准；WSL/自动化侧无法真实复现“笔悬停接管光标”的驱动行为。若用户已确认“笔点后迅速抬离”可稳定使用，就应停止继续把复杂度堆回主脚本。
- 配置样例已加入入口：`[radial.Input]` 下 `6 = 触摸键盘 | run: apps\TouchKeyboardToggle.exe`。若未来路径调整，优先改 helper 与样例配置，不改主逻辑。

**COM 方式（2026-09-13 新增，独立文件 `apps/TouchKeyboardToggleCom.ahk`）**：

- **该方法确实存在**：资源管理器点“触摸键盘”图标时，内部就是创建未公开组件并调用 `ITipInvocation::Toggle(HWND)`（`Toggle` 传 `GetDesktopWindow()`，`CLSCTX = 0x6` = INPROC_HANDLER|LOCAL_SERVER；`IID_ITipInvocation` = `{37c994e7-432b-4834-a2f7-dce1f13b834b}`）。
- **用户明确要求 `apps\TouchKeyboardToggle.ahk`（模拟点击版）保持原样**，所以 COM 版是**新增独立文件**，两者互不影响、可同时保留。
- CLSID 有讲究：**本机（Win10 19045）真正能用的是 `{054AAE20-4BEA-4347-8A35-64A533254A9D}`（“UIHost Class”，注册了 `LocalServer32` → `TabTip.exe`）**；网上最常见的 `{4ce576fa-83dc-4F88-951c-9d0782b4e376}`（“UIHostNoLaunch Class”）本机**没有** `LocalServer32`，只有 `TabTip.exe` 已在运行时才可用，否则报 `0x80040154`。helper 因此**两个都试**。
- `TabTip.exe` 未运行时必然失败（`0x80040154`）；helper 策略：先启动 `TabTip.exe`（起进程本身就是“显示”），1.5s 内可见就不再 Toggle（避免“已弹出又被关掉”），仍不可见才补一次 Toggle。
- WSL（Session 0）下 `{054AAE20}` 返回 `0x800702E4`（ERROR_ELEVATION_REQUIRED）——说明**类已注册、SCM 确实去拉起了 TabTip**，只是非交互会话起不来；**不能**据此判定方案不可用。
- 成败最终仍以**用户桌面手测**为准。

---

## 5. WSL 下的自测方法（**GUI 行为必须交用户手测**）

> **重要限制**：从 WSL interop 启动的 Windows GUI 程序**无法附着到交互桌面**（连 `notepad` 都会立刻退出）。
> 因此**任何图形界面/热键/鼠标交互行为，都必须请用户在 Windows 桌面上手动测试**，不要假装已测过。
> 曾被用户批评过"声称测试通过但实际是用户自己测的"，请如实说明测试边界。

**纯逻辑可以在 WSL 自测**（推荐在交付前做，能提前排掉大部分错误）：

```bash
cd /mnt/e/Working/SharpKnife
# ① 测试脚本必须带 UTF-8 BOM，否则中文字面量会被按 ANSI 误读
printf '\xEF\xBB\xBF' > _t.ahk
cat >> _t.ahk << 'EOF'
logf := "E:\Working\SharpKnife\_t.log"
try {
    FileDelete(logf)
} catch {
}
; …被测逻辑…
FileAppend("结果…`n", logf)
ExitApp
EOF
# ② 用 /ErrorStdOut 运行（可看到加载期语法错误）；外层 timeout 防挂
timeout 25 "/mnt/c/Users/joistw/AppData/Local/Programs/AutoHotkey/v2/AutoHotkey64.exe" \
    /ErrorStdOut "E:\Working\SharpKnife\_t.ahk" < /dev/null 2>&1 | head -5
# ③ 读回日志验证
cat _t.log
# ④ 清理测试文件
rm -f _t.ahk _t.log
```

要点：
- 脚本末尾务必 `ExitApp`，否则会驻留挂住（外层再套 `timeout`）。
- 结果写文件再读回，**不要依赖 GUI 弹窗**（会阻塞）。
- 测试文件用完即删，别留在仓库里。

### 5.1 脚本“毫无输出地卡死”时，怎么拿到 AHK 的报错（2026-09-13 实战）

AHK v2 的**加载期弹框**（`#Warn` 警告、调用了不存在的函数等）会**阻塞**脚本，而 `/ErrorStdOut` **只对语法错误生效**、抓不到这类对话框
→ 从 WSL 看就是“脚本没有任何输出、一直挂着”（正是 §4.1 #15 那个坑）。**不要**误判成“环境坏了”或“文件解析不了”。

读法：让脚本在后台跑起来，再用 **UI Automation** 读对话框里的 `RichEdit` 正文（`class=#32770` → `ControlType.Document` → `TextPattern.DocumentRange.GetText(-1)`）。
用 `GetWindowText` 读不到跨进程控件文字，必须走 `SendMessage(WM_GETTEXT)` 或 UIA。

**WSL interop 的进程运行在 Session 0（Services），不是用户的交互桌面**：`tasklist` 里自己起的进程显示 `Services 0`，用户的是 `Console 1`。
因此 `WinExist("A")` 返回 0、COM 本地服务器（如 `TabTip.exe`）拉不起来、GUI 无法附着桌面。
**结论**：从这里只能得出“WSL 里测不了”，**不能**得出“该 GUI/COM 方案不可行”。

**收尾务必清进程**：卡在弹框里的僵尸 AHK 会让后续带 `#SingleInstance Force` 的**同名**脚本一直等待；
`taskkill` 要**32 位与 64 位都杀**——Ahk2Exe 编译时会拉起 `AutoHotkey32.exe` 做校验，它卡住会让编译“无输出挂住”。

---

## 6. 代码功能地图

### 6.1 主流程

| 功能 | 入口 | 说明 |
|------|------|------|
| latex/unicode/AI/tikz 补全 | `CompleteAI()` ← `Ctrl+J` | 上下文选择 → 匹配/请求 → 输出 |
| 模式切换 | `ToggleMode()` / `SetModeDirect()` / `ShowModeList()` | 循环 / 直达 / 无框列表 |
| play 脚本步进 | `StepPlay()` ← `Ctrl+R` | 游标栈 + 9 类动作（见 `play-script-manual.md`） |
| 循环提醒 | `HealthToggle()` ← `Ctrl+Alt+H` | 阶段循环 + 声音 + 右上角提示 + 托盘状态 |
| 径向菜单 | `RadialShow()` ← `Ctrl+Shift+M` | 三层圆盘菜单（见 6.2） |
| 屏幕小键盘 | `KeypadToggle("arrow"/"numpad"/"symbol"/"letter")` ← `Ctrl+Shift+K` / `Ctrl+Shift+N` / `Ctrl+Shift+Y` / `Ctrl+Shift+E` | 方向 / 数字 / 符号 / 字母屏幕按键面板（见 6.3） |

### 6.2 径向菜单（Radial Menu）—— 最近改动最多的模块

**三层结构**（外观形式固定：圆形窗口 + 单环扇区 + 放射性文字，仅流程/内容可变）：

1. **第一层【常用】**：圆心 `常用`；周边第 1 个固定 `快捷菜单`，其后为**按统计排出的高频项**（个数 = `[radial] common_max`）。
   点常用项 → 执行快捷键（**不关闭菜单**）；点圆心 → 关闭。
2. **第二层【快捷菜单】**：圆心 `快捷菜单`；周边为**分组名**。点分组 → 第三层；点圆心 → 返回第一层。
3. **第三层【<组名>】**：圆心 = 组名；周边为该组**菜单项**。点菜单项 → 执行快捷键（**不关闭菜单**）；点圆心 → 返回第二层。

**流程要点（2026-09-12 改造）**：

- **触发键 = 开/关切换**：未打开则弹出，已打开则关闭（`RadialShow` 内 `if (radialGui) { RadialClose(); return }`）。
- **执行功能不关闭菜单**：`RadialOnItemClick` 的 `exec` 分支只 `RadialBumpStat()` + `RadialExecHotkey()`，**不再调用 `RadialClose()`**；便于连续执行多个功能。
- **圆心：点击 or 拖拽**（`RadialOnLButtonDown` / `RadialOnMouseMove` / `RadialOnLButtonUp`）：
  按下圆心先记录（鼠标屏幕坐标 + 窗口左上角）+ `SetCapture`；移动时**位移 > 3px** 才判定为拖拽 →
  `Gui.Move(按下时窗口位置 + 位移)` 移动圆盘（1:1 跟手，仅夹取在**虚拟屏幕**内）；抬起时若**没拖过**才触发圆心点击。
  拖拽判定用 `GetCursorPos` 绝对坐标差分（不依赖会随窗口移动而变化的客户区 `lParam`，避免抖动）。
  **拖拽分支只移动窗口，绝不做任何其它动作**（不切层/不关闭/不激活/不改焦点）。
- 圆盘窗口带 **`+E0x08000000`（`WS_EX_NOACTIVATE`）**：点击/拖拽菜单都**不改变前台窗口**（不抢焦点，编辑器光标与焦点不受影响）。
- 因窗口不获取键盘焦点，**Esc 由打开期间的全局热键接管**，但**不再由 radial 自己注册**：统一走 `Overlay*`（见 6.3），`RadialBuildMenu` 末尾 `OverlayPush("radial")`、`RadialClose` 里 `OverlayRemove("radial")`。
  **坑**：`Hotkey(Key,"Off")` 之后，即使再用函数对象注册（不报错）也不会重新启用，必须显式调 `Hotkey(Key,"On")`（`OverlayRegisterEscape` 已按此处理）。
- **位置夹取必须用虚拟屏幕**（`SysGet(76/77/78/79)`），不能用 `A_ScreenWidth/A_ScreenHeight`（仅主屏）——否则多显示器下圆盘会被"拉回主屏"，表现为一拖动就"消失"。
- `WM_LBUTTONUP` 需在 `RadialRegisterMsg`/`RadialUnregisterMsg` 成对注册/注销（`radialMsgUp`）。

**每层周边至少 4 个扇区**，不足补空位（无文字、禁止高亮、点击无效）。

关键函数：

| 函数 | 职责 |
|------|------|
| `RadialLoadConfig()` | 逐行解析 `[radial]` 段（自定义解析，非 `IniRead`），保证组/项顺序 |
| `RadialComputeLayout()` | 紧凑自适应半径：①圆心文字内接 ②内圈弧长够字高 ③环宽够最长文字 |
| `RadialBuildMenu()` | 按 `radialLevel` 构建当前层内容 + 补空位 + 建立 GUI/区域/消息钩子 |
| `RadialBuildRgns()` / `RadialFreeRgns()` | 扇区多边形区域与圆心区域的建立/释放（绘制与命中共用） |
| `RadialDraw()` | GDI 双缓冲绘制**本体**（三态着色：常态/高亮/变暗）；**不画文字**（文字在文字层） |
| `RadialPaintTexts(maskDC, colorDC)` / `RadialTextLayerPresent()` | 圆盘文字层：圆心文字 + 放射性扇区文字（彩色字身 + 白色掩码含黑边），以及合成 + 呈现（见 4.3） |
| `RadialHitTest()` | `PtInRegion` 命中；**空位扇区返回 0（不命中）** |
| `RadialOnItemClick()` | 按 `kind` 分发：`shortcut`/`group`/`exec`/`disabled`（`exec` 只执行不关闭） |
| `RadialOnLButtonDown()` / `RadialOnMouseMove()` / `RadialOnLButtonUp()` | 扇区点击 + 圆心「点击/拖拽」判定（阈值 3px，`SetCapture`→`Gui.Move`→`ReleaseCapture`） |
| `RadialOnCenterClick()` | 三层中心语义（关闭 / 返回上一层） |
| ~~`RadialOnEscape()`~~ | **已删除**：Esc 改由浮层公共层 `Overlay*` 接管（见 6.3），radial 自己不再注册 / 注销 Esc |
| `RadialVirtualBounds()` | 全部显示器合并区域（`SysGet(76..79)`），圆盘位置夹取用 |
| `RadialRestoreFocus()` | 点击后把焦点还给触发菜单前的窗口（圆盘不持焦点；`WS_EX_NOACTIVATE` 下通常已是空操作） |
| `RadialExecHotkey()` | 恢复焦点窗口后 `Send` 快捷键 |
| `RadialStatsInit()` / `RadialStatKey()` / `RadialBumpStat()` / `RadialTopFrequent()` | 统计文件初始化、键转义、计数 +1（实时写盘）、取高频前 N |

配置（`[radial]`）：

```ini
[radial]
trigger = ^+m        ; 触发键
font_size = 15       ; 字体（磅）；缺省 = [ui] font_size
common_max = 6       ; 第一层高频项个数（0~20）

[radial.base]        ; 一个分组 = 一个子节（xxx 为英文标识符，不显示）
name = 基础通用      ; 组显示名（中文）
1 = 复制 | ^c        ; 编号 = 功能名 | 快捷键
9 = 删除 | {Del}     ; 多字符键名必须用花括号
```

统计文件 `menu_stats.ini`（运行时生成，UTF-16 LE + BOM）：

```ini
[stats]
radial.base.1=12     ; 键 = radial.<组标识>.<编号>，与 config.ini 的 [radial.*] 一一对应
```

### 6.3 屏幕小键盘（Keypad）—— 与径向菜单同源的 GDI 浮层

四个独立浮层（都在 `KeypadKeysFor` 里定义）：**方向小键盘**（3×3：四角 = 退格/删除/上页/下页，中心【回车】；无【关】键）、**数字小键盘**（4 列 × 4 行：`7 8 9 +` / `4 5 6 -` / `1 2 3 ×` / `0 . ÷ 回车`，右列为四则运算）、**符号小键盘**（6 列 × 5 行共 30 键：标准键盘上除上述两面板已有键之外的全部符号 + 一个重复的正斜杠 + 空格 / Tab）与**字母小键盘**（6 列 × 5 行共 30 键：`a`-`z` 顺序 + 【Aa】大小写切换 + 【回车】反斜杠【触发】）。触发键默认 `^+k` / `^+n` / `^+y` / `^+e`，均为**开/关切换**，且**各自的触发键只管自己的面板**。

**关键约束（与径向菜单一致，改动时别破坏）**：

- 窗口带 `+E0x08000000`（`WS_EX_NOACTIVATE`）+ `Show("... NoActivate")`：点击 / 拖动都**不抢焦点**，这样点的按键才会发到用户原本的编辑窗口。
- **点按键不关闭**面板（可连续点），关闭靠：自己的触发键、`Esc`、鼠标右键（四套面板都没有【关】键——方向小键盘中心已改为【回车】）。
- 任意位置按下都先记录（`SetCapture`），位移 > 3px 判定为拖拽 → 只 `Gui.Move` 移动面板、不触发按键；抬起时要求**按下与抬起落在同一按键**才发送。**坑：判定为拖拽时必须同时置 `dragging` 与 `dragMoved`** —— 只置 `dragging` 的话，抬起时那段"拖动过就不触发"的分支永远不成立；而面板是 1:1 跟着光标走的，光标底下始终是同一个按键，命中判定挡不住 → 表现为"拖着拖着就把按中的键发出去了"（2026-09-15 用户实测反馈过，四块小键盘都受影响）。
- 位置夹取用 `RadialVirtualBounds()`（虚拟屏幕），不要改用 `A_ScreenWidth`。
- **五块浮层同屏不得重叠**：`OverlayAvoid(active)` 以"正在拖动 / 刚打开"的那块为 active（active 永不移动），把被它压住的浮层沿**最小位移方向**推开，两两留 8px 间隙、连锁处理、落点夹取虚拟屏幕；推不动就原地不动（避免屏幕边缘抖动）。**四个调用点**：`RadialBuildMenu` 末尾、径向拖拽 `Gui.Move` 之后、`KeypadShow` 末尾、小键盘拖拽 `Gui.Move` 之后——以后再新增浮层时务必补调用点。
- **字母键盘的大小写切换**：状态放在全局 `keypadLetterUpper`（运行期内一直记住，默认小写）。点【Aa】（`role = "toggle"`）→ `KeypadOnKeyPress` 翻转状态、`P.keys := KeypadKeysFor(kind)` 就地重建按键、`KeypadDraw` 重绘；**不要改窗口大小或位置**（最宽标签是【回车】/【触发】这两个汉字标签，不随大小写变化，布局天然一致）。`KeypadDraw` 里【Aa】键的底色随大写状态变化（大写偏暖色，起 CapsLock 指示灯作用）。
- 拖动中每次 `WM_MOUSEMOVE` 都会调 `OverlayAvoid`，所以里面只做坐标计算（`WinGetPos` + 比较），**不要在这里加重绘或重日志**。
- **文字层必须跟着面板动**：`KeypadOnMouseMove` 拖动分支、`OverlayMoveTo()`（避让推开）里都要 `OverlayTextLayerMove`；漏一处就会出现"面板走了、文字留在原地"。
- 发送按键复用 `RadialActivateFocusWin()` + `RadialWaitModifiersReleased()`（前缀是 Radial，但逻辑通用），再 `SendEvent`。
- 按键一律发送**普通字符 / 键名**，不用小键盘专用键（数字写 `"7"` 而非 `{Numpad7}`）：不受 NumLock 影响。
- **Send 特殊字符只有 `^ + ! # { }`**：写成 `{+}` `{^}` `{!}` `{#}` `{{}` `{}}`；另外 `"` 与 `` ` `` 是 AHK **源码**转义，要写成 `` `" `` 与 ` `` `。符号小键盘的 30 键已按此转义，改动时别漏。
- 符号小键盘的 30 键 = 标准键盘 32 个可打印标点全覆盖（`*` `+` `-` `.` `/` 由数字面板分担）+ 重复的 `/` + 空格 / Tab，刚好铺满 6 × 5。再加键前先想清楚面板尺寸：`KeypadComputeLayout` 按最宽标签定单元格，例如「空格」两个汉字会把整块面板从 306px 撑到 420px。

**`Overlay*`（浮层公共层，2026-09-15 新增，各浮层的独立性靠它）**：

- **径向菜单 / 方向 / 数字 / 符号 / 字母小键盘必须互相独立**：打开或关闭任一个都**不得**联动关闭另外几个（曾因 `KeypadToggle`→`RadialClose()`、`RadialShow`→`KeypadClose()` 的互斥调用被用户退回）。
  规则：**任何 Close 只关自己**；想一次性收起全部只能靠 `Esc`。
- 五个浮层都不持有键盘焦点，只能共用同一个 `Escape` 热键，因此由 `OverlayPush(name)` / `OverlayRemove(name)` 维护一个栈 `overlayStack`：有浮层打开时注册 `Escape`（`OverlayRegisterEscape`），全部关闭时注销（`OverlayUnregisterEscape`）。
- 栈的**语义是「最近操作过的排在末尾」**（不是"最近打开的"——用户明确要求过）：`OverlayTouch(name)` 把某个浮层移到末尾，调用时机为**打开面板**（即 `OverlayPush`）以及**在面板上移动鼠标（含拖拽）、在其上按下 / 抬起左键（含点空位、点空白的无效点击）**。为此 `RadialOnMouseMove/…LButtonDown/…LButtonUp` 与 `KeypadOnMouseMove/…LButtonDown/…LButtonUp` 都要调一次 `OverlayTouch(自己的 name)`；`OverlayTouch` 在"已在末尾 / 不在栈里"时直接返回，鼠标移动高频调用也不会白搬。
- `OverlayOnEscape()` 关闭**栈末尾那个**（radial → `RadialClose()`，其余 → `KeypadClose(kind)`）。
  **对等契约**：`RadialClose()` 与 `KeypadClose(kind)` 必须各自调用 `OverlayRemove(对应的 name)`，否则栈会残留、`Esc` 不会归还给系统。
- 各小键盘的状态存在注册表 `keypadPanels`（**`Map()`**：kind → 面板状态对象；键 = `"arrow"` / `"numpad"` / `"symbol"` / `"letter"`；动态键必须用 Map，见 §4.1 #19），**不要**再退回"单个全局 gui/hover/drag 变量"的写法——否则多块面板同时打开时会互相踩状态。鼠标消息钩子按 `keypadMsgCount` 引用计数注册 / 注销，回调统一用 `KeypadKindByHwnd(hwnd)` 分发（不属于自己的 hwnd 空 `return` 放行，见 §4.2）。

关键函数：

| 函数 | 职责 |
|------|------|
| `OverlayPush()` / `OverlayRemove()` / `OverlayTouch()` / `OverlayIndex()` / `OverlayOnEscape()` | 浮层栈（最近操作过的在末尾）/ Esc 接管（关闭栈末尾那个）——径向菜单与各小键盘共用 |
| `OverlayRects()` / `OverlayMoveTo()` / `OverlayRectsOverlap()` / `OverlayTryMove()` / `OverlayPushAway()` / `OverlayAvoidPass()` / `OverlayAvoid()` | 浮层避让（10c-2）：取各浮层的窗口矩形 → 把被动方沿最小位移方向推开（8px 间隙、连锁、夹取虚拟屏幕，推不动就不动）；对外只用 `OverlayAvoid(active)` |
| `KeypadLoadConfig()` | 读 `[keypad]`：`arrow_hotkey` / `numpad_hotkey` / `symbol_hotkey` / `letter_hotkey` / `font_size` / `opacity`（防空 + 防呆） |
| `KeypadKeysFor(kind)` | 按键定义数组 `[{label, send, role}]`；`role` = `key` / `toggle` / `action` / `close` / `blank`（`close` / `blank` 保留未用） |
| `KeypadLetterKeys()` | 字母小键盘按键：`a`-`z`（按全局 `keypadLetterUpper` 决定大小写）+ `Aa`（role = `toggle`）+ 回车 / 反斜杠 + 【触发】（role = `action`）。**最宽标签是汉字标签，不随大小写变化，故切换时不需要重新布局** |
| `KeypadRunAction(action)` | `role = "action"` 的键：`"trigger"` → 直接调用 `CompleteAI()`（等同按 SharpKnife 触发命令 Ctrl+J）。**必须直接调用处理函数，不能靠发送 Ctrl+J 再触发自身热键**，原因见 §4.1 #20 |
| `KeypadColsFor(kind)` | 各面板列数（arrow 3 / numpad 4 / symbol 6 / letter 6）；行数由按键数推导，新增面板只需在这里加一行 |
| `KeypadComputeLayout(kind, keys, sizePt)` | 按字号实测文字宽度算面板尺寸与各按键矩形（方向键为正方形） |
| `KeypadToggle(kind)` / `KeypadShow(kind)` / `KeypadClose(kind)` | 各自开 / 关（只影响自己）/ 弹出（鼠标位置、虚拟屏幕夹取） |
| `KeypadKindByHwnd(hwnd)` | 按窗口句柄找面板类型，供共用的鼠标回调分发 |
| `KeypadDraw(kind)` / `KeypadDrawText()` | GDI 双缓冲绘制**面板本体**（悬停高亮；【回车】键偏蓝；`role=close` 的暗红配色保留但未用）；**不画文字** |
| `KeypadPaintTexts(kind, maskDC, colorDC)` / `KeypadTextLayerPresent(kind)` | 面板文字层：所有按键文字（彩色字身 + 白色掩码含黑边）+ 合成 + 呈现；大小写切换后要重新调用 |
| `KeypadHitTest(kind, mx, my)` | 按键矩形命中（空位与空白处返回 0） |
| `KeypadOnMouseMove/…LButtonDown/…LButtonUp/…RButtonDown/…MouseLeave()` | 悬停高亮 + 点击/拖拽判定（阈值 3px）；按 hwnd 分发到对应面板 |
| `KeypadOnKeyPress(kind, idx)` / `KeypadSendKey(kind, raw)` | 分发（close = 关闭本面板、key = 发送）/ 校验目标窗口与修饰键后 `SendEvent` |
| `KeypadTrackMouseEventStruct(hwnd)` | `TrackMouseEvent` 结构（`hwndTrack` 由调用方传入；**不要**复用径向菜单那份） |

配置（`[keypad]`）：

```ini
[keypad]
arrow_hotkey = ^+k   ; 方向小键盘触发键
numpad_hotkey = ^+n  ; 数字小键盘触发键
symbol_hotkey = ^+y  ; 符号小键盘触发键
letter_hotkey = ^+e  ; 字母小键盘触发键
font_size = 15       ; 面板字体（磅，最小 6）；缺省 = [ui] font_size
opacity = 1          ; 面板透明度 0.0~1.0
```

> 调试：WSL 下**无法**验证 GUI/点击行为（Session 0 里连原版脚本的 auto-execute 都会卡住，见 §5）。
> 纯逻辑（配置解析 / 按键定义 / 布局计算）可把函数体逐字提取出来单测——注意 `SharpKnifeCore.ahk` 里有
> 单字母函数 `J()` / `K()`，**顶层**变量不能叫 `j` / `k`（函数内的局部变量没问题）。

### 6.4 已知的历史遗留（可清理，非必须）

- `RadialMakeClickHandler()`、`RadialGetLayout()`、`ATan2()` —— 只剩定义、**无任何调用**（早期"矩形控件版"径向菜单的残留；`ATan2` 是早期按角度命中检测的残留，现已被 `PtInRegion` 取代）。
  清理前请先 `grep` 确认确实无引用。

---

## 7. 与用户协作的节奏（重要）

1. **复杂/有歧义的需求 → 先方案讨论，明确"禁止修改文件"**，等用户确认后再动手。
2. 用户说"**开始改造吧 / 现在就改**"才是动手信号。
3. 每次改完：**先自测纯逻辑** → **重新编译 exe** → **请用户在 Windows 桌面手测** → 等反馈。
4. **不要谎报测试结果**：GUI 行为你无法测，就如实说"需要您在桌面验证"。
5. 用户说"**测试通过**"后，才进入提交。
6. 用户说"**提交 git**"（或"按既定规则提交"）→ 按 §2.2 执行。
7. 用户会做多轮细节微调（对交互与视觉要求高）：保持耐心，**每轮只改必要处**，并在回复里说明"改了什么、请重点验证哪一点"。
8. 需求含糊时（例如"统计关联到配置项"），先复述自己的理解或给出方案让用户确认，**不要凭猜测一路改到底**。

---

## 8. 沟通语言

- 与用户交流、代码注释、提交信息、文档：**全部中文**。
- 回复保持简洁，重点说明：**改了什么 / 为什么 / 请验证什么**。
