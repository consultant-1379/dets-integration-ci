import logging
import yaml
import os
import json
import getopt
import sys

LOG = logging.getLogger(__name__)

HELMFILE="/usr/bin/helmfile"
HELM="/usr/bin/helm"
CURRENT_WORKING_DIRECTORY=os.getcwd()
HELMFILE_BUILD_OUTPUT=CURRENT_WORKING_DIRECTORY + "/helmfile_build_output.txt"
HELMFILE_JSON=CURRENT_WORKING_DIRECTORY + "/helmfile_json_content.json"
CSAR_BUILD_PROPERTIES=CURRENT_WORKING_DIRECTORY + "/csar_build.properties"
RELEASES_ASSOCIATED_TO_CSARS_JSON=CURRENT_WORKING_DIRECTORY + "/releases_and_associated_csar.json"
CSARS_TO_BUILD=CURRENT_WORKING_DIRECTORY + "/csar_to_be_built.properties"
CSAR_HELM_CHART_MAPPING=CURRENT_WORKING_DIRECTORY + "/am_package_manager.properties"


def listToString(s):
    '''
    Function to change a list to a string delimited by ,
    '''
    # return string
    return (",".join(s))


def clean_up():
    '''
    Function to ensure all created file are removed if not needed
    '''
    if os.path.exists(HELMFILE_BUILD_OUTPUT):
        os.remove(HELMFILE_BUILD_OUTPUT)
    if os.path.exists(HELMFILE_JSON):
        os.remove(HELMFILE_JSON)
    if os.path.exists(CURRENT_WORKING_DIRECTORY + "compiledContent_crds-helmfile.yaml"):
        os.remove(CURRENT_WORKING_DIRECTORY + "compiledContent_crds-helmfile.yaml")
    if os.path.exists(CURRENT_WORKING_DIRECTORY + "compiledContent_helmfile.yaml"):
        os.remove(CURRENT_WORKING_DIRECTORY + "compiledContent_helmfile.yaml")
    if os.path.exists(CSAR_BUILD_PROPERTIES):
        os.remove(CSAR_BUILD_PROPERTIES)
    if os.path.exists(RELEASES_ASSOCIATED_TO_CSARS_JSON):
        os.remove(RELEASES_ASSOCIATED_TO_CSARS_JSON)
    if os.path.exists(CSARS_TO_BUILD):
        os.remove(CSARS_TO_BUILD)
    if os.path.exists(CSAR_HELM_CHART_MAPPING):
        os.remove(CSAR_HELM_CHART_MAPPING)


def execute_helmfile_with_build_command(state_values_file, path_to_helmfile):
    '''
    Command to execute the helmfile using the build command
    Inputs:
        state_values_file, state values file to use to pass into the helmfile to populate its details i.e. site values
        path_to_helmfile, Path to the helmfile to test against
    Outputs:
        File that contains all the build info for the helmfile
    '''
    #/usr/bin/helmfile --environment build --state-values-file ./build-environment/tags_true.yaml --file ./helmfile.yaml build > test.yaml
    helmfile_build_stream = os.popen(HELMFILE + ' --environment build --state-values-file ' + state_values_file + ' --file ' + path_to_helmfile + ' build')
    helmfile_build_output = helmfile_build_stream.read()

    # Write the output of the command to file
    helmfile_build_file = open(HELMFILE_BUILD_OUTPUT, "w")
    helmfile_build_file.write(helmfile_build_output)
    helmfile_build_file.close()


def split_content_from_helmfile_build_file():
    '''
    Command to split the content of of the helmfile build command into two seperate file one for CRD and one for the main helmfile
    Inputs:
        HELMFILE_BUILD_OUTPUT, global paramater created within the execute_helmfile_with_build_command function
    Outputs:
        Two file
           compiledContent_crds-helmfile.yaml
           compiledContent_helmfile.yaml
    '''
    filename=""
    start=0
    with open(HELMFILE_BUILD_OUTPUT) as helmfile_build_output:
        for line in helmfile_build_output:
            if "Source" in line:
                filename = line.split('Source: ')[1].rstrip("\n")
                fileContent = open("compiledContent_" + filename, "w")
                start=1
            elif "---" in line:
                if start == 1:
                    fileContent.close()
                start=0
            elif start == 1:
                fileContent.write(line)


