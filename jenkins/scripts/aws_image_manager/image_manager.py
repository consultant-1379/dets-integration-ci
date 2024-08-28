#!/usr/bin/python
from base64 import b64decode
import base64
import docker
import boto3
import logging
from pathlib import Path
from subprocess import Popen, PIPE
from aws_image_manager.utils import CustomError
from aws_image_manager import utils
from aws_image_manager.helm_template import HelmTemplate
from aws_image_manager.image import Image

try:
    from yaml import CLoader as Loader
except ImportError:
    from yaml import Loader
from yaml import load
import re

USER_HOME = str(Path.home())


def __set__command(helm, set_parameters):
    fullCommand = []
    start_cmd = ('helmfile -f ' + helm)
    fullCommand.append(start_cmd)
    #if values:
    #    fullCommand.append(' --values ' + ','.join(values))
    if set_parameters:
        fullCommand.append(' --state-values-file ' + ','.join(set_parameters))
        fullCommand.append(' template')
    if not set_parameters :
        logging.warning("""This is adding ' --set ingress.hostname=a' to the helm template command, if you have not specified any set/values.
                           """)
        fullCommand.append(' --set ingress.hostname=a')
    return ''.join(fullCommand)


def __get_images(args, skip_scalar=False):
    chart = args.helm
    image_list = set()
    for chart in chart:
        command = __set__command(chart, args.set)
        logging.info('Command is: ' + str(command))
        helm_template = Popen(command, shell=True, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        helm_template_output, err = helm_template.communicate()
        logging.info('Return code is: ' + str(helm_template.returncode))
        if helm_template.returncode:
            logging.error(
                'An error has occurred. The output sent to the stderr from the command is:\n'+
                err.decode('utf-8'))
            raise EnvironmentError('Command "{}" failed with error code {}'.format(
                                        str(command), str(helm_template.returncode)))
        image_list.update(__parse_helm_template(helm_template_output))
        if __images_in_scalar_values(helm_template_output.decode('utf-8')) and not skip_scalar:
            images_from_scalar_values = __handle_images_in_scalar_values(chart)
            if len(images_from_scalar_values) == 0:
                 logging.warning(
                    "Could not parse the image urls from the values.yaml file at root of chart. Please check the logs below to ensure all images have been packaged into the csar")
            image_list.update(images_from_scalar_values)
    image_list.add(Image(repo="armdocker.rnd.ericsson.se/proj-eo/common/deployment-manager", tag="latest"))
    return image_list


def __images_in_scalar_values(helm_template_output):
    """
    This method gets the "image:" lines from the helm template output and checks to see if any line contains {{
    :param helm_template_output:
    :return: True if the image tags contain {{
    """
    return [line for line in re.findall(".*image:.*", helm_template_output) if "{{" in line]


def __handle_images_in_scalar_values(helm_chart):
    logging.info(
        "Helm template contains images in a scalar value, will parse the values file for the remaining images")
    command = ("helm show values " + helm_chart)
    logging.info("Command is: " + command)
    helm_inspect = Popen(command, shell=True, stdin=PIPE, stdout=PIPE, stderr=PIPE)
    values, err = helm_inspect.communicate()
    if str(err):
        raise EnvironmentError('Helm command failed with error message: {0}'.format(str(err)))
    return __parse_values_file_for_images(values)


def __parse_values_file_for_images(values_file_contents):
    """
    :param values_file_contents: the contents of the values file from the integration helm chart
    :return: a list of Images
    """
    data = load(values_file_contents, Loader=Loader)
    global_root = data.get('global')
    if global_root is None:
        logging.warning("Could not find global in the values.yaml file")
        return set()
    registry = global_root.get('registry')
    if registry is None:
        logging.warning("Could not find global.registry in the values.yaml file")
        return set()
    global_registry_url = registry.get('url')
    if global_registry_url is None:
        logging.warning("Could not find global.registry.url in the values.yaml file")
        return set()
    logging.info("Global registry url is: " + global_registry_url)
    image_list = set()
    for key in data.keys():
        if key != 'global':
            sub_chart = data.get(key)
            image_credentials = sub_chart.get('imageCredentials')
            if image_credentials is None:
                logging.warning("Could not find imageCredentials in " + str(key))
                continue
            repo_path = image_credentials.get('repoPath')
            if repo_path is None:
                logging.warning("Could not find repoPath in " + str(key))
                continue
            logging.info("Repo path is: " + repo_path)
            for sub_key in sub_chart.keys():
                __look_for_images(global_registry_url, image_list, repo_path, sub_chart, sub_key)
    return image_list


def __look_for_images(global_registry_url, image_list, repo_path, sub_chart, sub_key):
    """
    :param global_registry_url: the parsed global registry url to be used
    :param image_list: the list of images to populate
    :param repo_path: the parsed repo path to be used
    :param sub_chart: the parent section of the values file
    :param sub_key: the key of the parent section of the values file
    :return: a list of images
    """
    if sub_key == 'images':
        images = sub_chart.get(sub_key)
        for images_key in images.keys():
            name = images.get(images_key).get('name')
            if name is None:
                logging.warning("Could not find name in " + images_key)
                continue
            repo = global_registry_url + '/' + repo_path + '/' + name
            tag = images.get(images_key).get('tag')
            if tag is None:
                logging.warning("Could not find tag in " + images_key)
                continue
            image = Image(repo=repo, tag=tag)
            logging.info('Repo is: ' + str(image))
            image_list.add(image)


def __parse_helm_template(helm_template):
    helm_template_obj = HelmTemplate(helm_template)
    return __extract_image_information(helm_template_obj.get_all_images())


def __extract_image_information(images):
    image_list = []
    for image in images:
        stripped = image.strip()
        if not stripped:
            continue
        split = stripped.split(':', 1)
        if len(split) > 1:
            __image = Image(repo=split[0], tag=split[1])
        else:
            __image = Image(repo=split[0])
        logging.info('Repo is: ' + __image.__str__())
        image_list.append(__image)
    return image_list


def __pull_images(image):
    """Pull images from local registry"""
    client = docker.from_env(timeout=int(600))
    logging.info("Pulling {0}".format(image.__str__()))
    client.images.pull(repository=image.repo, tag=image.tag, decode=True)
    logging.info("Completed pulling image {}".format(image.__str__()))
    client.close()


def __tag_images(image, aws_image_repo):
    """Tag armdocker images with ECR registry"""
    client = docker.from_env(timeout=int(600))
    client.images.get(image).tag(aws_image_repo)
    client.close()


def __push_images(image, aws_repo):
    """Push images to ECR registry"""
    client = docker.from_env(timeout=int(600))
    aws_image_repo = utils.replace_original_repo_with_ECR(image.repo, aws_repo)
    logging.info("tagging the image {0} with ECR repo".format(image.__str__()))
    client.images.get(image.__str__()).tag(repository=aws_image_repo, tag=image.tag )
    logging.info("Pushing {0}:{1}".format(aws_image_repo, image.tag))
    docker_server_output = client.images.push(repository=aws_image_repo, tag=image.tag, stream=True, decode=True)
    for server_output in docker_server_output:
        logging.debug(server_output)
        if 'error' in server_output.keys():
            __handle_push_error(repository=aws_image_repo, server_output=server_output)
    logging.info("Completed pushing image {0}/{1}".format(aws_image_repo, image.tag))
    client.close()


def __handle_push_error(repository, server_output):
    """Handle an error during push to docker registry."""

    error_message = ("There has been a problem while pushing {} to the registry.\n"
                     "The response from the server was:\n{}").format(repository, server_output)
    if 'Client.Timeout' in server_output['error']:
        raise CustomError('Timeout')
    if server_output['error'] == 'received unexpected HTTP status: 500 Internal Server Error':
        error_message += ("\nOne known reason for this error is if the registry no longer "
                          "has space to store images.")
    raise CustomError(error_message)


def __check_create_repo(images, aws_repo, aws_region):
    """Check and create if repository does not exist in ECR.
    :param image objects,  aws ecr adress,  aws region:
    :return:
    """
    aws_list = [ ]
    arm_set = set()
    registryid = aws_repo.split('.')[0]
    logging.info(" Building list of images in armdocker")
    for image in images:
        aws_image_repo = utils.replace_original_repo_with_ECR(image.repo, aws_repo)
        arm_set.add(aws_image_repo)
    logging.info(" Building list of repositories in ECR")
    session = boto3.Session(region_name=aws_region)
    ecr = session.client('ecr')
    response = ecr.describe_repositories(registryId=registryid , maxResults=300)
    for repo in response['repositories']:
        aws_list.append(repo['repositoryUri'])
    logging.info(" Checking if corresponding repo exist in ECR and then create")
    for repo in arm_set:
        if repo not in aws_list:
            logging.info("{0} does not exist".format(repo))
            repository = repo.split('/', 1)[1]
            __create_repo(repo=repository, aws_region=aws_region)


def __create_repo(repo, aws_region):
    """Create repository in ECR"""
    session = boto3.Session(region_name=aws_region)
    ecr = session.client('ecr')
    logging.info(" Creating new repository {} in ECR".format(repo))
    ecr.create_repository(
        repositoryName=repo
       )
    logging.info("new repository {} created in ECR".format(repo))
    return


def __login_repo(aws_repo, aws_region):
    """Login to ECR, obtain token and create docker config file"""
    client = docker.from_env(timeout=int(600))
    session = boto3.Session(region_name=aws_region)
    ecr = session.client('ecr')
    auth = ecr.get_authorization_token()
    token = auth["authorizationData"][0]["authorizationToken"]
    username, password = b64decode(token).decode('ascii').split(':')
    aws_repo_url = 'https://' + aws_repo
    docker_config_json = create_docker_config_json(aws_repo_url, username, password)
    create_docker_config_json_file(docker_config_json=docker_config_json)
    try:
        client.login(username=username, password=password, registry=aws_repo)
    except docker.errors.APIError:
        raise CustomError('Timeout')


def create_docker_config_json(registry_url, registry_user, registry_password):
    """Create a docker config json."""
    docker_config_json = '"auths":{"%s":{"username":"%s","password":"%s","auth":"%s"},' % \
                         (registry_url, registry_user, registry_password,
                          base64_encoder("%s:%s" % (registry_user, registry_password)))
    return docker_config_json


def base64_encoder(unencoded_value):
    """Encode a string to base64 string."""
    return base64.b64encode(unencoded_value.encode()).decode('utf-8')


def create_docker_config_json_file(docker_config_json):
    """Write the docker config."""
    docker_config_json_file_path = '{0}/.docker/config.json'.format(USER_HOME)
    logging.info("Creating docker config file at {0}".format(docker_config_json_file_path))
    Path(docker_config_json_file_path).parent.mkdir(parents=True, exist_ok=True)
    with open(docker_config_json_file_path, "r") as configf:
        configf_data = configf.read()
    configf_data = configf_data.replace('"auths": {', docker_config_json)
    with open(docker_config_json_file_path, "w") as configf:
        configf.write(configf_data)
