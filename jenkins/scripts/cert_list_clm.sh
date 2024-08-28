#!/bin/bash
NAME=$1



generate_token(){
  TOKEN=$(curl --request POST --header "Content-Type: application/json" --url https://clm-api.ericsson.net/vedauth/authorize/certificate --data @certs/oauth.json --key certs/sts-oss-support.cba.clm.local.key --cert certs/sts-oss-support.cba.clm.local.pem | jq -r .access_token )
  echo $TOKEN
}


generate_token

curl --request GET --header "Authorization: Bearer $TOKEN"  --url 'https://clm-api.ericsson.net/vedsdk/certificates/?parentdnrecursive=%5cVED%5cPolicy&offset=100&limit=10000' --cacert certs/sts-oss-support.cba.clm.local.pem | jq -r  '.Certificates[].Name' | grep ${NAME} > ${NAME}_cert_list.txt
echo "=========================== CERTS LIST for ${NAME}"
cat ${NAME}_cert_list.txt