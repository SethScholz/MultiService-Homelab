## Storage

The server uses two 6 TB-class HDDs partitioned identically. Each disk contains an EFI partition and two RAID member partitions.

The operating system uses a 64 GiB RAID 1 array mounted at `/`. A second RAID 1 array provides 
approximately 5.33 TiB of usable storage and is mounted at `/srv`.

The `/srv` filesystem contains the shared media storage used by Jellyfin, Sonarr, and Bazarr.

## Physical Storage

Each disk contains three partitions:

| Partition | Size | Purpose |
|---|---:|---|
| `sda1` / `sdb1` | ~1 GB | EFI System Partition |
| `sda2` / `sdb2` | 64 GB | RAID 1 member for `/` |
| `sda3` / `sdb3` | ~5.4 TB | RAID 1 member for `/srv` |

The two disks are approximately 5.5 TB in capacity each.

## RAID Configuration

Two independent RAID 1 arrays are used:

| Array | RAID level | Usable capacity | Filesystem | Mount point |
|---|---|---:|---|---|
| `/dev/md0` | RAID 1 | 64 GiB | ext4 | `/` |
| `/dev/md1` | RAID 1 | 5.33 TiB | ext4 | `/srv` |

Both arrays currently report a `clean` state with two active and synchronized devices.

### Root Array

`/dev/md0` consists of:

```text
/dev/sda2 ──┐
            ├── RAID 1 ── /dev/md0 ── ext4 ── /
/dev/sdb2 ──┘
```

### Data Array

`/dev/md1` consists of:

```text
/dev/sda3 ──┐
            ├── RAID 1 ── /dev/md1 ── ext4 ── /srv
/dev/sdb3 ──┘
```

## Filesystem Utilization

Current filesystem utilization:

| Mount point | Size | Used | Available | Utilization |
|---|---:|---:|---:|---:|
| `/` | 63 GB | 28 GB | 33 GB | 46% |
| `/srv` | 5.3 TB | 3.3 TB | 1.9 TB | 65% |
| `/boot/efi` | 1.1 GB | 6.4 MB | 1.1 GB | 1% |

The `/srv` filesystem is the primary data filesystem and currently uses approximately 65% of its available capacity.

## Media Storage

The shared media library is stored under `/srv/shared/media` and is accessed by Jellyfin, Sonarr, and Bazarr through Docker bind mounts.

| Directory | Approximate size |
|---|---:|
| `anime` | 1001 GB |
| `books` | 473 MB |
| `movies` | 428 GB |
| `tv` | 1.8 TB |

## Persistent Application Data

Application configuration and service data are stored outside the containers using Docker bind mounts.

| Application | Host path | Purpose |
|---|---|---|
| Jellyfin | `/home/serelor/jellyfin/config` | Configuration |
| Jellyfin | `/home/serelor/jellyfin/cache` | Cache |
| Sonarr | `/home/serelor/sonarr/config` | Configuration |
| Bazarr | `/home/serelor/bazarr/config` | Configuration |
| Minecraft | `/home/serelor/minecraft-serv` | Server data |

Using bind mounts allows containers to be recreated without removing
their persistent application data.

## RAID Considerations

RAID 1 maintains a mirrored copy of data on both member disks. The current configuration provides redundancy against failure of a single member disk in either RAID array.

RAID is not a substitute for backups. It does not protect against accidental deletion, filesystem corruption, malware, or simultaneous failure of both disks.
