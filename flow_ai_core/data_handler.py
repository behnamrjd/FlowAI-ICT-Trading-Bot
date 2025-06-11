import pandas as pd
import numpy as np
import logging
from datetime import datetime, timedelta, timezone
from typing import Dict, Optional, List, Tuple
import jdatetime # Added
from .data_sources.brsapi_fetcher import BrsAPIFetcher
from .config import (
    HTF_TIMEFRAMES, LTF_TIMEFRAME, ICT_ENABLED,
    ORDER_BLOCK_DETECTION, FAIR_VALUE_GAP_DETECTION,
    LIQUIDITY_SWEEP_DETECTION, ICTConfig
)
import ta

logger = logging.getLogger(__name__)

class ICTDataHandler:
    """ICT-enhanced data handler with BrsAPI integration"""
    
    def __init__(self):
        self.brs_fetcher = BrsAPIFetcher()
        self.price_history = {}
        self.ict_patterns = {}
        self.last_update = None
        
    def get_processed_data(self, symbol: str = "GOLD", timeframe: str = "1h", limit: int = 1000) -> pd.DataFrame:
        """دریافت و پردازش داده‌های ICT-enhanced"""
        try:
            # Note: 'timeframe' param might be misleading if only daily data is fetched from BrsAPI.
            logger.info(f"Attempting to fetch REAL DAILY historical data for {symbol} (requested timeframe: {timeframe}, limit: {limit} days).")

            # Calculate Shamsi date range for the API call
            j_today = jdatetime.date.today()
            shamsi_date_end_str = j_today.strftime('%Y-%m-%d')
            # Subtract (limit - 1) because if limit is 1, we want just today.
            # If limit is 2, we want today and yesterday.
            j_start_date = j_today - timedelta(days=max(0, limit - 1))
            shamsi_date_start_str = j_start_date.strftime('%Y-%m-%d')
            logger.info(f"Calculated Shamsi date range for BrsAPI: {shamsi_date_start_str} to {shamsi_date_end_str}")

            api_symbol_for_historical = "XAUUSD"

            historical_df = self.brs_fetcher.get_daily_historical_gold(
                symbol=api_symbol_for_historical,
                date_start=shamsi_date_start_str,
                date_end=shamsi_date_end_str
            )

            data: Optional[pd.DataFrame] = None

            if historical_df is not None and not historical_df.empty:
                logger.info(f"Successfully fetched {len(historical_df)} REAL DAILY historical candles for {symbol} from BrsAPI.")
                data = historical_df
                if timeframe != '1d':
                    logger.warning(f"Requested timeframe was '{timeframe}', but BrsAPI provided DAILY data. Analysis will use daily data.")
            else:
                logger.warning(
                    f"Failed to fetch real daily historical data for {symbol} via BrsAPI. "
                    f"FALLING BACK TO SYNTHETIC DATA GENERATION. THIS IS NOT SUITABLE FOR LIVE TRADING."
                )
                current_price_data = self.brs_fetcher.get_real_time_gold()
                if not current_price_data or 'price' not in current_price_data:
                    logger.error("CRITICAL: Failed to get current price from BrsAPI for synthetic data fallback. Cannot proceed.")
                    return pd.DataFrame()

                current_price = float(current_price_data['price'])
                # For synthetic data, the original 'timeframe' and 'limit' for candle generation are used.
                data = self._generate_enhanced_historical_data(current_price, timeframe, limit)
                if data.empty:
                     logger.error("Synthetic data generation also failed.")
                     return pd.DataFrame()

            if data.empty:
                logger.error(f"No data (real or synthetic) available for {symbol}.")
                return pd.DataFrame()
            
            data = self._add_technical_indicators(data)
            if ICT_ENABLED:
                data = self._add_ict_analysis(data)
            
            self.price_history[f"{symbol}_{timeframe}"] = data # Key uses requested timeframe
            self.last_update = datetime.now(timezone.utc)
            
            logger.info(f"✅ Processed {len(data)} candles for {symbol} (data granularity might be daily if real fetch succeeded).")
            return data
            
        except Exception as e:
            logger.error(f"Error in get_processed_data: {e}")
            import traceback
            logger.error(traceback.format_exc()) # Log full traceback
            return pd.DataFrame()
    
    def _generate_enhanced_historical_data(self, current_price: float, timeframe: str, limit: int) -> pd.DataFrame:
        """تولید داده‌های تاریخی پیشرفته"""
        try:
            # محاسبه تاریخ شروع
            if timeframe == "1h":
                start_time = datetime.now() - timedelta(hours=limit)
                freq = "1H"
            elif timeframe == "4h":
                start_time = datetime.now() - timedelta(hours=limit * 4)
                freq = "4H"
            elif timeframe == "1d":
                start_time = datetime.now() - timedelta(days=limit)
                freq = "1D"
            else:
                start_time = datetime.now() - timedelta(hours=limit)
                freq = "1H"
            
            # تولید تاریخ‌ها
            dates = pd.date_range(start=start_time, end=datetime.now(), freq=freq)
            
            # تولید قیمت‌های واقع‌گرایانه با الگوهای ICT
            prices = self._generate_ict_realistic_prices(current_price, len(dates))
            
            # ایجاد DataFrame
            data = []
            for i, (date, price) in enumerate(zip(dates, prices)):
                # محاسبه OHLC با volatility واقعی
                volatility = np.random.uniform(0.001, 0.003)  # 0.1% to 0.3%
                
                open_price = price * (1 + np.random.uniform(-volatility/2, volatility/2))
                close_price = price * (1 + np.random.uniform(-volatility/2, volatility/2))
                
                # High و Low با در نظر گیری ICT patterns
                high_extension = volatility * np.random.uniform(0.5, 1.5)
                low_extension = volatility * np.random.uniform(0.5, 1.5)
                
                high_price = max(open_price, close_price) * (1 + high_extension)
                low_price = min(open_price, close_price) * (1 - low_extension)
                
                # Volume واقع‌گرایانه
                base_volume = 1000
                volume_multiplier = 1 + abs(close_price - open_price) / open_price * 10
                volume = int(base_volume * volume_multiplier * np.random.uniform(0.5, 2.0))
                
                data.append({
                    'Open': open_price,
                    'High': high_price,
                    'Low': low_price,
                    'Close': close_price,
                    'Volume': volume
                })
            
            df = pd.DataFrame(data, index=dates)
            return df
            
        except Exception as e:
            logger.error(f"Error generating historical data: {e}")
            return pd.DataFrame()
    
    def _generate_ict_realistic_prices(self, current_price: float, length: int) -> List[float]:
        """تولید قیمت‌های واقع‌گرایانه با الگوهای ICT"""
        prices = [current_price]
        
        # پارامترهای ICT
        trend_strength = np.random.uniform(0.0001, 0.0005)  # قدرت ترند
        noise_level = 0.0002  # سطح نویز
        
        # ایجاد چندین فاز بازار
        phases = ['accumulation', 'markup', 'distribution', 'markdown']
        phase_lengths = np.random.multinomial(length - 1, [0.3, 0.3, 0.2, 0.2])
        
        current_phase_index = 0
        current_phase_remaining = phase_lengths[0]
        
        for i in range(1, length):
            # تغییر فاز در صورت نیاز
            if current_phase_remaining <= 0 and current_phase_index < len(phases) - 1:
                current_phase_index += 1
                current_phase_remaining = phase_lengths[current_phase_index]
            
            current_phase = phases[current_phase_index]
            
            # محاسبه تغییر قیمت بر اساس فاز ICT
            if current_phase == 'accumulation':
                # حرکت کم با نوسانات
                price_change = np.random.normal(0, noise_level)
            elif current_phase == 'markup':
                # حرکت صعودی قوی
                price_change = np.random.normal(trend_strength, noise_level)
            elif current_phase == 'distribution':
                # حرکت کم با نوسانات بالا
                price_change = np.random.normal(0, noise_level * 1.5)
            else:  # markdown
                # حرکت نزولی
                price_change = np.random.normal(-trend_strength, noise_level)
            
            new_price = prices[-1] * (1 + price_change)
            prices.append(new_price)
            current_phase_remaining -= 1
        
        return prices
    
    def _add_technical_indicators(self, data: pd.DataFrame) -> pd.DataFrame:
        """اضافه کردن اندیکاتورهای تکنیکال"""
        try:
            if len(data) < 50: # Increased slightly as some TA-Lib defaults might need more, better safe.
                logger.warning("Not enough data for full technical indicators calculation using 'ta' library.")
                return data
            
            # Data columns (e.g., data['Close']) are already pandas Series.
            
            # Moving Averages
            data['SMA_20'] = ta.trend.SMAIndicator(close=data['Close'], window=20, fillna=True).sma_indicator()
            data['SMA_50'] = ta.trend.SMAIndicator(close=data['Close'], window=50, fillna=True).sma_indicator()
            data['EMA_12'] = ta.trend.EMAIndicator(close=data['Close'], window=12, fillna=True).ema_indicator()
            data['EMA_26'] = ta.trend.EMAIndicator(close=data['Close'], window=26, fillna=True).ema_indicator()
            
            # RSI
            data['RSI'] = ta.momentum.RSIIndicator(close=data['Close'], window=14, fillna=True).rsi()
            
            # MACD
            macd_indicator = ta.trend.MACD(close=data['Close'], window_slow=26, window_fast=12, window_sign=9, fillna=True)
            data['MACD'] = macd_indicator.macd()
            data['MACD_Signal'] = macd_indicator.macd_signal()
            data['MACD_Histogram'] = macd_indicator.macd_diff() # Or (data['MACD'] - data['MACD_Signal'])
            
            # Bollinger Bands
            bb_indicator = ta.volatility.BollingerBands(close=data['Close'], window=20, window_dev=2, fillna=True)
            data['BB_Upper'] = bb_indicator.bollinger_hband()
            data['BB_Middle'] = bb_indicator.bollinger_mavg()
            data['BB_Lower'] = bb_indicator.bollinger_lband()

            # Stochastic Oscillator
            stoch_indicator = ta.momentum.StochasticOscillator(
                high=data['High'],
                low=data['Low'],
                close=data['Close'],
                window=14,
                smooth_window=3,
                fillna=True
            )
            data['Stoch_K'] = stoch_indicator.stoch()
            data['Stoch_D'] = stoch_indicator.stoch_signal()

            # ATR (Average True Range)
            data['ATR'] = ta.volatility.AverageTrueRange(
                high=data['High'],
                low=data['Low'],
                close=data['Close'],
                window=14,
                fillna=True
            ).average_true_range()

            logger.debug("Technical indicators added successfully using 'ta' library class-based interface.")
            return data
            
        except Exception as e:
            logger.error(f"Error adding technical indicators using 'ta' library: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return data
    
    def _add_ict_analysis(self, data: pd.DataFrame) -> pd.DataFrame:
        """اضافه کردن تحلیل‌های ICT"""
        try:
            # Order Blocks
            if ORDER_BLOCK_DETECTION:
                data = self._detect_order_blocks(data)
            
            # Fair Value Gaps
            if FAIR_VALUE_GAP_DETECTION:
                data = self._detect_fair_value_gaps(data)
            
            # Liquidity Sweeps
            if LIQUIDITY_SWEEP_DETECTION:
                data = self._detect_liquidity_sweeps(data)
            
            # Market Structure
            data = self._analyze_market_structure(data)
            
            logger.debug("ICT analysis completed")
            return data
            
        except Exception as e:
            logger.error(f"Error in ICT analysis: {e}")
            return data
    
    def _detect_order_blocks(self, data: pd.DataFrame) -> pd.DataFrame:
        """تشخیص Order Blocks"""
        try:
            data['Bullish_OB'] = False
            data['Bearish_OB'] = False
            data['OB_Strength'] = 0.0
            
            lookback = ICTConfig.OB_LOOKBACK_PERIODS
            min_body_size = ICTConfig.OB_MIN_BODY_SIZE
            
            for i in range(lookback, len(data)):
                current_candle = data.iloc[i]
                
                # محاسبه اندازه body
                body_size = abs(current_candle['Close'] - current_candle['Open'])
                price_range = current_candle['High'] - current_candle['Low']
                
                if body_size < min_body_size * current_candle['Close']:
                    continue
                
                # بررسی الگوی Order Block
                # Bullish Order Block: کندل قوی صعودی بعد از حرکت نزولی
                if (current_candle['Close'] > current_candle['Open'] and
                    body_size / price_range > 0.6):  # کندل با body قوی
                    
                    # بررسی حرکت قبلی
                    prev_lows = data['Low'].iloc[i-lookback:i]
                    if current_candle['Low'] <= prev_lows.min() * 1.001:  # نزدیک به کمترین قیمت
                        data.loc[data.index[i], 'Bullish_OB'] = True
                        data.loc[data.index[i], 'OB_Strength'] = body_size / price_range
                
                # Bearish Order Block: کندل قوی نزولی بعد از حرکت صعودی
                elif (current_candle['Close'] < current_candle['Open'] and
                      body_size / price_range > 0.6):
                    
                    prev_highs = data['High'].iloc[i-lookback:i]
                    if current_candle['High'] >= prev_highs.max() * 0.999:
                        data.loc[data.index[i], 'Bearish_OB'] = True
                        data.loc[data.index[i], 'OB_Strength'] = body_size / price_range
            
            logger.debug(f"Detected {data['Bullish_OB'].sum()} bullish and {data['Bearish_OB'].sum()} bearish order blocks")
            return data
            
        except Exception as e:
            logger.error(f"Error detecting order blocks: {e}")
            return data
    
    def _detect_fair_value_gaps(self, data: pd.DataFrame) -> pd.DataFrame:
        """تشخیص Fair Value Gaps"""
        try:
            data['Bullish_FVG'] = False
            data['Bearish_FVG'] = False
            data['FVG_Size'] = 0.0
            
            min_gap_size = ICTConfig.FVG_MIN_SIZE
            
            for i in range(2, len(data)):
                candle_1 = data.iloc[i-2]  # کندل اول
                candle_2 = data.iloc[i-1]  # کندل وسط
                candle_3 = data.iloc[i]    # کندل سوم
                
                # Bullish FVG: gap بین low کندل سوم و high کندل اول
                if (candle_3['Low'] > candle_1['High'] and
                    candle_2['Close'] > candle_2['Open']):  # کندل وسط صعودی
                    
                    gap_size = candle_3['Low'] - candle_1['High']
                    if gap_size >= min_gap_size * candle_2['Close']:
                        data.loc[data.index[i], 'Bullish_FVG'] = True
                        data.loc[data.index[i], 'FVG_Size'] = gap_size
                
                # Bearish FVG: gap بین high کندل سوم و low کندل اول
                elif (candle_3['High'] < candle_1['Low'] and
                      candle_2['Close'] < candle_2['Open']):  # کندل وسط نزولی
                    
                    gap_size = candle_1['Low'] - candle_3['High']
                    if gap_size >= min_gap_size * candle_2['Close']:
                        data.loc[data.index[i], 'Bearish_FVG'] = True
                        data.loc[data.index[i], 'FVG_Size'] = gap_size
            
            logger.debug(f"Detected {data['Bullish_FVG'].sum()} bullish and {data['Bearish_FVG'].sum()} bearish FVGs")
            return data
            
        except Exception as e:
            logger.error(f"Error detecting fair value gaps: {e}")
            return data
    
    def _detect_liquidity_sweeps(self, data: pd.DataFrame) -> pd.DataFrame:
        """تشخیص Liquidity Sweeps"""
        try:
            data['Buy_Side_Liquidity_Sweep'] = False
            data['Sell_Side_Liquidity_Sweep'] = False
            data['Liquidity_Strength'] = 0.0
            
            lookback = ICTConfig.LIQUIDITY_LOOKBACK
            threshold = ICTConfig.LIQUIDITY_THRESHOLD
            
            for i in range(lookback, len(data)):
                current_candle = data.iloc[i]
                
                # بررسی بازه قبلی برای یافتن highs و lows
                prev_data = data.iloc[i-lookback:i]
                
                # Buy Side Liquidity Sweep (شکستن high قبلی)
                prev_high = prev_data['High'].max()
                if (current_candle['High'] > prev_high and
                    (current_candle['High'] - prev_high) / prev_high >= threshold):
                    
                    # بررسی اینکه آیا قیمت برگشت کرده
                    if current_candle['Close'] < current_candle['High'] * 0.998:
                        data.loc[data.index[i], 'Buy_Side_Liquidity_Sweep'] = True
                        data.loc[data.index[i], 'Liquidity_Strength'] = (current_candle['High'] - prev_high) / prev_high
                
                # Sell Side Liquidity Sweep (شکستن low قبلی)
                prev_low = prev_data['Low'].min()
                if (current_candle['Low'] < prev_low and
                    (prev_low - current_candle['Low']) / prev_low >= threshold):
                    
                    if current_candle['Close'] > current_candle['Low'] * 1.002:
                        data.loc[data.index[i], 'Sell_Side_Liquidity_Sweep'] = True
                        data.loc[data.index[i], 'Liquidity_Strength'] = (prev_low - current_candle['Low']) / prev_low
            
            logger.debug(f"Detected {data['Buy_Side_Liquidity_Sweep'].sum()} buy-side and {data['Sell_Side_Liquidity_Sweep'].sum()} sell-side liquidity sweeps")
            return data
            
        except Exception as e:
            logger.error(f"Error detecting liquidity sweeps: {e}")
            return data
    
    def _analyze_market_structure(self, data: pd.DataFrame) -> pd.DataFrame:
        """تحلیل ساختار بازار"""
        try:
            data['Market_Structure'] = 'NEUTRAL'
            data['Structure_Strength'] = 0.0
            
            swing_length = ICTConfig.STRUCTURE_SWING_LENGTH
            
            # تشخیص swing highs و lows
            data['Swing_High'] = False
            data['Swing_Low'] = False
            
            for i in range(swing_length, len(data) - swing_length):
                current_high = data['High'].iloc[i]
                current_low = data['Low'].iloc[i]
                
                # Swing High: بالاترین قیمت در بازه
                left_highs = data['High'].iloc[i-swing_length:i]
                right_highs = data['High'].iloc[i+1:i+swing_length+1]
                
                if (current_high > left_highs.max() and 
                    current_high > right_highs.max()):
                    data.loc[data.index[i], 'Swing_High'] = True
                
                # Swing Low: پایین‌ترین قیمت در بازه
                left_lows = data['Low'].iloc[i-swing_length:i]
                right_lows = data['Low'].iloc[i+1:i+swing_length+1]
                
                if (current_low < left_lows.min() and 
                    current_low < right_lows.min()):
                    data.loc[data.index[i], 'Swing_Low'] = True
            
            # تحلیل ترند بر اساس swing points
            swing_highs = data[data['Swing_High']]['High']
            swing_lows = data[data['Swing_Low']]['Low']
            
            if len(swing_highs) >= 2 and len(swing_lows) >= 2:
                # بررسی ترند صعودی: Higher Highs و Higher Lows
                recent_highs = swing_highs.tail(2)
                recent_lows = swing_lows.tail(2)
                
                if (len(recent_highs) == 2 and recent_highs.iloc[1] > recent_highs.iloc[0] and
                    len(recent_lows) == 2 and recent_lows.iloc[1] > recent_lows.iloc[0]):
                    data.loc[data.index[-swing_length:], 'Market_Structure'] = 'BULLISH'
                    data.loc[data.index[-swing_length:], 'Structure_Strength'] = 0.8
                
                # بررسی ترند نزولی: Lower Highs و Lower Lows
                elif (len(recent_highs) == 2 and recent_highs.iloc[1] < recent_highs.iloc[0] and
                      len(recent_lows) == 2 and recent_lows.iloc[1] < recent_lows.iloc[0]):
                    data.loc[data.index[-swing_length:], 'Market_Structure'] = 'BEARISH'
                    data.loc[data.index[-swing_length:], 'Structure_Strength'] = 0.8
            
            logger.debug("Market structure analysis completed")
            return data
            
        except Exception as e:
            logger.error(f"Error analyzing market structure: {e}")
            return data
    
    def get_real_time_price(self) -> Optional[float]:
        """
        دریافت قیمت real-time.
        Returns:
            Optional[float]: The real-time price as a float, or None if fetching fails or data is invalid.
        """
        try:
            price_data = self.brs_fetcher.get_real_time_gold()
            if price_data and 'price' in price_data:
                return float(price_data['price'])
            else:
                logger.warning("Failed to get valid price data from BrsAPIFetcher.")
                return None
        except Exception as e:
            logger.error(f"Error getting real-time price: {e}")
            return None
    
    def get_ict_signals(self, data: pd.DataFrame) -> Dict:
        """استخراج سیگنال‌های ICT"""
        try:
            if data.empty or len(data) < 10:
                return {'signal': 'HOLD', 'confidence': 0.0, 'reasons': []}
            
            latest = data.iloc[-1]
            signals = []
            confidence_factors = []
            
            # بررسی Order Blocks
            if latest.get('Bullish_OB', False):
                signals.append('BUY')
                confidence_factors.append(latest.get('OB_Strength', 0.5))
            elif latest.get('Bearish_OB', False):
                signals.append('SELL')
                confidence_factors.append(latest.get('OB_Strength', 0.5))
            
            # بررسی Fair Value Gaps
            if latest.get('Bullish_FVG', False):
                signals.append('BUY')
                confidence_factors.append(0.6)
            elif latest.get('Bearish_FVG', False):
                signals.append('SELL')
                confidence_factors.append(0.6)
            
            # بررسی Liquidity Sweeps
            if latest.get('Sell_Side_Liquidity_Sweep', False):
                signals.append('BUY')  # معکوس - بعد از sweep معمولاً برگشت می‌خورد
                confidence_factors.append(latest.get('Liquidity_Strength', 0.7))
            elif latest.get('Buy_Side_Liquidity_Sweep', False):
                signals.append('SELL')
                confidence_factors.append(latest.get('Liquidity_Strength', 0.7))
            
            # بررسی Market Structure
            if latest.get('Market_Structure') == 'BULLISH':
                signals.append('BUY')
                confidence_factors.append(latest.get('Structure_Strength', 0.5))
            elif latest.get('Market_Structure') == 'BEARISH':
                signals.append('SELL')
                confidence_factors.append(latest.get('Structure_Strength', 0.5))
            
            # تعیین سیگنال نهایی
            if not signals:
                return {'signal': 'HOLD', 'confidence': 0.0, 'reasons': ['No ICT patterns detected']}
            
            # رای‌گیری
            buy_votes = signals.count('BUY')
            sell_votes = signals.count('SELL')
            
            if buy_votes > sell_votes:
                final_signal = 'BUY'
                confidence = np.mean([cf for i, cf in enumerate(confidence_factors) if signals[i] == 'BUY'])
            elif sell_votes > buy_votes:
                final_signal = 'SELL'
                confidence = np.mean([cf for i, cf in enumerate(confidence_factors) if signals[i] == 'SELL'])
            else:
                final_signal = 'HOLD'
                confidence = 0.5
            
            return {
                'signal': final_signal,
                'confidence': min(confidence, 0.95),  # حداکثر 95%
                'reasons': signals,
                'ict_patterns': {
                    'order_blocks': latest.get('Bullish_OB', False) or latest.get('Bearish_OB', False),
                    'fair_value_gaps': latest.get('Bullish_FVG', False) or latest.get('Bearish_FVG', False),
                    'liquidity_sweeps': latest.get('Buy_Side_Liquidity_Sweep', False) or latest.get('Sell_Side_Liquidity_Sweep', False),
                    'market_structure': latest.get('Market_Structure', 'NEUTRAL')
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting ICT signals: {e}")
            return {'signal': 'HOLD', 'confidence': 0.0, 'reasons': [f'Error: {str(e)}']}

# Global instance
ict_data_handler = ICTDataHandler()

def get_processed_data(symbol: str = "GOLD", timeframe: str = "1h", limit: int = 1000) -> pd.DataFrame:
    """تابع global برای دریافت داده‌های پردازش شده"""
    return ict_data_handler.get_processed_data(symbol, timeframe, limit)

def get_real_time_price() -> float:
    """تابع global برای دریافت قیمت real-time"""
    return ict_data_handler.get_real_time_price()

def get_ict_analysis(symbol: str = "GOLD", timeframe: str = "1h") -> Dict:
    """تابع global برای دریافت تحلیل ICT"""
    data = ict_data_handler.get_processed_data(symbol, timeframe, 200)
    return ict_data_handler.get_ict_signals(data)

# Legacy compatibility
def add_technical_indicators(data: pd.DataFrame) -> pd.DataFrame:
    """سازگاری با کد قدیمی"""
    return ict_data_handler._add_technical_indicators(data)
