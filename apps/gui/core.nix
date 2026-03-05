{ config, pkgs, lib, ... }:

{
  # Core GUI Applications
  # This module provides essential GUI applications including web browsers and multimedia tools

  # Firefox with program-specific enable
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    # Web Browsers
    microsoft-edge # Microsoft Edge - Chromium-based with MS integration
    # brave         # Privacy-focused Chromium browser
    # google-chrome # Google's proprietary Chrome browser

    # Media Viewers
    imv # Lightweight image viewer for Wayland and X11
    mpv # Powerful media player with minimal UI

    # Creative/Editing Tools
    gimp # GNU Image Manipulation Program - Photoshop alternative
    audacity # Audio editor and recorder
    # openshot-qt   # Video editor - DISABLED: depends on insecure qtwebengine
    # Alternative video editors to consider: kdenlive, shotcut, or davinci-resolve

    # Streaming and Recording
    obs-studio # Open Broadcaster Software - streaming and screen recording

    # Terminal
    alacritty
  ];
}
