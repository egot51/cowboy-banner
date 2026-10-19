// Собирает AUR-пакет cowboy-banner из scenes.json + статических файлов из src/.
//
//   node gen-linux.js [каталог-исходников] [каталог-пакета]
//
// По умолчанию: исходники ../../src (в репозитории проекта),
//               пакет     ../../linux
const fs = require("fs");
const path = require("path");
const { data, paintArt } = require("./paint.js");

const REPO = path.join(__dirname, "..");
const SRC = path.resolve(process.argv[2] || path.join(REPO, "src"));
const OUT = path.resolve(process.argv[3] || path.join(REPO, "linux"));

const PKGVER = "1.0.0";
const PKGREL = "1";

// Каталог src/ от прошлой версии пакета удаляем: makepkg резервирует его под
// распаковку исходников, и при makepkg -C он стирается целиком.
// Сам выходной каталог не чистим - в нём может лежать .git.
const legacy = path.join(OUT, "src");
if (fs.existsSync(legacy)) {
  fs.rmSync(legacy, { recursive: true, force: true });
  console.log("удалён устаревший каталог src/");
}

const mk = (p) => fs.mkdirSync(p, { recursive: true });
const write = (p, text, mode) => {
  mk(path.dirname(p));
  fs.writeFileSync(p, text, "utf8");
  if (mode) fs.chmodSync(p, mode);
};
// PowerShell 5.1 читает .ps1 без BOM как ANSI и ломает кириллицу внутри строк,
// поэтому профиль сохраняем с BOM. На Linux это безвредно, а на Windows
// тот же файл открывается без сюрпризов.
const writeBom = (p, text, mode) => write(p, "\uFEFF" + text, mode);

// Арт уже с цветами: на Linux терминал всегда UTF-8, псевдографика не нуждается
// в fallback-ветке, а читать файл через cat быстрее, чем разбирать разметку.
// Каталог называется files/, а не src/: src/ - служебный каталог makepkg
// ($srcdir по умолчанию), и makepkg --cleanbuild удаляет его целиком вместе
// с нашими файлами.
const scenes = {};
for (const [id, s] of Object.entries(data.scenes)) {
  const art = paintArt(s.unicode.art, s.unicode.segments);
  scenes[id] = { art, title: s.unicode.art.split("\n").filter((l) => l.trim()).pop().trim() };
}

for (const [id, s] of Object.entries(scenes)) {
  write(path.join(OUT, "files/art", `${id}.txt`), s.art.replace(/\n+$/, "") + "\n");
}

// Данные для bash и PowerShell: читаются с диска при каждом запуске, поэтому
// вынесены из профиля - профиль остаётся лёгким, а тексты правятся без пересборки.
const themes = data.themes;
write(
  path.join(OUT, "files/data/themes.list"),
  themes.map((t) => [t.id, t.ru, t.scenes.length].join("\t")).join("\n") + "\n"
);
for (const t of themes) {
  write(path.join(OUT, "files/data", `${t.id}.scenes`), t.scenes.join("\n") + "\n");
  write(path.join(OUT, "files/data", `${t.id}.titles`), t.scenes.map((s) => scenes[s].title).join("\n") + "\n");
  write(path.join(OUT, "files/data", `${t.id}.greet`), t.greet.join("\n") + "\n");
  write(path.join(OUT, "files/data", `${t.id}.say`), t.sayRu.join("\n") + "\n");
  write(path.join(OUT, "files/data", `${t.id}.sayen`), t.sayEn.join("\n") + "\n");
}

