#!/bin/bash
############################################################################
# Copyright Nash!Com, Daniel Nashed 2019, 2025  - APACHE 2.0 see LICENSE
# Copyright IBM Corporation 2015, 2020 - APACHE 2.0 see LICENSE
############################################################################

# Version 2.4.4 24.11.2025

# Main Script to build images.
# Run without parameters for detailed syntax.
# The script checks if software is available at configured location (download location or local directory).
# In case of a local software directory it hosts the software on a local NGINX container.

SCRIPT_NAME=$(readlink -f $0)
SCRIPT_DIR=$(dirname $SCRIPT_NAME)

# Standard configuration overwritten by build.cfg
# (Default) NGINX is used hosting software from the local "software" directory.

# Default: Update Linux base image while building the image

if [ -z "LinuxYumUpdate" ]; then
  LinuxYumUpdate=yes
fi

# Default: Check if software exits
CHECK_SOFTWARE=yes

CONTAINER_BUILD_SCRIPT_VERSION=2.4.4

# OnTime version
SELECT_ONTIME_VERSION_DOMINO14=1.11.1
SELECT_ONTIME_VERSION_DOMINO145=2.3.0

# Build kit shortens the output. This isn't really helpful for troubleshooting and following the build process ...
export BUILDKIT_PROGRESS=plain


if [ "$1" == "--version" ]; then
  echo $CONTAINER_BUILD_SCRIPT_VERSION
  exit 0
fi

# ----------------------------------------


ClearScreen()
{
  if [ "$DISABLE_CLEAR_SCREEN" = "yes" ]; then
    return 0
  fi

  clear
}


log_error()
{
  echo
  echo $@
  echo
}


log_error_exit()
{
  echo
  echo $@
  echo

  exit 1
}

log()
{
  echo
  echo $@
  echo
}


remove_file()
{
  if [ -z "$1" ]; then
    return 1
  fi

  if [ ! -e "$1" ]; then
    return 2
  fi

  rm -f "$1"
  return 0
}


check_version()
{
  count=1

  while true
  do
    VER=$(echo $1|cut -d"." -f $count)
    CHECK=$(echo $2|cut -d"." -f $count)

    if [ -z "$VER" ]; then return 0; fi
    if [ -z "$CHECK" ]; then return 0; fi

    if [ $VER -gt $CHECK ]; then return 0; fi
    if [ $VER -lt $CHECK ]; then
      echo "Warning: Unsupported $3 version $1 - Must be at least $2 !"
      sleep 1
      return 1
    fi

    count=$(expr $count + 1)
  done

  return 0
}

check_timezone()
{
  LARCH=$(uname)

  echo

  # If Timezone is not set use host's timezone
  if [ -z "$DOCKER_TZ" ]; then

    case "$LARCH" in

      Linux|Darwin)
        DOCKER_TZ=$(readlink /etc/localtime | awk -F'/zoneinfo/' '{print $2}')
        ;;

      *)
        DOCKER_TZ=""
      ;;
    esac

    echo "Using OS Timezone : [$DOCKER_TZ]"

  else

    if [ -e "/usr/share/zoneinfo/$DOCKER_TZ" ]; then
      echo "Timezone configured: [$DOCKER_TZ]"
    else
      log_error_exit "Invalid timezone specified [$DOCKER_TZ]"
    fi

  fi

  echo
  return 0
}

detect_container_environment()
{

  if [ -n "$CONTAINER_CMD" ]; then
    return 0
  fi

  if [ -n "$USE_DOCKER" ]; then
     CONTAINER_CMD=docker
     return 0
  fi

  if [ -n "$USE_PODMAN" ]; then
     CONTAINER_CMD=podman
     return 0
  fi

  CONTAINER_RUNTIME_VERSION_STR=$(podman -v 2> /dev/null | head -1)
  if [ -n "$CONTAINER_RUNTIME_VERSION_STR" ]; then
    CONTAINER_CMD=podman

    DOCKER_VERSION_STR=$(docker -v 2> /dev/null | head -1)

    if [ -n "$DOCKER_VERSION_STR" ]; then
       if [ "$DOCKER_VERSION_STR" != "$CONTAINER_RUNTIME_VERSION_STR" ]; then
         DISPLAY_WARNING="Docker & Podman detected - Expert only configuration (Docker is recommended!)"
       fi
    fi

    return 0
  fi

  CONTAINER_RUNTIME_VERSION_STR=$(nerdctl -v 2> /dev/null | head -1)
  if [ -n "$CONTAINER_RUNTIME_VERSION_STR" ]; then
    CONTAINER_CMD=nerdctl
    return 0
  fi

  CONTAINER_RUNTIME_VERSION_STR=$(docker -v 2> /dev/null | head -1)
  if [ -n "$CONTAINER_RUNTIME_VERSION_STR" ]; then
    CONTAINER_CMD=docker
    return 0
  fi

  if [ -z "$CONTAINER_CMD" ]; then
    log "No container environment detected!"
    exit 1
  fi

  return 0
}

check_container_environment()
{
  DOCKER_MINIMUM_VERSION="26.0.0"
  PODMAN_MINIMUM_VERSION="3.3.0"

  CONTAINER_ENV_NAME=
  CONTAINER_RUNTIME_VERSION=

  # No container environment required for native installs
  if [ "$INSTALL_DOMINO_NATIVE" = "yes" ]; then
    CONTAINER_CMD=NATIVE-INSTALL
    return 0
  fi

  detect_container_environment

  if [ "$CONTAINER_CMD" = "docker" ]; then

    CONTAINER_ENV_NAME=docker
    if [ -z "$CONTAINER_RUNTIME_VERSION_STR" ]; then
      CONTAINER_RUNTIME_VERSION_STR=$(docker -v 2> /dev/null | head -1)
    fi
    CONTAINER_RUNTIME_VERSION=$(echo $CONTAINER_RUNTIME_VERSION_STR | awk -F'version ' '{print $2 }'|cut -d"," -f1)

    # Check container environment
    check_version "$CONTAINER_RUNTIME_VERSION" "$DOCKER_MINIMUM_VERSION" "$CONTAINER_CMD"

    # Use sudo for docker command if not root on Linux

    if [ $(uname) = "Linux" ]; then
      if [ ! "$EUID" = "0" ]; then
        if [ "$DOCKER_USE_SUDO" = "yes" ]; then
          CONTAINER_CMD="sudo $CONTAINER_CMD"
        fi
      fi
    fi

  fi

  if [ "$CONTAINER_CMD" = "podman" ]; then

    check_version "$CONTAINER_RUNTIME_VERSION" "$PODMAN_MINIMUM_VERSION" "$CONTAINER_CMD"

    CONTAINER_ENV_NAME=podman
    if [ -z "$CONTAINER_RUNTIME_VERSION_STR" ]; then
      CONTAINER_RUNTIME_VERSION_STR=$(podman -v 2> /dev/null | head -1)
    fi
    CONTAINER_RUNTIME_VERSION=$(echo $CONTAINER_RUNTIME_VERSION_STR | awk -F'version ' '{print $2 }')

  fi

  if [ "$CONTAINER_CMD" = "nerdctl" ]; then

    CONTAINER_ENV_NAME=nerdctl
    if [ -z "$CONTAINER_RUNTIME_VERSION_STR" ]; then
      CONTAINER_RUNTIME_VERSION_STR=$(nerdctl -v 2> /dev/null | head -1)
    fi
    CONTAINER_RUNTIME_VERSION=$(echo $CONTAINER_RUNTIME_VERSION_STR | awk -F'version ' '{print $2 }')

    if [ -z "$CONTAINER_NAMESPACE" ]; then
      CONTAINER_NAMESPACE=k8s.io
    fi

    # Always add namespace option to nerdctl command line
    CONTAINER_CMD="$CONTAINER_CMD --namespace=$CONTAINER_NAMESPACE"

    # nerdctl does not support a network name during build
    CONTAINER_BUILD_DISABLE_HOST_NET=1

  else

    if [ -n "$DOCKER_NETWORK_NAME" ]; then
      CONTAINER_NETWORK_CMD="--network=$DOCKER_NETWORK_NAME"
    fi
  fi

  return 0
}


show_version ()
{
  echo
  echo HCL Domino Container Build Script
  echo ---------------------------------
  echo "Version $CONTAINER_BUILD_SCRIPT_VERSION"
  echo "(Running on $CONTAINER_ENV_NAME Version $CONTAINER_RUNTIME_VERSION)"
  echo
  return 0
}

usage()
{
  # check container environment first
  check_container_environment

  echo
  show_version
  echo
  echo "Usage: $(basename $SCRIPT_NAME) { domino | safelinx } version fp hf"
  echo
  echo "-checkonly       checks without build"
  echo "-verifyonly      checks download file checksum without build"
  echo "-(no)check       checks if files exist (default: yes)"
  echo "-(no)verify      checks downloaded file checksum (default: no)"
  echo "-(no)url         shows all download URLs, even if file is downloaded (default: no)"
  echo "-(no)linuxupd    updates container Linux while building image (default: yes)"
  echo "cfg|config       edits config file (either in current directory or if created in home dir)"
  echo "cpcfg            copies standard config file to config directory (default: $CONFIG_FILE)"
  echo "-cfgdir=<dir>    manually specify configuration directory (Default: ~/.DominoContainer)"

  echo
  echo "-tag=<image>     additional image tag"
  echo "-push=<image>    tag and push image to registry"
  echo "-autotest        test image after build"
  echo "testimage=<img>  test specified image"
  echo "-scan            scans a container image with Trivy for known vulnerabilities (CVEs)"
  echo "-scan=<file>     scans a container with Trivy and writes the result to a file"
  echo "                 file names ending with .json result in a JSON formatted file (CVE count is written to console)"
  echo "menu             invokes the build menu. the build menu is also invoked when no option is specified"
  echo "-menu=<file>     uses the specified menu name. Default is no menu file is specified: default.conf"
  echo
  echo Options
  echo
  echo "-conf            uses the default.conf file to build an image (see menu for details)"
  echo "-conf=<file>     uses the specified file to build an image"
  echo "-from=<image>    builds from a specified build image. there are named images like 'ubi' predefined"
  echo "-imagename=<img> defines the target image name"
  echo "-imagetag=<img>  defines the target image tag"
  echo "-save=<img>      exports the image after build. e.g. -save=domino-container.tgz"
  echo "-tz=<timezone>   explicitly set container timezone during build. by default Linux TZ is used"
  echo "-locale=<locale> specify Linux locale to install (e.g. de_DE.UTF-8)"
  echo "-lang=<lang>     specify Linux glibc language pack to install (e.g. de,it,fr). Multiple languages separated by comma"
  echo "-homedir=<dir>   custom home directory for notes user"
  echo "-pull            always try to pull a newer base image version"
  echo "-nginx=<img>     custom image name. if it is not available, it is build from Redhat UBI minimal"
  echo "-openssl         adds OpenSSL to Domino image"
  echo "-ssh             adds OpenSSL client to Domino image (-borg option always includes SSH client)"
  echo "-borg            adds borg client and Domino Borg Backup integration to image"
  echo "-verse           adds Verse to a Domino image"
  echo "-nomad           adds the Nomad server to a Domino image"
  echo "-traveler        adds the Traveler server to a Domino image"
  echo "-leap            adds the Domino Leap to a Domino image"
  echo "-capi            adds the C-API SDK/toolkit to a Domino image"
  echo "-domlp=xx        adds the specified Language Pack to the image"
  echo "-restapi         adds the Domino REST API to the image"
  echo "-ontime          adds OnTime from Domino V14 web-kit to the image"
  echo "-domiq           adds the Domino IQ server run-time to the image"
  echo "-mysql-jdbc      adds the MySQL JDBC driver to the image"
  echo "-postgresql-jdbc adds the PostgreSQL JDBC driver to the image"
  echo "-tika            updates the Tika server to the Domino server"
  echo "-iqsuite         adds GBS iQ.Suite to the container image under /opt"
  echo "-nshmailx        installs Nash!Com nshmailx simple mail send tool"
  echo "-node_exporter   installs Prometheus node_exporter into the container"
  echo "-domprom         installs Domino Prometheus statistics exporter"
  echo "-prometheus/prom installs Domino Prometheus statistics exporter & Node Exporter"
  echo "-k8s-runas       adds K8s runas user support"
  echo "-startscript=x   installs specified start script version from software repository"
  echo "-custom-addon=x  specify a tar file with additional Domino add-on software to install format: (https://)file.taz#sha256checksum"
  echo "-software=<dir>  explicitly specify SOFTWARE_DIR and override cfg file "
  echo
  echo "-linuxpkg=<pkg>       add on or more Linux packages to the container image. Multiple pgks are separated by blank and require quotes"
  echo "-linuxpkgskip=<pkg>   skip adding on or more Linux packages to the container image. Multiple pgks are separated by blank and require quotes"
  echo "-linuxpkgremove=<pkg> remove on or more Linux packages from the container image. Multiple pgks are separated by blank and require quotes"
  echo
  echo "SafeLinx options:"
  echo
  echo "-nomadweb        adds the latest Nomad Web version to a SafeLinx image"
  echo "-mysql           adds the MySQL client to the SafeLinx image"
  echo "-mssql           adds the Mircosoft SQL Server client to the SafeLinx image"
  echo
  echo "Build container:"
  echo
  echo " -apline_build_env create a Alpine based build container image for compiling C/C++ applications (nashcom/alpine_build_env)"
  echo
  echo "Special commands:"
  echo
  echo "save <img> <my.tgz>   exports the specified image to tgz format (e.g. save hclcom/domino:latest domino.tgz)"
  echo
  echo "Examples:"
  echo
  echo "  $(basename $SCRIPT_NAME) domino1 14.5 fp1"
  echo "  $(basename $SCRIPT_NAME) traveler 14.5 fp1"
  echo

  return 0
}


print_delim()
{
  echo "--------------------------------------------------------------------------------"
}

header()
{
  echo
  print_delim
  echo "$1"
  print_delim
  echo
}

dump_config()
{
  header "Build Configuration"
  echo "Build Environment      : [$CONTAINER_CMD] $CONTAINER_RUNTIME_VERSION"
  echo "BASE_IMAGE             : [$BASE_IMAGE]"
  echo "DOWNLOAD_FROM          : [$DOWNLOAD_FROM]"
  echo "SOFTWARE_DIR           : [$SOFTWARE_DIR]"
  echo "PROD_NAME              : [$PROD_NAME]"
  echo "PROD_VER               : [$PROD_VER]"
  echo "PROD_FP                : [$PROD_FP]"
  echo "PROD_HF                : [$PROD_HF]"
  echo "DOMLP_VER              : [$DOMLP_VER]"
  echo "DOMRESTAPI_VER         : [$DOMRESTAPI_VER]"
  echo "PROD_DOWNLOAD_FILE     : [$PROD_DOWNLOAD_FILE]"
  echo "PROD_FP_DOWNLOAD_FILE  : [$PROD_FP_DOWNLOAD_FILE]"
  echo "PROD_HF_DOWNLOAD_FILE  : [$PROD_HF_DOWNLOAD_FILE]"
  echo "TRAVELER_DOWNLOAD_FILE : [$TRAVELER_DOWNLOAD_FILE]"
  echo "RESTAPI_DOWNLOAD_FILE  : [$RESTAPI_DOWNLOAD_FILE]"
  echo "PROD_EXT               : [$PROD_EXT]"
  echo "CHECK_SOFTWARE         : [$CHECK_SOFTWARE]"
  echo "CHECK_HASH             : [$CHECK_HASH]"
  echo "DOWNLOAD_URLS_SHOW     : [$DOWNLOAD_URLS_SHOW]"
  echo "TAG_LATEST             : [$TAG_LATEST]"
  echo "TAG_IMAGE              : [$TAG_IMAGE]"
  echo "PUSH_IMAGE             : [$PUSH_IMAGE]"
  echo "DOCKER_FILE            : [$DOCKER_FILE]"
  echo "VERSE_VERSION          : [$VERSE_VERSION]"
  echo "NOMAD_VERSION          : [$NOMAD_VERSION]"
  echo "TRAVELER_VERSION       : [$TRAVELER_VERSION]"
  echo "LEAP_VERSION           : [$LEAP_VERSION]"
  echo "CAPI_VERSION           : [$CAPI_VERSION]"
  echo "NOMADWEB_VERSION       : [$NOMADWEB_VERSION]"
  echo "DOMIQ                  : [$DOMIQ]"
  echo "MYSQL_JDBC_VERSION     : [$MYSQL_JDBC_VERSION]"
  echo "MYSQL_INSTALL          : [$MYSQL_INSTALL]"
  echo "MSSQL_INSTALL          : [$MSSQL_INSTALL]"
  echo "POSTGRESQL_JDBC_VERSION: [$POSTGRESQL_JDBC_VERSION]"
  echo "BORG_VERSION           : [$BORG_VERSION]"
  echo "DOMBORG_VERSION        : [$DOMBORG_VERSION]"
  echo "TIKA_VERSION           : [$TIKA_VERSION]"
  echo "IQSUITE_VERSION        : [$IQSUITE_VERSION]"
  echo "NSHMAILX_VERSION       : [$NSHMAILX_VERSION]"
  echo "NODE_EXPORTER_VERSION  : [$NODE_EXPORTER_VERSION]"
  echo "DOMPROM_VERSION        : [$DOMPROM_VERSION]"
  echo "LINUX_PKG_ADD          : [$LINUX_PKG_ADD]"
  echo "LINUX_PKG_REMOVE       : [$LINUX_PKG_REMOVE]"
  echo "LINUX_PKG_SKIP         : [$LINUX_PKG_SKIP]"
  echo "LINUX_HOMEDIR          : [$LINUX_HOMEDIR]"
  echo "STARTSCRIPT_VER        : [$STARTSCRIPT_VER]"
  echo "CUSTOM_ADD_ONS         : [$CUSTOM_ADD_ONS]"
  echo "EXPOSED_PORTS          : [$EXPOSED_PORTS]"
  echo "LinuxYumUpdate         : [$LinuxYumUpdate]"
  echo "DOMINO_LANG            : [$DOMINO_LANG]"
  echo "LINUX_LANG             : [$LINUX_LANG]"
  echo "DOCKER_TZ              : [$DOCKER_TZ]"
  echo "NAMESPACE              : [$CONTAINER_NAMESPACE]"
  echo "K8S_RUNAS_USER         : [$K8S_RUNAS_USER_SUPPORT]"
  echo "SPECIAL_CURL_ARGS      : [$SPECIAL_CURL_ARGS]"
  echo "DominoResponseFile     : [$DominoResponseFile]"
  echo "BUILD_SCRIPT_OPTIONS   : [$BUILD_SCRIPT_OPTIONS]"
  echo
  return 0
}

