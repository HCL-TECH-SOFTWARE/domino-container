#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

# Create keyring file and import certificates
# $1 = PEM File
# $2 = keyring file (default: keyfile.kyr)
# $3 = keyring password (default: random)

if [ -z "$1" ]; then
  echo
  echo "No PEM file specified!"
  echo
  exit 1
fi

LOTUS=/opt/hcl/domino
PEM_FILE=$(realpath "$1")
KEYRING_FILE="$2"
KEYRING_PASSWORD="$3"

cd /local/notesdata

if [ -z "$KEYRING_FILE" ]; then
  KEYRING_FILE=keyfile.kyr
fi

if [ -e "$KEYRING_FILE" ]; then
  echo "Removing existing keyring [$KEYRING_FILE]"
  rm -f "$KEYRING_FILE"
fi

if [ -z "$KEYRING_PASSWORD" ]; then
  echo "Generating random keyring-file password"
  KEYRING_PASSWORD=$(sha1sum /local/notesdata/notes.ini)
fi

$LOTUS/bin/kyrtool create -k "$KEYRING_FILE" -p "$KEYRING_PASSWORD"
$LOTUS/bin/kyrtool import all -k "$KEYRING_FILE" -i "$PEM_FILE"

echo
echo "Successfully created/updated [$KEYRING_FILE] with [$PEM_FILE]"
echo

