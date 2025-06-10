#!/usr/bin/env python3
"""
Yahoo Finance Smart Fetcher v3.1 - Enhanced with Real-time Validation
Multi-symbol fallback with real-time data validation and price accuracy
Author: Behnam RJD
"""

import random
import time
import yfinance as yf
import pandas as pd
import pickle
import os
import logging
from datetime import datetime, timedelta, timezone
import numpy as np
import pytz

logger = logging.getLogger(__name__)

# Enhanced Gold symbols for fallback with real-time priority
GOLD_SYMBOLS = [
    "XAUUSD=X",  # Gold/USD Forex (Real-time priority)
    "GC=F",      # Gold Futures
    "GLD",       # SPDR Gold Shares ETF
    "IAU",       # iShares Gold Trust ETF
    "GOLD",      # Barrick Gold Corp
    "^XAU"       # Gold Index
]

# Test symbols for fallback
TEST_SYMBOLS = [
    "^GSPC",     # S&P 500
    "^DJI",      # Dow Jones
    "AAPL",      # Apple
    "MSFT"       # Microsoft
]

class YahooCacheManager:
    """Advanced cache manager with memory and disk storage"""
    
    def __init__(self, cache_dir="cache", cache_duration_hours=0.083):  # 5 minutes default
        self.cache_dir = cache_dir
        self.cache_duration = timedelta(hours=cache_duration_hours)
        os.makedirs(cache_dir, exist_ok=True)
        self.memory_cache = {}
        self.cache_timestamps = {}
    
    def get_cache_path(self, symbol, period, interval):
        """Get cache file path with safe filename"""
        clean_symbol = symbol.replace('=', '_').replace('^', '_').replace('/', '_')
        filename = f"{clean_symbol}_{period}_{interval}.pkl"
        return os.path.join(self.cache_dir, filename)
    
    def is_cache_valid(self, cache_path):
        """Check if cache file is still valid"""
        if not os.path.exists(cache_path):
            return False
        try:
            cache_time = datetime.fromtimestamp(os.path.getmtime(cache_path))
            return datetime.now() - cache_time < self.cache_duration
        except Exception:
            return False
    
    def get_cached_data(self, symbol, period, interval):
        """Get data from cache (memory first, then disk)"""
        cache_key = f"{symbol}_{period}_{interval}"
        
        # Check memory cache first
        if cache_key in self.memory_cache and cache_key in self.cache_timestamps:
            cache_age = datetime.now().timestamp() - self.cache_timestamps[cache_key]
            if cache_age < self.cache_duration.total_seconds():
                logger.debug(f"Using memory cache for {symbol}")
                return self.memory_cache[cache_key].copy()
        
        # Check disk cache
        cache_path = self.get_cache_path(symbol, period, interval)
        if self.is_cache_valid(cache_path):
            try:
                with open(cache_path, 'rb') as f:
                    data = pickle.load(f)
                    # Store in memory cache for next time
                    self.memory_cache[cache_key] = data.copy()
                    self.cache_timestamps[cache_key] = datetime.now().timestamp()
                    logger.info(f"Using disk cache for {symbol}")
                    return data
            except Exception as e:
                logger.warning(f"Failed to load cache for {symbol}: {e}")
        
        return None
    
    def save_to_cache(self, data, symbol, period, interval):
        """Save data to both memory and disk cache"""
        cache_key = f"{symbol}_{period}_{interval}"
        cache_path = self.get_cache_path(symbol, period, interval)
        
        try:
            # Save to memory cache
            self.memory_cache[cache_key] = data.copy()
            self.cache_timestamps[cache_key] = datetime.now().timestamp()
            
            # Save to disk cache
            with open(cache_path, 'wb') as f:
                pickle.dump(data, f)
            
            logger.info(f"Data cached for {symbol}")
        except Exception as e:
            logger.error(f"Failed to cache data for {symbol}: {e}")
    
    def clear_cache(self):
        """Clear all cached data"""
        self.memory_cache.clear()
        self.cache_timestamps.clear()
        
        try:
            for filename in os.listdir(self.cache_dir):
                if filename.endswith('.pkl'):
                    os.remove(os.path.join(self.cache_dir, filename))
            logger.info("All cache cleared")
        except Exception as e:
            logger.error(f"Failed to clear disk cache: {e}")

