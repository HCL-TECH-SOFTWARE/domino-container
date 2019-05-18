#!/bin/bash

###########################################################################
# Nash!Com Domino Docker Management Script                                #
# Version 1.0.5 11.05.2019                                                #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2019                                #
# Feedback domino_unix@nashcom.de                                         #
#                                                                         #
# Licensed under the Apache License, Version 2.0 (the "License");         #
# you may not use this file except in compliance with the License.        #
# You may obtain a copy of the License at                                 #
#                                                                         #
#      http://www.apache.org/licenses/LICENSE-2.0                         #
#                                                                         #
# Unless required by applicable law or agreed to in writing, software     #
# distributed under the License is distributed on an "AS IS" BASIS,       #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.#
# See the License for the specific language governing permissions and     #
# limitations under the License.                                          #
###########################################################################


# This script is intended to automate the X.509 certificate generation process.
# Keys, Certificates and PEM files to be used by the Domino kyrtool are automatically created if you use the local CA.
# For a public or corporate CA this script helps you generate the private key pair, signing requests (CSRs).
# And it also helps to build a PEM file which can be used for example the Domino kyrtool.

# Certificate Authority (CA) Configuration

# If you don't have a company CA configuration this script can create a simple,local CA.
# It will be used to generate all certificates needed. This is the default configuration.

# The following section defines the local CA.

# Please configure your company specific settings

# -------------------------- #
#  BEGIN MAIN CONFIGURATION  #
# -------------------------- #

DOMIMO_ORG="Acme"

DOMINO_SERVER="domino"
DOMINO_DNS="domino.acme.com"

PROTON_SERVER="proton"
PROTON_DNS="proton.acme.com"

IAM_SERVER="iam_server"
IAM_SERVER_DNS="iam.acme.com"

IAM_CLIENT="iam_client"
IAM_CLIENT_NAME="/O=$DOMIMO_ORG/CN=$IAM_CLIENT"

# You can choose between two different configurations 

# a.) a local, simple CA should be used
# b.) a public or corporate CA should be used

USE_LOCAL_CA=yes

CA_ORG=Acme
CA_PASSWORD=domino4ever

CERTMGR_CONFIG_FILE="/local/cfg/certmgr_config"
CERTMGR_DIR=`dirname $0`/certs

# -------------------------- #
#   END MAIN CONFIGURATION   #
# -------------------------- #


# Local CA Configuration
# ----------------------

# If you stay with the default configuration, a simple CA will be created via openssl.
# All certificates are automatically signed by this local CA when invoking this script.
# The whole process is processed in one step. However the script is designed to allow to update/regenerate keys and certificates.


# Public/Company CA 
# -----------------

# When using a public or company CA, this script automatically creates the private keys and certificate signing requests (CSRs).
# You have send those CSR files (*.csr) to the external CA and get back a certificate file (*.crt) in PEM format.
# To import the certificate automatically, the *.crt needs to have a matching name used for the *.csr file.
# IMPORTANT: For external CAs you have to also provide a PEM file (ca_all.pem) with the public key of the Root CA 
# and all intermediate certificates (ordered from most specific to Root CA cert).

# Steps:

# 1. Run this script once to generate the *.key files and *.csr files
# 2. Let the *.csr files sign from the external CA
# 3. Get the *.crt file with a matching name (before the dot) and copy it back to this directory
# 4. Ensure a certificate PEM file for the CA and all intermediate files is stored in the "pem" directory "ca_all.pem"
# 5. Invoke the script again to generate a xxx_all.pem file for each certificate
# 6. The final PEM file contains the private key, certificate, intermediate certs and the CA's root certificate in the right order to be user by the kyrtool

# The following configuration is optional for special cases and documentation purposes.
# It shows all local CA related default values which can be modified if needed for your convenience.


# Optional Specific Configuration
# ------------------------------- #

# Default configuration should work for most environments

# Optional Specific CA Configuration

CA_VALID_DAYS=3650
CA_KEY=ca.key
CA_CERT=ca.crt
CA_SUBJECT="/O=$CA_ORG/CN=CA"
CA_KEYLEN=4096
CA_ENCRYPTION=-aes256
CERT_SIGN_ALG=-sha256

# Properties for client keys and certificates

CLIENT_KEYLEN=4096
CLIENT_VALID_DAYS=3650

# Specific Server Name Configuration

PROTON_SERVER_NAME="/O=$DOMIMO_ORG/CN=$PROTON_SERVER"
DOMINO_SERVER_NAME="/O=$DOMIMO_ORG/CN=$DOMINO_SERVER"
IAM_SERVER_NAME="/O=$DOMIMO_ORG/CN=$IAM_SERVER"

