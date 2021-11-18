; ----------------------------------------------
; 参考Katex，尽可能使用latex触发出对应的unicode字符
;
; https://katex.org/docs/supported.html
; 
; 只对不方便键盘输入的字符进行latex[TAB]替换， 如果没有替换说明输入错误或不支持
;
; 只支持单字符的latex触发（目前支持如下11类）
;    _n[TAB]             ₙ   【下标触发】
;    ^n[TAB]             ⁿ   【上标触发】
;    \alpha[TAB]         α   【单字符触发】
;    \mathbbR[TAB]       ℝ   【空心字符触发】
;    \mathfrakR[TAB]     ℜ   【Fraktur字符触发】
;    \mathcalR[TAB]      𝓡   【花体字符触发】
;    \hatR[TAB]          R̂   【戴帽字符触发】
;    \dotR[TAB]          Ṙ   【上单点字符触发】
;    \ddotR[TAB]         R̈   【上双点字符触发】
;    \tildeR[TAB]        R͂   【波浪字符触发】
;    \barR[TAB]          R̄   【上横杠字符触发】
; ----------------------------------------------

; 下标和上标 【确保在希腊字母前面】 https://katex.org/docs/supported.html#line-breaks

:c*?:_0`t::₀  ; *表示不需要终止符(即空格, 句点或回车)来触发热字串， 另外指定Tab(`t)作为终止符；
;               ?表示即使此热字串在另一个单词中也会被触发。
;               c表示区分大小写: 当您输入缩写时, 它必须准确匹配脚本中定义的大小写形式
:c*?:^0`t::⁰
:c*?:_1`t::₁
:c*?:_1`t::¹
:c*?:_2`t::₂
:c*?:^2`t::²
:c*?:_3`t::₃
:c*?:^3`t::³
:c*?:_4`t::₄
:c*?:^4`t::⁴
:c*?:_5`t::₅
:c*?:^5`t::⁵
:c*?:_6`t::₆
:c*?:^6`t::⁶
:c*?:_7`t::₇
:c*?:^7`t::⁷
:c*?:_8`t::₈
:c*?:^8`t::⁸
:c*?:_9`t::₉
:c*?:^9`t::⁹
:c*?:_+`t::₊
:c*?:^+`t::⁺
:c*?:_-`t::₋
:c*?:^-`t::⁻
:c*?:_=`t::₌
:c*?:^=`t::⁼
:c*?:_(`t::₍
:c*?:^(`t::⁽
:c*?:_)`t::₎
:c*?:^)`t::⁾
:c*?:_0`t::ₐ
:c*?:^a`t::ᵃ
:c*?:^b`t::ᵇ
:c*?:^c`t::ᶜ
:c*?:^d`t::ᵈ
:c*?:_e`t::ₑ
:c*?:^e`t::ᵉ
:c*?:^f`t::ᶠ
:c*?:^g`t::ᵍ
:c*?:_h`t::ₕ
:c*?:^h`t::ʰ
:c*?:_i`t::ᵢ
:c*?:^i`t::ⁱ
:c*?:_j`t::ⱼ
:c*?:^j`t::ʲ
:c*?:_k`t::ₖ
:c*?:^k`t::ᵏ
:c*?:_l`t::ₗ
:c*?:^l`t::ˡ
:c*?:_m`t::ₘ
:c*?:^m`t::ᵐ
:c*?:_n`t::ₙ
:c*?:^n`t::ⁿ
:c*?:_o`t::ₒ
:c*?:^o`t::ᵒ
:c*?:_p`t::ₚ
:c*?:^p`t::ᵖ
:c*?:_r`t::ᵣ
:c*?:^r`t::ʳ
:c*?:_s`t::ₛ
:c*?:^s`t::ˢ
:c*?:_t`t::ₜ
:c*?:^t`t::ᵗ
:c*?:_u`t::ᵤ
:c*?:^u`t::ᵘ
:c*?:_v`t::ᵥ
:c*?:^v`t::ᵛ
:c*?:^w`t::ʷ
:c*?:_x`t::ₓ
:c*?:^x`t::ˣ
:c*?:^y`t::ʸ
:c*?:^z`t::ᶻ
:c*?:_\beta`t::ᵦ
:c*?:^\beta`t::ᵝ
:c*?:_\gamma`t::ᵧ
:c*?:^\gamma`t::ᵞ
:c*?:_\chi`t::ᵪ
:c*?:^\chi`t::ᵡ
:c*?:^\theta`t::ᶿ
:c*?:_\rho`t::ᵨ
:c*?:_\psi`t::ᵩ

; 定界符 https://katex.org/docs/supported.html#delimiters