class RobustYahooFetcher:
    """Enhanced Yahoo Finance fetcher with real-time validation"""
    
    def __init__(self, requests_per_minute=8, cache_duration_hours=0.083):
        self.requests_per_minute = requests_per_minute
        self.last_request_time = 0
        self.cache_manager = YahooCacheManager(cache_duration_hours=cache_duration_hours)
        self.failed_attempts = 0
        self.blacklisted_symbols = set()
    
    def _calculate_delay(self):
        """Calculate delay for conservative rate limiting"""
        min_interval = 60 / self.requests_per_minute
        current_time = time.time()
        time_since_last = current_time - self.last_request_time
        return max(0, min_interval - time_since_last)
    
    def _smart_delay(self, attempt):
        """Smart delay with exponential backoff and jitter"""
        if attempt == 0:
            return 0
        base_delay = min(60, 10 * (2 ** (attempt - 1)))
        jitter = random.uniform(0.7, 1.3)
        return base_delay * jitter
    
    def _is_symbol_blacklisted(self, symbol):
        """Check if symbol is temporarily blacklisted"""
        return symbol in self.blacklisted_symbols
    
    def _blacklist_symbol(self, symbol, duration_minutes=30):
        """Temporarily blacklist a problematic symbol"""
        self.blacklisted_symbols.add(symbol)
        logger.warning(f"Symbol {symbol} blacklisted for {duration_minutes} minutes")
        
        def remove_blacklist():
            time.sleep(duration_minutes * 60)
            self.blacklisted_symbols.discard(symbol)
            logger.info(f"Symbol {symbol} removed from blacklist")
        
        import threading
        threading.Thread(target=remove_blacklist, daemon=True).start()
    
    def _validate_data_freshness(self, data, max_delay_minutes=15):
        """Validate if data is fresh enough for trading"""
        if data.empty:
            return False, "No data available"
        
        try:
            latest_time = data.index[-1]
            
            # Convert to UTC if timezone-naive
            if latest_time.tzinfo is None:
                latest_time = latest_time.replace(tzinfo=timezone.utc)
            
            current_time = datetime.now(timezone.utc)
            delay_minutes = (current_time - latest_time).total_seconds() / 60
            
            if delay_minutes > max_delay_minutes:
                return False, f"Data is {delay_minutes:.1f} minutes old (max: {max_delay_minutes})"
            
            return True, f"Data is fresh ({delay_minutes:.1f} minutes old)"
            
        except Exception as e:
            return False, f"Error validating data freshness: {e}"
    
    def _get_real_time_price_fallback(self, symbol):
        """Get real-time price from multiple sources"""
        fallback_symbols = {
            'GC=F': ['XAUUSD=X', 'GLD', 'IAU'],
            'XAUUSD=X': ['GC=F', 'GLD', 'IAU'],
            'GLD': ['XAUUSD=X', 'GC=F', 'IAU'],
            'IAU': ['XAUUSD=X', 'GC=F', 'GLD']
        }
        
        symbols_to_try = [symbol] + fallback_symbols.get(symbol, [])
        
        for test_symbol in symbols_to_try:
            try:
                logger.info(f"Trying real-time fetch for {test_symbol}")
                data = yf.download(
                    test_symbol,
                    period="1d",
                    interval="1m",
                    progress=False,
                    threads=False,
                    timeout=10,
                    group_by=None
                )
                
                if isinstance(data.columns, pd.MultiIndex):
                    data.columns = data.columns.droplevel(0)
                
                if not data.empty:
                    is_fresh, message = self._validate_data_freshness(data, max_delay_minutes=10)
                    if is_fresh:
                        logger.info(f"✅ Fresh real-time data from {test_symbol}: {message}")
                        logger.info(f"💰 Real-time price: ${data['Close'].iloc[-1]:.2f}")
                        return data, test_symbol
                    else:
                        logger.warning(f"⚠️ Stale real-time data from {test_symbol}: {message}")
                
            except Exception as e:
                logger.warning(f"Failed to fetch real-time from {test_symbol}: {e}")
                continue
        
        return pd.DataFrame(), None
    
    def _resample_data(self, data, target_interval):
        """Resample 1-minute data to target interval"""
        try:
            # Mapping intervals to pandas frequency
            interval_map = {
                '5m': '5T',
                '15m': '15T', 
                '1h': '1H',
                '4h': '4H',
                '1d': '1D'
            }
            
            freq = interval_map.get(target_interval, '1H')
            
            resampled = data.resample(freq).agg({
                'Open': 'first',
                'High': 'max',
                'Low': 'min',
                'Close': 'last',
                'Volume': 'sum'
            }).dropna()
            
            logger.info(f"Resampled data from 1m to {target_interval}: {len(resampled)} candles")
            return resampled
            
        except Exception as e:
            logger.error(f"Error resampling data: {e}")
            return data
    
    def _validate_data(self, data):
        """Validate data quality - Enhanced for pandas Series ambiguity"""
        try:
            # Basic existence check
            if data is None or data.empty:
                return False
            
            # Check for required columns
            required_columns = ['Open', 'High', 'Low', 'Close']
            for col in required_columns:
                if col not in data.columns:
                    logger.warning(f"Missing column: {col}")
                    return False
            
            # Check minimum data length
            if len(data) < 1:
                logger.warning("No data rows")
                return False
            
            # Validate latest price data (avoid Series truth ambiguity)
            try:
                latest_close = float(data['Close'].iloc[-1])
                latest_high = float(data['High'].iloc[-1])
                latest_low = float(data['Low'].iloc[-1])
                latest_open = float(data['Open'].iloc[-1])
                
                # Check for valid numbers
                if any(pd.isna(x) for x in [latest_close, latest_high, latest_low, latest_open]):
                    logger.warning("NaN values in latest data")
                    return False
                
                # Check for positive prices
                if any(x <= 0 for x in [latest_close, latest_high, latest_low, latest_open]):
                    logger.warning("Non-positive prices detected")
                    return False
                
                # Check OHLC relationships
                if latest_high < latest_low:
                    logger.warning("High < Low relationship error")
                    return False
                
                if latest_high < max(latest_open, latest_close):
                    logger.warning("High < Open/Close relationship error")
                    return False
                    
                if latest_low > min(latest_open, latest_close):
                    logger.warning("Low > Open/Close relationship error")
                    return False
                
            except (IndexError, ValueError, TypeError) as e:
                logger.warning(f"Price validation error: {e}")
                return False
            
            logger.debug(f"Data validation passed: {len(data)} records")
            return True
            
        except Exception as e:
            logger.error(f"Data validation error: {e}")
            return False
    
    def fetch_single_symbol(self, symbol, period="5d", interval="1h", max_retries=3):
        """Fetch data for a single symbol with enhanced real-time validation"""
        
        if self._is_symbol_blacklisted(symbol):
            logger.debug(f"Skipping blacklisted symbol: {symbol}")
            return pd.DataFrame()
        
        # Check cache first
        cached_data = self.cache_manager.get_cached_data(symbol, period, interval)
        if cached_data is not None:
            # Validate cached data freshness
            is_fresh, message = self._validate_data_freshness(cached_data, max_delay_minutes=30)
            if is_fresh:
                logger.info(f"Using fresh cached data: {message}")
                logger.info(f"💰 Cached price: ${cached_data['Close'].iloc[-1]:.2f}")
                return cached_data
            else:
                logger.warning(f"Cached data is stale: {message}. Fetching fresh data...")
        
        # Apply rate limiting
        delay = self._calculate_delay()
        if delay > 0:
            logger.debug(f"Rate limiting: waiting {delay:.1f} seconds")
            time.sleep(delay)
        
        # Try real-time fallback first for critical intervals
        if interval in ['1m', '5m', '15m', '1h']:
            logger.info(f"🔄 Attempting real-time fetch for {symbol}")
            real_time_data, successful_symbol = self._get_real_time_price_fallback(symbol)
            if not real_time_data.empty:
                # Convert to requested interval if needed
                if interval != '1m':
                    real_time_data = self._resample_data(real_time_data, interval)
                
                self.cache_manager.save_to_cache(real_time_data, symbol, period, interval)
                logger.info(f"✅ Real-time data fetched from {successful_symbol}")
                return real_time_data
        
        # Fallback to standard fetch
        for attempt in range(max_retries):
            try:
                if attempt > 0:
                    smart_delay = self._smart_delay(attempt)
                    logger.info(f"Retry {attempt + 1} for {symbol}: waiting {smart_delay:.1f} seconds")
                    time.sleep(smart_delay)
                
                logger.info(f"Fetching {symbol} data (attempt {attempt + 1}/{max_retries})")
                
                data = yf.download(
                    symbol,
                    period=period,
                    interval=interval,
                    progress=False,
                    threads=False,
                    auto_adjust=True,
                    actions=False,
                    timeout=30,
                    group_by=None
                )
                
                if isinstance(data.columns, pd.MultiIndex):
                    data.columns = data.columns.droplevel(0)
                
                if data is not None and not data.empty:
                    # Enhanced validation
                    if self._validate_data(data):
                        # Check data freshness
                        is_fresh, message = self._validate_data_freshness(data, max_delay_minutes=60)
                        
                        if not is_fresh:
                            logger.warning(f"⚠️ Data freshness issue: {message}")
                            # Try real-time fallback
                            real_time_data, successful_symbol = self._get_real_time_price_fallback(symbol)
                            if not real_time_data.empty:
                                if interval != '1m':
                                    real_time_data = self._resample_data(real_time_data, interval)
                                data = real_time_data
                                logger.info(f"✅ Used real-time fallback from {successful_symbol}")
                        
                        self.failed_attempts = 0
                        self.last_request_time = time.time()
                        self.cache_manager.save_to_cache(data, symbol, period, interval)
                        
                        logger.info(f"✅ Successfully fetched {len(data)} records for {symbol}")
                        logger.info(f"📊 Data range: {data.index[0]} to {data.index[-1]}")
                        logger.info(f"💰 Latest price: ${data['Close'].iloc[-1]:.2f}")
                        
                        # Log data freshness for debugging
                        latest_time = data.index[-1]
                        current_time = datetime.now(timezone.utc)
                        if latest_time.tzinfo is None:
                            latest_time = latest_time.replace(tzinfo=timezone.utc)
                        delay_minutes = (current_time - latest_time).total_seconds() / 60
                        logger.info(f"⏰ Data age: {delay_minutes:.1f} minutes")
                        
                        return data
                    else:
                        logger.warning(f"Invalid data quality for {symbol}")
                        continue
                else:
                    logger.warning(f"⚠️ Empty data received for {symbol}")
                    
            except Exception as e:
                error_str = str(e).lower()
                
                if any(keyword in error_str for keyword in ['429', 'rate limit', 'too many requests']):
                    logger.warning(f"🚫 Rate limit detected for {symbol}: {e}")
                    self.failed_attempts += 1
                    
                    if attempt < max_retries - 1:
                        rate_limit_delay = 90 + random.uniform(30, 60)
                        logger.info(f"Rate limit backoff: {rate_limit_delay:.1f} seconds")
                        time.sleep(rate_limit_delay)
                        continue
                        
                elif any(keyword in error_str for keyword in ['delisted', 'no price data', 'not found']):
                    logger.error(f"❌ Symbol {symbol} appears to be delisted or invalid")
                    self._blacklist_symbol(symbol, 60)
                    break
                    
                elif any(keyword in error_str for keyword in ['network', 'connection', 'timeout']):
                    logger.warning(f"🌐 Network error for {symbol}: {e}")
                    if attempt < max_retries - 1:
                        time.sleep(random.uniform(10, 20))
                        continue
                    
                else:
                    logger.error(f"❌ Unexpected error for {symbol}: {e}")
                    if attempt < max_retries - 1:
                        time.sleep(random.uniform(5, 10))
                        continue
                
                break
        
        logger.error(f"❌ Failed to fetch {symbol} after {max_retries} attempts")
        return pd.DataFrame()
    
    def fetch_data_with_fallback(self, symbols, period="5d", interval="1h"):
        """Fetch data with symbol fallback - Enhanced with real-time priority"""
        
        if isinstance(symbols, str):
            symbols = [symbols]
        
        for symbol in symbols:
            logger.info(f"Trying symbol: {symbol}")
            data = self.fetch_single_symbol(symbol, period, interval)
            
            if data is not None and not data.empty:
                logger.info(f"✅ Success with symbol: {symbol}")
                return data, symbol
        
        logger.error("❌ All symbols failed")
        return pd.DataFrame(), None
    
    def reset(self):
        """Reset fetcher state"""
        self.failed_attempts = 0
        self.blacklisted_symbols.clear()
        logger.info("Yahoo fetcher reset")

