{ config, lib, pkgs, ... }:

let
  cfg = config.services.hass-server;
in {
  options.services.hass-server = {
    enable = lib.mkEnableOption "Home Assistant home automation";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data/hass";
      description = "Directory for Home Assistant config and state";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "Port for Home Assistant web interface";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port for Home Assistant";
    };

    extraComponents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional Home Assistant components to include";
      example = [ "esphome" "cast" "google_translate" ];
    };

    extraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = ps: [];
      description = "Extra Python packages for Home Assistant";
      example = lib.literalExpression ''
        ps: with ps; [ psycopg2 ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      configDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;

      extraComponents = [
        # Common default components
        "default_config"
        "met"
        "radio_browser"
      ] ++ cfg.extraComponents;

      extraPackages = cfg.extraPackages;

      config = {
        homeassistant = {
          name = "Home";
          unit_system = "metric";
          time_zone = "UTC";
        };
        http = {
          server_port = cfg.port;
        };
        # Enable frontend
        frontend = {};
        # Enable mobile app
        mobile_app = {};
        # Enable automation
        automation = "!include automations.yaml";
        script = "!include scripts.yaml";
        scene = "!include scenes.yaml";
      };
    };

    # Create directory and default YAML files
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 hass hass -"
      "f ${cfg.dataDir}/automations.yaml 0640 hass hass - []"
      "f ${cfg.dataDir}/scripts.yaml 0640 hass hass - []"
      "f ${cfg.dataDir}/scenes.yaml 0640 hass hass - []"
    ];

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
