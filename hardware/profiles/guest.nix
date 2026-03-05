{ config, lib, pkgs, ... }:

{
  # VM guest hardware profile
  # Optimized for virtual machines running on QEMU/KVM

  # Use QEMU guest agent for better integration with host
  services.qemuGuest.enable = true;

  # Boot configuration optimized for VMs
  boot = {
    # Use GRUB for UEFI boot (more compatible than systemd-boot for VMs)
    loader = {
      systemd-boot.enable = lib.mkForce false;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;  # Important for VMs
      };
      efi.canTouchEfiVariables = false;  # VMs can't modify real EFI vars
      timeout = lib.mkDefault 5;
    };

    # Kernel parameters for VMs
    kernelParams = [
      "console=tty0"
      "console=ttyS0,115200n8"  # Serial console for debugging
      "net.ifnames=0"  # Use eth0, eth1, etc. instead of ens3, ens4
    ];

    # VM-optimized kernel modules
    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
      "virtio_net"
      "virtio_balloon"
      "virtio_console"
      "virtio_rng"
      "ahci"
      "xhci_pci"
      "ehci_pci"
      "uhci_hcd"
    ];

    kernelModules = [ "kvm-intel" "kvm-amd" ];

    # Faster boot for VMs
    initrd.verbose = false;
  };

  # Filesystem configuration with sensible defaults
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    options = [ "noatime" "nodiratime" ];
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  # Swap configuration (optional, can be overridden)
  swapDevices = lib.mkDefault [ ];

  # Network configuration - use systemd-networkd for VMs
  networking = {
    useDHCP = lib.mkDefault false;
    useNetworkd = lib.mkDefault true;
  };

  # Enable serial console getty for debugging
  systemd.services."serial-getty@ttyS0" = {
    enable = lib.mkDefault true;
    wantedBy = lib.mkDefault [ "getty.target" ];
    serviceConfig.Restart = lib.mkDefault "always";
  };

  # Console configuration
  console = {
    earlySetup = true;
    keyMap = lib.mkDefault "us";
  };

  # Services optimized for VMs
  services = {
    # Minimal journal to save resources
    journald.extraConfig = ''
      Storage=volatile
      RuntimeMaxUse=64M
      SystemMaxUse=128M
    '';

    # Time sync (important for VMs)
    chrony.enable = lib.mkDefault true;

    # SSH for management
    openssh = {
      enable = lib.mkDefault true;
      settings = {
        PermitRootLogin = lib.mkDefault "prohibit-password";
        PasswordAuthentication = lib.mkDefault false;
      };
    };

    # SPICE/VNC support for graphical console
    spice-vdagentd.enable = lib.mkDefault true;
  };

  # Disable unnecessary hardware support
  hardware = {
    enableRedistributableFirmware = lib.mkDefault false;
    enableAllFirmware = lib.mkDefault false;
  };

  # VM-optimized nix settings
  nix.settings = {
    max-jobs = lib.mkDefault 4;
    cores = lib.mkDefault 2;
  };

  # Minimal documentation for VMs
  documentation = {
    enable = lib.mkDefault false;
    nixos.enable = lib.mkDefault false;
  };

  # Power management (not needed in VMs)
  powerManagement.enable = false;

  # Security
  security.sudo.wheelNeedsPassword = lib.mkDefault false;  # Easier VM management

  # Allow password login for VM console access
  # Set initialPassword for all wheel users (they can change it after first login)
  users.mutableUsers = lib.mkDefault true;
  users.users.root.initialPassword = lib.mkDefault "nixos";

  # Performance tuning for VMs
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkDefault 10;
    "vm.dirty_ratio" = lib.mkDefault 15;
    "vm.dirty_background_ratio" = lib.mkDefault 5;
  };

  # Minimal packages for VMs
  environment.systemPackages = with pkgs; [
    vim
    htop
    tmux
    git
    curl
    wget
    qemu-utils
  ];
}