# Global instance with enhanced settings
_robust_fetcher = RobustYahooFetcher(requests_per_minute=8, cache_duration_hours=0.083)

def fetch_yahoo_data_smart(symbol, period="5d", interval="1h"):
    """Main function with single symbol - Enhanced"""
    data, _ = _robust_fetcher.fetch_data_with_fallback([symbol], period, interval)
    return data

def fetch_gold_data_robust(period="5d", interval="1h"):
    """Fetch gold data with enhanced real-time fallbacks"""
    data, successful_symbol = _robust_fetcher.fetch_data_with_fallback(GOLD_SYMBOLS, period, interval)
    
    if data.empty:
        logger.warning("All gold symbols failed, trying test symbols...")
        data, successful_symbol = _robust_fetcher.fetch_data_with_fallback(TEST_SYMBOLS, period, interval)
    
    if not data.empty and successful_symbol:
        logger.info(f"Gold data retrieved using symbol: {successful_symbol}")
        logger.info(f"💰 Current gold price: ${data['Close'].iloc[-1]:.2f}")
    
    return data

def fetch_symbol_with_alternatives(primary_symbol, alternatives=None, period="5d", interval="1h"):
    """Fetch symbol data with alternative symbols"""
    symbols = [primary_symbol]
    if alternatives:
        symbols.extend(alternatives)
    
    data, successful_symbol = _robust_fetcher.fetch_data_with_fallback(symbols, period, interval)
    return data, successful_symbol

