import logging
from pathlib import Path
import datetime
import subprocess
import json
import argparse
import re
import requests
import socket

LOG = logging.getLogger('health_check')


def initialize_logging(name):
    # Initialize the logging to standard output and logfile.
    log_format = "[%(asctime)s] [%(name)s] [%(levelname)s]: %(message)s"
    log_file_path = _log_file_path(name)
    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(logging.Formatter(log_format))
    stream_handler.setLevel(('DEBUG'))
    logging.basicConfig(filename=log_file_path, format=log_format, level=logging.DEBUG)
    logging.getLogger('').addHandler(stream_handler)
    return logging.getLogger('')

def _log_file_path(name):
    absolute_log_directory = Path.cwd() / Path('logs')
    absolute_log_directory.mkdir(parents=True, exist_ok=True)
    return str(Path(absolute_log_directory) / datetime.datetime.now().strftime('%Y-%m-%dT%H_%M_%S%z_{0}_health_check.log'.format(name)))

def execute_command(command):
    """
    Execute a command on shell
    :param command: Command to be executed
    :return: Command Response
    """
    LOG.info("Executing command - {0}".format(command))
    proc = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    stdout_value = proc.communicate()[0].decode("utf-8").rstrip()
    LOG.info("Command output - ")
    LOG.info("{0}".format(stdout_value))
    return_value = proc.returncode
    LOG.info("Return code = {0}".format(return_value))
    if return_value != 0:
        LOG.info("Failed to execute command - {0}. Error is - {1}".format(command, stdout_value))
        return 1
    return stdout_value


def set_rest_api_token(username, password, url):
    """Authorisation on IDAM server and getting JWT."""
    headers = {'content-type': 'application/json',
               'X-Login': username,
               'X-Password': password}
    url = url + '/auth/v1'
    status_code, response = execute_rest_api(url=url, http_method="HttpMethod.POST", headers=headers)
    return status_code, response


def execute_rest_api(url, http_method="HttpMethod.GET", data=None, headers=None, token=None):
    """Generic handler http/https call."""
    if token is not None and token != '':
        final_headers = {'Content-Type': 'application/json',
                         'Accept': 'application/json',
                         'Cookie': 'JSESSIONID=' + token}
    else:
        final_headers = headers
    try:
        if http_method == "HttpMethod.GET":
            response = requests.get(url=url, headers=final_headers, data=data, verify=False)
        elif http_method == "HttpMethod.POST":
            response = requests.post(url=url, headers=final_headers, data=data, verify=False)

    except requests.exceptions.RequestException as err:
        result = "Unable to execute rest call " + str(url) + \
                 ". Error Reported: " + str(err)
        status_code = 502
        return status_code, result
    try:
        result = json.loads(response.text)
    except ValueError:
        result = response.text
    LOG.debug("execute_rest_api: status_code=%d, response=%s", response.status_code, result)
    return response.status_code, result


def health_checks(kubeconfig, name, namespace, pf_user, pf_pass, url):
    """
    Main method to iterate through the health checks
    :param kubeconfig file, namespace, pf_user, pf password & url
    :return: response code  0 or 1
    """

    helm_rc = helm_status(kubeconfig=kubeconfig, namespace=namespace, name=name)
    replicaset_rc = replicaset_status(kubeconfig=kubeconfig, namespace=namespace)
    daemonset_rc = daemonset_status(kubeconfig=kubeconfig, namespace=namespace)
    statefulset_rc = statefulset_status(kubeconfig=kubeconfig, namespace=namespace)
    job_rc = job_status(kubeconfig=kubeconfig, namespace=namespace)

    if (name != "openlab01"):
        ui_rc = ui_status(pf_user=pf_user, pf_pass=pf_pass, url=url)
    else:
        ui_rc = True

    if helm_rc and replicaset_rc and daemonset_rc and statefulset_rc and job_rc and ui_rc:
        LOG.info('All health checks passed')
        return
    else:
        pod_status(kubeconfig=kubeconfig, namespace=namespace)
        LOG.info('One or more health checks failed, please check the log for details')
        email_failed_health_check(name)
        exit(1)


def email_failed_health_check(name):
    """
    Send email alert on failed health check
    :param N/A
    :return: N/A
    :side effect: Send failed health check notification to team inbox
    """
    LOG.info("Sending health check failure notification to Team Muon inbox pdlteammuo@pdl.internal.ericsson.com")

    log_path = _log_file_path(name)
    hostname = socket.gethostbyaddr(socket.gethostname())[0]
    email_body = """
    The health check has failed for the {2} deployment!
    For detailed logs, please find the log file at the path below on the {1} host.
    Log location: {0}
    """.format(log_path, hostname, name)
    send_email = "echo \'{1}\' | mail -s \"Health check failed for deployment {0}!\" -S \"from=Team Muon Monitoring <$(whoami)@$(hostname)>\" \'pdlteammuo@pdl.internal.ericsson.com\'".format(name, email_body)
    execute_command(send_email)


