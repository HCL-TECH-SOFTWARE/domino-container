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
    install_packages which inetutils vi glibc-locales gdb
    return 0
  fi

  # Common packages for all distributions
  install_packages lsof ncurses bc which file net-tools diffutils findutils gettext gzip tar unzip

  # SUSE does not have gdb-minimal
  if [ -x /usr/bin/zypper ]; then
    install_package gdb
  else
    install_package gdb-minimal
    if [ ! -e /usr/bin/gdb ]; then
      ln -s /usr/bin/gdb.minimal /usr/bin/gdb
    fi
  fi

  # SUSE
  if [ -x /usr/bin/zypper ]; then
    install_packages glibc-locale libcap-progs vim procps

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

    # Might not be installed in all RedHat based container environments
    install_package util-linux

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


install_ssh_client()
{
  if [ -x /usr/bin/zypper ]; then
    install_package openssh

  elif [ -x /usr/bin/dnf ]; then
    install_package openssh-clients

  elif [ -x /usr/bin/tdnf ]; then
    install_package openssh-clients

  elif [ -x /usr/bin/microdnf ]; then
    install_package openssh-clients

  elif [ -x /usr/bin/yum ]; then
    install_package openssh-clients

  elif [ -x /usr/bin/apt-get ]; then
    install_package openssh-client

  elif [ -x /usr/bin/pacman ]; then
    install_package openssh

  elif [ -x /sbin/apk ]; then
    install_package openssh

  else
    log_error "No package manager found!"
    exit 1
  fi
}


install_linux_packages_hcl()
{
  # Only install minimum required packages for redistributable UBI image

  install_packages hostname unzip lsof gdb file net-tools procps-ng diffutils gettext

  # gdb installs also the C compiler, which is not required and increases image size
  remove_packages gcc make
}


glibc_lang_photon()
{
  if  [ -z "$LINUX_LANG" ]; then
    echo "Info: No support for -locale option on Photon OS"
  fi

  if [ -z "$DOMINO_LANG" ]; then
    return 0
  fi

  echo "Installing locale [$DOMINO_LANG] on Photon OS"
  install_package glibc-i18n
  echo "$DOMINO_LANG UTF-8" > /etc/locale-gen.conf
  locale-gen.sh
  remove_package glibc-i18n
}


glibc_lang_ubuntu()
{
  echo "Ubuntu Linux detected"

  install_package locales

  local INSTALL_LANG=$(echo $DOMINO_LANG|cut -f1 -d"_")

  if [ -n "$INSTALL_LANG" ]; then
    echo "Installing language pack: [$LINUX_LANG]"
    locale-gen $INSTALL_LANG
  fi

  if [ -n "$LINUX_LANG" ]; then

    echo "Installing language packs: [$LINUX_LANG]"
    for INSTALL_LANG in $(echo "$LINUX_LANG" | tr ',' '\n')
    do
      locale-gen $INSTALL_LANG
    done
  fi

  update-locale
}


glibc_lang_redhat()
{
  local INSTALL_LANG=$(echo $DOMINO_LANG|cut -f1 -d"_")

  if [ -n "$INSTALL_LANG" ]; then
    echo "Installing language pack: [$LINUX_LANG]"
    install_package glibc-langpack-$INSTALL_LANG
  fi

  if [ -n "$LINUX_LANG" ]; then

    echo "Installing language packs: [$LINUX_LANG]"
    for INSTALL_LANG in $(echo "$LINUX_LANG" | tr ',' '\n')
    do
      install_package glibc-langpack-$INSTALL_LANG
    done
  fi
}


glibc_lang_all_install()
{
  header "Installing the huge all packs glibc package (>200 MB)"

  if [ -x /usr/bin/zypper ]; then
    install_package glibc-locale
    return 0
  fi

  if [ -x /usr/bin/apt-get ]; then
    install_package locales-all
    return 0
  fi

  install_package glibc-all-langpacks
}


glibc_lang_ubi()
{
  echo "Redhat Universal base image (UBI) detected"
  glibc_lang_all_install
}


