; ==============================================================================
; SharpKnifeCore —— SharpKnife 纯逻辑核心（无 GUI / 无全局热键副作用）
; ------------------------------------------------------------------------------
; 由 SharpKnife.ahk #Include（主脚本行为不变）；test\test-logic.ahk 复用同一份
; 代码做逻辑层单测，保证测试的就是线上代码。
; 外部依赖的全局变量（cvsEntries / latex_mode / playScriptDir）由宿主脚本声明并赋值。
; 环境要求：AutoHotkey v2.0+（Windows 10）
; ==============================================================================
#Requires AutoHotkey v2.0

; ============================================================================
; 1. 加载 latexs.cvs —— 原始条目列表（模式过滤在触发时进行）
;    条目：{key, f2, f3, hasF3}
; ============================================================================
LoadCvsEntries(cvsFile) {
    entries := []
    if !FileExist(cvsFile)
        return entries
    Loop read, cvsFile {
        line := Trim(A_LoopReadLine)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        t1 := InStr(line, "`t")
        if (t1 = 0)
            continue
        key := Trim(SubStr(line, 1, t1 - 1), " `t")
        rest := Trim(SubStr(line, t1 + 1), " `t")
        if (rest = "")
            continue

        t2 := InStr(rest, "`t")

        if (t2 > 0) {
            f2 := Trim(SubStr(rest, 1, t2 - 1), " `t")   ; 第二字段
            f3 := Trim(SubStr(rest, t2 + 1), " `t")      ; 第三字段
            if (f2 != "" && f3 != "")
                entries.Push({key: key, f2: f2, f3: f3, hasF3: true})
        } else {
            ; 只有第二字段
            if (rest != "")
                entries.Push({key: key, f2: rest, f3: "", hasF3: false})
        }
    }
    return entries
}

; ============================================================================
; 2. 上下文解析 + 匹配 —— <前缀>*<待匹配字符串>* 模型
; ============================================================================
; IsValidStar: 字符串必须为空，或全部由 英文字母 / 数字 / 非 _ ^ \ 的符号
;              组成（区分大小写）。对应匹配模式中的 `*` 通配符。
IsValidStar(s) {
    if (s = "")
        return true
    return RegExMatch(s, "^[^_^\\]+$") != 0
}