# Check helm status
def helm_status(kubeconfig, namespace, name):
    """
    Check helm status of the IDUN deployment
    :param kubeconfig file, namespace
    :return: response code  0 or 1
    """
    LOG.info('Starting Helm release health check')

    charts_dict = get_release_status(kubeconfig=kubeconfig, namespace=namespace)
    if len(charts_dict) == 0:
        LOG.info('No Helm releases were found. Either no installation present or in-correct namespace, please check the log for details')
        email_failed_health_check(name)
        exit(1)

    LOG.info('Helm releases and status in {1} namespace: {0}'.format(charts_dict, namespace))
    for chart_name, chart_status in charts_dict.items():
        if chart_status not in get_release_operable_states():
            LOG.info('One or more Helm releases in the {} namespace are not in the desired state - releases should be in either \'deployed\' or \'superseded\' state)'.format(namespace))
            LOG.info('Helm release health check failed')
            return False
    LOG.info('Helm release health check passed')
    return True

# Check pod errors
def pod_status(kubeconfig, namespace):
    """
    Check pod status of the IDUN deployment
    :param kubeconfig file & namespace
    :return: response code  0 or 1
    """
    LOG.info('Starting pod health check')
    ls_command_output = pod_list(kubeconfig=kubeconfig, namespace=namespace )
    lines = str(ls_command_output).strip().split("\n")
    if len(lines) == 1:
        LOG.info('Pod health check passed')
        return True
    else:
        LOG.info('One or more pods are not in desired state')
        LOG.info('Pod health check failed')
        return False


# Check UI accessibilty
def ui_status(pf_user, pf_pass, url):
    LOG.info('Starting UI login checks on IDUN PF DMAAP endpoint')

    if not url.lower().startswith(('http://', 'https://')):
        url = "https://" + url

    status, token = set_rest_api_token(username=pf_user, password=pf_pass, url=url)
    print (status, token)
    if status == 200:
        url = url + '/dmaap-mr/topics'
        login_status, login = execute_rest_api(url=url, http_method="HttpMethod.GET", data=None, headers=None, token=token)
        if login_status == 200:
            LOG.info('UI login to DMAAP succeeded')
            LOG.info('UI login health check passed')
            return True

    LOG.info('UI login to DMAAP failed')
    LOG.info('UI login health check failed')
    return False

def replicaset_status(kubeconfig, namespace):
    """
    Check the status of each replicaset in the deployment
    :param kubeconfig
    :param namespace
    :return: False if any replicaset is not in desired state
             True otherwise
    """
    LOG.info('Starting replicaset health check')
    # Echo before output to preserve formatting in logs
    get_replicasets = "echo; kubectl get replicaset --kubeconfig {0} --namespace {1}".format(kubeconfig, namespace)
    output = execute_command(get_replicasets).splitlines()[2:]

    for line in output:
        current = line.split()[2]
        desired = line.split()[1]
        if current != desired:
            LOG.info('One or more ReplicaSets are not in the desired state')
            LOG.info('replicaset health check failed')
            return False

    LOG.info('replicaset health check passed')
    return True # All ReplicaSets are in the desired state

def daemonset_status(kubeconfig, namespace):
    """
    Check the status of each daemonset in the deployment
    :param kubeconfig
    :param namespace
    :return: False if any daemonset is not in desired state
             True otherwise
    """
    LOG.info('Starting daemonset health check')
    # Echo before output to preserve formatting in logs
    get_daemonsets = "echo; kubectl get daemonset --kubeconfig {0} --namespace {1}".format(kubeconfig, namespace)
    output = execute_command(get_daemonsets).splitlines()[2:]

    for line in output:
        current = line.split()[2]
        desired = line.split()[1]
        if current != desired:
            LOG.info('One or more DaemonSets are not in the desired state')
            LOG.info('daemonset health check failed')
            return False

    LOG.info('daemonset health check passed')
    return True # All DaemonSets are in the desired state

