# Jellyseerr Media Request Interface Module
#
# Custom implementation with static user for reliable persistent storage.
# Follows the same pattern as qBittorrent, Sonarr, Radarr, and Jellyfin.
#
# Data is stored directly at dataDir (default: /storage/data/jellyseerr) with
# consistent file ownership that survives reboots and VM recreation.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.jellyseerr-server;
in {
  options.services.jellyseerr-server = {
    enable = lib.mkEnableOption "Jellyseerr media request interface";

    user = lib.mkOption {
      type = lib.types.str;
      default = "jellyseerr";
      description = "User account under which Jellyseerr runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group for Jellyseerr (should match media-common.group)";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data/jellyseerr";
      description = "Directory for Jellyseerr config and state";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
      description = "Web interface port for Jellyseerr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port for Jellyseerr";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "Jellyseerr should not run as root for security reasons";
      }
    ];

    # Create jellyseerr user
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ cfg.group ];
      home = cfg.dataDir;
      createHome = false;
      description = "Jellyseerr media request interface";
    };

    # Jellyseerr systemd service
    systemd.services.jellyseerr = {
      description = "Jellyseerr Media Request Interface";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        PORT = toString cfg.port;
        CONFIG_DIRECTORY = cfg.dataDir;
      };

      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pkgs.jellyseerr}/bin/jellyseerr";
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = "0002";

        # Security hardening
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelLogs = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateMounts = true;
        PrivateDevices = true;

        # Allow write access to config directory
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    # Create directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
