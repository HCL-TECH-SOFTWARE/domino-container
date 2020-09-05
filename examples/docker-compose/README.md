# Docker-Compose Examples

Docker Compose is a separate component (not shipped wth Docker CE). Docker Compose is a conventient way to define one or multiple containers. Start and stop, creation of required components like volumes or networks etc. are automatically performed by Docker Compose.

It is also a good practice to use Docker Compose to be prepared for Kubernetes (K8s) which is also leveraging yml files to describe "pod" created in "services".

See details and installation instructions here https://docs.docker.com/compose/.

This dicrectroy contains examples for docker compose files for images built with this project.


## How to use the examples

The default docker-compose.yml file can be just started via the "up" command.
To run the server in background, add the -d option.

```bash
docker compose up -d
```

Other examples can be started specifying the yml file explicitly.

```bash
docker compose -f volt.yml up -d
```

To stop a service you specify the corresponding "down" command.

```bash
docker compose -f volt.yml down
```


