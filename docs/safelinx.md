---
layout: default
title: "SafeLinx Container"
nav_order: 9
description: "HCL SafeLinx/Nomad container"
has_children: false
---


# Community HCL SafeLinx Container with HCL Nomad Web support

HCL Nomad Web leverages the WebSockets protocol to connect to Domino servers.
This requires a gateway component in the HCL SafeLinx server to bridge between **WebSockets** protocol and the Notes protocol "**NRPC**".

Setting up a SafeLinx server in a classical way requires to use of a complicated to use Java admin client.

This project allows you to build a SafeLinx container including HCL Nomad Web components in one step.
The container allows you to configure the container including NomadWeb components simply by specifying environment variables.

## Build the container image

Download the SafeLinx WebKit and also the NomadWeb server components to your software directory.

The build command either builds to the container or shows missing software files:

```
./build.sh safelinx -nomadweb
```

Once authenticated in Flexnet, you can use the links provided to search for the software components.
Links only work with customer accounts with an enabled download search option.

**Example:**

```
Checking software via [/local/github/domino-container/software/software.txt]

1.3.0.0             [NA] HCL-SafeLinx-1300-x86_64.tar.gz
https://hclsoftware.flexnetoperations.com/flexnet/operationsportal/DownloadSearchPage.action?search=HCL-SafeLinx-1300-x86_64.tar.gz+&resultType=Files&sortBy=eff_date&listButton=Search

1.0.3               [NA] 20220325-2893-nomad_web_deploy.zip
https://hclsoftware.flexnetoperations.com/flexnet/operationsportal/DownloadSearchPage.action?search=20220325-2893-nomad_web_deploy.zip+&resultType=Files&sortBy=eff_date&listButton=Search


Correct Software Download Error(s) before building image [2]

```

Once all software is available,run the build process again.
The build will take around 2 minutes.


## Running the SafeLinx image

The SafeLinx container project ships with a predefined Docker compose file located in `examples/safelinx`.

The `docker-compose.yml` contains template variables, which are referenced in the configuration file `.env`

Review and edit the configuration file with your favourite editor

```
vi .env
```

### Requird configuration

```
CONTAINER_HOSTNAME=nomad.acme.com
DOMINO_ORG=acme
LDAP_HOST=ldap.acme.com
```

- **CONTAINER_HOSTNAME**  
  Hostname of the container, which is also defining the hostname of the SafeLinx server

- **DOMINO_ORG**  
  Domino organization name used for the LDAP search base path and also for certificate names created by default.

- **LDAP_HOST**  
  LDAP hostname or IP address to connect to.
  SafeLinx requires an LDAP connection to a Domino server in the domain to lookup users and servers


### LDAP Requirements

SafeLinx uses LDAP to find users, their home mail servers and Domino servers.
There are two missing attributes by default for anonymous LDAP connections.
You can either use authenticated LDAP or add the two missing fields to your configuration.

In case you want to use an anonymous LDAP connection to your Domino LDAL you have to add the following fields for anonymous queries in the default config doc

- dominoPerson / **MailServer**
- dominoServer / **SMTPFullHostDomain**


### Additional LDAP Parameters

For authenticated LDAP connections you should use secure LDAP (LDAPS port: 636).
If your LDAP server is not exposed outside your environment, adding the two missing fields with anonymous LDAP might be the easiest option.

```
LDAP_USER=
LDAP_PASSWORD=
LDAP_PORT=389
LDAP_SSL=auto
```

- **LDAP_USER**  
  LDAP user name when using an authenticated connection

- **LDAP_PASSOWRD**  
  LDAP password when using an authenticated connection

- **LDAP_PORT**  
  LDAP port is used to connect to the Domino LDAP server.
  This is usually port 389 for not encrypted connections.
  And port 636 for LDAPS connections (recommended for authenticated connections).

- **LDAP_SSL**  
  Secure LDAP. It can be `0` or `1`. The `auto` option automatically selects SSL based on the port number.


#### Trusted Roots for LDAPS connections

LDAP connections need to be verified. Trusted roots can be added to the container automatically.
You should need to drop a PEM file `trusted_roots.pem` with trusted roots into the `cert-mount` directory.


### Run the container

You have two different options to start. For a first test, it could make sense to run the container in front-end mode.
In production use, it makes sense to run the container detached.


Run the container in front-end mode

```
docker-compose up
```

Run the container detached

```
docker-compose up -d
```

## Server Certificate support

Out of the box, the container generates its own MicroCA to issue a web server certificate for your SafeLinx server.
This certificate is a good starting point and helps you with your final configuration.

Today most browsers don't support self-signed certificates.
So you will usually need to deploy trusted certificates for your SafeLinx server.

### Import trusted key/certs into the container

The `cert-mount` is designed for easy import of existing keys and certificates.

To import a new key and certificate just copy a `server.pem` file into the `cert-mount` directory.

Either a new certificate or a new certificate and key can be imported.
If only a certificate is imported, the certificate is checked against the existing private key.
The import is only performed if the certificate marches the private key.

To import an encrypted PEM-based private key, the container generates an import password at the first startup. 
This password can be used to import a CertMgr exportable key, which is always exported encrypted.

### Export private key to Domino CertMgr

In case you instead want to export your private key to your CertMgr server for certificate update flows, the container generates an export password printed once on startup. 
The password can be used to import `certstore_export.pem` stored in `cert-mount`.

### Automagical Certificate update

Once you either imported a key from CertMgr or exported your key to CertMgr, you can leverage automatic certificate update flows.

```
CERTMGR_HOST=certmgr.acme.com
```

- **CERTMGR_HOST**  
  CertMgr hostname to contact over HTTPS (443) to check for certificate updates

- **CERTMGR_CHECK_INTERVAL**  
  Interval in seconds to check CertMgr for certificate updates (Default 300 seconds).

## MySQL Server Support

Running the HCL Nomad Web Safelinx container with the internal flat-file configuration works well for up to 200 users.
In case you require more scalability, the Safelinx container can be built and configured with MySQL server support.

### Building the container with MySQL Support

Run the following build command, to include the MySQL client driver:

```
./build.sh safelinx -nomadweb -mysql
```

### Configuration for MySQL

The only additional parameter required is a password for the MySQL server user account.
All other parameters are predefined in the docker-compose file.

- **MYSQL_PASSWORD**  
  The password is shared beteen the SafeLinx and MySQL container.


### Running the SafeLinx container with MySQL container

MySQL is available as a container image. The container project contains an alternate `docker-compose_mysql.yml` file, which includes a setup including a MySQL container.

You can either rename the docker-compose.yml or specify the file explicitly:

```
docker-compose -f docker-compose_mysql.yml up -d
``` 