:c*?:\vert`t::∣
:c*?:\Vert`t::∥
:c*?:\|`t::∥
:c*?:\lVert`t::∥
:c*?:\rVert`t::∥
:c*?:\langle`t::⟨
:c*?:\rangle`t::⟩
:c*?:\lceil`t::⌈
:c*?:\rceil`t::⌉
:c*?:\lfloor`t::⌊
:c*?:\rfloor`t::⌋
:c*?:\lmoustache`t::⎰
:c*?:\rmoustache`t::⎱
:c*?:\lgroup`t::⟮
:c*?:\rgroup`t::⟯
:c*?:\ulcorner`t::┌
:c*?:\urcorner`t::┐
:c*?:\llcorner`t::└
:c*?:\lrcorner`t::┘
:c*?:\llbracket`t::⟦
:c*?:\rrbracket`t::⟧
:c*?:\lBrace`t::⦃
:c*?:\rBrace`t::⦄

:c*?:\lang`t::⟨
:c*?:\rang`t::⟩

; 环境 https://katex.org/docs/supported.html#delimiters
; 不适合ASCII码呈现，放弃

; 字母和unicode https://katex.org/docs/supported.html#letters-and-unicode

; 希腊字母
:c*?:\alpha`t::α
:c*?:\Alpha`t::Α
:c*?:\beta`t::β
:c*?:\Beta`t::Β
:c*?:\Gamma`t::Γ
:c*?:\gamma`t::γ
:c*?:\Delta`t::Δ
:c*?:\delta`t::δ
:c*?:\Epsilon`t::E
:c*?:\epsilon`t::ϵ
:c*?:\Zeta`t::Ζ
:c*?:\zeta`t::ζ
:c*?:\Eta`t::Η
:c*?:\eta`t::η
:c*?:\Theta`t::Θ
:c*?:\theta`t::θ
:c*?:\Iota`t::Ι
:c*?:\iota`t::ι
:c*?:\Kappa`t::Κ
:c*?:\kappa`t::κ
:c*?:\Lambda`t::Λ
:c*?:\lambda`t::λ
:c*?:\Mu`t::Μ
:c*?:\mu`t::μ
:c*?:\Nu`t::Ν
:c*?:\nu`t::ν
:c*?:\Xi`t::Ξ
:c*?:\xi`t::ξ
:c*?:\Omicron`t::Ο
:c*?:\omicron`t::ο
:c*?:\Pi`t::Π
:c*?:\pi`t::π
:c*?:\rho`t::ρ
:c*?:\Rho`t::Ρ
:c*?:\Sigma`t::Σ
:c*?:\sigma`t::σ
:c*?:\Tau`t::Τ
:c*?:\tau`t::τ
:c*?:\Upsilon`t::Υ
:c*?:\upsilon`t::υ
:c*?:\Phi`t::Φ
:c*?:\phi`t::ϕ
:c*?:\Chi`t::Χ
:c*?:\chi`t::χ
:c*?:\Psi`t::Ψ
:c*?:\psi`t::ψ
:c*?:\Omega`t::Ω
:c*?:\omega`t::ω

:c*?:\varGamma`t::Γ
:c*?:\varDelta`t::Δ
:c*?:\varTheta`t::Θ
:c*?:\varLambda`t::Λ
:c*?:\varXi`t::Ξ
:c*?:\varPi`t::Π
:c*?:\varSigma`t::Σ
:c*?:\varUpsilon`t::Υ
:c*?:\varPhi`t::Φ
:c*?:\varPsi`t::Ψ
:c*?:\varOmega`t::Ω

:c*?:\varepsilon`t::ε
:c*?:\varkappa`t::ϰ
:c*?:\vartheta`t::ϑ
:c*?:\thetasym`t::ϑ
:c*?:\varpi`t::ϖ
:c*?:\varrho`t::ϱ
:c*?:\varsigma`t::ς
:c*?:\varphi`t::φ
:c*?:\digamma`t::ϝ

; 其它字母

:c*?:\Im`t::ℑ
:c*?:\Reals`t::ℝ
:c*?:\OE`t::Œ
:c*?:\partial`t::∂
:c*?:\image`t::ℑ
:c*?:\wp`t::℘
:c*?:\o`t::ø
:c*?:\aleph`t::ℵ
:c*?:\Game`t::⅁
:c*?:\Bbbkk`t::𝕜
:c*?:\weierp`t::℘
:c*?:\O`t::Ø
:c*?:\alef`t::ℵ
:c*?:\Finv`t::Ⅎ
:c*?:\NN`t::ℕ
:c*?:\ZZ`t::ℤ
:c*?:\ss`t::ß
:c*?:\alefsym`t::ℵ
:c*?:\cnums`t::ℂ
:c*?:\natnums`t::ℕ
:c*?:\aa`t::˚ 
:c*?:\i`t::ı
:c*?:\beth`t::ℶ
:c*?:\Complex`t::ℂ
:c*?:\RR`t::ℝ
:c*?:\A`t::A˚
:c*?:\j`t::ȷ
:c*?:\gimel`t::ℷ
:c*?:\ell`t::ℓ
:c*?:\Re`t::ℜ
:c*?:\ae`t::æ
:c*?:\daleth`t::ℸ
:c*?:\hbar`t::ℏ
:c*?:\real`t::ℜ
:c*?:\AE`t::Æ
:c*?:\eth`t::ð
:c*?:\hslash`t::ℏ
:c*?:\reals`t::ℝ
:c*?:\oe`t::œ

; 布局 https://katex.org/docs/supported.html#layout
; 不适合Unicode呈现，放弃

; 换行符 https://katex.org/docs/supported.html#line-breaks
; 对Unicode没必要实现

; 重叠和间距 https://katex.org/docs/supported.html#overlap-and-spacing
; Unicode没必要实现

; 逻辑和集合 https://katex.org/docs/supported.html#logic-and-set-theory

