# SharpKnife —— LaTeX / Unicode / AI / TikZ 四模式补全（AutoHotkey v2）

一个基于 AutoHotkey v2 的全局 **LaTeX 命令 / Unicode 符号** 快速补全工具。在任何文本编辑框中按下 `Ctrl+J`，即可把光标前刚输入的 LaTeX 键补全为完整的 LaTeX 命令、Unicode 字符或环境模板。默认情况下所有数据来自本地触发表 `latexs.cvs`，**不联网、不需要任何 API**（仅 AI 模式需要 API）。

---

## 1. 项目文件

| 文件 | 作用 |
|------|------|
| `SharpKnife.ahk` | 主脚本（启动它） |
| `latexs.cvs` | 触发表（数据源，Tab 分隔，最多 3 字段） |
| `config.ini` | 配置（快捷键、打字延迟、UI、AI 等） |
| `README.md` | 本文档 |
| `debug.log` | 调试日志（由 `config.ini` 的 `[debug] enabled` 控制，默认关闭不生成） |

---

## 2. 安装与启动

1. 安装 **AutoHotkey v2**（https://www.autohotkey.com/ ，必须是 v2，不是 v1），要求 Windows 10。
2. 双击 `SharpKnife.ahk`。托盘区出现图标即就绪，启动时会弹出中文提示（当前模式、补全/循环切换/直接切换/模式列表快捷键）。
3. 修改 `config.ini` 后，右键托盘图标 → `重新加载(&R)` 生效。
4. 如需使用 **tikz 模式**（把 TikZ 代码渲染为图片），还需安装：**MiKTeX**（或其他 TeX 发行版）+ **Ghostscript** + **Snipaste**（https://www.snipaste.com/ ，贴图展示依赖，需保持后台运行）。

---

## 3. 整体逻辑

```
触发命令  →  上下文选择（空上下文 / 非法上下文 → 直接返回，无操作）
          →  上下文匹配（没有匹配上 → 直接返回，无操作）
          →  动作触发（用户取消 → 直接返回，无操作）

切换命令  →  模式切换（latex（默认）→ unicode → AI → tikz → latex 循环）

直接切换命令  →  模式切换（直接切换到指定模式：0=latex，1=unicode，2=AI，3=tikz）

触发模式列表  →  弹出无边框列表  →  上下键移动选择  →  模式切换（直接切换到指定模式）

步进执行命令  →  play 模式：关闭状态（未绑定脚本）弹出脚本文件选择窗口并绑定，
                 且立即执行第 1 个动作；开启状态（已绑定脚本）执行脚本下一步
```

---

## 4. 快捷键（均可通过 config.ini 修改）

