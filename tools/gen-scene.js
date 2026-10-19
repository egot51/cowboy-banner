// Генератор сцен "Дикий Запад" для приветствия в терминале.
// Каждая сцена рисуется трижды: ASCII / Unicode / DOS-набор глифов,
// поэтому раскладка во всех вариантах гарантированно совпадает.
// На выходе: scenes.json (арт + разметка цвета + палитра) - единый источник
// для генераторов профиля PowerShell и .cmd для cmd.exe.
const fs = require("fs");
const path = require("path");

const W = 76;
const H = 24;
const C = Math.floor(W / 2);

const GLYPHS = {
  ascii: {
    TL: "+", TR: "+", BL: "+", BR: "+", H: "-", V: "|", S1: "/", S2: "\\",
    FILL: "=", HEAVY: "#", LIGHT: ":", MOON: "o", FIRE: "^", DOT: ".",
    DUST: "*", WHEEL: "O", JOIN: "+", BASE: "T", DASH: "-", SHADE: "#",
  },
  unicode: {
    TL: "╭", TR: "╮", BL: "╰", BR: "╯", H: "─", V: "│", S1: "╱", S2: "╲",
    FILL: "═", HEAVY: "█", LIGHT: "░", MOON: "░", FIRE: "▲", DOT: "·",
    DUST: "✦", WHEEL: "◉", JOIN: "┬", BASE: "┴", DASH: "┄", SHADE: "▒",
  },
  // Только однобайтовые символы cp866: cmd не умеет читать .cmd с UTF-8.
  // Пламя - "^": байт 0x1E (▲) в cp866 служебный, рискованно.
  // Колесо - буква O: в cp866 нет ◉.
  dos: {
    TL: "┌", TR: "┐", BL: "└", BR: "┘", H: "─", V: "│", S1: "/", S2: "\\",
    FILL: "═", HEAVY: "█", LIGHT: "▒", MOON: "░", FIRE: "^", DOT: "·",
    DUST: "*", WHEEL: "O", JOIN: "┬", BASE: "┴", DASH: "·", SHADE: "▒",
  },
};

const PALETTE = {
  Sky: "38;5;214",
  Night: "38;5;60",
  Star: "38;5;250",
  Moon: "38;5;187",
  Horizon: "38;5;94",
  Dust: "38;5;240",
  Cactus: "38;5;71",
  Canvas: "38;5;223",
  Wood: "38;5;137",
  Wheel: "38;5;238",
  Wire: "38;5;245",
  Pole: "38;5;137",
  Rock: "38;5;244",
  Fire: "38;5;202",
  Log: "38;5;94",
  Sign: "38;5;208",
  Window: "38;5;214",
  // Space
  Space: "38;5;17",
  Ring: "38;5;110",
  Planet: "38;5;209",
  Crater: "38;5;173",
  Rocket: "38;5;196",
  Panel: "38;5;24",
  Earth: "38;5;33",
  // Cyber
  Neon: "38;5;201",
  Rain: "38;5;67",
  City: "38;5;238",
  Lit: "38;5;220",
  Code: "38;5;29",
  CodeBright: "38;5;120",
  // Ocean
  Water: "38;5;19",
  WaterTop: "38;5;44",
  Ray: "38;5;37",
  Hull: "38;5;172",
  Porthole: "38;5;220",
  Weed: "38;5;28",
  Fish: "38;5;222",
  Whale: "38;5;24",
  Bubble: "38;5;159",
  Caption: "1;38;5;231",
  Greet: "1;38;5;84",
  Fortune: "38;5;223",
  Hint: "38;5;242",
};

const SKY_STARS = [[3, 0], [11, 1], [18, 0], [58, 0], [66, 1], [73, 0], [7, 3], [52, 2]];
const NIGHT_STARS = [[2, 0], [9, 2], [16, 0], [23, 3], [30, 1], [37, 0], [44, 2], [51, 0],
                    [58, 3], [65, 1], [72, 0], [6, 5], [69, 5], [13, 6], [61, 7]];

