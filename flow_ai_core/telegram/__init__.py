from .admin_menu import setup_admin_handlers
from .user_menu import setup_user_handlers

def setup_telegram_handlers(dispatcher):
    """راه‌اندازی تمام handler های تلگرام"""
    setup_admin_handlers(dispatcher)
    setup_user_handlers(dispatcher)
