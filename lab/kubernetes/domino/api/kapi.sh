
NAMESPACE=default
SERVICE_ACCOUNT=domino-admin

APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
SECRET_NAME=$(kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE -o jsonpath='{.secrets[0].name}')
TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)

echo
echo "------------------------------------------------------------------------------------------"
curl -k -s $APISERVER/api --header "Authorization: Bearer $TOKEN"
echo
echo "------------------------------------------------------------------------------------------"
echo


curl -k -s --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/$NAMESPACE/pods/domino12 > api_domino12.txt

curl -k -s --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/$NAMESPACE/persistentvolumeclaims > api_pvc.txt

curl -k -s -H "Authorization: Bearer ${TOKEN}" -H 'Accept: application/json' -H 'Content-Type: application/json' -X POST ${APISERVER}/api/v1/namespaces/$NAMESPACE/persistentvolumeclaims -d @pvc.json > api_pvc_create.txt


