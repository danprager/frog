#lang rackjure

(require xml "take.rkt")

(provide xexprs->description
         xexpr->markdown)

(module+ test
  (require rackunit))

(define (xexprs->description xs [num 3])
  (str (~> (string-join (map (curryr xexpr->markdown " ") (take<= xs num))
                        "")
           escape-double-quotes)
       "..."))

(module+ test
  (check-equal?
   (xexprs->description '((h1 ([class "foo"]) "A heading")
                          (p "A " (em "paragraph") " of some stuff.")
                          (p "A " (em "paragraph") " of some stuff.")
                          (p "A " (em "paragraph") " of some stuff.")
                          (p "A " (em "paragraph") " of some stuff."))
                        3)
   "A heading: A _paragraph_ of some stuff. A _paragraph_ of some stuff. ...")
  (check-equal?
   (xexprs->description '((h1 ([class "foo"]) "A heading")
                          (p "A " (em "paragraph") " of some stuff.")
                          (img ([src "blah"]))
                          (p "A " (em "paragraph") " of some stuff.")
                          (p "A " (em "paragraph") " of some stuff."))
                        3)
   "A heading: A _paragraph_ of some stuff. ..."))

;; Not full markdown, just a "lite" variant for human readers only.
(define (xexpr->markdown x [block-suffix ""])
  (define (heading? s)
    (memq s '(h1 h2 h3 h4 h5 h6 h7 h8 h9)))
  (define (block? s)
    (memq s '(p div li)))
  (define (->s es) ;convert entities to string
    (apply str (map (curryr xexpr->markdown block-suffix) es)))
  (define (normalize x) ;; ensure xexpr has explicit attributes
    (match x
      [`(,(? symbol? tag) ([,(? symbol? ks) ,(? string? vs)] ...) ,es ...) x]
      [`(,(? symbol? tag) ,es ...) `(,tag () ,@es ...)] ;add '() attribs
      [_ x]))
  (match (normalize x)
    [`(em            ,_ ,es ...) (str "_" (->s es) "_")]
    [`(strong        ,_ ,es ...) (str "**" (->s es) "**")]
    [`(code          ,_ ,es ...) (str "`" (->s es) "`")]
    [`(,(? heading?) ,_ ,es ...) (str (->s es) ": ")]
    [`(,(? block?)   ,_ ,es ...) (str (->s es) block-suffix)]
    [`(,(? symbol?)  ,_ ,es ...) (str (->s es))]
    [(? string? s) s]
    ['ndash "--"]
    ['mdash "--"]
    ['amp "&"]
    [(or 'lsquo 'rsquo) "'"]
    [(or 'ldquo 'rdquo 'quot) "\""]
    [(? valid-char? c) (integer->char c)]
    [_ ""])) ;; ignore others

(module+ test
  (check-equal? (xexpr->markdown '(em "italic"))
                "_italic_")
  (check-equal? (xexpr->markdown '(em ([class "foo"]) "italic"))
                "_italic_")
  (check-equal? (xexpr->markdown '(strong "bold"))
                "**bold**")
  (check-equal? (xexpr->markdown '(strong ([class "foo"]) "bold"))
                "**bold**")
  (check-equal? (xexpr->markdown '(em "italic " (strong "bold") " italic"))
                "_italic **bold** italic_")
  (check-equal? (xexpr->markdown '(p "I am some " (em "italic") " text"))
                "I am some _italic_ text")
  (check-equal? (xexpr->markdown '(p ([class "foo"])
                                     "I am some " (em "italic") " text"))
                "I am some _italic_ text")
  (check-equal? (xexpr->markdown '(p "M" 'amp "Ms" 'mdash "gotta love 'em"))
                "M&Ms--gotta love 'em")
  (check-equal? (xexpr->markdown '(div (p "Hi.") (p "Hi.")) "\n")
                "Hi.\nHi.\n\n")
  (check-equal? (xexpr->markdown '(p "Hi" #x20 "there"))
                "Hi there"))

(define (escape-double-quotes s)
  (regexp-replace* #rx"\"" s "\\&quot;")) ;need to escape `&` in replace str

(module+ test
  (check-equal? (escape-double-quotes "A \"double quote\" in the string.")
                "A &quot;double quote&quot; in the string."))
