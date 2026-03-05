# OpenVPN Client Module
# Provides client-side OpenVPN connections with optional policy routing and kill switch
#
# Features:
# - Connect to VPN providers using .ovpn config files
# - Policy-based routing: route specific source IPs/networks through VPN
# - Kill switch: prevent VPN sources from leaking to WAN if VPN is down
# - Support for username/password authentication
# - DNS override support (ignore provider DNS)
#
# Usage:
#   services.client.networking.openvpn = {
#     enable = true;
#     servers.provider = {
#       configFile = ./provider.ovpn;
#       credentialsFile = "/etc/openvpn/credentials";
#       interface = "tun0";
#       policyRouting = {
#         enable = true;
#         fwmark = 100;
#         vpnSources = [ "10.88.1.50" "10.88.20.0/24" ];
#         wanInterface = "wan";
#       };
#     };
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.client.networking.openvpn;

  # Format vpnSources for nftables set (handles IPs and CIDRs)
  formatSources = sources:
    if sources == [] then ''"placeholder"''  # Empty sets cause syntax errors
    else lib.concatStringsSep ", " (map (s: ''"${s}"'') sources);

  # Generate route-up script for policy routing
  # Copies LAN/connected routes into the VPN table so return traffic (which has
  # ct mark restored in prerouting) can still reach LAN hosts via the correct
  # interfaces instead of looping back through the VPN tunnel.
  mkRouteUpScript = name: serverCfg:
    let pr = serverCfg.policyRouting;
    in pkgs.writeShellScript "openvpn-${name}-route-up" ''
      # Ensure ip rule exists (may have been flushed by networkd restart)
      ${pkgs.iproute2}/bin/ip rule del fwmark ${toString pr.fwmark} table ${toString pr.fwmark} 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip rule add fwmark ${toString pr.fwmark} table ${toString pr.fwmark} priority ${toString pr.fwmark}
      # Copy non-default routes from main table (LAN, connected, etc.)
      ${pkgs.iproute2}/bin/ip route show table main | ${pkgs.gnugrep}/bin/grep -v '^default' | while IFS= read -r route; do
        ${pkgs.iproute2}/bin/ip route replace $route table ${toString pr.fwmark} 2>/dev/null || true
      done
      # Add VPN default route last (traffic not matching LAN routes goes through tunnel)
      ${pkgs.iproute2}/bin/ip route replace default dev "$dev" table ${toString pr.fwmark}
    '';

  # Generate route-pre-down script for policy routing (cleans up VPN routing table)
  mkRouteDownScript = name: serverCfg:
    let pr = serverCfg.policyRouting;
    in pkgs.writeShellScript "openvpn-${name}-route-down" ''
      ${pkgs.iproute2}/bin/ip route flush table ${toString pr.fwmark} 2>/dev/null || true
    '';

  # Generate OpenVPN server config
  mkServerConfig = name: serverCfg: ''
    config ${serverCfg.configFile}
    ${lib.optionalString (serverCfg.credentialsFile != null) "auth-user-pass ${serverCfg.credentialsFile}"}

    ${lib.optionalString serverCfg.ignoreDns ''
    # Use local DNS, don't push DNS from provider
    pull-filter ignore "dhcp-option DNS"
    pull-filter ignore "dhcp-option DOMAIN"
    ''}

    # Interface configuration
    dev ${serverCfg.interface}
    dev-type tun

    ${lib.optionalString serverCfg.policyRouting.enable ''
    # Policy routing: don't accept routes pushed by server
    route-nopull
    # Enable script execution for route management
    script-security 2
    # Add VPN default route to policy routing table when tunnel comes up
    route-up ${mkRouteUpScript name serverCfg}
    # Clean up policy routing table when tunnel goes down
    route-pre-down ${mkRouteDownScript name serverCfg}
    ''}
    ${serverCfg.extraConfig}
  '';

  # Generate policy routing nftables rules for a server
  mkPolicyRoutingRules = name: serverCfg:
    let
      pr = serverCfg.policyRouting;
      vpnSourcesSet = formatSources pr.vpnSources;
    in
    lib.optionalString pr.enable ''
      # VPN Source Set
      set vpn_sources {
        type ipv4_addr
        flags interval
        elements = { ${vpnSourcesSet} }
      }

      # Prerouting Chain - Mark packets from VPN sources
      chain prerouting {
        type filter hook prerouting priority mangle; policy accept;

        # Restore mark from connection tracking for established connections
        ct mark ${toString pr.fwmark} meta mark set ct mark

        # Mark new connections from VPN sources
        ip saddr @vpn_sources meta mark set ${toString pr.fwmark}

        # Save mark to connection tracking for stateful handling
        meta mark ${toString pr.fwmark} ct mark set meta mark
      }

      # Forward Chain - VPN Policy and Kill Switch
      # Priority -5: runs BEFORE main firewall (priority 0)
      chain vpn_forward {
        type filter hook forward priority -5; policy accept;

        # VPN sources can exit via VPN tunnel (normal VPN path)
        meta mark ${toString pr.fwmark} oifname "${serverCfg.interface}" accept

        # VPN sources can reach internal networks
        # RFC1918 private ranges - internal access always allowed
        meta mark ${toString pr.fwmark} ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } accept

        ${lib.optionalString (pr.wanInterface != null) ''
        # KILL SWITCH: Block VPN sources from WAN interface
        # If VPN tunnel is down, traffic would route via wan - block it
        meta mark ${toString pr.fwmark} oifname "${pr.wanInterface}" log prefix "[vpn-killswitch-${name}] " drop
        ''}
      }
    '';

  # Get all servers with policy routing enabled
  serversWithPolicyRouting = lib.filterAttrs (_: s: s.policyRouting.enable) cfg.servers;

  # Collect all VPN interfaces that need special sysctl/networkd config
  allVpnInterfaces = lib.mapAttrsToList (_: s: s.interface) cfg.servers;

