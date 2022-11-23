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

header "Installing required packages and adding user nginx"

if [ -e /etc/photon-release ]; then
  install_packages shadow
else
  install_package shadow-utils
fi

useradd nginx -U

header "Installing NGINX ..."

install_package nginx 

cp nginx.conf /etc/nginx/nginx.conf
chmod 444 /etc/nginx/nginx.conf
setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

cp entrypoint.sh /entrypoint.sh
chmod 555 /entrypoint.sh

chown nginx:nginx /var/log/nginx

cd /

# Cleanup repository cache to save space
clean_linux_repo_cache

header "Successfully completed installation!"
