"""
FlowAI ICT Trading Bot Configuration Module
Handles all configuration settings and environment variables
"""

import os
import logging
from typing import List, Union, Any
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Setup logger
logger = logging.getLogger(__name__)

def get_env_var(key: str, default: Any = None, var_type: type = str) -> Any:
    """
    Get environment variable with type conversion and default value
    """
    value = os.getenv(key, default)
    
    if value is None:
        if default is not None:
            logger.info(f"Env var '{key}' not found. Using default: {default}")
            return default
        else:
            logger.error(f"Env var '{key}' not found, no default.")
            return None
    
    try:
        if var_type == bool:
            # اگر مقدار از قبل bool است
            if isinstance(value, bool):
                return value
            # اگر string است
            if isinstance(value, str):
                return value.lower() in ('true', '1', 'yes', 'on')
            # سایر انواع
            return bool(value)
        elif var_type == int:
            return int(value)
        elif var_type == float:
            return float(value)
        elif var_type == list:
            return [item.strip() for item in value.split(',') if item.strip()]
        else:
            return str(value)
    except (ValueError, AttributeError) as e:
        logger.warning(f"Failed to convert '{key}' to {var_type.__name__}: {e}. Using default: {default}")
        return default

# ===== BASIC TRADING CONFIGURATION =====
SYMBOL = get_env_var("SYMBOL", "GC=F")
TIMEFRAME = get_env_var("TIMEFRAME", "1h")
CANDLE_LIMIT = get_env_var("CANDLE_LIMIT", 1000, var_type=int)

# ===== RSI CONFIGURATION =====
RSI_PERIOD = get_env_var("RSI_PERIOD", 14, var_type=int)
RSI_OVERSOLD = get_env_var("RSI_OVERSOLD", 30, var_type=float)
RSI_OVERBOUGHT = get_env_var("RSI_OVERBOUGHT", 70, var_type=float)
RSI_CONFIRM_LOW = get_env_var("RSI_CONFIRM_LOW", 35, var_type=float)
RSI_CONFIRM_HIGH = get_env_var("RSI_CONFIRM_HIGH", 65, var_type=float)

# ===== SMA CONFIGURATION =====
SMA_PERIOD = get_env_var("SMA_PERIOD", 20, var_type=int)

# ===== FVG CONFIGURATION =====
FVG_THRESHOLD = get_env_var("FVG_THRESHOLD", 0.1, var_type=float)

# ===== SCHEDULER CONFIGURATION =====
SCHEDULE_INTERVAL_MINUTES = get_env_var("SCHEDULE_INTERVAL_MINUTES", 60, var_type=int)

# ===== LOGGING CONFIGURATION =====
LOG_LEVEL = get_env_var("LOG_LEVEL", "INFO")

# ===== AI MODEL CONFIGURATION =====
AI_RETURN_PERIODS = [1, 5, 10]  # Direct list
AI_VOLATILITY_PERIOD = get_env_var("AI_VOLATILITY_PERIOD", 20, var_type=int)
AI_ICT_FEATURE_LOOKBACK = get_env_var("AI_ICT_FEATURE_LOOKBACK", 50, var_type=int)
AI_TARGET_N_FUTURE_CANDLES = get_env_var("AI_TARGET_N_FUTURE_CANDLES", 5, var_type=int)
AI_TARGET_PROFIT_PCT = get_env_var("AI_TARGET_PROFIT_PCT", 0.01, var_type=float)
AI_TARGET_STOP_LOSS_PCT = get_env_var("AI_TARGET_STOP_LOSS_PCT", 0.01, var_type=float)
AI_TRAINING_CANDLE_LIMIT = get_env_var("AI_TRAINING_CANDLE_LIMIT", 2000, var_type=int)
AI_HPO_CV_FOLDS = get_env_var("AI_HPO_CV_FOLDS", 3, var_type=int)
AI_HPO_N_ITER = get_env_var("AI_HPO_N_ITER", 20, var_type=int)
AI_MIN_CANDLES_FOR_FVG_FEATURE = get_env_var("AI_MIN_CANDLES_FOR_FVG_FEATURE", 10, var_type=int)
AI_CONFIDENCE_THRESHOLD = get_env_var("AI_CONFIDENCE_THRESHOLD", 0.7, var_type=float)
MODEL_PATH = get_env_var("MODEL_PATH", "model.pkl")
MODEL_FEATURES_PATH = get_env_var("MODEL_FEATURES_PATH", "model_features.pkl")

