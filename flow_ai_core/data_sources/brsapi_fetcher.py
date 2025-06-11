import requests
import logging
from datetime import datetime
from typing import Optional # Added
import pandas as pd # Added
from ..config import USD_IRR_EXCHANGE_RATE

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
        self.cache_duration = 10

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
            response = requests.get(self.base_url, params=params, headers=self.headers, timeout=10)
            self.daily_calls += 1
            self.minute_calls += 1
            if response.status_code == 200:
                data = response.json()
                self.cache[cache_key] = {'data': data, 'timestamp': datetime.now()}
                return data
            else:
                logger.error(f"BrsAPI HTTP error: {response.status_code}")
                return None
        except Exception as e:
            logger.error(f"BrsAPI request failed: {e}")
            return None

    def get_real_time_gold(self):
        """دریافت قیمت real-time طلا با ساختار JSON جدید"""
        params = {'section': 'gold'}
        data = self._make_request(params)
        
        if not data or not isinstance(data, dict):
            logger.error("Invalid or empty data received from BrsAPI")
            return None
        
        # بررسی ساختار جدید JSON
        if not data.get('successful'):
            logger.error(f"BrsAPI returned error: {data.get('message_error')}")
            return None
        
        # استخراج قیمت انس طلا (XAUUSD)
        gold_data = data.get('gold', {})
        ounce_list = gold_data.get('ounce', [])
        
        if ounce_list and len(ounce_list) > 0:
            ounce = ounce_list[0]  # اولین آیتم انس طلا
            
            try:
                price_usd = float(ounce.get('price', 0))
                
                result = {
                    'price': price_usd,
                    'price_rial': price_usd * 70000,  # تبدیل تقریبی به ریال
                    'change': float(ounce.get('change_value', 0)),
                    'change_percent': float(ounce.get('change_percent', 0)),
                    'timestamp': datetime.now(),
                    'source': 'BrsAPI_Pro',
                    'symbol': ounce.get('symbol', 'XAUUSD'),
                    'name': ounce.get('name', 'انس طلا'),
                    'date': ounce.get('date', ''),
                    'time': ounce.get('time', ''),
                    'unit': ounce.get('unit', 'دلار')
                }
                
                logger.info(f"✅ BrsAPI Gold: ${price_usd:.2f} ({ounce.get('change_percent', 0):.2f}%)")
                return result
                
            except (ValueError, TypeError) as e:
                logger.error(f"Error processing gold ounce data: {e}")
        
        # اگر انس طلا موجود نبود، از طلای 18 عیار استفاده کن
        type_list = gold_data.get('type', [])
        for item in type_list:
            if 'IR_GOLD_18K' in item.get('symbol', ''):
                try:
                    price_rial = float(item.get('price', 0))
                    price_usd = price_rial / USD_IRR_EXCHANGE_RATE  # تبدیل به دلار
                    
                    result = {
                        'price': price_usd,
                        'price_rial': price_rial,
                        'change': float(item.get('change_value', 0)),
                        'change_percent': float(item.get('change_percent', 0)),
                        'timestamp': datetime.now(),
                        'source': 'BrsAPI_Pro_18K',
                        'symbol': item.get('symbol', 'IR_GOLD_18K'),
                        'name': item.get('name', 'طلای 18 عیار'),
                        'date': item.get('date', ''),
                        'time': item.get('time', ''),
                        'unit': 'USD (converted)'
                    }
                    
                    logger.info(f"✅ BrsAPI 18K Gold: ${price_usd:.2f}")
                    return result
                    
                except (ValueError, TypeError) as e:
                    logger.error(f"Error processing 18K gold data: {e}")
        
        logger.warning("No usable gold data found in BrsAPI response")
        return None

    def get_historical_gold_ohlcv(self, symbol: str, timeframe: str, count: int = 200) -> Optional[pd.DataFrame]:
        """
        Attempts to fetch historical OHLCV data for gold.
        NOTE: The exact API parameters for historical data are unknown.
        This method is a template and may require adjustment based on BrsAPI documentation.
        """
        params = {
            'section': 'gold',
            'symbol': symbol, # Placeholder, actual API symbol for XAUUSD history needed
            'timeframe': timeframe, # Placeholder, actual API timeframe format needed
            'history': 'ohlcv', # Speculative
            'count': str(count)
        }
        logger.info(f"Attempting to fetch historical data from BrsAPI with params: {params}")
        data = self._make_request(params)

        if not data or not isinstance(data, dict): # Check if data is None or not a dict
            logger.error(f"Failed to fetch or received invalid data from BrsAPI for historical data. Params: {params}")
            return None

        if not data.get('successful'): # Check for 'successful' key specifically
            logger.error(f"BrsAPI historical data request not successful: {data.get('message_error', 'Unknown error')}. Params: {params}")
            return None

        # SPECULATIVE PARSING LOGIC:
        ohlcv_list = data.get('candles', data.get('history_data')) # Try common keys

        if not ohlcv_list or not isinstance(ohlcv_list, list):
            logger.error(f"Historical data format from BrsAPI is not as expected (e.g., missing 'candles' or 'history_data' list). Response keys: {list(data.keys())}")
            return None

        processed_candles = []
        for candle_data in ohlcv_list:
            if not isinstance(candle_data, dict):
                logger.warning(f"Skipping invalid candle data item (not a dict): {candle_data}")
                continue
            try:
                # Attempt to parse timestamp (highly speculative)
                ts_val = candle_data.get('timestamp', candle_data.get('date', candle_data.get('time')))
                ts = pd.to_datetime(ts_val, unit='s', errors='coerce') # Try unixtime
                if pd.isna(ts):
                    ts = pd.to_datetime(ts_val, errors='coerce') # Try direct datetime string parsing

                if pd.isna(ts):
                    logger.warning(f"Could not parse valid timestamp from candle data: {candle_data}")
                    continue

                processed_candles.append({
                    'Timestamp': ts,
                    'Open': float(candle_data.get('open', candle_data.get('o', 0.0))),
                    'High': float(candle_data.get('high', candle_data.get('h', 0.0))),
                    'Low': float(candle_data.get('low', candle_data.get('l', 0.0))),
                    'Close': float(candle_data.get('close', candle_data.get('c', 0.0))),
                    'Volume': float(candle_data.get('volume', candle_data.get('v', 0.0)))
                })
            except (ValueError, TypeError) as e:
                logger.warning(f"Error processing individual candle data {candle_data}: {e}")
                continue

        if not processed_candles:
            logger.error("No valid historical candles could be processed from BrsAPI response, though data was received.")
            return None

        df = pd.DataFrame(processed_candles)
        if df.empty:
            logger.error("Resulting DataFrame is empty after processing candles.")
            return None

        df = df.set_index('Timestamp')
        df = df.sort_index()
        logger.info(f"Successfully processed {len(df)} historical candles for {symbol} from BrsAPI.")
        return df

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