def job_status(kubeconfig, namespace):
    """
    Check the status of each Job in the deployment
    :param kubeconfig
    :param namespace
    :return: False if any Job has pending completions
             True otherwise
    """

    LOG.info('Starting Job health check')
    # Echo before output to preserve formatting in logs
    get_jobs = "echo; kubectl get job --kubeconfig {0} --namespace {1}".format(kubeconfig, namespace)

    # Clean the list: Remove any jobs with the substring eric-data-search-engine-curator in the name
    output = [job for job in execute_command(get_jobs).splitlines()[2:] if "eric-data-search-engine-curator" not in job]

    for line in output:
        status = line.split()[1]
        current = status.split("/")[0]
        desired = status.split("/")[1]
        if current != desired:
            LOG.info('One or more Jobs are not in the desired state')
            LOG.info('Job health check failed')
            return False

    LOG.info('Job health check passed')
    return True # All Jobs are in the desired state

def statefulset_status(kubeconfig, namespace):
    """
    Check the status of each StatefulSet in the deployment
    :param kubeconfig
    :param namespace
    :return: False if any StatefulSet is not in Ready state
             True otherwise
    """

    LOG.info('Starting StatefulSet health check')
    # Echo before output to preserve formatting in logs
    get_jobs = "echo; kubectl get statefulset --kubeconfig {0} --namespace {1}".format(kubeconfig, namespace)
    output = execute_command(get_jobs).splitlines()[2:]

    for line in output:
        status = line.split()[1]
        current = status.split("/")[0]
        desired = status.split("/")[1]
        if current != desired:
            LOG.info('One or more StatefulSets are not in the desired state')
            LOG.info('StatefulSet health check failed')
            return False

    LOG.info('StatefulSet health check passed')
    return True # All StatefulSets are in the desired state


def get_release_status(kubeconfig, namespace):
    chart_dict = {}
    ls_command_output = helm_list(kubeconfig=kubeconfig, namespace=namespace)
    ls_command_output_json = json.loads(ls_command_output)
    for release in ls_command_output_json:
        chart_dict[release['name']] = release['status']
    return chart_dict


def pod_list(kubeconfig, namespace):
    """Return an output of kubectl get pod command."""
    LOG.info('Retrieving pods and states in namespace {}'.format(namespace))
    # Echo before output to preserve formatting in logs
    command_all = "echo; kubectl get pod --namespace {1} --kubeconfig {0}".format(kubeconfig, namespace)
    output_all = execute_command(command_all)

    # Filter out running, completed, successful pods and pods with the substring eric-data-search-engine-curator in the name
    command_error = "echo; kubectl get pod --namespace {1} --kubeconfig {0} | \
        grep -iv eric-data-search-engine-curator | grep -iv run | grep -iv compl | grep -iv succ".format(kubeconfig, namespace)
    output = execute_command(command_error)
    return output


def helm_list(kubeconfig, namespace):
    """Return an output of helm list command."""
    LOG.info('Retrieving Helm charts and states in namespace {}'.format(namespace))
    # Echo before output to preserve formatting in logs
    command = "echo; helm list --namespace {0} --kubeconfig {1} 2> /dev/null".format(namespace, kubeconfig)
    output = execute_command(command) # Print the friendly-formatted version of the Helm charts and states
    command_json = "helm list --namespace {0} --output json --kubeconfig {1} 2> /dev/null".format(namespace, kubeconfig)
    output_json = execute_command(command_json)

    return output_json


def get_release_operable_states():
    """
    The list of permissible states for Helm releases.
    """
    return [
        'deployed',
        'superseded'
    ]


def process_cmd_line_args():
    """
    Function to process command line arguments.

    Returns:
         (options, args) -- tuple with parameters provided to the script
    """
    description = 'Execute healthchecks for IDUN deployments .\n'
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument('--kubeconfig',
                        help="The path to the Kubeconfig file",
                        metavar="kubeconfig", required=True)
    parser.add_argument('--pf_user',
                        help="The user ID to check GUI access against",
                        metavar="so_user", required=True)
    parser.add_argument('--pf_pass',
                        help="The password for the user ID",
                        metavar="pf_password", required=True)
    parser.add_argument('--namespace',
                        help="The namespace to run the health check against (typically 'oss')",
                        metavar="namespace", required=True)
    parser.add_argument('--url',
                        help="The URL of the PF endpoint",
                        metavar="url", required=True)
    parser.add_argument('--name',
                        help="The name of the deployment",
                        metavar="name", required=True)
    args = parser.parse_args()
    return args

def main():
    global logger
    args = process_cmd_line_args()
    logger = initialize_logging(name=args.name)

    try:
        LOG.debug("Script args = '{}'".format(args))
        health_checks(kubeconfig=args.kubeconfig, name=args.name,
                      namespace=args.namespace, pf_user=args.pf_user,
                      pf_pass=args.pf_pass, url=args.url)
    except Exception as err:
        err = ("Error occurred - {0}".format(err))
        LOG.error(err)
        LOG.debug('%s\n' % err, exc_info=True)
        exit(1)


if __name__ == '__main__':
    main()
