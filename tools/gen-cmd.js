// Сборка cowboy.cmd - баннера для cmd.exe (темы + меню выбора).
//
// Сцен много, при каждом запуске выбирается случайная внутри темы,
// и не повторяет предыдущую - выбор хранится в %TEMP% отдельно на тему.
//
// Почему файл однобайтовый (cp866): cmd.exe не умеет разбирать .cmd с
// multibyte-символами - после UTF-8 символа ломается позиция чтения и строки
// рассыпаются на команды. Для консолей с другой кодировкой есть ASCII-ветка.
const fs = require("fs");
const path = require("path");
const { toCp866 } = require("./cp866");

// Раскраска - в общем модуле paint.js (его же используют генераторы профиля
// PowerShell и AUR-пакета для Linux).
const { data, E, PAL, paintLine } = require("./paint.js");
const themes = data.themes;

// Приветствия и поговорки берём из scenes.json - они живут вместе со сценами.
const saySets = (prefix, key) =>
  themes.map((t) => t[key].map((s, i) => `set "${prefix}${t.id}_${i + 1}=${s}"`).join("\r\n")).join("\r\n");

// Диспетчер текстов: выбирает приветствие и поговорку внутри темы.
// goto в конце блока обязателен: иначе выполнение провалится в следующую тему
// и все темы покажут текст последней.
const sayBlocks = themes
  .map((t) => {
    const L = [`:say_${t.id}`];
    t.greet.forEach((g, i) => L.push(`set "G${i + 1}=${g}"`));
    t.greet.forEach((_, i) => L.push(`if "%GI%"=="${i}" set "HI=%G${i + 1}%"`));
    L.push(`for /f "tokens=1,* delims==" %%f in ('set FR_${t.id}_%SI%') do set "FR=%%g"`);
    L.push(`for /f "tokens=1,* delims==" %%f in ('set EN_${t.id}_%SI%') do set "FE=%%g"`);
    L.push("goto :say_done");
    return L.join("\r\n");
  })
  .join("\r\n");

const sayDispatch = themes
  .map((t, i) => (i === themes.length - 1 ? `goto :say_${t.id}` : `if /I "%TH%"=="${t.id}" goto :say_${t.id}`))
  .join("\r\n");

// Строки подсказок вставляются в файл всегда, но печатаются только
// если задана переменная COWBOY_HINT (проверка внутри самого .cmd).
const hint = true;

// echo в batch умеет спецсимволы: экранируем всё, что cmd иначе проглотит.
const esc = (s) => s.replace(/[()&|<>^]/g, "^$&");
const echo = (text) => (text.length ? "echo " + esc(text) : "echo(");
const defs = (prefix, list) => list.map((f, i) => `set "${prefix}${i + 1}=${f}"`).join("\r\n");

// ── блок сцены ──────────────────────────────────────────────────────────
function sceneBlock(id, setName) {
  const s = data.scenes[id][setName];
  const colored = setName === "dos";
  const out = [echo("")];
  s.art.split("\n").forEach((l, i) => out.push(echo(colored ? paintLine(l, i, s.segments) : l)));
  out.push(echo(""));
  if (colored) {
    // ВАЖНО: только ${E}, не $E. Литерал "%E[0m" в строке .cmd сбивает разбор
    // переменных - cmd начинает искать пару %...% с этого места и дальше не идёт.
    out.push(echo(`${E}${PAL.Greet}  %HI%,${E}[0m ${E}[38;5;245m%USERNAME%${E}${PAL.Greet}!   %PART%${E}[0m%TAG%${E}${PAL.RESET}`));
    out.push(echo(`${E}${PAL.Fortune}  «%FR%»${E}${PAL.RESET}`));
    if (hint) {
      out.push(`if defined COWBOY_HINT echo ${esc(`${E}${PAL.Hint}  COWBOY_THEME=тема - сменить тему   |   COWBOY_BANNER=menu - меню тем${E}${PAL.RESET}`)}`);
    }
  } else {
    // ASCII-ветка: только латиница, иначе в консоли с чужой кодировкой будет каша
    out.push(echo("  %HI%, %USERNAME%!   %PARTA%%TAG%"));
    out.push(echo('  "%FE%"'));
    if (hint) out.push(`if defined COWBOY_HINT echo ${esc("  COWBOY_THEME=theme - switch   |   COWBOY_BANNER=menu - menu")}`);
  }
  out.push("goto :done");
  return out.join("\r\n");
}

