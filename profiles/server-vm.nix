# Server VM Profile
# Headless virtual machine server with TUI tools
# Imports: headless desktop + guest hardware + all TUI app modules
{ ... }:

{
  imports = [
    ../desktops/headless.nix
    ../hardware/profiles/guest.nix
    ../apps/tui/core.nix
    ../apps/tui/development.nix
    ../apps/tui/productivity.nix
  ];
}