:c*?:\forall`t::∀
:c*?:\exists`t::∃
:c*?:\exist`t::∃
:c*?:\nexists`t::∄
:c*?:\complement`t::∁
:c*?:\therefore`t::∴
:c*?:\because`t::∵
:c*?:\emptyset`t::∅
:c*?:\empty`t::∅
:c*?:\varnothing`t::∅
:c*?:\nsubseteq`t::⊈
:c*?:\nsupseteq`t::⊉
:c*?:\neg`t::¬
:c*?:\lnot`t::¬
:c*?:\notin`t::∉
:c*?:\ni`t::∋
:c*?:\notni`t::∌

;   ⊄   ⊅  ⊊ ⊋
;   ⊤ ⊥ 
; □ ⊨ ⊢

; 宏 https://katex.org/docs/supported.html#macros
; 没必要实现

; 运算符 https://katex.org/docs/supported.html#operators

; 大运算符 https://katex.org/docs/supported.html#big-operators
:c*?:\sum`t::∑
:c*?:\prod`t::∏
:c*?:\bigotimes`t::⊗
:c*?:\bigvee`t::⋁
:c*?:\int`t::∫
:c*?:\intop`t::∫
:c*?:\smallint`t::∫
:c*?:\iint`t::∬
:c*?:\iiint`t::∭
:c*?:\oint`t::∮
:c*?:\oiint`t::∯
:c*?:\oiiint`t::∰
:c*?:\coprod`t::∐
:c*?:\bigoplus`t::⨁
:c*?:\bigwedge`t::⋀
:c*?:\bigodot`t::⊙
:c*?:\bigcap`t::⋂
:c*?:\biguplus`t::⨄
:c*?:\bigcup`t::⋃
:c*?:\bigsqcup`t::⨆

; 二元运算符 https://katex.org/docs/supported.html#binary-operators

:c*?:\cdot`t::⋅
:c*?:\cdotp`t::⋅
:c*?:\gtrdot`t::⋗
:c*?:\intercal`t::⊺
:c*?:\centerdot`t::⋅
:c*?:\land`t::∧
:c*?:\rhd`t::⊳
:c*?:\circ`t::∘
:c*?:\leftthreetimes`t::⋋
:c*?:\rightthreetimes`t::⋌
:c*?:\amalg`t::⨿
:c*?:\circledast`t::⊛
:c*?:\ldotp`t::.
:c*?:\rtimes`t::⋊
:c*?:\circledcirc`t::⊚
:c*?:\lor`t::∨
:c*?:\ast`t::∗
:c*?:\circleddash`t::⊝
:c*?:\lessdot`t::⋖
:c*?:\barwedge`t::⊼
:c*?:\Cup`t::⋓
:c*?:\lhd`t::⊲
:c*?:\sqcap`t::⊓
:c*?:\bigcirc`t::◯
:c*?:\cup`t::∪
:c*?:\ltimes`t::⋉
:c*?:\sqcup`t::⊔
:c*?:\curlyvee`t::⋎
:c*?:\times`t::×
:c*?:\boxdot`t::⊡
:c*?:\curlywedge`t::⋏
:c*?:\pm`t::±
:c*?:\plusmn`t::±
:c*?:\mp`t::∓
:c*?:\unlhd`t::⊴
:c*?:\boxminus`t::⊟
:c*?:\div`t::÷
:c*?:\odot`t::⨀
:c*?:\unrhd`t::⊵
:c*?:\boxplus`t::⊞
:c*?:\divideontimes`t::⋇
:c*?:\ominus`t::⊖
:c*?:\uplus`t::⊎
:c*?:\boxtimes`t::⊠
:c*?:\dotplus`t::∔
:c*?:\oplus`t::⊕
:c*?:\vee`t::∨
:c*?:\bullet`t::•
:c*?:\doublebarwedge`t::⩞
:c*?:\otimes`t::⨂
:c*?:\veebar`t::⊻
:c*?:\Cap`t::⋒
:c*?:\doublecap`t::⋒
:c*?:\oslash`t::⊘
:c*?:\wedge`t::∧
:c*?:\cap`t::∩
:c*?:\doublecup`t::⋓
:c*?:\wr`t::≀

; 分数和二项式 https://katex.org/docs/supported.html#fractions-and-binomials
; 没必要实现

; 数学运算符 https://katex.org/docs/supported.html#fractions-and-binomials
; 大部分没必要实现
:c*?:\sqrt`t::√

; 关系 https://katex.org/docs/supported.html#relations
;      https://katex.org/docs/supported.html#negated-relations

:c*?:\neq`t::≠
:c*?:\lneqq`t::≨
:c*?:\gneqq`t::≩
:c*?:\doteqdot`t::≑
:c*?:\Doteq`t::≑	
:c*?:\lessapprox`t::⪅
:c*?:\smile`t::⌣
:c*?:\smallsmile`t::⌣
:c*?:\eqcirc`t::≖
:c*?:\lesseqgtr`t::⋚
:c*?:\sqsubset`t::⊏
:c*?:\lesseqqgtr`t::⪋
:c*?:\sqsubseteq`t::⊑
:c*?:\lessgtr`t::≶
:c*?:\sqsupset`t::⊐
:c*?:\approx`t::≈
:c*?:\lesssim`t::≲
:c*?:\sqsupseteq`t::⊒
:c*?:\ll`t::≪
:c*?:\Subset`t::⋐
:c*?:\eqsim`t::≂
:c*?:\lll`t::⋘
:c*?:\subset`t::⊂
:c*?:\sub`t::⊂
:c*?:\approxeq`t::≊
:c*?:\eqslantgtr`t::⪖
:c*?:\llless`t::⋘
:c*?:\subseteq`t::⊆
:c*?:\sube`t::⊆
:c*?:\asymp`t::≍
:c*?:\eqslantless`t::⪕
:c*?:\subseteqq`t::⫅
:c*?:\backepsilon`t::∍
:c*?:\equiv`t::≡
:c*?:\mid`t::∣
:c*?:\succ`t::≻
:c*?:\backsim`t::∽
:c*?:\fallingdotseq`t::≒
:c*?:\models`t::⊨
:c*?:\succapprox`t::⪸
:c*?:\backsimeq`t::⋍
:c*?:\frown`t::⌢
:c*?:\multimap`t::⊸
:c*?:\succcurlyeq`t::≽
:c*?:\between`t::≬
:c*?:\geq`t::≥
:c*?:\ge`t::≥
:c*?:\origof`t::⊶
:c*?:\succeq`t::⪰
:c*?:\bowtie`t::⋈
:c*?:\owns`t::∋
:c*?:\succsim`t::≿
:c*?:\bumpeq`t::≏
:c*?:\geqq`t::≧
:c*?:\parallel`t::∥
:c*?:\Supset`t::⋑
:c*?:\Bumpeq`t::≎
:c*?:\geqslant`t::⩾
:c*?:\perp`t::⊥
:c*?:\supset`t::⊃
:c*?:\circeq`t::≗
:c*?:\gg`t::≫
:c*?:\pitchfork`t::⋔
:c*?:\supseteq`t::⊇
:c*?:\supe`t::⊇
:c*?:\ggg`t::⋙
:c*?:\prec`t::≺
:c*?:\supseteqq`t::⫆
:c*?:\gggtr`t::⋙
:c*?:\precapprox`t::⪷
:c*?:\thickapprox`t::≈
:c*?:\preccurlyeq`t::≼
:c*?:\gtrapprox`t::⪆
:c*?:\preceq`t::⪯
:c*?:\trianglelefteq`t::⊴
:c*?:\gtreqless`t::⋛
:c*?:\precsim`t::≾
:c*?:\triangleq`t::≜
:c*?:\gtreqqless`t::⪌
:c*?:\propto`t::∝
:c*?:\trianglerighteq`t::⊵
:c*?:\gtrless`t::≷
:c*?:\risingdotseq`t::≓
:c*?:\varpropto`t::∝
:c*?:\gtrsim`t::≳
:c*?:\vartriangle`t::△
:c*?:\cong`t::≅
:c*?:\imageof`t::⊷
:c*?:\shortparallel`t::∥
:c*?:\vartriangleleft`t::⊲
:c*?:\curlyeqprec`t::⋞
:c*?:\in`t::∈
:c*?:\isin`t::∈
:c*?:\vartriangleright`t::⊳
:c*?:\curlyeqsucc`t::⋟
:c*?:\Join`t::⋈
:c*?:\dashv`t::⊣
:c*?:\le`t::≤
:c*?:\vdash`t::⊢
:c*?:\leq`t::≤
:c*?:\simeq`t::≃
:c*?:\vDash`t::⊨
:c*?:\doteq`t::≐
:c*?:\leqq`t::≦
:c*?:\smallfrown`t::⌢
:c*?:\Vdash`t::⊩
:c*?:\leqslant`t::⩽
:c*?:\Vvdash`t::⊪

