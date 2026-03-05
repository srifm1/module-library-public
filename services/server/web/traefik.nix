{ config, lib, pkgs, ... }:

let
  cfg = config.services.traefik-server;

  # Generate Traefik file provider configuration in TOML format
  dynamicConfigFile = pkgs.writeText "traefik-dynamic.toml" (
    lib.concatStringsSep "\n" (
      # HTTP routers and services
      (lib.mapAttrsToList (name: service: ''
        [http.routers.${name}]
        rule = "Host(`${service.domain}`)"
        service = "${name}"
        entryPoints = [${if service.enableHTTPS then "\"websecure\"" else "\"web\""}]
        ${lib.optionalString service.enableHTTPS ''
        [http.routers.${name}.tls]
        certResolver = "letsencrypt"
        ''}

        [http.services.${name}.loadBalancer]
        [[http.services.${name}.loadBalancer.servers]]
        url = "${service.backend}"
      '') cfg.services)
      ++
      # HTTPS redirect middleware if enabled
      (lib.optional cfg.httpsRedirect ''
        [http.middlewares.https-redirect.redirectScheme]
        scheme = "https"
        permanent = true
      '')
    )
  );

in {
  options.services.traefik-server = {
    enable = lib.mkEnableOption "Traefik reverse proxy";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/storage/data/traefik";
      description = "Directory for Traefik state and ACME certificates. Defaults to /storage/data for persistence on virtiofs mounts.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "example.com";
      description = "Base domain for services";
      example = "services.example.com";
    };

    services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          domain = lib.mkOption {
            type = lib.types.str;
            description = "Full domain name for this service";
            example = "app.example.com";
          };

          backend = lib.mkOption {
            type = lib.types.str;
            description = "Backend URL (including protocol and port)";
            example = "http://localhost:8080";
          };

          enableHTTPS = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable HTTPS with Let's Encrypt for this service";
          };
        };
      });
      default = {};
      description = "Services to proxy";
      example = lib.literalExpression ''
        {
          jellyfin = {
            domain = "jellyfin.example.com";
            backend = "http://localhost:8096";
            enableHTTPS = true;
          };
          sonarr = {
            domain = "sonarr.example.com";
            backend = "http://localhost:8989";
            enableHTTPS = true;
          };
        }
      '';
    };

    dashboardEnable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Traefik dashboard (accessible on port 8080)";
    };

    httpsRedirect = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically redirect HTTP to HTTPS";
    };

    letsEncrypt = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Let's Encrypt HTTPS certificate generation";
      };

      email = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Email address for Let's Encrypt certificate notifications";
        example = "admin@example.com";
      };

      staging = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use Let's Encrypt staging server (for testing)";
      };
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open HTTP/HTTPS ports in the firewall";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "DEBUG" "INFO" "WARN" "ERROR" ];
      default = "INFO";
      description = "Traefik log level";
    };
  };

  config = lib.mkIf cfg.enable {
    # Assertions to validate configuration
    assertions = [
      {
        assertion = cfg.services != {};
        message = "Traefik enabled but no services configured. Add services or disable Traefik.";
      }
      {
        assertion = !cfg.letsEncrypt.enable || cfg.letsEncrypt.email != "";
        message = "Let's Encrypt requires an email address to be configured";
      }
      {
        assertion = !cfg.letsEncrypt.enable || lib.any (s: s.enableHTTPS) (lib.attrValues cfg.services);
        message = "Let's Encrypt is enabled but no services have enableHTTPS set to true";
      }
      {
        assertion = cfg.domain != "";
        message = "Domain cannot be empty";
      }
    ];

    services.traefik = {
      enable = true;

      dynamicConfigFile = dynamicConfigFile;

      staticConfigOptions = {
        # Entrypoints
        entryPoints = {
          web = {
            address = ":80";
          } // lib.optionalAttrs cfg.httpsRedirect {
            http.redirections.entrypoint = {
              to = "websecure";
              scheme = "https";
            };
          };
        } // lib.optionalAttrs cfg.letsEncrypt.enable {
          websecure = {
            address = ":443";
          };
        };

        # Let's Encrypt certificate resolver
        certificatesResolvers = lib.mkIf cfg.letsEncrypt.enable {
          letsencrypt = {
            acme = {
              email = cfg.letsEncrypt.email;
              storage = "${cfg.dataDir}/acme.json";
              caServer = if cfg.letsEncrypt.staging
                then "https://acme-staging-v02.api.letsencrypt.org/directory"
                else "https://acme-v02.api.letsencrypt.org/directory";
              httpChallenge = {
                entryPoint = "web";
              };
            };
          };
        };

        # API and Dashboard
        api = lib.mkIf cfg.dashboardEnable {
          dashboard = true;
          insecure = true; # Dashboard on :8080
        };

        # Logging
        log = {
          level = cfg.logLevel;
        };

        accessLog = {};
      };
    };

    # Ensure Traefik state directory exists with proper permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 traefik traefik -"
    ] ++ lib.optional cfg.letsEncrypt.enable
      "f ${cfg.dataDir}/acme.json 0600 traefik traefik -";

    # Override systemd service to use custom dataDir instead of /var/lib/traefik
    systemd.services.traefik.serviceConfig = {
      ReadWritePaths = [ cfg.dataDir ];
      WorkingDirectory = lib.mkForce cfg.dataDir;
    };

    # Open firewall ports
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      [ 80 ]
      ++ lib.optional cfg.letsEncrypt.enable 443
      ++ lib.optional cfg.dashboardEnable 8080
    );
  };
}
