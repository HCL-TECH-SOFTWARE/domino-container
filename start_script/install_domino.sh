#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2021 - APACHE 2.0 see LICENSE
############################################################################

# Domino on Linux installation script
# Version 1.0.1 06.11.2021

# - Installs required software
# - Adds notes:notes user and group
# - Creates directory structure in /local/ for the Domino server data (/local/notesdata, /local/translog, ...)
# - Installs NashCom Domino on Linux start script 
# - Creates a new NRPC firewall rule and opens ports NRPC, HTTP, HTTPS and SMTP
# - Installs Domino with default options using silent install 
# - Sets security limits


if [ -n "$DOWNLOAD_FROM" ]; then
  echo "Downloading and installing software from [$DOWNLOAD_FROM]"

elif [ -n "$SOFTWARE_DIR" ]; then
  echo "Installing software from [$SOFTWARE_DIR]"

else
  SOFTWARE_DIR=/local/software
  echo "Installing software from default location [$SOFTWARE_DIR]"
fi

# In any case set a software directory -- also when downloading
if [ -z "$SOFTWARE_DIR" ]; then
  SOFTWARE_DIR=/local/software
fi

if [ -z "$DOMINO_DATA_PATH" ]; then
  DOMINO_DATA_PATH=/local/notesdata
fi


PROD_NAME=domino

DOMINO_DOCKER_GIT_URL=https://github.com/IBM/domino-docker/raw/master
START_SCRIPT_URL=$DOMINO_DOCKER_GIT_URL/dockerfiles/domino/install_dir/start_script.tar
VERSION_FILE_NAME_URL=$DOMINO_DOCKER_GIT_URL/software/current_version.txt
SOFTWARE_FILE=$SOFTWARE_DIR/software.txt
VERSION_FILE=$SOFTWARE_DIR/current_version.txt
LOTUS=/opt/hcl/domino
PROD_VER_FILE=$LOTUS/DominoVersionInstalled.txt

SPECIAL_CURL_ARGS=
CURL_CMD="curl --fail --location --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

if [ -z "$DOMINO_USER" ]; then
  DOMINO_USER=notes
fi

if [ -z "$DOMINO_GROUP" ]; then
  DOMINO_GROUP=notes
fi

if [ -z "$DIR_PERM" ]; then
  DIR_PERM=770
fi


print_delim ()
{
  echo "--------------------------------------------------------------------------------"
}

log_ok ()
{
  echo
  echo "$1"
  echo
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

 elif [ -x /usr/bin/dnf ]; then
   dnf install -y "$@"

 elif [ -x /usr/bin/yum ]; then
   yum install -y "$@"

 elif [ -x /usr/bin/apt ]; then
   apt install -y "$@"

 else
  echo "No package manager found!"
  exit 1

 fi
}

remove_package()
{
 if [ -x /usr/bin/zypper ]; then
   zypper rm -y "$@"

 elif [ -x /usr/bin/dnf ]; then
   dnf remove -y "$@"

 elif [ -x /usr/bin/yum ]; then
   yum remove -y "$@"

 elif [ -x /usr/bin/apt ]; then
   apt remove -y "$@"

 fi
}

