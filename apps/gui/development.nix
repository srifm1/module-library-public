{ config, pkgs, lib, ... }:

{
  # GUI Development Tools Module
  # This module provides integrated development environments (IDEs) and related GUI tools
  # for software development on desktop/laptop systems with graphical interfaces

  environment.systemPackages = with pkgs; [
    # Visual Studio Code
    # Microsoft's lightweight but powerful source code editor
    # Features extensive plugin ecosystem, integrated terminal, git support,
    # debugging capabilities, and support for numerous programming languages
    vscode

    # JetBrains IDEs
    # Professional development environments for various languages and frameworks

    # Rider - Cross-platform .NET IDE
    # Supports C#, VB.NET, F#, ASP.NET, JavaScript, TypeScript, and more
    jetbrains.rider

    # WebStorm - The smartest JavaScript IDE
    # Specialized for JavaScript, TypeScript, React, Vue, Angular development
    jetbrains.webstorm

    # PyCharm Professional - Python IDE for professional developers
    # Advanced Python development with web frameworks, databases, and scientific tools
    jetbrains.pycharm

    # DataGrip - Database IDE
    # Multi-engine database environment supporting PostgreSQL, MySQL, SQL Server, etc.
    jetbrains.datagrip
  ];
}
