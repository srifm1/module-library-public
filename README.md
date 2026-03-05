# NixOS Module Library

Reusable NixOS modules for managing a segmented home network with VLAN isolation, policy-based VPN routing, zone-based firewalling, and a self-hosted media/services stack. Built on systemd-networkd and nftables throughout.

## Architecture

```
module-library/
├── network-spec.nix          # Single source of truth for all IPs, VLANs, DNS
├── profiles/                 # Composed module sets (workstation, server-vm, etc.)
├── services/
│   ├── client/
│   │   ├── networking/       # OpenVPN (policy routing), WireGuard, interface modules
│   │   └── fileshare/        # NFS + VirtioFS client mounts
│   └── server/
│       ├── networking/       # nftables, Kea DHCP, Unbound DNS, WireGuard server
│       ├── media/            # Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent
│       ├── web/              # Traefik reverse proxy, ttyd web terminal
│       ├── fileshare/        # NFS + SMB servers
│       ├── devops/           # Gitea
│       ├── gaming/           # FoundryVTT
│       └── virt/             # libvirt/QEMU via NixVirt
├── desktops/                 # Sway (Wayland), GNOME, headless
├── apps/                     # GUI + TUI application bundles
└── hardware/                 # Profiles (desktop, laptop, server, VM guest, RPi)
```

### Network Specification

`network-spec.nix` is a pure data file that acts as an IP address registry. Every VLAN, subnet, gateway, host IP, WireGuard network, and DNS record is defined here once, then consumed by host configs via `lib.networkSpec`. No IP address is hardcoded anywhere else.

## Key Modules

### OpenVPN with Policy Routing (`services/client/networking/openvpn.nix`)

Routes specific source IPs through a VPN tunnel while leaving everything else on the WAN. Designed for pushing *arr/torrent traffic through a commercial VPN without affecting the rest of the network.

How it works:

1. **nftables prerouting** marks new connections from configured source IPs with a fwmark
2. **Kernel policy routing** (ip rule) sends marked packets to a dedicated routing table
3. **Route-up script** copies LAN routes into the VPN table so return traffic still reaches local hosts
4. **Kill switch** via nftables output chain blocks VPN sources from reaching the WAN directly if the tunnel drops
5. **ct mark restoration** ensures reply packets for existing connections stay in the VPN table
6. **`src_valid_mark=1`** sysctl makes reverse path filtering work with policy routing

```nix
services.client.networking.openvpn.servers.provider = {
  configFile = ./provider.ovpn;
  policyRouting = {
    enable = true;
    fwmark = 100;
    vpnSources = [ "10.88.20.11" ];  # services1 media IP
    wanInterface = "wan";
  };
};
```

### Zone-Based Firewall (`services/server/networking/nftables.nix`)

nftables firewall with named security zones mapped to interface sets:

- **trusted** (infra VLAN) -- full access
- **client** (wifi/cabled) -- internet + selected services
- **iot** (IoT VLANs) -- outbound-only, no lateral movement
- **vpn-client** (WireGuard peers) -- routed through to LAN

Each zone gets interface and IP sets auto-generated from configuration. Rules reference zones by name rather than raw interfaces. Supports per-zone SSH rate limiting, MAC-based device whitelisting, and ICMP rate limiting.

### WireGuard Server (`services/server/networking/wireguard.nix`)

Dual-tunnel WireGuard setup:

- **Point-to-Site** (port 51820) -- phones, laptops connecting remotely
- **Site-to-Site** (port 51821) -- inter-router tunnels between locations

Both use systemd-networkd netdevs (not the NixOS `networking.wireguard` module) for tighter integration with the rest of the network stack. DNS queries from WireGuard peers are forwarded to the router's Unbound instance.

### DHCP + DNS (`services/server/networking/kea.nix`, `unbound.nix`)

- **Kea DHCP4** serves per-VLAN pools with subnet-specific DNS domains
- **Unbound** provides recursive DNS with local zones for internal hosts, wildcard subdomains for the services VM, and upstream DNS-over-TLS

### Interface Modules (`services/client/networking/iface-*.nix`)

Four interface modules cover every combination of VLAN/native and DHCP/static. All use systemd-networkd with options for interface renaming, MAC matching, multiple addresses, forwarding, and WoL. A separate trunk module handles the tagged uplink.

### Media Stack (`services/server/media/`)

Thin wrappers around upstream NixOS modules with a shared `media-common` module that creates a unified media group and directory structure (`/storage/media/{movies,tv,downloads}`). Individual modules: Jellyfin, Sonarr, Radarr, Prowlarr, Jellyseerr, qBittorrent.

### Profiles

Pre-composed module sets for common roles:

| Profile | Includes |
|---------|----------|
| `profile-workstation` | Sway + desktop hardware + all GUI/TUI apps + bluetooth |
| `profile-server-vm` | Headless + VM guest hardware + TUI apps |
| `profile-server-physical` | Headless + server hardware + TUI apps |
| `profile-storage-nfs` | NFS client mounts (backups, data, media) |
| `profile-storage-virtiofs` | VirtioFS client mounts for VMs |

## Usage

```nix
{
  inputs.module-library.url = "github:srifm1/module-library-public";

  outputs = { nixpkgs, module-library, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.overlays = [ module-library.overlays.default ]; }
        module-library.nixosModules.profile-server-vm
        module-library.nixosModules.nftables
        module-library.nixosModules.kea
        ./hosts/myhost
      ];
    };
  };
}
```

`lib.networkSpec` is available to consuming flakes for referencing the network topology.

## License

MIT