linux_update()
{
  if [ -x /usr/bin/zypper ]; then

    header "Updating Linux via zypper"
    zypper refresh
    zypper update -y

  elif [ -x /usr/bin/dnf ]; then

    header "Updating Linux via dnf"
    dnf update -y

  elif [ -x /usr/bin/yum ]; then

    header "Updating Linux via yum"
    yum update -y

  elif [ -x /usr/bin/apt ]; then

    header "Updating Linux via apt"
    apt-get update -y
    apt-get upgrade -y

  fi
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

  CURL_RET=$($CURL_CMD "$DOWNLOAD_SERVER/$DOWNLOAD_FILE" --silent --head 2>&1)
  STATUS_RET=$(echo $CURL_RET | grep -e 'HTTP/1.1 200 OK' -e 'HTTP/2 200')
  if [ -z "$STATUS_RET" ]; then

    log_ok "Info: Download file does not exist [$DOWNLOAD_FILE]"
    return 0
  fi

  SAVED_DIR=$(pwd)
  if [ -n "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    cd $TARGET_DIR
  fi

  if [ -e "$DOWNLOAD_FILE" ]; then
    log_ok "Replacing existing file [$DOWNLOAD_FILE]"
    rm -f "$DOWNLOAD_FILE"
  fi

  echo
  $CURL_CMD "$DOWNLOAD_SERVER/$DOWNLOAD_FILE" -o "$(basename $DOWNLOAD_FILE)" 2>/dev/null
  echo

  if [ "$?" = "0" ]; then
    log_ok "Successfully downloaded: [$DOWNLOAD_FILE] "
    cd "$SAVED_DIR"
    return 0

  else
    log_error "File [$DOWNLOAD_FILE] not downloaded correctly"
    echo "CURL returned: [$CURL_RET]"
    cd "$SAVED_DIR"
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
    CURL_RET=$($CURL_CMD "$DOWNLOAD_FILE" --silent --head 2>&1)
    STATUS_RET=$(echo $CURL_RET | grep -e 'HTTP/1.1 200 OK' -e 'HTTP/2 200')

    if [ -n "$STATUS_RET" ]; then
      CURRENT_FILE="$CHECK_FILE"
      FOUND=TRUE
      break
    fi
  done

  if [ ! "$FOUND" = "TRUE" ]; then
    log_error "File [$DOWNLOAD_FILE] does not exist"
    echo "CURL returned: [$CURL_RET]"
    exit 1
  fi

  SAVED_DIR=$(pwd)

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
      cd "$SAVED_DIR"
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
      echo "DOWNLOAD_FILE: [$DOWNLOAD_FILE]"
      HASH=$($CURL_CMD $DOWNLOAD_FILE | tee >(tar $TAR_OPTIONS 2>/dev/null) | sha256sum -b | cut -d" " -f1)
      echo
      FOUND=$(grep "$HASH" "$SOFTWARE_FILE" | grep "$CURRENT_FILE" | wc -l)

      if [ "$FOUND" = "1" ]; then
        log_ok "Successfully downloaded, extracted & checked: [$DOWNLOAD_FILE] "
        cd "$SAVED_DIR"
        return 0

      else
        log_error "File [$DOWNLOAD_FILE] not downloaded correctly [2]"
        cd "$SAVED_DIR"
        exit 1
      fi
    else
      echo
      $CURL_CMD $DOWNLOAD_FILE | tar $TAR_OPTIONS 2>/dev/null
      echo

      if [ "$?" = "0" ]; then
        log_ok "Successfully downloaded & extracted: [$DOWNLOAD_FILE] "
        cd "$SAVED_DIR"
        return 0

      else
        log_error "File [$DOWNLOAD_FILE] not downloaded correctly [3]"
        cd "$SAVED_DIR"
        exit 1
      fi
    fi
  fi

  cd "$SAVED_DIR"
  return 0
}

get_current_version ()
{
  if [ -n "$VERSION_FILE_NAME_URL" ]; then

    DOWNLOAD_FILE=$VERSION_FILE_NAME_URL

    CURL_RET=$($CURL_CMD -L "$DOWNLOAD_FILE" --silent --head 2>&1)
    STATUS_RET=$(echo $CURL_RET | grep -e 'HTTP/1.1 200 OK' -e 'HTTP/2 200')
    if [ -n "$STATUS_RET" ]; then
      DOWNLOAD_VERSION_FILE=$DOWNLOAD_FILE
    fi
  fi

  if [ -n "$DOWNLOAD_VERSION_FILE" ]; then
    log_ok "Getting current software version from [$DOWNLOAD_VERSION_FILE]"
    LINE=`$CURL_CMD -L --silent $DOWNLOAD_VERSION_FILE | grep "^$1|"`
  else
    if [ ! -r "$VERSION_FILE" ]; then
      log_ok "No current version file found! [$VERSION_FILE]"
    else
      log_ok "Getting current software version from [$VERSION_FILE]"
      LINE=`grep "^$1|" $VERSION_FILE`
    fi
  fi

  PROD_VER=`echo $LINE|cut -d'|' -f2`
  PROD_FP=`echo $LINE|cut -d'|' -f3`
  PROD_HF=`echo $LINE|cut -d'|' -f4`

  return 0
}

set_security_limits()
{
  header "Set security limits"

  local REQ_NOFILES_SOFT=80000
  local REQ_NOFILES_HARD=80000

  local SET_SOFT=
  local SET_HARD=
  local UPD=FALSE

  NOFILES_SOFT=$(su - $DOMINO_USER -c ulimit' -n')
  NOFILES_HARD=$(su - $DOMINO_USER -c ulimit' -Hn')

  if [ "$NOFILES_SOFT" -ne "$REQ_NOFILES_SOFT" ]; then
    SET_SOFT=$REQ_NOFILES_SOFT   
    UPD=TRUE
  fi

  if [ "$NOFILES_HARD" -ne "$REQ_NOFILES_HARD" ]; then
    SET_HARD=$REQ_NOFILES_HARD
    UPD=TRUE
  fi

  if [ "$UPD" = "FALSE" ]; then
    return 0
  fi

  echo >> /etc/security/limits.conf
  echo "# -- Domino configuation begin --" >> /etc/security/limits.conf

  if [ -n "$SET_HARD" ]; then
    echo "$DOMINO_USER  hard    nofile  $SET_HARD" >> /etc/security/limits.conf
  fi

  if [ -n "$SET_SOFT" ]; then
    echo "$DOMINO_USER  soft    nofile  $SET_SOFT" >> /etc/security/limits.conf
  fi

  echo "# -- Domino configuation end --" >> /etc/security/limits.conf
  echo >> /etc/security/limits.conf
  
}

config_firewall()
{
  header "Configure firewall"

  if [ ! -e /usr/sbin/firewalld ]; then
    echo "Firewalld not installed"
    return 0
  fi

  # add well known NRPC port
  cp $SOFTWARE_DIR/start_script/extra/firewalld/nrpc.xml /etc/firewalld/services/ 

  # reload just in case to let firewalld notice the change
  firewall-cmd --reload

  # enable NRPC, HTTP, HTTPS and SMTP in firewall
  firewall-cmd --zone=public --permanent --add-service={nrpc,http,https,smtp}

  # reload firewall changes
  firewall-cmd --reload
}

add_notes_user()
{
  header "Add Notes user"

  local NOTES_UID=$(id -u $DOMINO_USER 2>/dev/null)
  if [ -n "$NOTES_UID" ]; then
    echo "$DOMINO_USER user already exists (UID:$NOTES_UID)"
    return 0
  fi 

  # creates user and group

  groupadd $DOMINO_GROUP
  useradd $DOMINO_USER -g $DOMINO_GROUP -m
}

glibc_lang_update7()
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

  yum reinstall -y glibc-common

  return 0
}

