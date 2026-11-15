// ─────────────────────────────────────────────────────────────
// 내부 상태
// ─────────────────────────────────────────────────────────────

#let _debug = state("rule-debug", false)
#let _font-size = state("rule-font-size", 12pt)
#let _cover-margin = state("rule-cover-margin", (top: 30mm, bottom: 30mm, left: 30mm, right: 30mm, footer: 15mm))
#let _margin = state("rule-margin", (top: 30mm, bottom: 30mm, left: 30mm, right: 30mm, footer: 15mm))
#let _compact-margin = state("rule-compact-margin", (top: 15mm, bottom: 15mm, left: 20mm, right: 20mm, footer: 3mm))
#let _page-numbering = state("rule-page-numbering", (content: [-- 1 --], alignment: center, size: none))

// 신·구조문대비표 안 표시. 상태 대신 raw의 탭 너비를 빌려 사용합니다.
#let _table-flag = 97

// 현재 위치와 자동 번호. zone: 0이면 본칙, n이면 n번째 부칙.
// _pos.update(p => ...) 형태로만 갱신해야 합니다.
#let _pos = state("rule-pos", (zone: 0, path: (), stack: (), counts: (), branches: (:), addenda: 0, saved: ()))

// 계층(편·장·절 등) 번호 카운터
#let _division-counter = counter("rule-division")
#let _division-branch-counter(key) = counter("rule-division-branch-" + key)

// ─────────────────────────────────────────────────────────────
// 내부 도구
// ─────────────────────────────────────────────────────────────

// 여백 정규화. footer를 생략하면 top의 절반을 사용합니다.
#let _normalize-margin(m, name) = {
  let required = ("top", "bottom", "left", "right")
  assert(
    type(m) == dictionary
      and required.all(k => k in m)
      and m.keys().all(k => k in required or k == "footer"),
    message: name + "의 형식이 잘못되었습니다. (top, bottom, left, right, footer(선택)를 지정해야 합니다.)",
  )
  (
    top: m.top,
    bottom: m.bottom,
    left: m.left,
    right: m.right,
    footer: m.at("footer", default: m.top / 2),
  )
}

// style 검사: 허용된 키와 값의 형식만 확인합니다.
#let _style-kinds-desc = (
  length: "길이",
  by-parent: "부모 key별 길이 딕셔너리(default 포함)",
  weight: "문자열 또는 정수",
  alignment: "정렬",
)

#let _check-kind(v, kind) = {
  if kind == "length" { type(v) == length }
  else if kind == "by-parent" { type(v) == dictionary and "default" in v and v.values().all(x => type(x) == length) }
  else if kind == "weight" { type(v) == str or type(v) == int }
  else if kind == "alignment" { type(v) == alignment }
  else { false }
}

// 조항 단계(make-level)의 style 키
#let _level-style-schema = (
  num-indent: ("length", "by-parent"), // 번호 시작 위치(부모 본문 왼쪽 끝 기준)
  num-width: ("length",), // 번호 시작부터 본문 시작까지의 폭
  min-gap: ("length",), // 번호가 길 때 번호와 본문 사이에 남길 최소 간격
  above: ("length",),
  below: ("length",),
  size: ("length",), // 그 단계의 번호와 본문 글자 크기
  title-size: ("length",), // 이하 title: true인 단계만
  title-weight: ("weight",),
  title-gap: ("length",),
  table-indent: ("length", "by-parent"), // 신·구조문대비표 안 들여쓰기
  table-gap: ("length",), // 신·구조문대비표 안 번호와 본문 사이
)
#let _title-style-keys = ("title-size", "title-weight", "title-gap")

// 계층(make-division)과 부칙(make-addendum)의 style 키
#let _heading-style-schema = (
  size: ("length",),
  weight: ("weight",),
  align: ("alignment",),
  above: ("length",),
  below: ("length",),
)

// 부모별 값 고르기. 부모 key가 없으면 default를 사용합니다.
#let _resolve-style(style, parent) = {
  let out = (:)
  for (k, v) in style {
    out.insert(k, if type(v) == dictionary { v.at(if parent == none { "default" } else { parent }, default: v.default) } else { v })
  }
  out
}

// style의 길이를 절대 길이로 바꿉니다. em은 base 기준입니다.
#let _absolutize(style, base) = {
  let out = (:)
  for (k, v) in style {
    out.insert(k, if type(v) == length { v.abs + v.em * base } else { v })
  }
  out
}

// style 검사 후 빠진 키를 none으로 채웁니다.
#let _normalize-style(style, schema, who, allow-title: true) = {
  assert(type(style) == dictionary, message: who + ": style은 딕셔너리여야 합니다.")
  for (k, v) in style {
    assert(k in schema, message: who + ": style에 '" + k + "'라는 키는 없습니다. 쓸 수 있는 키: " + schema.keys().join(", "))
    assert(
      allow-title or k not in _title-style-keys,
      message: who + ": style의 '" + k + "'는 title: true인 단계에서만 쓸 수 있습니다.",
    )
    assert(
      schema.at(k).any(kind => _check-kind(v, kind)),
      message: who + ": style의 '" + k + "' 값의 형식이 잘못되었습니다. 허용: "
        + schema.at(k).map(kind => _style-kinds-desc.at(kind)).join(" 또는 ") + ", 입력: " + repr(v),
    )
  }
  let out = (:)
  for k in schema.keys() { out.insert(k, style.at(k, default: none)) }
  out
}

// 콘텐츠를 일반 문자열로 펼칩니다.
#let _plain-text(c) = {
  if type(c) == str { c }
  else if c.has("text") { c.text }
  else if c.has("children") { c.children.map(_plain-text).fold("", (a, b) => a + b) }
  else if c.has("body") { _plain-text(c.body) }
  else if c.func() == [ ].func() { " " }
  else { "" }
}

// 별명이 붙은 조항의 위치를 표기합니다. (예: "부칙 제1조제2항(3쪽)")
#let _marker-where(m) = m.value.texts.filter(t => t != none).join("") + "(" + str(m.location().page()) + "쪽)"

// 문서의 별명을 모아 별명마다 metadata 배열로 돌려줍니다.
#let _markers() = {
  let out = (:)
  for m in query(<rule-marker>) {
    out.insert(m.value.name, out.at(m.value.name, default: ()) + (m,))
  }
  out
}