; 箭头 https://katex.org/docs/supported.html#arrows

:c*?:\circlearrowleft`t::↺
:c*?:\circlearrowright`t::↻
:c*?:\curvearrowleft`t::↶
:c*?:\curvearrowright`t::↷
:c*?:\Darr`t::⇓
:c*?:\dArr`t::⇓
:c*?:\darr`t::↓
:c*?:\dashleftarrow`t::⇠
:c*?:\dashrightarrow`t::⇢
:c*?:\downarrow`t::↓
:c*?:\Downarrow`t::⇓
:c*?:\downdownarrows`t::⇊
:c*?:\downharpoonleft`t::⇃
:c*?:\downharpoonright`t::⇂
:c*?:\gets`t::←
:c*?:\Harr`t::⇔
:c*?:\hArr`t::⇔
:c*?:\harr`t::↔
:c*?:\hookleftarrow`t::↩
:c*?:\hookrightarrow`t::↪
:c*?:\iff`t::⟺
:c*?:\impliedby`t::⟸
:c*?:\implies`t::⟹
:c*?:\Larr`t::⇐
:c*?:\lArr`t::⇐
:c*?:\larr`t::←
:c*?:\leadsto`t::⇝
:c*?:\leftarrow`t::←
:c*?:\Leftarrow`t::⇐
:c*?:\leftarrowtail`t::↢
:c*?:\leftharpoondown`t::↽
:c*?:\leftharpoonup`t::↼
:c*?:\leftleftarrows`t::⇇
:c*?:\leftrightarrow`t::↔
:c*?:\Leftrightarrow`t::⇔
:c*?:\leftrightarrows`t::⇆
:c*?:\leftrightharpoons`t::⇋
:c*?:\leftrightsquigarrow`t::↭
:c*?:\Lleftarrow`t::⇚
:c*?:\longleftarrow`t::⟵
:c*?:\Longleftarrow`t::⟸
:c*?:\longleftrightarrow`t::⟷
:c*?:\Longleftrightarrow`t::⟺
:c*?:\longmapsto`t::⟼
:c*?:\longrightarrow`t::⟶
:c*?:\Longrightarrow`t::⟹
:c*?:\looparrowleft`t::↫
:c*?:\looparrowright`t::↬
:c*?:\Lrarr`t::⇔
:c*?:\lrArr`t::⇔
:c*?:\lrarr`t::↔
:c*?:\Lsh`t::↰
:c*?:\mapsto`t::↦
:c*?:\nearrow`t::↗
:c*?:\nleftarrow`t::↚
:c*?:\nLeftarrow`t::⇍
:c*?:\nleftrightarrow`t::↮ 
:c*?:\nLeftrightarrow`t::⇎
:c*?:\nrightarrow`t::↛
:c*?:\nRightarrow`t::⇏
:c*?:\nwarrow`t::↖
:c*?:\Rarr`t::⇒
:c*?:\rArr`t::⇒
:c*?:\rarr`t::→
:c*?:\restriction`t::↾
:c*?:\rightarrow`t::→
:c*?:\Rightarrow`t::⇒
:c*?:\rightarrowtail`t::↣
:c*?:\rightharpoondown`t::⇁
:c*?:\rightharpoonup`t::⇀
:c*?:\rightleftarrows`t::⇄
:c*?:\rightleftharpoons`t::⇌
:c*?:\rightrightarrows`t::⇉
:c*?:\rightsquigarrow`t::⇝
:c*?:\Rrightarrow`t::⇛
:c*?:\Rsh`t::↱
:c*?:\searrow`t::↘
:c*?:\swarrow`t::↙
:c*?:\to`t::→
:c*?:\twoheadleftarrow`t::↞
:c*?:\twoheadrightarrow`t::↠
:c*?:\Uarr`t::⇑
:c*?:\uArr`t::⇑
:c*?:\uarr`t::↑
:c*?:\uparrow`t::↑
:c*?:\Uparrow`t::⇑
:c*?:\updownarrow`t::↕
:c*?:\Updownarrow`t::⇕
:c*?:\upharpoonleft`t::↿
:c*?:\upharpoonright`t::↾
:c*?:\upuparrows`t::⇈

; 其它常用符号 https://katex.org/docs/supported.html#symbols-and-punctuation

:c*?:\backprime`t::‵	
:c*?:\prime`t::′	
:c*?:\blacklozenge`t::⧫	
:c*?:\P`t::¶	
:c*?:\S`t::§	
:c*?:\sect`t::§	
:c*?:\copyright`t::©
:c*?:\circledR`t::®	
:c*?:\circledS`t::Ⓢ
:c*?:\dots`t::…
:c*?:\cdots`t::⋯
:c*?:\ddots`t::⋱
:c*?:\ldots`t::…
:c*?:\vdots`t::⋮
:c*?:\dotsb`t::⋯
:c*?:\dotsc`t::…
:c*?:\dotsi`t::⋯
:c*?:\dotsm`t::⋯
:c*?:\dotso`t::…
:c*?:\sdot`t::⋅
:c*?:\mathellipsis`t::…
:c*?:\textellipsis`t::…
:c*?:\Box`t::□
:c*?:\square`t::□
:c*?:\blacksquare`t::■
:c*?:\triangle`t::△
:c*?:\triangledown`t::▽
:c*?:\triangleleft`t::◃
:c*?:\triangleright`t::▹
:c*?:\bigtriangledown`t::▽
:c*?:\bigtriangleup`t::△
:c*?:\blacktriangle`t::▲
:c*?:\blacktriangledown`t::▼
:c*?:\blacktriangleleft`t::◀
:c*?:\blacktriangleright`t::▶
:c*?:\diamond`t::⋄
:c*?:\Diamond`t::◊
:c*?:\lozenge`t::◊
:c*?:\star`t::⋆
:c*?:\bigstar`t::★
:c*?:\clubsuit`t::♣
:c*?:\clubs`t::♣
:c*?:\diamondsuit`t::♢
:c*?:\diamonds`t::♢
:c*?:\spadesuit`t::♠
:c*?:\maltese`t::✠
:c*?:\nabla`t::∇
:c*?:\infty`t::∞
:c*?:\infin`t::∞
:c*?:\checkmark`t::✓
:c*?:\dag`t::†
:c*?:\dagger`t::†
:c*?:\ddag`t::‡
:c*?:\ddagger`t::‡
:c*?:\Dagger`t::‡
:c*?:\angle`t::∠
:c*?:\measuredangle`t::∡
:c*?:\sphericalangle`t::∢
:c*?:\top`t::⊤
:c*?:\bot`t::⊥
:c*?:\pounds`t::£
:c*?:\mathsterling`t::£
:c*?:\yen`t::¥
:c*?:\surd`t::√
:c*?:\degree`t::°
:c*?:\mho`t::℧
:c*?:\flat`t::♭
:c*?:\natural`t::♮
:c*?:\sharp`t::♯
:c*?:\heartsuit`t::♡
:c*?:\hearts`t::♡
:c*?:\spades`t::♠
:c*?:\minuso`t::⦵

