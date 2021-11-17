; ----------------------------------------------
; 参考Katex，尽可能使用latex触发出对应的unicode字符
;
; https://katex.org/docs/supported.html
; 
; 只对不方便键盘输入的字符进行latex[TAB]替换， 如果没有替换说明输入错误或不支持
;
; 只支持单字符的latex触发（目前支持如下7类）
;    1) _n[TAB]             ₙ   【下标触发】
;    2) ^n[TAB]             ⁿ   【上标触发】
;    3) \alpha[TAB]         α   【单字符触发】
;    4) \mathbbR[TAB]       ℝ   【空心字符触发】
;    5) \mathfrakR[TAB]     ℜ   【Fraktur字符触发】
;    6) \mathcalR[TAB]      𝓡   【花体字符触发】
;    7) \hatR[TAB]          R̂   【戴帽字符触发】
; ----------------------------------------------

; 下标和上标 【确保在希腊字母前面】 https://katex.org/docs/supported.html#line-breaks

:*?:_0`t::₀  ; *表示不需要终止符(即空格, 句点或回车)来触发热字串， 另外指定Tab(`t)作为终止符；
;              ?表示即使此热字串在另一个单词中也会被触发。
:*?:^0`t::⁰
:*?:_1`t::₁
:*?:_1`t::¹
:*?:_2`t::₂
:*?:^2`t::²
:*?:_3`t::₃
:*?:^3`t::³
:*?:_4`t::₄
:*?:^4`t::⁴
:*?:_5`t::₅
:*?:^5`t::⁵
:*?:_6`t::₆
:*?:^6`t::⁶
:*?:_7`t::₇
:*?:^7`t::⁷
:*?:_8`t::₈
:*?:^8`t::⁸
:*?:_9`t::₉
:*?:^9`t::⁹
:*?:_+`t::₊
:*?:^+`t::⁺
:*?:_-`t::₋
:*?:^-`t::⁻
:*?:_=`t::₌
:*?:^=`t::⁼
:*?:_(`t::₍
:*?:^(`t::⁽
:*?:_)`t::₎
:*?:^)`t::⁾
:*?:_0`t::ₐ
:*?:^a`t::ᵃ
:*?:^b`t::ᵇ
:*?:^c`t::ᶜ
:*?:^d`t::ᵈ
:*?:_e`t::ₑ
:*?:^e`t::ᵉ
:*?:^f`t::ᶠ
:*?:^g`t::ᵍ
:*?:_h`t::ₕ
:*?:^h`t::ʰ
:*?:_i`t::ᵢ
:*?:^i`t::ⁱ
:*?:_j`t::ⱼ
:*?:^j`t::ʲ
:*?:_k`t::ₖ
:*?:^k`t::ᵏ
:*?:_l`t::ₗ
:*?:^l`t::ˡ
:*?:_m`t::ₘ
:*?:^m`t::ᵐ
:*?:_n`t::ₙ
:*?:^n`t::ⁿ
:*?:_o`t::ₒ
:*?:^o`t::ᵒ
:*?:_p`t::ₚ
:*?:^p`t::ᵖ
:*?:_r`t::ᵣ
:*?:^r`t::ʳ
:*?:_s`t::ₛ
:*?:^s`t::ˢ
:*?:_t`t::ₜ
:*?:^t`t::ᵗ
:*?:_u`t::ᵤ
:*?:^u`t::ᵘ
:*?:_v`t::ᵥ
:*?:^v`t::ᵛ
:*?:^w`t::ʷ
:*?:_x`t::ₓ
:*?:^x`t::ˣ
:*?:^y`t::ʸ
:*?:^z`t::ᶻ
:*?:_\beta`t::ᵦ
:*?:^\beta`t::ᵝ
:*?:_\gamma`t::ᵧ
:*?:^\gamma`t::ᵞ
:*?:_\chi`t::ᵪ
:*?:^\chi`t::ᵡ
:*?:^\theta`t::ᶿ
:*?:_\rho`t::ᵨ
:*?:_\psi`t::ᵩ

; 定界符 https://katex.org/docs/supported.html#delimiters
:*?:\lceil`t::⌈
:*?:\rceil`t::⌉
:*?:\lfloor`t::⌊
:*?:\rfloor`t::⌋
:*?:\lmoustache`t::⎰
:*?:\rmoustache`t::⎱
:*?:\langle`t::⟨
:*?:\rangle`t::⟩
:*?:\lgroup`t::⟮
:*?:\rgroup`t::⟯
:*?:\ulcorner`t::┌
:*?:\urcorner`t::┐
:*?:\llcorner`t::└
:*?:\lrcorner`t::┘

