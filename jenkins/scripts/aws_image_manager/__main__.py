import argparse
import logging
from functools import partial
from aws_image_manager import utils
from aws_image_manager import image_manager
import os
import configparser
script_dir = os.path.dirname(os.path.abspath(__file__))
config_file = script_dir + '/' + 'config.ini'


def check_helm_arguments(args):
    if not args.helm :
        raise ValueError("--helm is required")
    if args.helm is not None:
        for helm in args.helm:
            if not os.path.exists(helm):
                raise ValueError("The specified helm chart, " + helm + ", doesn't exist")


def aws_image_handler(args):
    logging.debug('Args: ' + str(args))
    check_helm_arguments(args)
    images = image_manager.__get_images(args, skip_scalar=True)
    utils.retry_func(partial(image_manager.__login_repo, args.aws_repo, args.aws_region), max_retry=3)
    image_manager.__check_create_repo(images, args.aws_repo, args.aws_region)
    config = configparser.ConfigParser()
    config.read(config_file)
    e_list = config['IMAGES']['EXCLUDE'].split(',')
    for image in images:
        image_name = image.__str__().split('/')[-1].split(':')[0]
        if image_name in e_list:
            continue
        image_manager.__pull_images(image)
        utils.retry_func(partial(image_manager.__push_images, image, args.aws_repo), max_retry=3)


def parse_args():
    """
    entry point
    """
    parser = argparse.ArgumentParser(description='AWS Image Manager ')

    parser.add_argument(
        '-hm',
        '--helm',
        help='''One or more Helm charts to use to generate image list.
        This can be absolute paths or relative to the the current folder''',
        nargs='*',
        type=str
    )
    parser.add_argument(
        '-l',
        '--log',
        help='Change the logging level for this execution, default is INFO',
        default="INFO"
    )
    parser.add_argument(
        '--set',
        help='Values to be passed to the helm template during image list populate',
        nargs='*'
    )
    parser.add_argument(
        '-f',
        '--values',
        help='Yaml file containing values to be passed to the helm template',
        nargs='*'
    )
    parser.add_argument(
        '--aws_repo',
        help='AWS ECR registry url where the images will be pushed on AWS',
    )
    parser.add_argument(
        '--aws_region',
        help='AWS region where ECR registry is located',
    )
    return parser.parse_args()


def __configure_logging(logging, level):
    logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=level.upper())


def main():
    args = parse_args()
    __configure_logging(logging, args.log)
    aws_image_handler(args)


if __name__ == '__main__':
    main()
