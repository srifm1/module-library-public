{ config, lib, pkgs, ... }:

let
  cfg = config.services.media-common;
in {
  options.services.media-common = {
    enable = lib.mkEnableOption "shared media group and directory structure";

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Shared group name for media access across all services";
    };

    groupGid = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "GID for the media group. If null, system will assign automatically.";
    };

    mediaDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/media";
      description = "Base directory for media files";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data";
      description = "Base directory for service data/config";
    };

    directories = {
      movies = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.mediaDir}/movies";
        description = "Directory for movie files";
      };

      tv = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.mediaDir}/tv";
        description = "Directory for TV show files";
      };

      downloads = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.mediaDir}/downloads";
        description = "Directory for download files";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.group != "";
        message = "Media group name cannot be empty";
      }
    ];

    # Create shared media group
    users.groups.${cfg.group} = {
      gid = lib.mkIf (cfg.groupGid != null) cfg.groupGid;
    };

    # Create directories with proper permissions using systemd-tmpfiles
    systemd.tmpfiles.rules = [
      # Create main storage directories
      "d /storage 0755 root root -"
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.mediaDir} 0775 root ${cfg.group} -"

      # Create media subdirectories (group-writable for all services)
      "d ${cfg.directories.movies} 0775 root ${cfg.group} -"
      "d ${cfg.directories.tv} 0775 root ${cfg.group} -"
      "d ${cfg.directories.downloads} 0775 root ${cfg.group} -"
    ];
  };
}
