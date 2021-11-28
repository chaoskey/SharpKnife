# ahklib - AutoHotkey效率脚本

> 效率脚本库，根据需要逐步添加

## 微软输入中英文切换辅助

> 微软拼音输入法中英文状态同步记录，为每一个活动过的窗口记录中英文状态， 据此进行中文切换

### 假设 或 前置要求

- 输入法采用微软拼音并且默认为英文, 配置 `Ctrl+Space` 进行中英文切换

- 建议本脚开机启动

- 管住手，禁止鼠标点击切换中英文 【除非提示和系统显示不一样】

### 启动

> 建议配置成开机启动

```powershell
git clone https://github.com/chaoskey/ahklib.git

# 需要安装AutoHotkey
autohotkey.exe im_switch.ahk
```

## 基于LaTeX的Unicode特殊字符触发

> 用处1【默认, latex助手模式】: 用于纯latex输入。 
>
> 用处2【unicode模式】: 代码中（比如: 注释，甚至变量）使用unicode特殊字符。
>  
> 也可以在任何文本框输入, 只要想的起正确的局部片段即可.
>
> 参考Katex:  https://katex.org/docs/supported.html

### 启动

> 建议配置成开机启动

```powershell
git clone https://github.com/chaoskey/ahklib.git

# 需要先安装AutoHotkey
autohotkey.exe latex2unicode.ahk
```

### 用法 

1）能想起字符片段，可以用`\[片断字符串][TAB]`，可能会弹出菜单，然后选择输入

2）如果没有替换说明输入错误或不支持

3）非TAB终止符触发（比如: `[Space][Enter][Esc]`等等），表示放弃触发, 并且保持已输入的原样

4）用`Win + \`  进行 unicode模式 / latex助手模式 切换  【会有1s后消失的提示】

5）建议设置本脚开机启动

6）注意: 启动后的第一次触发，需要加载数据，可能有1s的延迟。

![](images/ex1.png)

### 范例

只支持单字符的LaTeX触发（目前支持如下6类）

| 分类 | LaTeX | Unicode | 说明 |
| ---- | ---- | ---- | ---- |
| 1.下标 | _n[TAB] | ₙ | 下标触发 |
| 2.上标 | ^n[TAB] | ⁿ | 上标触发 |
| 3.单字符 | \alpha[TAB] | α | 单字符触发 |
| 4.字体 | \mathbbR[TAB]  | ℝ | 空心字符触发 |
| 4.字体 | \mathfrakR[TAB] | ℜ | Fraktur字符触发 |
| 4.字体 | \mathcalR[TAB] | 𝓡 | 花体字符触发 |
| 5.组合 | R\[组合字符][TAB] 比如R\hat[Tab] | R̂ | 组合字符触发 |
| 6.片段搜索 | \[片断字符串][TAB] | 可能弹出菜单 | 搜索字符触发 |

### unicode模式/latex助手模式

可用`Win + \`  进行 unicode模式 / latex助手模式 切换  【会有1s后消失的提示】

unicode模式:   输出的结果是unicode字符，比如 ⨁

latex助手模式: 如果输入正确的或完全不正确，没有任何反应； 如果输入的正确的片段（不完全正确），会弹出菜单，选择输入，比如: \bigoplus

### 组合字符触发

> 重音符  https://katex.org/docs/supported.html#accents

| LaTeX | Unicode |
| ---- | ---- |
| R\hat[Tab] | R̂ |
| R\dot[Tab] 或 R\\.[Tab] | Ṙ |
| R\ddot[Tab] 或 R\\"[Tab] | R̈ |
| R\tilde[Tab] 或 R\\~[Tab]  | R̃ |
| R\bar[Tab] | R̄ |
| R\mathring[Tab] 或 R\r[Tab] | Rͦ |
| R\acute[Tab] 或 R\\'[Tab] | Ŕ |
| R\breve[Tab] 或 R\u[Tab] | R̆ |
| R\check[Tab] 或 R\v[Tab] | Ř |
| R\grave[Tab] 或 R\\`[Tab] | R̀ |
| R\underbar[Tab] | R̲ |
| R\H[Tab] | R̋ |

### 搜索字符触发

> 按下\键，等候输入，然后tab，可能出现如下5种情况:

- \后如果输入少于2个字符，可能是前面5类情况之一， 直接触发

- 如果完全匹配，就是前面5类情况之一， 直接触发

- 如果不完全匹配，但只有唯一匹配， 直接触发 

- 如果不完全匹配，并且不唯一，弹出菜单选择触发 

- 如果不匹配，不做任何处理  

### 关于UTF-8的编码问题

由于本工具输出的是unicode编码，如果编码不对可能会有问题。

如果您遇到了编码问题，请看下图的解决方案。

![](images/ex2.png)

