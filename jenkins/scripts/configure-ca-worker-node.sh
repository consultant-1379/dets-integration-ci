#!/bin/bash

CERTIFICATE_PATH=${1}
CERTIFICATE_NAME=${2}
KUBECONFIG_PATH=${3}
PUBLIC_DEPLOYMENT=${4}
CONTAINER_REGISTRY=${5}

if [ -z "${CERTIFICATE_PATH}" ] || [ -z "${CERTIFICATE_NAME}" ] || [ -z "${PUBLIC_DEPLOYMENT}" ] || [ -z "${KUBECONFIG_PATH}" ]; then
    echo "ERROR: Please check that the correct arguments were supplied"
    echo "INFO: Usage: ./configure-ca-worker-node.sh <CERTIFICATE_PATH> <CERTIFICATE_NAME> <KUBECONFIG_PATH> <PUBLIC_DEPLOYMENT> [ <CONTAINER_REGISTRY> ]"
    exit 1
fi

if [ "${PUBLIC_DEPLOYMENT}" = "true" ]; then
    if [ -z "${CONTAINER_REGISTRY}" ]; then
        echo "ERROR: For public deployments the <CONTAINER_REGISTRY> parameter (the ECR image registry name) must be provided"
        exit 1
    fi
    echo "INFO: Configuring worker node CA for public IDUNaaS deployment using container registry ${CONTAINER_REGISTRY}"
elif [ "${PUBLIC_DEPLOYMENT}" = "false" ]; then
    CONTAINER_REGISTRY=armdocker.rnd.ericsson.se
    echo "INFO: Configuring worker node CA for IDUNaaS deployment using container registry ${CONTAINER_REGISTRY}"
else
    echo "ERROR: The <PUBLIC_DEPLOYMENT> parameter must be either 'true' or 'false'"
    exit 1
fi

POD_IMAGE=${CONTAINER_REGISTRY}/dockerhub-ericsson-remote/alpine
CERTIFICATE_KEYREF=$(basename ${CERTIFICATE_PATH}) # Required to retrieve certificate in valueFrom.secretKeyRef.key within DaemonSet definition
echo "INFO: Using image ${POD_IMAGE} for idunaas-config-ca DaemonSet pods"
echo "INFO: Certificate will be dropped off to /etc/pki/ca-trust/source/anchors/${CERTIFICATE_NAME}.crt on all cluster worker nodes"

echo "INFO: Creating secret for certificate storage with below command"
echo "INFO: Command = kubectl create secret generic idunaas-config-ca --from-file=${CERTIFICATE_PATH} --kubeconfig=${KUBECONFIG_PATH} --namespace=kube-system"
kubectl create secret generic idunaas-config-ca --from-file=${CERTIFICATE_PATH} \
                                                --kubeconfig=${KUBECONFIG_PATH} \
                                                --namespace=kube-system

echo "INFO: Generating spec.yaml for DaemonSet creation"

cat > spec.yaml <<-EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: idunaas-config-ca
  namespace: kube-system
data:
  config.sh: |
    echo "\${TRUSTED_CERT}" > /etc/pki/ca-trust/source/anchors/${CERTIFICATE_NAME}.crt && update-ca-trust && systemctl restart containerd
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  namespace: kube-system
  name: idunaas-config-ca
  labels:
    app: idunaas-config-ca
spec:
  selector:
    matchLabels:
      app: idunaas-config-ca
  template:
    metadata:
      labels:
        app: idunaas-config-ca
    spec:
      hostPID: true
      hostNetwork: true
      initContainers:
      - name: nsenter-node
        command: ["nsenter"]
        args: ["--mount=/proc/1/ns/mnt", "--", "sh", "-c", "\$(CONFIG_CA)"]
        image: ${POD_IMAGE}
        env:
        - name: TRUSTED_CERT
          valueFrom:
            secretKeyRef:
              name: idunaas-config-ca
              key: ${CERTIFICATE_KEYREF}
        - name: CONFIG_CA
          valueFrom:
            configMapKeyRef:
              name: idunaas-config-ca
              key: config.sh
        securityContext:
          privileged: true
      containers:
      - name: sleep-node
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo INFO: Sleeping for 6 hours; sleep 6h; done"]
        image: ${POD_IMAGE}
EOF

echo "INFO: contents of spec.yaml:"; cat spec.yaml
echo "INFO: Creating required Kubernetes resources with below command"
echo "INFO: Command = kubectl apply -f spec.yaml --kubeconfig=${KUBECONFIG_PATH}"
kubectl apply -f spec.yaml --kubeconfig=${KUBECONFIG_PATH}
echo "INFO: Worker node CA configuration complete"
echo "INFO: configure-ca-worker-node.sh execution finished at $(date "+%D %T")"