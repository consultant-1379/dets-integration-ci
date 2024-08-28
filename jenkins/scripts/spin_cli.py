import os
import re
import sys
import json
import logging
import pathlib
import argparse
import datetime
import subprocess
LOG = logging.getLogger('spin_cli')


def log_path(name: str) -> str:
    """ Check if triggered Takes in name of the log file we are going to create prefixed by date. """
    absolute_log_directory = pathlib.Path.cwd() / pathlib.Path('logs')
    absolute_log_directory.mkdir(parents=True, exist_ok=True)
    return str(pathlib.Path(absolute_log_directory) / datetime.datetime.now().strftime('%Y-%m-%dT%H_%M_%S%z_{0}.log'.format(name)))


def initialize_logging(name: str) -> str:
    """ Create logger with given name and return a logger. """
    log_format = "[%(asctime)s] [%(name)s] [%(levelname)s]: %(message)s"
    log_file_path = log_path(name)
    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(logging.Formatter(log_format))
    stream_handler.setLevel(('DEBUG'))
    logging.basicConfig(filename=log_file_path, format=log_format, level=logging.DEBUG)
    logging.getLogger('').addHandler(stream_handler)
    return logging.getLogger('')


def execute_command(command: str) -> (str or Exception):
    """ Command to be executed and return 0 if command was successful otherwise 1. """
    LOG.info(f"Executing command - {command}")
    proc = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    stdout_value = proc.communicate()[0].decode("utf-8").rstrip()
    LOG.info(f"Command output = {stdout_value}")
    return_value = proc.returncode
    LOG.info(f"Return code = {return_value}")
    if return_value != 0:
        raise Exception(f"Failed to execute command - {command}. Error is - {stdout_value}")
    return stdout_value


def inject_variables(json_file: str, vars_dict: dict) -> None:
    """ Function to load variables.json file, populate template or pipeline file with variable substitution."""
    LOG.info(f"---------- Injecting variables values into {json_file} ----------")
    with open(json_file, 'r') as file:
        content = file.read()
    for var_name in set(re.findall(r"var\.[a-z]{1}[a-z_0-9]*", content)):
        LOG.info(f"Replacing the variable {var_name} with value ----> {vars_dict[var_name]['defaultValue']}")
        content = content.replace(f"${{ {var_name} }}", vars_dict[var_name]['defaultValue'])
    with open(json_file, 'w') as file:
        file.write(content)


def get_folder_contents(folder_name: str) -> list:
    """ Takes in relative folder name and return a listing of the folder content. """
    return list([os.path.relpath(os.path.join(dirpath, file), os.getcwd()) for (dirpath, dirnames, filenames) in os.walk(folder_name) for file in filenames])


def git_diff(reg_exp: str) -> list:
    """ Take in Regular expression, perform git diff-tree to get list of files added, modifed or deleted, return result. """
    cmd = f'git diff-tree --no-commit-id --name-status -r {os.environ["GIT_COMMIT"]} | grep {reg_exp} | egrep "spinnaker/|spin_cli.py" | cut -f2'
    return execute_command(cmd).splitlines()


def add_parent_child_dependencies(mod_files_dict: dict) -> dict:
    """ Take in modified template/pipelines and gets either child or parent dependency for plan mode, adds to exisiting dictionary and returns it. """
    LOG.info(f"---------- Adding additional dependencies for plan mode ----------")
    for key_name, set_of_files in sorted(mod_files_dict.items()):
        for file in set_of_files:
            additional_dependencies = list(filter(lambda file_name: key_name not in file_name, get_folder_contents(os.path.dirname(file))))
            if 'template' in key_name:
                mod_files_dict['pipeline'] = list(set().union(mod_files_dict['pipeline'], additional_dependencies))
            else:
                mod_files_dict['template'] = list(set().union(mod_files_dict['template'], additional_dependencies))
    return mod_files_dict


def get_modified_templates_pipelines(args: argparse.Namespace) -> dict:
    """ Get files in commit and return two dictionarys of templates, pipelines files modified. """
    mod_files = git_diff("^[^D]")
    mod_files_dict = {}
    reg_exp = re.compile(r".*variables\.json|.*spin_cli\.py")
    if any(reg_exp.match(file_name) for file_name in mod_files):
        spinnaker_files = get_folder_contents("spinnaker")
        for file_type in ['template', 'pipeline']:
            mod_files_dict[file_type] = list(filter(lambda file_name: file_type in file_name, spinnaker_files))
    else:
        for file_type in ['template', 'pipeline']:
            mod_files_dict[file_type] = list(filter(lambda file_name: file_type in file_name, mod_files))
        if args.plan:
            mod_files_dict = add_parent_child_dependencies(mod_files_dict)
    return mod_files_dict


def prepare_files(args: argparse.Namespace) -> dict:
    """ Loop through modified spinnaker files and inject variables and return 2 dictionarys of templates, pipelines with injected variables. """
    mod_files_dict  = get_modified_templates_pipelines(args)
    with open('spinnaker/variables/variables.json', 'r') as vars_file:
        vars_dict = {}
        list(filter(lambda var: vars_dict.update(var[0]), (value for _, value in json.load(vars_file).items())))
        for file_type in ['template', 'pipeline']:
            for file in mod_files_dict[file_type]:
               inject_variables(file, vars_dict)
    return mod_files_dict


