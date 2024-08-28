#!/bin/bash
REQ_CPU=$1
REQ_RAM=$2
CPU_TRESHOLD=$3
RAM_TRESHOLD=$4

CPU_OK_LIST=$(curl -s -H "Content-Type: application/x-www-form-urlencoded" "http://10.120.197.101:9099/api/v1/query?query=sum(kube_node_status_allocatable\{vpod=\"EIAP\",dc=\"ews0\",program=\"DETS\",resource=\"cpu\"\})by(cluster_id)-sum(kube_pod_container_resource_requests\{vpod=\"EIAP\",dc=\"ews0\",program=\"DETS\",resource=\"cpu\"\})by(cluster_id)-${REQ_CPU}>${CPU_TRESHOLD}" | jq  -r .data.result[].metric.cluster_id)
RAM_OK_LIST=$(curl -s -H "Content-Type: application/x-www-form-urlencoded" "http://10.120.197.101:9099/api/v1/query?query=sum(kube_node_status_allocatable\{vpod=\"EIAP\",dc=\"ews0\",program=\"DETS\",resource=\"memory\"\})by(cluster_id)-sum(kube_pod_container_resource_requests\{vpod=\"EIAP\",dc=\"ews0\",program=\"DETS\",resource=\"memory\"\})by(cluster_id)-${REQ_RAM}>${RAM_TRESHOLD}" | jq  -r .data.result[].metric.cluster_id)

echo "$CPU_OK_LIST" | sort > cpu.txt
echo "$RAM_OK_LIST" | sort > ram.txt

comm -12 cpu.txt ram.txt | head -1