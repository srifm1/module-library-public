{ config, pkgs, lib, ... }:

{
  # Laptop hardware profile
  # Optimized for mobile computing with power management and battery life

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
      enable32Bit = true;
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
  };

  # Boot configuration
  boot = {
    # Use latest kernel for best hardware support
    kernelPackages = pkgs.linuxPackages_latest;  # Higher priority than hw-desktop's mkDefault

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

    # Kernel parameters for laptop
    kernelParams = [
      "quiet"
      "splash"
    ];
  };

  # Power Management Configuration
  # Optimized for battery life and laptop usage

  # Systemd login manager settings
  services.logind.settings = {
    Login = {
      # Lid switch behavior
      HandleLidSwitch = "suspend";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";

      # Power key handling
      HandlePowerKey = "poweroff";
      HandleSuspendKey = "suspend";
      HandleHibernateKey = "hibernate";

      # Disable idle actions entirely
      IdleAction = "ignore";
      IdleActionSec = 0;
    };
  };

  # Additional power management via systemd targets
  systemd.targets = {
    sleep.enable = true;
    suspend.enable = true;
    hibernate.enable = true;
    hybrid-sleep.enable = true;
  };

  # Power profiles daemon configuration (used by GNOME)
  services.power-profiles-daemon.enable = lib.mkDefault true;

  # UPower configuration for battery management
  services.upower = {
    enable = true;
    criticalPowerAction = "Suspend";
    allowRiskyCriticalPowerAction = true;
  };

  # Disable automatic suspension via systemd sleep configuration
  environment.etc."systemd/sleep.conf".text = ''
    [Sleep]
    # Allow manual sleep/hibernate but don't auto-trigger
    AllowSuspend=yes
    AllowHibernation=yes
    AllowSuspendThenHibernate=yes
    AllowHybridSleep=yes

    # Don't suspend to disk automatically
    SuspendMode=
    SuspendState=mem
    HibernateMode=platform shutdown
    HibernateState=disk
    HybridSleepMode=suspend platform shutdown
    HybridSleepState=disk
  '';

  # Enable TLP for advanced power management (alternative to power-profiles-daemon)
  # Uncomment to use TLP instead of power-profiles-daemon
  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
  #     SOUND_POWER_SAVE_ON_BAT = 1;
  #   };
  # };

  # Backlight control
  programs.light.enable = lib.mkDefault true;

  # Touchpad support
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      tapping = true;
      disableWhileTyping = true;
    };
  };

  # Printing support
  services.printing = {
    enable = lib.mkDefault true;
    drivers = with pkgs; [ gutenprint hplip ];
  };

  # Performance tuning for laptop (balanced, overrides desktop defaults)
  boot.kernel.sysctl = {
    # Balanced swappiness for laptop
    "vm.swappiness" = 40;
    # Conservative file cache management
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
  };

  # Thermal management
  services.thermald.enable = lib.mkDefault (pkgs.stdenv.hostPlatform.isx86);
}
