import logging
import time
import yaml

class CustomError(Exception):
    def __init__(self, m):
        self.message = m
    def __str__(self):
        return self.message


def retry_func(func, max_retry=1):
    for retry in range(1, max_retry + 2):
        try:
            return func()
        except CustomError as err:
            logging.info('Failed execution, attempting again')
            time.sleep(30)
    else:
        raise CustomError('Max retries over, {}'.format(func))


def yaml_safe_load_wrapper(data):
    """Call yaml.safe_load() and return None on error (without any Exception)"""
    d = None
    try:
        d = yaml.safe_load(data)
    except:
        pass
    return d

def extract_data(keys, wanted_type, data, result_set):
    if type(data) is dict:
        for k, v in data.items():
            if k in keys and isinstance(v, wanted_type):
                result_set.add(v)
            elif type(v) is str:
                d = yaml_safe_load_wrapper(v)
                extract_data(keys, wanted_type, d, result_set)
            else:
                extract_data(keys, wanted_type, data[k], result_set)
    elif type(data) is list:
        for i in data:
            extract_data(keys, wanted_type, i, result_set)

## The function extract_data() replace the old find_key_in_dictionary() [see IDUN-24837]
## however the old function is still down here (commented) to make easier the test
## of the old code (it can come in handy in the future to check regression bugs)
##
# def find_key_in_dictionary(input_keys, wanted_type, dictionary):
#     if hasattr(dictionary, 'items'):
#         for k, v in dictionary.items():
#             if k in input_keys and isinstance(v, wanted_type):
#                 yield v
#             if isinstance(v, dict):
#                 yield from find_key_in_dictionary(input_keys, wanted_type, v)
#             elif isinstance(v, list):
#                 for item in v:
#                     yield from find_key_in_dictionary(input_keys, wanted_type, item)
#             elif isinstance(v, str):
#                 data = None
#                 try:
#                     data = yaml.safe_load(v)
#                 except:
#                     pass
#                 if isinstance(data, dict):
#                     yield from find_key_in_dictionary(input_keys, wanted_type, data)

def replace_original_repo_with_ECR(image_repo, aws_repo):
    image_path = image_repo.split('/')
    image_path[0] = aws_repo
    aws_image_repo = '/'.join(image_path)
    return aws_image_repo