;∤  ∦ ♯


; Unicode数学斜体符号
; 有待处理
;Item	Range	Item	Range
;Bold	\text{𝐀-𝐙 𝐚-𝐳 𝟎-𝟗}A-Z a-z 0-9	Double-struck	\text{𝔸-}ℤ\ 𝕜A-Z k
;Italic	\text{𝐴-𝑍 𝑎-𝑧}A-Z a-z	Sans serif	\text{𝖠-𝖹 𝖺-𝗓 𝟢-𝟫}A-Z a-z 0-9
;Bold Italic	\text{𝑨-𝒁 𝒂-𝒛}A-Z a-z	Sans serif bold	\text{𝗔-𝗭 𝗮-𝘇 𝟬-𝟵}A-Z a-z 0-9
;Script	\text{𝒜-𝒵}A-Z	Sans serif italic	\text{𝘈-𝘡 𝘢-𝘻}A-Z a-z
;	Monospace	\text{𝙰-𝚉 𝚊-𝚣 𝟶-𝟿}A-Z a-z 0-9

; Unicode
; 有待处理

; 字体

; \mathbb{x}  用 \mathbbx 代替
:c*?:\mathbba`t::𝕒
:c*?:\mathbbA`t::𝔸
:c*?:\mathbbb`t::𝕓
:c*?:\mathbbB`t::𝔹
:c*?:\mathbbc`t::𝕔
:c*?:\mathbbC`t::ℂ
:c*?:\mathbbd`t::𝕕
:c*?:\mathbbD`t::𝔻
:c*?:\mathbbe`t::𝕖
:c*?:\mathbbE`t::𝔼
:c*?:\mathbbf`t::𝕗
:c*?:\mathbbF`t::𝔽
:c*?:\mathbbg`t::𝕘
:c*?:\mathbbG`t::𝔾
:c*?:\mathbbh`t::𝕙
:c*?:\mathbbH`t::ℍ
:c*?:\mathbbi`t::𝕚
:c*?:\mathbbI`t::𝕀
:c*?:\mathbbj`t::𝕛
:c*?:\mathbbJ`t::𝕁
:c*?:\mathbbk`t::𝕜
:c*?:\mathbbK`t::𝕂
:c*?:\mathbbl`t::𝕝
:c*?:\mathbbL`t::𝕃
:c*?:\mathbbm`t::𝕞
:c*?:\mathbbM`t::𝕄
:c*?:\mathbbn`t::𝕟
:c*?:\mathbbN`t::ℕ
:c*?:\mathbbo`t::𝕠
:c*?:\mathbbO`t::𝕆
:c*?:\mathbbp`t::𝕡
:c*?:\mathbbP`t::ℙ
:c*?:\mathbbq`t::𝕢
:c*?:\mathbbQ`t::ℚ
:c*?:\mathbbr`t::𝕣
:c*?:\mathbbR`t::ℝ
:c*?:\mathbbs`t::𝕤
:c*?:\mathbbS`t::𝕊
:c*?:\mathbbt`t::𝕥
:c*?:\mathbbT`t::𝕋
:c*?:\mathbbu`t::𝕦
:c*?:\mathbbU`t::𝕌
:c*?:\mathbbv`t::𝕧
:c*?:\mathbbV`t::𝕍
:c*?:\mathbbw`t::𝕨
:c*?:\mathbbW`t::𝕎
:c*?:\mathbbx`t::𝕩
:c*?:\mathbbX`t::𝕏
:c*?:\mathbby`t::𝕪
:c*?:\mathbbY`t::𝕐
:c*?:\mathbbz`t::𝕫
:c*?:\mathbbZ`t::ℤ

