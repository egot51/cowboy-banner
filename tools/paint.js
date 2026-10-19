// Общий модуль раскраски ASCII-арта в ANSI-последовательности.
// Используется генераторами профиля PowerShell и AUR-пакета для Linux.
const fs = require("fs");
const path = require("path");

const data = JSON.parse(fs.readFileSync(path.join(__dirname, "scenes.json"), "utf8"));

const E = "\u001B";
const PAL = Object.fromEntries(Object.entries(data.palette).map(([k, v]) => [k, `[${v}m`]));
PAL.RESET = "[0m";

// Красит одну строку по сегментам.
// Сегменты перекрываются (провод поверх столбов) - обрезаем, а не выбрасываем,
// иначе кусок картинки теряет и цвет, и содержимое.
//
// Цвет считается для каждой позиции, а не подменой подстрок. Подмена
// (out.split(ch).join(...)) портила escape-последовательности: в сцене matrix
// в chars входят цифры и буквы ("0", "1", "a", "f", "7", "4", "#", "$", "%"),
// которые встречаются внутри уже записанного кода цвета - на выходе получалось
// 12 обрывков вида ESC[38;5;1ESC[... в одной картинке.
function paintLine(line, row, segments) {
  const segs = segments
    .filter((s) => row >= s.row[0] && row <= s.row[1])
    .sort((a, b) => a.col[0] - b.col[0]);
  if (segs.length === 0) return line;

  const colors = new Array(line.length).fill(null);
  const paint = (s, overwrite) => {
    const from = Math.max(0, s.col[0]);
    const to = Math.min(s.col[1], line.length - 1);
    if (to < from) return;
    const put = (c) => {
      if (c < from || c > to) return;
      if (overwrite || colors[c] === null) colors[c] = s.color;
    };
    if (!s.chars) {
      for (let c = from; c <= to; c++) put(c);
      return;
    }
    // Одиночные символы: подсветить каждое вхождение.
    const single = s.chars.filter((ch) => ch.length === 1);
    for (let c = from; c <= to; c++) {
      for (const ch of single) {
        if (line[c] === ch) {
          put(c);
          break;
        }
      }
    }
    // Многосимвольные узоры ("╲│╱", "\\|/") - подсветить все вхождения целиком.
    for (const ch of s.chars) {
      if (ch.length < 2) continue;
      let i = line.indexOf(ch, from);
      while (i !== -1 && i <= to) {
        for (let k = i; k < i + ch.length; k++) put(k);
        i = line.indexOf(ch, i + 1);
      }
    }
  };
  // Обычные сегменты не затирают друг друга, символьные накладываются поверх.
  for (const s of segs) if (!s.chars) paint(s, false);
  for (const s of segs) if (s.chars) paint(s, true);

  let out = "";
  let col = 0;
  let painted = false;
  while (col < line.length) {
    const c = colors[col];
    let end = col;
    while (end < line.length && colors[end] === c) end++;
    const chunk = line.slice(col, end);
    if (c) {
      out += E + PAL[c] + chunk;
      painted = true;
    } else {
      // Сброс перед текстом без цвета, иначе цвет предыдущего прогона
      // протечёт на пробелы и рисунок.
      out += (painted ? E + PAL.RESET : "") + chunk;
    }
    col = end;
  }
  return out;
}

// Обходит все строки арта и красит их.
function paintArt(art, segments) {
  return art.split("\n").map((l, i) => paintLine(l, i, segments)).join("\n");
}

module.exports = { data, E, PAL, paintLine, paintArt };
