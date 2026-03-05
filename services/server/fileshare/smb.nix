{ config, lib, pkgs, ... }:

let
  cfg = config.services.smb-server;

in {
  options.services.smb-server = {
    enable = lib.mkEnableOption "Samba file server with configurable shares";

    workgroup = lib.mkOption {
      type = lib.types.str;
      default = "WORKGROUP";
      description = "Windows workgroup name";
    };

    serverString = lib.mkOption {
      type = lib.types.str;
      default = "Samba File Server";
      description = "Server description string visible to clients";
    };

    netbiosName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "NetBIOS name for this server";
    };

    shares = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.path;
            description = "Directory path to share";
            example = "/storage/data";
          };

          comment = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Description of the share";
            example = "Data Storage";
          };

          browseable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether the share is visible in network browsing";
          };

          readOnly = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the share is read-only";
          };

          guestOk = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow guest access without authentication";
          };

          validUsers = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "List of valid users or groups (e.g., '@users')";
            example = "@users";
          };

          createMask = lib.mkOption {
            type = lib.types.str;
            default = "0664";
            description = "Permissions mask for new files";
          };

          directoryMask = lib.mkOption {
            type = lib.types.str;
            default = "0775";
            description = "Permissions mask for new directories";
          };

          extraConfig = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Additional raw Samba configuration for this share";
          };
        };
      });
      default = {};
      description = "Samba share configurations";
      example = lib.literalExpression ''
        {
          data = {
            path = "/storage/data";
            comment = "Data Storage";
            browseable = true;
            readOnly = false;
            guestOk = false;
            validUsers = "@users";
          };
          media = {
            path = "/storage/media";
            comment = "Media Storage";
            browseable = true;
            readOnly = false;
            guestOk = true;
          };
        }
      '';
    };

    enablePerformanceTuning = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable performance tuning options";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Samba ports in the firewall";
    };

    extraGlobalConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional raw Samba global configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    # Assertions to validate configuration
    assertions = [
      {
        assertion = cfg.shares != {};
        message = "Samba server enabled but no shares configured. Add shares or disable the service.";
      }
      {
        assertion = cfg.netbiosName != "";
        message = "NetBIOS name cannot be empty";
      }
    ];

    # Enable Samba server
    services.samba = {
      enable = true;
      openFirewall = cfg.openFirewall;

      settings = {
        global = {
          workgroup = cfg.workgroup;
          "server string" = cfg.serverString;
          "netbios name" = cfg.netbiosName;

          # Security settings
          security = "user";
          "encrypt passwords" = "yes";
          "passdb backend" = "tdbsam";

          # Logging
          "log level" = 2;
          "log file" = "/var/log/samba/%m.log";
          "max log size" = 50;
        } // lib.optionalAttrs cfg.enablePerformanceTuning {
          # Performance tuning options
          "socket options" = "TCP_NODELAY SO_RCVBUF=65536 SO_SNDBUF=65536";
          "read raw" = "yes";
          "write raw" = "yes";
          oplocks = "yes";
          "max xmit" = 65535;
          "dead time" = 15;
          "getwd cache" = "yes";
        };
      } // lib.mapAttrs (name: share: {
        path = share.path;
        browseable = if share.browseable then "yes" else "no";
        "read only" = if share.readOnly then "yes" else "no";
        "guest ok" = if share.guestOk then "yes" else "no";
        "create mask" = share.createMask;
        "directory mask" = share.directoryMask;
        comment = share.comment;
      } // lib.optionalAttrs (share.validUsers != null) {
        "valid users" = share.validUsers;
      } // lib.optionalAttrs (share.extraConfig != "") {
        extraConfig = share.extraConfig;
      }) cfg.shares;
    };

    # Create shared directories using systemd-tmpfiles
    systemd.tmpfiles.rules = map (share:
      "d ${share.path} 0775 root root -"
    ) (lib.attrValues cfg.shares);

    # Note: After enabling this module, administrators should:
    # 1. Add users to samba: sudo smbpasswd -a username
    # 2. Ensure users exist in the system
    # 3. Configure appropriate file permissions on shared directories
  };
}