in
{
  options.services.client.networking.openvpn = {
    enable = lib.mkEnableOption "OpenVPN client service";

    servers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          configFile = lib.mkOption {
            type = lib.types.path;
            description = "Path to the .ovpn configuration file";
            example = lib.literalExpression "./provider.ovpn";
          };

          credentialsFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              Path to credentials file with username on line 1, password on line 2.
              Should be stored in /etc/openvpn/ with restricted permissions.
            '';
            example = "/etc/openvpn/credentials";
          };

          interface = lib.mkOption {
            type = lib.types.str;
            default = "tun0";
            description = "TUN interface name for this VPN connection";
          };

          autoStart = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to automatically start this VPN connection on boot";
          };

          ignoreDns = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Ignore DNS settings pushed by the VPN provider";
          };

          extraConfig = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Additional OpenVPN configuration";
          };

          policyRouting = {
            enable = lib.mkEnableOption "policy-based routing for this VPN connection";

            fwmark = lib.mkOption {
              type = lib.types.int;
              default = 100;
              description = "Firewall mark to use for policy routing";
            };

            vpnSources = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = ''
                List of source IPs or CIDR blocks that should route through this VPN.
                Traffic from these sources will be forced through the VPN tunnel.
              '';
              example = [ "10.88.1.50" "10.88.20.0/24" ];
            };

            wanInterface = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                WAN interface name for kill switch functionality.
                If set, VPN sources will be blocked from exiting via this interface
                when the VPN is down (kill switch).
              '';
              example = "wan";
            };
          };
        };
      }));
      default = {};
      description = "OpenVPN server configurations";
    };
  };

  config = lib.mkIf cfg.enable {
    # OpenVPN service configurations
    services.openvpn.servers = lib.mapAttrs (name: serverCfg: {
      config = mkServerConfig name serverCfg;
      autoStart = serverCfg.autoStart;
    }) cfg.servers;

    # Install OpenVPN tools
    environment.systemPackages = [ pkgs.openvpn ];

    # Policy routing requires src_valid_mark so the kernel uses the fwmark's
    # routing table for reverse path filtering. Without this, strict rp_filter
    # drops VPN return traffic because it checks the main table (which says
    # "go via wan") instead of table 100 (which has the tun0 default route).
    boot.kernel.sysctl = lib.mkIf (serversWithPolicyRouting != {}) {
      "net.ipv4.conf.all.src_valid_mark" = 1;
    };

    # Configure VPN interfaces in systemd-networkd for proper forwarding
    systemd.network.networks = lib.listToAttrs (map (iface: {
      name = "60-${iface}";
      value = {
        matchConfig.Name = iface;
        networkConfig = {
          IPv4Forwarding = "yes";
          ConfigureWithoutCarrier = true;
          IgnoreCarrierLoss = true;
          # Don't touch addressing - OpenVPN manages the IP
          DHCP = "no";
          LinkLocalAddressing = "no";
          # Keep any addresses that OpenVPN sets
          KeepConfiguration = "yes";
        };
      };
    }) allVpnInterfaces);

    # Policy routing and kill switch nftables rules
    networking.nftables.tables = lib.listToAttrs (lib.mapAttrsToList (name: serverCfg: {
      name = "vpn_policy_${name}";
      value = {
        family = "ip";
        content = mkPolicyRoutingRules name serverCfg;
      };
    }) serversWithPolicyRouting);

    # Persistent ip rules for fwmark-based policy routing
    # Routes marked packets to the VPN routing table instead of the main table
    systemd.services = lib.listToAttrs (lib.mapAttrsToList (name: serverCfg:
      let pr = serverCfg.policyRouting;
      in {
        name = "openvpn-${name}-policy-rule";
        value = {
          description = "IP policy rule for OpenVPN ${name} (fwmark ${toString pr.fwmark} -> table ${toString pr.fwmark})";
          wantedBy = [ "multi-user.target" ];
          before = [ "openvpn-${name}.service" ];
          after = [ "network.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStartPre = "-${pkgs.iproute2}/bin/ip rule del fwmark ${toString pr.fwmark} table ${toString pr.fwmark}";
            ExecStart = "${pkgs.iproute2}/bin/ip rule add fwmark ${toString pr.fwmark} table ${toString pr.fwmark} priority ${toString pr.fwmark}";
            ExecStop = "${pkgs.iproute2}/bin/ip rule del fwmark ${toString pr.fwmark} table ${toString pr.fwmark}";
          };
        };
      }
    ) serversWithPolicyRouting);
  };
}
