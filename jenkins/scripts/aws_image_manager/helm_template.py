import yaml
import logging
from aws_image_manager import utils


class HelmTemplate(object):
    """This class contains methods for retrieving information from the rendered chart."""

    def __init__(self, helm_template):
        self.helm_template = helm_template

    def __load_into_yaml(self):
        # logging.debug(f"===> helmfile template output:\n{str(helm_template)}")
        return yaml.load_all(self.helm_template.decode('utf-8').replace('\t', ' ').rstrip(),
                             Loader=yaml.SafeLoader)

    def get_all_images(self):
        images = set()
        keys=["image","proxyImage"]
        logging.info(f"Looking for the following keys: {keys}")
        for template in self.__load_into_yaml():
            utils.extract_data(keys=keys, wanted_type=str, data=template, result_set=images)
        logging.info("Images are: " + str(images))
        return images