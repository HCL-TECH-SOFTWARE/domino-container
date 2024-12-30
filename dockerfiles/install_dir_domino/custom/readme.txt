
Custom resources directory used by the build process

ubuntu_noble.sources
--------------------

In case you or your provider has an Ubuntu APT mirror, this file allows to pass the repository to the build container.
The build container replaces the repository, before installing the packages.


Hetzner Ubuntu 24.04 (Noble)
----------------------------

When running container builds on Hetzner servers, copy the following file to 'ubuntu_noble.sources'.
The file contains Ubuntu Noble APT repositories as a HTTP resource.

ubuntu_noble.sources_hetzner

