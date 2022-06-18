#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2022 - APACHE 2.0 see LICENSE
############################################################################

# This script is the main entry point for the HCL SafeLinx container.
# The entry point is invoked by the container run-time to start the server and also acts as a shutdown monitor.

# ------------------------------------------------------------

# Mandatory configuration parameters

# NOMAD_HOST=nomad.acme.com
# NOMAD_DOMINO_CFG="NOMAD CN=domino-acme-01 nrpc://domino-acme-01.acme.com"
# DOMINO_ORG=Acme

# ------------------------------------------------------------ 

# Helper functions

log_space()
{
  echo
  echo "$@"
  echo
}

log_error()
{
  echo
  echo "ERROR - $@"
  echo
}

log_debug()
{
  if [ -z "$DEBUG" ]; then
    return 0
  fi

  echo "DEBUG - $@"
}

remove_file()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi

  ERR_TXT=$(rm -f "$1" >/dev/null 2>/dev/null)
  
  if [ -e "$1" ]; then
    echo "Info: File not deleted [$1]"
  fi

  return 0
}

nsh_cmp()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ -z "$2" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 1
  fi

  if [ ! -e "$2" ]; then
    return 1
  fi

  if [ -x /usr/bin/cmp ]; then
    cmp -s "$1" "$2"
    return $?
  fi

  HASH1=$(sha256sum "$1" | cut -d" " -f1)
  HASH2=$(sha256sum "$2" | cut -d" " -f1)

  if [ "$HASH1" = "$HASH2" ]; then
    return 0
  fi

  return 1
}


# Check mandatory parameters

if [ -z "$DOMINO_ORG" ]; then
  log_error "No Domino organization configured!"
fi

if [ -z "$LDAP_HOST" ]; then
  log_error "No LDAP host configured!"
fi

# Get default values if not specified

if [ -z "$NOMAD_HOST" ]; then
  NOMAD_HOST=$(hostname)
fi

if [ -z "$SAFELINX_HOST" ]; then
  SAFELINX_HOST=$NOMAD_HOST
fi

# Default certificate check interval is 5 minutes
if [ -z "$CERTMGR_CHECK_INTERVAL" ]; then
  CERTMGR_CHECK_INTERVAL=300
fi

# LDAP configuration (by default use Domino server and organization)

if [ -z "$LDAP_BASEDN" ]; then
  LDAP_BASEDN=$DOMINO_ORG
fi

# LDAP authentication is optional, when allowing two additional LDAP attributes

# ------------------------------------------------------------
#
#  When using anonymous LDAP add the following two fields
#  to LDAP anonymous queries in default config doc:
#
#  - mailserver
#  - smtpfullhostdomain
#
# ------------------------------------------------------------

#LDAP_USER=ldap-user
#LDAP_PASSWORD=password

# If LDAP port is not specified, authenticated LDAP requires always secure LDAP

if [ -z "$LDAP_PORT" ]; then
  if [ -z "$LDAP_USER" ]; then
    LDAP_PORT=389
  else
    LDAP_PORT=636
  fi
fi

# Determine LDAP SSL from port, if not specified

if [ -z "$LDAP_SSL" ]; then
  LDAP_SSL=auto
fi

if [ "$LDAP_SSL" = "auto" ]; then
  if [ "$LDAP_PORT" = "389" ]; then
    LDAP_SSL=0
  else
    LDAP_SSL=1
  fi
fi

if [ -z "$LDAP_UNTRUSTED" ]; then
  LDAP_UNTRUSTED=TRUE
fi


# Internal configuration

SAFELINX_DATASTORE=/opt/hcl/SafeLinx/datastore

CONFIG_BASE="o=local"

# Certificates and key need to be persistent between container updates
CERT_DIR=$SAFELINX_DATASTORE

if [ -z "$TRUSTED_ROOT_FILE" ]; then
  TRUSTED_ROOT_FILE=$CERT_DIR/trusted_roots.pem

  # Create it just in case to avoid errors
  touch "$TRUSTED_ROOT_FILE"
fi

SERVER_KEY=$CERT_DIR/server.key
SERVER_CERT=$CERT_DIR/server.pem
SERVER_CSR=$CERT_DIR/server.csr
SERVER_PWD=$CERT_DIR/server.pwd
IMPORT_PWD=$CERT_DIR/import.pwd
IMPORT_TMP_FILE=$CERT_DIR/import.pem

