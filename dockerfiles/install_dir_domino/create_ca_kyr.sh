#!/bin/bash

###########################################################################
# Nash!Com Certificate Management Script                                  #
# Version 1.0.0 30.01.2020                                                #
#                                                                         #
# (C) Copyright Daniel Nashed/NashCom 2020                                #
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

# -------------------------- #
#  BEGIN MAIN CONFIGURATION  #
# -------------------------- #

DOMINO_ORG=$OrganizationName
CA_ORG=$OrganizationName
CA_PASSWORD=TemporaryCaPassword

CREATE_KEYRINGS="yes"
USE_LOCAL_CA=yes
KEYRING_PASSWORD=KyrSafePassword

LOTUS=/opt/hcl/domino
KYRTOOL_BIN=$LOTUS/bin/kyrtool

if [ -z "$DOMINO_DATA_PATH" ]; then
  DOMINO_DATA_PATH=/local/notesdata
fi

# -------------------------- #
#   END MAIN CONFIGURATION   #
# -------------------------- #


# Local CA Configuration
# ----------------------

# If you stay with the default configuration, a simple CA will be created via openssl.
# All certificates are automatically signed by this local CA when invoking this script.
# The whole operation is processed in one step. However the script is designed to allow to update/regenerate keys and certificates.


# Optional/Specific Configuration
# -------------------------------

# Default configuration should work for most environments

# Optional Specific CA Configuration

CERTMGR_DIR=/local/certs
CA_VALID_DAYS=3650
CA_KEY=ca.key
CA_CERT=ca.crt
CA_SUBJECT="/O=$CA_ORG/CN=DominoDocker-CA"
CA_KEYLEN=4096
CA_ENCRYPTION=-aes256
CERT_SIGN_ALG=-sha256

# Properties for client keys and certificates

CLIENT_KEYLEN=4096
CLIENT_VALID_DAYS=825

# openssl Configuration

OPENSSL_CONFIG_FILE=/etc/pki/tls/openssl.cnf

# Specific Server Name Configuration

# Use a config file if present
if [ -z "$CERTMGR_CONFIG_FILE" ]; then
  CERTMGR_CONFIG_FILE=./certmgr_config
fi

if [ -r "$CERTMGR_CONFIG_FILE" ]; then
  echo "(Using config file $CERTMGR_CONFIG_FILE)"
  . $CERTMGR_CONFIG_FILE
else
  echo "Info: Using default configuration in script" 
fi

# Set correct directories based on main path

CERTMGR_DIR=$(realpath "$CERTMGR_DIR")

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

log ()
{
  echo $1 $2 $3 $4 
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
    return 1
  fi	
 
  if [ $LOGNAME = "root" ]; then
    echo "You cannot be 'root' to execute the kyrtool"
    return 1
  fi	

  if [ ! -r "$DOMINO_DATA_PATH/notes.ini" ]; then
    echo "Cannot read notes.ini"
    return 1
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
  
  CURRENT_DIR=$(pwd)

  cd "$DOMINO_DATA_PATH"
  $KYRTOOL_BIN create -k "$KYR_FILE" -p "$KEYRING_PASSWORD"
  $KYRTOOL_BIN import all -k "$KYR_FILE" -i "$PEM_ALL_FILE"
  $KYRTOOL_BIN verify "$PEM_ALL_FILE" > "$TXT_DIR/kyr_$1.txt"
  
  cd "$CURRENT_DIR"
}

