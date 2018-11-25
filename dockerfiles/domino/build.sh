#!/bin/bash
#
############################################################################
# (C) Copyright IBM Corporation 2015, 2018                                 #
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
#
# usage:
# 	./build.sh <parameter>
#
#  parameter - URL which is used to download the Domino installation package from
#
# example:
#	./build-image.sh http://127.0.0.1/domino10
#

if [ "$1" = "" ] ; then
    echo "Usage:" 
    echo "  ./build.sh <DownloadFromURL>"
else
    echo "Building image : ibmcom/domino:10.0.0"
    docker build -t ibmcom/domino:10.0.0 -f Dockerfile-domino10-centos.txt . --build-arg DownloadFrom=$1
fi