| 命令 | 默认 | 配置项 |
|------|------|--------|
| 触发命令 | `Ctrl+J` | `[trigger] hotkey` |
| 循环切换命令 | `Ctrl+Shift+J` | `[trigger] toggle_hotkey` |
| 直接切换命令 | `Ctrl+Shift+0`（latex）/ `Ctrl+Shift+1`（unicode）/ `Ctrl+Shift+2`（AI）/ `Ctrl+Shift+3`（tikz） | `[trigger] direct_prefix`（前缀） |
| 触发模式列表 | `Ctrl+Shift+\`（弹出无框列表，上下键选择模式后 Enter 切换） | `[trigger] mode_list_hotkey` |
| 步进执行命令 | `Ctrl+R`（play 模式专属，无论处于哪个状态都有效） | `[trigger] step_hotkey` |

### 模式切换

- **latex 模式**（默认）：把上下文补全为 LaTeX 命令 / 环境模板。
- **unicode 模式**：把上下文替换为对应的 Unicode 字符。
- **AI 模式**：把 AI 生成的结果追加到上下文之后（两个内容之间隔一行）；思考模式（`[ai] thinking=enabled`）且流式请求（`[ai] stream=true`）下，会弹出一个无边框窗口**实时**滚动呈现思考过程，思考完毕后自动离开（窗口保留，可随时通过任务栏回到窗口按 Esc 关闭），随后才输出正式结果（默认非流式，不弹思考窗口）。思考窗口**可拖动**（按住空白处拖动，移到不遮挡编辑区的位置）；思考过程中置顶，思考完毕离开后**不再置顶**——焦点回到编辑器时窗口被编辑器盖住（不可见但仍存在）。
- **tikz 模式**：把选中的 TikZ 绘图代码自动编译渲染为图片，并复制到剪贴板、通过 **Snipaste 贴图**展示（Snipaste 自带拖动 / 缩放 / 编辑 / 标注能力）。
- 循环切换命令在四个模式之间**循环切换**（latex → unicode → AI → tikz → latex）；直接切换命令可**一步直达**指定模式（`Ctrl+Shift+0/1/2/3`）；触发模式列表命令弹出**无框列表**（`latex 模式（0）` / `unicode 模式（1）` / `AI 模式（2）` / `tikz 模式（3）`），通过**上下键移动选择**、回车切换到指定模式（Esc 取消则无操作）。托盘菜单也可直接选择模式（`latex 模式` / `unicode 模式` / `AI 模式` / `tikz 模式`）。
- **play 模式**：**独立模式**，不与上述四种互斥模式共用切换命令；可与当前生效的互斥模式**并存**，拥有独立的 *步进执行命令*（`Ctrl+R`）。play 模式没有独立的开启/关闭操作，其状态由**是否绑定脚本文件**自然决定——已绑定脚本文件即处于开启状态，脚本执行完毕后自动解绑回到关闭状态。脚本格式与步进语义详见下文「play 脚本格式」。

---

## 5. 上下文选择

**优先使用触发前人工选择的内容**作为上下文（选区优先）；否则取**文字光标前的非空连续字符串**（即光标前紧邻的一段不含空格 / Tab 的连续文本）。

- 上下文为空（光标前是空白或行首）→ 直接返回，无操作。

### 合法上下文（latex / unicode 模式）

`<前缀><待匹配字符串>`：

- `<前缀>` ∈ { `_` , `^` , `_\` , `^\` , `\` }（按最长优先匹配）
- `<待匹配字符串>`：**非空**，由 **英文字母 / 数字 / 除 `_ ^ \` 之外的符号** 组成，**区分大小写**
- **非法上下文**（不以合法前缀开头、或只有前缀无内容、或待匹配字符串含 `_` `^` `\`）→ 直接返回，无操作

AI 模式和 tikz 模式**不存在上下文匹配**：任何非空上下文都合法——AI 模式直接作为 AI 提示语；tikz 模式把选中内容作为 TikZ 绘图代码（优先使用选区，否则取光标前连续字符串）。

play 模式**不参与上下文选择与上下文匹配**（步进执行完全依赖自定义格式脚本，与文本上下文无关）。

---

## 6. 上下文匹配（基于 latexs.cvs，仅 latex / unicode 模式）

### 触发表格式

`latexs.cvs` 每行用 **Tab** 分隔，最多 3 个字段；以 `;` 开头或空行为注释：

- 第 1 字段：LaTeX 键（如 `\alpha`、`_0`）
- 第 2 字段：Unicode 或文字描述（以 `:` 开头 = 仅 unicode 模式）
- 第 3 字段（可选）：LaTeX 块模板（如 `{Text}\begin{array}...##{Left 25}`）

### 模式过滤

- **unicode 模式**：第 2 字段中间不能含空格（含空格的条目被排除）
- **latex 模式**：第 2 字段不能以 `:` 开头（以 `:` 开头的条目被排除）

### 匹配模式