function makeCtx(g, grid, over) {
  const put = (col, row, text) => {
    [...text].forEach((ch, i) => {
      const c = col + i, r = row;
      if (r < 0 || r >= H || c < 0 || c >= W) { over.push(`r=${r} c=${c}`); return; }
      grid[r][c] = ch;
    });
  };
  const hline = (row, from, to, ch = g.H) => {
    if (to >= from) put(from, row, ch.repeat(to - from + 1));
  };
  const mid = (row, text) => put(C - Math.floor(text.length / 2), row, text);
  const ellipse = (rowC, colC, rx, ry, ch) => {
    for (let r = 0; r < H; r++) {
      const t = 1 - ((r - rowC) / ry) ** 2;
      if (t <= 0) continue;
      const hx = rx * Math.sqrt(t);
      // ceil/floor, а не round - иначе края эллипса получаются несимметричными
      hline(r, Math.ceil(colC - hx), Math.floor(colC + hx), ch);
    }
  };
  const ring = (rowC, colC, rx, ry, ch, rFrom, rTo) => {
    for (let r = rFrom; r <= rTo; r++) {
      const t = 1 - ((r - rowC) / ry) ** 2;
      if (t <= 0) continue;
      const hx = rx * Math.sqrt(t);
      put(Math.ceil(colC - hx), r, ch);
      put(Math.floor(colC + hx), r, ch);
    }
  };
  const cactus = (col, row, small) => {
    if (small) {
      put(col, row, "_|_");
      put(col, row + 1, "| |");
      put(col, row + 2, " | ");
    } else {
      put(col + 2, row, "_|_");
      put(col + 2, row + 1, "| |");
      put(col + 1, row + 2, "_| |_");
      put(col, row + 3, "| | | |");
      put(col, row + 4, "|_| |_|");
    }
  };
  const mesas = (leftCol = 5, rightCol = 60) => {
    hline(6, leftCol, leftCol + 8);
    put(leftCol, 7, g.S1 + g.H.repeat(9) + g.S2);
    put(leftCol, 8, g.V + " ".repeat(9) + g.V);
    hline(4, rightCol, rightCol + 10);
    put(rightCol, 5, g.S1 + g.H.repeat(11) + g.S2);
    for (let r = 6; r <= 8; r++) put(rightCol, r, g.V + " ".repeat(11) + g.V);
  };
  const caption = (text) => mid(23, text);
  return { put, hline, mid, ellipse, ring, cactus, mesas, caption };
}

// ── СЦЕНА 1: крытая повозка на закате ────────────────────────────────
function drawWagon(x, g, ox, oy) {
  const L = (dx, dy, ch, n) => x.put(ox + dx, oy + dy, ch.repeat(n));
  L(11, 0, g.H, 18);                                  // верхний тент
  x.put(ox + 10, oy + 1, g.S1); x.put(ox + 29, oy + 1, g.S2);
  L(6, 2, g.H, 4); x.put(ox + 10, oy + 2, g.S1);     // передний козырёк
  x.put(ox + 29, oy + 2, g.S2); L(30, 2, g.H, 4);
  x.put(ox + 5, oy + 3, g.S1); x.put(ox + 34, oy + 3, g.S2);
  L(11, 3, g.V, 1); L(28, 3, g.V, 1);
  x.put(ox + 4, oy + 4, g.V); x.put(ox + 35, oy + 4, g.V);
  L(11, 4, g.V, 1); L(28, 4, g.V, 1);
  x.put(ox + 5, oy + 5, g.S1); L(6, 5, g.H, 5);      // пол кузова
  L(11, 5, g.V, 1); L(12, 5, g.H, 17); L(28, 5, g.V, 1); L(29, 5, g.H, 5);
  x.put(ox + 34, oy + 5, g.S2);
  x.put(ox + 7, oy + 6, g.WHEEL);                    // колёса
  x.put(ox + 30, oy + 6, g.WHEEL);
}

const SCENE_WAGON = {
  id: "wagon",
  caption: "T H E   S U N S E T   T R A I L",
  segments: [
    { row: [0, 8], col: [0, 75], color: "Sky" },
    { row: [0, 8], col: [0, 75], color: "Star", chars: ["✦", "·", "*"] },
    { row: [9, 9], col: [0, 75], color: "Horizon" },
    { row: [12, 16], col: [6, 12], color: "Cactus" },
    { row: [13, 15], col: [62, 68], color: "Cactus" },
    { row: [11, 13], col: [18, 57], color: "Canvas" },
    { row: [14, 16], col: [18, 57], color: "Wood" },
    { row: [17, 17], col: [18, 57], color: "Wheel" },
    { row: [18, 22], col: [0, 75], color: "Dust" },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    SKY_STARS.forEach(([c, r]) => x.put(c, r, r % 2 ? g.DOT : g.DUST));
    x.put(8, 3, g.S2 + g.S1);                          // птицы
    x.put(15, 2, g.S2 + g.S1);
    x.ellipse(4.2, C, 13, 3.4, g.FILL);                // солнце
    x.put(C + 7, 3, g.DUST);
    x.mesas();
    x.hline(9, 0, 75, g.FILL);
    x.cactus(6, 12, false);
    x.cactus(62, 13, true);
    drawWagon(x, g, 18, 11);
    x.put(10, 20, "..  .   ..");                       // пыль из-под колёс
    x.put(12, 21, "  .   .");
    x.caption(SCENE_WAGON.caption);
  },
};

// ── СЦЕНА 2: телеграфная линия ───────────────────────────────────────
function pole(x, g, px, top) {
  x.put(px, top, g.JOIN);                             // изолятор
  x.put(px - 1, top + 1, g.H); x.put(px, top + 1, "┼"); x.put(px + 1, top + 1, g.H);
  for (let r = top + 2; r <= top + 6; r++) x.put(px, r, g.V);
  x.put(px, top + 7, g.BASE);
}

