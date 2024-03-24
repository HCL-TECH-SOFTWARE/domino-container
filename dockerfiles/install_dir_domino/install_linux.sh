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

LINUX_PACKAGE_LIST_BASEIMAGE=/tmp/package_list_baseimage.txt
LINUX_PACKAGE_LIST_AFTER_UPDATE=/tmp/package_list_after_update.txt
LINUX_PACKAGE_LIST_AFTER_INSTALL=/tmp/package_list_after_install.txt
LINUX_PACKAGE_LIST_DIFF=/tmp/package_list_diff.txt

# Include helper functions & defines
. $INSTALL_DIR/script_lib.sh


install_linux_packages()
{
  header "Installing required and useful Linux packages"

  if [ "CONTAINER_INSTALLER" = "hcl" ]; then
    echo Skipping additonal packages to be installed
    return 0
  fi

  # Special package list for Archlinux
  if [ -x /usr/bin/pacman ]; then
    install_packages which inetutils vi unzip glibc-locales gdb
    return 0
  fi

  # Common packages for all distributions
  install_packages lsof ncurses bc which file net-tools diffutils findutils gettext gzip tar unzip

  # SUSE does not have gdb-minimal
  if [ -x /usr/bin/zypper ]; then
    install_package gdb
  else
    install_package gdb-minimal
    if [ ! -e /usr/bin/gdb.minimal ]; then
      ln -s /usr/bin/gdb.minimal /usr/bin/gdb
    fi
  fi

  # SUSE
  if [ -x /usr/bin/zypper ]; then
    install_packages glibc-locale libcap-progs vim

  # Ubuntu, Debian, Astra Linux

  # Install setcap (required to set capability for gdb)
  # procps is named differently

  elif [ -x /usr/bin/apt-get ]; then

    install_package procps libcap2-bin

  else

    install_package procps-ng

    # Installing the English local should always work
    install_package glibc-langpack-en

    # Installing the German locale might fail if UBI systems is running on machine without Redhat subscription
    install_package glibc-langpack-de

  fi

  # PhotonOS
  if [ -e /etc/photon-release ]; then
    install_packages shadow gawk rpm coreutils-selinux util-linux vim tzdata
    return 0
  fi

  # On some platforms certain programs are in their own package not installed by default..
  install_if_missing curl
  install_if_missing hostname
  install_if_missing xargs
  install_if_missing vi vi vim
  install_if_missing awk

  # jq the ultimate tool for JSON files...
  install_if_missing jq

}

install_linux_packages_hcl()
{
  # Only install minimum required packages for redistributable UBI image

  install_packages hostname unzip lsof gdb file net-tools procps-ng diffutils gettext

  # gdb installs also the C compiler, which is not required and increases image size
  remove_packages gcc make
}


yum_glibc_lang_update()
{

  local INSTALL_LANG=$(echo $DOMINO_LANG|cut -f1 -d"_")

  if [ -e /etc/photon-release ]; then

    if [ -z "$INSTALL_LANG" ]; then
      return 0
    fi

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

  if [ -n "$INSTALL_LANG" ]; then
    install_package glibc-langpack-$INSTALL_LANG
  fi

  if [ "$LINUX_LANG" = "all" ]; then

    echo "Installing the huge all packs glibc package"
    install_package glibc-all-langpacks

  elif [ -n "$LINUX_LANG" ]; then

    echo "Installing language packs:  [$LINUX_LANG]"
    for INSTALL_LANG in $(echo "$LINUX_LANG" | tr ',' '\n')
    do
      install_package glibc-langpack-$INSTALL_LANG
    done
  fi

  return 0
}


list_installed_packages()
{
  if [ -z "$1" ]; then
    return 0
  fi

  if [ -x /usr/bin/apt ]; then
     apt list --installed | tr ' ' '/' | cut -f1,3 -d'/' | tr '/' '-' | sort > "$1"

  elif [ -x /usr/bin/rpm ]; then
    rpm -qa | sort > "$1"

  elif [ -x /usr/bin/pacman ]; then
    /usr/bin/pacman -Q

  else
    # Special case Photon OS, only get package name not version for now
    yum list installed | cut -f1 -d' ' | sort | uniq > "$1"
  fi
}


# Main logic to update Linux and install Linux packages


list_installed_packages "$LINUX_PACKAGE_LIST_BASEIMAGE"

# Check for Linux updates if requested first

check_linux_update


# List all installed packages in base image

list_installed_packages "$LINUX_PACKAGE_LIST_AFTER_UPDATE"


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

  # Install database client if requested

  if [ "$MYSQL_INSTALL" = "yes" ]; then
    install_mysql_client
  fi

  if [ "$MSSQL_INSTALL" = "yes" ]; then
    install_mssql_client
  fi

  # Install custom Linux packages requested by admin into Linux layer

  if [ -n "LINUX_PKG_ADD" ]; then
    header "Installing custom packages: $LINUX_PKG_ADD"
    install_packages "$LINUX_PKG_ADD"
  fi

fi

# Cleanup repository cache to save space
clean_linux_repo_cache

# List all installed packages after installing all Linux packages 

list_installed_packages "$LINUX_PACKAGE_LIST_AFTER_INSTALL"

# Diff which packages have been installed

comm -3 "$LINUX_PACKAGE_LIST_AFTER_UPDATE" "$LINUX_PACKAGE_LIST_AFTER_INSTALL"  > "$LINUX_PACKAGE_LIST_DIFF"

header "Linux packages installed"
cat "$LINUX_PACKAGE_LIST_DIFF"
echo

