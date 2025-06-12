import os
import logging
from typing import Union, List
from dotenv import load_dotenv

# بارگذاری متغیرهای محیطی
load_dotenv()

# تنظیم logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_env_var(key: str, default: Union[str, int, float, bool] = None, var_type: type = str):
    """دریافت متغیر محیطی با تبدیل نوع"""
    value = os.getenv(key, default)
    
    if var_type == bool:
        return str(value).lower() in ('true', '1', 'yes', 'on')
    elif var_type == int:
        try:
            return int(value)
        except (ValueError, TypeError):
            return default if default is not None else 0
    elif var_type == float:
        try:
            return float(value)
        except (ValueError, TypeError):
            return default if default is not None else 0.0
    elif var_type == list:
        if isinstance(value, str):
            return [item.strip() for item in value.split(',') if item.strip()]
        return default if default is not None else []
    
    return str(value) if value is not None else default

# ===== TELEGRAM CONFIGURATION =====
TELEGRAM_BOT_TOKEN = get_env_var('TELEGRAM_BOT_TOKEN')
TELEGRAM_ADMIN_IDS_RAW = get_env_var('TELEGRAM_ADMIN_IDS', '', var_type=list)
TELEGRAM_PREMIUM_USERS_RAW = get_env_var('TELEGRAM_PREMIUM_USERS', '', var_type=list)

TELEGRAM_ADMIN_IDS = []
TELEGRAM_PREMIUM_USERS = []
_admin_ids_conversion_error = False

# تبدیل به integer برای Admin IDs
if TELEGRAM_ADMIN_IDS_RAW: # فقط اگر رشته خالی نباشد تلاش کن
    try:
        TELEGRAM_ADMIN_IDS = [int(id_str) for id_str in TELEGRAM_ADMIN_IDS_RAW if id_str.strip()]
    except ValueError:
        logger.error("Invalid format for TELEGRAM_ADMIN_IDS in .env file. Expected comma-separated integers.")
        _admin_ids_conversion_error = True
        # TELEGRAM_ADMIN_IDS will remain empty as initialized

# تبدیل به integer برای Premium Users
if TELEGRAM_PREMIUM_USERS_RAW: # فقط اگر رشته خالی نباشد تلاش کن
    try:
        TELEGRAM_PREMIUM_USERS = [int(id_str) for id_str in TELEGRAM_PREMIUM_USERS_RAW if id_str.strip()]
    except ValueError:
        logger.warning("Invalid format for TELEGRAM_PREMIUM_USERS in .env file. Expected comma-separated integers. Premium users list will be empty.")
        TELEGRAM_PREMIUM_USERS = [] # Ensure it's empty on error

# ===== BRSAPI CONFIGURATION =====
BRSAPI_KEY = get_env_var('BRSAPI_KEY', 'FreeQZdOYW6D3nNv95jZ9BcYXJHzTJpf')
BRSAPI_DAILY_LIMIT = get_env_var('BRSAPI_DAILY_LIMIT', 10000, var_type=int)
BRSAPI_MINUTE_LIMIT = get_env_var('BRSAPI_MINUTE_LIMIT', 60, var_type=int)

# ===== ICT TRADING CONFIGURATION =====
# Higher Time Frame settings
HTF_TIMEFRAMES = get_env_var('HTF_TIMEFRAMES', '1d,4h', var_type=list)
LTF_TIMEFRAME = get_env_var('LTF_TIMEFRAME', '1h')

# ICT Strategy Parameters
ICT_ENABLED = get_env_var('ICT_ENABLED', True, var_type=bool)
ORDER_BLOCK_DETECTION = get_env_var('ORDER_BLOCK_DETECTION', True, var_type=bool)
FAIR_VALUE_GAP_DETECTION = get_env_var('FAIR_VALUE_GAP_DETECTION', True, var_type=bool)
LIQUIDITY_SWEEP_DETECTION = get_env_var('LIQUIDITY_SWEEP_DETECTION', True, var_type=bool)

