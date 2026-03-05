{ config, pkgs, lib, ... }:

{
  # Raspberry Pi hardware profile
  # Optimized for ARM-based Raspberry Pi devices

  # Boot configuration for Raspberry Pi
  boot = {
    # Raspberry Pi uses U-Boot or custom boot
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = lib.mkDefault true;
    };

    # Raspberry Pi kernel
    # Note: NixOS typically uses the mainline kernel with Raspberry Pi support
    # For official Raspberry Pi kernel, you may need to override this
    kernelPackages = lib.mkDefault pkgs.linuxPackages_rpi4;

    # Kernel parameters
    kernelParams = [
      "console=ttyS0,115200n8"
      "console=tty0"
    ];

    # Enable firmware
    initrd.includeDefaultModules = true;

    # Faster boot
    initrd.verbose = false;
  };

  # Hardware support
  hardware = {
    # Enable Raspberry Pi firmware
    enableRedistributableFirmware = true;

    # Raspberry Pi GPU support
    raspberry-pi."4".apply-overlays-dtmerge.enable = lib.mkDefault true;

    # OpenGL support (VC4 driver)
    graphics = {
      enable = true;
    };
  };

  # Filesystem configuration
  fileSystems = {
    "/" = lib.mkDefault {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    "/boot" = lib.mkDefault {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
    };
  };

  # Swap (typically on SD card, use with caution)
  swapDevices = lib.mkDefault [ ];

  # Network configuration
  networking = {
    useDHCP = lib.mkDefault true;
    wireless.enable = lib.mkDefault true;  # Enable WiFi
  };

  # Enable SSH for headless management
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PermitRootLogin = lib.mkDefault "prohibit-password";
      PasswordAuthentication = lib.mkDefault false;
    };
  };

  # Serial console for debugging
  systemd.services."serial-getty@ttyS0" = {
    enable = lib.mkDefault true;
    wantedBy = lib.mkDefault [ "getty.target" ];
  };

  # Console configuration
  console = {
    earlySetup = true;
    keyMap = lib.mkDefault "us";
  };

  # Services
  services = {
    # Minimal journal (SD card wear)
    journald.extraConfig = ''
      Storage=volatile
      RuntimeMaxUse=32M
      SystemMaxUse=64M
    '';

    # Time sync
    chrony.enable = lib.mkDefault true;
  };

  # Minimal documentation to save space
  documentation = {
    enable = lib.mkDefault false;
    nixos.enable = lib.mkDefault false;
  };

  # Power management (minimal for embedded)
  powerManagement.enable = lib.mkDefault true;

  # Performance tuning for SD card
  boot.kernel.sysctl = {
    # Low swappiness (SD card wear)
    "vm.swappiness" = lib.mkDefault 10;
    # Conservative caching
    "vm.dirty_ratio" = lib.mkDefault 10;
    "vm.dirty_background_ratio" = lib.mkDefault 3;
  };

  # Nix settings for limited resources
  nix.settings = {
    max-jobs = lib.mkDefault 2;
    cores = lib.mkDefault 2;
  };

  # Essential packages for Raspberry Pi
  environment.systemPackages = with pkgs; [
    vim
    htop
    libraspberrypi
    raspberrypi-eeprom
  ];

  # CPU frequency governor (for power efficiency)
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