// 중복된 별명의 오류 메시지를 만듭니다.
#let _duplicate-marker-message(name, found) = (
  "별명 \"" + name + "\"이(가) 여러 조항에 붙어 있습니다: " + found.map(_marker-where).join(", ")
)

// 문서에 쓰인 조항 단계 정의를 depth 순으로 돌려줍니다.
#let _level-defs() = {
  let seen = (:)
  for m in query(<rule-level-def>) { seen.insert(m.value.key, m.value) }
  seen.values().sorted(key: d => d.depth)
}

// 라벨 문자열을 만듭니다. 건너뛴 단계는 "0"으로 채웁니다.
#let _label-string(zone, entries) = {
  let resolved = entries
  if entries.any(e => e == none) {
    let defs = _level-defs()
    resolved = entries.enumerate().map(((d, e)) => {
      if e != none { e } else {
        let def = defs.find(x => x.depth == d)
        (key: if def == none { "level" + str(d) } else { def.key }, part: "0")
      }
    })
  }
  let prefix = if zone > 0 { "rule-addendum-" + str(zone) + "-" } else { "rule-" }
  prefix + resolved.map(e => e.key + "-" + e.part).join("-")
}

// 목 번호. 범위를 넘으면 none을 돌려줍니다.
#let _hangeul-initials = (0, 2, 3, 5, 6, 7, 9, 11, 12, 14, 15, 16, 17, 18) // ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎ
#let _hangeul-vowels = (0, 4, 8, 13) // ㅏㅓㅗㅜ
#let hangeul-number(n) = {
  if n < 1 or n > 56 { return none }
  let i = n - 1
  let cho = _hangeul-initials.at(calc.rem(i, 14))
  let jung = _hangeul-vowels.at(calc.quo(i, 14))
  str.from-unicode(0xAC00 + (cho * 21 + jung) * 28)
}
// 목 번호에 쓰는 글자 모음. parse 정규식에 사용합니다.
#let hangeul-number-chars = range(1, 57).map(hangeul-number).join("")

// ─────────────────────────────────────────────────────────────
// 양식 초기 설정
// ─────────────────────────────────────────────────────────────

