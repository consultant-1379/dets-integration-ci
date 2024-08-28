#!/bin/bash
TAGS="$1"
DOMAIN_NAME="$2"
WORKDIR="$3"

generate_token(){
  TOKEN=$(curl --request POST --header "Content-Type: application/json" --url https://clm-api.ericsson.net/vedauth/authorize/certificate --data @${WORKDIR}/certs/oauth.json --key ${WORKDIR}/certs/sts-oss-support.cba.clm.local.key --cert ${WORKDIR}/certs/sts-oss-support.cba.clm.local.pem | jq -r .access_token )
  echo $TOKEN
}

delete_certifcate(){
  NAME=$1
  echo "================== DELETING $NAME ================== "
  guid=$(curl --request GET --header "Authorization: Bearer $TOKEN" --url https://clm-api.ericsson.net/vedsdk/certificates/?name=$NAME --cacert ../certs/sts-oss-support.cba.clm.local.pem | jq -r  '.Certificates[].Guid')
  if [ -z "$guid" ]; then
    echo "certifcate $NAME not present in CLM"
  else
    echo "Cert $CERT_HOSTNAME guid =  $guid"
    curl --request DELETE --header "Authorization: Bearer $TOKEN" --header "Content-Type: application/json" https://clm-api.ericsson.net/vedsdk/certificates/${guid}
  fi
}
       


#MAIN
generate_token

for tag in $TAGS
do 
    delete_certifcate ${tag}${DOMAIN_NAME} 
done 