// Статические файлы: скрипт, профиль PowerShell, хуки установки, man.
// BOM - только профилю PowerShell: bash и данные с BOM ломаются (shebang,
// первая строка через sed, лишний символ в арте).
const statics = [
  ["bin/cowboy-banner", "files/bin/cowboy-banner", 0o755, write],
  ["profile.ps1", "files/profile.ps1", 0o644, writeBom],
  ["cowboy-banner.install", "cowboy-banner.install", 0o644, write],
  ["man/cowboy-banner.1", "files/man/cowboy-banner.1", 0o644, write],
];
for (const [from, to, mode, put] of statics) {
  // BOM в исходнике снимаем: writeBom добавит ровно один, иначе получится
  // два подряд и PowerShell увидит мусор в начале файла.
  const text = fs.readFileSync(path.join(SRC, from), "utf8").replace(/^\uFEFF/, "");
  put(path.join(OUT, to), text, mode);
}

const pkgdesc =
  "Цветной ASCII-баннер (Дикий Запад, космос, киберпанк, океан) при старте bash, zsh и PowerShell";

write(
  path.join(OUT, "LICENSE"),
  `MIT License

Copyright (c) 2026 CIwi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
`
);

// Мейнтейнер. Настоящий email нужен только в копии пакета для AUR (там он
// обязателен), поэтому в публичный репозиторий он не попадает: соберите
// пакет для AUR с переменной окружения
//   COWBOY_MAINTAINER="Имя <email>" node tools/gen-linux.js src <каталог>
const MAINTAINER = process.env.COWBOY_MAINTAINER || "CIwi";

write(
  path.join(OUT, "PKGBUILD"),
  `# Maintainer: ${MAINTAINER}
# Собирать нечего: картинки, скрипты и данные уже лежат в files/.
pkgname=cowboy-banner
pkgver=${PKGVER}
pkgrel=${PKGREL}
pkgdesc='${pkgdesc}'
arch=('any')
# Адрес исходников пакета. makepkg требует url, а AUR показывает его
# на странице пакета.
url='https://github.com/egot51/cowboy-banner'
license=('MIT')
depends=('bash' 'coreutils')
optdepends=('zsh: баннер в zsh' 'powershell: баннер в PowerShell 7+')
install="$pkgname.install"
source=()
sha256sums=()
options=('!strip')

check() {
    # Дымовой тест: картинка и меню должны печататься без ошибок.
    COWBOY_ROOT="$startdir/files" COWBOY_ALWAYS=1 \\
        bash "$startdir/files/bin/cowboy-banner" > /dev/null
    COWBOY_ROOT="$startdir/files" COWBOY_ALWAYS=1 COWBOY_BANNER=menu \\
        bash "$startdir/files/bin/cowboy-banner" > /dev/null
    COWBOY_ROOT="$startdir/files" COWBOY_ALWAYS=1 COWBOY_THEME=any \\
        bash "$startdir/files/bin/cowboy-banner" > /dev/null
}

package() {
    cd "$startdir/files"

    # install -D создаёт только ведущие каталоги; каталог-назначение
    # с завершающим слэшем должен существовать заранее.
    mkdir -p "$pkgdir/usr/share/cowboy-banner/art" "$pkgdir/usr/share/cowboy-banner/data"

    install -Dm755 bin/cowboy-banner "$pkgdir/usr/bin/cowboy-banner"
    install -Dm644 profile.ps1 "$pkgdir/usr/share/cowboy-banner/profile.ps1"
    install -Dm644 art/*.txt "$pkgdir/usr/share/cowboy-banner/art/"
    install -Dm644 data/* "$pkgdir/usr/share/cowboy-banner/data/"
    install -Dm644 man/cowboy-banner.1 "$pkgdir/usr/share/man/man1/cowboy-banner.1"
    # README и LICENSE лежат в корне пакета, а package() уже перешёл в files/
    install -Dm644 "$startdir/README.md" "$pkgdir/usr/share/doc/$pkgname/README.md"
    install -Dm644 "$startdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"

    # Новые пользователи получают баннер в PowerShell сразу.
    # В bash и zsh автозапуск подключает post_install - у Arch нет общего
    # rc-фрагмента, который подхватили бы новые аккаунты.
    install -Dm644 profile.ps1 \\
        "$pkgdir/etc/skel/Default/.config/powershell/Microsoft.PowerShell_profile.ps1"
}
`
);

