#!/bin/bash
############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2022 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

INSTALL_DIR=$(dirname $0)
export LANG=C

# Include helper functions & defines
. $INSTALL_DIR/script_lib.sh

# Installer string definitions to check for successful installation
DOM_V12_STRING_OK="Domino Server Installation Successful"
LP_STRING_OK="Selected Language Packs are successfully installed."
FP_STRING_OK="The installation completed successfully."
HF_STRING_OK="The installation completed successfully."
TRAVELER_STRING_OK="Installation completed with warnings."
HF_UNINSTALL_STRING_OK="The installation completed successfully."
JVM_STRING_OK="Patch was successfully applied."
JVM_STRING_FP_OK="Tree diff file patch successful!"

# Log Files
INST_DOM_LOG=$DOMDOCK_LOG_DIR/install_domino.log
INST_FP_LOG=$DOMDOCK_LOG_DIR/install_fp.log
INST_HF_LOG=$DOMDOCK_LOG_DIR/install_hf.log
INST_TRAVELER_LOG=$DOMDOCK_LOG_DIR/install_traveler.log


install_domino()
{
  INST_VER=$PROD_VER

  check_installed_version ver $INST_VER
  if [ "$?" = "1" ]; then
    INST_VER=""
  fi

  if [ -z "$PROD_FP" ]; then
    INST_FP=""
  else
    INST_FP=$PROD_VER$PROD_FP

    check_installed_version fp $INST_FP
    if [ "$?" = "1" ]; then
      INST_FP=""
    fi
  fi

  if [ -z "$PROD_HF" ]; then
    INST_HF=""
  else
    INST_HF=$PROD_VER$PROD_FP$PROD_HF

    check_installed_version hf $INST_HF
    if [ "$?" = "1" ]; then
      INST_HF=""
    fi
  fi

  header "Downloading Domino Installation files ..."

  if [ -n "$INST_VER" ]; then
    get_download_name $PROD_NAME $INST_VER
    download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" domino_server
  fi

  if [ -n "$INST_FP" ]; then
    get_download_name $PROD_NAME $INST_FP domino_fp
    download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" domino_fp
  fi

  if [ -n "$INST_HF" ]; then
    get_download_name $PROD_NAME $INST_HF domino_hf
    download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" domino_hf
  fi

  if [ -n "$INST_VER" ]; then
    header "Installing $PROD_NAME $INST_VER"
    log_space "Running Domino Silent Install -- This takes a while ..."

    DominoResponseFile=domino_install.properties

    CURRENT_DIR=$(pwd)
    cd domino_server/linux64
    ./install -f "$INSTALL_DIR/$DominoResponseFile" -i silent
    cd $CURRENT_DIR

    INSTALL_LOG=$(find $LOTUS -name "HCL_Domino_Install_*.log")

    mv "$INSTALL_LOG" "$INST_DOM_LOG"
    check_file_str "$INST_DOM_LOG" "$DOM_V12_STRING_OK"

    if [ "$?" = "1" ]; then
      echo
      log_ok "Domino installed successfully"

      # Store Domino Version Information
      set_domino_version ver

    else
      print_delim
      cat $INST_DOM_LOG
      print_delim

      log_error "Domino Installation failed!!!"
      exit 1
    fi

    remove_directory domino_server

    # Copy license files
    mkdir -p /licenses
    cp $Notes_ExecDirectory/license/*.txt /licenses

  fi

  if [ -n "$INST_FP" ]; then
    header "Installing Fixpack $INST_FP"

    log_space "Running Domino Fixpack Silent Install -- This takes a while ..."

    CURRENT_DIR=$(pwd)
    cd domino_fp/linux64/domino

    ./install -script script.dat > $INST_FP_LOG
    cd $CURRENT_DIR

    check_file_str "$INST_FP_LOG" "$FP_STRING_OK"

    if [ "$?" = "1" ]; then
    	echo
      log_ok "Fixpack installed successfully"

      # Store Domino Fixpack Information
      set_domino_version fp

    else

      echo
      print_delim
      cat $INST_FP_LOG
      print_delim
      log_error "Fixpack Installation failed!!!"
      exit 1
    fi

    remove_directory domino_fp

  fi

  if [ -n "$INST_HF" ]; then
    header "Installing IF/HF INST_HF"

    log_space "Running Domino Iterimsfix/Hotfix Silent Install -- This takes a while ..."

    CURRENT_DIR=$(pwd)
    cd domino_hf/linux64

    ./install -script script.dat > $INST_HF_LOG
    cd $CURRENT_DIR

    check_file_str "$INST_HF_LOG" "$HF_STRING_OK"

    if [ "$?" = "1" ]; then
      echo
      log_ok "InterimsFix/HotFix installed successfully"

      # Store Domino Interimsfix/Hotfix Information
      set_domino_version hf

    else

      echo
      print_delim
      cat hf.log
      print_delim
      log_error "InterimsFix/HotFix Installation failed!!!"

      exit 1
    fi

    remove_directory domino_hf

  fi

  return 0
}

install_osgi_file()
{
  local SOURCE=$1
  local TARGET="$PLUGINS_FOLDER/$(basename $1)"

  install_file "$SOURCE" "$TARGET" root root 755
}

install_verse()
{
  local ADDON_NAME=verse
  local ADDON_VER=$1

  if [ -z "$ADDON_VER" ]; then
    return 0
  fi

  header "$ADDON_NAME Installation"

  get_download_name $ADDON_NAME $ADDON_VER
  download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" "$ADDON_NAME"

  header "Installing $ADDON_NAME $ADDON_VER"

  OSGI_FOLDER="$Notes_ExecDirectory/osgi"
  PLUGINS_FOLDER=$OSGI_FOLDER"/shared/eclipse/plugins"

  mkdir -p $PLUGINS_FOLDER
  CURRENT_DIR=$(pwd)
  cd $ADDON_NAME
  echo "Unzipping files .."
  unzip -q  *.zip
  unzip -q HCL_Verse.zip

  echo "Copying files .."

  for JAR in eclipse/plugins/*.jar; do
    install_osgi_file "$JAR"
  done

  for JAR in *.jar; do
    install_osgi_file "$JAR"
  done

  install_file "iwaredir.ntf" "$DOMINO_DATA_PATH/iwaredir.ntf" $DOMINO_USER $DOMINO_GROUP 644

  log_space Installed $ADDON_NAME

  cd $CURRENT_DIR
}

docker_set_timezone()
{
  if [ -z "$DOCKER_TZ" ]; then
    return 0
  fi

  CURRENT_TZ=$(readlink /etc/localtime)
  SET_TZ=/usr/share/zoneinfo/$DOCKER_TZ

  if [ "$CURRENT_TZ" = "$SET_TZ" ]; then
    log_space "Timezone [$DOCKER_TZ] already set"
    return 0
  fi

  if [ ! -e "$SET_TZ" ]; then
    log_space "Cannot read timezone [$SET_TZ] -- Timezone not changed"
    return 1
  fi

  log_space "Timezone set to [$DOCKER_TZ]"
  ln -sf "$SET_TZ" /etc/localtime

  return 0
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

set_ini_var_if_not_set()
{
  local file=$1
  local var=$2
  local new=$3

  if [ ! -e "$file" ]; then
    echo "Notes.ini [$file] not found! when adding [$var] = [$new]"
    return 0
  fi

  # Check if entry exists empty. if not present append new entry

  local found=$(grep -i "^$var=" $file)
  if [ -z "$found" ]; then
    echo $var=$new >> $file
  fi

  return 0
}

set_default_notes_ini_variables()
{
  # Avoid Domino Directory Design Update Prompt
  set_ini_var_if_not_set $DOMINO_DATA_PATH/notes.ini "SERVER_UPGRADE_NO_DIRECTORY_UPGRADE_PROMPT" "1"

  # Allow server names with dots and undercores
  set_ini_var_if_not_set $DOMINO_DATA_PATH/notes.ini "ADMIN_IGNORE_NEW_SERVERNAMING_CONVENTION" "1"

  # Use current ODS
  set_ini_var_if_not_set $DOMINO_DATA_PATH/notes.ini "Create_R12_Databases" "1"
}

install_linux_packages()
{
  header "Installing required and useful Linux packages"

  # Common packages for all distributions
  install_package openssl curl gdb lsof ncurses bc which file net-tools cpio diffutils file findutils gettext gzip tar unzip

  # SUSE
  if [ -x /usr/bin/zypper ]; then
    install_package glibc-locale libcap-progs vim

  else

    # SUSE does not require those packages

    install_package procps-ng

    # Installing the English local should always work
    install_package glibc-langpack-en

    # Installing the German locale might fail if UBI systems is running on machine without Redhat subscrption
    install_package glibc-langpack-de

  fi

  # PhotonOS
  if [ -e /etc/photon-release ]; then
    install_package shadow gawk rpm coreutils-selinux util-linux vim tzdata
    return 0
  fi

  # On some platforms certain programs are in their iwn package not installed by default..
  install_if_missing hostname
  install_if_missing xargs

  # jq the ultimate tool for JSON files...
  install_if_missing jq

}

install_perl()
{
  # Temporary install perl for installers if not already installed

  if [ -e /usr/bin/perl ]; then
    return 0
  fi

  if [ -n "$NO_PERL_INSTALL" ]; then
    return 0
  fi

  header "Installing perl"

  if [ -e /etc/photon-release ]; then
    install_package perl
    return 0
  fi

  if [ -x /usr/bin/zypper ]; then
    install_package perl
    return 0
  fi

  install_package perl-libs

  # Mark perl for uninstall
  UNINSTALL_PERL_AFTER_INSTALL=yes
}

remove_perl()
{
  # Removing perl if temporary installed

  if [ ! "$UNINSTALL_PERL_AFTER_INSTALL" = "yes" ]; then
    return 0
  fi

  header "Uninstalling perl"

  remove_package perl-libs perl
}


# --- Main Install Logic ---

export DOMINO_USER=notes
export DOMINO_GROUP=notes

header "Environment Setup"

echo "INSTALL_DIR           = [$INSTALL_DIR]"
echo "DownloadFrom          = [$DownloadFrom]"
echo "Product               = [$PROD_NAME]"
echo "Version               = [$PROD_VER]"
echo "Fixpack               = [$PROD_FP]"
echo "InterimsFix/Hotfix    = [$PROD_HF]"
echo "DominoResponseFile    = [$DominoResponseFile]"
echo "DominoVersion         = [$DominoVersion]"
echo "DominoUserID          = [$DominoUserID]"
echo "LinuxYumUpdate        = [$LinuxYumUpdate]"
echo "DOMINO_LANG           = [$DOMINO_LANG]"
echo "VERSE_VERSION         = [$VERSE_VERSION]"

# Check for Linux updates if requested first
check_linux_update

# Needed by Astra Linux
if [ -x /usr/bin/apt ]; then
   apt install -y apt-utils
fi

# Check if all Linux packages are install. Even xargs could be missing..
install_linux_packages

LINUX_VERSION=$(cat /etc/os-release | grep "VERSION_ID="| cut -d= -f2 | xargs)
LINUX_PRETTY_NAME=$(cat /etc/os-release | grep "PRETTY_NAME="| cut -d= -f2 | xargs)
LINUX_ID=$(cat /etc/os-release | grep "^ID="| cut -d= -f2 | xargs)

# Show current OS version
if [ -n "$LINUX_PRETTY_NAME" ]; then
  header "$LINUX_PRETTY_NAME"
fi

yum_glibc_lang_update

# This logic allows incremental installs for images based on each other (e.g. 10.0.1 -> 10.0.1FP1)
if [ -e $LOTUS ]; then
  FIRST_TIME_SETUP=0
  header "!! Incremantal install based on exiting Domino image !!"
else
  FIRST_TIME_SETUP=1
fi

if [ "$FIRST_TIME_SETUP" = "1" ]; then

  # Add notes user
  if [ -z "$DominoUserID" ]; then
    useradd $DOMINO_USER -U -m
  else
    useradd $DOMINO_USER -U -m -u $DominoUserID
  fi

  # Set user local if configured
  if [ -n "$DOMINO_LANG" ]; then
    echo "export LANG=$DOMINO_LANG" >> /home/$DOMINO_USER/.bash_profile
  fi

  # This alias is really missing ..
  echo "alias ll='ls -l'" >> /home/$DOMINO_USER/.bashrc

  # Set security limits for pam modules (su needs it)
  echo >> /etc/security/limits.conf
  echo '# -- Begin Changes Domino --' >> /etc/security/limits.conf
  echo '* soft nofile 65535' >> /etc/security/limits.conf
  echo '* hard nofile 65535' >> /etc/security/limits.conf
  echo '# -- End Changes Domino --' >> /etc/security/limits.conf

else

  # Check for existing user's group and overwrite (for base images with different group - like root)
  export DOMINO_GROUP=$(id -gn "$DOMINO_USER")

  # Don't install perl for Domino installer
  NO_PERL_INSTALL=yes
fi

# Allow world full access to the main directories to ensure all mounts work.
# Those directories might get replaced with mount points or re-created on startup of the container when /local mount is used.
# Ensure only root can write into the script directory!

# If inheriting an existing installation, it's important to ensure /local has the right permissions root:root including all permissions
# Without the full permissions mounts to sub directories don't work if specifying different users

if [ -e "/local" ]; then
  chown root:root /local
  chmod 777 /local
fi

if [ -e "$DOMINO_DATA_PATH" ]; then
  chmod $DIR_PERM "$DOMINO_DATA_PATH"
fi

# Ensure this directories are owned by root and nobody else can write to the directory
create_directory $DOMDOCK_DIR root root 755
create_directory $DOMDOCK_SCRIPT_DIR root root 755

#Owned by root but writable for everyone
create_directory $DOMDOCK_LOG_DIR root root 777

# Needs full permissions for mount points
create_directory /local root root 777

# All other directories are owned by Domino
create_directory "$DOMINO_DATA_PATH" $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory /local/translog $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory /local/daos $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory /local/nif $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory /local/ft $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory /local/backup $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory /local/restore $DOMINO_USER $DOMINO_GROUP $DIR_PERM

if [ "$BORG_INSTALL" = "yes" ]; then
  create_directory /local/borg $DOMINO_USER $DOMINO_GROUP $DIR_PERM
fi

docker_set_timezone

# Check if HCL Domino image is already installed -> In that case just set version
if [ -e "/tmp/notesdata.tbz2" ]; then

  set_domino_version ver
  FIRST_TIME_SETUP=
  SkipDominoMoveInstallData=yes

  # Set link to install data
  ln -s /tmp/notesdata.tbz2 $DOMDOCK_DIR/install_data_domino.taz

  # Domino is already installed. No perl needed
  NO_PERL_INSTALL=yes
fi

install_perl

if [ "$BORG_INSTALL" = "yes" ]; then

  if [ -e /etc/centos-release ]; then
    header "Installing Borg Backup"
    install_package epel-release

    # Borg Backup needs a different perl version in powertools
    if [ -x /usr/bin/yum ]; then
      yum config-manager --set-enabled powertools
    fi

    install_package borgbackup openssh-clients
  fi
fi

if [ "$OPENSSL_INSTALL" = "yes" ]; then
  if [ ! -e /usr/bin/openssl ]; then
    header "Installing openssl"
    install_package openssl
  fi
fi

cd "$INSTALL_DIR"

# Download updated software.txt file if available
download_file_ifpresent "$DownloadFrom" software.txt "$INSTALL_DIR"

if [ "$FIRST_TIME_SETUP" = "1" ]; then
  case "$PROD_NAME" in
    domino)
      install_domino
      ;;

    *)
      log_error "Unknown product [$PROD_NAME] - Terminating installation"
      exit 1
      ;;
  esac
fi

# Install Verse if requested
install_verse "$VERSE_VERSION"

remove_perl

header "Installing Start Script"

# Extracting start script files
cd $INSTALL_DIR
tar -xf start_script.tar

# Explicitly set docker environment to ensure any Docker implementation works
export DOCKER_ENV=yes

# Allow gdb to use sys ptrace --> Needs to be granted explicitly on some container platforms

if [ -x /usr/bin/gdb ]; then
  if [ ! -L /usr/bin/gdb ]; then
    echo "symbolic link"
    setcap 'cap_sys_ptrace+ep' /usr/bin/gdb
    echo "Setting cap_sys_ptrace for /usr/bin/gdb"
  fi
fi

# Some platforms like UBI use a sym link for gdb
if [ -x /usr/libexec/gdb ]; then
  if [ ! -L /usr/libexec/gdb ]; then
    setcap 'cap_sys_ptrace+ep' /usr/libexec/gdb
    echo "Setting cap_sys_ptrace for /usr/libexec/gdb"
  fi
fi

# Run start script installer
$INSTALL_DIR/start_script/install_script

# Install Setup Files and Docker Entrypoint

if [ "$BORG_INSTALL" = "yes" ]; then
  # Install Borg Backup scripts
  $INSTALL_DIR/start_script/install_borg
fi

header "Final Steps & Configuration"

# Copy pre-start configuration
install_file "$INSTALL_DIR/docker_prestart.sh" "$DOMDOCK_SCRIPT_DIR/docker_prestart.sh" root root 755

# Copy script lib used by other installers
install_file "$INSTALL_DIR/script_lib.sh" "$DOMDOCK_SCRIPT_DIR/script_lib.sh" root root 755

# Copy Docker specific start script configuration if provided
install_file "$INSTALL_DIR/rc_domino_config" "$DOMINO_DATA_PATH/rc_domino_config" root root 644
install_file "$INSTALL_DIR/domino_docker_entrypoint.sh" "/domino_docker_entrypoint.sh" root root 755

# Install Data Directory Copy File
install_file "$INSTALL_DIR/domino_install_data_copy.sh" "$DOMDOCK_SCRIPT_DIR/domino_install_data_copy.sh" root root 755

# Install health check script
install_file "$INSTALL_DIR/domino_docker_healthcheck.sh" "/domino_docker_healthcheck.sh" root root 755

# Install keyring create/update script

install_file "$INSTALL_DIR/create_keyring.sh" "$DOMDOCK_SCRIPT_DIR/create_keyring.sh" root root 755
install_file "$INSTALL_DIR/create_ca_kyr.sh" "$DOMDOCK_SCRIPT_DIR/create_ca_kyr.sh" root root 755

install_file "$INSTALL_DIR/nuid2pw" "$DOMDOCK_SCRIPT_DIR/nuid2pw" root root 4550

# Set notes.ini variables needed
set_default_notes_ini_variables

# --- Cleanup Routines to reduce image size ---

# Remove Fixpack/Hotfix backup files
find $Notes_ExecDirectory -maxdepth 1 -type d -name "120**" -exec rm -rf {} \; 2>/dev/null

# Remove not needed domino/html data to keep image smaller
find $DOMINO_DATA_PATH/domino/html -name "*.dll" -exec rm -rf {} \; 2>/dev/null
find $DOMINO_DATA_PATH/domino/html -name "*.msi" -exec rm -rf {} \; 2>/dev/null

remove_directory "$DOMINO_DATA_PATH/domino/html/download/filesets"
remove_directory "$DOMINO_DATA_PATH/domino/html/help"

# Remove Domino 12 and  higher uninstaller --> we never uninstall but rebuild from scratch
remove_directory "$Notes_ExecDirectory/_HCL Domino_installation"

# Create missing links

create_startup_link kyrtool
create_startup_link dbmt
install_res_links

# Remove tune kernel binary, because it cannot be used in container environments
remove_file "$LOTUS/notes/latest/linux/tunekrnl"

# In some versions the Tika file is also in the data directory.
remove_file $DOMINO_DATA_PATH/tika-server.jar

# Ensure permissons are set correctly for data directory
chown -R $DOMINO_USER:$DOMINO_GROUP $DOMINO_DATA_PATH

# Now export the lib path just in case for Domino to run
export LD_LIBRARY_PATH=$Notes_ExecDirectory:$LD_LIBRARY_PATH

# If configured, move data directory to a compressed tar file

if [ "$SkipDominoMoveInstallData" = "yes" ]; then
  header "Skipping notesdata compression for incremental build"

else
  DOMDOCK_INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_domino.taz

  header "Moving install data $DOMINO_DATA_PATH -> [$DOMDOCK_INSTALL_DATA_TAR]"

  cd $DOMINO_DATA_PATH
  remove_file "$DOMDOCK_INSTALL_DATA_TAR"
  tar -czf "$DOMDOCK_INSTALL_DATA_TAR" .

  remove_directory "$DOMINO_DATA_PATH"
  create_directory "$DOMINO_DATA_PATH" $DOMINO_USER $DOMINO_GROUP $DIR_PERM
fi

# Cleanup repository cache to save space
clean_linux_repo_cache

header "Successfully completed installation!"

exit 0
