#!/bin/bash
echo "docker volume create dominodata_demo1"
docker volume create dominodata_demo1
echo "Starting container"
echo 'docker run -it -e "ServerName=Think2019-demo1" \
    -e "OrganizationName=DEMO" \
    -e "AdminFirstName=Thomas" \
    -e "AdminLastName=Hampel" \
    -e "AdminPassword=passw0rd" \
    -p 80:80 \
    -p 1352:1352 \
    -h think.demo.com \
    -v dominodata_demo1:/local/notesdata-pod \
    --name think \  
    ibmcom/domino:10.0.1'
# countdown...
secs=$((10))
while [ $secs -gt 0 ]; do
   echo -ne " Starting in : $secs\033[0K\r"
   sleep 1
   : $((secs--))
done
docker run -it -e "ServerName=Think2019-demo1" \
    -e "OrganizationName=DEMO" \
    -e "AdminFirstName=Thomas" \
    -e "AdminLastName=Hampel" \
    -e "AdminPassword=passw0rd" \
    -h think.demo.com \
    -p 80:80 \
    -p 1352:1352 \
    -v dominodata_demo1:/local/notesdata-pod \
    --name think-demo1 \
    ibmcom/domino:10.0.1