check_build_nginx_image()
{
  if [ -z "$NGINX_IMAGE_NAME" ]; then
    return 0
  fi

  local IMAGE_ID="$($CONTAINER_CMD inspect --format "{{.ID}}" $NGINX_IMAGE_NAME 2>/dev/null)"

  if [ -n "$IMAGE_ID" ]; then
    # Image already exists
    log "Info: $NGINX_IMAGE_NAME already exists"
    sleep 1
    return 0
  fi

  header "Building NGINX Image $NGINX_IMAGE_NAME ..."

  if [ -z "$NGINX_BASE_IMAGE" ]; then
    NGINX_BASE_IMAGE=registry.access.redhat.com/ubi10/ubi-minimal:latest
  fi

  # Get Build Time
  BUILDTIME=$(date +"%d.%m.%Y %H:%M:%S")

  # Switch to directory containing the dockerfiles
  cd dockerfiles

  export BUILDAH_FORMAT

  $CONTAINER_CMD build --no-cache $BUILD_OPTIONS $BUILD_OPTION_NET $DOCKER_PULL_OPTION -f dockerfile_nginx -t $NGINX_IMAGE_NAME --build-arg NGINX_BASE_IMAGE=$NGINX_BASE_IMAGE .

  cd ..

  local IMAGE_ID="$($CONTAINER_CMD inspect --format "{{.ID}}" $NGINX_IMAGE_NAME 2>/dev/null)"

  if [ -z "$IMAGE_ID" ]; then
    log_error_exit "Cannot find NGINX container image: $NGINX_IMAGE_NAME"
  fi
}


build_squid_image()
{
  if [ -z "$SQUID_IMAGE_NAME" ]; then
    return 0
  fi

  check_timezone
  check_container_environment

  header "Building Squid Image $SQUID_IMAGE_NAME ..."

  if [ -z "$SQUID_BASE_IMAGE" ]; then
    SQUID_BASE_IMAGE=registry.access.redhat.com/ubi10/ubi-minimal:latest
  fi

  # Get Build Time
  BUILDTIME=$(date +"%d.%m.%Y %H:%M:%S")

  # Switch to directory containing the dockerfiles
  cd dockerfiles

  export BUILDAH_FORMAT

  $CONTAINER_CMD build --no-cache $BUILD_OPTIONS $BUILD_OPTION_NET $DOCKER_PULL_OPTION -f dockerfile_squid -t $SQUID_IMAGE_NAME --build-arg SQUID_BASE_IMAGE=$SQUID_BASE_IMAGE .

  cd ..

}


build_alpine_build_env()
{

  NASHCOM_ALPINE_BUILD_IMAGE_NAME=nashcom/alpine_build_env

  header "Building $NASHCOM_ALPINE_BUILD_IMAGE_NAME ..."

  # Switch to directory containing the dockerfiles
  cd dockerfiles

  export BUILDAH_FORMAT

  $CONTAINER_CMD build --no-cache -f dockerfile_alpine_build_environment -t $NASHCOM_ALPINE_BUILD_IMAGE_NAME .

  cd ..
  echo
  print_runtime

}


nginx_start()
{

  if [ "$INSTALL_DOMINO_NATIVE" = "yes" ]; then
    return 0
  fi

  # Create a nginx container hosting software download locally

  local IMAGE_NAME=docker.io/library/nginx:latest

  if [ -n "$NGINX_IMAGE_NAME" ]; then
    check_build_nginx_image
    IMAGE_NAME=$NGINX_IMAGE_NAME
  elif [ -n "$NGINX_IMAGE" ]; then
    IMAGE_NAME=$NGINX_IMAGE
  fi

  # Check if we already have this container in status exited
  STATUS="$($CONTAINER_CMD inspect --format '{{ .State.Status }}' $SOFTWARE_CONTAINER 2>/dev/null)"

  if [ -z "$STATUS" ]; then
    echo "Creating Docker container: $SOFTWARE_CONTAINER hosting [$SOFTWARE_DIR] based on [$IMAGE_NAME]"
    $CONTAINER_CMD run --name $SOFTWARE_CONTAINER -p $SOFTWARE_PORT:80 -v $SOFTWARE_DIR:/usr/share/nginx/html:Z -d $IMAGE_NAME
  elif [ "$STATUS" = "exited" ]; then
    echo "Starting existing Docker container: $SOFTWARE_CONTAINER"
    $CONTAINER_CMD start $SOFTWARE_CONTAINER
  fi

  echo "Starting Docker container: $SOFTWARE_CONTAINER"

  # Start local nginx container to host SW Repository

  if [ -z "$BUILD_OPTION_NET" ]; then

    SOFTWARE_REPO_IP="$($CONTAINER_CMD inspect --format '{{ .NetworkSettings.IPAddress }}' $SOFTWARE_CONTAINER 2>/dev/null)"
    if [ -z "$SOFTWARE_REPO_IP" ]; then
      echo "No specific IP address using host address"
      SOFTWARE_REPO_IP=$(hostname --all-ip-addresses | cut -f1 -d" "):$SOFTWARE_PORT
    fi
  else
    SOFTWARE_REPO_IP=127.0.0.1:$SOFTWARE_PORT
  fi

  DOWNLOAD_FROM=http://$SOFTWARE_REPO_IP
  echo "Hosting HCL Software repository on $DOWNLOAD_FROM"
  echo
}

nginx_stop()
{
  if [ "$INSTALL_DOMINO_NATIVE" = "yes" ]; then
    return 0
  fi

  # Stop and remove SW repository

  $CONTAINER_CMD stop $SOFTWARE_CONTAINER
  $CONTAINER_CMD container rm $SOFTWARE_CONTAINER
  echo "Stopped & Removed Software Repository Container"
  echo
}

print_runtime()
{
  hours=$((SECONDS / 3600))
  seconds=$((SECONDS % 3600))
  minutes=$((seconds / 60))
  seconds=$((seconds % 60))
  h=""; m=""; s=""
  if [ ! $hours = "1" ] ; then h="s"; fi
  if [ ! $minutes = "1" ] ; then m="s"; fi
  if [ ! $seconds = "1" ] ; then s="s"; fi
  if [ ! $hours = 0 ] ; then echo "Completed in $hours hour$h, $minutes minute$m and $seconds second$s"
  elif [ ! $minutes = 0 ] ; then echo "Completed in $minutes minute$m and $seconds second$s"
  else echo "Completed in $seconds second$s"; fi
  echo
}

http_head_check()
{
  local CURL_RET=$($CURL_CMD -w 'RESP_CODE:%{response_code}\n' --silent --head "$1" | grep 'RESP_CODE:200')

  if [ -z "$CURL_RET" ]; then
    return 0
  else
    return 1
  fi
}

get_current_version_txt()
{
  # Use cached data and not load it very time
  if [ -z "$CURRENT_VERSION_TXT" ]; then

    if [ -n "$DOWNLOAD_FROM" ]; then
      DOWNLOAD_FILE="$DOWNLOAD_FROM/$VERSION_FILE_NAME"
      http_head_check "$DOWNLOAD_FILE"
      if [ "$?" = "1" ]; then
        DOWNLOAD_VERSION_FILE="$DOWNLOAD_FILE"
      fi
    fi

    if [ -n "$DOWNLOAD_VERSION_FILE" ]; then
      CURRENT_VERSION_TXT=$($CURL_CMD --silent "$DOWNLOAD_VERSION_FILE")
    else
      if [ ! -r "$VERSION_FILE" ]; then
        echo "No current version file found! [$VERSION_FILE]"
      else
       CURRENT_VERSION_TXT=$(cat "$VERSION_FILE")
      fi
    fi
  fi
}


get_current_version()
{
  get_current_version_txt
  LINE=$(echo "$CURRENT_VERSION_TXT" | grep "^$1|")

  if [ -z "$2" ]; then
    PROD_VER=$(echo $LINE|cut -d'|' -f2)
    PROD_FP=$(echo $LINE|cut -d'|' -f3)
    PROD_HF=$(echo $LINE|cut -d'|' -f4)

  else
    export $2=$(echo $LINE|cut -d'|' -f2)$(echo $LINE|cut -d'|' -f3)$(echo $LINE|cut -d'|' -f4)
  fi

  return 0
}


get_current_addon_version()
{
  local S1=$2
  local S2=${!2}

  get_current_version_txt
  LINE=$(echo "$CURRENT_VERSION_TXT" | grep "^$1|")
  export $2=$(echo $LINE|cut -d'|' -f2 -s)

  return 0
}


copy_config_file()
{
  if [ -e "$CONFIG_FILE" ]; then
    echo "Config File [$CONFIG_FILE] already exists!"
    return 0
  fi

  mkdir -p $DOMINO_DOCKER_CFG_DIR
  if [ -e "$BUILD_CFG_FILE" ]; then
    cp "$BUILD_CFG_FILE" "$CONFIG_FILE"
  else
    echo "Cannot copy config file"
  fi
}


edit_config_file()
{
  if [ ! -e "$CONFIG_FILE" ]; then
    echo
    echo "Creating new config file [$CONFIG_FILE]"
    sleep 3
    copy_config_file
  fi

  $EDIT_COMMAND $CONFIG_FILE

  # Apply changes after editing the profile
  . $CONFIG_FILE
}


check_for_hcl_image()
{
  # If the base is the HCL Domino image,
  # Also bypass software download check.
  # But check if the image is available.

  case "$FROM_IMAGE" in

    domino-docker*)
      LINUX_NAME="HCL Base Image"
      BASE_IMAGE=$FROM_IMAGE
      ;;

    *)
      return 0
      ;;
  esac

  IMAGE_ID=$($CONTAINER_CMD images $BASE_IMAGE -q)
  if [ -z "$IMAGE_ID" ]; then
    log_error_exit "Base image [$FROM_IMAGE] does not exist"
  fi

  # Derive version from Docker image name
  PROD_NAME=domino
  PROD_VER=$(echo $FROM_IMAGE | cut -d":" -f 2 -s)

  # don't check software
  CHECK_SOFTWARE=no
  CHECK_HASH=no
}

check_from_image()
{
  if [ -z "$FROM_IMAGE" ]; then

    if [ "$PROD_NAME" = "domino" ]; then
      FROM_IMAGE=ubi-minimal
    elif [ "$PROD_NAME" = "traveler" ]; then
      FROM_IMAGE=hclcom/domino:latest
    elif [ "$PROD_NAME" = "leap" ]; then
      FROM_IMAGE=hclcom/domino:latest
    elif [ "$PROD_NAME" = "safelinx" ]; then
      FROM_IMAGE=ubi-minimal
    else
      FROM_IMAGE=ubi-minimal
    fi
  fi

  case "$FROM_IMAGE" in

    centos|centos10)
      LINUX_NAME="CentOS Stream 10 (Coughlan)"
      BASE_IMAGE=quay.io/centos/centos:stream10
      ;;

    centos9)
      LINUX_NAME="CentOS Stream 9"
      BASE_IMAGE=quay.io/centos/centos:stream9
      ;;

    rocky10)
      LINUX_NAME="Rocky Linux 10 (Red Quartz)"
      BASE_IMAGE=docker.io/rockylinux/rockylinux:10
      ;;

    rocky9)
      LINUX_NAME="Rocky Linux 9 (Blue Onyx)"
      BASE_IMAGE=docker.io/rockylinux/rockylinux:9
      ;;

    rocky|rocky-minimal|rocky10-minimal)
      LINUX_NAME="Rocky Linux 10 (Red Quartz)"
      BASE_IMAGE=docker.io/rockylinux/rockylinux:10-minimal
      ;;

    rocky9-minimal)
      LINUX_NAME="Rocky Linux 9 (Blue Onyx)"
      BASE_IMAGE=docker.io/rockylinux/rockylinux:9-minimal
      ;;

    rocky8)
      LINUX_NAME="Rocky Linux 8"
      BASE_IMAGE=docker.io/rockylinux/rockylinux:8
      ;;

    alma|alma10)
      LINUX_NAME="Alma Linux 10 (Purple Lion)"
      BASE_IMAGE=almalinux:10
      ;;

    alma9)
      LINUX_NAME="Alma Linux 9 (Moss Jungle Cat)"
      BASE_IMAGE=almalinux:9
      ;;

    alma8)
      LINUX_NAME="Alma Linux 8"
      BASE_IMAGE=almalinux:8
      ;;

    amazon)
      LINUX_NAME="Amazon Linux"
      BASE_IMAGE=docker.io/amazonlinux
      ;;

    oracle10)
      LINUX_NAME="Oracle Linux Server 10"
      BASE_IMAGE=oraclelinux:10
      ;;

    oracle|oracle9)
      LINUX_NAME="Oracle Linux Server 9"
      BASE_IMAGE=oraclelinux:9
      ;;

    photon|photon5)
      LINUX_NAME="VMware Photon OS/Linux 5"
      BASE_IMAGE=docker.io/photon:5.0
      ;;

    ubi|ubi10)
      LINUX_NAME="Red Hat Enterprise Linux 10 (Coughlan)"
      BASE_IMAGE=registry.access.redhat.com/ubi10
      ;;

    ubi9)
      LINUX_NAME="Red Hat Enterprise Linux 9 (Plow)"
      BASE_IMAGE=registry.access.redhat.com/ubi9
      ;;

    ubi-minimal|ubi10-minimal)
      LINUX_NAME="Red Hat Enterprise Linux 10 (Coughlan)"
      BASE_IMAGE=registry.access.redhat.com/ubi10/ubi-minimal
      ;;

    ubi9-minimal)
      LINUX_NAME="Red Hat Enterprise Linux 9 (Plow)"
      BASE_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal
      ;;

    ubuntu|ubuntu24)
      LINUX_NAME="Ubuntu 24.04 LTS (Noble Numbat)"
      BASE_IMAGE=ubuntu:noble
      ;;

    ubuntu22)
      LINUX_NAME="Ubuntu 22.04 LTS (Jammy Jellyfish)"
      BASE_IMAGE=ubuntu:jammy
      ;;

    debian13)
      LINUX_NAME="Debian 13 (Trixie)"
      BASE_IMAGE=debian:13
      ;;

    debian|debian12)
      LINUX_NAME="Debian 12 (Bookworm)"
      BASE_IMAGE=debian:12
      ;;

    debian11)
      LINUX_NAME="Debian 11 (Bullseye)"
      BASE_IMAGE=debian:11
      ;;

    leap)
      LINUX_NAME="SUSE Leap"
      BASE_IMAGE=opensuse/leap
      ;;

    leap16)
      LINUX_NAME="SUSE Leap 16.0"
      BASE_IMAGE=opensuse/leap:16.0
      ;;

    leap15.6)
      LINUX_NAME="SUSE Leap 15.6"
      BASE_IMAGE=opensuse/leap:15.6
      ;;

    bci)
      LINUX_NAME="SUSE Enterprise"
      BASE_IMAGE=registry.suse.com/bci/bci-base
      ;;

    bci16|bci16.0)
      LINUX_NAME="SUSE Enterprise 16.0"
      BASE_IMAGE=registry.suse.com/bci/bci-base:16.0
      ;;

    bci15.6)
      LINUX_NAME="SUSE Enterprise 15.6"
      BASE_IMAGE=registry.suse.com/bci/bci-base:15.6
      ;;

    tumbleweed)
      LINUX_NAME="SUSE Tumbleweed (experimental)"
      BASE_IMAGE=opensuse/tumbleweed
      ;;

    fedora)
      LINUX_NAME="Fedora (experimental)"
      BASE_IMAGE=fedora:latest
      ;;

    archlinux)
      LINUX_NAME="Arch Linux (experimental)"
      BASE_IMAGE=docker.io/archlinux
       log_error_exit "Cannot build on Arch Linux because it is a  rolling Linux distribution not compatibile with Domino"
      ;;

    kali)
      LINUX_NAME="Kali Linux (experimental)"
      BASE_IMAGE=docker.io/kalilinux/kali-rolling
      ;;

    *)
      LINUX_NAME=$FROM_IMAGE
      BASE_IMAGE=$FROM_IMAGE
      echo "Info: Manual specified base image used! [$FROM_IMAGE]"
      ;;

  esac

  echo "Base Image - $LINUX_NAME"
}


set_standard_image_labels()
{

  if [ -z "$CONTAINER_MAINTAINER" ]; then
    CONTAINER_MAINTAINER="thomas.hampel, daniel.nashed@nashcom.de"
  fi

  if [ -z "$CONTAINER_VENDOR" ]; then
    CONTAINER_VENDOR="Domino Container Community Project"
  fi

  if [ -z "$CONTAINER_DOMINO_NAME" ]; then
    CONTAINER_DOMINO_NAME="HCL Domino Community Image"
  fi

  if [ -z "$CONTAINER_DOMINO_DESCRIPTION" ]; then
    CONTAINER_DOMINO_DESCRIPTION="HCL Domino Enterprise Server"
  fi

  if [ -z "$CONTAINER_TRAVELER_NAME" ]; then
    CONTAINER_TRAVELER_NAME="HCL Traveler Community Image"
  fi

  if [ -z "$CONTAINER_TRAVELER_DESCRIPTION" ]; then
    CONTAINER_TRAVELER_DESCRIPTION="HCL Traveler Mobile Sync Server"
  fi

  if [ -z "$CONTAINER_VOLT_NAME" ]; then
    CONTAINER_VOLT_NAME="HCL Volt Community Image"
  fi

  if [ -z "$CONTAINER_VOLT_DESCRIPTION" ]; then
    CONTAINER_VOLT_DESCRIPTION="HCL Volt - Low Code platform"
  fi

  if [ -z "$CONTAINER_LEAP_NAME" ]; then
    CONTAINER_LEAP_NAME="HCL Domino Leap Community Image"
  fi

  if [ -z "$CONTAINER_LEAP_DESCRIPTION" ]; then
    CONTAINER_LEAP_DESCRIPTION="HCL Domino Leap - Low Code platform"
  fi


  if [ -z "$CONTAINER_SAFELINX_NAME" ]; then
    CONTAINER_SAFELINX_NAME="HCL SafeLinx Community Image"
  fi

  if [ -z "$CONTAINER_SAFELINX_DESCRIPTION" ]; then
    CONTAINER_SAFELINX_DESCRIPTION="HCL SafeLinx - Secure reverse proxy & VPN"
  fi

  if [ -z "$CONTAINER_OPENSHIFT_EXPOSED_SERVICES" ]; then
    CONTAINER_OPENSHIFT_EXPOSED_SERVICES="1352:nrpc 80:http 110:pop3 143:imap 389:ldap 443:https 636:ldaps 993:imaps 995:pop3s"
  fi

  if [ -z "$CONTAINER_OPENSHIFT_MIN_MEMORY" ]; then
    CONTAINER_OPENSHIFT_MIN_MEMORY="2Gi"
  fi

  if [ -z "$CONTAINER_OPENSHIFT_MIN_CPU" ]; then
    CONTAINER_OPENSHIFT_MIN_CPU=2
  fi

}