# ICT Risk Management
ICT_RISK_PER_TRADE = get_env_var('ICT_RISK_PER_TRADE', 0.02, var_type=float)  # 2%
ICT_MAX_DAILY_RISK = get_env_var('ICT_MAX_DAILY_RISK', 0.05, var_type=float)  # 5%
ICT_RR_RATIO = get_env_var('ICT_RR_RATIO', 2.0, var_type=float)  # 1:2 Risk/Reward

# ===== AI MODEL CONFIGURATION =====
# Defaulting to False as model.pkl is not currently in use or provided.
AI_MODEL_ENABLED = get_env_var('AI_MODEL_ENABLED', False, var_type=bool)
AI_MODEL_PATH = get_env_var('AI_MODEL_PATH', 'models/flowai_model.pkl')
AI_CONFIDENCE_THRESHOLD = get_env_var('AI_CONFIDENCE_THRESHOLD', 0.7, var_type=float)
AI_RETRAIN_INTERVAL = get_env_var('AI_RETRAIN_INTERVAL', 24, var_type=int)  # hours

# ===== PRICE ENGINE CONFIGURATION =====
PRICE_ENGINE_PRIMARY = get_env_var('PRICE_ENGINE_PRIMARY', 'BrsAPI')
PRICE_ENGINE_FALLBACK = get_env_var('PRICE_ENGINE_FALLBACK', 'GoldAPI')
PRICE_VALIDATION_ENABLED = get_env_var('PRICE_VALIDATION_ENABLED', True, var_type=bool)
PRICE_HISTORY_LIMIT = get_env_var('PRICE_HISTORY_LIMIT', 1000, var_type=int)

# ===== SIGNAL GENERATION CONFIGURATION =====
SIGNAL_GENERATION_ENABLED = get_env_var('SIGNAL_GENERATION_ENABLED', True, var_type=bool)
SIGNAL_CHECK_INTERVAL = get_env_var('SIGNAL_CHECK_INTERVAL', 300, var_type=int)  # seconds
SIGNAL_MIN_CONFIDENCE = get_env_var('SIGNAL_MIN_CONFIDENCE', 0.6, var_type=float)
SIGNAL_COOLDOWN = get_env_var('SIGNAL_COOLDOWN', 300, var_type=int)  # seconds

# ===== MARKET HOURS CONFIGURATION =====
MARKET_START_HOUR = get_env_var('MARKET_START_HOUR', 13, var_type=int)  # GMT
MARKET_END_HOUR = get_env_var('MARKET_END_HOUR', 22, var_type=int)  # GMT
MARKET_TIMEZONE = get_env_var('MARKET_TIMEZONE', 'UTC')

# ===== BACKTEST CONFIGURATION =====
BACKTEST_ENABLED = get_env_var('BACKTEST_ENABLED', True, var_type=bool)
BACKTEST_START_DATE = get_env_var('BACKTEST_START_DATE', '2024-01-01')
BACKTEST_END_DATE = get_env_var('BACKTEST_END_DATE', '2024-12-31')
BACKTEST_INITIAL_BALANCE = get_env_var('BACKTEST_INITIAL_BALANCE', 10000, var_type=float)

# ===== RISK MANAGEMENT CONFIGURATION =====
RISK_MANAGEMENT_ENABLED = get_env_var('RISK_MANAGEMENT_ENABLED', True, var_type=bool)
MAX_DAILY_LOSS_PERCENT = get_env_var('MAX_DAILY_LOSS_PERCENT', 5.0, var_type=float)
MAX_POSITION_SIZE_PERCENT = get_env_var('MAX_POSITION_SIZE_PERCENT', 10.0, var_type=float)
MAX_DRAWDOWN_PERCENT = get_env_var('MAX_DRAWDOWN_PERCENT', 15.0, var_type=float)
MAX_DAILY_TRADES = get_env_var('MAX_DAILY_TRADES', 20, var_type=int)

