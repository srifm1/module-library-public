{ config, lib, pkgs, ... }:

let
  cfg = config.services.ttyd-server;

  # Wrapper script that sets XDG_RUNTIME_DIR before exec'ing the shell.
  # Without this, tools like shpool can't find the user session socket
  # (they fall back to ~/.local/run/ instead of /run/user/<uid>/).
  sessionWrapper = pkgs.writeShellScript "ttyd-session" ''
    export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
    exec ${cfg.shell}${lib.optionalString cfg.loginShell " -l"}
  '';
in {
  options.services.ttyd-server = {
    enable = lib.mkEnableOption "ttyd web-based terminal";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7681;
      description = "Port for ttyd web interface";
    };

    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Network interface to bind (null = all interfaces)";
    };

    shell = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.bash}/bin/bash";
      description = "Shell to spawn for terminal sessions";
    };

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Run shell as this user (null = ttyd service user)";
    };

    loginShell = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use login shell (sources profile)";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open ttyd port in the firewall";
    };

    writeable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow clients to write to the terminal";
    };

    clientOptions = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "xterm.js client options (fontSize, theme, etc.)";
      example = { fontSize = "16"; };
    };
  };

  config = lib.mkIf cfg.enable {
    services.ttyd = {
      enable = true;
      port = cfg.port;
      interface = cfg.interface;
      writeable = cfg.writeable;
      clientOptions = cfg.clientOptions;
      entrypoint =
        if cfg.user != null then
          [ "${pkgs.util-linux}/bin/runuser" "-l" cfg.user "--" "${sessionWrapper}" ]
        else
          [ cfg.shell ] ++ (if cfg.loginShell then [ "-l" ] else []);
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
