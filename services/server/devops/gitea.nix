{ config, lib, pkgs, ... }:

let
  cfg = config.services.gitea-server;
in {
  options.services.gitea-server = {
    enable = lib.mkEnableOption "Gitea git forge";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/gitea";
      description = "Directory for Gitea data";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Domain name for Gitea";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "HTTP port for Gitea web interface";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "SSH port for Gitea git operations";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports for Gitea";
    };

    useHTTPS = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use HTTPS in ROOT_URL (set true if behind HTTPS reverse proxy)";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "gitea";
      description = "User account under which Gitea runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "gitea";
      description = "Group under which Gitea runs";
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [ "sqlite3" "postgres" "mysql" ];
        default = "sqlite3";
        description = "Database type to use";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Database host (for postgres/mysql)";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "gitea";
        description = "Database name";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "gitea";
        description = "Database user";
      };
    };

    lfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Git LFS support";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "Gitea should not run as root for security reasons";
      }
    ];

    services.gitea = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      stateDir = cfg.dataDir;
      lfs.enable = cfg.lfs.enable;

      database = {
        type = cfg.database.type;
        host = cfg.database.host;
        name = cfg.database.name;
        user = cfg.database.user;
        path = "${cfg.dataDir}/data/gitea.db";
      };

      settings = {
        server = {
          DOMAIN = cfg.domain;
          HTTP_PORT = cfg.httpPort;
          SSH_PORT = cfg.sshPort;
          ROOT_URL = "${if cfg.useHTTPS then "https" else "http"}://${cfg.domain}/";
        };
        session = {
          COOKIE_SECURE = cfg.useHTTPS;
        };
        service = {
          DISABLE_REGISTRATION = true; # Secure by default
        };
      };
    };

    # Firewall
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.httpPort cfg.sshPort ];
    };

    # Create directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Ensure Gitea waits for its data directory to be mounted
    # This prevents race conditions with virtiofs or network mounts
    systemd.services.gitea = {
      unitConfig.RequiresMountsFor = cfg.dataDir;
    };
  };
}