:c*?:\mathbb0`t::𝟘
:c*?:\mathbb1`t::𝟙
:c*?:\mathbb2`t::𝟚
:c*?:\mathbb3`t::𝟛
:c*?:\mathbb4`t::𝟜
:c*?:\mathbb5`t::𝟝
:c*?:\mathbb6`t::𝟞
:c*?:\mathbb7`t::𝟟
:c*?:\mathbb8`t::𝟠
:c*?:\mathbb9`t::𝟡

; \mathfrak{x}  用 \mathfrakx 代替
:c*?:\mathfraka`t::𝔞
:c*?:\mathfrakA`t::𝔄
:c*?:\mathfrakb`t::𝔟
:c*?:\mathfrakB`t::𝔅
:c*?:\mathfrakc`t::𝔠
:c*?:\mathfrakC`t::ℭ
:c*?:\mathfrakd`t::𝔡
:c*?:\mathfrakD`t::𝔇
:c*?:\mathfrake`t::𝔢
:c*?:\mathfrakE`t::𝔈
:c*?:\mathfrakf`t::𝔣
:c*?:\mathfrakF`t::𝔉
:c*?:\mathfrakg`t::𝔤
:c*?:\mathfrakG`t::𝔊
:c*?:\mathfrakh`t::𝔥
:c*?:\mathfrakH`t::ℌ
:c*?:\mathfraki`t::𝔦
:c*?:\mathfrakI`t::ℑ
:c*?:\mathfrakj`t::𝔧
:c*?:\mathfrakJ`t::𝔍
:c*?:\mathfrakk`t::𝔨
:c*?:\mathfrakK`t::𝔎
:c*?:\mathfrakl`t::𝔩
:c*?:\mathfrakL`t::𝔏
:c*?:\mathfrakm`t::𝔪
:c*?:\mathfrakM`t::𝔐
:c*?:\mathfrakn`t::𝔫
:c*?:\mathfrakN`t::𝔑
:c*?:\mathfrako`t::𝔬
:c*?:\mathfrakO`t::𝔒
:c*?:\mathfrakp`t::𝔭
:c*?:\mathfrakP`t::𝔓
:c*?:\mathfrakq`t::𝔮
:c*?:\mathfrakQ`t::𝔔
:c*?:\mathfrakr`t::𝔯
:c*?:\mathfrakR`t::ℜ
:c*?:\mathfraks`t::𝔰
:c*?:\mathfrakS`t::𝔖
:c*?:\mathfrakt`t::𝔱
:c*?:\mathfrakT`t::𝔗
:c*?:\mathfraku`t::𝔲
:c*?:\mathfrakU`t::𝔘
:c*?:\mathfrakv`t::𝔳
:c*?:\mathfrakV`t::𝔙
:c*?:\mathfrakw`t::𝔴
:c*?:\mathfrakW`t::𝔚
:c*?:\mathfrakx`t::𝔵
:c*?:\mathfrakX`t::𝔛
:c*?:\mathfraky`t::𝔶
:c*?:\mathfrakY`t::𝔜
:c*?:\mathfrakz`t::𝔷
:c*?:\mathfrakZ`t::ℨ

; \mathcal{x}  用 \mathcalx 代替
:c*?:\mathcala`t::𝓪
:c*?:\mathcalA`t::𝓐
:c*?:\mathcalb`t::𝓫
:c*?:\mathcalB`t::𝓑
:c*?:\mathcalc`t::𝓬
:c*?:\mathcalC`t::𝓒
:c*?:\mathcald`t::𝓭
:c*?:\mathcalD`t::𝓓
:c*?:\mathcale`t::𝓮
:c*?:\mathcalE`t::𝓔
:c*?:\mathcalf`t::𝓯
:c*?:\mathcalF`t::𝓕
:c*?:\mathcalg`t::𝓰
:c*?:\mathcalG`t::𝓖
:c*?:\mathcalh`t::𝓱
:c*?:\mathcalH`t::𝓗
:c*?:\mathcali`t::𝓲
:c*?:\mathcalI`t::𝓘
:c*?:\mathcalj`t::𝓳
:c*?:\mathcalJ`t::𝓙
:c*?:\mathcalk`t::𝓴
:c*?:\mathcalK`t::𝓚
:c*?:\mathcall`t::𝓵
:c*?:\mathcalL`t::𝓛
:c*?:\mathcalm`t::𝓶
:c*?:\mathcalM`t::𝓜
:c*?:\mathcaln`t::𝓷
:c*?:\mathcalN`t::𝓝
:c*?:\mathcalo`t::𝓸
:c*?:\mathcalO`t::𝓞
:c*?:\mathcalp`t::𝓹
:c*?:\mathcalP`t::𝓟
:c*?:\mathcalq`t::𝓺
:c*?:\mathcalQ`t::𝓠
:c*?:\mathcalr`t::𝓻
:c*?:\mathcalR`t::𝓡
:c*?:\mathcals`t::𝓼
:c*?:\mathcalS`t::𝓢
:c*?:\mathcalt`t::𝓽
:c*?:\mathcalT`t::𝓣
:c*?:\mathcalu`t::𝓾
:c*?:\mathcalU`t::𝓤
:c*?:\mathcalv`t::𝓿
:c*?:\mathcalV`t::𝓥
:c*?:\mathcalw`t::𝔀
:c*?:\mathcalW`t::𝓦
:c*?:\mathcalx`t::𝔁
:c*?:\mathcalX`t::𝓧
:c*?:\mathcaly`t::𝔂
:c*?:\mathcalY`t::𝓨
:c*?:\mathcalz`t::𝔃
:c*?:\mathcalZ`t::𝓩