UPD_PEM_FILE=$CERT_DIR/upd_chain.pem
UPD_P12_FILE=$CERT_DIR/upd_server.p12

CERT_MOUNT=/cert-mount

UPD_MOUNT_CERT=$CERT_MOUNT/server.pem
UPD_MOUNT_KEY=$CERT_MOUNT/server.key
UPD_MOUNT_TRUSTED_ROOT_FILE=$CERT_MOUNT/trusted_roots.pem

EXPORT_SECURE_PEM=$CERT_MOUNT/certstore_export.pem
LAST_FINGERPRINT_ERROR=/tmp/last_fingerprint_error.txt

# Store CA and P12 in datastore (it's a simple CA and cannot be protected). But if we get a real PEM, set a strong password

SERVER_P12=$SAFELINX_DATASTORE/server_cert.p12
CA_KEY=$SAFELINX_DATASTORE/ca.key
CA_CERT=$SAFELINX_DATASTORE/ca.pem
CA_SEQ=$SAFELINX_DATASTORE/ca.seq


# ------------------------------------------------------------

echo
echo HCL SafeLinx Community Server
echo
echo "Configuration"
echo  ------------------------------------------------------------
echo "DOMINO_ORG       : [$DOMINO_ORG]"
echo "NOMAD_HOST       : [$NOMAD_HOST]"

if [  "$NOMAD_HOST" != "$SAFELINX_HOST" ]; then
  echo "SAFELINX_HOST    : [$SAFELINX_HOST]"
fi

echo "CONFIG_BASE      : [$CONFIG_BASE]"

if [ -n "$NOMAD_DOMINO_CFG" ]; then
  echo "NOMAD_DOMINO_CFG : [$NOMAD_DOMINO_CFG]"
fi

echo "CERTMGR_HOST     : [$CERTMGR_HOST]"
echo "(CHECK_INTERVAL) : [$CERTMGR_CHECK_INTERVAL]"

echo "TRUSTED_ROOTS    : [$TRUSTED_ROOT_FILE]"
echo "LDAP_HOST        : [$LDAP_HOST]"
echo "LDAP_PORT        : [$LDAP_PORT]"
echo "LDAP_SSL         : [$LDAP_SSL]"
echo "LDAP_USER        : [$LDAP_USER]"
echo "LDAP_BASEDN      : [$LDAP_BASEDN]"
echo  ------------------------------------------------------------
echo


start_safelinx_server()
{
  wgstart >> /tmp/safelinx.log 2>&1
}

restart_safelinx_server()
{
  wgstop
  start_safelinx_server
}


# SafeLinx configuration setup via command-line interface

