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

# Helper functioncs

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
  exit 1
}

remove_file()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi

  ERR_TXT=$(rm -f "$1" 2>&1 >/dev/null)
  
  if [ -e "$1" ]; then
    echo "Info: File not deleted [$1]"
  fi

  return 0
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

if [ -z "$CERTMGR_HOST" ]; then
  CERTMGR_HOST=$NOMAD_HOST
fi

# LDAP configuration (by default use Domino server and organization)

if [ -z "$LDAP_BASEDN" ]; then
  LDAP_BASEDN=$DOMINO_ORG
fi

# LDAP authentication is optional, when allowing two additional LDAP attributes

#LDAP_USER=ldap-user
#LDAP_PASSWORD=password

# ------------------------------------------------------------ 
#
#  When using anonymous LDAP add the following two fields 
#  to LDAP anonymous queries in default config doc:
#
#  - mailserver
#  - smtpfullhostdomain
#
# ------------------------------------------------------------ 

# Internal configuration

SAFELINX_DATASTORE=/opt/hcl/SafeLinx/datastore
CONFIG_BASE="o=local"

# Temporary or to import certs & keys

CERT_DIR=/tmp
SERVER_KEY=$CERT_DIR/server.key
SERVER_CERT=$CERT_DIR/server.pem
SERVER_CSR=$CERT_DIR/server.csr
UPD_PEM_FILE=/tmp/upd_chain.pem
UPD_CERT=/cert-mount/server.pem
UPD_KEY=/cert-mount/server.key


# Store CA and P12 in datastore (it's a simple CA and cannot be protected). But if we get a real PEM, set a strong password

SERVER_P12=$SAFELINX_DATASTORE/server_cert.p12
CA_KEY=$SAFELINX_DATASTORE/ca.key
CA_CERT=$SAFELINX_DATASTORE/ca.pem
CA_SEQ=$SAFELINX_DATASTORE/ca.seq

# LATER: Generate a random password
#P12_PASSWORD=$(openssl rand -base64 32)
P12_PASSWORD=secret

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

echo
echo "LDAP_HOST        : [$LDAP_HOST]"
echo "LDAP_USER        : [$LDAP_USER]"
echo "LDAP_BASEDN      : [$LDAP_BASEDN]"
echo  ------------------------------------------------------------
echo


# SafeLinx configuration setup via command-line interface

ConfigureSafeLinx()
{

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
      -a ipServicePort=389          \
      -a ibm-requiressl=0
  else

    mkwg -s ibm-ldapServerPtr -g mk \
      -a cn="LDAP-Server"           \
      -a primaryou="$CONFIG_BASE"   \
      -a host="$LDAP_HOST"          \
      -a ipServicePort=636          \
      -a ibm-requiressl=1           \
      -a uid="$LDAP_USER"           \
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
    -a hcl-wlkeypwd="$P12_PASSWORD"              \
    -a listenport=443                            \
    -a state=0                                   \
    -a ibm-wlMaxThreads=8                        \
    -a ibm-wlAuthRef="cn=LDAP-Authentication,$CONFIG_BASE" \
    -a httpproxyaddr="NOMAD /nomad file:///usr/local/nomad-src"

  if [ -n "$NOMAD_DOMINO_CFG" ]; then
      echo -a httpproxyaddr="NOMAD /nomad file:///usr/local/nomad-src, $NOMAD_DOMINO_CFG" 
  fi

  # Keep the config in the volume and copy later on start

  cp -f /opt/hcl/SafeLinx/wgated.conf $SAFELINX_DATASTORE
}

create_local_ca_cert_p12()
{
  log_space "Creating new certificate for $NOMAD_HOST"

  # Create CA key and cert

  openssl ecparam -name prime256v1 -genkey -noout -out $CA_KEY
  openssl req -new -x509 -days 3650 -key $CA_KEY -out $CA_CERT -subj "/O=$DOMINO_ORG/CN=SafeLinxCA"

  # Create server key and cert

  openssl ecparam -name prime256v1 -genkey -noout -out $SERVER_KEY

  openssl req -new -key $SERVER_KEY -out $SERVER_CSR -subj "/O=$DOMINO_ORG/CN=$NOMAD_HOST" -addext "subjectAltName = DNS:$NOMAD_HOST" -addext extendedKeyUsage=serverAuth
  openssl x509 -req -days 3650 -in $SERVER_CSR -CA $CA_CERT -CAkey $CA_KEY -out $SERVER_CERT -CAcreateserial -CAserial $CA_SEQ -extfile <(printf "extendedKeyUsage = serverAuth \n subjectAltName=DNS:$NOMAD_HOST")

  # LATER: OpenSSL 3.0 supports new flags
  #openssl x509 -req -days 3650 -in $SERVER_CSR -CA $CA_CERT -CAkey $CA_KEY -out $SERVER_CERT -CAcreateserial -CAserial $CA_SEQ -copy_extensions copy # Copying extensions can be dangerous! Requests should be checked

  openssl pkcs12 -export -out "$1" -inkey "$SERVER_KEY" -in "$SERVER_CERT" -certfile "$CA_CERT" -password "pass:$P12_PASSWORD"

  # Remove PEM files to not import it again next time. Keep the CA key & cert.

  remove_file "$SERVER_KEY"
  remove_file "$SERVER_CERT"
  remove_file "$SERVER_CSR"
}


