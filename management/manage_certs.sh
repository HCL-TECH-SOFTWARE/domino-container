#!/bin/bash

###########################################################################
# Nash!Com Certificate Management Script                                  #
# Version 1.1.0 28.05.2019                                                #
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

CREATE_CONFIGURED_CERTS="yes"

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

CREATE_KEYRINGS="yes"
KEYRING_PASSWORD=domino4ever

#CERTMGR_CONFIG_FILE="/local/cfg/certmgr_config"
CERTMGR_DIR=`dirname $0`/certs

LOTUS=/opt/ibm/domino
KYRTOOL_BIN=$LOTUS/bin/kyrtool
DOMINO_DATA_PATH=/local/notesdata

# -------------------------- #
#   END MAIN CONFIGURATION   #
# -------------------------- #


# Local CA Configuration
# ----------------------

# If you stay with the default configuration, a simple CA will be created via openssl.
# All certificates are automatically signed by this local CA when invoking this script.
# The whole operation is processed in one step. However the script is designed to allow to update/regenerate keys and certificates.


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
#    (You can also pass a .pfx or a .cer (DER encoded) certificate file. They just have to match the naming and will be converted to PEM)
# 4. Ensure a certificate PEM file for the CA and all intermediate files is stored in the "pem" directory. "ca_all.pem" is stored in the ca directory.
# 5. Invoke the script again to generate a xxx_all.pem file for each certificate
# 6. The final PEM file contains the private key, certificate, intermediate certs and the CA's root certificate in the right order to be user by the kyrtool

# The following configuration is optional for special cases and documentation purposes.
# It shows all local CA related default values which can be modified if needed for your convenience.


# Optional/Specific Configuration
# -------------------------------

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

TODO_FILE=/tmp/certmgr_todo.txt

# Use a config file if present
if [ -z "$CERTMGR_CONFIG_FILE" ]; then
  CERTMGR_CONFIG_FILE=./certmgr_config
fi

if [ -r "$CERTMGR_CONFIG_FILE" ]; then
  echo "(Using config file $CERTMGR_CONFIG_FILE)"
  . $CERTMGR_CONFIG_FILE
else
  echo "Cannot read config file [$CERTMGR_CONFIG_FILE]" 
  exit 1
fi

# Set correct directories based on main path

CERTMGR_DIR=`realpath "$CERTMGR_DIR"`

CA_DIR=$CERTMGR_DIR/ca
KEY_DIR=$CERTMGR_DIR/key
CSR_DIR=$CERTMGR_DIR/csr
CRT_DIR=$CERTMGR_DIR/crt
PEM_DIR=$CERTMGR_DIR/pem
TXT_DIR=$CERTMGR_DIR/txt
KYR_DIR=$CERTMGR_DIR/kyr

CA_KEY_FILE=$CA_DIR/$CA_KEY
CA_CRT_FILE=$CA_DIR/$CA_CERT
CA_PEM_ALL_FILE=$CA_DIR/ca_all.pem

# -------------------------- #

pushd()
{
  command pushd "$@" > /dev/null
}

popd()
{
  command popd "$@" > /dev/null
}

log ()
{
  echo $1 $2 $3 $4 
}

todo ()
{
  echo $1 $2 $3 $4 >> "$TODO_FILE"
}

remove_file()
{
  if [ -e "$1" ]; then
    echo "Removing [$1]"
    rm -f "$1"
  fi 
}

rm_file()
{
  if [ -e "$1" ]; then
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
    remove_file "$CA_CRT_FILE"
  fi

  if [ -e "$CA_CRT_FILE" ]; then
    log "Root CA cert already exists"
  else
    log "Generating Root CA certificate"
    openssl req -passin pass:$CA_PASSWORD -new -x509 -days $CA_VALID_DAYS -key $CA_KEY_FILE -out $CA_CRT_FILE -subj "$CA_SUBJECT" $CERT_SIGN_ALG > /dev/null

    # write CA's trusted root cert
    cat $CA_CRT_FILE > $CA_PEM_ALL_FILE
  fi
}

check_kyrtool ()
{
  if [ ! -x "$KYRTOOL_BIN" ]; then
    echo "Kyrtool not found or cannot be executed [$KYRTOOL_BIN]"
    exit 1
  fi	
 
  if [ ! $LOGNAME = "notes" ]; then
    echo "You have be 'notes' to execute the kyrtool"
    exit 1
  fi	

  if [ ! -r "$DOMINO_DATA_PATH/notes.ini" ]; then
    echo "Cannot read notes.ini"
    exit 1
  fi	
}

