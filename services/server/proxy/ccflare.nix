# ccflare Server Module
# Wrapper around the ccflare flake providing consistent options
#
# This module wraps the upstream ccflare module with our standard
# naming convention (services.ccflare-server).
#
# The upstream module is imported via module-library/flake.nix from:
#   git+ssh://gitea@git.services.example.net/Flakes/ccflare.git
#
# Usage:
#   services.ccflare-server = {
#     enable = true;
#     port = 18080;
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.ccflare-server;
in {
  options.services.ccflare-server = {
    enable = lib.mkEnableOption "ccflare Claude API load-balancing proxy";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open ccflare port in the firewall";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18080;
      description = "Port for ccflare to listen on";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional settings passed to the upstream ccflare module";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ccflare = {
      enable = true;
      openFirewall = cfg.openFirewall;
      settings = { port = cfg.port; } // cfg.settings;
    };
  };
}
