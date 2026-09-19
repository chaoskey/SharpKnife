# AGENTS.md —— 给 AI 协作者的长期约定

> **本文件的作用**：把本项目开发中形成的**约定、习惯、风格与踩过的坑**固化下来。
> 即使历史会话被删除、或换到全新会话/新模型，只要读本文件，就应当能**按同样的方式接续开发**，不必重新摸索、也不该重复犯同样的错误。
>
> 最后更新：2026-09-19

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
| **默认热键 / 配置默认值**变更 | 源码默认值 + 注释、`config.ini.example`、`README.md`、`Requirements.md`、本文件的功能地图与示例、`articles/` 下相关文章 |

`README.md` 是**用户文档**（面向使用），`Requirements.md` 是**需求文档**（纯文字、不写实现细节）——不要把实现方案塞进需求文档。

### 2.4 AGENTS.md 的层级

- 子目录里**允许**有各自的 `AGENTS.md`（现有 `articles/AGENTS.md`）：改某个路径下的文件时，仓库根到该文件所在目录**每一层**的 `AGENTS.md` 都要遵守，**越靠近文件越优先**；但都不得推翻本文件 §2 与开发/用户的直接指令。
- 子目录 `AGENTS.md` 由 **AI 自动维护**，**不必等用户提醒**（2026-09-18 用户明确要求）：动手前先确认目标目录有没有它；只对该目录成立的约定/坑写在那里，仓库级共识才写回本文件；**每次在该目录里干完活收尾时，主动把本次新出现的约定/坑补进去，并更新文件顶部的"最后更新"日期**——不要问用户"要不要更新"，直接做，在回复里说一句改了什么。

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
| 21 | **`Gui` 对象被 `Destroy()` 之后再读它的属性（如 `.Hwnd`）会抛 `Error: Gui has no window`**；而 AHK 的**定时器可以在任意时刻插入执行**，所以"先 Destroy、后把全局引用清空"的写法有真实竞态：定时器正好插在中间，就会在窗口已销毁的状态下读 `.Hwnd`（2026-09-15 自然语言运行框按 Esc 关闭时实测崩溃） | 关闭窗口的固定顺序：**先 `SetTimer(自己的定时器, 0)` 停表 → 再清空所有全局控件/窗口引用 → 最后才 `Destroy()`**；此外凡是需要用句柄的地方统一走一个安全包装（如 `RunBoxHwnd()`：`try h := gui.Hwnd`，失败返回 0），不要直接读属性 |
| 22 | **`Run()` 不是 cmd**：传进去的字符串会被当成**一个可执行文件路径**（空格外才是参数），所以把**整条命令用引号包起来**（cmd 里能跑）在 AHK 里会找不到文件 —— `run: "C:\x\app.exe snip --full"` 点下去毫无反应（2026-09-15 用户实测：手工在 cmd 里执行正常，圆盘菜单里却无效）。 | `run:` 推荐写法是**只给可执行文件加引号**：`run: "C:\x\app.exe" snip --full`。`OverlayRunCommand` 现在会生成候选写法**逐个尝试**（① 原样 → ② 整条带引号时拆成 `"exe" 参数` → ③ 未加引号但路径含空格时截到 `.exe/.cmd/.bat/.com` 再补引号），且**原样永远是第一个候选**，保证既有配置行为完全不变；失败会逐条写进 debug.log。 |
| 23 | **顶层函数名不能与全局变量重名**（AHK 变量名 / 函数名都大小写不敏感）：`RunBoxLayout()` 与 `global runboxLayout` 撞名，加载期直接报 `This function declaration conflicts with an existing global variable. Specifically: runboxLayout`（2026-09-18 踩过）。 | 改名前先想清楚：函数用动词式命名（如 `RunBoxComputeLayout()`），变量用名词式；交付前用 `grep -oE '^[A-Za-z_][A-Za-z0-9_]*\(' SharpKnife.ahk \| tr -d '(' \| sort -u` 取全部函数名，和 `global` 名单对一遍差集。 |
| 24 | **`WinGetPos(&x, &y)` 省略标题 = 读"当前前台窗口"，不是"我们自己的窗口"**：多窗口组件里极易静默用错坐标（把别人的位置当成自己的）。2026-09-18 写运行框三窗口同步时自查发现，当时一个 20ms 定时器 + 每帧移动 3 个窗口，只要目标错了就会满屏乱跑。 | 凡是要**自己**窗口的坐标，一律显式写 `WinGetPos(&x, &y, , , "ahk_id " . hw)`（同类的 `WinMove` / `WinGetClientPos` / `Gui.Move` 也一样把目标写全）。 |
| 25 | **`FileRead(path)` 不带编码参数时按 ANSI 读**（只有带 BOM 才自动识别）。中文文件被按 ANSI 读会得到 `鍒悕` 这种乱码，而且**不报任何错** —— 2026-09-19 写运行框记忆时，`runbox_memory.md` 是**不带 BOM 的 UTF-8**（`write` 工具写的），结果 `## 别名` 等小节名全部匹配失败、记忆整块静默失效，排查了很久才发现是编码而不是逻辑。 | 读文本一律走 `RunBoxReadTextFile(path)`（依次试 `"UTF-8"` → `"UTF-16"` → 无参兜底）；**自己写文件时一定补 BOM**（`f.Write(Chr(0xFEFF))`，编码用 `"UTF-8-RAW"`）。 |
| 26 | **`SplitPath` 的出参顺序是 `(&名, &目录, &扩展名, &无扩展名的名)`** —— **扩展名在第 4 位、无扩展名在第 5 位**（与 v1 习惯相反）。写反了不报错，只会拼出 `md.20260919-072350.bak.runbox_memory` 这种怪文件名（2026-09-19 实测）。 | 记牢 (名, 目录, **扩展**, **无扩展名**)；拼扩展名时用 `(ext = "" ? "" : "." . ext)` 防空。 |
| 27 | **`>` 在 AHK 里是"数值比较"**：拿时间戳字符串（`20260919-072007`）或空串去比会抛 `Expected a Number but got a String` / `got an empty string`。 | 时间戳、版本号这类**一律用 `StrCompare(a, b) > 0`**；排序前还要守卫"初值为空串"的情况（`bestKey = "" || StrCompare(...) > 0`）。 |
| 28 | **`IsSet(x)` 只吃变量，不吃属性**（`IsSet(obj.prop)` 直接报 `IsSet requires a variable`）；而对象字面量（Object）**没有 `.Has()`**（§4.1 #4）。 | 判断 Object 有没有某属性用 `try { if (obj.HasOwnProp("prop")) ... } catch { }` 包一层（见 `RunBoxMemoryItemCount`），别用 `IsSet`。 |
| 29 | **箭头函数体写成 `(表达式)` 容易被当成"求值"而不是"执行副作用"**：2026-09-19 写 `push := (s) => (StrLen(s) >= 2 && !RunBoxInArray(keys, s))` 后调用 `push(x)`，`keys` **一直是空数组**（表现为"记忆的相关度排序永远不生效"），且不报错。 | 有副作用的辅助逻辑**老老实实写 `if` + 显式语句**，或用真正的嵌套函数 `f(x) { ... }`；箭头函数只用于"纯取值"。 |

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
- **自动隐藏任务栏**是可靠性分水岭：不隐藏时点击很可靠；隐藏时必须先唤出任务栏，否则常见**任务栏闪一下但键盘不弹出**。
- **数位板笔的限制在驱动层**：笔尖靠近板面时驱动会持续接管/吸附光标，helper 的 `SetCursorPos` 可能落不到目标。可用工作流是**点完“触摸键盘”立刻把笔抬离**；这类问题以**用户桌面手测**为准，笔能稳定用了就不要再往主脚本堆复杂度。
- 配置样例已加入入口：`[radial.Input]` 下 `6 = 触摸键盘 | run: apps\TouchKeyboardToggle.exe`。若未来路径调整，优先改 helper 与样例配置，不改主逻辑。

**COM 方式（2026-09-13 新增，独立文件 `apps/TouchKeyboardToggleCom.ahk`）**：

