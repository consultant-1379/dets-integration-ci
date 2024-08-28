"""This module contains a list of utility functions."""


from datetime import datetime
import time
import logging
from pathlib import Path

LOG = logging.getLogger(__name__)


def get_log_level_from_verbosity(verbosity):
    """Return a log level based on a given verbosity number."""
    log_levels = {
        0: logging.CRITICAL,
        1: logging.ERROR,
        2: logging.WARNING,
        3: logging.INFO,
        4: logging.DEBUG
    }
    return log_levels.get(verbosity, "Invalid verbosity level")

def initialize_logging(verbosity, working_directory, logs_sub_directory, filename_postfix):
    """
    Initialize the logging to standard output and standard out at different verbosities.

    Returns the log file path relative to the working directory.
    """
    log_format = "[%(asctime)s] [%(name)s] [%(levelname)s]: %(message)s"
    absolute_log_directory = Path(working_directory) / Path(logs_sub_directory)
    absolute_log_directory.mkdir(parents=True, exist_ok=True)
    relative_log_file_path = str(Path(logs_sub_directory) / datetime.now().strftime(
        '%Y-%m-%dT%H_%M_%S%z_{0}.log'.format(filename_postfix))
                                 )
    absolute_log_file_path = str(Path(working_directory) / Path(relative_log_file_path))
    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(logging.Formatter(log_format))
    stream_handler.setLevel(get_log_level_from_verbosity(verbosity))
    logging.basicConfig(filename=absolute_log_file_path, format=log_format, level=logging.DEBUG)
    logging.getLogger('').addHandler(stream_handler)
    logging.getLogger("kubernetes").setLevel(logging.INFO)
    return relative_log_file_path
