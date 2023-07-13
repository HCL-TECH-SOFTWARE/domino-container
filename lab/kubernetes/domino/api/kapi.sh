#!/bin/bash

CURL_OPTIONS=-ks

if [ -z "$NAMESPACE" ]; then
  NAMESPACE=default
fi

if [ -z "$SERVICE_ACCOUNT" ]; then
  SERVICE_ACCOUNT=domino-admin
fi

if [ -z "$APISERVER" ]; then
  APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
fi

if [ -z "$TOKEN" ]; then
  TOKEN=$(cat $SERVICE_ACCOUNT.jwt)
fi

echo "API Server: $APISERVER"

echo
echo "------------------------------------------------------------------------------------------"
curl $CURL_OPTIONS $APISERVER/api --header "Authorization: Bearer $TOKEN"
echo
echo "------------------------------------------------------------------------------------------"
echo

curl $CURL_OPTIONS --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/$NAMESPACE/pods/domino12 > api_domino12.log

curl $CURL_OPTIONS --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/$NAMESPACE/persistentvolumeclaims > api_pvc.log

curl "$CURL_OPTIONS" -H "Authorization: Bearer ${TOKEN}" -H 'Accept: application/json' -H 'Content-Type: application/json' -X POST ${APISERVER}/api/v1/namespaces/$NAMESPACE/persistentvolumeclaims -d @pvc.json > api_pvc_create.log

