# Self-Hosted Homelab Infrastructure

A self-hosted Linux server used to run containerized media and game
services, with redundant storage, container isolation, and automated
health monitoring.

## Overview

This project documents the design, deployment, and maintenance of a
self-built Ubuntu Server system running several containerized services.

The server provides:

- Media streaming through Jellyfin
- Automated media management through Sonarr and Bazarr
- A containerized Minecraft server
- RAID 1 storage for system and application data
- Automated infrastructure health checks

The infrastructure is managed using Linux, Docker, Docker Compose, and
Bash.

## Hardware

| Component | Specification |
|---|---|
| CPU | Intel Core i5-13600K |
| RAM | 64 GB DDR4 |
| GPU | NVIDIA GTX 1650 Ti |
| Storage | 2 × 6 TB-class HDD |
| Operating system | Ubuntu Server |

## Architecture

The server uses Docker to isolate application workloads from the host
system.

Jellyfin, Sonarr, and Bazarr use Docker's default bridge network and
share access to the media filesystem. Minecraft is managed separately
through Docker Compose on its own Compose-created network.

Persistent storage is provided by two RAID 1 arrays:

- `/dev/md0` — 64 GiB mounted at `/`
- `/dev/md1` — 5.33 TiB mounted at `/srv`

The shared media library is stored under:

```text
/srv/shared/media
```

See [`docs/architecture.md`](docs/architecture.md) for the complete
architecture documentation.

## Services

| Service | Technology | Port |
|---|---|---:|
| Jellyfin | Docker | 8096 |
| Sonarr | Docker | 8989 |
| Bazarr | Docker | 6767 |
| Minecraft | Docker Compose | 25565 |

Service configuration and deployment details are documented in
[`docs/deployment.md`](docs/deployment.md).

## Storage

The server uses two independent RAID 1 arrays to provide redundancy
against failure of a single member disk.

The `/srv` array provides approximately 5.33 TiB of usable storage for
the server's shared data.

RAID is used for redundancy and is not considered a substitute for
backups.

See [`docs/storage.md`](docs/storage.md) for the complete storage
configuration.

## Automation

The repository includes a Bash-based health check:

```bash
./scripts/healthcheck.sh
```

The script checks:

- Docker daemon availability
- Container state
- Application responsiveness
- Minecraft TCP availability
- RAID health
- Filesystem utilization
- System load
- Memory utilization

The script returns standard exit codes:

| Exit code | Status |
|---:|---|
| `0` | Healthy |
| `1` | Warning |
| `2` | Critical |

This allows the health check to be used manually or integrated with
future monitoring and automation.

## Security

The Minecraft container is configured with several container-level
security restrictions:

- Runs as a non-root UID/GID
- Drops all Linux capabilities
- Enables `no-new-privileges`
- Uses a memory limit
- Uses a temporary `tmpfs` filesystem for `/tmp`

These settings reduce the privileges available to the Minecraft
workload if the application is compromised.

## Documentation

- [`Architecture`](docs/architecture.md) — System architecture,
  hardware, services, storage, and container relationships
- [`Deployment`](docs/deployment.md) — Service deployment and
  operational procedures
- [`Storage`](docs/storage.md) — RAID configuration, filesystems,
  utilization, and persistent application data

## Technologies

- Ubuntu Server
- Linux
- Docker
- Docker Compose
- Bash
- Git
- RAID 1
- ext4
- Java
- Jellyfin
- Sonarr
- Bazarr
- Minecraft / Forge
