; ----------------------------------------------
; 参考Katex，尽可能使用latex触发出对应的unicode字符
;
; https://katex.org/docs/supported.html
; 
; 只对不方便键盘输入的字符进行latex[TAB]替换， 如果没有替换说明输入错误或不支持
;
; 只支持单字符的latex触发（目前支持如下6类）
;    1.下标   _n[TAB]             ₙ   【下标触发】
;    2.上标   ^n[TAB]             ⁿ   【上标触发】
;    3.单字符  \alpha[TAB]         α   【单字符触发】
;    4.字体     \mathbbR[TAB]       ℝ   【空心字符触发】
;    4.字体     \mathfrakR[TAB]     ℜ   【Fraktur字符触发】
;    4.字体     \mathcalR[TAB]      𝓡   【花体字符触发】  
;    5.组合     R\[组合字符][TAB] 比如R\dot[TAB]          R̂   【组合字符触发】
;    6.片段搜索     \[片断字符串][TAB]       【搜索字符触发】
;
;           1) \后如果输入少于2个字符，可能是前面11类情况之一， 直接触发
;           2) 如果完全匹配，就是前面11类情况之一， 直接触发
;           3) 如果不完全匹配，但只有唯一匹配， 直接触发
;           4) 如果不完全匹配，并且不唯一，弹出菜单选择触发
;           5) 如果不匹配，不做任何处理  
; 
;  可用`Win + \`  进行 unicode模式 / latex助手模式 切换  【会有1s后消失的提示】
;       unicode模式:   输出的结果是unicode字符，比如 ⨁
;       latex助手模式: 如果输入正确的或完全不正确，没有任何反应
;                     如果输入的正确的片段（不完全正确），会弹出菜单，选择输入，比如: \bigoplus
; ----------------------------------------------
; 模块注册。   据此可实现模块之间的相互调用
FileEncoding , UTF-8
global modules := {}

; latex2unicode模块注册
modules["latex2unicode"] := True
; 加载热latex
loadHotlatex()
Return

;------------------------------------------------------------------------------------------
;  latex热键收集      
;------------------------------------------------------------------------------------------

; 模仿热字串(Hotstring)，专门用来添加热latex(Hotlatex)
; 收集热latex串，并排序（方便快速定位）
Hotlatex(key, value)
{
    global latexHotstring
    global unicodestring

    ; 默认尾部插入
    idx := latexHotstring.Length() + 1
    ; 通过字符串比较，确定正确插入位置
    for i_, v_ in latexHotstring
    {
        if (leStr(key, v_))
        {
            idx := i_
            Break
        }
    }
    latexHotstring.InsertAt(idx, key)
    unicodestring.InsertAt(idx, Value)
}

; 字符串比较: ≤
; 优先长度比较，然后字典比较
leStr(str1, str2)
{
    if (StrLen(str1) < StrLen(str2))
        return True
    if (StrLen(str1) > StrLen(str2))
        return False
    return (str1 <= str2)
}

; 装载LaTeX热字符
loadHotlatex()
{
    ; 默认1: 对应unicode模式;  0: 对应latex助手模式
    global latexMode := 1
    ; 热字符串列表 （由于关联数组的键不区分大小写，所以改用两个数组）
    global latexHotstring
    global unicodestring

    if not latexHotstring
    {
        latexHotstring := []
        unicodestring := []
    }

    if (latexHotstring.Count() = 0)
    {
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
    }
}

;------------------------------------------------------------------------------------------------------
;        latex热键处理 (完全用Input接管)
;------------------------------------------------------------------------------------------------------
; 按下\键，等候输入，然后tab，可能出现如下4种情况
;     1) \后如果输入少于2个字符，尝试完全匹配，否则无任何变化
;     2) 如果完全匹配 或 不完全但唯一匹配，会自动替换成:  unicode（unicode模式） 
;                                                  或 正确的latex代码（latex助手模式）
;     3) 如果不完全且不唯一匹配，会弹出菜单选择替换，替换的结果是: unicode字符（unicode模式）
;                                                          或 正确的latex代码（latex助手模式）
;     4) 如果不匹配，不做任何处理
;
;  可用`Win + \`  进行 unicode模式 / latex助手模式 切换  【会有1s后消失的提示】
;       unicode模式:   输出的结果是unicode字符，比如 ⨁
;       latex助手模式: 如果输入正确的或完全不正确，没有任何反应
;                     如果输入的正确的片段（不完全正确），会弹出菜单，选择输入，比如: \bigoplus
;------------------------------------------------------------------------------------------------------
HotlatexHandler(prefix)
{
    global latexMode

    ; 如果已经加载im_switch模块，支持在中文输入状态下直接输入，会自动切换倒英文状态
    if modules["im_switch"] and (getImState() = 1)
    {
        Send ^{Space}{bs 2}{text}%prefix%
        setImState(0)
        IMToolTip()
    }

    ;--------------------------------------------
    ;        首先解决 _ \ ^  组合的相互干扰问题
    ;--------------------------------------------

    ; 按次序记录prefix 和 search，防止类似 “_\” 的组合相互干扰
    global  prefixs
    global  searchs
    global  indexPrefix
    global  lastErrorLevel

    ; 比如: 如果输入“_abc\efg”, _先等候输入， \后等候输入
    if (not prefixs)
    {
        prefixs := []
        indexPrefix := 0
    }
    prefixs.Push(prefix)
    indexPrefix := indexPrefix + 1
    
    ; 等候输入
    Input, search, V C , {tab}{space}{enter}{esc}{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}{Up}{Down}{Home}{End}{PgUp}{PgDn}{CapsLock}{NumLock}{PrintScreen}{Pause}
    if (not lastErrorLevel)
        lastErrorLevel := ErrorLevel

    ; 比如: 前面输入“_abc\efg”, 然后tab, _先处理efg， 后处理abc\
    ; 后处理的插前面，确保和prefixs对应
    if not searchs
        searchs := []
    searchs.InsertAt(1, search)

    if (indexPrefix > 1) and (prefixs[indexPrefix] == prefix)
    {
        ; 忽略后续触发，同时确保了searchs完全填充
        indexPrefix := indexPrefix - 1
        return
    }

    ; 拼凑成完整的待处理字符串
    search := prefixs[1]
    for index, value in searchs
        search := search "" value

    ; 确定最后一个前缀-搜索对（一定会匹配）
    regStr := "O)([_\^\\]+)([^_\^\\]*)$"
    if (latexMode == 0)
        ; latex助手模式下，禁用 _ \ ^  组合
        regStr := "O)([_\^\\])([^_\^\\]*)$"
    RegExMatch(search, regStr, SubPat)
    prefix := SubPat.Value(1)
    search := SubPat.Value(2)

    ; 清空全局变量
    prefixs := []
    searchs := []
    indexPrefix := 0
    ; 非tab终止符触发，表示放弃
    if (lastErrorLevel != "EndKey:tab")
    {
        lastErrorLevel := ""
        return
    }
    lastErrorLevel := ""

    ;--------------------------------------------
    ;        下面是正式的逻辑流程
    ;--------------------------------------------
    global latexHotstring
    global unicodestring

    ; 需要删除的字符数:  前缀数 + 输入字符数 + `t字符数
    n := StrLen(prefix) + StrLen(search) + 1

    flag := False ; 默认是不完全匹配模式
    ; 如果输入的字符数小于2然后[tab]，则要求完全匹配（防止菜单过长）
    if (n < StrLen(prefix) + 2 + 1)
        flag := True

    ; 搜索匹配
    matches := []
    for index, value in latexHotstring
    {         
        key := value
        value := unicodestring[index]

        if (latexMode == 1) and InStr(value, key)
            ; Hotlatex("\mathbb", "黑板粗体 ℝ \mathbb{R}")
            ; 如果“键”在“值”中出现，表明只适用于latex助手模式. 【禁止“值”以:开头】
            Continue

        if (latexMode == 0) and (SubStr(value, 1, 1) == ":")
            ; Hotlatex("\mathbba", ":𝕒") 
            ; 如果"值"以:开头，表明只适用于unicode模式. 【禁止“键”在“值”中出现】
            Continue
        
        ; 剔除额外标记“:”
        value := LTrim(value, ":")

        ; 如果是完全匹配，跳过字符数过大的部分（基于已排序的情况）
        if flag and (StrLen(key) > n-1)
            Break
        
        if  (SubStr(key, 1, StrLen(prefix)) == prefix) and InStr(key, search) 
        {
            if (search == SubStr(key, StrLen(prefix)+1)) 
            {
                if (Not flag)
                {
                    ; 进入完全匹配模式
                    matches := []
                    flag := True
                }    
                ; 收集完全匹配的热LaTeX
                matches.Push(key "=" value)
            }else if (Not flag) {
                ; 在不完全匹配模式下，才能收集不完全匹配的热LaTeX
                matches.Push(key "=" value)
            }
        }    
    }

    ; 唯一匹配（可能是完全匹配，也可能是不完全匹配）
    if (matches.Length() == 1)
    {
        if flag and (latexMode==0)
        {
            ; latex助手模式下的完全匹配， 只需要退1格复原
            Send, {bs}
        } else {
            ; 由于是唯一匹配，直接替换即可
            ; unicdoe模式选择等号右边输出； latex助手模式选择等号左边输出
            value := StrSplit(matches[1], "=")[latexMode+1]
            Send, {bs %n%}%value%
        }
        return
    } 

    ; 不唯一匹配（肯定是不完全匹配，需要弹出菜单，通过选择进行替换）
    if (matches.Length() > 1)
    {
        ; 弹出菜单
        for index, value in matches
        {
            ; 发现问题: 添加的菜单项不区分大小写，比如: a A 只能作为同一个菜单项。
            ; 解决方案: 加序号前缀
            itemName := index " : " value
            Menu, HotMenu, Add, %itemName%, MenuHandler
        }
        Send, {bs %n%}
        Sleep 30 ; 延迟30毫秒，确保弹出窗口前退格完成（似乎没有同步发送的API，只能这样）
        Menu, HotMenu, Show
        return
    }

    ; 不匹配， 只需要退1格复原
    Send, {bs}
}

MenuHandler:    ; 菜单选择处理
; 剔除序号前缀
idx := InStr(A_ThisMenuItem, ":")+2
value := SubStr(A_ThisMenuItem, idx)
; unicdoe模式选择等号右边输出； latex助手模式选择等号左边输出
value := StrSplit(value, "=")[latexMode+1]
Send, %value%
Menu, HotMenu, DeleteAll
return

; ~ 表示触发热键时, 热键中按键原有的功能不会被屏蔽(对操作系统隐藏) 
~\::    ; latex命令热键
HotlatexHandler("\")
return
~+6::   ; 上标热键 Shift+6(+6 或 ^) 
HotlatexHandler("^")
return
~+-::   ; 下标热键 Shift+-(+- 或 _) 
HotlatexHandler("_")
return

;-----------------------------------------------------------------------------
;    `Win + \`  进行 unicode模式 / latex助手模式 切换
;-----------------------------------------------------------------------------

#\::    ; 模式切换热键
global latexMode
latexMode := Mod(latexMode+1,2)
if (latexMode=1)
    ToolTip, unicode模式
else
    ToolTip, latex助手模式
SetTimer, RemoveLatexToolTip, -1000
return

RemoveLatexToolTip:    ; 删除当前模式提示
ToolTip
return

