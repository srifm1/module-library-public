{ config, pkgs, lib, ... }:

{
  # Desktop workstation hardware profile
  # Optimized for desktop computers with full hardware support

  # Hardware support
  hardware = {
    # Enable firmware updates
    enableRedistributableFirmware = true;
    enableAllFirmware = true;

    # CPU microcode updates
    cpu.intel.updateMicrocode = lib.mkDefault true;
    cpu.amd.updateMicrocode = lib.mkDefault true;

    # OpenGL/graphics acceleration
    graphics = {
      enable = true;
      enable32Bit = true;  # Support for 32-bit applications (gaming, Wine)
    };

  };

  # Audio support via PipeWire (disable pulseaudio)
  services.pulseaudio.enable = false;

  # PipeWire for modern audio/video routing
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    jack.enable = lib.mkDefault true;
  };

  # Boot configuration
  boot = {
    # Use latest kernel for best hardware support
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    # UEFI boot with systemd-boot
    loader = {
      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = lib.mkDefault true;
      timeout = lib.mkDefault 5;
    };

    # Enable Plymouth for boot splash
    plymouth.enable = lib.mkDefault true;

    # Kernel parameters for desktop
    kernelParams = [
      "quiet"
      "splash"
    ];
  };

  # Power management (basic, not aggressive)
  powerManagement.enable = lib.mkDefault true;

  # Printing support
  services.printing = {
    enable = lib.mkDefault true;
    drivers = with pkgs; [ gutenprint hplip ];
  };

  # Scanner support
  hardware.sane = {
    enable = lib.mkDefault true;
    extraBackends = with pkgs; [ hplipWithPlugin ];
  };

  # Performance tuning for desktop
  boot.kernel.sysctl = {
    # Desktop-optimized swappiness
    "vm.swappiness" = lib.mkDefault 60;
    # Responsive file cache management
    "vm.dirty_ratio" = lib.mkDefault 20;
    "vm.dirty_background_ratio" = lib.mkDefault 10;
  };
}
