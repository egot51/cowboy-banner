# cowboy-banner

Цветной ASCII-баннер при запуске терминала: случайная картинка внутри
случайной темы, приветствие по времени суток и случайная поговорка по теме.

Работает в **PowerShell** и **cmd** на Windows, в **bash**, **zsh** и
**PowerShell 7** на Linux. Четыре темы, десять картинок.

```
                            ·                                        ✦              ·
                    ·  ═══════════════════        ✦
                        ═══════════════════✦═════
                          ═════════════════════════         ───────────
                          ═════════════════════════         ╱───────────╲
             ─────────             ═══════════════════════          │           │
             ╱─────────╲               ═══════════════              │           │
             │         │                                            │           │
════════════════════════════════════════════════════════════════════════════
                    ·             ·                ·
```

## Что внутри

| Тема | Картинок | Что нарисовано |
|---|---|---|
| `wildwest` | 4 | повозка на пыльной дороге, телеграфные столбы, костёр, салон |
| `space` | 2 | планета с кольцом и ракетой, спутник |
| `cyber` | 2 | неоновый город, цифровой дождь и `0xDEADBEEF` |
| `ocean` | 2 | подлодка с перископом, кит над водой |

Всего 16 приветствий и 24 поговорки (русские и английские).

## Установка

### Windows

```powershell
git clone https://github.com/egot51/cowboy-banner.git
cd cowboy-banner
powershell -ExecutionPolicy Bypass -File windows\install.ps1
```

Скрипт положит профиль в `Documents\WindowsPowerShell`, подключит его из
существующего профиля (не затирая его), включит автозапуск cmd и выставит
политику выполнения `RemoteSigned` для текущего пользователя.

Удаление:

```powershell
powershell -ExecutionPolicy Bypass -File windows\uninstall.ps1
```

Можно и вручную — тогда нужен только `Node.js`, чтобы пересобрать:

```powershell
node tools\gen-profile.js "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1"
node tools\gen-cmd.js "$env:USERPROFILE\bin\cowboy.cmd"
```

### Linux (Arch)

```bash
yay -S cowboy-banner
```

Пакет ставит `/usr/bin/cowboy-banner`, арт и тексты в
`/usr/share/cowboy-banner`, а хуки установки дописывают запуск в `~/.bashrc`,
`~/.zshrc` и профиль PowerShell (с бэкапом, при удалении пакета блоки
вырезаются обратно).

Сборка пакета из этого репозитория:

```bash
cd linux && makepkg -si
```

## Управление

Переменные одинаковы для всех шеллов (в PowerShell с префиксом `$env:`).

| Переменная | Значения |
|---|---|
| `COWBOY_THEME` | `wildwest` (по умолчанию), `space`, `cyber`, `ocean`, `any`, `menu` |
| `COWBOY_BANNER` | не задана - картинка; `menu` - меню тем; `none` - молчать; `plain`/`ascii` - без цвета |
| `COWBOY_HINT` | `on` - подсказка и метка `[тема]` под картинкой |
| `COWBOY_ALWAYS` | `1` - печатать и при перенаправлении вывода (cmd и Linux) |
| `COWBOY_CMD` | синоним `COWBOY_BANNER` |
| `NO_COLOR` | задан - цвета выключены (Linux) |

```cmd
setx COWBOY_THEME ocean     :: сменить тему (закрой и открой окно)
setx COWBOY_BANNER none     :: выключить
setx COWBOY_BANNER menu     :: меню тем
```

В PowerShell есть функции `Show-CowboyBanner`, `Show-CowboyMenu`,
`Disable-CowboyBanner`, `Enable-CowboyBanner`, `Get-CowboyBanner` и
алиас `cowboy` (напечатать ещё одну картинку).

## Как это устроено

Арт рисуется кодом и **пре-рендерится в ANSI-последовательности**: в
PowerShell 5.1 разбор разметки при каждом старте стоил бы ~200 мс, поэтому
в профиле лежат готовые строки. Для Linux тот же арт читается с диска -
там профиль от этого не раздувается.

```
src/                 исходники: скрипт bash, профиль PowerShell, хуки, man
tools/               генераторы (Node.js) и scenes.json - источник правды
windows/             готовый профиль PowerShell и cowboy.cmd для Windows
linux/               готовый AUR-пакет
tests/               автотесты: bash, PKGBUILD, PowerShell, сверка раскраски
```

Цвет считается для каждой позиции, а не подменой подстрок: подмена
находила символы внутри уже записанных кодов цвета и ломала картинку.

Пересобрать всё:

```powershell
.\build.ps1
```

```bash
./build.sh
```

Тесты (нужны Node.js и Git Bash; Windows PowerShell - для теста профиля):

```bash
bash tests/test-linux.sh      # 32 проверки: скрипт, режимы, темы, локали
bash tests/test-pkgbuild.sh   # 26 проверок: PKGBUILD и хуки установки
powershell -File tests/test-linux.ps1    # 23 проверки: профиль PowerShell
node tests/verify-paint.js              # сверка раскраски с исходным артом
```

## Требования

- Windows: PowerShell 5.1 или новее, `cmd.exe`
- Linux: `bash`, `coreutils`; опционально `zsh`, `powershell`
- Для сборки из исходников: Node.js 18+

## Лицензия

MIT, см. [LICENSE](LICENSE). Картинки нарисованы кодом в этом же репозитории.
