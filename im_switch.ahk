; -----------------------------------------------
; 微软拼音输入法中英文状态同步记录
; 假设：
;	1) 输入法采用微软拼音并且默认为英文
;	2) 本脚开机启动
;	3) 管住手，禁止鼠标点击切换中英文 【除非提示和系统显示不一样】
;   4) 为每一个活动过的窗口记录中英文状态
;------------------------------------------------


FileEncoding , UTF-8
Return

; 查看中英文状态信息
imStateInfo()
{
    global ids
    global imState

    id := getHWND()
    if (!imState[id])
    {
       imState[id] := 0
    }
    Send ------------------{Enter}
    for index, value in ids
    {
        key := value
        value := imState[key]
        Send %key%=%value%{Enter}
    }
    Send ------------------{Enter}
}

; 获取当前活动窗口ID(HWND)
getHWND()
{   
    ; 窗口ID(HWND)列表【只保留最近活动的10个ID就足够了】
    global ids
    ; 每个窗口ID,对应一个独立中英文状态【0代表英，1代表中】 
    global imState

    if (not ids)
        ids := []
    if (not imState)
        imstate := {}

    ; 当前活动窗口ID
    id := WinExist("A")
    
    ; 将当前窗口ID移到最后，表示最近
    for index, value in ids
    {
        if (value = id)
        {
            ids.RemoveAt(index)
        }
    }
    ids.Push(id)
    
    ; 确保记录的最近活动窗口ID不超过10个
    if (ids.Length() > 10)
    {
        oldid := ids[1]
        ids.RemoveAt(1)
        imState.Delete(oldid)
    }
    
    return id
}

; 获取当前窗口的中英文状态变量值
getImState()
{
    global imState
    id := getHWND()
    if (!imState[id])
    {
       imState[id] := 0 
    }
   return imState[id]
}

; 切换当前窗口的中英文状态变量值 
switchImState()
{
    global imState
    id := getHWND()
    if (!imState[id])
    {
       imState[id] := 0
    }
    if (imState[id] = 0)
    {
        imState[id] := 1
    }
    else
    {
        imState[id] := 0
    }
    return imState[id]
}

; 设定当前窗口的中英文状态变量值
setImState(v)
{
    global imState
    id := getHWND()
    imState[id] := v
    return imState[id]
}

; 查看中英文状态信息

::imstate::
if (getImState() = 1)
{
    Send ^{Space}	; 切换到英文状态
}
setImState(0)		; 记录并切换到英文状态  
IMToolTip()
imStateInfo()
return

; 重新映射微软拼音中英文切换的快捷

~^Space::		; Ctl+空格，并且保留原始功能
switchImState()		; 切换并记录中英文状态
IMToolTip()
return

; Markdown中准备编辑数学公式

:*?:$::        		; 按下$立刻执行,  ?表示即使此热字串在另一个单词中也会被触发。
if (getImState() = 1)
{
    Send ^{Space}	; 切换到英文状态
}
setImState(0)		; 记录并切换到英文状态   
Send $			; 保留原始功能
IMToolTip()
return

; Vim中回到普通模式

~Esc::         		; Esc, 并且保留原始功能
if (getImState() = 1)
{
    Send ^{Space}	; 切换到英文状态
}
setImState(0)
IMToolTip()
return

; Vim进入命令行模式 【+;就是冒号:】

+;::          		; 按下:(Shift + ;)
if (getImState() = 1)
{
    Send ^{Space}
}
setImState(0)
Send {Text}:
IMToolTip()
return

IMToolTip()
{
    if (getImState() = 1)
        ToolTip, 中
    else
        ToolTip, EN
    SetTimer, RemoveIMToolTip, -1000
}

RemoveIMToolTip:
ToolTip
return
