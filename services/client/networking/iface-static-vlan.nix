{ config, lib, ... }:

let
  cfg = config.net.iface.static-vlan;

  mkInterfaceConfig = name: ifcfg:
    let
      priority = 70;
    in
    {
      # VLAN netdev configuration
      netdevs."20-${name}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = name;
        };
        vlanConfig = {
          Id = ifcfg.vlanId;
        };
      };

      # Network configuration for the VLAN interface
      networks."${toString priority}-${name}" = {
        matchConfig.Name = name;

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

        linkConfig.RequiredForOnline = if ifcfg.requiredForOnline then "yes" else "no";
      };
    };

  allConfigs = lib.mapAttrsToList mkInterfaceConfig cfg;
  mergedNetdevs = lib.foldl' (acc: c: acc // c.netdevs) { } allConfigs;
  mergedNetworks = lib.foldl' (acc: c: acc // c.networks) { } allConfigs;
in
{
  options.net.iface.static-vlan = lib.mkOption {
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

        address = lib.mkOption {
          type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
          description = "Static IP address(es) with CIDR notation (e.g., 10.88.1.1/24)";
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
      };
    });
    default = { };
    description = "VLAN interfaces with static IP configuration";
  };

  config = lib.mkIf (config.networking.useNetworkd && cfg != { }) {
    systemd.network = {
      netdevs = mergedNetdevs;
      networks = mergedNetworks;
    };
  };
}
