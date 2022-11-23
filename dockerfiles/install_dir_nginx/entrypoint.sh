#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2022 - APACHE 2.0 see LICENSE
############################################################################

# This script is the main entry point for the NGINX container.
# The entry point is invoked by the container run-time to start NGINX.

# Set more paranoid umask to ensure files can be only read by user
umask 0077

# Create log directory with owner nginx
mkdir /tmp/nginx
chown nginx:nginx /tmp/nginx

echo
echo
echo NGINX Server
echo ------------------------------------------
nginx -V
echo ------------------------------------------
echo
echo

nginx -g 'daemon off;'

exit 0

