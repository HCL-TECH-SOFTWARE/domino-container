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
  
FROM ibmcom/domino:latest

# Headers
LABEL DominoDocker.maintainer="thomas.hampel@de.ibm.com, daniel.nashed@nashcom.de, pwithers@intec.co.uk"

# External arguments with a default value
ARG DownloadFrom=http://172.17.0.3
ARG PROD_NAME=
ARG PROD_VER=
ARG PROD_FP=
ARG PROD_HF=
ARG DominoResponseFile=domino10_response.dat
ARG DominoMoveInstallData=
ARG LocalInstallDir=/tmp/install
ARG DominoUserID=
ARG DOMINO_LANG=

ARG NUI_NOTESDIR=/opt/ibm/domino/notes/latest/linux
    
COPY ${LocalInstallDir}/DOMINO_APPDEV_PACK_1.0.1_MP_EN.tgz ${NUI_NOTESDIR}

USER root
RUN yum install -y epel-release && \
	yum install -y nodejs npm && \
	yum install -y mod_ssl

RUN cd ${NUI_NOTESDIR} && \
	tar -xvzf ${NUI_NOTESDIR}/DOMINO_APPDEV_PACK_1.0.1_MP_EN.tgz && \
	cd /opt/ibm/domino/notes/latest/linux && \
	ls -la libnotes.so && \
	tar -xf ${NUI_NOTESDIR}/DOMINO_APPDEV_PACK_1.0.1_MP_EN/DOMINO_APPDEV_PACK_1.0.1_MP_EN/proton-addin-0.3.1.tgz && \
	tar -xf ${NUI_NOTESDIR}/DOMINO_APPDEV_PACK_1.0.1_MP_EN/DOMINO_APPDEV_PACK_1.0.1_MP_EN/oauth-dsapi-0.3.1.tgz && \
	tar -xf ${NUI_NOTESDIR}/DOMINO_APPDEV_PACK_1.0.1_MP_EN/DOMINO_APPDEV_PACK_1.0.1_MP_EN/domino-iam-service-1.1.4.tgz && \
	/bin/bash -c "sh -v ./setup_proton.sh" && \
	/bin/bash -c "sh -x ./setup_dsapi.sh"

# Expose Ports NRPC HTTP POP3 IMAP LDAP HTTPS LDAPS IMAPS POP3S DIIOP DIIOPS PROTON
EXPOSE 1352 80 110 143 389 443 636 993 995 63148 63149 3002