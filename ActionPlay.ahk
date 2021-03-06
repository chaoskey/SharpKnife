; -----------------------------------------------
; 动作播放（完善中...）
; -----------------------------------------------
;
; 默认动作: （主线程）发送文本到窗口, 一步一行 支持发送快捷键，比如 比如{BS 8}{ENTER}
;   单行文本, 比如: <!-- ... -->
;   多行文本, 比如: 
; <!-- 
; ...
; -->
;
; 编码问题方案一:
;   Windows下，采用UTF-8 with BOM
;   优点: 只需要选择UTF-8 with BOM保存， 无需其它设置
;   缺点: UTF-8 with BOM是微软特有的，  强迫症患者严重不爽
; 编码问题方案二:
;   Windows下，采用UTF-8， 同时将本地编码也改成UTF-8()
;   优点: 只需UTF-8，强迫症患者感觉舒服多了
;   缺点: 需要将本地编码也改成UTF-8，  这点麻烦对强迫症患者不是事
; 
;------------------------------------------------

#SingleInstance, force

FileEncoding , UTF-8-RAW

#Include lib\util.ahk

; 托盘提示
Menu, Tray,Tip , 动作播放

; 启动GDI+支持
startupGdip()
return ; 自动运行段结束

; 动作处理主流程
doAction(){
    global action_cmds

    ; 加载动作文件  若已加载，则自动跳过
    loadAction()

    ; 解析单行
    ;   <!-- 命令 ...内容...  -->
    if parseSingleLine() {
        return
    }

    ; 解析多行
    ;   <!-- 命令
    ;   ...内容1...
    ;   ...内容2...
    ;   -->
    if parseMultiLine() {
        return
    }

    ; 抛弃不匹配内容, 直到匹配为止
    if (action_cmds.Length() > 0) {
        action_cmds.RemoveAt(1)
        doAction()
    }
    return
}

; 加载动作文件  若已加载，则自动跳过
loadAction(){
    
    ; 指定一个在脚本退出时自动运行的回调函数或子程序.

    global action_cmds
    if (not action_cmds)
        action_cmds := []  

    if (action_cmds.Length()==0) {
        ; 选择文件
        FileSelectFile, actioinFile, 1, , 打开动作脚本, 文本文档 (*.txt)
        ; 读取文件
        Loop, read, %actioinFile% 
        {
            if (Trim(A_LoopReadLine) != "")
                action_cmds.Push(A_LoopReadLine)
        }
    }
}

; 解析单行
;   <!-- 命令 ...内容...  -->
; 返回: 匹配成功与否
parseSingleLine(){
    global action_cmds

    ; 判断单行字符串
    ; 命令部分必须是非贪婪的， 比如 <!-- 图片 region:0-0 W100 H50 -->
    position := RegExMatch(action_cmds[1], "O)^\s*<!--\s+(.+?)\s+(.+)\s+-->\s*$", SubPat)
    if (position == 0)
        position := RegExMatch(action_cmds[1], "O)^\s*<!--\s+(.+?)\s+-->\s*$", SubPat)
    if position {
        ; 执行命令，并返回命令是否终止
        endCmd := execCmd(SubPat.Value(1), SubPat.Value(2))
        action_cmds.RemoveAt(1)
        if (not endCmd) {
            ; 如果命令未终止，继续
            doAction()
        }
        return True
    }
    return False
}

; 解析多行
;   <!-- 命令
;   ...内容1...
;   ...内容2...
;   -->
; 返回: 匹配成功与否
parseMultiLine(){
    global action_cmds
    global action_curr_cmd

    ; 如果遇到多行开始标记
    if RegExMatch(action_cmds[1], "O)^\s*<!--\s+(.+?)\s*$", SubPat){
        ; 开启多行标记(用存在当前命令表示)
        action_curr_cmd := SubPat.Value(1)
        action_cmds.RemoveAt(1)
    }
    ; 如果遇到多行结束标记
    if RegExMatch(action_cmds[1], "^\s*-->\s*$", SubPat){
        ; 关闭多行标记(将当前命令置零表示)
        action_curr_cmd := 0
        action_cmds.RemoveAt(1)
        ; 命令未终止，继续
        doAction()
        return True
    }
    if action_curr_cmd{
        ; 执行命令，并返回命令是否终止
        endCmd := execCmd(action_curr_cmd, action_cmds[1])
        action_cmds.RemoveAt(1)
        if (not endCmd){
            ; 如果命令未终止，继续
            doAction()
        }
        return True
    }
    return False
}

