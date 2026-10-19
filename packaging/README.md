# Сборка пакетов для разных дистрибутивов

Все форматы собираются из **одного дерева файлов** — `linux/files/`.
Оно генерируется из исходников (`src/` + `tools/`) и содержит готовую
раскладку `/usr`:

```
files/
├── etc/skel/Default/.config/powershell/Microsoft.PowerShell_profile.ps1
├── usr/bin/cowboy-banner
├── usr/lib/cowboy-banner/{install.sh,remove.sh}   общие хуки
├── usr/share/cowboy-banner/{art,data,profile.ps1}
├── usr/share/man/man1/cowboy-banner.1
├── usr/share/doc/cowboy-banner/README.md
└── usr/share/licenses/cowboy-banner/LICENSE
```

Общие хуки `install.sh` и `remove.sh` используют все unix-форматы: они
дописывают вызов баннера в `~/.bashrc`, `~/.zshrc` и профиль PowerShell
(с бэкапом) и вырезают эти строки при удалении. Правки в одном файле
достаточно для всех пакетов.

## Что чем собирается

| Формат | Дистрибутивы | Чем собирать | Где рецепт |
|---|---|---|---|
| AUR | Arch, Manjaro | `makepkg` | `linux/PKGBUILD` |
| deb | Debian, Ubuntu, Mint | свой сборщик на Node | `packaging/debian/`, `packaging/build-deb.js` |
| rpm | Fedora, RHEL, openSUSE | `rpmbuild` | `packaging/rpm/cowboy-banner.spec` |
| nix | NixOS, любой nix-дистрибутив | `nix build` | `packaging/nix/flake.nix` |
| zip | Windows (Scoop, Chocolatey, winget) | свой сборщик на Node | `packaging/build-zip.js` |

## Сборка всего

```powershell
.\packaging\build-all.ps1      # Windows: .deb, zip, манифесты, тесты
```

```bash
sh packaging/build-all.sh      # Linux: .deb, .rpm (нужен rpmbuild), zip, тесты
```

Артефакты появляются в `dist/`.

## По шагам

### Debian / Ubuntu

```bash
node packaging/build-deb.js
sudo dpkg -i dist/cowboy-banner_1.0.0_all.deb
```

Сборщик написан на Node и не требует `dpkg-deb`: формат `.deb` — это ar-архив
с тремя членами, а tar и gzip делает сам Node. Чтобы поменять email
мейнтейнера:

```bash
node packaging/build-deb.js --maintainer "Имя <email>"
```

### Fedora / RHEL / openSUSE

```bash
sh packaging/build-all.sh
sudo rpm -i dist/cowboy-banner-1.0.0-1*.rpm
```

Нужен `rpmbuild` (Fedora: `dnf install rpm-build`).

### Nix

```bash
nix build .#cowboy-banner
nix profile install .#cowboy-banner
```

Для home-manager есть готовый модуль:

```nix
programs.cowboyBanner = {
  enable = true;
  theme = "ocean";
};
```

### Windows: Scoop, Chocolatey, winget

Сначала собирается zip — это общий артефакт для трёх менеджеров:

```powershell
node packaging\build-zip.js
node packaging\update-manifests.js    # вписывает sha256 в манифесты
```

Потом артефакт выкладывается в Releases (тег `v1.0.0`), и манифесты
заливаются туда, где их ждут:

| Пакет | Куда класть манифест |
|---|---|
| Scoop | `bucket` (свой репозиторий) или PR в `ScoopInstaller/Main` |
| Chocolatey | `chocolatey-community/chocolatey-packages` |
| winget | `microsoft/winget-pkgs`, путь `manifests/e/egot51/cowboy-banner/<версия>/` |

Пока Releases не опубликованы, в манифестах стоит заглушка
`ЗАМЕНИТЬ_НА_SHA256` — `update-manifests.js` заменяет её настоящим хешем
после сборки.

## Проверки

```bash
bash tests/test-linux.sh        # скрипт и режимы: 32 проверки
bash tests/test-pkgbuild.sh     # PKGBUILD и хуки: 26 проверок
node tests/test-deb.js          # разбор собранного .deb: 28 проверок
node tests/test-packages.js     # манифесты всех форматов: 57 проверок
powershell -File tests/test-zip.ps1   # zip: установка, запуск, удаление: 23 проверки
powershell -File tests/test-linux.ps1 # профиль PowerShell: 23 проверки
```

## Мелочи, о которые легко споткнуться

- **BOM.** Все файлы `.ps1` должны быть в UTF-8 с BOM: без него PowerShell 5.1
  читает кириллицу как ANSI и ломает разбор. Проверяет `tests/test-packages.js`.
- **CRLF.** В bash-скриптах и файлах данных переводы строк должны быть LF.
  `.gitattributes` требует `eol=lf`, а `cowboy.cmd` помечен как `-text` —
  он однобайтовый (cp866) и с CRLF.
- **`src/` в AUR.** Каталог `src/` зарезервирован makepkg (`$srcdir`),
  поэтому полезная нагрузка лежит в `files/`.
- **Символ `@` в .cmd.** В шаблоне для .cmd писать только `@E`, а не `$E`:
  литерал `%E[0m` сбивает разбор переменных cmd.
