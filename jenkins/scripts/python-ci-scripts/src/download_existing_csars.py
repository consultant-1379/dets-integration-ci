import logging
import sys
import os
import requests
from requests.exceptions import HTTPError
from requests.auth import HTTPBasicAuth
import time

LOG = logging.getLogger(__name__)

def download_existing_csars_from_repo(artifactory_repo_url, applications_to_check):
    # Read environment variables passed into container from docker run
    functional_user_username = os.environ.get('FUNCTIONAL_USER_USERNAME', None)
    functional_user_password = os.environ.get('FUNCTIONAL_USER_PASSWORD', None)

    # Fail script if any of the above are empty
    if artifactory_repo_url is None or applications_to_check is None or \
            functional_user_username is None or functional_user_password is None:
        print("ERROR: One or more mandatory environment variables not set.")
        raise

    with open(applications_to_check, "r") as application_file:
        for line in application_file:
            csar_name = line.split("_")[0]
            csar_version = line.split("_")[1]
            if "False" in line:
                LOG.error("-----------------------------------------------------------------------------------------------------------------------")
                LOG.error("CSAR for " + csar_name + ":" + csar_version + " does not exist. Please ensure the CSAR are available in the ")
                LOG.error("Repo, " + artifactory_repo_url + "/" + csar_name)
                LOG.error("-----------------------------------------------------------------------------------------------------------------------")
                raise

    with open(applications_to_check, "r") as application_file:
        for line in application_file:
            csar_name = line.split("_")[0]
            csar_version = line.split("_")[1]
            full_csar_name=csar_name + "-" + csar_version + ".csar"
            full_url=artifactory_repo_url + "/" + csar_name + "/" + csar_version + "/" + full_csar_name
            LOG.info("-----------------------------------------------------------------------------------------------------------------------")
            LOG.info("Repo url for " + csar_name + ": " + full_url)
            try:
                artifactory_response = requests.get(full_url, auth=HTTPBasicAuth(functional_user_username, functional_user_password), stream=True)
                download_path = "output-files/" + full_csar_name

                with open(download_path, "wb") as download_file:
                    LOG.info("Downloading " + full_csar_name)
                    response = requests.get(full_url, auth=HTTPBasicAuth(functional_user_username, functional_user_password), stream=True)
                    total_length = response.headers.get('content-length')

                    if total_length is None: # no content length header
                        download_file.write(response.content)
                    else:
                        increment = int(10)
                        dl = 0
                        total_length = int(total_length)
                        percentage = int(total_length / 10 )
                        percentage_to_add = percentage
                        sys.stdout.write("\r[1%]")
                        sys.stdout.flush()
                        for data in response.iter_content(chunk_size=4096):
                            dl += len(data)
                            download_file.write(data)
                            if dl >= int(percentage):
                                sys.stdout.write("\r[" + str(increment) + "%]")
                                sys.stdout.flush()
                                increment += 10
                                percentage += percentage_to_add
            except HTTPError as http_err:
                print(f'HTTP error occurred: {http_err}')
                raise
            except Exception as err:
                print(f'Other error occurred: {err}')
                raise
            LOG.info("-----------------------------------------------------------------------------------------------------------------------")
