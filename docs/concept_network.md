---
layout: default
title: "Container network"
nav_order: 7
parent: "Concept & Overview"
description: "Container network"
has_children: false
---

**Docker Native Networking and Container Networking**


## Introduction
Docker provides multiple networking options to enable communication between containers, hosts, and external networks.  
Two primary networking modes in Docker are

- **Bridge Networking** (container networking) 
- **Host Networking** (native networking).

Each mode has its advantages and trade-offs, making it crucial to choose the appropriate one based on the use case.

For production environments usually the host network makes most sense from performance and IP transparency point of view.  
The following abstract provides details, benefits and trade-offs for the different network modes.

Those different modes might also be impact the firewall configuration you have to take into account.  
When running a single Domino on a container host, there is no need to use a brigde network.  
The default configuration when running the container management script **dominoctl** is **host** networking.


## Docker Bridge Networking (Container Networking)


### Overview

Bridge networking is the default mode in Docker. When a container is launched without specifying a network, it is automatically connected to the default bridge network (`docker0`). Containers within the same bridge network can communicate with each other using container names as hostnames.


### How It Works

- A virtual Ethernet bridge (`docker0`) is created.
- Containers are assigned a private IP address within a subnet (e.g., `172.17.0.0/16`).
- Docker’s built-in NAT (Network Address Translation) allows outbound communication.
- Port mapping (`-p 8080:80`) is used to expose container ports to the host.


### Configuration Considerations

- Requires **port mapping** (`-p` flag) for external access.
- Introduces **overhead** due to NAT and user-space routing.
- Ideal for **multi-container applications** running within a single Docker host.
- Supports **container-to-container communication** without exposing ports externally.

---


## Docker Host Networking (Native Networking)


### Overview
Host networking mode removes the network isolation between the container and the host. The container shares the host’s network namespace, allowing it to use the host’s IP address and network interfaces directly.


### How It Works

- No virtual bridge or NAT is involved.
- The container runs on the same IP stack as the host.
- Services in the container listen directly on the host’s network interfaces.


### Performance and IP Visibility

- **Better Performance**: Eliminates the overhead of NAT and network translation, reducing latency and improving throughput.
- **Original IP Addresses**: Since the container uses the host’s network stack, incoming traffic retains the client’s original IP address.


### Configuration Considerations

- No need for **port mapping** (e.g., `-p` flags are ignored).
- Containers can **bind to the same ports** as the host, which may cause conflicts.
- Reduced **network isolation**, increasing potential security risks.

---


## Comparison Table: Benefits & Restrictions

| Feature            | Bridge Networking (Container Mode) | Host Networking (Native Mode) |
|:--------------------|:-----------------------------------|:------------------------------|
| **Performance**   | Lower due to NAT overhead        | Higher, no NAT involved      |
| **IP Visibility** | Only sees host’s IP in logs      | Sees original client IP      |
| **Port Mapping**  | Required (`-p 8080:80`)         | Not needed, binds directly  |
| **Isolation**     | Better security, network sandboxing | Less isolation, shares host network |
| **Use Case**      | Multi-container apps, cloud deployments | High-performance, low-latency applications |
| **Security**      | More secure due to namespace isolation | Less secure, exposed to host vulnerabilities |


## How to configure both network modes

- For host network specify: `--network host` when launching the container with native Docker/Podman commands.
- When using the container runtime script **dominoctl** set `CONTAINER_NETWORK_NAME=host` (via dominoctl cfg)

- For bridged networking specify the exported ports via `-p host-port:container_port` for example: `-p 443:443` at Docker command line
- When using **dominoctl** specify the ports in the same format via `CONTAINER_PORTS=` (via dominoctl cfg)


---

## Key Takeaways

- **Use Bridge Networking** when container isolation, security, and controlled network communication are priorities.
- **Use Host Networking** when performance and direct access to the host’s network are required.
- Be cautious with **port conflicts** and **security implications** when using host mode.
- Choosing the right networking mode depends on the specific application needs, performance requirements, and security considerations.
- The default configuration using Docker/Podman out of the box is bridge networking and needs explicitly publish ports
- The default whe using **dominoctl** is host networking, which does not need any separate configuration

