import requests
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

class BrsAPIFetcher:
    def __init__(self, api_key="FreeQZdOYW6D3nNv95jZ9BcYXJHzTJpf"):
        self.api_key = api_key
        self.base_url = "https://BrsApi.ir/Api/Market/Gold_Currency_Pro.php"
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        self.daily_limit = 8000
        self.minute_limit = 45
        self.daily_calls = 0
        self.minute_calls = 0
        self.last_minute = datetime.now().minute
        self.last_reset = datetime.now().date()
        self.cache = {}
        self.cache_duration = 10  # seconds

    def _reset_counters_if_needed(self):
        now = datetime.now()
        if now.date() != self.last_reset:
            self.daily_calls = 0
            self.last_reset = now.date()
        if now.minute != self.last_minute:
            self.minute_calls = 0
            self.last_minute = now.minute

    def _check_rate_limits(self):
        self._reset_counters_if_needed()
        if self.daily_calls >= self.daily_limit:
            logger.warning("Daily limit reached")
            return False
        if self.minute_calls >= self.minute_limit:
            logger.warning("Minute limit reached")
            return False
        return True

    def _get_cache_key(self, params):
        return f"{params.get('section', 'all')}_{params.get('history', '0')}_{params.get('symbol', 'none')}"

    def _is_cache_valid(self, cache_key):
        if cache_key not in self.cache:
            return False
        cache_time = self.cache[cache_key]['timestamp']
        return (datetime.now() - cache_time).seconds < self.cache_duration

    def _make_request(self, params):
        cache_key = self._get_cache_key(params)
        if self._is_cache_valid(cache_key):
            logger.debug(f"Using cached data for {cache_key}")
            return self.cache[cache_key]['data']
        if not self._check_rate_limits():
            if cache_key in self.cache:
                logger.warning(f"Rate limited, using expired cache for {cache_key}")
                return self.cache[cache_key]['data']
            return None
        try:
            params['key'] = self.api_key
            logger.debug(f"Making request: {params}")
            response = requests.get(self.base_url, params=params, headers=self.headers, timeout=10)
            self.daily_calls += 1
            self.minute_calls += 1
            if response.status_code == 200:
                data = response.json()
                self.cache[cache_key] = {'data': data, 'timestamp': datetime.now()}
                logger.debug(f"API Response: {data}")
                return data
            else:
                logger.error(f"BrsAPI HTTP error: {response.status_code}")
                logger.error(f"Response: {response.text}")
                return None
        except Exception as e:
            logger.error(f"BrsAPI request failed: {e}")
            return None

    def get_real_time_gold(self):
        params = {'section': 'gold'}
        data = self._make_request(params)
        logger.debug(f"Raw API Response: {data}")
        if not data or not isinstance(data, list):
            logger.error("Invalid or empty data received from BrsAPI")
            return None
        for item in data:
            name = item.get('name', '').lower()
            if 'طلا' in name or 'gold' in name:
                try:
                    price_str = str(item.get('price', '0')).replace(',', '')
                    price_rial = float(price_str)
                    price_usd = price_rial / 70000
                    change_val = str(item.get('change_value', '0')).replace(',', '')
                    return {
                        'price': price_usd,
                        'price_rial': price_rial,
                        'change': float(change_val),
                        'change_percent': float(item.get('change_percent', '0')),
                        'timestamp': datetime.now(),
                        'source': 'BrsAPI_Pro',
                        'symbol': item.get('name', 'Gold'),
                        'date': item.get('date', ''),
                        'time': item.get('time', '')
                    }
                except Exception as e:
                    logger.error(f"Error processing gold data: {e}")
                    continue
        logger.warning("No gold data found in response")
        return None

# Global instance
brs_fetcher = BrsAPIFetcher()

def get_brsapi_gold_price():
    data = brs_fetcher.get_real_time_gold()
    return data['price'] if data and isinstance(data, dict) else None

def get_brsapi_status():
    status = {
        'daily_calls': brs_fetcher.daily_calls,
        'daily_limit': brs_fetcher.daily_limit,
        'minute_calls': brs_fetcher.minute_calls,
        'minute_limit': brs_fetcher.minute_limit,
        'daily_remaining': brs_fetcher.daily_limit - brs_fetcher.daily_calls,
        'minute_remaining': brs_fetcher.minute_limit - brs_fetcher.minute_calls,
        'daily_usage_percent': (brs_fetcher.daily_calls / brs_fetcher.daily_limit) * 100,
        'minute_usage_percent': (brs_fetcher.minute_calls / brs_fetcher.minute_limit) * 100
    }
    return status
