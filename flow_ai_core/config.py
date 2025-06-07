import os
from dotenv import load_dotenv
# Assuming utils.py is in the same package (flow_ai_core)
from .utils import logger # Use relative import for utils within the same package

load_dotenv() # Loads variables from .env in the root project directory

def get_env_var(var_name, default_value=None, var_type=str):
    value = os.getenv(var_name)
    if value is None:
        if default_value is None:
            logger.warning(f"Env var '{var_name}' not found, no default.")
        else:
            logger.info(f"Env var '{var_name}' not found. Using default: {default_value}")
        return default_value
    try:
        if var_type == bool:
            return value.lower() in ('true', '1', 't', 'yes', 'y')
        if var_type == list_str: # Custom type for comma-separated strings
             return [item.strip() for item in value.split(',') if item.strip()]
        if var_type == list_float: # Custom type for comma-separated floats
            return [float(item.strip()) for item in value.split(',') if item.strip()]
        return var_type(value)
    except ValueError:
        logger.error(f"Error converting env var {var_name} ('{value}') to {var_type}. Using default: {default_value}")
        return default_value

# Custom types for get_env_var
list_str = "list_str"
list_float = "list_float"


# Telegram Configuration
TELEGRAM_BOT_TOKEN = get_env_var("TELEGRAM_BOT_TOKEN")
TELEGRAM_CHAT_ID = get_env_var("TELEGRAM_CHAT_ID")

# Trading Configuration
SYMBOL = get_env_var("SYMBOL", "XAU/USD")
TIMEFRAME = get_env_var("TIMEFRAME", "1h")
CANDLE_LIMIT = get_env_var("CANDLE_LIMIT", 50, var_type=int) # For LTF signal generation display window

# AI Model Configuration
MODEL_PATH = get_env_var("MODEL_PATH", "model.pkl") # Should be in root

# Technical Analysis Parameters
RSI_PERIOD = get_env_var("RSI_PERIOD", 14, var_type=int)
RSI_OVERSOLD = get_env_var("RSI_OVERSOLD", 30, var_type=int)
RSI_OVERBOUGHT = get_env_var("RSI_OVERBOUGHT", 70, var_type=int)
RSI_CONFIRM_LOW = get_env_var("RSI_CONFIRM_LOW", 40, var_type=int)
RSI_CONFIRM_HIGH = get_env_var("RSI_CONFIRM_HIGH", 60, var_type=int)
SMA_PERIOD = get_env_var("SMA_PERIOD", 50, var_type=int)
FVG_THRESHOLD = get_env_var("FVG_THRESHOLD", 0.1, var_type=float)

# Scheduler Configuration
SCHEDULE_INTERVAL_MINUTES = get_env_var("SCHEDULE_INTERVAL_MINUTES", 60, var_type=int)

# Logging Configuration
LOG_LEVEL = get_env_var("LOG_LEVEL", "INFO").upper()

# CCXT Exchange Configuration
CCXT_EXCHANGE_ID = get_env_var("CCXT_EXCHANGE_ID", "binance")
CCXT_API_KEY = get_env_var("CCXT_API_KEY", None)
CCXT_API_SECRET = get_env_var("CCXT_API_SECRET", None)

# AI Training Configuration
AI_TRAINING_CANDLE_LIMIT = get_env_var("AI_TRAINING_CANDLE_LIMIT", 2000, var_type=int)
AI_TARGET_N_FUTURE_CANDLES = get_env_var("AI_TARGET_N_FUTURE_CANDLES", 5, var_type=int)
AI_TARGET_PROFIT_PCT = get_env_var("AI_TARGET_PROFIT_PCT", 0.005, var_type=float)
AI_TARGET_STOP_LOSS_PCT = get_env_var("AI_TARGET_STOP_LOSS_PCT", 0.0025, var_type=float)
AI_MIN_CANDLES_FOR_FVG_FEATURE = get_env_var("AI_MIN_CANDLES_FOR_FVG_FEATURE", 10, var_type=int) # Used in old feature eng
AI_RETURN_PERIODS = get_env_var("AI_RETURN_PERIODS", "1,3,5", var_type=list_str) 
AI_RETURN_PERIODS = [int(p) for p in AI_RETURN_PERIODS] # Convert to int list
AI_VOLATILITY_PERIOD = get_env_var("AI_VOLATILITY_PERIOD", 10, var_type=int)
AI_ICT_FEATURE_LOOKBACK = get_env_var("AI_ICT_FEATURE_LOOKBACK", 15, var_type=int)


