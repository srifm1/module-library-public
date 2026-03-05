{ config, pkgs, lib, ... }:

{
  # Gaming Applications
  # This module provides gaming-related packages and configuration
  #
  # Note: Firewall rules for Steam Remote Play and dedicated servers
  # should be configured separately if needed.

  # Enable Steam
  programs.steam = {
    enable = true;
  };

  # Additional gaming packages
  environment.systemPackages = with pkgs; [
    # steam is handled by programs.steam above
  ];
}
