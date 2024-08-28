#!/bin/bash

# If you want to check one of the following conditions:
# - KEY and CSR have been generated together
# - KEY and CRT can be used together in a web server
# - the CSR is the one used to generate the CRT
# please run this script and compare the printed values (they should be equals).
# Moreover this script print the expiration date of the CRT.

#[ -z "$1" ] && echo "Usage: $0 <crt> [<key>] [<csr>]" && exit -1
[ -z "$1" ] && echo "Usage: $0 <folder_containing_certificates>" && exit -1

cd $1
ls | grep -q intermediate-ca.crt
[ $? -ne 0 ] && echo "Error: intermediate-ca.crt not found in folder '$1'" && exit -1

EXIT_CODE=0
for CRT in $(ls *.crt | grep -v intermediate-ca.crt); do

    KEY=$(echo $CRT | sed 's/crt$/key/')
    [ ! -f "$KEY" ] && echo "Error: key not found: $KEY" && EXIT_CODE=-1
    MOD_CRT=$(openssl x509 -noout -modulus -in $CRT)
    MOD_KEY=$(openssl rsa  -noout -modulus -in $KEY)
    [ "$MOD_KEY" != "$MOD_CRT" ] && echo "Error: key and crt does not match: $KEY $CRT" && EXIT_CODE=-1

    CSR=$(echo $CRT | sed 's/crt$/csr/')
    if [ -f "$CSR" ]; then
        MOD_CSR=$(openssl req  -noout -modulus -in $CSR)
        [ "$MOD_CSR" != "$MOD_CRT" ] && echo "Error: csr and crt does not match: $CSR $CRT" && EXIT_CODE=-1
    fi

    openssl verify -CAfile intermediate-ca.crt $CRT 2>/dev/null \
        | grep -q -F 'certificate has expired'
    if [ ${PIPESTATUS[0]} -ne 0 -o ${PIPESTATUS[1]} -eq 0 ]; then
        openssl x509 -noout -text -in $CRT \
            | grep -F -e 'Not After' \
            | sed 's/Not After/Certificate valid until/'
        echo "Error: validation of CRT failed: $CRT"
        EXIT_CODE=-1
    fi

done

[ $EXIT_CODE -eq 0 ] && echo "HTTPS Certificates validation in folder '$1': SUCCESS"
exit $EXIT_CODE
