{ config, lib, pkgs, ... }:

let
  cfg = config.services.sonarr-server;
in {
  options.services.sonarr-server = {
    enable = lib.mkEnableOption "Sonarr TV show manager";

    user = lib.mkOption {
      type = lib.types.str;
      default = "sonarr";
      description = "User account under which Sonarr runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group for Sonarr (should match media-common.group)";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data/sonarr";
      description = "Directory for Sonarr config and state";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8989;
      description = "Web interface port for Sonarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port for Sonarr (8989)";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "Sonarr should not run as root for security reasons";
      }
    ];

    # Create sonarr user
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ cfg.group ];
      home = cfg.dataDir;
      createHome = false;
      description = "Sonarr system user";
    };

    # Sonarr TV Show Manager Configuration
    services.sonarr = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      dataDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;
    };

    # Security hardening
    systemd.services.sonarr.serviceConfig = {
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

    # Create directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
