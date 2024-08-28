import logging
from pathlib import Path
import datetime
import argparse
import requests
import json


LOG = logging.getLogger('subsystems')


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
    return str(Path(absolute_log_directory) / datetime.datetime.now().strftime(
        '%Y-%m-%dT%H_%M_%S%z_{0}_subsystem.log'.format(name)))


def set_rest_api_token(username, password, url):
    """Authorisation on IDAM server and getting JWT."""
    headers = {'content-type': 'application/json',
               'X-Login': username,
               'X-Password': password}
    url = url + '/auth/v1'
    status_code, response = execute_rest_api(url=url, http_method="HttpMethod.POST", headers=headers)
    return status_code, response


def execute_rest_api(url, http_method="HttpMethod.GET", data=None, jsonf=None, headers=None, token=None):
    """Generic handler http/https call."""
    if token is not None and token != '':
        final_headers = {'Content-Type': 'application/json',
                         'Accept': 'application/json',
                         'Cookie': 'JSESSIONID=' + token}
    else:
        final_headers = headers
    try:
        if http_method == "HttpMethod.GET":
            response = requests.get(url=url, headers=final_headers, data=data, json=jsonf, verify=False)
        elif http_method == "HttpMethod.POST":
            response = requests.post(url=url, headers=final_headers, data=data, json=jsonf, verify=False)

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


def subsystem_create(so_hostname, subsystem_type, config, user, passw):
    if not so_hostname.lower().startswith(('http://', 'https://')):
        url = "https://" + so_hostname
    else:
        url = so_hostname
    LOG.info('Executing API operation to create {} connectivity '.format(subsystem_type))
    LOG.info('Obtain Token for SO ')
    status, token = set_rest_api_token(username=user, password=passw, url=url)
    if status == 200:
        LOG.info('Successfuly got Token for SO ')
        if subsystem_type == 'tenant':
            url_get = url + '/subsystem-manager/v1/subsystems'
            LOG.info('GET subsytem details of EOCM ')
            get_status, get_subsystem_output = execute_rest_api(url=url_get, token=token)
            if get_status == 200:
                LOG.info('Successfully GET subsytem details of EOCM ')
                connection_id = \
                [x for x in get_subsystem_output if x['subsystemType']['type'] == 'NFVO'][0]['connectionProperties'][0][
                'id']
                subsytem_id = [x for x in get_subsystem_output if x['subsystemType']['type'] == 'NFVO'][0]['id']
            else:
                LOG.info('Failed to get subsytem details of EOCM ')
                exit(1)

            url = url + '/subsystem-manager/v1/tenant-mappings'
            tenant_dict = {"tenantName": "master", "subsystemId": subsytem_id, "connectionProperties": [connection_id]}
            tenant_status, tenant_output = execute_rest_api(url=url, http_method="HttpMethod.POST",
                                                            data=json.dumps(tenant_dict),
                                                            headers=None,
                                                            token=token)
            if tenant_status == 201:
                LOG.info('Successfully mapped tenant connection ')
            else:
                LOG.info('Failed to map tenant connections for EOCM ')
                exit(1)
        elif subsystem_type == 'ecm':
            url = url + '/subsystem-manager/v1/subsystems'
            ecm_status, ecm_output = execute_rest_api(url=url, http_method="HttpMethod.POST", data=open(config, 'rb'),
                                                      token=token)
            if ecm_status == 201:
                LOG.info('Successfully added EOCM to subsystems ')
            else:
                LOG.info('Failed to add EOCM to subsystems ')
                exit(1)
        elif subsystem_type == 'enm':
            url = url + '/subsystem-manager/v1/subsystems'
            enm_status, enm_output = execute_rest_api(url=url, http_method="HttpMethod.POST", data=open(config, 'rb'),
                                                      token=token)
            if enm_status == 201:
                LOG.info('Successfully added ENM to subsystems ')
            else:
                LOG.info('Failed to add ENM to subsystems ')
                exit()
    else:
        LOG.info('Cannot get Token for SO ')
        exit(1)


def process_cmd_line_args():
    """
    Function to process command line arguments.

    Returns:
         (options, args) -- tuple with parameters provided to the script
    """
    description = 'Execute subsystems connection for IDUN deployments .\n'
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument('--so_hostname',
                        help="SO Hostname or URL",
                        metavar="so_hostname", required=True)
    parser.add_argument('--subsystem_type',
                        help="Type of subsystem that needs to be connected, eg: eocm, enm",
                        metavar="subsystem_type", required=True)
    parser.add_argument('--config',
                        help="Path to json file with input configuration for subsystems",
                        metavar="config", required=False)
    parser.add_argument('--user',
                        help="Username for SO login",
                        metavar="user", required=True)
    parser.add_argument('--passw',
                        help="password for SO login",
                        metavar="passw", required=True)
    args = parser.parse_args()
    return args


def main():
    global logger
    args = process_cmd_line_args()
    logger = initialize_logging(name=args.subsystem_type)

    try:
        LOG.debug("Script args = '{}'".format(args))
        subsystem_create(so_hostname=args.so_hostname, subsystem_type=args.subsystem_type,
                         config=args.config, user=args.user, passw=args.passw)
    except Exception as err:
        err = ("Error occurred - {0}".format(err))
        LOG.error(err)
        LOG.debug('%s\n' % err, exc_info=True)
        exit(1)


if __name__ == '__main__':
    main()