; 环境 https://katex.org/docs/supported.html#delimiters
; 不适合ASCII码呈现，放弃

; 字母和unicode https://katex.org/docs/supported.html#letters-and-unicode

; 希腊字母
:*?:\alpha`t::α
:*?:\Alpha`t::Α
:*?:\beta`t::β
:*?:\Beta`t::Β
:*?:\Gamma`t::Γ
:*?:\gamma`t::γ
:*?:\Delta`t::Δ
:*?:\delta`t::δ
:*?:\Epsilon`t::E
:*?:\epsilon`t::ϵ
:*?:\Zeta`t::Ζ
:*?:\zeta`t::ζ
:*?:\Eta`t::Η
:*?:\eta`t::η
:*?:\Theta`t::Θ
:*?:\theta`t::θ
:*?:\Iota`t::Ι
:*?:\iota`t::ι
:*?:\Kappa`t::Κ
:*?:\kappa`t::κ
:*?:\Lambda`t::Λ
:*?:\lambda`t::λ
:*?:\Mu`t::Μ
:*?:\mu`t::μ
:*?:\Nu`t::Ν
:*?:\nu`t::ν
:*?:\Xi`t::Ξ
:*?:\xi`t::ξ
:*?:\Omicron`t::Ο
:*?:\omicron`t::ο
:*?:\Pi`t::Π
:*?:\pi`t::π
:*?:\rho`t::ρ
:*?:\Rho`t::Ρ
:*?:\Sigma`t::Σ
:*?:\sigma`t::σ
:*?:\Tau`t::Τ
:*?:\tau`t::τ
:*?:\Upsilon`t::Υ
:*?:\upsilon`t::υ
:*?:\Phi`t::Φ
:*?:\phi`t::ϕ
:*?:\Chi`t::Χ
:*?:\chi`t::χ
:*?:\Psi`t::Ψ
:*?:\psi`t::ψ
:*?:\Omega`t::Ω
:*?:\omega`t::ω

:*?:\varGamma`t::Γ
:*?:\varDelta`t::Δ
:*?:\varTheta`t::Θ
:*?:\varLambda`t::Λ
:*?:\varXi`t::Ξ
:*?:\varPi`t::Π
:*?:\varSigma`t::Σ
:*?:\varUpsilon`t::Υ
:*?:\varPhi`t::Φ
:*?:\varPsi`t::Ψ
:*?:\varOmega`t::Ω

:*?:\varepsilon`t::ε
:*?:\varkappa`t::ϰ
:*?:\vartheta`t::ϑ
:*?:\thetasym`t::ϑ
:*?:\varpi`t::ϖ
:*?:\varrho`t::ϱ
:*?:\varsigma`t::ς
:*?:\varphi`t::φ
:*?:\digamma`t::ϝ

; 其它字母

:*?:\nabla`t::∇
:*?:\Im`t::ℑ
:*?:\Reals`t::ℝ
:*?:\OE`t::Œ
:*?:\partial`t::∂
:*?:\image`t::ℑ
:*?:\wp`t::℘
:*?:\o`t::ø
:*?:\aleph`t::ℵ
:*?:\Game`t::⅁
:*?:\Bbbkk`t::𝕜
:*?:\weierp`t::℘
:*?:\O`t::Ø
:*?:\alef`t::ℵ
:*?:\Finv`t::Ⅎ
:*?:\NN`t::ℕ
:*?:\ZZ`t::ℤ
:*?:\ss`t::ß
:*?:\alefsym`t::ℵ
:*?:\cnums`t::ℂ
:*?:\natnums`t::ℕ
:*?:\aa`t::˚ 
:*?:\i`t::ı
:*?:\beth`t::ℶ
:*?:\Complex`t::ℂ
:*?:\RR`t::ℝ
:*?:\A`t::A˚
:*?:\j`t::ȷ
:*?:\gimel`t::ℷ
:*?:\ell`t::ℓ
:*?:\Re`t::ℜ
:*?:\ae`t::æ
:*?:\daleth`t::ℸ
:*?:\hbar`t::ℏ
:*?:\real`t::ℜ
:*?:\AE`t::Æ
:*?:\eth`t::ð
:*?:\hslash`t::ℏ
:*?:\reals`t::ℝ
:*?:\oe`t::œ