# ===== FINANCIAL DATA CONFIGURATION =====
USD_IRR_EXCHANGE_RATE = get_env_var('USD_IRR_EXCHANGE_RATE', 70000.0, var_type=float)

# ===== NOTIFICATION CONFIGURATION =====
NOTIFICATIONS_ENABLED = get_env_var('NOTIFICATIONS_ENABLED', True, var_type=bool)
EMAIL_NOTIFICATIONS = get_env_var('EMAIL_NOTIFICATIONS', False, var_type=bool)
WEBHOOK_NOTIFICATIONS = get_env_var('WEBHOOK_NOTIFICATIONS', False, var_type=bool)

# Email settings (if enabled)
EMAIL_SMTP_SERVER = get_env_var('EMAIL_SMTP_SERVER', 'smtp.gmail.com')
EMAIL_SMTP_PORT = get_env_var('EMAIL_SMTP_PORT', 587, var_type=int)
EMAIL_USERNAME = get_env_var('EMAIL_USERNAME', '')
EMAIL_PASSWORD = get_env_var('EMAIL_PASSWORD', '')

# ===== LOGGING CONFIGURATION =====
LOG_LEVEL = get_env_var('LOG_LEVEL', 'INFO')
LOG_FILE_PATH = get_env_var('LOG_FILE_PATH', 'logs/flowai.log')
LOG_MAX_SIZE = get_env_var('LOG_MAX_SIZE', 10, var_type=int)  # MB
LOG_BACKUP_COUNT = get_env_var('LOG_BACKUP_COUNT', 5, var_type=int)

# ===== DATABASE CONFIGURATION =====
DATABASE_ENABLED = get_env_var('DATABASE_ENABLED', False, var_type=bool)
DATABASE_URL = get_env_var('DATABASE_URL', 'sqlite:///flowai.db')

# ===== PERFORMANCE CONFIGURATION =====
CACHE_ENABLED = get_env_var('CACHE_ENABLED', True, var_type=bool)
CACHE_TTL = get_env_var('CACHE_TTL', 300, var_type=int)  # seconds
PARALLEL_PROCESSING = get_env_var('PARALLEL_PROCESSING', True, var_type=bool)
MAX_WORKERS = get_env_var('MAX_WORKERS', 4, var_type=int)

# ===== DEVELOPMENT CONFIGURATION =====
DEBUG_MODE = get_env_var('DEBUG_MODE', False, var_type=bool)
TESTING_MODE = get_env_var('TESTING_MODE', False, var_type=bool)
PAPER_TRADING = get_env_var('PAPER_TRADING', True, var_type=bool)

# ===== NEWS HANDLING CONFIGURATION =====
NEWS_FETCH_URL = get_env_var('NEWS_FETCH_URL', 'https://nfs.faireconomy.media/ff_calendar_thisweek.json', var_type=str)
# Comma-separated list, e.g., "USD,EUR"
NEWS_MONITORED_CURRENCIES = get_env_var('NEWS_MONITORED_CURRENCIES', 'USD', var_type=list)
# Comma-separated, e.g., "High,Medium,Low"
NEWS_MONITORED_IMPACTS = get_env_var('NEWS_MONITORED_IMPACTS', 'High,Medium', var_type=list)
NEWS_BLACKOUT_MINUTES_BEFORE = get_env_var('NEWS_BLACKOUT_MINUTES_BEFORE', 30, var_type=int)
NEWS_BLACKOUT_MINUTES_AFTER = get_env_var('NEWS_BLACKOUT_MINUTES_AFTER', 60, var_type=int)
NEWS_CACHE_TTL_SECONDS = get_env_var('NEWS_CACHE_TTL_SECONDS', 3600, var_type=int) # 1 hour

