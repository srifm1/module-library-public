# FoundryVTT Server Module
# Wrapper around the private FoundryVTT flake providing consistent options
#
# This module wraps the upstream FoundryVTT module with our standard
# naming convention (services.foundryvtt-server) and adds openFirewall.
#
# The upstream module is imported via module-library/flake.nix from:
#   git+ssh://gitea@gitea.services.example.net/Apps/FoundryVTT.git
#
# Usage:
#   services.foundryvtt-server = {
#     enable = true;
#     dataDir = "/storage/data/foundryvtt";
#     openFirewall = true;
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.foundryvtt-server;
in {
  options.services.foundryvtt-server = {
    enable = lib.mkEnableOption "FoundryVTT virtual tabletop server";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data/foundryvtt";
      description = "Directory for FoundryVTT worlds, systems, and modules data";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 30000;
      description = "Port for FoundryVTT web interface";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open FoundryVTT port in the firewall";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Hostname/IP to bind to";
    };

    upnp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable UPnP port mapping";
    };

    proxySSL = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether running behind an SSL proxy";
    };

    proxyPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Port used by the SSL proxy (usually 443)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Pass configuration to upstream module from FoundryVTT flake
    services.foundryvtt = {
      enable = true;
      dataDir = cfg.dataDir;
      port = cfg.port;
      hostName = cfg.hostname;
      upnp = cfg.upnp;
      proxySSL = cfg.proxySSL;
      proxyPort = cfg.proxyPort;
    };

    # Open firewall (not provided by upstream module)
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