write(
  path.join(OUT, ".SRCINFO"),
  `pkgbase = cowboy-banner
\tpkgdesc = ${pkgdesc}
\tpkgver = ${PKGVER}
\tpkgrel = ${PKGREL}
\tepoch = 0
\tarch = any
\turl = https://github.com/egot51/cowboy-banner
\tlicense = MIT
\tmakedepends =
\tdepends = bash
\tdepends = coreutils
\toptdepends = zsh: баннер в zsh
\toptdepends = powershell: баннер в PowerShell 7+
\tprovides =
\tconflicts =
\treplaces =
\toptions = !strip
\tinstall = cowboy-banner.install
`
);

// Перегенерация .SRCINFO на машине с Arch (нужен makepkg).
write(
  path.join(OUT, "update-srcinfo.sh"),
  `#!/bin/sh
# Перегенерировать .SRCINFO так, как это сделает makepkg.
# Запускать на Arch: sh update-srcinfo.sh
set -e
command -v makepkg >/dev/null 2>&1 || {
    echo "makepkg не найден: этот скрипт нужен только на Arch" >&2
    exit 1
}
makepkg --printsrcinfo > .SRCINFO
echo ".SRCINFO обновлён"
`
);

const picLines = themes
  .map((t) => {
    const items = t.scenes.map((s) => `**${scenes[s].title.replace(/\s+/g, " ")}**`).join(", ");
    return `- **${t.id}** — ${t.ru} (${t.scenes.length})\n  ${items}`;
  })
  .join("\n");

write(
  path.join(OUT, "README.md"),
  `# cowboy-banner

Цветной ASCII-баннер при старте терминала: случайная картинка внутри случайной
темы, приветствие по времени суток и случайная поговорка по теме. Работает в
bash, zsh и PowerShell 7+.

${picLines}

## Установка

\`\`\`bash
yay -S cowboy-banner       # или paru / pikaur
\`\`\`

Хуки установки сами допишут запуск в \`~/.bashrc\`, \`~/.zshrc\` и профиль
PowerShell (с бэкапом). Посмотреть прямо сейчас:

\`\`\`bash
cowboy-banner
\`\`\`

## Управление

| Переменная | Значения |
|---|---|
| \`COWBOY_THEME\` | \`wildwest\` (по умолчанию), \`space\`, \`cyber\`, \`ocean\`, \`any\`, \`menu\` |
| \`COWBOY_BANNER\` | не задана — картинка; \`menu\` — меню тем; \`none\` — молчать; \`plain\`/\`ascii\` — без цвета; \`off\` = \`menu\` |
| \`COWBOY_HINT\` | \`on\` — подсказка и метка \`[тема]\` под картинкой |
| \`COWBOY_ALWAYS\` | \`1\` — печатать и при перенаправлении вывода |
| \`NO_COLOR\` | задан — цвета выключены |

Навсегда (bash):

\`\`\`bash
echo 'export COWBOY_THEME=ocean' >> ~/.bashrc
echo 'export COWBOY_BANNER=none' >> ~/.bashrc
\`\`\`

Навсегда (PowerShell):

\`\`\`powershell
$env:COWBOY_THEME = 'ocean'
$env:COWBOY_BANNER = 'none'
\`\`\`

Меню тем прямо сейчас:

\`\`\`bash
COWBOY_BANNER=menu cowboy-banner
pwsh -c 'COWBOY_BANNER=menu; . /usr/share/cowboy-banner/profile.ps1'
\`\`\`

Подробности: \`man cowboy-banner\`.

## Что где лежит

| Путь | Что |
|---|---|
| \`/usr/bin/cowboy-banner\` | скрипт на bash |
| \`/usr/share/cowboy-banner/art/\` | ${Object.keys(scenes).length} картинок с ANSI-цветом |
| \`/usr/share/cowboy-banner/data/\` | приветствия, поговорки, списки сцен |
| \`/usr/share/cowboy-banner/profile.ps1\` | версия для PowerShell |
| \`\${XDG_RUNTIME_DIR:-/tmp}/cowboy-banner.state\` | прошлая картинка, чтобы не повторялась |
| \`/etc/skel/Default/.config/powershell/Microsoft.PowerShell_profile.ps1\` | баннер для новых пользователей PowerShell |

## Удаление

\`\`\`bash
sudo pacman -Rns cowboy-banner
\`\`\`

Хуки \`pre_remove\` вырежут свои блоки из rc-файлов и профиля PowerShell.
Прежние версии файлов остаются рядом как \`*.cowboy-banner.bak\`.

## Лицензия

MIT, см. \`LICENSE\`.

## Публикация в AUR

1. Заведите аккаунт на <https://aur.archlinux.org> и добавьте свой открытый
   SSH-ключ в профиле.
2. Создайте пустой репозиторий пакета (AUR сам создаст его при первом пуше):

   \`\`\`bash
   git clone ssh://aur.archlinux.org/<ваш-email>/cowboy-banner.git
   cd cowboy-banner
   \`\`\`

3. Скопируйте сюда файлы: \`PKGBUILD\`, \`.SRCINFO\`, \`cowboy-banner.install\`,
   \`LICENSE\`, \`README.md\`, \`.gitignore\`, \`.gitattributes\`, каталог
   \`files/\`.
4. Проверьте, что \`.SRCINFO\` совпадает с тем, что сделает makepkg:

   \`\`\`bash
   sh update-srcinfo.sh    # требует makepkg, то есть Arch
   \`\`\`

5. Отправьте:

   \`\`\`bash
   git add -A
   git commit -m "Initial version"
   git push
   \`\`\`

6. Пакет появится в AUR после проверки модератором. Дальше его ставят через
   \`yay -S cowboy-banner\` или \`paru -S cowboy-banner\`.

Перед отправкой в \`PKGBUILD\` должна быть строка \`# Maintainer: Имя <email>\` -
email мейнтейнера обязателен для AUR (он же пойдёт в SSH-URL репозитория
AUR). В публичной копии репозитория настоящего email нет: там стоит только
имя, а пакет для AUR собирается с переменной окружения:

\`\`\`bash
COWBOY_MAINTAINER="Имя <email>" node tools/gen-linux.js src <каталог-пакета>
\`\`\`

Поле \`url\` уже проставлено на адрес этого репозитория.
`
);

