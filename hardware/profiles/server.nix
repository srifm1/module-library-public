{ config, pkgs, lib, ... }:

{
  # Server hardware profile
  # Optimized for headless server operation with reliability and remote management

  # Hardware support
  hardware = {
    # Enable firmware updates
    enableRedistributableFirmware = true;
    enableAllFirmware = true;

    # CPU microcode updates
    cpu.intel.updateMicrocode = lib.mkDefault true;
    cpu.amd.updateMicrocode = lib.mkDefault true;

    # Disable graphics acceleration (headless)
    graphics.enable = lib.mkDefault false;
  };

  # Disable audio (use services.pulseaudio path per NixOS 24.11+)
  services.pulseaudio.enable = false;

  # Boot configuration
  boot = {
    # Use stable kernel for servers
    kernelPackages = lib.mkDefault pkgs.linuxPackages;

    # UEFI boot with systemd-boot
    loader = {
      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = 20;  # Keep more generations for rollback
      };
      efi.canTouchEfiVariables = lib.mkDefault true;
      timeout = lib.mkDefault 10;  # Longer timeout for server boot
    };

    # No boot splash on servers
    plymouth.enable = false;

    # Kernel parameters for server
    kernelParams = [
      "console=tty0"
      "console=ttyS0,115200n8"  # Serial console for remote management
    ];

    # Enable watchdog for automatic recovery
    kernelModules = [ "iTCO_wdt" "softdog" ];
  };

  # Enable serial console getty for remote management
  systemd.services."serial-getty@ttyS0" = {
    enable = lib.mkDefault true;
    wantedBy = lib.mkDefault [ "getty.target" ];
    serviceConfig.Restart = lib.mkDefault "always";
  };

  # Console configuration
  console = {
    earlySetup = true;
    keyMap = lib.mkDefault "us";
  };

  # Watchdog for automatic recovery from hangs (NixOS 24.11+ option paths)
  systemd.settings.Manager = {
    RuntimeWatchdogSec = lib.mkDefault "30s";
    RebootWatchdogSec = lib.mkDefault "10m";
  };

  # Services optimized for servers
  services = {
    # Persistent journal for troubleshooting
    journald.extraConfig = ''
      Storage=persistent
      SystemMaxUse=1G
      MaxRetentionSec=1month
      Compress=yes
    '';

    # Time sync (critical for servers)
    chrony = {
      enable = lib.mkDefault true;
      servers = lib.mkDefault [
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
      ];
    };

    # SSH for remote management (essential)
    openssh = {
      enable = lib.mkDefault true;
      settings = {
        PermitRootLogin = lib.mkDefault "prohibit-password";
        PasswordAuthentication = lib.mkDefault false;
      };
    };

    # Fail2ban for security (optional but recommended)
    fail2ban = {
      enable = lib.mkDefault false;  # Can be enabled per-host
    };
  };

  # Power management (basic, not aggressive)
  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "performance";  # Performance for servers
  };

  # Disable unnecessary services
  services.xserver.enable = lib.mkDefault false;  # No GUI on servers

  # Security hardening
  security = {
    # Sudo configuration
    sudo = {
      wheelNeedsPassword = lib.mkDefault true;
      execWheelOnly = true;
    };

    # Audit framework
    auditd.enable = lib.mkDefault false;  # Can be enabled per-host
  };

  # Performance tuning for servers
  boot.kernel.sysctl = {
    # Server-optimized swappiness
    "vm.swappiness" = lib.mkDefault 10;

    # Conservative file cache management
    "vm.dirty_ratio" = lib.mkDefault 10;
    "vm.dirty_background_ratio" = lib.mkDefault 5;

    # Network tuning for servers
    "net.core.netdev_max_backlog" = lib.mkDefault 5000;
    "net.core.rmem_max" = lib.mkDefault 16777216;
    "net.core.wmem_max" = lib.mkDefault 16777216;
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 16777216";

    # Security hardening
    "net.ipv4.conf.all.rp_filter" = lib.mkDefault 1;
    "net.ipv4.conf.default.rp_filter" = lib.mkDefault 1;
    "net.ipv4.conf.all.accept_source_route" = lib.mkDefault 0;
    "net.ipv4.conf.default.accept_source_route" = lib.mkDefault 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = lib.mkDefault 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = lib.mkDefault 1;
  };

  # Nix settings optimized for server builds
  nix.settings = {
    max-jobs = lib.mkDefault "auto";
    cores = lib.mkDefault 0;  # Use all cores
  };

  # Keep documentation for servers (helpful for troubleshooting)
  documentation = {
    enable = lib.mkDefault true;
    nixos.enable = lib.mkDefault true;
    man.enable = lib.mkDefault true;
  };

  # Essential packages for server management
  environment.systemPackages = with pkgs; [
    vim
    htop
    tmux
    git
    curl
    wget
    rsync
    lsof
    tcpdump
    iotop
    sysstat
  ];

  # Automatic system upgrades (optional, disable if manual control preferred)
  system.autoUpgrade = {
    enable = lib.mkDefault false;  # Can be enabled per-host
    # dates = "04:00";
    # allowReboot = false;
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 30d";
  };
}
