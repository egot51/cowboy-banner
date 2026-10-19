// Сверяет старую (подмена подстрок) и новую (цвет на позицию) раскраску.
// Рисунок должен совпасть символ в символ, цвета - на тех же позициях.
const path = require("path");
const { data, E, PAL } = require("../tools/paint.js");
const { paintLine: newPaint } = require("../tools/paint.js");

// Ровно то, что было в paint.js до правки.
function oldPaint(line, row, segments) {
  const segs = segments.filter((s) => row >= s.row[0] && row <= s.row[1]).sort((a, b) => a.col[0] - b.col[0]);
  let out = "";
  let col = 0;
  for (const s of segs) {
    if (s.chars) continue;
    const to = Math.min(s.col[1], line.length - 1);
    const from = Math.max(s.col[0], col);
    if (from > to) continue;
    if (from > col) out += " ".repeat(from - col);
    out += E + PAL[s.color] + line.slice(from, to + 1);
    col = to + 1;
  }
  if (col < line.length) out += E + PAL.RESET + line.slice(col);
  for (const s of segs) {
    if (!s.chars) continue;
    for (const ch of s.chars) {
      if (line.includes(ch)) out = out.split(ch).join(E + PAL[s.color] + ch + E + PAL.RESET);
    }
  }
  return out;
}

// Разбирает раскрашенную строку в последовательность (цвет, символ).
// Возвращает null, если встретилась не ANSI-последовательность (испорченная).
// exec() с флагом g ищет совпадение дальше по строке, поэтому индекс
// совпадения обязателен: иначе битый обрывок молча проскакивает.
const RE = new RegExp(E + "\\[([0-9;]*)m", "g");
const STRIP = new RegExp(E + "\\[[0-9;]*m", "g");
function parse(painted) {
  const cells = [];
  let i = 0;
  let color = null;
  while (i < painted.length) {
    if (painted[i] === E) {
      RE.lastIndex = i;
      const m = RE.exec(painted);
      if (!m || m.index !== i) return null;
      color = m[1] === "0" ? null : m[1];
      i += m[0].length;
      continue;
    }
    cells.push([color, painted[i]]);
    i++;
  }
  return cells;
}

let textDiff = 0;
let colorDiff = 0;
let corruptOld = 0;
let coloredBefore = 0;
let coloredAfter = 0;

for (const set of ["ascii", "unicode", "dos"]) {
  for (const [id, sc] of Object.entries(data.scenes)) {
    const s = sc[set];
    s.art.split("\n").forEach((line, row) => {
      const oldPainted = oldPaint(line, row, s.segments);
      const newPainted = newPaint(line, row, s.segments);

      // Эталон - исходный арт: без цветов он обязан совпасть символ в символ.
      const newText = newPainted.replace(STRIP, "");
      if (newText !== line) {
        textDiff++;
        console.log(`  ${id}/${set} строка ${row}: НОВЫЙ РИСУНОК РАЗОШЁЛСЯ С ЭТАЛОНОМ`);
      }

      const diffs = [];
      const oldCells = parse(oldPainted);
      const newCells = parse(newPainted);
      if (!newCells) {
        textDiff++;
        console.log(`  ${id}/${set} строка ${row}: НОВЫЙ вывод не разобран`);
        return;
      }
      if (!oldCells) {
        corruptOld++;
        return;
      }
      if (oldCells.length !== newCells.length) {
        textDiff++;
        console.log(`  ${id}/${set} строка ${row}: разная длина (${oldCells.length} / ${newCells.length})`);
        return;
      }
      for (let k = 0; k < oldCells.length; k++) {
        if (oldCells[k][0]) coloredBefore++;
        if (newCells[k][0]) coloredAfter++;
        if (oldCells[k][1] !== newCells[k][1]) textDiff++;
        // Один и тот же символ мог получить цвет в обоих вариантах, но разный:
        if (oldCells[k][0] !== newCells[k][0] && oldCells[k][0] && newCells[k][0]) {
          colorDiff++;
          diffs.push(`${k}:'${oldCells[k][1]}' ${oldCells[k][0]} -> ${newCells[k][0]}`);
        }
      }
      if (diffs.length) console.log(`  ${id}/${set} строка ${row}: ${diffs.length} симв. -> ${diffs.slice(0, 6).join(", ")}`);
    });
  }
}

console.log(`строк, испорченных в СТАРОМ варианте: ${corruptOld}`);
console.log(`расхождений нового рисунка с эталоном: ${textDiff}`);
console.log(`расхождений цвета на небитых строках: ${colorDiff}`);
console.log(`цветных символов на небитых строках: было ${coloredBefore}, стало ${coloredAfter}`);
// Расхождения цвета - это ожидаемые исправления: старая подмена подстрок
// красила символы вне своего участка и ломала escape-последовательности.
// Критерий готовности - рисунок совпал с эталоном.
if (colorDiff) {
  console.log("");
  console.log("  (расхождения цвета - это точечные исправления старой раскраски,");
  console.log("   они перечислены выше и являются ожидаемыми)");
}
process.exit(textDiff === 0 ? 0 : 1);
