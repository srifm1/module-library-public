# NixOS Module Library

A collection of reusable, declarative NixOS modules for building modular system configurations. This library provides battle-tested modules for networking, services, desktops, applications, and hardware profiles.

## Overview

This repository provides NixOS modules that can be imported into your flake-based NixOS configurations. Each module is designed to be self-contained, well-documented, and follows NixOS best practices.

## Usage

### Adding as a Flake Input

Add this repository as an input to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    module-library = {
      url = "path:/storage/data/code/system-flake-repos/module-library";
      # or use git:
      # url = "git+https://your-repo-url/module-library";
    };
  };

  outputs = { self, nixpkgs, module-library }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Apply the overlay for custom packages
        { nixpkgs.overlays = [ module-library.overlays.default ]; }

        # Import composition profiles
        module-library.nixosModules.profile-workstation

        # Import individual modules as needed
        module-library.nixosModules.hw-laptop

        # Your host-specific configuration
        ./hosts/myhost
      ];
    };
  };
}
```

### Example Host Configuration

```nix
# hosts/myhost/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Configure modules imported from the library
  desktops.gnome = {
    enable = true;
    username = "myuser";
  };

  # Host-specific settings
  networking.hostName = "myhost";
  system.stateVersion = "24.05";
}
```

## Module Categories

### Network Interfaces

Modules for configuring network interfaces with various topologies:

- `iface-dhcp-native` - DHCP on native (untagged) interface
- `iface-dhcp-vlan` - DHCP on VLAN-tagged interface
- `iface-static-native` - Static IP on native interface
- `iface-static-vlan` - Static IP on VLAN-tagged interface
- `iface-trunk` - Trunk interface for carrying multiple VLANs

### Client Services

Modules for client-side services:

**Networking:**
- `openvpn-client` - OpenVPN client configuration (`services.client.networking.openvpn`)
- `wireguard-client` - WireGuard VPN client (`services.client.networking.wireguard`)

**File Sharing:**
- `nfs-client` - NFS client mounts (`services.client.fileshare.nfs`)
- `virtiofs-client` - VirtioFS client mounts (`services.virtiofs-client`)

### Server Services

Modules for server-side services (options under `services.<name>-server`):

**Networking:**
- `kea` - ISC Kea DHCP server (`services.kea-server`)
- `unbound` - Unbound DNS resolver (`services.unbound-server`)
- `nftables` - nftables firewall (`services.nftables-firewall`)
- `wireguard-server` - WireGuard VPN server (`services.wireguard-server`)

**File Sharing:**
- `nfs-server` - NFS file server (`services.nfs-server`)
- `smb-server` - Samba/SMB file server (`services.smb-server`)

**Web:**
- `traefik` - Traefik reverse proxy (`services.traefik-server`)
- `ttyd` - ttyd web terminal (`services.ttyd-server`)

**Media:**
- `media-common` - Shared media service config (`services.media-common`)
- `jellyfin` - Jellyfin media server (`services.jellyfin-server`)
- `sonarr` - Sonarr TV management (`services.sonarr-server`)
- `radarr` - Radarr movie management (`services.radarr-server`)
- `prowlarr` - Prowlarr indexer (`services.prowlarr-server`)
- `jellyseerr` - Jellyseerr request management (`services.jellyseerr-server`)
- `qbittorrent` - qBittorrent download client (`services.qbittorrent-server`)

**Gaming:**
- `foundryvtt` - Foundry VTT game server (`services.foundryvtt-server`)

**DevOps:**
- `gitea` - Gitea git forge (`services.gitea-server`)

**Automation:**
- `home-assistant` - Home Assistant (`services.hass-server`)

**Other:**
- `ssh` - SSH server configuration (`services.ssh-server`)

### Virtualization

- `nixvirt-host` - libvirtd/QEMU host with NixVirt integration

### Desktops

Desktop environment modules:

- `gnome` - GNOME desktop environment
- `sway` - Sway (Wayland) window manager
- `headless` - Headless system (no GUI)

### Applications

Application bundles organized by interface type:

**GUI Applications:**
- `apps-gui-core` - Essential GUI applications
- `apps-gui-dev` - Development tools with GUI
- `apps-gui-gaming` - Gaming applications
- `apps-gui-productivity` - Productivity applications

**TUI Applications:**
- `apps-tui-core` - Essential terminal applications
- `apps-tui-dev` - Terminal-based development tools
- `apps-tui-productivity` - Terminal productivity tools

### Hardware

Hardware-specific configurations:

**Discrete Hardware:**
- `bluetooth` - Bluetooth support
- `nvidia` - NVIDIA graphics drivers
- `vial` - Vial keyboard configuration

**Hardware Profiles:**
- `hw-desktop` - Desktop PC profile
- `hw-guest` - Virtual machine guest profile
- `hw-laptop` - Laptop profile (power management, etc.)
- `hw-rpi` - Raspberry Pi profile
- `hw-server` - Server profile (headless, optimized)

### Composition Profiles

Pre-composed module sets for common configurations:

- `profile-workstation` - Desktop/laptop with sway, GUI+TUI apps, bluetooth
- `profile-server-vm` - Headless VM server with TUI apps
- `profile-server-physical` - Headless physical server with TUI apps
- `profile-storage-nfs` - NFS storage client (backups, data, media mounts)
- `profile-storage-virtiofs` - VirtioFS storage client for VMs

### Network Specification

The library exports `lib.networkSpec` - a single source of truth for all network topology, IP assignments, VLAN definitions, WireGuard configuration, and DNS records.

## Module Design

All modules in this library follow these principles:

1. **Declarative Options**: Server modules expose options under `services.<name>-server`, client modules under `services.client.<category>.<name>` or `services.<name>-client`
2. **Enable Guards**: Modules are disabled by default and must be explicitly enabled
3. **Self-Contained**: Modules include all necessary package dependencies and configurations
4. **Well-Documented**: Each option includes descriptions and type information
5. **Composable**: Modules can be combined without conflicts

## Contributing

When adding new modules:

1. Place the module in the appropriate category directory
2. Follow the existing module structure and naming conventions
3. Add the module export to `flake.nix`
4. Update this README with the module description
5. Ensure the module has proper option documentation

## License

This module library is provided as-is for use in NixOS configurations.
