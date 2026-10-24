# System module, shared by the NixOS and nix-darwin outputs (both expose
# `environment.systemPackages` and `environment.etc`). Installs the prebuilt
# package system-wide. When parcels are given, it also writes
# /etc/kozutsumi/kozutsumi.yml and installs a thin wrapper so the system-wide
# `kozutsumi` defaults to that config. A user's own `--config` still overrides it.
#
# For per-user config prefer the home-manager module instead.
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
  configPath = "/etc/kozutsumi/kozutsumi.yml";

  # Wrap the binary so it defaults to the system config. --add-flags prepends the
  # flag, so an explicit `--config` passed by the user comes later and wins.
  wrapped = pkgs.symlinkJoin {
    name = "kozutsumi-wrapped";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/kozutsumi --add-flags "--config ${configPath}"
    '';
  };
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
        }
      '';
      description = ''
        Parcels to generate the system-wide kozutsumi config from. Each parcel
        maps a name to a list of entries: bare app names, `~/` or `/` paths,
        URLs, or `sh:` shell commands. When set, /etc/kozutsumi/kozutsumi.yml is
        written and the system `kozutsumi` defaults to it.
      '';
    };

    settings = lib.mkOption {
      type = yamlFormat.type;
      default = { };
      description = ''
        Extra settings merged on top of {option}`parcels` and written verbatim to
        the config file. Keys here override parcels of the same name.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ (if hasConfig then wrapped else cfg.package) ];

    environment.etc = lib.mkIf hasConfig {
      "kozutsumi/kozutsumi.yml".source = yamlFormat.generate "kozutsumi.yml" (cfg.parcels // cfg.settings);
    };
  };
}
