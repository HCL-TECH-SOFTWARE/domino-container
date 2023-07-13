#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2023 - APACHE 2.0 see LICENSE
############################################################################

# This script is the main entry point for the SQUID container.
# The entry point is invoked by the container run-time to start SQUID.

# Set more paranoid umask to ensure files can be only read by user
umask 0077


echo
echo
echo Squid Server
echo ------------------------------------------
squid --version
echo ------------------------------------------
echo
echo

squid -N

exit 0