- **该方法确实存在**：资源管理器点“触摸键盘”图标时，内部就是创建未公开组件并调用 `ITipInvocation::Toggle(HWND)`（`Toggle` 传 `GetDesktopWindow()`，`CLSCTX = 0x6` = INPROC_HANDLER|LOCAL_SERVER；`IID_ITipInvocation` = `{37c994e7-432b-4834-a2f7-dce1f13b834b}`）。
- **用户明确要求 `apps\TouchKeyboardToggle.ahk`（模拟点击版）保持原样**，所以 COM 版是**新增独立文件**，两者互不影响、可同时保留。
- CLSID 有讲究：**本机（Win10 19045）真正能用的是 `{054AAE20-4BEA-4347-8A35-64A533254A9D}`（“UIHost Class”，注册了 `LocalServer32` → `TabTip.exe`）**；网上最常见的 `{4ce576fa-83dc-4F88-951c-9d0782b4e376}`（“UIHostNoLaunch Class”）本机**没有** `LocalServer32`，只有 `TabTip.exe` 已在运行时才可用，否则报 `0x80040154`。helper 因此**两个都试**。
- `TabTip.exe` 未运行时必然失败（`0x80040154`）；helper 策略：先启动 `TabTip.exe`（起进程本身就是“显示”），1.5s 内可见就不再 Toggle（避免“已弹出又被关掉”），仍不可见才补一次 Toggle。
- WSL（Session 0）下 `{054AAE20}` 返回 `0x800702E4`（ERROR_ELEVATION_REQUIRED）——说明**类已注册、SCM 确实去拉起了 TabTip**，只是非交互会话起不来；**不能**据此判定方案不可用。

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

**WSL interop 的进程在 Session 0（Services），不在交互桌面**（`tasklist` 里自己起的显示 `Services 0`，用户的是 `Console 1`）：因此 `WinExist("A")` 返回 0、COM 本地服务器拉不起来、GUI 无法附着桌面。
**结论**：这里只能得出“WSL 里测不了”，**不能**得出“该 GUI/COM 方案不可行”。

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
| 自然语言运行框 | `RunBoxShow()` ← `F6` | 中文需求 → 模型解析成动作序列 → 确认后自动执行（见 6.5） |

### 6.2 径向菜单（Radial Menu）—— 最近改动最多的模块

**三层结构**（外观形式固定：圆形窗口 + 单环扇区 + 放射性文字，仅流程/内容可变）：

1. **第一层【常用】**：圆心 `常用`；周边第 1 个固定 `快捷菜单`，其后为**按统计排出的高频项**（个数 = `[radial] common_max`）。
   点常用项 → 执行快捷键（**不关闭菜单**）；点圆心 → 关闭。
2. **第二层【快捷菜单】**：圆心 `快捷菜单`；周边为**分组名**。点分组 → 第三层；点圆心 → 返回第一层。
3. **第三层【<组名>】**：圆心 = 组名；周边为该组**菜单项**。点菜单项 → 执行快捷键（**不关闭菜单**）；点圆心 → 返回第二层。

**流程要点（2026-09-12 改造）**：

- **触发键 = 开/关切换**：未打开则弹出，已打开则关闭（`RadialShow` 内 `if (radialGui) { RadialClose(); return }`）。
- **执行功能默认不关闭菜单**：`RadialOnItemClick` 的 `exec` 分支只 `RadialBumpStat()` + `RadialExecAction()`（后者走浮层动作层），**不调用 `RadialClose()`**；便于连续执行多个功能。想让某一项点击后关闭菜单，把它的动作写成 `close` 即可。
- **圆心：点击 or 拖拽**（`RadialOnLButtonDown` / `RadialOnMouseMove` / `RadialOnLButtonUp`）：
  按下圆心先记录（鼠标屏幕坐标 + 窗口左上角）+ `SetCapture`；移动时**位移 > 3px** 才判定为拖拽 →
  `Gui.Move(按下时窗口位置 + 位移)` 移动圆盘（1:1 跟手，仅夹取在**虚拟屏幕**内）；抬起时若**没拖过**才触发圆心点击。
  拖拽判定用 `GetCursorPos` 绝对坐标差分（不依赖会随窗口移动而变化的客户区 `lParam`，避免抖动）。
  **拖拽分支只移动窗口，绝不做任何其它动作**（不切层/不关闭/不激活/不改焦点）。
- 圆盘窗口带 **`+E0x08000000`（`WS_EX_NOACTIVATE`）**：点击/拖拽菜单都**不改变前台窗口**（不抢焦点，编辑器光标与焦点不受影响）。
- 因窗口不获取键盘焦点，**Esc 由打开期间的全局热键接管**，但**不再由 radial 自己注册**：统一走 `Overlay*`（见 6.3），`RadialBuildMenu` 末尾 `OverlayPush("radial")`、`RadialClose` 里 `OverlayRemove("radial")`。
  **坑**：`Hotkey(Key,"Off")` 之后，即使再用函数对象注册（不报错）也不会重新启用，必须显式调 `Hotkey(Key,"On")`（`OverlayRegisterEscape` 已按此处理）。
- **分组隐藏参数 `hidden`（2026-09-15 新增）**：`[radial.<组>]` 段里可写 `hidden = true/false`（也接受 `1/0`、`yes/no`、`on/off`；**非法值沿用默认 false**）。分组对象在 `RadialLoadConfig` 里创建时带 `hidden: false`，解析到该键才置位。**三处过滤**（少一处都会"漏"出来）：① 第二层【快捷菜单】用 `RadialVisibleGroups()` 列分组；② 第一层【常用】的 `RadialTopFrequent()` 里 `if (g.hidden) continue`（否则隐藏组的高频项照样冒出来）；③ `RadialBuildMenu` 构建第三层前，若当前分组已隐藏则退回第二层。
  注意：隐藏只影响**圆盘菜单的显示**；`OverlayConfiguredItems()`（运行框的白名单 / `item:` 查表）仍包含隐藏分组的项。如果以后想连运行框也排除，改 `OverlayConfiguredItems()` 一处即可。
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
| `RadialExecAction(item)` | 执行菜单项：**统一交给浮层动作层** `OverlayActionExecute(..., "radial", radialFocusWin)`（旧版自己判 run:/hotkey 的写法已删除） |
| `RadialItemAction()` / `RadialCaseShownName()` | 取菜单项动作文本 / 取菜单项显示名（大小写状态生效时单字母项的名字一起变大写） |
| `RadialStatsInit()` / `RadialStatKey()` / `RadialBumpStat()` / `RadialTopFrequent()` | 统计文件初始化、键转义、计数 +1（实时写盘）、取高频前 N |

配置（`[radial]`）：

```ini
[radial]
trigger = ^+m        ; 触发键
font_size = 15       ; 字体（磅）；缺省 = [ui] font_size
common_max = 6       ; 第一层高频项个数（0~20）

[radial.base]        ; 一个分组 = 一个子节（xxx 为英文标识符，不显示）
name = 基础通用      ; 组显示名（中文）
1 = 复制 | ^c        ; 编号 = 功能名 | 动作（动作写法与四块小键盘**完全相同**）
9 = 删除 | {Del}     ; 多字符键名必须用花括号
8 = 画图 | run: mspaint.exe
7 = 循环提醒 | self:health    ; self: 直接调用本脚本功能（不模拟按键）
6 = 关闭 | close              ; 关闭整个菜单
```

统计文件 `menu_stats.ini`（运行时生成，UTF-16 LE + BOM）：

```ini
[stats]
radial.base.1=12     ; 键 = radial.<组标识>.<编号>，与 config.ini 的 [radial.*] 一一对应
```

### 6.2a 浮层动作层（四块小键盘 + 径向菜单共用，2026-09-15 新增）

**配置里一格/一项的"动作"只有一套定义，两个组件共用**；以后新增动作类型只改两个函数，
小键盘与径向菜单会同时支持（**不要**在某个组件里单独实现一套）：

