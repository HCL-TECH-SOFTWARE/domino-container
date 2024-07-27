---
layout: default
title: "Run in production"
nav_order: 3
parent: "Concept & Overview"
description: "Run in production"
has_children: false
---

# Running Domino Containers in Production

To understand how to best run Domino containers in production environments, we first need to look at what a Domino container really is. A container image is a thin virtualization layer on top of Linux, using resources like the kernel, file system, memory, and network from the underlying Linux operating system.

Running Domino in a container involves a container run-time on the Linux host machine. When considering the scalability of a Domino container, it is essential to understand the scalability and resource availability of the underlying environment. Additionally, there are special configuration options on the container side to better work on different run-times, which are handled in separate sections.

## Sizing a Domino Server in a Container Environment

Because a Domino container is essentially a Linux server with a thin virtualization layer, the system resource requirements and sizing are the same as for a Domino server on Linux. In contrast to most other container-based software, Domino is not based on a micro service architecture with many small containers. A single Domino container needs all the resources another application would split into many separate containers.

This means all the storage, I/O, and RAM consumption is required for a single container in a similar way you would expect from a normal Linux server. When evaluating Domino in a hosted container platform or even in a corporate Kubernetes (K8s) environment, you should consider the expected resource requirements.

Consult your cloud provider or the internal team responsible for the container platform being planned for use. Cloud providers might have multiple offerings, often shared services, which might not be suitable for larger Domino server deployments based on the nature of the resource requirements.

## Storage Requirements

### NSF, NIF, FT
- Requires fast storage capable of handling many small (often 4K) random I/O operations.

### Transaction Logging (Translog)
- Requires low latency small 4K write operations.

### DAOS
- Uses larger block size (32K) sequential read/write operations. A DAOS NLO is written once and then read many times.

Because of the different storage performance and size requirements, splitting these directories into different volumes is important in the container world. NSF, NIF, FT, and Translog should be hosted on the most performant storage available (like NVMe SSD-based storage today). DAOS is usually the largest storage block required and works well with standard disk storage.

### Planning Domino IOPS Requirements

Because of the nature of Domino databases, many smaller I/Os are involved in file operations. For a mail server, you should plan for 1 IOPS per user. Application server IOPS requirements highly depend on your application and should be measured in the existing environment before containerizing it.

### Special Considerations for Measuring Current IOPS

Additional RAM dramatically reduces read I/O operations on Linux. When measuring performance, make sure the machine has similar RAM sizing (or at least not lower than available in the new target environment). The file system cache is not part of a container itself; it is handled on the host platform by the kernel.

When moving from a Domino server on Linux to a container-based environment, the file system cache becomes a shared resource among all containers running on the host. If less file system caching is available, the I/O read requirements might be higher than on a local virtual machine with dedicated RAM resources for a single Domino server.

IOPS should be measured over at least a day, week, and month interval to include important peak situations. Database maintenance and view/FT updates have different I/O patterns than standard daily operations. Over a week, application usage might vary as well.

## Choosing the Right Container Platform

The right run-time to use depends on the requirements. Deploying a larger server in production should always use a server-type deployment like Docker, Podman, or Kubernetes. Hosted platforms usually use Kubernetes in one form or another. Depending on the services used, a Domino admin might not even see what technology is used. The beauty of containers is that they can be developed locally, distributed via container registries, and then deployed on different run-time platforms.

### Desktop Platforms

Developing on a desktop platform makes a lot of sense because these platforms provide a lot of tooling and integration. However, the target platform for larger deployments should always be a server-grade product.

#### Docker Desktop (Windows/Mac/Linux) and Rancher Desktop (Windows/Mac)

Both provide Docker and Kubernetes run-time and development environments to build containers. On Windows, the development environment leverages the Windows Subsystem for Linux (WSL2) . Consuming containers also works on Windows, but building your own container requires a Linux WSL instance.

### No Support for Apple Silicon

Because Domino, and specifically Java integrated with Domino, is currently only available for Intel/AMD x64 hardware, running on an ARM-based host platform is problematic from a performance and stability point of view. There is currently no solution to run a Domino container on Apple Silicon.

**Tip:** A workaround would be running a Linux machine on x64 hardware or using a Windows ARM-based container running Domino.  [UTM - Virtual Machines for Mac](https://mac.getutm.app/) would be a free and open-source solution, which would work well for a local VM. Commercial solutions might provide better integration for keyboard and other components, but for a Domino server running in the background, UTM would be sufficient.

### Running Docker/Podman in a Local Linux Environment

WSL runs its own instance of Linux on a Microsoft Linux kernel and can also be a local Docker container host. In that case, the Docker or Podman run-time is running inside the Linux instance within WSL using a shared kernel provided by WSL . This type of deployment is mainly intended for local developer/lab environments.

### Docker or Podman Running on a Linux Machine

Docker and Podman servers run on top of a container run-time like [containerd](https://containerd.io/) on a Linux host using the local resources almost 1:1  . In this scenario, usually a single Domino container runs on a Linux virtual machine.

In general, this approach could also be used to run multiple container instances on one Linux host. However, this requires binding containers to specific IPs or using different host ports for exposed services.

This type of platform allows the use of native Linux resources instead of container volumes and container network. Whenever possible, use the native resources like host network and native volumes, which map 1:1 to Linux resources.

### Host Network Instead of Container Network

In addition to performance overhead, a container network (bridged network) is a kind of NAT where original IP address information can be lost. The native IP address can be important for SMTP but also for HTTPS to handle IP-based lockouts and other functionality.

Be aware that in host mode all servers run as if they are on the Linux host. They would see each other and might have port conflicts if not binding a port to a specific IP or different ports. The network configuration in this deployment would be more like a partitioned server environment but with servers running in different containers.

### Running on Kubernetes (K8s)

On K8s, the performance really depends on what resources the K8s infrastructure allows the container to use. In a K8s cluster, storage is usually external to the machine in a SAN or NAS, which can have performance implications. A K8s environment on-prem and especially in the cloud is usually optimized for micro containers. Defining the resource needs for IOPS, RAM, and storage size, and discussing with the cloud provider or internal K8s team is an important planning step for a successful Domino container deployment on K8s.

Cloud providers usually provide their own type of storage which can have different type of I/O characteristics.

**Kubernetes CSI** (Container Storage Interface) is a standard for exposing storage systems to containerized workloads on Kubernetes . It allows storage vendors to develop plugins that expose new storage systems in Kubernetes without having to touch the core Kubernetes code.

---

### References

1. [WSL (Windows Subsystem for Linux)](https://docs.microsoft.com/en-us/windows/wsl/)
2. [UTM - Virtual Machines for Mac](https://mac.getutm.app/)
3. [Docker](https://www.docker.com/)
4. [Podman](https://podman.io/)
5. [containerd](https://containerd.io/)
6. [Kubernetes CSI](https://kubernetes-csi.github.io/docs/)

