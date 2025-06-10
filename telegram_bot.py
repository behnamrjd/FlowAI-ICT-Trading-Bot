import logging
import sys
import os
import signal
import threading
import time
from datetime import datetime

# اضافه کردن مسیر پروژه
sys.path.append('/opt/FlowAI-ICT-Trading-Bot')

from telegram.ext import Updater, CommandHandler, MessageHandler, Filters, CallbackQueryHandler
from flow_ai_core.telegram import setup_telegram_handlers
from flow_ai_core.config import (
    TELEGRAM_BOT_TOKEN, ICT_ENABLED, AI_MODEL_ENABLED,
    SIGNAL_GENERATION_ENABLED, LOG_LEVEL, LOG_FILE_PATH
)
from flow_ai_core.telegram.signal_manager import start_signal_monitoring, stop_signal_monitoring
from flow_ai_core.reporting_engine import generate_daily_report
from flow_ai_core.notification_system import send_system_alert
from flow_ai_core.data_handler import ict_data_handler

# تنظیم logging پیشرفته
def setup_logging():
    """تنظیم سیستم logging پیشرفته"""
    # ایجاد فولدر logs
    os.makedirs('logs', exist_ok=True)
    
    # تنظیم سطح logging
    log_level = getattr(logging, LOG_LEVEL.upper(), logging.INFO)
    
    # فرمت logging
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s'
    )
    
    # File handler
    file_handler = logging.FileHandler(LOG_FILE_PATH, encoding='utf-8')
    file_handler.setFormatter(formatter)
    file_handler.setLevel(log_level)
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    console_handler.setLevel(log_level)
    
    # Root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)
    
    # Telegram library logging (کاهش سطح)
    logging.getLogger('telegram').setLevel(logging.WARNING)
    logging.getLogger('urllib3').setLevel(logging.WARNING)

setup_logging()
logger = logging.getLogger(__name__)