create_keyring ()
{
  if [ ! "$CREATE_KEYRINGS" = "yes" ]; then return 0; fi
  if [ "$1" = "iam_server" ]; then return 0; fi
  if [ "$1" = "iam_client" ]; then return 0; fi

  KYR_FILE=$KYR_DIR/$1.kyr
  PEM_ALL_FILE=$PEM_DIR/${1}_all.pem

  if [ -e "$KYR_FILE" ]; then 
  	log "Keyring file [$KYR_FILE] already exists"
  	return 0
  fi
  
  check_kyrtool
  
  pushd .

  cd "$DOMINO_DATA_PATH"
  $KYRTOOL_BIN create -k "$KYR_FILE" -p "$KEYRING_PASSWORD"
  $KYRTOOL_BIN import all -k "$KYR_FILE" -i "$PEM_ALL_FILE"
  $KYRTOOL_BIN verify "$PEM_ALL_FILE" > "$TXT_DIR/kyr_$1.txt"
  
  popd
}

create_keyring_files ()
{
  if [ ! "$CREATE_KEYRINGS" = "yes" ]; then return 0; fi
  check_kyrtool

  log

  ALL_CRTS=`find "$CRT_DIR" -type f -name "*.crt" -printf "%p\n" | sort`

  for CRT in $ALL_CRTS; do
    NAME=`basename "$CRT" | cut -d"." -f1`
    create_keyring "$NAME"
  done
}


create_key_cert()
{
  NAME="$1"
  SUBJ="$2"
  SANS="$3"

  KEY_FILE=$KEY_DIR/$NAME.key
  CSR_FILE=$CSR_DIR/$NAME.csr
  CRT_FILE=$CRT_DIR/$NAME.crt
  PEM_FILE=$CRT_DIR/$NAME.pem
  CER_FILE=$CRT_DIR/$NAME.cer
  PFX_FILE=$CRT_DIR/$NAME.pfx
  KYR_FILE=$KYR_DIR/$NAME.kyr
  PEM_ALL_FILE=$PEM_DIR/${NAME}_all.pem

  if [ -z "$SUBJ$SANS" ]; then
    log "No configuration for [$NAME]"
  fi

  if [ -e "$KEY_FILE" ]; then
    log "Key [$KEY_FILE] already exists"
  else
    log "Generating key [$KEY_FILE]"
    openssl genrsa -out "$KEY_FILE" $CLIENT_KEYLEN > /dev/null
    remove_file "$CSR_FILE"
    remove_file "$CRT_FILE"
    remove_file "$CER_FILE"
    remove_file "$PFX_FILE"
    remove_file "$KYR_FILE"
  fi

  # PEM is named CRT internally
  if [ -e "$PEM_FILE" ]; then
    CRT_FILE = "$PEM_FILE"
  fi
      
  if [ -e "$CRT_FILE" ]; then
    log "Certificate exists [$CRT_FILE]"
    remove_file "$CSR_FILE"
  else

    if [ -e "$CSR_FILE" ]; then
      log "Certificate Sign Request (CSR) already exists [$CSR_FILE]"
    else
      log "Creating certificate Sign Request (CSR) [$CSR_FILE]"
      openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -subj "$SUBJ" $CRT_SIGN_ALG > /dev/null
      
      if [ ! -z $SANS ]; then
        echo >> $CSR_FILE
        echo "DNS: "$SANS >> $CSR_FILE
      fi

      remove_file "$CRT_FILE"
      remove_file "$CER_FILE"
      remove_file "$PFX_FILE"
      remove_file "$PEM_ALL_FILE"
      remove_file "$KYR_FILE"
    fi
  fi

  if [ -e "$CSR_FILE" ]; then

    if [ "$USE_LOCAL_CA" = "yes" ]; then

      log "Signing CSR [$CSR_FILE] with local CA"
      if [ -z "$SANS" ]; then
        openssl x509 -passin pass:$CA_PASSWORD -req -days $CLIENT_VALID_DAYS -in $CSR_FILE -CA $CA_CRT_FILE -CAkey $CA_KEY_FILE \
          -out $CRT_FILE -CAcreateserial -CAserial $CA_DIR/ca.seq > /dev/null
      else
        openssl x509 -passin pass:$CA_PASSWORD -req -days $CLIENT_VALID_DAYS -in $CSR_FILE -CA $CA_CRT_FILE -CAkey $CA_KEY_FILE \
          -out $CRT_FILE -CAcreateserial -CAserial $CA_DIR/ca.seq -extfile <(printf "subjectAltName=DNS:$SANS") > /dev/null
      fi

      if [ -e "$CSR_FILE" ]; then
        remove_file "$CSR_FILE"
      fi
    fi
  fi
}

