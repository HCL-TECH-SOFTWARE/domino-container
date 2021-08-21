#!/bin/bash

############################################################################
# Copyright Nash!Com, Daniel Nashed 2021 - APACHE 2.0 see LICENSE
############################################################################

# Domino on Linux installation script

# - Installs required software
# - Adds notes:notes user and group
# - Creates directory structure in /local/ for the Domino server data (/local/notesdata, /local/translog, ...)
# - Installs NashCom Domino on Linux start script 
# - Creates a new NRPC firewall rule and opens ports NRPC, HTTP, HTTPS and SMTP
# - Installs Domino with default options using silent install 
# - Sets security limits


SOFTWARE_DIR=/local/software

#DOWNLOAD_FROM=http://127.0.0.1:7777
PROD_NAME=domino

DOMINO_DOCKER_GIT_URL=https://github.com/IBM/domino-docker/raw/master
START_SCRIPT_URL=$DOMINO_DOCKER_GIT_URL/dockerfiles/domino/install_dir/start_script.tar
VERSION_FILE_NAME_URL=$DOMINO_DOCKER_GIT_URL/software/current_version.txt
SOFTWARE_FILE=$SOFTWARE_DIR/software.txt
VERSION_FILE=$SOFTWARE_DIR/current_version.txt
LOTUS=/opt/hcl/domino

SPECIAL_CURL_ARGS=
CURL_CMD="curl --fail --location --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"

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

    echo "Info: Download file does not exist [$DOWNLOAD_FILE]"
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
    echo "CURL returned: [$CURL_RET]"
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
      echo "DOWNLOAD_FILE: [$DOWNLOAD_FILE]"
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
    echo "Getting current software version from [$DOWNLOAD_VERSION_FILE]"
    LINE=`$CURL_CMD -L --silent $DOWNLOAD_VERSION_FILE | grep "^$1|"`
  else
    if [ ! -r "$VERSION_FILE" ]; then
      echo "No current version file found! [$VERSION_FILE]"
    else
      echo "Getting current software version from [$VERSION_FILE]"
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

  NOFILES_SOFT=$(su - notes -c ulimit' -n')
  NOFILES_HARD=$(su - notes -c ulimit' -Hn')

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
    echo "notes  hard    nofile  $SET_HARD" >> /etc/security/limits.conf
  fi

  if [ -n "$SET_SOFT" ]; then
    echo "notes  soft    nofile  $SET_SOFT" >> /etc/security/limits.conf
  fi

  echo "# -- Domino configuation end --" >> /etc/security/limits.conf
  echo >> /etc/security/limits.conf
  
}

config_firewall()
{
  header "Configure firewall"

  # add well known NRPC port
  cp /local/software/start_script/extra/firewalld/nrpc.xml /etc/firewalld/services/ 

  # enable NRPC, HTTP, HTTPS and SMTP in firewall
  firewall-cmd --zone=public --permanent --add-service={nrpc,http,https,smtp}

  # reload firewall changes
  firewall-cmd --reload
}

add_notes_user()
{
  header "Add Notes user"

  local NOTES_UID=$(id -u notes 2>/dev/null)
  if [ -n "$NOTES_UID" ]; then
    echo "notes user already exists (UID:$NOTES_UID)"
    return 0
  fi 

  # creates notes:notes user and group
  adduser notes -U
}

install_software()
{
  # updates CentOS 
  yum -y update 

  # adds repository for additional software packages
  yum -y install epel-release 

  # installes required and useful packages
  yum -y install gdb perl-libs jq sysstat git bind-utils net-tools
}


create_directories()
{
  header "Create directory structure /local.."

  # creates local directory structure with the right owner notes:notes
  mkdir -p $SOFTWARE_DIR 
  mkdir -p /local/notesdata
  mkdir -p /local/translog
  mkdir -p /local/nif
  mkdir -p /local/ft
  chown -R notes:notes /local
  chown  -R notes:notes $SOFTWARE_DIR
}

install_start_script()
{
  header "Install Nash!Com Domino start script"
  
  # Downloads and installs the latest Domino start script from the Domino Docker Community image GitHub repo

  cd $SOFTWARE_DIR 
  $CURL_CMD -L $START_SCRIPT_URL -o start_script.tar

  if [ -e start_script ]; then
    rm -rf start_script
  fi

  tar -xf start_script.tar
  start_script/install_script

}

install_domino()
{
  header "Install Domino"

  if [ -e "$LOTUS/bin/server" ]; then
    echo "Domino already installed"
    return 0
  fi

  # Determines current version
  if [ -z "$PROD_VER" ]; then
    get_current_version $PROD_NAME 
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
    echo "Please download software from FlexNet to [$SOFTWARE_DIR]"
    echo
    echo 1. Log into Flexnet first: https://hclsoftware.flexnetoperations.com
    echo 2. Visit the following URL:
    echo 
    echo $CURRENT_DOWNLOAD_URL
    echo 

    exit 1
  fi

  # Installs Domino with silent response file

  cd $SOFTWARE_DIR/linux64
  ./install -f "$(pwd)/responseFile/installer.properties" -i silent
  
  cd $SOFTWARE_DIR 
  rm -rf linux64

}

SAVED_DIR=$(pwd)

header "Nash!Com Domino Installer"

add_notes_user
create_directories
install_software
install_start_script
install_domino
set_security_limits
config_firewall

cd $SAVED_DIR

echo
echo "Done"
echo
