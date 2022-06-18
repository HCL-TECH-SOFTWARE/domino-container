#!/bin/bash
############################################################################
# Copyright Nash!Com, Daniel Nashed 2022 - APACHE 2.0 see LICENSE
############################################################################

# Installer for Linux layer
# -------------------------
# - Updates Linux to latest packages if requrested
# - Adds packages needed for Domino at run-time
# - Remporay required packages for installation are installed in Domino install layer

INSTALL_DIR=$(dirname $0)
export LANG=C

# Include helper functions & defines
. $INSTALL_DIR/script_lib.sh


install_linux_packages()
{
  header "Installing required and useful Linux packages"

  # Common packages for all distributions
  install_packages curl lsof ncurses which file net-tools diffutils file findutils gettext gzip tar unzip openssl ncurses-compat-libs

  # SUSE
  if [ -x /usr/bin/zypper ]; then
    install_packages glibc-locale libcap-progs vim

  else

    # SUSE does not require those packages
    install_package procps-ng

    # Installing the English local should always work
    install_package glibc-langpack-en

    # Installing the German locale might fail if UBI systems is running on machine without Redhat subscription
    install_package glibc-langpack-de

  fi

  # On Debian, Ubuntu and Astra Linux install setcap (required to set capability for gdb)
  if [ -x /usr/bin/apt-get ]; then
    install_package libcap2-bin
  fi

  # PhotonOS
  if [ -e /etc/photon-release ]; then
    install_packages shadow gawk rpm coreutils-selinux util-linux vim tzdata
    return 0
  fi

  # On some platforms certain programs are in their own package not installed by default..
  install_if_missing hostname
  install_if_missing xargs
}

yum_glibc_lang_update()
{

  local INSTALL_LOCALE=$(echo $DOMINO_LANG|cut -f1 -d"_")

  if [ -z "$INSTALL_LOCALE" ]; then
    return 0
  fi

  if [ -e /etc/photon-release ]; then

    echo "Installing locale [$DOMINO_LANG] on Photon OS"
    install_package glibc-i18n
    echo "$DOMINO_LANG UTF-8" > /etc/locale-gen.conf
    locale-gen.sh
    remove_package glibc-i18n
    return 0
  fi

  # Only needed for CentOS like platforms -> check if yum is installed

  if [ ! -x /usr/bin/yum ]; then
    return 0
  fi

  install_package glibc-langpack-$INSTALL_LOCALE

  return 0
}

install_mysql_client()
{

  local ADDON_NAME="MySQL Client"
  header "$ADDON_NAME Installation"

  curl -LO https://repo.mysql.com/mysql80-community-release-el7-1.noarch.rpm
  rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022

  install_package mysql80-community-release-el7-1.noarch.rpm
  install_package mysql
  install_package mysql-connector-odbc.x86_64

  log_space Installed $ADDON_NAME
}

install_mssql_client()
{

  local ADDON_NAME="Microsoft SQL Server Client"
  header "$ADDON_NAME Installation"

  curl https://packages.microsoft.com/config/rhel/8/prod.repo > /etc/yum.repos.d/mssql-release.repo

  ACCEPT_EULA=Y install_package msodbcsql18
  ACCEPT_EULA=Y install_package mssql-tools18

  echo >> /etc/bashrc
  echo 'PATH="$PATH:/opt/mssql-tools18/bin"' >> /etc/bashrc

  log_space Installed $ADDON_NAME
}


# Main logic to update Linux and install Linux packages

# Check for Linux updates if requested first

check_linux_update
install_linux_packages
yum_glibc_lang_update

# Install database client if requested

if [ "$MYSQL_INSTALL" = "yes" ]; then
  install_mysql_client
fi

if [ "$MSSQL_INSTALL" = "yes" ]; then
  install_mssql_client
fi


# Cleanup repository cache to save space
clean_linux_repo_cache

