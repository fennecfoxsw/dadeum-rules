// 값이 none이면 기본값을 사용합니다.
#let _or(v, default) = if v == none { default } else { v }

// 조항(항·호·목 등)을 내어쓰기로 그립니다. 번호가 길면 min-gap만큼 본문을 밀어냅니다.
// 본문 시작 = num-indent + max(num-width, 번호 폭 + min-gap)
#let numbered(num, body, ctx) = {
  let s = ctx.style
  let indent = _or(s.num-indent, 0pt)
  let width = _or(s.num-width, 0pt)
  let gap = _or(s.min-gap, 0pt)
  block(width: 100%, above: _or(s.above, auto), below: _or(s.below, auto), breakable: true)[
    #set text(size: s.size) if s.size != none
    #context {
      let body-x = indent + calc.max(width, measure(num).width + gap)
      pad(left: body-x)[#place(top + left, dx: indent - body-x, num)#body]
    }
  ]
}

// 신·구조문대비표 안의 조항을 한 줄로 이어 그립니다.
// 들여쓰기가 없으면 h(0pt)를 넣지 않습니다(넣으면 간격이 좁아짐).
#let numbered-table(num, body, ctx) = {
  let s = ctx.style
  let indent = _or(s.table-indent, 0pt)
  let gap = _or(s.table-gap, 0pt)
  block(width: 100%, above: _or(s.above, auto), below: _or(s.below, auto), breakable: true)[
    #set text(size: s.size) if s.size != none
    #if indent == 0pt [#num #h(gap) #body] else [#h(indent) #num #h(gap) #body]
  ]
}

// 계층(편·장·절·관 등)의 제목을 그립니다.
#let division-heading(num, title, ctx) = {
  let s = ctx.style
  show heading: it => block(above: s.above, below: s.below, width: 100%)[
    #align(s.align)[#text(size: s.size, weight: s.weight, fill: black)[#it.body]]
  ]
  heading(level: ctx.heading-level, outlined: ctx.outlined, numbering: none)[#num #title]
}

// 조의 제목("제1조 (목적)")과 본문을 그립니다. 부칙 안의 조는 목차에서 뺍니다.
#let article-render(num, body, ctx) = {
  let s = ctx.style
  block(above: s.above, below: s.below, breakable: true)[
    #{
      show heading: it => text(size: s.title-size, weight: s.title-weight, fill: black)[#it.body]
      heading(level: ctx.heading-level, outlined: not ctx.addendum, numbering: none)[#ctx.cite (#ctx.title)]
    } #h(s.title-gap)#body
  ]
}

// 신·구조문대비표 안의 조를 그립니다.
#let article-render-table(num, body, ctx) = [*#ctx.cite (#ctx.title)* #h(ctx.style.table-gap)#body]
