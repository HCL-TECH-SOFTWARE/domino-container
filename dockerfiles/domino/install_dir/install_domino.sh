#!/bin/bash
############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2020 - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2019 - APACHE 2.0 see LICENSE
############################################################################

INSTALL_DIR=$(dirname $0)

export DOMDOCK_DIR=/domino-docker
export DOMDOCK_LOG_DIR=/domino-docker
export DOMDOCK_TXT_DIR=/domino-docker
export DOMDOCK_SCRIPT_DIR=/domino-docker/scripts

# in docker environment the LOGNAME is not set
if [ -z "$LOGNAME" ]; then
  export LOGNAME=$(whoami)
fi


# Since Domino 11 the new install directory is /opt/hcl/domino
case "$PROD_VER" in
  9*|10*)
    INSTALLER_VERSION=10
    export LOTUS=/opt/ibm/domino
    ;;
  *)
    INSTALLER_VERSION=11
    export LOTUS=/opt/hcl/domino
    ;;
esac

export Notes_ExecDirectory=$LOTUS/notes/latest/linux
export DYLD_LIBRARY_PATH=$Notes_ExecDirectory:$DYLD_LIBRARY_PATH
export LD_LIBRARY_PATH=$Notes_ExecDirectory:$LD_LIBRARY_PATH
export NUI_NOTESDIR=$LOTUS
export DOMINO_DATA_PATH=/local/notesdata
export PATH=$PATH:$DOMINO_DATA_PATH

SOFTWARE_FILE=$INSTALL_DIR/software.txt
CURL_CMD="curl --fail --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

DIR_PERM=770

# Helper Functions

DOM_V10_STRING_OK="Dominoserver Installation successful"
DOM_V11_STRING_OK="install Domino Server Installation Successful"
LP_STRING_OK="Selected Language Packs are successfully installed."
FP_STRING_OK="The installation completed successfully."
HF_STRING_OK="The installation completed successfully."
TRAVELER_STRING_OK="Installation completed with warnings."
HF_UNINSTALL_STRING_OK="The installation completed successfully."
JVM_STRING_OK="Patch was successfully applied."
JVM_STRING_FP_OK="Tree diff file patch successful!"


INST_DOM_LOG=$DOMDOCK_LOG_DIR/install_domino.log
INST_FP_LOG=$DOMDOCK_LOG_DIR/install_fp.log
INST_HF_LOG=$DOMDOCK_LOG_DIR/install_hf.log
INST_TRAVELER_LOG=$DOMDOCK_LOG_DIR/install_traveler.log

pushd()
{
  command pushd "$@" > /dev/null
}

popd ()
{
  command popd "$@" > /dev/null
}

export pushd popd

print_delim ()
{
  echo "--------------------------------------------------------------------------------"
}

log_ok ()
{
  echo "$1"
}

log_error ()
{
  echo
  echo "Failed - $1"
  echo
}

header ()
{
  echo
  print_delim
  echo "$1"
  print_delim
  echo
}

install_package()
{
 if [ -x /usr/bin/zypper ]; then

   zypper install -y "$@"

 elif [ -x /usr/bin/yum ]; then

   yum install -y "$@"

 fi
}

remove_package()
{
 if [ -x /usr/bin/zypper ]; then
   zypper rm -y "$@"

 elif [ -x /usr/bin/yum ]; then
   yum remove -y "$@"

 fi
}

check_file_str ()
{
  CURRENT_FILE="$1"
  CURRENT_STRING="$2"


  if [ -e "$CURRENT_FILE" ]; then
    CURRENT_RESULT=$(grep "$CURRENT_STRING" "$CURRENT_FILE")

    if [ -z "$CURRENT_RESULT" ]; then
      return 0
    else
      return 1
    fi
  fi

  return 0
}