; 重音符  https://katex.org/docs/supported.html#accents

; \hat{x}  用 \hatx 代替
:c*?:\hata`t::â
:c*?:\hatA`t::Â
:c*?:\hatb`t::b̂
:c*?:\hatB`t::B̂
:c*?:\hatc`t::ĉ
:c*?:\hatC`t::Ĉ
:c*?:\hatd`t::d̂
:c*?:\hatD`t::D̂
:c*?:\hate`t::ê
:c*?:\hatE`t::Ê
:c*?:\hatf`t::f̂
:c*?:\hatF`t::F̂
:c*?:\hatg`t::ĝ
:c*?:\hatG`t::Ĝ
:c*?:\hath`t::ĥ
:c*?:\hatH`t::Ĥ
:c*?:\hati`t::î
:c*?:\hatI`t::Î
:c*?:\hatj`t::ĵ
:c*?:\hatJ`t::Ĵ
:c*?:\hatk`t::k̂
:c*?:\hatK`t::K̂
:c*?:\hatl`t::l̂
:c*?:\hatL`t::L̂
:c*?:\hatm`t::m̂
:c*?:\hatM`t::M̂
:c*?:\hatn`t::n̂
:c*?:\hatN`t::N̂
:c*?:\hato`t::ô
:c*?:\hatO`t::Ô
:c*?:\hatp`t::p̂
:c*?:\hatP`t::P̂
:c*?:\hatq`t::q̂
:c*?:\hatQ`t::Q̂
:c*?:\hatr`t::r̂
:c*?:\hatR`t::R̂
:c*?:\hats`t::ŝ
:c*?:\hatS`t::Ŝ
:c*?:\hatt`t::t̂
:c*?:\hatT`t::T̂
:c*?:\hatu`t::û
:c*?:\hatU`t::Û
:c*?:\hatv`t::v̂
:c*?:\hatV`t::V̂
:c*?:\hatw`t::ŵ
:c*?:\hatW`t::Ŵ
:c*?:\hatx`t::x̂
:c*?:\hatX`t::X̂
:c*?:\haty`t::ŷ
:c*?:\hatY`t::Ŷ
:c*?:\hatz`t::ẑ
:c*?:\hatZ`t::Ẑ

; \dot{x}  用 \dotx 代替
; https://52unicode.com/combining-diacritical-marks-zifu
:c*?:\dota`t::ȧ
:c*?:\dotA`t::Ȧ
:c*?:\dotb`t::ḃ
:c*?:\dotB`t::Ḃ
:c*?:\dotc`t::ċ
:c*?:\dotC`t::Ċ
:c*?:\dotd`t::ḋ
:c*?:\dotD`t::Ḋ
:c*?:\dote`t::ė
:c*?:\dotE`t::Ė
:c*?:\dotf`t::ḟ
:c*?:\dotF`t::Ḟ
:c*?:\dotg`t::ġ
:c*?:\dotG`t::Ġ
:c*?:\doth`t::ḣ
:c*?:\dotH`t::Ḣ
:c*?:\doti`t::i′
:c*?:\dotI`t::I′
:c*?:\dotj`t::j′
:c*?:\dotJ`t::J′
:c*?:\dotk`t::k̇
:c*?:\dotK`t::K̇
:c*?:\dotl`t::l̇
:c*?:\dotL`t::L̇
:c*?:\dotm`t::ṁ
:c*?:\dotM`t::Ṁ
:c*?:\dotn`t::ṅ
:c*?:\dotN`t::Ṅ
:c*?:\doto`t::ȯ
:c*?:\dotO`t::Ȯ
:c*?:\dotp`t::ṗ
:c*?:\dotP`t::Ṗ
:c*?:\dotq`t::q̇
:c*?:\dotQ`t::Q̇
:c*?:\dotr`t::ṙ
:c*?:\dotR`t::Ṙ
;:c*?:\dots`t::ṡ ; 和 \dots -> … 有冲突 
:c*?:\dotS`t::Ṡ
:c*?:\dott`t::ṫ
:c*?:\dotT`t::Ṫ
:c*?:\dotu`t::u̇
:c*?:\dotU`t::U̇
:c*?:\dotv`t::v̇
:c*?:\dotV`t::V̇
:c*?:\dotw`t::ẇ
:c*?:\dotW`t::Ẇ
:c*?:\dotx`t::ẋ
:c*?:\dotX`t::Ẋ
:c*?:\doty`t::ẏ
:c*?:\dotY`t::Ẏ
:c*?:\dotz`t::ż
:c*?:\dotZ`t::Ż