// ── меню выбора темы ────────────────────────────────────────────────────
const INNER = 60;
const G = { TL: "╔", TR: "╗", H: "═", V: "║", ML: "╠", MR: "╣", BL: "╚", BR: "╝" };
const A = { TL: "+", TR: "+", H: "-", V: "|", ML: "+", MR: "+", BL: "+", BR: "+" };

function menuBlock(boxed, ru) {
  const g = boxed ? G : A;
  const W = (t) => (t.length > INNER ? t.slice(0, INNER) : t + " ".repeat(INNER - t.length));
  const L = [];
  L.push(echo(`  ${g.TL}${g.H.repeat(INNER)}${g.TR}`));
  // заголовок тоже паддингуем до INNER, иначе правая рамка уезжает
  const head = ru ? "   Т Е М Ы   Б А Н Н Е Р О В   -   что рисовать?" : "   B A N N E R   T H E M E S   -   pick one";
  L.push(echo(`  ${g.V}${W(head)}${g.V}`));
  L.push(echo(`  ${g.ML}${g.H.repeat(INNER)}${g.MR}`));
  themes.forEach((t, i) => {
    const desc = ru ? t.ru : t.title;
    const mark = i === 0 ? "%MK1%" : i === 1 ? "%MK2%" : i === 2 ? "%MK3%" : "%MK4%";
    const row = `${mark} ${t.id.padEnd(9)} ${desc.padEnd(14)} ${t.scenes.length} шт`;
    L.push(echo(`  ${g.V}${ru ? W(row) : W(row)}${g.V}`));
  });
  const anyMark = "%MK5%";
  L.push(echo(`  ${g.V}${W(`${anyMark} any       ${ru ? "любая тема" : "any theme"}  ${ru ? " (случайно)" : " (random)"}`)}${g.V}`));
  L.push(echo(`  ${g.BL}${g.H.repeat(INNER)}${g.BR}`));
  L.push(echo(""));
  L.push(echo(`  ${ru ? "Сейчас активна тема:" : "Current theme:"} %CURT%`));
  L.push(echo(""));
  L.push(echo(`  ${ru ? "Переключить тему (работает и в PowerShell, и в cmd):" : "Switch theme (works in PowerShell and cmd):"}`));
  themes.forEach((t) => L.push(echo(`      setx COWBOY_THEME ${t.id}`)));
  L.push(echo(`      setx COWBOY_THEME any        ${ru ? "(каждая картинка случайная)" : "(random picture each time)"}`));
  L.push(echo(""));
  L.push(echo(`  ${ru ? "Только для этого окна (без setx):" : "This window only (no setx):"}`));
  L.push(echo(`      set COWBOY_THEME=ocean        cmd`));
  L.push(echo(`      $env:COWBOY_THEME = 'ocean'   PowerShell`));
  L.push(echo(""));
  L.push(echo(`  ${ru ? "Что бывает в COWBOY_BANNER:" : "Values of COWBOY_BANNER:"}`));
  L.push(echo(`      ${ru ? "(не задана) рисовать картинку" : "(unset)        draw the picture"}  setx COWBOY_BANNER ""`));
  L.push(echo(`      menu        ${ru ? "показать это меню " : "show this menu      "}  setx COWBOY_BANNER menu`));
  L.push(echo(`      none        ${ru ? "не выводить ничего " : "show nothing        "}  setx COWBOY_BANNER none`));
  L.push(echo(`      ascii       ${ru ? "без псевдографики   " : "no box drawing      "}  setx COWBOY_BANNER ascii`));
  L.push(echo(`      plain       ${ru ? "без цвета          " : "no colors          "}  setx COWBOY_BANNER plain`));
  L.push(echo(`      ${ru ? "off - старое имя для menu, то же самое" : "off - old name of menu, same thing"}`));
  L.push(echo(""));
  L.push(echo(`  ${ru ? "Подсказки в баннере - отдельно:" : "Hints in the banner:"}    setx COWBOY_HINT on`));
  return L.join("\r\n");
}

// ── диспетчер тем ───────────────────────────────────────────────────────
const themeBlocks = [];
themes.forEach((t, i) => {
  themeBlocks.push(`:th_${t.id}`);
  themeBlocks.push(`set "TH=${t.id}"`);
  themeBlocks.push(`set "NS=${t.scenes.length}"`);
  themeBlocks.push("goto :pick");
});
const anyBlock = [":anytheme", `set /a R=%RANDOM% %% ${themes.length}`]
  .concat(themes.map((t, i) => (i < themes.length - 1 ? `if "%R%"=="${i}" goto :th_${t.id}` : `goto :th_${t.id}`)))
  .join("\r\n");

