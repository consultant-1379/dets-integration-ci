helm install docker-registry \
    --namespace container-registry \
    --set replicaCount=1 \
    --set persistence.enabled=true \
    --set persistence.size=100Gi \
    --set persistence.deleteEnabled=true \
    --set persistence.storageClass=network-block \
    --set persistence.existingClaim=docker-registry-pv-claim \
    --set secrets.htpasswd=$(cat ./htpasswd) \
    twuni/docker-registry \
    --version 2.2.2


kubectl create secret tls docker-registry-tls \
    --namespace container-registry \
    --key docker-registry.hall144.rnd.gic.ericsson.se.key \
    --cert docker-registry.hall144.rnd.gic.ericsson.se.crt