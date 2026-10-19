# Пакет cowboy-banner для Fedora / RHEL / openSUSE.
#
# Собирается из дерева files/ - оно общее для всех форматов (deb, rpm, nix,
# AUR), поэтому состав файлов у всех одинаковый.
#
#   rpmbuild -ba cowboy-banner.spec
#
Name:           cowboy-banner
Version:        1.0.0
Release:        1%{?dist}
Summary:        Цветной ASCII-баннер при старте терминала
License:        MIT
URL:            https://github.com/egot51/cowboy-banner
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
Requires:       bash
Requires:       coreutils
Recommends:     zsh
Recommends:     powershell

%description
Случайная картинка внутри случайной темы, приветствие по времени суток
и случайная поговорка по теме. Четыре темы: Дикий Запад, космос, киберпанк
и океан, десять картинок.

Работает в bash, zsh и PowerShell 7. Переменные COWBOY_THEME, COWBOY_BANNER,
COWBOY_HINT и COWBOY_ALWAYS. Пакет ничего не делает сам: %post только
дописывает вызов в rc-файлы с бэкапом, а %preun убирает эти строки.

%prep
%setup -q

%build
# Собирать нечего: картинки и тексты уже готовы.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a files/usr files/etc %{buildroot}/

%files
%license %{buildroot}/usr/share/licenses/cowboy-banner/LICENSE
%doc %{buildroot}/usr/share/doc/cowboy-banner/README.md
%{_bindir}/cowboy-banner
%{_datadir}/cowboy-banner/art
%{_datadir}/cowboy-banner/data
%{_datadir}/cowboy-banner/profile.ps1
%{_mandir}/man1/cowboy-banner.1*
%{_datadir}/licenses/cowboy-banner/LICENSE
%{_datadir}/doc/cowboy-banner/README.md
%dir %{_libdir}/cowboy-banner
%{_libdir}/cowboy-banner/install.sh
%{_libdir}/cowboy-banner/remove.sh
%dir %{_datadir}/skel/Default/.config/powershell
%{_datadir}/skel/Default/.config/powershell/Microsoft.PowerShell_profile.ps1

%post
/usr/lib/cowboy-banner/install.sh

%preun
# На удалении убираем строки из rc-файлов. На апгрейде - нет:
# /usr/lib/cowboy-banner/remove.sh ещё существует, но строки нужны.
if [ "$1" = "0" ]; then
    /usr/lib/cowboy-banner/remove.sh
fi

%postun
# На переустановке ставим строки заново - после апгрейда их могло не быть.
if [ "$1" -ge "1" ]; then
    /usr/lib/cowboy-banner/install.sh
fi

%changelog
* Mon Oct 19 2026 CIwi <200380906+egot51@users.noreply.github.com> - 1.0.0-1
- Initial release: ASCII-баннеры при старте терминала.