check_cert_update()
{
  # Check for new certificate
  openssl s_client -servername $NOMAD_HOST -showcerts $CERTMGR_HOST:443 </dev/null 2>/dev/null | sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > $UPD_PEM_FILE

  if [ ! "$?" = "0" ]; then
    log_error "Cannot retrieve certificate from CertMgr server"
    return 1
  fi

  if [ ! -s "$UPD_PEM_FILE" ]; then
    log_error "No certificate returned by CertMgr server"
    return 1
  fi

  # Get Fingerprint for certificate from server
  FINGER_PRINT_UPD=$(openssl x509 -in $UPD_PEM_FILE -noout -fingerprint -sha256 | cut -d '=' -f 2)
  FINGER_PRINT=$(openssl x509 -in $SERVER_CERT -noout -fingerprint -sha256 | cut -d '=' -f 2)

  if [ "$FINGER_PRINT" = "$FINGER_PRINT_UPD" ]; then
    return 0
  fi

  # Get public key hash of updated cert
  PUB_KEY_HASH=$(openssl x509 -in $UPD_PEM_FILE -noout -pubkey | openssl sha1 | cut -d ' ' -f 2)

  # Get public key hash of pkey on disk
  PUB_PKEY_HASH=$(openssl pkey -in $SERVER_KEY -pubout | openssl sha1 | cut -d ' ' -f 2)

  # Both keys must be the same to have matching certificate for existing key
  echo

  if [ "$PUB_KEY_HASH" = "$PUB_PKEY_HASH" ]; then
    echo "OK - Certificate is matching key --> Updating certificate"

  else
    log_error  "Certificate does not match key --> Not updating certificate"

    UPD_SUBJECT=$(openssl x509 -in $UPD_PEM_FILE -noout -subject)
    UPD_ISSUER=$(openssl x509 -in $UPD_PEM_FILE -noout -issuer)

    CERT_SUBJECT=$(openssl x509 -in $SERVER_CERT -noout -subject)
    CERT_ISSUER=$(openssl x509 -in $SERVER_CERT -noout -issuer)

    echo
    echo "Cert: $CERT_SUBJECT  [$CERT_ISSUER]"
    echo "New:  $UPD_SUBJECT  [$UPD_ISSUER]"
    echo

    return 1
  fi

  remove_file "$UPD_PEM_FILE"

}

convert_pem_to_p12()
{ 
  log_space "Converting certificate from PEM to PKCS12"

  openssl pkcs12 -export -out "$3" -inkey "$1" -in "$2" -password "pass:$P12_PASSWORD"

  # Update password in config
  # LATER: update the password if random password 
  # chwg -s hcl-wlNomad -l "cn=nomad-web-proxy0,cn=NomadServer,$CONFIG_BASE" -a hcl-wlkeypwd="$P12_PASSWORD"

  # Try to remove the PEM after creating P12. If they are mounted, this might fail
  remove_file "$UPD_CERT"
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

  log_space "SafeLinx/Nomad already configured"

  # Copy saved config from datastore on startup

  cp $SAFELINX_DATASTORE/wgated.conf /opt/hcl/SafeLinx/wgated.conf

else

  log_space "Configuring SafeLinx/Nomad"
  ConfigureSafeLinx
fi


# If there is a PEM update the P12

if [ -e "$UPD_CERT" ]; then
  convert_pem_to_p12 "$UPD_KEY" "$UPD_CERT" "$SERVER_P12"

# If no P12 is there, create a new cert and convert it to P12

elif [ ! -e "$SERVER_P12" ]; then
  create_local_ca_cert_p12 "$SERVER_P12"
fi


#Clear password

P12_PASSWORD=zzz


# Start SafeLinx

log_space "Starting SafeLinx server .."

wgstart

# Run in a loop and wait for termination

while true
do
  sleep 1
done

# Exit terminates the calling script cleanly

exit 0

