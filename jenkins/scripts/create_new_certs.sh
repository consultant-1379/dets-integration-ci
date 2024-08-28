#!/bin/bash

[ -z "$1" ] && echo "Usage: $0 <certificates folder>" && exit -1
[ ! -d "$1" ]  && echo "Error: Folder $1 does not exist" && exit -2
[ ! -f "$1/intermediate-ca.crt" ] && echo "Folder $1 is not a certificate folder" && exit -3

cd $1

[ "$2" == "--with-enm" ] && mkdir -p enm-http-client
mkdir -p iam-http-server
mkdir -p iam-ldap-server
mkdir -p la-syslog-client
mkdir -p la-http-server
mkdir -p la-http-client
mkdir -p eric-log-client-certs-cacert
mkdir -p sef-osm-http-client
mkdir -p sef-osm-iam-client
mkdir -p bootstrap-http-server
mkdir -p minio-http-server
mkdir -p eic-http-server

#Copy Intermediate CA

[ "$2" == "--with-enm" ] && cp intermediate-ca.crt enm-http-client/enm-http-client.crt
cp intermediate-ca.crt iam-http-server/iam-http-server.crt
cp intermediate-ca.crt iam-ldap-server/iam-ldap-server.crt
cp intermediate-ca.crt la-syslog-client/la-syslog-client.crt
cp intermediate-ca.crt la-http-server/la-http-server.crt
cp intermediate-ca.crt la-http-client/la-http-client.crt
cp intermediate-ca.crt eric-log-client-certs-cacert/eric-log-client-certs-cacert.crt
cp intermediate-ca.crt sef-osm-http-client/sef-osm-http-client.crt
cp intermediate-ca.crt sef-osm-iam-client/sef-osm-iam-client.crt
cp intermediate-ca.crt bootstrap-http-server/bootstrap-http-server.crt
cp intermediate-ca.crt minio-http-server/minio-http-server.crt
cp intermediate-ca.crt eic-http-server/eic-http-server.crt

#Copy certificates

cp th.*crt th-http-server.crt
cp th.*key th-http-server.key

cp iam.*crt iam-http-server.crt
cp iam.*key iam-http-server.key

cp la.*crt la-http-server.crt
cp la.*key la-http-server.key

cp gas.*crt gas-http-server.crt
cp gas.*key gas-http-server.key

cp adc.*crt ves-http-server.crt
cp adc.*key ves-http-server.key

cp appmgr.*crt appmgr-http-server.crt
cp appmgr.*key appmgr-http-server.key

cp bdr.*crt minio-http-server.crt
cp bdr.*key minio-http-server.key

cp bootstrap.*crt bootstrap-http-server.crt
cp bootstrap.*key bootstrap-http-server.key

cp eic.*crt eic-http-server.crt
cp eic.*key eic-http-server.key

cp gas-http-server.crt eric-log-client-certs.crt
cp gas-http-server.key eric-log-client-certs.key

cp gas-http-server.crt sef-osm-http-client.crt
cp gas-http-server.key sef-osm-http-client.key

cp iam-http-server.crt sef-osm-iam-client.crt
cp iam-http-server.key sef-osm-iam-client.key
