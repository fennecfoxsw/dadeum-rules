// == 전체 프리셋 ==
// 계층: 편·장·절·관 / 단계: 조·항·호·목
// 단계 구성을 크게 바꾸려면 이 파일을 복사해 고쳐 쓰세요.
// 길이 단위에 pt·mm을 사용하면 고정 크기, em을 사용하면 기본 글자 크기에 비례한 크기로 설정됩니다.

#import "../template.typ": *
#import "../renders.typ"

// ─────────────────────────────────────────────────────────────
// 계층
// ─────────────────────────────────────────────────────────────

#let (part, branch-part, manual-part, part-args) = make-division(
  key: "part",
  depth: 0,
  branch: true,
  bare: n => str(n),
  cite-prefix: "제",
  unit: "편",
  heading-level: 2,
  style: (size: 1.5em, weight: "bold", align: center, above: 1.18em, below: 2.83em),
  render: renders.division-heading,
)

#let (chapter, branch-chapter, manual-chapter, chapter-args) = make-division(
  key: "chapter",
  depth: 1,
  branch: true,
  bare: n => str(n),
  cite-prefix: "제",
  unit: "장",
  heading-level: 3,
  style: (size: 1.33em, weight: "bold", align: center, above: 1.18em, below: 2.36em),
  render: renders.division-heading,
)

#let (section-title, branch-section-title, manual-section-title, section-title-args) = make-division(
  key: "section",
  depth: 2,
  branch: true,
  bare: n => str(n),
  cite-prefix: "제",
  unit: "절",
  heading-level: 4,
  style: (size: 1.17em, weight: "bold", align: left, above: 1.18em, below: 1.89em),
  render: renders.division-heading,
)

#let (subsection, branch-subsection, manual-subsection, subsection-args) = make-division(
  key: "subsection",
  depth: 3,
  branch: true,
  bare: n => str(n),
  cite-prefix: "제",
  unit: "관",
  heading-level: 5,
  style: (size: 1.08em, weight: "bold", align: left, above: 0.94em, below: 1.42em),
  render: renders.division-heading,
)

// ─────────────────────────────────────────────────────────────
// 조항
// ─────────────────────────────────────────────────────────────

// 번호와 본문 사이 최소 간격(번호의 마침표 끝부터). num-width는 한 자리 번호가 이 간격을 두고
// 들어가도록 잡아 두었습니다. 두 자리 번호나 범위 번호처럼 더 긴 번호만 본문이 밀립니다.
#let _min-gap = 1em

#let (article, branch-article, manual-article, article-args) = make-level(
  key: "article",
  depth: 0,
  branch: true,
  title: true,
  bare: n => str(n),
  cite-prefix: "제",
  unit: "조",
  parse: regex("제\s*(\d+)\s*조(?:\s*의\s*(\d+))?"),
  heading-level: 6,
  style: (title-size: 1em, title-weight: "bold", title-gap: 0.5em, above: 1.86em, below: 1.86em, table-gap: 0.25em),
  render: renders.article-render,
  render-table: renders.article-render-table,
)
#let b-article = branch-article

#let (clause, manual-clause, clause-args) = make-level(
  key: "clause",
  depth: 1,
  bare: circ,
  cite-bare: n => str(n), // 표시는 ①, 인용은 제1항
  cite-prefix: "제",
  unit: "항",
  parse: regex("제\s*(\d+)\s*항"),
  style: (
    num-indent: 0.4em,
    num-width: 2.2em,
    min-gap: _min-gap,
    above: 0.86em,
    below: 0pt,
    table-indent: 0pt,
    table-gap: 0.5em,
  ),
  render: renders.numbered,
  render-table: renders.numbered-table,
)

#let (numitem, branch-numitem, manual-numitem, numitem-args) = make-level(
  key: "numitem",
  depth: 2,
  branch: true,
  bare: n => str(n),
  suffix: ".",
  cite-prefix: "제",
  unit: "호",
  parse: regex("제\s*(\d+)\s*호(?:\s*의\s*(\d+))?"),
  style: (
    num-indent: (default: 1.75em, clause: -0.65em),
    num-width: 1.9em,
    min-gap: _min-gap,
    above: 0.86em,
    below: 0pt,
    table-indent: (default: 0pt, clause: 1.5em),
    table-gap: 0.5em,
  ),
  render: renders.numbered,
  render-table: renders.numbered-table,
)

#let (subitem, manual-subitem, subitem-args) = make-level(
  key: "subitem",
  depth: 3,
  bare: hangeul-number,
  suffix: ".",
  unit: "목",
  parse: regex("제?\s*(?:\()?([" + hangeul-number-chars + "])(?:\))?\s*목"),
  style: (
    num-indent: -1.1em,
    num-width: 2.3em,
    min-gap: _min-gap,
    above: 0.86em,
    below: 0pt,
    table-indent: 3em,
    table-gap: 0.5em,
  ),
  render: renders.numbered,
  render-table: renders.numbered-table,
)
