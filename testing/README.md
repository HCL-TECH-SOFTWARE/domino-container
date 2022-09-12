# Domino Community Container Image Automation Testing

The automation test script is intended to test any image build with the Domino container community project.
The main purpose is to ensure quality of the project. The automation test is intended to be run before any submission into the develop branch.

By default the automation test uses the standard image name **hclcom/domino:latest**.
Using the **-image=my-image** option any community image can be tested.

The test script requires an image containing the Domino start script. Therefore other images cannot be tested.

## Running the automation test script

```
cd testing
./AutomationTest.sh
```

## How it works

- The script brings up a new Domino container **domino-autotesting** with the specified or default image.
- The pre-defined One Touch Setup JSON file **DominoContainerAutoConfig.json** is copied into the started container to configure the Domino server
- Once the server is started, container commands are exectured into the running container
- The data directory is defined as a native volume, where the script can interact with `IBM_TECHNICAL_SUPPORT/console.log` to check for console output.
- Test results are written into a JSON and CSV file in parallel
- After container shutdown the JSON and CSV file information are displayed on the console


## Domino One Touch Setup

The following main configuration options are currently used to bring up the server

- Create a first server with standard server tasks + POP3
- Set standard notes.ini best practices
- Create ID vault via One Touch Setup
- CertMgr TLS setup with a MicroCA used to create a server certificate with ECDSA NIST-P 384
- Enable circular transaction log
- Configure basic TLS settings in server document and enable internet sites
- Create a configuration document with a best practices configuration
- Create internet sites for HTTP, LDAP, IMAP, POP3 with TLS enabled
- Create Global Domain document
- Create **domcfg.nsf**
- Create and configure **iwaredir.nsf**
- Configure Traveler if the image has Traveler support


## Additional AutomationTest.sh options

- `logs`  
  Show container logs

- `bash`  
  Run a container bash

- `root`  
  Run bash with root permissions inside container

- `exec`  
  Execute a command inside the container

- `console`  
  Run live Domino server console

- `domino`  
  Run Domino start script command

- `stop`  
  Stop container

- `rm`  
  Remove container

- `cleanup`  
  Cleanup Domino server

- `-image=image-name`  
  Specify image to test

- `-nostop`  
  Don't stop container after testing (debugging/testing)

### Examples

Bring up the specified Traveler server image and keeps the server running after performing all tests

```
./AutomationTest.sh -image=hclcom/traveler:12.0.1 -nostop
```

Jump into the running container

```
./AutomationTest.sh bash
```


## Test performed

- **domino.jvm.available**  
  Checks if the JVM returns a proper version

- **domino.server.running**  
  Checks console, if server process started

- **domino.http.running**  
  Checks if HTTL task is running

- **domino.certificate.available**  
  Checks if HTTPS responds and the certificate is trusted

- **domino.server.onetouch.microca-cert**  
  Checks if the right certificate has been created via One Touch MicroCA configuration

- **domino.server.onetouch.createdb**  
  Checks if OneTouch setup created **iwaredir.nsf**

- **domino.idvault.create**  
  Checks if ID Vault has been created by One Touch setup

- **domino.backup.create**  
  Runs a backup of log.nsf and checks if the backup is available

- **startscript.archivelog**  
  Tests the Domino start script `archivelog` command by invoking it remotely and checking the resulting giz file

- **container.health**  
  Test if the container health script configured, returns the server is healthy

- **startscript.server.restart**  
  Restarts the Domino server inside the container via Domino start script and checks if the server comes up again

- **domino.translog.create**  
  Verifies if translog configured via One Touch setup, created transaction log extends after restarting the server

- **domino.smtp_pop3.mail**  
  Sends a SMTP mail via STARTTLS and retrieves the message via secure POP3

## Traveler image additional tests

If a Traveler image is detected, automatically perform additional testing

- **traveler.server.available**  
  Check the Traveler status URL with the admin user via Traveler status URL

