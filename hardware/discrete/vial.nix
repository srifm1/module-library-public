# Vial Keyboard Support
# udev rules and package for Vial QMK keyboard configuration
#
# This module enables support for configuring QMK keyboards using
# the Vial firmware interface.

{ config, pkgs, lib, ... }:

{
  # Vial GUI application
  environment.systemPackages = with pkgs; [ vial ];

  # Vial udev rules for keyboard access
  # https://get.vial.today/manual/linux-udev.html
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';
}
