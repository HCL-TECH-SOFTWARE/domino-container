Download Domino 10 Beta App Dev Pack installation archive
===========================================================

Domino 10 beta app dev pack installation archive is expected to be downloaded, the .tgz extracted to "resources" which should give a file named "DOMINO_APPDEV_PACK_1.0_LNX_EN.tar".

The file is not included in this repository for licensing reasons.


Create Docker image for Domino 10
=============================================================================
The Dockerfile in this directory creates a new Docker image klehmann/domino:10.0.0-appdev based on "centos" and installs Domino 10.

    docker build -t klehmann/domino:10.0.1-appdev .

Once installed, you will need to add proton to the server tasks and set the listen port and address, as in the documentation. This process just copies the files across and sets permissions on make_certs.sh and make_keyring.sh.

Note: no action is taken to enforce HTTPS access to proton in the docker image