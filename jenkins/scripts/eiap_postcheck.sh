#!/bin/bash

# --------------------------------------------------------------------------
#  COPYRIGHT Ericsson 2022
#
#  The copyright to the computer program(s) herein is the property of
#  Ericsson Inc. The programs may be used and/or copied only with written
#  permission from Ericsson Inc. or in accordance with the terms and
#  conditions stipulated in the agreement/contract under which the
#  program(s) have been supplied.
# --------------------------------------------------------------------------

######################################################
###### declare veriable for the script ###############
######################################################

KUBE_CONFIG=$1
NAME_SPACE=$2
DOMAIN_NAME=$3


######################################################
###### Log file Formatting  ##########################
######################################################
LOG_FILE="postcheck_logs.txt" #output file

function checkLogExist() {
    if [ -e "$LOG_FILE" ]; then
        >"$LOG_FILE"
    else
        touch $LOG_FILE
    fi
     chown -R $USER $LOG_FILE
}
checkLogExist


######################################################
######### Function for Post check validation #########
######################################################

###1. kubeconfig validate connectivity 
function validateKubeConnectivity()
{
  output=$(kubectl get ns --kubeconfig "${KUBE_CONFIG}")
  if [[ $? != 0 ]]; then
	echo 'Invalid Kube Config File, Please check' >>$LOG_FILE
	echo 'Result: FAILED' 2>&1 | tee -a $LOG_FILE
	exit 1
  fi
	echo 'Connected to Cluster successfully for Post check' >>$LOG_FILE
	echo 'Result: PASSED' 2>&1 | tee -a $LOG_FILE
	
}


###2. Check The Namespace
function checkTheNameSpace()
{
  output=$(kubectl get ns --kubeconfig "${KUBE_CONFIG}" | grep -i "${NAME_SPACE}")
  if  [ $(echo "$output" | wc -l) = 0 ]; then
	kubectl get ns --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
    echo 'The Name Space Not Available ' >>$LOG_FILE
	echo 'Result: FAILED' 2>&1 | tee -a $LOG_FILE
	exit 1
  fi
	kubectl get ns --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
	echo 'Mentioned Namespace Present' >>$LOG_FILE
	echo 'Result: PASSED' 2>&1 | tee -a $LOG_FILE
	
}


###3. validate check_helm_chart
function check_helm_chart()
{
  output=$(helm list -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" )
  if [[ $? != 0 ]]; then
    echo "$output" >>$LOG_FILE
	echo 'No helm chart found ' >>$LOG_FILE
	echo 'Result: FAILED' 2>&1 | tee -a $LOG_FILE
	exit 1
  fi
	echo "$output" >>$LOG_FILE 
	echo "Result: PASSED" 2>&1 | tee -a $LOG_FILE
	
}


###4. validate check Node Status 
function checkNodeStatus()
{
	CHECK_NODES=$(kubectl get nodes -o wide --kubeconfig "${KUBE_CONFIG}" | grep -v "Ready")
	if [ $(echo "$CHECK_NODES" | wc -l) -gt 1 ]; then
		kubectl get node -o wide --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
		echo "Result: FAILED" 2>&1 | tee -a $LOG_FILE
		exit 1
		
	fi
		kubectl get node -o wide --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
		echo "Result: PASSED" 2>&1 | tee -a $LOG_FILE
}


###5. validate check pod Status 
function checkPodStatus()
{
	CHECK_PODS=$(kubectl get pods -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" | egrep -v '1/1|2/2|3/3|4/4|5/5|6/6|Completed')
	if [ $(echo "$CHECK_PODS" | wc -l) -gt 1 ]; then
		kubectl get pods -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
		echo "Result: FAILED" 2>&1 | tee -a $LOG_FILE
		exit 1
		
	fi
		kubectl get pods -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
		echo "Result: PASSED" 2>&1 | tee -a $LOG_FILE
}


###6. Check Helm Chart Version
function checkTheChartVersion()
{
  output=$(kubectl get virtualservices --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}")
  if [[ $? != 0 ]]; then
	kubectl get virtualservices --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}" >>$LOG_FILE
    echo 'The chart version not found' >>$LOG_FILE
	echo 'Result: FAILED' 2>&1 | tee -a $LOG_FILE
	exit 1
  fi
	kubectl get virtualservices --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}" >>$LOG_FILE
	echo 'The chart versions found' >>$LOG_FILE
	echo 'Result: PASSED' 2>&1 | tee -a $LOG_FILE
	
}


