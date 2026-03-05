{ config, lib, pkgs, ... }:

let
  cfg = config.services.nfs-server;

  # Helper function to generate export line
  mkExportLine = path: clients:
    "${path} ${lib.concatStringsSep " " (map (c: "${c.address}(${c.options})") clients)}";

in {
  options.services.nfs-server = {
    enable = lib.mkEnableOption "NFS server with configurable exports";

    exports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.path;
            description = "Directory path to export";
            example = "/storage/data";
          };

          clients = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                address = lib.mkOption {
                  type = lib.types.str;
                  description = "Client IP address or network (CIDR notation)";
                  example = "10.88.50.0/24";
                };

                options = lib.mkOption {
                  type = lib.types.str;
                  default = "rw,sync,no_subtree_check";
                  description = "NFS export options for this client";
                  example = "rw,sync,no_subtree_check,no_root_squash";
                };
              };
            });
            default = [];
            description = "List of clients allowed to access this export";
            example = lib.literalExpression ''
              [
                { address = "10.88.50.0/24"; options = "rw,sync,no_subtree_check"; }
                { address = "192.168.1.100"; options = "ro,sync"; }
              ]
            '';
          };
        };
      });
      default = {};
      description = "NFS exports configuration";
      example = lib.literalExpression ''
        {
          backups = {
            path = "/storage/backups";
            clients = [
              { address = "10.88.50.0/24"; options = "rw,sync,no_subtree_check,no_root_squash"; }
            ];
          };
          media = {
            path = "/storage/media";
            clients = [
              { address = "10.88.20.0/24"; options = "rw,sync,no_subtree_check"; }
              { address = "192.168.1.0/24"; options = "ro,sync,no_subtree_check"; }
            ];
          };
        }
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open NFS ports in the firewall";
    };

    nfsVersion = lib.mkOption {
      type = lib.types.enum [ 3 4 ];
      default = 4;
      description = "NFS protocol version to use";
    };
  };

  config = lib.mkIf cfg.enable {
    # Assertions to validate configuration
    assertions = [
      {
        assertion = cfg.exports != {};
        message = "NFS server enabled but no exports configured. Add exports or disable the service.";
      }
      {
        assertion = lib.all (export: export.clients != []) (lib.attrValues cfg.exports);
        message = "All NFS exports must have at least one client configured";
      }
    ];

    # Enable NFS server
    services.nfs.server = {
      enable = true;

      # Generate exports file from configuration
      exports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: export:
          mkExportLine export.path export.clients
        ) cfg.exports
      );
    };

    # Create exported directories using systemd-tmpfiles
    systemd.tmpfiles.rules = map (export:
      "d ${export.path} 0755 root root -"
    ) (lib.attrValues cfg.exports);

    # Open firewall ports for NFS if requested
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        2049  # NFS
        111   # portmapper
      ] ++ lib.optionals (cfg.nfsVersion == 3) [
        20048 # mountd (NFSv3)
      ];

      allowedUDPPorts = [
        2049  # NFS
        111   # portmapper
      ] ++ lib.optionals (cfg.nfsVersion == 3) [
        20048 # mountd (NFSv3)
      ];
    };
  };
}