| 函数 | 职责 |
|------|------|
| `OverlayActionParse(text)` | 动作文本 → `{type, value}`：`none`（空）/ `send`（普通按键或 `send:` / `hotkey:` 显式写法）/ `paste`（`paste:` 剪贴板粘贴）/ `wait`（`wait:` 毫秒，夹取 0~10000）/ `item`（`item: 名称`，按名字执行已配置项）/ `run`（`run:`）/ `self`（`self:`，命令名转小写）/ `close` / `case` |
| `OverlayActionExecute(act, owner, fallbackWin)` | 执行动作；`owner` = `"radial"` 或小键盘 kind，`fallbackWin` = 该浮层记录的备用目标窗口 |
| `OverlaySendKey()` / `OverlayPrepareInject()` | 普通按键：目标窗口校验 + 物理修饰键等待后 `SendEvent`（两个组件共用同一套守卫；`OverlayOwnerHwnd(owner)` 用于"前台被浮层自己占了"的回退判断） |
| `OverlayRunCommand(cmdLine)` | `run:`：等待修饰键释放后 `Run()`（原 `RadialRunCommand`，已改名共用） |
| `OverlayRunSelf(cmd, owner, fallbackWin)` | `self:` 命令表：`trigger` / `toggle_mode` / `mode_latex` / `mode_unicode` / `mode_ai` / `mode_tikz` / `mode_list` / `step` / `health` / `radial` / `keypad_arrow` / `keypad_numpad` / `keypad_symbol` / `keypad_letter`；**直接调用处理函数，不模拟按键**（§4.1 #20） |
| `OverlayCloseOwner(owner)` | `close`：关掉发起动作的浮层（`radial` → `RadialClose()`；其余 → `KeypadClose(kind)`） |
| `OverlayPasteText()` | `paste:`：备份剪贴板 → 写入文本 → `SendEvent("^v")` → 恢复剪贴板（长文本比逐字发送快且稳） |
| `OverlayConfiguredItems()` / `OverlayActionText()` / `OverlayLookupItem()` | 已配置命令表（四块小键盘的键 + 圆盘菜单项 → `{name, action, source}`）/ 圆盘菜单项转动作文本 / 按名字查表（`item:` 与运行框共用） |
| `OverlayCaseUpper()` / `OverlayCaseTransform()` / `OverlayCaseToggle()` / `OverlayRefresh()` | `case`：大小写状态**按浮层名**存在 `overlayCaseState`；`OverlayCaseTransform` 只在"动作恰好是一个 a-z 字母"时把标签与动作一起变大写；`OverlayRefresh` 让小键盘就地重建按键、圆盘重建菜单 |

> **血泪教训（2026-09-15 用户实测反馈）**：径向菜单原来只认 `run:` 与"其余一律当快捷键发送"，
> 所以配置里写 `self:health` 会把 `self:health` **当文本原样打出去**。修法是让径向菜单也走这一层。
> 以后加动作类型（例如 `win:` / `delay:`）时，**必须**在 `OverlayActionParse` 与 `OverlayActionExecute` 两处加，
> 并同步 README / config.ini.example 的动作说明。

### 6.3 屏幕小键盘（Keypad）—— 与径向菜单同源的 GDI 浮层

四个独立浮层（按键内容由 `[keypad.<kind>]` 配置驱动，缺省见 `KeypadDefaultDefs()` 的内置默认）：**方向小键盘**（3×3：四角 = 退格/删除/上页/下页，中心【回车】）、**数字小键盘**（4 列 × 4 行：`7 8 9 +` / `4 5 6 -` / `1 2 3 ×` / `0 . ÷ 回车`，右列为四则运算）、**符号小键盘**（6 列 × 5 行共 30 键：标准键盘上除上述两面板已有键之外的全部符号 + 一个重复的正斜杠 + 空格 / Tab）与**字母小键盘**（6 列 × 5 行共 30 键：`a`-`z` 顺序 + 【Aa】大小写切换 + 【回车】反斜杠【触发】）。触发键默认 `^+k` / `^+n` / `^+y` / `^+e`，均为**开/关切换**，且**各自的触发键只管自己的面板**。四个面板共用同一套实现（键网格 + 角色分发），面板之间只有配置不同。

**关键约束（与径向菜单一致，改动时别破坏）**：

- 窗口带 `+E0x08000000`（`WS_EX_NOACTIVATE`）+ `Show("... NoActivate")`：点击 / 拖动都**不抢焦点**，这样点的按键才会发到用户原本的编辑窗口。
- **点按键不关闭**面板（可连续点），关闭靠：自己的触发键、`Esc`、鼠标右键（四套面板都没有【关】键——方向小键盘中心已改为【回车】）。
- 任意位置按下都先记录（`SetCapture`），位移 > 3px 判定为拖拽 → 只 `Gui.Move` 移动面板、不触发按键；抬起时要求**按下与抬起落在同一按键**才发送。**坑：判定为拖拽时必须同时置 `dragging` 与 `dragMoved`** —— 只置 `dragging` 的话，抬起时那段"拖动过就不触发"的分支永远不成立；而面板是 1:1 跟着光标走的，光标底下始终是同一个按键，命中判定挡不住 → 表现为"拖着拖着就把按中的键发出去了"（2026-09-15 用户实测反馈过，四块小键盘都受影响）。
- 位置夹取用 `RadialVirtualBounds()`（虚拟屏幕），不要改用 `A_ScreenWidth`。
- **浮层避让现在有 6 个参与者**（2026-09-15 起）：径向菜单、四块小键盘，**外加自然语言运行框**。运行框在 `OverlayRects()` 里以 `runbox` 为名，并且是把"运行框 + 键帽排"取**并集**后push进去的**一个整体矩形**（两者必须一起动，不能被拆开）；`OverlayMoveTo("runbox", …)` 挪运行框后调 `RunBoxSyncWindows()`（面板 + 文字层 + 输入框窗口 + 键帽排一起走）。
  调用点：`RunBoxShow()` 末尾、`RunBoxApplyHeight()` 末尾（撑开 / 收起后）、**WM_MOVE(0x0003)**（拖动过程中实时推开被压住的浮层）以及 **WM_EXITSIZEMOVE(0x0232)**（松手后再整理一次）。
  **防互相顶**：运行框被避让挪动时，`OverlayMoveTo("runbox", …)` 记 `runboxAvoidTick`；`RunBoxMoveHandler` 里 `A_TickCount - runboxAvoidTick <= 250ms` 就跳过避让，否则会来回抖。active 永不移动，正常拖动不受影响。
- **六个浮层同屏不得重叠**：`OverlayAvoid(active)` 以"正在拖动 / 刚打开"的那块为 active（active 永不移动），把被它压住的浮层推开，两两留 8px 间隙、连锁处理、落点夹取虚拟屏幕；推不动就原地不动（避免屏幕边缘抖动）。**调用点**：`RadialBuildMenu` 末尾、径向拖拽 `Gui.Move` 之后、`KeypadShow` 末尾、小键盘拖拽 `Gui.Move` 之后，外加运行框的四处（见上一条）——以后再新增浮层时务必补调用点。
  `OverlayPushAway` 会生成**四个候选落点（右 / 左 / 下 / 上）并按位移从小到大逐个尝试**，不是只试"较近的水平 + 较近的垂直"两个：运行框这类大窗口很容易把两个近位都挡住，那时远侧明明有空位却推不动（2026-09-15 实测修掉）。
