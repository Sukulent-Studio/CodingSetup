// ---------------------------------------------------------------
// Титульный лист (ОмГТУ), повторяет титульник из titul.pdf
//
// Использование в основном документе:
//   #import "titul.typ": titul
//   #titul(student: [Иванов И. И.], city-year: [Омск 2026])
//
// Все тексты вынесены в параметры, менять нужно только их.
// ---------------------------------------------------------------

// Подгонка вертикальных интервалов под шаг строк в оригинале
// (шрифт 14pt, интервал 1.5 => расстояние между строками ~24pt).
#let titul-pitch = 24pt   // шаг между базовыми линиями строк
#let titul-lead = 14.7pt  // просвет между строками

// n пустых строк между блоками
#let titul-blank(n) = v(titul-lead + n * titul-pitch)

#let titul(
  org: [Федеральное государственное автономное образовательное учреждение \ высшего образования],
  university: [«Омский государственный технический университет»],
  department: [Кафедра «Автоматизированные системы обработки информации и управления»],

  doc-type: [ОТЧЁТ],
  discipline: [по дисциплине «Объектно-ориентированное программирование»],
  work: [Лабораторная работа №3],
  student-line: [студента Пчёлкина Романа Валерьевича группы ПИН-241],

  doc-name: [Пояснительная записка],
  cipher: [Шифр работы От-2068998-43-ПИН-23-24 ПЗ],
  direction: [Направление 09.03.04 Программная инженерия],

  teacher-role: [Доцент, к.т.н.],
  teacher: [Степанов П.П.],
  student-role: [Студент],
  student: [Пчёлкин Р. В.],

  city-year: [Омск 2025],
) = page(
  paper: "a4",
  margin: (left: 30mm, right: 10mm, top: 20mm, bottom: 20mm),
  numbering: none, // номер страницы на титульнике не выводится
)[
  #set text(font: "Liberation Serif", size: 14pt, lang: "ru")
  #set par(
    justify: false,
    first-line-indent: 0pt,
    leading: titul-lead,
    spacing: titul-lead,
  )

  // Шапка
  #align(center)[
    #org \
    #university \
    #department
  ]

  #titul-blank(4)

  // Вид работы
  #align(center)[
    *#doc-type* \
    #discipline \
    // #work \
    #student-line
  ]

  #titul-blank(1)

  // Название документа
  #align(center)[
    *#doc-name* \
    #cipher \
    #direction
  ]

  #titul-blank(3.3)

  // Подписи: слева должность, справа ФИО
  #grid(
    columns: (319pt, 1fr),
    row-gutter: titul-lead + titul-pitch,
    [#teacher-role], [#teacher],
    [#student-role], [#student],
  )

  // Город и год прижаты к низу страницы
  #v(1fr)
  #align(center)[#city-year]
]

// ---------------------------------------------------------------
// Пример: титульник + следующая страница с номером 2
// (при импорте через #import этот блок в документ не попадает)
// ---------------------------------------------------------------
#titul()

#set page(
  paper: "a4",
  margin: (left: 30mm, right: 10mm, top: 20mm, bottom: 20mm),
  numbering: "1",
)
#set text(font: "Liberation Serif", size: 14pt, lang: "ru")
