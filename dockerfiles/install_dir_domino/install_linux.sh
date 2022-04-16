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

  if [ "CONTAINER_INSTALLER" = "hcl" ]; then
    echo Skipping additonal packages to be installed
    return 0
  fi

  # Common packages for all distributions
  install_packages curl gdb lsof ncurses bc which file net-tools cpio diffutils file findutils gettext gzip tar unzip

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

  # jq the ultimate tool for JSON files...
  install_if_missing jq

}

install_linux_packages_hcl()
{
  # Only install minimum required packages for redistributable UBI image

  install_packages hostname unzip lsof gdb file net-tools procps-ng diffutils 
  #glibc-langpack-en 

  # gdb installs also the C compiler, which is not required and increases image size

  remove_packages gcc make
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

# Main logic to update Linux and install Linux packages

# Check for Linux updates if requested first

check_linux_update

header "Linux OS layer - Installating required software"

# Check if all Linux packages are installed - Even xargs could be missing..

if [ "$CONTAINER_INSTALLER" = "hcl" ]; then

  install_linux_packages_hcl

else

  # Needed by Astra Linux, Ubuntu and Debian. Might be already installed during update.
  if [ -x /usr/bin/apt ]; then
     install_package apt-utils
  fi

  install_linux_packages

  yum_glibc_lang_update

  if [ -n "$BORG_INSTALL" ]; then
    OPENSSL_INSTALL=yes
    install_package fuse
  fi

  if [ "$BORG_INSTALL" = "yes" ]; then

    if [ -e /etc/centos-release ]; then
      header "Installing Borg Backup from Linux repository"
      install_package epel-release

      # Borg Backup needs a different perl version in powertools
      if [ -x /usr/bin/yum ]; then
        yum config-manager --set-enabled powertools
      fi

      install_package borgbackup
    fi

  elif [ -n "$BORG_INSTALL" ]; then
      header "Installing Borg Backup $BORG_INSTALL"

      download_file_ifpresent "$DownloadFrom" software.txt "$INSTALL_DIR"

      cd "$INSTALL_DIR"
      get_download_name borg $BORG_INSTALL
      download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" "/usr/bin" "borg"

      if [ ! -e /usr/bin/borg ]; then
        log_error "Borg Backup installation failed!"
        exit 1
      fi

      chmod 755 /usr/bin/borg
  fi

  if [ "$OPENSSL_INSTALL" = "yes" ]; then
    if [ ! -e /usr/bin/openssl ]; then
      header "Installing openssl"
      install_package openssl
    fi
  fi

fi

# Cleanup repository cache to save space
clean_linux_repo_cache

