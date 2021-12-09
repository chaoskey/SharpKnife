# Ctrl功能增强

> 本工具是[SharpKnife(利刃)](../README.md)效率工具库的成员

![](../images/CtrlRich.jpg)


## 启动

> 建议配置成开机启动

```powershell
git clone https://github.com/chaoskey/SharpKnife.git
# 需要先安装AutoHotkey
autohotkey.exe CtrlRich.ahk

# 或者  下载 https://github.com/chaoskey/SharpKnife/releases
CtrlRich.exe
```

## 基本说明

所有“Ctrl+单字符”Ctrl松开后的命令的系统功能不变。

所有“Ctrl+多字符”命令都当成增强命令，已定制的命令有动作，否则无动作。

在Ctrl按下后，单字符”或“多字符”的每个字符都要求快速单击，否则一个字符可能会出现多个重复字符。

【控制命令】Ctrl松开前可能执行的命令，所有的控制命令都可反复敲击
【功能命令】Ctrl松开后可能执行的命令。

从基本的Ctrl-X-C-V的"剪切-复制-粘贴"命令开始增强。

## 增加 “剪切板历史记录-浏览-删除” 的功能

> 相关命令都是基于Ctrl-V增强的“控制命令”，Ctrl松开前执行。

- Ctrl-VA 删除所有剪切板历史记录（特别标记的除外）

- Ctrl-VS 浏览下一条历史记录

- Ctrl-VD 删除当前历史记录（包括特别标记的）

- Ctrl-VF 浏览上一条历史记录

## 增加“剪切板历史记录的搜索-标记”功能

> 这是一个“功能命令”，Ctrl松开后执行。

- 敲击Ctrl+SS触发等候输入“搜索关键词”然后敲击Tab进行搜索。

如果有匹配的内容，则弹出列表选择粘贴。

我假定凡是经过搜索粘贴的内容都是重要的值得特别标记的内容。

凡是特别标记的内容，不能被控制命令Ctrl-VA删除，只能被控制命令Ctrl-VD选择删除。

## 增加截图的复制粘贴功能

> 这是一个类似系统复制粘贴的“功能命令”，Ctrl松开后执行。

- Ctrl + CC  截图复制, 触发后用鼠标选择屏幕上任何矩形区域即可

- Ctrl + VV  位图粘贴, 触发后用鼠标选择要粘贴的位置，就可将剪切板中的位图粘贴。

## 增加桌面贴图管理

> 这是类似剪切板历史记录管理的“控制命令”，Ctrl松开前执行。

- Ctrl + VVA 删除全部桌面贴图

- Ctrl + VVS 下一个桌面贴图闪烁

- Ctrl + VVD 删除当前桌面贴图

- Ctrl + VVF 上一个桌面贴图闪烁

## 关于控制命令的说明

- 目前控制命令只在Ctrl+V 或 Ctrl+VV后，在Ctrl保持按下的状态下执行

- Ctrl一旦松开，所有的控制命令字符将全部消失，比如:   Ctrl+VSSFFDD = Ctrl+V ,所有松开后会执行系统粘贴功能。

- 一般而言Ctrl+V 或 Ctrl+VV 执行控制命令并Ctrl松开后会执行系统粘贴或位图粘贴

- 如果希望上述控制命令并Ctrl松开后不执行粘贴功能，可以追加一个特殊的字符X， 比如: Ctrl+VSSX = Ctrl+VX ，这个命令未定制，所以无任何动作。
