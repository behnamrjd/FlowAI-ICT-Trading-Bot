#!/usr/bin/env python3
"""
FlowAI ICT Trading Bot - Data Handler v3.0
Advanced data fetching and processing with smart Yahoo Finance integration
Author: Behnam RJD
"""

import pandas as pd
import numpy as np
import yfinance as yf
import ta
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import warnings
warnings.filterwarnings('ignore')

# Import smart fetcher
from .yahoo_smart_fetcher import fetch_yahoo_data_smart, reset_yahoo_fetcher, fetch_gold_data
from . import config

# Setup logging
logger = logging.getLogger(__name__)

def fetch_ohlcv_data(symbol: str, timeframe: str, limit: int = 1000) -> pd.DataFrame:
    """
    Fetch OHLCV data using smart Yahoo Finance fetcher with anti-rate-limiting
    
    Args:
        symbol: Trading symbol (e.g., 'GC=F' for Gold)
        timeframe: Timeframe (1m, 5m, 15m, 30m, 1h, 1d, 1wk, 1mo)
        limit: Maximum number of candles to fetch
    
    Returns:
        DataFrame with OHLCV data
    """
    try:
        logger.info(f"Fetching OHLCV: {symbol} ({timeframe}), {limit} candles from yahoo...")
        
        # Map timeframe to period for Yahoo Finance
        period_map = {
            '1m': '7d',      # 1 minute data - max 7 days
            '2m': '60d',     # 2 minute data - max 60 days  
            '5m': '60d',     # 5 minute data - max 60 days
            '15m': '60d',    # 15 minute data - max 60 days
            '30m': '60d',    # 30 minute data - max 60 days
            '1h': '730d',    # 1 hour data - max 730 days (2 years)
            '1d': '5y',      # 1 day data - max 5 years
            '1wk': '10y',    # 1 week data - max 10 years
            '1mo': '20y'     # 1 month data - max 20 years
        }
        
        period = period_map.get(timeframe, '730d')
        
        # Use smart fetcher to avoid rate limiting
        df = fetch_yahoo_data_smart(symbol, period=period, interval=timeframe)
        
        if df is None or df.empty:
            logger.error(f"No data received for {symbol}")
            return pd.DataFrame()
        
        # Process and clean data
        df = process_raw_data(df)
        
        # Limit to requested number of candles
        if len(df) > limit:
            df = df.tail(limit)
        
        logger.info(f"Fetched {len(df)} candles from Yahoo Finance for {symbol}")
        return df
        
    except Exception as e:
        logger.error(f"Error fetching OHLCV data for {symbol}: {e}")
        
        # Try resetting fetcher on persistent errors
        try:
            reset_yahoo_fetcher()
            logger.info("Reset Yahoo fetcher due to persistent errors")
        except Exception as reset_error:
            logger.warning(f"Failed to reset Yahoo fetcher: {reset_error}")
            
        return pd.DataFrame()

def process_raw_data(df: pd.DataFrame) -> pd.DataFrame:
    """Process raw Yahoo Finance data to standard format"""
    try:
        # Reset index to get datetime as column
        if df.index.name in ['Date', 'Datetime']:
            df = df.reset_index()
        
        # اصلاح column mapping - handle MultiIndex columns
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = df.columns.droplevel(0)  # حذف سطح اول
        
        # Standardize column names
        column_mapping = {
            'Date': 'timestamp',
            'Datetime': 'timestamp',
            'Open': 'Open',
            'High': 'High', 
            'Low': 'Low',
            'Close': 'Close',
            'Adj Close': 'Adj_Close',
            'Volume': 'Volume'
        }
        
        # Rename columns if they exist
        for old_name, new_name in column_mapping.items():
            if old_name in df.columns:
                df = df.rename(columns={old_name: new_name})
        
        # Set timestamp as index if it exists
        if 'timestamp' in df.columns:
            df.set_index('timestamp', inplace=True)
        
        # اطمینان از تک ستونه بودن OHLCV columns
        required_columns = ['Open', 'High', 'Low', 'Close', 'Volume']
        for col in required_columns:
            if col in df.columns:
                if isinstance(df[col], pd.DataFrame):
                    df[col] = df[col].iloc[:, 0]  # اولین ستون
        
        # Clean data
        df = clean_ohlcv_data(df)
        
        return df
        
    except Exception as e:
        logger.error(f"Error processing raw data: {e}")
        return df

