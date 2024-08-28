import os
import re
import requests
from requests.exceptions import HTTPError
from requests.auth import HTTPBasicAuth

def convert(text):
    return int(text) if text.isdigit() else text

def eiae_keys(text):
    return [ convert(x) for x in re.split(r'(\d+)', text) ]

def get_latest_helmfile_version_from_repo():
    artifacts = []

    # Read environment variables passed into container from docker run
    helmfile_repo_url = os.environ.get('INT_CHART_REPO', None)
    helmfile_name = os.environ.get('INT_CHART_NAME', None)
    functional_user_username = os.environ.get('FUNCTIONAL_USER_USERNAME', None)
    functional_user_password = os.environ.get('FUNCTIONAL_USER_PASSWORD', None)

    # Fail script if any of the above are empty
    if helmfile_repo_url is None or helmfile_name is None or \
            functional_user_username is None or functional_user_password is None:
        print("ERROR: One or more mandatory environment variables not set.")
        raise

    # Format helmfile repo url with appropriate endpoint
    helmfile_repo_substring = "artifactory/"
    additional_artifactory_api_path = "api/storage/"
    index_of_substring_end = helmfile_repo_url.index(helmfile_repo_substring) + len(helmfile_repo_substring)
    helmfile_repo_url = helmfile_repo_url[:index_of_substring_end] \
        + additional_artifactory_api_path + helmfile_repo_url[index_of_substring_end:]

    try:
        # Send request to get contents of eric-eiae-helmfile directory in aritfactory
        artifactory_response = requests.get(f"{helmfile_repo_url}/{helmfile_name}",
                                            auth=HTTPBasicAuth(functional_user_username, functional_user_password))
        artifactory_response.raise_for_status()
        artifactory_json_response = artifactory_response.json()
        # Extract all artifact names into list (helmfile.tgz files)
        for artifact in artifactory_json_response["children"]:
            artifacts.append(artifact["uri"][1:])
        print(f"Artifacts found in repo:\n{artifacts}")
        # Sort to get helmfile artifact with the latest version
        artifacts.sort(key=eiae_keys, reverse=True)

        print("-----------------------------------------------------------------------------------")
        print(f"Latest helmfile version from artifactory is {artifacts[0]}")
        print("-----------------------------------------------------------------------------------")
        # Separate the version number to be written to artifact.properties
        version_number = re.search('eric-eiae-helmfile-(.*?).tgz', artifacts[0]).group(1)
    except HTTPError as http_err:
        print(f'HTTP error occurred: {http_err}')
        raise
    except Exception as err:
        print(f'Other error occurred: {err}')
        raise

    try:
        # Write version to artifact.properties
        with open("output-files/artifact.properties", "w") as artifact_properties:
            artifact_properties.write(f"INT_CHART_VERSION:{version_number}")
    except IOError as io_error:
        print(f'File write error, could not write to artifact.properties: {io_error}')
        raise
