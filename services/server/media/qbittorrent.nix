{ config, lib, pkgs, ... }:

let
  cfg = config.services.qbittorrent-server;
in {
  options.services.qbittorrent-server = {
    enable = lib.mkEnableOption "qBittorrent-nox torrent client";

    user = lib.mkOption {
      type = lib.types.str;
      default = "qbittorrent";
      description = "User account under which qBittorrent runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group for qBittorrent (should match media-common.group)";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data/qbittorrent";
      description = "Directory for qBittorrent config and state";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8090;
      description = "WebUI port for qBittorrent";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall port for qBittorrent WebUI";
    };

    mediaDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ "/storage/media/downloads" "/storage/media/movies" "/storage/media/tv" ];
      description = "Media directories qBittorrent needs write access to";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "qBittorrent should not run as root for security reasons";
      }
    ];

    # Create qbittorrent user
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ cfg.group ];
      home = cfg.dataDir;
      createHome = false;
      description = "qBittorrent-nox system user";
    };

    # qBittorrent-nox Custom systemd Service
    systemd.services.qbittorrent-nox = {
      description = "qBittorrent-nox torrent client";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --profile=${cfg.dataDir} --webui-port=${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = "0002"; # Creates files with group write permissions

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
        MemoryDenyWriteExecute = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
        RestrictSUIDSGID = true;

        # Allow write access to data and media directories
        ReadWritePaths = [ cfg.dataDir ] ++ cfg.mediaDirectories;

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
