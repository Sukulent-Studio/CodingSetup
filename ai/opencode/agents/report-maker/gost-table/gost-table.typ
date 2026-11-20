// ---------------------------------------------------------------
// Таблицы с надписью «Продолжение таблицы N» на следующих страницах
// ---------------------------------------------------------------

// Приводит позиционные аргументы к списку строк.
// Строка — это массив ячеек (блок). Допускается и массив блоков.
#let _rows(items) = {
  let out = ()
  for it in items {
    if type(it) == array {
      if it.len() > 0 and type(it.first()) == array {
        out += _rows(it) // массив блоков -> раскрываем
      } else {
        out.push(it) // один блок = одна строка
      }
    }
  }
  out
}

// Глобальная настройка «подпись по левому краю страницы» (включается в table-continuation)
#let _caption-at-edge = state("ct-caption-at-edge", false)

// Таблица: figure с невидимыми маркерами начала и конца.
// Строки передаются блоками:
//   long-table(columns: .., header: .., ([a], [b], [c]), ([d], [e], [f]))
// либо одним массивом блоков:  long-table(.., rows)
// Старый формат (плоский список ячеек) тоже работает.
//   header: ()        — (или не указывать) таблица без заголовка.
//   number-rows: true — добавить в начало каждой строки порядковый номер.
//   hyphenate: true   — включить переносы слов внутри таблицы.
//   caption-at-edge   — подпись по левому краю страницы (а не таблицы);
//                       auto — берётся из table-continuation, true/false — для одной таблицы.
// Возвращает figure, поэтому после вызова можно ставить метку <label>.
#let long-table(
  caption: none,
  columns: auto,
  header: (),
  number-rows: false,
  hyphenate: true,
  caption-at-edge: auto,
  ..args, // строки и именованные параметры table (align, inset и т.д.)
) = {
  let items = args.pos()
  // если среди аргументов есть не массивы — это плоский список ячеек
  let flat = items.any(x => type(x) != array)
  let cells = if flat {
    items
  } else {
    _rows(items)
      .enumerate()
      .map(((i, r)) => if number-rows { (str(i + 1), ..r) } else { r })
      .flatten()
  }

  figure(
    kind: table,
    caption: caption, // supplement, позиция и разделитель подписи — из шаблона
    {
      // переносы слов: при justify: false Typst сам их не включает
      set text(hyphenate: hyphenate)
      // маркер начала: запоминаем номер таблицы
      context {
        let n = counter(figure.where(kind: table)).get().first()
        [#metadata(n) <ct-start>]
      }
      // шапка повторяется на каждой странице; без header (или none / ()) таблица без шапки
      let head = if header == none or header.len() == 0 {
        ()
      } else {
        (table.header(..header),)
      }
      let tbl = table(
        columns: columns,
        ..head,
        ..cells,
        ..args.named(),
      )
      // Подпись по левому краю страницы: figure растягивается на всю ширину
      // текста (таблица остаётся по центру), а подпись выравнивается влево.
      // Обёртка только у тела figure, поэтому метка <label> и ссылки работают.
      context {
        let edge = if caption-at-edge == auto {
          _caption-at-edge.get()
        } else {
          caption-at-edge
        }
        if edge { block(width: 100%, align(center, tbl)) } else { tbl }
      }
      // маркер конца
      [#metadata(none) <ct-end>]
    },
  )
}

// Надпись «Продолжение таблицы N» для текущей страницы (или ничего)
#let continuation-label(prefix: [Продолжение таблицы]) = context {
  let p = here().page()
  let starts = query(<ct-start>)
  let ends = query(<ct-end>)
  for (s, e) in starts.zip(ends) {
    if s.location().page() < p and p <= e.location().page() {
      // локальные настройки, чтобы надпись не наследовала абзацные стили шаблона
      set par(first-line-indent: 0pt, justify: false)
      align(right, [#prefix #s.value])
    }
  }
}

// Подключение (ПОСЛЕ #show: gost.with(...)):  #show: table-continuation
//
// Модуль НЕ меняет оформление подписей, отступов, переносов и т.д. —
// всё это остаётся за шаблоном. Он добавляет только колонтитул
// с надписью «Продолжение таблицы N».
//   prefix      — текст надписи.
//   base-header — ваш обычный колонтитул (если он есть), выводится выше надписи.
//   caption-at-edge — true: подписи таблиц стоят по левому краю страницы
//                     (по умолчанию false: оформление как у шаблона).
//                     Включает только таблицы, созданные через long-table.
#let table-continuation(
  prefix: [Продолжение таблицы],
  base-header: none,
  caption-at-edge: false,
  doc,
) = {
  set page(header: {
    base-header
    continuation-label(prefix: prefix)
  })

  _caption-at-edge.update(caption-at-edge)

  if caption-at-edge {
    // то же правило, что и в шаблоне; нужно, если шаблон его не задаёт
    show figure.caption.where(kind: table): set align(left)
    doc
  } else {
    doc
  }
}
