#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2022 - APACHE 2.0 see LICENSE
############################################################################

INSTALL_DIR=$(dirname $0)

# Include helper functions

. $INSTALL_DIR/script_lib.sh

# --- Main Install Logic ---

cd $INSTALL_DIR

check_linux_update

header "Installing required packages and adding user squid"

if [ -e /etc/photon-release ]; then
  install_packages shadow
else
  install_package shadow-utils
fi

useradd squid -U

header "Installing Squid ..."

install_package squid 

#cp squid.conf /etc/squid/squid.conf
chmod 444 /etc/squid/squid.conf

cp entrypoint.sh /entrypoint.sh
chmod 555 /entrypoint.sh

chown squid:squid /var/log/squid
chown squid:squid /run

cd /

# Cleanup repository cache to save space
clean_linux_repo_cache

header "Successfully completed installation!"
