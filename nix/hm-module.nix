# home-manager module. Works under both NixOS and nix-darwin's home-manager
# integration, so it is the recommended way to configure kozutsumi per user.
#
#   programs.kozutsumi = {
#     enable = true;
#     parcels.work = [ "Slack" "~/work" "https://github.com" ];
#   };
#
# generates ~/.config/kozutsumi/kozutsumi.yml, which is where kozutsumi looks by
# default, and installs the prebuilt package into the user profile.
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.kozutsumi;
  yamlFormat = pkgs.formats.yaml { };
  hasConfig = cfg.parcels != { } || cfg.settings != { };
in
{
  options.programs.kozutsumi = {
    enable = lib.mkEnableOption "kozutsumi, a launcher for groups of apps, files, folders and URLs";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "kozutsumi.packages.\${system}.default";
      description = "The kozutsumi package to use. Defaults to the prebuilt binary from this flake.";
    };

    parcels = lib.mkOption {
      type = with lib.types; attrsOf (listOf str);
      default = { };
      example = lib.literalExpression ''
        {
          work = [ "Slack" "~/work" "https://github.com" ];
          notify = [ "sh:osascript -e 'display notification \"done\"'" ];
        }
      '';
      description = ''
        Parcels to generate the kozutsumi config from. Each parcel maps a name to
        a list of entries: bare app names, `~/` or `/` paths, URLs, or `sh:` shell
        commands.
      '';
    };

    settings = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = ''
        Extra settings merged on top of {option}`parcels` and written verbatim to
        the config file, for anything not expressible through {option}`parcels`.
        Keys here override parcels of the same name.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."kozutsumi/kozutsumi.yml" = lib.mkIf hasConfig {
      source = yamlFormat.generate "kozutsumi.yml" (cfg.parcels // cfg.settings);
    };
  };
}