glibc_lang_update()
{
  header "glibc Language Setup"

  echo "DOMINO_LANG: $DOMINO_LANG"
  echo "LINUX_LANG : $LINUX_LANG"
  echo

  if [ -z "$DOMINO_LANG" ] && [ -z "$LINUX_LANG" ]; then
    echo "Info: No locale to install"
    return 0
  fi

  # Special handling for VMware Photon OS
  if [ -e /etc/photon-release ]; then
    glibc_lang_photon
    return 0
  fi

  # If all languages are requests, just do that
  if [ "$LINUX_LANG" = "all" ]; then
    glibc_lang_all_install
    return 0
  fi

  # Redhat UBI does not provide separate glibc langpacks. Install all locales as a fallback
  if [ -n "$(grep '^NAME=' /etc/os-release | grep 'Red Hat Enterprise Linux')" ]; then
    glibc_lang_ubi
    return 0
  fi

  # Ubuntu supports generating locales
  if [ -n "$(grep '^NAME=' /etc/os-release | grep 'Ubuntu')" ]; then
    glibc_lang_ubuntu
    return 0
  fi

  if [ -x /usr/bin/zypper ]; then
    glibc_lang_all_install

  elif [ -x /usr/bin/dnf ]; then
    glibc_lang_redhat
    return 0

  elif [ -x /usr/bin/microdnf ]; then
    glibc_lang_redhat
    return 0

  elif [ -x /usr/bin/yum ]; then
    glibc_lang_redhat
    return 0

  elif [ -x /usr/bin/apt-get ]; then
    # For other Debian package manger based platforms use glibc locales-all
    echo "Info: Debian package manager base platform detected"
    glibc_lang_all_install
    return 0

  elif [ -x /usr/bin/pacman ]; then
    echo "Info: No locale update routine for Arch Linux"
    return 0

  else
    echo "Info: No locale update routine for this platform"
    return 0
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


install_node_exporter()
{
  if [ -z "$NODE_EXPORTER_INSTALL" ]; then
    return 0
  fi

 local NODE_EXPORTER_DIR="/opt/prometheus/node_exporter"

  mkdir -p "$NODE_EXPORTER_DIR"

  header "Installing requested Prometheus Node Exporter $NODE_EXPORTER_INSTALL"

  get_download_name node_exporter "$NODE_EXPORTER_INSTALL"

  if [ -z "$DOWNLOAD_NAME" ]; then
    log_error "Cannot find requested Prometheus Node Exporter $NODE_EXPORTER_INSTALL"
    return 0
  fi

  download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" "$NODE_EXPORTER_DIR"

  local NODE_EXPORTER_BIN=$(find "$NODE_EXPORTER_DIR" -type f -name "node_exporter")

  if [ -z "$NODE_EXPORTER_BIN" ]; then
     echo "Node Exporter not found"
     exit 1
  fi

  # Remove version directory
  local NODE_EXPORTER_INST_DIR=$(dirname $NODE_EXPORTER_BIN)

  if [ "opt/prometheus/node_exporter" = "$NODE_EXPORTER_INST_DIR" ]; then
    return 0
  fi

  mv "$NODE_EXPORTER_INST_DIR/"* "$NODE_EXPORTER_DIR"
  remove_directory "$NODE_EXPORTER_INSTL_DIR"
}


check_custom_software_repositories()
{
  VERSION_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -f2 -d'=')

  if [ "$VERSION_CODENAME" = "noble" ]; then
    if [ -e /etc/apt/sources.list.d/ubuntu.sources ]; then
      if [ -e "$INSTALL_DIR/custom/ubuntu_noble.sources" ]; then
        header "Replacing Ubuntu Nobel repositories"
        cp -f "$INSTALL_DIR/custom/ubuntu_noble.sources" /etc/apt/sources.list.d/ubuntu.sources
      fi
    fi

  elif [ "$VERSION_CODENAME" = "bookworm" ]; then
    if [ -e /etc/apt/sources.list.d/debian.sources ]; then
      if [ -e "$INSTALL_DIR/custom/debian_bookworm.sources" ]; then
        header "Replacing Debian Bookworm repositories"
        cp -f "$INSTALL_DIR/custom/debian_bookworm.sources" /etc/apt/sources.list.d/debian.sources
      fi
    fi
  fi
}


check_install_trusted_root()
{
  if [ -e "$INSTALL_DIR/custom/trusted_root.pem" ]; then
    install_linux_trusted_root "$INSTALL_DIR/custom/trusted_root.pem"
  fi
}

# Main logic to update Linux and install Linux packages


list_installed_packages "$LINUX_PACKAGE_LIST_BASEIMAGE"

check_custom_software_repositories

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

  check_install_trusted_root

  install_linux_packages

  glibc_lang_update
  header "glibc locales installed"
  locale -a
  echo

  if [ -n "$BORG_INSTALL" ]; then
    OPENSSL_INSTALL=yes
    SSH_INSTALL=yes
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

  if [ "$SSH_INSTALL" = "yes" ]; then
    if [ ! -e /usr/bin/ssh ]; then
      header "Installing SSH client"
      install_ssh_client
    fi
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

  install_node_exporter

  # Install custom Linux packages requested by admin into Linux layer

  if [ -n "LINUX_PKG_ADD" ]; then
    header "Installing custom packages: $LINUX_PKG_ADD"
    install_packages "$LINUX_PKG_ADD"
  fi

   # Remove packages remove Linux base image

  if [ -n "LINUX_PKG_REMOVE" ]; then
    header "Removing packages: $LINUX_PKG_REMOVE"
    remove_packages "$LINUX_PKG_REMOVE"
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

