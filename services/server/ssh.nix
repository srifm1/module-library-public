{ config, lib, pkgs, ... }:

let
  cfg = config.services.ssh-server;

in {
  options.services.ssh-server = {
    enable = lib.mkEnableOption "OpenSSH server with security hardening";

    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = "SSH server port";
    };

    passwordAuthentication = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow password authentication (key-based auth is more secure)";
    };

    permitRootLogin = lib.mkOption {
      type = lib.types.enum [ "yes" "no" "prohibit-password" "forced-commands-only" ];
      default = "no";
      description = "Whether to allow root login";
    };

    x11Forwarding = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable X11 forwarding";
    };

    allowedUsers = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = "List of users allowed to log in via SSH (null means all users)";
      example = [ "andrew" ];
    };

    restrictToLAN = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Restrict SSH access to private network ranges only.
        This adds firewall rules to block SSH from non-private IPs.
      '';
    };

    privateNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];
      description = "List of private network ranges to allow when restrictToLAN is enabled";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open SSH port in the firewall";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra SSH server configuration";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      description = "Authorized SSH keys per user";
      example = lib.literalExpression ''
        {
          andrew = [
            "ssh-ed25519 AAAAC3Nz... user@host"
          ];
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Assertions to validate configuration
    assertions = [
      {
        assertion = cfg.port > 0 && cfg.port < 65536;
        message = "SSH port must be between 1 and 65535";
      }
      {
        assertion = !cfg.passwordAuthentication || cfg.permitRootLogin != "yes";
        message = "Allowing both password authentication and root login is a security risk";
      }
      {
        assertion = !cfg.restrictToLAN || cfg.privateNetworks != [];
        message = "restrictToLAN requires at least one private network to be configured";
      }
    ];

    # Enable OpenSSH server
    services.openssh = {
      enable = true;
      ports = [ cfg.port ];

      settings = {
        PasswordAuthentication = cfg.passwordAuthentication;
        PermitRootLogin = cfg.permitRootLogin;
        X11Forwarding = cfg.x11Forwarding;
        PermitEmptyPasswords = false;
      } // lib.optionalAttrs (cfg.allowedUsers != null) {
        AllowUsers = cfg.allowedUsers;
      };

      extraConfig = cfg.extraConfig;
    };

    # Configure authorized keys for users
    users.users = lib.mapAttrs (username: keys: {
      openssh.authorizedKeys.keys = keys;
    }) cfg.authorizedKeys;

    # Open firewall port if requested
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    # Configure nftables for LAN-only access if requested
    # NOTE: This uses nftables (not iptables) and requires networking.nftables.enable = true
    # when restrictToLAN is used. The rules are added to the nixos-fw table.
    networking.nftables.tables.ssh-restrict = lib.mkIf (cfg.openFirewall && cfg.restrictToLAN) {
      family = "inet";
      content = ''
        chain ssh-filter {
          type filter hook input priority filter + 1; policy accept;

          # Allow SSH from private networks
          ${lib.concatMapStringsSep "\n          " (net:
            "ip saddr ${net} tcp dport ${toString cfg.port} accept"
          ) cfg.privateNetworks}

          # Allow SSH from IPv6 private networks
          ip6 saddr fc00::/7 tcp dport ${toString cfg.port} accept
          ip6 saddr fe80::/10 tcp dport ${toString cfg.port} accept

          # Log and drop SSH from other sources
          tcp dport ${toString cfg.port} log prefix "[ssh-restrict] " drop
        }
      '';
    };

    # Enable nftables when restrictToLAN is used
    networking.nftables.enable = lib.mkIf cfg.restrictToLAN true;
  };
}
