# Kea DHCP Server Module
# Provides ISC Kea DHCP4 server with subnet and pool configuration
#
# Usage:
#   services.kea-server = {
#     enable = true;
#     interfaces = [ "eth1" "eth2" ];
#     subnets = [
#       {
#         subnet = "10.88.1.0/24";
#         pools = [ "10.88.1.100 - 10.88.1.200" ];
#         routers = [ "10.88.1.1" ];
#         dnsServers = [ "10.88.1.1" ];
#         domainName = "example.com";
#         interface = "eth1";
#       }
#     ];
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.kea-server;

  # Convert subnet configuration to Kea format
  mkSubnet = idx: subnet: {
    id = idx + 1;  # Kea requires numeric IDs starting from 1
    inherit (subnet) subnet interface;
    pools = map (pool: { inherit pool; }) subnet.pools;
    option-data = lib.optionals (subnet.routers != [ ]) [
      {
        name = "routers";
        data = lib.concatStringsSep ", " subnet.routers;
      }
    ] ++ lib.optionals (subnet.dnsServers != [ ]) [
      {
        name = "domain-name-servers";
        data = lib.concatStringsSep ", " subnet.dnsServers;
      }
    ] ++ lib.optionals (subnet.domainName != null) [
      {
        name = "domain-name";
        data = subnet.domainName;
      }
    ] ++ lib.optionals (subnet.domainSearch != [ ]) [
      {
        name = "domain-search";
        data = lib.concatStringsSep ", " subnet.domainSearch;
      }
    ] ++ lib.optionals (subnet.ntpServers != [ ]) [
      {
        name = "ntp-servers";
        data = lib.concatStringsSep ", " subnet.ntpServers;
      }
    ] ++ subnet.extraOptions;
  };

in
{
  options.services.kea-server = {
    enable = lib.mkEnableOption "Kea DHCP4 server";

    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of network interfaces to listen on for DHCP requests";
      example = [ "eth1" "vlan10" "vlan11" ];
    };

    subnets = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          subnet = lib.mkOption {
            type = lib.types.str;
            description = "Subnet in CIDR notation";
            example = "10.88.1.0/24";
          };

          pools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "DHCP address pools in 'start - end' format";
            example = [ "10.88.1.100 - 10.88.1.200" ];
          };

          interface = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Specific interface this subnet is associated with";
            example = "eth1";
          };

          routers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Default gateway(s) for this subnet";
            example = [ "10.88.1.1" ];
          };

          dnsServers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "DNS server(s) for this subnet";
            example = [ "10.88.1.1" "8.8.8.8" ];
          };

          domainName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Domain name for this subnet";
            example = "example.com";
          };

          domainSearch = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Domain search list for this subnet";
            example = [ "example.com" "internal.example.com" ];
          };

          ntpServers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "NTP server(s) for this subnet";
            example = [ "time.example.com" ];
          };

          extraOptions = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
            description = "Additional DHCP options in Kea format";
            example = [
              { name = "boot-file-name"; data = "pxelinux.0"; }
            ];
          };
        };
      });
      default = [ ];
      description = "DHCP subnet configurations";
    };

    validLifetime = lib.mkOption {
      type = lib.types.int;
      default = 7200;
      description = "Default lease time in seconds";
    };

    maxValidLifetime = lib.mkOption {
      type = lib.types.int;
      default = 86400;
      description = "Maximum lease time in seconds";
    };

    leaseFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/kea/dhcp4.leases";
      description = "Path to lease database file";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically open firewall ports for DHCP";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Kea configuration options";
    };
  };

  config = lib.mkIf cfg.enable {
    services.kea.dhcp4 = {
      enable = true;
      settings = lib.mkMerge [
        {
          # Interface configuration
          interfaces-config = {
            interfaces = cfg.interfaces;
          };

          # Lease database
          lease-database = {
            type = "memfile";
            persist = true;
            name = cfg.leaseFile;
          };

          # Lease times
          valid-lifetime = cfg.validLifetime;
          max-valid-lifetime = cfg.maxValidLifetime;

          # Subnet configurations
          subnet4 = lib.imap0 mkSubnet cfg.subnets;
        }
        cfg.extraConfig
      ];
    };

    # Open firewall for DHCP if requested
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [ 67 68 ];
    };
  };
}
