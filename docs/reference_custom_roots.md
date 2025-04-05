---
layout: default
title: "Custom Trusted Roots"
nav_order: 5
parent: "Reference"
description: "Custom Trusted Roots"
has_children: false
---

# Custom Linux trusted root certificate

Depending on the required configuration, the might be a need for adding custom trusted roots to Linux and/or Domino.
Specially on Linux level root certificates might be needed to verify corporate certificates, which are not trusted out of the box.

It is important to add a trusted root to the Linux trust store early in the build process to ensure all Linux based build functionality can leverage it.
The build script understands the logic to include for the most common Linux base images (Redhat, SUSE, Debian, Debian).


## How to add a trusted root

Linux comes with a pre-defined list of trusted root certificates.
To allow to use corporate trusted root, add a PEM formatted certificate file with the following name.
The container image built adds the root certificate to the container images trusted roots.
The root is used for example for OpenSSL and curl.

The Linux trusted root can by providing a PEM file with the following name to [dockerfiles/install_dir_domino/custom](https://github.com/HCL-TECH-SOFTWARE/domino-container/tree/main/dockerfiles/install_dir_domino/custom):

```
trusted_root.pem
```


# Custom Domino trusted root certificate

A second root certficate (or the same) can also be imported into Domino trust stores later in the image build logic when Domino is installed.

Domino uses multiple trust stores:

- **/local/notesdata/cacert.pem** used for HTTP Requests in Lotus Script and other backend code using curl
- **Domino JVM trust store** used by Java
- Domino Directory Trusted roots
- certstore.nsf Trusted roots

names.nsf and certstore.nsf can by managed in Domino and is replicated within the domain.


## How to add a trusted root

The PEM file and JVM trusted roots can be updated by providing a PEM file with the following name to `dockerfiles/install_dir_domino/custom`:

```
trusted_domino_root.pem
```

