{
  description = "NixOS module library - reusable system configuration modules";

  inputs = {
    foundryvtt.url = "git+ssh://gitea@git.services.example.net/Apps/FoundryVTT.git";
    foundryvtt-relay.url = "git+ssh://gitea@git.services.example.net/Flakes/foundryvtt-rest-api.git";
    ccflare.url = "git+ssh://gitea@git.services.example.net/Flakes/ccflare.git";
    ccshell.url = "git+ssh://gitea@git.services.example.net/WorkflowManagement/ccshell.git";
    claude-code.url = "git+ssh://gitea@git.services.example.net/Apps/claude-code.git";
    gsd.url = "git+ssh://gitea@git.services.example.net/Apps/gsd.git";
    mdsway.url = "git+ssh://gitea@git.services.example.net/workflowmanagement/mdsway.git";
    markdown-viewer.url = "git+ssh://gitea@git.services.example.net/apps/markdownviewer.git";
    NixVirt.url = "github:AshleyYakeley/NixVirt";
  };

  outputs = { self, foundryvtt, foundryvtt-relay, ccflare, ccshell, claude-code, gsd, mdsway, markdown-viewer, NixVirt, ... }: {
    lib.networkSpec = import ./network-spec.nix;

    overlays.default = final: prev:
      let
        system = prev.stdenv.hostPlatform.system;
      in {
        foundryvtt-rest-api-relay = foundryvtt-relay.packages.${system}.default;
        ccflare = ccflare.packages.${system}.default;
        ccshell = ccshell.packages.${system}.default;
        claude-code = claude-code.packages.${system}.default;
        gsd = gsd.packages.${system}.default;
        mdsway = mdsway.packages.${system}.default;
        mdsway-daemon = mdsway.packages.${system}.mdsway-daemon;
        markdown-viewer = markdown-viewer.packages.${system}.default;
      };

    nixosModules = {
      # Network interfaces
      iface-dhcp-native = import ./services/client/networking/iface-dhcp-native.nix;
      iface-dhcp-vlan = import ./services/client/networking/iface-dhcp-vlan.nix;
      iface-static-native = import ./services/client/networking/iface-static-native.nix;
      iface-static-vlan = import ./services/client/networking/iface-static-vlan.nix;
      iface-trunk = import ./services/client/networking/iface-trunk.nix;

      # Client services
      openvpn-client = import ./services/client/networking/openvpn.nix;
      wireguard-client = import ./services/client/networking/wireguard.nix;
      nfs-client = import ./services/client/fileshare/nfs.nix;
      virtiofs-client = import ./services/client/fileshare/virtiofs.nix;

      # Server networking
      kea = import ./services/server/networking/kea.nix;
      unbound = import ./services/server/networking/unbound.nix;
      nftables = import ./services/server/networking/nftables.nix;
      wireguard-server = import ./services/server/networking/wireguard.nix;

      # Server fileshare
      nfs-server = import ./services/server/fileshare/nfs.nix;
      smb-server = import ./services/server/fileshare/smb.nix;

      # Server misc
      traefik = import ./services/server/web/traefik.nix;
      ttyd = import ./services/server/web/ttyd.nix;

      # Media services
      media-common = import ./services/server/media/common.nix;
      jellyfin = import ./services/server/media/jellyfin.nix;
      sonarr = import ./services/server/media/sonarr.nix;
      radarr = import ./services/server/media/radarr.nix;
      prowlarr = import ./services/server/media/prowlarr.nix;
      jellyseerr = import ./services/server/media/jellyseerr.nix;
      qbittorrent = import ./services/server/media/qbittorrent.nix;

      # Gaming
      foundryvtt = { ... }: {
        imports = [
          foundryvtt.nixosModules.foundryvtt
          (import ./services/server/gaming/foundryvtt.nix)
        ];
      };
      foundryvtt-relay = { ... }: {
        imports = [
          foundryvtt-relay.nixosModules.default
          (import ./services/server/gaming/foundryvtt-relay.nix)
        ];
      };

      # Proxy
      ccflare = { ... }: {
        imports = [
          ccflare.nixosModules.default
          (import ./services/server/proxy/ccflare.nix)
        ];
      };

      # DevOps
      gitea = import ./services/server/devops/gitea.nix;

      # Desktops
      gnome = import ./desktops/gnome.nix;
      sway = import ./desktops/sway.nix;
      headless = import ./desktops/headless.nix;

      # Apps
      apps-gui-core = import ./apps/gui/core.nix;
      apps-gui-dev = import ./apps/gui/development.nix;
      apps-gui-gaming = import ./apps/gui/gaming.nix;
      apps-gui-productivity = import ./apps/gui/productivity.nix;
      apps-tui-core = import ./apps/tui/core.nix;
      apps-tui-dev = import ./apps/tui/development.nix;
      apps-tui-productivity = import ./apps/tui/productivity.nix;

      # Hardware
      bluetooth = import ./hardware/discrete/bluetooth.nix;
      nvidia = import ./hardware/discrete/nvidia.nix;
      vial = import ./hardware/discrete/vial.nix;
      hw-desktop = import ./hardware/profiles/desktop.nix;
      hw-guest = import ./hardware/profiles/guest.nix;
      hw-laptop = import ./hardware/profiles/laptop.nix;
      hw-rpi = import ./hardware/profiles/rpi.nix;
      hw-server = import ./hardware/profiles/server.nix;

      # Virtualization
      nixvirt-host = { ... }: {
        imports = [
          NixVirt.nixosModules.default
          (import ./services/server/virt/nixvirt-host.nix)
        ];
      };

      # Composition profiles
      profile-workstation = import ./profiles/workstation.nix;
      profile-server-vm = import ./profiles/server-vm.nix;
      profile-server-physical = import ./profiles/server-physical.nix;

      # Storage client profiles
      profile-storage-nfs = import ./profiles/storage-client-nfs.nix;
      profile-storage-virtiofs = import ./profiles/storage-client-virtiofs.nix;
    };
  };
}
