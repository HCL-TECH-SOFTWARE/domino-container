#!/bin/bash

docker run -ia \
    -h domino.acme.com \
    -p 80:80 -p 1352:1352 \
    -v notesdata:/local/notesdata \
    --name docker-domino \
    --env-file env_domino \
    ibmcom/domino:latest
