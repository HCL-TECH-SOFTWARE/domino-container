---
layout: default
title: "Domino Setup"
nav_order: 4
description: Domino Setup Web UI"
parent: "Run Image"
has_children: false
---


# Domino Setup Web UI (domsetup)

## Overview

The **Domino Setup Web UI** provides a simple web-based interface to initialize or extend a Domino server setup using the **Domino One-Touch Setup (OTS)** mechanism.
It allows both **interactive setup via browser** and **automated setup posting a OTS JSON file**.
domsetup.sh implements a Micro Web server written in Bash leveraging OpenSSL command line.


### Core Functionality

* Provides a **web-based UI** to perform the initial Domino server setup.
* Supports passing a **first or additional server OTS JSON file** for automated setup.
* Allows uploading an OTS JSON file directly via a **single HTTP POST** to `/ots`.
* Automatically **creates a self-signed TLS certificate** if none is provided.
* Uses the **OpenSSL** command-line tool for key and certificate handling.
* Supports the **`@Base64:`** format to provide an encoded `server.id` inside the OTS JSON.
* Can upload server.ids in a separate upload request or post.
* Supports both **Basic Authentication** and **Bearer Token Authentication** for secured access.


## How to enable the Setup Menu

To enable the setup web GUI set the following environment variable in your container configuarion.

```
DOMSETUP_ENABLED=1
```


# Scenarios

## First server setup via Web GUI

A first server does not need any existing other server nor configuration and can be setup via a simple to use Web GUI.
The first server setup creates the cert.id, server.id, id-vault.id and the first server configuration.

Note: Resulting ID files should be safely copied for backup purposes.


## First server setup using an OTS JSON file

A first server can also be automatically setup uploading or posting a full OTS JSON file.


## Additional server setup using an OTS JSON file

Additional servers can only be configured using an OTS JSON file as well.
Usually the admin server is specified as the existing server to copy system databases.

In addition to the connection to an existing server, the additional servers needs it's server.id.

On Kubernetes the server.id might be provided using a secret.
But specially on Docker it might be useful to just use a single OTS JSON file with an embedded server.id using the `@Base64: ...` syntax described below.

The server ID can be also uploaded in a separate post before uploading an OTS JSON file.


## OTS Server.ID @Base64: Syntax

To pass a server.id to an OTS additional server setup it can be encoded in base64 and stored into the server.id field.

Standard OTS configuration:

```
"IDFilePath": "server.id"
```

Custom configuration passing a server.id

```
"IDFilePath": "@Base64: <base64-encoded-server.id>"
```


## Command Line Usage


### Uploading an OTS JSON via `curl`

To upload an OTS JSON file the file can just be posted to the `/ots` URL.


```
curl -v -k -X POST https://localhost/ots -H "Content-Type: application/octet-stream" --data-binary @ots.json -u admin:password
```


### Uploading a server.id `curl`

In case the OTS JSON additional server setup does not provide a server.id embedded via @Base64: syntax, the server.id can also be uploaded before uploading the OTS JSON file.

To upload an OTS JSON file the file can just be posted to the `/serverid` URL.


```
curl -s -X POST https://volt.nashcom.org:8443/serverid -H "Content-Type: application/octet-stream" --data-binary @my-server.id -u admin:password
```


Result: 

```
Domino Server.ID recreived: SHA256 3ae053c7af734c9f3b97f0ece3af211762519aa8449de8ecae1f96dd43cb13b5
```

### Uploading a server.id `curl` with JSON response

Specially for automation a parsable result is important.
The setup GUI Javascript calculates the hash of the uploaded file and verifies it against the resulting JSON.


```
curl -s -X POST https://volt.nashcom.org:8443/serverid -H "Content-Type: application/octet-stream" -H "Accept: application/json" --data-binary @my-server.id -u admin:password | jq
```

Result:


```
{
  "status": "200",
  "text": "Domino Server.ID recreived",
  "sha256": "3ae053c7af734c9f3b97f0ece3af211762519aa8449de8ecae1f96dd43cb13b5"
}
```



## Environment Variables

The following table describes all environment variables and their default values.


Environment variables are usually passed thru the container configuration, but stay in the container until it is recreated.
Therefore DominoSetup can use an environment file to pass temporary configuration environment variables.

Define `DOMSETUP_ENV_FILE` to specify a mounted environment file.
The default value for this file is `/run/secrets/domsetup/env`



