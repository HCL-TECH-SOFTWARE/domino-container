
# Domino Container Project – Proxmox LXC Mode

## Overview

The Domino Container project traditionally builds container images for Docker and Kubernetes environments.
With the introduction of Proxmox LXC mode, the build system now supports generating native LXC templates that integrate tightly with Proxmox VE and ZFS.

This approach combines:

* Container-style deployment logic
* Native Linux runtime (systemd, SSH)
* ZFS-optimized storage architecture

The result is a highly efficient, low-overhead alternative to VM-based or Docker-based deployments, specifically optimized for Domino workloads.


## Key Features

* Native Proxmox LXC template generation
* systemd-based runtime environment
* Integrated SSH access
* Reuse of Domino container deployment logic
* ZFS-native storage model
* Versioned, shared `/opt` datasets
* Domino-aware `/local` data layout
* Automatic deployment via data tar mechanism


## Architecture Overview


```
+------------------------------------------------------------+
|                Domino Container Build System                |
+------------------------------------------------------------+
            |                     |                     |
            v                     v                     v
   +----------------+   +----------------------+   +------------------+
   |  LXC Template  |   |  /opt ZFS Dataset    |   |  Domino Data Tar |
   |                |   |  (versioned)         |   |                  |
   | - Base OS      |   | - Domino binaries    |   | - notes.ini      |
   | - systemd      |   | - Install resources  |   | - /local layout  |
   | - SSH enabled  |   | - Install tar        |   |                  |
   +----------------+   +----------------------+   +------------------+
            \_____________________|_____________________/
                                  |
                                  v
                    +----------------------------------+
                    |     Proxmox LXC Container        |
                    |----------------------------------|
                    | - systemd                        |
                    | - SSH                            |
                    | - /opt (read-only mount)         |
                    | - /local (ZFS subvolume)         |
                    +----------------------------------+
                                  |
                                  v
                    +----------------------------------+
                    |        systemd Service           |
                    |  (Domino start script wrapper)   |
                    +----------------------------------+
                                  |
                                  v
                    +----------------------------------+
                    |      Domino Start Script         |
                    |----------------------------------|
                    | - Check for new data tar         |
                    | - Deploy/update /local           |
                    | - Start Domino                   |
                    +----------------------------------+
                                  |
                   +--------------+--------------+
                   |                             |
                   v                             v
        +------------------------+    +------------------------+
        | Deploy Domino Data     |    | Start Existing Instance|
        +------------------------+    +------------------------+
                   \______________________/ 
                              |
                              v
                    +------------------------+
                    |   Domino Server        |
                    +------------------------+
```


## Startup Logic

### Docker / Kubernetes

* Uses `/entrypoint.sh`
* Handles:

  * Data deployment
  * Domino startup


### Proxmox LXC

* Uses systemd service and Domino start script

Startup flow:

```
Container Boot
     |
     v
systemd
     |
     v
Domino Service
     |
     v
Check for new data tar in /opt
     |
   +----+----+
   |         |
Deploy      Start
to /local   Existing
   |         |
   +----+----+
        |
        v
Domino running
```


## ZFS Storage Architecture

### Dataset Layout

```
ZFS Pool: rpool
│
├── rpool/data/domino-opt-20260413-1005
│     └── /opt
│
├── rpool/data/subvol-101-disk-0
│     └── /local
│         ├── notesdata
│         ├── translog
│         ├── daos
│         ├── nif
│         └── ft
│
├── rpool/data/subvol-102-disk-0
│     └── /local
│         ├── notesdata
│         ├── translog
│         ├── daos
│         ├── nif
│         └── ft
│
└── rpool/data/vm-200-disk-0
      └── ext4/xfs
```


## `/opt` – Shared Binary Layer

### Naming Convention

```
rpool/data/domino-opt-<timestamp>
```

Example:

```
rpool/data/domino-opt-20260413-1005
```

### Characteristics

* Independent ZFS dataset
* Versioned
* Mounted read-only
* Shared across multiple containers

### Contents

