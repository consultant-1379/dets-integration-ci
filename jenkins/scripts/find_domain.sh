#!/bin/bash
CLUSTER=$1
DOMAINS_BOOKED=$(curl -s -H "Content-Type: application/x-www-form-urlencoded" "http://10.120.197.101:9099/api/v1/query?query=kube_configmap_annotations\{vpod=\"EIAP\",dc=\"ews0\",program=\"DETS\",cluster_id=\"${CLUSTER}\",namespace=\"bookings\",configmap=~\".*\"\}" | jq  -r .data.result[].metric.annotation_domain |grep -v null | sort | uniq)


if [ $(echo "$DOMAINS_BOOKED" | grep ".$CLUSTER-eiap.ews.gic.ericsson.se") ]
then
    echo ".$CLUSTER-eiap.ews.gic.ericsson.se"
    exit 0
fi

for i in {1..10}
do
    if [ $(echo "$DOMAINS_BOOKED" | grep ".$CLUSTER-x${i}.ews.gic.ericsson.se") ]
    then
        echo ".$CLUSTER-x${i}.ews.gic.ericsson.se"
        exit 0
    fi
done