get_download_name ()
{
  DOWNLOAD_NAME=""
  if [ -e "$SOFTWARE_FILE" ]; then
    DOWNLOAD_NAME=$(grep "$1|$2|" "$SOFTWARE_FILE" | cut -d"|" -f3)
  else 
    log_error "Download file [$SOFTWARE_FILE] not found!"
    exit 1
  fi

  if [ -z "$DOWNLOAD_NAME" ]; then
    log_error "Download for [$1] [$2] not found!"
    exit 1
  fi

  return 0
}

download_file_ifpresent ()
{
  DOWNLOAD_SERVER=$1
  DOWNLOAD_FILE=$2
  TARGET_DIR=$3

  if [ -z "$DOWNLOAD_FILE" ]; then
    log_error "No download file specified!"
    exit 1
  fi

  CURL_RET=$($CURL_CMD "$DOWNLOAD_SERVER/$DOWNLOAD_FILE" --silent --head 2>&1 | grep 'HTTP/1.1 200 OK')
  if [ -z "$CURL_RET" ]; then
    echo "Download file does not exist [$DOWNLOAD_FILE]"
    return 0
  fi

  pushd .
  if [ -n "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    cd $TARGET_DIR
  fi

  if [ -e "$DOWNLOAD_FILE" ]; then
  	echo
    echo "Replacing existing file [$DOWNLOAD_FILE]"
    rm -f "$DOWNLOAD_FILE"
  fi

  echo
  $CURL_CMD "$DOWNLOAD_SERVER/$DOWNLOAD_FILE" -o "$(basename $DOWNLOAD_FILE)" 2>/dev/null
  echo

  if [ "$?" = "0" ]; then
    log_ok "Successfully downloaded: [$DOWNLOAD_FILE] "
    echo
    popd
    return 0

  else
    log_error "File [$DOWNLOAD_FILE] not downloaded correctly"
    popd
    exit 1
  fi
}

download_and_check_hash ()
{
  DOWNLOAD_SERVER=$1
  DOWNLOAD_STR=$2
  TARGET_DIR=$3

  if [ -z "$DOWNLOAD_FILE" ]; then
    log_error "No download file specified!"
    exit 1
  fi

  # check if file exists before downloading

  for CHECK_FILE in $(echo "$DOWNLOAD_STR" | tr "," "\n" ) ; do

    DOWNLOAD_FILE=$DOWNLOAD_SERVER/$CHECK_FILE
    CURL_RET=$($CURL_CMD "$DOWNLOAD_FILE" --silent --head 2>&1 | grep 'HTTP/1.1 200 OK')

    if [ ! -z "$CURL_RET" ]; then
      CURRENT_FILE="$CHECK_FILE"
      FOUND=TRUE
      break
    fi
  done

  if [ ! "$FOUND" = "TRUE" ]; then
    log_error "File [$DOWNLOAD_SERVER/$DOWNLOAD_STR] does not exist"
    exit 1
  fi

  pushd .

  if [ -n "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR"
  fi

  if [[ "$DOWNLOAD_FILE" =~ ".tar.gz" ]]; then
    TAR_OPTIONS=xz
  elif [[ "$DOWNLOAD_FILE" =~ ".taz" ]]; then
    TAR_OPTIONS=xz
  elif [[ "$DOWNLOAD_FILE" =~ ".tar" ]]; then
    TAR_OPTIONS=x
  else
    TAR_OPTIONS=""
  fi

  if [ -z "$TAR_OPTIONS" ]; then

    # download without extracting for none tar files
    
    echo
    local DOWNLOADED_FILE=$(basename $DOWNLOAD_FILE)
    $CURL_CMD "$DOWNLOAD_FILE" -o "$DOWNLOADED_FILE"

    if [ ! -e "$DOWNLOADED_FILE" ]; then
      log_error "File [$DOWNLOAD_FILE] not downloaded [1]"
      popd
      exit 1
    fi

    HASH=$(sha256sum -b $DOWNLOADED_FILE | cut -f1 -d" ")
    FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)

    if [ "$FOUND" = "1" ]; then
      log_ok "Successfully downloaded: [$DOWNLOAD_FILE] "
    else
      log_error "File [$DOWNLOAD_FILE] not downloaded correctly [1]"
    fi

  else
    if [ -e $SOFTWARE_FILE ]; then
      echo
      HASH=$($CURL_CMD $DOWNLOAD_FILE | tee >(tar $TAR_OPTIONS 2>/dev/null) | sha256sum -b | cut -d" " -f1)
      echo
      FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)

      if [ "$FOUND" = "1" ]; then
        log_ok "Successfully downloaded, extracted & checked: [$DOWNLOAD_FILE] "
        popd
        return 0

      else
        log_error "File [$DOWNLOAD_FILE] not downloaded correctly [2]"
        popd
        exit 1
      fi
    else
      echo
      $CURL_CMD $DOWNLOAD_FILE | tar $TAR_OPTIONS 2>/dev/null
      echo

      if [ "$?" = "0" ]; then
        log_ok "Successfully downloaded & extracted: [$DOWNLOAD_FILE] "
        popd
        return 0

      else
        log_error "File [$DOWNLOAD_FILE] not downloaded correctly [3]"
        popd
        exit 1
      fi
    fi
  fi

  popd
  return 0
}

