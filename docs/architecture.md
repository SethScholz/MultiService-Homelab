# Architecture

The server runs several containerized services on a single Ubuntu
Server host. Jellyfin, Sonarr, and Bazarr use Docker's default bridge
network and share access to the media filesystem. Minecraft is deployed
through Docker Compose on its own Compose-managed network.

## Hardware

| Component | Specification |
|---|---|
| CPU | Intel Core i5-13600K |
| RAM | 64 GB DDR4 |
| GPU | NVIDIA GTX 1650 Ti |
| Storage | 2 × 6 TB HDD |
| Storage configuration | Two RAID 1 arrays (~64 GiB root + ~5.33 TiB `/srv`) |
| OS | Ubuntu Server |

## Services

| Service | Container | Port | Deployment |
|---|---|---:|---|
| Jellyfin | `jellyfin` | 8096 | Docker |
| Sonarr | `sonarr` | 8989 | Docker |
| Bazarr | `bazarr` | 6767 | Docker |
| Minecraft | `minecraft` | 25565 | Docker Compose |

## Storage

Jellyfin, Sonarr, and Bazarr share the `/srv/shared/media`
filesystem for media storage.

Application configuration is persisted using bind mounts
under `/home/serelor/`.

Minecraft uses `/home/serelor/minecraft-serv` as its persistent
container data directory.

### Service relationships

```text
                         Ubuntu Server
                              |
                        Docker Engine
                              |
          +-------------------+-------------------+
          |                   |                   |
      Jellyfin             Sonarr              Bazarr
       :8096                :8989                :6767
          |                   |                   |
          +-------------------+-------------------+
                              |
                    /srv/shared/media
                              |
                           RAID 1
                        2 × 6 TB HDD

               Application configuration / cache
                              |
                        Bind-mounted
                              |
                    /home/serelor/<service>/
                              |
                              +----> Containers

                              +

                         Minecraft
                           :25565
                              |
                    minecraft-serv_default
                              |
                  /home/serelor/minecraft-serv
```

## Container Security

The Minecraft container runs as UID/GID `1000:1000` rather than as root. Linux capabilities are dropped and `no-new-privileges` is
enabled to reduce the container's ability to perform privileged operations or escalate privileges.

The container's `/tmp` directory is provided as a temporary `tmpfs` filesystem rather than persistent host storage.

## Design Decisions

- Docker is used to isolate application workloads from the host system.
- Bind mounts are used for persistent application data and shared media.
- RAID 1 provides redundancy against failure of a single storage device.
- Minecraft is managed with Docker Compose to keep its container configuration declarative and reproducible.
- The Minecraft container is explicitly hardened by running as a non-root UID/GID, dropping Linux capabilities, and enabling `no-new-privileges`.
