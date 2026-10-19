// Кодировщик cp866 (DOS-кириллица + псевдографика).
//
// Зачем: cmd.exe не умеет разбирать .cmd с multibyte-символами — после UTF-8
// символа ломается позиция чтения и строки рассыпаются на команды.
// Однобайтовый файл в кодировке консоли читается построчно без сбоев.
//
// Таблица псевдографики - реальная Windows cp866 (совпадает с WHATWG ibm866):
//   0xB0..0xDF псевдографика, 0xA0..0xAF а..п, 0xE0..0xEF р..я
// Внимание: « » — — … в cp866 НЕТ (0xAB это "л", 0x97 это "Щ"), они заменяются.
const HI = "АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ";   // 0x80..0x9F, без разрывов
const LO = "абвгдежзийклмнопрстуфхцчшщъыьэюя";   // 0xA0..0xAF + 0xE0..0xEF

const BOX_PAIRS = [
  "░▒▓│┤╡╢╖╕╣║╗╝╜╛┐",       // 0xB0
  "└┴┬├─┼╞╟╚╔╩╦╠═╬╧",         // 0xC0
  "╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀",         // 0xD0
];

const BOX = {};
[...BOX_PAIRS.join("")].forEach((ch, i) => {
  BOX[ch] = 0xb0 + i;
});
// ВАЖНО: сюда НЕЛЬЗЯ добавлять ▲ (0x1E) и ▼ (0x1F) - в cp866 это
// служебные байты без глифа. Если понадобится - падает проверка ниже.
Object.assign(BOX, { "Ё": 0xf0, "ё": 0xf1, "·": 0xfa, "°": 0xf8 });

// Чего в cp866 нет - заменяем на близкое, молча уходим не должны.
const FALLBACK = {
  "«": '"', "»": '"', "„": '"', "“": '"', "”": '"',
  "—": "-", "–": "-", "…": "...", "№": "N", "ё": "е", "Ё": "Е",
  "‑": "-", "−": "-", "→": "->", "★": "*",
};

function toCp866(str) {
  const bytes = [];
  const missing = new Set();
  for (const ch of str) {
    const cp = ch.codePointAt(0);
    if (cp < 128) { bytes.push(cp); continue; }
    if (BOX[ch] !== undefined) { bytes.push(BOX[ch]); continue; }
    const i = HI.indexOf(ch);
    if (i >= 0) { bytes.push(0x80 + i); continue; }
    const j = LO.indexOf(ch);
    if (j >= 0) { bytes.push(j < 16 ? 0xa0 + j : 0xe0 + (j - 16)); continue; }
    const fb = FALLBACK[ch];
    if (fb) { for (const c of fb) bytes.push(c.codePointAt(0)); continue; }
    missing.add(ch);
    bytes.push(0x3f);
  }
  if (missing.size) {
    throw new Error(
      "нет в cp866 и нет замены: " +
        [...missing].map((c) => `${c} U+${c.codePointAt(0).toString(16)}`).join(", ")
    );
  }
  return Buffer.from(bytes);
}

module.exports = { toCp866 };

// Самопроверка: закодированное должно читаться обратно байт в байт.
if (require.main === module) {
  const probe =
    HI + " " + LO + " Ёё " +
    [...BOX_PAIRS.join("")].join("") +
    ' %USERNAME% "test" +---+ \\ | > ^ &';
  const back = new TextDecoder("ibm866").decode(toCp866(probe));
  if (back !== probe) {
    console.error("!! round-trip не сошёлся:");
    for (let i = 0; i < probe.length; i++) {
      if (probe[i] !== back[i]) {
        console.error(`   позиция ${i}: ждали ${JSON.stringify(probe[i])} (U+${probe.codePointAt(i).toString(16)}), получили ${JSON.stringify(back[i])} (U+${back.codePointAt(i).toString(16)})`);
      }
    }
    process.exit(1);
  }
  console.log("cp866 round-trip OK (" + probe.length + " символов)");
}
