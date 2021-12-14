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
            if InStr(this.tagcliparray, "`n" currclip "`n") {
                this.tagcliparray := StrReplace(this.tagcliparray, "`n" currclip "`n" , "`n")
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
            if (InStr(this.tagcliparray, "`n" v_ "`n") == 0){
                Filedelete, % this.clipDir "\" v_ ".clip" ; 清空clip文件
            }
        }
        this.cliparray := StrSplit(Trim(this.tagcliparray, " `t`n"), "`n")
        if (this.cliparray.Length() = 0){
            clipboard := "" ; 清空剪贴板
        }else{
            ; 重新索引并重新编号
            this.indexClipAndRenumber()
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
            if InStr(this.tagcliparray, "`n" oldclip "`n") {
                this.tagcliparray := StrReplace(this.tagcliparray, "`n" oldclip "`n" , "`n" newclip "`n")
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
            return True
        }
        return False
    }

    ; 将clip标记数据全部读入内存
    readTags(){
        this.tagcliparray := "`n"
        if FileExist(this.clipDir) {  
            Loop, read, % this.clipDir "\clip.tag" 
            {
                line := Trim(A_LoopReadLine)
                if (line != "") {
                    this.tagcliparray := this.tagcliparray line "`n"
                }
            }
        }else{
            FileCreateDir, this.clipDir
        }
    }

    ; clip索引（逆序排列）
    indexClip(){
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
            ; 逆序排列
            Sort,filelist,N R
            ; 索引后的结果
            this.cliparray := StrSplit(filelist, "`n")
            ; 保证和剪切板同步
            this.readClip()
        }
    }

    ; clip索引并重新编号（逆序排列）
    ; 假设cliparray 和 tagcliparray  完全一致的清空下调用
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
                    FileMove, % this.clipDir "\" v_ ".clip", % this.clipDir "\" newIndex ".clip" , 1
                }
            }
            ; 逆序排列
            filelist := Trim(filelist, " `t`n")
            Sort,filelist,N R
            ; 写入.clip\clip.tag，并保持和tagcliparray一致
            this.tagcliparray := filelist "`n"
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
        aclip := Min(Max(this.activeclip,1), this.cliparray.Length())
        if (aclip > 0) and InStr(this.tagcliparray, "`n" this.cliparray[aclip] "`n") {
            return "[★]"
        }
        return ""
    }

    ; 将指定clip标记之
    ; 默认，将当前clip标记之
    setClipTag(aclip := -1){
        if (aclip < 0) {
            aclip := this.activeclip
        }
        aclip := Min(Max(this.activeclip,1), this.cliparray.Length())
        if (aclip > 0){
            currclip := this.cliparray[aclip]
            if (this.tagcliparray = "`n") or (0 = InStr(this.tagcliparray, "`n" currclip "`n")) {
                FileAppend , % currclip "`n", % this.clipDir "\clip.tag"
                this.tagcliparray := this.tagcliparray currclip "`n"
            } 
        } 
    }

    ; 搜索纯文本clip
    searchClip(ByRef textList, ByRef clipList, sText, showWidth := 62){
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
                ; 大段内容概览(大于showWidth个字符)，简单内容全部显示
                if (searchIdx := InStr(clip, sText)){
                    if (StrLen(clip) > showWidth) {
                        ; 内容概览裁剪

                        clip_end := InStr(clip, "`r`n" , , searchIdx)
                        if clip_end {
                            clip := SubStr(clip, 1 , clip_end - 1)
                        }
                        clip_start := InStr(clip, "`r`n" , , 0)
                        if clip_start {
                            clip := SubStr(clip, clip_start + 2)
                        }
                        clip := Trim(clip)
                        if ((L__ := StrLen(clip)) > showWidth - 8){
                            searchIdx := InStr(clip, search)
                            l_ := StrLen(search)
                            L1__ := searchIdx - 1
                            L2__ := L__ - l_ - L1__
                            l1_ := (showWidth - 8 - l_)//2
                            l2_ := showWidth - 8 - l_ - l1_
                            if (L1__ < l1_){
                                l1_ := L1__
                                l2_ := showWidth - 8 - l_ - l1_
                            }else if (L2__ < l2_){
                                l2_ := L2__
                                l1_ := showWidth - 8 - l_ - l2_
                            }
                            clip := SubStr(clip, searchIdx - l1_ , showWidth - 8)
                            if (l1_ < L1__){
                                clip := "... " clip
                            }
                            if (l2_ < L2__){
                                clip := clip " ..."
                            }
                        }
                    }
                    if InStr(this.tagcliparray, "`n" v_ "`n"){
                        ; 特殊标记clip靠前
                        textList.InsertAt(1, "[★]" clip )
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