; 执行命令
; 返回: 命令是否终止
execCmd(cmd, content) {
    ; 默认命令不终止，但以最后一个子命令为准
    endCmd := False
    for index, subcmd in StrSplit(content, "##") {
        endCmd := execSubCmd(cmd, subcmd)   
    }
    return endCmd
}

; 执行子命令
; 返回: 子命令是否终止
execSubCmd(cmd, content) {
    ; 解析子命令参数
    subCmd := content
    paras := "" 
    index := InStr(content, "::")
    if index {
        subCmd := SubStr(content, 1, index - 1)
        paras := SubStr(content, index + 2)
    }
    subcmd := Trim(subcmd)
    paras := Trim(paras)

    ; 通用控制子命令"继续"，适用于任何命令
    if (subCmd = "继续"){
        ; 出现在最后，比如“##继续”,才有效
        ; 表示继续执行下一步命令
        return False
    }

    ; 命令处理
    if (cmd = "文本"){
        Send, % subCmd
        return True
    }
    if (cmd = "图片") {
        return execImageCmd(subcmd, paras) 
    }
    if (cmd = "声音") {
        return execAudioCmd(subcmd, paras) 
    }
    if (cmd = "视频") {
        return execVideoCmd(subcmd, paras) 
    }
    ; 默认命令没终止
    return False
}

; 执行图片子命令
; 返回: 子命令是否终止
execImageCmd(subcmd, paras)
{
    global action_image_dir
    global action_images ; 记录已打开的图片对应的窗口句柄, 第一个位置算最近
    ; 当前待显示的图片参数
    global currImagePara
    if (not currImagePara) {
     currImagePara := {}
    }

    ; Region: 显示当前图片的局部（指定的矩形, 椭圆形或多边形）
    ;   https://www.autoahk.com/help/autohotkey/zh-cn/docs/commands/WinSet.htm#Region
    ;   WinSet, Region , Options, WinTitle, WinText, ExcludeTitle, ExcludeText
    if  (subcmd = "局部") {
        if (paras = ""){
            return False
        }
        if currImagePara["file"] {
            currImagePara["crop"] := paras
            return True
        }
        ; 设置最近的图片, 第一个位置算最近
        hWND := action_images[1]
        paras := StrSplit(paras, ",")
        options := paras[1] "-" paras[2] " W" paras[3] " H" paras[4]  
        WinSet, Region, %options%, ahk_id %hWND%
        return True
    }
        ; Transparent: 设置当前图片为半透明状态
    ;   设置透明度: 0 表示完全透明, 255 表示完全不透明.
    ;   https://www.autoahk.com/help/autohotkey/zh-cn/docs/commands/WinSet.htm#Transparent
    ;   WinSet, Transparent , N, WinTitle, WinText, ExcludeTitle, ExcludeText
    if  (subcmd = "透明") {
        if (paras = ""){
            return False
        }
        if currImagePara["file"] {
            currImagePara["alpha"] := paras
            return True
        }
        ; 设置最近的图片, 第一个位置算最近
        hWND := action_images[1]
        WinSet, Transparent, %paras%, ahk_id %hWND%
        return True
    }

    ; 激活指定图片窗口, 并将其指定为最近
    ;   WinActivate , WinTitle, WinText, ExcludeTitle, ExcludeText
    if  (subcmd = "激活") {
        if (paras = ""){
            return False
        }
        ; 激活指定图片
        WinActivate , paras
        ; 将该图片设置为最近，先删后加
        hWND := WinExist(paras)
        for i_ , v_ in action_images {
            if (v_ == hWND){
                action_images.RemoveAt(i_)
                Break
            }
        }
        action_images.InsertAt(1, hWND)      
        return True
    }

    ; 位置移动
    if (subcmd = "位置") {
        if (paras == ""){
            ; 当前鼠标位置
            MouseGetPos, xpos, ypos
        } else {
            ; 指定位置
            pos_ := StrSplit(paras, ",")
            xpos := pos_[1]
            ypos := pos_[2]
        }
        if currImagePara["file"] {
            paras := xpos "," ypos
            currImagePara["position"] := paras
            return True
        }
        ; 移动最近的图片
        hWND := action_images[1]
        WinMove, ahk_id %hWND%, , %xpos%, %ypos%  
        return True
    }

    ; 标记图片（通过修改标题实现）
    if (subcmd = "标记") {
        if (paras = ""){
            return False
        }
        ; 对最近的图片打标签(修改窗口标题)
        hWND := action_images[1]
        WinSetTitle, ahk_id %hWND%, , %paras%
        return True
    }

    ; 关闭指定图片
    if (subcmd = "关闭") {
        if (paras = ""){
            ; 关闭最近的图片,并删除图片记录
            hWND := action_images[1]
            action_images.RemoveAt(1)
            Gui, %hWND%:Destroy
            return True
        }
        if (paras = "all"){
            ; 删除所有未关闭的图片
            if (action_images.Length() == 0) {
                return False    
            }
            for i_ , v_ in action_images {
                Gui, %v_%:Destroy
            }
            action_images := []
            return True
        }

        ; 关闭指定标签的图片
        hWND := WinExist(paras)
        existHWND := False
        ; 删除指定图片记录
        for i_ , v_ in action_images {
            if (v_ == hWND){
                action_images.RemoveAt(i_)
                existHWND := True
                Break
            }
        }
        if existHWND {
            Gui, %hWND%:Destroy
        }
        return True
    }

    ; 改变图片目录
    if (subcmd = "目录") {
        action_image_dir := paras
        return False ; 子命令未终止
    }

    ; 显示图片
    if (subcmd = "显示") {
        if currImagePara["file"] {
            ; 显示图片
            drawImage(action_image_dir "\" currImagePara["file"]
                , currImagePara["crop"]
                , currImagePara["position"]
                , currImagePara["alpha"]) 

            currImagePara["file"] :=  ""
            currImagePara["position"] :=  ""
            currImagePara["crop"] :=  ""
            currImagePara["alpha"] :=  255
        }
        return True
    }

    ; 当前待显示图片
    currImagePara["file"] :=  subcmd
    currImagePara["position"] :=  ""
    currImagePara["crop"] :=  ""
    currImagePara["alpha"] :=  255 
    return False
}