; \ddot{x}  用 \ddotx 代替
; https://52unicode.com/combining-diacritical-marks-zifu
:c*?:\ddota`t::ä
:c*?:\ddotA`t::Ä
:c*?:\ddotb`t::b̈
:c*?:\ddotB`t::B̈
:c*?:\ddotc`t::c̈
:c*?:\ddotC`t::C̈
:c*?:\ddotd`t::d̈
:c*?:\ddotD`t::D̈
:c*?:\ddote`t::ë
:c*?:\ddotE`t::Ë
:c*?:\ddotf`t::f̈
:c*?:\ddotF`t::F̈
:c*?:\ddotg`t::g̈
:c*?:\ddotG`t::G̈
:c*?:\ddoth`t::ḧ
:c*?:\ddotH`t::Ḧ
:c*?:\ddoti`t::i′′
:c*?:\ddotI`t::Ï
:c*?:\ddotj`t::j′′
:c*?:\ddotJ`t::J̈
:c*?:\ddotk`t::k̈
:c*?:\ddotK`t::K̈
:c*?:\ddotl`t::l̈
:c*?:\ddotL`t::L̈
:c*?:\ddotm`t::m̈
:c*?:\ddotM`t::M̈
:c*?:\ddotn`t::n̈
:c*?:\ddotN`t::N̈
:c*?:\ddoto`t::ö
:c*?:\ddotO`t::Ö
:c*?:\ddotp`t::p̈
:c*?:\ddotP`t::P̈
:c*?:\ddotq`t::q̈
:c*?:\ddotQ`t::Q̈
:c*?:\ddotr`t::r̈
:c*?:\ddotR`t::R̈
;:c*?:\ddots`t::s̈ ; 和 \ddots -> ⋱ 有冲突
:c*?:\ddotS`t::S̈
:c*?:\ddott`t::ẗ
:c*?:\ddotT`t::T̈
:c*?:\ddotu`t::ü
:c*?:\ddotU`t::Ü
:c*?:\ddotv`t::v̈
:c*?:\ddotV`t::V̈
:c*?:\ddotw`t::ẅ
:c*?:\ddotW`t::Ẅ
:c*?:\ddotx`t::ẍ
:c*?:\ddotX`t::Ẍ
:c*?:\ddoty`t::ÿ
:c*?:\ddotY`t::Ÿ
:c*?:\ddotz`t::z̈
:c*?:\ddotZ`t::Z̈

; \tilde{x}  用 \tildex 代替
; https://52unicode.com/combining-diacritical-marks-zifu
:c*?:\tildea`t::ã 
:c*?:\tildeA`t::Ã
:c*?:\tildeb`t::b͂
:c*?:\tildeB`t::B͂
:c*?:\tildec`t::c͂
:c*?:\tildeC`t::C͂
:c*?:\tilded`t::d͂
:c*?:\tildeD`t::D͂
:c*?:\tildee`t::ẽ
:c*?:\tildeE`t::Ẽ
:c*?:\tildef`t::f͂
:c*?:\tildeF`t::F͂
:c*?:\tildeg`t::g͂
:c*?:\tildeG`t::G͂
:c*?:\tildeh`t::h͂
:c*?:\tildeH`t::H͂
:c*?:\tildei`t::i͂
:c*?:\tildeI`t::Ĩ
:c*?:\tildej`t::j͂
:c*?:\tildeJ`t::J͂
:c*?:\tildek`t::k͂
:c*?:\tildeK`t::K͂
:c*?:\tildel`t::l͂
:c*?:\tildeL`t::L͂
:c*?:\tildem`t::m͂
:c*?:\tildeM`t::M͂
:c*?:\tilden`t::ñ
:c*?:\tildeN`t::Ñ
:c*?:\tildeo`t::õ
:c*?:\tildeO`t::Õ
:c*?:\tildep`t::p͂
:c*?:\tildeP`t::P͂
:c*?:\tildeq`t::q͂
:c*?:\tildeQ`t::Q͂
:c*?:\tilder`t::r͂
:c*?:\tildeR`t::R͂
:c*?:\tildes`t::s͂
:c*?:\tildeS`t::S͂
:c*?:\tildet`t::t͂
:c*?:\tildeT`t::T͂
:c*?:\tildeu`t::ũ
:c*?:\tildeU`t::Ũ
:c*?:\tildev`t::ṽ
:c*?:\tildeV`t::Ṽ
:c*?:\tildew`t::w͂
:c*?:\tildeW`t::W͂
:c*?:\tildex`t::x͂
:c*?:\tildeX`t::X͂
:c*?:\tildey`t::ỹ
:c*?:\tildeY`t::Ỹ
:c*?:\tildez`t::z͂
:c*?:\tildeZ`t::Z͂

; \bar{x}  用 \barx 代替
; https://52unicode.com/combining-diacritical-marks-zifu
:c*?:\bara`t::ā
:c*?:\barA`t::Ā
:c*?:\barb`t::b̄
:c*?:\barB`t::B̄
:c*?:\barc`t::c̄
:c*?:\barC`t::C̄
:c*?:\bard`t::d̄
:c*?:\barD`t::D̄
:c*?:\bare`t::ē
:c*?:\barE`t::Ē
:c*?:\barf`t::f̄
:c*?:\barF`t::F̄
:c*?:\barg`t::ḡ
:c*?:\barG`t::Ḡ
:c*?:\barh`t::h̄
:c*?:\barH`t::H̄
:c*?:\bari`t::ī
:c*?:\barI`t::Ī
:c*?:\barj`t::j̄
:c*?:\barJ`t::J̄
:c*?:\bark`t::k̄
:c*?:\barK`t::K̄
:c*?:\barl`t::l̄
:c*?:\barL`t::L̄
:c*?:\barm`t::m̄
:c*?:\barM`t::M̄
:c*?:\barn`t::n̄
:c*?:\barN`t::N̄
:c*?:\baro`t::ō
:c*?:\barO`t::Ō
:c*?:\barp`t::p̄
:c*?:\barP`t::P̄
:c*?:\barq`t::q̄
:c*?:\barQ`t::Q̄
:c*?:\barr`t::r̄
:c*?:\barR`t::R̄
:c*?:\bars`t::s̄
:c*?:\barS`t::S̄
:c*?:\bart`t::t̄
:c*?:\barT`t::T̄
:c*?:\baru`t::ū
:c*?:\barU`t::Ū
:c*?:\barv`t::v̄
:c*?:\barV`t::V̄
:c*?:\barw`t::w̄
:c*?:\barW`t::W̄
:c*?:\barx`t::x̄
:c*?:\barX`t::X̄
:c*?:\bary`t::ȳ
:c*?:\barY`t::Ȳ
:c*?:\barz`t::z̄
:c*?:\barZ`t::Z̄