// .gitignore для makepkg: собранные пакеты и рабочие файлы в репозиторий не идут.
// Каталог files/ (полезная нагрузка) - часть репозитория, его игнорировать нельзя.
write(path.join(OUT, ".gitignore"), "pkg/\n*.pkg.tar.*\n*.src.tar.*\n.makepkg*\n");

// На Windows системный git по умолчанию переводит строки в CRLF (core.autocrlf=true).
// Тогда в файлах данных появляется \r, в id сцены попадает CR и картинка не
// находится. Принудительно требуем LF в репозитории и в рабочей копии.
write(
  path.join(OUT, ".gitattributes"),
  "# Весь пакет - текст, и его нужно хранить и выдавать с LF.\n" +
    "* text=auto eol=lf\n" +
    "\n" +
    "# art/*.txt - готовая картинка с ANSI-последовательностями, трогать нельзя.\n" +
    "files/art/*.txt -diff\n"
);

let files = 0;
const walk = (d) => {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else files++;
  }
};
walk(OUT);
const artBytes = Object.values(scenes).reduce((a, s) => a + Buffer.byteLength(s.art, "utf8"), 0);
console.log(`aur/cowboy-banner: ${files} файлов, ${PKGVER}-${PKGREL}`);
console.log(`  тем ${themes.length}, картинок ${Object.keys(scenes).length}, арт ${(artBytes / 1024).toFixed(1)} КБ (без цвета ~${(artBytes / 3.4 / 1024).toFixed(1)} КБ)`);
console.log(`  собрано сцен: ${Object.keys(scenes).join(", ")}`);