const dispatchDos = [":d_first", `if /I "%TH%"=="${themes[0].id}" goto :d_${themes[0].id}`]
  .concat(themes.slice(1).map((t) => `if /I "%TH%"=="${t.id}" goto :d_${t.id}`))
  .concat([`goto :d_${themes[themes.length - 1].id}`])
  .concat(
    themes.flatMap((t) => {
      const jumps = t.scenes.map((s, i) => (i < t.scenes.length - 1 ? `if "%S%"=="${i}" goto :${s}_dos` : `goto :${s}_dos`));
      return [`:d_${t.id}`, `if not "%CP%"=="866" goto :a_${t.id}`, ...jumps];
    })
  )
  .join("\r\n");

const dispatchAsc = themes.flatMap((t) => {
  const jumps = t.scenes.map((s, i) => (i < t.scenes.length - 1 ? `if "%S%"=="${i}" goto :${s}_asc` : `goto :${s}_asc`));
  return [`:a_${t.id}`, ...jumps];
}).join("\r\n");

// ── сборка файла ────────────────────────────────────────────────────────
const head = `@echo off
rem ==========================================================================
rem  THE WILD WEST / SPACE / CYBER / OCEAN - баннер при запуске cmd.exe
rem  Темы: ${themes.map((t) => t.id).join(", ")} - внутри темы сцена выбирается случайно.
rem
rem    COWBOY_BANNER=off     вместо картинки - меню выбора темы
rem    COWBOY_BANNER=none    не показывать ничего
rem    COWBOY_THEME=<тема>   wildwest | space | cyber | ocean | any
rem    COWBOY_BANNER=ascii   без псевдографики (для консолей не в cp866)
rem    COWBOY_ALWAYS=1       показывать и в cmd /c (для скриптов и тестов)
rem
rem  Убрать совсем:
rem    reg delete "HKCU\\Software\\Microsoft\\Command Processor" /v AutoRun /f
rem ==========================================================================

if defined COWBOY_BANNER_DONE goto :eof
set "COWBOY_BANNER_DONE=1"

rem Переключатель один на оба шелла, регистр не важен, пробелы не важны:
rem "set X=off " в cmd даёт значение "off " - это ловушка, поэтому режем пробелы.
rem Пробелы режем в два шага: подстановка %ПЕРЕМ: =% на НЕОПРЕДЕЛЕННОЙ
rem переменной даёт пробел, а не пустую строку.
set "OFF=%COWBOY_CMD%"
if not defined OFF set "OFF=%COWBOY_BANNER%"
set "OFF=%OFF: =%"
if /I "%OFF%"=="none" goto :eof
rem Баннер - только в интерактивном окне (в командной строке нет /c или /k),
rem иначе он засоряет вывод у скриптов.
if defined COWBOY_ALWAYS goto :nocheck
echo %cmdcmdline% | find /i "/c " >nul && goto :eof
echo %cmdcmdline% | find /i "/k " >nul && goto :eof
:nocheck

setlocal
set "ESC=${E}"

rem --- кодовая страница консоли (языконезависимо) ------------------------
set "CP="
for /f "delims=" %%a in ('chcp') do set "RAW=%%a"
set "RAW=%RAW: =%"
set "RAW=%RAW::=/%"
for /f "tokens=1,* delims=/" %%a in ("%RAW%") do set "CP=%%b"
if /I "%OFF%"=="ascii" set "CP=000"

rem Меню - после определения кодировки: красивая рамка требует cp866.
rem "off" - старое имя для menu, работает как синоним.
if /I "%OFF%"=="menu" goto :menu
if /I "%OFF%"=="off" goto :menu

rem --- тема ---------------------------------------------------------------
set "TH=%COWBOY_THEME%"
set "TH=%TH: =%"
if not defined TH set "TH=wildwest"
if /I "%TH%"=="any" goto :anytheme
if /I "%TH%"=="menu" goto :menu
if /I "%TH%"=="off" goto :menu
${themes.slice(1).map((t) => `if /I "%TH%"=="${t.id}" goto :th_${t.id}`).join("\r\n")}
${themeBlocks.join("\r\n")}
goto :th_${themes[0].id}

${anyBlock}

:pick
rem --- сцена: случайно внутри темы, но не та же, что в прошлый раз ---------
set /a S=%RANDOM% %% %NS%
set "SF=%TEMP%\\cowboy-scene-%TH%.txt"
set "PREV="
if exist "%SF%" set /p PREV=<"%SF%"
if "%PREV%"=="%S%" set /a S=(%S%+1) %% %NS%
> "%SF%" echo %S%

rem --- метка [тема] в приветствии: только если попросили подсказки -------
set "TAG="
if defined COWBOY_HINT set "TAG=   [%TH%]"

rem --- время суток, приветствие и поговорка по теме ----------------------
for /f "tokens=1 delims=:." %%a in ("%TIME%") do set "HOUR=%%a"
if not defined HOUR set "HOUR=12"
set /a HOUR=%HOUR% 2>nul
if not defined HOUR set "HOUR=12"
set /a GI=%RANDOM% %% ${themes[0].greet.length}
set /a SI=%RANDOM% %% ${themes[0].sayRu.length}

rem поговорки всех тем: русские (FR_тема_N) и английские (EN_тема_N)
${saySets("FR_", "sayRu")}
${saySets("EN_", "sayEn")}

set "PART=ДОБРЫЙ ВЕЧЕР"
set "PARTA=GOOD EVENING"
if %HOUR% LSS 5 set "PART=ДОБРАЯ НОЧЬ"
if %HOUR% LSS 5 set "PARTA=GOOD NIGHT"
if %HOUR% GEQ 5 if %HOUR% LSS 12 set "PART=ДОБРОЕ УТРО"
if %HOUR% GEQ 5 if %HOUR% LSS 12 set "PARTA=GOOD MORNING"
if %HOUR% GEQ 12 if %HOUR% LSS 18 set "PART=ДОБРЫЙ ДЕНЬ"
if %HOUR% GEQ 12 if %HOUR% LSS 18 set "PARTA=GOOD AFTERNOON"

${sayDispatch}
${sayBlocks}
:say_done

rem --- выбор сцены --------------------------------------------------------
${dispatchDos}

${dispatchAsc}

rem ======================= МЕНЮ ТЕМ =====================================
:menu
setlocal
set "CURT=%COWBOY_THEME%"
if not defined CURT set "CURT=wildwest"
set "CURT=%CURT: =%"
rem Маркер темы - звёздочка, а не ">": в echo это знак перенаправления вывода.
rem Поле маркера всегда 2 символа, иначе строки съезжают по колонкам.
set "MK1=  "
set "MK2=  "
set "MK3=  "
set "MK4=  "
set "MK5=  "
if /I "%CURT%"=="${themes[0].id}" set "MK1= *"
if /I "%CURT%"=="${themes[1].id}" set "MK2= *"
if /I "%CURT%"=="${themes[2].id}" set "MK3= *"
if /I "%CURT%"=="${themes[3].id}" set "MK4= *"
if /I "%CURT%"=="any" set "MK5= *"
echo(
rem --- красивое меню (нужна cp866) ---
if not "%CP%"=="866" goto :menu_ascii
${menuBlock(true, true)}
goto :menu_done
:menu_ascii
${menuBlock(false, false)}
:menu_done
endlocal
goto :eof

`;

// cmd.exe надёжно разбирает .cmd только с CRLF - нормализуем все переводы строк.
const crlf = (s) => s.replace(/\r?\n/g, "\r\n");

const parts = [crlf(head)];

for (const theme of themes) {
  for (const id of theme.scenes) {
    parts.push(`rem ===== ${theme.id} / ${id} =====`);
    parts.push(`:${id}_dos`);
    parts.push(sceneBlock(id, "dos"));
    parts.push("");
    parts.push(`:${id}_asc`);
    parts.push(sceneBlock(id, "ascii"));
    parts.push("");
  }
}

parts.push(`:done
endlocal
goto :eof
`);

const body = crlf(parts.join("\r\n"));
const target = process.argv[2];
if (!target) {
  console.error("usage: node gen-cmd.js <путь-к-cowboy.cmd>");
  process.exit(1);
}
fs.writeFileSync(target, toCp866(body));
console.log(`cmd записан: ${target}`);
console.log(`тем: ${themes.length} (${themes.map((t) => t.id).join(", ")}) | сцен: ${themes.reduce((n, t) => n + t.scenes.length, 0)} | ${fs.statSync(target).size} байт (cp866)`);