def gather_release_and_repo_info(filename, releases_dict, csar_dict, get_all_images):
    '''
    Function used to read the output of the helmfile build and append the appropriate info
    into a dictionary so can be easily consumed later
    Input:
        filename: File that contains the helmfile build output for a given helmfile chart.
        releases_dict: Empty Dictionary for gather all the associated chart details
        csar_dict: Empty dictionary for gathering the releases and there associated CSAR
        get_all_images: Used to check whether you want to include items that are set to false accoding to the state value used.
    Output:
        Dictionary of the release information
    '''
    with open(filename, 'r') as f:
        valuesYaml = yaml.load(f, Loader=yaml.FullLoader)
    for item in valuesYaml['releases']:
        name = item.get('name')
        version = item.get('version')
        chart = item.get('chart')
        namespace = item.get('namespace')
        values = item.get('values')
        installed = item.get('installed')
        #Use the content of the label to build a CSAR list of the files to be created
        labels = item.get('labels')
        if get_all_images == "true":
            if labels != None:
                for key, value in labels.items():
                    if key == 'csar':
                        csar_dict[name] = value
        elif installed:
            if labels != None:
                for key, value in labels.items():
                    if key == 'csar':
                        csar_dict[name] = value
        releases_dict[name] = {}
        releases_dict[name]['name'] = name
        releases_dict[name]['version'] = version
        releases_dict[name]['chart'] = chart
        releases_dict[name]['labels'] = labels
        releases_dict[name]['installed'] = installed
        releases_dict[name]['namespace'] = namespace
        releases_dict[name]['values'] = values
    # Append the repository information for the release
    for item in valuesYaml['repositories']:
        name = item.get('name')
        url = item.get('url')
        if name in releases_dict.keys():
            releases_dict[name]['url'] = url

def fetch_helmfile_charts(releases_dict, csar_dict, csar_list, state_values_file, path_to_helmfile):
    '''
    Function to take the content of the generated JSON and build up the variables for the CSAR build job.
    Input:
        releases_dict: Dictionary Content of the helmfile according the state file inputted
        csar_dict: List of the CSAR to be created
        csar_list: A list of what CSAR the release should be added to
        state_values_file: state values file (site-values.yaml)
        path_to_helmfile: path to the helmfile under test
    Output:
        Required charts downloaded
        File created that can be used by the am package manager to generate the CSAR's using the downloaded charts
    '''
    LOG.info("Adding chart repos from repositories.yaml")
    # Load the repos so the charts can be pulled
    os.system(HELMFILE + " --state-values-file " + state_values_file + " --file " + path_to_helmfile + " repos")

    for key in csar_dict:
        chart = releases_dict[key]['chart']
        version = releases_dict[key]['version']
        LOG.info("Fetching Chart " + chart + " with version " + version + " from artifactory")
        LOG.info(HELM + " pull " + chart + " --version " + version)
        os.system(HELM + " pull " + chart + " --version " + version)
    # Build up a file that can be used to pass the details to the am package manager.
    am_package_manager_prop = open(CSAR_HELM_CHART_MAPPING, "w")
    for item in csar_list:
        csar_name = item.split(':')[0]
        csar_version = item.split(':')[1]
        csar_item_list = []
        for key, value in csar_dict.items():
            if value == csar_name:
                version = releases_dict[key]['version']
                csar_item_list.append(key + "-" + version + ".tgz")
        csar_content = listToString(csar_item_list)
        am_package_manager_prop.write(str(csar_name) + "-" + str(csar_version) + "=" + str(csar_content) + "\n")
    am_package_manager_prop.close()



def generate_csar_content(releases_dict, csar_dict, csar_list):
    '''
    Function to take the content of the generated JSON and build up the variables for the CSAR build job.
    Input:
        releases_dict: Dictionary Content of the helmfile according the state file inputted
        csar_dict: List of the CSAR to be created
        csar_list: A list of what CSAR the release should be added to
    Output:
        artifact.properties that will list the Chart(s), Chart version(s) and Chart repo(s) for all the
        releases in the helmfile which should have a CSAR built
    '''
    artifactProp = open(CSAR_BUILD_PROPERTIES, "w")
    for item in csar_list:
        item = item.split(':')[0]
        csarItemList = []
        for key, value in csar_dict.items():
            if value == item and key != item:
                csarItemList.append(key)
        csarItemList.insert(0, item)
        for entry in ['name','version','url']:
            itemList = []
            for csarItem in csarItemList:
                values = releases_dict.get(csarItem)
                itemDetails = values.get(entry)
                itemList.append(itemDetails)
            CsarContent = listToString(itemList)
            artifactProp.write(str(item) + "_" + str(entry) + "=" + str(CsarContent) + "\n")
    artifactProp.close()


