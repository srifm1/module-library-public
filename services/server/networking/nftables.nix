# nftables Firewall Module
# Provides zone-based firewall with NAT support
#
# Note: Zone names with hyphens are converted to underscores in set names.
# For example, zone "vpn-client" creates set "vpn_client_ifs".
#
# Usage:
#   services.nftables-firewall = {
#     enable = true;
#     zones = {
#       trusted = { interfaces = [ "vlan10" "vlan19" ]; };
#       client = { interfaces = [ "vlan11" "vlan13" ]; };
#       iot = { interfaces = [ "vlan12" "vlan14" ]; };
#       vpn-client = { interfaces = [ "wg-p2s" ]; };  # Creates @vpn_client_ifs
#     };
#     wanInterface = "wan";
#     inputRules = ''
#       # Allow SSH from trusted zone
#       iifname @trusted_ifs tcp dport 22 accept
#       # Allow DNS from VPN clients (note underscore in set name)
#       iifname @vpn_client_ifs tcp dport 53 accept
#     '';
#     forwardRules = ''
#       # Allow trusted zone to access anywhere
#       iifname @trusted_ifs accept
#     '';
#     natRules = ''
#       # Masquerade to WAN
#       oifname "wan" masquerade
#     '';
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.nftables-firewall;

  # Generate zone interface sets
  mkZoneSets = zones:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (name: zoneConfig:
      let
        # Normalize zone name: replace hyphens with underscores for nftables set names
        setName = lib.replaceStrings ["-"] ["_"] name;
        ifList = if zoneConfig.interfaces == [ ]
                 then ''"__placeholder_${setName}"''  # Empty sets cause syntax errors
                 else lib.concatMapStringsSep ", " (iface: ''"${iface}"'') zoneConfig.interfaces;
      in ''
        set ${setName}_ifs {
          type ifname
          elements = { ${ifList} }
        }
      ''
    ) zones);

  # Generate IP sets for zones
  mkIpSets = zones:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (name: zoneConfig:
      let
        # Normalize zone name: replace hyphens with underscores for nftables set names
        setName = lib.replaceStrings ["-"] ["_"] name;
      in
      lib.optionalString (zoneConfig.ipSets != [ ]) ''
        set ${setName}_ips {
          type ipv4_addr
          ${if zoneConfig.ipSets == [ ] then "" else "elements = { ${lib.concatStringsSep ", " zoneConfig.ipSets} }"}
        }
      ''
    ) zones);

  # Generate trusted devices MAC set
  mkTrustedDevicesSet = devices:
    if devices == [ ] then ""
    else ''
      set trusted_macs {
        type ether_addr
        elements = { ${lib.concatMapStringsSep ", " (d: d.mac) devices} }
      }
    '';

