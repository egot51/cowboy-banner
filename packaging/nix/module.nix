# Модуль для home-manager: включает баннер в профиле оболочки.
#
#   programs.cowboyBanner.enable = true;
#   programs.cowboyBanner.theme = "ocean";
#
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.cowboyBanner;
in
{
  options.programs.cowboyBanner = {
    enable = lib.mkEnableOption "ASCII-баннер при старте терминала";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "wildwest";
      example = "ocean";
      description = "Тема баннера: wildwest, space, cyber, ocean, any";
    };

    banner = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Значение COWBOY_BANNER: пусто - рисовать, menu - меню тем, none - молчать";
    };

    hint = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Показывать подсказку и метку темы под картинкой";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.cowboy-banner ];

    programs.bash.initExtra = ''
      export COWBOY_THEME="${cfg.theme}"
      ${lib.optionalString (cfg.banner != "") "export COWBOY_BANNER=\"${cfg.banner}\""}
      ${lib.optionalString cfg.hint "export COWBOY_HINT=on"}
      [ -x ${pkgs.cowboy-banner}/bin/cowboy-banner ] && ${pkgs.cowboy-banner}/bin/cowboy-banner
    '';

    programs.zsh.initExtra = ''
      export COWBOY_THEME="${cfg.theme}"
      ${lib.optionalString (cfg.banner != "") "export COWBOY_BANNER=\"${cfg.banner}\""}
      ${lib.optionalString cfg.hint "export COWBOY_HINT=on"}
      [ -x ${pkgs.cowboy-banner}/bin/cowboy-banner ] && ${pkgs.cowboy-banner}/bin/cowboy-banner
    '';
  };
}