`<前缀>*<待匹配字符串>*`，其中 `*` 代表**非空的英文字母 / 数字 / 非 `_ ^ \` 的符号**组成的**区分大小写**的字符串，**或空字符串**。

### 四种匹配类型

| 类型 | 含义 | 条件 |
|------|------|------|
| `=` 精确匹配 | 两个 `*` 都是空字符串 | L 空 且 R 空 |
| `<` 头对齐匹配 | 第一个 `*` 空，第二个 `*` 非空 | L 空 且 R 非空 |
| `>` 尾对齐匹配 | 第一个 `*` 非空，第二个 `*` 空 | L 非空 且 R 空 |
| `~` 中间匹配 | 两个 `*` 都非空 | L 非空 且 R 非空 |

### 匹配结果

- **只匹配出 1 项** → 直接动作触发
- **匹配出 2 项及以上** → 弹出**无框列表**：
  - 最多显示 10 项，通过上下键移动可滚动查看所有匹配项
  - 回车选择要触发的项 → 动作触发
  - 按 Esc（取消键）取消 → 无操作
  - 列表项格式：`<匹配类型> <第1字段> <第2字段>`（第 2 字段剔除 `:` 前缀）
  - 列表字体大小由 `config.ini → [ui] font_size` 控制（默认 15）

---

## 7. 动作触发

### 动作触发（latex / unicode：先删除上下文，再插入替换文本；AI：追加到上下文之后）

- **latex 模式 · 2 字段**：删除上下文（选区整体删除；光标前上下文先选中再删除），用第 1 字段替换上下文，并在**尾部追加一个空格**
- **latex 模式 · 3 字段**：删除上下文，用第 3 字段解析后的模板替换上下文，并将**光标左移指定格数**（`##{Left N}`）
- **unicode 模式**：删除上下文，用第 2 字段（剔除 `:` 前缀）替换上下文，并在**尾部追加一个空格**
- **AI 模式**：上下文保持不变，把 AI 生成的结果追加到上下文之后——两个内容之间**隔一行**（即一个空行）。思考模式（`[ai] thinking=enabled`）且流式请求（`[ai] stream=true`）下，弹出无边框窗口**实时**滚动呈现思考过程，思考完毕后自动离开（窗口保留，可随时通过任务栏回到窗口按 Esc 关闭），随后才输出正式结果（默认非流式，不弹思考窗口）。思考窗口**可拖动**（按住空白处拖动）；思考过程中置顶，思考完毕离开后**不再置顶**——焦点回到编辑器时窗口被编辑器盖住（不可见但仍存在）
- **tikz 模式**：把上下文作为 TikZ 绘图代码 → 自动包装为完整 LaTeX 文档 → `pdflatex` 编译 → 转 PNG → 复制到剪贴板并通过 **Snipaste 贴图**展示（未运行 Snipaste 时自动启动）。编译失败显示 `main.log` 错误行；超时自动终止并提示。触发时记录调试日志（`[debug] enabled=true` 时）
- **play 模式**：根据**自定义格式脚本**步进式执行，与上述互斥模式并存、状态由是否绑定脚本文件决定。关闭状态下触发 *步进执行命令* 弹出**系统文件选择框**（`FileSelect`，过滤 `*.json`，初始目录 = 脚本所在目录），选定后绑定进入开启状态并**立即执行第 1 个动作**；取消选择则不绑定、无动作。开启状态下触发则执行脚本**下一步**（已有动作执行中则本次无动作）。脚本执行完最后一步自动解绑回到关闭状态；脚本加载失败（JSON 无法解析或结构/字段非法）→ 弹错误提示、不绑定；动作执行失败 → 记日志 / 提示后**跳过该动作**继续前进，不中断脚本。

### play 脚本格式

play 模式的脚本是一个 **UTF-8 编码的 JSON 文件**（扩展名 `.json`，由 *步进执行命令* 弹出的文件选择框指定，只允许选择 `.json`）。脚本内相对路径一律以**脚本文件所在目录**为基准解析。