check_exposed_ports()
{

  # Allow custom exposed ports
  if [ -n "$EXPOSED_PORTS" ]; then
    return 0
  fi

  EXPOSED_PORTS="1352 25 80 110 143 389 443 465 587 636 993 995 63148 63149"

  if [ -n "$NOMAD_VERSION" ]; then
    EXPOSED_PORTS="$EXPOSED_PORTS 9443"
  fi

  if [ -n "$NODE_EXPORTER_VERSION" ]; then
    EXPOSED_PORTS="$EXPOSED_PORTS 9100"
  fi

  return 0
}

add_custom_addon_label()
{
  local ADDON_NAME=
  local ADDON_VER=
  local ADDON_TEXT=

  if [ -z "$1" ]; then
    return 0
  fi

  ADDON_NAME="$(basename $(echo $1| cut -f1 -d# | cut -f1 -d'.'))"
  ADDON_VER="$(echo $1| cut -f3 -d#)"

  if [ -z "$ADDON_VER" ]; then
     ADDON_TEXT="$ADDON_NAME"
  else
     ADDON_TEXT="$ADDON_NAME=$ADDON_VER"
  fi

  if [ -z "$CONTAINER_DOMINO_CUSTOM_ADDONS" ]; then
    CONTAINER_DOMINO_CUSTOM_ADDONS="$ADDON_TEXT"
  else
    CONTAINER_DOMINO_CUSTOM_ADDONS="$CONTAINER_DOMINO_CUSTOM_ADDONS,$ADDON_TEXT"
  fi
}


check_custom_addon_label()
{

  if [ -z "$CUSTOM_ADD_ONS" ]; then
    return 0
  fi

  local CUSTOM_INSTALL_FILE=

  for CUSTOM_INSTALL_FILE in $(echo "$CUSTOM_ADD_ONS" | tr "," "\n" ) ; do
     add_custom_addon_label "$CUSTOM_INSTALL_FILE"
  done
}


add_addon_label()
{

  if [ -z "$1" ]; then
    return 0
  fi

  if [ -z "$2" ]; then
    return 0
  fi

  if [ -z "$CONTAINER_DOMINO_ADDONS" ]; then
    CONTAINER_DOMINO_ADDONS="$1=$2"
  else
    CONTAINER_DOMINO_ADDONS="$CONTAINER_DOMINO_ADDONS,$1=$2"
  fi
}


check_addon_label()
{
  if [ "$DOCKER_FILE" = "dockerfile_hcl" ] || [ "$DominoResponseFile" = "domino14_full_install.properties" ]; then

    # HCL container image build and full installer file: Verse, Nomad, OnTime
    if [ -z "$VERSE_VERSION" ]; then
      add_addon_label "verse" "installed"
    fi

    if [ -z "$NOMAD_VERSION" ]; then
      add_addon_label "nomad" "installed"
    fi

    add_addon_label "ontime" "$ONTIME_VERSION"

  elif [ "$DominoResponseFile" = "domino14_ontime_install.properties" ]; then

    # OnTime is added from Domino V14 WebKit
    add_addon_label "ontime" "$ONTIME_VERSION"
  fi

  if [ -n "$DOMLP_LANG" ]; then
    add_addon_label "languagepack" "$DOMLP_LANG"
  fi

  if [ -n "$VERSE_VERSION" ]; then
    add_addon_label "verse" "$VERSE_VERSION"
  fi

  if [ -n "$NOMAD_VERSION" ]; then
    add_addon_label "nomad" "$NOMAD_VERSION"
  fi

  if [ -n "$TRAVELER_VERSION" ]; then
    add_addon_label "traveler" "$TRAVELER_VERSION"
  fi

  if [ -n "$DOMRESTAPI_VER" ]; then
    add_addon_label "domrestapi" "$DOMRESTAPI_VER"
  fi

  if [ -n "$CAPI_VERSION" ]; then
    add_addon_label "capi" "$CAPI_VERSION"
  fi

  if [ -n "$DOMIQ_VERSION" ]; then
    add_addon_label "domiq" "$DOMIQ_VERSION"
  fi

  if [ -n "$LEAP_VERSION" ]; then
    add_addon_label "leap" "$LEAP_VERSION"
  fi

  if [ -n "$IQSUITE_VERSION" ]; then
    add_addon_label "iqsuite" "$IQSUITE_VERSION"
  fi

  if [ -n "$DOMPROM_VERSION" ]; then
    add_addon_label "domprom" "$DOMPROM_VERSION"
  fi

  if [ -n "$NODE_EXPORTER_VERSION" ]; then
    add_addon_label "node_exporter" "$NODE_EXPORTER_VERSION"
  fi

  if [ -n "$BORG_VERSION" ]; then
    add_addon_label "borg" "$BORG_VERSION"
  fi

  if [ -n "$DOMBORG_VERSION" ]; then
    add_addon_label "domborg" "$DOMBORG_VERSION"
  fi

  if [ -n "$NSHMAILX_VERSION" ]; then
    add_addon_label "nshmailx" "$NSHMAILX_VERSION"
  fi

  if [ -n "$MYSQL_JDBC_VERSION" ]; then
    add_addon_label "mysql-jdbc" "$MYSQL_JDBC_VERSION"
  fi

  if [ -n "$POSTGRESQL_JDBC_VERSION" ]; then
    add_addon_label "postgresql-jdbc" "$POSTGRESQL_JDBC_VERSION"
  fi

}


build_domino()
{
  CONTAINER_DOMINO_ADDONS=
  check_addon_label
  check_custom_addon_label

  echo
  echo "CONTAINER_DOMINO_ADDONS: [$CONTAINER_DOMINO_ADDONS]"
  echo "CONTAINER_DOMINO_CUSTON_ADDONS: [$CONTAINER_DOMINO_CUSTOM_ADDONS]"
  echo

  $CONTAINER_CMD build --no-cache $BUILD_OPTIONS $BUILD_OPTION_NET $DOCKER_PULL_OPTION \
    $CONTAINER_NETWORK_CMD \
    -t $DOCKER_IMAGE \
    -f $DOCKER_FILE \
    --label maintainer="$CONTAINER_MAINTAINER" \
    --label name="$CONTAINER_DOMINO_NAME" \
    --label vendor="$CONTAINER_VENDOR" \
    --label description="$CONTAINER_DOMINO_DESCRIPTION" \
    --label summary="$CONTAINER_DOMINO_DESCRIPTION" \
    --label version="$DOCKER_IMAGE_VERSION" \
    --label buildtime="$BUILDTIME" \
    --label release="$BUILDTIME" \
    --label architecture="x86_64" \
    --label io.k8s.description="$CONTAINER_DOMINO_DESCRIPTION" \
    --label io.k8s.display-name="$CONTAINER_DOMINO_NAME" \
    --label io.openshift.tags="domino" \
    --label io.openshift.expose-services="$CONTAINER_OPENSHIFT_EXPOSED_SERVICES" \
    --label io.openshift.non-scalable=true \
    --label io.openshift.min-memory="$CONTAINER_OPENSHIFT_MIN_MEMORY" \
    --label io.openshift.min-cpu="$CONTAINER_OPENSHIFT_MIN_CPU" \
    --label DominoContainer.maintainer="$CONTAINER_MAINTAINER" \
    --label DominoContainer.description="$CONTAINER_DOMINO_DESCRIPTION" \
    --label DominoContainer.version="$DOCKER_IMAGE_VERSION" \
    --label DominoContainer.buildtime="$BUILDTIME" \
    --label DominoContainer.addons="$CONTAINER_DOMINO_ADDONS" \
    --label DominoContainer.custom-addons="$CONTAINER_DOMINO_CUSTOM_ADDONS" \
    --label DominoContainer.baseimage="$BASE_IMAGE" \
    --build-arg PROD_NAME=$PROD_NAME \
    --build-arg PROD_VER=$PROD_VER \
    --build-arg DOMLP_VER=$DOMLP_VER \
    --build-arg DOMRESTAPI_VER=$DOMRESTAPI_VER \
    --build-arg PROD_FP=$PROD_FP \
    --build-arg PROD_HF=$PROD_HF \
    --build-arg PROD_DOWNLOAD_FILE=$PROD_DOWNLOAD_FILE \
    --build-arg PROD_FP_DOWNLOAD_FILE=$PROD_FP_DOWNLOAD_FILE \
    --build-arg PROD_HF_DOWNLOAD_FILE=$PROD_HF_DOWNLOAD_FILE \
    --build-arg TRAVELER_DOWNLOAD_FILE=$TRAVELER_DOWNLOAD_FILE\
    --build-arg RESTAPI_DOWNLOAD_FILE=$RESTAPI_DOWNLOAD_FILE\
    --build-arg DOCKER_TZ=$DOCKER_TZ \
    --build-arg BASE_IMAGE=$BASE_IMAGE \
    --build-arg DownloadFrom=$DOWNLOAD_FROM \
    --build-arg SOFTWARE_REPO_IP=$SOFTWARE_REPO_IP \
    --build-arg LinuxYumUpdate=$LinuxYumUpdate \
    --build-arg OPENSSL_INSTALL="$OPENSSL_INSTALL" \
    --build-arg SSH_INSTALL="$iSSH_INSTALL" \
    --build-arg BORG_VERSION="$BORG_VERSION" \
    --build-arg DOMBORG_VERSION="$DOMBORG_VERSION" \
    --build-arg TIKA_VERSION="$TIKA_VERSION" \
    --build-arg IQSUITE_VERSION="$IQSUITE_VERSION" \
    --build-arg NODE_EXPORTER_VERSION="$NODE_EXPORTER_VERSION" \
    --build-arg DOMPROM_VERSION="$DOMPROM_VERSION" \
    --build-arg VERSE_VERSION="$VERSE_VERSION" \
    --build-arg NOMAD_VERSION="$NOMAD_VERSION" \
    --build-arg TRAVELER_VERSION="$TRAVELER_VERSION" \
    --build-arg LEAP_VERSION="$LEAP_VERSION" \
    --build-arg CAPI_VERSION="$CAPI_VERSION" \
    --build-arg DOMIQ_VERSION="$DOMIQ_VERSION" \
    --build-arg NSHMAILX_VERSION="$NSHMAILX_VERSION" \
    --build-arg MYSQL_INSTALL="$MYSQL_INSTALL" \
    --build-arg MYSQL_JDBC_VERSION="$MYSQL_JDBC_VERSION" \
    --build-arg POSTGRESQL_JDBC_VERSION="$POSTGRESQL_JDBC_VERSION" \
    --build-arg LINUX_PKG_ADD="$LINUX_PKG_ADD" \
    --build-arg LINUX_PKG_REMOVE="$LINUX_PKG_REMOVE" \
    --build-arg LINUX_PKG_SKIP="$LINUX_PKG_SKIP" \
    --build-arg LINUX_HOMEDIR="$LINUX_HOMEDIR" \
    --build-arg MSSQL_INSTALL="$MSSQL_INSTALL" \
    --build-arg STARTSCRIPT_VER="$STARTSCRIPT_VER" \
    --build-arg CUSTOM_ADD_ONS="$CUSTOM_ADD_ONS" \
    --build-arg DOMINO_LANG="$DOMINO_LANG" \
    --build-arg LINUX_LANG="$LINUX_LANG" \
    --build-arg K8S_RUNAS_USER_SUPPORT="$K8S_RUNAS_USER_SUPPORT" \
    --build-arg EXPOSED_PORTS="$EXPOSED_PORTS" \
    --build-arg SPECIAL_CURL_ARGS="$SPECIAL_CURL_ARGS" \
    --build-arg DominoResponseFile="$DominoResponseFile" \
    --build-arg BUILD_SCRIPT_OPTIONS="$BUILD_SCRIPT_OPTIONS" .
}

build_traveler()
{
  $CONTAINER_CMD build --no-cache $BUILD_OPTIONS $BUILD_OPTION_NET $DOCKER_PULL_OPTION \
    $CONTAINER_NETWORK_CMD \
    -t $DOCKER_IMAGE \
    -f $DOCKER_FILE \
    --label maintainer="$CONTAINER_MAINTAINER" \
    --label name="$CONTAINER_TRAVELER_NAME" \
    --label vendor="$CONTAINER_VENDOR" \
    --label description="$CONTAINER_TRAVELER_DESCRIPTION" \
    --label summary="$CONTAINER_TRAVELER_NAME" \
    --label version="$DOCKER_IMAGE_VERSION" \
    --label buildtime="$BUILDTIME" \
    --label release="$BUILDTIME" \
    --label architecture="x86_64" \
    --label io.k8s.description="$CONTAINER_TRAVELER_DESCRIPTION" \
    --label io.k8s.display-name="$CONTAINER_TRAVELER_NAME" \
    --label io.openshift.tags="traveler" \
    --label io.openshift.expose-services="$CONTAINER_OPENSHIFT_EXPOSED_SERVICES" \
    --label io.openshift.non-scalable=true \
    --label io.openshift.min-memory="$CONTAINER_OPENSHIFT_MIN_MEMORY" \
    --label io.openshift.min-cpu="$CONTAINER_OPENSHIFT_MIN_CPU" \
    --label TravelerContainer.description="$CONTAINER_TRAVELER_DESCRIPTION" \
    --label TravelerContainer.version="$DOCKER_IMAGE_VERSION" \
    --label TravelerContainer.buildtime="$BUILDTIME" \
    --build-arg PROD_NAME="$PROD_NAME" \
    --build-arg PROD_VER="$PROD_VER" \
    --build-arg PROD_DOWNLOAD_FILE=$PROD_DOWNLOAD_FILE \
    --build-arg DownloadFrom="$DOWNLOAD_FROM" \
    --build-arg SOFTWARE_REPO_IP=$SOFTWARE_REPO_IP \
    --build-arg LinuxYumUpdate="$LinuxYumUpdate" \
    --build-arg BASE_IMAGE=$BASE_IMAGE \
    --build-arg SPECIAL_CURL_ARGS="$SPECIAL_CURL_ARGS" .
}

build_volt()
{
  $CONTAINER_CMD build --no-cache $BUILD_OPTIONS $BUILD_OPTION_NET $DOCKER_PULL_OPTION \
    $CONTAINER_NETWORK_CMD \
    -t $DOCKER_IMAGE \
    -f $DOCKER_FILE \
    --label maintainer="$CONTAINER_MAINTAINER" \
    --label name="$CONTAINER_VOLT_NAME" \
    --label vendor="$CONTAINER_VENDOR" \
    --label description="$CONTAINER_VOLT_DESCRIPTION" \
    --label summary="$CONTAINER_VOLT_DESCRIPTION" \
    --label version="$DOCKER_IMAGE_VERSION" \
    --label buildtime="$BUILDTIME" \
    --label release="$BUILDTIME" \
    --label architecture="x86_64" \
    --label io.k8s.description="$CONTAINER_VOLT_DESCRIPTION" \
    --label io.k8s.display-name="$CONTAINER_VOLT_NAME" \
    --label io.openshift.tags="volt" \
    --label io.openshift.expose-services="$CONTAINER_OPENSHIFT_EXPOSED_SERVICES" \
    --label io.openshift.non-scalable=true \
    --label io.openshift.min-memory="$CONTAINER_OPENSHIFT_MIN_MEMORY" \
    --label io.openshift.min-cpu="$CONTAINER_OPENSHIFT_MIN_CPU" \
    --label VoltContainer.description="$CONTAINER_VOLT_DESCRIPTION" \
    --label VoltContainer.version="$DOCKER_IMAGE_VERSION" \
    --label VoltContainer.buildtime="$BUILDTIME" \
    --build-arg PROD_NAME="$PROD_NAME" \
    --build-arg PROD_VER="$PROD_VER" \
    --build-arg PROD_DOWNLOAD_FILE=$PROD_DOWNLOAD_FILE \
    --build-arg DownloadFrom="$DOWNLOAD_FROM" \
    --build-arg SOFTWARE_REPO_IP=$SOFTWARE_REPO_IP \
    --build-arg LinuxYumUpdate="$LinuxYumUpdate" \
    --build-arg BASE_IMAGE=$BASE_IMAGE \
    --build-arg SPECIAL_CURL_ARGS="$SPECIAL_CURL_ARGS" .
}

build_leap()
{
  $CONTAINER_CMD build --no-cache $BUILD_OPTIONS $BUILD_OPTION_NET $DOCKER_PULL_OPTION \
    $CONTAINER_NETWORK_CMD \
    -t $DOCKER_IMAGE \
    -f $DOCKER_FILE \
    --label maintainer="$CONTAINER_MAINTAINER" \
    --label name="$CONTAINER_LEAP_NAME" \
    --label vendor="$CONTAINER_VENDOR" \
    --label description="$CONTAINER_LEAP_DESCRIPTION" \
    --label summary="$CONTAINER_LEAP_DESCRIPTION" \
    --label version="$DOCKER_IMAGE_VERSION" \
    --label buildtime="$BUILDTIME" \
    --label release="$BUILDTIME" \
    --label architecture="x86_64" \
    --label io.k8s.description="$CONTAINER_LEAP_DESCRIPTION" \
    --label io.k8s.display-name="$CONTAINER_LEAP_NAME" \
    --label io.openshift.tags="leap" \
    --label io.openshift.expose-services="$CONTAINER_OPENSHIFT_EXPOSED_SERVICES" \
    --label io.openshift.non-scalable=true \
    --label io.openshift.min-memory="$CONTAINER_OPENSHIFT_MIN_MEMORY" \
    --label io.openshift.min-cpu="$CONTAINER_OPENSHIFT_MIN_CPU" \
    --label LeapContainer.description="$CONTAINER_LEAP_DESCRIPTION" \
    --label LeapContainer.version="$DOCKER_IMAGE_VERSION" \
    --label LeapContainer.buildtime="$BUILDTIME" \
    --build-arg PROD_NAME="$PROD_NAME" \
    --build-arg PROD_VER="$PROD_VER" \
    --build-arg PROD_DOWNLOAD_FILE=$PROD_DOWNLOAD_FILE \
    --build-arg DownloadFrom="$DOWNLOAD_FROM" \
    --build-arg SOFTWARE_REPO_IP=$SOFTWARE_REPO_IP \
    --build-arg LinuxYumUpdate="$LinuxYumUpdate" \
    --build-arg BASE_IMAGE=$BASE_IMAGE \
    --build-arg SPECIAL_CURL_ARGS="$SPECIAL_CURL_ARGS" .
}

