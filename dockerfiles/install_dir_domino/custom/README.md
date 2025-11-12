
# Custom resources for Linux


This directory contains 

## Custom repository mirror configuration


To customize the mirror list for current Ubuntu and Debian, you can specify a custom repository file.


### Ubuntu 24.04 (Noble)

```
ubuntu_noble.sources
```

### Debian 12 (Bookworm)

```
debian_bookworm.sources
```


## Custom Linux tusted root certificate

Linux comes with a pre-defined list of trusted root certificates.
To allow to use corporate trusted root, add a PEM formatted certificate file with the following name.
The container image built adds the root certificate to the container images trusted roots.
The root is used for example for OpenSSL and curl.

```
trusted_root.pem
```


# Custom Domino tusted root certificate

Domino uses multiple trust stores:

- **/local/notesdata/cacert.pem** used for HTTP Requests in Lotus Script and other backend code using curl
- **Domino JVM trust store** used by Java
- Domino Directory Trusted roots
- certstore.nsf Trusted roots


names.nsf and certstore.nsf can be managed in Domino and is replicated within the domain.  
The PEM file and JVM trusted roots can be updated by providing a PEM file with the following name:

```
trusted_domino_root.pem
```


# Custom Domino Setup Logo

To replace the Domino Setup logo place a SVG file into the custom directory.
The standard Domino logo is placed into the domsetup web root.

```
domsetup-logo.svg
```


