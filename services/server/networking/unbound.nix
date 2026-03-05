# Unbound DNS Server Module
# Provides Unbound recursive DNS resolver with local zone support
#
# Usage:
#   services.unbound-server = {
#     enable = true;
#     interfaces = [ "127.0.0.1" "10.88.1.1" ];
#     accessControl = [
#       { subnet = "127.0.0.0/8"; action = "allow"; }
#       { subnet = "10.88.0.0/16"; action = "allow"; }
#     ];
#     localZones = [
#       { zone = "example.com."; type = "transparent"; }
#     ];
#     localData = [
#       ''"server1.example.com. A 10.88.1.10"''
#       ''"server2.example.com. A 10.88.1.11"''
#     ];
#     forwardZones = [
#       {
#         name = ".";
#         forwardAddrs = [
#           "1.1.1.1@853#cloudflare-dns.com"
#           "1.0.0.1@853#cloudflare-dns.com"
#         ];
#         forwardTlsUpstream = true;
#       }
#     ];
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.unbound-server;

  # Convert access control to "subnet action" format
  mkAccessControl = ac: "${ac.subnet} ${ac.action}";

  # Convert local zone to "zone type" format
  mkLocalZone = zone: ''"${zone.zone}" ${zone.type}'';

in
{
  options.services.unbound-server = {
    enable = lib.mkEnableOption "Unbound DNS resolver";

    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = "IP addresses to listen on for DNS queries";
      example = [ "127.0.0.1" "10.88.1.1" "10.88.2.1" ];
    };

    accessControl = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          subnet = lib.mkOption {
            type = lib.types.str;
            description = "Subnet in CIDR notation";
            example = "10.88.0.0/16";
          };

          action = lib.mkOption {
            type = lib.types.enum [ "allow" "deny" "refuse" "allow_snoop" ];
            default = "allow";
            description = "Action to take for queries from this subnet";
          };
        };
      });
      default = [
        { subnet = "127.0.0.0/8"; action = "allow"; }
      ];
      description = "Access control list for DNS queries";
    };

    localZones = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          zone = lib.mkOption {
            type = lib.types.str;
            description = "DNS zone name (must end with .)";
            example = "example.com.";
          };

          type = lib.mkOption {
            type = lib.types.enum [ "static" "transparent" "redirect" "refuse" "nodefault" ];
            default = "transparent";
            description = "Zone type - how Unbound handles this zone";
          };
        };
      });
      default = [ ];
      description = "Local DNS zones to serve";
    };

    localData = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Local DNS records in zone file format";
      example = [
        ''"server.example.com. A 10.88.1.10"''
        ''"10.1.10.88.in-addr.arpa. PTR server.example.com."''
      ];
    };

    forwardZones = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Zone name to forward (use . for all)";
            example = ".";
          };

          forwardAddrs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Upstream DNS servers to forward to";
            example = [ "8.8.8.8" "8.8.4.4" ];
          };

          forwardTlsUpstream = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Use DNS-over-TLS for upstream queries";
          };
        };
      });
      default = [ ];
      description = "Zones to forward to upstream DNS servers";
    };

    enableIPv6 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable IPv6 support";
    };

    cacheMinTtl = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Minimum TTL for cached entries (seconds)";
    };

    cacheMaxTtl = lib.mkOption {
      type = lib.types.int;
      default = 86400;
      description = "Maximum TTL for cached entries (seconds)";
    };

    prefetch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prefetch popular entries before they expire";
    };

    numThreads = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Number of threads to use";
    };

    msgCacheSize = lib.mkOption {
      type = lib.types.str;
      default = "50m";
      description = "Size of message cache";
    };

    rrsetCacheSize = lib.mkOption {
      type = lib.types.str;
      default = "100m";
      description = "Size of RRset cache";
    };

    hideIdentity = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Hide server identity in responses";
    };

    hideVersion = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Hide server version in responses";
    };

    hardenGlue = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Harden against out-of-zone glue records";
    };

    hardenDnssecStripped = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Harden against DNSSEC stripping";
    };

    useCapsForId = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use 0x20-encoded random bits for query IDs";
    };

    enableRemoteControl = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable remote control for stats and management";
    };

    remoteControlInterface = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Interface for remote control";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically open firewall ports for DNS";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Unbound configuration options";
    };
  };

  config = lib.mkIf cfg.enable {
    services.unbound = {
      enable = true;
      settings = lib.mkMerge [
        {
          server = {
            # Listen interfaces
            interface = cfg.interfaces;

            # Access control
            access-control = map mkAccessControl cfg.accessControl;

            # Protocol settings
            do-ip4 = true;
            do-ip6 = cfg.enableIPv6;
            do-udp = true;
            do-tcp = true;

            # Security hardening
            hide-identity = cfg.hideIdentity;
            hide-version = cfg.hideVersion;
            harden-glue = cfg.hardenGlue;
            harden-dnssec-stripped = cfg.hardenDnssecStripped;
            use-caps-for-id = cfg.useCapsForId;

            # Performance tuning
            cache-min-ttl = cfg.cacheMinTtl;
            cache-max-ttl = cfg.cacheMaxTtl;
            prefetch = cfg.prefetch;
            num-threads = cfg.numThreads;
            msg-cache-size = cfg.msgCacheSize;
            rrset-cache-size = cfg.rrsetCacheSize;

            # Local zones
            local-zone = map mkLocalZone cfg.localZones;

            # Local data
            local-data = cfg.localData;
          };

          # Remote control
          remote-control = lib.mkIf cfg.enableRemoteControl {
            control-enable = true;
            control-interface = cfg.remoteControlInterface;
          };

          # Forward zones
          forward-zone = map (fz: {
            name = fz.name;
            forward-addr = fz.forwardAddrs;
            forward-tls-upstream = fz.forwardTlsUpstream;
          }) cfg.forwardZones;
        }
        cfg.extraConfig
      ];
    };

    # Open firewall for DNS if requested
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    # Ensure unbound starts after network is ready and auto-restarts on failure
    systemd.services.unbound = {
      after = [ "systemd-networkd.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5s";
      };
      # Handle crash recovery: validate key files and remove if invalid
      # so unbound-control-setup can regenerate them fresh
      preStart = lib.mkBefore ''
        if [ -d "/var/lib/unbound" ]; then
          for keyfile in unbound_server.key unbound_server.pem unbound_control.key unbound_control.pem; do
            keypath="/var/lib/unbound/$keyfile"
            if [ -f "$keypath" ]; then
              # Remove if file is empty or unreadable (corrupt after crash)
              if ! [ -s "$keypath" ] || ! [ -r "$keypath" ]; then
                echo "Removing invalid $keyfile for regeneration"
                rm -f "$keypath"
              # For key files, verify they contain valid PEM data
              elif [ "''${keyfile##*.}" = "key" ] || [ "''${keyfile##*.}" = "pem" ]; then
                if ! grep -q "BEGIN" "$keypath" 2>/dev/null; then
                  echo "Removing corrupt $keyfile (invalid PEM) for regeneration"
                  rm -f "$keypath"
                fi
              fi
            fi
          done
        fi
      '';
    };
  };
}
