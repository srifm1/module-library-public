{ config, lib, pkgs, ... }:

let
  cfg = config.services.radarr-server;
in {
  options.services.radarr-server = {
    enable = lib.mkEnableOption "Radarr movie manager";

    user = lib.mkOption {
      type = lib.types.str;
      default = "radarr";
      description = "User account under which Radarr runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group for Radarr (should match media-common.group)";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data/radarr";
      description = "Directory for Radarr config and state";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7878;
      description = "Web interface port for Radarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port for Radarr (7878)";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "Radarr should not run as root for security reasons";
      }
    ];

    # Create radarr user
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ cfg.group ];
      home = cfg.dataDir;
      createHome = false;
      description = "Radarr system user";
    };

    # Radarr Movie Manager Configuration
    services.radarr = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      dataDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;
    };

    # Security hardening
    systemd.services.radarr.serviceConfig = {
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