# ===== ADVANCED ICT PARAMETERS =====
ICT_SWING_LOOKBACK_PERIODS = get_env_var('ICT_SWING_LOOKBACK_PERIODS', 10, var_type=int)
ICT_SWING_HIGH_LOW_PERIODS = get_env_var('ICT_SWING_HIGH_LOW_PERIODS', 5, var_type=int)
ICT_STRUCTURE_CONFIRMATION_PERIODS = get_env_var('ICT_STRUCTURE_CONFIRMATION_PERIODS', 3, var_type=int)

# ===== ICT MSS (Market Structure Shift) =====
ICT_MSS_SWING_LOOKBACK = get_env_var('ICT_MSS_SWING_LOOKBACK', 20, var_type=int)
ICT_MSS_CONFIRMATION_PERIODS = get_env_var('ICT_MSS_CONFIRMATION_PERIODS', 3, var_type=int)
ICT_MSS_MIN_BREAK_PERCENTAGE = get_env_var('ICT_MSS_MIN_BREAK_PERCENTAGE', 0.001, var_type=float)

# ===== ICT BOS (Break of Structure) =====
ICT_BOS_SWING_LOOKBACK = get_env_var('ICT_BOS_SWING_LOOKBACK', 15, var_type=int)
ICT_BOS_CONFIRMATION_PERIODS = get_env_var('ICT_BOS_CONFIRMATION_PERIODS', 2, var_type=int)

# ===== ICT CHoCH (Change of Character) =====
ICT_CHOCH_LOOKBACK_PERIODS = get_env_var('ICT_CHOCH_LOOKBACK_PERIODS', 10, var_type=int)
ICT_CHOCH_CONFIRMATION = get_env_var('ICT_CHOCH_CONFIRMATION', 3, var_type=int)

# ===== ICT ORDER BLOCK SETTINGS =====
ICT_OB_MIN_BODY_RATIO = get_env_var('ICT_OB_MIN_BODY_RATIO', 0.3, var_type=float)
ICT_OB_MIN_SIZE = get_env_var('ICT_OB_MIN_SIZE', 0.0005, var_type=float)
ICT_OB_MAX_LOOKBACK = get_env_var('ICT_OB_MAX_LOOKBACK', 20, var_type=int)
ICT_OB_CONFIRMATION_PERIODS = get_env_var('ICT_OB_CONFIRMATION_PERIODS', 3, var_type=int)

# ===== ICT PD ARRAY SETTINGS =====
ICT_PD_ARRAY_LOOKBACK_PERIODS = get_env_var('ICT_PD_ARRAY_LOOKBACK_PERIODS', 50, var_type=int)
ICT_PD_ARRAY_MIN_TOUCHES = get_env_var('ICT_PD_ARRAY_MIN_TOUCHES', 3, var_type=int)
ICT_PD_ARRAY_CONFIRMATION = get_env_var('ICT_PD_ARRAY_CONFIRMATION', 2, var_type=int)

# Minimum Fair Value Gap size as a decimal (e.g., 0.0003 for 0.03%)
FVG_THRESHOLD = get_env_var('ICT_FVG_THRESHOLD', 0.0003, var_type=float)

_default_retracement_levels_str = "0.236,0.382,0.5,0.618,0.786"
ICT_PD_RETRACEMENT_LEVELS_STR = get_env_var('ICT_PD_RETRACEMENT_LEVELS', _default_retracement_levels_str)
ICT_PD_RETRACEMENT_LEVELS = []
try:
    if ICT_PD_RETRACEMENT_LEVELS_STR:
        ICT_PD_RETRACEMENT_LEVELS = [float(x.strip()) for x in ICT_PD_RETRACEMENT_LEVELS_STR.split(',') if x.strip()]
    if not ICT_PD_RETRACEMENT_LEVELS: # If parsing resulted in empty list or original string was empty
        raise ValueError("Empty or invalid list")
