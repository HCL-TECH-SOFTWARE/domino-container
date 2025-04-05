---
layout: default
title: "Custom Repositories"
nav_order: 4
parent: "Reference"
description: "Custom Repositories"
has_children: false
---

# Custom Linux repository mirror configuration

Specially in corporate enviroments source/mirror repositories might need to be customized to update and install Linux packages from a locally trusted location instead downloading them from public sources.
In larger deployments a corporate image with the right adjusted repositories would make sense.
The Domino Container would then just be derived from the company container base image and inherit Linux packet sources, custom trusted roots and for example proxy configurations.

But for smaller environments or if Domino is the only impage the following functionality allows image customization at build time.


## Custom repository mirror configuration for Ubuntu/Debian

The following description expects custom files in [dockerfiles/install_dir_domino/custom](https://github.com/HCL-TECH-SOFTWARE/domino-container/tree/main/dockerfiles/install_dir_domino/custom).

To customize the mirror list for current Ubuntu and Debian, you can specify a custom repository file.
The following configuration has been only tested for Ubuntu 24.04 and Debian 12 and is only available for those two platforms today.

Hetzner for example provides a mirror for all their customers.
The project contains the source repository files, which can be copied into `dockerfiles/install_dir_domino/custom`.

Files need to have the following. You just need to copy the files into the right location.
The build process picks up the repository before starting to install Linux packages.

The directory [dockerfiles/install_dir_domino/linux_repositories](https://github.com/HCL-TECH-SOFTWARE/domino-container/tree/main/dockerfiles/install_dir_domino/linux_repositories)  contains example reposity files for Hetzner, which are a good example and are ready to use on Hetzner servers.


### Ubuntu 24.04 (Noble)

```
ubuntu_noble.sources
```

### Debian 12 (Bookworm)

```
debian_bookworm.sources
```

For Hetzner servers just copy the corresponding file to `dockerfiles/install_dir_domino/custom` with the corresponding name (`ubuntu_noble.sources`,  `debian_bookworm.sources`)


