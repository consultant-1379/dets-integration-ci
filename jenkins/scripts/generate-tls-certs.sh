#!/bin/bash

DOMAIN_NAME="$1"
TAGS="$2"
CA_CRT_PATH="$3"
CA_KEY_PATH="$4"

create_certificate_for () {   
    HOSTNAME="$1"
    crt="${HOSTNAME}.crt"
    csr="${HOSTNAME}.csr"
    key="${HOSTNAME}.key"
    openssl genrsa -out "$key"
    openssl req -new -key "$key" -out "$csr" -subj "/CN=${HOSTNAME}"
    openssl x509 -req -in "$csr" -out "$crt" -CA "$CA_CRT_PATH" -CAcreateserial -CAkey "$CA_KEY_PATH" -days 365
}

# always create certs for GAS and IAM
create_certificate_for iam${DOMAIN_NAME}
create_certificate_for gas${DOMAIN_NAME}
create_certificate_for la${DOMAIN_NAME}
for tag in $TAGS
do 
  create_certificate_for ${tag}${DOMAIN_NAME}
done 