- **根**是一个动作数组（相当于一个 `seq`），表示「依次启动」的一串步骤。
- 每个动作是一个 JSON 对象，用 `type` 区分 6 类动作：`text` / `paste` / `audio` / `video` / `seq` / `par`；可携带可选 `note`（注释，仅人工阅读，执行时忽略）；未定义字段一律忽略。
- **校验**（加载阶段一次完成）：结构非法（根非数组、缺必填字段、字段类型错误、`type` 未知、`pos` / `size` 非 `[x, y]` 数字对、时间格式非法）→ 整体拒绝、不绑定；数值越界（`opacity` 超 0~100、`volume` 为负）→ 截断到最近边界，不视为非法。

六类动作：

| type | 说明 | 必填 / 可选字段 |
|------|------|----------------|
| `text` | 文本输入 | `value`（字符串或字符串数组）；`{...}` 按 AHK 键名解释（如 `{ENTER}`、`{BS 9}`），其余字符（含 `+` `!` `#` `^` `%`）一律字面输出，字面 `{` / `}` 用 `` ` `` 前缀转义；`delay`（可选，毫秒，字符输出间隔）；`{Delay N}` 文本内段级延迟记号 |
| `paste` | 贴图 | `path`；`pos` `[x, y]`（缺省居中；负值居中语义：`x<0`=水平居中、`y<0`=竖直居中、双负=双居中）、`size` `[w, h]`（缺省原尺寸，拉伸到精确尺寸不保比例）、`opacity` 0~100（缺省 100）、`delay`（可选毫秒，缺省 0 = 立即贴图；> 0 = 延时 `delay` 毫秒后贴图）、`ttl`（可选毫秒，缺省 0 = 不自动销毁；> 0 = 实际贴图后经 `ttl` 毫秒自动销毁该贴图）、`wait`（可选布尔，缺省 false；仅 `delay>0` 或 `ttl>0` 时有意义，true = 等待贴图窗口关闭后才继续）、`pin`（可选布尔，缺省 false；置顶守护——该贴图存活期间始终保持在**实际贴图时已存在的全部贴图**之上，被点击置前的旧贴图会被守护盖回，详见 Requirements.md 8.1） |
| `audio` | 播音频 | `path`；`start` / `end`（`HH:MM:SS`、`MM:SS` 或秒数，缺省 0 / 播完）、`volume`（缺省 1.0，负值截断为 0）、`wait`（缺省 false） |
| `video` | 播视频 | `path`；`pos` / `size`（窗口位置尺寸，画面在窗口内等比缩放；`pos` 负值居中语义同 `paste`）、`opacity`、`start` / `end` / `volume`、`wait` |
| `seq` | 顺序嵌套 | `actions`（子动作数组）；`step`（缺省 true = 单步，false = 一次性依次执行完） |
| `par` | 并行嵌套 | `actions`（子动作数组）；并行启动全部子动作，全部完成后才算完成 |

- `audio` / `video` 是否阻塞步进仅由 `wait` 决定：`false` 启动即完成（后台继续播），`true` 非阻塞等待播放结束（期间占用执行中标记）。
- **继承规则**：一次性 `seq` 或 `par` 的所有嵌套子 `seq`（任意深度）都强制一次性，忽略其 `step`。
- **步进语义**：绑定即执行第 1 个动作（顶层数组为空则绑定后立即自动解绑）；每次步进命令推进一个动作，执行中标记为真时本次无动作；顶层游标越过末尾即执行完毕、自动解绑。`seq` 单步（`step=true`）只启动第 1 个子动作并压入内部游标，子动作全部完成才弹出并前移顶层游标。
- **失败处理**：动作执行失败（文件不存在、ffplay / Snipaste 未安装等）→ 记日志 / 提示后跳过该动作继续前进，不中断脚本（`seq` / `par` 的子动作同理）。

**text 动作的`delay` 与 `{Delay N}`（自造扩展，控制打字速度）：**

- **`delay`**（可选，毫秒，缺省 0=即时）：整条 text 动作的字符输出间隔；每发一个字符（或按键动作）后等待 `delay` 毫秒；负值截断为 0。
- **`{Delay N}`**（文本内记号，非官方）：在 `value` 中插入后，**之后所有内容**（字符与按键）按 `N` 毫秒间隔输出，直到下一个 `{Delay M}` 切换；记号本身不输出。`delay` 字段为整串初始间隔，`{Delay N}` 运行时覆盖/切换。
- 典型：数组内让某行慢速——在该行行首放 `{Delay 100}`；同段内前即时后慢，用 `"{Delay 0}前半{Delay 100}后半"`。

示例：

```json
[
  { "type": "text", "value": "大家好，欢迎来到演示{ENTER}" },
  { "type": "paste", "path": "images/title.png", "pos": [100, 100], "size": [600, 200] },
  { "type": "seq", "step": false, "actions": [
      { "type": "audio", "path": "audio/ding.mp3", "wait": true },
      { "type": "text", "value": "（提示音结束）开始讲解" }
  ] },
  { "type": "par", "actions": [
      { "type": "audio", "path": "audio/bgm.mp3", "volume": 0.5 },
      { "type": "video", "path": "video/demo.mp4", "pos": [400, 200], "size": [800, 450] }
  ] }
]
```

### 3 字段模板解析

`{Text}...##{Left N}`：