build_safelinx()
{
  $CONTAINER_CMD build --no-cache $BUILD_OPTIONS $BUILD_OPTION_NET $DOCKER_PULL_OPTION \
    $CONTAINER_NETWORK_CMD \
    -t $DOCKER_IMAGE \
    -f $DOCKER_FILE \
    --label maintainer="$CONTAINER_MAINTAINER" \
    --label name="$CONTAINER_SAFELINX_NAME" \
    --label vendor="$CONTAINER_VENDOR" \
    --label description="$CONTAINER_SAFELINX_DESCRIPTION" \
    --label summary="$CONTAINER_SAFELINX_DESCRIPTION" \
    --label version="$DOCKER_IMAGE_VERSION" \
    --label buildtime="$BUILDTIME" \
    --label release="$BUILDTIME" \
    --label architecture="x86_64" \
    --label io.k8s.description="$CONTAINER_SAFELINX_DESCRIPTION" \
    --label io.k8s.display-name="$CONTAINER_SAFELINX_NAME" \
    --label io.openshift.expose-services="80:http 443:https" \
    --label io.openshift.min-memory="2Gi" \
    --label io.openshift.min-cpu=2 \
    --label SafeLinxContainer.description="$CONTAINER_SAFELINX_DESCRIPTION" \
    --label SafeLinxContainer.version="$DOCKER_IMAGE_VERSION" \
    --label SafeLinxContainer.buildtime="$BUILDTIME" \
    --build-arg PROD_NAME="$PROD_NAME" \
    --build-arg PROD_VER="$PROD_VER" \
    --build-arg PROD_DOWNLOAD_FILE=$PROD_DOWNLOAD_FILE \
    --build-arg NOMADWEB_VERSION="$NOMADWEB_VERSION" \
    --build-arg MYSQL_INSTALL="$MYSQL_INSTALL" \
    --build-arg MSSQL_INSTALL="$MSSQL_INSTALL" \
    --build-arg DownloadFrom="$DOWNLOAD_FROM" \
    --build-arg SOFTWARE_REPO_IP=$SOFTWARE_REPO_IP \
    --build-arg LinuxYumUpdate="$LinuxYumUpdate" \
    --build-arg BASE_IMAGE=$BASE_IMAGE \
    --build-arg SPECIAL_CURL_ARGS="$SPECIAL_CURL_ARGS" .
}

docker_build()
{
  # Get product name from file name
  if [ -z $PROD_NAME ]; then
    log_error_exit "No product specified"
  fi

  if [ -z "$DOWNLOAD_FROM" ]; then
    log_error_exit "No download location specified!"
  fi

  #CUSTOM_VER=$(echo "$CUSTOM_VER" | awk '{print toupper($0)}')
  CUSTOM_FP=$(echo "$CUSTOM_FP" | awk '{print toupper($0)}')
  CUSTOM_HF=$(echo "$CUSTOM_HF" | awk '{print toupper($0)}')

  if [ -n "$CUSTOM_VER" ]; then
    PROD_VER=$CUSTOM_VER
    PROD_FP=$CUSTOM_FP
    PROD_HF=$CUSTOM_HF
  fi

  if [ -z "$DOCKER_IMAGE_NAME" ]; then
    if [ -n "$CONTAINER_IMAGE_NAME" ]; then
      DOCKER_IMAGE_NAME=$CONTAINER_IMAGE_NAME
    else
      DOCKER_IMAGE_NAME="hclcom/$PROD_NAME"
    fi
  fi

  DOCKER_IMAGE_VERSION=$PROD_VER$PROD_FP$PROD_HF$PROD_EXT

  if [ -z "$DOCKER_IMAGE_TAG" ]; then
    if [ -n "$CONTAINER_IMAGE_VERSION" ]; then
      DOCKER_IMAGE_TAG=$CONTAINER_IMAGE_VERSION
    else
      DOCKER_IMAGE_TAG=$PROD_VER$PROD_FP$PROD_HF$PROD_EXT
    fi
  fi

  # Set default or custom LATEST tag
  if [ -n "$TAG_LATEST" ]; then
    DOCKER_TAG_LATEST="$DOCKER_IMAGE_NAME:$TAG_LATEST"
  fi

  if [ "$CONTAINER_CMD" = "nerdctl" ]; then
    # Currently nerdctl cannot handle a second tag
    DOCKER_TAG_LATEST=
  fi

  # Get Build Time
  BUILDTIME=$(date +"%d.%m.%Y %H:%M:%S")

  # Get build arguments
  DOCKER_IMAGE=$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG
  DOCKER_IMAGE_BUILD_VERSION=$DOCKER_IMAGE_VERSION

  header "Building Image $DOCKER_IMAGE ..."

  export BUILDAH_FORMAT

  # Switch to directory containing the dockerfiles
  cd dockerfiles

  set_standard_image_labels

  case "$PROD_NAME" in

    domino)

      if [ -z "$DOCKER_FILE" ]; then
        DOCKER_FILE=dockerfile
      fi

      build_domino
      ;;

    traveler)

      DOCKER_FILE=dockerfile_traveler

      build_traveler
      ;;

    volt)

      DOCKER_FILE=dockerfile_volt
      build_volt
      ;;

    leap)

      DOCKER_FILE=dockerfile_leap
      build_leap
      ;;

    safelinx)

      DOCKER_FILE=dockerfile_safelinx

      build_safelinx
      ;;

    *)
      log_error_exit "Unknown product [$PROD_NAME] - Terminating installation"
      ;;
  esac

  if  [ ! "$?" = "0" ]; then
    log_error_exit "Image build failed!"
  fi

  cd $CURRENT_DIR

  # Test image via automation testing before tagging and uploading it
  auto_test

  # Scan image if requested
  ScanImage

  if [ -n "$DOCKER_TAG_LATEST" ]; then
    $CONTAINER_CMD tag $DOCKER_IMAGE $DOCKER_TAG_LATEST
    echo
  fi

  if [ -n "$TAG_IMAGE" ]; then
    $CONTAINER_CMD tag $DOCKER_IMAGE $TAG_IMAGE
    echo
  fi

  if [ -n "$PUSH_IMAGE" ]; then
    $CONTAINER_CMD tag $DOCKER_IMAGE $PUSH_IMAGE

    header "Pushing image $PUSH_IMAGE to registry"
    $CONTAINER_CMD push $PUSH_IMAGE
    echo
  fi

  # Save/Export image if requested
  docker_save

  echo
  return 0
}

check_all_domdownload()
{
  # Domino Download script integration to automatically download software if script is present
  local LP_LANG=
  local LP_VER=
  local DOWNLOAD_OPTIONS="-silent -download"

  if [ ! -e "$DOMDOWNLOAD_BIN" ]; then
    return 0
  fi

  $DOMDOWNLOAD_BIN -product=$PROD_NAME -platform=linux -ver=$PROD_VER $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"

  if [ "$PROD_NAME" = "domino" ]; then

    if [ -n "$PROD_FP" ]; then
      $DOMDOWNLOAD_BIN -product=domino -platform=linux -ver=$PROD_VER$PROD_FP $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
    fi

    if [ -n "$PROD_HF" ]; then
      $DOMDOWNLOAD_BIN -product=domino -platform=linux -ver=$PROD_VER$PROD_FP$PROD_HF $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
    fi

  fi

  if [ -n "$TRAVELER_VERSION" ] && [ -z "$TRAVELER_DOWNLOAD_FILE" ]; then
    $DOMDOWNLOAD_BIN -product=traveler -platform=linux -ver=$TRAVELER_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$DOMLP_LANG" ]; then
    $DOMDOWNLOAD_BIN -product=domino -platform=linux -type=langpack -lang=$DOMLP_LANG -ver=$PROD_VER $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$VERSE_VERSION" ]; then
    $DOMDOWNLOAD_BIN -product=verse -platform=linux -ver=$VERSE_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$DOMRESTAPI_VER" ] && [ -z "$RESTAPI_DOWNLOAD_FILE" ]; then
    $DOMDOWNLOAD_BIN -product=restapi -platform=linux -ver=$DOMRESTAPI_VER $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$NOMAD_VERSION" ]; then
    $DOMDOWNLOAD_BIN -product=nomad -platform=linux -ver=$NOMAD_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$LEAP_VERSION" ]; then
    $DOMDOWNLOAD_BIN -product=leap -platform=linux -ver=$LEAP_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$CAPI_VERSION" ]; then
    $DOMDOWNLOAD_BIN -product=capi -platform=linux -ver=$CAPI_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$DOMIQ_VERSION" ]; then
    $DOMDOWNLOAD_BIN -product=domiq -platform=linux -ver=$DOMIQ_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$IQSUITE_VERSION" ]; then
    $DOMDOWNLOAD_BIN -product=iqsuite -platform=linux -ver=$IQSUITE_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$MYSQL_JDBC_VERSION" ]; then
    $DOMDOWNLOAD_BIN -product=mysql-jdbc -platform=linux -ver=$MYSQL_JDBC_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$POSTGRESQL_JDBC_VERSION" ]; then
    $DOMDOWNLOAD_BIN -product=postgresql-jdbc -platform=linux -ver=$POSTGRESQL_JDBC_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi

  if [ -n "$NSHMAILX_VERSION" ]; then
    $DOMDOWNLOAD_BIN -product=nshmailx -platform=linux -ver=$NSHMAILX_VERSION $DOWNLOAD_OPTIONS "-dir=$SOFTWARE_DIR"
  fi
}


get_download_link()
{
  CURRENT_DOWNLOAD_URL="https://my.hcltechsw.com/downloads/domino/domino"
}


check_domdownload()
{
  # $1 download file name
  # $2 optional file id
  # $3 hash if fileID  is specified

  if [ ! -e "$DOMDOWNLOAD_BIN" ]; then
    return 0
  fi

  # if MHS fileID is specified don't search but directly download from MHS
  if [ -n "$2" ]; then
    $DOMDOWNLOAD_BIN "-filename=$1" "-fileid=$2" "-hash=$3" "-dir=$SOFTWARE_DIR"
    return 0
  fi

  $DOMDOWNLOAD_BIN "$1" "-dir=$SOFTWARE_DIR"
}

check_software()
{
  CURRENT_NAME=$(echo $1|cut -d'|' -f1)
  CURRENT_VER=$(echo $1|cut -d'|' -f2)
  CURRENT_FILES=$(echo $1|cut -d'|' -f3)
  CURRENT_FILE_ID=$(echo $1|cut -d'|' -f4)
  CURRENT_HASH=$(echo $1|cut -d'|' -f5)

  if [ "$CURRENT_FILE_ID" = "-" ]; then
    CURRENT_FILE_ID=
  fi

  if [ -z "$DOWNLOAD_FROM" ]; then

    FOUND=
    DOWNLOAD_1ST_FILE=

    for CHECK_FILE in $(echo "$CURRENT_FILES" | tr "," "\n"); do

      # Check for absolute download link
      case "$CHECK_FILE" in

        *://*)
          if [ -z "$DOWNLOAD_1ST_FILE" ]; then
            DOWNLOAD_1ST_FILE=$(basename $CHECK_FILE)
	  else
	    # Try to download file to cache it
	    $CURL_CMD -s "$CHECK_FILE" -o "$SOFTWARE_DIR/$DOWNLOAD_1ST_FILE"
            echo "Downloading file to cache it locally $CHECK_FILE ..."
	    HASH=$(sha256sum -b "$SOFTWARE_DIR/$DOWNLOAD_1ST_FILE" | cut -d" " -f1)

	    if [ "$CURRENT_HASH" = "$HASH" ]; then
              echo "Download successful -> $SOFTWARE_DIR/$DOWNLOAD_1ST_FILE"
	    else
              echo "Failed to download file to cache it locally form $CHECK_FILE"
	      remove_file "$SOFTWARE_DIR/$DOWNLOAD_1ST_FILE"
	    fi
          fi

          if [ -z "$FOUND" ]; then
            http_head_check "$CHECK_FILE"
            if [ "$?" = "1" ]; then
              CURRENT_FILE="$CHECK_FILE"
              FOUND=TRUE
              break
            fi
          fi
          ;;

        *)
          if [ -z "$DOWNLOAD_1ST_FILE" ]; then
            DOWNLOAD_1ST_FILE=$CHECK_FILE
          fi

          if [ -r "$SOFTWARE_DIR/$CHECK_FILE" ]; then
            CURRENT_FILE="$CHECK_FILE"
            FOUND=TRUE
            break
          else

            if [ "$CURRENT_FILE_ID" != "x" ]; then
              check_domdownload "$CHECK_FILE" "$CURRENT_FILE_ID" "$CURRENT_HASH"
              if [ -r "$SOFTWARE_DIR/$CHECK_FILE" ]; then
                CURRENT_FILE="$CHECK_FILE"
                FOUND=TRUE
                break
              fi
            fi
          fi
          ;;
      esac
    done

    if [ "$FOUND" = "TRUE" ]; then
      if [ -z "$CURRENT_HASH" ]; then
        CURRENT_STATUS="NA"
      else
        if [ ! "$CHECK_HASH" = "yes" ]; then
          CURRENT_STATUS="OK"
        else

          case "$CHECK_FILE" in

            *://*)
              HASH=$($CURL_CMD --silent $CHECK_FILE 2>/dev/null | sha256sum -b | cut -d" " -f1)
              ;;

            *)
              HASH=$(sha256sum $SOFTWARE_DIR/$CURRENT_FILE -b | cut -d" " -f1)
              ;;
          esac

          if [ "$CURRENT_HASH" = "$HASH" ]; then
            CURRENT_STATUS="OK"
          else
        echo "$CURRENT_HASH -  $HASH"
            CURRENT_STATUS="CR"
          fi
        fi
      fi
    else
      CURRENT_STATUS="NA"
    fi
  else

    FOUND=
    DOWNLOAD_1ST_FILE=

    for CHECK_FILE in $(echo "$CURRENT_FILES" | tr "," "\n") ; do

      # Check for absolute download link
      case "$CHECK_FILE" in
        *://*)
          DOWNLOAD_FILE=$CHECK_FILE

           if [ -z "$DOWNLOAD_1ST_FILE" ]; then
             DOWNLOAD_1ST_FILE=$(basename $CHECK_FILE)
           fi

          ;;

        *)
          DOWNLOAD_FILE=$DOWNLOAD_FROM/$CHECK_FILE

          if [ -z "$DOWNLOAD_1ST_FILE" ]; then
            DOWNLOAD_1ST_FILE=$CHECK_FILE
          fi
          ;;
      esac

      http_head_check "$DOWNLOAD_FILE"
      if [ "$?" = "1" ]; then
        CURRENT_FILE="$CHECK_FILE"
        FOUND=TRUE
        break
      fi
    done

    if [ ! "$FOUND" = "TRUE" ]; then
      CURRENT_STATUS="NA"
    else
      if [ -z "$CURRENT_HASH" ]; then
        CURRENT_STATUS="OK"
      else
        if [ ! "$CHECK_HASH" = "yes" ]; then
          CURRENT_STATUS="OK"
        else
          HASH=$($CURL_CMD --silent $DOWNLOAD_FILE 2>/dev/null | sha256sum -b | cut -d" " -f1)

          if [ "$CURRENT_HASH" = "$HASH" ]; then
            CURRENT_STATUS="OK"
          else
            CURRENT_STATUS="CR"
          fi
        fi
      fi
    fi
  fi

  CURRENT_DOWNLOAD_URL=""

  case "$CURRENT_NAME" in

    domino|traveler|volt|leap|verse|nomad|capi|borg|safelinx|nomadweb)

      if [ -n "$DOWNLOAD_1ST_FILE" ]; then
        get_download_link "$CURRENT_NAME" "$DOWNLOAD_1ST_FILE"
      fi
      ;;

    startscript)

      STARTSCRIPT_FILE=domino-startscript_v${CURRENT_VER}.taz
      CURRENT_DOWNLOAD_URL=${STARTSCRIPT_GIT_URL}/releases/download/v${CURRENT_VER}/domino-startscript_v${CURRENT_VER}.taz
     ;;

    *)
      CURRENT_DOWNLOAD_URL=""
      ;;
  esac

  count=$(echo $CURRENT_VER | wc -c)
  while [[ $count -lt 20 ]] ;
  do
    CURRENT_VER="$CURRENT_VER "
    count=$((count+1));
  done;

  echo "$CURRENT_VER [$CURRENT_STATUS] $DOWNLOAD_1ST_FILE"

  if [ ! "$CURRENT_STATUS" = "OK" ]; then
    DOWNLOAD_ERROR_COUNT=$((DOWNLOAD_ERROR_COUNT+1))
  fi

  return 0
}

check_software_file()
{
  FOUND=""

  if [ -z "$PROD_NAME" ]; then
    echo
    echo "--- $1 ---"
    echo
  fi

  if [ -z "$2" ]; then
    SEARCH_STR="^$1|"
  else
    SEARCH_STR="^$1|$2|"
  fi

  # Read software buffer once. Either from local or remote download software.txt

  if [ -z "$DOWNLOAD_SOFTWARE_BUFFER" ]; then

    if [ -z "$DOWNLOAD_SOFTWARE_FILE" ]; then
      DOWNLOAD_SOFTWARE_BUFFER=$(cat $SOFTWARE_FILE)
    else
      DOWNLOAD_SOFTWARE_BUFFER=$($CURL_CMD --silent $DOWNLOAD_SOFTWARE_FILE)
    fi

  fi

  # Check if line is found for search string in buffer

  LINE=$(echo -e "$DOWNLOAD_SOFTWARE_BUFFER" | grep "$SEARCH_STR")

  if [ -n "$LINE" ]; then
    check_software $(echo $LINE |grep "$SEARCH_STR")
    FOUND="TRUE"
  fi

  if [ -z "$PROD_NAME" ]; then
    echo
  else
    if [ ! "$FOUND" = "TRUE" ]; then

      CURRENT_VER=$2
      count=$(echo $CURRENT_VER | wc -c)
      while [[ $count -lt 20 ]] ;
      do
        CURRENT_VER="$CURRENT_VER "
        count=$((count+1));
      done;

      echo "$CURRENT_VER [NA] $1 - Not found in software file!"
      DOWNLOAD_ERROR_COUNT=$((DOWNLOAD_ERROR_COUNT+1))
      SOFTWARE_FILE_ERROR_COUNT=$((SOFTWARE_FILE_ERROR_COUNT+1))
    fi
  fi
}

