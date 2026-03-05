{ config, lib, ... }:

let
  cfg = config.net.iface.trunk;

  # Safely access optional VLAN configs (modules may not be imported)
  dhcpVlanCfg = if config.net.iface ? dhcp-vlan then config.net.iface.dhcp-vlan else {};
  staticVlanCfg = if config.net.iface ? static-vlan then config.net.iface.static-vlan else {};

  # Collect all VLANs that reference each trunk interface
  discoverVlans = trunkName:
    let
      dhcpVlans = lib.mapAttrsToList
        (name: vcfg: vcfg.parent)
        (lib.filterAttrs (name: vcfg: vcfg.parent == trunkName) dhcpVlanCfg);
      staticVlans = lib.mapAttrsToList
        (name: vcfg: vcfg.parent)
        (lib.filterAttrs (name: vcfg: vcfg.parent == trunkName) staticVlanCfg);
    in
    lib.unique (dhcpVlans ++ staticVlans);

  mkInterfaceConfig = name: ifcfg:
    let
      # Interface name for network matching:
      # 1. If renaming, use the renamed name
      # 2. Else if matchName is set, use that (for tests without renaming)
      # 3. Else use the attrset key
      netName = if ifcfg.rename != null then ifcfg.rename
                else if ifcfg.matchName != null then ifcfg.matchName
                else name;
      priority = 50;

      # Get VLAN interface names that use this trunk
      vlanNames = let
        dhcpVlanNames = lib.mapAttrsToList
          (vname: vcfg: vname)
          (lib.filterAttrs (vname: vcfg: vcfg.parent == netName) dhcpVlanCfg);
        staticVlanNames = lib.mapAttrsToList
          (vname: vcfg: vname)
          (lib.filterAttrs (vname: vcfg: vcfg.parent == netName) staticVlanCfg);
      in
      lib.unique (dhcpVlanNames ++ staticVlanNames);
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
        matchConfig = {
          Name = netName;
          Type = "ether";
        };

        # Auto-wire VLANs
        networkConfig = {
          VLAN = vlanNames;
          LinkLocalAddressing = "no";
          IPv4Forwarding = if ifcfg.forwarding then "yes" else "no";
        } // lib.optionalAttrs ifcfg.carrierTolerance {
          ConfigureWithoutCarrier = true;
          IgnoreCarrierLoss = true;
        };

        linkConfig.RequiredForOnline = if ifcfg.requiredForOnline then "yes" else "no";
      };
    };

  allConfigs = lib.mapAttrsToList mkInterfaceConfig cfg;
  mergedLinks = lib.foldl' (acc: c: acc // c.links) { } allConfigs;
  mergedNetworks = lib.foldl' (acc: c: acc // c.networks) { } allConfigs;
in
{
  options.net.iface.trunk = lib.mkOption {
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
          default = false;
          description = "Whether this interface is required for network-online.target";
        };

        forwarding = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable IPv4 forwarding on this interface";
        };
      };
    });
    default = { };
    description = "Trunk interfaces for carrying multiple VLANs (auto-wires VLANs)";
  };

  config = lib.mkIf (config.networking.useNetworkd && cfg != { }) {
    systemd.network = {
      links = mergedLinks;
      networks = mergedNetworks;
    };
  };
}
