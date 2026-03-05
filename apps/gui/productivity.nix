{ config, pkgs, lib, ... }:

{
  # Productivity Applications
  # This module provides GUI applications for office work, calculations, and remote access
  #
  # Note: Vial keyboard support moved to hardware/discrete/vial.nix

  environment.systemPackages = with pkgs; [
    # Office Suite
    libreoffice     # Full office suite - Writer, Calc, Impress, Draw

    # Utilities
    qalculate-gtk   # Advanced calculator with unit conversion and graphing

    # Remote Access
    remmina         # Remote desktop client - supports RDP, VNC, SSH, and more

    # Application Launcher
    wofi            # Wayland-native application launcher/menu

    # Media processing
    ffmpeg          # Audio/video encoding, decoding, and processing

    # File Management
    vifm            # Vim-like file manager with dual panes
  ];
}