check_file_busy()
{
  if [ ! -e "$1" ]; then
    return 0
  fi

  local TARGET_REAL_BIN=$(readlink -f $1)
  local FOUND_TARGETS=$(lsof "$TARGET_REAL_BIN" 2>/dev/null | grep "$TARGET_REAL_BIN")

  if [ -n "$FOUND_TARGETS" ]; then
    return 1
  else
    return 0
  fi
}

nsh_cmp()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ -z "$2" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 1
  fi

  if [ ! -e "$2" ]; then
    return 1
  fi

  if [ -x /usr/bin/cmp ]; then
    cmp -s "$1" "$2"
    return $?
  fi

  HASH1=$(sha256sum "$1" | cut -d" " -f1)
  HASH2=$(sha256sum "$2" | cut -d" " -f1)

  if [ "$HASH1" = "$HASH2" ]; then
    return 0
  fi

  return 1
}

install_file()
{
  SOURCE_FILE=$1
  TARGET_FILE=$2
  OWNER=$3
  GROUP=$4
  PERMS=$5

  if [ ! -r "$SOURCE_FILE" ]; then
    echo "[$SOURCE_FILE] Can not read source file"
    return 1
  fi

  if [ -e "$TARGET_FILE" ]; then

    nsh_cmp "$SOURCE_FILE" "$TARGET_FILE"
    if [ $? -eq 0 ]; then
      echo "[$TARGET_FILE] File did not change -- No update needed"
      return 0
    fi

    if [ ! -w "$TARGET_FILE" ]; then
      echo "[$TARGET_FILE] Can not update binary -- No write permissions"
      return 1
    fi

    check_file_busy "$TARGET_FILE"

    if [ $? -eq 1 ]; then
      echo "[$TARGET_FILE] Error - Can not update file -- Binary in use"
      return 1
    fi
  fi
  
  cp -f "$SOURCE_FILE" "$TARGET_FILE"
 
  if [ ! -z "$OWNER" ]; then
    chown $OWNER:$GROUP "$TARGET_FILE"
  fi

  if [ ! -z "$PERMS" ]; then
    chmod "$PERMS" "$TARGET_FILE"
  fi

  echo "[$TARGET_FILE] copied"

  return 2
}

create_directory ()
{
  TARGET_FILE=$1
  OWNER=$2
  GROUP=$3
  PERMS=$4

  if [ -z "$TARGET_FILE" ]; then
    return 0
  fi

  if [ -e "$TARGET_FILE" ]; then
    return 0
  fi
  
  mkdir -p "$TARGET_FILE"
  
  if [ ! -z "$OWNER" ]; then
    chown $OWNER:$GROUP "$TARGET_FILE"
  fi

  if [ ! -z "$PERMS" ]; then
    chmod "$PERMS" "$TARGET_FILE"
  fi
  
  return 0
}