class FlowAIICTTelegramBot:
    def __init__(self):
        self.updater = None
        self.running = False
        self.start_time = datetime.now()
        self.health_check_interval = 300  # 5 minutes
        self.last_health_check = datetime.now()
        
        # آمار عملکرد
        self.stats = {
            'messages_processed': 0,
            'errors_count': 0,
            'uptime_start': self.start_time,
            'last_restart': None
        }
        
        logger.info("FlowAI-ICT Telegram Bot initialized")
        
    def error_handler(self, update, context):
        """مدیریت خطاهای تلگرام با گزارش‌دهی پیشرفته"""
        self.stats['errors_count'] += 1
        error_msg = str(context.error)
        
        logger.error(f"Telegram error: {error_msg}")
        logger.error(f"Update: {update}")
        logger.error(f"Context: {context}")
        
        if update and update.effective_message:
            try:
                user_id = update.effective_user.id if update.effective_user else "Unknown"
                message_text = update.effective_message.text if update.effective_message.text else "No text"
                
                logger.error(f"Error details - User: {user_id}, Message: {message_text}")
                
                # ارسال پیام خطا به کاربر
                update.effective_message.reply_text(
                    "❌ **System Error**\n\n"
                    "An error occurred while processing your request.\n"
                    "Our team has been notified.\n\n"
                    "Please try again in a moment.\n"
                    "If the problem persists, contact support.",
                    parse_mode='Markdown'
                )
            except Exception as e:
                logger.error(f"Error sending error message to user: {e}")
        
        # ارسال هشدار به ادمین‌ها (فقط برای خطاهای مهم)
        if self.stats['errors_count'] % 5 == 0:  # هر 5 خطا
            try:
                error_alert = f"""
🚨 **System Error Alert**

❌ **Error:** {error_msg[:200]}
📊 **Total Errors:** {self.stats['errors_count']}
⏰ **Time:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
🔄 **Uptime:** {datetime.now() - self.start_time}

🔍 **Action Required:** Check logs for details
"""
                send_system_alert("error", error_alert, admin_only=True)
            except Exception as e:
                logger.error(f"Failed to send error alert: {e}")
    
    def message_handler_wrapper(self, handler_func):
        """Wrapper برای شمارش پیام‌ها و مدیریت آمار"""
        def wrapper(update, context):
            try:
                self.stats['messages_processed'] += 1
                return handler_func(update, context)
            except Exception as e:
                logger.error(f"Error in message handler: {e}")
                self.error_handler(update, context)
        return wrapper
    
    def signal_handler(self, signum, frame):
        """مدیریت سیگنال‌های سیستم"""
        logger.info(f"Received signal {signum}, initiating graceful shutdown...")
        self.shutdown()
    
    def health_check_loop(self):
        """حلقه بررسی سلامت سیستم"""
        while self.running:
            try:
                current_time = datetime.now()
                uptime = current_time - self.start_time
                
                # بررسی سلامت هر 5 دقیقه
                if (current_time - self.last_health_check).total_seconds() >= self.health_check_interval:
                    self.perform_health_check(uptime)
                    self.last_health_check = current_time
                
                time.sleep(60)  # بررسی هر دقیقه
                
            except Exception as e:
                logger.error(f"Error in health check loop: {e}")
                time.sleep(60)
    
    def perform_health_check(self, uptime):
        """انجام بررسی سلامت سیستم"""
        try:
            logger.info(f"Health check - Uptime: {uptime}")
            logger.info(f"Messages processed: {self.stats['messages_processed']}")
            logger.info(f"Errors count: {self.stats['errors_count']}")
            
            # بررسی وضعیت ICT data handler
            try:
                test_price = ict_data_handler.get_real_time_price()
                if test_price > 0:
                    logger.info(f"ICT Data Handler: OK - Price: ${test_price:.2f}")
                else:
                    logger.warning("ICT Data Handler: Price data issue")
            except Exception as e:
                logger.error(f"ICT Data Handler health check failed: {e}")
            
            # بررسی signal monitoring
            from flow_ai_core.telegram.signal_manager import signal_manager
            if signal_manager.running:
                logger.info("Signal Monitoring: Active")
            else:
                logger.warning("Signal Monitoring: Inactive")
            
            # بررسی حافظه (اختیاری)
            try:
                import psutil
                memory_percent = psutil.virtual_memory().percent
                cpu_percent = psutil.cpu_percent()
                logger.info(f"System resources - Memory: {memory_percent}%, CPU: {cpu_percent}%")
                
                if memory_percent > 90:
                    logger.warning(f"High memory usage: {memory_percent}%")
                if cpu_percent > 90:
                    logger.warning(f"High CPU usage: {cpu_percent}%")
            except ImportError:
                pass  # psutil not installed
            
            # ارسال گزارش سلامت روزانه
            if uptime.total_seconds() % 86400 < self.health_check_interval:  # روزانه
                self.send_daily_health_report(uptime)
                
        except Exception as e:
            logger.error(f"Error in health check: {e}")
    
    def send_daily_health_report(self, uptime):
        """ارسال گزارش سلامت روزانه"""
        try:
            health_report = f"""
📊 **Daily Health Report - FlowAI-ICT Bot**

⏰ **Uptime:** {uptime}
📨 **Messages Processed:** {self.stats['messages_processed']}
❌ **Errors:** {self.stats['errors_count']}
📈 **Error Rate:** {(self.stats['errors_count'] / max(self.stats['messages_processed'], 1) * 100):.2f}%

🎯 **ICT Features:**
🔹 ICT Engine: {'🟢 Active' if ICT_ENABLED else '🔴 Inactive'}
🔹 AI Model: {'🟢 Active' if AI_MODEL_ENABLED else '🔴 Inactive'}
🔹 Signal Generation: {'🟢 Active' if SIGNAL_GENERATION_ENABLED else '🔴 Inactive'}

🤖 **System Status:** Healthy ✅
"""
            send_system_alert("info", health_report, admin_only=True)
            logger.info("Daily health report sent")
        except Exception as e:
            logger.error(f"Error sending daily health report: {e}")
    
    def shutdown(self):
        """خاموش کردن ایمن ربات"""
        logger.info("🛑 Initiating FlowAI-ICT Telegram Bot shutdown...")
        
        try:
            self.running = False
            
            # توقف نظارت سیگنال‌ها
            try:
                stop_signal_monitoring()
                logger.info("Signal monitoring stopped")
            except Exception as e:
                logger.error(f"Error stopping signal monitoring: {e}")
            
            # تولید گزارش نهایی
            try:
                final_report = generate_daily_report()
                logger.info("Final daily report generated")
            except Exception as e:
                logger.error(f"Error generating final report: {e}")
            
            # توقف updater
            if self.updater:
                try:
                    self.updater.stop()
                    logger.info("Telegram updater stopped")
                except Exception as e:
                    logger.error(f"Error stopping updater: {e}")
            
            # ارسال اطلاع توقف
            try:
                uptime = datetime.now() - self.start_time
                shutdown_message = f"""
🛑 **FlowAI-ICT Bot Shutdown**

⏰ **Uptime:** {uptime}
📨 **Messages Processed:** {self.stats['messages_processed']}
❌ **Total Errors:** {self.stats['errors_count']}
📊 **Final Status:** Graceful shutdown completed

🎯 **ICT Features Status:**
🔹 All systems stopped safely
🔹 Data integrity maintained
🔹 Ready for restart

⏰ **Shutdown Time:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
                send_system_alert("info", shutdown_message, admin_only=True)
            except Exception as e:
                logger.error(f"Error sending shutdown alert: {e}")
            
            logger.info("✅ FlowAI-ICT Telegram Bot shutdown completed successfully")
            
        except Exception as e:
            logger.error(f"Error during shutdown: {e}")
    
    def start(self):
        """شروع ربات تلگرام ICT"""
        try:
            logger.info("🚀 Starting FlowAI-ICT Telegram Bot...")
            
            # بررسی تنظیمات
            if not TELEGRAM_BOT_TOKEN:
                logger.error("❌ TELEGRAM_BOT_TOKEN not found in config!")
                return False
            
            logger.info(f"ICT Engine: {'Enabled' if ICT_ENABLED else 'Disabled'}")
            logger.info(f"AI Model: {'Enabled' if AI_MODEL_ENABLED else 'Disabled'}")
            logger.info(f"Signal Generation: {'Enabled' if SIGNAL_GENERATION_ENABLED else 'Disabled'}")
            
            # ایجاد updater
            self.updater = Updater(TELEGRAM_BOT_TOKEN, use_context=True)
            dispatcher = self.updater.dispatcher
            
            # راه‌اندازی handler های تلگرام
            setup_telegram_handlers(dispatcher)
            
            # اضافه کردن error handler
            dispatcher.add_error_handler(self.error_handler)
            
            # تنظیم signal handlers
            signal.signal(signal.SIGINT, self.signal_handler)
            signal.signal(signal.SIGTERM, self.signal_handler)
            
            # شروع ربات
            self.updater.start_polling(
                drop_pending_updates=True,
                clean=True,
                timeout=30,
                read_latency=2.0
            )
            self.running = True
            
            logger.info("🤖 FlowAI-ICT Telegram Bot started successfully!")
            logger.info("📱 Bot is ready to receive messages with ICT analysis...")
            
            # شروع نظارت خودکار سیگنال‌ها
            if SIGNAL_GENERATION_ENABLED:
                try:
                    start_signal_monitoring()
                    logger.info("📡 ICT Signal monitoring started")
                except Exception as e:
                    logger.error(f"Error starting signal monitoring: {e}")
            
            # شروع health check در thread جداگانه
            health_thread = threading.Thread(target=self.health_check_loop, daemon=True)
            health_thread.start()
            logger.info("💊 Health monitoring started")
            
            # ارسال اطلاع شروع
            try:
                startup_message = f"""
