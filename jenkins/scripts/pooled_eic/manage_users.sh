#!/bin/bash

function usage {
    echo "Usage:"
    echo -n "$0 --kubeconfig <kubeconfig file> "
    echo -n "--action <ADD-NAMESPACE-USERS || DEL-NAMESPACE-USERS || ANONATE-NAMESPACE-USERS || "
    echo -n "ADD-CLUSTER-ADMINS || DEL-CLUSTER-ADMINS || ANONATE-CLUSTER-ADMINS> "
    echo    "--users <Eg: 'zshicna,zlaigar,zmcddec'> --namespace <eic namespace>"
}

# extract parameters:
while [ $# -gt 0 ]; do
    case "$1" in
        "--action")
            shift
            ACTION="$1"
        ;;
        "--users")
            shift
            USERS="$1"
        ;;
        "--namespace")
            shift
            NAMESPACE="$1"
        ;;
        "--kubeconfig")
            shift
            KUBECONFIG="$1"
        ;;
        *)
            echo "[$(basename $0)] ERROR: Bad command line argument '$1'"
            usage
            exit -1
        ;;
    esac
    shift
done

SCRIPT_DIR=$(dirname $(realpath $0))
CLUSTER=$(echo $NAMESPACE | cut -d '-' -f 1)
IFS=',' read -r -a userarr <<< $USERS

function main {
    echo $ACTION | grep -q -F NAMESPACE-USERS
    local IS_USER_OPERATION=$?
    [ -z "$NAMESPACE" ] && [ $IS_USER_OPERATION -eq 0 ] && { echo "Error: namesapce is empty"; usage; exit -1; }
    if [ "$ACTION" == "ADD-NAMESPACE-USERS" ]; then
        echo "Creating clusterroles for namespace user"
        kubectl --kubeconfig $KUBECONFIG apply -f $SCRIPT_DIR/templates/clusterrole_namespace_admin_access.yaml; RC1=$?
        kubectl --kubeconfig $KUBECONFIG apply -f $SCRIPT_DIR/templates/clusterrole_cluster_wide_access.yaml;    RC2=$?
        if [ $RC1 -eq 0 -a $RC2 -eq 0 ]; then
            add_namespace_users
            update_annotation_for_namespace_users
        else
            echo "Error: Clusterrole creation failed."
            exit 1
        fi
    elif [ "$ACTION" == "DEL-NAMESPACE-USERS" ]; then
        del_namespace_users
        update_annotation_for_namespace_users
    elif [ "$ACTION" == "ANONATE-NAMESPACE-USERS" ]; then
        update_annotation_for_namespace_users

    elif [ "$ACTION" == "ADD-CLUSTER-ADMINS" ]; then
        add_cluster_admins
        update_annotation_for_cluster_admins
    elif [ "$ACTION" == "DEL-CLUSTER-ADMINS" ]; then
        del_cluster_admins
        update_annotation_for_cluster_admins
    elif [ "$ACTION" == "ANONATE-CLUSTER-ADMINS" ]; then
        update_annotation_for_cluster_admins

    else
        echo "Error: Wrong command '$ACTION'."
        usage
        exit 1
    fi
}

function add_namespace_users {
    for usr in "${userarr[@]}"; do
        echo "Adding user $usr to namespaces $NAMESPACE and eric-crd-ns as namespace admin in cluster $CLUSTER"
        kubectl --kubeconfig $KUBECONFIG --namespace $NAMESPACE \
                create rolebinding admin-${NAMESPACE}-${usr}    \
                --clusterrole=namespaced-admin-access-pooled    \
                --user=$usr

        kubectl --kubeconfig $KUBECONFIG --namespace eric-crd-ns get rolebinding admin-eric-crd-ns-${usr} 2>/dev/null
        if [ $? -ne 0 ]; then
            kubectl --kubeconfig $KUBECONFIG --namespace eric-crd-ns \
                    create rolebinding admin-eric-crd-ns-${usr}      \
                    --clusterrole=namespaced-admin-access-pooled     \
                    --user=$usr
        fi

        kubectl --kubeconfig $KUBECONFIG get clusterrolebinding admin-pv-${usr} 2>/dev/null
        if [ $? -ne 0 ]; then
            kubectl --kubeconfig $KUBECONFIG                  \
                    create clusterrolebinding admin-pv-${usr} \
                    --clusterrole=volumes-access-users        \
                    --user=${usr}
        fi
    done
}

function del_namespace_users {
    for usr in "${userarr[@]}"; do
        echo "Removing user $usr from namespaces $NAMESPACE and eric-crd-ns from cluster $CLUSTER"
        kubectl --kubeconfig $KUBECONFIG --namespace $NAMESPACE \
                delete rolebinding admin-${NAMESPACE}-${usr}

        kubectl --kubeconfig $KUBECONFIG get rolebinding -A 2>/dev/null | grep -F ${usr} | grep -v -F eric-crd-ns
        if [ $? -ne 0 ]; then
            kubectl --kubeconfig $KUBECONFIG --namespace eric-crd-ns \
                    delete rolebinding admin-eric-crd-ns-${usr}
            kubectl --kubeconfig $KUBECONFIG \
                    delete clusterrolebinding admin-pv-${usr}
        fi
    done
}

function update_annotation_for_namespace_users {
    echo "Annotating namespace users in namespace ${NAMESPACE}"
    NS_USERS=$(kubectl --kubeconfig $KUBECONFIG -n $NAMESPACE get rolebinding 2>&1 \
                | grep admin-$NAMESPACE | expand | cut -d ' ' -f 1 \
                | cut -d '-' -f 6 | tr '\n' , | sed 's/,$//')
    kubectl --kubeconfig $KUBECONFIG annotate --overwrite namespace $NAMESPACE users=$NS_USERS
}

function add_cluster_admins {
    for usr in "${userarr[@]}"; do
        kubectl --kubeconfig $KUBECONFIG get clusterrolebinding admin-cluster-$usr 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Adding Admin user $usr to cluster $CLUSTER"
            kubectl --kubeconfig $KUBECONFIG                     \
                    create clusterrolebinding admin-cluster-$usr \
                    --clusterrole=cluster-admin                  \
                    --user=$usr
        fi
    done
}

function del_cluster_admins {
    for usr in "${userarr[@]}"; do
        kubectl --kubeconfig $KUBECONFIG get clusterrolebinding admin-cluster-$usr 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "Deleting Admin user $usr from cluster $CLUSTER"
            kubectl --kubeconfig $KUBECONFIG delete clusterrolebinding admin-cluster-$usr
        else
            echo "No clusterrolebinding found for Admin user ${usr}"
        fi
    done
}

function update_annotation_for_cluster_admins {
    ADMIN_USERS=$(kubectl --kubeconfig $KUBECONFIG get clusterrolebindings 2>&1 \
                    | grep admin-cluster- | expand | cut -d ' ' -f 1 \
                    | cut -d '-' -f 3 | tr '\n' , | sed 's/,$//')
    echo "${ADMIN_USERS}"

    # Check if 'cluster-admins' ConfigMap exists, and create it if it doesn't
    kubectl --kubeconfig $KUBECONFIG --namespace bookings get configmap cluster-admins 2>&1 | grep -q "Error from server (NotFound)"
    if [ $? -eq 0 ]; then
        kubectl --kubeconfig $KUBECONFIG --namespace bookings create configmap cluster-admins
    fi

    kubectl --kubeconfig $KUBECONFIG --namespace bookings \
            annotate --overwrite configmap cluster-admins admin-users=$ADMIN_USERS
}

main