drawImage(file, crop, position, alpha)
{
    global action_images ; 记录已打开的图片对应的窗口句柄, 第一个位置算最近
    if (not action_images) {
        action_images := []
    }
    ; 从图片创建位图句柄
    pBitmap := Gdip_CreateBitmapFromFile(file)
    hWND := pasteImageToScreen(pBitmap, crop, position, alpha)
    ; 记录窗口句柄，插入第一个位置
    action_images.InsertAt(1, hWND)
    ; 删除位图GID对象（pBitmap）
    Gdip_DisposeImage(pBitmap) 
}

; 执行声音子命令
; 返回: 子命令是否终止
execAudioCmd(subcmd, paras){
    global action_audio_dir

    ; 当前待播放音频参数
    global currAudioPara
    if (not currAudioPara) {
        currAudioPara := {}
    }

    if  (subcmd = "字幕") {
        if (paras = ""){
            return False
        }
        currAudioPara["subtitle"] := paras
        return True
    }

    ; 字幕位置
    if (subcmd = "位置") {
        if (paras == ""){
            ; 当前鼠标位置
            MouseGetPos, xpos, ypos
        } else {
            ; 指定位置
            pos_ := StrSplit(paras, ",")
            xpos := pos_[1]
            ypos := pos_[2]
        }
        paras := xpos "," ypos
        currAudioPara["position"] := paras
        return True
    }

    ; 改变音频目录
    if (subcmd = "目录") {
        action_audio_dir := paras
        return False ; 子命令未终止
    }

    ; 播放音频
    if (subcmd = "播放") {
        file := ""
        if currAudioPara["file"] {
            file := action_audio_dir "\" currAudioPara["file"]
        }
        ; 播放音频文件，如果文件为空，朗读文字
        playAudio(file
            , currAudioPara["subtitle"]
            , currAudioPara["position"]) 

        currAudioPara["file"] :=  ""
        currAudioPara["subtitle"] :=  ""
        currAudioPara["position"] :=  ""
        
        return True
    }

    ; 当前待播放音频
    currAudioPara["file"] :=  subcmd
    currAudioPara["subtitle"] :=  ""
    currAudioPara["position"] :=  ""
    return False
}