; 布局 https://katex.org/docs/supported.html#layout
; 不适合Unicode呈现，放弃

; 换行符 https://katex.org/docs/supported.html#line-breaks
; 对Unicode没必要实现

; 重叠和间距 https://katex.org/docs/supported.html#overlap-and-spacing
; Unicode没必要实现

; 逻辑和集合 https://katex.org/docs/supported.html#logic-and-set-theory

:*?:\forall`t::∀
:*?:\exists`t::∃
:*?:\exist`t::∃
:*?:\nexists`t::∄
:*?:\complement`t::∁
:*?:\therefore`t::∴
:*?:\because`t::∵
:*?:\emptyset`t::∅
:*?:\empty`t::∅
:*?:\varnothing`t::∅
:*?:\subset`t::⊂
:*?:\supset`t::⊃
:*?:\nsubseteq`t::⊈
:*?:\nsupseteq`t::⊉
:*?:\subseteq`t::⊆
:*?:\supseteq`t::⊇
:*?:\mapsto`t::↦
:*?:\to`t::→
:*?:\gets`t::←
:*?:\leftrightarrow`t::↔
:*?:\implies`t::⟹
:*?:\impliedby`t::⟸
:*?:\iff`t::⟺
:*?:\mid`t::∣
:*?:\neg`t::¬
:*?:\lnot`t::¬
:*?:\in`t::∈
:*?:\isin`t::∈
:*?:\notin`t::∉
:*?:\ni`t::∋
:*?:\notni`t::∌

;   ⊄   ⊅  ⊊ ⊋
;   ⊤ ⊥ 
; □ ⊨ ⊢

; 宏 https://katex.org/docs/supported.html#macros
; 没必要实现

; 运算符 https://katex.org/docs/supported.html#operators

; 大运算符 https://katex.org/docs/supported.html#big-operators
:*?:\sum`t::∑
:*?:\prod`t::∏
:*?:\bigotimes`t::⊗
:*?:\bigvee`t::⋁
:*?:\int`t::∫
:*?:\intop`t::∫
:*?:\smallint`t::∫
:*?:\iint`t::∬
:*?:\iiint`t::∭
:*?:\oint`t::∮
:*?:\oiint`t::∯
:*?:\oiiint`t::∰
:*?:\coprod`t::∐
:*?:\bigoplus`t::⨁
:*?:\bigwedge`t::⋀
:*?:\bigodot`t::⊙
:*?:\bigcap`t::⋂
:*?:\biguplus`t::⨄
:*?:\bigcup`t::⋃
:*?:\bigsqcup`t::⨆

; 二元运算符 https://katex.org/docs/supported.html#binary-operators

:*?:\cdot`t::⋅
:*?:\cdotp`t::⋅
:*?:\gtrdot`t::⋗
:*?:\intercal`t::⊺
:*?:\centerdot`t::⋅
:*?:\land`t::∧
:*?:\rhd`t::⊳
:*?:\circ`t::∘
:*?:\leftthreetimes`t::⋋
:*?:\rightthreetimes`t::⋌
:*?:\amalg`t::⨿
:*?:\circledast`t::⊛
:*?:\ldotp`t::.
:*?:\rtimes`t::⋊
:*?:\circledcirc`t::⊚
:*?:\lor`t::∨
:*?:\ast`t::∗
:*?:\circleddash`t::⊝
:*?:\lessdot`t::⋖
:*?:\barwedge`t::⊼
:*?:\Cup`t::⋓
:*?:\lhd`t::⊲
:*?:\sqcap`t::⊓
:*?:\bigcirc`t::◯
:*?:\cup`t::∪
:*?:\ltimes`t::⋉
:*?:\sqcup`t::⊔
:*?:\curlyvee`t::⋎
:*?:\times`t::×
:*?:\boxdot`t::⊡
:*?:\curlywedge`t::⋏
:*?:\pm`t::±
:*?:\plusmn`t::±
:*?:\mp`t::∓
:*?:\unlhd`t::⊴
:*?:\boxminus`t::⊟
:*?:\div`t::÷
:*?:\odot`t::⨀
:*?:\unrhd`t::⊵
:*?:\boxplus`t::⊞
:*?:\divideontimes`t::⋇
:*?:\ominus`t::⊖
:*?:\uplus`t::⊎
:*?:\boxtimes`t::⊠
:*?:\dotplus`t::∔
:*?:\oplus`t::⊕
:*?:\vee`t::∨
:*?:\bullet`t::•
:*?:\doublebarwedge`t::⩞
:*?:\otimes`t::⨂
:*?:\veebar`t::⊻
:*?:\Cap`t::⋒
:*?:\doublecap`t::⋒
:*?:\oslash`t::⊘
:*?:\wedge`t::∧
:*?:\cap`t::∩
:*?:\doublecup`t::⋓
:*?:\wr`t::≀

; 分数和二项式 https://katex.org/docs/supported.html#fractions-and-binomials
; 没必要实现

; 数学运算符 https://katex.org/docs/supported.html#fractions-and-binomials
; 大部分没必要实现
:*?:\sqrt`t::√