const SCENE_WIRE = {
  id: "wire",
  caption: "T H E   L O N G   W I R E",
  segments: [
    { row: [0, 8], col: [0, 75], color: "Sky" },
    { row: [0, 8], col: [0, 75], color: "Star", chars: ["✦", "·", "*"] },
    { row: [9, 9], col: [0, 75], color: "Horizon" },
    { row: [11, 18], col: [10, 12], color: "Pole" },
    { row: [11, 18], col: [63, 65], color: "Pole" },
    { row: [13, 15], col: [11, 65], color: "Wire" },
    { row: [16, 20], col: [30, 36], color: "Cactus" },
    { row: [17, 19], col: [44, 59], color: "Rock" },
    { row: [19, 22], col: [0, 75], color: "Dust" },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    SKY_STARS.forEach(([c, r]) => x.put(c, r, r % 2 ? g.DOT : g.DUST));
    x.ellipse(5.6, C, 9, 2.4, g.FILL);                 // низкое солнце
    x.mesas();
    x.hline(9, 0, 75, g.FILL);

    pole(x, g, 11, 11);
    pole(x, g, 64, 11);
    // провисающий провод (ниже перекладины, чтобы не спорить со столбом)
    x.put(12, 13, g.S2); x.put(63, 13, g.S1);
    x.put(13, 14, g.S2); x.put(62, 14, g.S1);
    x.put(14, 15, g.S2); x.hline(15, 15, 60, "_"); x.put(61, 15, g.S1);

    x.cactus(30, 16, false);
    // валуны
    x.put(45, 17, " __ "); x.put(44, 18, "/    \\"); x.put(44, 19, "\\____/");
    x.put(56, 17, " __ "); x.put(55, 18, "/  \\"); x.put(55, 19, "\\__/");
    x.put(20, 21, "..   .");
    x.caption(SCENE_WIRE.caption);
  },
};

// ── СЦЕНА 3: ночной костёр ───────────────────────────────────────────
const SCENE_FIRE = {
  id: "fire",
  caption: "C A M P F I R E   A T   D U S K",
  segments: [
    { row: [0, 8], col: [0, 75], color: "Night" },
    { row: [0, 8], col: [0, 75], color: "Star", chars: ["✦", "·", "*"] },
    { row: [2, 6], col: [0, 75], color: "Moon", chars: ["░", "o"] },
    { row: [9, 9], col: [0, 75], color: "Horizon" },
    { row: [6, 8], col: [0, 75], color: "Rock" },
    { row: [13, 17], col: [34, 42], color: "Fire" },
    { row: [18, 19], col: [33, 43], color: "Log" },
    { row: [14, 18], col: [16, 22], color: "Cactus" },
    { row: [20, 22], col: [0, 75], color: "Dust" },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    NIGHT_STARS.forEach(([c, r]) => x.put(c, r, r % 3 ? g.DOT : g.DUST));
    x.mesas(22, 58);
    x.ellipse(3.4, 13, 6, 2.6, g.MOON);               // луна с кратерами
    x.put(11, 3, " "); x.put(15, 4, " "); x.put(12, 2, " ");
    x.hline(9, 0, 75, g.FILL);

    // угли
    [[36, 11], [40, 10], [38, 12], [34, 12]].forEach(([c, r]) => x.put(c, r, g.DOT));
    // пламя
    x.put(38, 13, g.FIRE);
    x.put(37, 14, g.FIRE.repeat(3));
    x.put(36, 15, g.FIRE.repeat(5));
    x.put(35, 16, g.FIRE.repeat(7));
    x.hline(17, 35, 41, g.HEAVY);
    // поленья
    x.put(34, 18, g.S2); x.hline(18, 35, 41, g.H); x.put(42, 18, g.S1);
    x.put(34, 19, g.S1); x.hline(19, 35, 41, g.H); x.put(42, 19, g.S2);

    x.cactus(16, 14, false);
    x.put(30, 20, "..   .");
    x.caption(SCENE_FIRE.caption);
  },
};

// ── СЦЕНА 4: салон с качающимися дверями ────────────────────────────
const SCENE_SALOON = {
  id: "saloon",
  caption: "T H E   L A S T   S A L O O N   I N   T O W N",
  segments: [
    { row: [0, 8], col: [0, 75], color: "Night" },
    { row: [0, 8], col: [0, 75], color: "Star", chars: ["✦", "·", "*"] },
    { row: [2, 6], col: [0, 75], color: "Moon", chars: ["░", "o"] },
    { row: [3, 5], col: [36, 37], color: "Pole" },
    { row: [6, 8], col: [26, 49], color: "Sign" },
    { row: [11, 18], col: [16, 59], color: "Wood" },
    { row: [12, 15], col: [19, 25], color: "Window" },
    { row: [12, 15], col: [50, 56], color: "Window" },
    { row: [15, 17], col: [35, 40], color: "Window" },
    { row: [19, 19], col: [16, 59], color: "Wood" },
    { row: [20, 22], col: [0, 75], color: "Dust" },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    NIGHT_STARS.forEach(([c, r]) => x.put(c, r, r % 3 ? g.DOT : g.DUST));
    x.ellipse(3.2, 60, 5, 2.2, g.MOON);               // луна
    // столб с вывеской
    x.put(37, 3, g.V); x.put(37, 4, g.V); x.put(37, 5, g.V);
    x.put(26, 6, g.TL); x.hline(6, 27, 48, g.H); x.put(49, 6, g.TR);
    x.put(26, 7, g.V); x.put(27, 7, "  S A L O O N  "); x.put(41, 7, g.V);
    x.put(26, 8, g.BL); x.hline(8, 27, 48, g.H); x.put(49, 8, g.BR);
    // фасад
    x.put(16, 11, g.TL); x.hline(11, 17, 58, g.H); x.put(59, 11, g.TR);
    for (let r = 12; r <= 18; r++) { x.put(16, r, g.V); x.put(59, r, g.V); }
    x.hline(12, 19, 25, g.HEAVY);                     // окна
    x.hline(13, 19, 25, g.HEAVY);
    x.hline(14, 19, 25, g.HEAVY);
    x.hline(12, 50, 56, g.HEAVY);
    x.hline(13, 50, 56, g.HEAVY);
    x.hline(14, 50, 56, g.HEAVY);
    // качающиеся двери
    x.put(35, 15, g.S2); x.put(40, 15, g.S1);
    x.put(36, 16, g.S2); x.put(39, 16, g.S1);
    x.put(37, 17, g.S2); x.put(38, 17, g.S1);
    x.put(16, 18, g.BL); x.hline(18, 17, 58, g.H); x.put(59, 18, g.BR);
    x.hline(19, 16, 59, g.FILL);                      // крыльцо
    x.put(20, 20, "..   .   ..");
    x.caption(SCENE_SALOON.caption);
  },
};

