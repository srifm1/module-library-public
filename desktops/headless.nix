{ config, pkgs, lib, ... }:

{
  config = {
    # Headless/server profile - minimal configuration
    # Most services are disabled by default in NixOS, so we only need
    # to explicitly disable things that might be pulled in by other modules

    # Enable systemd-networkd for server networking
    networking.useNetworkd = lib.mkDefault true;
    networking.useDHCP = lib.mkDefault false;
    systemd.network.enable = lib.mkDefault true;
    systemd.network.wait-online.enable = lib.mkDefault false;

    # Disable X11
    services.xserver.enable = lib.mkDefault false;

    # Disable sound (use mkDefault to allow overrides)
    services.pulseaudio.enable = false;
    services.pipewire.enable = lib.mkDefault false;

    # Disable printing (low priority so desktop overrides win)
    services.printing.enable = lib.mkOverride 1500 false;

    # Console-only environment - minimal packages
    environment.systemPackages = with pkgs; [
      vim
      wget
      curl
    ];
  };
}