create_pem_kyr()
{
  NAME="$1"

  KEY_FILE=$KEY_DIR/$NAME.key
  CSR_FILE=$CSR_DIR/$NAME.csr
  CRT_FILE=$CRT_DIR/$NAME.crt
  PEM_FILE=$CRT_DIR/$NAME.pem
  CER_FILE=$CRT_DIR/$NAME.cer
  PFX_FILE=$CRT_DIR/$NAME.pfx
  PEM_ALL_FILE=$PEM_DIR/${NAME}_all.pem
  KYR_FILE=$KYR_DIR/$NAME.kyr

  if [ ! -e "$CRT_FILE" ]; then
    
    # Convert from PFX format to PEM
  	if [ -e "$PFX_FILE" ]; then
      log "Converting [$PFX_FILE] to [$CRT_FILE]"
      openssl pkcs12 -in "$PFX_FILE" -out $CRT_FILE -nodes
    fi

    # Convert from DER format to PEM
  	if [ -e "$CER_FILE" ]; then
      log "Converting [$CER_FILE] to [$CRT_FILE]"
      openssl x509 -inform der -in "$CER_FILE" -outform pem -out "$CRT_FILE"
    fi
  fi

  if [ -e "$CRT_FILE" ]; then
    cat "$KEY_FILE" > "$PEM_ALL_FILE"
    cat "$CRT_FILE" >> "$PEM_ALL_FILE"
    cat "$CA_PEM_ALL_FILE" >> "$PEM_ALL_FILE"
      
    create_keyring "$NAME"
  fi
}

check_cert()
{
  NAME="$1"

  if [ "$NAME" = "ca" ]; then
    KEY_FILE=$CA_DIR/$NAME.key
    CRT_FILE=$CA_DIR/$NAME.crt
    CSR_FILE=""
  else
    KEY_FILE=$KEY_DIR/$NAME.key
    CRT_FILE=$CRT_DIR/$NAME.crt
    CSR_FILE=$CSR_DIR/$NAME.csr
  fi

  STATUS=""
  PEM_ALL_FILE="$PEM_DIR/${NAME}_all.pem"

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
    # Reading key len from CA would need CA password -> get it from configuration and assume it did not change
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
  else
    remove_file "$PEM_ALL_FILE"
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
  mkdir -p $KYR_DIR
}

generate_config_keys_and_certs ()
{
  create_key_cert domino     "$DOMINO_SERVER_NAME" "$DOMINO_DNS"
  create_key_cert proton     "$PROTON_SERVER_NAME" "$PROTON_DNS"
  create_key_cert iam_server "$IAM_SERVER_NAME"    "$IAM_SERVER_DNS"
  create_key_cert iam_client "$IAM_CLIENT_NAME"    ""
}

check_keys_and_certs ()
{
  log

  ALL_KEYS=`find "$KEY_DIR" -type f -name "*.key" -printf "%p\n" | sort`

  for KEY in $ALL_KEYS; do
    NAME=`basename "$KEY" | cut -d"." -f1`
    create_pem_kyr  "$NAME"
  done

  log

  check_cert ca 

  for KEY in $ALL_KEYS; do
    NAME=`basename "$KEY" | cut -d"." -f1`
    check_cert "$NAME"
  done

  echo "Certificates issues by CA located -> $CRT_DIR"
  echo "PEM files including trusted roots -> $PEM_DIR"
  
  if [ "$CREATE_KEYRINGS" = "yes" ]; then
    echo "Keyring files                     -> $KYR_DIR"
  fi
  
  log

  if [ ! -e "$CA_PEM_ALL_FILE" ]; then
    todo "Please copy your CA's root / intermediate certficiate PEM file into [$CA_PEM_ALL_FILE]"
  fi
}

# --- Main Logic --

# a.) Create defined keys & certs
# b.) Configure an additonal cert

# Syntax: name cert-subject cert-dns
# Example: traveler "/O=$acme/CN=traveler" traveler.acme.com 

check_create_dirs

rm_file "$TODO_FILE"

if [ -z "$1" ]; then

  # Create CA if not present but configured
  create_ca

  if [ "$CREATE_CONFIGURED_CERTS" = "yes" ]; then
    generate_config_keys_and_certs
  fi
  
  # Check all certs and show details
  check_keys_and_certs

else
  # Generate one specific key/cert
  create_key_cert "$1" "$2" "$3"
  create_pem_kyr "$1"
  check_cert "$1"
fi

if [ -e "$TODO_FILE" ]; then
  cat $TODO_FILE
  log
  rm_file "$TODO_FILE"
fi