ConfigureSafeLinx()
{

  # Generate passwords on first start
  openssl rand -base64 32 > "$SERVER_PWD"
  openssl rand -base64 32 > "$IMPORT_PWD"

  # Initial config & setup db

  mkwg -s wlCfg -g mk               \
    -a basedn="$CONFIG_BASE"        \
    -a hostname="$SAFELINX_HOST"    \
    -a onlysecureconns=0            \
    -a dbmstype=0                   \
    -a wpsstoretype=0               \
    -a wgmgrdlog=err,log,warn

  # Create a SafeLinx server resource

  mkwg -s ibm-wlGateway -g mk       \
    -a cn="NomadServer"             \
    -a primaryou="$CONFIG_BASE"     \
    -a hostname="$SAFELINX_HOST"    \
    -a dbmstype=0                   \
    -a loglvl=err,warn,log,debug

  # Create LDAP server

  if [ -z "$LDAP_USER" ]; then

    mkwg -s ibm-ldapServerPtr -g mk \
      -a cn="LDAP-Server"           \
      -a primaryou="$CONFIG_BASE"   \
      -a host="$LDAP_HOST"          \
      -a ipServicePort="$LDAP_PORT" \
      -a ibm-requiressl="$LDAP_SSL" \
      -a ibm-wlkeyfile="$TRUSTED_ROOT_FILE" \
      -a ibm-wlUntrusted="$LDAP_UNTRUSTED"
  else

    mkwg -s ibm-ldapServerPtr -g mk \
      -a cn="LDAP-Server"           \
      -a primaryou="$CONFIG_BASE"   \
      -a host="$LDAP_HOST"          \
      -a ipServicePort="$LDAP_PORT" \
      -a ibm-requiressl="$LDAP_SSL" \
      -a uid="$LDAP_USER"           \
      -a ibm-wlkeyfile="$TRUSTED_ROOT_FILE" \
      -a ibm-wlUntrusted="$LDAP_UNTRUSTED"  \
      -a ibm-ldapPassword="$LDAP_PASSWORD"
  fi
 
  # Create LDAP authentication 

  mkwg -s ibm-wlAuthMethod -t ibm-wlAuthLdap -g mk \
    -a description="Domino LDAP"    \
    -a primaryou="$CONFIG_BASE"     \
    -a cn="LDAP-Authentication"     \
    -a ibm-wlIncludeRealm=0         \
    -a ibm-wlMaxThreads=4           \
    -a ibm-wlGina=FALSE             \
    -a userkeyfield=mail            \
    -a ibm-wlDisableVerify=TRUE     \
    -a "ibm-ldapServerRef=cn=LDAP-Server,$CONFIG_BASE"

  # Create Nomad web service

  mkwg -s ibm-wlHttpService -t hcl-wlNomad -g mk \
    -a description="HCL Nomad"                   \
    -a parent="cn=NomadServer,$CONFIG_BASE"      \
    -a ibm-wlUrl="https://$NOMAD_HOST"           \
    -a ibm-wlkeyfile="$SERVER_P12"               \
    -a hcl-wlkeypwd=$(cat "$SERVER_PWD")         \
    -a listenport=443                            \
    -a state=0                                   \
    -a ibm-wlMaxThreads=8                        \
    -a ibm-wlAuthRef="cn=LDAP-Authentication,$CONFIG_BASE" \
    -a httpproxyaddr="NOMAD /nomad file:///usr/local/nomad-src"

  # LATER: Maybe allow explicit NOMAD settings
  if [ -n "$NOMAD_DOMINO_CFG" ]; then
      echo -a httpproxyaddr="NOMAD /nomad file:///usr/local/nomad-src, $NOMAD_DOMINO_CFG" 
  fi

  # Keep the config in the volume and copy later on start

  cp -f /opt/hcl/SafeLinx/wgated.conf $SAFELINX_DATASTORE

  echo
  echo "Generated PEM import password: $(cat "$IMPORT_PWD")"
  echo
  echo "Write down the password, if you plan to import password protected PEM files (e.g. from HCL Domino CertMgr)"
  echo
}


create_local_ca_cert_p12()
{
  log_space "Creating new certificate for $NOMAD_HOST"

  # Create CA key and cert if not present

  if [ ! -e "$CA_KEY" ]; then
    openssl ecparam -name prime256v1 -genkey -noout -out $CA_KEY
  fi

  if [ ! -e "$CA_CERT" ]; then
    openssl req -new -x509 -days 3650 -key $CA_KEY -out $CA_CERT -subj "/O=$DOMINO_ORG/CN=SafeLinxCA"
  fi

  # Create server key
  if [ ! -e "$SERVER_KEY" ]; then
    openssl ecparam -name prime256v1 -genkey -noout -out $SERVER_KEY
  fi

  # Create server cert
  openssl req -new -key $SERVER_KEY -out $SERVER_CSR -subj "/O=$DOMINO_ORG/CN=$NOMAD_HOST" -addext "subjectAltName = DNS:$NOMAD_HOST" -addext extendedKeyUsage=serverAuth
  openssl x509 -req -days 3650 -in $SERVER_CSR -CA $CA_CERT -CAkey $CA_KEY -out $SERVER_CERT -CAcreateserial -CAserial $CA_SEQ -extfile <(printf "extendedKeyUsage = serverAuth \n subjectAltName=DNS:$NOMAD_HOST")

  # LATER: OpenSSL 3.0 supports new flags
  #openssl x509 -req -days 3650 -in $SERVER_CSR -CA $CA_CERT -CAkey $CA_KEY -out $SERVER_CERT -CAcreateserial -CAserial $CA_SEQ -copy_extensions copy # Copying extensions can be dangerous! Requests should be checked

  openssl pkcs12 -export -out "$1" -inkey "$SERVER_KEY" -in "$SERVER_CERT" -certfile "$CA_CERT" -password "pass:$(cat "$SERVER_PWD")"

  remove_file "$SERVER_CSR"

  # Export new key and chain in one file with encrypted private key and show the password once on console if a CertMgr server is configured

  if [ -e "$CERT_MOUNT" ]; then
    cp -f "$CA_CERT" "$CERT_MOUNT/root_cert_safelinx_ca.pem"
  fi

  if [ -n "$EXPORT_DISABLED" ]; then
    return 0
  fi

  if [ -z "$CERTMGR_HOST" ]; then
    return 0
  fi

  local EXPORT_PASSWORD=$(openssl rand -base64 32)

  openssl pkey -in "$SERVER_KEY" -out "$EXPORT_SECURE_PEM" -aes256 -passout pass:"$EXPORT_PASSWORD"
  cat "$SERVER_CERT" >> "$EXPORT_SECURE_PEM"
  cat "$CA_CERT" >> "$EXPORT_SECURE_PEM"

  log_space "Export Password: $EXPORT_PASSWORD"
}