remove_directory ()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi

  rm -rf "$1"

  if [ -e "$1" ]; then
    echo " --- directory not completely deleted! ---"
    ls -l "$1"
    echo " --- directory not completely deleted! ---"
  fi
  
  return 0
}

remove_file ()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi
  
  rm -rf "$1"
  return 0
}

install_res_links ()
{
  DOMINO_RES_DIR=$Notes_ExecDirectory/res
  GERMAN_LOCALE="de_DE.UTF-8"
  ENGLISH_LOCALE="en_US.UTF-8"

  cd $DOMINO_RES_DIR

  if [ ! -e "$DOMINO_RES_DIR/C" ]; then
    echo "Error: No default locate res files found ($DOMINO_RES_DIR/C)"
    return 1
  fi

  if [ ! -e "$DOMINO_RES_DIR/$GERMAN_LOCALE" ]; then
    echo "Creating symbolic link for German res files ($GERMAN_LOCALE)"
    ln -s C $GERMAN_LOCALE 
  fi

  if [ ! -e "$DOMINO_RES_DIR/$ENGLISH_LOCALE" ]; then
    echo "Creating symbolic link for English res files ($ENGLISH_LOCALE)"
    ln -s C $ENGLISH_LOCALE
  fi

  return 0
}

create_startup_link ()
{
  if [ -z "$1" ]; then
    return 0
  fi
  
  TARGET_PATH=$LOTUS/bin/$1
  SOURCE_PATH=$LOTUS/bin/tools/startup
  
  if [ ! -e "$TARGET_PATH" ]; then
    ln -f -s $SOURCE_PATH $TARGET_PATH 
    echo "Installed startup link for [$1]"
  fi

  return 0
}

get_domino_version ()
{
  DOMINO_INSTALL_DAT=$LOTUS/.install.dat

  if [ -e $DOMINO_INSTALL_DAT ]; then

    find_str=$(tail "$DOMINO_INSTALL_DAT" | grep "rev = " | awk -F " = " '{print $2}' | tr -d '"')

    if [ ! -z "$find_str" ]; then
      DOMINO_VERSION=$find_str

      if [ "$DOMINO_VERSION" = "11000000" ]; then
        DOMINO_VERSION=1100
      fi

      if [ "$DOMINO_VERSION" = "10000000" ]; then
        DOMINO_VERSION=1001
      fi

      if [ "$DOMINO_VERSION" = "90010" ]; then
        DOMINO_VERSION=901
      fi

    else
      DOMINO_VERSION="UNKNOWN"
    fi
  else
    DOMINO_VERSION="NONE"
  fi

  return 0
}

set_domino_version ()
{
  get_domino_version
  echo $PROD_VER > $DOMDOCK_TXT_DIR/domino_$1.txt
  echo $PROD_VER > $DOMINO_DATA_PATH/domino_$1.txt
}

check_installed_version ()
{
  VersionFile=$DOMDOCK_TXT_DIR/domino_$1.txt
  
  if [ ! -r $VersionFile ]; then
    return 0
  fi

 CHECK_VERSION=$(cat $VersionFile)
 INSTALL_VERSION=$(echo $2 | tr -d '.')
 
 if [ "$CHECK_VERSION" = "$INSTALL_VERSION" ]; then
   echo "Domino $INSTALL_VERSION already installed" 
   return 1
 else
   return 0
 fi
 
}

