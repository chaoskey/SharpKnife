/*
    剪切板历史管理

global clipHist := new ClipHistory()
*/
class ClipHistory
{
    ; 默认在当前“.clip”子目录中保存Clip历史
    clipDir := ".clip"
    ; 标记的clip文件名（保持和文件.clip/clip.tag内容同步）
    ; 注意： 
    ; 1) tagcliparray用"`n"分割并作为开头结尾
    ; 2) 但是， .clip/clip.tag的内容不包括开头的"`n"
    tagcliparray := ""
    ; clip文件名列表
    cliparray := [] 
    ; 当前clip文件名索引
    activeclip := 0

    ; 系统剪切板（只存储当前clip）
    ; Clipboard      文本剪切板
    ; ClipboardAll   富剪切板, 包括了Clipboard

    ; 构造函数
    __New(clipDir := ".clip"){
        this.clipDir := clipDir
        ; 初始索引
        this.indexClip()
    }

    reset(){
        this.activeclip := 0
        this.deleteAndHoldClip()
    }

    ; 将当前clip读入Clipboard
    readClip(aclip := -1){
        if (aclip < 0){
            aclip := this.activeclip
        }
        aclip := Min(Max(aclip,1), this.cliparray.Length())
        if (aclip > 0) {
            currclip := this.cliparray[aclip]
            currPath := this.clipDir "\"  currclip ".clip"
            IfExist, %currPath%
                FileRead,Clipboard,*c %currPath%
        }else{
            Clipboard := ""
        }
    }

    ; 下一个clip
    nextClip(){
        if (this.cliparray.Length() > 1) {
            ; 下一个位置
            this.activeclip := this.activeclip + 1
            if (this.activeclip > this.cliparray.Length()){
                this.activeclip := 1
            }
            this.readClip()
        }
    }

    ; 上一个clip
    prevClip(){
        if (this.cliparray.Length() > 1) {
            ; 上一个位置
            this.activeclip := this.activeclip - 1
            if (this.activeclip < 1){
                this.activeclip := this.cliparray.Length()
            }
            ; 将当前clip读入到Clipboard
            this.readClip()
        }
    } 

    ; 删除当前clip
    deleteClip(aclip := -1){
        if (aclip < 0){
            aclip := this.activeclip
        }
        aclip := Min(Max(aclip,1), this.cliparray.Length())
        if (aclip > 0) {
            ; 删除当前索引位置的clip
            currclip := this.cliparray[aclip]
            Filedelete, % this.clipDir "\" currclip ".clip"
            if (idx1 := InStr(this.tagcliparray, "`n" currclip "|")) {
                idx2 := InStr(this.tagcliparray, "`n", , idx1 + 1)
                line := SubStr(this.tagcliparray, idx1 , idx2 - idx1 + 1)
                this.tagcliparray := StrReplace(this.tagcliparray, line , "`n")
                FileDelete, % this.clipDir "\clip.tag"
                FileAppend , % SubStr(this.tagcliparray, 2) , % this.clipDir "\clip.tag"
            }
            ; 删除后处理
            this.cliparray.RemoveAt(aclip)
            this.activeclip := aclip - 1
            this.readClip()
        }
    }

    ; 删除所有clip
    deleteClipAll(){
        this.activeclip := 0 ; 当前clip文件名索引
        for i_, v_ in this.cliparray {
            if (InStr(this.tagcliparray, "`n" v_ "|") == 0){
                Filedelete, % this.clipDir "\" v_ ".clip" ; 清空clip文件
            }
        }
        ; 重新索引并重新编号
        this.indexClipAndRenumber()
    }

    ; 已标记不能被删除
    ; 如果未标记的clip数量大于maxNum, 则最近minNum个未标记clip也不能被删除
    ; 除此之外的clip全部删除
    deleteAndHoldClip(maxNum := 500, minNum := 100){
        ; 计算未标记的clip总数
        unTagNum := this.cliparray.Length() - StrSplit(Trim(this.tagcliparray,"`n"),"`n").Length()
        if (unTagNum > maxNum){
            holdedUnTagNum := 0
            _cliparray := []
            for i_, v_ in this.cliparray {
                ; 已标记的clip必须保留
                if (InStr(this.tagcliparray, "`n" v_ "|") > 0){
                    _cliparray.Push(v_)
                    Continue
                }
                ; 没有标记的只保留最近的minNum个
                if (holdedUnTagNum < minNum){
                    _cliparray.Add(v_)
                    holdedUnTagNum := holdedUnTagNum + 1
                }else{
                    ; 多余的删除
                    Filedelete, % this.clipDir "\" v_ ".clip"
                }
            }
            this.cliparray := _cliparray
        }
    }

    ;  新加clip
    addClip(){
        ; 最近的clip文件名+1，即将添加的clip文件名
        lastclip := 1
        if (this.cliparray.Length() > 0){
            lastclip := this.cliparray[1] + 1 
        }
        ; 将当前Clipboard内容保存到文件
        IfExist, % this.clipDir "\" lastclip ".clip"
            FileDelete, % this.clipDir "\" lastclip ".clip"
        FileAppend,%ClipboardAll%, % this.clipDir "\" lastclip ".clip"
        ; 重新索引
        this.indexClip()
    }

    ; 将当前clip变成最近clip
    moveClip(aclip := -1){
        if (aclip < 0){
            aclip := this.activeclip
        }
        aclip := Min(Max(aclip,1), this.cliparray.Length())
        if (aclip > 1) {
            ; 当前粘贴内容对应的clip文件名
            oldclip := this.cliparray[aclip]
            newclip := this.cliparray[1] + 1
            ; 将当前clip文件变成最近文件 
            FileMove, % this.clipDir "\" oldclip ".clip", % this.clipDir "\" newclip ".clip" , 1
            ; 同步修改 .clip\clip.tag
            if InStr(this.tagcliparray, "`n" oldclip "|") {
                this.tagcliparray := StrReplace(this.tagcliparray, "`n" oldclip "|" , "`n" newclip "|")
                FileDelete, % this.clipDir "\clip.tag"
                FileAppend , %  SubStr(this.tagcliparray, 2) , % this.clipDir "\clip.tag"
            }
            ; 重新索引
            this.indexClip()
        }
    }

    ; 将指定内容保存到clip
    saveClip(saveText, aclip := -1){
        if (aclip < 0){
            aclip := this.activeclip
        }
        aclip := Min(Max(aclip,1), this.cliparray.Length())
        if (aclip > 0) {
            ; 分离标签和clip
            tag := ""
            idx1 := InStr(saveText, "[")
            idx2 := InStr(saveText, "]", idx1 + 1)
            if (idx1 = 1) and (idx2 > 2) {
                tag := SubStr(saveText, idx1 + 1 , idx2 - idx1 -1)
            }
            if (idx1 = 1) and (idx2 > 1) {
                saveText := SubStr(saveText, idx2 + 1)
            }
            ; 如果是空文本，意味着删除当前clip
            saveText := Trim(saveText, "`r`n")
            if (Trim(saveText) = "") {
                this.deleteClip(aclip)
                Clipboard := ""
                return False
            }
            ; 将修改后的内容保存到对应文件，并且写入剪切板
            currclip := this.cliparray[aclip]
            IfExist, % this.clipDir "\" currclip ".clip"
                FileDelete, % this.clipDir "\" currclip ".clip"
            Clipboard := saveText
            FileAppend,%ClipboardAll%, % this.clipDir "\" currclip ".clip"
            this.activeclip := aclip
            this.setClipTag(tag, this.activeclip)
            return True
        }
        return False
    }

    ; 将clip标记数据全部读入内存
    readTags(){
        this.tagcliparray := "`n"
        tagPath := this.clipDir "\clip.tag"
        if FileExist(tagPath) {
            Loop, read, %tagPath%
            {
                line := Trim(A_LoopReadLine)
                if (line != "") {
                    if (InStr(line, "|") = 0){
                        line := line "|★"
                    }
                    this.tagcliparray := this.tagcliparray line "`n"
                }
            }
        }
    }

    ; clip索引（逆序排列）
    indexClip(){
        this.cliparray := [] ; clip文件名列表
        this.activeclip := 0 ; 当前clip文件名索引
        if (not FileExist(this.clipDir)) {  
            FileCreateDir, % this.clipDir
        }
        ; 尝试将clip标记数据全部读入内存
        if (this.tagcliparray = "") {
            this.readTags()
        }
        ; 收集clip文件名
        filelist := ""
        Loop, Files, % this.clipDir "\*.clip"
        {
            filename := SubStr(A_LoopFileName, 1, -5)
            filelist := filelist filename "`n"
        }
        if (filelist != ""){
            filelist := Trim(filelist, " `t`n")
            ; 逆序排列
            Sort,filelist,N R
            ; 索引后的结果
            this.cliparray := StrSplit(filelist, "`n")
            ; 保证和剪切板同步
            this.readClip()
        }
    }

    ; clip索引并重新编号（逆序排列）
    ; 假设clip文件 和 tagcliparray  完全一致的清空下调用
    indexClipAndRenumber(){
        this.cliparray := [] ; clip文件名列表
        this.activeclip := 0 ; 当前clip文件名索引
        ; 尝试将clip标记数据全部读入内存
        if (this.tagcliparray = "") {
            this.readTags()
        }
        ; 收集clip文件名
        filelist := ""
        Loop, Files, % this.clipDir "\*.clip"
        {
            filename := SubStr(A_LoopFileName, 1, -5)
            filelist := filelist filename "`n"
        }
        if (filelist != ""){
            filelist := Trim(filelist, " `t`n")
            ; 正序排列
            Sort,filelist,N
            ; filelist的列表形式，及其"`n"分割的字符串副本
            _filelist_ := StrSplit(filelist, "`n")
            filelist := "`n" filelist "`n"
            ; 批量文件改名，并保证和tagcliparray一致（重新从1开始编号）
            newIndex := 0
            for i_, v_ in _filelist_
            {
                newIndex := newIndex + 1
                if (newIndex != v_) { 
                    filelist := StrReplace(filelist, "`n" v_ "`n" , "`n" newIndex "`n")
                    this.tagcliparray := StrReplace(this.tagcliparray, "`n" v_ "|" , "`n" newIndex "|")
                    FileMove, % this.clipDir "\" v_ ".clip", % this.clipDir "\" newIndex ".clip" , 1
                }
            }
            ; 逆序排列
            filelist := Trim(filelist, " `t`n")
            tmp := Trim(this.tagcliparray, " `t`n")
            Sort,filelist,N R
            Sort,tmp, N R
            ; 写入.clip\clip.tag，并保持和tagcliparray一致
            this.tagcliparray := tmp "`n"
            FileDelete, % this.clipDir "\clip.tag"
            FileAppend , % this.tagcliparray, % this.clipDir "\clip.tag"
            ; 索引后的结果
            this.tagcliparray := "`n" this.tagcliparray
            this.cliparray := StrSplit(filelist, "`n")
            ; 保证和剪切板同步
            this.readClip()
        }
    }

    ; 得到指定clip对应的标签
    ; 默认，取当前clip对应的标签
    getClipTag(aclip := -1){
        if (aclip < 0) {
            aclip := this.activeclip
        }
        aclip := Min(Max(aclip,1), this.cliparray.Length())
        if (aclip > 0) and (idx0 := InStr(this.tagcliparray, "`n" this.cliparray[aclip] "|")) {
            idx1 := InStr(this.tagcliparray, "|", , idx0)
            idx2 := InStr(this.tagcliparray, "`n", , idx1)
            tag := SubStr(this.tagcliparray, idx1 + 1, idx2 - idx1 -1)
            return tag
        }
        return ""
    }

    ; 将指定clip标记之
    ; 默认，将当前clip标记之
    setClipTag(tag, aclip := -1){
        ; 默认标签转义
        tag := StrReplace(tag, "*" , "★")
        if (aclip < 0) {
            aclip := this.activeclip
        }
        aclip := Min(Max(this.activeclip,1), this.cliparray.Length())
        if (aclip > 0){
            currclip := this.cliparray[aclip]
            if (0 = (idx1 := InStr(this.tagcliparray, "`n" currclip "|"))) {
                if (tag != "") {
                    line := currclip "|" tag "`n"
                    FileAppend , %line% , % this.clipDir "\clip.tag"
                    this.tagcliparray := this.tagcliparray line
                }
            }else{
                idx2 := InStr(this.tagcliparray, "`n" , , idx1 + 1)
                line := SubStr(this.tagcliparray, idx1, idx2 - idx1 + 1)
                if (tag != "") {
                    newline := "`n" currclip "|" tag "`n"
                }else{
                    newline := "`n"
                }
                this.tagcliparray := StrReplace(this.tagcliparray, line , newline)
                FileDelete, % this.clipDir "\clip.tag"
                FileAppend , % SubStr(this.tagcliparray, 2) , % this.clipDir "\clip.tag"
            } 
        } 
    }

    ; 搜索纯文本clip
    searchClip(ByRef textList, ByRef clipList, sText, showWidth := 85){
        textList := []
        clipList := []
        ; 搜索
        for i_ , v_ in this.cliparray{
            currPath := this.clipDir "\"  v_ ".clip"
            if FileExist(currPath){
                FileRead,Clipboard,*c %currPath%
                ; 只标记文本clip
                clip := Trim(Clipboard)
                if (clip = "") {
                    Continue
                }
                ; 大段内容概览(大于showWidth个字节)，简单内容全部显示
                ; 注意: 是字节数，而不是字符数
                clip := Trim(StrReplace(clip, "`r`n" , " "))
                if (idx := InStr(clip, sText)){
                    LL := StrLen(clip)
                    l := StrLen(sText)
                    loop {
                        if (idx > 1) and (idx < LL - l + 1){
                            idx := idx -1
                            l := l + 2
                        }else if (l < LL){
                            if (idx > 1){
                                idx := idx -1
                            }
                            l := l + 1
                        }else {
                            Break
                        }
                        line := SubStr(clip, idx, l)
                        if (StrPut(line, "utf-8") > showWidth){
                            Break
                        }
                    }
                    clip := SubStr(clip, idx, l)
                    if (idx > 1) {
                        clip := "... " clip
                    }
                    if (idx < LL - l + 1){
                        clip := clip " ..."
                    }
                    if InStr(this.tagcliparray, "`n" v_ "|"){
                        ; 特殊标记clip靠前
                        tag := this.getClipTag(i_)
                        if (tag != ""){
                            tag := "[" tag "]"
                        }
                        textList.InsertAt(1, tag clip )
                        clipList.InsertAt(1, i_)
                    }else{
                        textList.Push(clip)
                        clipList.Push(i_)
                    }
                }
            }       
        }        
    }
}

