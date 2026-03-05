{ config, pkgs, lib, ... }:

{
  # Terminal Development Tools
  # This module provides terminal-based development and DevOps tools

  environment.systemPackages = with pkgs; [
    # Version control
    git
    git-lfs # Git Large File Storage extension
    lazygit # Terminal UI for git

    # Editors
    neovim

    # AI coding assistants
    claude-code
    ccshell # Claude Code shell wrapper
    gsd # Get Stuff Done - TUI task manager

    # Search and file tools
    ripgrep
    tree-sitter # Parser generator for treesitter grammars

    # System monitoring
    htop

    # Network filesystem
    sshfs

    # Build tools
    gnumake # Required for building some nvim plugins (e.g., LuaSnip)
    gcc # C compiler for native extensions

    # Cloud and DevOps
    azure-cli # Azure CLI - DISABLED: incompatible with Python 3.13
    powershell # Cross-platform PowerShell
  ];
}