- 剔除前缀 `{Text}`
- 剔除后缀 `##{Left N}`，解析出数字 `N`，触发后光标左移 `N` 格

### AI 模式对返回结果的规范性要求（默认提示语已满足，可配置）

1. 默认必须是完整的 LaTeX 片段或范例（可合法渲染成数学公式或符号）；
2. 若上下文提示语中有特别要求，结果也可以是 Unicode 符号或由 Unicode 符号组成的公式；
3. 若上下文提示语要求输出 Markdown 格式，行内公式用一对 `$` 包围、行间公式用一对 `$$` 包围（`$$` 独占一行），不使用 Markdown 代码块围栏；
4. 若上下文提示语要求输出绘图代码：若输出包含 `\begin{document}`，必须使用 standalone 文档类；若是 3D 绘图输出，优先采用 `tikz-3dplot` 宏包，具体根据上下文提示语涉及的任务，也可以改用 `pgfplots` 或纯 TikZ 的 `3d` 库；
5. 若满足要求的结果有 2 种或多种可能，返回全部候选的 JSON 数组，客户端弹出无框列表供选择（与本地多匹配列表行为一致）。

---

## 8. 配置说明（config.ini）

```ini
[trigger]
hotkey = ^j            ; 触发命令（^=Ctrl, !=Alt, +=Shift, #=Win）
toggle_hotkey = ^+j    ; 循环切换命令
direct_prefix = ^+     ; 直接切换命令的前缀（前缀+0/1/2/3：0=latex，1=unicode，2=AI，3=tikz）
mode_list_hotkey = ^+\ ; 触发模式列表（弹出无框列表，上下键选择模式）
step_hotkey = ^r      ; 步进执行命令（play 模式专属，无论处于哪个状态都有效）

[context]
type_delay_ms = 3      ; 每插入一个字符的延迟（毫秒）

[ui]
show_progress = true   ; 是否显示进度提示（AI 请求期间）
progress_text = 正在生成...   ; 进度提示文字
font_size = 15         ; 多选列表字体大小（磅，最小 6）
max_typing_chars = 2000 ; 单次插入最大字符数（超出截断并提示，Ctrl+Z 可撤销）

[ai]                   ; —— 仅对 AI 模式有效 ——
api_key = ...          ; DeepSeek API 密钥（必填，AI 模式才能工作）
base_url = https://opencode.ai/zen/go/v1   ; API 地址
endpoint = /chat/completions               ; 接口路径
api_style = chat       ; chat=聊天补全接口（默认）；completion=原生补全接口（若服务支持可切换）
model = deepseek-v4-flash                  ; 默认采用官方 Deepseek v4 flash 模型
temperature = 0.3      ; 采样温度（0~2）
max_tokens = 4096      ; 生成的最大 token 数
thinking = enabled     ; 是否启用思考（enabled / disabled / 留空不发送）
reasoning_effort = low ; 推理强度（low / medium / high / 留空不发送）
stream = false         ; 是否流式请求（true=边接收边输出，思考模式下实时滚动呈现思考过程；false=非流式默认）
timeout_ms = 30000     ; 请求超时（毫秒）
system_prompt = ...    ; 约束提示语（可选；不填则使用内置默认，已满足规范性要求）

[tikz]                  ; —— 仅对 tikz 模式有效 ——
pdflatex_path =         ; pdflatex 路径（留空自动探测 PATH 中的 pdflatex.exe）
converter = auto        ; PDF 转 PNG 工具：auto=自动探测（pdftoppm / mutool / gswin64c / magick 任一可用者）
dpi = 150               ; 输出 PNG 分辨率（像素/英寸）
border = 5pt            ; standalone 文档四周留白
extra_packages =        ; 额外宏包（逗号分隔，自动注入导言区 \usepackage{...}）
timeout_ms = 30000      ; 编译超时（毫秒，超时自动终止进程）
snipaste_path =         ; Snipaste 路径（留空自动探测 PATH / 常见安装路径；贴图功能依赖 Snipaste 已安装并运行）
```

