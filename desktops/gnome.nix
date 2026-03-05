{ config, pkgs, lib, ... }:

{
  options.desktops.gnome = {
    laptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable laptop-specific features (touchpad, power management)";
    };
  };

  config = {
    # Enable NetworkManager for desktop network management
    networking.networkmanager.enable = lib.mkDefault true;

    # Enable display server (handles both Wayland and X11)
    services.xserver.enable = true;

    # Enable GDM and GNOME Desktop Environment
    services.displayManager.gdm = {
      enable = true;
      wayland = true;
    };
    # Disable SDDM when GNOME/GDM is active (avoids conflict with sway module)
    services.displayManager.sddm.enable = lib.mkForce false;
    services.desktopManager.gnome = {
      enable = true;
      # Configure GNOME power management
      extraGSettingsOverridePackages = with pkgs; [ gnome-settings-daemon ];
      extraGSettingsOverrides = ''
        [org.gnome.desktop.session]
        idle-delay=0

        [org.gnome.settings-daemon.plugins.power]
        sleep-inactive-ac-type='nothing'
        sleep-inactive-ac-timeout=0
      '' + lib.optionalString config.desktops.gnome.laptop ''
        sleep-inactive-battery-type='suspend'
        sleep-inactive-battery-timeout=1200
      '';
    };

    # Configure keyboard layout
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # Enable CUPS for printing
    services.printing.enable = lib.mkDefault true;

    # Exclude default GNOME packages we don't want
    environment.gnome.excludePackages = with pkgs; [
      gnome-console
    ];

    # Ensure Wayland is available for electron apps
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    # Add clipboard support for Wayland
    environment.systemPackages = with pkgs; [
      wl-clipboard
    ];

    # Laptop-specific configuration
    services.libinput.enable = lib.mkIf config.desktops.gnome.laptop true;
    services.upower.enable = lib.mkIf config.desktops.gnome.laptop true;
    services.power-profiles-daemon.enable = lib.mkIf config.desktops.gnome.laptop true;
  };
}
