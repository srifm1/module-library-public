{ config, pkgs, lib, ... }:

{
  # Terminal Productivity Tools
  # This module provides terminal-based productivity and utility applications

  environment.systemPackages = with pkgs; [
    # Terminal multiplexing
    shpool # Session persistence for shell sessions

    # Terminal productivity tools can be added here
    # Examples might include:
    # - taskwarrior (task management)
    # - calcurse (calendar/scheduling)
    # - mutt/neomutt (email)
    # - newsboat (RSS reader)
    # - todo.txt-cli (simple task management)
  ];
}
