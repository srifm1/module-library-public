# NFS Client Module
# Provides NFS client functionality for mounting remote NFS shares
#
# Features:
# - Mount remote NFS shares (NFSv3 and NFSv4)
# - Automatic mounting on access (automount)
# - Configurable mount options (soft/hard, timeouts, etc.)
# - Automatic creation of mount points
# - Support for multiple NFS servers
#
# Usage:
#   services.client.fileshare.nfs = {
#     enable = true;
#     mounts = {
#       backups = {
#         server = "fileserver";
#         remotePath = "/storage/backups";
#         mountPoint = "/storage/backups";
#         automount = true;
#         options = [ "rw" "soft" ];
#       };
#       data = {
#         server = "fileserver";
#         remotePath = "/storage/data";
#         mountPoint = "/storage/data";
#       };
#     };
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.services.client.fileshare.nfs;

  # Default mount options for NFS
  defaultOptions = [
    "_netdev"                    # Network device
    "x-systemd.device-timeout=5s"  # Wait time for device
    "x-systemd.mount-timeout=5s"   # Mount timeout
  ];

  # Options for automount
  automountOptions = [
    "x-systemd.automount"        # Mount on access
    "noauto"                     # Don't mount at boot
    "x-systemd.idle-timeout=60"  # Unmount after idle
  ];

  # Build mount options for a mount configuration
  buildMountOptions = mountCfg:
    let
      base = defaultOptions ++ mountCfg.extraOptions;
      withAutomount = if mountCfg.automount then base ++ automountOptions else base;
      withVersion = if mountCfg.nfsVersion != null
        then withAutomount ++ [ "nfsvers=${toString mountCfg.nfsVersion}" ]
        else withAutomount;
      withMountType = if mountCfg.softMount
        then withVersion ++ [ "soft" "intr" ]
        else withVersion ++ [ "hard" ];
      withRw = if mountCfg.readOnly
        then withMountType ++ [ "ro" ]
        else withMountType ++ [ "rw" ];
    in
    withRw;

  # Build device string for NFS mount
  buildDevice = mountCfg: "${mountCfg.server}:${mountCfg.remotePath}";

  # Extract parent directory from mount point
  parentDir = mountPoint:
    let
      parts = lib.splitString "/" mountPoint;
      parentParts = lib.init parts;
    in
    lib.concatStringsSep "/" parentParts;

in
{
  options.services.client.fileshare.nfs = {
    enable = lib.mkEnableOption "NFS client service";

    mounts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          server = lib.mkOption {
            type = lib.types.str;
            description = "NFS server hostname or IP address";
            example = "fileserver.local";
          };

          remotePath = lib.mkOption {
            type = lib.types.str;
            description = "Remote path on the NFS server";
            example = "/storage/data";
          };

          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Local mount point path";
            example = "/mnt/data";
          };

          nfsVersion = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum [ 3 4 ]);
            default = null;
            description = ''
              NFS protocol version to use (3 or 4).
              If null, the system will negotiate automatically.
            '';
            example = 3;
          };

          automount = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Enable automounting. The share will be mounted on first access
              and unmounted after idle timeout.
            '';
          };

          idleTimeout = lib.mkOption {
            type = lib.types.int;
            default = 60;
            description = ''
              Seconds of idle time before automatic unmount.
              Only applies when automount is enabled.
            '';
          };

          softMount = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Use soft mount (return errors if server is unreachable).
              If false, uses hard mount (retry indefinitely).
              Soft mounts are recommended to prevent system hangs.
            '';
          };

          readOnly = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Mount the share as read-only";
          };

          extraOptions = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Additional mount options to pass to mount.nfs";
            example = [ "noatime" "nodiratime" ];
          };

          createMountPoint = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Automatically create the mount point directory";
          };

          mountPointOwner = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "Owner of the mount point directory";
            example = "andrew";
          };

          mountPointGroup = lib.mkOption {
            type = lib.types.str;
            default = "root";
            description = "Group of the mount point directory";
            example = "users";
          };

          mountPointMode = lib.mkOption {
            type = lib.types.str;
            default = "0755";
            description = "Permissions mode for the mount point directory";
            example = "0755";
          };
        };
      }));
      default = {};
      description = "NFS mount configurations";
      example = lib.literalExpression ''
        {
          backups = {
            server = "fileserver";
            remotePath = "/storage/backups";
            mountPoint = "/storage/backups";
            automount = true;
            nfsVersion = 3;
          };
          data = {
            server = "192.168.1.100";
            remotePath = "/export/data";
            mountPoint = "/mnt/nfs/data";
            softMount = false;
            readOnly = false;
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable NFS support
    boot.supportedFilesystems = [ "nfs" "nfs4" ];

    # Install NFS utilities
    environment.systemPackages = with pkgs; [ nfs-utils ];

    # Enable rpcbind service for NFS (required for NFSv3)
    services.rpcbind.enable = true;

    # Configure NFS mounts
    fileSystems = lib.listToAttrs (lib.mapAttrsToList (name: mountCfg: {
      name = mountCfg.mountPoint;
      value = {
        device = buildDevice mountCfg;
        fsType = "nfs";
        options = buildMountOptions mountCfg;
      };
    }) cfg.mounts);

    # Create mount points and their parent directories
    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList (name: mountCfg:
      let
        parent = parentDir mountCfg.mountPoint;
      in
      lib.optionals mountCfg.createMountPoint (
        # Create parent directory first (if not root)
        (lib.optional (parent != "" && parent != "/")
          "d ${parent} ${mountCfg.mountPointMode} ${mountCfg.mountPointOwner} ${mountCfg.mountPointGroup} -")
        ++ [
          # Create mount point
          "d ${mountCfg.mountPoint} ${mountCfg.mountPointMode} ${mountCfg.mountPointOwner} ${mountCfg.mountPointGroup} -"
        ]
      )
    ) cfg.mounts);
  };
}
