# Server Physical Profile
# Headless physical server with TUI tools
# Imports: headless desktop + server hardware + all TUI app modules
{ ... }:

{
  imports = [
    ../desktops/headless.nix
    ../hardware/profiles/server.nix
    ../apps/tui/core.nix
    ../apps/tui/development.nix
    ../apps/tui/productivity.nix
  ];
}
