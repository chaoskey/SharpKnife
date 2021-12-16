#Include lib\util.ahk

/*
    截图贴图管理(仅与当前剪切板交换数据)
*/
class SniPaste
{
    pastearray := [] ; 屏幕贴图的句柄列表
    activepaste := 0 ; 当前桌面贴图索引

    ; 构造函数
    __New(){
    }

    reset(){
        this.activepaste := 0
    }

    ; 截图复制（到剪切板）
    snip(){
        ; 按住鼠标左键-移动鼠标-松开: 选择截图区域
        screen_ := SelectRegionFromScreen("LButton")
        ; 获取区域截图
        pBitmap := Gdip_BitmapFromScreen(screen_)
        ; 获取到Clipboard
        Gdip_SetBitmapToClipboard(pBitmap)
        ; 删除内存位图
        Gdip_DisposeImage(pBitmap)
    }

    ; （从剪切板）粘贴到屏幕
    paste(){
        ; 从Clipboard获取位图
        pBitmap := Gdip_CreateBitmapFromClipboard()
        if (pBitmap < 0 ){
            return -1
        }
        ; 贴图
        CoordMode, Mouse, Screen
        MouseGetPos, X, Y
        hWND := pasteImageToScreen(pBitmap, , X "," Y)
        this.pastearray.Push(hWND)
        ; 删除内存位图
        Gdip_DisposeImage(pBitmap)
        ; 定位
        down_ := False
        loop{
            keyIsDown := GetKeyState("LButton" , "P")
            if keyIsDown {
                down_ := True
            } else if down_{
                break
            }
            MouseGetPos, X, Y
            ; 移动贴图
            WinMove, ahk_id %hWND%, , %X%, %Y%  
        }
        return hWND
    }

    ; 下一张桌面贴图, 并闪烁之
    nextPaste(){
        if (this.pastearray.Length() > 1) {
            ; 下一个位置
            this.activepaste := this.activepaste + 1
            if (this.activepaste > this.pastearray.Length()){
                this.activepaste := 1
            }
            this.flashPaste()
        }
    }

    ; 上一张桌面贴图, 并闪烁之
    prevPaste(){
        if (this.pastearray.Length() > 1) {
            ; 上一个位置
            this.activepaste := this.activepaste - 1
            if (this.activepaste < 1){
                this.activepaste := this.pastearray.Length()
            }
            this.flashPaste()
        }
    }

    ; 清空所有屏幕贴图
    clearPastes(){
        for idx_, value_ in this.pastearray {
            Gui, %value_%:Destroy
        }
        this.pastearray := []
    }

    ; 删除指定屏幕贴图
    deletPaste(apaste := -1){
        if (apaste < 0){
            apaste := this.activepaste
        }
        apaste := Min(Max(apaste,1), this.pastearray.Length())
        if (apaste > 0){
            hWND := this.pastearray[apaste]
            Gui, %hWND%:Destroy
            this.pastearray.RemoveAt(apaste)
            this.activepaste := apaste - 1
        }
    }

    ; 桌面贴图闪动提示
    flashPaste(apaste := -1){
        if (apaste < 0){
            apaste := this.activepaste
        }
        apaste := Min(Max(apaste,1), this.pastearray.Length())
        if (apaste > 0){
            hWND := this.pastearray[apaste]
            Loop 3
            {
                Gui, %hWND%:Hide
                Sleep 50
                Gui, %hWND%:Show
                Sleep 50
            }
        }
    }
}