###7. validate check PVC Status 
function checkPvcStatus()
{
	CHECK_PVCS=$(kubectl get pvc -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" | egrep -v 'Bound')
	if [ $(echo "$CHECK_PVCS" | wc -l) -gt 1 ]; then
		kubectl get pvc -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
		echo "Result: FAILED" 2>&1 | tee -a $LOG_FILE
		exit 1
		
	fi
		kubectl get pvc -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
		echo "Result: PASSED" 2>&1 | tee -a $LOG_FILE
}


###8. validate check pv Status 
function checkPvStatus()
{
	CHECK_PV=$(kubectl get pv -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" | egrep -v 'Bound')
	if [ $(echo "$CHECK_PV" | wc -l) -gt 1 ]; then
		kubectl get pv -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
		echo "Result: FAILED" 2>&1 | tee -a $LOG_FILE
		exit 1
		
	fi
		kubectl get pv -n "${NAME_SPACE}" --kubeconfig "${KUBE_CONFIG}" >>$LOG_FILE
		echo "Result: PASSED" 2>&1 | tee -a $LOG_FILE
}


###9.	EIAP statefulset 
function checkStatefulset()
{
  output=$(kubectl get statefulset --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}")
  if [[ $? != 0 ]]; then
	kubectl get statefulset --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}" >>$LOG_FILE
    echo 'The statefulset not found under name space ${NAME_SPACE}' >>$LOG_FILE
	echo 'Result: FAILED' 2>&1 | tee -a $LOG_FILE
	exit 1
  fi
	kubectl get statefulset --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}" >>$LOG_FILE
	echo 'The statefulset found under namespace' ${NAME_SPACE} >>$LOG_FILE
	echo 'Result: PASSED' 2>&1 | tee -a $LOG_FILE
	
}


###10.	EIAP secrets
function checkSecrets()
{
  output=$(kubectl get secrets --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}")
  if [[ $? != 0 ]]; then
	kubectl get secrets --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}" >>$LOG_FILE
    echo 'The secrets not found under name space ${NAME_SPACE}' >>$LOG_FILE
	echo 'Result: FAILED' 2>&1 | tee -a $LOG_FILE
	exit 1
  fi
	kubectl get secrets --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}" >>$LOG_FILE
	echo 'The secrets found under namespace' ${NAME_SPACE} >>$LOG_FILE
	echo 'Result: PASSED' 2>&1 | tee -a $LOG_FILE
	
}


###11.	EIAP configmap
function checkConfigmap()
{
  output=$(kubectl get configmap --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}")
  if [[ $? != 0 ]]; then
	kubectl get configmap --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}" >>$LOG_FILE
    echo 'The configmap not found under name space ${NAME_SPACE}' >>$LOG_FILE
	echo 'Result: FAILED' 2>&1 | tee -a $LOG_FILE
	exit 1
  fi
	kubectl get configmap --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}" >>$LOG_FILE
	echo 'The configmap found under namespace' ${NAME_SPACE} >>$LOG_FILE
	echo 'Result: PASSED' 2>&1 | tee -a $LOG_FILE
	
}


###12. Check the GUI Login
function checkTheGuiLogin()
{
  output=$(kubectl get virtualservices --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}" | grep gas${DOMAIN})
  if [[ $? != 0 ]]; then
        kubectl get virtualservices --kubeconfig "${KUBE_CONFIG}" -n "${NAME_SPACE}"  >>$LOG_FILE
        echo 'no end point found' >>$LOG_FILE
        echo 'Result: FAILED' 2>&1 | tee -a $LOG_FILE
        exit 1
  fi
  touch tmp.txt
  output1=$(curl -k -X POST -H "Content-Type: application/json" -H "X-login: system-user" -H 'X-password: Ericsson123!' gas${DOMAIN} -K tmp.txt >> $LOG_FILE )
        if [[ $? != 0 ]]; then
                echo 'End point Error' >>$LOG_FILE
                echo 'Result: FAILED' 2>&1 | tee -a $LOG_FILE
                exit 1
        fi
                echo 'Valid End point Found' >>$LOG_FILE
                echo 'Result: PASSED' 2>&1 | tee -a $LOG_FILE
        rm tmp.txt
}

###########################################
######### Function Execution Area #########
###########################################

echo '############ EIAP Post Installation validation ########' 2>&1 | tee -a $LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 1. validate connectivity via kubeconfig #######' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
validateKubeConnectivity # Call the function 1
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 2. Check The Namespace  #######################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
checkTheNameSpace # Call the function 2
echo '================================================' >>$LOG_FILE


echo '#########################################' >>$LOG_FILE
echo '####### 3. validate check helm chart ##################' 2>&1 | tee -a $LOG_FILE
echo '#########################################' >>$LOG_FILE
check_helm_chart # Call the  function 3
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 4. validate check Node Status #################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
checkNodeStatus # Call the  function 4
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 5. validate check pod Status ##################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
checkPodStatus # Call the  function 5
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 6. Check Helm Chart Version  ##################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
checkTheChartVersion # Call the function 6
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 7. validate check PVC Status   ################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
checkPvcStatus # Call the  function 7
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 8. validate check pv Status ###################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
#checkPvStatus # Call the  function 8
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 9. Check EIAP statefulset #####################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
checkStatefulset # Call the function 9
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 10. Check EIAP secrets ########################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
checkSecrets # Call the function 10
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 11. Check EIAP configmap ######################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
checkConfigmap # Call the function 11
echo '================================================' >>$LOG_FILE


echo '#######################################' >>$LOG_FILE
echo '####### 12. Check the GUI Login #######################' 2>&1 | tee -a $LOG_FILE
echo '#######################################' >>$LOG_FILE
#checkTheGuiLogin # Call the function 12
echo '================================================' >>$LOG_FILE