; 关系 https://katex.org/docs/supported.html#relations
;      https://katex.org/docs/supported.html#negated-relations
; 太多了，只实现常用的即可

:*?:\approx`t::≈
:*?:\approxeq`t::≊
:*?:\neq`t::≠
:*?:\equiv`t::≡
:*?:\leq`t::≤
:*?:\geq`t::≥
:*?:\leqq`t::≦
:*?:\geqq`t::≧
:*?:\lneqq`t::≨
:*?:\gneqq`t::≩
:*?:\ll`t::≪
:*?:\gg`t::≫

; ≢   ⩽ ⩾  ≮ ≯ ≰ ≱ 
; ≲ ≳ ≺ ≻ ≼ ≽ ≾ ≿ ⊀ ⊁ ∼ ≁ ≃ ≄ ∽ ∾ ≀ 
; ≅ ≇  ≉   ≆ ≋ ≌ ≍ ≐ ≑ ⪇ ⪈ ⪯ ⪰ ⪵ ⪶

; 箭头 https://katex.org/docs/supported.html#arrows
; 太多了，只实现常用的即可

:*?:\leftarrow`t::←
:*?:\uparrow`t::↑
:*?:\rightarrow`t::→
:*?:\updownarrow`t::↕
:*?:\leftarrowtail`t::↢
:*?:\rightarrowtail`t::↣
:*?:\nleftarrow`t::↚
:*?:\nrightarrow`t::↛
:*?:\rightleftarrows`t::⇄
:*?:\leftleftarrows`t::⇇
:*?:\rightrightarrows`t::⇉
:*?:\downdownarrows`t::⇊
:*?:\upuparrows`t::⇈
:*?:\Leftarrow`t::⇐
:*?:\Rightarrow`t::⇒
:*?:\Uparrow`t::⇑
:*?:\Downarrow`t::⇓
:*?:\Updownarrow`t::⇕
:*?:\Leftrightarrow`t::⇔
:*?:\dashrightarrow`t::⇢
:*?:\dashleftarrow`t::⇠
:*?:\longleftrightarrow`t::⟷
:*?:\Longleftarrow`t::⟸
:*?:\Longrightarrow`t::⟹
:*?:\Longleftrightarrow`t::⟺

; ↖ ↗ ↘ ↙ 
; ↩  ↠ ↞ ↪ ↩ ⇝ ⇌ ⇋ ⇀ ⇁

; 其它常用符号 https://katex.org/docs/supported.html#symbols-and-punctuation
; 太多了，只实现常用的即可

:*?:\ldots`t::…
:*?:\infty`t::∞
:*?:\propto`t::∝
:*?:\angle`t::∠
:*?:\measuredangle`t::∡
:*?:\sphericalangle`t::∢
:*?:\diamond`t::⋄
:*?:\star`t::⋆
:*?:\dagger`t::†

;∣ ∤ ∤ ∥ ∦ ∦ ♭ ♮ ♯

; 重音符  https://katex.org/docs/supported.html#accents

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
:c*?:\mathbba`t::𝕒 ; C表示区分大小写: 当您输入缩写时, 它必须准确匹配脚本中定义的大小写形式
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
:c*?:\mathbbx`t::𝕩
:c*?:\mathbbX`t::𝕏
:c*?:\mathbby`t::𝕪
:c*?:\mathbbY`t::𝕐
:c*?:\mathbbz`t::𝕫
:c*?:\mathbbZ`t::ℤ

:*?:\mathbb0`t::𝟘
:*?:\mathbb1`t::𝟙
:*?:\mathbb2`t::𝟚
:*?:\mathbb3`t::𝟛
:*?:\mathbb4`t::𝟜
:*?:\mathbb5`t::𝟝
:*?:\mathbb6`t::𝟞
:*?:\mathbb7`t::𝟟
:*?:\mathbb8`t::𝟠
:*?:\mathbb9`t::𝟡

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

