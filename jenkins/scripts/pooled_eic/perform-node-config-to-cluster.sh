#!/bin/bash

function usage {
    echo "INFO: [$(basename $0)] Usage:
    $0 --kubeconfig <kubeconfig> --ca-crt-path <path-to-CA.crt> [--max-pods 110]
Note:
    --max-pods: (Optional) Set the maximum number of pods allowed to run concurrently in each node.
                Any positive integer is a valid value, max-pods=110 will used if not given.
    "
}

while [ $# -gt 0 ]; do
    case "$1" in
        "--kubeconfig")
            shift
            KUBECONFIG_PATH="$1"
            ;;
        "--ca-crt-path")
            shift
            CERTIFICATE_PATH="$1"
            ;;
        "--max-pods")
            shift
            MAX_PODS="$1"
            ;;
        *)
            echo "[$(basename $0)] ERROR: Bad command line argument: '$1'"
            usage
            exit -1
        ;;
    esac
    shift
done
MAX_PODS=${MAX_PODS:-110}

echo "[$(basename $0)] Parameters from the command line:
    --kubeconfig    $KUBECONFIG_PATH
    --ca-crt-path   $CERTIFICATE_PATH
    --max-pods      $MAX_PODS
"

if [ -z "${CERTIFICATE_PATH}" ] || [ -z "${KUBECONFIG_PATH}" ]; then
    echo "ERROR: Please check that the correct arguments were supplied"
    usage
    exit 1
fi



CERTIFICATE_NAME=$(basename $CERTIFICATE_PATH)
CERTIFICATE_NAME=${CERTIFICATE_NAME:0:-4}
POD_IMAGE=armdocker.rnd.ericsson.se/dockerhub-ericsson-remote/alpine
KUBECTL="kubectl --kubeconfig=${KUBECONFIG_PATH} --namespace=kube-system"
CERTIFICATE_KEYREF=$(basename ${CERTIFICATE_PATH})

echo "==> Creation of Secret, ConfigMap and DeamonSet"

$KUBECTL create secret generic photon-config-ca --from-file=${CERTIFICATE_PATH}

echo "INFO: Contents of public CRT of the CA:"
$KUBECTL get secret photon-config-ca -o yaml

cat > spec.yaml <<-EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-config
data:
  config.sh: |
    echo "INFO: Deploying the photon CA"
    echo "\${TRUSTED_CERT}" > /usr/share/pki/trust/anchors/${CERTIFICATE_NAME}.crt
    update-ca-certificates
    systemctl restart containerd
    echo "INFO: Updating maxPods to ${MAX_PODS}"
    cp /var/lib/kubelet/config.yaml /var/lib/kubelet/config.backup.yaml
    sed -i 's/^maxPods: [0-9]*/maxPods: ${MAX_PODS}/' /var/lib/kubelet/config.yaml
    systemctl restart kubelet
    echo "INFO: Node Configuration Completed"
    sync    # This prevent the logs of the container to miss messages
    sleep 2
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-config
  labels:
    app: node-config
spec:
  selector:
    matchLabels:
      app: node-config
  template:
    metadata:
      labels:
        app: node-config
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
              name: photon-config-ca
              key: ${CERTIFICATE_KEYREF}
        - name: CONFIG_CA
          valueFrom:
            configMapKeyRef:
              name: node-config
              key: config.sh
        securityContext:
          privileged: true
      containers:
      - name: sleep-node
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo INFO: Sleeping for 6 hours; sleep 6h; done"]
        image: ${POD_IMAGE}
EOF

echo "INFO: Contents of DeamonSet definition:"; cat spec.yaml
$KUBECTL apply -f spec.yaml

echo "INFO: Waiting for daemonset to be executed correctly"
MAX_RETRY=12
for i in $(seq 0 $MAX_RETRY); do
    sleep 10
    DAEMONSET=$($KUBECTL get daemonset node-config | tail -n 1)
    DESIRED=$(echo $DAEMONSET | awk '{print $2}')
    CURRENT=$(echo $DAEMONSET | awk '{print $3}')
    READY=$(echo $DAEMONSET | awk '{print $4}')
    UP_TO_DATE=$(echo $DAEMONSET | awk '{print $5}')
    AVAILABLE=$(echo $DAEMONSET | awk '{print $6}')
    NUM=$($KUBECTL logs -l app=node-config -c nsenter-node | grep -F "INFO: Node Configuration Completed" | wc -l)
    echo "INFO: DESIRED=$DESIRED CURRENT=$CURRENT READY=$READY UP_TO_DATE=$UP_TO_DATE NUM=$NUM (attempt ${i}/${MAX_RETRY})"
    if [ "$DESIRED" != "0" ] \
        && [ "$DESIRED" == "$NUM" ]    \
        && [ "$DESIRED" == "$CURRENT" ]    \
        && [ "$DESIRED" == "$READY" ]      \
        && [ "$DESIRED" == "$UP_TO_DATE" ] \
        && [ "$DESIRED" == "$AVAILABLE" ]; then
            echo "INFO: Worker node CA configuration & max pods changed to ${MAX_PODS} completed"
            break
    fi
    if [ $i -eq $MAX_RETRY ]; then
        echo "ERROR: MAX_RETRY reached before daemonset was ready"
        exit -2
    fi
    echo "INFO: waiting 10 seconds before checking the status again"
done


echo "==> Init Container logs"
$KUBECTL logs -l app=node-config -c nsenter-node


echo "==> Check Max Number of Pods per node"
$KUBECTL get nodes -o jsonpath='{.items[*].status.capacity.pods}'
echo ""     # new line to fix the output

echo "==> Delete DeamonSet"
$KUBECTL delete -f spec.yaml
$KUBECTL delete secret photon-config-ca