except ValueError:
    logger.warning(f"Invalid format for ICT_PD_RETRACEMENT_LEVELS: '{ICT_PD_RETRACEMENT_LEVELS_STR}'. Using default values.")
    ICT_PD_RETRACEMENT_LEVELS = [float(x.strip()) for x in _default_retracement_levels_str.split(',')]

# ===== ICT PD EXTENSION LEVELS =====
_default_extension_levels_str = "1.272,1.414,1.618,2.0,2.618"
ICT_PD_EXTENSION_LEVELS_STR = get_env_var('ICT_PD_EXTENSION_LEVELS', _default_extension_levels_str)
ICT_PD_EXTENSION_LEVELS = []
try:
    if ICT_PD_EXTENSION_LEVELS_STR:
        ICT_PD_EXTENSION_LEVELS = [float(x.strip()) for x in ICT_PD_EXTENSION_LEVELS_STR.split(',') if x.strip()]
    if not ICT_PD_EXTENSION_LEVELS:
        raise ValueError("Empty or invalid list")
except ValueError:
    logger.warning(f"Invalid format for ICT_PD_EXTENSION_LEVELS: '{ICT_PD_EXTENSION_LEVELS_STR}'. Using default values.")
    ICT_PD_EXTENSION_LEVELS = [float(x.strip()) for x in _default_extension_levels_str.split(',')]

# ===== ICT SPECIFIC CONFIGURATIONS =====
class ICTConfig:
    """ICT Strategy specific configurations"""
    
    # Session Times (GMT)
    LONDON_SESSION_START = 7
    LONDON_SESSION_END = 16
    NEW_YORK_SESSION_START = 13
    NEW_YORK_SESSION_END = 22
    ASIA_SESSION_START = 21
    ASIA_SESSION_END = 6
    
    # Order Block Settings
    OB_MIN_BODY_SIZE = 0.0005  # Minimum body size for order block
    OB_LOOKBACK_PERIODS = 20   # Periods to look back for order blocks
    OB_VALIDITY_PERIODS = 50   # How long order block remains valid
    
    # Fair Value Gap Settings
    FVG_MIN_SIZE = 0.0003      # Minimum gap size
    FVG_MAX_AGE = 100          # Maximum age in periods
    
    # Liquidity Settings
    LIQUIDITY_THRESHOLD = 0.001  # Minimum move to consider liquidity sweep
    LIQUIDITY_LOOKBACK = 50      # Periods to look for highs/lows
    
    # Market Structure
    STRUCTURE_SWING_LENGTH = 10   # Swing high/low detection length
    STRUCTURE_CONFIRMATION = 3    # Periods for structure confirmation

