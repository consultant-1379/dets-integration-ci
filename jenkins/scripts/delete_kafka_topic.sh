#!/bin/bash

NAMESPACE=$1
KUBE_CONFIG_PATH=$2
CASSANDRA_USER=$3
CASSANDRA_PASSWORD=$4


function applyworkaround()
{
    declare -i key_counter=1
    check_empty_topic
    while [  ${key_counter} -le 3 ]; do
        ((key_counter++))
        if [[ -n ${check_empty_key} ]]; then
            echo "Keys are not empty, continuing to apply workaround"
            break
        fi
        echo "Waiting for Kafka keys to be populated"
        sleep 1m
        check_empty_topic
    done
    if [[ -z ${check_empty_key} ]]; then
        echo "Kafka keys are empty! Exiting..."
        exit 1
    fi
    get_cassandra_key
    get_kafka_topic $key_cassandra
    if [[ ${keys_topic} -ge 2 ]]; then
       echo "Matching key in Kafka and DB, no action required."
       exit 0
    fi
    echo "Applying workaround"
    delete_db_row
    restart_pods
    delete_kafka_topic SDC-DISTR-NOTIF-TOPIC-AUTO
    delete_kafka_topic SDC-DISTR-STATUS-TOPIC-AUTO
}

function check_empty_topic()
{
    echo "Checking for the empty keys in Kafka topics.."
    kubectl --kubeconfig "${KUBE_CONFIG_PATH}" exec -t  eric-data-message-bus-kf-0 -n "${NAMESPACE}" -- \
    curl http://eric-oss-dmaap:3904/topics/listAll > topics.json
    if [[ -s topics.json ]]; then
        check_empty_key=$(jq -r '.topics[] | select(.topicName | startswith("SDC-DISTR-")) | .owner' topics.json)
    fi
}

function get_cassandra_key() {
    echo "Checking the kafka key stored in Cassandra DB..."
    kubectl --kubeconfig "${KUBE_CONFIG_PATH}" exec -t eric-data-wide-column-database-cd-0 -c cassandra -n "${NAMESPACE}" -- \
    cqlsh --no-color -k sdcrepository -e "select * from operationalenvironment" -u ${CASSANDRA_USER} -p ${CASSANDRA_PASSWORD} >key_cassandra.out
    if [[ -s key_cassandra.out ]]; then
        key_cassandra=$(cat key_cassandra.out|awk -F"|" '{print $8}'|grep -v ^$|grep -v ueb_api_key|tr -d ' ')
    fi
}

function get_kafka_topic(){
    echo "Checking the keys used by Kafka topics.."
    key=$1
    kubectl --kubeconfig "${KUBE_CONFIG_PATH}" exec -t  eric-data-message-bus-kf-0 -n "${NAMESPACE}" -- \
    curl http://eric-oss-dmaap:3904/topics/listAll >topics.json
    if [[ -s topics.json ]]; then
        keys_topic=$(jq -r '.topics[] | select(.topicName | startswith("SDC-DISTR-")) | .owner' topics.json | grep -w ${key} | wc -l)
    fi
}

function delete_db_row() {
    echo "Deleting the row in Cassandra DB"
    kubectl --kubeconfig "${KUBE_CONFIG_PATH}" exec -t eric-data-wide-column-database-cd-0 -c cassandra -n "${NAMESPACE}" -- \
    cqlsh --no-color -k sdcrepository -e "delete from operationalenvironment where environment_id = 'AUTO'" -u ${CASSANDRA_USER} -p ${CASSANDRA_PASSWORD}
    if [[ $? -eq 0 ]]; then
      echo "Successfully deleted the row"
    else
      echo "Failed to delete the row"
      exit 1
    fi
}

function delete_kafka_topic()
{
    topic=$1
    echo "Deleting kafka topic ${topic} as it is not using the key stored in DB"
    kubectl --kubeconfig "${KUBE_CONFIG_PATH}" exec -t  eric-data-message-bus-kf-0 -n "${NAMESPACE}" -- \
    kafka-topics --delete --bootstrap-server eric-data-message-bus-kf-client:9092 --topic "${topic}"
    if [[ $? -eq 0 ]]; then
        echo "Successfully deleted the topic ${topic}"
    else
        echo "Failed to delete the topic ${topic}"
        exit 1
    fi
}

function restart_pods()
{
    UDSPOD=$(kubectl --kubeconfig "${KUBE_CONFIG_PATH}" -n "${NAMESPACE}" get  pod -o=name| grep -Ei "uds-service" | grep -Eiv "uds-service-config")
    echo -e "Restarting ${UDSPOD} \n"
    kubectl --kubeconfig "${KUBE_CONFIG_PATH}" -n "${NAMESPACE}" delete "${UDSPOD}"
    EOPOD=$(kubectl --kubeconfig "${KUBE_CONFIG_PATH}" -n "${NAMESPACE}" get  pod -o=name| grep -Ei "eric-eo-onboarding")
    echo -e "Restarting ${EOPOD} \n"
    kubectl --kubeconfig "${KUBE_CONFIG_PATH}" -n "${NAMESPACE}" delete "${EOPOD}"
}
# Main


function main()
{
   declare -i count=1
   get_cassandra_key
   if [[ -z ${key_cassandra} ]]; then
       echo "Cassandra key is empty"
       exit 1
   fi

   while [ ${count} -le 3 ]; do
       ((count++))
       get_kafka_topic $key_cassandra

       if [[ ${keys_topic} -ge 2 ]]; then
           echo "Matching key in Kafka and DB, no action required."
           exit 0
       else
           echo "Mismatch key in Kafka and DB, applying workaround"
           applyworkaround
       fi
   done
   echo "Failed"
   exit 1
}

main
