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

# Domino Docker Build Script
# Usage  : .\build.ps1 <URL for download repository>
# Example: .\build.ps1 http://192.168.1.1

$ScriptName = $MyInvocation.MyCommand.Name
$global:DownloadFrom = $args[0]

$DockerImageName = 'ibmcom/domino'
$DockerImageVersion = '10.0.1'
$DockerFile = 'dockerfile_domino.txt'

$DominoBasePackage = 'domino10/DOM_SVR_V10.0.1_64_BIT_Lnx.tar'

function ShowUsage {
    Write-Output "Usage: $ScriptName { domino }"
}

Function DockerBuild () {
    # Get build arguments
    $DockerImage = "${DockerImageName}:${DockerImageVersion}"
    
    Write-Output "Building Image: $DockerImage"

    # Build the image
    Push-Location
    Set-Location $PSScriptRoot
    docker build -t ${DockerImageName}:${DockerImageVersion} -f $DockerFile --build-arg DownloadFrom=$global:DownloadFrom --build-arg DominoBasePackage=$DominoBasePackage .
    Pop-Location
}

if ($DownloadFrom -eq "") {
    Write-Output "No download location specified!"
    ShowUsage
    exit
}

DockerBuild