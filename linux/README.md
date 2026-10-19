# cowboy-banner

Цветной ASCII-баннер при старте терминала: случайная картинка внутри случайной
темы, приветствие по времени суток и случайная поговорка по теме. Работает в
bash, zsh и PowerShell 7+.

- **wildwest** — Дикий Запад (4)
  **T H E S U N S E T T R A I L**, **T H E L O N G W I R E**, **C A M P F I R E A T D U S K**, **T H E L A S T S A L O O N I N T O W N**
- **space** — Космос (2)
  **O R B I T O F F A M I L Y**, **D E E P S P A C E N E T W O R K**
- **cyber** — Киберпанк (2)
  **N E O N N I G H T**, **G H O S T I N T H E S H E L L**
- **ocean** — Океан (2)
  **D E E P W A T E R**, **S O M E W H E R E A B O V E T H E S E A**

## Установка

```bash
yay -S cowboy-banner       # или paru / pikaur
```

Хуки установки сами допишут запуск в `~/.bashrc`, `~/.zshrc` и профиль
PowerShell (с бэкапом). Посмотреть прямо сейчас:

```bash
cowboy-banner
```

## Управление

| Переменная | Значения |
|---|---|
| `COWBOY_THEME` | `wildwest` (по умолчанию), `space`, `cyber`, `ocean`, `any`, `menu` |
| `COWBOY_BANNER` | не задана — картинка; `menu` — меню тем; `none` — молчать; `plain`/`ascii` — без цвета; `off` = `menu` |
| `COWBOY_HINT` | `on` — подсказка и метка `[тема]` под картинкой |
| `COWBOY_ALWAYS` | `1` — печатать и при перенаправлении вывода |
| `NO_COLOR` | задан — цвета выключены |

Навсегда (bash):

```bash
echo 'export COWBOY_THEME=ocean' >> ~/.bashrc
echo 'export COWBOY_BANNER=none' >> ~/.bashrc
```

Навсегда (PowerShell):

```powershell
$env:COWBOY_THEME = 'ocean'
$env:COWBOY_BANNER = 'none'
```

Меню тем прямо сейчас:

```bash
COWBOY_BANNER=menu cowboy-banner
pwsh -c 'COWBOY_BANNER=menu; . /usr/share/cowboy-banner/profile.ps1'
```

Подробности: `man cowboy-banner`.

## Что где лежит

| Путь | Что |
|---|---|
| `/usr/bin/cowboy-banner` | скрипт на bash |
| `/usr/share/cowboy-banner/art/` | 10 картинок с ANSI-цветом |
| `/usr/share/cowboy-banner/data/` | приветствия, поговорки, списки сцен |
| `/usr/share/cowboy-banner/profile.ps1` | версия для PowerShell |
| `${XDG_RUNTIME_DIR:-/tmp}/cowboy-banner.state` | прошлая картинка, чтобы не повторялась |
| `/etc/skel/Default/.config/powershell/Microsoft.PowerShell_profile.ps1` | баннер для новых пользователей PowerShell |

## Удаление

```bash
sudo pacman -Rns cowboy-banner
```

Хуки `pre_remove` вырежут свои блоки из rc-файлов и профиля PowerShell.
Прежние версии файлов остаются рядом как `*.cowboy-banner.bak`.

## Лицензия

MIT, см. `LICENSE`.

## Публикация в AUR

1. Заведите аккаунт на <https://aur.archlinux.org> и добавьте свой открытый
   SSH-ключ в профиле.
2. Создайте пустой репозиторий пакета (AUR сам создаст его при первом пуше):

   ```bash
   git clone ssh://aur.archlinux.org/<ваш-email>/cowboy-banner.git
   cd cowboy-banner
   ```

3. Скопируйте сюда файлы: `PKGBUILD`, `.SRCINFO`, `cowboy-banner.install`,
   `LICENSE`, `README.md`, `.gitignore`, `.gitattributes`, каталог
   `files/`.
4. Проверьте, что `.SRCINFO` совпадает с тем, что сделает makepkg:

   ```bash
   sh update-srcinfo.sh    # требует makepkg, то есть Arch
   ```

5. Отправьте:

   ```bash
   git add -A
   git commit -m "Initial version"
   git push
   ```

6. Пакет появится в AUR после проверки модератором. Дальше его ставят через
   `yay -S cowboy-banner` или `paru -S cowboy-banner`.

Перед отправкой поправьте в `PKGBUILD` строку `# Maintainer:` (ваш email -
он же пойдёт в SSH-URL репозитория AUR) и проверьте поле `url`. Сейчас там
страница самого пакета в AUR; если исходники выложить отдельно, укажите
адрес этого репозитория.