check_software_status()
{
  if [ ! -z "$DOWNLOAD_FROM" ]; then

    DOWNLOAD_FILE=$DOWNLOAD_FROM/$SOFTWARE_FILE_NAME

    http_head_check "$DOWNLOAD_FILE"
    if [ "$?" = "1" ]; then
      DOWNLOAD_SOFTWARE_FILE=$DOWNLOAD_FILE
      echo "Checking software via [$DOWNLOAD_SOFTWARE_FILE]"
    fi

  else

    if [ ! -r "$SOFTWARE_FILE" ]; then
      echo "Software [$SOFTWARE_FILE] Not found!"
      DOWNLOAD_ERROR_COUNT=99
      return 1
    else
      echo "Checking software via [$SOFTWARE_FILE]"
    fi
  fi

  if [ -z "$PROD_NAME" ]; then
    check_software_file "domino"
    check_software_file "traveler"
    check_software_file "volt"
    check_software_file "leap"
    check_software_file "safelinx"

    if [ -n "$VERSE_VERSION" ]; then
      check_software_file "verse" "$VERSE_VERSION"
    fi

    if [ -n "$DOMLP_VER" ]; then
      check_software_file "domlp" "$DOMLP_VER"
    fi

    if [ -n "$DOMRESTAPI_VER" ] && [ -z "$RESTAPI_DOWNLOAD_FILE" ] ; then
      check_software_file "domrestapi" "$DOMRESTAPI_VER"
    fi

    if [ -n "$NOMAD_VERSION" ]; then
      check_software_file "nomad" "$NOMAD_VERSION"
    fi

    if [ -n "$TRAVELER_VERSION" ] && [ -z "$TRAVELER_DOWNLOAD_FILE" ] ; then
      check_software_file "traveler" "$TRAVELER_VERSION"
    fi

    if [ -n "$LEAP_VERSION" ]; then
      check_software_file "leap" "$LEAP_VERSION"
    fi

    if [ -n "$NOMADWEB_VERSION" ]; then
      check_software_file "nomadweb" "$NOMADWEB_VERSION"
    fi

    if [ -n "$CAPI_VERSION" ]; then
      check_software_file "capi" "$CAPI_VERSION"
    fi

    if [ -n "$DOMIQ_VERSION" ]; then
      check_software_file "domiq" "$DOMIQ_VERSION"
    fi

    if [ -n "$STARTSCRIPT_VER" ]; then
      check_software_file "startscript" "$STARTSCRIPT_VER"
    fi

    if [ -n "$BORG_VERSION" ]; then
      if [ ! "$BORG_VERSION" = "yes" ]; then
        check_software_file "borg" "$BORG_VERSION"
      fi
    fi

    if [ -n "$DOMBORG_VERSION" ]; then
      if [ ! "$DOMBORG_VERSION" = "yes" ]; then
        check_software_file "domborg" "$DOMBORG_VERSION"
      fi
    fi

    if [ -n "$TIKA_VERSION" ]; then
      if [ ! "$TIKA_VERSION" = "yes" ]; then
        check_software_file "tika" "$TIKA_VERSION"
      fi
    fi

    if [ -n "$IQSUITE_VERSION" ]; then
      check_software_file "iqsuite" "$IQSUITE_VERSION"
    fi

    if [ -n "$NSHMAILX_VERSION" ]; then
      check_software_file "nshmailx" "$NSHMAILX_VERSION"
    fi

    if [ -n "$NODE_EXPORTER_VERSION" ]; then
      if [ ! "$NODE_EXPORTER_VERSION" = "yes" ]; then
        check_software_file "node_exporter" "$NODE_EXPORTER_VERSION"
      fi
    fi

    if [ -n "$DOMPROM_VERSION" ]; then
      if [ ! "$DOMPROM_VERSION" = "yes" ]; then
        check_software_file "domprom" "$DOMPROM_VERSION"
      fi
    fi

    if [ -n "$MYSQL_JDBC_VERSION" ]; then
      if [ ! "$MYSQL_JDBC_VERSION" = "yes" ]; then
        check_software_file "mysql-jdbc" "$MYSQL_JDBC_VERSION"
      fi
    fi

    if [ -n "$POSTGRESQL_JDBC_VERSION" ]; then
      if [ ! "$POSTGRESQL_JDBC_VERSION" = "yes" ]; then
        check_software_file "postgresql-jdbc" "$POSTGRESQL_JDBC_VERSION"
      fi
    fi

  else
    echo

    if [ -z "$PROD_VER" ]; then
      check_software_file "$PROD_NAME"
    else

      if [ -z "$PROD_DOWNLOAD_FILE" ]; then
        check_software_file "$PROD_NAME" "$PROD_VER"
      else

        if [ -z "$DOWNLOAD_FROM" ]; then

          if [ -e "$SOFTWARE_DIR/$PROD_DOWNLOAD_FILE" ]; then
            echo "Info: Not checking download file [$SOFTWARE_DIR/$PROD_DOWNLOAD_FILE]"
          else
            echo "Download file not found [$SOFTWARE_DIR/$PROD_DOWNLOAD_FILE]"
            exit 1
          fi

        else

          http_head_check "$DOWNLOAD_FROM/$PROD_DOWNLOAD_FILE"
          if [ "$?" = "1" ]; then
            echo "Info: Not checking download file [$DOWNLOAD_FROM/$PROD_DOWNLOAD_FILE]"
          else
            echo "Download file not found [$DOWNLOAD_FROM/$PROD_DOWNLOAD_FILE]"
            exit 1
          fi
        fi

      fi

      if [ -n "$PROD_FP" ]; then
        if [ -z "$PROD_FP_DOWNLOAD_FILE" ]; then
          check_software_file "$PROD_NAME" "$PROD_VER$PROD_FP"

        else

          if [ -z "$DOWNLOAD_FROM" ]; then

            if [ -e "$SOFTWARE_DIR/$PROD_FP_DOWNLOAD_FILE" ]; then
              echo "Info: Not checking download file [$SOFTWARE_DIR/$PROD_FP_DOWNLOAD_FILE]"
            else
              echo "Download file not found [$SOFTWARE_DIR/$PROD_FP_DOWNLOAD_FILE]"
              exit 1
            fi

          else

            http_head_check "$DOWNLOAD_FROM/$PROD_FP_DOWNLOAD_FILE"
            if [ "$?" = "1" ]; then
              echo "Info: Not checking download file [$DOWNLOAD_FROM/$PROD_FP_DOWNLOAD_FILE]"
            else
              echo "Download file not found [$DOWNLOAD_FROM/$PROD_FP_DOWNLOAD_FILE]"
              exit 1
            fi
          fi

        fi
      fi

      if [ -n "$PROD_HF" ]; then

        if [ -z "$PROD_HF_DOWNLOAD_FILE" ]; then
          check_software_file "$PROD_NAME" "$PROD_VER$PROD_FP$PROD_HF"

        else

          if [ -z "$DOWNLOAD_FROM" ]; then

            if [ -e "$SOFTWARE_DIR/$PROD_HF_DOWNLOAD_FILE" ]; then
              echo "Info: Not checking download file [$SOFTWARE_DIR/$PROD_HF_DOWNLOAD_FILE]"
            else
              echo "Download file not found [$SOFTWARE_DIR/$PROD_HF_DOWNLOAD_FILE]"
              exit 1
            fi

          else

            http_head_check "$DOWNLOAD_FROM/$PROD_HF_DOWNLOAD_FILE"
            if [ "$?" = "1" ]; then
              echo "Info: Not checking download file [$DOWNLOAD_FROM/$PROD_HF_DOWNLOAD_FILE]"
            else
              echo "Download file not found [$DOWNLOAD_FROM/$PROD_HF_DOWNLOAD_FILE]"
              exit 1
            fi
          fi

        fi
      fi
    fi

    if [ -n "$VERSE_VERSION" ]; then
      check_software_file "verse" "$VERSE_VERSION"
    fi

    if [ -n "$DOMLP_VER" ]; then
      check_software_file "domlp" "$DOMLP_VER"
    fi

    if [ -n "$DOMRESTAPI_VER" ] && [ -z "$RESTAPI_DOWNLOAD_FILE" ]; then
      check_software_file "domrestapi" "$DOMRESTAPI_VER"
    fi

    if [ -n "$NOMAD_VERSION" ]; then
      check_software_file "nomad" "$NOMAD_VERSION"
    fi

    if [ -n "$TRAVELER_VERSION" ] && [ -z "$TRAVELER_DOWNLOAD_FILE" ]; then
      check_software_file "traveler" "$TRAVELER_VERSION"
    fi

    if [ -n "$LEAP_VERSION" ]; then
      check_software_file "leap" "$LEAP_VERSION"
    fi

    if [ -n "$NOMADWEB_VERSION" ]; then
      check_software_file "nomadweb" "$NOMADWEB_VERSION"
    fi

    if [ -n "$CAPI_VERSION" ]; then
      check_software_file "capi" "$CAPI_VERSION"
    fi

    if [ -n "$DOMIQ_VERSION" ]; then
      check_software_file "domiq" "$DOMIQ_VERSION"
    fi

    if [ -n "$STARTSCRIPT_VER" ]; then
      check_software_file "startscript" "$STARTSCRIPT_VER"
    fi

    if [ -n "$BORG_VERSION" ]; then
      if [ ! "$BORG_VERSION" = "yes" ]; then
        check_software_file "borg" "$BORG_VERSION"
      fi
    fi

    if [ -n "$DOMBORG_VERSION" ]; then
      if [ ! "$DOMBORG_VERSION" = "yes" ]; then
        check_software_file "domborg" "$DOMBORG_VERSION"
      fi
    fi

    if [ -n "$TIKA_VERSION" ]; then
      if [ ! "$TIKA_VERSION" = "yes" ]; then
        check_software_file "tika" "$TIKA_VERSION"
      fi
    fi

    if [ -n "$IQSUITE_VERSION" ]; then
      check_software_file "iqsuite" "$IQSUITE_VERSION"
    fi

    if [ -n "$NSHMAILX_VERSION" ]; then
      check_software_file "nshmailx" "$NSHMAILX_VERSION"
    fi

    if [ -n "$NODE_EXPORTER_VERSION" ]; then
      if [ ! "$NODE_EXPORTER_VERSION" = "yes" ]; then
        check_software_file "node_exporter" "$NODE_EXPORTER_VERSION"
      fi
    fi

    if [ -n "$DOMPROM_VERSION" ]; then
      if [ ! "$DOMPROM_VERSION" = "yes" ]; then
        check_software_file "domprom" "$DOMPROM_VERSION"
      fi
    fi

    if [ -n "$MYSQL_JDBC_VERSION" ]; then
      if [ ! "$MYSQL_JDBC_VERSION" = "yes" ]; then
        check_software_file "mysql-jdbc" "$MYSQL_JDBC_VERSION"
      fi
    fi

    if [ -n "$POSTGRESQL_JDBC_VERSION" ]; then
      if [ ! "$POSTGRESQL_JDBC_VERSION" = "yes" ]; then
        check_software_file "postgresql-jdbc" "$POSTGRESQL_JDBC_VERSION"
      fi
    fi

    echo
  fi
}

check_all_software()
{
  SOFTWARE_FILE=$SOFTWARE_DIR/software.txt

  # if software file isn't found check standard location (check might lead to the same directory if standard location already)
  if [ ! -e "$SOFTWARE_FILE" ]; then
    SOFTWARE_FILE=$SCRIPT_DIR/software/$SOFTWARE_FILE_NAME
  fi

  STARTSCRIPT_GIT_URL=https://github.com/nashcom/domino-startscript

  DOWNLOAD_ERROR_COUNT=0
  SOFTWARE_FILE_ERROR_COUNT=0

  check_software_status

  if [ ! "$SOFTWARE_FILE_ERROR_COUNT" = "0" ]; then
    echo "Correct Software file Error(s) before building image [$SOFTWARE_FILE_ERROR_COUNT]"
    echo "Hint: You might have an older custom software.txt file in your software location, which needs to be updated"
    echo
  fi

  if [ ! "$DOWNLOAD_ERROR_COUNT" = "0" ]; then
    echo "Correct Software Download Error(s) before building image [$DOWNLOAD_ERROR_COUNT]"

    if [ -z "$DOWNLOAD_FROM" ]; then
      if [ -z $SOFTWARE_DIR ]; then
        echo "No download location or software directory specified!"
        DOWNLOAD_ERROR_COUNT=99
      else
        echo "Copy files to [$SOFTWARE_DIR]"
      fi
    else
      echo "Upload files to [$DOWNLOAD_FROM]"
    fi

    echo
  fi

  CHECK_SOFTWARE_STATUS=$DOWNLOAD_ERROR_COUNT
}


log_custom_software_ok()
{
  echo "[OK] $@"
}

log_custom_software_error()
{
  echo "$@"
}


check_one_custom_software_file()
{
  local DOWNLOAD_STR=$1
  local CHECK_FILE=
  local DOWNLOAD_FILE=

  CHECK_FILE=$(echo "$DOWNLOAD_STR" | cut -f1 -d"#" | xargs)
  EXPECTED_HASH=$(echo "$DOWNLOAD_STR" | cut -f2 -d"#" | xargs)

  # Check for absolute download link
  case "$CHECK_FILE" in
    *://*)
      DOWNLOAD_FILE=$CHECK_FILE
      ;;

    *)
      if [ -n "$DOWNLOAD_FROM" ]; then
        DOWNLOAD_FILE=$DOWNLOAD_FROM/$CHECK_FILE
      fi
      ;;
  esac

  if [ -z "$DOWNLOAD_FILE" ]; then

    DOWNLOAD_FILE=$SOFTWARE_DIR/$CHECK_FILE

    if [ ! -e "$DOWNLOAD_FILE" ]; then
       log_custom_software_error "[NA] $CHECK_FILE"
       return 1
    fi

    if [ "$CHECK_HASH" = "yes" ]; then
      HASH=$(sha256sum -b "$DOWNLOAD_FILE"| cut -d" " -f1)
    else
      log_custom_software_ok "$CHECK_FILE"
      return 0
    fi

  else

    http_head_check "$DOWNLOAD_FILE"

    if [ "$?" = "0" ]; then
      log_custom_software_error "[NA] $CHECK_FILE"
      return 1
    fi

    if [ "$CHECK_HASH" = "yes" ]; then
      HASH=$($CURL_CMD -s $DOWNLOAD_FILE | sha256sum -b | cut -d" " -f1)
    else
      log_custom_software_ok "$CHECK_FILE"
      return 0
    fi
  fi

  if [ -z "$CHECK_HASH" ]; then
    log_space "Warning: No hash specified for download: [$DOWNLOAD_FILE]"
  fi

  if [ "$HASH" = "$EXPECTED_HASH" ]; then
    log_custom_software_ok "$CHECK_FILE"
    return 0
  fi

   log_custom_software_error "[CR] $CHECK_FILE"
   return 1
}


check_custom_software()
{
  local entry=
  local lines=
  local failed=0

  if [ -z "$1" ]; then
    return 0
  fi

  header "Checking custom software"

  lines=$(echo "$1" | tr ',' '\n')

  while read entry; do
    check_one_custom_software_file "$entry"
    if [ "$?" != "0" ]; then
      failed=$(expr $failed + 1)
    fi
  done <<< "$lines"

  if [ "$failed" != "0" ]; then
      log_error_exit "Custom software check failed - Please correct $failed error(s) and retry"
  fi

  echo
}


docker_save()
{
  if [ -z "$DOCKER_IMAGE_EXPORT_NAME" ]; then
    return 0
  fi

  header "Exporting $DOCKER_IMAGE -> $DOCKER_IMAGE_EXPORT_NAME"

  $CONTAINER_CMD save $DOCKER_IMAGE | gzip > $DOCKER_IMAGE_EXPORT_NAME

  if [ "$?" = "0" ]; then
    IMAGE_SIZE=$(du -h $DOCKER_IMAGE_EXPORT_NAME)
    log "Exported container image: $IMAGE_SIZE"
  else
    log "Error exporting container image!"
  fi

  return 0
}

test_image()
{
  export CONTAINER_CMD
  export USE_DOCKER

  local IMAGE_NAME=$1
  if [ -z "$IMAGE_NAME" ]; then
     IMAGE_NAME="$DOCKER_IMAGE"
  fi

  if [ -z "$IMAGE_NAME" ]; then
     IMAGE_NAME="hclcom/domino:latest"
  fi

  header "Running Automation test for $IMAGE_NAME ..."

  local CURRENT_DIR=$(pwd)
  cd "$SCRIPT_DIR/testing"

  ./AutomationTest.sh -image="$IMAGE_NAME"

  local ret=$?
  cd "$CURRENT_DIR"

  if [ "$ret" != "0" ]; then
    log_error_exit "Automation testing for image [$IMAGE_NAME failed] with $ret automation test errors!"
  fi

  log "Automation testing for new image [$IMAGE_NAME] successful!"
}

auto_test()
{
  if [ "$AutoTestImage" != "yes" ]; then
    return 0
  fi

  test_image "$DOCKER_IMAGE"
}


trivy_scan_image()
{
  header "Running Trivy Scan on $DOCKER_IMAGE ..."

  if [ -x /usr/bin/trivy ]; then
    TRIVY_BIN=/usr/bin/trivy
  elif [ -x /usr/local/bin/trivy ]; then
    TRIVY_BIN=/usr/local/bin/trivy
  fi

  if [ -z "$TRIVY_BIN" ]; then
    log "Trivy is not installed! Skipping scan"
    return 0
  fi

  if [ -z "$DOCKER_IMAGE_BUILD_VERSION" ]; then
    log "No image specified - Cannot scan image"
    return 0
  fi

  # If no output file is specified, just run the scan with standard output
  if [ -z  "$1" ]; then
    $TRIVY_BIN image "$DOCKER_IMAGE" --scanners vuln
    echo
    return 0
  fi

  case "$1" in

    *.json)

      $TRIVY_BIN image -o "$1" -f json "$DOCKER_IMAGE"

      if [ ! -x /usr/bin/jq ]; then
        log "Scan completed: $1"
        log "JQ not availble - Cannot display summary"
        return 0
      fi

      header "Trivy Scan Summary"

      cat "$1" | jq -r '.Results[0].Target'
      echo "--------------------"
      cat "$1" | jq -r '.Results[0].Vulnerabilities[].Severity' 2> /dev/null | sort | uniq -c
      echo

      cat "$1" | jq -r '.Results[1].Target'
      echo "--------------------"
      cat "$1" | jq -r '.Results[1].Vulnerabilities[].Severity' 2> /dev/null | sort | uniq -c
      echo
      ;;

    *)
      $TRIVY_BIN image "$DOCKER_IMAGE" -o "$1"
      header "Trivy Scan Result"
      log "See details in output file: [$1]. No stable result format available currently."
      ;;

  esac

  echo

}

ScanImage()
{
  # Only scan if requested
  if [ "$ScanImage" != "yes" ] && [ -z "$IMAGE_SCAN_RESULT_FILE" ]; then
    return 0
  fi

  trivy_scan_image "$IMAGE_SCAN_RESULT_FILE"
}

parse_domino_version()
{
  local VER_UPPER=
  PROD_VER=
  PROD_FP=
  PROD_IF=
  PROD_HF=

  VER_UPPER=$(echo "$1" | awk '{print toupper($0)}')
  PROD_VER=$(echo "$VER_UPPER" | awk -F'[A-Z ]' '{print $1}')

  local FP=$(echo "$VER_UPPER" | awk -F'FP' '{print $2}' | awk -F'[A-Z ]' '{print $1}')
  local IF=$(echo "$VER_UPPER" | awk -F'IF' '{print $2}' | awk -F'[A-Z ]' '{print $1}')
  local HF=$(echo "$VER_UPPER" | awk -F'HF' '{print $2}' | awk -F'[A-Z ]' '{print $1}')
  local EA=$(echo "$VER_UPPER" | awk -F'EA' '{print $2}' | awk -F'[A-Z ]' '{print $1}')

  if [ -n "$EA" ]; then
    PROD_VER="$1"
    PROD_FP=
    PROD_IF=

  elif [ -n "$FP" ]; then

    FULL_PROD_FP=${PROD_VER}FP${FP}
    PROD_FP=FP${FP}

    if [ -n "$IF" ]; then
      FULL_PROD_HF=${PROD_FP}IF${IF}
      PROD_HF=IF${IF}
    fi

    if [ -n "$HF" ]; then
      FULL_PROD_HF=${PROD_FP}HF${HF}
      PROD_HF=$HF${HF}
    fi

  else

    PROD_FP=
    if [ -n "$IF" ]; then
      FULL_PROD_HF=${PROD_VER}IF${IF}
      PROD_HF=IF${IF}
    fi

    if [ -n "$HF" ]; then
      FULL_PROD_HF=${PROD_FP}HF${HF}
      PROD_HF=HF${HF}
    fi

  fi
}