convert_pem_to_p12()
{
  # $1 = key in PEM format
  # $2 = cert cain in PEM format
  # $3 = P12 file

  log_debug "Converting certificate from PEM to PKCS12"

  openssl pkcs12 -export -out "$UPD_P12_FILE" -inkey "$1" -in "$2" -password "pass:$(cat "$SERVER_PWD")"

  if [ ! "$?" = "0" ]; then
    remove_file "$UPD_P12_FILE"
    return 1
  fi

  # Update P12 if successful
  cp -f "$UPD_P12_FILE" "$3"
  remove_file "$UPD_P12_FILE"

  # LATER: update the password if random password
  # chwg -s hcl-wlNomad -l "cn=nomad-web-proxy0,cn=NomadServer,$CONFIG_BASE" -a hcl-wlkeypwd="$(cat "$SERVER_PWD")"

  return 0
}

show_cert()
{
  if [ -z "$1" ]; then
    return 0
  fi

  if [ ! -e "$1" ]; then
    return 0
  fi

  local SAN=$(openssl x509 -in "$1" -noout -ext subjectAltName | grep "DNS:" | xargs )
  local SUBJECT=$(openssl x509 -in "$1" -noout -subject | cut -d '=' -f 2- )
  local ISSUER=$(openssl x509 -in "$1" -noout -issuer | cut -d '=' -f 2- )
  local EXPIRATION=$(openssl x509 -in "$1" -noout -enddate | cut -d '=' -f 2- )
  local FINGERPRINT=$(openssl x509 -in "$1" -noout -fingerprint | cut -d '=' -f 2- )
  local SERIAL=$(openssl x509 -in "$1" -noout -serial | cut -d '=' -f 2- )

  echo
  echo "SAN         : $SAN"
  echo "Subject     : $SUBJECT"
  echo "Issuer      : $ISSUER"
  echo "Expiration  : $EXPIRATION"
  echo "Fingerprint : $FINGERPRINT"
  echo "Serial      : $SERIAL"
  echo
}

