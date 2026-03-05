# Prowlarr Indexer Manager Module
#
# Custom implementation with static user for reliable persistent storage.
# Follows the same pattern as qBittorrent, Sonarr, Radarr, and Jellyfin.
#
# Data is stored directly at dataDir (default: /storage/data/prowlarr) with
# consistent file ownership that survives reboots and VM recreation.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.prowlarr-server;
in {
  options.services.prowlarr-server = {
    enable = lib.mkEnableOption "Prowlarr indexer manager";

    user = lib.mkOption {
      type = lib.types.str;
      default = "prowlarr";
      description = "User account under which Prowlarr runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group for Prowlarr (should match media-common.group)";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data/prowlarr";
      description = "Directory for Prowlarr config and state";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9696;
      description = "Web interface port for Prowlarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port for Prowlarr (9696)";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "Prowlarr should not run as root for security reasons";
      }
    ];

    # Create prowlarr user
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ cfg.group ];
      home = cfg.dataDir;
      createHome = false;
      description = "Prowlarr indexer manager";
    };

    # Prowlarr systemd service
    systemd.services.prowlarr = {
      description = "Prowlarr Indexer Manager";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pkgs.prowlarr}/bin/Prowlarr -nobrowser -data=${cfg.dataDir}";
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
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
        RestrictSUIDSGID = true;

        # Allow write access to data directory
        ReadWritePaths = [ cfg.dataDir ];

        # Capabilities
        CapabilityBoundingSet = "";
        SystemCallFilter = [ "@system-service" "~@privileged" ];
        SystemCallErrorNumber = "EPERM";
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
