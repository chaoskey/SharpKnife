# AGENTS.md —— 给 AI 协作者的长期约定

> **本文件的作用**：把本项目开发中形成的**约定、习惯、风格与踩过的坑**固化下来。
> 即使历史会话被删除、或换到全新会话/新模型，只要读本文件，就应当能**按同样的方式接续开发**，不必重新摸索、也不该重复犯同样的错误。
>
> 最后更新：2026-09-11

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
| 9 | `FileDelete` 对**不存在的文件会抛异常** | 包 `try { FileDelete(f) } catch { }` |
| 10 | `IniWrite` 新建文件是 **UTF-16 LE + BOM**，且**会保留已有注释**；中文节名/键名可用 | 直接用它读写统计类文件即可 |
| 11 | INI **键名不能含 `=`**（会被当键值分隔符） | 转义为 `%3D` 后再读写 |
| 12 | 自己解析 INI 时**必须剥离行内注释**，否则 `key = 15  ; 注释` 的值校验失败被静默忽略 | 用 `RegExMatch(line, "\s;", &m)` 截断（用"空白+分号"，避免误伤 `{;}` 这类紧贴分号） |
| 13 | **全局变量声明必须早于配置加载调用**，否则 `global x := …` 会把已加载的数据覆盖掉 | 本项目的 `RadialLoadConfig()` 调用就在 radial 全局变量声明**之后**（曾因此排查很久） |
| 14 | 脚本中部的 `FileDelete(debug.log)` 会**清掉此前写入的日志** | 不要依赖该时间点之前的日志；必要时把诊断写在清空之后 |

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

### 4.4 其它

- `CreateFontW` 的 `escapement` 单位是 **0.1 度**；旋转文字用 `TextOutW`（`DrawText` 不支持旋转）。
- 本机 Windows 缩放/多显示器等环境细节未知时，优先用**相对计算**（如以鼠标为圆心、按屏幕夹取），避免硬编码坐标。

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
try { FileDelete(logf) } catch { }
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

### 6.2 径向菜单（Radial Menu）—— 最近改动最多的模块

**三层结构**（外观形式固定：圆形窗口 + 单环扇区 + 放射性文字，仅流程/内容可变）：

1. **第一层【常用】**：圆心 `常用`；周边第 1 个固定 `快捷菜单`，其后为**按统计排出的高频项**（个数 = `[radial] common_max`）。
   点常用项 → 执行快捷键并关闭；点圆心 → 关闭。
2. **第二层【快捷菜单】**：圆心 `快捷菜单`；周边为**分组名**。点分组 → 第三层；点圆心 → 返回第一层。
3. **第三层【<组名>】**：圆心 = 组名；周边为该组**菜单项**。点菜单项 → 执行快捷键并关闭；点圆心 → 返回第二层。

**每层周边至少 4 个扇区**，不足补空位（无文字、禁止高亮、点击无效）。

关键函数：

| 函数 | 职责 |
|------|------|
| `RadialLoadConfig()` | 逐行解析 `[radial]` 段（自定义解析，非 `IniRead`），保证组/项顺序 |
| `RadialComputeLayout()` | 紧凑自适应半径：①圆心文字内接 ②内圈弧长够字高 ③环宽够最长文字 |
| `RadialBuildMenu()` | 按 `radialLevel` 构建当前层内容 + 补空位 + 建立 GUI/区域/消息钩子 |
| `RadialBuildRgns()` / `RadialFreeRgns()` | 扇区多边形区域与圆心区域的建立/释放（绘制与命中共用） |
| `RadialDraw()` | GDI 双缓冲绘制（三态着色：常态/高亮/变暗；放射性文字） |
| `RadialHitTest()` | `PtInRegion` 命中；**空位扇区返回 0（不命中）** |
| `RadialOnItemClick()` | 按 `kind` 分发：`shortcut`/`group`/`exec`/`disabled` |
| `RadialOnCenterClick()` | 三层中心语义（关闭 / 返回上一层） |
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

### 6.3 已知的历史遗留（可清理，非必须）

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
