import logging
import time
import sys
from datetime import timedelta
import traceback
import click
import getLatestHelmfileVersion
import check_for_existing_csars
import get_details_from_helmfile
import download_existing_csars
import update_site_values
import utils

LOG = logging.getLogger(__name__)

def log_verbosity_option(func):
    """A decorator for the log verbosity command line argument."""
    return click.option('-v', '--verbosity', type=click.IntRange(0, 4), default=3, show_default=True,
                        help='number for the log level verbosity, 0 lowest, 4 highest'
                        )(func)

def csar_repo_option(func):
    """A decorator for the CSAR artifactory repo url."""
    return click.option('--csar-repo-url', 'csar_repo_url', required=True, type=str,
                        help='A URL, including the path to the directory in artifactory where CSARs are stored for a specific application.'
                        )(func)


def applications_to_check_option(func):
    """A decorator for the for the file that has the list of application to iterate over."""
    return click.option('--applications_to_check', 'applications_to_check', required=True, type=str,
                        help='This should be file with a list of all the application from the helmfile that a CSAR should be checked for.'
                        )(func)


def deployment_tag_list(func):
    """A decorator for the list of tags for the application to iterate over."""
    return click.option('--deployment-tags', 'deployment_tag_list', required=True, type=str,
                        help='This should be a list of the deployment tags which are set to true'
                        )(func)


def state_values_file(func):
    """A decorator for the path to the full values file."""
    return click.option('--state-values-file', 'state_values_file', required=True, type=str,
                        help='This is the full path to the state values file'
                        )(func)

def helmfile_path(func):
    """A decorator for the path to the helmfile under test."""
    return click.option('--path-to-helmfile', 'path_to_helmfile', required=True, type=str,
                        help='This is the full path to the helmfile under test'
                        )(func)

def get_all_images(func):
    """A decorator set a true/false boolean."""
    return click.option('--get-all-images', 'get_all_images', required=True, type=str,
                        help='Set a true or false boolean to state whether to gather all CSAR independent of state values file'
                        )(func)

def fetch_charts(func):
    """A decorator set a true/false boolean."""
    return click.option('--fetch-charts', 'fetch_charts', required=True, type=str,
                        help='Set a true or false boolean this tells the script to download the charts from the helmfile'
                        )(func)

@click.group(context_settings=dict(terminal_width=220))
def cli():
    """The CI Script Executor."""


@cli.command()
@state_values_file
@helmfile_path
@get_all_images
@fetch_charts
@log_verbosity_option
def get_release_details_from_helmfile(state_values_file, path_to_helmfile, get_all_images, fetch_charts, verbosity):
    """Get all the CSAR to be created according to the helmfile and state values passed"""
    log_file_path = utils.initialize_logging(verbosity=verbosity, working_directory='/ci-scripts/', logs_sub_directory='output-files/ci-script-executor-logs', filename_postfix='get_csar_details_from_helmfile')
    LOG.info("Starting To Get Details from Helmfile")
    start_time = time.time()
    exit_code = 0
    try:
        get_details_from_helmfile.fetch_helmfile_details(state_values_file, path_to_helmfile, get_all_images, fetch_charts)
    except Exception as exception:
        LOG.error('Get Details from Helmfile failed with the following error')
        LOG.debug(traceback.format_exc())
        LOG.error(exception)
        LOG.info('Please refer to the following log file for further output: %s', log_file_path)
        exit_code = 1
    else:
        LOG.info('Get CSAR Details from Helmfile completed successfully')
    finally:
        end_time = time.time()
        time_taken = end_time - start_time
        LOG.info('Time Taken: %s', timedelta(seconds=round(time_taken)))
        sys.exit(exit_code)


