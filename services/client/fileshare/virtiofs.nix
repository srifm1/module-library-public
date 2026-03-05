# virtiofs client module
# Mounts virtiofs shares from the host (e.g., from QEMU/KVM)

{ config, lib, pkgs, ... }:

let
  cfg = config.services.virtiofs-client;

  mountModule = lib.types.submodule {
    options = {
      tag = lib.mkOption {
        type = lib.types.str;
        description = "virtiofs tag name configured on the host";
        example = "storage-data";
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        description = "Path where the share will be mounted";
        example = "/storage/data";
      };

      options = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "rw" ];
        description = "Mount options";
        example = [ "rw" "noatime" ];
      };
    };
  };

in {
  options.services.virtiofs-client = {
    enable = lib.mkEnableOption "virtiofs client mounts";

    mounts = lib.mkOption {
      type = lib.types.attrsOf mountModule;
      default = {};
      description = "virtiofs mounts to configure";
      example = lib.literalExpression ''
        {
          data = {
            tag = "storage-data";
            mountPoint = "/storage/data";
          };
          media = {
            tag = "storage-media";
            mountPoint = "/storage/media";
            options = [ "rw" "noatime" ];
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable virtiofs filesystem support
    boot.supportedFilesystems = [ "virtiofs" ];

    # Configure virtiofs mounts
    fileSystems = lib.mapAttrs' (name: mount: lib.nameValuePair mount.mountPoint {
      device = mount.tag;
      fsType = "virtiofs";
      options = mount.options;
    }) cfg.mounts;

    # Create mount point directories
    systemd.tmpfiles.rules =
      # Create parent directories
      (lib.unique (map (mount:
        let parent = dirOf mount.mountPoint;
        in "d ${parent} 0755 root root -"
      ) (lib.attrValues cfg.mounts)))
      ++
      # Create mount points themselves
      (map (mount: "d ${mount.mountPoint} 0755 root root -") (lib.attrValues cfg.mounts));
  };
}
