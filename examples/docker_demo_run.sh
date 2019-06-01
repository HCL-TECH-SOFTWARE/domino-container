#!/bin/bash

docker run -d -it \
    -h demo.acme.com \
    -p 80:80 -p 1352:1352 \
    -v demo-notesdata:/local/notesdata \
    --name demo-docker-domino \
    --env-file env_domino \
    ibmcom/domino:latest
