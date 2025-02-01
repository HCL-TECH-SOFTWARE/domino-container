
# Use a custom mirror for Ubuntu and Debian packages

In case you or your provider has an Ubuntu APT mirror, this file allows to pass the repository to the build container.
The build container replaces the repository, before installing the packages.
Those repositories are only supported for certain platforms and code streams, because they need to be tested.

The functionality should work for corporate mirrors and also for provider mirrors.
Below you find the Ubnuntu and Debian mirrors from Hetzner which only work when building on Hetzner infrastructure.
They are a good example how a mirror file should look like.


## Hetzner Ubuntu 24.04 (Noble)

When running container builds on Hetzner servers, copy the following file to `ubuntu_noble.sources` in the custom directory one level up.
The file contains Ubuntu Noble APT repositories as a HTTP resource.

```
ubuntu_noble.sources_hetzner
```


## Debian 12 (Bookworm)

When running container builds on Hetzner servers, copy the following file to `debian_bookworm.sources`.
The file contains Debian 12 Bookworm APT repositories as a HTTP resource.

```
debian_bookworm.sources_hetzner
```