print_lp()
{
  printf " (%s)  %-10s\n" "$1" "$2"
}

print_ver()
{
  printf "(%s)  %-10s\n" "$1" "$2"
}

print_select()
{
  if [ -n "$3" ]; then
    printf " (%s)  %-19s [%s]  %s\n" "$1" "$2" "$3" "$4"
  else
    printf " (%s)  %-19s\n" "$1" "$2"
  fi
}


get_language_pack_display_name()
{
  local LP_DE="German"
  local LP_ES="Spanish"
  local LP_FR="French"
  local LP_IT="Italian"
  local LP_NL="Dutch"
  local LP_JA="Japanese"

  case "$SELECT_DOMLP_LANG" in

    DE)
      DISPLAY_DOMLP="$LP_DE"
      ;;

    ES)
      DISPLAY_DOMLP="$LP_ES"
      ;;

    FR)
      DISPLAY_DOMLP="$LP_FR"
      ;;

    IT)
      DISPLAY_DOMLP="$LP_IT"
      ;;

    NL)
      DISPLAY_DOMLP="$LP_NL"
      ;;

    JA)
      DISPLAY_DOMLP="$LP_JA"
      ;;

    *)
      DISPLAY_DOMLP=
      ;;

  esac
}


select_language_pack()
{
  local LP_DE="German"
  local LP_ES="Spanish"
  local LP_FR="French"
  local LP_IT="Italian"
  local LP_NL="Dutch"
  local LP_JA="Japanese"

  ClearScreen
  echo
  echo "Domino Language Pack"
  echo "--------------------"
  echo
  print_lp "DE" "$LP_DE"
  print_lp "ES" "$LP_ES"
  print_lp "FR" "$LP_FR"
  print_lp "IT" "$LP_IT"
  print_lp "NL" "$LP_NL"
  print_lp "JA" "$LP_JA"
  echo
  echo
  read -n1 -p " Select language pack  [0] to cancel? " LP;

  case "$LP" in

    0)
      return 0
      ;;

    d)
      SELECT_DOMLP_LANG=DE
      DISPLAY_DOMLP="$LP_DE"
      ;;

    e)
      SELECT_DOMLP_LANG=ES
      DISPLAY_DOMLP="$LP_ES"
      ;;

    f)
      SELECT_DOMLP_LANG=FR
      DISPLAY_DOMLP="$LP_FR"
      ;;

    i)
      SELECT_DOMLP_LANG=IT
      DISPLAY_DOMLP="$LP_IT"
      ;;

    n)
      SELECT_DOMLP_LANG=NL
      DISPLAY_DOMLP="$LP_NL"
      ;;

    j)
      SELECT_DOMLP_LANG=JA
      DISPLAY_DOMLP="$LP_JA"
      ;;

  esac
}

select_domino_version()
{
  local VER=
  local VER_LATEST=
  local VER_140=
  local VER_1202=
  local VER_145=

  get_current_version domino VER_LATEST
  VER="$VER_LATEST"

  get_current_version domino-12.0.2 VER_1202
  get_current_version domino-14.0 VER_140
  get_current_version domino-14.5.1 VER_1451

  ClearScreen
  echo
  echo "HCL Domino Version"
  echo "------------------"
  echo

  print_ver "1" "$VER_LATEST"
  print_ver "2" "$VER_140"
  print_ver "3" "$VER_1202"
  echo
  print_ver "4" "$VER_1451 (Beta)"

  echo
  read -n1 -p " Select Domino version  [0] to cancel? " VER;

  SELECT_DOMIQ_VERSION=

  case "$VER" in

    0)
      return 0
      ;;

    1)
      DOMINO_VERSION="$VER_LATEST"
      parse_domino_version "$DOMINO_VERSION"
      get_current_addon_version traveler SELECT_TRAVELER_VERSION
      SELECT_DOMIQ_VERSION=$PROD_VER
      ONTIME_VERSION="$SELECT_ONTIME_VERSION_DOMINO145"
      ;;

    2)
      DOMINO_VERSION="$VER_140"
      SELECT_TRAVELER_VERSION="$VER_140"
      ONTIME_VERSION="$SELECT_ONTIME_VERSION_DOMINO14"
      parse_domino_version "$DOMINO_VERSION"
      get_current_addon_version traveler SELECT_TRAVELER_VERSION
      ;;

    3)
      DOMINO_VERSION="$VER_1202"
      parse_domino_version "$DOMINO_VERSION"
      # Reset OnTime for older releases
      ONTIME_VERSION=
      DominoResponseFile=
      get_current_addon_version traveler SELECT_TRAVELER_VERSION
      ;;

    4)
      DOMINO_VERSION="$VER_1451"
      parse_domino_version "$DOMINO_VERSION"
      # Reset OnTime for older releases
      ONTIME_VERSION=
      DominoResponseFile=
      get_current_addon_version traveler-14.5.1 SELECT_TRAVELER_VERSION
      ;;

  esac

  # Select corresponding C-API version
  SELECT_CAPI_VERSION=$PROD_VER
}


load_conf()
{
  local BUILD_CONF=
  local LATESTSEL=latest
  local FROM_IMAGE_SELECT=$FROM_IMAGE
  local DOCKER_TZ_SELECT=$DOCKER_TZ
  local LINUX_LANG_SELECT=$LINUX_LANG
  local DOMINO_LANG_SELECT=$DOMINO_LANG
  local LINUX_PKG_ADD_SELECT=$LINUX_PKG_ADD
  local LINUX_PKG_REMOVE_SELECT=$LINUX_PKG_REMOVE
  local LINUX_PKG_SKIP_SELECT=$LINUX_PKG_SKIP
  local LINUX_HOMEDIR_SELECT=$LINUX_HOMEDIR
  local CUSTOM_ADD_ONS_SELECT=$CUSTOM_ADD_ONS
  local BORG_SELECT=$BORG_VERSION
  local TIKA_SELECT=$TIKA_VERSION
  local MYSQL_JDBC_SELECT=$MYSQL_JDBC_VERSION
  local POSTGRESQL_JDBC_VERSION_SELECT=$POSTGRESQL_JDBC_VERSION
  local IQSUITE_SELECT=$IQSUITE_VERSION

  if [ -n "$1" ]; then
    BUILD_CONF=$DOMINO_DOCKER_CFG_DIR/$1

  elif [ -n "$CONF_FILE" ]; then
    BUILD_CONF=$DOMINO_DOCKER_CFG_DIR/$CONF_FILE

  else
    return 0
  fi

  if [ -r "$BUILD_CONF" ]; then
    . $BUILD_CONF
    echo "Conf loaded from [$BUILD_CONF]"
  fi

  PROD_NAME="domino"

  if [ -z "$DOMINO_VERSION" ] || [ "$DOMINO_VERSION" = "$LATESTSEL" ]; then
    get_current_version domino
    DOMINO_VERSION=$PROD_VER$PROD_FP$PROD_HF
  else
    parse_domino_version "$DOMINO_VERSION"
  fi

  get_current_addon_version verse SELECT_VERSE_VERSION
  get_current_addon_version nomad SELECT_NOMAD_VERSION
  get_current_addon_version traveler SELECT_TRAVELER_VERSION
  get_current_addon_version leap SELECT_LEAP_VERSION
  get_current_addon_version capi SELECT_CAPI_VERSION
  get_current_addon_version domiq SELECT_DOMIQ_VERSION
  get_current_addon_version domrestapi SELECT_DOMRESTAPI_VER
  get_current_addon_version borg SELECT_BORG_VERSION
  get_current_addon_version domborg SELECT_DOMBORG_VERSION
  get_current_addon_version tika SELECT_TIKA_VERSION
  get_current_addon_version mysql-jdbc SELECT_MYSQL_JDBC_VERSION
  get_current_addon_version postgresql-jdbc SELECT_POSTGRESQL_JDBC_VERSION
  get_current_addon_version iqsuite SELECT_IQSUITE_VERSION
  get_current_addon_version nshmailx SELECT_NSHMAILX_VERSION
  get_current_addon_version node_exporter SELECT_NODE_EXPORTER_VERSION
  get_current_addon_version domprom SELECT_DOMPROM_VERSION

  case "$PROD_VER" in

    14.5)
      SELECT_ONTIME_VERSION="$SELECT_ONTIME_VERSION_DOMINO145"
      ;;

    14*)
    SELECT_ONTIME_VERSION="$SELECT_ONTIME_VERSION_DOMINO14"
      ;;

    *)
      SELECT_ONTIME_VERSION=
      ;;
  esac

  if [ "$LATESTSEL" = "$VERSE_VERSION" ];           then VERSE_VERSION=$SELECT_VERSE_VERSION; fi
  if [ "$LATESTSEL" = "$TRAVELER_VERSION" ];        then TRAVELER_VERSION=$SELECT_TRAVELER_VERSION; fi
  if [ "$LATESTSEL" = "$NOMAD_VERSION" ];           then NOMAD_VERSION=$SELECT_NOMAD_VERSION; fi
  if [ "$LATESTSEL" = "$LEAP_VERSION" ];            then LEAP_VERSION=$SELECT_LEAP_VERSION; fi
  if [ "$LATESTSEL" = "$DOMRESTAPI_VER" ];          then DOMRESTAPI_VER=$SELECT_DOMRESTAPI_VER; fi
  if [ "$LATESTSEL" = "$CAPI_VERSION" ];            then CAPI_VERSION=$SELECT_CAPI_VERSION; fi
  if [ "$LATESTSEL" = "$DOMIQ_VERSION" ];           then DOMIQ_VERSION=$SELECT_DOMIQ_VERSION; fi
  if [ "$LATESTSEL" = "$ONTIME_VERSION" ];          then ONTIME_VERSION=$SELECT_ONTIME_VERSION; fi
  if [ "$LATESTSEL" = "$BORG_VERSION" ];            then BORG_VERSION=$SELECT_BORG_VERSION; DOMBORG_VERSION=$SELECT_DOMBORG_VERSION; fi
  if [ "$LATESTSEL" = "$TIKA_VERSION" ];            then TIKA_VERSION=$SELECT_TIKA_VERSION; fi
  if [ "$LATESTSEL" = "$MYSQL_JDBC_VERSION" ];      then MYSQL_JDBC_VERSION=$SELECT_MYSQL_JDBC_VERSION; fi
  if [ "$LATESTSEL" = "$POSTGRESQL_JDBC_VERSION" ]; then POSTGRESQL_JDBC_VERSION=$SELECT_POSTGRESQL_JDBC_VERSION; fi
  if [ "$LATESTSEL" = "$IQSUITE_VERSION" ];         then IQSUITE_VERSION=$SELECT_IQSUITE_VERSION; fi
  if [ "$LATESTSEL" = "$NSHMAILX_VERSION" ];        then NSHMAILX_VERSION=$SELECT_NSHMAILX_VERSION; fi
  if [ "$LATESTSEL" = "$NODE_EXPORTER_VERSION" ];   then NODE_EXPORTER_VERSION=$SELECT_NODE_EXPORTER_VERSION; fi
  if [ "$LATESTSEL" = "$DOMPROM_VERSION" ];         then DOMPROM_VERSION=$SELECT_DOMPROM_VERSION; fi

  if [ -n "$FROM_IMAGE_SELECT" ];        then FROM_IMAGE=$FROM_IMAGE_SELECT; fi
  if [ -n "$DOCKER_TZ_SELECT" ];         then DOCKER_TZ=$DOCKER_TZ_SELECT; fi
  if [ -n "$LINUX_LANG_SELECT" ];        then LINUX_LANG=$LINUX_LANG_SELECT; fi
  if [ -n "$DOMINO_LANG_SELECT" ];       then DOMINO_LANG=$DOMINO_LANG_SELECT; fi
  if [ -n "$LINUX_PKG_ADD_SELECT" ];     then LINUX_PKG_ADD=$LINUX_PKG_ADD_SELECT; fi
  if [ -n "$LINUX_PKG_REMOVE_SELECT" ];  then LINUX_PKG_REMOVE=$LINUX_PKG_REMOVE_SELECT; fi
  if [ -n "$LINUX_PKG_SKIP_SELECT" ];    then LINUX_PKG_SKIP=$LINUX_PKG_SKIP_SELECT; fi
  if [ -n "$CUSTOM_ADD_ONS_SELECT" ];    then CUSTOM_ADD_ONS=$CUSTOM_ADD_ONS_SELECT; fi
  if [ -n "$BORG_SELECT" ];              then BORG_VERSION=$BORG_SELECT; fi
  if [ -n "$TIKA_SELECT" ];              then TIKA_VERSION=$TIKA_SELECT; fi
  if [ -n "$MYSQL_JDBC_SELECT" ];        then MYSQL_JDBC_VERSION=$MYSQL_JDBC_SELECT; fi
  if [ -n "$IQSUITE_SELECT" ];           then IQSUITE_VERSION=$IQSUITE_SELECT; fi
  if [ -n "$NSHMAILX_SELECT" ];          then NSHMAILX_VERSION=$NSHMAILX_SELECT; fi
  if [ -n "$NODE_EXPORTER_SELECT" ];     then NODE_EXPORTER_VERSION=$NODE_EXPORTER_SELECT; fi
  if [ -n "$DOMPROM_SELECT" ];           then DOMPROM_VERSION=$DOMPROM_SELECT; fi

  if [ -n "$NODE_EXPORTER_VERSION" ] && [ -n "$DOMPROM_VERSION" ]; then PROM_INSTALL=yes; fi

  if [ -n "$ONTIME_VERSION" ]; then
     DominoResponseFile=domino14_ontime_install.properties
  fi

  check_from_image
}


write_conf()
{
  local BUILD_CONF=$DOMINO_DOCKER_CFG_DIR/$CONF_FILE
  local LATESTSEL=latest

  if [ -z "$DOMINO_DOCKER_CFG_DIR" ]; then
    echo "No configuration directory set!"
    sleep 2
    return 0
  fi

  if [ ! -e "$DOMINO_DOCKER_CFG_DIR" ]; then
     mkdir -p "$DOMINO_DOCKER_CFG_DIR"
  fi

  if [ ! -w "$DOMINO_DOCKER_CFG_DIR" ]; then
    echo "Cannot write to configuration directory: $DOMINO_DOCKER_CFG_DIR"
    sleep 2
    return 0
  fi

  echo "# Saved conf/menu file" > "$BUILD_CONF"
  echo "DOMINO_VERSION=$LATESTSEL" >> "$BUILD_CONF"

  if [ -n "$VERSE_VERSION" ];    then echo "VERSE_VERSION=$LATESTSEL"    >> "$BUILD_CONF"; fi
  if [ -n "$TRAVELER_VERSION" ]; then echo "TRAVELER_VERSION=$LATESTSEL" >> "$BUILD_CONF"; fi
  if [ -n "$NOMAD_VERSION" ];    then echo "NOMAD_VERSION=$LATESTSEL"    >> "$BUILD_CONF"; fi
  if [ -n "$DOMRESTAPI_VER" ];   then echo "DOMRESTAPI_VER=$LATESTSEL"   >> "$BUILD_CONF"; fi
  if [ -n "$CAPI_VERSION" ];     then echo "CAPI_VERSION=$LATESTSEL"     >> "$BUILD_CONF"; fi
  if [ -n "$DOMIQ_VERSION" ];    then echo "DOMIQ_VERSION=$LATESTSEL"    >> "$BUILD_CONF"; fi
  if [ -n "$LEAP_VERSION" ];     then echo "LEAP_VERSION=$LATESTSEL"     >> "$BUILD_CONF"; fi
  if [ -n "$ONTIME_VERSION" ];   then echo "ONTIME_VERSION=$LATESTSEL"   >> "$BUILD_CONF"; fi
  if [ -n "$DOMLP_LANG" ];       then echo "DOMLP_LANG=$DOMLP_LANG"      >> "$BUILD_CONF"; fi
  if [ -n "$BORG_VERSION" ];     then echo "BORG_VERSION=$LATESTSEL"     >> "$BUILD_CONF"; fi
  if [ -n "$TIKA_VERSION" ];     then echo "TIKA_VERSION=$LATESTSEL"     >> "$BUILD_CONF"; fi
  if [ -n "$IQSUITE_VERSION" ];  then echo "IQSUITE_VERSION=$LATESTSEL"  >> "$BUILD_CONF"; fi
  if [ -n "$NSHMAILX_VERSION" ]; then echo "NSHMAILX_VERSION=$LATESTSEL" >> "$BUILD_CONF"; fi

  if [ "$AutoTestImage" = "yes" ]; then echo "AutoTestImage=$AutoTestImage" >> "$BUILD_CONF"; fi

  # Additional parameters only configurable on command line
  if [ -n "$FROM_IMAGE" ];       then echo "FROM_IMAGE=$FROM_IMAGE"                 >> "$BUILD_CONF"; fi
  if [ -n "$LINUX_PKG_ADD" ];    then echo "LINUX_PKG_ADD=\"$LINUX_PKG_ADD\""       >> "$BUILD_CONF"; fi
  if [ -n "$LINUX_PKG_REMOVE" ]; then echo "LINUX_PKG_REMOVE=\"$LINUX_PKG_REMOVE\"" >> "$BUILD_CONF"; fi
  if [ -n "$LINUX_PKG_SKIP" ];   then echo "LINUX_PKG_SKIP=\"$LINUX_PKG_SKIP\""     >> "$BUILD_CONF"; fi
  if [ -n "$CUSTOM_ADD_ONS" ];   then echo "CUSTOM_ADD_ONS=$CUSTOM_ADD_ONS"         >> "$BUILD_CONF"; fi
  if [ -n "$LINUX_HOMEDIR" ];    then echo "LINUX_HOMEDIR=$LINUX_HOMEDIR"           >> "$BUILD_CONF"; fi
  if [ -n "$DOCKER_TZ" ];        then echo "DOCKER_TZ=$DOCKER_TZ"                   >> "$BUILD_CONF"; fi
  if [ -n "$LINUX_LANG" ];       then echo "LINUX_LANG=$LINUX_LANG"                 >> "$BUILD_CONF"; fi
  if [ -n "$DOMINO_LANG" ];      then echo "DOMINO_LANG=$DOMINO_LANG"               >> "$BUILD_CONF"; fi
  if [ -n "$DOMPROM_VERSION" ];  then echo "DOMPROM_VERSION=$LATESTSEL"             >> "$BUILD_CONF"; fi

  if [ -n "$MYSQL_JDBC_VERSION" ];      then echo "MYSQL_JDBC_VERSION=$LATESTSEL"      >> "$BUILD_CONF"; fi
  if [ -n "$POSTGRESQL_JDBC_VERSION" ]; then echo "POSTGRESQL_JDBC_VERSION=$LATESTSEL" >> "$BUILD_CONF"; fi
  if [ -n "$NODE_EXPORTER_VERSION" ];   then echo "NODE_EXPORTER_VERSION=$LATESTSEL"   >> "$BUILD_CONF"; fi

  # Parameters only stored in conf file
  echo "CONTAINER_MAINTAINER=\"$CONTAINER_MAINTAINER\""                 >> "$BUILD_CONF"
  echo "CONTAINER_VENDOR=\"$CONTAINER_VENDOR\""                         >> "$BUILD_CONF"
  echo "CONTAINER_DOMINO_NAME=\"$CONTAINER_DOMINO_NAME\""               >> "$BUILD_CONF"
  echo "CONTAINER_DOMINO_DESCRIPTION=\"$CONTAINER_DOMINO_DESCRIPTION\"" >> "$BUILD_CONF"
  echo "CONTAINER_IMAGE_VERSION=\"$CONTAINER_IMAGE_VERSION\""           >> "$BUILD_CONF"
  echo "CONTAINER_IMAGE_NAME=\"$CONTAINER_IMAGE_NAME\""                 >> "$BUILD_CONF"

  echo
  echo
  echo " Saved to [$BUILD_CONF]"
  echo -n " "
  sleep 2
}

