"""
FlowAI ICT Trading Bot Utility Functions
Common utility functions and logging setup
"""

import os
import logging
import sys
from datetime import datetime
from typing import Optional, Dict, Any
import pandas as pd
import numpy as np

def setup_logging(log_level: str = "INFO", log_dir: str = "logs") -> logging.Logger:
    """
    Setup comprehensive logging for the trading bot
    """
    # Create logs directory if it doesn't exist
    os.makedirs(log_dir, exist_ok=True)
    
    # Configure log level
    numeric_level = getattr(logging, log_level.upper(), logging.INFO)
    
    # Create logger
    logger = logging.getLogger("FlowAI_Bot")
    logger.setLevel(numeric_level)
    
    # Clear existing handlers
    logger.handlers.clear()
    
    # Create formatters
    detailed_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(module)s:%(lineno)d - %(message)s'
    )
    
    simple_formatter = logging.Formatter(
        '%(levelname)s:%(name)s:%(message)s'
    )
    
    # File handler for detailed logs
    log_file = os.path.join(log_dir, f"flowai_bot_{datetime.now().strftime('%Y%m%d')}.log")
    file_handler = logging.FileHandler(log_file, encoding='utf-8')
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(detailed_formatter)
    
    # Console handler for important messages
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(numeric_level)
    console_handler.setFormatter(simple_formatter)
    
    # Add handlers to logger
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    # Prevent propagation to root logger
    logger.propagate = False
    
    logger.info(f"Logging setup complete. Logger name: '{logger.name}', Level: {log_level}")
    
    return logger

def safe_divide(numerator: float, denominator: float, default: float = 0.0) -> float:
    """
    Safely divide two numbers, returning default if denominator is zero
    """
    try:
        if denominator == 0 or pd.isna(denominator) or pd.isna(numerator):
            return default
        return float(numerator / denominator)
    except (TypeError, ValueError, ZeroDivisionError):
        return default

def safe_percentage_change(current: float, previous: float, default: float = 0.0) -> float:
    """
    Safely calculate percentage change
    """
    try:
        if previous == 0 or pd.isna(previous) or pd.isna(current):
            return default
        return float((current - previous) / previous * 100)
    except (TypeError, ValueError, ZeroDivisionError):
        return default

def format_price(price: float, decimals: int = 2) -> str:
    """
    Format price with appropriate decimal places
    """
    try:
        return f"${price:,.{decimals}f}"
    except (TypeError, ValueError):
        return "N/A"

def format_percentage(value: float, decimals: int = 2) -> str:
    """
    Format percentage value
    """
    try:
        return f"{value:.{decimals}f}%"
    except (TypeError, ValueError):
        return "N/A"

def validate_dataframe(df: pd.DataFrame, required_columns: list) -> bool:
    """
    Validate that DataFrame has required columns and is not empty
    """
    if df is None or df.empty:
        return False
    
    missing_columns = [col for col in required_columns if col not in df.columns]
    if missing_columns:
        return False
    
    return True

def clean_numeric_data(series: pd.Series, fill_method: str = 'forward') -> pd.Series:
    """
    Clean numeric data by handling NaN and infinite values
    """
    # Replace infinite values with NaN
    series = series.replace([np.inf, -np.inf], np.nan)
    
    # Fill NaN values
    if fill_method == 'forward':
        series = series.fillna(method='ffill')
    elif fill_method == 'backward':
        series = series.fillna(method='bfill')
    elif fill_method == 'zero':
        series = series.fillna(0)
    elif isinstance(fill_method, (int, float)):
        series = series.fillna(fill_method)
    
    # Final fallback to zero
    series = series.fillna(0)
    
    return series

def calculate_atr(high: pd.Series, low: pd.Series, close: pd.Series, period: int = 14) -> pd.Series:
    """
    Calculate Average True Range (ATR)
    """
    try:
        # True Range calculation
        tr1 = high - low
        tr2 = abs(high - close.shift(1))
        tr3 = abs(low - close.shift(1))
        
        true_range = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
        atr = true_range.rolling(window=period).mean()
        
        return clean_numeric_data(atr)
    except Exception:
        return pd.Series(index=high.index, data=0.0)

def detect_swing_points(high: pd.Series, low: pd.Series, lookback: int = 5) -> Dict[str, pd.Series]:
    """
    Detect swing highs and lows
    """
    swing_highs = pd.Series(index=high.index, data=False)
    swing_lows = pd.Series(index=low.index, data=False)
    
    try:
        for i in range(lookback, len(high) - lookback):
            # Check for swing high
            if high.iloc[i] == high.iloc[i-lookback:i+lookback+1].max():
                swing_highs.iloc[i] = True
            
            # Check for swing low
            if low.iloc[i] == low.iloc[i-lookback:i+lookback+1].min():
                swing_lows.iloc[i] = True
    
    except Exception:
        pass
    
    return {
        'swing_highs': swing_highs,
        'swing_lows': swing_lows
    }

def get_version_info() -> Dict[str, str]:
    """
    Get version information for the bot
    """
    return {
        'bot_version': '2.0.0',
        'python_version': sys.version.split()[0],
        'pandas_version': pd.__version__,
        'numpy_version': np.__version__
    }

def create_signal_message(signal_type: str, symbol: str, price: float, 
                         confidence: float, analysis: Dict[str, Any]) -> str:
    """
    Create formatted signal message for notifications
    """
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    message = f"""
🚨 **FlowAI XAU Trading Signal** 🚨

📊 **Symbol:** {symbol}
📈 **Signal:** {signal_type.upper()}
⏰ **Time:** {timestamp}
💰 **Price:** {format_price(price)}

🤖 **AI Analysis:**
   • Confidence: {format_percentage(confidence * 100)}
   • HTF Bias: {analysis.get('htf_bias', 'N/A')}
   • Risk Level: {analysis.get('risk_level', 'MEDIUM')}

📋 **Technical Analysis:**
   • RSI: {analysis.get('rsi', 'N/A')}
   • Trend: {analysis.get('trend', 'N/A')}
   • Volume: {analysis.get('volume_status', 'N/A')}

⚠️ **Risk Management:**
   • Stop Loss: {analysis.get('stop_loss', 'N/A')}
   • Take Profit: {analysis.get('take_profit', 'N/A')}

🎯 **Powered by FlowAI v2.0**
"""
    
    return message.strip()

# Initialize logger for this module
logger = setup_logging()
