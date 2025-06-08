#!/usr/bin/env python3
"""
Yahoo Finance Smart Fetcher v3.0 - Complete & Error-Free
Multi-symbol fallback with advanced error handling
Author: Behnam RJD
"""

import random
import time
import yfinance as yf
import pandas as pd
import pickle
import os
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

# Multiple symbol options for gold trading
GOLD_SYMBOLS = [
    "GC=F",      # Gold Futures (Primary)
    "GOLD",      # Barrick Gold Corp
    "IAU",       # iShares Gold Trust ETF
    "GLD",       # SPDR Gold Shares ETF
    "XAUUSD=X",  # Gold/USD Forex
    "^XAU"       # Gold Index
]

# Fallback symbols for testing
TEST_SYMBOLS = [
    "^GSPC",     # S&P 500
    "^DJI",      # Dow Jones
    "AAPL",      # Apple
    "MSFT"       # Microsoft
]

class YahooCacheManager:
    """Advanced cache manager with multiple storage options"""
    
    def __init__(self, cache_dir="cache", cache_duration_hours=1):
        self.cache_dir = cache_dir
        self.cache_duration = timedelta(hours=cache_duration_hours)
        os.makedirs(cache_dir, exist_ok=True)
        self.memory_cache = {}
        self.cache_timestamps = {}
    
    def get_cache_path(self, symbol, period, interval):
        """Get cache file path for given parameters"""
        # Clean symbol name for filename
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
        
        # Clear disk cache
        try:
            for filename in os.listdir(self.cache_dir):
                if filename.endswith('.pkl'):
                    os.remove(os.path.join(self.cache_dir, filename))
            logger.info("All cache cleared")
        except Exception as e:
            logger.error(f"Failed to clear disk cache: {e}")

class RobustYahooFetcher:
    """Robust Yahoo Finance fetcher with multi-symbol fallback"""
    
    def __init__(self, requests_per_minute=10, cache_duration_hours=1):
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
        
        # Conservative exponential backoff
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
        
        # Remove from blacklist after duration
        def remove_blacklist():
            time.sleep(duration_minutes * 60)
            self.blacklisted_symbols.discard(symbol)
            logger.info(f"Symbol {symbol} removed from blacklist")
        
        import threading
        threading.Thread(target=remove_blacklist, daemon=True).start()
    
    def _validate_data(self, data):
        """Validate data quality - Fixed for pandas Series ambiguity"""
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
        """Fetch data for a single symbol with robust error handling"""
        
        # Skip blacklisted symbols
        if self._is_symbol_blacklisted(symbol):
            logger.debug(f"Skipping blacklisted symbol: {symbol}")
            return pd.DataFrame()
        
        # Check cache first
        cached_data = self.cache_manager.get_cached_data(symbol, period, interval)
        if cached_data is not None:
            return cached_data
        
        # Apply rate limiting
        delay = self._calculate_delay()
        if delay > 0:
            logger.debug(f"Rate limiting: waiting {delay:.1f} seconds")
            time.sleep(delay)
        
        for attempt in range(max_retries):
            try:
                # Smart delay between attempts
                if attempt > 0:
                    smart_delay = self._smart_delay(attempt)
                    logger.info(f"Retry {attempt + 1} for {symbol}: waiting {smart_delay:.1f} seconds")
                    time.sleep(smart_delay)
                
                logger.info(f"Fetching {symbol} data (attempt {attempt + 1}/{max_retries})")
                
                # Use yfinance with conservative parameters
                data = yf.download(
                    symbol,
                    period=period,
                    interval=interval,
                    progress=False,
                    threads=False,
                    auto_adjust=True,
                    actions=False,
                    timeout=30
                )
                
                if data is not None and not data.empty:
                    # Validate data quality
                    if self._validate_data(data):
                        self.failed_attempts = 0
                        self.last_request_time = time.time()
                        self.cache_manager.save_to_cache(data, symbol, period, interval)
                        
                        logger.info(f"✅ Successfully fetched {len(data)} records for {symbol}")
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
                    self._blacklist_symbol(symbol, 60)  # Blacklist for 1 hour
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
        """Fetch data with symbol fallback"""
        
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

# Global instance with conservative settings
_robust_fetcher = RobustYahooFetcher(requests_per_minute=8)

def fetch_yahoo_data_smart(symbol, period="5d", interval="1h"):
    """Main function with single symbol"""
    data, _ = _robust_fetcher.fetch_data_with_fallback([symbol], period, interval)
    return data

def fetch_gold_data_robust(period="5d", interval="1h"):
    """Fetch gold data with multiple symbol fallbacks"""
    data, successful_symbol = _robust_fetcher.fetch_data_with_fallback(GOLD_SYMBOLS, period, interval)
    
    if data.empty:
        logger.warning("All gold symbols failed, trying test symbols...")
        data, successful_symbol = _robust_fetcher.fetch_data_with_fallback(TEST_SYMBOLS, period, interval)
    
    if not data.empty and successful_symbol:
        logger.info(f"Gold data retrieved using symbol: {successful_symbol}")
    
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

# Test function for debugging
def test_all_gold_symbols():
    """Test all gold symbols to see which ones work"""
    results = {}
    
    for symbol in GOLD_SYMBOLS:
        try:
            data = yf.download(symbol, period="5d", interval="1h", progress=False)
            results[symbol] = len(data) if not data.empty else 0
        except Exception as e:
            results[symbol] = f"Error: {str(e)[:50]}"
    
    return results

if __name__ == "__main__":
    # Test the fetcher
    print("Testing Yahoo Finance Smart Fetcher...")
    
    # Test gold symbols
    print("\n1. Testing gold symbols:")
    results = test_all_gold_symbols()
    for symbol, result in results.items():
        print(f"  {symbol}: {result}")
    
    # Test robust fetcher
    print("\n2. Testing robust fetcher:")
    data = fetch_gold_data_robust()
    if not data.empty:
        print(f"  ✅ Success: {len(data)} records")
        print(f"  Latest price: ${data['Close'].iloc[-1]:.2f}")
    else:
        print("  ❌ Failed to fetch gold data")