- **四个面板的按键内容完全由配置驱动**（2026-09-15 改造）：`[keypad.<kind>]` 段里「编号 = 名称 | 动作」，编号即格子序号（行优先、1 起），缺号 = 空位；`cols` / `rows` / `square` / `case` 均可配。动作四类：普通 Send 字符串 / `run:` / `close` / `case` / `self:`（自身命令，直接调用处理函数）。**一个键都没写（或整段删掉）的面板沿用 `KeypadDefaultDefs()` 的内置默认**，所以老配置行为不变。解析用**自定义行解析**（与径向菜单同一套）：整行 `;` 注释、行内「空白 + `;`」注释；值里的 `;` 与 `|` 必须写成 `%3B` / `%7C`（否则被当注释 / 分隔符）。新增面板只需在 `KeypadLoadConfig` 的 kind 白名单与 `KeypadDefaultDefs()` 里各加一处。
- **`OverlayCaseTransform()` 只返回 `{label, action}`**（它要同时服务小键盘与圆盘菜单，圆盘项没有 `role`）——所以**凡是拿它的返回值当"按键对象"用的地方，必须自己把 `role` 补回来**。2026-09-15 就是漏了这一步：`KeypadKeysFor` 在大写状态下用变换结果替换了整对象，导致 30 个键全没有 `role`，字母键盘一切换大小写，`KeypadHitTest` 读 `.role` 就抛 `This value of type "Object" has no property named "role"`（用户实测崩溃）。修法是在 `KeypadKeysFor` 里变换后 `kk.role := k.role`。以后再给"按键"加字段时，记得同步这条。
- **大小写状态是通用机制、不是字母面板专属**（实现见 §6.2a 的浮层动作层）：`case = true` 的面板才启用，状态存在 `overlayCaseState`（**按浮层名**，运行期内记住，默认小写）。点动作是 `case` 的键 → `OverlayCaseToggle(kind)` → `OverlayRefresh(kind)` 就地重建按键 + `KeypadDraw` 重绘 + 文字层重建；**不要改窗口大小或位置**。大写只影响「动作恰好是一个 ASCII 小写字母」的键（标签与发送内容一起变大写），其它键（回车、`\`、`^j`、`run:`、数字、符号）不受影响；`KeypadDraw` 里该键底色随状态变化（大写偏暖色，起 CapsLock 指示灯作用）。
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
| `KeypadLoadConfig()` | 自定义行解析 `[keypad]`（4 个触发键 / `font_size` / `opacity`）与 `[keypad.arrow/numpad/symbol/letter]`（`name` / `cols` / `rows` / `square` / `case` / `编号 = 名称 \| 动作`）；防空 + 防呆，缺段 / 非法值一律沿用内置默认 |
| `KeypadDefaultDefs()` | 四块面板的**内置默认**按键（等于改造前写死的那四套；配置里一个键都没写的面板就用它） |
| `KeypadParseItem()` / `KeypadUnescape()` / `KeypadRoleFor()` | 解析「名称 \| 动作」、反转义 `%3B`→`;` `%7C`→`\|`、把动作归到角色（`key` / `close` / `case` / `blank`） |
| `KeypadKeysFor(kind)` | 按定义表 + 当前大小写状态生成按键数组 `[{label, action, role}]`（`role` = `key` / `close` / `case` / `blank`）；**动作语义**见 `KeypadOnKeyPress` |
| `OverlayCaseUpper(owner)` / `overlayCaseState` | 大小写状态**按浮层名**存（`Map`：`"letter"` / `"radial"` → true/false，运行期内记住）——属于浮层动作层（见 6.2a） |
| `KeypadColsFor()` / `KeypadRowsFor()` / `KeypadSquareFor()` | 列数 / 行数 / 是否正方形按键，全部来自定义表（`[keypad.<kind>]`，缺省用内置默认） |
| `KeypadComputeLayout(kind, keys, sizePt)` | 按字号实测文字宽度算面板尺寸与各按键矩形；行数取「定义里声明的行数」与「按键数推导」的较大者，`square = true` 时按键取正方形 |
| `KeypadToggle(kind)` / `KeypadShow(kind, pushEscape := true)` / `KeypadClose(kind)` | 各自开 / 关（只影响自己）/ 弹出（鼠标位置、虚拟屏幕夹取）；`pushEscape = false` 时只建面板、不登记浮层栈（运行框下方的键帽排 `runkeys` 用它，见 6.5） |
| `KeypadKindByHwnd(hwnd)` | 按窗口句柄找面板类型，供共用的鼠标回调分发 |
| `KeypadDraw(kind)` / `KeypadDrawText()` | GDI 双缓冲绘制**面板本体**（悬停高亮；【回车】键偏蓝；`role=close` 的暗红配色保留但未用）；**不画文字** |
| `KeypadPaintTexts(kind, maskDC, colorDC)` / `KeypadTextLayerPresent(kind)` | 面板文字层：所有按键文字（彩色字身 + 白色掩码含黑边）+ 合成 + 呈现；大小写切换后要重新调用 |
| `KeypadHitTest(kind, mx, my)` | 按键矩形命中（空位与空白处返回 0） |
| `KeypadOnMouseMove/…LButtonDown/…LButtonUp/…RButtonDown/…MouseLeave()` | 悬停高亮 + 点击/拖拽判定（阈值 3px）；按 hwnd 分发到对应面板 |
| `KeypadOnKeyPress(kind, idx)` | 取出按键的动作文本，**统一交给浮层动作层**执行：`OverlayActionExecute(OverlayActionParse(k.action), kind, P.focusWin)` |
| `KeypadTrackMouseEventStruct(hwnd)` | `TrackMouseEvent` 结构（`hwndTrack` 由调用方传入；**不要**复用径向菜单那份） |

配置（`[keypad]`）：

```ini
[keypad]                 ; 触发键 / 字号 / 透明度（与原样一致）
arrow_hotkey = ^+k
numpad_hotkey = ^+n
symbol_hotkey = ^+y
letter_hotkey = ^+e
font_size = 15
opacity = 1

[keypad.arrow]           ; 一个面板一段：cols / rows / square / case + 编号 = 名称 | 动作
name = 方向键盘
cols = 3
rows = 3
square = true
1 = 退格 | {BS}
5 = 回车 | {Enter}
6 = 复制 | ^c            ; 动作也可以直接是快捷键
7 = 记事本 | run: notepad.exe
8 = 触发 | self:trigger  ; self: 调用本脚本自身功能（不模拟按键）
9 = 关闭 | close

[runbox]                 ; 自然语言运行框（见 6.5）
hotkey = F6
confirm = true           ; 先列清单、确认后执行
step_delay_ms = 120
run_wait_ms = 800
max_actions = 40

