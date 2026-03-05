# VirtioFS Storage Client Profile
# Standard VM virtiofs mounts for guests running on the hypervisor
# Mounts: storage-backups, storage-data, storage-media, secrets-key
{ lib, ... }:

{
  imports = [ ../services/client/fileshare/virtiofs.nix ];

  services.virtiofs-client = {
    enable = true;
    mounts = {
      backups = {
        tag = "storage-backups";
        mountPoint = "/storage/backups";
      };
      data = {
        tag = "storage-data";
        mountPoint = "/storage/data";
      };
      media = {
        tag = "storage-media";
        mountPoint = "/storage/media";
      };
      secrets-key = {
        tag = "secrets-key";
        mountPoint = lib.mkDefault "/run/secrets-key";
        options = [ "ro" ];
      };
    };
  };
}
