{ config, lib, pkgs, ... }:

let
  cfg = config.services.jellyfin-server;
in {
  options.services.jellyfin-server = {
    enable = lib.mkEnableOption "Jellyfin media server";

    user = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin";
      description = "User account under which Jellyfin runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group for Jellyfin (should match media-common.group)";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data/jellyfin";
      description = "Directory for Jellyfin config and state";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8096;
      description = "Web interface port for Jellyfin";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports for Jellyfin";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "Jellyfin should not run as root for security reasons";
      }
    ];

    # Create jellyfin user
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ cfg.group ];
      home = cfg.dataDir;
      createHome = false;
      description = "Jellyfin system user";
    };

    # Jellyfin Media Server Configuration
    services.jellyfin = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      dataDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;
    };

    # Override Jellyfin to keep cache and log under dataDir
    systemd.services.jellyfin = {
      environment = {
        JELLYFIN_DATA_DIR = cfg.dataDir;
        JELLYFIN_CONFIG_DIR = "${cfg.dataDir}/config";
        JELLYFIN_LOG_DIR = "${cfg.dataDir}/log";
        JELLYFIN_CACHE_DIR = "${cfg.dataDir}/cache";
      };

      serviceConfig = {
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

    # Create directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/config 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/cache 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/log 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Firewall rules
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port 8920 ];
      allowedUDPPorts = [ 1900 7359 ];
    };
  };
}
