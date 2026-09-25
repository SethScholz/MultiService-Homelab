# Deployment

This document describes the deployment and configuration of the server's containerized services.

## Host Environment

The server runs Ubuntu Server and uses Docker Engine to host the application workloads.

The server uses two RAID 1 arrays:

- `/dev/md0` — 64 GiB ext4 filesystem mounted at `/`
- `/dev/md1` — 5.33 TiB ext4 filesystem mounted at `/srv`

The shared media library is located at `/srv/shared/media`.

## Docker Services

The server runs four primary containerized services:

| Service | Image | Port | Deployment |
|---|---|---:|---|
| Jellyfin | `jellyfin/jellyfin:latest` | 8096 | Docker |
| Sonarr | `lscr.io/linuxserver/sonarr:latest` | 8989 | Docker |
| Bazarr | `lscr.io/linuxserver/bazarr:latest` | 6767 | Docker |
| Minecraft | `eclipse-temurin:17-jre` | 25565 | Docker Compose |

Jellyfin, Sonarr, and Bazarr use Docker's default bridge network.
Minecraft is managed separately through Docker Compose and uses its own Compose-created network.

## Host Setup

The server is a self-built system running Ubuntu Server with the
following hardware:

| Component | Specification |
|---|---|
| CPU | Intel Core i5-13600K |
| RAM | 64 GB DDR4 |
| GPU | NVIDIA GTX 1650 Ti |
| Storage | 2 × 6 TB-class HDD |
| Operating system | Ubuntu Server |

Persistent storage is provided by two RAID 1 arrays. See
[`storage.md`](storage.md) for the complete storage architecture.

## Storage Preparation

The server's storage is configured before deploying the containers.

Two RAID 1 arrays provide redundant storage:

- `/dev/md0` — 64 GiB ext4 filesystem mounted at `/`
- `/dev/md1` — 5.33 TiB ext4 filesystem mounted at `/srv`

The media directory is located at:

```text
/srv/shared/media
```

Jellyfin, Sonarr, and Bazarr access the media directory through Docker
bind mounts. Application configuration is stored separately under
`/home/serelor/`.

See [`storage.md`](storage.md) for the complete storage architecture.

## Service Deployment

### Jellyfin

Jellyfin is deployed as a Docker container using the official
`jellyfin/jellyfin:latest` image.

The container exposes port `8096` for the Jellyfin web interface and uses Docker's default bridge network.

Persistent data is stored on the host using bind mounts:

| Host path | Container path | Purpose |
|---|---|---|
| `/home/serelor/jellyfin/config` | `/config` | Application configuration |
| `/home/serelor/jellyfin/cache` | `/cache` | Application cache |
| `/srv/shared/media` | `/media` | Shared media library |

The container is configured with a restart policy of `unless-stopped`,
allowing Docker to automatically restart the service after a container
or host restart.

### Sonarr

Sonarr is deployed as a Docker container using the
`lscr.io/linuxserver/sonarr:latest` image.

The container exposes port `8989` and uses Docker's default bridge network.

Persistent data is stored using the following bind mounts:

| Host path | Container path | Purpose |
|---|---|---|
| `/home/serelor/sonarr/config` | `/config` | Application configuration |
| `/srv/shared/media` | `/media` | Shared media library |

The container uses a restart policy of `unless-stopped`.

### Bazarr

Bazarr is deployed as a Docker container using the `lscr.io/linuxserver/bazarr:latest` image.

The container exposes port `6767` and uses Docker's default bridge network.

Persistent data is stored using the following bind mounts:

| Host path | Container path | Purpose |
|---|---|---|
| `/home/serelor/bazarr/config` | `/config` | Application configuration |
| `/srv/shared/media` | `/media` | Shared media library |

The container uses a restart policy of `unless-stopped`.

### Minecraft

Minecraft is managed using Docker Compose from
`compose/minecraft/compose.yaml`.

The service uses the `eclipse-temurin:17-jre` image and mounts the Minecraft server directory into the container:

| Host path | Container path | Purpose |
|---|---|---|
| `/home/serelor/minecraft-serv` | `/data` | Minecraft server data |

The server listens on TCP port `25565` and runs on its own Compose-managed Docker network.

The container is configured with several security restrictions:

- Runs as UID/GID `1000:1000` rather than root.
- Drops all Linux capabilities.
- Enables `no-new-privileges`.
- Limits container memory to 10 GiB.
- Provides `/tmp` as a temporary `tmpfs` filesystem.

The container uses a restart policy of `unless-stopped`.

The Compose configuration is maintained in
[`../compose/minecraft/compose.yaml`](../compose/minecraft/compose.yaml).

## Verification

After deployment, the services can be verified using Docker's container status and logs.

To view the running containers:

```bash
docker ps
```

The expected services are:

| Container | Expected state | Port |
|---|---|---:|
| `jellyfin` | Running | 8096 |
| `sonarr` | Running | 8989 |
| `bazarr` | Running | 6767 |
| `minecraft` | Running | 25565 |

Minecraft can be inspected separately through Docker Compose:

```bash
cd compose/minecraft
docker compose ps
```

Container logs can be inspected with:

```bash
docker logs <container>
```

The host's storage and RAID status can also be verified:

```bash
df -hT
cat /proc/mdstat
```

A healthy RAID 1 array should show both member devices as active and
synchronized.

## Maintenance

Routine administration is performed using Docker and standard Linux system utilities.

Container status can be checked with:

```bash
docker ps
```

Container logs can be viewed with:

```bash
docker logs <container>
```

Minecraft is managed through Docker Compose:

```bash
cd compose/minecraft
docker compose ps
docker compose logs
docker compose restart
```

Filesystem utilization can be monitored with:

```bash
df -hT
```

RAID health can be checked with:

```bash
cat /proc/mdstat
```

The service configuration and deployment documentation are maintained
in this repository so that changes to the infrastructure can be
documented alongside the project.

