# Workstation Profile
# Desktop/laptop workstation with GUI apps, TUI tools, and Bluetooth
# Imports: sway desktop + desktop hardware + all GUI and TUI app modules + bluetooth
{ ... }:

{
  imports = [
    ../desktops/sway.nix
    ../hardware/profiles/desktop.nix
    ../apps/gui/core.nix
    ../apps/gui/development.nix
    ../apps/gui/gaming.nix
    ../apps/gui/productivity.nix
    ../apps/tui/core.nix
    ../apps/tui/development.nix
    ../apps/tui/productivity.nix
    ../hardware/discrete/bluetooth.nix
  ];
}