glibc_lang_add()
{

  local INSTALL_LOCALE
  local INSTALL_LANG

  if [ -z "$1" ]; then
    INSTALL_LOCALE=$(echo $DOMINO_LANG|cut -f1 -d"_")
    INSTALL_LANG=$DOMINO_LANG

  else
    INSTALL_LOCALE=$(echo $1|cut -f1 -d"_")
    INSTALL_LANG=$1
  fi

  if [ -z "$INSTALL_LOCALE" ]; then
    return 0
  fi

  header "Installing locale [$INSTALL_LOCALE]"

  CHECK_LOCALE_INSTALLED=$(locale -a | grep "^$INSTALL_LOCALE")

  if [ -n "$CHECK_LOCALE_INSTALLED" ]; then
    echo "Locale [$INSTALL_LOCALE] already installed"
    return 0
  fi

  # Ubuntu
  if [ "$LINUX_ID" = "ubuntu" ]; then
    install_package language-pack-$INSTALL_LOCALE
  fi

  # Debian
  if [ "$LINUX_ID" = "debian" ]; then
    # Debian has locales already installed
    return 0
  fi

  #Photon OS
  if [ "$LINUX_ID" = "photon" ]; then

    install_package glibc-i18n
    echo "$INSTALL_LANG UTF-8" >> /etc/locale-gen.conf
    locale-gen.sh
    #yum remove -y glibc-i18n

    return 0
  fi

  # Only needed for centos like platforms -> check if yum is installed

  if [ ! -x /usr/bin/yum ]; then
    return 0
  fi

  if [ "$LINUX_VERSION" = "7" ]; then
      yum_glibc_lang_update7
  else
    yum install -y glibc-langpack-$INSTALL_LOCALE
  fi

  return 0
}

install_software()
{
  # updates Linux
  # don't run automatic update
  # linux_update

  # adds epel repository for additional software packages on RHEL/CentOS/Fedora platforms

  case "$LINUX_ID_LIKE" in

    *fedora*|*rhel*)
      install_package epel-release
    ;;

  esac

  # epel on Oracle Linux has a different name

  case "$LINUX_PRETTY_NAME" in

    Oracle*)
      local MAJOR_VER=$(echo $LINUX_PLATFORM_ID | cut -d ":" -f2)
      install_package oracle-epel-release-$MAJOR_VER
    ;;

  esac

  # install required and useful packages
  install_package gdb hostname tar sysstat net-tools jq gettext

  # additional packages by platform

  if [ "$LINUX_ID" = "photon" ]; then
    # Photon OS packages
    install_package bindutils

  elif [ -x /usr/bin/apt ]; then
    # Ubuntu needs different packages and doesn't provide some others
    install_package bind9-utils

  else

    # RHEL/CentOS/Fedora
    case "$LINUX_ID_LIKE" in
      *fedora*|*rhel*)
        install_package procps-ng which bind-utils
      ;;
    esac
  fi

  # first check if platform supports perl-libs
  if [ ! -x /usr/bin/perl ]; then
    install_package perl-libs
  fi

  # if not found install full perl package
  if [ ! -x /usr/bin/perl ]; then
    install_package perl
  fi
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

