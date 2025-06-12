"""
FlowAI-ICT Core Module v4.5
Fixed version without circular imports
"""

# Import only essential modules without circular dependencies
from . import config

# Version info
__version__ = "4.5"
__author__ = "FlowAI Team"

# Initialize logging
import logging
logger = logging.getLogger(__name__)
logger.info("FlowAI-ICT Core Module initialized")

# DO NOT import telegram_bot here - causes circular import
# All telegram functionality is handled in the main telegram_bot.py file
