# Domino Docker Containers

This project contains build scripts for HCL Domino Docker/Container images via [dockerfiles](https://docs.docker.com/engine/reference/builder/).
The repository provides the utilities to build HCL Domino Server with the latest software or specific version in a Docker/Container image.
There are separate folders within this repository for Domino add-on HCL products like Traveler and HCL Domino Volt as well.

## Where to get HCL Domino software

The project uses the official HCL web-kit installers to build container images download from the official HCL Flexnet repository.  
All HCL customers should have a download account for [HCL Flexnet software portal](https://hclsoftware.flexnetoperations.com/flexnet/operationsportal).  
HCL Business Partners with the [Partner Pack](https://www.hcltechsw.com/resources/partner-connect/resources/partner-pack) can download software in a similar way.

## Supported environments

The project is supported on Docker Desktop, Docker Server, Podman, Rancher Desktop, Kubernetes (K8s) and OpenShift.
See detailed information about [supported run-time and build environments](docs/supported-environments.md).

## Documentation & Quickstart

See the [documentation](docs/index.md) and the [Quickstart](docs/quickstart.md) for details

## Issues
For issues relating specifically to the Dockerfiles and scripts, please use the [GitHub issue tracker](issues)

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

License for the products that can be installed within the images is as follows:
* HCL Domino Enterprise Server 12 under the [HCL License Agreement](https://www.hcltechsw.com/wps/portal/resources/license-agreements)
* HCL Domino Volt under the [HCL License Agreement](https://www.hcltechsw.com/wps/portal/resources/license-agreements)
* HCL Notes Traveler under the [HCL License Agreement](https://www.hcltechsw.com/wps/portal/resources/license-agreements)

Note that HCL Domino and add-on products are commercial software - The software licenses agreement does not permit further distribution of the docker image that was built using this script.
