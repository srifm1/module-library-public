# NFS Storage Client Profile
# Standard 3-mount NFS client configuration for physical hosts
# Mounts: backups, data, media from the NFS server defined in network-spec
{ ... }:

let
  networkSpec = import ../network-spec.nix;
in
{
  imports = [ ../services/client/fileshare/nfs.nix ];

  services.client.fileshare.nfs = {
    enable = true;
    mounts = {
      backups = {
        server = networkSpec.nfsServer;
        remotePath = "/storage/backups";
        mountPoint = "/storage/backups";
        automount = true;
        softMount = true;
      };
      data = {
        server = networkSpec.nfsServer;
        remotePath = "/storage/data";
        mountPoint = "/storage/data";
        automount = true;
        softMount = true;
      };
      media = {
        server = networkSpec.nfsServer;
        remotePath = "/storage/media";
        mountPoint = "/storage/media";
        automount = true;
        softMount = true;
      };
    };
  };
}