// ═══════════════════ ТЕМА: SPACE ═══════════════════════════════════════

// Планета с кольцом: задняя дуга кольца -> планета -> передняя дуга.
const SCENE_PLANET = {
  id: "planet",
  caption: "O R B I T   O F   F A M I L Y",
  segments: [
    { row: [0, 22], col: [0, 75], color: "Space" },
    { row: [0, 22], col: [0, 75], color: "Star", chars: ["✦", "·", "*"] },
    { row: [3, 6], col: [12, 64], color: "Ring" },
    { row: [5, 16], col: [20, 56], color: "Planet" },
    { row: [15, 17], col: [12, 64], color: "Ring" },
    { row: [0, 8], col: [67, 72], color: "Rocket" },
    { row: [18, 22], col: [4, 14], color: "Moon" },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    [[4, 0], [12, 2], [19, 1], [27, 0], [35, 2], [44, 1], [52, 0], [60, 2], [70, 0], [73, 3], [66, 1]]
      .forEach(([c, r]) => x.put(c, r, r % 2 ? g.DOT : g.DUST));

    // задняя (верхняя) дуга кольца - её потом накроет планета
    x.hline(3, 24, 52, g.H);
    x.hline(4, 16, 60, g.H);
    x.hline(5, 12, 64, g.H);
    x.hline(6, 14, 62, g.H);

    x.ellipse(10.5, 38, 18, 5.5, g.LIGHT);
    [[27, 8, 3, 2], [45, 12, 4, 2], [34, 14, 2, 1], [50, 8, 2, 1]]
      .forEach(([c, r, rx, ry]) => x.ellipse(r, c, rx, ry, " "));   // кратеры - дырки

    // передняя (нижняя) дуга кольца - поверх планеты
    x.hline(15, 12, 64, g.H);
    x.hline(16, 16, 60, g.H);
    x.hline(17, 24, 52, g.H);

    // ракета - в чистом небе справа, иначе пиксели планеты попадают внутрь корпуса
    x.put(69, 0, g.S1); x.put(70, 0, g.S2);
    x.put(68, 1, g.S1); x.put(71, 1, g.S2);
    x.hline(2, 67, 72, g.H);
    x.put(67, 3, g.V); x.put(72, 3, g.V);
    x.put(69, 3, g.MOON);
    x.put(67, 4, g.V); x.put(72, 4, g.V);
    x.hline(5, 67, 72, g.H);
    x.put(68, 6, g.S2); x.put(71, 6, g.S1);
    x.put(70, 7, g.FIRE);
    x.put(70, 8, g.FIRE);

    // маленький спутник внизу слева
    x.ellipse(20, 9, 5, 2.4, g.MOON);
    x.caption(SCENE_PLANET.caption);
  },
};