in
{
  options.services.nftables-firewall = {
    enable = lib.mkEnableOption "nftables firewall";

    zones = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          interfaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Network interfaces in this zone";
            example = [ "vlan10" "vlan19" ];
          };

          ipSets = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "IP addresses to add to this zone (optional)";
            example = [ "10.88.1.50" "10.88.1.51" ];
          };
        };
      });
      default = { };
      description = "Security zones with their interfaces and IP sets";
      example = {
        trusted = { interfaces = [ "vlan10" "vlan19" ]; };
        client = { interfaces = [ "vlan11" "vlan13" ]; };
      };
    };

    wanInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "WAN interface name for internet access";
      example = "wan";
    };

    inputPolicy = lib.mkOption {
      type = lib.types.enum [ "accept" "drop" "reject" ];
      default = "drop";
      description = "Default policy for input chain";
    };

    forwardPolicy = lib.mkOption {
      type = lib.types.enum [ "accept" "drop" "reject" ];
      default = "drop";
      description = "Default policy for forward chain";
    };

    outputPolicy = lib.mkOption {
      type = lib.types.enum [ "accept" "drop" "reject" ];
      default = "accept";
      description = "Default policy for output chain";
    };

    enableConntrack = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable connection tracking (established/related)";
    };

    allowLoopback = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow all traffic on loopback interface";
    };

    allowIcmp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow ICMP (ping) traffic";
    };

    icmpRateLimit = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "5/second";
      description = "Rate limit for ICMP on WAN (null to disable)";
    };

    inputRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Custom input chain rules (nftables syntax)";
      example = ''
        iifname @trusted_ifs tcp dport 22 accept
        iifname @client_ifs tcp dport 22 ct state new limit rate 10/minute accept
      '';
    };

    forwardRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Custom forward chain rules (nftables syntax)";
      example = ''
        iifname @trusted_ifs accept
        iifname @client_ifs oifname "wan" accept
      '';
    };

    outputRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Custom output chain rules (nftables syntax)";
    };

    enableNat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable NAT table for masquerading";
    };

    natRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Custom NAT rules (nftables syntax)";
      example = ''
        oifname "wan" ip saddr 10.88.0.0/16 masquerade
      '';
    };

    enableLogging = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable logging of dropped packets";
    };

    logPrefix = lib.mkOption {
      type = lib.types.str;
      default = "[nft-drop] ";
      description = "Prefix for firewall log messages";
    };

    logRateLimit = lib.mkOption {
      type = lib.types.str;
      default = "5/second";
      description = "Rate limit for firewall logging";
    };

    disableDefaultFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable NixOS default firewall when using nftables";
    };

    extraTableConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra configuration for the filter table";
    };

    trustedDevices = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          mac = lib.mkOption {
            type = lib.types.str;
            description = "MAC address of the trusted device";
            example = "aa:bb:cc:dd:ee:ff";
          };
          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Description of this device";
            example = "Andrew's laptop";
          };
        };
      });
      default = [ ];
      description = ''
        List of trusted devices by MAC address.
        These devices get infra-level access regardless of which interface/zone they're on.
        Useful for personal devices that may connect via WiFi (client zone) but need full access.
      '';
      example = [
        { mac = "aa:bb:cc:dd:ee:ff"; description = "Andrew's laptop"; }
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    warnings =
      let
        fw = config.networking.firewall;
        hasPorts = fw.allowedTCPPorts != [] || fw.allowedUDPPorts != [];
      in
      lib.optional (cfg.enable && hasPorts)
        "networking.firewall.allowedTCPPorts/allowedUDPPorts have no effect when services.nftables-firewall is active. Configure rules in services.nftables-firewall.inputRules instead.";

    # Disable default firewall if requested
    networking.firewall.enable = lib.mkIf cfg.disableDefaultFirewall (lib.mkForce false);

    networking.nftables = {
      enable = true;

      tables.filter = {
        family = "inet";
        content = ''
          # =============================================================
          # Zone Interface Sets
          # =============================================================
          ${mkZoneSets cfg.zones}

          # =============================================================
          # Zone IP Sets
          # =============================================================
          ${mkIpSets cfg.zones}

          # =============================================================
          # Trusted Devices MAC Set
          # =============================================================
          ${mkTrustedDevicesSet cfg.trustedDevices}

          # =============================================================
          # Input Chain - Traffic destined for this host
          # =============================================================
          chain input {
            type filter hook input priority 0; policy ${cfg.inputPolicy};

            ${lib.optionalString cfg.enableConntrack ''
            # Connection tracking
            ct state established,related accept
            ct state invalid drop
            ''}

            ${lib.optionalString cfg.allowLoopback ''
            # Loopback
            iif lo accept
            ''}

            ${lib.optionalString cfg.allowIcmp (
              if cfg.wanInterface != null && cfg.icmpRateLimit != null then ''
              # ICMP - rate limited on WAN, unrestricted internal
              iifname "${cfg.wanInterface}" icmp type echo-request limit rate ${cfg.icmpRateLimit} accept
              iifname != "${cfg.wanInterface}" ip protocol icmp accept
              '' else ''
              # ICMP
              ip protocol icmp accept
              ''
            )}

            ${lib.optionalString (cfg.trustedDevices != [ ]) ''
            # Trusted devices - full access regardless of interface
            ether saddr @trusted_macs accept
            ''}

            # Custom input rules
            ${cfg.inputRules}

            ${lib.optionalString cfg.enableLogging ''
            # Log dropped packets
            limit rate ${cfg.logRateLimit} log prefix "${cfg.logPrefix}input] "
            ''}
          }

          # =============================================================
          # Forward Chain - Traffic passing through this host
          # =============================================================
          chain forward {
            type filter hook forward priority 0; policy ${cfg.forwardPolicy};

            ${lib.optionalString cfg.enableConntrack ''
            # Connection tracking
            ct state established,related accept
            ct state invalid drop
            ''}

            ${lib.optionalString (cfg.trustedDevices != [ ]) ''
            # Trusted devices - full access regardless of interface
            ether saddr @trusted_macs accept
            ''}

            # Custom forward rules
            ${cfg.forwardRules}

            ${lib.optionalString cfg.enableLogging ''
            # Log dropped packets
            limit rate ${cfg.logRateLimit} log prefix "${cfg.logPrefix}forward] "
            ''}
          }

          # =============================================================
          # Output Chain - Traffic originating from this host
          # =============================================================
          chain output {
            type filter hook output priority 0; policy ${cfg.outputPolicy};

            # Custom output rules
            ${cfg.outputRules}
          }

          # Extra table configuration
          ${cfg.extraTableConfig}
        '';
      };

      # NAT table for masquerading
      tables.nat = lib.mkIf cfg.enableNat {
        family = "ip";
        content = ''
          chain postrouting {
            type nat hook postrouting priority srcnat;

            # Custom NAT rules
            ${cfg.natRules}
          }
        '';
      };
    };
  };
}