# ===== VALIDATION =====
def validate_config():
    """اعتبارسنجی تنظیمات"""
    errors = []
    
    if not TELEGRAM_BOT_TOKEN:
        errors.append("TELEGRAM_BOT_TOKEN is required and cannot be empty.")

    if _admin_ids_conversion_error:
        errors.append("TELEGRAM_ADMIN_IDS contains invalid non-integer values. Please check .env file.")
    elif not TELEGRAM_ADMIN_IDS: # This condition implies TELEGRAM_ADMIN_IDS_RAW was empty or all its elements were empty strings, and no conversion error occurred.
        errors.append("TELEGRAM_ADMIN_IDS is required and cannot be empty. Please set at least one admin ID in .env file.")
    
    if not BRSAPI_KEY:
        errors.append("BRSAPI_KEY is required")
    
    if AI_CONFIDENCE_THRESHOLD < 0 or AI_CONFIDENCE_THRESHOLD > 1:
        errors.append("AI_CONFIDENCE_THRESHOLD must be between 0 and 1")
    
    if SIGNAL_MIN_CONFIDENCE < 0 or SIGNAL_MIN_CONFIDENCE > 1:
        errors.append("SIGNAL_MIN_CONFIDENCE must be between 0 and 1")
    
    if ICT_RISK_PER_TRADE <= 0 or ICT_RISK_PER_TRADE > 0.1:
        errors.append("ICT_RISK_PER_TRADE must be between 0 and 0.1 (10%)")

    if USD_IRR_EXCHANGE_RATE <= 0:
        errors.append("USD_IRR_EXCHANGE_RATE must be a positive number.")

    # News Handling Validation
    if not NEWS_FETCH_URL:
        errors.append("NEWS_FETCH_URL is required.")
    if not NEWS_MONITORED_CURRENCIES:
        errors.append("NEWS_MONITORED_CURRENCIES cannot be empty if news handling is active.")
    if not NEWS_MONITORED_IMPACTS:
        errors.append("NEWS_MONITORED_IMPACTS cannot be empty if news handling is active.")
    if NEWS_BLACKOUT_MINUTES_BEFORE < 0:
        errors.append("NEWS_BLACKOUT_MINUTES_BEFORE cannot be negative.")
    if NEWS_BLACKOUT_MINUTES_AFTER < 0:
        errors.append("NEWS_BLACKOUT_MINUTES_AFTER cannot be negative.")
    if NEWS_CACHE_TTL_SECONDS <= 0:
        errors.append("NEWS_CACHE_TTL_SECONDS must be positive.")

    # Advanced ICT Parameters Validation
    if ICT_SWING_LOOKBACK_PERIODS <= 0:
        errors.append("ICT_SWING_LOOKBACK_PERIODS must be positive.")
    if ICT_MSS_SWING_LOOKBACK <= 0:
        errors.append("ICT_MSS_SWING_LOOKBACK must be positive.")
    if not (0 < ICT_OB_MIN_BODY_RATIO < 1):
        errors.append("ICT_OB_MIN_BODY_RATIO must be between 0 and 1.")
    if ICT_PD_ARRAY_LOOKBACK_PERIODS <= 0:
        errors.append("ICT_PD_ARRAY_LOOKBACK_PERIODS must be positive.")
    if FVG_THRESHOLD <= 0:
        errors.append("FVG_THRESHOLD must be positive.")
    if not ICT_PD_RETRACEMENT_LEVELS:
        errors.append("ICT_PD_RETRACEMENT_LEVELS cannot be empty.")
    if any(not (0 <= level <= 1) for level in ICT_PD_RETRACEMENT_LEVELS):
        errors.append("All ICT_PD_RETRACEMENT_LEVELS must be between 0 and 1.")
    
    if errors:
        for error in errors:
            logger.error(f"Configuration error: {error}")
        raise ValueError(f"Configuration validation failed: {', '.join(errors)}")
    
    logger.info("Configuration validation passed")
    logger.info("FlowAI-ICT Configuration loaded successfully")
    logger.info(f"ICT Strategy: {'Enabled' if ICT_ENABLED else 'Disabled'}")
    logger.info(f"AI Model: {'Enabled' if AI_MODEL_ENABLED else 'Disabled'}")
    logger.info(f"Admin IDs: {TELEGRAM_ADMIN_IDS}")
    logger.info(f"Premium Users: {len(TELEGRAM_PREMIUM_USERS)}")
    
    if USD_IRR_EXCHANGE_RATE == 70000.0 and not os.getenv('USD_IRR_EXCHANGE_RATE'):
        logger.warning("Using default USD_IRR_EXCHANGE_RATE of 70000.0. "
                         "Please set USD_IRR_EXCHANGE_RATE in your .env file for accurate "
                         "18K Gold price conversion if XAUUSD is unavailable.")
    
    return True

# اجرای اعتبارسنجی
try:
    validate_config()
except ValueError as e:
    logger.error(f"Configuration validation failed: {e}")
    # در حالت production، ممکن است بخواهید برنامه را متوقف کنید
    # sys.exit(1)
