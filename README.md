# ahklib - AutoHotkey效率脚本

> 效率脚本库，根据需要逐步添加

## 微软输入中英文切换辅助

> 微软拼音输入法中英文状态同步记录，为每一个活动过的窗口记录中英文状态， 据此进行中文切换

**假设 或 前置要求**：

- 输入法采用微软拼音并且默认为英文

- 建议本脚开机启动

- 管住手，禁止鼠标点击切换中英文

**启动**:  【建议配置成开机启动】

`autohotkey.exe im_switch.ahk` 或 `autohotkey.exe main.ahk`(包括本项目所有脚本)

## 基于LaTex的Unicode特殊字符触发

> 参考Katex，尽可能使用latex触发出对应的unicode字符，适用于任何文本框，只支持字符逐个输入。
>
> https://katex.org/docs/supported.html

**假设 或 前置要求**：

- 使用者熟练使用LaTex语法

- 建议本脚开机启动

**启动**:  【建议配置成开机启动】

`autohotkey.exe latex2unicode.ahk` 或 `autohotkey.exe main.ahk`(包括本项目所有脚本)

**用法**: 只对不方便键盘输入的字符进行latex[TAB]替换， 如果没有替换说明输入错误或不支持

**范例**: 只支持单字符的latex触发（目前支持如下7类）

| latex | unicode | 说明 |
| ---- | ---- | ---- |
| _n[TAB] | ₙ | 下标触发 |
| ^n[TAB] | ⁿ | 上标触发 |
| \alpha[TAB] | α | 单字符触发 |
| \mathbbR[TAB]  | ℝ | 空心字符触发 |
| \mathfrakR[TAB] | ℜ | Fraktur字符触发 |
| \mathcalR[TAB] | 𝓡 | 花体字符触发 |
| \hatR[TAB] | R̂ | 戴帽字符触发 |


