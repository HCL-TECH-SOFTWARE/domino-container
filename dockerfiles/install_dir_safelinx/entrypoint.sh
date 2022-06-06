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


# Check mandatory parameters

if [ -z "$NOMAD_DOMINO_CFG" ]; then
  log_error "No Domino Nomad configured!"
fi

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

# Certificate location in data store

CERT_DIR=$SAFELINX_DATASTORE

SERVER_KEY=$CERT_DIR/server.key
SERVER_CERT=$CERT_DIR/server.pem
SERVER_CSR=$CERT_DIR/server.csr
SERVER_P12=$CERT_DIR/server_cert.p12

CA_KEY=$CERT_DIR/ca.key
CA_CERT=$CERT_DIR/ca.pem
CA_SEQ=$CERT_DIR/ca.seq

P12_PASSWORD=trusted

# ------------------------------------------------------------

echo
echo "Configuration"
echo  ------------------------------------------------------------
echo "CONFIG_BASE      : [$CONFIG_BASE]"
echo "DOMINO_ORG       : [$DOMINO_ORG]"
echo "SAFELINX_HOST    : [$SAFELINX_HOST]"
echo "NOMAD_HOST       : [$NOMAD_HOST]"
echo "NOMAD_DOMINO_CFG : [$NOMAD_DOMINO_CFG]"
echo
echo "LDAP_HOST        : [$LDAP_HOST]"
echo "LDAP_USER        : [$LDAP_USER]"
echo "LDAP_BASEDN      : [$LDAP_BASEDN]"
echo  ------------------------------------------------------------
echo


# SafeLinx configuration setup via command-line interface

ConfigureSafeLinx()
{
  # Initial config, setup db.
  mkwg -s wlCfg -g mk               \
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

  # Create directory servers and auth methods

  if [ -z "$LDAP_USER" ]; then

    mkwg -s ibm-ldapServerPtr -g mk \
      -a cn="LDAP-Server"           \
      -a primaryou="$CONFIG_BASE"   \
      -a basedn="$BASE_DN"          \
      -a host="$LDAP_HOST"          \
      -a ipServicePort=389          \
      -a ibm-requiressl=0
  else

    mkwg -s ibm-ldapServerPtr -g mk \
      -a cn="LDAP-Server"           \
      -a primaryou="$CONFIG_BASE"   \
      -a basedn="$BASE_DN"          \
      -a host="$LDAP_HOST"          \
      -a ipServicePort=636          \
      -a ibm-requiressl=1           \
      -a uid="$LDAP_USER"           \
      -a ibm-ldapPassword="$LDAP_PASSWORD"
  fi
 
  # Create auth methods for each domain
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

  # Create Nomad web service.
  mkwg -s ibm-wlHttpService -t hcl-wlNomad -g mk \
    -a description="HCL Nomad"                   \
    -a parent="cn=NomadServer,$CONFIG_BASE"      \
    -a ibm-wlUrl="https://$NOMAD_HOST"           \
    -a ibm-wlkeyfile="$SERVER_P12"               \
    -a hcl-wlkeypwd="$P12_PASSWORD"              \
    -a listenport=443                            \
    -a state=0                                   \
    -a ibm-wlMaxThreads=8                        \
    -a ibm-wlAuthRef="cn=LDAP-Authentication,$CONFIG_BASE"      \
    -a httpproxyaddr="NOMAD /nomad file:///usr/local/nomad-src" \
    -a httpproxyaddr="$NOMAD_DOMINO_CFG" 

   # Keep the config in the volume and copy on start
   cp -f /opt/hcl/SafeLinx/wgated.conf $SAFELINX_DATASTORE
}

create_local_ca_cert_p12()
{
  echo "Creating new certificate for $NOMAD_HOST"

  # Create CA key and cert
  openssl ecparam -name prime256v1 -genkey -noout -out $CA_KEY
  openssl req -new -x509 -days 3650 -key $CA_KEY -out $CA_CERT -subj "/O=$DOMINO_ORG/CN=SafeLinxCA"

  # Create server key and cert
  openssl ecparam -name prime256v1 -genkey -noout -out $SERVER_KEY

  openssl req -new -key $SERVER_KEY -out $SERVER_CSR -subj "/O=$DOMINO_ORG/CN=$NOMAD_HOST" -addext "subjectAltName = DNS:$NOMAD_HOST" -addext extendedKeyUsage=serverAuth
  openssl x509 -req -days 3650 -in $SERVER_CSR -CA $CA_CERT -CAkey $CA_KEY -out $SERVER_CERT -CAcreateserial -CAserial $CA_SEQ -extfile <(printf "extendedKeyUsage = serverAuth \n subjectAltName=DNS:$NOMAD_HOST")

  # LATER: OpenSSL 3.0 supports new flags
  #openssl x509 -req -days 3650 -in $SERVER_CSR -CA $CA_CERT -CAkey $CA_KEY -out $SERVER_CERT -CAcreateserial -CAserial $CA_SEQ -copy_extensions copy # Copying extensions can be dangerous! Requests should be checked

  openssl pkcs12 -export -out "$SERVER_P12" -inkey "$SERVER_KEY" -in "$SERVER_CERT" -certfile "$CA_CERT" -password "pass:$P12_PASSWORD"
}

ConvertPEMtoP12()
{ 
  echo "Converting certificate from PEM to PKCS12"
  openssl pkcs12 -export -out "$SERVER_P12" -inkey "$SERVER_KEY" -in "$SERVER_CERT" -password "pass:$P12_PASSWORD"
}

# --- main logic ---

myterm()
{
   echo "Received shutdown signal, shutting down ..."
   wgstop
   exit
}

trap myterm SIGTERM SIGHUP SIGQUIT SIGINT SIGKILL


if [ ! -e "$SERVER_CERT" ]; then
  create_local_ca_cert_p12
fi

if [ ! -e "$SERVER_P12" ]; then
  ConvertPEMtoP12
fi


# Create configuration

if [ -e "$SAFELINX_DATASTORE/wgated.conf" ]; then

  log_space "SafeLinx/Nomad already configured"
  # Copy config from data store
  cp $SAFELINX_DATASTORE/wgated.conf /opt/hcl/SafeLinx/wgated.conf

else

  log_space "Configuring SafeLinx/Nomad"
  ConfigureSafeLinx
fi

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

