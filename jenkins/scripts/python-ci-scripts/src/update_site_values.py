import logging
import oyaml as yaml  # pip install oyaml

LOG = logging.getLogger(__name__)


def set_deployment_tags(state_values_file, deployment_tag_list):
    LOG.info('Set true for such tags: "%s"', deployment_tag_list)

    with open(state_values_file, 'r') as stream:
        parsed_yaml = yaml.safe_load(stream)

    for tag in deployment_tag_list.split(' '):
        if tag in parsed_yaml['tags']:
            parsed_yaml['tags'][tag] = True
        else:
            raise Exception('There is no such tag "{}" in yaml file'.format(tag))

    LOG.info('Parsed yaml file:\n %s', yaml.dump(parsed_yaml))

    with open(state_values_file, 'w') as yaml_file:
        yaml.dump(parsed_yaml, yaml_file, allow_unicode=True)