def reset_yahoo_fetcher():
    """Reset the global fetcher"""
    global _robust_fetcher
    _robust_fetcher.reset()

def clear_yahoo_cache():
    """Clear all cached data"""
    global _robust_fetcher
    _robust_fetcher.cache_manager.clear_cache()

# Convenience functions
def fetch_gold_data(period="5d", interval="1h"):
    """Fetch gold data with robust fallback"""
    return fetch_gold_data_robust(period, interval)

def fetch_symbol_data(symbol, period="5d", interval="1h"):
    """Fetch any symbol with error handling"""
    return fetch_yahoo_data_smart(symbol, period, interval)

# Enhanced test function
def test_all_gold_symbols():
    """Test all gold symbols with real-time validation"""
    results = {}
    
    for symbol in GOLD_SYMBOLS:
        try:
            logger.info(f"Testing {symbol}...")
            data = yf.download(symbol, period="1d", interval="1h", progress=False, group_by=None)
            if isinstance(data.columns, pd.MultiIndex):
                data.columns = data.columns.droplevel(0)
            
            if not data.empty:
                latest_price = data['Close'].iloc[-1]
                latest_time = data.index[-1]
                current_time = datetime.now(timezone.utc)
                
                if latest_time.tzinfo is None:
                    latest_time = latest_time.replace(tzinfo=timezone.utc)
                
                delay_minutes = (current_time - latest_time).total_seconds() / 60
                
                results[symbol] = {
                    'records': len(data),
                    'price': f"${latest_price:.2f}",
                    'delay_minutes': f"{delay_minutes:.1f}",
                    'status': 'Fresh' if delay_minutes < 30 else 'Stale'
                }
            else:
                results[symbol] = {'status': 'No data'}
                
        except Exception as e:
            results[symbol] = {'status': f"Error: {str(e)[:50]}"}
    
    return results