cert_update()
{
  local NEW_PEM="$1"
  local CURRENT_PEM="$2"
  local CURRENT_KEY="$3"
  local CHECK_FINGERPRINT=

  if [ -z "$NEW_PEM" ]; then
    log_error "No new PEM specified"
     return 1
  fi

  if [ ! -e "$NEW_PEM" ]; then
    log_error "New PEM does not exist [$NEW_PEM]"
    return 1
  fi

  if [ -z "$CURRENT_PEM" ]; then
    log_error "No curren PEM specified"
    remove_file "$NEW_PEM"
    return 1
  fi

  if [ -z "$CURRENT_KEY" ]; then
    log_error "No new current key specified"
    remove_file "$NEW_PEM"
    return 1
  fi

  # Compare if there is an existing cert, else update in any case
  if [ -e "$CURRENT_PEM" ]; then

    # Get Fingerprints
    local FINGER_PRINT_UPD=$(openssl x509 -in "$NEW_PEM" -noout -fingerprint -sha256 | cut -d '=' -f 2)
    local FINGER_PRINT=$(openssl x509 -in "$CURRENT_PEM" -noout -fingerprint -sha256 | cut -d '=' -f 2)

    if [ "$FINGER_PRINT" = "$FINGER_PRINT_UPD" ]; then
      remove_file "$NEW_PEM"
      return 1
    fi
  fi

  # Get public key hash of updated cert and current key
  local PUB_KEY_HASH=$(openssl x509 -in "$NEW_PEM" -noout -pubkey | openssl sha1 | cut -d ' ' -f 2)
  local PUB_PKEY_HASH=$(openssl pkey -in "$CURRENT_KEY" -pubout | openssl sha1 | cut -d ' ' -f 2)

  # Both keys must be the same when matching certificate for existing key
  if [ "$PUB_KEY_HASH" = "$PUB_PKEY_HASH" ]; then

    echo
    echo "Certificate Update"
    echo "------------------"
    show_cert "$NEW_PEM"

  else

    if [ -e "$LAST_FINGERPRINT_ERROR" ]; then
      CHECK_FINGERPRINT=$(cat "$LAST_FINGERPRINT_ERROR")
    else
      CHECK_FINGERPRINT=
    fi

    if [ "$CHECK_FINGERPRINT" = "$FINGER_PRINT_UPD" ]; then
      log_debug "key and cert did not match again"

    else
      log_error "Certificate does not match key --> Not updating certificate"

      echo "NEW"
      echo "---"
      show_cert "$NEW_PEM"

      echo "OLD"
      echo "---"
      show_cert "$CURRENT_PEM"
    fi

    remove_file "$NEW_PEM"

    # Remember hash of last cert that did not match
    echo "$FINGER_PRINT_UPD" > "$LAST_FINGERPRINT_ERROR"
    return 2
  fi

  # Keep updated cert for comparing at next update 
  cp -f "$NEW_PEM" "$CURRENT_PEM"
  remove_file "$NEW_PEM"

  log_debug "Copying updated certificate [$NEW_PEM] -> [$CURRENT_PEM]"

  convert_pem_to_p12 "$CURRENT_KEY" "$CURRENT_PEM" "$SERVER_P12"

  return 0
}

check_cert_download()
{
  # Downloads certificate from server (usually a CertMgr server)
  # Returns 0 if updated
  # All other cases return an error

  if [ -z "$CERTMGR_HOST" ]; then
    return 1
  fi

  if [ ! -e "$SERVER_KEY" ]; then
    log_debug "No key found when checking CertMgr server"
    return 2
  fi

  log_debug "Checking for certificate update on [$CERTMGR_HOST] for [$NOMAD_HOST]"

  # Check for new certificate
  openssl s_client -servername $NOMAD_HOST -showcerts $CERTMGR_HOST:443 </dev/null 2>/dev/null | sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > "$UPD_PEM_FILE"

  if [ ! "$?" = "0" ]; then
    log_error "Cannot retrieve certificate from CertMgr server [$CERTMGR_HOST]"
    return 3
  fi

  if [ ! -s "$UPD_PEM_FILE" ]; then
    log_error "No certificate returned by CertMgr server"
    remove_file "$UPD_PEM_FILE"
    return 4
  fi

  cert_update "$UPD_PEM_FILE" "$SERVER_CERT" "$SERVER_KEY" 
  
  return 0
}

check_trusted_root_update()
{
  if [ -e "$UPD_MOUNT_TRUSTED_ROOT_FILE" ]; then
    cp -f "$UPD_MOUNT_TRUSTED_ROOT_FILE" "$TRUSTED_ROOT_FILE"
    remove_file "$UPD_MOUNT_TRUSTED_ROOT_FILE"
    log_space "Trusted roots PEM updated! ($TRUSTED_ROOT_FILE)"
  fi
}