# AI Hyperparameter Tuning
AI_HPO_N_ITER = get_env_var("AI_HPO_N_ITER", 25, var_type=int)
AI_HPO_CV_FOLDS = get_env_var("AI_HPO_CV_FOLDS", 3, var_type=int)

# ICT Analysis Parameters
ICT_SWING_LOOKBACK_PERIODS = get_env_var("ICT_SWING_LOOKBACK_PERIODS", 5, var_type=int)
ICT_MSS_SWING_LOOKBACK = get_env_var("ICT_MSS_SWING_LOOKBACK", 10, var_type=int)
ICT_OB_MIN_BODY_RATIO = get_env_var("ICT_OB_MIN_BODY_RATIO", 0.3, var_type=float)
ICT_OB_LOOKBACK_FOR_MSS = get_env_var("ICT_OB_LOOKBACK_FOR_MSS", 15, var_type=int) # Not heavily used yet
# ICT_FVG_LOOKBACK_FOR_OB_MSS=10 # Replaced by AI_ICT_FEATURE_LOOKBACK generally

# Premium/Discount Configuration
ICT_PD_ARRAY_LOOKBACK_PERIODS = get_env_var("ICT_PD_ARRAY_LOOKBACK_PERIODS", 60, var_type=int)
ICT_PD_RETRACEMENT_LEVELS = get_env_var("ICT_PD_RETRACEMENT_LEVELS", "0.5,0.618,0.786", var_type=list_float)

# Liquidity Sweep + MSS Configuration
ICT_SWEEP_MSS_LOOKBACK_CANDLES = get_env_var("ICT_SWEEP_MSS_LOOKBACK_CANDLES", 10, var_type=int)
ICT_SWEEP_RETRACEMENT_TARGET_FVG = get_env_var("ICT_SWEEP_RETRACEMENT_TARGET_FVG", True, var_type=bool)

# Higher Timeframe (HTF) Configuration
HTF_TIMEFRAMES = get_env_var("HTF_TIMEFRAMES", "1D,4h", var_type=list_str)
HTF_LOOKBACK_CANDLES = get_env_var("HTF_LOOKBACK_CANDLES", 200, var_type=int)
HTF_BIAS_CONSENSUS_REQUIRED = get_env_var("HTF_BIAS_CONSENSUS_REQUIRED", False, var_type=bool) # Defaulted to False

# HTF Level Lookbacks (example, can add more specific ones)
HTF_LEVEL_LOOKBACK_DEFAULT = get_env_var("HTF_LEVEL_LOOKBACK_DEFAULT", 30, var_type=int) # Default lookback for HTF levels
HTF_LEVEL_LOOKBACK_1D = get_env_var("HTF_LEVEL_LOOKBACK_1D", 30, var_type=int)
HTF_LEVEL_LOOKBACK_4H = get_env_var("HTF_LEVEL_LOOKBACK_4H", 60, var_type=int) # Approx 10 days of 4h candles

# General application settings
price_precision = 5 if 'XAU' in SYMBOL.upper() else 2 # Used in main.py for formatting

# Validate essential configurations
if not TELEGRAM_BOT_TOKEN:
    logger.critical("TELEGRAM_BOT_TOKEN is not set. Bot cannot start.")
    # exit(1) # Or raise an error
if not TELEGRAM_CHAT_ID:
    logger.critical("TELEGRAM_CHAT_ID is not set. Bot cannot send messages.")
    # exit(1)

logger.info("Configuration loaded successfully.")
logger.debug(f"Trading Symbol: {SYMBOL}, LTF: {TIMEFRAME}, HTFs: {HTF_TIMEFRAMES}")