if __name__ == "__main__":
    # Enhanced test with real-time validation
    print("Testing Enhanced Yahoo Finance Smart Fetcher...")
    
    # Test gold symbols with real-time validation
    print("\n1. Testing gold symbols with real-time validation:")
    results = test_all_gold_symbols()
    for symbol, result in results.items():
        if isinstance(result, dict) and 'price' in result:
            print(f"  {symbol}: {result['records']} records, Price: {result['price']}, "
                  f"Age: {result['delay_minutes']}min ({result['status']})")
        else:
            print(f"  {symbol}: {result}")
    
    # Test enhanced fetcher
    print("\n2. Testing enhanced robust fetcher:")
    data = fetch_gold_data_robust()
    if not data.empty:
        latest_time = data.index[-1]
        current_time = datetime.now(timezone.utc)
        if latest_time.tzinfo is None:
            latest_time = latest_time.replace(tzinfo=timezone.utc)
        delay_minutes = (current_time - latest_time).total_seconds() / 60
        
        print(f"  ✅ Success: {len(data)} records")
        print(f"  💰 Latest price: ${data['Close'].iloc[-1]:.2f}")
        print(f"  ⏰ Data age: {delay_minutes:.1f} minutes")
        print(f"  📊 Data range: {data.index[0]} to {data.index[-1]}")
    else:
        print("  ❌ Failed to fetch gold data")