// Спутник над земным шаром
const SCENE_SAT = {
  id: "satellite",
  caption: "D E E P   S P A C E   N E T W O R K",
  segments: [
    { row: [0, 22], col: [0, 75], color: "Space" },
    { row: [0, 13], col: [0, 75], color: "Star", chars: ["✦", "·", "*"] },
    { row: [5, 11], col: [22, 53], color: "Panel" },
    { row: [5, 11], col: [34, 41], color: "Lit" },
    { row: [14, 22], col: [0, 75], color: "Earth" },
    { row: [12, 13], col: [0, 75], color: "Ray" },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    [[2, 0], [9, 2], [15, 0], [22, 1], [30, 3], [47, 1], [55, 0], [63, 2], [70, 0], [74, 3], [39, 1]]
      .forEach(([c, r]) => x.put(c, r, r % 2 ? g.DOT : g.DUST));

    // солнечные панели
    x.put(22, 5, g.TL); x.hline(5, 23, 31, g.H); x.put(32, 5, g.TR);
    for (let r = 6; r <= 9; r++) { x.put(22, r, g.V); x.put(32, r, g.V); }
    x.hline(6, 23, 31, g.H); x.hline(7, 23, 31, g.DASH);
    x.hline(8, 23, 31, g.H); x.hline(9, 23, 31, g.DASH);
    x.put(22, 10, g.BL); x.hline(10, 23, 31, g.H); x.put(32, 10, g.BR);

    x.put(42, 5, g.TL); x.hline(5, 43, 52, g.H); x.put(53, 5, g.TR);
    for (let r = 6; r <= 9; r++) { x.put(42, r, g.V); x.put(53, r, g.V); }
    x.hline(6, 43, 52, g.H); x.hline(7, 43, 52, g.DASH);
    x.hline(8, 43, 52, g.H); x.hline(9, 43, 52, g.DASH);
    x.put(42, 10, g.BL); x.hline(10, 43, 52, g.H); x.put(53, 10, g.BR);

    // корпус
    x.put(34, 5, g.TL); x.hline(5, 35, 40, g.H); x.put(41, 5, g.TR);
    for (let r = 6; r <= 10; r++) { x.put(34, r, g.V); x.put(41, r, g.V); }
    x.put(34, 11, g.BL); x.hline(11, 35, 40, g.H); x.put(41, 11, g.BR);
    x.hline(7, 35, 40, g.MOON);
    x.put(37, 9, g.DOT);

    // антенна
    x.put(37, 12, g.S1); x.put(38, 12, g.S2);
    x.put(36, 13, g.S1); x.put(39, 13, g.S2);
    x.hline(14, 36, 39, g.H);

    // земной шар снизу: видна только верхняя дуга, поэтому по краям
    // рисуем в пределах холста (hx обрезаем, иначе уходит за границы)
    for (let r = 12; r < 23; r++) {
      const t = 1 - ((r - 26) / 13) ** 2;
      if (t <= 0) continue;
      const hx = Math.min(38, 46 * Math.sqrt(t));
      x.hline(r, Math.max(0, Math.ceil(38 - hx)), Math.min(75, Math.floor(38 + hx)), g.LIGHT);
    }
    x.caption(SCENE_SAT.caption);
  },
};

// ═══════════════════ ТЕМА: CYBER ══════════════════════════════════════

// Неоновый город: небо, дождь, здания со светящимися окнами
const SCENE_CITY = {
  id: "city",
  caption: "N E O N   N I G H T",
  segments: [
    { row: [0, 22], col: [0, 75], color: "Space" },
    { row: [0, 22], col: [0, 75], color: "Star", chars: ["✦", "·", "*"] },
    { row: [1, 4], col: [56, 70], color: "Moon" },
    { row: [0, 10], col: [0, 75], color: "Rain", chars: ["╲", "\\", "V"] },
    { row: [6, 19], col: [0, 75], color: "City" },
    { row: [6, 19], col: [0, 75], color: "Lit", chars: ["▒", "o"] },
    { row: [7, 9], col: [30, 44], color: "Neon" },
    { row: [20, 22], col: [0, 75], color: "Rain" },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    [[5, 1], [12, 0], [20, 2], [46, 0], [50, 2], [74, 1]].forEach(([c, r]) => x.put(c, r, g.DUST));
    x.ellipse(2.4, 63, 6, 2.2, g.MOON);

    // дождь рисуем ДО зданий, иначе капли режут неоновую вывеску
    [[7, 3], [18, 5], [27, 2], [37, 6], [49, 4], [58, 7], [68, 3], [72, 8]]
      .forEach(([c, r]) => { x.put(c, r, g.S2); x.put(c + 1, r + 1, g.S2); });

    const towers = [[3, 12, 9], [14, 10, 8], [26, 18, 7], [46, 13, 9], [57, 9, 7], [65, 14, 10]];
    towers.forEach(([c, top, w]) => {
      x.hline(top, c, c + w, g.H);
      for (let r = top + 1; r <= 19; r++) { x.put(c, r, g.V); x.put(c + w, r, g.V); }
      x.hline(19, c, c + w, g.H);
      // окна
      for (let r = top + 2; r < 19; r += 2) {
        for (let k = 2; k < w; k += 3) {
          if ((r + k + w) % 3 === 0) x.put(c + k, r, g.SHADE);
        }
      }
      if (top < 8) { x.put(c + Math.floor(w / 2), top - 1, g.V); x.put(c + Math.floor(w / 2), top - 2, g.DOT); }
    });

    // неоновая вывеска на центральном здании
    x.put(30, 7, g.TL); x.hline(7, 31, 42, g.H); x.put(43, 7, g.TR);
    x.put(30, 8, g.V); x.put(32, 8, "N E O N"); x.put(41, 8, g.V);
    x.put(30, 9, g.BL); x.hline(9, 31, 42, g.H); x.put(43, 9, g.BR);

    x.caption(SCENE_CITY.caption);
  },
};

