"""
FlowAI ICT Trading Bot Core Module
Advanced AI-Powered Gold Trading System
"""

__version__ = "2.0.0"
__author__ = "Behnam RJD"
__description__ = "FlowAI XAU Trading Bot - Advanced AI-Powered Gold Trading System"

# Core modules
from . import config
from . import data_handler
from . import ict_analysis
from . import telegram_bot
from . import utils

__all__ = [
    'config',
    'data_handler', 
    'ict_analysis',
    'telegram_bot',
    'utils'
]