def clean_ohlcv_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean OHLCV data by removing invalid values and filling gaps
    
    Args:
        df: DataFrame with OHLCV data
    
    Returns:
        Cleaned DataFrame
    """
    try:
        if df.empty:
            return df
        
        # Remove rows with all NaN values
        df = df.dropna(how='all')
        
        # Forward fill missing values
        df = df.fillna(method='ffill')
        
        # Remove rows where OHLC values are zero or negative
        numeric_columns = ['Open', 'High', 'Low', 'Close']
        for col in numeric_columns:
            if col in df.columns:
                df = df[df[col] > 0]
        
        # Ensure High >= Low, High >= Open, High >= Close, Low <= Open, Low <= Close
        if all(col in df.columns for col in ['Open', 'High', 'Low', 'Close']):
            # Fix impossible OHLC relationships
            df['High'] = df[['Open', 'High', 'Low', 'Close']].max(axis=1)
            df['Low'] = df[['Open', 'High', 'Low', 'Close']].min(axis=1)
        
        # Remove duplicate timestamps
        df = df[~df.index.duplicated(keep='last')]
        
        # Sort by timestamp
        df = df.sort_index()
        
        logger.debug(f"Cleaned data: {len(df)} valid candles")
        return df
        
    except Exception as e:
        logger.error(f"Error cleaning OHLCV data: {e}")
        return df

def add_technical_indicators(df: pd.DataFrame) -> pd.DataFrame:
    """Add technical indicators - Fixed for new TA library"""
    try:
        if df.empty or len(df) < 20:
            logger.warning("Insufficient data for technical indicators")
            return df
        
        # RSI - Fixed syntax
        df['RSI'] = ta.momentum.rsi(df['Close'], window=14)
        
        # Moving Averages - Simple calculation
        df['SMA_20'] = df['Close'].rolling(window=20).mean()
        df['SMA_50'] = df['Close'].rolling(window=50).mean()
        df['EMA_12'] = df['Close'].ewm(span=12).mean()
        df['EMA_26'] = df['Close'].ewm(span=26).mean()
        
        # MACD - Fixed syntax
        df['MACD'] = ta.trend.macd_diff(df['Close'])
        df['MACD_Signal'] = ta.trend.macd_signal(df['Close'])
        df['MACD_Histogram'] = ta.trend.macd(df['Close'])
        
        # Bollinger Bands - Manual calculation
        bb_period = 20
        bb_std = 2
        df['BB_Middle'] = df['Close'].rolling(window=bb_period).mean()
        bb_std_dev = df['Close'].rolling(window=bb_period).std()
        df['BB_Upper'] = df['BB_Middle'] + (bb_std_dev * bb_std)
        df['BB_Lower'] = df['BB_Middle'] - (bb_std_dev * bb_std)
        df['BB_Width'] = (df['BB_Upper'] - df['BB_Lower']) / df['BB_Middle']
        
        # ATR - Fixed syntax
        df['ATR'] = ta.volatility.average_true_range(
            high=df['High'], 
            low=df['Low'], 
            close=df['Close'], 
            window=14
        )
        
        # Stochastic - Fixed syntax
        df['Stoch_K'] = ta.momentum.stoch(
            high=df['High'],
            low=df['Low'], 
            close=df['Close'],
            window=14
        )
        df['Stoch_D'] = df['Stoch_K'].rolling(window=3).mean()
        
        # Volume indicators - Simple calculation
        if 'Volume' in df.columns and df['Volume'].sum() > 0:
            df['Volume_SMA'] = df['Volume'].rolling(window=20).mean()
            
            # On-Balance Volume - Manual calculation
            df['OBV'] = (df['Volume'] * ((df['Close'] - df['Close'].shift(1)) > 0).astype(int)).cumsum()
        
        # Price change and returns
        df['Price_Change'] = df['Close'].pct_change()
        df['Price_Change_Abs'] = df['Close'].diff()
        
        # Volatility
        df['Volatility'] = df['Price_Change'].rolling(20).std()
        
        # Fill NaN values
        df = df.fillna(method='ffill').fillna(0)
        
        logger.debug("Technical indicators added successfully")
        return df
        
    except Exception as e:
        logger.error(f"Error adding technical indicators: {e}")
        return df


def get_processed_data(symbol: str, timeframe: str = "1h", limit: int = 1000) -> pd.DataFrame:
    """Get processed data with enhanced validation and real-time checks"""
    try:
        from . import config
        
        # Enhanced data fetching with validation
        logger.info(f"Fetching {symbol} data with enhanced validation...")
        
        # Get raw data
        raw_data = fetch_yahoo_data_smart(symbol, period="5d", interval=timeframe)
        
        if raw_data.empty:
            logger.warning(f"No raw data received for {symbol}")
            
            # Try fallback symbols if enabled
            if hasattr(config, 'ENABLE_REAL_TIME_FALLBACK') and config.ENABLE_REAL_TIME_FALLBACK:
                fallback_symbols = getattr(config, 'FALLBACK_SYMBOLS', ['GC=F', 'GLD'])
                
                for fallback_symbol in fallback_symbols:
                    logger.info(f"Trying fallback symbol: {fallback_symbol}")
                    raw_data = fetch_yahoo_data_smart(fallback_symbol, period="5d", interval=timeframe)
                    
                    if not raw_data.empty:
                        logger.info(f"✅ Success with fallback symbol: {fallback_symbol}")
                        break
            
            if raw_data.empty:
                logger.error(f"All data sources failed for {symbol}")
                return pd.DataFrame()
        
        # Validate data quality
        if hasattr(config, 'VALIDATE_DATA_FRESHNESS') and config.VALIDATE_DATA_FRESHNESS:
            latest_time = raw_data.index[-1]
            current_time = datetime.now(timezone.utc)
            
            if latest_time.tzinfo is None:
                latest_time = latest_time.replace(tzinfo=timezone.utc)
            
            delay_minutes = (current_time - latest_time).total_seconds() / 60
            max_delay = getattr(config, 'MAX_DATA_DELAY_MINUTES', 30)
            
            if delay_minutes > max_delay:
                logger.warning(f"⚠️ Data is {delay_minutes:.1f} minutes old (max: {max_delay})")
                
                # Log price comparison for debugging
                latest_price = raw_data['Close'].iloc[-1]
                logger.info(f"📊 Using price: ${latest_price:.2f} from {latest_time}")
            else:
                logger.info(f"✅ Data is fresh ({delay_minutes:.1f} minutes old)")
        
        # Process the data
        processed_data = process_raw_data(raw_data)
        
        if processed_data.empty:
            logger.error("Data processing failed")
            return pd.DataFrame()
        
        # Add technical indicators
        processed_data = add_technical_indicators(processed_data)
        
        # Limit data if requested
        if limit and len(processed_data) > limit:
            processed_data = processed_data.tail(limit)
        
        logger.info(f"✅ Processed {len(processed_data)} candles for {symbol}")
        logger.info(f"📊 Price range: ${processed_data['Close'].min():.2f} - ${processed_data['Close'].max():.2f}")
        logger.info(f"💰 Latest price: ${processed_data['Close'].iloc[-1]:.2f}")
        
        return processed_data
        
    except Exception as e:
        logger.error(f"Error getting processed data for {symbol}: {e}")
        import traceback
        traceback.print_exc()
        return pd.DataFrame()

def get_htf_data(symbol: str, timeframes: List[str]) -> Dict[str, pd.DataFrame]:
    """
    Get Higher Time Frame (HTF) data for multiple timeframes
    
    Args:
        symbol: Trading symbol
        timeframes: List of timeframes (e.g., ['1d', '4h'])
    
    Returns:
        Dictionary with timeframe as key and DataFrame as value
    """
    htf_data = {}
    
    try:
        for tf in timeframes:
            logger.info(f"Fetching HTF data for {symbol} on {tf}")
            
            # Determine appropriate limit based on timeframe
            limit_map = {
                '1h': 500,
                '4h': 200, 
                '1d': 100,
                '1w': 52,
                '1M': 24
            }
            
            limit = limit_map.get(tf, 200)
            
            df = get_processed_data(symbol, tf, limit)
            
            if not df.empty:
                htf_data[tf] = df
                logger.info(f"HTF {tf}: {len(df)} candles loaded")
            else:
                logger.warning(f"No HTF data available for {tf}")
        
        return htf_data
        
    except Exception as e:
        logger.error(f"Error fetching HTF data: {e}")
        return {}

def resample_data(df: pd.DataFrame, target_timeframe: str) -> pd.DataFrame:
    """
    Resample data to different timeframe
    
    Args:
        df: Source DataFrame
        target_timeframe: Target timeframe (e.g., '4h', '1d')
    
    Returns:
        Resampled DataFrame
    """
    try:
        if df.empty:
            return df
        
        # Define resampling rules
        agg_dict = {
            'Open': 'first',
            'High': 'max', 
            'Low': 'min',
            'Close': 'last',
            'Volume': 'sum'
        }
        
        # Resample
        resampled = df.resample(target_timeframe).agg(agg_dict)
        
        # Remove rows with NaN values
        resampled = resampled.dropna()
        
        # Add technical indicators to resampled data
        resampled = add_technical_indicators(resampled)
        
        logger.info(f"Data resampled to {target_timeframe}: {len(resampled)} candles")
        return resampled
        
    except Exception as e:
        logger.error(f"Error resampling data: {e}")
        return df

def validate_data_quality(df: pd.DataFrame) -> Tuple[bool, List[str]]:
    """
    Validate data quality and return issues found
    
    Args:
        df: DataFrame to validate
    
    Returns:
        Tuple of (is_valid, list_of_issues)
    """
    issues = []
    
    try:
        if df.empty:
            issues.append("DataFrame is empty")
            return False, issues
        
        # Check for required columns
        required_columns = ['Open', 'High', 'Low', 'Close', 'Volume']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            issues.append(f"Missing columns: {missing_columns}")
        
        # Check for NaN values
        nan_columns = df.columns[df.isnull().any()].tolist()
        if nan_columns:
            issues.append(f"NaN values in columns: {nan_columns}")
        
        # Check for negative or zero prices
        price_columns = ['Open', 'High', 'Low', 'Close']
        for col in price_columns:
            if col in df.columns:
                invalid_prices = (df[col] <= 0).sum()
                if invalid_prices > 0:
                    issues.append(f"Invalid prices in {col}: {invalid_prices} rows")
        
        # Check OHLC relationships
        if all(col in df.columns for col in price_columns):
            high_issues = (df['High'] < df[['Open', 'Low', 'Close']].max(axis=1)).sum()
            low_issues = (df['Low'] > df[['Open', 'High', 'Close']].min(axis=1)).sum()
            
            if high_issues > 0:
                issues.append(f"High price inconsistencies: {high_issues} rows")
            if low_issues > 0:
                issues.append(f"Low price inconsistencies: {low_issues} rows")
        
        # Check for sufficient data
        if len(df) < 20:
            issues.append(f"Insufficient data: only {len(df)} candles")
        
        is_valid = len(issues) == 0
        return is_valid, issues
        
    except Exception as e:
        issues.append(f"Validation error: {e}")
        return False, issues

def get_market_hours_data(df: pd.DataFrame) -> Dict[str, pd.DataFrame]:
    """
    Split data by market hours (Asian, London, US sessions)
    
    Args:
        df: DataFrame with timestamp index
    
    Returns:
        Dictionary with session data
    """
    try:
        if df.empty:
            return {}
        
        # Ensure index is datetime
        if not isinstance(df.index, pd.DatetimeIndex):
            return {}
        
        # Define session hours (UTC)
        sessions = {
            'asian': (0, 8),      # 00:00 - 08:00 UTC
            'london': (8, 16),    # 08:00 - 16:00 UTC  
            'us': (13, 21),       # 13:00 - 21:00 UTC
            'overlap': (13, 16)   # London/US overlap
        }
        
        session_data = {}
        
        for session_name, (start_hour, end_hour) in sessions.items():
            # Filter data by hour
            session_mask = (df.index.hour >= start_hour) & (df.index.hour < end_hour)
            session_df = df[session_mask].copy()
            
            if not session_df.empty:
                session_data[session_name] = session_df
                logger.debug(f"{session_name} session: {len(session_df)} candles")
        
        return session_data
        
    except Exception as e:
        logger.error(f"Error splitting market hours data: {e}")
        return {}

def calculate_statistics(df: pd.DataFrame) -> Dict[str, float]:
    """
    Calculate basic statistics for the dataset
    
    Args:
        df: DataFrame with OHLCV data
    
    Returns:
        Dictionary with statistics
    """
    try:
        if df.empty or 'Close' not in df.columns:
            return {}
        
        stats = {
            'count': len(df),
            'mean_price': df['Close'].mean(),
            'std_price': df['Close'].std(),
            'min_price': df['Close'].min(),
            'max_price': df['Close'].max(),
            'price_range': df['Close'].max() - df['Close'].min(),
            'mean_volume': df['Volume'].mean() if 'Volume' in df.columns else 0,
            'volatility': df['Close'].pct_change().std() * np.sqrt(252),  # Annualized
            'total_return': (df['Close'].iloc[-1] / df['Close'].iloc[0] - 1) * 100,
            'max_drawdown': calculate_max_drawdown(df['Close'])
        }
        
        return stats
        
    except Exception as e:
        logger.error(f"Error calculating statistics: {e}")
        return {}

def calculate_max_drawdown(prices: pd.Series) -> float:
    """
    Calculate maximum drawdown from price series
    
    Args:
        prices: Series of prices
    
    Returns:
        Maximum drawdown as percentage
    """
    try:
        # Calculate cumulative returns
        cumulative = (1 + prices.pct_change()).cumprod()
        
        # Calculate running maximum
        running_max = cumulative.cummax()
        
        # Calculate drawdown
        drawdown = (cumulative - running_max) / running_max
        
        # Return maximum drawdown as percentage
        return drawdown.min() * 100
        
    except Exception as e:
        logger.error(f"Error calculating max drawdown: {e}")
        return 0.0

# Convenience functions for specific symbols
def get_gold_data(timeframe: str = '1h', limit: int = 1000) -> pd.DataFrame:
    """Get processed gold (GC=F) data"""
    return get_processed_data('GC=F', timeframe, limit)

def get_gold_htf_data() -> Dict[str, pd.DataFrame]:
    """Get HTF data for gold using configured timeframes"""
    timeframes = config.HTF_TIMEFRAMES.split(',') if hasattr(config, 'HTF_TIMEFRAMES') else ['1d', '4h']
    return get_htf_data('GC=F', timeframes)

# Cache management
_data_cache = {}
_cache_timestamps = {}

def get_cached_data(symbol: str, timeframe: str, cache_duration: int = 300) -> Optional[pd.DataFrame]:
    """
    Get data from cache if available and fresh
    
    Args:
        symbol: Trading symbol
        timeframe: Timeframe
        cache_duration: Cache duration in seconds
    
    Returns:
        Cached DataFrame or None
    """
    try:
        cache_key = f"{symbol}_{timeframe}"
        
        if cache_key in _data_cache and cache_key in _cache_timestamps:
            cache_age = datetime.now().timestamp() - _cache_timestamps[cache_key]
            
            if cache_age < cache_duration:
                logger.debug(f"Using cached data for {cache_key}")
                return _data_cache[cache_key].copy()
        
        return None
        
    except Exception as e:
        logger.error(f"Error accessing cache: {e}")
        return None

def cache_data(symbol: str, timeframe: str, df: pd.DataFrame) -> None:
    """
    Cache data for future use
    
    Args:
        symbol: Trading symbol
        timeframe: Timeframe  
        df: DataFrame to cache
    """
    try:
        cache_key = f"{symbol}_{timeframe}"
        _data_cache[cache_key] = df.copy()
        _cache_timestamps[cache_key] = datetime.now().timestamp()
        logger.debug(f"Data cached for {cache_key}")
        
    except Exception as e:
        logger.error(f"Error caching data: {e}")

def clear_cache() -> None:
    """Clear all cached data"""
    global _data_cache, _cache_timestamps
    _data_cache.clear()
    _cache_timestamps.clear()
    logger.info("Data cache cleared")
