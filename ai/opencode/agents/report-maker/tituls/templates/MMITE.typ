// ---------------------------------------------------------------
// Титульный лист (ОмГТУ), отчёт к лабораторным работам
//
// Шаблон вызывается через titul() из main.typ.
// ---------------------------------------------------------------

#let titul-pitch = 24pt   // шаг между базовыми линиями строк
#let titul-lead = 14.7pt  // просвет между строками

// n пустых строк между блоками
#let titul-blank(n) = v(titul-lead + n * titul-pitch)

#let titul(
  org: [Федеральное государственное автономное образовательное \ учреждение высшего образования],
  university: [«ОМСКИЙ ГОСУДАРСТВЕННЫЙ ТЕХНИЧЕСКИЙ УНИВЕРСИТЕТ»],
  department: [Кафедра математических методов и \ информационных технологий в экономике],

  doc-type: [Отчет к лабораторным работам],
  discipline: ["Системный анализ"],

  group: [ПИН-241],
  student: [А. В. Масальский],
  teacher: [О.Г. Шевелева],
  year: [2026],

  city: [Омск],
) = page(
  paper: "a4",
  margin: (left: 30mm, right: 10mm, top: 20mm, bottom: 20mm),
  numbering: none, // номер страницы на титульнике не выводится
)[
  #set text(font: ("Times New Roman", "Liberation Serif"), size: 14pt, lang: "ru")
  #set par(
    justify: false,
    first-line-indent: 0pt,
    leading: titul-lead,
    spacing: titul-lead,
  )

  // Шапка: организация
  #align(center)[
    *#org*
  ]

  #titul-blank(1)

  // Университет и кафедра
  #align(center)[
    *#university* \
    *#department*
  ]

  #titul-blank(5)

  // Вид работы
  #align(center)[
    *#doc-type* \
    по дисциплине \
    *#discipline*
  ]

  #titul-blank(6)

  // Правый блок: исполнитель и проверяющий
  #align(right)[
    #block(width: 195pt)[
      #align(left)[
        Выполнил ст. гр. #group \
        \_\_\_\_\_\_\_\_\_\_#student \
        "\_\_\_\_"\_\_\_\_\_\_\_\_\_\_\_#year г. \
        Принял \
        \_\_\_\_\_\_\_\_\_#teacher \
        "\_\_\_\_"\_\_\_\_\_\_\_\_\_\_\_#year г.
      ]
    ]
  ]

  // Город и год прижаты к низу страницы
  #v(1fr)
  #align(center)[*#city #year*]
]
