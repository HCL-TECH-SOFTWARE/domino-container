# Domino Docker Containers

[![HCL Domino](https://img.shields.io/badge/HCL-Domino-ffde21?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB2aWV3Qm94PSIwIDAgNzE0LjMzIDcxNC4zMyI+PGRlZnM+PHN0eWxlPi5jbHMtMXtmaWxsOiM5M2EyYWQ7fS5jbHMtMntmaWxsOnVybCgjbGluZWFyLWdyYWRpZW50KTt9PC9zdHlsZT48bGluZWFyR3JhZGllbnQgaWQ9ImxpbmVhci1ncmFkaWVudCIgeDE9Ii0xMjA3LjIiIHkxPSItMTQzIiB4Mj0iLTEwMzguNjYiIHkyPSItMTQzIiBncmFkaWVudFRyYW5zZm9ybT0ibWF0cml4KDEuMDYsIDAuMTMsIC0wLjExLCAwLjk5LCAxMzUzLjcsIDYwMC42MikiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIj48c3RvcCBvZmZzZXQ9IjAiIHN0b3AtY29sb3I9IiNmZmRmNDEiLz48c3RvcCBvZmZzZXQ9IjAuMjYiIHN0b3AtY29sb3I9IiNmZWRjM2QiLz48c3RvcCBvZmZzZXQ9IjAuNSIgc3RvcC1jb2xvcj0iI2ZiZDIzMiIvPjxzdG9wIG9mZnNldD0iMC43NCIgc3RvcC1jb2xvcj0iI2Y2YzExZiIvPjxzdG9wIG9mZnNldD0iMC45NyIgc3RvcC1jb2xvcj0iI2VmYWEwNCIvPjxzdG9wIG9mZnNldD0iMSIgc3RvcC1jb2xvcj0iI2VlYTYwMCIvPjwvbGluZWFyR3JhZGllbnQ+PC9kZWZzPjxnIGlkPSJMYXllcl8zIiBkYXRhLW5hbWU9IkxheWVyIDMiPjxwb2x5Z29uIGNsYXNzPSJjbHMtMSIgcG9pbnRzPSI0MzcuNDYgMjgzLjI4IDMzNi40NiA1MDYuNjkgMjExLjY4IDUwNy40NSAzNjYuOTIgMTYyLjYxIDQzNy40NiAyODMuMjgiLz48cG9seWdvbiBjbGFzcz0iY2xzLTEiIHBvaW50cz0iNjQwLjU5IDMwNC4xIDUyOS4wMiA1NTEuOTYgMzUzLjYzIDU2Ni42MiA1NDIuMzIgMTQ3LjcxIDY0MC41OSAzMDQuMSIvPjxwb2x5Z29uIGNsYXNzPSJjbHMtMiIgcG9pbnRzPSIyNzMuMTkgMjY1LjM3IDE5MC4xMSA0NTAuMDYgNzMuNzQgNDM5LjI4IDE5NC4zMiAxNzEuMzMgMjczLjE5IDI2NS4zNyIvPjwvZz48L3N2Zz4K
)](https://www.hcl-software.com/domino)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/nashcom/buil-test/blob/main/LICENSE)


This project contains build scripts for HCL Domino Docker/Container images via [dockerfiles](https://docs.docker.com/engine/reference/builder/).
The repository provides the utilities to build HCL Domino Server with the latest software or specific version in a Docker/Container image.
There are separate folders within this repository for Domino add-on HCL products like Traveler and HCL Domino Leap  as well.

## You are looking to (just) configure & control Domino container instances - not to build containers?

You are in luck, just at the wrong place. Head over to [Nash!Com's Domino start script](https://github.com/nashcom/domino-startscript) and follow the instructions there. There is no need to use this repository.

## Where to get HCL Domino software

The project uses the official HCL web-kit installers to build container images download from the new official [My HCLSoftware Portal](https://my.hcltechsw.com/).

- All HCL customers with active maintenance should have a download account
- The [Partner Pack](https://www.hcltechsw.com/resources/partner-connect/resources/partner-pack) provides the same access for HCL Business Partners

See how to [download software](howto_download-software.md) for details.

## Supported environments

The project is supported on Docker Desktop, Docker Server, Podman, Rancher Desktop, Kubernetes (K8s) and OpenShift.
See detailed information about [supported run-time and build environments](docs/concept_environments.md).

## Documentation & Quickstart

See the [documentation](docs/index.md) and the [Quickstart](docs/quickstart.md) for details

## Issues
For issues relating specifically to the Dockerfiles and scripts, please use the [GitHub issue tracker](https://github.com/HCL-TECH-SOFTWARE/domino-container/issues)

## Contributing
We welcome contributions following [our guidelines](CONTRIBUTING.md).

## Community Support
Special Thanks go to the following people for having provided valuable input to this project

* [Ulrich Krause](https://www.eknori.de/2017-08-20/domino-on-docker/) for his very early contibutions in this space.
* Matteo Bisi for his [Presentation](https://www.slideshare.net/mbisi/connect2016-1172-shipping-domino).
* [Egor Margineanu](https://www.egmar.ro/) who also can be found on [Github](https://github.com/egmar)
* Thomas Hampel for initiating the original IBM Domino 9.0.1 Docker project
* Daniel Nashed for donating his [startscript](https://github.com/nashcom/domino-startscript) under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html).

## License
The Dockerfiles and associated scripts are licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html). 

HCL Domino and add-on products are commercial software - The software licenses agreement does not permit further distribution of the docker image that was built using this script!  
Refer to the [HCL license home page](https://www.hcl-software.com/resources/license-agreements) for detailed information about the HCL Domino and add-on product license terms.

