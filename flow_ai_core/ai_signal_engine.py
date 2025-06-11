import pandas as pd
import numpy as np
import logging
from datetime import datetime, timezone
from typing import Dict, Optional, List
from .data_handler import get_processed_data, get_real_time_price
from .data_sources.brsapi_fetcher import get_brsapi_gold_price, get_brsapi_status
import talib
from ..news_handler import EconomicNewsHandler
from .. import config # To access news configuration settings

logger = logging.getLogger(__name__)

# Initialize News Handler globally for this module
# This assumes config is loaded when this module is imported.
try:
    news_handler_instance = EconomicNewsHandler(
        news_url=config.NEWS_FETCH_URL,
        monitored_currencies=config.NEWS_MONITORED_CURRENCIES,
        monitored_impacts=config.NEWS_MONITORED_IMPACTS,
        cache_ttl_seconds=config.NEWS_CACHE_TTL_SECONDS
    )
    logger.info("EconomicNewsHandler initialized successfully in ai_signal_engine.")
except Exception as e:
    logger.error(f"CRITICAL: Failed to initialize EconomicNewsHandler in ai_signal_engine: {e}. News checking will be disabled.")
    news_handler_instance = None

class AISignalEngine:
    def __init__(self):
        self.last_signal_time = None
        self.signal_cooldown = 300  # 5 دقیقه کولداون بین سیگنال‌ها
        self.market_hours = {
            'start': 13,  # 1 PM GMT (بازار لندن)
            'end': 22     # 10 PM GMT (بازار نیویورک)
        }
        
    def is_market_active(self) -> bool:
        """بررسی فعال بودن بازار طلا"""
        now = datetime.now(timezone.utc)
        current_hour = now.hour
        weekday = now.weekday()
        
        # بازار طلا: دوشنبه تا جمعه، 13:00-22:00 GMT
        if weekday >= 5:  # آخر هفته
            return False
            
        if self.market_hours['start'] <= current_hour <= self.market_hours['end']:
            return True
            
        return False
    
    def calculate_technical_indicators(self, data: pd.DataFrame) -> Dict:
        """محاسبه اندیکاتورهای تکنیکال"""
        if data.empty or len(data) < 20:
            logger.warning("Not enough data for technical analysis")
            return {}
        
        try:
            close_prices = data['Close'].values
            high_prices = data['High'].values
            low_prices = data['Low'].values
            volumes = data['Volume'].values
            
            # RSI
            rsi = talib.RSI(close_prices, timeperiod=14)
            current_rsi = rsi[-1] if not np.isnan(rsi[-1]) else 50
            
            # MACD
            macd, macd_signal, macd_hist = talib.MACD(close_prices)
            current_macd = macd[-1] if not np.isnan(macd[-1]) else 0
            current_macd_signal = macd_signal[-1] if not np.isnan(macd_signal[-1]) else 0
            
            # Moving Averages
            sma_20 = talib.SMA(close_prices, timeperiod=20)
            sma_50 = talib.SMA(close_prices, timeperiod=50)
            ema_12 = talib.EMA(close_prices, timeperiod=12)
            ema_26 = talib.EMA(close_prices, timeperiod=26)
            
            current_sma_20 = sma_20[-1] if not np.isnan(sma_20[-1]) else close_prices[-1]
            current_sma_50 = sma_50[-1] if not np.isnan(sma_50[-1]) else close_prices[-1]
            current_ema_12 = ema_12[-1] if not np.isnan(ema_12[-1]) else close_prices[-1]
            current_ema_26 = ema_26[-1] if not np.isnan(ema_26[-1]) else close_prices[-1]
            
            # Bollinger Bands
            bb_upper, bb_middle, bb_lower = talib.BBANDS(close_prices)
            current_bb_upper = bb_upper[-1] if not np.isnan(bb_upper[-1]) else close_prices[-1] * 1.02
            current_bb_lower = bb_lower[-1] if not np.isnan(bb_lower[-1]) else close_prices[-1] * 0.98
            
            # Stochastic
            stoch_k, stoch_d = talib.STOCH(high_prices, low_prices, close_prices)
            current_stoch_k = stoch_k[-1] if not np.isnan(stoch_k[-1]) else 50
            
            current_price = close_prices[-1]
            
            return {
                'price': current_price,
                'rsi': current_rsi,
                'macd': current_macd,
                'macd_signal': current_macd_signal,
                'macd_histogram': current_macd - current_macd_signal,
                'sma_20': current_sma_20,
                'sma_50': current_sma_50,
                'ema_12': current_ema_12,
                'ema_26': current_ema_26,
                'bb_upper': current_bb_upper,
                'bb_lower': current_bb_lower,
                'bb_middle': (current_bb_upper + current_bb_lower) / 2,
                'stoch_k': current_stoch_k,
                'volume': volumes[-1] if len(volumes) > 0 else 1000
            }
            
        except Exception as e:
            logger.error(f"Error calculating technical indicators: {e}")
            return {}
    
    def generate_ai_signal(self, force_analysis: bool = False) -> Optional[Dict]:
        """تولید سیگنال AI با تحلیل پیشرفته"""
        try:
            # بررسی کولداون (مگر اینکه force باشد)
            if not force_analysis and self.last_signal_time:
                time_diff = (datetime.now() - self.last_signal_time).total_seconds()
                if time_diff < self.signal_cooldown:
                    logger.info(f"Signal cooldown active: {self.signal_cooldown - time_diff:.0f}s remaining")
                    return None
            
            # بررسی ساعات بازار (مگر اینکه force باشد)
            if not force_analysis and not self.is_market_active():
                logger.info("Market is closed, no signal generated")
                return None
            
            # دریافت داده‌های پردازش شده
            data = get_processed_data(symbol="GOLD", timeframe="1h", limit=100)
            if data.empty:
                logger.error("No data available for signal generation")
                return None
            
            # محاسبه اندیکاتورها
            indicators = self.calculate_technical_indicators(data)
            if not indicators:
                logger.error("Failed to calculate technical indicators")
                return None

            # News Check
            if news_handler_instance:
                try:
                    active_news_events = news_handler_instance.get_upcoming_relevant_events(
                        minutes_before_event_start=config.NEWS_BLACKOUT_MINUTES_BEFORE,
                        minutes_after_event_start=config.NEWS_BLACKOUT_MINUTES_AFTER
                    )
                    if active_news_events:
                        event_titles = [event['title'] for event in active_news_events]
                        reason = f"News blackout: {', '.join(event_titles)}"
                        logger.info(f"Signal generation paused due to active high-impact news: {reason}")
                        # Construct a 'HOLD' signal response including current price from indicators
                        return {
                            'action': 'HOLD',
                            'reason': reason,
                            'confidence': 0.99, # High confidence in holding due to news
                            'current_price': indicators.get('price', 0.0),
                            'entry_price': indicators.get('price', 0.0), # For consistency
                            'target_price': indicators.get('price', 0.0),
                            'stop_loss': indicators.get('price', 0.0),
                            'timestamp': datetime.now(timezone.utc),
                            'indicators': indicators, # Include indicators for context
                            'analysis_details': [reason],
                            'bullish_score': 0, # No bullish/bearish analysis performed
                            'bearish_score': 0,
                            'market_active': self.is_market_active(), # Current market status
                            'forced': force_analysis,
                            'news_event_active': True # Flag indicating news interference
                        }
                except Exception as e_news:
                    logger.error(f"Error during news check: {e_news}. Proceeding without news-based pause.")
            
            # تحلیل AI
            signal = self._analyze_market_conditions(indicators, force_analysis)
            
            if signal:
                self.last_signal_time = datetime.now()
                logger.info(f"AI Signal generated: {signal['action']} with confidence {signal['confidence']:.2f}")
            
            return signal
            
        except Exception as e:
            logger.error(f"Error generating AI signal: {e}")
            return None
    
    def _analyze_market_conditions(self, indicators: Dict, force_analysis: bool) -> Optional[Dict]:
        """تحلیل شرایط بازار و تولید سیگنال"""
        try:
            price = indicators['price']
            rsi = indicators['rsi']
            macd = indicators['macd']
            macd_signal = indicators['macd_signal']
            macd_hist = indicators['macd_histogram']
            sma_20 = indicators['sma_20']
            sma_50 = indicators['sma_50']
            ema_12 = indicators['ema_12']
            ema_26 = indicators['ema_26']
            bb_upper = indicators['bb_upper']
            bb_lower = indicators['bb_lower']
            stoch_k = indicators['stoch_k']
            
            # امتیازدهی سیگنال‌ها
            bullish_score = 0
            bearish_score = 0
            signals_detail = []
            
            # RSI Analysis
            if rsi < 30:
                bullish_score += 2
                signals_detail.append("RSI oversold (bullish)")
            elif rsi > 70:
                bearish_score += 2
                signals_detail.append("RSI overbought (bearish)")
            elif 40 <= rsi <= 60:
                signals_detail.append("RSI neutral")
            
            # MACD Analysis
            if macd > macd_signal and macd_hist > 0:
                bullish_score += 2
                signals_detail.append("MACD bullish crossover")
            elif macd < macd_signal and macd_hist < 0:
                bearish_score += 2
                signals_detail.append("MACD bearish crossover")
            
            # Moving Average Analysis
            if price > sma_20 > sma_50:
                bullish_score += 1
                signals_detail.append("Price above SMAs (bullish)")
            elif price < sma_20 < sma_50:
                bearish_score += 1
                signals_detail.append("Price below SMAs (bearish)")
            
            # EMA Analysis
            if ema_12 > ema_26:
                bullish_score += 1
                signals_detail.append("EMA12 > EMA26 (bullish)")
            else:
                bearish_score += 1
                signals_detail.append("EMA12 < EMA26 (bearish)")
            
            # Bollinger Bands Analysis
            if price <= bb_lower:
                bullish_score += 1
                signals_detail.append("Price at lower Bollinger Band (oversold)")
            elif price >= bb_upper:
                bearish_score += 1
                signals_detail.append("Price at upper Bollinger Band (overbought)")
            
            # Stochastic Analysis
            if stoch_k < 20:
                bullish_score += 1
                signals_detail.append("Stochastic oversold")
            elif stoch_k > 80:
                bearish_score += 1
                signals_detail.append("Stochastic overbought")
            
            # تعیین سیگنال نهایی
            total_score = bullish_score + bearish_score
            confidence = 0
            action = "HOLD"
            
            if bullish_score >= 4 and bullish_score > bearish_score:
                action = "BUY"
                confidence = min(0.95, (bullish_score / max(total_score, 1)) * 0.8 + 0.2)
            elif bearish_score >= 4 and bearish_score > bullish_score:
                action = "SELL"
                confidence = min(0.95, (bearish_score / max(total_score, 1)) * 0.8 + 0.2)
            elif force_analysis:
                # در حالت force، حتی سیگنال‌های ضعیف‌تر را ارائه می‌دهیم
                if bullish_score > bearish_score:
                    action = "BUY"
                    confidence = min(0.7, (bullish_score / max(total_score, 1)) * 0.6 + 0.1)
                elif bearish_score > bullish_score:
                    action = "SELL"
                    confidence = min(0.7, (bearish_score / max(total_score, 1)) * 0.6 + 0.1)
                else:
                    action = "HOLD"
                    confidence = 0.5
            
            # محاسبه اهداف قیمتی
            if action == "BUY":
                entry_price = price
                target_price = price * 1.015  # 1.5% target
                stop_loss = price * 0.992     # 0.8% stop loss
            elif action == "SELL":
                entry_price = price
                target_price = price * 0.985  # 1.5% target
                stop_loss = price * 1.008     # 0.8% stop loss
            else:
                entry_price = price
                target_price = price
                stop_loss = price
            
            # فقط سیگنال‌های با اعتماد بالا یا force را برمی‌گردانیم
            if confidence >= 0.6 or force_analysis:
                return {
                    'action': action,
                    'confidence': confidence,
                    'entry_price': entry_price,
                    'target_price': target_price,
                    'stop_loss': stop_loss,
                    'current_price': price,
                    'timestamp': datetime.now(),
                    'indicators': indicators,
                    'analysis_details': signals_detail,
                    'bullish_score': bullish_score,
                    'bearish_score': bearish_score,
                    'market_active': self.is_market_active(),
                    'forced': force_analysis
                }
            
            return None
            
        except Exception as e:
            logger.error(f"Error in market analysis: {e}")
            return None

# Global instance
ai_signal_engine = AISignalEngine()

def get_ai_trading_signal(force_analysis: bool = False) -> Optional[Dict]:
    """تابع global برای دریافت سیگنال AI"""
    return ai_signal_engine.generate_ai_signal(force_analysis)

def get_market_status() -> Dict:
    """دریافت وضعیت بازار"""
    return {
        'market_active': ai_signal_engine.is_market_active(),
        'last_signal_time': ai_signal_engine.last_signal_time,
        'cooldown_remaining': max(0, ai_signal_engine.signal_cooldown - 
                                 (datetime.now() - ai_signal_engine.last_signal_time).total_seconds()
                                 if ai_signal_engine.last_signal_time else 0)
    }
