"""
Module to configure the logger.
"""

import logging
import os
from typing import Literal, Union

from google.cloud import logging_v2

LogLevelName = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]


def _to_numeric(log_level: Union[int, str, LogLevelName]) -> int:
    """
    Convert log level to numeric if not already given as
    in the numeric form.
    >>> _to_numeric(log_level=20)
    20
    >>> _to_numeric(log_level="DEBUG")
    10
    """
    if isinstance(log_level, int):
        return log_level

    level_name = log_level.upper()
    numeric = getattr(logging, level_name, logging.INFO)
    return int(numeric)


def get_configured_logger(
    *,
    log_level: Union[int, str, LogLevelName] = "INFO",
) -> logging.Logger:
    """
    Uses Cloud Logging if the code runs in
    Cloud Run/Functions (Gen 2) but uses basicConfig
    i.e. the console if run locally.
    If running on the Cloud, the K_SERVICE variable is set.
    Returns a module logger to use throughout the app.
    """
    numeric_level = _to_numeric(log_level)

    if os.getenv("K_SERVICE"):
        client_gcp_logging = logging_v2.Client()
        client_gcp_logging.setup_logging(log_level=numeric_level)
    else:
        logging.basicConfig(
            level=numeric_level,
            format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            force=True,
        )
    logger = logging.getLogger(__name__)
    logger.setLevel(numeric_level)
    return logger