# ===== ICT ANALYSIS CONFIGURATION =====
ICT_SWING_LOOKBACK_PERIODS = get_env_var("ICT_SWING_LOOKBACK_PERIODS", 5, var_type=int)
ICT_MSS_SWING_LOOKBACK = get_env_var("ICT_MSS_SWING_LOOKBACK", 10, var_type=int)
ICT_OB_MIN_BODY_RATIO = get_env_var("ICT_OB_MIN_BODY_RATIO", 0.3, var_type=float)
ICT_OB_LOOKBACK_FOR_MSS = get_env_var("ICT_OB_LOOKBACK_FOR_MSS", 15, var_type=int)
ICT_PD_ARRAY_LOOKBACK_PERIODS = get_env_var("ICT_PD_ARRAY_LOOKBACK_PERIODS", 60, var_type=int)
ICT_PD_RETRACEMENT_LEVELS = get_env_var("ICT_PD_RETRACEMENT_LEVELS", "0.5,0.618,0.786", var_type=list)
ICT_SWEEP_MSS_LOOKBACK_CANDLES = get_env_var("ICT_SWEEP_MSS_LOOKBACK_CANDLES", 10, var_type=int)
ICT_SWEEP_RETRACEMENT_TARGET_FVG = get_env_var("ICT_SWEEP_RETRACEMENT_TARGET_FVG", True, var_type=bool)

# ===== HTF CONFIGURATION =====
HTF_TIMEFRAMES = get_env_var("HTF_TIMEFRAMES", "1d,4h", var_type=list)
HTF_LOOKBACK_CANDLES = get_env_var("HTF_LOOKBACK_CANDLES", 1000, var_type=int)
HTF_BIAS_CONSENSUS_REQUIRED = get_env_var("HTF_BIAS_CONSENSUS_REQUIRED", False, var_type=bool)
HTF_LEVEL_LOOKBACK_DEFAULT = get_env_var("HTF_LEVEL_LOOKBACK_DEFAULT", 30, var_type=int)
HTF_LEVEL_LOOKBACK_1D = get_env_var("HTF_LEVEL_LOOKBACK_1D", 30, var_type=int)
HTF_LEVEL_LOOKBACK_4H = get_env_var("HTF_LEVEL_LOOKBACK_4H", 60, var_type=int)

# ===== TELEGRAM CONFIGURATION =====
TELEGRAM_BOT_TOKEN = get_env_var("TELEGRAM_BOT_TOKEN")
TELEGRAM_CHAT_ID = get_env_var("TELEGRAM_CHAT_ID")
TELEGRAM_ENABLED = get_env_var("TELEGRAM_ENABLED", True, var_type=bool)

# ===== RISK MANAGEMENT =====
RISK_MANAGEMENT_ENABLED = get_env_var("RISK_MANAGEMENT_ENABLED", True, var_type=bool)
MAX_DAILY_SIGNALS = get_env_var("MAX_DAILY_SIGNALS", 5, var_type=int)
SIGNAL_COOLDOWN_MINUTES = get_env_var("SIGNAL_COOLDOWN_MINUTES", 30, var_type=int)

# ===== SYSTEM CONFIGURATION =====
DEBUG_MODE = get_env_var("DEBUG_MODE", False, var_type=bool)
ENABLE_BACKTESTING = get_env_var("ENABLE_BACKTESTING", False, var_type=bool)
LOG_RETENTION_DAYS = get_env_var("LOG_RETENTION_DAYS", 7, var_type=int)

# Convert PD retracement levels to float list
try:
    ICT_PD_RETRACEMENT_LEVELS = [float(level) for level in ICT_PD_RETRACEMENT_LEVELS]