@cli.command()
@csar_repo_option
@applications_to_check_option
@log_verbosity_option
def check_for_existing_csar(csar_repo_url, applications_to_check, verbosity):
    """Check a specific CSAR repo for a CSAR with a matching version to avoid duplication during CSAR build"""
    log_file_path = utils.initialize_logging(verbosity=verbosity, working_directory='/ci-scripts/', logs_sub_directory='output-files/ci-script-executor-logs', filename_postfix='check_for_existing_csar')
    LOG.info("Starting Check For Existing CSARs")
    start_time = time.time()
    exit_code = 0
    try:
        check_for_existing_csars.check_for_existing_csars_in_repo(csar_repo_url, applications_to_check)
    except Exception as exception:
        LOG.error('Check For Existing CSARs failed with the following error')
        LOG.debug(traceback.format_exc())
        LOG.error(exception)
        LOG.info('Please refer to the following log file for further output: %s', log_file_path)
        exit_code = 1
    else:
        LOG.info('Check For Existing CSARs completed successfully')
    finally:
        end_time = time.time()
        time_taken = end_time - start_time
        LOG.info('Time Taken: %s', timedelta(seconds=round(time_taken)))
        sys.exit(exit_code)


@cli.command()
@csar_repo_option
@applications_to_check_option
@log_verbosity_option
def download_existing_csar(csar_repo_url, applications_to_check, verbosity):
    """Downloads the officialy build CSAR from the CSAR REPO"""
    log_file_path = utils.initialize_logging(verbosity=verbosity, working_directory='/ci-scripts/', logs_sub_directory='output-files/ci-script-executor-logs', filename_postfix='download_existing_csar')
    LOG.info("Starting Download of CSARs")
    start_time = time.time()
    exit_code = 0
    try:
        download_existing_csars.download_existing_csars_from_repo(csar_repo_url, applications_to_check)
    except Exception as exception:
        LOG.error('Download of existing CSARs failed with the following error')
        LOG.debug(traceback.format_exc())
        LOG.error(exception)
        LOG.info('Please refer to the following log file for further output: %s', log_file_path)
        exit_code = 1
    else:
        LOG.info('Download of existing CSARs completed successfully')
    finally:
        end_time = time.time()
        time_taken = end_time - start_time
        LOG.info('Time Taken: %s', timedelta(seconds=round(time_taken)))
        sys.exit(exit_code)


@cli.command()
@state_values_file
@deployment_tag_list
@log_verbosity_option
def set_deployment_tags(state_values_file, deployment_tag_list, verbosity):
    """Set the deployment tags according to the list inputted"""
    log_file_path = utils.initialize_logging(verbosity=verbosity, working_directory='/ci-scripts/', logs_sub_directory='output-files/ci-script-executor-logs', filename_postfix='update_site_values')
    LOG.info("Starting to set the deployment tags")
    start_time = time.time()
    exit_code = 0
    try:
        update_site_values.set_deployment_tags(state_values_file, deployment_tag_list)
    except Exception as exception:
        LOG.error('Setting the deployment tags failed with the following error')
        LOG.debug(traceback.format_exc())
        LOG.error(exception)
        LOG.info('Please refer to the following log file for further output: %s', log_file_path)
        exit_code = 1
    else:
        LOG.info('Set deployment tags completed successfully')
    finally:
        end_time = time.time()
        time_taken = end_time - start_time
        LOG.info('Time Taken: %s', timedelta(seconds=round(time_taken)))
        sys.exit(exit_code)


@cli.command()
@log_verbosity_option
def get_latest_helmfile_version(verbosity):
    """Get the latest helmfile version from the specified repo"""
    log_file_path = utils.initialize_logging(verbosity=verbosity, working_directory='/ci-scripts/', logs_sub_directory='output-files/ci-script-executor-logs', filename_postfix='get_latest_helmfile_version')
    LOG.info("Starting Get Latest Helmfile Version")
    start_time = time.time()
    exit_code = 0
    try:
        getLatestHelmfileVersion.get_latest_helmfile_version_from_repo()
    except Exception as exception:
        LOG.error('Get Latest Helmfile Version failed with the following error')
        LOG.debug(traceback.format_exc())
        LOG.error(exception)
        LOG.info('Please refer to the following log file for further output: %s', log_file_path)
        exit_code = 1
    else:
        LOG.info('Get Latest Helmfile Version completed successfully')
    finally:
        end_time = time.time()
        time_taken = end_time - start_time
        LOG.info('Time Taken: %s', timedelta(seconds=round(time_taken)))
        sys.exit(exit_code)
