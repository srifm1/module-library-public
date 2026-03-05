# Media Services

This directory contains NixOS modules for media management services.

## Services

| Service | Description | Port |
|---------|-------------|------|
| Jellyfin | Media streaming server | 8096 |
| Sonarr | TV show manager | 8989 |
| Radarr | Movie manager | 7878 |
| Prowlarr | Indexer manager | 9696 |
| Jellyseerr | Media request interface | 5055 |
| qBittorrent | Torrent client | 8090 |

## Hardening Note

Services in this directory use two implementation patterns:

### Upstream Wrappers (jellyfin, sonarr, radarr)

These modules delegate to upstream NixOS service modules (`services.jellyfin`,
`services.sonarr`, etc.). Hardening is managed by upstream. We create static
users for predictable UIDs that persist across rebuilds.

### Custom Systemd Units (prowlarr, jellyseerr, qbittorrent)

These modules create custom `systemd.services` directly with comprehensive
hardening because upstream doesn't provide a NixOS service module:

- `PrivateTmp = true`
- `NoNewPrivileges = true`
- `ProtectSystem = "strict"`
- `ProtectHome = true`
- `ProtectKernelTunables/Modules/ControlGroups = true`
- `RestrictAddressFamilies`, `SystemCallFilter`, etc.

This difference is intentional - we only add hardening where we control the
service definition. Upstream-wrapped services inherit whatever hardening
(if any) the upstream NixOS module provides.

## Common Configuration

All media services:
- Use static users (not DynamicUser) for predictable file ownership
- Default to `/storage/data/{service}` for persistence on virtiofs mounts
- Share the `media` group for cross-service file access
- Use `media-common` module for shared group and directory setup