edit_conf()
{
  local BUILD_CONF=$DOMINO_DOCKER_CFG_DIR/$CONF_FILE
  local MODIFIED_BEFORE=
  local MODIFIED_AFTER=

  if [ -z "$CONF_FILE" ]; then
    return 0
  fi

  if [ -e "$BUILD_CONF" ]; then
    local MODIFIED_BEFORE=$(stat -c %Y "$BUILD_CONF")
  fi

  if [ ! -e "$BUILD_CONF" ]; then
    write_conf
    $EDIT_COMMAND "$BUILD_CONF"
  fi

  $EDIT_COMMAND "$BUILD_CONF"

  MODIFIED_AFTER=$(stat -c %Y "$BUILD_CONF")

  if [ "$MODIFIED_BEFORE" = "$MODIFIED_AFTER" ]; then
    return 0
  fi

  # Reset certain variables before reload
  CUSTOM_ADD_ONS=
  FROM_IMAGE=
  BORG_VERSION=
  TIKA_VERSION=
  IQSUITE_VERSION=
  MYSQL_JDBC_VERSION=
  POSTGRESQL_JDBC_VERSION=

  load_conf
}


display_custom_add_ons()
{
  local TXT=
  local ADD_ON=
  local DISPLAY_ADD_ONS=

  if [ -z "$CUSTOM_ADD_ONS" ]; then
    return 0
  fi

  for ADD_ON in $(echo "$CUSTOM_ADD_ONS" | tr "," "\n" ) ; do

    TXT=$(echo $ADD_ON | cut -f1 -d'#')
    if [ -z "$DISPLAY_ADD_ONS" ]; then
      DISPLAY_ADD_ONS="$TXT"
    else
      DISPLAY_ADD_ONS="$DISPLAY_ADD_ONS, $TXT"
    fi
  done

  echo " Add-Ons    : $DISPLAY_ADD_ONS"
}


select_software()
{
  SELECTED=

  local SELECT_TRAVELER_VERSION=
  local SELECT_NOMAD_VERSION=
  local SELECT_VERSE_VERSION=

  local SELECT_LEAP_VERSION=
  local SELECT_CAPI_VERSION=
  local SELECT_DOMIQ_VERSION=
  local SELECT_NSHMAILX_VERSION=
  local SELECT_DOMRESTAPI_VER=
  local SELECT_DOMLP_LANG=
  local SELECT_BORG=
  local SELECT_PROM=

  local XX="X"
  local ZZ=" "
  local DISPLAY_LP=
  local D=$XX
  local T=$ZZ
  local N=$ZZ
  local V=$ZZ
  local R=$ZZ
  local L=$ZZ
  local C=$ZZ
  local P=$ZZ
  local A=$ZZ
  local I=$ZZ
  local O=$ZZ
  local G=$ZZ
  local M=$ZZ
  local J=$ZZ

  load_conf

  while [ 1 ];
  do

     # Language pack has special display mapping and is selected by name
    SELECT_DOMLP_LANG=$DOMLP_LANG
    get_language_pack_display_name

    if [ -n "$VERSE_VERSION" ];    then V=$XX; else V=$ZZ; fi
    if [ -n "$TRAVELER_VERSION" ]; then T=$XX; else T=$ZZ; fi
    if [ -n "$NOMAD_VERSION" ];    then N=$XX; else N=$ZZ; fi
    if [ -n "$DOMLP_LANG" ];       then L=$XX; else L=$ZZ; fi
    if [ -n "$DOMRESTAPI_VER" ];   then R=$XX; else R=$ZZ; fi
    if [ -n "$CAPI_VERSION" ];     then A=$XX; else A=$ZZ; fi
    if [ -n "$DOMIQ_VERSION" ];    then J=$XX; else J=$ZZ; fi
    if [ -n "$NSHMAILX_VERSION" ]; then X=$XX; else X=$ZZ; fi
    if [ -n "$LEAP_VERSION" ];     then P=$XX; else P=$ZZ; fi
    if [ -n "$ONTIME_VERSION" ];   then O=$XX; else O=$ZZ; fi
    if [ -n "$BORG_VERSION" ];     then G=$XX; else G=$ZZ; fi
    if [ -n "$PROM_INSTALL" ];     then M=$XX; else M=$ZZ; fi

    if [ "$AutoTestImage" = "yes" ]; then I=$XX; else I=$ZZ; fi

    if [ -z "$DOMLP_LANG" ]; then
      DISPLAY_LP=
    else
       DISPLAY_LP="$DISPLAY_DOMLP ($DOMLP_LANG)"
    fi

    if [ "$PROM_INSTALL" = "yes" ]; then
      DISPLAY_PROM="domprom $DOMPROM_VERSION & Node Exporter $NODE_EXPORTER_VERSION"
    else
      DISPLAY_PROM=
    fi

    ClearScreen
    echo

    if [ "$INSTALL_DOMINO_NATIVE" = "yes" ]; then
      echo "HCL Domino on Linux Installer"
      echo "-----------------------------"
    else
      echo "HCL Domino Container Community Image"
      echo "------------------------------------"
    fi

    echo
    print_select "D" "HCL Domino"     "$D" "$DOMINO_VERSION"

    case "$PROD_VER" in
      14*) print_select "O" "OnTime" "$O" "$ONTIME_VERSION"
    esac

    print_select "V" "Verse"          "$V" "$VERSE_VERSION"
    print_select "T" "Traveler"       "$T" "$TRAVELER_VERSION"
    print_select "N" "Nomad Server"   "$N" "$NOMAD_VERSION"
    print_select "L" "Language Pack"  "$L" "$DISPLAY_LP"
    print_select "R" "REST-API"       "$R" "$DOMRESTAPI_VER"
    print_select "A" "C-API SDK"      "$A" "$CAPI_VERSION"
    print_select "P" "Domino Leap"    "$P" "$LEAP_VERSION"
    if [ -n "$SELECT_DOMIQ_VERSION" ]; then
      print_select "J" "Domino IQ"      "$J" "$DOMIQ_VERSION"
    fi
    echo
    print_select "M" "Prometheus"     "$M" "$DISPLAY_PROM"
    print_select "G" "Borg Backup"    "$G" "$BORG_VERSION"
    print_select "X" "nshmailx"       "$X" "$NSHMAILX_VERSION"

    echo
    if [ "$INSTALL_DOMINO_NATIVE" != "yes" ]; then
      print_select "I" "Test created image" "$I"
      echo
    fi

    print_select "W" "Write selection"
    print_select "E" "Edit selection"
    print_select "C" "Configuration"
    print_select "H" "Help"
    echo

    display_custom_add_ons
    if [ -n "$TIKA_VERSION" ]; then
      echo " Tika Server: $TIKA_VERSION"
    fi

    if [ -n "$IQSUITE_VERSION" ]; then
      echo " IQ Suite   : $IQSUITE_VERSION"
    fi

    if [ "$INSTALL_DOMINO_NATIVE" != "yes" ]; then
      echo
      echo " Base Image : $LINUX_NAME"

      if [ -n "$DOCKER_VERSION_STR" ]; then
    echo
        echo " $DISPLAY_WARNING"
     fi

    fi

    echo
    read -n1 -p " Select software & Options,  [B] to build,  [Q] to cancel? " SELECTED;

    case $(echo "$SELECTED" | awk '{print tolower($0)}') in

      b)
        return 0
        ;;

      0|q)
        ClearScreen
    echo
        exit 0
        ;;

      t)
        if [ -z "$TRAVELER_VERSION" ]; then
          case "$PROD_VER" in
            *)
               TRAVELER_VERSION="$SELECT_TRAVELER_VERSION"
               ;;
          esac

          T=$XX
        else
          TRAVELER_VERSION=
          T=$ZZ
        fi
        ;;

      n)
        if [ -z "$NOMAD_VERSION" ]; then
          NOMAD_VERSION=$SELECT_NOMAD_VERSION
        else
          NOMAD_VERSION=
        fi
        ;;

      v)
        if [ -z "$VERSE_VERSION" ]; then
          VERSE_VERSION=$SELECT_VERSE_VERSION
        else
          VERSE_VERSION=
        fi
        ;;

      r)
        if [ -z "$DOMRESTAPI_VER" ]; then
          DOMRESTAPI_VER=$SELECT_DOMRESTAPI_VER
        else
          DOMRESTAPI_VER=
        fi
        ;;

      p)
        if [ -z "$LEAP_VERSION" ]; then
          LEAP_VERSION=$SELECT_LEAP_VERSION
        else
          LEAP_VERSION=
        fi
        ;;

      a)
        if [ -z "$CAPI_VERSION" ]; then
          CAPI_VERSION=$SELECT_CAPI_VERSION
        else
          CAPI_VERSION=
        fi
        ;;

      x)
        if [ -z "$NSHMAILX_VERSION" ]; then
          NSHMAILX_VERSION=$SELECT_NSHMAILX_VERSION
        else
          NSHMAILX_VERSION=
        fi
        ;;

      j)
        if [ -z "$DOMIQ_VERSION" ]; then
          DOMIQ_VERSION=$SELECT_DOMIQ_VERSION
        else
          DOMIQ_VERSION=
        fi
        ;;

      m)
        if [ -z "$PROM_INSTALL" ]; then
          PROM_INSTALL=yes

          if [ -z "$NODE_EXPORTER_VERSION" ]; then
            get_current_addon_version node_exporter NODE_EXPORTER_VERSION
          fi

          if [ -z "$DOMPROM_VERSION" ]; then
            get_current_addon_version domprom DOMPROM_VERSION
          fi

        else
          PROM_INSTALL=
      DOMPROM_VERSION=
          NODE_EXPORTER_VERSION=
        fi
        ;;

      g)
        if [ -z "$BORG_VERSION" ]; then
          BORG_VERSION=$SELECT_BORG_VERSION
          DOMBORG_VERSION=$SELECT_DOMBORG_VERSION
        else
          BORG_VERSION=
          DOMBORG_VERSION=
        fi
        ;;

      l)
        if [ -z "$DOMLP_LANG" ]; then
          select_language_pack
          DOMLP_LANG=$SELECT_DOMLP_LANG
        else
          DOMLP_LANG=
        fi
        ;;

      d)
        select_domino_version

        if [ -n "$TRAVELER_VERSION" ]; then
          case "$PROD_VER" in
            *)
               TRAVELER_VERSION="$SELECT_TRAVELER_VERSION"
               ;;
          esac
        fi
        ;;

      o)
        if [ -z "$ONTIME_VERSION" ]; then
          case "$PROD_VER" in
            14.5)
              ONTIME_VERSION="$SELECT_ONTIME_VERSION_DOMINO145"
              DominoResponseFile=domino14_ontime_install.properties
              ;;

            14*)
              ONTIME_VERSION="$SELECT_ONTIME_VERSION_DOMINO14"
              SELECT_DOMIQ_VERSION=
              DominoResponseFile=domino14_ontime_install.properties
              ;;

            *)
              ONTIME_VERSION=
              DominoResponseFile=
              ;;
           esac
        else
          ONTIME_VERSION=
          DominoResponseFile=
        fi
        ;;

      i)
        if [ -z "$AutoTestImage" ]; then
          AutoTestImage=yes
        else
          AutoTestImage=
        fi
        ;;

      c)
        edit_config_file
        ;;

      w)
        write_conf
        ;;

      e)
        edit_conf
        ;;

      h)
    usage
        read -n1 -p "" SELECTED;
        ;;

      *)
    echo
    echo
    echo " Invalid option selected: $SELECTED"
    echo -n " "
    sleep 2
    ;;
    esac

  done
}

build_menu()
{
  # Ensure to always read from terminal even stdin was redirected
  exec < /dev/tty
  select_software
  ClearScreen
  echo

  if [ -n "$ONTIME_VER" ]; then
    DominoResponseFile=domino14_ontime_install.properties
  fi

  if [ "$SELECTED" = "0" ] || [ -z "$SELECTED" ] ; then
    log "No build selected - Done"
    exit 0
  fi

  TAG_LATEST="latest"
}


copy_software_txt()
{
  if [ -z "$SOFTWARE_DIR" ]; then
    SOFTWARE_DIR=/local/software
  fi

  if [ ! -e "$SOFTWARE_DIR/software/current_version.txt" ]; then
    cp "$SCRIPT_DIR/software/current_version.txt" "$SOFTWARE_DIR"
  fi

  if [ ! -e "$SOFTWARE_DIR/software/software.txt" ]; then
    cp "$SCRIPT_DIR/software/software.txt" "$SOFTWARE_DIR"
  fi
}


