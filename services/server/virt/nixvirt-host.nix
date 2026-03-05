# nixvirt-host.nix
# libvirtd host configuration for VM orchestration
# NixVirt module is imported internally from module-library's flake inputs
{ config, lib, pkgs, ... }:

{
  # LibVirt/QEMU configuration for VM management
  virtualisation.libvirtd = {
    enable = true;

    # QEMU configuration
    qemu = {
      package = lib.mkDefault pkgs.qemu_kvm;
      runAsRoot = lib.mkDefault false;
      swtpm.enable = lib.mkDefault true;  # TPM support for Windows 11, etc
      verbatimConfig = ''
        user = "root"
      '';
      vhostUserPackages = [ pkgs.virtiofsd ];  # Required for virtiofs support
    };

    # Network configuration - allow all VLAN bridges
    allowedBridges = [
      "br0" "br-wan" "br-lan"
      "br10" "br11" "br12" "br13" "br14"
      "br15" "br16" "br17" "br18" "br19" "br20"
    ];

    # Performance settings
    onBoot = "ignore";  # Don't auto-start VMs (systemd handles this)
    onShutdown = "shutdown";  # Gracefully shutdown VMs

    # Extra libvirt configuration
    extraConfig = ''
      # Logging
      log_level = 2
      log_outputs = "2:syslog:libvirtd"

      # Security
      security_driver = "none"  # Disable AppArmor/SELinux for NixOS

      # Network
      firewall_backend = "iptables"
    '';
  };

  # Ensure libvirtd can find virtiofsd
  systemd.services.libvirtd = {
    path = [ pkgs.virtiofsd ];
    environment = {
      VIRTIOFSD = "${pkgs.virtiofsd}/bin/virtiofsd";
    };
  };

  # User permissions for libvirt access
  users.groups.libvirtd.members = [ "root" ];

  # Kernel modules for virtualization (both AMD and Intel - kernel ignores the one that doesn't match)
  boot.kernelModules = [
    "kvm-amd"
    "kvm-intel"
    "vhost_net"
    "vhost_vsock"
  ];

  # Sysctl settings for VMs
  boot.kernel.sysctl = {
    # VM performance
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
  };

  # Management tools
  environment.systemPackages = with pkgs; [
    libvirt
    virt-manager
    virt-viewer
    qemu_kvm
    qemu-utils
    OVMF
    swtpm
    spice-gtk
    virtiofsd

    # Monitoring
    virt-top
  ];

  # Firewall rules for VM management
  networking.firewall = {
    # VNC ports (5900-5910)
    allowedTCPPortRanges = [
      { from = 5900; to = 5910; }
    ];

    # Libvirt remote management ports
    allowedTCPPorts = [
      16509  # libvirt
      16514  # libvirt-tls
    ];
  };

  # CPU governor for better VM performance
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
}