// 규정 문서 양식을 사용하도록 설정합니다.
#let rule-document(
  document-title: none,
  serif: "Noto Serif CJK KR",
  san-serif: "Noto Sans CJK KR",
  default-font-type: "serif",
  font-size: 12pt,
  margin: (top: 30mm, bottom: 30mm, left: 30mm, right: 30mm, footer: 15mm),
  compact-margin: (top: 15mm, bottom: 15mm, left: 20mm, right: 20mm, footer: 3mm),
  cover-margin: none,
  page-numbering: (content: [-- 1 --], alignment: center),
  link-color: none,
  debug: false,
  body,
) = {
  if document-title != none { set document(title: document-title) }

  assert(type(debug) == bool, message: "debug는 true 혹은 false여야 합니다.")
  assert(type(font-size) == length, message: "font-size는 12pt처럼 길이여야 합니다.")
  assert(type(page-numbering) in (str, content, function, dictionary), message: "page-numbering은 큰 따옴표로 감싼 문자열이거나 대괄호로 감싼 내용이거나 함수이거나 딕셔너리여야 합니다.")

  _debug.update(debug)
  _font-size.update(font-size)
  _margin.update(_normalize-margin(margin, "margin"))
  _compact-margin.update(_normalize-margin(compact-margin, "compact-margin"))
  _cover-margin.update(_normalize-margin(if cover-margin == none { margin } else { cover-margin }, "cover-margin"))

  let numbering-content = page-numbering
  let numbering-align = center
  let numbering-size = none
  if type(page-numbering) == dictionary {
    numbering-content = page-numbering.at("content", default: [-- 1 --])
    numbering-align = page-numbering.at("alignment", default: center)
    numbering-size = page-numbering.at("size", default: none)
  }
  assert(type(numbering-content) in (str, content, function), message: "page-numbering의 content는 문자열이거나 내용이거나 함수여야 합니다.")
  if type(numbering-content) == str {
    numbering-content = [#numbering-content]
  }
  _page-numbering.update((content: numbering-content, alignment: numbering-align, size: numbering-size))

  // 페이지 기본 설정

  let font = (serif, san-serif)
  if default-font-type == "san-serif" or default-font-type == "고딕" {
    font = (san-serif, serif)
  }
  set text(
    font: font,
    lang: "ko",
  )
  set par(
    justify: true,
    leading: 0.86em,
    spacing: 0.86em,
    first-line-indent: 0pt,
    linebreaks: "optimized",
  )
  show link: set text(fill: link-color) if link-color != none

  // 제목 스타일링(장·절·조 등은 preset에서 정의)

  set heading(numbering: (..levels) => {
    let pos = levels.pos()
    let lvl = pos.len()
    if lvl == 1 {
      none
    } else if lvl == 2 {
      str(pos.at(1)) + "."
    } else if lvl == 3 {
      numbering("가.", pos.at(2))
    } else if lvl == 4 {
      str(pos.at(3)) + ")"
    } else if lvl == 5 {
      numbering("가", pos.at(4)) + ")"
    } else if lvl == 6 {
      "(" + str(pos.at(5)) + ")"
    }
  })

  // 1단계 제목: '목차', '정관'과 같이 페이지의 큰 구성을 나눌 때 사용합니다.
  show heading.where(level: 1): it => {
    if document-title == none {
      set document(title: it.body)
    }
    block(above: 15mm, below: 8mm)[
      #align(left)[#text(size: font-size * 5 / 3, weight: "bold", fill: black)[#it.body]]
    ]
  }

  // 2·3단계 일반 제목
  show heading.where(level: 2): it => block(above: 10mm, below: 10mm)[#it]
  show heading.where(level: 3): it => block(above: 8mm, below: 8mm)[#it]

  body

  // 단계 정의 검사: 같은 key에 다른 정의, 같은 depth에 다른 key
  context {
    for (label-name, what) in ((<rule-level-def>, "조항 단계"), (<rule-division-def>, "계층")) {
      let by-key = (:)
      let by-depth = (:)
      for m in query(label-name) {
        let d = m.value
        if d.key in by-key {
          assert(
            by-key.at(d.key) == d,
            message: what + " key '" + d.key + "'에 서로 다른 정의가 있습니다. "
              + "preset의 단계를 다시 정의했다면, 그 정의를 문서 맨 앞(import 바로 아래)에 두어 모든 곳에서 같은 정의가 쓰이게 하세요.",
          )
        } else {
          by-key.insert(d.key, d)
        }
        let dk = str(d.depth)
        if dk in by-depth {
          assert(
            by-depth.at(dk) == d.key,
            message: what + " depth " + dk + "에 서로 다른 key('" + by-depth.at(dk) + "', '" + d.key + "')가 있습니다.",
          )
        } else {
          by-depth.insert(dk, d.key)
        }
      }
    }
  }

  // 별명 중복 검사(디버그 모드에서는 빨간 글씨로 표시)
  if not debug {
    context {
      let dups = _markers().pairs().filter(((name, found)) => found.len() > 1)
      if dups.len() > 0 {
        panic(dups.map(((name, found)) => _duplicate-marker-message(name, found)).join("\n"))
      }
    }
  }

  if debug == true {
    pagebreak()
    [= Rule Marker Registry]
    context {
      let markers = _markers()
      table(
        columns: (auto, 1fr, auto),
        [*별명*], [*조항*], [*라벨*],
        ..markers.pairs().map(((name, found)) => found.map(m => (
          if found.len() > 1 [#name #text(fill: red, weight: "extrabold")[(중복)]] else [#name],
          [#m.value.texts.filter(t => t != none).join("")],
          [#raw(m.value.label)],
        ))).flatten().flatten()
      )
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 페이지 레이아웃
// ─────────────────────────────────────────────────────────────

// 표지 페이지: 표지, 목차에 사용됩니다.
#let cover-page(body) = context {
  let margin = _cover-margin.get()
  let _ = margin.remove("footer")

  set par(
    leading: 0.86em,
    spacing: 0pt,
  )
  set page(
    paper: "a4",
    margin: margin,
    numbering: none,
  )

  body
}

// 본문 페이지
#let body-page(compact-margin: false, body) = context {
  let numbering-data = _page-numbering.get()
  let numbering-content = numbering-data.content
  let numbering-align = numbering-data.alignment
  let font-size = _font-size.get()
  // 페이지 번호 크기: 기본 12pt
  let numbering-size = if numbering-data.size == none { 12pt } else { numbering-data.size }
  let margin = if compact-margin { _compact-margin.get() } else { _margin.get() }
  let footer-descent = margin.remove("footer")
  set par(
    leading: 0.86em,
    spacing: 0.86em,
  )
  set page(
    paper: "a4",
    margin: margin,
    numbering: "1",
    footer-descent: footer-descent,
    footer: context {
      let current-p = counter(page).get().first()
      set text(size: numbering-size)
      if type(numbering-content) == function {
        // 함수 형식: (page, total) 딕셔너리를 넘깁니다.
        let info = (page: current-p, total: counter(page).final().first())
        align(numbering-align, numbering-content(info))
      } else {
        // 문자열·내용 형식: 숫자를 현재 쪽 번호로 바꿉니다.
        align(numbering-align)[
          #show regex("\d+"): [#str(current-p)]
          #numbering-content
        ]
      }
    },
  )
  set text(fill: black, size: font-size)

  body
}

// ─────────────────────────────────────────────────────────────
// 페이지 구성
// ─────────────────────────────────────────────────────────────

// 표지: 로고와 제목, 개정일자와 간단한 장식이 포함된 표지입니다.
#let cover(title, revised, accent-color, sub-logo, main-logo) = [
  #align(left)[#sub-logo]
  #v(28mm)
  #rect(
    width: 100%,
    height: 10mm,
    fill: accent-color.transparentize(50%),
    stroke: none,
  )
  #v(12mm)
  #align(center)[#text(size: 28pt, weight: "bold", fill: black)[#title]]
  #v(12mm)
  #rect(
    width: 100%,
    height: 10mm,
    fill: accent-color.transparentize(50%),
    stroke: none,
  )
  #v(28mm)
  #align(center)[#text(size: 18pt, weight: "medium", fill: red)[#revised]]
  #v(1fr)
  #align(center)[#main-logo]
  #pagebreak()
]

// 간단한 표지: 제목 및 상단과 하단에 추가로 작성할 수 있는 텍스트들을 직사각형 박스로 둘러싼 간단한 형태의 표지입니다.
#let simple-cover(title, top-text: none, bottom-text: none) = [
  #if top-text != none {
    align(center + top)[
      #set par(spacing: 0.86em)
      #rect(stroke: 1pt + black, inset: 30pt, radius: 0pt, [
        #text(
          size: 18pt,
          fill: black,
          tracking: 3pt,
          hyphenate: true,
        )[#top-text]
      ])
    ]
  }
  #align(center + horizon)[
    #set par(spacing: 0.86em)
    #rect(stroke: 1pt + black, inset: 30pt, radius: 0pt, [
      #text(
        size: 20pt,
        weight: "bold",
        fill: black,
        tracking: 3pt,
        hyphenate: true,
      )[#title]
    ])
  ]
  #if bottom-text != none {
    align(center + bottom)[
      #set par(spacing: 0.86em)
      #rect(stroke: 1pt + black, inset: 30pt, radius: 0pt, [
        #text(
          size: 18pt,
          fill: black,
          tracking: 3pt,
          hyphenate: true,
        )[#bottom-text]
      ])
    ]
  }

  #pagebreak()
]

// 목차 페이지
#let toc-page(depth: 3) = [
  #show: body => context {
    set text(fill: black, size: _font-size.get())
    body
  }
  #context text(size: _font-size.get() * 2, weight: "bold")[목차]
  #v(12mm)
  #[
    #set outline.entry(fill: repeat([.], gap: 0.20em))
    #show outline.entry: set block(above: 5mm)
    #show outline.entry.where(level: 1): none
    #show outline.entry: set text(weight: "regular")
    #outline(title: none, depth: depth, indent: 1em)
  ]
  #pagebreak()
]

