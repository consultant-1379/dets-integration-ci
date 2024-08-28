import logging
import os
import requests
from requests.exceptions import HTTPError
from requests.auth import HTTPBasicAuth

LOG = logging.getLogger(__name__)

def check_for_existing_csars_in_repo(artifactory_repo_url, applications_to_check):
    # Read environment variables passed into container from docker run
    functional_user_username = os.environ.get('FUNCTIONAL_USER_USERNAME', None)
    functional_user_password = os.environ.get('FUNCTIONAL_USER_PASSWORD', None)

    # Fail script if any of the above are empty
    if artifactory_repo_url is None or applications_to_check is None or \
            functional_user_username is None or functional_user_password is None:
        LOG.error("ERROR: One or more mandatory environment variables not set.")
        raise

    output_file="output-files/build_csar.properties"

    if os.path.exists(output_file):
        os.remove(output_file)

    check_output_file="output-files/csar_check.properties"
    repository_url="https://arm.seli.gic.ericsson.se/artifactory/proj-eric-oss-drop-generic-local/csars"

    if os.path.exists(check_output_file):
        os.remove(check_output_file)


    with open(applications_to_check, "r") as application_file:
        for line in application_file:
            artifacts = []
            version_found = False
            csar_name = line.split("=")[0]
            csar_version = line.split("=")[1].rstrip('\n')
            LOG.info("Full CSAR Repo url for " + csar_name + " to be used:\n " + artifactory_repo_url + "/" + csar_name)
            try:
                # Send request to get CSAR versions available on CSAR repo
                artifactory_response = requests.get(artifactory_repo_url + "/" + csar_name, auth=HTTPBasicAuth(functional_user_username, functional_user_password))

                if artifactory_response.status_code == 200:
                    artifactory_response.raise_for_status()
                    artifactory_response_json = artifactory_response.json()
                    # Extract all artifact names into list (helmfile.tgz files)
                    for artifact in artifactory_response_json["children"]:
                        artifacts.append(artifact["uri"][1:])
                    LOG.info("Artifacts found in repo:\n " + str(artifacts))
                if csar_version in artifacts:
                    LOG.info("-----------------------------------------------------------------------------------------------------------------------")
                    LOG.info("CSAR Version " + csar_version + " exists in CSAR repo, for " + csar_name + ":" + csar_version)
                    LOG.info("-----------------------------------------------------------------------------------------------------------------------")
                    version_found = True
                else:
                    LOG.info("-----------------------------------------------------------------------------------------------------------------------")
                    LOG.info("CSAR Version " + csar_version + " not found in CSAR repo, for " + csar_name + ":" + csar_version)
                    LOG.info("-----------------------------------------------------------------------------------------------------------------------")
            except HTTPError as http_err:
                LOG.info("HTTP error occurred: " + http_err)
                raise
            except Exception as err:
                LOG.info("Other error occurred: " + err)
                raise

            try:
                # Write decision whether CSAR is found or not to build_csar.properties
                with open(output_file, "a+") as build_csar_properties:
                    build_csar_properties.write(csar_name + "_" + csar_version + "_csar_found=" + str(version_found) + "\n")
            except IOError as io_error:
                LOG.error("File write error, could not write to build_csar.properties: " + io_error)
                raise

            try:
                # Write Information on CSAR to csar_check.properties
                with open(check_output_file, "a+") as csar_check_properties:
                    if version_found:
                        csar_check_properties.write(csar_name + "__AVAILABLE=" + repository_url + "/" + csar_name + "/" + csar_version + "\n")
                    else:
                        csar_check_properties.write(csar_name + "__NOT_FOUND=" + repository_url + "/" + csar_name + "/" + csar_version + "\n")
            except IOError as io_error:
                LOG.error("File write error, could not write to csar_check.properties: " + io_error)
                raise