// Цифровой дождь
const SCENE_MATRIX = {
  id: "matrix",
  caption: "G H O S T   I N   T H E   S H E L L",
  segments: [
    { row: [0, 22], col: [0, 75], color: "Space" },
    { row: [0, 22], col: [0, 75], color: "Code", chars: ["0", "1", "a", "f", "7", "4", "#", "$", "%"] },
    { row: [0, 22], col: [0, 75], color: "CodeBright", chars: ["█", "#", "@"] },
    { row: [10, 12], col: [0, 75], color: "Lit" },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    const hex = "01af74c9e2b7d0356";
    let seed = 20241018;
    const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
    for (let col = 1; col < 76; col += 3) {
      const len = 4 + Math.floor(rnd() * 12);
      const top = Math.floor(rnd() * 8);
      for (let k = 0; k < len; k++) {
        const r = top + k;
        if (r > 21) break;
        const ch = hex[Math.floor(rnd() * hex.length)];
        x.put(col, r, k === 0 ? g.HEAVY : (rnd() > 0.25 ? ch : g.DOT));
      }
    }
    x.put(0, 10, g.TL); x.put(0, 11, g.V); x.put(0, 12, g.BL);
    x.put(74, 10, g.TR); x.put(74, 11, g.V); x.put(74, 12, g.BR);
    x.hline(10, 1, 73, g.DASH);
    x.hline(12, 1, 73, g.H);
    x.put(2, 11, "> ");
    x.put(5, 11, "0x");
    "DEADBEEF".split("").forEach((ch, i) => x.put(7 + i, 11, ch));
    x.put(15, 11, g.HEAVY);
    x.caption(SCENE_MATRIX.caption);
  },
};

// ═══════════════════ ТЕМА: OCEAN ══════════════════════════════════════

const SCENE_SUB = {
  id: "submarine",
  caption: "D E E P   W A T E R",
  segments: [
    { row: [0, 22], col: [0, 75], color: "Water" },
    { row: [0, 2], col: [0, 75], color: "WaterTop" },
    { row: [3, 9], col: [0, 75], color: "Ray", chars: ["╱", "/"] },
    { row: [7, 14], col: [20, 55], color: "Hull" },
    { row: [11, 12], col: [24, 51], color: "Porthole", chars: ["o", "●"] },
    { row: [16, 22], col: [0, 75], color: "Weed" },
    { row: [0, 22], col: [0, 75], color: "Fish", chars: ["╲│╱", "\\|/", "><"] },
    { row: [0, 22], col: [0, 75], color: "Bubble", chars: ["o", "°"] },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    // поверхность воды
    x.hline(0, 0, 75, g.H);
    for (let c = 1; c <= 70; c += 6) { x.put(c, 1, g.TL); x.put(c + 3, 1, g.TR); }
    x.hline(2, 0, 75, g.H);

    // лучи света
    [[9, 3, 6], [24, 3, 8], [44, 3, 5], [58, 3, 7], [69, 3, 4]]
      .forEach(([c, r, len]) => { for (let k = 0; k < len; k++) x.put(c + k, r + k, g.S1); });

    // рубка и перископ
    x.put(37, 4, g.H); x.put(38, 4, g.H); x.put(39, 4, g.H);
    x.put(38, 5, g.V);
    x.put(34, 6, g.TL); x.hline(6, 35, 41, g.H); x.put(42, 6, g.TR);
    x.put(34, 7, g.V); x.put(42, 7, g.V);
    x.put(33, 8, g.TL); x.hline(8, 34, 42, g.H); x.put(43, 8, g.TR);
    x.put(33, 9, g.V); x.put(43, 9, g.V);

    // корпус
    x.put(22, 10, g.S1);
    x.hline(10, 23, 55, g.H);
    x.put(56, 10, g.S2);
    x.put(22, 11, g.V);
    x.hline(11, 23, 55, g.H);
    x.put(56, 11, g.V);
    x.put(22, 12, g.V); x.put(56, 12, g.V);          // борта на уровне иллюминаторов
    for (let c = 27; c <= 51; c += 8) x.put(c, 12, "o");
    x.put(22, 13, g.V);
    x.hline(13, 23, 55, g.H);
    x.put(56, 13, g.V);
    x.put(23, 14, g.BL); x.hline(14, 24, 54, g.H); x.put(55, 14, g.BR);
    x.hline(15, 30, 34, g.H); x.hline(15, 44, 48, g.H);         // шасси

    // винт
    x.put(57, 11, g.H);
    x.put(58, 10, g.S1); x.put(58, 12, g.S2);
    x.put(59, 10, g.S2); x.put(59, 12, g.S1);
    x.put(60, 11, g.V);

    // рыбы и пузыри
    [[8, 6], [12, 9], [66, 7], [70, 11], [6, 13]].forEach(([c, r]) => x.put(c, r, "o"));
    [[16, 5], [68, 5], [64, 9]].forEach(([c, r]) => { x.put(c, r, g.S2); x.put(c + 1, r, g.V); x.put(c + 2, r, g.S1); });
    x.put(19, 8, "o"); x.put(65, 13, "o");

    // водоросли
    [[6, 19, 4], [14, 18, 5], [58, 19, 4], [67, 18, 5]]
      .forEach(([c, top, h]) => { for (let k = 0; k < h; k++) x.put(c, top + k, (k % 2) ? g.S1 : g.V); });
    x.caption(SCENE_SUB.caption);
  },
};

