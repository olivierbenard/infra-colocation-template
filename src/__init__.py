"""
Initializing module to configure logger.
"""

import os

from src.logger_setup import _to_numeric, get_configured_logger

LOG_LEVEL_STR = os.getenv("LOG_LEVEL", "INFO").upper()
LOG_LEVEL = _to_numeric(LOG_LEVEL_STR)
logger = get_configured_logger(log_level=LOG_LEVEL)
