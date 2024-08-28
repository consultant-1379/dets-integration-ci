#!/bin/bash

if [ $# -lt 1 ]; then
        echo "This script require kubeconfig file provided as first parameter"
        exit 1
fi

export KUBECONFIG=${1}
NAMESPACE=${2}
PROMETHEUS_VERSION=${3}

CLUSTER_NAME=$(kubectl config get-clusters | tail -1)

delete_ns()
{
	helm uninstall dets-monitoring  -n $NAMESPACE
	kubectl delete ns $NAMESPACE
	kubectl delete validatingwebhookconfiguration/dets-monitoring-kube-prome-admission -A
	kubectl delete mutatingwebhookconfiguration/dets-monitoring-kube-prome-admission -A
	kubectl delete svc -n kube-system dets-monitoring-kube-prome-kube-scheduler dets-monitoring-kube-prome-kube-etcd dets-monitoring-kube-prome-coredns
	kubectl delete crd prometheuses.monitoring.coreos.com prometheusrules.monitoring.coreos.com
}

install_dets-monitoring()
{
	cp $(dirname $0)/custom-vals/custom-vals-eiap.yml  custom-vals-eiap-cluster-name.yml
	sed -i "s/CLUSTER_REPLACE/${CLUSTER_NAME}/g" custom-vals-eiap-cluster-name.yml
	kubectl create ns $NAMESPACE
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update prometheus-community 
	helm install dets-monitoring  prometheus-community/kube-prometheus-stack -n $NAMESPACE -f custom-vals-eiap-cluster-name.yml --version $PROMETHEUS_VERSION
}

create_ingress()
{
	cat > promateusz.yaml << EOF

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
  generation: 1
  labels:
  name: promateusz
  namespace: $NAMESPACE
spec:
  ingressClassName: nginx
  rules:
  - host: dets-prom.$CLUSTER_NAME.rnd.gic.ericsson.se
    http:
      paths:
      - backend:
          service:
            name: dets-monitoring-kube-prome-prometheus
            port:
              number: 9090
        path: /
        pathType: Prefix
EOF

	kubectl apply -f promateusz.yaml
	echo "Waiting 20 sec for ingress setup"
	sleep 20
}

checks()
{
	INGRESS_CHECK=$(curl -kv http://dets-prom.$CLUSTER_NAME.rnd.gic.ericsson.se 2>&1 | grep "302 Found")

	if [[ $INGRESS_CHECK =~ "302 Found" ]]; then
		echo "Ingress OK - http://dets-prom.$CLUSTER_NAME.rnd.gic.ericsson.se"
	else
		echo "Ingress not OK"
		exit 1
	fi
}

checkout_monitoring()
{
	git clone ssh://lciadm100@gerrit.ericsson.se:29418/DETES/com.ericsson.de.stsoss/monitoring && scp -p -P 29418 lciadm100@gerrit.ericsson.se:hooks/commit-msg monitoring/.git/hooks/
}

update_ccd_json()
{
	local stat=0
	cd monitoring/CMS/prometheus/prometheus_config

	tac ccd-list.json | sed s/"\[$"/'    { "targets": [ "dets-prom.'$CLUSTER_NAME'.rnd.gic.ericsson.se" ], "labels":{"program" : "DETS", "dc" : "ews0", "vpod" : "EIAP", "cluster_id" : "'$CLUSTER_NAME'"} },\n\['/g | tac > ccd-list.json.tmp
	jq . ccd-list.json.tmp > /dev/null && stat=0 || { echo "wrong JSON format."; return 1; }
	mv ccd-list.json.tmp ccd-list.json

	return $stat
}

push_for_review()
{
	git add .
	git config --local user.email "lciadm100@ericsson.com"
	git config --local user.name "lciadm100"
	git commit -m "Lciadm100 add $CLUSTER_NAME"
	git push origin HEAD:refs/for/master
}

push_no_review()
{
	git add .
        git config --local user.email "lciadm100@ericsson.com"
        git config --local user.name "lciadm100"
        git commit -m "Lciadm100 add $CLUSTER_NAME"
        git push origin master
}

#BODY

DETS_NS=$(kubectl get ns | grep $NAMESPACE) #Check if NS exists

if [[ -z $DETS_NS ]]; then
        echo "Namespace doesn't exist. It will be created."
else
        echo "Namespace already present. Removing."
        delete_ns
fi

install_dets-monitoring
create_ingress
checks

checkout_monitoring

grep $CLUSTER_NAME monitoring/CMS/prometheus/prometheus_config/ccd-list.json >/dev/null &&
	{
		echo "Cluster already present in ccd-list.json. Update of repository not required."
	} ||
	{
		update_ccd_json && push_no_review || echo "Repo PUSH skipped"
	}
