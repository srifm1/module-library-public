# FoundryVTT REST API Relay Module
# Wrapper around the foundryvtt-rest-api flake providing consistent options
#
# This module wraps the upstream foundryvtt-rest-api-relay module with our
# standard naming convention (services.foundryvtt-relay-server).
#
# The upstream module is imported via module-library/flake.nix from:
#   git+ssh://gitea@git.services.example.net/Flakes/foundryvtt-rest-api.git
#
# Usage:
#   services.foundryvtt-relay-server = {
#     enable = true;
#     openFirewall = true;
#     settings = {
#       PORT = "3010";
#       DB_TYPE = "sqlite";
#     };
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.foundryvtt-relay-server;
in {
  options.services.foundryvtt-relay-server = {
    enable = lib.mkEnableOption "FoundryVTT REST API relay";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the relay port in the firewall";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3010;
      description = "Port for the relay to listen on";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional settings passed to the upstream relay module";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = "Environment files containing secrets for the relay service";
    };
  };

  config = lib.mkIf cfg.enable {
    services.foundryvtt-rest-api-relay = {
      enable = true;
      settings = { PORT = cfg.port; } // cfg.settings;
      environmentFiles = cfg.environmentFiles;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
