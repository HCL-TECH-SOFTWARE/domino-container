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

# Main Script to build images. This is script also hosts the software repository locally by default
# Usage  : .\build.ps1 <parameter>
# Example: .\build.ps1 domino

$ScriptName = $MyInvocation.MyCommand.Name
$TargetImage = $args[0]

$global:DownloadFrom = ''
# (Default) NIGX is used for hosting software from the local "software" directory.
# (Optional) Configure software download location.
# $DownloadFrom='http://192.168.1.1'

$global:SoftwareDir = ''
# With NGINX container you could chose your own local directory or if the variable is empty use the default "software" subdirectory 
# $SoftwareDir='c:\local\software'

$SoftwarePort = 7777
$SoftwareContainer = 'ibmsoftware'
$UseNGINX = 1
function ShowUsage {
    Write-Output "Usage: $ScriptName { domino }"
}

# Create a nginx container hosting software download locally
function StartNGINX () {    
    $Status="$(docker inspect --format '{{ .State.Status }}' $SoftwareContainer)"

    # Check if the container has a status of "exited"
    if ($Status -eq "") {
        Write-Output "Creating Docker container: $SoftwareContainer hosting [$global:SoftwareDir]"
        docker run --name ${SoftwareContainer} -p ${SoftwarePort}:80 -v ${global:SoftwareDir}:/usr/share/nginx/html:ro -d nginx
    } elseif ($Status -eq "exited") {
        Write-Output "Starting existing Docker container: $SoftwareContainer"
        docker start $SoftwareContainer
    }

    Write-Output "Starting Docker container: $SoftwareContainer"

    # Start local nginx container to host SW Repository
    $SoftwareRepoIP = "$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $SoftwareContainer)"
    if ($SoftwarRepoIP -eq "") {
        Write-Output "Unable to locate software repository."
    } else {
        $global:DownloadFrom = "http://$SoftwareRepoIP"
        Write-Output "Hosting IBM Software repository on $global:DownloadFrom"
    }
}

function StopNGINX () {
  # Stop and remove SW repository
  docker stop $SoftwareContainer
  docker container rm $SoftwareContainer
  Write-Output "Stopped & Removed Software Repository Container"
}

if (!$TargetImage) {
    Write-Output "No Taget Image specified! - Terminating"
    ShowUsage
    exit
}

if ($DownloadFrom -eq '') {
    $UseNGINX = 1
  
    if ($global:SoftwareDir -eq '') {
        $global:SoftwareDir = "$PSScriptRoot\software"
    }
}

$BuildScript="dockerfiles\$TargetImage\build_$TargetImage.ps1"

if (-not(Test-Path $BuildScript)) {
    Write-Output "Cannot execute build script for [$TargetImage] -- Terminating [$BuildScript]"
    exit
}

if ($UseNGINX -eq 1) {
    StartNGINX
}

& $BuildScript $global:DownloadFrom

Write-Output "Download from: $global:DownloadFrom"

if ($UseNGINX -eq 1) {
    StopNGINX
}