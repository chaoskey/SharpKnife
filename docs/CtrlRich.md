## Ctrl功能增强

> 本工具是[SharpKnife(利刃)](../README.md)效率工具库的成员

保证系统原生Ctrl功能不变（Ctrl松开执行的命令）

- 【系统复制】`Ctrl + c`

- 【系统粘贴】`Ctrl + v`

- 【系统剪切】`Ctrl + x`

新增截图的复制粘贴功能（Ctrl松开执行的命令）

- 【截图复制】`Ctrl + cc`    鼠标选择屏幕上任何矩形区域（先Ctrl+cc，后选择）

- 【图片粘贴】`Ctrl + vv`    鼠标选择粘贴屏幕任意位置，也可以将复制文本作为图片粘贴  （先Ctrl+cc，后选择）

增加Clipboard浏览管理（Ctrl未松开执行的命令）

- 【下一个clip浏览】  `Ctrl + vs(x)`    如果以x结尾，则表示松开后也不执行（下同）

- 【上一个clip浏览】  `Ctrl + vf(x)`

- 【删除当前clip】       `Ctrl + vd(x)`

- 【删除全部】           `Ctrl + va(x)`

贴图管理（Ctrl未松开执行的命令）

- 【下一个贴图】  Ctrl + vvs(x)

- 【上一个贴图】  Ctrl + vvf(x)

- 【删除当前贴图】   Ctrl + vvd(x)

- 【删除全部贴图】   Ctrl + vva(x)

组合命令（Ctrl松开）

- `Ctrl + c[a|s|d|f]*  = Ctrl + c`      

- `Ctrl + v[a|s|d|f]*  = Ctrl + v`

- `Ctrl + c[a|s|d|f]*c  = Ctrl + cc`

- `Ctrl + v[a|s|d|f]*v  = Ctrl + vv`

### 启动

> 建议配置成开机启动

```powershell
git clone https://github.com/chaoskey/SharpKnife.git
# 需要先安装AutoHotkey
autohotkey.exe CtrlRich.ahk

# 或者  下载 https://github.com/chaoskey/SharpKnife/releases
CtrlRich.exe
```