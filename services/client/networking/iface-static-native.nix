{ config, lib, ... }:

let
  cfg = config.net.iface.static-native;

  mkInterfaceConfig = name: ifcfg:
    let
      netName = if ifcfg.rename != null then ifcfg.rename else name;
      priority = 40;
    in
    {
      # Link configuration (if renaming needed)
      links = lib.optionalAttrs (ifcfg.rename != null) {
        "10-${name}" = {
          matchConfig = if ifcfg.matchMac != null
            then { PermanentMACAddress = ifcfg.matchMac; }
            else { Name = ifcfg.matchName; };
          linkConfig.Name = ifcfg.rename;
        };
      };

      # Network configuration
      networks."${toString priority}-${netName}" = {
        matchConfig.Name = netName;

        address = if builtins.isList ifcfg.address then ifcfg.address else [ ifcfg.address ];

        routes = lib.optionals (ifcfg.gateway != null) [
          { Gateway = ifcfg.gateway; }
        ];

        networkConfig = {
          DNS = ifcfg.dns;
          IPv4Forwarding = if ifcfg.forwarding then "yes" else "no";
          IPv6Forwarding = "no";
        } // lib.optionalAttrs ifcfg.carrierTolerance {
          ConfigureWithoutCarrier = true;
          IgnoreCarrierLoss = true;
        };

        linkConfig = {
          RequiredForOnline = if ifcfg.requiredForOnline then "yes" else "no";
        } // lib.optionalAttrs ifcfg.wakeOnLan {
          WakeOnLan = "magic";
        };
      };
    };

  allConfigs = lib.mapAttrsToList mkInterfaceConfig cfg;
  mergedLinks = lib.foldl' (acc: c: acc // c.links) { } allConfigs;
  mergedNetworks = lib.foldl' (acc: c: acc // c.networks) { } allConfigs;
in
{
  options.net.iface.static-native = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        matchName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Match interface by name";
        };

        matchMac = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Match interface by MAC address";
        };

        rename = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Rename interface to this name";
        };

        carrierTolerance = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable ConfigureWithoutCarrier and IgnoreCarrierLoss";
        };

        requiredForOnline = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether this interface is required for network-online.target";
        };

        forwarding = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable IPv4 forwarding on this interface";
        };

        address = lib.mkOption {
          type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
          description = "Static IP address(es) with CIDR notation";
          example = [ "10.88.20.10/24" "10.88.20.11/24" ];
        };

        gateway = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default gateway IP address";
        };

        dns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "DNS server IP addresses";
        };

        wakeOnLan = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Wake-on-LAN";
        };
      };
    });
    default = { };
    description = "Native (non-VLAN) interfaces with static IP configuration";
  };

  config = lib.mkIf (config.networking.useNetworkd && cfg != { }) {
    systemd.network = {
      links = mergedLinks;
      networks = mergedNetworks;
    };
  };
}