def determine_action(file_name: str, mode: str) -> str:
    """ Takes in a file name (i.e. template or pipeline file) with the spin mode and determines action and returns that command. """
    if ('plan' in mode or 'save' in mode) and ('template' in file_name):
        return f"-template save --file {file_name}"
    elif 'plan' in mode and 'pipeline' in file_name:
        return f"-template plan --file {file_name} > {file_name.split('/')[-1]}"
    elif 'save' in mode and 'pipeline' in file_name:
        return f" save --file {file_name}"


def execute(file_dict: dict, reverse: bool, mode: str) -> None:
    """ Take in dictionary of templates and pipelines file and executes spin command on them based on file type and spin mode (i.e. plan or save). """
    for _, set_of_files in sorted(file_dict.items(), reverse=reverse):
        for file in set_of_files:
            execute_command(f"spin pipeline{determine_action(file, mode)}")


def create_app_test_folder() -> str:
    """ Create commiters own application folder on spinnaker in the form {commiter-id}-app-test-folder if it does not exist and returns folder name. """
    app_test_folder = f'{os.getenv("GERRIT_CHANGE_OWNER_EMAIL", os.getenv("GERRIT_EVENT_ACCOUNT_EMAIL", "idunaas")).split("@")[0]}-app-test-folder'
    if not app_test_folder in execute_command('spin application list'):
        try:
            LOG.info(f"Creating application test folder {app_test_folder}")
            execute_command(f"spin application save -a {app_test_folder} --owner-email pdlteammuo@pdl.internal.ericsson.com --cloud-providers [kubernetes]")
        except Exception as err:
            _, value, _ = sys.exc_info()
            if 'RetrofitError' not in str(value):
                raise Exception(f"Problem creating Spinnaker {app_test_folder} application folder. Existing script.")
    return app_test_folder


def update_planned_files_meta_info(app_test_folder: str, mod_files_dict: dict) -> None:
    """ Update planned templates/pipelines with test meta information so we don't overwrite live templates/pipelines. """
    for key_name, set_of_files in sorted(mod_files_dict.items()):
         for file in set_of_files:
             with open(file, 'r') as file_in:
                 data = json.load(file_in)
             if 'template' in key_name:
                 data['id'] += f"-{os.environ['BUILD_ID']}"
                 data['metadata']['name'] += f"-{os.environ['BUILD_ID']}"
                 data['metadata']['scopes'].append(app_test_folder)
             elif 'pipeline' in key_name:
                 data['application'] = app_test_folder
                 data['template']['reference'] = ":".join(f"{data['template']['reference']}".split(':', 2)[:2]) + f"-{os.environ['BUILD_ID']}:latest"
             with open(file, 'w') as file_out:
                 json.dump(data, file_out, indent=4)


def spin_plan(app_test_folder: str, mod_files_dict: dict) -> None:
    """ Loop through dictionary, executing spin save for templates and spin plan for pipelines. """
    update_planned_files_meta_info(app_test_folder, mod_files_dict)
    LOG.info(f"Templates and Pipelines for updating: {json.dumps(mod_files_dict, sort_keys=True, indent=4)}")
    execute(mod_files_dict, True, 'plan')
    execute((lambda d: d.pop('template') and d)(mod_files_dict), True, 'save')


def spin_save(mod_files_dict: dict) -> None:
    """ Loop through dictionary, push updates to spinnaker. """
    LOG.info(f"Templates and Pipelines for updating: {json.dumps(mod_files_dict, sort_keys=True, indent=4)}")
    execute(mod_files_dict, True, 'save')


def process_cmd_line_args():
    """ Function to process command line arguments and returns tuple with parameters provided to the script. """
    parser = argparse.ArgumentParser(description='Execute spin plan or spin save on templates and pipelines.\n')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--plan', action='store_true')
    group.add_argument('--save', action='store_true')
    return parser.parse_args()


def main():
    """ Creates logger, prepares modified files and executes either spin plan or spin save. """
    global logger
    try:
        logger = initialize_logging("spin_cli")
        args = process_cmd_line_args()
        mod_files_dict = prepare_files(args)
        LOG.info(mod_files_dict)
        if args.save:
            spin_save(mod_files_dict)
        elif args.plan:
            spin_plan(create_app_test_folder(), mod_files_dict)
        exit(0)
    except json.JSONDecodeError as err:
        LOG.error(f"JSONDecodeError detected: line: {err.lineno}, file: {err.doc}, error: {err.msg}")
    except KeyError or TypeError or ValueError as err:
        LOG.error(f"KeyError, ValueError or TypeError detected: {err}")
    except OSError as err:
        LOG.error(f"File error detected, err code: {err.errno}, error: {err.strerror}")
    except Exception as err:
        LOG.error(f"General Error occurred - {err}")
        LOG.debug(err, exc_info=True)
    exit(1)


if __name__ == '__main__':
    main()