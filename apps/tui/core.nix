{ config, pkgs, lib, ... }:

{
  # Core Terminal (TUI) Applications
  # This module provides essential command-line utilities and networking tools

  environment.systemPackages = with pkgs; [
    # Network utilities
    wget
    curl

    # File management
    tree
    file
    which
    trash-cli
    gcc

    # Text processing
    jq
    yq

    # Archive tools
    unzip
    zip

    # Network Analysis
    iftop           # Interactive network traffic monitor (like top for network)
    nmap            # Network discovery and security auditing tool

    # Serial Communication
    # minicom       # DISABLED: lrzsz dependency fails to build on nixpkgs unstable

    # Additional useful networking tools
    traceroute      # Trace packet routes
    mtr             # Combines ping and traceroute functionality
    netcat          # Swiss army knife for TCP/IP
    tcpdump         # Packet analyzer
    wireshark-cli   # Terminal interface for Wireshark (tshark)
  ];
}
