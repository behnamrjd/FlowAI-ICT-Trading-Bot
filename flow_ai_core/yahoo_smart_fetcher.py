#!/usr/bin/env python3
"""
Yahoo Finance Smart Fetcher - Anti Rate Limiting System
Handles Yahoo Finance API limitations with intelligent retry and rotation
Author: Behnam RJD
"""

import random
import time
import requests
import yfinance as yf
import pandas as pd
import pickle
import os
import logging
from datetime import datetime, timedelta
from functools import wraps

logger = logging.getLogger(__name__)

# User-Agent Pool for rotation
USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:132.0) Gecko/20100101 Firefox/132.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:132.0) Gecko/20100101 Firefox/132.0',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/133.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0'
]

def get_random_headers():
    """Generate random headers to avoid detection"""
    return {
        'User-Agent': random.choice(USER_AGENTS),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Cache-Control': 'max-age=0',
        'DNT': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none'
    }

class YahooSessionManager:
    """Manages multiple sessions with different headers"""
    
    def __init__(self, num_sessions=5):
        self.sessions = []
        self.current_session = 0
        self.num_sessions = num_sessions
        self.create_sessions()
    
    def create_sessions(self):
        """Create multiple sessions with different headers"""
        self.sessions.clear()
        for i in range(self.num_sessions):
            session = requests.Session()
            session.headers.update(get_random_headers())
            self.sessions.append(session)
        logger.info(f"Created {self.num_sessions} sessions with random headers")
    
    def get_next_session(self):
        """Get next session in rotation"""
        session = self.sessions[self.current_session]
        self.current_session = (self.current_session + 1) % len(self.sessions)
        return session
    
    def reset_sessions(self):
        """Reset all sessions with new headers"""
        self.create_sessions()
        logger.info("All sessions reset with new headers")

class YahooCacheManager:
    """Manages caching to reduce API calls"""
    
    def __init__(self, cache_dir="cache", cache_duration_hours=1):
        self.cache_dir = cache_dir
        self.cache_duration = timedelta(hours=cache_duration_hours)
        os.makedirs(cache_dir, exist_ok=True)
    
    def get_cache_path(self, symbol, period, interval):
        """Get cache file path for given parameters"""
        return os.path.join(self.cache_dir, f"{symbol}_{period}_{interval}.pkl")
    
    def is_cache_valid(self, cache_path):
        """Check if cache is still valid"""
        if not os.path.exists(cache_path):
            return False
        
        cache_time = datetime.fromtimestamp(os.path.getmtime(cache_path))
        return datetime.now() - cache_time < self.cache_duration
    
    def get_cached_data(self, symbol, period, interval):
        """Get data from cache if valid"""
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
        """Save data to cache"""
        cache_path = self.get_cache_path(symbol, period, interval)
        try:
            with open(cache_path, 'wb') as f:
                pickle.dump(data, f)
            logger.info(f"Data cached for {symbol}")
        except Exception as e:
            logger.error(f"Failed to cache data: {e}")

class SmartYahooFetcher:
    """Smart Yahoo Finance fetcher with anti-rate-limiting"""
    
    def __init__(self, requests_per_minute=20, cache_duration_hours=1):
        self.requests_per_minute = requests_per_minute
        self.last_request_time = 0
        self.session_manager = YahooSessionManager()
        self.cache_manager = YahooCacheManager(cache_duration_hours=cache_duration_hours)
        self.failed_attempts = 0
        self.max_failed_attempts = 3
    
    def _calculate_delay(self):
        """Calculate delay needed for rate limiting"""
        min_interval = 60 / self.requests_per_minute
        current_time = time.time()
        time_since_last = current_time - self.last_request_time
        
        if time_since_last < min_interval:
            return min_interval - time_since_last
        return 0
    
    def _handle_rate_limit(self, attempt=0):
        """Handle rate limiting with exponential backoff"""
        base_delay = 60  # 1 minute base delay
        jitter = random.uniform(0.5, 1.5)
        delay = base_delay * (2 ** attempt) * jitter
        
        logger.warning(f"Rate limited! Backing off for {delay:.1f} seconds...")
        
        # Reset sessions during backoff
        self.session_manager.reset_sessions()
        time.sleep(delay)
        
        self.failed_attempts += 1
    
    def fetch_data(self, symbol, period="5d", interval="1h", max_retries=5):
        """Fetch data with smart retry logic"""
        
        # Check cache first
        cached_data = self.cache_manager.get_cached_data(symbol, period, interval)
        if cached_data is not None:
            return cached_data
        
        # Apply rate limiting
        delay = self._calculate_delay()
        if delay > 0:
            logger.info(f"Rate limiting: waiting {delay:.2f} seconds")
            time.sleep(delay)
        
        for attempt in range(max_retries):
            try:
                # Get session with random headers
                session = self.session_manager.get_next_session()
                
                # Create ticker with session
                ticker = yf.Ticker(symbol, session=session)
                
                # Fetch data
                logger.info(f"Fetching {symbol} data (attempt {attempt + 1})")
                data = ticker.history(period=period, interval=interval, progress=False)
                
                if data is not None and not data.empty:
                    # Success! Reset failed attempts and cache data
                    self.failed_attempts = 0
                    self.last_request_time = time.time()
                    self.cache_manager.save_to_cache(data, symbol, period, interval)
                    
                    logger.info(f"Successfully fetched {len(data)} records for {symbol}")
                    return data
                else:
                    logger.warning(f"Empty data received for {symbol}")
                    
            except Exception as e:
                error_str = str(e).lower()
                
                if "429" in error_str or "rate limit" in error_str or "too many requests" in error_str:
                    logger.warning(f"Rate limit detected: {e}")
                    self._handle_rate_limit(attempt)
                    
                    if attempt < max_retries - 1:
                        continue
                else:
                    logger.error(f"Non-rate-limit error: {e}")
                    if attempt < max_retries - 1:
                        time.sleep(random.uniform(1, 3))
                        continue
                    break
        
        logger.error(f"Failed to fetch data for {symbol} after {max_retries} attempts")
        return pd.DataFrame()
    
    def reset(self):
        """Reset fetcher state"""
        self.session_manager.reset_sessions()
        self.failed_attempts = 0
        logger.info("Yahoo fetcher reset")

# Global instance
_smart_fetcher = SmartYahooFetcher()

def fetch_yahoo_data_smart(symbol, period="5d", interval="1h"):
    """Main function to fetch Yahoo Finance data smartly"""
    return _smart_fetcher.fetch_data(symbol, period, interval)

def reset_yahoo_fetcher():
    """Reset the global fetcher instance"""
    global _smart_fetcher
    _smart_fetcher.reset()

# Convenience functions
def fetch_gold_data(period="5d", interval="1h"):
    """Fetch gold (GC=F) data"""
    return fetch_yahoo_data_smart("GC=F", period, interval)

def fetch_symbol_data(symbol, period="5d", interval="1h"):
    """Fetch any symbol data"""
    return fetch_yahoo_data_smart(symbol, period, interval)
