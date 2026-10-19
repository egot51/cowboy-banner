{
  description = "Цветной ASCII-баннер при старте терминала: случайная картинка внутри случайной темы, приветствие по времени суток и случайная поговорка. Темы: Дикий Запад, космос, киберпанк, океан. Работает в bash, zsh и PowerShell 7.";

  homepage = "https://github.com/egot51/cowboy-banner";

  license = "MIT";

  maintainers = [
    "egot51"
  ];

  # Пакет собирается из общего дерева files/ - того же, что и для deb, rpm и AUR.
  outputs = [
    {
      name = "cowboy-banner";
      version = "1.0.0";
      src = ./linux/files;

      # Файлы раскладываются в store как есть, но путь /usr внутри пакета
      # для nix не имеет смысла - поэтому переносим в $out.
      installPhase = ''
        mkdir -p $out
        cp -a usr $out/
        cp -a etc $out/
        # Хуки установки в nix не нужны: пакет не трогает rc-файлы сам.
        rm -rf $out/usr/lib
        ln -s $out/usr/bin/cowboy-banner $out/bin/cowboy-banner
      '';

      # nix ставит пакет неизменяемым, поэтому подсказки про COWBOY_THEME
      # и прочие переменные вынесены в meta.
      meta = {
        description = ''
          Чтобы включить баннер, добавьте в профиль shell:
            export COWBOY_THEME=wildwest
          Меню тем: COWBOY_BANNER=menu cowboy-banner
          Выключить: COWBOY_BANNER=none
        '';
      };
    }
  ];

  # Модуль для home-manager: включается одной строкой в конфиге.
  homeManagerModules = import ./packaging/nix/module.nix;
}
