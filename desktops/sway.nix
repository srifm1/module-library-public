{ config, pkgs, lib, ... }:

{
  options.desktops.sway = {
    laptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable laptop-specific features (touchpad, power management)";
    };
  };

  config = {
    # Enable NetworkManager for desktop network management
    networking.networkmanager.enable = lib.mkDefault true;

    # Enable Sway window manager
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true; # Fixes GTK applications on Sway
      extraPackages = with pkgs; [
        # Core Wayland utilities
        swaylock
        swayidle

        # Application launcher
        rofi

        # Status bar
        waybar

        # Notification daemon
        swaynotificationcenter
        libnotify
        sound-theme-freedesktop

        # Screenshot utilities
        grim
        slurp
        wf-recorder
        sway-contrib.grimshot

        # Clipboard manager
        wl-clipboard

        # Display management
        wdisplays
        kanshi

        # Brightness and volume control
        brightnessctl
        pamixer
        pavucontrol

        # Network manager applet
        networkmanagerapplet

        # Authentication agent
        polkit_gnome

        # File manager
        pcmanfm

        # GTK theme configuration
        gnome-themes-extra
        gsettings-desktop-schemas
        lxappearance

        # Additional utilities
        sway-overfocus

        # Fonts and icons
        papirus-icon-theme
      ];
    };

    # XDG portal for Wayland screen sharing
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
    };

    # Enable display manager (SDDM works well with Sway)
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    # Configure keyboard layout
    services.xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    # Enable touchpad support (laptop only)
    services.libinput.enable = lib.mkIf config.desktops.sway.laptop true;

    # Enable CUPS for printing
    services.printing.enable = true;

    # Enable power management (laptop only)
    services.upower.enable = lib.mkIf config.desktops.sway.laptop true;
    services.power-profiles-daemon.enable = lib.mkIf config.desktops.sway.laptop true;

    # Wayland-specific environment variables
    environment.sessionVariables = {
      # Enable Wayland support for various toolkits
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";

      # XDG settings
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "sway";
    };

    # Enable dbus for inter-process communication
    services.dbus.enable = true;

    # Security wrapper for swaylock
    security.pam.services.swaylock = {};

    # Fonts for the desktop
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      font-awesome
      jetbrains-mono
      nerd-fonts.jetbrains-mono
    ];
  };
}
