;-----------------------------------------------
;            LaTeX收集 
;-----------------------------------------------

getLaTeXHotstring(){
    global latexHotstring
    loadHotlatex()
    return latexHotstring        
}
getTriggerFirstChar(){
    global triggerFirstChar
    loadHotlatex()
    return triggerFirstChar
}
getLaTeXHot(index){
    global latexHotstring
    loadHotlatex()

    if (index < 1){
        index := 1
    } else if (index > latexHotstring.Length()){
        index := latexHotstring.Length()
    } 
    return latexHotstring[index]         
}
getUnicode(index){
    global unicodestring 
    loadHotlatex()

    if (index < 1){
        index := 1
    } else if (index > unicodestring.Length()){
        index := unicodestring.Length()
    }
    return unicodestring[index]         
}
getLaTeXBlock(index){
    global latexblockstring 
    loadHotlatex()

    if (index < 1){
        index := 1
    } else if (index > latexblockstring.Length()){
        index := latexblockstring.Length()
    }
    return latexblockstring[index]         
}

; 模仿热字串(Hotstring)，专门用来添加热latex(Hotlatex)
; 收集热latex串，并排序（方便快速定位）
Hotlatex(key, value, block := ""){
    global latexHotstring       ; LaTex热串
    global unicodestring        ; Unicode符号 或 提示性描述
    global latexblockstring     ; LaTex块结构
    global triggerFirstChar     ; 用作触发的首字符

    ; 收集触发字符
    firstChar := SubStr(key, 1 , 1)
    newFirstChar := True
    for i_, v_ in triggerFirstChar{
        if (v_ == firstChar){
            newFirstChar := False
            Break
        }
    }
    triggerFirstChar.Push(firstChar)

    ; 默认尾部插入
    idx := latexHotstring.Length() + 1
    ; 通过字符串比较，确定正确插入位置
    for i_, v_ in latexHotstring{
        if (leStr(key, v_)){
            idx := i_
            Break
        }
    }
    latexHotstring.InsertAt(idx, key)
    unicodestring.InsertAt(idx, value)
    latexblockstring.InsertAt(idx, block)
}

; 字符串比较: ≤
; 优先长度比较，然后字典比较
leStr(str1, str2){
    if (StrLen(str1) < StrLen(str2)){
        return True
    }
    if (StrLen(str1) > StrLen(str2)){
        return False
    }
    return (str1 <= str2)
}