create_directories()
{
  header "Create directory structure /local ..."

  # creates local directory structure with the right owner 

  create_directory /local $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/notesdata $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/translog $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/daos $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/nif $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/ft $DOMINO_USER $DOMINO_GROUP $DIR_PERM
  create_directory /local/backup $DOMINO_USER $DOMINO_GROUP $DIR_PERM

  mkdir -p $SOFTWARE_DIR
}

set_sh_shell()
{
  ORIG_SHELL_LINK=$(readlink /bin/sh)

  if [ -z "$1" ]; then
     echo "Current sh: [$ORIG_SHELL_LINK]"
     ORIG_SHELL_LINK=
     return 0
  fi

  if [ "$ORIG_SHELL_LINK" = "$1" ]; then
    ORIG_SHELL_LINK=
    return 0
  fi

  echo "Switching sh shell from [$ORIG_SHELL_LINK] to [$1]"

  local SAVED_DIR=$(pwd)
  cd /bin
  ln -sf "$1" sh
  cd "$SAVED_DIR"

  return 1
}

install_start_script()
{
  header "Install Nash!Com Domino start script"
  
  # Downloads and installs the latest Domino start script from the Domino Docker Community image GitHub repo

  cd $SOFTWARE_DIR 
  $CURL_CMD -sL $START_SCRIPT_URL -o start_script.tar

  if [ -e start_script ]; then
    rm -rf start_script
  fi

  tar -xf start_script.tar
  start_script/install_script
  rm -rf start_script.tar

}

cleanup_install_data ()
{
  remove_directory $SOFTWARE_DIR/start_script
}

get_notes_ini_var()
{
  # $1 = filename
  # $2 = ini.variable

  ret_ini_var=""
  if [ -z "$1" ]; then
    return 0
  fi

  if [ -z "$2" ]; then
    return 0
  fi

  ret_ini_var=`awk -F '=' -v SEARCH_STR="$2" '{if (tolower($1) == tolower(SEARCH_STR)) print $2}' $1 | xargs`
  return 0
}

set_notes_ini_var()
{
  # updates or sets notes.ini parameter
  local FILE=$1
  local VAR=$2
  local NEW=$3
  local LINE_FOUND=
  local LINE_NEW="$VAR=$NEW"

  LINE_FOUND=$(grep -i "^$VAR=" $FILE)

  if [ -z "$LINE_FOUND" ]; then
    echo "$LINE_NEW"  >> $FILE
    return 0
  fi

  sed -i "s~${LINE_FOUND}~${LINE_NEW}~g" "$FILE"

  return 0
}

setup_notes_ini()
{
  # Avoid Domino Directory Design Update Prompt
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "SERVER_UPGRADE_NO_DIRECTORY_UPGRADE_PROMPT" "1"

  # Allow server names with dots and undercores
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "ADMIN_IGNORE_NEW_SERVERNAMING_CONVENTION" "1"

  # Ensure current ODS is used for V12 -> does not harm on earlier releases
  set_notes_ini_var $DOMINO_DATA_PATH/notes.ini "Create_R12_Databases" "1"
}