install_domino_native()
{
  header "Installing Domino on local machine ..."

  local INSTALL_TMP_DIR=/tmp/install_domino
  export DOMDOCK_LOG_DIR=/tmp/install_domino/logs

  mkdir -p "$INSTALL_TMP_DIR"
  mkdir -p "$DOMDOCK_LOG_DIR"

  # Copy install files
  cp -r $SCRIPT_DIR/dockerfiles/install_dir_domino/* "$INSTALL_TMP_DIR"
  cp -r $SCRIPT_DIR/dockerfiles/install_dir_common/* "$INSTALL_TMP_DIR"

  cd "$INSTALL_TMP_DIR"

  # Export variables
  export PROD_NAME
  export PROD_VER
  export DOMLP_VER
  export DOMRESTAPI_VER
  export PROD_FP
  export PROD_HF
  export TIKA_VERSION
  export MYSQL_JDBC_VERSION
  export POSTGRESQL_JDBC_VERSION
  export IQSUITE_VERSION
  export VERSE_VERSION
  export NOMAD_VERSION
  export TRAVELER_VERSION
  export LEAP_VERSION
  export CAPI_VERSION
  export DOMIQ_VERSION
  export NSHMAILX_VERSION
  export CUSTOM_ADD_ONS
  export DOMINO_LANG
  export LINUX_LANG
  export DominoResponseFile
  export BUILD_SCRIPT_OPTIONS
  export INSTALL_DOMINO_NATIVE
  export DOMINO_INSTALL_DATA_TAR
  export LinuxYumUpdate
  export SPECIAL_CURL_ARGS

  export SkipDominoMoveInstallData=yes
  export DOMDOCK_LOG_DIR=/tmp

  # Always replace REST API binary directory
  if [ -n "$DOMRESTAPI_VER" ]; then
    if [ -e "/opt/hcl/restapi" ]; then
      rm -rf "/opt/hcl/restapi"
    fi
  fi

  if [ -n "$DOWNLOAD_FROM" ]; then
    export DownloadFrom="$DOWNLOAD_FROM"

  else
    if [ -z "$SOFTWARE_DIR" ]; then
      SOFTWARE_DIR=/local/software
    fi

    export DownloadFrom="file://$SOFTWARE_DIR"
  fi

  log "Getting software from: $DownloadFrom"

  $(pwd)/install_linux.sh
  $(pwd)/install_domino.sh

  # cleanup
  cd /
  rm -rf "$INSTALL_TMP_DIR"
}


# --- Main script logic ---

SOFTWARE_PORT=7777
SOFTWARE_FILE_NAME=software.txt
SOFTWARE_CONTAINER=hclsoftware

VERSION_FILE_NAME=current_version.txt
DOMDOWNLOAD_BIN=/usr/local/bin/domdownload

# Use vi if no other editor specified in config

if [ -z "$EDIT_COMMAND" ]; then
  if [ -n "$EDITOR" ]; then
    EDIT_COMMAND="$EDITOR"
  else
    EDIT_COMMAND="vi"
  fi
fi

# Default config directory. Can be overwritten by environment

if [ -z "$BUILD_CFG_FILE"]; then
  BUILD_CFG_FILE=build.cfg
fi

if [ -z "$DOMINO_DOCKER_CFG_DIR" ]; then

  # Check for legacy config else use new location in user home. But first check if the local directory has a configuration

  if [ -r .DominoContainer ]; then
    DOMINO_DOCKER_CFG_DIR=.DominoContainer
    CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/$BUILD_CFG_FILE

  elif [ -r /local/cfg/build_config ]; then
    DOMINO_DOCKER_CFG_DIR=/local/cfg
    CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/build_config

  elif [ -r ~/DominoDocker/build.cfg ]; then
    DOMINO_DOCKER_CFG_DIR=~/DominoDocker
    CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/build.cfg

  elif [ -r ~/.DominoDocker/build.cfg ]; then
    DOMINO_DOCKER_CFG_DIR=~/.DominoDocker
    CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/build.cfg

  else
    DOMINO_DOCKER_CFG_DIR=~/.DominoContainer
    CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/$BUILD_CFG_FILE
  fi
else
    if [ -z "$CONFIG_FILE" ]; then
      CONFIG_FILE=$DOMINO_DOCKER_CFG_DIR/$BUILD_CFG_FILE
    fi
fi

# Use a config file if present

if [ -r "$CONFIG_FILE" ]; then
  echo "(Using config file $CONFIG_FILE)"
  . $CONFIG_FILE
else
  if [ -r "$BUILD_CFG_FILE" ]; then
    . "$BUILD_CFG_FILE"
  fi
fi

CURL_CMD="curl --location --max-redirs 10 --fail --connect-timeout 15 --max-time 300 $SPECIAL_CURL_ARGS"
VERSION_FILE=$SOFTWARE_DIR/$VERSION_FILE_NAME

# If version file isn't found check standard location (check might lead to the same directory if standard location already)
if [ ! -e "$VERSION_FILE" ]; then
  VERSION_FILE=$SCRIPT_DIR/software/$VERSION_FILE_NAME
fi

# Invoke menu if no parameters are specified or a menu file is specified
if [ -z "$1" ]; then

  if [ -z "$CONF_FILE" ]; then
    CONF_FILE=default.conf
  fi
fi

# Special commands
if [ "$1" = "save" ]; then
  if [ -z "$3" ]; then
    log_error_exit "Invalid syntax! Usage: $0 save <image name> <export name>"
  fi

  # get and check container environment (usually initialized after getting all the options)
  check_container_environment

  header "Exporting $2 -> $3 - This takes some time ..."
  $CONTAINER_CMD save "$2" | gzip > "$3"

  if [ "$?" = "0" ]; then
    IMAGE_SIZE=$(du -h $3)
    log "Exported container image: $IMAGE_SIZE"
  else
    log_error_exit "Error exporting container image!"
  fi

  exit 0
fi

# Install OpenSSL by default
if [ -z "$OPENSSL_INSTALL" ]; then
  OPENSSL_INSTALL=yes
fi

for a in "$@"; do

  p=$(echo "$a" | awk '{print tolower($0)}')

  case "$p" in
    domino|traveler|volt|leap|safelinx)
      PROD_NAME=$p
      ;;

    squid)
      SQUID_IMAGE_NAME=hclcom/squid
      build_squid_image
      exit 0
      ;;

    testimage|testimage=*)
      IMAGE_NAME=$(echo "$a" | cut -f2 -d= -s)
      if [ -n "$IMAGE_NAME" ]; then
        test_image "$IMAGE_NAME"
      else
        test_image "$DOCKER_IMAGE_NAME"
      fi
      exit 0
      ;;

    -verse*|+verse*)
      VERSE_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$VERSE_VERSION" ]; then
        get_current_addon_version verse VERSE_VERSION
      fi
      ;;

    -nomadweb*|+nomadweb*)
      NOMADWEB_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$NOMADWEB_VERSION" ]; then
        get_current_addon_version nomadweb NOMADWEB_VERSION
      fi
      ;;

    -nomad*|+nomad*)
      NOMAD_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$NOMAD_VERSION" ]; then
        get_current_addon_version nomad NOMAD_VERSION
      fi
      ;;

    -traveler_download=*)
      TRAVELER_DOWNLOAD_FILE=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -traveler*|+traveler*)
      TRAVELER_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$TRAVELER_VERSION" ]; then
        get_current_addon_version traveler TRAVELER_VERSION
      fi
      ;;

    -leap*|+leap*)
      LEAP_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$LEAP_VERSION" ]; then
        get_current_addon_version leap LEAP_VERSION
      fi
      ;;

    -mysql-jdbc*|+mysql-jdbc*)
      MYSQL_JDBC_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$MYSQL_JDBC_VERSION" ]; then
        get_current_addon_version mysql-jdbc MYSQL_JDBC_VERSION
      fi
      ;;

   -postgresql-jdbc*|+postgresql-jdbc*)
      POSTGRESQL_JDBC_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$POSTGRESQL_JDBC_VERSION" ]; then
        get_current_addon_version postgresql-jdbc POSTGRESQL_JDBC_VERSION
      fi
      ;;

    -mysql*|+mysql*)
      MYSQL_INSTALL=yes
      ;;

    -mssql*|+mssql*)
      MSSQL_INSTALL=yes
      ;;

    -capi*|+capi*)
      CAPI_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$CAPI_VERSION" ]; then
        get_current_addon_version capi CAPI_VERSION
      fi
      ;;

    -domiq*|+domiq*)
      DOMIQ_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$DOMIQ_VERSION" ]; then
        get_current_addon_version domiq DOMIQ_VERSION
      fi
      ;;

    -linuxpkg=*|+linuxpkg=*)
      LINUX_PKG_ADD=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -linuxpkgrm=*|+linuxpkgrm=*|-linuxpkgremove=*|+linuxpkgremove=*)
      LINUX_PKG_REMOVE=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -linuxpkgskip=*|+linuxpkgskip=*)
      LINUX_PKG_SKIP=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -homedir=*)
    LINUX_HOMEDIR=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -startscript=*|+startscript=*)
      STARTSCRIPT_VER=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -custom-addon=*|+custom-addon=*)
      CUSTOM_ADD_ONS=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -custom-add-ons=*|+custom-add-ons=*)
      CUSTOM_ADD_ONS=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -from=*)
      FROM_IMAGE=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -software=*)
      SOFTWARE_DIR=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -download=*)
      DOWNLOAD_FROM=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -imagename=*)
      DOCKER_IMAGE_NAME=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -imagetag=*)
      DOCKER_IMAGE_TAG=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -save=*)
      DOCKER_IMAGE_EXPORT_NAME=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -tz=*)
      DOCKER_TZ=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -locale=*)
      DOMINO_LANG=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -lang=*)
      LINUX_LANG=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -pull)
      DOCKER_PULL_OPTION="--pull"
      ;;

   -tag=*)
      TAG_IMAGE=$(echo "$a" | cut -f2 -d= -s)
      ;;

   -push=*)
      PUSH_IMAGE=$(echo "$a" | cut -f2 -d= -s)
      ;;

   -prod_download=*)
      PROD_DOWNLOAD_FILE=$(echo "$a" | cut -f2 -d= -s)
      ;;

   -fp_download=*)
      PROD_FP_DOWNLOAD_FILE=$(echo "$a" | cut -f2 -d= -s)
      ;;

   -hf_download=*)
      PROD_HF_DOWNLOAD_FILE=$(echo "$a" | cut -f2 -d= -s)
      ;;

   -nginx=*)
      NGINX_IMAGE_NAME=$(echo "$a" | cut -f2 -d= -s)
      ;;

   -nginxbase=*)
      NGINX_BASE_IMAGE=$(echo "$a" | cut -f2 -d= -s)
      ;;

    9*|10*|11*|12*|14*|v12*|v14*)
      PROD_VER=$a
      ;;

    fp*)
      PROD_FP=$p
      ;;

    beta*)
      PROD_FP=$p
      ;;

    hf*|if*)
      PROD_HF=$p
      ;;

    -domlp=*|+domlp=*)
      DOMLP_LANG=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -restapi_download=*)
      RESTAPI_DOWNLOAD_FILE=$(echo "$a" | cut -f2 -d= -s)
      echo "RESTAPI_DOWNLOAD_FILE: [$RESTAPI_DOWNLOAD_FILE]"
      ;;

    -restapi*|+restapi*)
      DOMRESTAPI_VER=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$DOMRESTAPI_VER" ]; then
        get_current_addon_version domrestapi DOMRESTAPI_VER
      fi
      ;;

    -DominoResponseFile=*)
      DominoResponseFile=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -ontime|+ontime)
      DominoResponseFile=domino14_ontime_install.properties
      ONTIME_VERSION=$SELECT_ONTIME_VERSION_DOMINO145
      ;;

    _*)
      PROD_EXT=$a
      ;;

    # Special for other latest tags
    latest*)
      TAG_LATEST=$a
      ;;

    dockerfile*)
      DOCKER_FILE=$a
      ;;

    domino-docker:*)
      # To build on top of HCL image
      FROM_IMAGE=$a
      DOCKER_FILE=dockerfile_hcl
      ;;

    cfg|config)
      edit_config_file
      exit 0
      ;;

    cpcfg)
      copy_config_file
      exit 0
      ;;

    apline_build_env)
      build_alpine_build_env
      exit 0
      ;;

    -checkonly)
      BUILD_IMAGE=no
      CHECK_SOFTWARE=yes
      ;;

    -check)
      CHECK_SOFTWARE=yes
      ;;

    -nocheck)
      CHECK_SOFTWARE=no
      ;;

    -verifyonly)
      BUILD_IMAGE=no
      CHECK_SOFTWARE=yes
      CHECK_HASH=yes
      ;;

    -verify)
      CHECK_SOFTWARE=yes
      CHECK_HASH=yes
      ;;

    -noverify)
      CHECK_HASH=no
      ;;

    -url)
      DOWNLOAD_URLS_SHOW=yes
      ;;

    -nourl)
      DOWNLOAD_URLS_SHOW=no
      ;;

    -linuxupd)
      LinuxYumUpdate=yes
      ;;

    -nolinuxupd)
      LinuxYumUpdate=no
      ;;

    -installnative)
      INSTALL_DOMINO_NATIVE=yes
      ;;

    menu|m)
      BUILD_MENU=yes
      CONF_FILE=default.conf
      ;;

    menu=*|-menu=*)
      CONF_FILE=$(echo "$a" | cut -f2 -d= -s)

      case "$CONF_FILE" in
        *.conf)
          ;;
        *)
      CONF_FILE=$CONF_FILE.conf
          ;;
      esac
      ;;

    conf|-conf)
      load_conf default.conf
      ;;

    conf=*|-conf=*)
      TEMP=$(echo "$a" | cut -f2 -d= -s)

      case "$TEMP" in
        *.conf)
          ;;
        *)
          TEMP=$TEMP.conf
          ;;
      esac

      load_conf "$TEMP"
      TEMP=
      ;;

    -cfgdir=*|-configdir=*)
      DOMINO_DOCKER_CFG_DIR=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -autotest)
      AutoTestImage=yes
      ;;

    -scan)
      ScanImage=yes
      ;;

    -scan=*)
      IMAGE_SCAN_RESULT_FILE=$(echo "$a" | cut -f2 -d= -s)
      ;;

    -borg|-borg=*|+borg|+borg=*)
      BORG_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$BORG_VERSION" ]; then
        get_current_addon_version borg BORG_VERSION
      fi

      if [ -z "$BORG_VERSION" ]; then
        BORG_VERSION=yes
      fi
      ;;

    -tika|-tika=*|+tika|+tika=*)
      TIKA_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$TIKA_VERSION" ]; then
        get_current_addon_version tika TIKA_VERSION
      fi

      if [ -z "$TIKA_VERSION" ]; then
        TIKA_VERSION=yes
      fi
      ;;

    -iqsuite|-iqsuite=*|+iqsuite|+iqsuite=*)
      IQSUITE_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$IQSUITE_VERSION" ]; then
        get_current_addon_version iqsuite IQSUITE_VERSION
      fi
      ;;

    -nshmailx|--nshmailx=*|+-nshmailx|+-nshmailx=*)
      NSHMAILX_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$NSHMAILX_VERSION" ]; then
        get_current_addon_version nshmailx NSHMAILX_VERSION
      fi
      ;;

    -node_exporter|-node_exporter=*|+node_exporter|+=node_exporter*)
      NODE_EXPORTER_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$NODE_EXPORTER_VERSION" ]; then
        get_current_addon_version node_exporter NODE_EXPORTER_VERSION
      fi

      if [ -z "$NODE_EXPORTER_VERSION" ]; then
        NODE_EXPORTER_VERSION=yes
      fi
      ;;

    -domprom|-domprom=*|+domprom|+=domprom*)
      DOMPROM_VERSION=$(echo "$a" | cut -f2 -d= -s)

      if [ -z "$DOMPROM_VERSION" ]; then
        get_current_addon_version domprom DOMPROM_VERSION
      fi

      if [ -z "$DOMPROM_VERSION" ]; then
        DOMPROM_VERSION=yes
      fi
      ;;

    -prometheus|-prom)

      PROM_INSTALL=yes

      if [ -z "$DOMPROM_VERSION" ]; then
        get_current_addon_version domprom DOMPROM_VERSION
      fi

      if [ -z "$DOMPROM_VERSION" ]; then
        DOMPROM_VERSION=yes
      fi

      if [ -z "$NODE_EXPORTER_VERSION" ]; then
        get_current_addon_version node_exporter NODE_EXPORTER_VERSION
      fi

      if [ -z "$NODE_EXPORTER_VERSION" ]; then
        NODE_EXPORTER_VERSION=yes
      fi
      ;;

    -openssl)
      OPENSSL_INSTALL=yes
      ;;

    -noopenssl)
      OPENSSL_INSTALL=no
      ;;

    -ssh)
      SSH_INSTALL=yes
      ;;

    -k8s-runas)
      K8S_RUNAS_USER_SUPPORT=yes
      ;;

    ver|version|-ver|-version)
      # check container environment first
      check_container_environment
      show_version
      exit 0
      ;;

    about)

      if [ -x /opt/nashcom/startscript/nshinfo.sh ]; then
        /opt/nashcom/startscript/nshinfo.sh

      elif [ -x "$SCRIPT_DIR/dockerfiles/install_dir_domino/startscript/nshinfo.sh" ]; then
        "$SCRIPT_DIR/dockerfiles/install_dir_domino/startscript/nshinfo.sh"

      else
        echo "No Info Script available"
      fi
      exit 0
      ;;

    About|about+)

      if [ -x /opt/nashcom/startscript/nshinfo.sh ]; then
        /opt/nashcom/startscript/nshinfo.sh ipinfo

      elif [ -x "$SCRIPT_DIR/dockerfiles/install_dir_domino/startscript/nshinfo.sh" ]; then
        "$SCRIPT_DIR/dockerfiles/install_dir_domino/startscript/nshinfo.sh"

      else
        echo "No Info Script available"
      fi

      exit 0
      ;;

    -h|/h|-?|/?|-help|--help|help|usage)
      usage
      exit 0
      ;;

    *)
      log_error_exit "Invalid parameter [$a]"
      ;;
  esac
done


# Copy software.txt ..
if [ "$INSTALL_DOMINO_NATIVE" = "yes" ]; then
  copy_software_txt
fi


check_timezone
check_container_environment

# Invoke build menu asking for Domino image details
if [ "$BUILD_MENU" = "yes" ] || [ -n "$CONF_FILE" ] ; then
  build_menu
fi

if [ -n "$DISPLAY_WARNING" ]; then
  log "Warning - $DISPLAY_WARNING"
  sleep 4
fi

if [ -z "$PROD_NAME" ]; then
  PROD_NAME="domino"
fi

check_for_hcl_image
check_from_image

echo "[Running in $CONTAINER_CMD configuration]"

# In case software directory is not set and the well know location is filled with software

if [ -z "$SOFTWARE_DIR" ]; then
  SOFTWARE_DIR=$SCRIPT_DIR/software
fi

if [ -z "$DOWNLOAD_FROM" ]; then
  SOFTWARE_USE_NGINX=1
fi

if [ -z "$DOWNLOAD_FROM" ]; then

  echo "Getting software from [$SOFTWARE_DIR]"
else
  echo "Getting software from [$DOWNLOAD_FROM]"
fi

if [ -z "$PROD_VER" ]; then
  PROD_VER="latest"
fi

if [ -z "$BUILD_OPTIONS" ]; then
  BUILD_OPTIONS="--platform linux/amd64"
fi

if [ "$CONTAINER_BUILD_DISABLE_HOST_NET" != "1" ]; then
  BUILD_OPTION_NET="--network=host"
fi

if [ "$PROD_VER" = "latest" ]; then
  get_current_version "$PROD_NAME"

  if [ -z "$TAG_LATEST" ]; then
    TAG_LATEST="latest"
  fi
fi

# Calculate the right version for Language Pack
if [ -n "$DOMLP_LANG" ]; then
  DOMLP_LANG=$(echo "$DOMLP_LANG" | awk '{print toupper($0)}')
  DOMLP_VER=$DOMLP_LANG-$PROD_VER
fi

# Calculate the right version for Nomad server for selected Domino version
if [ -n "$NOMAD_VERSION" ]; then

  # Allow to specify explict nomad version (currently identified by "-". might change in future )
  case "$NOMAD_VERSION" in

    *-*)
      ;;

    # For now make it a special case before we phase out older Nomad versions
    1.0.13*|1.0.14*|1.0.15*|1.0.16*|1.0.17*)
      ;;

    *)
      NOMAD_VERSION=$NOMAD_VERSION-$PROD_VER
      ;;
  esac
fi

# If borgbackup is installed, also install Domino Borg
if [ -n "$BORG_VERSION" ]; then
  get_current_addon_version domborg DOMBORG_VERSION
fi


# Calculate the right version for Domino RESTAPI for selected Domino version
if [ -n "$DOMRESTAPI_VER" ] && [ -z "$RESTAPI_DOWNLOAD_FILE" ] ; then

  case "$PROD_VER" in

    12*)
      DOMRESTAPI_VER=$DOMRESTAPI_VER-12
      ;;

    14.5*)
      DOMRESTAPI_VER=$DOMRESTAPI_VER-14.5
      ;;

    *)
      DOMRESTAPI_VER=$DOMRESTAPI_VER-14
      ;;
  esac
fi


check_exposed_ports

# Ensure product versions are always uppercase
#PROD_VER=$(echo "$PROD_VER" | awk '{print toupper($0)}')
PROD_FP=$(echo "$PROD_FP" | awk '{print toupper($0)}')
PROD_HF=$(echo "$PROD_HF" | awk '{print toupper($0)}')
DOMLP_LANG=$(echo "$DOMLP_LANG" | awk '{print toupper($0)}')

# Ensure the right response file
if [ "$PROD_NAME" = "domino" ] && [ -z "$DominoResponseFile" ]; then
  case "$PROD_VER" in
    14*)
      DominoResponseFile=domino14_install.properties
      ;;
  esac
fi

# The HCL image always uses the full Domino 14.0 install including Verse, Nomad and OnTime
if [ "$DOCKER_FILE" = "dockerfile_hcl" ]; then
  DominoResponseFile=domino14_full_install.properties
fi

echo
echo "Product to install: $PROD_NAME $PROD_VER $PROD_FP $PROD_HF"
echo

dump_config

if [ -z "$PROD_NAME" ]; then
  log_error_exit "No product specified! - Terminating"
fi

if [ -z "$PROD_VER" ]; then
  log_error_exit "No Target version specified! - Terminating"
fi


if [ "$CHECK_SOFTWARE" = "yes" ]; then


  if [ -n "$CUSTOM_ADD_ONS" ]; then
    check_custom_software "$CUSTOM_ADD_ONS"
  fi

  check_all_software

  if [ ! "$CHECK_SOFTWARE_STATUS" = "0" ]; then
    #Terminate if status is not OK. Errors are already logged
    exit 0
  fi

fi

if [ "$BUILD_IMAGE" = "no" ]; then
  # no build requested
  exit 0
fi

if [ -z "$DOWNLOAD_FROM" ]; then
  SOFTWARE_USE_NGINX=1

  if [ -z "$SOFTWARE_DIR" ]; then
    SOFTWARE_DIR=$SCRIPT_DIR/software
  fi
fi

echo


# Podman started to use OCI images by default. We still want Docker image format

if [ -z "$BUILDAH_FORMAT" ]; then
  BUILDAH_FORMAT=docker
fi

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_start
fi

CURRENT_DIR=$(pwd)

if [ "$INSTALL_DOMINO_NATIVE" = "yes" ]; then
  install_domino_native
  print_runtime
  exit 0
fi

docker_build

cd "$CURRENT_DIR"

if [ "$SOFTWARE_USE_NGINX" = "1" ]; then
  nginx_stop
fi

print_runtime

exit 0