def check_csar_labels(releases_dict, csar_dict, get_all_images):
    # Temporary fix used for helmfiles that don't have the CSAR Label already defined
    # This can be removed at a later stage, current date 17/02/2022
    if not csar_dict:
        csar_dict_temp = { }
        csar_dict_temp.update({
                'eric-tm-ingress-controller-cr-crd':'eric-cloud-native-base',
                'eric-service-mesh-integration':'eric-service-mesh-integration',
                'service-mesh-integration':'service-mesh-integration',
                'eric-eo-so':'eric-eo-so',
                'eric-oss-dmm':'eric-oss-dmm',
                'eric-oss-adc':'eric-oss-adc',
                'eric-oss-pf':'eric-oss-pf',
                'eric-mesh-controller-crd':'eric-cloud-native-base',
                'eric-cncs-oss-config':'eric-cncs-oss-config',
                'eric-cloud-native-base':'eric-cloud-native-base',
                'eric-oss-ericsson-adaptation':'eric-oss-ericsson-adaptation',
                'eric-topology-handling':'eric-topology-handling',
                'eric-oss-common-base':'eric-oss-common-base',
                'eric-oss-app-mgr':'eric-oss-app-mgr',
                'eric-oss-config-handling':'eric-oss-config-handling',
                'eric-oss-uds':'eric-oss-uds',
                'eric-oss-task-automation-ae':'eric-oss-task-automation-ae'
                })
        # Add a check to ensure all the items in the dictionary are in the releases dict. For older helmfiles
        #csar_dict = csar_dict_temp.copy()
        csar_dict.update(csar_dict_temp)
        for key in csar_dict_temp:
            if key not in releases_dict.keys():
               csar_dict.pop(key)

        if get_all_images == "false":
            tmp_csar_dict = csar_dict.copy()
            for key in csar_dict:
                name = releases_dict[key]['name']
                installed = releases_dict[key]['installed']
                if not installed:
                    if name in csar_dict:
                        del tmp_csar_dict[name]
            csar_dict.clear()
            csar_dict.update(tmp_csar_dict)


def fetch_helmfile_details(state_values_file, path_to_helmfile, get_all_images, fetch_charts):
    '''
    Execution stage for all the function calls
    '''
    LOG.info('Inputted Paramaters')
    LOG.info('state_values_file: ' + state_values_file)
    LOG.info('path_to_helmfile: ' + path_to_helmfile)
    LOG.info('get_all_images: ' + get_all_images)
    LOG.info('fetch_charts: ' + fetch_charts)

    clean_up()
    execute_helmfile_with_build_command(state_values_file, path_to_helmfile)
    split_content_from_helmfile_build_file()
    # Generate empty dictionaries
    releases_dict = { }
    csar_dict = { }
    # Generate empty list
    csar_list = []
    # Iterate over all the compiledContent_* files and generate a release Dictionary that holds
    # the chart, version, repo etc. info for all the releases within the Helmfiles
    for filename in os.listdir(CURRENT_WORKING_DIRECTORY):
        if filename.startswith("compiledContent_"):
            gather_release_and_repo_info(filename, releases_dict, csar_dict, get_all_images)

    # Temporary fix used for helmfiles that don't have the CSAR Label already defined
    # This can be removed at a later stage
    check_csar_labels(releases_dict, csar_dict, get_all_images)

    # Print info to the screen
    LOG.info("JSON Final Dict")
    app_json = json.dumps(releases_dict, indent=4, sort_keys=True)
    LOG.info(str(app_json))
    LOG.info("CSAR's to be built")
    for value in csar_dict.values():
        if not any(value in string for string in csar_list):
            version = releases_dict[value]['version']
            csar_list.append(value + ":" + version)
            LOG.info(value + ":" + version)

    # Writing the Full Helmfile JSON to a file for later use
    with open(HELMFILE_JSON, "w") as full_json_file:
       full_json_file.write(app_json)
    full_json_file.close()

    #releases_and_associated_csar_json = json.dumps(csar_dict)
    # Writing the associated CSAR's to releases to a file for later use
    with open(RELEASES_ASSOCIATED_TO_CSARS_JSON, "w") as releases_and_associated_csar_json_file:
       releases_and_associated_csar_json_file.write(json.dumps(csar_dict, indent=4, sort_keys=True))
    releases_and_associated_csar_json_file.close()

    # Write the CSAR's to be created to a file for later use
    with open(CSARS_TO_BUILD,'w') as csar_to_be_built:
        file_content = "\n".join(csar_list)
        csar_to_be_built.write(file_content)
    csar_to_be_built.close()

    # Generate the CSAR build artifact.properties
    generate_csar_content(releases_dict, csar_dict, csar_list)

    # Fetch the charts
    if fetch_charts == 'true':
        fetch_helmfile_charts(releases_dict, csar_dict, csar_list, state_values_file, path_to_helmfile)
