#!/bin/bash
# After creation put under com.ericsson.idunaas.ci/deployments/<NEW_ENV_NAME>/workdir/certificates

function usage {
    echo "[$(basename $0)] Usage:
    $0 --dns-domain <domain name> \
 [--folder <folder to use for req, csr, key>]\
 [--app-list <app list>]\
 [--ca-key <ca_key>]\
 [--ca-crt <ca_crt>]
Default values:
    --folder: current forlder
    --app-list: adc,appmgr,bdr,bootstrap,ch,eas,gas,iam,la,ml,os,th,eic,rapp
    --ca-key, --ca-crt: the CRT will not be generated if this is empty

Example for adc.139502265861.eu-west-1.ac.ericsson.se and gas.139502265861.eu-west-1.ac.ericsson.se:
    $0 --dns-domain 139502265861.eu-west-1.ac.ericsson.se --folder . --app-list adc,gas
    "
}

APPS_ENABLED=adc,appmgr,bdr,bootstrap,ch,eas,gas,iam,la,ml,os,th,eic
CERTS_DIR=.

while [ $# -gt 0 ]; do
    case "$1" in
        "--dns-domain")
            shift
            DNS_DOMAIN="$1"
            ;;
        "--folder")
            shift
            CERTS_DIR="$1"
            ;;
        "--app-list")
            shift
            APPS_ENABLED="$1"
            ;;
        "--ca-key")
            shift
            CA_KEY="$1"
            ;;
        "--ca-crt")
            shift
            CA_CRT="$1"
            ;;
        *)
            echo "[$(basename $0)] ERROR: Bad command line argument: '$1'"
            usage
            exit -1
        ;;
    esac
    shift
done

echo "[$(basename $0)] Parameters from the command line:
    --dns-domain $DNS_DOMAIN
    --folder $CERTS_DIR
    --app-list $APPS_ENABLED
    --ca-key $CA_KEY
    --ca-crt $CA_CRT
"

test -z "$DNS_DOMAIN" -o -z "$CERTS_DIR" \
    && echo "Error: at least one parameter is empty" \
    && usage \
    && exit -2

test ! -d "$CERTS_DIR" -a ! -d "$(realpath $CERTS_DIR)" \
    && echo "Error: $CERTS_DIR is not a directory" \
    && usage \
    && exit -3

if [ -n "$CA_CRT" ]; then
    [ -z "$CA_KEY" ]   && echo "Error: CA_KEY is empty, please provide the parameter --ca-key" && exit -5
    [ ! -e "$CA_CRT" ] && echo "Error: '$CA_CRT' does not exist"                               && exit -5
    [ ! -e "$CA_KEY" ] && echo "Error: '$CA_KEY' does not exist"                               && exit -5
    CA_CRT=$(realpath "$CA_CRT")
    CA_KEY=$(realpath "$CA_KEY")
fi

cd $CERTS_DIR || exit -4

[ -n "$CA_CRT" ] && cp "$CA_CRT" "intermediate-ca.crt"

cat <<"EOF" > certs.req.tmpl
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
C = SE
ST = Stockholm
L = Stockholm
O = Ericsson AB
OU = IT
CN = SEDME:CN
[v3_req]
keyUsage = nonRepudiation, digitalSignature, keyEncipherment,dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = SEDME:CN
EOF

for i in $(echo $APPS_ENABLED | tr , ' '); do
    FQDN="$i.$DNS_DOMAIN"
    sed 's/SEDME:CN/'${FQDN}'/g' certs.req.tmpl > ${FQDN}.req
    if [ "$i" == "bootstrap" ]; then
        echo "DNS.2 = broker*.$DNS_DOMAIN" >> ${FQDN}.req
    fi
    openssl req -new -newkey rsa:2048 -nodes -out ${FQDN}.csr -keyout ${FQDN}.key -config ${FQDN}.req -extensions v3_req
    if [ -n "$CA_CRT" ]; then
        openssl x509 -req -in ${FQDN}.csr -out ${FQDN}.crt -CA "$CA_CRT" -CAcreateserial -CAkey "$CA_KEY" -days 365 -extfile ${FQDN}.req -extensions v3_req
    fi
done
rm certs.req.tmpl