> 注：`config.ini` 为 UTF-16 LE + BOM 编码（AutoHotkey `IniRead` 原生支持），如需手工修改请用支持该编码的编辑器。

---

## 9. 实现要点（供复现）

- `cvsEntries`：启动时读取 `latexs.cvs` 得到条目数组 `{key, f2, f3, hasF3}`；`hasF3` 表示是否为 3 列条目；模式过滤在触发时进行
- `GetContext()` / `GetContextAI()`：上下文选择（选区优先 + 光标前连续串），返回 `{text, fromSelection}`
- `GetContextInfo(context)`：解析合法上下文，返回 `{prefix, search}`；非法返回 0
- `IsValidStar(s)`：`*` 通配符校验（空串，或仅含英文字母 / 数字 / 非 `_ ^ \` 符号）
- `FindMatches(info)`：按当前模式过滤后，按 `<前缀>*<S>*` 匹配，返回 `{key, f2, f3, hasF3, type}` 数组；排序 `=` > `>` > `<` > `~`，同类型按键长升序
- `ProcessLatexTemplate(f3)`：解析 `{Text}` 与 `##{Left N}`
- `ShowMultiSelection()` / `ShowList()`：无框列表（深色背景、最多 10 行、上下键滚动、Esc 取消、Enter 选择）
- `GetCaretScreenPos()`：多层级获取光标屏幕坐标（AHK 原生 → GetGUIThreadInfo → EM_POSFROMCHAR → UIA → 鼠标位置）
- `AIRequest()`：非流式 WinHttp 请求，响应体按 UTF-8 字节解码（避免中文乱码）；chat / completion 两种风格；`thinking` / `reasoning_effort` 附加参数；返回 `result`（最终补全文本）与 `reasoning`（思考过程）；推理型模型 `content` 为空时回退读取 `reasoning_content`
- `AIRequestStream()`：流式请求（`[ai] stream=true`，仅 chat 风格）——用 `curl.exe -N` 发起、`stream=true` 请求体，响应写临时文件并用 `SetTimer` 轮询增量解析 SSE（`data:` 行）；`delta.content` 累积为 `result`，`delta.reasoning_content` / `delta.reasoning` 实时追加到思考窗口；`StreamProcessFile()` 按字节偏移 + 完整行边界读取，规避 UTF-8 半字符 / 半行截断
- `ShowThinkingWindow()` / `AppendThinkingText()` / `ThinkingWindowDrag()` / `LeaveThinkingWindow()` / `CloseThinkingWindow()`：思考模式下弹出无框窗口（进任务栏，标题“AI 思考过程”，便于随时回到），`AppendThinkingText()` 把思考增量实时追加并滚动到底（`WM_VSCROLL` + `SB_BOTTOM`）；`ThinkingWindowDrag()` 在按住窗口空白处（Edit 之外）时发送 `WM_NCLBUTTONDOWN` + `HTCAPTION` 让系统接管拖动，使无边框窗口**可拖动**；思考完毕后 `LeaveThinkingWindow()` 先**取消置顶**（`WinSetAlwaysOnTop 0`）再自动离开（窗口保留、焦点还给原编辑器继续输出正式结果，窗口被编辑器盖住；用户可点击窗口按 Esc 触发 `CloseThinkingWindow()` 关闭）。窗口以 `Show("NA")` 显示，不抢焦点，避免插入结果按键发错窗口
- 文本插入使用 `SendText` 逐字符（受 `type_delay_ms` 控制），避免 `^` `{` `+` 等被解释为修饰键
- 触发 / 循环切换 / 直接切换 / 模式列表热键均通过 config.ini 配置，启动时注册（`Hotkey` 指令）；直接切换为 `direct_prefix` + 数字 0/1/2/3；模式列表复用 `ShowList()` 无框列表（`ShowModeList()`），选择后调用 `SetModeDirect()` 直达对应模式
- `StepPlay()`：play 模式专属的步进执行命令（默认 `Ctrl+R`）——`playScriptFile` 为空（关闭状态）时用 `FileSelect()` 弹出脚本文件选择窗口（过滤 `*.json`）并绑定脚本进入开启状态、立即执行第 1 步；非空（开启状态）且无动作执行中时执行下一步（`PlayRunStepFrame()`）
- play 脚本引擎：`PlayBind()` / `PlayUnbind()` 绑定与解绑；`PlayRunStepFrame()` / `PlayAdvanceStepFrame()` / `PlayPopStepFrame()` / `PlayPushSeqFrame()` 维护**步进游标栈**（栈底顶层游标 + 单步 `seq` 的内部游标）与**执行中标记** `playBusy`；`PlayIsOneShot()` 判定一次性 `seq`（继承规则：一次性 `seq` / `par` 的嵌套子 `seq` 强制一次性）；`PlayDispatchStepAction()` / `PlayExecTree()` / `PlayExecList()` / `PlayExecAll()` / `PlayParChildDone()` 派发并驱动 6 类动作
- play 动作实现：`PlayDoText()` / `PlaySendText()` / `PlayFlushLiteral()`（`{KEY}` 键名按 `Send` 发送、`` ` `` 转义字面 `{`/`}`、`\n`/`\r` 换行、其余字符含修饰符 `+!#^%` 走 `SendText` 字面输出）；`PlayDoPaste()`（入口：`delay > 0` 时用一次性定时器延迟 `delay` 毫秒后调 `PlayDoPasteNow()` 执行实际贴图）→ `PlayDoPasteNow()`（GDI+ 按 `size` 缩放 PNG → 复制到剪贴板 → Snipaste 贴图 → 移到 `pos` → `WinSetTransparent` 设透明度；`ttl > 0` 时用定时器在 `ttl` 毫秒后自动销毁贴图窗口——激活该窗口发送 `Esc`（Snipaste 官方销毁）并恢复焦点，极端情况补发关闭消息，缺省 0 不自动销毁由用户自主销毁；`wait` 仅在 `delay>0` 或 `ttl>0` 时有意义，`true` 时经 `PlayWatchPaster()` / `PlayPasterPoll()` 轮询等贴图窗口关闭后才完成动作）；`PlayStartMedia()` / `PlayWaitSdlWindow()` / `PlayWatchMedia()` / `PlayMediaPoll()`（ffplay `-nodisp`/`-left`/`-top`/`-x`/`-y`/`-ss`/`-t`/`-af volume=...`，`pos` 含负值时 `-left`/`-top` 不传、启动后用 `WinMove` 做居中修正——负值语义同 paste，`wait=true` 时非阻塞轮询进程退出 / 窗口关闭判定完成）
- play 解析与校验：`PlayLoadScript()` 及 `PlaySkipWs()` / `PlayParseValue()` / `PlayParseObject()` / `PlayParseArray()` / `PlayParseString()` / `PlayHexToInt()` / `PlayParseNumber()` 实现内置 JSON 解析；`PlayValidateAction()` / `PlayValidateText()` / `PlayValidatePaste()` / `PlayValidateMedia()` / `PlayValidateSeq()` / `PlayValidatePar()` / `PlayIsXY()` / `PlayIsNumber()` / `PlayIsBool()` / `PlayValidateTime()` / `PlayTimeToSeconds()` 加载阶段整体校验（结构非法整体拒绝；`opacity` / `volume` 越界截断）；`PlayResolvePath()` 以脚本所在目录解析相对路径
- play 贴图辅助：`GdipEnsure()`（GDI+ 全局初始化一次，进程退出由系统释放、不调用 Shutdown）/ `PlayScalePng()` / `PlaySavePng()` / `PlayGetPngEncoderClsid()` / `PlayLoadHbitmap()` / `PlayCopyPngToClipboard()` / `PlayPasterHwnds()` / `PlayPasterEnumHwnds()` / `PlayNewPaster()`（枚举 Snipaste 贴图窗口以定位新贴图）；`PlayPinPaster()` / `PlayPinPoll()` / `PlayBelowAbovePinned()` / `PlayRaiseTop()`（paste `pin` 置顶守护：贴图成功后登记该贴图与"贴图时已存在的贴图集合"，约 100ms 沿 Z 序链检查被压住窗口是否跑到上方，是则 `WinMoveTop` 提回最前，贴图销毁自动解除）；`PlayShowError()` / `PlayNoteFail()` / `PlayNum()` 错误提示与失败记录
- `CompleteTikz()`：tikz 模式主流程——建临时目录 → `WrapTikzDocument()` 包装（裸语句 / 含 `tikzpicture` / 含 `document` 三形态自动识别，`\usepackage` / `\usetikzlibrary` / `\tikzset` / `\pgfplotsset` 开头行自动提取到导言区）→ `CompileTikz()`（`Run` + `ProcessExist` 轮询实现超时保护——`ProcessWaitClose` 对已退出进程会假超时、不能用；失败读 `main.log` 错误行）→ `ConvertPdfToPng()`（按配置顺序尝试 pdftoppm / mutool / gswin64c / magick）→ `PasteTikzImage()` 把图片复制到剪贴板（PNG + CF_DIB 双格式）并通过 Snipaste 贴图展示；`FindSnipaste()` 自动探测 Snipaste 路径（配置 → PATH → 常见安装路径），未运行时自动启动并等待就绪；`TikzCopyPng()` 复制图片到剪贴板（`HbmToDib()` 生成 CF_DIB）；贴图成功后延迟 8 秒清理临时目录
- 调试日志由 `config.ini` 的 `[debug] enabled` 开关控制（默认 `false` 不输出）；设为 `true` 时写入 `debug.log`，启动时清空旧日志

---

## 10. 目录结构

```
SharpKnife/
    SharpKnife.ahk   ← 主脚本（启动它）
    latexs.cvs       ← 触发表（数据源）
    config.ini       ← 配置
    README.md        ← 本文档
    debug.log        ← 调试日志（由 [debug] enabled 控制，默认关闭不生成）
    images/          ← 托盘图标
```

---

## 许可

个人使用。