; 播放音频文件，如果文件为空，朗读文字
playAudio(file, subtitle, position)
{
    global action_spvoice

    pos_ := StrSplit(position, ",")
    xpos := pos_[1]
    ypos := pos_[2]

    if subtitle
        ; 如果有字幕则在指定位置显示之 
        ToolTip , %subtitle%, %xpos%, %xpos%
    if file {
        ; 播放音频
        SoundPlay, %file%, WAIT
    } else {
        if (not action_spvoice) {
            ; 初次使用时启动
            action_spvoice := ComObjCreate("sapi.spvoice")
        }
        ; 朗读文字
        action_spvoice.Speak(subtitle)
    }
    if subtitle
        ToolTip
}

; 执行视频子命令
; 返回: 子命令是否终止
execVideoCmd(subcmd, paras){
    global action_video_dir

    ; 当前待播放视频参数
    global currVideoPara
    if (not currVideoPara) {
        currVideoPara := {}
    }

    ; 播放窗口位置
    if (subcmd = "位置") {
        if (paras == ""){
            ; 当前鼠标位置
            MouseGetPos, xpos, ypos
        } else {
            ; 指定位置
            pos_ := StrSplit(paras, ",")
            xpos := pos_[1]
            ypos := pos_[2]
        }
        if currImagePara["file"] {
            paras := xpos "," ypos
            currImagePara["position"] := paras
            return True
        }
        return True
    }

    ; 改变视频目录
    if (subcmd = "目录") {
        action_video_dir := paras
        return False ; 子命令未终止
    }

    ; 播放音频
    if (subcmd = "播放") {
        file := ""
        if currVideoPara["file"] {
            file := action_video_dir "\" currVideoPara["file"]
        }
        ; 播放音频文件，如果文件为空，朗读文字
        playVideo(file, currVideoPara["position"]) 

        currVideoPara["file"] :=  ""
        currVideoPara["position"] :=  ""
        
        return True
    }

    ; 当前待播放视频
    currVideoPara["file"] :=  subcmd
    currVideoPara["position"] :=  ""
    return False
}


; 播放视频文件
playVideo(file, position)
{
    pos_ := StrSplit(position, ",")
    xpos := pos_[1]
    ypos := pos_[2]
    
    ; 播放视频
    RunWait "ffplay" "-hide_banner" "-nostats" "-autoexit" %file%, , Hide
}


~F8::
; 如果有IMSwitch.ahk的加持， 可确保在英文状态下执行脚本
_getImState := "getImState"
_setImState := "setImState"
_IMToolTip := "IMToolTip"
if isFunc(_getImState){
    imState := %_getImState%()
    if (imState = 1){
        ; 确保只在中文状态下动作
        Send ^{Space}
        %_IMToolTip%(0)
    }
}
oldKeyDelay := A_KeyDelay
SetKeyDelay, 50
doAction()
SetKeyDelay, oldKeyDelay


; 如果是矢量绘制和填充，将平滑模式设置为 antialias=4 ，使形状看起来更平滑
;Gdip_SetSmoothingMode(G, 4)
; 创建一个完全不透明的红色画笔（pBrush）【GID对象】
;pBrush := Gdip_BrushCreateSolid(0xffff0000)
; 用画笔(pBrush)绘制椭圆填充位图
; 从坐标 (100,50) 填充 200x300 的椭圆
;Gdip_FillEllipse(G, pBrush, 100, 300, 200, 300)
; 删除画笔GID对象（pBrush）
;Gdip_DeleteBrush(pBrush)
; ---------------------------
; 使用GDI位图的设备上下文句柄hdc更新分层窗口hwnd1 
;UpdateLayeredWindow(hwnd1, hdc, 0, 0, A_ScreenWidth, A_ScreenHeight)

;Sleep 5000

; 创建一个稍微透明（0x66）的蓝色画笔【GID对象】
;pBrush := Gdip_BrushCreateSolid(0x660000ff)
; 使用创建的画笔用矩形填充位图的图形
; 从坐标 (250,80) 填充一个 300x200 的矩形
;Gdip_FillRectangle(G, pBrush, 250, 80, 300, 200)
; 删除画笔GID对象（pBrush）
;Gdip_DeleteBrush(pBrush)
; ---------------------------
; 使用GDI位图的设备上下文句柄hdc更新分层窗口hwnd1 
;UpdateLayeredWindow(hwnd1, hdc, 0, 0, A_ScreenWidth, A_ScreenHeight)

return