#!/usr/bin/env python3
"""
Yahoo Finance Smart Fetcher v3.0 - Error-Free Version
Compatible with all yfinance versions
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

class YahooCacheManager:
    """Simple cache manager for reducing API calls"""
    
    def __init__(self, cache_dir="cache", cache_duration_hours=1):
        self.cache_dir = cache_dir
        self.cache_duration = timedelta(hours=cache_duration_hours)
        os.makedirs(cache_dir, exist_ok=True)
    
    def get_cache_path(self, symbol, period, interval):
        return os.path.join(self.cache_dir, f"{symbol}_{period}_{interval}.pkl")
    
    def is_cache_valid(self, cache_path):
        if not os.path.exists(cache_path):
            return False
        cache_time = datetime.fromtimestamp(os.path.getmtime(cache_path))
        return datetime.now() - cache_time < self.cache_duration
    
    def get_cached_data(self, symbol, period, interval):
        cache_path = self.get_cache_path(symbol, period, interval)
        if self.is_cache_valid(cache_path):
            try:
                with open(cache_path, 'rb') as f:
                    data = pickle.load(f)
                    logger.info(f"Using cached data for {symbol}")
                    return data
            except Exception as e:
                logger.warning(f"Failed to load cache: {e}")
        return None
    
    def save_to_cache(self, data, symbol, period, interval):
        cache_path = self.get_cache_path(symbol, period, interval)
        try:
            with open(cache_path, 'wb') as f:
                pickle.dump(data, f)
            logger.info(f"Data cached for {symbol}")
        except Exception as e:
            logger.error(f"Failed to cache data: {e}")

class SimpleYahooFetcher:
    """Simple, safe Yahoo Finance fetcher - Error-Free"""
    
    def __init__(self, requests_per_minute=15, cache_duration_hours=1):
        self.requests_per_minute = requests_per_minute
        self.last_request_time = 0
        self.cache_manager = YahooCacheManager(cache_duration_hours=cache_duration_hours)
        self.failed_attempts = 0
    
    def _calculate_delay(self):
        """Calculate delay for rate limiting"""
        min_interval = 60 / self.requests_per_minute
        current_time = time.time()
        time_since_last = current_time - self.last_request_time
        return max(0, min_interval - time_since_last)
    
    def _smart_delay(self, attempt):
        """Smart delay with exponential backoff"""
        if attempt == 0:
            return 0
        base_delay = min(30, 5 * (2 ** (attempt - 1)))
        jitter = random.uniform(0.5, 1.5)
        return base_delay * jitter
    
    def fetch_data(self, symbol, period="5d", interval="1h", max_retries=5):
        """Fetch data with only valid yfinance parameters"""
        
        # Check cache first
        cached_data = self.cache_manager.get_cached_data(symbol, period, interval)
        if cached_data is not None:
            return cached_data
        
        # Apply basic rate limiting
        delay = self._calculate_delay()
        if delay > 0:
            logger.info(f"Rate limiting: waiting {delay:.1f} seconds")
            time.sleep(delay)
        
        for attempt in range(max_retries):
            try:
                # Smart delay between attempts
                if attempt > 0:
                    smart_delay = self._smart_delay(attempt)
                    logger.info(f"Attempt {attempt + 1}: waiting {smart_delay:.1f} seconds")
                    time.sleep(smart_delay)
                
                # Simple yfinance call with only valid parameters
                logger.info(f"Fetching {symbol} data (attempt {attempt + 1}/{max_retries})")
                
                # Use only guaranteed valid parameters
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
                    # Success!
                    self.failed_attempts = 0
                    self.last_request_time = time.time()
                    self.cache_manager.save_to_cache(data, symbol, period, interval)
                    
                    logger.info(f"✅ Successfully fetched {len(data)} records for {symbol}")
                    return data
                else:
                    logger.warning(f"⚠️ Empty data received for {symbol}")
                    
            except Exception as e:
                error_str = str(e).lower()
                
                if any(keyword in error_str for keyword in ['429', 'rate limit', 'too many requests']):
                    logger.warning(f"🚫 Rate limit detected: {e}")
                    self.failed_attempts += 1
                    
                    if attempt < max_retries - 1:
                        rate_limit_delay = 60 + random.uniform(30, 90)
                        logger.info(f"Rate limit backoff: {rate_limit_delay:.1f} seconds")
                        time.sleep(rate_limit_delay)
                        continue
                        
                elif 'no data found' in error_str:
                    logger.error(f"❌ No data available for {symbol}")
                    break
                    
                else:
                    logger.error(f"❌ Error: {e}")
                    if attempt < max_retries - 1:
                        time.sleep(random.uniform(2, 5))
                        continue
                
                break
        
        logger.error(f"❌ Failed to fetch {symbol} after {max_retries} attempts")
        return pd.DataFrame()
    
    def reset(self):
        """Reset fetcher state"""
        self.failed_attempts = 0
        logger.info("Yahoo fetcher reset")

# Global instance
_simple_fetcher = SimpleYahooFetcher(requests_per_minute=12)

def fetch_yahoo_data_smart(symbol, period="5d", interval="1h"):
    """Main function - error-free"""
    return _simple_fetcher.fetch_data(symbol, period, interval)

def reset_yahoo_fetcher():
    """Reset the global fetcher"""
    global _simple_fetcher
    _simple_fetcher.reset()

def fetch_gold_data(period="5d", interval="1h"):
    """Fetch gold data safely"""
    return fetch_yahoo_data_smart("GC=F", period, interval)

def fetch_symbol_data(symbol, period="5d", interval="1h"):
    """Fetch any symbol safely"""
    return fetch_yahoo_data_smart(symbol, period, interval)
