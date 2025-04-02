---
layout: default
title: "Docker or Podman?"
nav_order: 9
parent: "Reference"
description: "Docker or Podman?"
has_children: false
---


# Docker or Podman?

Docker and Podman are both container run-time and build environments which work very similar, but have differences you should know about.

Podman is shipped with Redhat and CentOS based distributions, because Redhat is pushing Podman.
Most distributions support Docker and Podman but often the Docker version is not up to date in the base Linux installation.

For Docker the recommended installation option is to use the [official Docker installation steps](https://docs.docker.com/engine/install/) and the Docker provided repositories.

Because of the daemon-less approach of Podman, Docker is often the easier to use option.
If you are not an expert and if there is no corporate requirement for Podman, the recommendation is clearly to use Docker

Podman has specific Redhat registry integration.
When working in the Redhat universe and need end to end image validation, Podman might still be the better choice.
Podman can be setup to validate image signatures and only pull validated images, defined per registry.

The following section describes the key differences in more detail.
The Domino Container project fully supports both.
You should just not install both at the same time - unless you really know what you are doing.


# Podman vs. Docker


## **Daemon-Based vs. Daemonless Architecture**  
- **Docker**: Uses a centralized **daemon (`dockerd`)**, which manages all containers and images system-wide.  
  - The daemon runs as a background service, and all Docker commands interact with it.  
  - Since everything is managed centrally, containers and images are shared across all users by default.  
  - If `dockerd` is stopped, all managed containers are stoppped.  


- **Podman**: Is **daemonless**, meaning each container runs as a separate process managed by the user invoking the command.  
  - There is no single background service managing all containers, making Podman more modular.  
  - **Each user has their own independent container runtime and storage**, isolating images and containers per user.  


## **Automatic Container Start on System Boot**  

Since Docker has a long-running daemon, it includes built-in support for automatic container startup:  
  - **Restart Policies (`--restart`)**: When `dockerd` starts, it automatically restarts containers based on policies like `always`, `on-failure`, or `unless-stopped`.  
  - Containers are managed within the daemon, so the auto-restart mechanism is tightly integrated.  


Podman does not have a persistent background process, so it relies on **systemd** for container auto-start:  
  - Containers must be registered as **systemd services**.  
  - You can use `podman generate systemd` to create a service file for a container, then enable and start it with `systemctl`.  
  - This allows fine-grained control over container lifecycle management.  


## **Per-User Image and Container Management**  

- **Docker**:
  - Uses a **global storage** model where all images and containers are stored in `/var/lib/docker`.  
  - Since `dockerd` runs as a root-controlled process, all users on the system share the same container and image storage.  
  - If one user pulls an image or starts a container, all other users can see and use it (unless access is restricted manually).  


- **Podman**:
  - Uses a **per-user storage** model. Each user has their own container and image storage located in their home directory (`$HOME/.local/share/containers`).  
  - **Images and containers are isolated per user**, meaning one user's containers or images are not visible to another user by default.  
  - Users can still configure shared storage manually (e.g., via `/var/lib/containers`), but this is not the default behavior.  
  - This approach makes Podman better suited for multi-user environments where isolation is required.  


## **CLI Differences and Multi-Container Management**  


- **Docker**:
  - Uses a **single, unified CLI (`docker`)** for managing images, containers, and volumes.  
  - Requires `docker-compose` for managing multi-container applications.  

- **Podman**:
  - Maintains **CLI compatibility with Docker** (most `docker` commands work with `podman`).  
  - Lacks a native `docker-compose`. The alternative `podman-compose` still does not work well and it would be recommended to use docker-compose with Podman.  
  - Multi-container applications can also be deployed using **Kubernetes YAML files** (`podman play kube`).  

---


# **Summary Table**  

| Feature           | Docker | Podman |
|------------------|--------|--------|
| **Daemon**       | Requires `dockerd` | Daemonless |
| **Auto-start**   | Managed by `dockerd` restart policies | Uses `systemd` services |
| **Container Storage** | Shared among all users (`/var/lib/docker`) | Per-user storage (`$HOME/.local/share/containers`) |
| **Image Storage** | Shared among all users (`/var/lib/docker`) | Per-user storage (`$HOME/.local/share/containers`) |
| **Multi-container** | `docker-compose` | `podman-compose` or Kubernetes YAML |
| **Container Visibility** | All users see the same containers | Each user sees only their own containers |
| **Image Visibility** | All users see the same images | Each user sees only their own images |