[keypad.letter]          ; 字母面板：case = true 启用大小写状态
cols = 6
rows = 5
case = true
1 = a | a
27 = Aa | case           ; 点它切换大小写
30 = 触发 | self:trigger
```

> 配置里某个面板**一个键都没写**（或整段删掉）→ 沿用内置默认按键；`config.ini.example` 里的四段就是内置默认的完整等价写法。
> 值里的分号 / 竖线写 `%3B` / `%7C`（符号面板的 `;` 与 `|` 两个键即如此）。

> 调试：WSL 下**无法**验证 GUI/点击行为（Session 0 里连原版脚本的 auto-execute 都会卡住，见 §5）。
> 纯逻辑（配置解析 / 按键定义 / 布局计算）可把函数体逐字提取出来单测，但**提取脚本本身有三个坑**（2026-09-15 全部踩过）：
> ① sed 提取函数要用 `^函数名(参数) {` **带上 ` {`** 锚定：只写 `^KeypadLoadConfig()` 会同时匹配 auto-execute 段里的**裸调用**，把中间的其它函数一起卷进来、导致"无输出卡死"；
> ② 被测函数用到的**全局变量必须在测试脚本里也赋值**（哪怕赋空串）：AHK v2 对"从未被赋值的全局变量"会弹**加载期警告框**阻塞脚本，症状同样是"毫无输出"（与 §4.1 #15 同类）；
> ③ 测试脚本里的变量名别撞内置函数：`Ln`（自然对数）当变量名会报错，`log` 同理（§4.1 #3）——本例中 `Ln` 就白折腾了一轮。
> ④ 提取出来的测试脚本顶部要写 `#Warn All, Off`（加载期 `#Warn` 弹框会阻塞、`/ErrorStdOut` 抓不到，见 §5.1）。
> ⑤ 测试脚本里的全局变量要**按类型**赋初值：`keypadPanels` / `keypadDefs` 之类必须是 `Map()`，`overlayStack` 是 `[]`，计数器是 `0`；赋成空串会在 `.Has()` / `++` 上直接报错。另外**块外被调用的 GDI 辅助函数（`BrushSolid` / `RectStruct` / `BrushColorVal` / `RadialMeasureText` / `RadialCreateFont`）要抽真实实现**，打成返回空串的桩会在 `.w` / `FillRect` 上炸。
> ⑥ **不要在无桌面测试里走到 `Hotkey(...)` 注册**（例如 `OverlayPush` → `OverlayRegisterEscape`）：Session 0 下会直接阻塞。
> 另注意 `SharpKnifeCore.ahk` 里有单字母函数 `J()` / `K()`，**顶层**变量不能叫 `j` / `k`（函数内的局部变量没问题）。

### 6.4 已知的历史遗留（可清理，非必须）

- `RadialMakeClickHandler()`、`RadialGetLayout()`、`ATan2()` —— 只剩定义、**无任何调用**（早期"矩形控件版"径向菜单的残留；`ATan2` 是早期按角度命中检测的残留，现已被 `PtInRegion` 取代）。
  清理前请先 `grep` 确认确实无引用。

---

### 6.5 自然语言运行框（RunBox，2026-09-15 新增）

**一句话**：`[runbox] hotkey`（默认 `F6`）→ 单行输入框写中文需求 → 交给 `[ai]` 的模型解析成**动作序列** → 状态行给一行摘要、回车确认 → 逐条自动执行。

| 函数 | 职责 |
|------|------|
| `RunBoxLoadConfig()` / `RunBoxCfg()` | 读 `[runbox]` 段；`RunBoxCfg` 负责**剥离行内注释**（`IniRead` 不会剥，"值  ; 注释" 会把注释带回来） |
| `RunBoxCatalogText()` | 把 `OverlayConfiguredItems()` 压成"`[面板/组] 名字=动作、…`"文本，喂给模型；解析时另用它做白名单 |
| `RunBoxBuildPrompt()` / `RunBoxBuildFallbackPrompt()` | 第一阶段"判类别 + 翻译成动作"提示语（含已配置命令表 + `prompt_extra`）；第二阶段兜底提示语只问"这条需求能不能当文字输出"。都借 `AIRequest` 第 5 个参数覆盖 `[ai] system_prompt` |
| `RunBoxParseReply(reply)` | **纯文本放行 + 动作严格白名单**解析 → `{actions, dropped, error, noAction}`；容忍 markdown 围栏与行首编号；`ERROR:` 单独识别、`NOACTION` 单独标记 |
| `RunBoxShow()` / `RunBoxClose()` / `RunBoxDefault()` / `RunBoxEsc()` | 弹出 / 关闭（**四窗口结构**见下）：面板 `Gui` + 文字层 + 独立的输入框窗口 + 独立的执行过程窗口（`Edit` + 隐藏的 `Default` 按钮吃回车，`OnEvent("Escape")` 吃 Esc）；状态机 `input → loading → confirm → running → done` |
| `RunBoxSubmit()` | 取需求 → 临时覆盖 `ai_model` / `ai_timeout` → `AIRequest(..., sysPrompt)` → 解析 → `RunBoxShowConfirm()`；失败回到输入态并把原因显示在状态栏 |
| `RunBoxShowConfirm()` | 状态行给一行摘要（"将执行 N 条，丢弃 M 行：回车执行…"），明细写进过程日志；`confirm = false` 时直接 `RunBoxExecute()` |
| `RunBoxExecute()` / `RunBoxStep()` / `RunBoxFinish()` | `SetTimer` 逐条推进（不阻塞、可中断）：每条走 `OverlayActionExecute(act, "runbox", runboxPrevWin)`；`run:` 后额外等 `run_wait_ms`；结束/中止都停表并显示结果 |
| `RunBoxToggleDetail()` / `RunBoxLogAdd()` / `RunBoxRenderLog()` | 底部"执行过程"把手：展开 / 收起面板（改高度 + 显示/隐藏日志窗 + 重排），并记全过程日志（需求 → 模型结果 → 清单与丢弃 → 每条成败与耗时 → 结果与总耗时）；收起时不渲染，展开时才把日志写进只读 Edit 并滚到底（可滚动 / 选中 / 复制） |
| `RunBoxEscOn()` / `RunBoxEscOff()` / `RunBoxEscHandler()` | 执行期间临时接管全局 `Escape`（按一次 = 中止剩余动作）；结束后若有浮层则 `OverlayRegisterEscape()` 还回去，否则 `Hotkey("Escape","Off")` |
| **窗口层（2026-09-18 新增）** | |
| `RunBoxComputeLayout()` / `RunBoxPanelHeight()` | 算布局（面板 / 输入框 / 状态 / 把手 / 日志的矩形，缓存进 `runboxLayout`）与当前应有的高度 |
| `RunBoxApplyOpacity(hwnd)` | 面板整窗 `LWA_ALPHA = [runbox] opacity`（只在 < 1.0 时加 `WS_EX_LAYERED`） |
| `RunBoxPanelDraw()` | GDI 双缓冲画面板本体（底色 2D2D2D + 1px 浅灰边框；**不画文字**） |
| `RunBoxPaintTexts()` / `RunBoxDrawText()` | 文字层内容：提示行（FFD98A）/ 状态行（E6E6E6，13pt）/ 把手（9EC8FF），彩色字身 + 黑边（执行过程已不在这里画，见下方 `runboxLogGui` 行） |
| `RunBoxTextLayerPresent()` / `RunBoxTextsChanged()` / `RunBoxTextsFlush()` / `RunBoxSetStatus()` / `RunBoxSetHandle()` | 重画文字层（固定只盖面板上半部分）；状态行 / 把手文字改成"改变量 + 节流重绘"（250ms 合并，首个请求立即重绘） |
| `RunBoxLogVisible()` / `RunBoxLogBoxes()` / `RunBoxInputVisible()` | 执行过程窗口：展开时 `Show("NoActivate")` 并贴到日志矩形、收起时 `Hide`；输入框窗口：解析期间整块隐藏（白底会留白条）、完成后恢复并重新贴合 |
| `RunBoxTextBoxes()` / `RunBoxSyncWindows()` / `RunBoxFocusInput()` | 输入框窗口贴到面板上的输入框矩形（用客户区偏移 `runboxInOffX/Y` 换算）；四窗 + 键帽排一起对齐；把焦点 / 光标交给输入框窗口 |
| `RunBoxDragStart()` / `RunBoxDragTick()` / `RunBoxDragEnd()` | 自实现面板拖动：`SetCapture` + 20ms 定时器轮询 `GetCursorPos` / `GetAsyncKeyState`，位移夹取虚拟屏幕 |
| **自适应记忆（2026-09-19 新增）** | |
| `RunBoxMemoryPath()` / `RunBoxReadTextFile(path)` | 记忆文件路径（相对脚本目录）与**带编码的健壮读取**（见下方坑 ①） |
| `RunBoxMemoryParse(t,&m)` / `RunBoxMemoryParseItem(raw,sec)` | 记忆文本 ↔ 模型；四段 = `## 别名/偏好/正例/反例`，另有 `## 快捷`（预留、原样保留）与"不认识的小节"（同样原样保留） |
| `RunBoxMemoryLoad(force)` / `RunBoxMemoryReloadIfChanged()` | 加载 / 按 mtime 变化重载（用户手改文件后不必重启）；`memory_file` 留空 = 空记忆、功能降级为原行为 |
| `RunBoxMemoryRender(m)` / `RunBoxMemorySave(m,what)` / `RunBoxMemoryBackupPath()` / `RunBoxMemoryPruneBackups()` / `RunBoxMemoryLatestBackup()` / `RunBoxMemoryUndo()` | 渲染全文（**保留不认识的段落与手写注释**）→ 备份（保留最近 5 份）→ 写 `.tmp` 再改名（原子）→ 可回滚 |
| `RunBoxAllowedMaps(&act,&name)` | 白名单两张表（**解析与别名快路径共用同一套**，别在两处各写一份） |
| `RunBoxMemoryPromptBlock(req)` / `RunBoxMemoryBlockText()` / `RunBoxMemoryQueryKeys()` / `RunBoxMemoryAliasFold()` | 记忆块拼进提示语（按相关度排序 + 字数封顶 + 裁剪计数写日志） |
| `RunBoxAliasResolve(req,&hits,&why)` / `RunBoxAliasResolveTarget()` / `RunBoxAliasBump()` | **别名快路径**：命中即**不调模型**直接给动作；目标一律过白名单；说法折叠大小写、**目标值原样** |
| `RunBoxFeedbackPrefix(text)` / `RunBoxBuildLearnPrompt()` / `RunBoxMemoryListing()` | 反馈前缀识别（`纠正：` `更正：` `记住：` `记下：` `学习：`）与"记忆维护"专用提示语（与运行框提示语**分开**） |
| `RunBoxParseLearnReply(reply)` / `RunBoxMemoryPlan(parsed)` / `RunBoxMemoryIndexMap()` / `RunBoxMemoryApplyPlan(plan)` / `RunBoxMemoryPlanDiff(plan)` | 学习回复解析（只认 `ADD alias/pref/example/counter` 与 `DEL n`，其余全丢）→ 逐条校验（目标必须过白名单）→ 生成 diff → 应用（不落盘） |
| `RunBoxLearningStart(feedback)` / `RunBoxLearnShowDiff(plan)` / `RunBoxLearnApply(plan)` / `RunBoxLearnConfirmGo()` / `RunBoxLearnCancel()` / `RunBoxLearnAbort()` / `RunBoxLearnArm()` | 学习流程与两个新状态 `learning` / `learnconfirm`（回车才写盘；Esc 只取消、不关运行框） |
| `RunBoxSelfCommand(c)` | 运行框自身 `self:` 命令：`runbox_learn` / `runbox_memory_reload` / `runbox_memory_undo` / `runbox_memory_show`（`OverlayRunSelf` 里按 `runbox_` 前缀转发） |
| `RunBoxJournalAppend()` / `RunBoxJournalFlush()` / `RunBoxJournalEscape()` | 运行流水 `runbox_learn.log`：**只写不读**、不参与提示语；一次需求一条（含命中的别名与记忆块规模） |
| `RunBoxDumpPrompt(req)` | 诊断开关 `--dump-runbox-prompt[=需求]`：把真实提示语写进 `runbox_prompt_dump.txt`（评测脚本与用户自查共用） |

**设计要点 / 坑**：

- **界面只有两块**（用户明确要求，2026-09-15 从三块改为两块）：① 输入框；② 可展开 / 收起的"动作执行过程"。**没有**独立的"计划清单"控件——清单明细与丢弃原因只写进过程日志，状态行只给一行摘要。
  （2026-09-18：输入框与执行过程各在一个**独立的不透明顶层窗口**里，都是 `Edit`（白底黑字输入框 + 深色只读日志框）；"两块"的语义没变。）
- **四窗口结构（2026-09-18 改造，动运行框之前先看懂）**：用户先要求"除输入框外都受 `[runbox] opacity` 控制、面板上的文字一律带黑边且不受透明度影响"，实测后又要求"执行过程必须能选中 / 复制 / 滚动"。**Windows 硬约束**：`SetLayeredWindowAttributes(LWA_ALPHA)` 是按**整个顶层窗口**（含其所有子控件）施加的，子控件没法单独豁免 —— 所以**输入框与执行过程都必须各自成一个顶层窗口**，运行框因此共四个窗口（外加复用的键帽排）：
  · `runboxGui`    面板：GDI 自绘底色 / 1px 边框 / 圆角，整窗 `LWA_ALPHA = [runbox] opacity`，带 `WS_EX_NOACTIVATE`（点面板不抢焦点），**不画任何文字**；
  · `runboxTextGui` 文字层：`OverlayTextLayerNew` + `OverlayTextLayerPresent`（与径向菜单 / 小键盘同一套），**只盖面板上半部分**（提示行 / 状态行 / 把手），文字与黑边 alpha 恒 255；
  · `runboxInputGui` 输入框窗口：不透明顶层窗口（`-Caption +AlwaysOnTop +ToolWindow`），白底黑字 `Edit` + 隐藏 Default 按钮；Esc 事件挂在它上面；
  · `runboxLogGui`  执行过程窗口：同样独立、不透明，里面是只读多行 `Edit`（`+VScroll`：可滚动 / 选中 / `Ctrl+C`），收起时 `Hide`。
  四者一起移动（`RunBoxSyncWindows`）、一起避让（`OverlayRects()` 里并成 `"runbox"`）；`RunBoxHwnd()` 返回**面板**；判断"是不是运行框自己"一律走 `RunBoxIsSelfWin()`（面板 + 输入框 + 执行过程 + 键帽排）——`OverlayPrepareInject` 对 runbox / runkeys 也改用它（只比一个句柄会漏掉另外两个窗口）。
- **模型输出=不可信输入；判定顺序（2026-09-17 用户定稿）**：`RunBoxParseReply` 把 `OverlayConfiguredItems()` 压成白名单（`"类型|内容"→配置原写法`、`名称→配置名称`），`RunBoxSubmit` 分两步走：
  · **第一步 判类别**（`RunBoxBuildPrompt`）：要文字（网址 / 答案 / 内容 / 翻译…）→ 直接 `paste:`（推荐）/ `send:` / `hotkey:`，**无需先配置**、必须照原样输出，`send:` / `hotkey:` 只在不含 `^ ! + # { }` 时当纯文本；要操作 → 只能用表里的动作（`item:` 首选或逐字一致的动作），表里没有则按约定输出 `ERROR: NOACTION`；**多行文字**（写诗等）写成一行 `paste:` + 字面 `\n`（解析时还原成真换行），另把 `paste:` 后紧跟的裸行当**续行**拼进同一条（`contIdx`）——两条路都保证一次粘贴、换行不丢。
  · **第二步 兜底重问**：第一阶段 `parsed.error != "" || actions.Length = 0` 时用 `RunBoxBuildFallbackPrompt()` **再问一次**"这条需求能不能也理解成要文字？" → 能就 `paste:` 输出，不能就 `ERROR: 没有对应的操作`；程序用 `RunBoxFallbackPick()` **只接受文字**（`paste:` 或漏写前缀的纯文本；按键 / `item:` / `run:` / `self:` 全丢弃，兜底路径不可能执行动作），最终只提示"没有对应的操作"、不往编辑器打字。`RunBoxParseReply` 返回 `noAction`（宽松匹配 `no[\s_-]*action`）。
  · **没前缀的裸文字不执行**（防解释被打进编辑器）；`wait:` 丢弃；丢弃原因写进"执行过程"。
  · **日志**：`RunBoxAskModel()` 统一套用 / 恢复 `[runbox] model`、`timeout_ms`；`RunBoxLogModelReply()` + `RunBoxBrief()` 把两次请求的**模型原文（600 字）与思考（300 字）**压成一行记进 debug.log。
  **红线不变**：动作仍只允许执行配置里已有的；"输出文字"是用户放行的。
  **大小写必须精确匹配**（2026-09-15 用户实测"要大写却打出小写"的根因）：`RunBoxParseReply` 的白名单键、`OverlayLookupItem` 的比较都**不能**用 `StrLower` 折叠或 AHK 的 `=`（`=` 大小写不敏感）—— 否则 `item: A` 会命中配置里先出现的 `a`（字母键盘的小写项），于是打出小写。现在名字用 `allowedName[原名]`、动作用 `type . "|" . 原样动作` 作键，`OverlayLookupItem` 用 `==` 比较。
  另外 `OverlayConfiguredItems()` 会给 `case = true` 的面板**追加大写变体**（`StrUpper` 标签与动作，与 `KeypadKeysFor` 生成大写键的方式一致），这样"说出大写字母"时模型才能引用到 `A` 这一项。
  两个提示语必须与上面的判定顺序一致：`RunBoxBuildPrompt`（判类别 + 动作）与 `RunBoxBuildFallbackPrompt`（兜底只问"能不能当文字"）；**不要**为了让模型"更聪明"放宽**动作**校验（动作只认配置里已有的），也不要把"输出文字"这类需求又收回去。
- **自适应记忆（2026-09-19 新增，动它之前先读这段）**——目标是"运行框越用越准"，设计要点：
  · **分层，不是替换**：提示语顺序固定为 **骨架（格式契约 + 安全红线）→ 自动记忆 → 手写 `prompt_extra` →「已配置动作表」**。动作表**必须留在最末尾**（离 user 消息最近，注意力最强）；记忆块绝不能接在它后面。**记忆只是软参考**，拼进去时明确声明"不得用它改变输出格式或动作表"。
  · **记忆不生产能力**：任何需要"新增动作类型"的需求（典型：打开网址）都**不属于**这里 —— 那是 `Overlay*` 动作层的事。记忆只固化"用户怎么说 / 怎么理解"。
  · **别名快路径先于模型**（`RunBoxAliasResolve` 在 `RunBoxSubmit` 里**排在 `RunBoxAskModel` 之前**）：命中就不调模型。命中规则见 `alias_match`（默认 `contain`，且**说法须 ≥2 字**——单字别名会把本该交给模型的句子"截胡"）。目标解析后**一律过 `RunBoxAllowedMaps` 白名单**，所以记忆里写 `url: …`（本期不存在的动作类型）也不会凭空造出能力，只会被拒。
  · **只有显式反馈能改记忆**：程序**判不出**"这次执行成功了没有"，模型自认为成功不算成功 —— 所以隐式信号（重发、Esc 中止、ERROR）只进 `runbox_learn.log` 流水，**绝不自动改提示语**。要自动化这套之前，先想清楚这一点。
  · **学习只允许 ADD / DEL 条目**，不允许模型重写整个文件；写盘前备份（保留最近 5 份）、写 `.tmp` 再改名；`RunBoxMemoryRender` 必须**保留不认识的段落与手写注释**（`## 快捷` 段是给下一期预留的，写入时不得丢失）。
  · 三个状态变量要分清：`runboxMemory`（当前记忆）、`runboxLearnPlan`（待确认的变更计划，`learnconfirm` 态回车才落盘）、`runboxLastReq/LastActions/LastResult`（反馈学习要用的"上一次"上下文）。
  · 学习流程**只写记忆文件，不执行任何动作**：`RunBoxParseLearnReply` 的返回值里**不存在**可执行动作数组，别给它加。
  · **改名/删除配置项后**记忆里的别名会指向失效目标：运行时会**跳过该条并写日志**，但**不删盘上的条目**（配置可能只是临时改名）——这是有意为之。
  · 记忆的四个文件全是运行时产物，已进 `.gitignore`：`runbox_memory.md`、`runbox_memory.*.bak.md`、`runbox_learn.log`、`runbox_prompt_dump.txt`。
- **`--dump-runbox-prompt[=需求]` 与 `--selftest` 的分流位置很讲究**：必须放在 **auto-execute 开头、任何配置加载与热键注册之前**（`A_Args` 要到 auto-execute 才可用，所以这是最早的位置）。理由见 §5.1：加载期弹框会阻塞脚本、那时一行代码都没执行，开关放得越晚越可能在半路卡死。`test/runbox_eval/runbox_eval.py` 就是靠这个开关拿到**与线上完全一致**的提示语。
- **允许"用已有动作组合达成目标" + 危险动作不得被组合（2026-09-19 用户定稿）**：用户要的是**目标**，目标不必在表里；约束只落在**动作**层——最终序列里**每个动作**都必须在表里。提示语因此把原来的"表里没有 → 立刻 ERROR: NOACTION"改成"先想能不能用已有动作**组合**出来，实在不行才 NOACTION"，并加了两个组合示例（含用户实测那条"向上选三个文件"→ `item: 按下Shift` / `{Up}` / `{Up}` / `item: 松开Shift`）。
  两个配套要点，改之前必须知道：
  ① **危险类必须在程序里硬拦，不能只写提示语**：`RunBoxDangerWords()` / `RunBoxIsDangerous()` 按**配置项名 + 动作文本**的关键词识别删除 / 永久删除 / 剪切 / 关闭 / 重命名等；`RunBoxParseReply` 在**序列多于 1 条**时丢弃其中的危险动作。实测（2026-09-19）：提示语里已标 ⚠危险，模型**仍然**把危险动作编进组合（"清空文件夹"→ [全选/删除/回车]，"剪切并粘到上一级"→ [剪切/上/粘贴]），**所以软约束不够**。
  ② **"单条不拦、多条才拦"是用户确认的边界**：序列只有 1 条时那是用户在明确要求这件事（"删除这个文件"必须照常能用），多条时才算"被编进组合"。改这个判断前先想清楚，别把用户的正常删除需求一起拦掉。
  ③ `RunBoxCatalogTextMarked()` 是喂给模型的那份动作表（带 ⚠危险 标记），`RunBoxCatalogText()` 保持无标记、供其它地方用。
  ④ 踩过的坑：判危险时取配置项要用 `OverlayLookupItem()` 返回的 `{name, action, source}`，**不要**把 `{name, action, source}` 丢给 `OverlayActionText()`——那个函数吃的是圆盘菜单项对象（`actionType` / `actionValue`），字段不同，会抛 "has no property named actionType"。
- **运行框执行序列"跳过修饰键闸门"（2026-09-19 用户实测反馈后定稿，别改回去）**：`OverlayPrepareInject` 里那道 `RadialWaitModifiersReleased()`（等 400ms 让 Ctrl/Shift/Alt/Win 抬起）是为**浮层**设计的——浮层被 `Ctrl+Shift+M` 之类的真实组合键唤起时，用户手指可能还按着，不等就会把注入的按键拼成组合键。但自然语言运行框的**多步序列**里"按住修饰键"本身是合法写法（`{Ctrl down}` … `{Up}` … `{Ctrl up}`），前一步注入后修饰键就处于按下状态，于是后面**每一步都 400ms 超时被取消**——用户实测就是"第 1 条 16ms 成功、其余全部 406ms 未执行"，而且第 7 条 `{Ctrl up}` 永远发不出去（闸门要求"先松开才准发松开"）。
  现在的做法：`OverlayPrepareInject` 里按 owner 分流，**`owner = "runbox"` 跳过等待**，其余（`radial` / `arrow` / `numpad` / `symbol` / `letter` / `runkeys`）**行为一字不变**。`run:` 走 `OverlayRunCommand`，那条路径不接 owner，**保持原样继续等待**（用户选法 A）。
  配套：`RunBoxReleaseModifiers()` 在 `RunBoxFinish`（正常结束与 Esc 中止的唯一收尾点）里抬起悬挂的修饰键，防止序列中途被打断而"Ctrl 粘住"。它**只对逻辑上按下的键发 up**，且**清不掉"跨需求故意保持"**的用法（不做超时自动松开）。
  改这里之前想清楚：**不要**为了方便把闸门在浮层那边也去掉（会破坏组合键唤起后的注入），也**不要**把 `run:` 一起放开（用户明确选了 A）。
- **触发键默认 F6（2026-09-18 起）**：单键触发比三键组合省事，且 F6 在常用软件里裸按冲突最小（老的 `^+i` 会顶掉浏览器 DevTools 的 `Ctrl+Shift+I`）。换默认键时必须按 §2.3 的表把源码默认值 + 注释、`config.ini.example`、`README.md`、`Requirements.md`、本文件与 `articles/` 文章一次同步干净（2026-09-18 就是这么从 `^+i` 换成 `F6` 的）。另注意笔记本顶排可能是媒体键（Fn-Lock），单键能否生效要用户桌面手测。
- 等待**不让模型输出**：动作间 `step_delay_ms`、`run:` 后 `run_wait_ms` 由程序插；`wait:` 动作只留给配置层用（面板/菜单做宏）。
- `AIRequest` 第 5 个参数 `systemPrompt` 为空时沿用 `[ai] system_prompt`，非空时覆盖 —— 运行框靠它换提示语，其它调用点不受影响。
- 运行框**要抢焦点**（要打字、要输入法），与五块浮层的 `WS_EX_NOACTIVATE` 相反；执行完 `RunBoxFinish` 置回 `"input"`、清空输入框（焦点去向见下条）。
- **目标窗口用 `RunBoxTrackTarget()` 持续跟踪**（打开期间 `SetTimer(..., 400)`，跳过 `RunBoxIsSelfWin()` 认出的自家窗口）：只看弹出那一刻不够 —— 用户中途切到别的程序后，之后的目标就该是那个程序（用户要求：最近一个活动的窗口，排除运行框本身）。
- **展开 / 收起：布局算高度 + 默认收起**（2026-09-15 定稿"确定性高度"，2026-09-18 改为布局驱动）：
  · 高度只有两个值，都由 `RunBoxComputeLayout()` 按字号实测算出（不再 `AutoSize`、不再用 `ControlGetPos` 量控件）：`hSmall`（收起）与 `hBig`（展开 = 收起 + 间距 + 14 行日志高）。
  · `RunBoxApplyHeight()` = 按 `runboxExpanded` 选高度 → `Move()` 并夹取屏幕 → 重画面板 → `RunBoxLogVisible()`（展开显示 / 收起隐藏执行过程窗口）→ `RunBoxSyncWindows()` 重排四窗 + 键帽排 → 重画文字层。
  · **默认必须是收起态**：`RunBoxShow` 里显式 `runboxExpanded := false`（执行过程窗口创建后先不 Show，由 `RunBoxLogVisible` 管）。
  · **收起时不渲染执行过程**（用户明确要求）：`RunBoxLogAdd` 只把行压进 `runboxLog`，展开时才 `RunBoxRenderLog()` 把日志写进只读 Edit（写 Edit 很便宜，不必节流）。
- **配色与字号（2026-09-18 用户反馈"看着费劲"后调整）**：提示行 `FFCB66`→`FFD98A`、状态行 `888888`→`E6E6E6`、把手 `88AADD`→`9EC8FF`；状态行字号由 `ui_font_size - 4` 提到 `ui_font_size - 2`（15pt 时 11→13pt）；输入框改**白底黑字**（`c000000 BackgroundFFFFFF`）。配色硬编码在 `RunBoxPaintTexts()` 里，要改就改那里。
- **运行框下方的热键键帽（2026-09-15 新增）**：就是**第 5 个小键盘面板** `runkeys`（一排 7 键：回车 `{Enter}` / Tab / 空格 / 删除 / 退格 / 取消 `{Esc}` / 触发 `self:trigger`，`cols: 7, rows: 1`），布局、圆角、悬停高亮、**文字层**（字身 + 黑边，字号取 `[keypad] font_size`）都与小键盘 / 圆盘一致。
  · `KeypadShow(kind, pushEscape := true)` 新增了开关：键帽排传 `false`，**不登记浮层栈**（Esc 仍归运行框管）。这样也不会因为弹一次键帽排就去注册 / 注销全局 Escape 热键。
  · `OverlayOwnerHwnd("runkeys")`（与 `"runbox"` 一样）返回**输入框窗口的 hwnd**：键帽不抢焦点，点它时前台是输入框窗口，必须当成"自家窗口"才会退回跟踪到的目标窗口。
  · 位置由 `RunKeysAnchor()` 吸在运行框正下方；拖动 / 展开收起都跟随（`WM_MOVE`、`RunBoxApplyHeight`），发送目标随 `RunBoxTrackTarget()` 更新。
  · **键帽排的配置在 `[runbox.runkeys]` 子节**（用户要求放在 runbox 名下），**语义与 `[keypad.<kind>]` 完全一致**：`RunBoxLoadKeycaps()` 用 `IniRead(configFile, "runbox.runkeys", …)` 读 `name` / `cols` / `rows` / `square` / `case` 与编号项；写了编号就整体替换键帽（缺号 = 空位，越界忽略），一条都没写就沿用 `KeypadDefaultDefs()` 里的内置 7 键；**`cols` / `rows` 不写就用内置默认值，不做任何自动排布**。
    硬要求：只把写死的换成可配置（不自动排布、不塞进 `OverlayConfiguredItems()`），行为 / 效果完全不变。
    键帽定义由 `KeypadParseItem` / `KeypadRoleFor` 解析（`run:` / `self:` / `case` / `close` / `paste:` 都可用）。
  · 键帽排**自己**不进 `OverlayRects()`，与运行框合并成一个整体矩形参与避让（见 §6.3），严格保持"下方居中、间隔 6px"。
- **`RunBox*` 函数改完必须核对 `global` 声明**（2026-09-15 已犯两次，都是"新增全局变量后忘了把它加进某个函数的 global 行"）：
  漏写时那行赋值会变成**函数局部变量**，全局仍是空串 —— 表现为面板上永远看不到该更新（旧版曾以 `runboxDetail.Visible` 抛 `This value of type "String" has no property named "Visible"` 的形式炸出来）。
  自查办法（可重复跑）：把每个 `^RunBox[A-Za-z]*\(.*\) \{` 函数体抓出来，比对"函数体内出现的 `runbox*` 变量"与"该函数 global 行里声明的名字"，差集必须为空。
  2026-09-18 又踩一坑：**顶层函数名不能和全局变量重名**（AHK 大小写不敏感）——`RunBoxLayout()` 撞 `global runboxLayout`，加载期直接报 `This function declaration conflicts with an existing global variable`，已改名 `RunBoxComputeLayout()`（见 §4.1 #23）。
  同一天**又犯一次**：给运行框新增 `runboxLogGui / runboxLogEdit / runboxLogOffX / runboxLogOffY` 时忘了写进 `RunBoxShow` 的 global 行，四个名字全变成局部变量、全局仍是空串 —— 表现是"点开执行过程是一片空"（窗口既不显示也没灌内容）。**可重复跑的核对脚本**（比人眼可靠）：把文件按 `^函数名(参数) {` 切出每个 `RunBox*` 函数体，先抹掉字符串字面量、再抹掉所有已定义函数名（函数引用如 `SetTimer(RunBoxStep, 10)` 不算变量），剩下的 `runbox\w*` 必须全部出现在该函数的 `global` 行里，差集必须为空。
  同一轮还修了：`ControlGetPos` 等**输出参数失败时会被置回"未赋值"**，所以 `if (dh <= 0)` 这类比较会抛 `This local variable has not been assigned a value` —— 输出参数一律先 `IsSet()` 判断再比较。
- **执行完的焦点归属按"有没有打开新窗口"决定**（2026-09-16 用户明确）：`RunBoxExecute` 里先快照 `runboxExecBaseWin := runboxPrevWin`（在激活目标窗口之前），`RunBoxFinish` 收尾时取 `fg := WinExist("A")`：
  · `fg` 不是运行框自己、且 ≠ `runboxExecBaseWin` → 动作打开了新窗口 → **什么都不做**（不 `WinActivate` 回运行框，也不还给旧窗口）；
  · 否则（前台是运行框 / 无前台 / 还是执行前那个窗口）→ `RadialActivateFocusWin(runboxPrevWin)`；Esc 中止（`focusTarget := false`）或无可用目标才留在运行框。
  · "自己"一律用 `RunBoxIsSelfWin(hwnd)` 判（运行框主窗口 + `runkeys` 键帽排；读 `P.gui.Hwnd` 要包 `try`）：**运行框可以有焦点，但永远不算动作目标，也不算"要回退到的上一个窗口"**。
  · 坑：`keepNew` 为真时绝不能落进原来那个 `else`（会 `WinActivate` + `runboxEdit.Focus()` 抢回焦点）——结构必须是 `if (keepNew) {…} else { 还给目标窗口 / 退回运行框 }`。
  配套：触发键 `RunBoxShow` 在"窗口已打开"时——**只把焦点拿回来、永不关闭**（`WinActivate` + `runboxEdit.Focus()`），这样"执行完在目标窗口干活 → 按触发键回来下一条"才顺（2026-09-18 用户把触发键从"开/关切换"改成"只打开 / 聚焦"）。关闭运行框只有一条路：**在运行框上按 `Esc`**（Gui 的 Escape 事件 → `RunBoxEsc` → `RunBoxClose`）。
- **两种"取消"必须区分（2026-09-18 用户强调）**：在运行框上按 `Esc` = 对**当前窗口**（运行框自己）的取消 → 关闭运行框；键帽排 `runkeys` 的【取消】= 对**"除运行框之外最近活动的那个窗口"**的取消 → 把 `Esc` 发给该目标窗口，运行框照旧开着。**键帽排上的所有键**（回车 / Tab / 空格 / 删除 / 退格 / 取消 / 触发）都以"排除运行框之外的最近活动窗口"（`keypadPanels["runkeys"].focusWin` = `runboxPrevWin`）为作用对象，走 `OverlayActionExecute(..., "runkeys", focusWin)` → `OverlayPrepareInject` 先把前台切到目标窗口再发送，**绝不会打到运行框自己身上**（此机制改造前就有，用户只是强调）。
- **`Hotkey("Escape","Off")` 必须包 `try`**：未注册时抛 `Nonexistent hotkey`（`RunBoxEscOff` 漏过，2026-09-15 在"开了运行框但没执行动作就关闭"路径上复现并修掉；`OverlayUnregisterEscape` 早就包了 try）。
- **关闭窗口的竞态**：`RunBoxClose` 必须"先停跟踪定时器 → 清空全局引用 → 最后 `Destroy()`"，句柄读取一律走 `RunBoxHwnd()`（`try` 包住并失败返回 0）。原先顺序写反了，Esc 关闭时定时器插进来读 `.Hwnd`，抛 `Gui has no window`（用户实测崩溃，已修）。
- 底部把手**不再是控件**（2026-09-18）：把手文字画在文字层上，点击由 `RunBoxNcLButtonDown` 按 `runboxLayout.handle` 矩形做几何命中（文字层带 `WS_EX_TRANSPARENT`，点击穿透到面板）。展开 / 收起后重画并 `RunBoxFocusInput()` 把光标还给输入框。
- **运行框的拖动 = `WM_NCHITTEST(0x0084)` 给 `HTCAPTION` + `WM_NCLBUTTONDOWN(0x00A1)` 里自己拖**（2026-09-18 改）：`RunBoxHitTest` 对面板统一返回 `HTCAPTION(2)`；`RunBoxNcLButtonDown` 收到 `wParam=2` 时——落点在把手矩形内就展开 / 收起，否则**吞掉消息并启动自实现拖动**（面板是 `WS_EX_NOACTIVATE`，不能指望系统的 HTCAPTION 移动循环）。看 `RunBoxDragStart` / `RunBoxDragTick`：`SetCapture` + 20ms 定时器轮询 `GetCursorPos` 与 `GetAsyncKeyState`，位移夹取虚拟屏幕。单击（没拖动）时 `RunBoxDragEnd` 会主动 `RunBoxFocusInput()`：面板带 `WS_EX_NOACTIVATE`，点它本来不抢焦点，若不主动把光标还回去，"点一下运行框再按 `Esc` 关闭"就不成立（解析 / 执行中 busy 时绝不抢）。**不要**照抄思考窗口那套 `WM_LBUTTONDOWN(0x0201)`：0x0201 同一时刻只能挂一个回调，径向菜单 / 小键盘 / 思考窗口已经各自在抢，运行框再抢会把它们顶掉（2026-09-15 特意避开）。
- **执行过程最终是"独立的不透明只读 `Edit` 窗口"（2026-09-18 两轮改动后定稿）**：先做过"跟面板一起半透明、文字画在文字层"的版本，用户实测后明确要求"能选中、能 `Ctrl+C` 复制、能滚动翻阅"，于是改回独立窗口里的只读多行 `Edit`（与输入框同思路）。**由此带来的约定**：这块区域是实心深色、不参与 `[runbox] opacity`，所以主文字层**只需盖面板上半部分**（`RunBoxTextLayerPresent` 固定传 `hSmall`），状态行高频刷新时不必再为展开区做逐像素合成（`RunBoxTextsChanged` 的 250ms 节流仍然保留）。改动前请先想清楚："要可选中的文字"与"要跟面板一起半透明"这两条**在 Windows 上不可兼得**（`Edit` 文字由系统绘制，既加不了描边、也没法豁免父窗口的 alpha）。
- AHK v2 坑：字符串里的双引号**不能写 `""`**（那是 v1 写法），要用 `` `" `` 或单引号字符串；三连反引号（markdown 围栏）要用 `Chr(96)` 拼。2026-09-15 两处都踩过。

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