except (ValueError, TypeError):
    ICT_PD_RETRACEMENT_LEVELS = [0.5, 0.618, 0.786]
    logger.warning("Invalid PD retracement levels, using defaults")

# Log configuration summary
logger.debug(f"Trading Symbol: {SYMBOL}, LTF: {TIMEFRAME}, HTFs: {HTF_TIMEFRAMES}")
logger.info("Configuration loaded successfully.")

# ===== ADVANCED AI CONFIGURATION =====
AI_ADVANCED_FEATURES = get_env_var("AI_ADVANCED_FEATURES", True, var_type=bool)
AI_TIME_BASED_FILTERING = get_env_var("AI_TIME_BASED_FILTERING", True, var_type=bool)
AI_VOLATILITY_FILTERING = get_env_var("AI_VOLATILITY_FILTERING", True, var_type=bool)
AI_VOLUME_CONFIRMATION = get_env_var("AI_VOLUME_CONFIRMATION", True, var_type=bool)

# High Volatility Trading Hours (UTC)
HIGH_VOLATILITY_HOURS = [(8, 10), (13, 15), (20, 22)]

# Advanced Target Thresholds
AI_STRONG_BUY_THRESHOLD = get_env_var("AI_STRONG_BUY_THRESHOLD", 0.008, var_type=float)
AI_BUY_THRESHOLD = get_env_var("AI_BUY_THRESHOLD", 0.003, var_type=float)
AI_HOLD_THRESHOLD = get_env_var("AI_HOLD_THRESHOLD", 0.002, var_type=float)
AI_SELL_THRESHOLD = get_env_var("AI_SELL_THRESHOLD", -0.003, var_type=float)
AI_STRONG_SELL_THRESHOLD = get_env_var("AI_STRONG_SELL_THRESHOLD", -0.008, var_type=float)

# Volume and Volatility Filters
MIN_VOLUME_MULTIPLIER = get_env_var("MIN_VOLUME_MULTIPLIER", 1.2, var_type=float)
MIN_VOLATILITY_MULTIPLIER = get_env_var("MIN_VOLATILITY_MULTIPLIER", 1.1, var_type=float)

# Model Metadata Path
MODEL_METADATA_PATH = get_env_var("MODEL_METADATA_PATH", "model_metadata.pkl")

# ===== ADVANCED AI CONFIGURATION v3.0 =====
AI_EXTENDED_HOURS = get_env_var("AI_EXTENDED_HOURS", True, var_type=bool)
EXTENDED_TRADING_ENABLED = get_env_var("EXTENDED_TRADING_ENABLED", True, var_type=bool)
SESSION_STRENGTH_THRESHOLD = get_env_var("SESSION_STRENGTH_THRESHOLD", 0.5, var_type=float)

# Extended Trading Hours (UTC)
EXTENDED_TRADING_HOURS = [(6, 12), (12, 18), (18, 24)]

# Advanced Target Thresholds v3.0
AI_STRONG_BUY_THRESHOLD = get_env_var("AI_STRONG_BUY_THRESHOLD", 0.008, var_type=float)
AI_BUY_THRESHOLD = get_env_var("AI_BUY_THRESHOLD", 0.003, var_type=float)
AI_HOLD_THRESHOLD = get_env_var("AI_HOLD_THRESHOLD", 0.001, var_type=float)
AI_SELL_THRESHOLD = get_env_var("AI_SELL_THRESHOLD", -0.003, var_type=float)
AI_STRONG_SELL_THRESHOLD = get_env_var("AI_STRONG_SELL_THRESHOLD", -0.008, var_type=float)

# Model Configuration v3.0
MODEL_VERSION = get_env_var("MODEL_VERSION", "3.0")
MODEL_METADATA_PATH = get_env_var("MODEL_METADATA_PATH", "model_metadata.pkl")

# ===== TIMEZONE CONFIGURATION =====
TIMEZONE = get_env_var('TIMEZONE', 'Asia/Tehran')
UTC_OFFSET = '+0330'
