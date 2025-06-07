"""
FlowAI ICT Trading Bot Data Handler
Manages data fetching, processing, and caching from various sources
"""

import pandas as pd
import numpy as np
import yfinance as yf
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Tuple, Any
import time
import os
from . import config
from . import utils

# Setup logger
logger = logging.getLogger("FlowAI_Bot")

class DataHandler:
    """
    Handles all data operations for the trading bot
    """
    
    def __init__(self):
        self.cache = {}
        self.cache_duration = 300  # 5 minutes cache
        
    def fetch_ohlcv_data(self, symbol: str, timeframe: str, limit: int = 1000) -> pd.DataFrame:
        """
        Fetch OHLCV data from Yahoo Finance
        """
        try:
            cache_key = f"{symbol}_{timeframe}_{limit}"
            current_time = time.time()
            
            # Check cache
            if cache_key in self.cache:
                cached_data, cache_time = self.cache[cache_key]
                if current_time - cache_time < self.cache_duration:
                    logger.debug(f"Using cached data for {symbol} ({timeframe})")
                    return cached_data
            
            logger.info(f"Fetching OHLCV: {symbol} ({timeframe}), {limit} candles from yahoo...")
            
            # Map timeframe to yfinance format
            interval_map = {
                '1m': '1m', '5m': '5m', '15m': '15m', '30m': '30m',
                '1h': '1h', '2h': '2h', '4h': '4h',
                '1d': '1d', '1w': '1wk', '1M': '1mo'
            }
            
            yf_interval = interval_map.get(timeframe, '1h')
            
            # Calculate period based on timeframe and limit
            if timeframe in ['1m', '5m', '15m', '30m']:
                period = f"{min(limit * self._get_minutes(timeframe), 7*24*60)}m"
            elif timeframe in ['1h', '2h', '4h']:
                days = min(limit * self._get_hours(timeframe) // 24 + 1, 730)
                period = f"{days}d"
            else:
                period = "2y"
            
            # Fetch data from yfinance
            ticker = yf.Ticker(symbol)
            data = ticker.history(period=period, interval=yf_interval)
            
            if data.empty:
                logger.error(f"No data received for {symbol}")
                return pd.DataFrame()
            
            # Standardize column names
            data = data.rename(columns={
                'Open': 'Open',
                'High': 'High', 
                'Low': 'Low',
                'Close': 'Close',
                'Volume': 'Volume'
            })
            
            # Ensure we have the required columns
            required_columns = ['Open', 'High', 'Low', 'Close', 'Volume']
            for col in required_columns:
                if col not in data.columns:
                    logger.warning(f"Missing column {col}, filling with Close price")
                    data[col] = data['Close'] if 'Close' in data.columns else 0
            
            # Clean data
            data = data[required_columns].copy()
            data = data.dropna()
            
            # Limit to requested number of candles
            if len(data) > limit:
                data = data.tail(limit)
            
            # Add technical indicators
            data = self._add_basic_indicators(data)
            
            # Cache the data
            self.cache[cache_key] = (data.copy(), current_time)
            
            logger.info(f"Fetched {len(data)} candles from Yahoo Finance for {symbol}")
            return data
            
        except Exception as e:
            logger.error(f"Error fetching data for {symbol}: {e}")
            return pd.DataFrame()
    
    def _get_minutes(self, timeframe: str) -> int:
        """Get minutes for timeframe"""
        mapping = {'1m': 1, '5m': 5, '15m': 15, '30m': 30}
        return mapping.get(timeframe, 60)
    
    def _get_hours(self, timeframe: str) -> int:
        """Get hours for timeframe"""
        mapping = {'1h': 1, '2h': 2, '4h': 4}
        return mapping.get(timeframe, 1)
    
    def _add_basic_indicators(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Add basic technical indicators to the dataframe
        """
        try:
            # Simple Moving Averages
            df['SMA_10'] = df['Close'].rolling(window=10).mean()
            df['SMA_20'] = df['Close'].rolling(window=20).mean()
            df['SMA_50'] = df['Close'].rolling(window=50).mean()
            
            # RSI
            df['RSI'] = self._calculate_rsi(df['Close'], period=14)
            
            # Fill NaN values
            df = df.fillna(method='ffill').fillna(0)
            
            return df
            
        except Exception as e:
            logger.error(f"Error adding basic indicators: {e}")
            return df
    
    def _calculate_rsi(self, prices: pd.Series, period: int = 14) -> pd.Series:
        """
        Calculate RSI (Relative Strength Index)
        """
        try:
            delta = prices.diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
            rs = gain / loss
            rsi = 100 - (100 / (1 + rs))
            return rsi.fillna(50)
        except Exception:
            return pd.Series(index=prices.index, data=50.0)
    
    def get_processed_data(self, symbol: str, timeframe: str, limit: int = None) -> pd.DataFrame:
        """
        Get processed data ready for analysis
        """
        if limit is None:
            limit = config.CANDLE_LIMIT
            
        # Calculate required lookback for features
        primary_tf_feature_lookback = max(config.AI_RETURN_PERIODS) + \
                                    config.AI_VOLATILITY_PERIOD + \
                                    config.AI_ICT_FEATURE_LOOKBACK + 100
        
        total_limit = max(limit, primary_tf_feature_lookback)
        
        logger.info(f"Fetching primary TF ({timeframe}, {total_limit} candles) data for {symbol}...")
        
        df = self.fetch_ohlcv_data(symbol, timeframe, total_limit)
        
        if df.empty:
            logger.error(f"No data available for {symbol}")
            return pd.DataFrame()
        
        return df
    
    def get_htf_data(self, symbol: str, htf_timeframes: List[str]) -> Dict[str, pd.DataFrame]:
        """
        Get Higher Time Frame data for multiple timeframes
        """
        htf_data = {}
        
        for htf in htf_timeframes:
            try:
                logger.info(f"Fetching HTF ({htf}, {config.HTF_LOOKBACK_CANDLES} candles) data for {symbol}...")
                
                htf_df = self.fetch_ohlcv_data(symbol, htf, config.HTF_LOOKBACK_CANDLES)
                
                if not htf_df.empty:
                    htf_data[htf] = htf_df
                    logger.debug(f"HTF {htf}: {len(htf_df)} candles loaded")
                else:
                    logger.warning(f"No HTF data available for {htf}")
                    
            except Exception as e:
                logger.error(f"Error fetching HTF data for {htf}: {e}")
        
        return htf_data
    
    def validate_data_quality(self, df: pd.DataFrame) -> bool:
        """
        Validate data quality and completeness
        """
        if df.empty:
            logger.error("DataFrame is empty")
            return False
        
        required_columns = ['Open', 'High', 'Low', 'Close', 'Volume']
        missing_columns = [col for col in required_columns if col not in df.columns]
        
        if missing_columns:
            logger.error(f"Missing required columns: {missing_columns}")
            return False
        
        # Check for data consistency
        if (df['High'] < df['Low']).any():
            logger.warning("Data inconsistency: High < Low detected")
            return False
        
        if (df['High'] < df['Close']).any() or (df['Low'] > df['Close']).any():
            logger.warning("Data inconsistency: Close outside High/Low range")
            return False
        
        # Check for sufficient data
        if len(df) < 50:
            logger.warning(f"Insufficient data: only {len(df)} candles")
            return False
        
        logger.debug("Data quality validation passed")
        return True
    
    def get_latest_price(self, symbol: str) -> Optional[float]:
        """
        Get the latest price for a symbol
        """
        try:
            df = self.fetch_ohlcv_data(symbol, '1m', 1)
            if not df.empty:
                return float(df['Close'].iloc[-1])
        except Exception as e:
            logger.error(f"Error getting latest price for {symbol}: {e}")
        
        return None
    
    def calculate_volatility(self, df: pd.DataFrame, period: int = 20) -> pd.Series:
        """
        Calculate price volatility
        """
        try:
            returns = df['Close'].pct_change()
            volatility = returns.rolling(window=period).std() * np.sqrt(period)
            return volatility.fillna(0)
        except Exception as e:
            logger.error(f"Error calculating volatility: {e}")
            return pd.Series(index=df.index, data=0.0)
    
    def get_market_hours_info(self, symbol: str) -> Dict[str, Any]:
        """
        Get market hours information for a symbol
        """
        # Basic market hours (can be expanded)
        market_info = {
            'is_open': True,  # Crypto markets are always open
            'next_open': None,
            'next_close': None,
            'timezone': 'UTC'
        }
        
        # For traditional markets, add specific hours
        if symbol.endswith('=F') or any(x in symbol for x in ['GC', 'SI', 'CL']):
            # Futures markets
            market_info.update({
                'market_type': 'futures',
                'trading_hours': '23:00 Sun - 22:00 Fri (UTC)'
            })
        
        return market_info

# Create global instance
data_handler = DataHandler()

# Convenience functions
def fetch_ohlcv_data(symbol: str, timeframe: str, limit: int = 1000) -> pd.DataFrame:
    """Convenience function to fetch OHLCV data"""
    return data_handler.fetch_ohlcv_data(symbol, timeframe, limit)

def get_processed_data(symbol: str, timeframe: str, limit: int = None) -> pd.DataFrame:
    """Convenience function to get processed data"""
    return data_handler.get_processed_data(symbol, timeframe, limit)

def get_htf_data(symbol: str, htf_timeframes: List[str]) -> Dict[str, pd.DataFrame]:
    """Convenience function to get HTF data"""
    return data_handler.get_htf_data(symbol, htf_timeframes)
