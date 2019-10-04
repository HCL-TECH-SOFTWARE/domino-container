############################################################################
# (C) Copyright IBM Corporation 2015, 2019                                 #
#                                                                          #
# Licensed under the Apache License, Version 2.0 (the "License");          #
# you may not use this file except in compliance with the License.         #
# You may obtain a copy of the License at                                  #
#                                                                          #
#      http://www.apache.org/licenses/LICENSE-2.0                          #
#                                                                          #
# Unless required by applicable law or agreed to in writing, software      #
# distributed under the License is distributed on an "AS IS" BASIS,        #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. #
# See the License for the specific language governing permissions and      #
# limitations under the License.                                           #
#                                                                          #
############################################################################
  
FROM centos:7

# Headers
LABEL DominoDocker.maintainer="thomas.hampel@de.ibm.com, daniel.nashed@nashcom.de"

# External arguments with a default value
ARG LinuxYumUpdate=
ARG DownloadFrom=
ARG PROD_NAME=
ARG PROD_VER=
ARG PROD_FP=
ARG PROD_HF=
ARG DominoResponseFile=
ARG DominoMoveInstallData=
ARG LocalInstallDir=/tmp/install
ARG DominoUserID=
ARG DOMINO_LANG=
ARG DOCKER_TZ

USER root

# Copy Install Files to container
COPY install_dir $LocalInstallDir

# Prepare environment for Domino
# Update, Install required packages and run separate install script

RUN yum install -y openssl bc perl which wget nano unzip rsync lsof gdb sysstat file && \
  $LocalInstallDir/install_domino.sh && \
  yum clean all >/dev/null && \
  rm -fr /var/cache/yum && \
  rm -rf $LocalInstallDir

HEALTHCHECK --interval=60s --timeout=10s CMD /domino_docker_healthcheck.sh

# Expose Ports NRPC HTTP POP3 IMAP LDAP HTTPS LDAPS IMAPS POP3S DIIOP DIIOPS
EXPOSE 1352 80 110 143 389 443 636 993 995 63148 63149

ENTRYPOINT ["/domino_docker_entrypoint.sh"]

USER notes

