{ config, lib, ... }:

let
  cfg = config.net.iface.dhcp-vlan;

  mkInterfaceConfig = name: ifcfg:
    let
      priority = 60;
    in
    {
      # VLAN netdev configuration
      netdevs."20-${name}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = name;
        };
        vlanConfig.Id = ifcfg.vlanId;
      };

      # Network configuration for the VLAN interface
      networks."${toString priority}-${name}" = {
        matchConfig.Name = name;

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

        linkConfig.RequiredForOnline = if ifcfg.requiredForOnline then "yes" else "no";
      };
    };

  allConfigs = lib.mapAttrsToList mkInterfaceConfig cfg;
  mergedNetdevs = lib.foldl' (acc: c: acc // c.netdevs) { } allConfigs;
  mergedNetworks = lib.foldl' (acc: c: acc // c.networks) { } allConfigs;
in
{
  options.net.iface.dhcp-vlan = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        parent = lib.mkOption {
          type = lib.types.str;
          description = "Parent interface name (trunk interface)";
        };

        vlanId = lib.mkOption {
          type = lib.types.ints.between 1 4094;
          description = "VLAN ID (1-4094)";
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
      };
    });
    default = { };
    description = "VLAN interfaces configured via DHCP";
  };

  config = lib.mkIf (config.networking.useNetworkd && cfg != { }) {
    systemd.network = {
      netdevs = mergedNetdevs;
      networks = mergedNetworks;
    };
  };
}