| Variable                    | Description                                                                      | Default                         |
| --------------------------- | -------------------------------------------------------------------------------- | ------------------------------- |
| **DOMSETUP_HOST**           | Hostname used for setup operations.                                              | System hostname                 |
| **DOMSETUP_HTTPS_PORT**     | HTTPS port the setup web UI listens on (must be >= 1024.                         | `1352`                          |
| **DOMSETUP_USER**           | Username for Basic authentication.                                               | `admin`                         |
| **DOMSETUP_PASSWORD**       | Password for setup user. Can point to a file path containing the password.       | `/tmp/domsetup-key.pass`        |
| **DOMSETUP_BEARER**         | Bearer token for authentication (used instead of username/password).             | *(unset)*                       |
| **DOMSETUP_CERT_FILE**      | TLS certificate file to use for HTTPS.                                           | `/tmp/domsetup-cert.pem`        |
| **DOMSETUP_KEY_FILE**       | Private key file associated with the TLS certificate.                            | `/tmp/domsetup-key.pem`         |
| **DOMSETUP_KEY_FILE_PWD**   | File containing the password for the TLS private key, if required.               | `/tmp/domsetup-password.txt`    |
| **DOMSETUP_CERTMGR_HOST**   | Hostname of a Domino CertMgr server used to retrieve a matching TLS certificate. | *(unset)*                       |
| **DOMSETUP_CERTMGR_LOOKUP** | Name used to look up an existing TLS certificate in CertMgr (supports SANs).     | *(unset)*                       |
| **DOMSETUP_JSON_FILE**      | Path where the generated OTS JSON file will be stored.                           | `$DOMINO_AUTO_CONFIG_JSON_FILE` |
| **DOMSETUP_DOMINO_REDIR**   | URL to redirect to after successful setup.                                       | `/verse`                        |
| **DOMSETUP_WEBROOT**        | Directory containing the setup web UI files.                                     | `<script_dir>/domsetup-webroot` |
| **DOMSETUP_NOGUI**          | Set to `1` to disable the web UI (Allow OTS JSON posts only).                    | *(unset)*                       |



## Locations checked for Domino OTS JSON Template

The Domino One Touch JSON template is the base for a first server setup.
It contains environment variables which are replaced by DominoSetup.

Domino OTS JSON files are searched in the following order:


1. Directly specified DOMINO_AUTO_CONFIG_TEMPLATE_JSON_FILE
2. /run/secrets/domsetup/DominoAutoConfigTemplate.json
3. /local/notesdata/DominoAutoConfigTemplate.json
4. <domsetup script dir>/first_server.json
5. /opt/nashcom/startscript/OneTouchSetup/first_server.json



## Integrated MicroCA

The default locations are checked for a TLS key and certificate first.
In case no TLS certificate and key is found, temporary self signed certificate is generated.


## Kubernetes Deployment Notes

Specially on Kubernetes, certificates are often stored in secrets.
The script first checks the following locations for TLS key, cert and password.


### Default TLS Certificate/Key Locations Checked First

If no explicit paths are defined via environment variables, the following default paths are checked first:


```
/run/secrets/domsetup/tls.crt
/run/secrets/domsetup/tls.key
/run/secrets/domsetup/key.pass
```

### Kubernetes-Specific Parameters

| Variable                  | Description                                                   | Default                          |
| ------------------------- | ------------------------------------------------------------- | -------------------------------- |
| **DOMSETUP_CERT_FILE**    | Path to the mounted TLS certificate file.                     | `/run/secrets/domsetup/tls.crt`  |
| **DOMSETUP_KEY_FILE**     | Path to the mounted TLS private key file.                     | `/run/secrets/domsetup/tls.key`  |
| **DOMSETUP_KEY_FILE_PWD** | Path to the mounted password file for the TLS key (optional). | `/run/secrets/domsetup/key.pass` |
| **DOMSETUP_ENV_FILE**     | Optional file to specify  environment variables               | `/run/secrets/domsetup/env`      |

These locations are typically populated via **Kubernetes Secrets**, mounted into the container to provide TLS certificates and private keys securely at runtime.
They can be also used in Docker and other environments but have their defaults adopted to the K8s secrets namespace.



## Domino OTS TLS Setup Integration

For a first server setup TLS Credentials can be imported from a PEM file.
To write a file containing the DominoSetup private key and certificate chain define an export file via `DOMSETUP_TLS_FILE`.

Example:

```
DOMSETUP_TLS_FILE=/tmp/domsetup_tls.pem
```

### Domino OTS configuration example

The following example also contains the configuration needed for password protected private keys.

```
 "security": {
      "TLSSetup": {
        "method": "import",
        "importFilePath": "/tmp/domsetup_tls.pem",
        "importFilePassword": "@Secret:/run/secrets/domsetup/key.pass"
      }
    }
```


---

## Notes

* Requires **OpenSSL** command line.
* When no certificate or key file is provided, a self-signed certificate is generated automatically.
* When using **CertMgr integration**, `DOMSETUP_CERTMGR_HOST` must be defined.
* For non-interactive automation, set `DOMSETUP_NOGUI=1` and POST the OTS JSON directly to `/ots`.
* In Kubernetes environments, it is recommended to use mounted secrets for TLS keys and certificates under `/run/secrets/domsetup/`.


## Implementation details

### Port Setup

The default port to setup a server is 1352 used for a HTTPS connection.
The main reason is that none privileged processes can't bind to ports below 1024.
The program uses for communication is the OpenSSL command-line which should not be authorized to listen to restricted ports.

### Waiting for server setup to complete

After the setup completes the redirect needs to change to the standard HTTPS port (443).
A redirect to another port would be denied by CORS.
Therefore the Javascript in **complete.html** waits for **/domcfg.nsf/style.css** to be available before using Javascript load the specified login page.
The name of the redirect URL is passed as a parameter and the link to the style sheet is derived from that name.
Requesting image files and style sheets is not restricted by CORS and works cross servers.

Checking `style.css` in `domcfg.nsf` is a reliable way to detect the server has been started and the login form is available.