const SCENE_WHALE = {
  id: "whale",
  caption: "S O M E W H E R E   A B O V E   T H E   S E A",
  segments: [
    { row: [0, 22], col: [0, 75], color: "Water" },
    { row: [0, 2], col: [0, 75], color: "WaterTop" },
    { row: [3, 8], col: [0, 75], color: "Ray", chars: ["╱", "/"] },
    { row: [11, 19], col: [10, 64], color: "Whale" },
    { row: [13, 14], col: [14, 22], color: "Bubble", chars: ["o", "°"] },
    { row: [20, 22], col: [0, 75], color: "Weed" },
    { row: [0, 22], col: [0, 75], color: "Fish", chars: ["╲│╱", "\\|/"] },
    { row: [23, 23], col: [0, 75], color: "Caption" },
  ],
  draw(g, x) {
    x.hline(0, 0, 75, g.H);
    for (let c = 2; c <= 68; c += 7) { x.put(c, 1, g.TL); x.put(c + 4, 1, g.TR); }
    x.hline(2, 0, 75, g.H);

    // лодка на ватерлинии
    x.put(10, 0, g.V);
    x.put(9, 1, g.S1); x.put(11, 1, g.S2);
    x.hline(2, 7, 13, g.H);
    x.put(7, 3, g.S2); x.put(13, 3, g.S1);

    // лучи света
    [[18, 3, 6], [34, 3, 5], [50, 3, 7], [64, 3, 4]]
      .forEach(([c, r, len]) => { for (let k = 0; k < len; k++) x.put(c + k, r + k, g.S1); });

    // пузыри
    [[28, 6], [30, 4], [27, 8], [33, 5], [46, 7]].forEach(([c, r]) => x.put(c, r, "o"));

    // силуэт кита: тело овалом, хвост - двумя лопастями
    x.ellipse(15, 32, 22, 4.5, g.HEAVY);
    x.put(16, 15, " ");                                        // глаз
    x.hline(14, 52, 56, g.HEAVY);                              // хвостовик
    x.hline(15, 52, 56, g.HEAVY);
    x.hline(16, 52, 56, g.HEAVY);
    x.hline(12, 54, 65, g.HEAVY);                              // верхняя лопасть
    x.hline(13, 52, 67, g.HEAVY);
    x.hline(17, 52, 67, g.HEAVY);                              // нижняя лопасть
    x.hline(18, 54, 65, g.HEAVY);
    // плавник
    x.put(26, 19, g.S1); x.hline(20, 27, 32, g.HEAVY); x.put(33, 19, g.S2);

    // рыбы
    [[8, 7], [66, 6], [71, 11], [6, 12]].forEach(([c, r]) => {
      x.put(c, r, g.S2); x.put(c + 1, r, g.V); x.put(c + 2, r, g.S1);
    });
    // водоросли
    [[5, 20, 3], [12, 19, 4], [62, 20, 3], [70, 19, 4]]
      .forEach(([c, top, h]) => { for (let k = 0; k < h; k++) x.put(c, top + k, (k % 2) ? g.S1 : g.V); });
    x.caption(SCENE_WHALE.caption);
  },
};

