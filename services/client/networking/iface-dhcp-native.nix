{ config, lib, ... }:

let
  cfg = config.net.iface.dhcp-native;

  mkInterfaceConfig = name: ifcfg:
    let
      # Interface name for network matching:
      # 1. If renaming, use the renamed name
      # 2. Else if matchName is set, use that (for tests without renaming)
      # 3. Else use the attrset key
      netName = if ifcfg.rename != null then ifcfg.rename
                else if ifcfg.matchName != null then ifcfg.matchName
                else name;
      priority = 30;
    in
    {
      # Link configuration (if renaming needed and we have a valid match method)
      links = lib.optionalAttrs (ifcfg.rename != null && (ifcfg.matchMac != null || ifcfg.matchName != null)) {
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

        networkConfig = {
          DHCP = "ipv4";
          IPv4Forwarding = if ifcfg.forwarding then "yes" else "no";
          IPv6Forwarding = "no";
          IPv6AcceptRA = false;
        } // lib.optionalAttrs ifcfg.carrierTolerance {
          ConfigureWithoutCarrier = true;
          IgnoreCarrierLoss = true;
        };

        dhcpV4Config = {
          RouteMetric = ifcfg.routeMetric;
          UseDNS = ifcfg.useDns;
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
  options.net.iface.dhcp-native = lib.mkOption {
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

        routeMetric = lib.mkOption {
          type = lib.types.int;
          default = 100;
          description = "DHCP route metric";
        };

        useDns = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use DNS servers provided by DHCP";
        };

        wakeOnLan = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Wake-on-LAN";
        };
      };
    });
    default = { };
    description = "Native (non-VLAN) interfaces configured via DHCP";
  };

  config = lib.mkIf (config.networking.useNetworkd && cfg != { }) {
    systemd.network = {
      links = mergedLinks;
      networks = mergedNetworks;
    };
  };
}
