---
layout: default
title: "Build images behind a proxy"
nav_order: 4
description: "Building Images on Docker behind a proxy"
parent: "Howto"
has_children: false
---

# Introduction

In a corporate environment a direct connection to GitHub, container registry and Linux repositories might not be possible.
All involved components support running behind a proxy, but might need a separate configuration.
The following information provides details about how to specify the proxy settings.

In some environments a local Linux repository server like a [RedHat Satellite server](https://www.redhat.com/en/technologies/management/satellite)
might be available and needs different preparation for container base images.

Also a local registry like [Harbor](https://goharbor.io/) might be used in your environment.
In this case container base images are usually downloaded from your internal repository.

Depending on your environment you might not need a proxy but different base image names pointing to your local registry.
In this case the admins responsible for maintaining the local registry should be able to provide you with the right information how to consume images in your corporate environment.

If you don't have a local registry or Linux repository cache, the following information help you to leverage a proxy connection to external resources.

## Select the right base image to consume behind a proxy

In some environments proxy target addresses need to be explicitly white listed.
In those cases CentOS Stream and other distributions working with a larger mirror list, are not the best choice.

The default RedHat Universal Base Image (UBI) uses a fixed target address, which can be included in a corporate proxy allow list.

## Example Proxy white list for Redhat

The following white list entries would be currently required for consuming Redhat images.

- **Redhat Registry**  
  registry.access.redhat.com
- **Redhat Quary registry CDN**  
  *.quay.io
- **Redhat UBI Linux update repository**  
  cdn-ubi.redhat.com

## Proxy white list for HCL Software downloads

```
https://my.hcltechsw.com
https://api.hcltechsw.com
https://ds_infolib.hcltechsw.com
https://d1rvrben0dw4ya.cloudfront.net
```

## Proxy white list for accessing GitHub

```
https://github.com
https://raw.githubusercontent.com
```


# Build requirements

In general the following requirements are important

- Docker needs to be able to pull images
- The container image build Linux needs to have access to a repository server to load new packages and update existing packages

If you have an internal repository server for Linux updates for the base image you choose, you want to point image to that repository.
In this case you might want to build your own base image containing the right repository URLs like you configure your normal Linux servers.

But sometimes your host OS and the container image might differ and you want to pull the Linux packages from a trusted external resource.
In some cases customers even restrict the target URLs on their proxy, which can be also problematic.
But in this case your Squid proxy access.log or equivalent on your proxy is your friend.

Once you figured out where and how you get your base image and Linux updates, you can start setting the configuration.

# Configure proxy on Docker host

Once Docker has a proxy setting, it will pass the proxy to the container during build via environment variables.
Those settings are picked up by your build container.

For local connections I had to modify the build logic to exclude the NGINX local hosting IP, which would have gone thru the proxy too.
Curl in the currently used versions in most distributions does not yet allow to exclude IP ranges.
Therefore only the IP address of the NGINX instance is excluded.

In a local environment you might have local resources which can't use the proxy.
To exclude targets by domain specify the no proxy setting as well as shown in the examples below.


Edit the Docker systemd file `/usr/lib/systemd/system/docker.service` to update the environments variables.

```
vi /usr/lib/systemd/system/docker.service
```

## Example for a Squid proxy

```
Environment=https_proxy=http://192.168.96.99:3128
Environment=http_proxy=http://192.168.96.99:3128
Environment=no_proxy=notes.lab
```

## Reload the systemd configuration and restart Docker

```
systemctl daemon-reload
systemctl restart docker
```

# Configure proxy on Docker client

The Docker client also requires proxy settings to download container images.
Edit or create the Docker configuration file in your home directory.

```
mkdir ~/.docker
vi ~/.docker/config.json
```

Specify the proxy configuration like shown in this example.

```
{
  "proxies": {
    "default": {
      "httpProxy": "http://192.168.96.99:3128",
      "httpsProxy": "http://192.168.96.99:3128",
      "noProxy": "notes.lab"
     }
  }
}
```

## Configure proxy for your current session for curl, git and other operations

Usually the proxy should be already set on OS level.
But if it is not generally set, you can export the proxy using environment variables in your current session or in your profile.

```
export https_proxy=http://192.168.96.99:3128
export http_proxy=http://192.168.96.99:3128
export no_proxy=notes.lab
```


This last step might not be needed for a Docker build, but would be useful for curl and other operations.
Your admin might have already globally set the proxy in your environment.
Else also for pulling Linux updates or installing packages on your host needs the proxy (unless you configured a local repository cache)

The proxy would be also used by your Git client to pull updates from GitHub.