TODO_FILE=todo.txt

# use a config file if present
if [ -e "$CERTMGR_CONFIG_FILE" ]; then
  echo "(Using config file $CERTMGR_CONFIG_FILE)"
  . $CERTMGR_CONFIG_FILE
fi

# set correct directories based on main path

CA_DIR=$CERTMGR_DIR/ca
KEY_DIR=$CERTMGR_DIR/key
CSR_DIR=$CERTMGR_DIR/csr
CRT_DIR=$CERTMGR_DIR/crt
PEM_DIR=$CERTMGR_DIR/pem
TXT_DIR=$CERTMGR_DIR/txt

CA_KEY_FILE=$CA_DIR/$CA_KEY
CA_CRT_FILE=$CA_DIR/$CA_CERT

# -------------------------- #

log ()
{
  echo $1 $2 $3 $4 
}

todo ()
{
  echo $1 $2 $3 $4 >> "$TODO_FILE"
}

rm_file()
{
  if [ -e "$1" ]; then
    echo "Removing [$1]"
    rm -f "$1"
  fi 
}

create_ca()
{
  if [ "$USE_LOCAL_CA" = "yes" ]; then
    log "Using local CA"
  else
    log "Using public or company CA"
    return 0
  fi

  if [ -e "$CA_KEY_FILE" ]; then
    log "Root CA key already exists"
  else
    log "Generate Root CA's private key"
    openssl genrsa -passout pass:$CA_PASSWORD $CA_ENCRYPTION -out $CA_KEY_FILE $CA_KEYLEN > /dev/null
    rm_file "$CA_CRT_FILE"
  fi

  if [ -e "$CA_CRT_FILE" ]; then
    log "Root CA cert already exists"
  else
    log "Generating Root CA certificate"
    openssl req -passin pass:$CA_PASSWORD -new -x509 -days $CA_VALID_DAYS -key $CA_KEY_FILE -out $CA_CRT_FILE -subj "$CA_SUBJECT" $CERT_SIGN_ALG > /dev/null
  fi
}

create_key_cert()
{
  NAME="$1"
  SUBJ="$2"
  SANS="$3"

  KEY_FILE=$KEY_DIR/$NAME.key
  CSR_FILE=$CSR_DIR/$NAME.csr
  CRT_FILE=$CRT_DIR/$NAME.crt

  if [ -z "$SUBJ$SANS" ]; then
    log "No configuration for [$NAME]"
  fi

  if [ -e "$KEY_FILE" ]; then
    log "Key [$KEY_FILE] already exists"
  else
    log "Generating key [$KEY_FILE]"
    openssl genrsa -out "$KEY_FILE" $CLIENT_KEYLEN > /dev/null
    rm_file "$CRT_FILE"
    rm_file "$CSR_FILE"
  fi
    
  if [ -e $CRT_FILE ]; then
    log "Certificate already exists [$CRT_FILE]"
    return 0
  fi

  if [ -e $CSR_FILE ]; then
    log "Certificate Sign Request (CSR) already exists [$CSR_FILE]"
  else
    log "Creating certificate Sign Request (CSR) [$CSR_FILE]"
    openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -subj "$SUBJ" $CRT_SIGN_ALG > /dev/null
    rm_file "$CRT_FILE"
  fi

  if [ -e $CSR_FILE ]; then

    if [ "$USE_LOCAL_CA" = "yes" ]; then

      log "Signing CSR [$CSR_FILE] with local CA"
      if [ -z "$SANS" ]; then
        openssl x509 -passin pass:$CA_PASSWORD -req -days $CLIENT_VALID_DAYS -in $CSR_FILE -CA $CA_CRT_FILE -CAkey $CA_KEY_FILE \
          -out $CRT_FILE -CAcreateserial -CAserial $CA_DIR/ca.seq > /dev/null
      else
        openssl x509 -passin pass:$CA_PASSWORD -req -days $CLIENT_VALID_DAYS -in $CSR_FILE -CA $CA_CRT_FILE -CAkey $CA_KEY_FILE \
          -out $CRT_FILE -CAcreateserial -CAserial $CA_DIR/ca.seq -extfile <(printf "subjectAltName=DNS:$SANS") > /dev/null
      fi

      if [ -e  $CSR_FILE ]; then
        log "Remove CSR [$CSR_FILE]"
        rm -f "$CSR_FILE"
      fi
    fi
  fi
}