```
/opt
├── domino/
├── domino-container/
│     └── install_data_domino.taz
├── node_exporter/
└── nashcom/
```

All runtime components are contained in `/opt`:

* Domino binaries
* Deployment data tar
* Prometheus node exporter
* NashCom start logic


## `/local` – Domino Data Layer

### Directory Structure

```
/local
├── notesdata
├── translog
├── daos
├── nif
└── ft
```

### Characteristics

* ZFS subvolume per container
* Read-write
* Native ZFS behavior

### Data Roles

| Directory | Purpose             | I/O Pattern      | Rebuildable |
| --------- | ------------------- | ---------------- | ----------- |
| notesdata | Core databases      | Mixed            | No          |
| translog  | Transaction logging | Sequential write | No          |
| daos      | Attachments         | Large objects    | No          |
| nif       | View indexes        | Random R/W       | Yes         |
| ft        | Full-text indexes   | Batch/sequential | Yes         |



## Storage Model Comparison

```
Docker / Kubernetes                Proxmox LXC

zvol (block device)               ZFS subvolume
   ↓                                ↓
ext4/xfs                           native ZFS
   ↓                                ↓
mounted volume                     direct mount

Higher overhead                    Lower overhead
Indirect ZFS usage                 Native ZFS usage
```


## `/opt` Sharing Model

```
           rpool/data/domino-opt-20260413-1005
                       (read-only)
                          |
        +-----------------+-----------------+
        |                                   |
   LXC CT 101                          LXC CT 102
        |                                   |
   /opt (RO)                           /opt (RO)
   /local (RW)                         /local (RW)
```


## `/opt` Version Switching (Atomic Upgrades)

### Principle

A new `/opt` dataset is created for each build.
Containers switch to the new dataset and restart.

No in-place modification is performed.


## Versioned Datasets

```
rpool/data/domino-opt-20260413-1005
rpool/data/domino-opt-20260420-0915
```


## Switching Workflow

### Prepare new `/opt`

```
zfs create rpool/data/domino-opt-20260420-0915
```

Populate with:

* HCL Domino binaries
* `/opt/domino-container/install_data_domino.taz`
* Prometheus Node Exporter
* Nash!Com Dominoi Start Script


### Update container mount

```
pct set <CTID> -mp0 /rpool/data/domino-opt-20260420-0915,mp=/opt,ro=1
```


### Restart container

```
pct restart <CTID>
```


## Runtime Behavior After Switch

On restart:

1. systemd starts the Domino service
2. Domino start script runs
3. Script checks:

```
/opt/domino-container/install_data_domino.taz
```

4. If updated:

   * Deploys to `/local`
5. Starts Domino


## Rollback

Switch back to previous dataset:

```
pct set <CTID> -mp0 /rpool/data/domino-opt-20260413-1005,mp=/opt,ro=1
pct restart <CTID>
```


## Multi-Container Upgrade

```
Old version                     New version
domino-opt-20260413        domino-opt-20260420
        |                          |
     CT101                      CT101
     CT102                      CT102
```

Containers can be switched independently or in groups.


## Advantages of LXC Mode


### Performance

* No block device overhead
* Direct filesystem access


### Storage Efficiency

* Shared `/opt`
* No duplication of binaries
* ZFS compression and deduplication


### Flexibility

* Instant snapshots and clones
* Independent lifecycle for `/opt` and `/local`


### Operational Simplicity

* No Docker runtime required
* systemd and SSH available
* Native Proxmox integration


## Architecture Summary

This design introduces three layers:

1. Immutable shared layer
   `/opt` as versioned ZFS dataset

2. Mutable instance layer
   `/local` as per-container ZFS subvolume

3. Execution layer
   LXC container with systemd and Domino start logic


## Final Summary

The Proxmox LXC mode extends the Domino Container project by:

* Bringing container-style deployment into a native LXC environment
* Leveraging ZFS datasets and subvolumes directly
* Preserving consistent startup and deployment logic
* Aligning with Domino’s internal data architecture

This results in a deployment model that is efficient, flexible, and optimized for Domino workloads
leveraging LXC technology -- native Proxmox deployment method.