check_cert_file_update()
{
  # Updates cert & key and trusted roots from cert-mount

  # server.pem        : can contain the cert+chain and also the private key
  # server.key        : can be a separate file for the key

  if [ ! -e "$UPD_MOUNT_CERT" ]; then
    return 1
  fi

  # File content modified?
  nsh_cmp "$UPD_MOUNT_CERT" "$SERVER_CERT"
  if [ $? -eq 0 ]; then
    remove_file "$UPD_MOUNT_CERT"
    remove_file "$UPD_MOUNT_KEY"
    return 2
  fi

  remove_file "$IMPORT_TMP_FILE"

  if [ -e "$UPD_MOUNT_KEY" ]; then

    # Check key if present (might have been passed once only)
    openssl pkey -in "$UPD_MOUNT_KEY" -passin pass:$(cat "$IMPORT_PWD") -out "$IMPORT_TMP_FILE"
    remove_file "$UPD_MOUNT_KEY"

  else

    # If there is no separate key, check if there is a key in server.pem
    openssl pkey -in "$UPD_MOUNT_CERT" -passin pass:$(cat "$IMPORT_PWD") -out "$IMPORT_TMP_FILE"
  fi

  # Now check if there is a new key to import or if the file is empty

  if [ ! -s "$IMPORT_TMP_FILE" ]; then
    log_debug "No updated key found"

  else
    log_debug "New key imported"
    cp -f "$IMPORT_TMP_FILE" "$SERVER_KEY"
  fi

  remove_file "$IMPORT_TMP_FILE"

  # If there is no new or existing key, exporting to P12 makes no sence
  if [ ! -e "$SERVER_KEY" ]; then
    remove_file "$UPD_MOUNT_CERT"
    log_error "FATAL ERROR: No existing key found! Check your SafeLinx datastore ($SERVER_KEY)!"
    return 2
  fi

  cert_update "$UPD_MOUNT_CERT" "$SERVER_CERT" "$SERVER_KEY" 

  return 0
}

wait_for_inital_cert()
{

  remove_file "$LAST_FINGERPRINT_ERROR"

  local seconds=

  if [ -e "$SERVER_P12" ]; then
    log_debug "Startup: Server P12 already exists"
    return 0
  fi

  if [ -z "$CERT_MOUNT_WAIT_TIMEOUT" ]; then
    return 0
  fi

  local seconds=$CERT_MOUNT_WAIT_TIMEOUT
  log_space "Waiting for mounted cert ..."

  while true; do

    if [ -e "$UPD_MOUNT_CERT" ]; then
      log_space "Certficate found"
      return 0
    fi

    if [ $seconds -le 0 ]; then
      log_space "Startup: Timeout waiting for initial certificate"
      return 1
    fi

    sleep 1
    seconds=$(expr $seconds - 1)
  done
}

myterm()
{
   log_space "Received shutdown signal, shutting down ..."
   wgstop
   exit
}


# --- Main logic ---

trap myterm SIGTERM SIGHUP SIGQUIT SIGINT SIGKILL


# Create configuration

if [ -e "$SAFELINX_DATASTORE/wgated.conf" ]; then

  log_space "SafeLinx already configured"

  # Copy saved config from datastore on startup

  cp $SAFELINX_DATASTORE/wgated.conf /opt/hcl/SafeLinx/wgated.conf

else

  log_space "Configuring SafeLinx"
  ConfigureSafeLinx
fi

wait_for_inital_cert

# If there is a PEM update the P12

if [ -e "$UPD_MOUNT_CERT" ]; then
  check_cert_file_update
else
  check_cert_download
fi

check_trusted_root_update

# If no P12 is there, create a new cert and convert it to P12

if [ ! -e "$SERVER_P12" ]; then
  create_local_ca_cert_p12 "$SERVER_P12"
fi


# Start SafeLinx

start_safelinx_server

# Print product and version
echo
echo
lswg -V | head -1
echo

echo
echo
echo "Certificate"
echo "-----------"

if [ -e "$SERVER_CERT" ]; then
  show_cert "$SERVER_CERT"
else
  echo "ERROR - No certificate found!"
fi

echo

# Run in a loop and wait for termination

seconds=0

while true; do

  check_trusted_root_update

  # Check for local cert update every second
  if [ -e "$UPD_MOUNT_CERT" ]; then
    check_cert_file_update

  # Only check remote update in specified interval
  else
    sec_mod=$(expr $seconds "%" $CERTMGR_CHECK_INTERVAL)

    if [ "$sec_mod" = "0" ]; then
      check_cert_download
    fi
  fi

  sleep 1
  seconds=$(expr $seconds + 1)
done


# Exit terminates the calling script cleanly
exit 0

