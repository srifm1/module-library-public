# WireGuard Client/Peer Module
# Provides WireGuard VPN connections in client/peer mode
# Self-contained: directly configures systemd-networkd without relying on
# NixOS's networking.wireguard module.
#
# Features:
# - Point-to-Site (P2S): Connect to remote WireGuard servers as a client
# - Site-to-Site (S2S): Peer-to-peer connections between sites
# - Multiple interface support for different use cases
# - Automatic forwarding configuration
# - Proper reverse path filtering configuration
#
# Usage:
#   services.client.networking.wireguard = {
#     enable = true;
#     interfaces = {
#       wg-home = {
#         ips = [ "10.77.100.10/32" ];
#         privateKeyFile = "/etc/wireguard/private";
#         peers = [
#           {
#             publicKey = "SERVER_PUBLIC_KEY";
#             endpoint = "vpn.example.com:51820";
#             allowedIPs = [ "10.0.0.0/8" ];
#             persistentKeepalive = 25;
#           }
#         ];
#       };
#     };
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.client.networking.wireguard;

  # Generate credential name for systemd
  credentialName = name: "wireguard-${name}-private-key";

  # Generate netdev for a WireGuard interface
  mkNetdev = name: iface: {
    netdevConfig = {
      Kind = "wireguard";
      Name = name;
    } // lib.optionalAttrs (iface.mtu != null) {
      MTUBytes = toString iface.mtu;
    };
    wireguardConfig = {
      PrivateKey = "@${credentialName name}";
    } // lib.optionalAttrs (iface.listenPort != null) {
      ListenPort = iface.listenPort;
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
    }) iface.peers;
  };

  # Generate network config for a WireGuard interface
  mkNetwork = name: iface: {
    matchConfig.Name = name;
    address = iface.ips;
    networkConfig = {
      ConfigureWithoutCarrier = iface.configureWithoutCarrier;
    } // lib.optionalAttrs iface.enableForwarding {
      IPv4Forwarding = "yes";
    };
  };

  # Generate LoadCredential entries for all interfaces
  mkCredentials = lib.flatten (lib.mapAttrsToList (name: iface:
    [ "${credentialName name}:${iface.privateKeyFile}" ]
    ++ lib.concatMap (peer:
      lib.optional (peer.presharedKeyFile != null)
        "wireguard-${name}-${peer.publicKey}-psk:${peer.presharedKeyFile}"
    ) iface.peers
  ) cfg.interfaces);

  # Peer submodule definition
  peerOptions = lib.types.submodule {
    options = {
      publicKey = lib.mkOption {
        type = lib.types.str;
        description = "Base64 encoded public key of the peer";
        example = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
      };

      presharedKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing the preshared key (PSK) for this peer";
        example = "/root/wireguard-keys/peer1-psk";
      };

      endpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Endpoint address and port for this peer.
          Format: "hostname:port" or "IP:port"
          Leave null for peers that connect to you.
        '';
        example = "vpn.example.com:51820";
      };

      allowedIPs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          List of IP addresses or CIDR blocks this peer is allowed to use.
          For clients: their tunnel IP (e.g., "10.77.100.10/32")
          For site-to-site: tunnel IP + remote networks (e.g., ["10.77.200.2/32", "10.77.50.0/24"])
        '';
        example = [ "10.77.100.10/32" ];
      };

      persistentKeepalive = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = ''
          Send keepalive packets every N seconds.
          Useful for maintaining NAT mappings and keeping tunnels alive.
          Common value: 25 seconds.
        '';
        example = 25;
      };
    };
  };

  # Interface submodule definition
  interfaceOptions = lib.types.submodule ({ name, ... }: {
    options = {
      ips = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          IP addresses for this WireGuard interface.
          Usually includes CIDR notation.
        '';
        example = [ "10.77.100.1/24" ];
      };

      listenPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = ''
          UDP port to listen on for incoming connections.
          Leave null for client-only interfaces (no incoming connections).
        '';
        example = 51820;
      };

      privateKeyFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          Path to file containing the private key for this interface.
          Generate with: wg genkey > /root/wireguard-keys/wg-private
          Permissions should be 600.
        '';
        example = "/root/wireguard-keys/wg-p2s-private";
      };

      peers = lib.mkOption {
        type = lib.types.listOf peerOptions;
        default = [];
        description = "List of WireGuard peers for this interface";
      };

      enableForwarding = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable IPv4 forwarding on this interface.
          Typically disabled for clients, enabled for site-to-site.
        '';
      };

      disableRpFilter = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Disable reverse path filtering on this interface.
          Required for VPN traffic where source IPs don't match return path.
        '';
      };

      configureWithoutCarrier = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Allow configuration even when interface has no carrier.
          Typically enabled for VPN interfaces.
        '';
      };

      mtu = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "MTU for this interface";
        example = 1420;
      };
    };
  });

  # Collect all interfaces that need sysctl configuration
  interfacesWithRpFilter = lib.filterAttrs (_: iface: iface.disableRpFilter) cfg.interfaces;

in
{
  options.services.client.networking.wireguard = {
    enable = lib.mkEnableOption "WireGuard VPN client/peer service";

    interfaces = lib.mkOption {
      type = lib.types.attrsOf interfaceOptions;
      default = {};
      description = ''
        WireGuard interface configurations.
        Each attribute name becomes the interface name.
      '';
      example = lib.literalExpression ''
        {
          wg-home = {
            ips = [ "10.77.100.10/32" ];
            privateKeyFile = "/etc/wireguard/private";
            peers = [ /* ... */ ];
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Install WireGuard tools
    environment.systemPackages = [ pkgs.wireguard-tools ];

    # Ensure wireguard kernel module is loaded
    boot.kernelModules = [ "wireguard" ];

    # Configure systemd-networkd netdevs for WireGuard interfaces
    systemd.network.netdevs = lib.mapAttrs' (name: iface:
      lib.nameValuePair "40-${name}" (mkNetdev name iface)
    ) cfg.interfaces;

    # Configure systemd-networkd networks for WireGuard interfaces
    systemd.network.networks = lib.mapAttrs' (name: iface:
      lib.nameValuePair "40-${name}" (mkNetwork name iface)
    ) cfg.interfaces;

    # Load WireGuard private keys as credentials for systemd-networkd
    systemd.services.systemd-networkd.serviceConfig.LoadCredential = mkCredentials;

    # Disable reverse path filtering for WireGuard interfaces
    boot.kernel.sysctl = lib.listToAttrs (lib.mapAttrsToList (name: _: {
      name = "net.ipv4.conf.${name}.rp_filter";
      value = 0;
    }) interfacesWithRpFilter);
  };
}