🚀 **FlowAI-ICT Bot Started**

⏰ **Start Time:** {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}

🎯 **ICT Features:**
🔹 ICT Engine: {'🟢 Active' if ICT_ENABLED else '🔴 Inactive'}
🔹 AI Model: {'🟢 Active' if AI_MODEL_ENABLED else '🔴 Inactive'}
🔹 Signal Generation: {'🟢 Active' if SIGNAL_GENERATION_ENABLED else '🔴 Inactive'}

🤖 **System Ready:**
🔹 Order Block Detection: Ready
🔹 Fair Value Gap Analysis: Ready
🔹 Liquidity Sweep Detection: Ready
🔹 Market Structure Analysis: Ready

📱 **Bot Status:** Online and Ready! ✅
"""
                send_system_alert("info", startup_message, admin_only=True)
            except Exception as e:
                logger.error(f"Error sending startup alert: {e}")
            
            # نگه داشتن ربات فعال
            self.updater.idle()
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Error starting FlowAI-ICT bot: {e}")
            return False
        finally:
            self.shutdown()

def main():
    """تابع اصلی"""
    try:
        # نمایش اطلاعات شروع
        print("🎯 FlowAI-ICT Trading Bot")
        print("=" * 50)
        print(f"🔹 ICT Engine: {'Enabled' if ICT_ENABLED else 'Disabled'}")
        print(f"🔹 AI Model: {'Enabled' if AI_MODEL_ENABLED else 'Disabled'}")
        print(f"🔹 Signal Generation: {'Enabled' if SIGNAL_GENERATION_ENABLED else 'Disabled'}")
        print(f"🔹 Log Level: {LOG_LEVEL}")
        print("=" * 50)
        
        # ایجاد و شروع ربات
        bot = FlowAIICTTelegramBot()
        success = bot.start()
        
        if not success:
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("Bot stopped by user (Ctrl+C)")
        print("\n🛑 Bot stopped by user")
    except Exception as e:
        logger.error(f"Unexpected error in main: {e}")
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