// Тексты под темы: приветствие (латиницей - одинаково для всех кодировок)
// и поговорки на русском + английском (английский нужен для ASCII-ветки cmd).
const THEMES = [
  {
    id: "wildwest",
    title: "WILD WEST",
    ru: "Дикий Запад",
    greet: ["H O W D Y", "Y O H O,  C O W B O Y", "E V E N I N G,  S T R A N G E R", "K I N G  O F  T H E  H I L L"],
    sayRu: [
      "Случай ведёт только на запад.",
      "Сначала скажи «howdy», потом запускай терминал.",
      "Под седлом бага не ищи — он сверху, в стеке.",
      "Терпение, лошади и длинный pipeline — основа любого деплоя.",
      "Раннее утро идеально для rm -rf. И для кофе.",
      "Кто не рискует, тот не едет верхом.",
    ],
    sayEn: [
      "Luck rides only west.",
      "Say howdy before you touch the shell.",
      "The bug is never under the saddle, it is in the stack.",
      "Patience, horses, and one long pipeline.",
      "Early morning is perfect for rm -rf. And for coffee.",
      "No risk, no ride.",
    ],
    scenes: [SCENE_WAGON, SCENE_WIRE, SCENE_FIRE, SCENE_SALOON],
  },
  {
    id: "space",
    title: "SPACE",
    ru: "Космос",
    greet: ["H E Y,  A S T R O N A U T", "T O  B E  O R  N O T  T O  B E", "L A U N C H  T - M I N U T S", "M I S S I O N  C O N T R O L"],
    sayRu: [
      "Критическая масса не прощает поспешных коммитов.",
      "В вакууме никто не слышит твой деплой — он всё равно упадёт.",
      "Спутник связи полезнее спутника-обвинителя.",
      "Чем выше орбита, тем ближе к звезде релиз.",
      "Скажи «поехали», отодвинься от пульта и нажми Enter.",
      "Гравитация терпелива: она дождётся.",
    ],
    sayEn: [
      "Critical mass does not forgive premature commits.",
      "In vacuum nobody hears your deploy - it still fails.",
      "A comms satellite beats an accusation satellite.",
      "The higher the orbit, the closer to star release.",
      "Say to be, step back from the panel and press Enter.",
      "Gravity is patient, it will wait.",
    ],
    scenes: [SCENE_PLANET, SCENE_SAT],
  },
  {
    id: "cyber",
    title: "CYBER",
    ru: "Киберпанк",
    greet: ["W E L C O M E ,  N E T R U N N E R", "G O O D  E V E N I N G ,  H A C K E R", "S Y S T E M  R E A D Y", "N E O N  L I G H T S  O N"],
    sayRu: [
      "Матрица была красива, пока ты не открыл продакшн.",
      "Никогда не коммить в пятницу. Никогда.",
      "Стек-трейс тебя палит — он честнее полиции.",
      "Тёмный экран — не баг, а фича: он говорит правду.",
      "Кто ищет логи, тот теряет время. Кто их читает — находит истину.",
      "Не бойся отладчика. Бойся продакшна.",
    ],
    sayEn: [
      "The Matrix was pretty until you hit production.",
      "Never commit on Friday. Never.",
      "Your stack trace betrays you, it is more honest than the police.",
      "A black screen is not a bug, it is a feature: it tells the truth.",
      "Those who search logs lose time. Those who read them find truth.",
      "Do not fear the debugger. Fear production.",
    ],
    scenes: [SCENE_CITY, SCENE_MATRIX],
  },
  {
    id: "ocean",
    title: "OCEAN",
    ru: "Океан",
    greet: ["A H O Y,  M A T E S", "P O R T  A H O Y", "M O O R I N G  S T A R", "C L E A R  W A T E R S"],
    sayRu: [
      "Подводные лодки не терпят подводных камней в коде.",
      "Течение уносит баги к дедлайну быстрее, чем ты думаешь.",
      "На дне только логи и иллюминаторы.",
      "Глубже значит темнее: в логах всегда так.",
      "Проверь иллюминаторы, прежде чем уходить в рейс.",
      "Шторм снаружи, дедлайн внутри — одинаково страшно.",
    ],
    sayEn: [
      "Submarines do not like underwater rocks in the code.",
      "The current carries bugs to the deadline faster than you think.",
      "At the bottom there are only logs and portholes.",
      "Deeper means darker: in logs it is always so.",
      "Check the portholes before you sail.",
      "A storm outside, a deadline inside, equally scary.",
    ],
    scenes: [SCENE_SUB, SCENE_WHALE],
  },
];

const SCENES = THEMES.flatMap((t) => t.scenes);

// ── Отрисовка и проверки ──────────────────────────────────────────────
const out = {};
const report = [];

for (const setName of Object.keys(GLYPHS)) {
  const g = GLYPHS[setName];
  for (const scene of SCENES) {
    const grid = Array.from({ length: H }, () => Array(W).fill(" "));
    const over = [];
    scene.draw(g, makeCtx(g, grid, over));
    const lines = grid.map((row) => row.join("").replace(/\s+$/, ""));
    const art = lines.join("\n");
    const max = Math.max(...lines.map((l) => [...l].length));

    if (over.length) throw new Error(`${scene.id}/${setName}: вылет за холст ${over.length}: ${over.slice(0, 3)}`);
    if (max > W) throw new Error(`${scene.id}/${setName}: ширина ${max} > ${W}`);
    if (lines.length !== H) throw new Error(`${scene.id}/${setName}: высота ${lines.length} != ${H}`);

    out[scene.id] = out[scene.id] || {};
    out[scene.id][setName] = { art, segments: scene.segments };
    report.push(`${scene.id}/${setName}: ok (${max} cols)`);

    fs.writeFileSync(path.join(__dirname, `scene-${scene.id}-${setName}.txt`), art + "\n", "utf8");
  }
}

// сверка раскладки между наборами глифов
for (const scene of SCENES) {
  const base = out[scene.id].ascii.art.split("\n");
  for (const setName of ["unicode", "dos"]) {
    const other = out[scene.id][setName].art.split("\n");
    const bad = base.findIndex((l, i) => [...l].length !== [...other[i]].length);
    if (bad !== -1) throw new Error(`${scene.id}: расхождение раскладки ascii/${setName} в строке ${bad}`);
  }
}

fs.writeFileSync(
  path.join(__dirname, "scenes.json"),
  JSON.stringify({
    width: W,
    height: H,
    palette: PALETTE,
    themes: THEMES.map((t) => ({
      id: t.id,
      title: t.title,
      ru: t.ru,
      greet: t.greet,
      sayRu: t.sayRu,
      sayEn: t.sayEn,
      scenes: t.scenes.map((s) => s.id),
    })),
    scenes: out,
  }, null, 0),
  "utf8"
);

console.log(report.join("\n"));
console.log(`\nсцен: ${SCENES.length}, наборов глифов: ${Object.keys(GLYPHS).length}`);
console.log("записано: scenes.json + " + SCENES.length * Object.keys(GLYPHS).length + " .txt");
console.log("\nсписок сцен: " + SCENES.map((s) => s.id).join(", "));