install_domino()
{
  header "Install Domino"

  # If no version was speficed find current version
  if [ -z "$PROD_VER" ]; then
    get_current_version $PROD_NAME 
  fi

  if [ -e "$LOTUS/bin/server" ]; then

    # If Domino was installed by this routine, there is a version file
    if [ -e "$PROD_VER_FILE" ]; then
  
      PROD_VER_INSTALLED=$(head -1 $PROD_VER_FILE)

      if [ "$PROD_FORCE_INSTALL" = "yes" ]; then
        log_ok "Re-installing Domino $PROD_VER"

      elif [ "$PROD_VER" = "$PROD_VER_INSTALLED" ]; then
        log_ok "Domino $PROD_VER already installed"
        return 0

      else
        log_ok "Updating Domino $PROD_VER_INSTALLED -> $PROD_VER"
      fi

    else
      log_ok "Domino already installed"
      return 0
    fi

  else
    log_ok "Installing Domino $PROD_VER"
  fi

  # Gets download name stored in GitHub repo 

  download_file_ifpresent "$DOMINO_DOCKER_GIT_URL/software" software.txt "$SOFTWARE_DIR"

  get_download_name $PROD_NAME $PROD_VER

  # Either extract existing files or download, check hash and unpack Domino web-kit

  if [ -e $SOFTWARE_DIR/$DOWNLOAD_NAME ]; then

   echo "Extracting existing web kit [$DOWNLOAD_NAME]"
   cd $SOFTWARE_DIR
   tar -xf $DOWNLOAD_NAME

  elif [ -n "$DOWNLOAD_FROM" ]; then
      download_and_check_hash "$DOWNLOAD_FROM" "$DOWNLOAD_NAME"
  else

    DOWNLOAD_LINK_FLEXNET="https://hclsoftware.flexnetoperations.com/flexnet/operationsportal/DownloadSearchPage.action?search="
    DOWNLOAD_LINK_FLEXNET_OPTIONS="+&resultType=Files&sortBy=eff_date&listButton=Search"

    CURRENT_DOWNLOAD_URL="$DOWNLOAD_LINK_FLEXNET$DOWNLOAD_NAME$DOWNLOAD_LINK_FLEXNET_OPTIONS"

    header "Software download"
    echo "Please download [$DOWNLOAD_NAME] from FlexNet to [$SOFTWARE_DIR]"
    echo
    echo 1. Log into Flexnet first: https://hclsoftware.flexnetoperations.com
    echo 2. Visit the following URL:
    echo 
    echo $CURRENT_DOWNLOAD_URL
    echo 

    exit 1
  fi

  # Installs Domino with silent response file

  # Switch default sh shell from dash to bash on Ubuntu and Debian for Domino install
  set_sh_shell bash

  cd $SOFTWARE_DIR/linux64
  ./install -f "$(pwd)/responseFile/installer.properties" -i silent
  
  # Switch back sh shell if changed
  if [ -n "$ORIG_SHELL_LINK" ]; then
    set_sh_shell "$ORIG_SHELL_LINK"
  fi

  cd $SOFTWARE_DIR 
  rm -rf linux64

  echo $PROD_VER > $PROD_VER_FILE

}

print_runtime()
{
  echo

  # the following line does not work on OSX
  # echo "Completed in" `date -d@$SECONDS -u +%T`

  hours=$((SECONDS / 3600))
  seconds=$((SECONDS % 3600))
  minutes=$((seconds / 60))
  seconds=$((seconds % 60))
  h=""; m=""; s=""
  if [ ! $hours =  "1" ] ; then h="s"; fi
  if [ ! $minutes =  "1" ] ; then m="s"; fi
  if [ ! $seconds =  "1" ] ; then s="s"; fi

  if [ ! $hours =  0 ] ; then echo "Completed in $hours hour$h, $minutes minute$m and $seconds second$s"
  elif [ ! $minutes = 0 ] ; then echo "Completed in $minutes minute$m and $seconds second$s"
  else echo "Completed in $seconds second$s"; fi
}

must_be_root()
{
  if [ "$EUID" = "0" ]; then
    return 0
  fi

  log_error "Installation requires root permissions. Switch to root or try 'sudo'"
  exit 1
}


# -- Main logic --

SAVED_DIR=$(pwd)

LINUX_VERSION=$(cat /etc/os-release | grep "VERSION_ID="| cut -d= -f2 | xargs)
LINUX_PRETTY_NAME=$(cat /etc/os-release | grep "PRETTY_NAME="| cut -d= -f2 | xargs)
LINUX_ID=$(cat /etc/os-release | grep "^ID="| cut -d= -f2 | xargs)
LINUX_ID_LIKE=$(cat /etc/os-release | grep "^ID_LIKE="| cut -d= -f2 | xargs)
LINUX_PLATFORM_ID=$(cat /etc/os-release | grep "^PLATFORM_ID="| cut -d= -f2 | xargs)

if [ -z "$LINUX_PRETTY_NAME" ]; then
  echo "Unsupported platform!"
  exit 1
fi

LINUX_VM_INFO=
if [ -n "$(uname -r|grep microsoft)" ]; then
  LINUX_VM_INFO="on WSL"
fi

header "Nash!Com Domino Installer for $LINUX_PRETTY_NAME $LINUX_VM_INFO"

must_be_root
add_notes_user
create_directories
install_software

# Add locales
if [ -z "$DOMINO_LANG" ]; then
  glibc_lang_add en_US.UTF-8
  glibc_lang_add de_DE.UTF-8
else
  glibc_lang_add
fi

# Set posix locale for installing Domino to ensure the right res/C link
export LANG=C

install_start_script
install_domino
setup_notes_ini
set_security_limits
config_firewall
cleanup_install_data

cd $SAVED_DIR

echo
echo "Done"
print_runtime
echo
