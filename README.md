# SharpKnife(利刃) - 基于AutoHotkey的效率工具

> 计划将我常用效率工具全部集成到`SharpKnife`(利刃)这个工具中, 根据需要逐步添加。
> 
> `SharpKnife`(利刃), 是用AutoHotkey这个效率神器开发的。

## 已集成功能

- [输入法助手](docs/IMSwitch.md)（中英文状态切换辅助）

- [LaTeX助手](docs/LaTeXHelper.md)（`\[命令|搜索]Tab`）

- [Ctrl功能增强](docs/CtrlRich.md)（保留系统功能+剪切板浏览管理+截贴图及其管理+翻译）

- 动作播放（不完善打磨中...）

## 全部启动

> 建议配置成开机启动
>
> 为了可在任何窗口下正常运行SharpKnife.exe中的**Ctrl功能增强**，脚本强制以管理员身份运行。（比如: Ctrl-cf是选择翻译，如果是非管理员状态，有些环境会触发搜索快捷键Ctrl-f；用管理员身份运行可以避免这个问题: Ctrl-cf不会触发Ctrl-f搜索，只有Ctrl-f才能触发搜索）

```powershell
git clone https://github.com/chaoskey/SharpKnife.git
# 需要先安装AutoHotkey
autohotkey.exe SharpKnife.ahk

# 或者  下载 https://github.com/chaoskey/SharpKnife/releases
SharpKnife.exe
```