// 개정 이력
#let revision-history(entries, alignment: right) = [
  #block(width: 100%, below: 10mm)[
    #align(alignment)[
      #context text(size: _font-size.get() * 13 / 12, fill: black)[
        #grid(
          columns: (auto, auto),
          column-gutter: 18pt,
          row-gutter: 0.86em,
          align: (alignment, alignment),
          ..entries.flatten()
        )
      ]
    ]
  ]
]

// ─────────────────────────────────────────────────────────────
// 단계 정의: 조항(make-level)
// ─────────────────────────────────────────────────────────────

// 디버그 정보를 앞 조항과 겹치지 않도록 블록으로 띄워 표시합니다.
#let _debug-note(body) = context block(above: par.leading, below: 0pt, width: 100%, body)

// 번호 해석: 3 → "3." / "제3호", "3~4" → 범위, "3-2" → 가지번호
// 쓸 수 없는 번호는 오류 대신 invalid에 남깁니다(상태 갱신 안의 오류는 Typst가 보여 주지 않음).
#let _number-info(args, n, who) = {
  let raw-bare = args.bare
  let raw-cite = if args.cite-bare == none { args.bare } else { args.cite-bare }
  let bare(x) = { let v = raw-bare(x); if v == none { str(x) } else { v } }
  let cite-bare(x) = { let v = raw-cite(x); if v == none { str(x) } else { v } }
  let first-invalid(xs) = xs.find(x => raw-bare(x) == none or raw-cite(x) == none)
  let sfx = args.suffix
  let cite(x) = args.cite-prefix + cite-bare(x) + args.unit
  if type(n) == int {
    return (part: str(n), num: [#(bare(n) + sfx)], cite: cite(n), range: false, branch: false, invalid: first-invalid((n,)))
  }
  assert(type(n) == str, message: who + ": 번호는 정수이거나 \"3~4\"(범위), \"3-2\"(가지번호) 형식의 문자열이어야 합니다.")
  let r = n.match(regex("^\s*(\d+)\s*~\s*(\d+)\s*$"))
  if r != none {
    let (a, z) = r.captures.map(int)
    return (
      part: str(a) + "to" + str(z),
      num: [#(bare(a) + " ~ " + bare(z) + sfx)],
      cite: cite(a) + "부터 " + cite(z) + "까지",
      range: true,
      branch: false,
      invalid: first-invalid((a, z)),
    )
  }
  let b = n.match(regex("^\s*(\d+)\s*-\s*(\d+)\s*$"))
  assert(b != none, message: who + ": 번호 문자열은 \"3~4\"(범위) 또는 \"3-2\"(가지번호) 형식이어야 합니다. 입력: " + repr(n))
  assert(args.branch, message: who + ": 가지번호를 쓰려면 make-level에 branch: true를 지정해야 합니다.")
  let (a, br) = b.captures.map(int)
  (
    part: str(a) + "-" + str(br),
    num: [#(bare(a) + "의" + str(br) + sfx)],
    cite: cite(a) + "의" + str(br),
    range: false,
    branch: true,
    invalid: first-invalid((a,)),
  )
}

// 조항 하나를 출력합니다. mode: "auto"(자동 번호), "branch"(가지번호), "manual"(수동 번호)
#let _provision(args, style, who, mode, n, title, body, m) = {
  let d = args.depth
  // 번호 형식 검사
  if mode == "manual" { let _ = _number-info(args, n, who) }
  // 들어갈 때: 번호를 정하고 위치를 쌓습니다.
  _pos.update(p => {
    let counts = p.counts
    let branches = p.branches
    let num = n
    if mode == "auto" {
      let c = counts.at(d, default: 0) + 1
      counts = counts.slice(0, calc.min(d, counts.len()))
      while counts.len() < d { counts.push(0) }
      counts.push(c)
      branches = branches.pairs().filter(((k, v)) => int(k) < d).to-dict()
      branches.insert(str(d), 1)
      num = c
    } else if mode == "branch" {
      let b = branches.at(str(d), default: 1) + 1
      branches = branches.pairs().filter(((k, v)) => int(k) <= d).to-dict()
      branches.insert(str(d), b)
      num = str(counts.at(d, default: 0)) + "-" + str(b)
      counts = counts.slice(0, calc.min(d + 1, counts.len()))
    } else {
      counts = counts.slice(0, calc.min(d + 1, counts.len()))
      branches = branches.pairs().filter(((k, v)) => int(k) <= d).to-dict()
    }
    let info = _number-info(args, num, who)
    let path = p.path.slice(0, calc.min(d, p.path.len()))
    while path.len() < d { path.push(none) }
    path.push((key: args.key, part: info.part, text: info.cite, num: info.num, range: info.range, branch: info.branch, invalid: info.invalid))
    (..p, path: path, stack: p.stack + ((zone: p.zone, path: p.path),), counts: counts, branches: branches)
  })
  context {
    let cur = _pos.get()
    let path = cur.path
    let me = path.at(d, default: none)
    // 첫 조판 단계에서는 위치가 없을 수 있으므로 임시 값으로 진행합니다.
    if me == none or me.key != args.key {
      me = (key: args.key, part: "0", text: "", num: [], range: false, branch: false, invalid: none)
      path = path.slice(0, calc.min(d, path.len()))
      while path.len() < d { path.push(none) }
      path.push(me)
    }

    // 쓸 수 없는 번호(디버그 모드에서는 빨간 글씨로 표시)
    let invalid-msg = if me.invalid == none { none } else {
       "사용할 수 없는 " + args.unit + " 번호 "
    }
    if invalid-msg != none and not _debug.get() { panic(who + ": " + invalid-msg + str(me.invalid)) }

    let parent = none
    for p in path.slice(0, d).rev() {
      if p != none {
        parent = p.key
        break
      }
    }
    // em 기준: 단계의 size, 없으면 현재 글자 크기
    let s = _resolve-style(style, parent)
    let base = text.size
    if s.size != none {
      base = s.size.abs + s.size.em * base
      s.size = base
    }
    let ctx = (
      style: _absolutize(s, base),
      key: args.key,
      depth: d,
      parent: parent,
      range: me.range,
      branch: me.branch,
      addendum: cur.zone > 0,
      title: title,
      cite: me.text,
      heading-level: args.heading-level,
    )

    if raw.tab-size == _table-flag {
      // 대비표 안: 라벨 없이 render-table로 그립니다.
      assert(args.render-table != none, message: who + ": 이 단계는 표 안 생김새(render-table)가 정의되지 않아 신·구조문대비표 안에서 쓸 수 없습니다.")
      (args.render-table)(me.num, body, ctx)
      if invalid-msg != none { _debug-note(text(fill: red, weight: "extrabold")[#invalid-msg]) }
    } else {
      let lab = _label-string(cur.zone, path.map(p => if p == none { none } else { (key: p.key, part: p.part) }))
      [#metadata(args)<rule-level-def>]
      [#metadata((zone: cur.zone, parts: path.map(p => if p == none { none } else { p.part })))#label(lab)]
      if m != none {
        let texts = path.map(p => if p == none { none } else { p.text })
        if cur.zone > 0 and texts.first() != none { texts.at(0) = "부칙 " + texts.first() }
        [#metadata((
            name: m,
            label: lab,
            zone: cur.zone,
            parts: path.map(p => if p == none { none } else { p.part }),
            texts: texts,
          ))<rule-marker>]
      }
      (args.render)(me.num, body, ctx)
      if invalid-msg != none { _debug-note(text(fill: red, weight: "extrabold")[#invalid-msg]) }
      if _debug.get() {
        _debug-note({
          [#text(fill: green)[#repr(label(lab)) ]#text(fill: purple)[#if m == none [none] else { m }]]
          if m != none and query(<rule-marker>).filter(x => x.value.name == m).len() > 1 {
            [ #text(fill: red, weight: "extrabold")[별명이 중복됨]]
          }
        })
      }
    }
  }
  // 나올 때: 이전 위치로 되돌립니다(번호는 유지).
  _pos.update(p => {
    let prev = p.stack.last()
    (..p, zone: prev.zone, path: prev.path, stack: p.stack.slice(0, -1))
  })
}

// 조항 단계를 정의합니다. (자동 번호 함수, [가지번호 함수], 수동 번호 함수, 정의 인자)를 반환합니다.
#let make-level(
  key: none,
  depth: none,
  branch: false,
  title: false,
  heading-level: none,
  bare: none,
  suffix: "",
  cite-bare: none,
  cite-prefix: "",
  unit: none,
  parse: none,
  style: (:),
  render: none,
  render-table: none,
) = {
  let args = (
    key: key,
    depth: depth,
    branch: branch,
    title: title,
    heading-level: heading-level,
    bare: bare,
    suffix: suffix,
    cite-bare: cite-bare,
    cite-prefix: cite-prefix,
    unit: unit,
    parse: parse,
    style: style,
    render: render,
    render-table: render-table,
  )
  let who = "make-level(key: " + repr(key) + ")"
  assert(type(key) == str and key.match(regex("^[a-z][a-z0-9]*$")) != none, message: "make-level: key는 영문 소문자로 시작하는 영문 소문자·숫자 문자열이어야 합니다. 입력: " + repr(key))
  assert(type(depth) == int and depth >= 0, message: who + ": depth는 0 이상의 정수여야 합니다.")
  assert(type(branch) == bool and type(title) == bool, message: who + ": branch와 title은 true 또는 false여야 합니다.")
  assert(heading-level == none or (type(heading-level) == int and heading-level >= 1), message: who + ": heading-level은 none이거나 1 이상의 정수여야 합니다.")
  assert(type(bare) == function, message: who + ": bare는 번호(정수)를 받아 문자열을 돌려주는 함수여야 합니다.")
  assert(type(suffix) == str and type(cite-prefix) == str, message: who + ": suffix와 cite-prefix는 문자열이어야 합니다.")
  assert(cite-bare == none or type(cite-bare) == function, message: who + ": cite-bare는 함수이거나 none(bare와 같음)이어야 합니다.")
  assert(type(unit) == str, message: who + ": unit은 문자열이어야 합니다. (예: \"항\")")
  assert(type(parse) == regex, message: who + ": parse는 정규식이어야 합니다. (예: regex(\"제\\s*(\\d+)\\s*항\"))")
  assert(type(render) == function, message: who + ": render는 필수입니다. (num, body, ctx) => content 형태의 함수를 넘기세요.")
  assert(render-table == none or type(render-table) == function, message: who + ": render-table은 함수이거나 none이어야 합니다.")
  let s = _normalize-style(style, _level-style-schema, who, allow-title: title)

  let auto-impl(t, body, m) = _provision(args, s, who, "auto", none, t, body, m)
  let branch-impl(t, body, m) = _provision(args, s, who, "branch", none, t, body, m)
  let manual-impl(n, t, body, m) = _provision(args, s, who, "manual", n, t, body, m)

  let fns = if title {
    (
      (t, body, m: none) => auto-impl(t, body, m),
      (t, body, m: none) => branch-impl(t, body, m),
      (n, t, body, m: none) => manual-impl(n, t, body, m),
    )
  } else {
    (
      (body, m: none) => auto-impl(none, body, m),
      (body, m: none) => branch-impl(none, body, m),
      (n, body, m: none) => manual-impl(n, none, body, m),
    )
  }
  if branch { (fns.at(0), fns.at(1), fns.at(2), args) } else { (fns.at(0), fns.at(2), args) }
}

// ─────────────────────────────────────────────────────────────
// 단계 정의: 계층(make-division)
// ─────────────────────────────────────────────────────────────

#let _division(args, style, who, n, title) = {
  let num = if type(n) == int {
    (args.cite-prefix + (args.bare)(n) + args.unit, false)
  } else {
    let b = if type(n) == str { n.match(regex("^\s*(\d+)\s*-\s*(\d+)\s*$")) } else { none }
    assert(b != none, message: who + ": 번호는 정수이거나 \"2-2\"(가지번호) 형식의 문자열이어야 합니다.")
    assert(args.branch, message: who + ": 가지번호를 쓰려면 make-division에 branch: true를 지정해야 합니다.")
    let (a, br) = b.captures.map(int)
    (args.cite-prefix + (args.bare)(a) + args.unit + "의" + str(br), true)
  }
  // 계층이 시작되면 본칙으로 돌아갑니다.
  _pos.update(p => (..p, zone: 0, path: ()))
  [#metadata(args)<rule-division-def>]
  context (args.render)(num.at(0), title, (
    style: _absolutize(style, text.size),
    key: args.key,
    depth: args.depth,
    heading-level: args.heading-level,
    outlined: args.outlined,
    branch: num.at(1),
  ))
}

// 계층(편·장·절·관 등)을 정의합니다. (자동 번호 함수, [가지번호 함수], 수동 번호 함수, 정의 인자)를 반환합니다.
#let make-division(
  key: none,
  depth: none,
  branch: false,
  bare: none,
  cite-prefix: "",
  unit: none,
  heading-level: none,
  outlined: true,
  style: (:),
  render: none,
) = {
  let args = (
    key: key,
    depth: depth,
    branch: branch,
    bare: bare,
    cite-prefix: cite-prefix,
    unit: unit,
    heading-level: heading-level,
    outlined: outlined,
    style: style,
    render: render,
  )
  let who = "make-division(key: " + repr(key) + ")"
  assert(type(key) == str and key.match(regex("^[a-z][a-z0-9]*$")) != none, message: "make-division: key는 영문 소문자로 시작하는 영문 소문자·숫자 문자열이어야 합니다. 입력: " + repr(key))
  assert(type(depth) == int and depth >= 0, message: who + ": depth는 0 이상의 정수여야 합니다.")
  assert(type(branch) == bool and type(outlined) == bool, message: who + ": branch와 outlined는 true 또는 false여야 합니다.")
  assert(type(bare) == function, message: who + ": bare는 번호(정수)를 받아 문자열을 돌려주는 함수여야 합니다.")
  assert(type(cite-prefix) == str and type(unit) == str, message: who + ": cite-prefix와 unit은 문자열이어야 합니다.")
  assert(type(heading-level) == int and heading-level >= 1, message: who + ": heading-level은 1 이상의 정수여야 합니다.")
  assert(type(render) == function, message: who + ": render는 필수입니다. (num, title, ctx) => content 형태의 함수를 넘기세요.")
  let s = _normalize-style(style, _heading-style-schema, who)

  let auto-fn(title) = {
    _division-counter.step(level: depth + 1)
    _division-branch-counter(key).update(1)
    context _division(args, s, who, _division-counter.get().at(depth, default: 0), title)
  }
  let branch-fn(title) = {
    _division-branch-counter(key).step()
    _division-counter.update((..ns) => {
      let a = ns.pos()
      if a.len() > depth + 1 { a.slice(0, depth + 1) } else { a }
    })
    context {
      let n = _division-counter.get().at(depth, default: 0)
      let b = _division-branch-counter(key).get().first()
      _division(args, s, who, str(n) + "-" + str(b), title)
    }
  }
  let manual-fn(n, title) = _division(args, s, who, n, title)
  if branch { (auto-fn, branch-fn, manual-fn, args) } else { (auto-fn, manual-fn, args) }
}

// ─────────────────────────────────────────────────────────────
// 부칙
// ─────────────────────────────────────────────────────────────

// 부칙 제목 기본 생김새
#let _default-addendum-style = (
  size: 1.33em,
  weight: "bold",
  align: center,
  above: 1.18em,
  below: 2.36em,
)
#let _default-addendum-render(title, ctx) = {
  let s = ctx.style
  show heading: it => block(above: s.above, below: s.below, width: 100%)[
    #align(s.align)[#text(size: s.size, weight: s.weight, fill: black)[#it.body]]
  ]
  heading(level: 2, outlined: false, numbering: none, title)
}

// 부칙을 정의합니다. 생김새만 바꿀 수 있습니다. (부칙 함수, 정의 인자)를 반환합니다.
#let make-addendum(style: _default-addendum-style, render: _default-addendum-render) = {
  let args = (style: style, render: render)
  let who = "make-addendum"
  assert(type(render) == function, message: who + ": render는 (title, ctx) => content 형태의 함수여야 합니다.")
  let s = _normalize-style(style, _heading-style-schema, who)

  // hint: 부칙을 인용할 때 쓰는 문자열(또는 배열). 결과물에는 표시되지 않습니다.
  let addendum-fn(title, hint: none) = {
    let hints = if hint == none { () } else if type(hint) == str { (hint,) } else { hint }
    assert(
      type(hints) == array and hints.all(h => type(h) == str and h.trim() != ""),
      message: "addendum의 hint는 비어 있지 않은 문자열이거나 문자열의 배열이어야 합니다.",
    )
    // 부칙 구역으로 들어가고 조 번호를 초기화합니다.
    _pos.update(p => (..p, zone: p.addenda + 1, addenda: p.addenda + 1, path: (), counts: (), branches: (:)))
    [#metadata((hints: hints))<rule-addendum-meta>]
    context render(title, (style: _absolutize(s, text.size), hints: hints))
    context if _debug.get() {
      let shown = if hints.len() == 0 { "none" } else { hints.map(h => "\"" + h + "\"").join(", ") }
      align(center, text(fill: maroon)[Hint: #shown])
    }
  }
  (addendum-fn, args)
}

// 기본 부칙
#let (addendum, addendum-args) = make-addendum()

// 원형 숫자 변환 함수. 유니코드 자체의 한계로 인해 최대 50까지만 변환할 수 있습니다.
#let circ(num) = {
  if num >= 1 and num <= 20 {
    str.from-unicode(0x245f + num)
  } else if num >= 21 and num <= 35 {
    str.from-unicode(0x323C + num)
  } else if num >= 36 and num <= 50 {
    str.from-unicode(0x328D + num)
  } else {
    str(num) // 50을 넘어가면 일반 숫자로 표시
  }
}

// ─────────────────────────────────────────────────────────────
// 인용
// ─────────────────────────────────────────────────────────────

// 오류 메시지에 쓸 부칙 목록을 만듭니다.
#let _describe-addenda(addenda) = (
  addenda
    .enumerate()
    .map(((i, hints)) => {
      let shown = if hints.len() == 0 { "(힌트 없음)" } else { hints.map(h => "\"" + h + "\"").join(", ") }
      "  " + str(i + 1) + "번째 부칙: " + shown
    })
    .join("\n")
)

// 인용문에 포함된 부칙 힌트를 찾습니다. 긴 힌트 안의 짧은 힌트는 제외합니다.
#let _match-addendum-hints(text-val, addenda) = {
  let found = ()
  for (i, hints) in addenda.enumerate() {
    for h in hints {
      if text-val.contains(h) { found.push((num: i + 1, hint: h)) }
    }
  }
  let kept = ()
  for f in found.sorted(key: f => -f.hint.len()) {
    if not kept.any(k => k.hint.contains(f.hint)) { kept.push(f) }
  }
  (nums: kept.map(f => f.num).dedup(), hints: kept.map(f => f.hint))
}

// 번호 문자열을 정수로 바꿉니다(예: 목의 "다"를 3으로). 찾지 못하면 none을 돌려줍니다.
#let _number-from(def, s) = {
  if s.match(regex("^\d+$")) != none { return int(s) }
  let make = if def.cite-bare == none { def.bare } else { def.cite-bare }
  for n in range(1, 1000) {
    if make(n) == s { return n }
  }
  none
}

// 이 규정 문서의 특정 조문을 인용합니다.
#let at(body) = context {
  let text-val = _plain-text(body).trim()
  if text-val == "" { return body }

  // 오류(디버그 모드에서는 빨간 글씨로 표시)
  let fail(msg) = {
    if _debug.get() { [#body#text(fill: red, weight: "extrabold")[(#msg)]] } else { panic(msg) }
  }

  let is-citation-addendum = text-val.match(regex("부\s*칙")) != none
  let addenda = query(<rule-addendum-meta>).map(m => m.value.hints)

  // 부칙 힌트를 찾아, 번호로 읽히지 않게 인용문에서 지웁니다.
  let hinted-addendum = none
  let parse-text = text-val
  if is-citation-addendum {
    let r = _match-addendum-hints(text-val, addenda)
    if r.nums.len() > 1 {
      return fail(
        "인용문이 여러 부칙의 힌트와 일치합니다.\n입력: \"" + text-val + "\"\n일치한 힌트: "
          + r.hints.map(h => "\"" + h + "\"").join(", ") + "\n후보:\n" + _describe-addenda(addenda),
      )
    }
    if r.nums.len() == 1 {
      hinted-addendum = r.nums.first()
      for h in r.hints { parse-text = parse-text.replace(h, " ") }
    }
  }

  // 단계별로 번호를 읽습니다.
  let defs = _level-defs()
  let found = (:) // depth(문자열) → (key, part)
  for def in defs {
    let mt = parse-text.match(def.parse)
    if mt != none {
      let num = _number-from(def, mt.captures.first())
      if num == none {
        return fail("인용문의 " + def.unit + " 번호를 해석할 수 없습니다: \"" + mt.captures.first() + "\"\n입력: \"" + text-val + "\"")
      }
      let br = mt.captures.at(1, default: none)
      found.insert(str(def.depth), (key: def.key, part: str(num) + if br != none { "-" + br } else { "" }))
    }
  }
  if found.len() == 0 {
    return fail("인용문에서 조항 번호를 찾을 수 없습니다.\n입력: \"" + text-val + "\"")
  }

  let current = _pos.get()
  let depths = found.keys().map(int)
  let top = calc.min(..depths)
  let bottom = calc.max(..depths)
  let entries = ()
  for d in range(bottom + 1) {
    if str(d) in found {
      entries.push(found.at(str(d)))
    } else if d < top {
      // 상위 단계: 현재 위치
      let c = current.path.at(d, default: none)
      entries.push(if c == none { none } else { (key: c.key, part: c.part) })
    } else {
      // 빠진 단계: 0
      entries.push(none)
    }
  }

  // 부칙 처리
  let explicit-top = top == 0
  let zone = 0
  if is-citation-addendum or (not explicit-top and current.zone > 0) {
    zone = if hinted-addendum != none { hinted-addendum } else if current.zone > 0 {
      current.zone
    } else if addenda.len() == 1 { 1 } else { none }
    if zone == none {
      return fail(
        if addenda.len() == 0 {
          "인용할 부칙이 없습니다.\n입력: \"" + text-val + "\""
        } else {
          (
            "부칙이 여러 개라 어느 부칙을 인용하는지 알 수 없습니다. 인용문에 아래 힌트 중 하나를 포함하세요."
              + " 힌트가 없는 부칙은 addendum의 hint로 지정할 수 있습니다.\n입력: \"" + text-val + "\"\n후보:\n"
              + _describe-addenda(addenda)
          )
        },
      )
    }
  }

  let target-string = _label-string(zone, entries)
  let target-label = label(target-string)
  let exists = query(target-label).len() > 0
  if not exists and not _debug.get() {
    panic("at() 인용 대상이 존재하지 않습니다.\n입력: \"" + text-val + "\"\n" + repr(here().position()) + "\nLabel: `" + repr(target-label) + "`")
  }
  link(if exists { target-label } else { here() })[#body]
  if _debug.get() {
    link(if exists { target-label } else { here() })[#text(fill: blue)[(#repr(target-label))]]
    if not exists [#text(fill: red, weight: "extrabold")[해당 위치를 찾을 수 없음.]]
  }
}

// 별명으로 조항을 인용합니다.
#let at-m(marker-args) = context {
  let markers = _markers()

  // 별명으로 조항 찾기
  let get-target(name) = {
    let found = markers.at(name, default: ())
    if _debug.get() != true {
      assert(found.len() > 0, message: "별명을 찾을 수 없습니다: " + name)
      assert(found.len() == 1, message: _duplicate-marker-message(name, found))
    }
    if found.len() == 1 { found.first().value } else { none }
  }

  // 기준 위치와 겹치는 상위 단계를 생략한 인용문
  let compute-parts(target, base) = {
    let diff-found = target.zone != base.zone
    let text-parts = ()
    for (d, part) in target.parts.enumerate() {
      if not diff-found and part != base.parts.at(d, default: none) { diff-found = true }
      let t = target.texts.at(d)
      if diff-found and t != none { text-parts.push(t) }
    }
    // 자기 자신 인용
    if text-parts.len() == 0 {
      text-parts.push(target.texts.filter(t => t != none).last())
    }
    text-parts.join("")
  }
  let as-base(target) = (zone: target.zone, parts: target.parts)

  let current = _pos.get()
  let caller = (zone: current.zone, parts: current.path.map(p => if p == none { none } else { p.part }))

  // 디버그 모드용 누락·중복 별명 표기
  let debug-error(name) = {
    if markers.at(name, default: ()).len() > 1 {
      [#text(fill: red, weight: "extrabold")["#name" 별명이 중복됨]]
    } else {
      [#text(fill: red, weight: "extrabold")["#name" 별명을 찾을 수 없음.]]
    }
  }

  if type(marker-args) == str {
    // 단일 인용
    let target = get-target(marker-args)
    if target == none { return debug-error(marker-args) }
    let target-label = label(target.label)
    link(target-label)[#compute-parts(target, caller)]
    if _debug.get() == true {
      link(target-label)[#text(fill: blue)[(#repr(target-label))]]
    }
  } else if type(marker-args) == array {
    if marker-args.len() == 0 { return () }

    if type(marker-args.at(0)) == array {
      // 범위 인용
      let range-pair = marker-args.at(0)
      assert(range-pair.len() == 2, message: "범위 인용은 정확히 2개의 별명이 필요합니다.")
      let start-target = get-target(range-pair.at(0))
      let end-target = get-target(range-pair.at(1))
      if start-target == none { return debug-error(range-pair.at(0)) }
      if end-target == none { return debug-error(range-pair.at(1)) }

      let start-text = compute-parts(start-target, caller)
      let end-text = compute-parts(end-target, as-base(start-target))
      [#link(label(start-target.label))[#start-text]부터 #link(label(end-target.label))[#end-text]까지]
      if _debug.get() == true {
        [#link(label(start-target.label))[(#repr(label(start-target.label))] ~ #link(label(end-target.label))[(#repr(label(end-target.label))]]
      }
    } else {
      // 나열 인용
      let targets = marker-args.map(name => (name: name, obj: get-target(name)))
      for t in targets { if t.obj == none { return debug-error(t.name) } }

      let result-content = ()
      let base = caller
      for t in targets {
        result-content.push([
          #link(label(t.obj.label))[#compute-parts(t.obj, base)]
          #if _debug.get() == true [
            #text(fill: blue, size: 0.8em)[<#t.obj.label>]
          ]
        ])
        base = as-base(t.obj)
      }

      let len = result-content.len()
      if len == 1 { return result-content.at(0) } else if len == 2 {
        return [#result-content.at(0) 및 #result-content.at(1)]
      } else {
        let front = result-content.slice(0, len - 1).join(", ")
        return [#front 및 #result-content.at(len - 1)]
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
// 신·구조문대비표
// ─────────────────────────────────────────────────────────────

// 표 모드: 이 안의 조항은 render-table로 그립니다.
// 표 안에서 바뀐 자동 번호는 표를 나올 때 되돌려, 본문 번호에 영향을 주지 않게 합니다.
#let _table-scope(body) = {
  _pos.update(p => (..p, saved: p.saved + ((counts: p.counts, branches: p.branches),)))
  {
    set raw(tab-size: _table-flag)
    body
  }
  _pos.update(p => {
    let last = p.saved.last()
    (..p, counts: last.counts, branches: last.branches, saved: p.saved.slice(0, -1))
  })
}

#let side-by-side-table(
  hide-inner-stroke: false,
  no-inset: false,
  hide-remark: false,
  rows,
) = _table-scope(
  block(width: 100%, above: 1.2em, below: 1.2em, breakable: true)[
    #show: body => context {
      set text(size: _font-size.get() * 5 / 6)
      body
    }
    #set par(leading: 0.86em, first-line-indent: 0pt)

    #let table-stroke(col, row, total-rows) = {
      let base-stroke = 0.5pt + gray

      if hide-inner-stroke {
        let bottom-line = if row == 0 or row == total-rows - 1 {
          base-stroke
        } else { none }
        let top-line = if row == 0 { base-stroke } else { none }
        (
          left: base-stroke,
          right: base-stroke,
          top: top-line,
          bottom: bottom-line,
        )
      } else {
        base-stroke
      }
    }

    #let columns = (1fr, 1fr, 0.4fr)
    #let final-rows = rows
    #if hide-remark == true {
      columns = (1fr, 1fr)
      final-rows = final-rows.map(it => (it.at(0), it.at(1)))
    }

    #table(
      columns: columns,
      stroke: (col, row) => table-stroke(col, row, final-rows.len() + 1),
      fill: (col, row) => if row == 0 { rgb("#f9f9fa") } else { none },
      align: (col, row) => if row == 0 { center + horizon } else { left + top },
      ..if not no-inset { (inset: (x: 10pt, y: 12pt)) },
      table.header(
        [*현행*],
        [*개정안*],
        ..if not hide-remark { ([*비고*],) } else { () },
        repeat: false
      ),

      ..final-rows.flatten()
    )
  ],
)

// 개별 행 함수
#let compare-row(old-content, new-content, remark: none) = (
  [#old-content],
  [#new-content],
  [#remark],
)

// ─────────────────────────────────────────────────────────────
// 기타 문장부호
// ─────────────────────────────────────────────────────────────

// 겹낫표(『』): 책의 제목이나 신문 이름 등을 나타낼 때 사용합니다.
#let d-bracket(body) = [『#body』]

// 겹화살괄호(《》): 책의 제목이나 신문 이름 등을 나타낼 때 사용합니다.
#let d-arrow(body) = [《#body》]

// 홑낫표(｢｣): 소제목, 그림이나 노래와 같은 예술 작품의 제목, 상호, 법률, 규정 등을 나타낼 때 사용합니다.
#let s-bracket(body) = [｢#body｣]

// 홑화살괄호(〈〉): 소제목, 그림이나 노래와 같은 예술 작품의 제목, 상호, 법률, 규정 등을 나타낼 때 사용합니다.
#let s-arrow(body) = [〈#body〉]

// 가운뎃점(·): 짝을 이루는 것을 나타낼 때 사용합니다. Typst의 sym.dot.c를 사용합니다.
#let cdot = sym.dot.c