create_keyring_files ()
{
  if [ ! "$CREATE_KEYRINGS" = "yes" ]; then return 0; fi
  check_kyrtool

  log

  ALL_CRTS=$(find "$CRT_DIR" -type f -name "*.crt" -printf "%p\n" | sort)

  for CRT in $ALL_CRTS; do
    NAME=$(basename "$CRT" | cut -d"." -f1)
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

  # Support for multiple SANS

  SANS_DNS=""
  if [ ! -z "$SANS" ]; then
    for i in $(echo $SANS | tr ',' '\n') ; do
      if [ -z "$SANS_DNS" ]; then
        SANS_DNS=DNS:$i
      else
        SANS_DNS=$SANS_DNS,DNS:$i
      fi
    done
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
    CRT_FILE="$PEM_FILE"
  fi
      
  if [ -e "$CRT_FILE" ]; then
    log "Certificate exists [$CRT_FILE]"
    remove_file "$CSR_FILE"
  else

    if [ -e "$CSR_FILE" ]; then
      log "Certificate Sign Request (CSR) already exists [$CSR_FILE]"
    else
      log "Creating certificate Sign Request (CSR) [$CSR_FILE]"

      if [ -z "$SANS_DNS" ]; then 
        openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -subj "$SUBJ" $CERT_SIGN_ALG > /dev/null
      else
        openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -subj "$SUBJ" $CERT_SIGN_ALG -reqexts SAN -config <(cat $OPENSSL_CONFIG_FILE <(printf "[SAN]\nsubjectAltName=$SANS_DNS")) > /dev/null
      fi
      
      echo >> $CSR_FILE
      if [ ! -z "$SUBJ" ]; then
        echo $SUBJ >> $CSR_FILE
      fi

      if [ ! -z "$SANS" ]; then
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
      if [ -z "$SANS_DNS" ]; then
        openssl x509 -passin pass:$CA_PASSWORD -req -days $CLIENT_VALID_DAYS -in $CSR_FILE -CA $CA_CRT_FILE -CAkey $CA_KEY_FILE \
          -out $CRT_FILE -CAcreateserial -CAserial $CA_DIR/ca.seq  -extfile <(printf "extendedKeyUsage = clientAuth") > /dev/null
      else
        openssl x509 -passin pass:$CA_PASSWORD -req -days $CLIENT_VALID_DAYS -in $CSR_FILE -CA $CA_CRT_FILE -CAkey $CA_KEY_FILE \
         -out $CRT_FILE -CAcreateserial -CAserial $CA_DIR/ca.seq  -extfile <(printf "extendedKeyUsage = serverAuth \n subjectAltName=$SANS_DNS") > /dev/null
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

  # PEM is named CRT internally
  if [ -e "$PEM_FILE" ]; then
    CRT_FILE="$PEM_FILE"
  fi

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
    PEM_FILE=$CA_DIR/$NAME.pem
    CSR_FILE=""
  else
    KEY_FILE=$KEY_DIR/$NAME.key
    CRT_FILE=$CRT_DIR/$NAME.crt
    PEM_FILE=$CRT_DIR/$NAME.pem
    CSR_FILE=$CSR_DIR/$NAME.csr
  fi

  # PEM is named CRT internally
  if [ -e "$PEM_FILE" ]; then
    CRT_FILE="$PEM_FILE"
  fi

  STATUS=""
  PEM_ALL_FILE="$PEM_DIR/${NAME}_all.pem"

  if [ -e "$CRT_FILE" ]; then
    SUBJECT=$(openssl x509 -subject -noout -in $CRT_FILE | awk -F'subject= ' '{print $2 }')
    DNS_NAME=$(openssl x509 -text -noout -in $CRT_FILE | grep DNS | cut -d":" -f2)
    NOT_AFTER=$(openssl x509 -enddate -noout -in $CRT_FILE | awk -F'notAfter=' '{print $2 }')
    CA=$(openssl x509 -issuer -noout -in $CRT_FILE | awk -F'issuer= ' '{print $2 }')

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
      KEYLEN=$(openssl rsa -in $KEY_FILE -text -noout|  grep "Private-Key:" | awk -F'Private-Key: ' '{print $2 }' | tr -d "()")
    else
      KEYLEN=""
      STATUS="NO RSA Private/Public Key"
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

check_keys_and_certs ()
{
  log

  ALL_KEYS=$(find "$KEY_DIR" -type f -name "*.key" -printf "%p\n" | sort)

  for KEY in $ALL_KEYS; do
    NAME=$(basename "$KEY" | cut -d"." -f1)
    create_pem_kyr  "$NAME"
  done

  log

  check_cert ca 

  for KEY in $ALL_KEYS; do
    NAME=$(basename "$KEY" | cut -d"." -f1)
    check_cert "$NAME"
  done

  echo "Certificates issues by CA located -> $CRT_DIR"
  echo "PEM files including trusted roots -> $PEM_DIR"
  
  if [ "$CREATE_KEYRINGS" = "yes" ]; then
    echo "Keyring files                     -> $KYR_DIR"
  fi
  
  log
}

# --- Main Logic --

if [ ! -x /usr/bin/openssl ]; then
  echo "Info: No OpenSSL installed - skipping keyring creation"
else

  if [ -z "$DOMINO_HOST_NAME" ]; then
    if [ -x /usr/bin/hostname ]; then
      DOMINO_HOST_NAME=$(hostname)
    else
      DOMINO_HOST_NAME=$(cat /proc/sys/kernel/hostname)
    fi
  fi

  check_create_dirs
  create_ca
  create_key_cert keyfile "/O=$DOMINO_ORG/CN=$DOMINO_HOST_NAME" "$DOMINO_HOST_NAME"
  create_pem_kyr keyfile
  cp $KYR_DIR/* $DOMINO_DATA_PATH
  rm -rf $CERTMGR_DIR
fi
