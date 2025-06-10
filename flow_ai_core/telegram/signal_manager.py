import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from telegram import Bot
from telegram.error import TelegramError
from ..ai_signal_engine import get_ai_trading_signal, get_market_status
from ..config import TELEGRAM_BOT_TOKEN, TELEGRAM_PREMIUM_USERS, TELEGRAM_ADMIN_IDS
import threading
import time

logger = logging.getLogger(__name__)

class TelegramSignalManager:
    def __init__(self):
        self.bot = Bot(token=TELEGRAM_BOT_TOKEN)
        self.running = False
        self.signal_thread = None
        self.check_interval = 300  # 5 دقیقه
        self.subscribers = {
            'premium': set(TELEGRAM_PREMIUM_USERS),
            'admin': set(TELEGRAM_ADMIN_IDS),
            'free': set()
        }
        self.signal_history = []
        
    def add_subscriber(self, user_id: int, tier: str = 'free'):
        """اضافه کردن مشترک"""
        if tier in self.subscribers:
            self.subscribers[tier].add(user_id)
            logger.info(f"User {user_id} added to {tier} subscribers")
    
    def remove_subscriber(self, user_id: int, tier: str = 'free'):
        """حذف مشترک"""
        if tier in self.subscribers:
            self.subscribers[tier].discard(user_id)
            logger.info(f"User {user_id} removed from {tier} subscribers")
    
    def format_signal_message(self, signal: Dict, tier: str = 'free') -> str:
        """فرمت کردن پیام سیگنال برای تلگرام"""
        action_emoji = {
            'BUY': '🟢',
            'SELL': '🔴', 
            'HOLD': '🟡'
        }
        
        confidence_stars = '⭐' * int(signal['confidence'] * 5)
        
        if tier == 'premium' or tier == 'admin':
            # پیام کامل برای کاربران پریمیوم
            message = f"""
🚨 **سیگنال معاملاتی FlowAI** 🚨

{action_emoji.get(signal['action'], '🟡')} **عمل:** {signal['action']}
⭐ **اعتماد:** {signal['confidence']:.1%} {confidence_stars}

💰 **قیمت‌ها:**
🔹 قیمت فعلی: ${signal['current_price']:.2f}
🔹 قیمت ورود: ${signal['entry_price']:.2f}
🎯 هدف: ${signal['target_price']:.2f} ({((signal['target_price']/signal['entry_price']-1)*100):+.1f}%)
🛑 حد ضرر: ${signal['stop_loss']:.2f} ({((signal['stop_loss']/signal['entry_price']-1)*100):+.1f}%)

📊 **تحلیل تکنیکال:**
🔹 RSI: {signal['indicators']['rsi']:.1f}
🔹 MACD: {signal['indicators']['macd']:.3f}
🔹 SMA20: ${signal['indicators']['sma_20']:.2f}
🔹 امتیاز صعودی: {signal['bullish_score']}
🔹 امتیاز نزولی: {signal['bearish_score']}

⏰ **زمان:** {signal['timestamp'].strftime('%Y-%m-%d %H:%M:%S')}
🏪 **وضعیت بازار:** {'فعال' if signal['market_active'] else 'بسته'}
{'🔄 **تحلیل اجباری**' if signal.get('forced') else ''}

⚠️ **هشدار:** این سیگنال صرفاً جنبه آموزشی دارد.
"""
        else:
            # پیام محدود برای کاربران رایگان
            message = f"""
🚨 **سیگنال رایگان FlowAI** 🚨

{action_emoji.get(signal['action'], '🟡')} **عمل:** {signal['action']}
⭐ **اعتماد:** {confidence_stars}

💰 **قیمت فعلی:** ${signal['current_price']:.2f}

💎 **برای دریافت تحلیل کامل:**
🔹 اهداف قیمتی دقیق
🔹 حد ضرر محاسبه شده
🔹 تحلیل‌های تکنیکال پیشرفته
🔹 اطلاع‌رسانی فوری

👆 ارتقا به پریمیوم دهید!

⏰ {signal['timestamp'].strftime('%H:%M')}
"""
        
        return message
    
    async def send_signal_to_users(self, signal: Dict):
        """ارسال سیگنال به کاربران"""
        try:
            # ارسال به ادمین‌ها
            admin_message = self.format_signal_message(signal, 'admin')
            for admin_id in self.subscribers['admin']:
                try:
                    await self.bot.send_message(
                        chat_id=admin_id,
                        text=admin_message,
                        parse_mode='Markdown'
                    )
                    logger.info(f"Signal sent to admin {admin_id}")
                except TelegramError as e:
                    logger.error(f"Failed to send signal to admin {admin_id}: {e}")
            
            # ارسال به کاربران پریمیوم
            premium_message = self.format_signal_message(signal, 'premium')
            for premium_id in self.subscribers['premium']:
                try:
                    await self.bot.send_message(
                        chat_id=premium_id,
                        text=premium_message,
                        parse_mode='Markdown'
                    )
                    logger.info(f"Signal sent to premium user {premium_id}")
                except TelegramError as e:
                    logger.error(f"Failed to send signal to premium user {premium_id}: {e}")
            
            # ارسال به کاربران رایگان (محدود)
            if signal['confidence'] >= 0.8:  # فقط سیگنال‌های قوی
                free_message = self.format_signal_message(signal, 'free')
                for free_id in self.subscribers['free']:
                    try:
                        await self.bot.send_message(
                            chat_id=free_id,
                            text=free_message,
                            parse_mode='Markdown'
                        )
                        logger.info(f"Signal sent to free user {free_id}")
                    except TelegramError as e:
                        logger.error(f"Failed to send signal to free user {free_id}: {e}")
            
            # ذخیره در تاریخچه
            self.signal_history.append({
                'signal': signal,
                'sent_time': datetime.now(),
                'recipients': {
                    'admin': len(self.subscribers['admin']),
                    'premium': len(self.subscribers['premium']),
                    'free': len(self.subscribers['free']) if signal['confidence'] >= 0.8 else 0
                }
            })
            
            # نگهداری آخرین 50 سیگنال
            if len(self.signal_history) > 50:
                self.signal_history.pop(0)
                
        except Exception as e:
            logger.error(f"Error sending signals: {e}")
    
    def signal_monitoring_loop(self):
        """حلقه نظارت بر سیگنال‌ها"""
        logger.info("Signal monitoring started")
        
        while self.running:
            try:
                # تولید سیگنال AI
                signal = get_ai_trading_signal(force_analysis=False)
                
                if signal:
                    logger.info(f"New signal generated: {signal['action']} with confidence {signal['confidence']:.2f}")
                    
                    # ارسال سیگنال به کاربران
                    asyncio.run(self.send_signal_to_users(signal))
                
                # انتظار تا چک بعدی
                time.sleep(self.check_interval)
                
            except Exception as e:
                logger.error(f"Error in signal monitoring loop: {e}")
                time.sleep(60)  # انتظار 1 دقیقه در صورت خطا
    
    def start_monitoring(self):
        """شروع نظارت خودکار"""
        if not self.running:
            self.running = True
            self.signal_thread = threading.Thread(target=self.signal_monitoring_loop, daemon=True)
            self.signal_thread.start()
            logger.info("Automatic signal monitoring started")
    
    def stop_monitoring(self):
        """توقف نظارت خودکار"""
        self.running = False
        if self.signal_thread:
            self.signal_thread.join(timeout=5)
        logger.info("Automatic signal monitoring stopped")
    
    async def send_manual_signal(self, user_id: int, force: bool = True) -> bool:
        """ارسال سیگنال دستی"""
        try:
            signal = get_ai_trading_signal(force_analysis=force)
            
            if signal:
                # تشخیص نوع کاربر
                if user_id in self.subscribers['admin']:
                    tier = 'admin'
                elif user_id in self.subscribers['premium']:
                    tier = 'premium'
                else:
                    tier = 'free'
                
                message = self.format_signal_message(signal, tier)
                
                await self.bot.send_message(
                    chat_id=user_id,
                    text=message,
                    parse_mode='Markdown'
                )
                
                logger.info(f"Manual signal sent to user {user_id}")
                return True
            else:
                await self.bot.send_message(
                    chat_id=user_id,
                    text="🔍 **تحلیل انجام شد**\n\nدر حال حاضر شرایط مناسبی برای سیگنال وجود ندارد.\n\n⏰ لطفاً دوباره تلاش کنید.",
                    parse_mode='Markdown'
                )
                return False
                
        except Exception as e:
            logger.error(f"Error sending manual signal to {user_id}: {e}")
            return False
    
    def get_signal_statistics(self) -> Dict:
        """دریافت آمار سیگنال‌ها"""
        if not self.signal_history:
            return {
                'total_signals': 0,
                'buy_signals': 0,
                'sell_signals': 0,
                'hold_signals': 0,
                'avg_confidence': 0,
                'last_signal_time': None
            }
        
        total = len(self.signal_history)
        buy_count = sum(1 for s in self.signal_history if s['signal']['action'] == 'BUY')
        sell_count = sum(1 for s in self.signal_history if s['signal']['action'] == 'SELL')
        hold_count = sum(1 for s in self.signal_history if s['signal']['action'] == 'HOLD')
        avg_confidence = sum(s['signal']['confidence'] for s in self.signal_history) / total
        
        return {
            'total_signals': total,
            'buy_signals': buy_count,
            'sell_signals': sell_count,
            'hold_signals': hold_count,
            'avg_confidence': avg_confidence,
            'last_signal_time': self.signal_history[-1]['sent_time'] if self.signal_history else None,
            'subscribers_count': {
                'admin': len(self.subscribers['admin']),
                'premium': len(self.subscribers['premium']),
                'free': len(self.subscribers['free'])
            }
        }

# Global instance
signal_manager = TelegramSignalManager()

def start_signal_monitoring():
    """شروع نظارت خودکار سیگنال‌ها"""
    signal_manager.start_monitoring()

def stop_signal_monitoring():
    """توقف نظارت خودکار سیگنال‌ها"""
    signal_manager.stop_monitoring()

async def send_manual_analysis(user_id: int) -> bool:
    """ارسال تحلیل دستی"""
    return await signal_manager.send_manual_signal(user_id, force=True)

def get_signal_stats() -> Dict:
    """دریافت آمار سیگنال‌ها"""
    return signal_manager.get_signal_statistics()