; 解析合法上下文 "<前缀><待匹配字符串>" → {prefix, search}；非法返回 0。
; rest（待匹配字符串）须为非空，且仅由 英文字母 / 数字 / 除 _ ^ \ 之外的符号 组成（区分大小写）。
GetContextInfo(context) {
    for p in ["_\", "^\", "_", "^", "\"] {
        if (SubStr(context, 1, StrLen(p)) = p) {
            rest := SubStr(context, StrLen(p) + 1)
            if (rest = "" || InStr(rest, "_") || InStr(rest, "^") || InStr(rest, "\"))
                return 0
            return {prefix: p, search: rest}
        }
    }
    return 0
}

; 按上下文匹配触发表条目（带模式过滤）。
; 返回 {key, f2, f3, hasF3, type} 数组。
FindMatches(info) {
    global cvsEntries, latex_mode
    matches := []
    P := info.prefix
    S := info.search
    for e in cvsEntries {
        ; --- 模式过滤 ---
        if (latex_mode) {
            ; latex 模式：第二字段不能以 : 开头
            if (SubStr(e.f2, 1, 1) = ":")
                continue
        } else {
            ; unicode 模式：第二字段中间不能含空格
            if (InStr(e.f2, " "))
                continue
        }
        ; 键必须以相同的前缀开头
        if (SubStr(e.key, 1, StrLen(P)) != P)
            continue
        ; body = 键去掉前缀；匹配模式 = L + S + R（L/R 可为空或由合法字符组成）
        body := SubStr(e.key, StrLen(P) + 1)
        pos := InStr(body, S, true)    ; 区分大小写
        if (pos = 0)
            continue
        L := SubStr(body, 1, pos - 1)
        R := SubStr(body, pos + StrLen(S))
        if (!IsValidStar(L))
            continue
        if (!IsValidStar(R))
            continue
        if (L = "" && R = "")
            mt := "="
        else if (L = "" && R != "")
            mt := "<"    ; 头对齐：前段（第一个 *）为空，匹配串对齐键的头部
        else if (L != "" && R = "")
            mt := ">"    ; 尾对齐：后段（第二个 *）为空，匹配串对齐键的尾部
        else
            mt := "~"
        matches.Push({key: e.key, f2: e.f2, f3: e.f3, hasF3: e.hasF3, type: mt})
    }
    ; 排序：= (1) > (2) < (3) ~ (4)；同类型内键较短者在前
    n := matches.Length
    loop n - 1 {
        i := A_Index
        loop n - i {
            j := A_Index
            a := matches[j]
            b := matches[j + 1]
            ra := 1 + (a.type = ">") + 2 * (a.type = "<") + 3 * (a.type = "~")
            rb := 1 + (b.type = ">") + 2 * (b.type = "<") + 3 * (b.type = "~")
            swap := false
            if (ra > rb)
                swap := true
            else if (ra = rb && StrLen(a.key) > StrLen(b.key))
                swap := true
            if (swap) {
                matches[j] := b
                matches[j + 1] := a
            }
        }
    }
    return matches
}

; ============================================================================
; 3. 处理 LaTeX 模板：处理 {Text} 前缀与 ##{Left N} 标记
; ============================================================================
ProcessLatexTemplate(template) {
    ; 若存在 {Text} 前缀则去掉
    if (SubStr(template, 1, 6) = "{Text}") {
        template := SubStr(template, 7)
    }
    ; 若存在 ##{Left N} 后缀则提取并去掉
    leftMove := 0
    dd := InStr(template, "##")
    if (dd > 0) {
        suffix := SubStr(template, dd)
        template := SubStr(template, 1, dd - 1)
        ; 解析 {Left N}
        leftStart := InStr(suffix, "{Left ")
        if (leftStart > 0) {
            leftEnd := InStr(suffix, "}", , leftStart)
            if (leftEnd > leftStart) {
                numStr := SubStr(suffix, leftStart + 6, leftEnd - leftStart - 6)
                leftMove := Integer(numStr)
            }
        }
    }
    return { text: template, leftMove: leftMove }
}

; ============================================================================
; 4. play 脚本 —— JSON 解析（纯字符串解析，不依赖文件系统 / GUI）
; ============================================================================
PlaySkipWs(txt, &pos) {
    len := StrLen(txt)
    while (pos <= len) {
        c := SubStr(txt, pos, 1)
        if (c = " " || c = "`t" || c = "`n" || c = "`r")
            pos++
        else
            break
    }
}

PlayParseValue(txt, &pos) {
    PlaySkipWs(txt, &pos)
    if (pos > StrLen(txt))
        throw Error("意外结束")
    c := SubStr(txt, pos, 1)
    if (c = "{")
        return PlayParseObject(txt, &pos)
    if (c = "[")
        return PlayParseArray(txt, &pos)
    if (c = '"')
        return PlayParseString(txt, &pos)
    if (c = "-" || InStr("0123456789", c))
        return PlayParseNumber(txt, &pos)
    if (SubStr(txt, pos, 4) = "true") {
        pos += 4
        return true
    }
    if (SubStr(txt, pos, 5) = "false") {
        pos += 5
        return false
    }
    if (SubStr(txt, pos, 4) = "null") {
        pos += 4
        return 0
    }
    throw Error("位置 " . pos . " 处存在非法字符")
}

PlayParseObject(txt, &pos) {
    pos++
    m := Map()
    PlaySkipWs(txt, &pos)
    if (pos <= StrLen(txt) && SubStr(txt, pos, 1) = "}") {
        pos++
        return m
    }
    loop {
        PlaySkipWs(txt, &pos)
        if (pos > StrLen(txt) || SubStr(txt, pos, 1) != '"')
            throw Error("对象键必须为字符串")
        key := PlayParseString(txt, &pos)
        PlaySkipWs(txt, &pos)
        if (pos > StrLen(txt) || SubStr(txt, pos, 1) != ":")
            throw Error("缺少冒号")
        pos++
        m[key] := PlayParseValue(txt, &pos)
        PlaySkipWs(txt, &pos)
        if (pos > StrLen(txt))
            throw Error("对象未闭合")
        c := SubStr(txt, pos, 1)
        if (c = ",") {
            pos++
            continue
        }
        if (c = "}") {
            pos++
            return m
        }
        throw Error("对象语法错误")
    }
}

PlayParseArray(txt, &pos) {
    pos++
    arr := []
    PlaySkipWs(txt, &pos)
    if (pos <= StrLen(txt) && SubStr(txt, pos, 1) = "]") {
        pos++
        return arr
    }
    loop {
        arr.Push(PlayParseValue(txt, &pos))
        PlaySkipWs(txt, &pos)
        if (pos > StrLen(txt))
            throw Error("数组未闭合")
        c := SubStr(txt, pos, 1)
        if (c = ",") {
            pos++
            continue
        }
        if (c = "]") {
            pos++
            return arr
        }
        throw Error("数组语法错误")
    }
}

PlayParseString(txt, &pos) {
    pos++
    out := ""
    len := StrLen(txt)
    while (pos <= len) {
        c := SubStr(txt, pos, 1)
        if (c = '"') {
            pos++
            return out
        }
        if (c = "\") {
            pos++
            if (pos > len)
                throw Error("字符串转义不完整")
            e := SubStr(txt, pos, 1)
            pos++
            if (e = '"')
                out .= '"'
            else if (e = "\")
                out .= "\"
            else if (e = "/")
                out .= "/"
            else if (e = "b")
                out .= Chr(8)
            else if (e = "f")
                out .= Chr(12)
            else if (e = "n")
                out .= "`n"
            else if (e = "r")
                out .= "`r"
            else if (e = "t")
                out .= "`t"
            else if (e = "u") {
                if (pos + 3 > len)
                    throw Error("unicode 转义不完整")
                hex := SubStr(txt, pos, 4)
                pos += 4
                if (!RegExMatch(hex, "^[0-9a-fA-F]{4}$"))
                    throw Error("unicode 转义非法")
                out .= Chr(PlayHexToInt(hex))
            } else {
                throw Error("非法转义字符")
            }
            continue
        }
        out .= c
        pos++
    }
    throw Error("字符串未闭合")
}

PlayHexToInt(hex) {
    v := 0
    digits := "0123456789abcdef"
    i := 1
    while (i <= 4) {
        c := StrLower(SubStr(hex, i, 1))
        v := v * 16 + (InStr(digits, c) - 1)
        i++
    }
    return v
}

PlayParseNumber(txt, &pos) {
    rest := SubStr(txt, pos)
    if (RegExMatch(rest, "^(-?\d+)(\.\d+)?([eE][+-]?\d+)?", &m)) {
        tok := m[0]
        pos += StrLen(tok)
        if (InStr(tok, ".") || InStr(tok, "e") || InStr(tok, "E"))
            return Float(tok)
        return Integer(tok)
    }
    throw Error("非法数字")
}

; ============================================================================
; 5. play 脚本 —— 结构校验（加载阶段）
; ============================================================================
PlayValidateAction(a) {
    if (!(IsObject(a) && a is Map))
        return false
    if (!a.Has("type") || !(a["type"] is String))
        return false
    t := a["type"]
    if (t = "text")
        return PlayValidateText(a)
    if (t = "sleep")
        return PlayValidateSleep(a)
    if (t = "run")
        return PlayValidateRun(a)
    if (t = "note")
        return PlayValidateNote(a)
    if (t = "paste")
        return PlayValidatePaste(a)
    if (t = "audio")
        return PlayValidateMedia(a, false)
    if (t = "video")
        return PlayValidateMedia(a, true)
    if (t = "seq")
        return PlayValidateSeq(a)
    if (t = "par")
        return PlayValidatePar(a)
    return false
}

PlayValidateText(a) {
    if (!a.Has("value"))
        return false
    v := a["value"]
    valid := false
    if (v is String) {
        valid := true
    } else if (IsObject(v) && v is Array) {
        valid := true
        for item in v {
            if (!(item is String)) {
                valid := false
                break
            }
        }
    }
    if (!valid)
        return false
    ; delay：可选，毫秒，控制字符输出间隔；缺省 0（即时输出）；负值按最近边界截断为 0
    if (a.Has("delay")) {
        if (!PlayIsNumber(a["delay"]))
            return false
        if (a["delay"] < 0)
            a["delay"] := 0
        a["delay"] := Round(a["delay"])
    } else {
        a["delay"] := 0
    }
    return true
}

PlayValidatePaste(a) {
    if (!a.Has("path") || !(a["path"] is String) || a["path"] = "")
        return false
    if (a.Has("pos")) {
        p := a["pos"]
        if (!PlayIsXY(p))
            return false
        a["pos"] := {x: Round(p[1]), y: Round(p[2])}
    }
    if (a.Has("size")) {
        s := a["size"]
        if (!PlayIsXY(s))
            return false
        if (s[1] < 0 || s[2] < 0)
            return false
        if (s[1] <= 0 && s[2] <= 0)
            return false
        a["size"] := {w: Round(s[1]), h: Round(s[2])}
    }
    op := 100
    if (a.Has("opacity")) {
        if (!PlayIsNumber(a["opacity"]))
            return false
        op := Round(a["opacity"])
        if (op > 100)
            op := 100
        if (op < 0)
            op := 0
    }
    a["opacity"] := op
    ; ttl：贴图后自动销毁的毫秒数；0（缺省）= 不自动销毁，由用户手动销毁；>0 = 贴图后经此毫秒后自动销毁
    ttl := 0
    if (a.Has("ttl")) {
        if (!PlayIsNumber(a["ttl"]))
            return false
        ttl := Round(a["ttl"])
        if (ttl < 0)
            ttl := 0
    }
    a["ttl"] := ttl
    ; wait：是否等待贴图窗口关闭后才继续。
    ; 语义：ttl = 0 时 wait 无意义（被忽略，始终相当于 false）；ttl > 0 时 wait 有意义，缺省 false。
    ; wait 有意义且为 true → 贴图动作在贴图窗口自动销毁（ttl 到期关闭）后才完成，否则立即完成。
    w := false
    if (a.Has("wait")) {
        if (!PlayIsBool(a["wait"]))
            return false
        w := a["wait"] ? true : false
    }
    a["wait"] := w
    return true
}

PlayValidateMedia(a, isVideo) {
    if (!a.Has("path") || !(a["path"] is String) || a["path"] = "")
        return false
    if (a.Has("start")) {
        if (!PlayValidateTime(a["start"]))
            return false
        a["start"] := PlayTimeToSeconds(a["start"])
    } else {
        a["start"] := 0
    }
    if (a.Has("end")) {
        if (!PlayValidateTime(a["end"]))
            return false
        a["end"] := PlayTimeToSeconds(a["end"])
    } else {
        a["end"] := -1
    }
    vol := 1.0
    if (a.Has("volume")) {
        if (!PlayIsNumber(a["volume"]))
            return false
        vol := a["volume"]
        if (vol < 0)
            vol := 0
    }
    a["volume"] := vol
    w := false
    if (a.Has("wait")) {
        if (!PlayIsBool(a["wait"]))
            return false
        w := a["wait"] ? true : false
    }
    a["wait"] := w
    if (isVideo) {
        if (a.Has("pos")) {
            p := a["pos"]
            if (!PlayIsXY(p))
                return false
            a["pos"] := {x: Round(p[1]), y: Round(p[2])}
        }
        if (a.Has("size")) {
            s := a["size"]
            if (!PlayIsXY(s))
                return false
            if (s[1] < 0 || s[2] < 0)
                return false
            if (s[1] <= 0 && s[2] <= 0)
                return false
            a["size"] := {w: Round(s[1]), h: Round(s[2])}
        }
        op := 100
        if (a.Has("opacity")) {
            if (!PlayIsNumber(a["opacity"]))
                return false
            op := Round(a["opacity"])
            if (op > 100)
                op := 100
            if (op < 0)
                op := 0
        }
        a["opacity"] := op
    }
    return true
}

PlayValidateSeq(a) {
    if (!a.Has("actions"))
        return false
    acts := a["actions"]
    if (!(IsObject(acts) && acts is Array))
        return false
    oneshot := false
    if (a.Has("step")) {
        if (!PlayIsBool(a["step"]))
            return false
        oneshot := !(a["step"] ? true : false)
    }
    a["oneshot"] := oneshot
    for item in acts {
        if (!PlayValidateAction(item))
            return false
    }
    return true
}

PlayValidatePar(a) {
    if (!a.Has("actions"))
        return false
    acts := a["actions"]
    if (!(IsObject(acts) && acts is Array))
        return false
    for item in acts {
        if (!PlayValidateAction(item))
            return false
    }
    return true
}

PlayValidateSleep(a) {
    if (!a.Has("duration"))
        return false
    if (!PlayValidateTime(a["duration"]))
        return false
    a["duration"] := PlayTimeToSeconds(a["duration"])
    if (a["duration"] < 0)
        return false
    return true
}

PlayValidateRun(a) {
    if (!a.Has("path") || !(a["path"] is String) || a["path"] = "")
        return false
    if (a.Has("args") && !(a["args"] is String))
        return false
    w := false
    if (a.Has("wait")) {
        if (!PlayIsBool(a["wait"]))
            return false
        w := a["wait"] ? true : false
    }
    a["wait"] := w
    h := false
    if (a.Has("hide")) {
        if (!PlayIsBool(a["hide"]))
            return false
        h := a["hide"] ? true : false
    }
    a["hide"] := h
    return true
}

PlayValidateNote(a) {
    if (!a.Has("text") || !(a["text"] is String) || a["text"] = "")
        return false
    dur := 2.5
    if (a.Has("duration")) {
        if (!PlayValidateTime(a["duration"]))
            return false
        dur := PlayTimeToSeconds(a["duration"])
    }
    if (dur < 0)
        return false
    a["duration"] := dur
    return true
}

PlayIsXY(v) {
    if (!(IsObject(v) && v is Array))
        return false
    if (v.Length != 2)
        return false
    return PlayIsNumber(v[1]) && PlayIsNumber(v[2])
}

PlayIsNumber(v) {
    return (v is Integer || v is Float)
}

PlayIsBool(v) {
    return (v is Integer && (v = 0 || v = 1))
}

PlayValidateTime(v) {
    if (PlayIsNumber(v))
        return true
    if (!(v is String))
        return false
    return PlayTimeToSeconds(v) >= 0
}

PlayTimeToSeconds(v) {
    if (PlayIsNumber(v))
        return v
    if (!(v is String))
        return -1
    s := Trim(v)
    if (RegExMatch(s, "^\d+(\.\d+)?$"))
        return Float(s)
    if (RegExMatch(s, "^\d{1,2}:\d{1,2}:\d{1,2}(\.\d+)?$")) {
        parts := StrSplit(s, ":")
        return Integer(parts[1]) * 3600 + Integer(parts[2]) * 60 + Float(parts[3])
    }
    if (RegExMatch(s, "^\d{1,2}:\d{1,2}(\.\d+)?$")) {
        parts := StrSplit(s, ":")
        return Integer(parts[1]) * 60 + Float(parts[2])
    }
    return -1
}

; ============================================================================
; 6. play 脚本 —— 纯解析 + 校验入口（无 GUI）
;    文本 → 根动作数组；失败返回 0 并把错误消息写入 errMsg。
;    宿主脚本的 PlayLoadScript() 读取文件后调用本函数，仅在失败时弹窗提示。
; ============================================================================
PlayParseScriptText(txt, &errMsg) {
    errMsg := ""
    if (SubStr(txt, 1, 1) = Chr(0xFEFF))
        txt := SubStr(txt, 2)
    root := ""
    pos := 1
    try {
        root := PlayParseValue(txt, &pos)
        PlaySkipWs(txt, &pos)
        if (pos <= StrLen(txt))
            throw Error("JSON 尾部存在多余内容")
    } catch as e {
        errMsg := "脚本 JSON 解析失败：" . e.Message
        return 0
    }
    if (!(IsObject(root) && root is Array)) {
        errMsg := "脚本格式非法：根必须是动作数组（seq）"
        return 0
    }
    for item in root {
        if (!PlayValidateAction(item)) {
            errMsg := "脚本结构校验失败：存在缺必填字段 / 类型错误 / 未知 type 的动作"
            return 0
        }
    }
    return root
}

; ============================================================================
; 7. play 脚本 —— 相对路径解析（基准 = 脚本所在目录 playScriptDir）
; ============================================================================
PlayResolvePath(p) {
    global playScriptDir
    ; URL（http/https/mailto/www. 开头）是绝对定位，不拼接脚本目录，原样返回
    if (RegExMatch(p, "i)^(https?://|mailto:|www\.)"))
        return p
    if (playScriptDir = "" || RegExMatch(p, "^[a-zA-Z]:[\\/]") || SubStr(p, 1, 1) = "\")
        return p
    return playScriptDir . "\" . p
}

PlayNum(v) {
    return Format("{:g}", v)
}

; ============================================================================
; 8. JSON 工具（用于 AI 接口）
; ============================================================================
; JSON 字符串转义（先转义反斜杠，再转义双引号、换行等）
JsonEscape(s) {
    q := Chr(34)
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, q, "\" . q)
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return s
}

; JSON 字符串值封装："<值>"
J(s) {
    return Chr(34) . JsonEscape(s) . Chr(34)
}

; JSON 字段名标记："<name>":
K(name) {
    return Chr(34) . name . Chr(34) . ":"
}

; 从 json 的 pos 位置（应为 " 开头）解析一个 JSON 字符串字面量；
; 返回解码后的字符串（失败返回 0），endPos 指向闭合引号之后
ParseJsonStringAt(json, pos, &endPos) {
    n := StrLen(json)
    if (SubStr(json, pos, 1) != Chr(34))
        return 0
    i := pos + 1
    buf := ""
    while (i <= n) {
        c := SubStr(json, i, 1)
        if (c = "\") {
            i++
            if (i > n)
                return 0
            e := SubStr(json, i, 1)
            switch e {
                case "n": buf .= "`n"
                case "r": buf .= "`r"
                case "t": buf .= "`t"
                case "b": buf .= "`b"
                case "f": buf .= "`f"
                case "/": buf .= "/"
                case Chr(34): buf .= Chr(34)
                case "\": buf .= "\"
                case "u":
                    hex := SubStr(json, i + 1, 4)
                    if (RegExMatch(hex, "^[0-9a-fA-F]{4}$")) {
                        buf .= Chr(Integer("0x" . hex))
                        i += 4
                    } else {
                        return 0    ; 非法的 \u 转义
                    }
                default:
                    return 0        ; 非法转义 → 解析失败（回退到字面量处理）
            }
            i++
        } else if (c = Chr(34)) {
            endPos := i + 1
            return buf
        } else {
            buf .= c
            i++
        }
    }
    return 0
}

; 提取 JSON 对象中某个字符串字段的值（如 "content" / "text"），找不到返回 ""
JsonFieldString(json, field) {
    marker := Chr(34) . field . Chr(34) . ":"
    n := StrLen(json)
    start := 1
    while (start <= n) {
        pos := InStr(json, marker, true, start)
        if (!pos)
            return ""
        p := pos + StrLen(marker)
        while (p <= n && InStr(" `t`r`n", SubStr(json, p, 1)))
            p++
        if (SubStr(json, p, 1) = Chr(34)) {
            val := ParseJsonStringAt(json, p, &endp)
            ; 必须用类型判断而非 `val != 0`：AHK 的 `!=` 会按数值比较，
            ; 当字段值恰为字符串 "0" 时 `"0" != 0` 为假 → 被误判为解析失败丢弃。
            if (val is String)
                return val
        }
        start := pos + 1
    }
    return ""
}

; 解析 JSON 字符串数组（如 ["a","b"]），返回字符串数组；失败返回 0
ParseJsonStringArray(text) {
    text := Trim(text, " `t`r`n")
    n := StrLen(text)
    if (SubStr(text, 1, 1) != "[")
        return 0
    result := []
    i := 2
    while (i <= n) {
        c := SubStr(text, i, 1)
        if (c = " " || c = "`t" || c = "`n" || c = "`r" || c = ",") {
            i++
            continue
        }
        if (c = "]") {
            return (result.Length > 0) ? result : 0
        }
        if (c = Chr(34)) {
            val := ParseJsonStringAt(text, i, &i)
            ; 类型判断，避免字符串 "0" 被数值比较误判为失败（0）
            if (!(val is String))
                return 0
            result.Push(val)
            continue
        }
        i++
    }
    return (result.Length > 0) ? result : 0
}

; 解析 AI 返回内容为候选字符串数组（1..N 个）
ParseCandidates(response) {
    s := Trim(response, " `t`r`n")
    ; 去除可能的 markdown 代码块围栏（``` 或 ~~~）
    f := Chr(96) . Chr(96) . Chr(96)
    p1 := InStr(s, f)
    if (p1) {
        nl := InStr(s, "`n", , p1 + 3)
        if (nl)
            cs := nl + 1
        else
            cs := p1 + 3
        p2 := InStr(s, f, , cs)
        if (p2)
            s := Trim(SubStr(s, cs, p2 - cs), " `t`r`n")
    }
    ; 若是 JSON 数组 → 解析为多个候选
    if (SubStr(s, 1, 1) = "[") {
        arr := ParseJsonStringArray(s)
        if (arr != 0)
            return arr
    }
    ; 否则整个响应作为单一候选；若被引号包裹则剥离
    if (SubStr(s, 1, 1) = Chr(34)) {
        val := ParseJsonStringAt(s, 1, &endp)
        if (val is String)
            return [val]
    }
    if (SubStr(s, 1, 1) = Chr(34) && SubStr(s, -1) = Chr(34))
        s := SubStr(s, 2, StrLen(s) - 2)
    return [s]
}

; 判断 a 是否为 b 的前缀（空字符串视为任意字符串的前缀）
IsPrefix(a, b) {
    return SubStr(b, 1, StrLen(a)) = a
}