#!/bin/sh

KUBE_CONFIG=$1

function validate_kube_connectivity()
{
  output=$(kubectl get ns --kubeconfig "${KUBE_CONFIG}"  2>&1)
  if [[ $? != 0 ]]; then
    echo 'AWS credentials are invalid. Error connecting to EKS cluster' >&2
    exit 1
  fi
  echo 'EKS connectivity exists'
}

validate_kube_connectivity
