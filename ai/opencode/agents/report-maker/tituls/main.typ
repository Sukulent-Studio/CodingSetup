#import "templates/ASOIU.typ": titul as asoiu-titul
#import "templates/MMITE.typ": titul as mmite-titul

// Единая точка входа для титульных листов.
//
// Общие поля шаблонов:
//   org, university, department, doc-type, discipline,
//   group, student, teacher, city, year.
//
// Дополнительные поля передаются только нужному шаблону. Например:
//   #titul("MMITE", (group: [ПИН-241], student: [И. И. Иванов]))
//   #titul("ASOIU", (work: [Лабораторная работа №3]))
#let titul(template, data) = {
  if template == "ASOIU" {
    asoiu-titul(..data)
  } else if template == "MMITE" {
    mmite-titul(..data)
  } else {
    panic("Неизвестный шаблон титульника: " + repr(template))
  }
}