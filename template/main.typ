#import "@local/dadeum-rules:0.1.0": *
#import preset.basic: * // 편·관까지 쓰려면 preset.full

#show: rule-document.with(
  document-title: [○○ 정관],
  debug: false, // true로 바꾸면 조항 라벨과 별명, 인용 대상이 문서에 표시됩니다.
)

// ===== 표지·목차 =====

#show: cover-page

#cover(
  [○○ 정관],
  "2026. 1. 1. 개정",
  rgb("#239dad"),
  image("sub_logo.png", height: 10mm),
  image("main_logo.png", height: 15mm),
)

// 장식이 없는 표지를 쓰려면 위 cover 대신 아래를 사용하세요.
// #simple-cover(
//   [○○ 정관],
//   top-text: [○○],
//   bottom-text: [2026. 1. 1. 개정],
// )

#toc-page()

// ===== 본문 =====

#show: body-page

= 정관

#revision-history((
  ("2024. 1. 1.", "제정"),
  ("2025. 1. 1.", "1차 개정"),
  ("2026. 1. 1.", "2차 개정"),
))

#chapter[총칙]

#article[목적][
  이 정관은 ○○(이하 "법인"이라 한다)의 조직과 운영에 필요한 사항을 정함을 목적으로 한다.
]

#article[정의][
  이 정관에서 사용하는 용어의 뜻은 다음과 같다.
  #numitem(m: "회원")["회원"이란 #at[제4조]에 따라 법인에 가입한 사람을 말한다.]
  #numitem["임원"이란 다음 각 목의 사람을 말한다.
    #subitem[이사장]
    #subitem[이사]
    #subitem[감사]
  ]
]

#article[사업][
  법인은 #at[제1조]의 목적을 달성하기 위하여 다음 각 호의 사업을 한다.
  #numitem[○○에 관한 조사·연구]
  #numitem[○○에 관한 교육·홍보]
  #numitem[그 밖에 법인의 목적 달성에 필요한 사업]
]

#b-article[수익사업][
  법인은 #at[제3조] 각 호의 사업에 드는 경비를 충당하기 위하여 필요한 경우 수익사업을 할 수 있다.
]

#chapter[회원]

#article[회원의 자격][
  #clause[회원은 법인의 목적에 동의하는 사람으로서 가입신청서를 제출한 사람으로 한다.]
  #clause[#at[제1항]에 따른 가입은 이사회의 승인을 받아야 한다.]
]

#article[회원의 권리와 의무][
  #clause[#at-m("회원")에 따른 회원은 총회에 참석하여 의결권을 행사할 수 있다.]
  #clause[회원은 정관과 총회의 의결 사항을 지켜야 한다.]
]

#chapter[임원]

#section-title[임원의 구성]

#article[임원의 종류][
  #clause[법인에 다음 각 호의 임원을 둔다.
    #numitem[이사장 1명]
    #numitem(m: "이사")[이사 5명 이상 15명 이하]
    #numitem[감사 2명]
  ]
  #clause[#at-m("이사")의 이사에는 이사장을 포함한다.]
]

#article[임원의 임기][
  임원의 임기는 2년으로 하며, 연임할 수 있다.
]

// 부칙의 hint는 여러 부칙 중 하나를 인용할 때 씁니다. 결과물에는 표시되지 않습니다.
#addendum(hint: "2026. 1. 1.")[부칙 \<2026. 1. 1.\>]

#article[시행일][
  이 정관은 2026년 1월 1일부터 시행한다.
]

#article[경과조치][
  이 정관 시행 당시 종전의 정관에 따라 선임된 임원은 #at[제6조]에 따른 임원으로 본다.
]

// ===== 신·구조문대비표 (개정안을 만들 때) =====
// 개정안 문서에서는 아래처럼 신·구조문대비표를 씁니다. 표 안의 조항은 manual- 함수로 번호를 직접 정합니다.
//
// #show: body-page.with(compact-margin: true)
// #side-by-side-table(hide-inner-stroke: true, no-inset: true, (
//   compare-row(
//     [#manual-article(5)[회원의 자격][#manual-clause(1)[(생략)]]],
//     [#manual-article(5)[회원의 자격][#manual-clause(1)[(현행과 같음)]]],
//   ),
//   compare-row(
//     [#manual-clause(2)[(신설)]],
//     [#manual-clause(2)[가입 절차는 회칙으로 정한다.]],
//     remark: [가입 절차 위임],
//   ),
// ))