install_domino ()
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
  
  echo
  echo "Downloading Domino Installation files ..."
  echo
  
  if [ ! -z "$INST_VER" ]; then
    get_download_name $PROD_NAME $INST_VER
    download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" domino_server
  fi

  if [ ! -z "$INST_FP" ]; then
    get_download_name $PROD_NAME $INST_FP domino_fp
    download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" domino_fp
  fi

  if [ ! -z "$INST_HF" ]; then
    get_download_name $PROD_NAME $INST_HF domino_hf
    download_and_check_hash "$DownloadFrom" "$DOWNLOAD_NAME" domino_hf
  fi

  if [ ! -z "$INST_VER" ]; then
    header "Installing $PROD_NAME $INST_VER"
    pushd .

    echo
    echo "Running Domino Silent Install -- This takes a while ..."
    echo

    if [ "$INSTALLER_VERSION" = "10" ]; then

      # Install Domino 10 (Older Installer InstallShield Multi Platform)

      if [ -z "$DominoResponseFile" ]; then
        DominoResponseFile=domino10_response.dat
      fi

      case "$PROD_NAME" in
        domino)
          cd domino_server/linux64/domino
          ;;

        domino-ce)
          cd domino_server/linux64/DominoEval
          ;;

        *)
          log_error "Unknown product [$PROD_NAME] - Terminating installation"
          popd
          exit 1
          ;;
      esac

      ./install -silent -options "$INSTALL_DIR/$DominoResponseFile"
      
      mv "$Notes_ExecDirectory/DominoInstall.log" "$INST_DOM_LOG"
      check_file_str "$INST_DOM_LOG" "$DOM_V10_STRING_OK"

    else

      # Install Domino 11 and higher (Installer changed to InstallAnyware Multi Platform)

      if [ -z "$DominoResponseFile" ]; then
        DominoResponseFile=domino11_install.properties
      fi

      case "$PROD_NAME" in
        domino)
          cd domino_server/linux64
          ;;

        domino-ce)
          cd domino_server/linux64/DominoEval
          ;;

        *)
          log_error "Unknown product [$PROD_NAME] - Terminating installation"
          popd
          exit 1
          ;;
      esac


      ./install -f "$INSTALL_DIR/$DominoResponseFile" -i silent

      INSTALL_LOG=$(find $LOTUS -name "HCL_Domino_Install_*.log")

      mv "$INSTALL_LOG" "$INST_DOM_LOG"
      check_file_str "$INST_DOM_LOG" "$DOM_V11_STRING_OK"
    fi

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
      popd
      exit 1
    fi

    popd
    rm -rf domino_server

    # Copy license files
    mkdir -p /licenses
    cp $Notes_ExecDirectory/license/*.txt /licenses

  fi

  if [ ! -z "$INST_FP" ]; then
    header "Installing Fixpack $INST_FP"

    echo
    echo "Running Domino Fixpack Silent Install -- This takes a while ..."
    echo

    pushd .
    cd domino_fp/linux64/domino

    ./install -script script.dat > $INST_FP_LOG

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
      popd
      exit 1
    fi

    popd
    rm -rf domino_fp

  fi  

  if [ ! -z "$INST_HF" ]; then
    header "Installing IF/HF INST_HF"

    echo
    echo "Running Domino Iterimsfix/Hotfix Silent Install -- This takes a while ..."
    echo

    pushd .
    cd domino_hf/linux64

    ./install -script script.dat > $INST_HF_LOG

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

      popd
      exit 1
    fi

    popd
    rm -rf domino_hf

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
  PLUGINS_FOLDER=$OSGI_FOLDER"/eclipse/plugins"

  mkdir -p $PLUGINS_FOLDER
  pushd .
  cd $ADDON_NAME
  echo "Unzipping files .."
  unzip -q  *.zip
  unzip -q HCL_Verse.zip 

  echo "Copying files .."

  for JAR in eclipse/plugins/*.jar; do
    install_osgi_file "$JAR"
  done

  install_file "iwaredir.ntf" "$DOMINO_DATA_PATH/iwaredir.ntf" $DOMINO_USER $DOMINO_GROUP 644

  echo
  echo Installed $ADDON_NAME
  echo

  popd

}

docker_set_timezone ()
{
  if [ -z "$DOCKER_TZ" ]; then
    return 0
  fi

  CURRENT_TZ=$(readlink /etc/localtime)
  SET_TZ=/usr/share/zoneinfo/$DOCKER_TZ

  if [ "$CURRENT_TZ" = "$SET_TZ" ]; then
    echo
    echo "Timezone [$DOCKER_TZ] already set"
    echo
    return 0
  fi

  if [ ! -e "$SET_TZ" ]; then
    echo
    echo "Cannot read timezone [$SET_TZ] -- Timezone not changed"
    echo
    return 1
  fi

  echo
  echo "Timezone set to [$DOCKER_TZ]"
  echo
  ln -sf "$SET_TZ" /etc/localtime

  return 0
}

yum_glibc_lang_update7()
{
  # on CentOS/RHEL 7 the locale is not containing all langauges
  # removing override_install_langs from /etc/yum.conf and reinstalling glibc-common
  # reinstall does only work if package is up to date

  local STR="override_install_langs="
  local FILE="/etc/yum.conf"

  FOUND=$(grep "$STR" "$FILE")

  if [ -z "$FOUND" ]; then
    return 0
  fi

  grep -v -i "$STR" "$FILE" > "$FILE.updated"
  mv "$FILE.updated" "$FILE"

  echo
  echo Updating glibc locale ...
  echo


  if [ "$LinuxYumUpdate" = "yes" ]; then
    # packages have been already updated, just need reinstall
    yum reinstall -y glibc-common
  else  
    # update first before reinstall

    # RedHat update
    yum update -y glibc-common
    yum reinstall -y glibc-common
  fi

  return 0
}


yum_glibc_lang_update_allpacks()
{
  # install allpack to correct locale settings

  local ALL_LANGPACKS=$(rpm -q glibc-all-langpacks | grep "x86_64")

  echo

  if [ -z "$ALL_LANGPACKS" ]; then
    yum install -y glibc-all-langpacks
  else
    echo "Already installed: $ALL_LANGPACKS"
  fi

  echo
  return 0
}

yum_glibc_lang_update()
{
  # Not needed on SuSE platform with zypper
  if [ -x /usr/bin/zypper ]; then
    return 0
  fi

  case "$LINUX_VERSION" in
    7*)
      yum_glibc_lang_update7
      ;;
    *)
      yum_glibc_lang_update_allpacks
      ;;
  esac
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
echo "DominoMoveInstallData = [$DominoMoveInstallData]"
echo "DominoVersion         = [$DominoVersion]"
echo "DominoUserID          = [$DominoUserID]"
echo "LinuxYumUpdate        = [$LinuxYumUpdate]"
echo "VERSE_VERSION         = [$VERSE_VERSION]"

# Install CentOS updates if requested
if [ "$LinuxYumUpdate" = "yes" ]; then

  if [ -x /usr/bin/zypper ]; then

    header "Updating Linux via zypper"
    # SuSE update
    zypper refersh
    zypper update

  elif [ -x /usr/bin/yum ]; then

    header "Updating Linux via yum"
    # RedHat update
    yum update -y glibc-common

  fi
fi

LINUX_VERSION=$(cat /etc/os-release | grep "VERSION_ID="| cut -d= -f2 | xargs)
LINUX_PRETTY_NAME=$(cat /etc/os-release | grep "PRETTY_NAME="| cut -d= -f2 | xargs)

# Show current OS version
if [ -n "$LINUX_PRETTY_NAME" ]; then
  header "$LINUX_PRETTY_NAME"
fi

yum_glibc_lang_update

# This logic allows incremental installs for images based on each other (e.g. 10.0.1 -> 10.0.1FP1) 
if [ -e $LOTUS ]; then
  FIRST_TIME_SETUP=0
  echo
  echo "!! Incremantal install based on exiting Domino image !!"
  echo
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

  # Set User Local if configured
  if [ ! -z "$DOMINO_LANG" ]; then
    echo "export LANG=$DOMINO_LANG" >> /home/$DOMINO_USER/.bash_profile
  fi

  # Set security limits for pam modules (su needs it)
  echo >> /etc/security/limits.conf
  echo '# -- Begin Changes Domino --' >> /etc/security/limits.conf
  echo '* soft nofile 65535' >> /etc/security/limits.conf
  echo '* hard nofile 65535' >> /etc/security/limits.conf
  echo '# -- End Changes Domino --' >> /etc/security/limits.conf
 
else

  # Check for existing user's group and overwrite (for base images with different group - like root)
  export DOMINO_GROUP=`id -gn "$DOMINO_USER"`

fi

# Allow world full access to the main directories to ensure all mounts work.
# Those directories might get replaced with mount points or re-created on startup of the container when /local mount is used.
# Ensure only root can write into the script directory!

# if inheriting an existing installation, it's important to ensure /local has the right permissions

if [ -e "/local" ]; then
  chown -R $DOMINO_USER:$DOMINO_GROUP /local
fi

if [ -e "$DOMINO_DATA_PATH" ]; then
  chmod $DIR_PERM $DOMINO_DATA_PATH
fi

create_directory $DOMDOCK_DIR root root 777
create_directory $DOMDOCK_SCRIPT_DIR root root 755

create_directory /local $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory $DOMINO_DATA_PATH $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory /local/translog $DOMINO_USER $DOMINO_GROUP $DIR_PERM 
create_directory /local/daos $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory /local/nif $DOMINO_USER $DOMINO_GROUP $DIR_PERM
create_directory /local/ft $DOMINO_USER $DOMINO_GROUP $DIR_PERM

docker_set_timezone


# check if HCL Domino image is already installed -> in that case just set version
if [ -e "/tmp/notesdata.tbz2" ]; then
  set_domino_version ver
  FIRST_TIME_SETUP=
  DominoMoveInstallData=
  # set link to install data
  ln -s /tmp/notesdata.tbz2 $DOMDOCK_DIR/install_data_domino.taz

  NO_PERL_INSTALL=yes
fi


# Temporary install perl for installers if not already installed

  if [ -z "$NO_PERL_INSTALL" ]; then
  if [ ! -e /usr/bin/perl ]; then
    header "Installing perl"
    install_package perl
    # disable uninstall because git requires it
    # UNINSTALL_PERL_AFTER_INSTALL=yes
  fi
fi

# Yes we want git along like we want curl ;-)
# But than we need to keep Perl

if [ -n "$GIT_INSTALL" ]; then
  if [ ! -e /usr/bin/git ]; then
    header "Installing git"
    install_package install git
  fi
fi


if [ -n "$OPENSSL_INSTALL" ]; then
  if [ ! -e /usr/bin/openssl ]; then
    header "Installing openssl"
    install_package openssl 
  fi
fi


cd "$INSTALL_DIR"

# Download updated software.txt file if available
download_file_ifpresent "$DownloadFrom" software.txt "$INSTALL_DIR"

case "$PROD_NAME" in
  domino|domino-ce)
    install_domino
    ;;

  *)
    log_error "Unknown product [$PROD_NAME] - Terminating installation"
    exit 1
    ;;
esac

# Install Verse if requested
install_verse "$VERSE_VERSION"

# removing perl if temporary installed

if [ "$UNINSTALL_PERL_AFTER_INSTALL" = "yes" ]; then
  # removing perl 
  header "Uninstalling perl"
  remove_package perl
fi

header "Installing Start Script"

# Extracting start script files
cd $INSTALL_DIR
tar -xf start_script.tar

# explicitly set docker environment to ensure any Docker implementation works
export DOCKER_ENV=yes

# allow gdb to use sys ptrace --> needs to be granted explicitly on some container platforms

if [ -x /usr/bin/gdb ]; then
  if [ ! -L /usr/bin/gdb ]; then
    echo "symbolic link"
    setcap 'cap_sys_ptrace+ep' /usr/bin/gdb
    echo "Setting cap_sys_ptrace for /usr/bin/gdb"
  fi
fi

# some platforms like UBI use a sym link for gdb
if [ -x /usr/libexec/gdb ]; then
  if [ ! -L /usr/libexec/gdb ]; then
    setcap 'cap_sys_ptrace+ep' /usr/libexec/gdb
    echo "Setting cap_sys_ptrace for /usr/libexec/gdb"
  fi
fi

# Run start script installer
$INSTALL_DIR/start_script/install_script

# Install Setup Files and Docker Entrypoint
install_file "$INSTALL_DIR/SetupProfile.pds" "$DOMDOCK_DIR/SetupProfile.pds" $DOMINO_USER $DOMINO_GROUP 666
install_file "$INSTALL_DIR/SetupProfileSecondServer.pds" "$DOMDOCK_DIR/SetupProfileSecondServer.pds" $DOMINO_USER $DOMINO_GROUP 666

header "Final Steps & Configuration"

# Copy pre-start configuration
install_file "$INSTALL_DIR/docker_prestart.sh" "$DOMDOCK_SCRIPT_DIR/docker_prestart.sh" root root 755

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

# Copy tools required for automating Domino Server configuration
install_file "$INSTALL_DIR/DatabaseSigner.jar" "$DOMINO_DATA_PATH/DatabaseSigner.jar" root root 644
install_file "$INSTALL_DIR/DominoUpdateConfig.jar" "$DOMINO_DATA_PATH/DominoUpdateConfig.jar" root root 644

# --- Cleanup Routines to reduce image size ---

# Remove Fixpack/Hotfix backup files
find $Notes_ExecDirectory -maxdepth 1 -type d -name "100**" -exec rm -rf {} \; 2>/dev/null
find $Notes_ExecDirectory -maxdepth 1 -type d -name "110**" -exec rm -rf {} \; 2>/dev/null

# Remove not needed domino/html data to keep image smaller
find $DOMINO_DATA_PATH/domino/html -name "*.dll" -exec rm -rf {} \; 2>/dev/null
find $DOMINO_DATA_PATH/domino/html -name "*.msi" -exec rm -rf {} \; 2>/dev/null

remove_directory "$DOMINO_DATA_PATH/domino/html/download/filesets"
remove_directory "$DOMINO_DATA_PATH/domino/html/help"

# Remove Domino 10 and earlier uninstaller --> we never uninstall but rebuild from scratch
remove_directory "$Notes_ExecDirectory/_uninst"


# Remove Domino 11 and  higher uninstaller --> we never uninstall but rebuild from scratch
remove_directory "$Notes_ExecDirectory/_HCL Domino_installation"

# Domino 11 uses InstallAnywhere, which has it's own install JRE (see above)
remove_directory "$Notes_ExecDirectory/jre"

# Create missing links

create_startup_link kyrtool
create_startup_link dbmt
install_res_links

remove_file "$LOTUS/notes/latest/linux/tunekrnl"

# In some versions the Tika file is also in the data directory.
remove_file $DOMINO_DATA_PATH/tika-server.jar

# Ensure permissons are set correctly for data directory
chown -R $DOMINO_USER:$DOMINO_GROUP $DOMINO_DATA_PATH

if [ "$FIRST_TIME_SETUP" = "1" ]; then
  # Prepare data directory (compact NSFs and NTFs)

  header "Prepare $DOMINO_DATA_PATH via compact"

  su - $DOMINO_USER -c $INSTALL_DIR/domino_install_data_prep.sh
fi

# If configured, move data directory to a compressed tar file

if [ ! -z "$DominoMoveInstallData" ]; then

  INSTALL_DATA_TAR=$DOMDOCK_DIR/install_data_domino.taz

  header "Moving install data $DOMINO_DATA_PATH -> [$INSTALL_DATA_TAR]"

  cd $DOMINO_DATA_PATH
  remove_file "$INSTALL_DATA_TAR"
  tar -czf "$INSTALL_DATA_TAR" .

  rm -rf $DOMINO_DATA_PATH
  create_directory $DOMINO_DATA_PATH root root 777
fi

header "Successfully completed installation!"

exit 0

