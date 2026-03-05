{ config, pkgs, lib, ... }:

{
  # Bluetooth hardware support module
  # Enables Bluetooth with bluez stack and blueman GUI manager

  # Enable Bluetooth hardware and services
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = lib.mkDefault true;  # Configurable: override per-host with mkForce or higher priority
  };

  # Bluetooth management GUI (blueman)
  # Provides system tray applet and device manager
  services.blueman.enable = true;

  # Ensure required packages are available
  environment.systemPackages = with pkgs; [
    bluez
    bluez-tools
  ];
}
