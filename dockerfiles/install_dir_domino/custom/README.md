
# Custom resources for Linux


This directory contains 

## Custom repository mirror configuration


To customize the mirror list for current Ubuntu and Debian, you can specify a custom repository file.


### Hetzner Ubuntu 24.04 (Noble)

```
ubuntu_noble.sources
```

### Debian 12 (Bookworm)

```
debian_bookworm.sources
```


## Custom trusted root certificate

Linux comes with a pre-defined list of trusted root certificates.
To allow to use corporate trusted root, add a PEM formatted certificate file with the following name.
The container image built adds the root certificate to the container images trusted roots.
The root is used for example for OpenSSL and curl.

```
trusted_root.pem
```