; 装载LaTeX热字符
loadHotlatex(){
    ; 热字符串列表
    global latexHotstring       ; LaTex热串
    global unicodestring        ; Unicode符号 或 提示性描述
    global latexblockstring     ; LaTex块结构
    global triggerFirstChar     ; 用作触发的首字符

    if (not latexHotstring){
        latexHotstring := []
        unicodestring := []
        latexblockstring := []
        triggerFirstChar := []
    }

    if (latexHotstring.Count() = 0){
        ; 下标和上标 【确保在希腊字母前面】 https://katex.org/docs/supported.html#line-breaks
        
        Hotlatex("_0", ":₀") ; 如果"值"以:开头，表明只适用于unicode模式. 【禁止“键”在“值”中出现】
        Hotlatex("^0", ":⁰")
        Hotlatex("_1", ":₁")
        Hotlatex("^1", ":¹")
        Hotlatex("_2", ":₂")
        Hotlatex("^2", ":²")
        Hotlatex("_3", ":₃")
        Hotlatex("^3", ":³")
        Hotlatex("_4", ":₄")
        Hotlatex("^4", ":⁴")
        Hotlatex("_5", ":₅")
        Hotlatex("^5", ":⁵")
        Hotlatex("_6", ":₆")
        Hotlatex("^6", ":⁶")
        Hotlatex("_7", ":₇")
        Hotlatex("^7", ":⁷")
        Hotlatex("_8", ":₈")
        Hotlatex("^8", ":⁸")
        Hotlatex("_9", ":₉")
        Hotlatex("^9", ":⁹")
        Hotlatex("_+", ":₊")
        Hotlatex("^+", ":⁺")
        Hotlatex("_-", ":₋")
        Hotlatex("^-", ":⁻")
        Hotlatex("_=", ":₌")
        Hotlatex("^=", ":⁼")
        Hotlatex("_(", ":₍")
        Hotlatex("^(", ":⁽")
        Hotlatex("_)", ":₎")
        Hotlatex("^)", ":⁾")
        Hotlatex("_a", ":ₐ")
        Hotlatex("^a", ":ᵃ")
        Hotlatex("^b", ":ᵇ")
        Hotlatex("^c", ":ᶜ")
        Hotlatex("^d", ":ᵈ")
        Hotlatex("_e", ":ₑ")
        Hotlatex("^e", ":ᵉ")
        Hotlatex("^f", ":ᶠ")
        Hotlatex("^g", ":ᵍ")
        Hotlatex("_h", ":ₕ")
        Hotlatex("^h", ":ʰ")
        Hotlatex("_i", ":ᵢ")
        Hotlatex("^i", ":ⁱ")
        Hotlatex("_j", ":ⱼ")
        Hotlatex("^j", ":ʲ")
        Hotlatex("_k", ":ₖ")
        Hotlatex("^k", ":ᵏ")
        Hotlatex("_l", ":ₗ")
        Hotlatex("^l", ":ˡ")
        Hotlatex("_m", ":ₘ")
        Hotlatex("^m", ":ᵐ")
        Hotlatex("_n", ":ₙ")
        Hotlatex("^n", ":ⁿ")
        Hotlatex("_o", ":ₒ")
        Hotlatex("^o", ":ᵒ")
        Hotlatex("_p", ":ₚ")
        Hotlatex("^p", ":ᵖ")
        Hotlatex("_r", ":ᵣ")
        Hotlatex("^r", ":ʳ")
        Hotlatex("_s", ":ₛ")
        Hotlatex("^s", ":ˢ")
        Hotlatex("_t", ":ₜ")
        Hotlatex("^t", ":ᵗ")
        Hotlatex("_u", ":ᵤ")
        Hotlatex("^u", ":ᵘ")
        Hotlatex("_v", ":ᵥ")
        Hotlatex("^v", ":ᵛ")
        Hotlatex("^w", ":ʷ")
        Hotlatex("_x", ":ₓ")
        Hotlatex("^x", ":ˣ")
        Hotlatex("^y", ":ʸ")
        Hotlatex("^z", ":ᶻ")
        Hotlatex("_\beta", ":ᵦ")
        Hotlatex("^\beta", ":ᵝ")
        Hotlatex("_\gamma", ":ᵧ")
        Hotlatex("^\gamma", ":ᵞ")
        Hotlatex("_\chi", ":ᵪ")
        Hotlatex("^\chi", ":ᵡ")
        Hotlatex("^\theta", ":ᶿ")
        Hotlatex("_\rho", ":ᵨ")
        Hotlatex("_\psi", ":ᵩ")
        Hotlatex("_\partial", ":ₔ")

        ; 分割符 https://katex.org/docs/supported.html#delimiters

        Hotlatex("\vert", "∣")
        Hotlatex("\Vert", "∥")
        Hotlatex("\|", "∥")
        Hotlatex("\lVert", "∥")
        Hotlatex("\rVert", "∥")
        Hotlatex("\langle", "⟨")
        Hotlatex("\rangle", "⟩")
        Hotlatex("\lceil", "⌈")
        Hotlatex("\rceil", "⌉")
        Hotlatex("\lfloor", "⌊")
        Hotlatex("\rfloor", "⌋")
        Hotlatex("\lmoustache", "⎰")
        Hotlatex("\rmoustache", "⎱")
        Hotlatex("\lgroup", "⟮")
        Hotlatex("\rgroup", "⟯")
        Hotlatex("\ulcorner", "┌")
        Hotlatex("\urcorner", "┐")
        Hotlatex("\llcorner", "└")
        Hotlatex("\lrcorner", "┘")
        Hotlatex("\llbracket", "⟦")
        Hotlatex("\rrbracket", "⟧")
        Hotlatex("\lBrace", "⦃")
        Hotlatex("\rBrace", "⦄")
        Hotlatex("\lang", "⟨")
        Hotlatex("\rang", "⟩")

        ; 环境 https://katex.org/docs/supported.html#delimiters
        ; 不适合ASCII码呈现，放弃

        ; 字母和unicode https://katex.org/docs/supported.html#letters-and-unicode

        ; 希腊字母")
        Hotlatex("\alpha", "α")
        Hotlatex("\Alpha", "Α")
        Hotlatex("\beta", "β")
        Hotlatex("\Beta", "Β")
        Hotlatex("\Gamma", "Γ")
        Hotlatex("\gamma", "γ")
        Hotlatex("\Delta", "Δ")
        Hotlatex("\delta", "δ")
        Hotlatex("\Epsilon", "E")
        Hotlatex("\epsilon", "ϵ")
        Hotlatex("\Zeta", "Ζ")
        Hotlatex("\zeta", "ζ")
        Hotlatex("\Eta", "Η")
        Hotlatex("\eta", "η")
        Hotlatex("\Theta", "Θ")
        Hotlatex("\theta", "θ")
        Hotlatex("\Iota", "Ι")
        Hotlatex("\iota", "ι")
        Hotlatex("\Kappa", "Κ")
        Hotlatex("\kappa", "κ")
        Hotlatex("\Lambda", "Λ")
        Hotlatex("\lambda", "λ")
        Hotlatex("\Mu", "Μ")
        Hotlatex("\mu", "μ")
        Hotlatex("\Nu", "Ν")
        Hotlatex("\nu", "ν")
        Hotlatex("\Xi", "Ξ")
        Hotlatex("\xi", "ξ")
        Hotlatex("\Omicron", "Ο")
        Hotlatex("\omicron", "ο")
        Hotlatex("\Pi", "Π")
        Hotlatex("\pi", "π")
        Hotlatex("\rho", "ρ")
        Hotlatex("\Rho", "Ρ")
        Hotlatex("\Sigma", "Σ")
        Hotlatex("\sigma", "σ")
        Hotlatex("\Tau", "Τ")
        Hotlatex("\tau", "τ")
        Hotlatex("\Upsilon", "Υ")
        Hotlatex("\upsilon", "υ")
        Hotlatex("\Phi", "Φ")
        Hotlatex("\phi", "ϕ")
        Hotlatex("\Chi", "Χ")
        Hotlatex("\chi", "χ")
        Hotlatex("\Psi", "Ψ")
        Hotlatex("\psi", "ψ")
        Hotlatex("\Omega", "Ω")
        Hotlatex("\omega", "ω")

        Hotlatex("\varGamma", "Γ")
        Hotlatex("\varDelta", "Δ")
        Hotlatex("\varTheta", "Θ")
        Hotlatex("\varLambda", "Λ")
        Hotlatex("\varXi", "Ξ")
        Hotlatex("\varPi", "Π")
        Hotlatex("\varSigma", "Σ")
        Hotlatex("\varUpsilon", "Υ")
        Hotlatex("\varPhi", "Φ")
        Hotlatex("\varPsi", "Ψ")
        Hotlatex("\varOmega", "Ω")

        Hotlatex("\varepsilon", "ε")
        Hotlatex("\varkappa", "ϰ")
        Hotlatex("\vartheta", "ϑ")
        Hotlatex("\thetasym", "ϑ")
        Hotlatex("\varpi", "ϖ")
        Hotlatex("\varrho", "ϱ")
        Hotlatex("\varsigma", "ς")
        Hotlatex("\varphi", "φ")
        Hotlatex("\digamma", "ϝ")

        ; 其它字母

        Hotlatex("\Im", "ℑ")
        Hotlatex("\Reals", "ℝ")
        Hotlatex("\OE", "Œ")
        Hotlatex("\partial", "∂")
        Hotlatex("\image", "ℑ")
        Hotlatex("\wp", "℘")
        Hotlatex("\o", "ø")
        Hotlatex("\aleph", "ℵ")
        Hotlatex("\Game", "⅁")
        Hotlatex("\Bbbkk", "𝕜")
        Hotlatex("\weierp", "℘")
        Hotlatex("\O", "Ø")
        Hotlatex("\alef", "ℵ")
        Hotlatex("\Finv", "Ⅎ")
        Hotlatex("\NN", "ℕ")
        Hotlatex("\ZZ", "ℤ")
        Hotlatex("\ss", "ß")
        Hotlatex("\alefsym", "ℵ")
        Hotlatex("\cnums", "ℂ")
        Hotlatex("\natnums", "ℕ")
        Hotlatex("\aa", "˚")
        Hotlatex("\i", "ı")
        Hotlatex("\beth", "ℶ")
        Hotlatex("\Complex", "ℂ")
        Hotlatex("\RR", "ℝ")
        Hotlatex("\A", "A˚")
        Hotlatex("\j", "ȷ")
        Hotlatex("\gimel", "ℷ")
        Hotlatex("\ell", "ℓ")
        Hotlatex("\Re", "ℜ")
        Hotlatex("\ae", "æ")
        Hotlatex("\daleth", "ℸ")
        Hotlatex("\hbar", "ℏ")
        Hotlatex("\real", "ℜ")
        Hotlatex("\AE", "Æ")
        Hotlatex("\eth", "ð")
        Hotlatex("\hslash", "ℏ")
        Hotlatex("\reals", "ℝ")
        Hotlatex("\oe", "œ")

        ; 布局 https://katex.org/docs/supported.html#layout
        ; 不适合Unicode呈现，放弃

        ; 换行符 https://katex.org/docs/supported.html#line-breaks
        ; 对Unicode没必要实现

        ; 重叠和间距 https://katex.org/docs/supported.html#overlap-and-spacing
        ; Unicode没必要实现

        ; 逻辑和集合 https://katex.org/docs/supported.html#logic-and-set-theory

        Hotlatex("\forall", "∀")
        Hotlatex("\exists", "∃")
        Hotlatex("\exist", "∃")
        Hotlatex("\nexists", "∄")
        Hotlatex("\complement", "∁")
        Hotlatex("\therefore", "∴")
        Hotlatex("\because", "∵")
        Hotlatex("\emptyset", "∅")
        Hotlatex("\empty", "∅")
        Hotlatex("\varnothing", "∅")
        Hotlatex("\neg", "¬")
        Hotlatex("\lnot", "¬")
        Hotlatex("\ni", "∋")

        ;   ⊄   ⊅  

        ; 宏 https://katex.org/docs/supported.html#macros
        ; 没必要实现

        ; 运算符 https://katex.org/docs/supported.html#operators

        ; 大运算符 https://katex.org/docs/supported.html#big-operators
        Hotlatex("\sum", "∑")
        Hotlatex("\prod", "∏")
        Hotlatex("\bigotimes", "⊗")
        Hotlatex("\bigvee", "⋁")
        Hotlatex("\int", "∫")
        Hotlatex("\intop", "∫")
        Hotlatex("\smallint", "∫")
        Hotlatex("\iint", "∬")
        Hotlatex("\iiint", "∭")
        Hotlatex("\oint", "∮")
        Hotlatex("\oiint", "∯")
        Hotlatex("\oiiint", "∰")
        Hotlatex("\coprod", "∐")
        Hotlatex("\bigoplus", "⨁")
        Hotlatex("\bigwedge", "⋀")
        Hotlatex("\bigodot", "⊙")
        Hotlatex("\bigcap", "⋂")
        Hotlatex("\biguplus", "⨄")
        Hotlatex("\bigcup", "⋃")
        Hotlatex("\bigsqcup", "⨆")

        ; 二元运算符 https://katex.org/docs/supported.html#binary-operators

        Hotlatex("\cdot", "⋅")
        Hotlatex("\cdotp", "⋅")
        Hotlatex("\gtrdot", "⋗")
        Hotlatex("\intercal", "⊺")
        Hotlatex("\centerdot", "⋅")
        Hotlatex("\land", "∧")
        Hotlatex("\rhd", "⊳")
        Hotlatex("\circ", "∘")
        Hotlatex("\leftthreetimes", "⋋")
        Hotlatex("\rightthreetimes", "⋌")
        Hotlatex("\amalg", "⨿")
        Hotlatex("\circledast", "⊛")
        Hotlatex("\ldotp", ".")
        Hotlatex("\rtimes", "⋊")
        Hotlatex("\circledcirc", "⊚")
        Hotlatex("\lor", "∨")
        Hotlatex("\ast", "∗")
        Hotlatex("\circleddash", "⊝")
        Hotlatex("\lessdot", "⋖")
        Hotlatex("\barwedge", "⊼")
        Hotlatex("\Cup", "⋓")
        Hotlatex("\lhd", "⊲")
        Hotlatex("\sqcap", "⊓")
        Hotlatex("\bigcirc", "◯")
        Hotlatex("\cup", "∪")
        Hotlatex("\ltimes", "⋉")
        Hotlatex("\sqcup", "⊔")
        Hotlatex("\curlyvee", "⋎")
        Hotlatex("\times", "×")
        Hotlatex("\boxdot", "⊡")
        Hotlatex("\curlywedge", "⋏")
        Hotlatex("\pm", "±")
        Hotlatex("\plusmn", "±")
        Hotlatex("\mp", "∓")
        Hotlatex("\unlhd", "⊴")
        Hotlatex("\boxminus", "⊟")
        Hotlatex("\div", "÷")
        Hotlatex("\odot", "⨀")
        Hotlatex("\unrhd", "⊵")
        Hotlatex("\boxplus", "⊞")
        Hotlatex("\divideontimes", "⋇")
        Hotlatex("\ominus", "⊖")
        Hotlatex("\uplus", "⊎")
        Hotlatex("\boxtimes", "⊠")
        Hotlatex("\dotplus", "∔")
        Hotlatex("\oplus", "⊕")
        Hotlatex("\vee", "∨")
        Hotlatex("\bullet", "•")
        Hotlatex("\doublebarwedge", "⩞")
        Hotlatex("\otimes", "⨂")
        Hotlatex("\veebar", "⊻")
        Hotlatex("\Cap", "⋒")
        Hotlatex("\doublecap", "⋒")
        Hotlatex("\oslash", "⊘")
        Hotlatex("\wedge", "∧")
        Hotlatex("\cap", "∩")
        Hotlatex("\doublecup", "⋓")
        Hotlatex("\wr", "≀")

        ; 分数和二项式 https://katex.org/docs/supported.html#fractions-and-binomials
        ; 没必要实现

        ; 数学运算符 https://katex.org/docs/supported.html#fractions-and-binomials
        ; 大部分没必要实现")
        Hotlatex("\sqrt", "√")
        Hotlatex("\frac", "分数 \frac{a}{b}")
        Hotlatex("\tfrac", "分数 \tfrac{a}{b}")
        Hotlatex("\genfrac", "复杂分数 \genfrac ( ] {2pt}{1}a{a+1}")
        Hotlatex("\over", "分数 {a \over b}")
        Hotlatex("\dfrac", "大分数 \dfrac{a}{b}")
        Hotlatex("\above", "粗杠分数 {a \above{2pt} b+1}")
        Hotlatex("\cfrac", "连分数 \cfrac{a}{1 + \cfrac{1}{b}}")
        Hotlatex("\binom", "组合数 \binom{n}{k}")
        Hotlatex("\dbinom", "大组合数 \dbinom{n}{k}")
        Hotlatex("\brace", "花括组合数 {n\brace k}")
        Hotlatex("\choose", "组合数 {n \choose k}")
        Hotlatex("\tbinom", "组合数 \tbinom{n}{k}")
        Hotlatex("\brack", "方括组合数 {n\brack k}")

        ; 关系 https://katex.org/docs/supported.html#relations
        ;      https://katex.org/docs/supported.html#negated-relations

        Hotlatex("\doteqdot", "≑")
        Hotlatex("\Doteq", "≑")
        Hotlatex("\lessapprox", "⪅")
        Hotlatex("\smile", "⌣")
        Hotlatex("\smallsmile", "⌣")
        Hotlatex("\eqcirc", "≖")
        Hotlatex("\lesseqgtr", "⋚")
        Hotlatex("\sqsubset", "⊏")
        Hotlatex("\lesseqqgtr", "⪋")
        Hotlatex("\sqsubseteq", "⊑")
        Hotlatex("\lessgtr", "≶")
        Hotlatex("\sqsupset", "⊐")
        Hotlatex("\approx", "≈")
        Hotlatex("\lesssim", "≲")
        Hotlatex("\sqsupseteq", "⊒")
        Hotlatex("\ll", "≪")
        Hotlatex("\Subset", "⋐")
        Hotlatex("\eqsim", "≂")
        Hotlatex("\lll", "⋘")
        Hotlatex("\subset", "⊂")
        Hotlatex("\sub", "⊂")
        Hotlatex("\approxeq", "≊")
        Hotlatex("\eqslantgtr", "⪖")
        Hotlatex("\llless", "⋘")
        Hotlatex("\subseteq", "⊆")
        Hotlatex("\sube", "⊆")
        Hotlatex("\asymp", "≍")
        Hotlatex("\eqslantless", "⪕")
        Hotlatex("\subseteqq", "⫅")
        Hotlatex("\backepsilon", "∍")
        Hotlatex("\equiv", "≡")
        Hotlatex("\mid", "∣")
        Hotlatex("\succ", "≻")
        Hotlatex("\backsim", "∽")
        Hotlatex("\fallingdotseq", "≒")
        Hotlatex("\models", "⊨")
        Hotlatex("\succapprox", "⪸")
        Hotlatex("\backsimeq", "⋍")
        Hotlatex("\frown", "⌢")
        Hotlatex("\multimap", "⊸")
        Hotlatex("\succcurlyeq", "≽")
        Hotlatex("\between", "≬")
        Hotlatex("\geq", "≥")
        Hotlatex("\ge", "≥")
        Hotlatex("\origof", "⊶")
        Hotlatex("\succeq", "⪰")
        Hotlatex("\bowtie", "⋈")
        Hotlatex("\owns", "∋")
        Hotlatex("\succsim", "≿")
        Hotlatex("\bumpeq", "≏")
        Hotlatex("\geqq", "≧")
        Hotlatex("\parallel", "∥")
        Hotlatex("\Supset", "⋑")
        Hotlatex("\Bumpeq", "≎")
        Hotlatex("\geqslant", "⩾")
        Hotlatex("\perp", "⊥")
        Hotlatex("\supset", "⊃")
        Hotlatex("\circeq", "≗")
        Hotlatex("\gg", "≫")
        Hotlatex("\pitchfork", "⋔")
        Hotlatex("\supseteq", "⊇")
        Hotlatex("\supe", "⊇")
        Hotlatex("\ggg", "⋙")
        Hotlatex("\prec", "≺")
        Hotlatex("\supseteqq", "⫆")
        Hotlatex("\gggtr", "⋙")
        Hotlatex("\precapprox", "⪷")
        Hotlatex("\thickapprox", "≈")
        Hotlatex("\preccurlyeq", "≼")
        Hotlatex("\gtrapprox", "⪆")
        Hotlatex("\preceq", "⪯")
        Hotlatex("\trianglelefteq", "⊴")
        Hotlatex("\gtreqless", "⋛")
        Hotlatex("\precsim", "≾")
        Hotlatex("\triangleq", "≜")
        Hotlatex("\gtreqqless", "⪌")
        Hotlatex("\propto", "∝")
        Hotlatex("\trianglerighteq", "⊵")
        Hotlatex("\gtrless", "≷")
        Hotlatex("\risingdotseq", "≓")
        Hotlatex("\varpropto", "∝")
        Hotlatex("\gtrsim", "≳")
        Hotlatex("\vartriangle", "△")
        Hotlatex("\cong", "≅")
        Hotlatex("\imageof", "⊷")
        Hotlatex("\shortparallel", "∥")
        Hotlatex("\vartriangleleft", "⊲")
        Hotlatex("\curlyeqprec", "⋞")
        Hotlatex("\in", "∈")
        Hotlatex("\isin", "∈")
        Hotlatex("\vartriangleright", "⊳")
        Hotlatex("\curlyeqsucc", "⋟")
        Hotlatex("\Join", "⋈")
        Hotlatex("\dashv", "⊣")
        Hotlatex("\le", "≤")
        Hotlatex("\vdash", "⊢")
        Hotlatex("\leq", "≤")
        Hotlatex("\simeq", "≃")
        Hotlatex("\vDash", "⊨")
        Hotlatex("\doteq", "≐")
        Hotlatex("\leqq", "≦")
        Hotlatex("\smallfrown", "⌢")
        Hotlatex("\Vdash", "⊩")
        Hotlatex("\leqslant", "⩽")
        Hotlatex("\Vvdash", "⊪")

        Hotlatex("\not", "≠")
        Hotlatex("\gnapprox", "⪊")
        Hotlatex("\gneq", "⪈")
        Hotlatex("\gneqq", "≩")
        Hotlatex("\gnsim", "⋧")
        Hotlatex("\gvertneqq", "≩") ; 找不到完全一致unicode，只能用最接近的替代
        Hotlatex("\lnapprox", "⪉")
        Hotlatex("\lneq", "⪇")
        Hotlatex("\lneqq", "≨")
        Hotlatex("\lnsim", "⋦")
        Hotlatex("\lvertneqq", "≨") ; 找不到完全一致unicode，只能用最接近的替代
        Hotlatex("\ncong", "≆")
        Hotlatex("\ne", "≠")
        Hotlatex("\neq", "≠")
        Hotlatex("\ngeq", "≱")
        ;Hotlatex("\ngeqq", "≧̸") ; 有问题？ https://52unicode.com/combining-diacritical-marks-zifu
        ;Hotlatex("\ngeqslant", "⩾̸") ; 有问题？ https://52unicode.com/combining-diacritical-marks-zifu
        Hotlatex("\ngtr", "≯")
        Hotlatex("\nleq", "≰")
        ;Hotlatex("\nleqq", "≦") ; 有问题？ https://52unicode.com/combining-diacritical-marks-zifu
        ;Hotlatex("\nleqslant", "̸⩽") ; 有问题？ https://52unicode.com/combining-diacritical-marks-zifu
        Hotlatex("\nless", "≮")
        Hotlatex("\nmid", "∤")
        Hotlatex("\notin", "∉")
        Hotlatex("\notni", "∌")
        Hotlatex("\nparallel", "∦")
        Hotlatex("\nprec", "⊀")
        Hotlatex("\npreceq", "⋠")
        Hotlatex("\nshortmid", "∤")
        Hotlatex("\nshortparallel", "∦")
        Hotlatex("\nsim", "≁")
        Hotlatex("\nsubseteq", "⊈")
        ;Hotlatex("\nsubseteqq", "̸⫅") ; 有问题？ https://52unicode.com/combining-diacritical-marks-zifu
        Hotlatex("\nsucc", "⊁")
        Hotlatex("\nsucceq", "⋡")
        Hotlatex("\nsupseteq", "⊉")
        ;Hotlatex("\nsupseteqq", "̸⫆") ; 有问题？ https://52unicode.com/combining-diacritical-marks-zifu
        Hotlatex("\ntriangleleft", "⋪")
        Hotlatex("\ntrianglelefteq", "⋬")
        Hotlatex("\ntriangleright", "⋫")
        Hotlatex("\ntrianglerighteq", "⋭")
        Hotlatex("\nvdash", "⊬")
        Hotlatex("\nvDash", "⊭")
        Hotlatex("\nVDash", "⊯")
        Hotlatex("\nVdash", "⊮")
        Hotlatex("\precnapprox", "⪹")
        Hotlatex("\precneqq", "⪵")
        Hotlatex("\precnsim", "⋨")
        Hotlatex("\subsetneq", "⊊")
        Hotlatex("\subsetneqq", "⫋")
        Hotlatex("\succnapprox", "⪺")
        Hotlatex("\succneqq", "⪶")
        Hotlatex("\succnsim", "⋩")
        Hotlatex("\supsetneq", "⊋")
        Hotlatex("\supsetneqq", "⫌")
        Hotlatex("\varsubsetneq", "⊊") ; 找不到完全一致unicode，只能用最接近的替代
        Hotlatex("\varsubsetneqq", "⫋") ; 找不到完全一致unicode，只能用最接近的替代
        Hotlatex("\varsupsetneq", "⊋") ; 找不到完全一致unicode，只能用最接近的替代
        Hotlatex("\varsupsetneqq", "⫌") ; 找不到完全一致unicode，只能用最接近的替代

        ; 箭头 https://katex.org/docs/supported.html#arrows

        Hotlatex("\circlearrowleft", "↺")
        Hotlatex("\circlearrowright", "↻")
        Hotlatex("\curvearrowleft", "↶")
        Hotlatex("\curvearrowright", "↷")
        Hotlatex("\Darr", "⇓")
        Hotlatex("\dArr", "⇓")
        Hotlatex("\darr", "↓")
        Hotlatex("\dashleftarrow", "⇠")
        Hotlatex("\dashrightarrow", "⇢")
        Hotlatex("\downarrow", "↓")
        Hotlatex("\Downarrow", "⇓")
        Hotlatex("\downdownarrows", "⇊")
        Hotlatex("\downharpoonleft", "⇃")
        Hotlatex("\downharpoonright", "⇂")
        Hotlatex("\gets", "←")
        Hotlatex("\Harr", "⇔")
        Hotlatex("\hArr", "⇔")
        Hotlatex("\harr", "↔")
        Hotlatex("\hookleftarrow", "↩")
        Hotlatex("\hookrightarrow", "↪")
        Hotlatex("\iff", "⟺")
        Hotlatex("\impliedby", "⟸")
        Hotlatex("\implies", "⟹")
        Hotlatex("\Larr", "⇐")
        Hotlatex("\lArr", "⇐")
        Hotlatex("\larr", "←")
        Hotlatex("\leadsto", "⇝")
        Hotlatex("\leftarrow", "←")
        Hotlatex("\Leftarrow", "⇐")
        Hotlatex("\leftarrowtail", "↢")
        Hotlatex("\leftharpoondown", "↽")
        Hotlatex("\leftharpoonup", "↼")
        Hotlatex("\leftleftarrows", "⇇")
        Hotlatex("\leftrightarrow", "↔")
        Hotlatex("\Leftrightarrow", "⇔")
        Hotlatex("\leftrightarrows", "⇆")
        Hotlatex("\leftrightharpoons", "⇋")
        Hotlatex("\leftrightsquigarrow", "↭")
        Hotlatex("\Lleftarrow", "⇚")
        Hotlatex("\longleftarrow", "⟵")
        Hotlatex("\Longleftarrow", "⟸")
        Hotlatex("\longleftrightarrow", "⟷")
        Hotlatex("\Longleftrightarrow", "⟺")
        Hotlatex("\longmapsto", "⟼")
        Hotlatex("\longrightarrow", "⟶")
        Hotlatex("\Longrightarrow", "⟹")
        Hotlatex("\looparrowleft", "↫")
        Hotlatex("\looparrowright", "↬")
        Hotlatex("\Lrarr", "⇔")
        Hotlatex("\lrArr", "⇔")
        Hotlatex("\lrarr", "↔")
        Hotlatex("\Lsh", "↰")
        Hotlatex("\mapsto", "↦")
        Hotlatex("\nearrow", "↗")
        Hotlatex("\nleftarrow", "↚")
        Hotlatex("\nLeftarrow", "⇍")
        Hotlatex("\nleftrightarrow", "↮")
        Hotlatex("\nLeftrightarrow", "⇎")
        Hotlatex("\nrightarrow", "↛")
        Hotlatex("\nRightarrow", "⇏")
        Hotlatex("\nwarrow", "↖")
        Hotlatex("\Rarr", "⇒")
        Hotlatex("\rArr", "⇒")
        Hotlatex("\rarr", "→")
        Hotlatex("\restriction", "↾")
        Hotlatex("\rightarrow", "→")
        Hotlatex("\Rightarrow", "⇒")
        Hotlatex("\rightarrowtail", "↣")
        Hotlatex("\rightharpoondown", "⇁")
        Hotlatex("\rightharpoonup", "⇀")
        Hotlatex("\rightleftarrows", "⇄")
        Hotlatex("\rightleftharpoons", "⇌")
        Hotlatex("\rightrightarrows", "⇉")
        Hotlatex("\rightsquigarrow", "⇝")
        Hotlatex("\Rrightarrow", "⇛")
        Hotlatex("\Rsh", "↱")
        Hotlatex("\searrow", "↘")
        Hotlatex("\swarrow", "↙")
        Hotlatex("\to", "→")
        Hotlatex("\twoheadleftarrow", "↞")
        Hotlatex("\twoheadrightarrow", "↠")
        Hotlatex("\Uarr", "⇑")
        Hotlatex("\uArr", "⇑")
        Hotlatex("\uarr", "↑")
        Hotlatex("\uparrow", "↑")
        Hotlatex("\Uparrow", "⇑")
        Hotlatex("\updownarrow", "↕")
        Hotlatex("\Updownarrow", "⇕")
        Hotlatex("\upharpoonleft", "↿")
        Hotlatex("\upharpoonright", "↾")
        Hotlatex("\upuparrows", "⇈")

        ; 其它常用符号 https://katex.org/docs/supported.html#symbols-and-punctuation

        Hotlatex("\backprime", "‵")
        Hotlatex("\prime", "′")
        Hotlatex("\blacklozenge", "⧫")
        Hotlatex("\P", "¶")
        Hotlatex("\S", "§")
        Hotlatex("\sect", "§")
        Hotlatex("\copyright", "©")
        Hotlatex("\circledR", "®")
        Hotlatex("\circledS", "Ⓢ")
        Hotlatex("\dots", "…")
        Hotlatex("\cdots", "⋯")
        Hotlatex("\ddots", "⋱")
        Hotlatex("\ldots", "…")
        Hotlatex("\vdots", "⋮")
        Hotlatex("\dotsb", "⋯")
        Hotlatex("\dotsc", "…")
        Hotlatex("\dotsi", "⋯")
        Hotlatex("\dotsm", "⋯")
        Hotlatex("\dotso", "…")
        Hotlatex("\sdot", "⋅")
        Hotlatex("\mathellipsis", "…")
        Hotlatex("\textellipsis", "…")
        Hotlatex("\Box", "□")
        Hotlatex("\square", "□")
        Hotlatex("\blacksquare", "■")
        Hotlatex("\triangle", "△")
        Hotlatex("\triangledown", "▽")
        Hotlatex("\triangleleft", "◃")
        Hotlatex("\triangleright", "▹")
        Hotlatex("\bigtriangledown", "▽")
        Hotlatex("\bigtriangleup", "△")
        Hotlatex("\blacktriangle", "▲")
        Hotlatex("\blacktriangledown", "▼")
        Hotlatex("\blacktriangleleft", "◀")
        Hotlatex("\blacktriangleright", "▶")
        Hotlatex("\diamond", "⋄")
        Hotlatex("\Diamond", "◊")
        Hotlatex("\lozenge", "◊")
        Hotlatex("\star", "⋆")
        Hotlatex("\bigstar", "★")
        Hotlatex("\clubsuit", "♣")
        Hotlatex("\clubs", "♣")
        Hotlatex("\diamondsuit", "♢")
        Hotlatex("\diamonds", "♢")
        Hotlatex("\spadesuit", "♠")
        Hotlatex("\maltese", "✠")
        Hotlatex("\nabla", "∇")
        Hotlatex("\infty", "∞")
        Hotlatex("\infin", "∞")
        Hotlatex("\checkmark", "✓")
        Hotlatex("\dag", "†")
        Hotlatex("\dagger", "†")
        Hotlatex("\ddag", "‡")
        Hotlatex("\ddagger", "‡")
        Hotlatex("\Dagger", "‡")
        Hotlatex("\angle", "∠")
        Hotlatex("\measuredangle", "∡")
        Hotlatex("\sphericalangle", "∢")
        Hotlatex("\top", "⊤")
        Hotlatex("\bot", "⊥")
        Hotlatex("\pounds", "£")
        Hotlatex("\mathsterling", "£")
        Hotlatex("\yen", "¥")
        Hotlatex("\surd", "√")
        Hotlatex("\degree", "°")
        Hotlatex("\mho", "℧")
        Hotlatex("\flat", "♭")
        Hotlatex("\natural", "♮")
        Hotlatex("\sharp", "♯")
        Hotlatex("\heartsuit", "♡")
        Hotlatex("\hearts", "♡")
        Hotlatex("\spades", "♠")
        Hotlatex("\minuso", "⦵")

        
        ; 重音符  https://katex.org/docs/supported.html#accents
        ; https://52unicode.com/combining-diacritical-marks-zifu
        
        Hotlatex("\hat", "̂")  ;   R\hat[Tab]  -> R̂
        ;Hotlatex("\^", "̂")  ;   R\^[Tab]  -> R̂    有冲突，不能用
        Hotlatex("\dot", "̇")  ;   R\dot[Tab]  -> Ṙ
        Hotlatex("\.", "̇")  ;   R\.[Tab]  -> Ṙ
        Hotlatex("\ddot", "̈") ;   R\ddot[Tab]  -> R̈
        Hotlatex("\""", "̈") ;   R\"[Tab]  -> R̈  
        Hotlatex("\tilde", "̃") ;   R\tilde[Tab]  -> R̃
        Hotlatex("\~", "̃") ;   R\~[Tab]  -> R̃
        Hotlatex("\bar", "̄") ;   R\bar[Tab]  -> R̄ 
        ;Hotlatex("\`=", "̄") ;   R\=[Tab]  -> R̄ 有问题？？
        Hotlatex("\mathring", "ͦ") ;   R\mathring[Tab]  -> Rͦ
        Hotlatex("\r", "ͦ") ;   R\r[Tab]  -> Rͦ
        Hotlatex("\acute", "́") ;   R\acute[Tab]  -> Ŕ
        Hotlatex("\'", "́") ;   R\'[Tab]  -> Ŕ
        Hotlatex("\vec", "上短箭头 \vec{F}") ;   R\vec[Tab]  -> R   找不到对应的可显示的unicode符号， 所以只能在latex助手模式中使用
        Hotlatex("\breve", "̆") ;   R\breve[Tab]  -> R̆
        Hotlatex("\u", "̆") ;   R\u[Tab]  -> R̆
        Hotlatex("\check", "̌") ;   R\check[Tab]  -> Ř
        Hotlatex("\v", "̌") ;   R\v[Tab]  -> Ř
        Hotlatex("\grave", "̀") ;   R\grave[Tab]  -> R̀
        Hotlatex("\``", "̀") ;   R\`[Tab]  -> R̀ 
        Hotlatex("\underbar", "̲") ;   R\underbar[Tab]  -> R̲
        Hotlatex("\H", "̋") ;   R\H[Tab]  -> R̋

        Hotlatex("\widetilde", "上宽波浪 \widetilde{ac}")
        Hotlatex("\overgroup", "上宽括号 \overgroup{AB}")
        Hotlatex("\utilde", "下宽波浪 \utilde{AB}")
        Hotlatex("\undergroup", "下宽括号 \undergroup{AB}")
        Hotlatex("\Overrightarrow", "上宽右箭头 \Overrightarrow{AB}")
        Hotlatex("\overleftarrow", "上宽左箭头 \overleftarrow{AB}")
        Hotlatex("\overrightarrow", "上宽右箭头 \overrightarrow{AB}")
        Hotlatex("\underleftarrow", "下宽左箭头 \underleftarrow{AB}")
        Hotlatex("\underrightarrow", "下宽右箭头 \underrightarrow{AB}")
        Hotlatex("\overleftharpoon", "上宽左半箭头 \overleftharpoon{ac}")
        Hotlatex("\overrightharpoon", "上宽右半箭头 \overrightharpoon{ac}")
        Hotlatex("\overleftrightarrow", "上宽双箭头 \overleftrightarrow{AB}")
        Hotlatex("\overbrace", "上宽花括号 \overbrace{AB}")
        Hotlatex("\underleftrightarrow", "下宽双箭头 \underleftrightarrow{AB}")
        Hotlatex("\underbrace", "下宽花括号 \underbrace{AB}")
        Hotlatex("\overline", "上宽横杠 \overline{AB}")
        Hotlatex("\overlinesegment", "上宽线段 \overlinesegment{AB}")
        Hotlatex("\underline", "下宽横杠 \underline{AB}")
        Hotlatex("\underlinesegment", "下宽线段 \underlinesegment{AB}")
        Hotlatex("\widehat", "上宽帽 \widehat{ac}")
        Hotlatex("\widecheck", "上宽倒帽 \widecheck{ac}")

        ; Unicode数学斜体符号
        ; 字体 https://katex.org/docs/supported.html#style-color-size-and-font

        Hotlatex("\mathrm", "罗马正体 \mathrm{R}")
        Hotlatex("\mathbf", "正粗体 \mathbf{R}")
        Hotlatex("\mathit", "意大利斜体 ℝ \mathit{R}")
        Hotlatex("\mathnormal", "默认字体 \mathnormal{R}")
        Hotlatex("\textbf", "正粗体 \textbf{R}")
        Hotlatex("\textit", "意大利斜体 \textit{R}")
        Hotlatex("\textrm", "罗马正体 ℝ \textrm{R}")
        Hotlatex("\bf", "正粗体 \bf R")
        Hotlatex("\it", "意大利斜体 \it R")
        Hotlatex("\rm", "罗马正体 \rm R")
        Hotlatex("\bold", "加粗 \bold{R}")
        Hotlatex("\textup", "直立文本 \textup{R}")
        Hotlatex("\textnormal", "默认字体 \textnormal{R}")
        Hotlatex("\boldsymbol", "加粗斜体 \boldsymbol{R}")
        Hotlatex("\Bbb", "黑板粗体 ℝ \Bbb{R}")
        Hotlatex("\text", "等宽字体 \text{R}")
        Hotlatex("\bm", "加粗 \bm{R}")
        Hotlatex("\mathsf", "无衬线字体 \mathsf{R}")
        Hotlatex("\textmd", "中等权重 \textmd{R}")
        Hotlatex("\frak", "哥特体 ℜ \frak{R}")
        Hotlatex("\textsf", "无衬线字体 \textsf{R}")
        Hotlatex("\mathtt", "等宽字体 \mathtt{R}")
        Hotlatex("\sf", "无衬线字体 \sf R")
        Hotlatex("\texttt", "等宽字体 \texttt{R}")
        Hotlatex("\tt", "等宽字体 \tt R")
        Hotlatex("\cal", "手写体 𝓡 \cal R")
        Hotlatex("\mathscr", " 花体 \mathscr{R}")

        ; \mathbb{x}  用 \mathbbx 代替
        Hotlatex("\mathbb", "黑板粗体 ℝ \mathbb{R}") ; 如果“键”在“值”中出现，表明只适用于latex助手模式. 【禁止“值”以:开头】
        Hotlatex("\mathbba", ":𝕒") ; 如果"值"以:开头，表明只适用于unicode模式. 【禁止“键”在“值”中出现】
        Hotlatex("\mathbbA", ":𝔸")
        Hotlatex("\mathbbb", ":𝕓")
        Hotlatex("\mathbbB", ":𝔹")
        Hotlatex("\mathbbc", ":𝕔")
        Hotlatex("\mathbbC", ":ℂ")
        Hotlatex("\mathbbd", ":𝕕")
        Hotlatex("\mathbbD", ":𝔻")
        Hotlatex("\mathbbe", ":𝕖")
        Hotlatex("\mathbbE", ":𝔼")
        Hotlatex("\mathbbf", ":𝕗")
        Hotlatex("\mathbbF", ":𝔽")
        Hotlatex("\mathbbg", ":𝕘")
        Hotlatex("\mathbbG", ":𝔾")
        Hotlatex("\mathbbh", ":𝕙")
        Hotlatex("\mathbbH", ":ℍ")
        Hotlatex("\mathbbi", ":𝕚")
        Hotlatex("\mathbbI", ":𝕀")
        Hotlatex("\mathbbj", ":𝕛")
        Hotlatex("\mathbbJ", ":𝕁")
        Hotlatex("\mathbbk", ":𝕜")
        Hotlatex("\mathbbK", ":𝕂")
        Hotlatex("\mathbbl", ":𝕝")
        Hotlatex("\mathbbL", ":𝕃")
        Hotlatex("\mathbbm", ":𝕞")
        Hotlatex("\mathbbM", ":𝕄")
        Hotlatex("\mathbbn", ":𝕟")
        Hotlatex("\mathbbN", ":ℕ")
        Hotlatex("\mathbbo", ":𝕠")
        Hotlatex("\mathbbO", ":𝕆")
        Hotlatex("\mathbbp", ":𝕡")
        Hotlatex("\mathbbP", ":ℙ")
        Hotlatex("\mathbbq", ":𝕢")
        Hotlatex("\mathbbQ", ":ℚ")
        Hotlatex("\mathbbr", ":𝕣")
        Hotlatex("\mathbbR", ":ℝ")
        Hotlatex("\mathbbs", ":𝕤")
        Hotlatex("\mathbbS", ":𝕊")
        Hotlatex("\mathbbt", ":𝕥")
        Hotlatex("\mathbbT", ":𝕋")
        Hotlatex("\mathbbu", ":𝕦")
        Hotlatex("\mathbbU", ":𝕌")
        Hotlatex("\mathbbv", ":𝕧")
        Hotlatex("\mathbbV", ":𝕍")
        Hotlatex("\mathbbw", ":𝕨")
        Hotlatex("\mathbbW", ":𝕎")
        Hotlatex("\mathbbx", ":𝕩")
        Hotlatex("\mathbbX", ":𝕏")
        Hotlatex("\mathbby", ":𝕪")
        Hotlatex("\mathbbY", ":𝕐")
        Hotlatex("\mathbbz", ":𝕫")
        Hotlatex("\mathbbZ", ":ℤ")

        Hotlatex("\mathbb0", ":𝟘")
        Hotlatex("\mathbb1", ":𝟙")
        Hotlatex("\mathbb2", ":𝟚")
        Hotlatex("\mathbb3", ":𝟛")
        Hotlatex("\mathbb4", ":𝟜")
        Hotlatex("\mathbb5", ":𝟝")
        Hotlatex("\mathbb6", ":𝟞")
        Hotlatex("\mathbb7", ":𝟟")
        Hotlatex("\mathbb8", ":𝟠")
        Hotlatex("\mathbb9", ":𝟡")

        ; \mathfrak{x}  用 \mathfrakx 代替
        Hotlatex("\mathfrak", "哥特体 ℜ \mathfrak{R}") 
        Hotlatex("\mathfraka", ":𝔞")
        Hotlatex("\mathfrakA", ":𝔄")
        Hotlatex("\mathfrakb", ":𝔟")
        Hotlatex("\mathfrakB", ":𝔅")
        Hotlatex("\mathfrakc", ":𝔠")
        Hotlatex("\mathfrakC", ":ℭ")
        Hotlatex("\mathfrakd", ":𝔡")
        Hotlatex("\mathfrakD", ":𝔇")
        Hotlatex("\mathfrake", ":𝔢")
        Hotlatex("\mathfrakE", ":𝔈")
        Hotlatex("\mathfrakf", ":𝔣")
        Hotlatex("\mathfrakF", ":𝔉")
        Hotlatex("\mathfrakg", ":𝔤")
        Hotlatex("\mathfrakG", ":𝔊")
        Hotlatex("\mathfrakh", ":𝔥")
        Hotlatex("\mathfrakH", ":ℌ")
        Hotlatex("\mathfraki", ":𝔦")
        Hotlatex("\mathfrakI", ":ℑ")
        Hotlatex("\mathfrakj", ":𝔧")
        Hotlatex("\mathfrakJ", ":𝔍")
        Hotlatex("\mathfrakk", ":𝔨")
        Hotlatex("\mathfrakK", ":𝔎")
        Hotlatex("\mathfrakl", ":𝔩")
        Hotlatex("\mathfrakL", ":𝔏")
        Hotlatex("\mathfrakm", ":𝔪")
        Hotlatex("\mathfrakM", ":𝔐")
        Hotlatex("\mathfrakn", ":𝔫")
        Hotlatex("\mathfrakN", ":𝔑")
        Hotlatex("\mathfrako", ":𝔬")
        Hotlatex("\mathfrakO", ":𝔒")
        Hotlatex("\mathfrakp", ":𝔭")
        Hotlatex("\mathfrakP", ":𝔓")
        Hotlatex("\mathfrakq", ":𝔮")
        Hotlatex("\mathfrakQ", ":𝔔")
        Hotlatex("\mathfrakr", ":𝔯")
        Hotlatex("\mathfrakR", ":ℜ")
        Hotlatex("\mathfraks", ":𝔰")
        Hotlatex("\mathfrakS", ":𝔖")
        Hotlatex("\mathfrakt", ":𝔱")
        Hotlatex("\mathfrakT", ":𝔗")
        Hotlatex("\mathfraku", ":𝔲")
        Hotlatex("\mathfrakU", ":𝔘")
        Hotlatex("\mathfrakv", ":𝔳")
        Hotlatex("\mathfrakV", ":𝔙")
        Hotlatex("\mathfrakw", ":𝔴")
        Hotlatex("\mathfrakW", ":𝔚")
        Hotlatex("\mathfrakx", ":𝔵")
        Hotlatex("\mathfrakX", ":𝔛")
        Hotlatex("\mathfraky", ":𝔶")
        Hotlatex("\mathfrakY", ":𝔜")
        Hotlatex("\mathfrakz", ":𝔷")
        Hotlatex("\mathfrakZ", ":ℨ")

        ; \mathcal{x}  用 \mathcalx 代替
        Hotlatex("\mathcal", "手写体 𝓡 \mathcal{R}") 
        Hotlatex("\mathcala", ":𝓪")
        Hotlatex("\mathcalA", ":𝓐")
        Hotlatex("\mathcalb", ":𝓫")
        Hotlatex("\mathcalB", ":𝓑")
        Hotlatex("\mathcalc", ":𝓬")
        Hotlatex("\mathcalC", ":𝓒")
        Hotlatex("\mathcald", ":𝓭")
        Hotlatex("\mathcalD", ":𝓓")
        Hotlatex("\mathcale", ":𝓮")
        Hotlatex("\mathcalE", ":𝓔")
        Hotlatex("\mathcalf", ":𝓯")
        Hotlatex("\mathcalF", ":𝓕")
        Hotlatex("\mathcalg", ":𝓰")
        Hotlatex("\mathcalG", ":𝓖")
        Hotlatex("\mathcalh", ":𝓱")
        Hotlatex("\mathcalH", ":𝓗")
        Hotlatex("\mathcali", ":𝓲")
        Hotlatex("\mathcalI", ":𝓘")
        Hotlatex("\mathcalj", ":𝓳")
        Hotlatex("\mathcalJ", ":𝓙")
        Hotlatex("\mathcalk", ":𝓴")
        Hotlatex("\mathcalK", ":𝓚")
        Hotlatex("\mathcall", ":𝓵")
        Hotlatex("\mathcalL", ":𝓛")
        Hotlatex("\mathcalm", ":𝓶")
        Hotlatex("\mathcalM", ":𝓜")
        Hotlatex("\mathcaln", ":𝓷")
        Hotlatex("\mathcalN", ":𝓝")
        Hotlatex("\mathcalo", ":𝓸")
        Hotlatex("\mathcalO", ":𝓞")
        Hotlatex("\mathcalp", ":𝓹")
        Hotlatex("\mathcalP", ":𝓟")
        Hotlatex("\mathcalq", ":𝓺")
        Hotlatex("\mathcalQ", ":𝓠")
        Hotlatex("\mathcalr", ":𝓻")
        Hotlatex("\mathcalR", ":𝓡")
        Hotlatex("\mathcals", ":𝓼")
        Hotlatex("\mathcalS", ":𝓢")
        Hotlatex("\mathcalt", ":𝓽")
        Hotlatex("\mathcalT", ":𝓣")
        Hotlatex("\mathcalu", ":𝓾")
        Hotlatex("\mathcalU", ":𝓤")
        Hotlatex("\mathcalv", ":𝓿")
        Hotlatex("\mathcalV", ":𝓥")
        Hotlatex("\mathcalw", ":𝔀")
        Hotlatex("\mathcalW", ":𝓦")
        Hotlatex("\mathcalx", ":𝔁")
        Hotlatex("\mathcalX", ":𝓧")
        Hotlatex("\mathcaly", ":𝔂")
        Hotlatex("\mathcalY", ":𝓨")
        Hotlatex("\mathcalz", ":𝔃")
        Hotlatex("\mathcalZ", ":𝓩")  

        ; 批注
        Hotlatex("\cancel", "右斜删除符 \cancel{5}")  
        Hotlatex("\bcancel", "左斜删除符 \bcancel{5}")  
        Hotlatex("\xcancel", "叉删除符 \xcancel{ABC}")  
        Hotlatex("\sout", "横删除符 \sout{abc}")  
        Hotlatex("\boxed", "方框符 \boxed{\pi=\frac c d}")  
        Hotlatex("\angl", "直角标记 \angl n")  
        Hotlatex("\angln", "直角标记 \angln")  
        Hotlatex("\phase", "角度标记 \phase{-78^\circ}")  

        ; 垂直布局
        Hotlatex("\stackrel", "上标记 \stackrel{!}{=}")  
        Hotlatex("\overset", "上标记 \overset{!}{=}")  
        Hotlatex("\underset", "下标记 \underset{!}{=}")  
        Hotlatex("\atop", "上下布局 a \atop b") 

        ; Environments
        ; https://katex.org/docs/supported.html#environments

        Hotlatex("\array", "数组 \begin{array} ..."
            ,"{Text}\begin{array}{cc} a & b \\ c & d \end{array}##{Left 25}")
        Hotlatex("\subarray", "上下标数组 \begin{subarray}{l} ..."
            ,"{Text}\begin{subarray}{l} i \\ j \end{subarray}##{Left 20}")
        Hotlatex("\arraystretch", "表格数组 \def\arraystretch{1.5} ..."
            ,"{Text}\def\arraystretch{1.5}\begin{array}{c:c:c} a & b & c \\ \hline d & e & f \\ \hdashline g & h & i \end{array}##{Left 64}")
        Hotlatex("\matrix", "无定界矩阵 \begin{matrix} ..."
            ,"{Text}\begin{matrix} a & b \\ c & d \end{matrix}##{Left 26}")
        Hotlatex("\pmatrix", "圆括号矩阵 \begin{pmatrix} ..."
            ,"{Text}\begin{pmatrix} a & b \\ c & d \end{pmatrix}##{Left 27}")
        Hotlatex("\bmatrix", "方括号矩阵 \begin{bmatrix} ..."
            ,"{Text}\begin{bmatrix} a & b \\ c & d \end{bmatrix}##{Left 27}")
        Hotlatex("\vmatrix", "竖括号矩阵&行列式 \begin{vmatrix} ..."
            ,"{Text}\begin{vmatrix} a & b \\ c & d \end{vmatrix}##{Left 27}")
        Hotlatex("\Vmatrix", "双竖括号矩阵&行列式 \begin{Vmatrix} ..."
            ,"{Text}\begin{Vmatrix} a & b \\ c & d \end{Vmatrix}##{Left 27}")
        Hotlatex("\Bmatrix", "花括号矩阵 \begin{Bmatrix} ..."
            ,"{Text}\begin{Bmatrix} a & b \\ c & d \end{Bmatrix}##{Left 27}")
        Hotlatex("\cases", "左条件分支 \begin{cases} ..."
            ,"{Text}\begin{cases} a &\text{if } b \\ c &\text{if } d \end{cases}##{Left 45}")
        Hotlatex("\rcases", "右条件分支 begin{rcases} ..."
            ,"{Text}\begin{rcases} a &\text{if } b \\ c &\text{if } d \end{rcases}##{Left 46}")
        Hotlatex("\align", "对齐 begin{align} ..."
            ,"{Text}\begin{align} a&=b+c \\ d+e&=f \end{align}##{Left 27}")
        Hotlatex("\alignat", "紧凑对齐 begin{alignat} ..."
            ,"{Text}\begin{alignat}{1} 10&x+&3&y=2\\ 3&x+&13&y=4 \end{alignat}##{Left 37}")
        Hotlatex("\gather", "居中对齐 begin{gather} ..."
            ,"{Text}\begin{gather} a=b \\ e=b+c \end{gather}##{Left 24}")  
    }
}