check_cert()
{
  NAME="$1"

  if [ "$NAME" = "ca" ]; then
    KEY_FILE=$CA_DIR/$NAME.key
    CRT_FILE=$CA_DIR/$NAME.crt
  else
    KEY_FILE=$KEY_DIR/$NAME.key
    CRT_FILE=$CRT_DIR/$NAME.crt
    CSR_FILE=$CSR_DIR/$NAME.csr
  fi

  PEM_CA_ALL_FILE=$PEM_DIR/ca_all.pem

  STATUS=""
  PEM_FILE="$PEM_DIR/${NAME}_all.pem"

  if [ -e "$CRT_FILE" ]; then
    SUBJECT=`openssl x509 -subject -noout -in $CRT_FILE | awk -F'subject= ' '{print $2 }'`
    DNS_NAME=`openssl x509 -text -noout -in $CRT_FILE | grep DNS | cut -d":" -f2`
    NOT_AFTER=`openssl x509 -enddate -noout -in $CRT_FILE | awk -F'notAfter=' '{print $2 }'`
    CA=`openssl x509 -issuer -noout -in $CRT_FILE | awk -F'issuer= ' '{print $2 }'`

    openssl x509 -text -noout -in $CRT_FILE > $TXT_DIR/$NAME.txt

  else
    SUBJECT=""
    DNS_NAME=""
    NOT_AFTER=""
    CA=""
    STATUS="NO Certificate"
  fi

  if [ "$NAME" = "ca" ]; then
  	# reading key len from CA would need CA password
    KEYLEN="$CA_KEYLEN bit"
  else
    if [ -e "$KEY_FILE" ]; then
      KEYLEN=`openssl rsa -in $KEY_FILE -text -noout|  grep "Private-Key:" | awk -F'Private-Key: ' '{print $2 }' | tr -d "()"`
    else
      KEYLEN=""
      STATUS="NO RSA Private/Public Key"
    fi

    if [ -e "$CSR_FILE" ]; then
      todo "Please send CSR [$CSR_FILE] to external CA for signing"
    fi
  fi

  if [ -z "$STATUS" ]; then
    STATUS="OK"
    cat "$KEY_FILE"   > "$PEM_FILE"
    cat "$CRT_FILE"  >> "$PEM_FILE"

    # don't try to add CA certs to it's own PEM file
    if [ ! "$NAME" = "ca" ]; then
      cat "$PEM_CA_ALL_FILE" >> "$PEM_FILE"
    fi
  else
   rm_file "$PEM_FILE"
  fi

  echo "--------------------------------------------"
  echo " $NAME -> $STATUS"
  echo "--------------------------------------------"
  echo " KeyLen       :  $KEYLEN"
  echo " Subject      :  $SUBJECT"
  if [ ! -z "$DNS_NAME" ]; then
   echo " DNS NAME     :  $DNS_NAME"
  fi
  if [ ! "$CA_SUBJECT" = "$CA" ]; then
    echo " Issuing CA   :  $CA"
  fi
  echo " Valid Until  :  $NOT_AFTER"
  echo "--------------------------------------------"
  echo
}

check_create_dirs ()
{
  mkdir -p $CA_DIR
  mkdir -p $KEY_DIR
  mkdir -p $CSR_DIR
  mkdir -p $CRT_DIR
  mkdir -p $PEM_DIR
  mkdir -p $TXT_DIR
}

generate_keys_and_certs ()
{
  create_ca
  create_key_cert domino     "$DOMINO_SERVER_NAME" "$DOMINO_DNS"
  create_key_cert proton     "$PROTON_SERVER_NAME" "$PROTON_DNS"
  create_key_cert iam_server "$IAM_SERVER_NAME"    "$IAM_SERVER_DNS"
  create_key_cert iam_client "$IAM_CLIENT_NAME"    ""
}

check_keys_and_certs ()
{
  log
  echo > "$TODO_FILE"

  check_cert ca 

  all_keys=`find "$KEY_DIR" -type f -name "*.key" -printf "%p\n" | sort`

  for KEY in $all_keys; do
    NAME=`basename "$KEY" | cut -d"." -f1`
    check_cert "$NAME"
  done

  echo "Complete PEM files including trusted roots -> $PEM_DIR"
  echo "Certificates issues by CA locationed here  -> $CRT_DIR"
  log
  cat $TODO_FILE
  log

  rm -f "$TODO_FILE"
}


# --- Main logic --

# Either create defined keys & certs
# Or configure an additonal cert
# syntax: name cert-subject cert-dns
# example: traveler "/O=$acme/CN=traveler" traveler.acme.com 

check_create_dirs

if [ -z "$1" ]; then

  generate_keys_and_certs
  check_keys_and_certs

else

  create_key_cert "$1" "$2" "$3"
  check_cert "$1"
fi

