# WireGuard VPN Server Module
# Provides WireGuard VPN server with support for multiple interfaces (P2S, S2S)
# Self-contained: directly configures systemd-networkd without relying on
# NixOS's networking.wireguard module.
#
# Usage:
#   services.wireguard-server = {
#     enable = true;
#     interfaces = {
#       wg-p2s = {
#         ips = [ "10.77.100.1/24" ];
#         listenPort = 51820;
#         privateKeyFile = "/root/wireguard-keys/wg-p2s-private";
#         peers = [
#           {
#             publicKey = "CLIENT_PUBLIC_KEY";
#             allowedIPs = [ "10.77.100.10/32" ];
#           }
#         ];
#         enableForwarding = true;
#         disableRpFilter = true;
#       };
#       wg-s2s = {
#         ips = [ "10.77.200.1/30" ];
#         listenPort = 51821;
#         privateKeyFile = "/root/wireguard-keys/wg-s2s-private";
#         peers = [
#           {
#             publicKey = "REMOTE_SITE_PUBLIC_KEY";
#             endpoint = "remote.example.com:51821";
#             allowedIPs = [ "10.77.200.2/32" "10.77.50.0/24" ];
#             persistentKeepalive = 25;
#           }
#         ];
#         enableForwarding = true;
#       };
#     };
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.wireguard-server;

  # Generate credential name for systemd
  credentialName = name: "wireguard-${name}-private-key";

  # Generate netdev for a WireGuard interface
  mkNetdev = name: ifaceConfig: {
    netdevConfig = {
      Kind = "wireguard";
      Name = name;
    } // lib.optionalAttrs (ifaceConfig.mtu != null) {
      MTUBytes = toString ifaceConfig.mtu;
    };
    wireguardConfig = {
      PrivateKey = "@${credentialName name}";
    } // lib.optionalAttrs (ifaceConfig.listenPort != null) {
      ListenPort = ifaceConfig.listenPort;
    };
    wireguardPeers = map (peer: {
      PublicKey = peer.publicKey;
      AllowedIPs = peer.allowedIPs;
    } // lib.optionalAttrs (peer.endpoint != null) {
      Endpoint = peer.endpoint;
    } // lib.optionalAttrs (peer.persistentKeepalive != null) {
      PersistentKeepalive = peer.persistentKeepalive;
    } // lib.optionalAttrs (peer.presharedKeyFile != null) {
      PresharedKey = "@wireguard-${name}-${peer.publicKey}-psk";
    }) ifaceConfig.peers;
  };

  # Generate network config for a WireGuard interface
  mkNetwork = name: ifaceConfig: {
    matchConfig.Name = name;
    address = ifaceConfig.ips;
    networkConfig = {
      ConfigureWithoutCarrier = true;
    } // lib.optionalAttrs ifaceConfig.enableForwarding {
      IPv4Forwarding = "yes";
    };
  };

  # Generate LoadCredential entries for all interfaces
  mkCredentials = lib.flatten (lib.mapAttrsToList (name: ifaceConfig:
    [ "${credentialName name}:${ifaceConfig.privateKeyFile}" ]
    ++ lib.concatMap (peer:
      lib.optional (peer.presharedKeyFile != null)
        "wireguard-${name}-${peer.publicKey}-psk:${peer.presharedKeyFile}"
    ) ifaceConfig.peers
  ) cfg.interfaces);

in
{
  options.services.wireguard-server = {
    enable = lib.mkEnableOption "WireGuard VPN server";

    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          ips = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "IP addresses for this WireGuard interface in CIDR notation";
            example = [ "10.77.100.1/24" ];
          };

          listenPort = lib.mkOption {
            type = lib.types.nullOr lib.types.port;
            default = null;
            description = "UDP port to listen on";
            example = 51820;
          };

          privateKeyFile = lib.mkOption {
            type = lib.types.str;
            description = "Path to private key file";
            example = "/root/wireguard-keys/wg-private";
          };

          peers = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                publicKey = lib.mkOption {
                  type = lib.types.str;
                  description = "Public key of the peer";
                };

                allowedIPs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "IP addresses/subnets this peer can use";
                  example = [ "10.77.100.10/32" ];
                };

                endpoint = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Endpoint address (for initiating connections)";
                  example = "peer.example.com:51820";
                };

                persistentKeepalive = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "Interval in seconds to send keepalive packets";
                  example = 25;
                };

                presharedKeyFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Path to preshared key file for additional security";
                };
              };
            });
            default = [ ];
            description = "List of WireGuard peers";
          };

          enableForwarding = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable IPv4 forwarding for this interface";
          };

          disableRpFilter = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Disable reverse path filtering (needed for VPN routing)";
          };

          mtu = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "MTU for the interface";
            example = 1420;
          };
        };
      });
      default = { };
      description = "WireGuard interface configurations";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically open firewall ports for WireGuard";
    };

    installTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install wireguard-tools package";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install WireGuard tools
    environment.systemPackages = lib.mkIf cfg.installTools [ pkgs.wireguard-tools ];

    # Ensure wireguard kernel module is loaded
    boot.kernelModules = [ "wireguard" ];

    # Configure systemd-networkd netdevs for WireGuard interfaces
    systemd.network.netdevs = lib.mapAttrs' (name: ifaceConfig:
      lib.nameValuePair "40-${name}" (mkNetdev name ifaceConfig)
    ) cfg.interfaces;

    # Configure systemd-networkd networks for WireGuard interfaces
    systemd.network.networks = lib.mapAttrs' (name: ifaceConfig:
      lib.nameValuePair "40-${name}" (mkNetwork name ifaceConfig)
    ) cfg.interfaces;

    # Load WireGuard private keys as credentials for systemd-networkd
    systemd.services.systemd-networkd.serviceConfig.LoadCredential = mkCredentials;

    # Disable reverse path filtering for VPN interfaces
    boot.kernel.sysctl = lib.mkMerge (lib.mapAttrsToList (name: ifaceConfig:
      lib.mkIf ifaceConfig.disableRpFilter {
        "net.ipv4.conf.${name}.rp_filter" = 0;
      }
    ) cfg.interfaces);

    # Open firewall ports
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = lib.mapAttrsToList (name: ifaceConfig:
        ifaceConfig.listenPort
      ) (lib.filterAttrs (name: ifaceConfig: ifaceConfig.listenPort != null) cfg.interfaces);
    };
  };
}
