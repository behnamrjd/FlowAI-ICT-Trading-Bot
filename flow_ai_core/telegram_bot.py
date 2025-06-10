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
from flow_ai_core.config import TELEGRAM_BOT_TOKEN
from flow_ai_core.telegram.signal_manager import start_signal_monitoring, stop_signal_monitoring
from flow_ai_core.reporting_engine import generate_daily_report
from flow_ai_core.notification_system import send_system_alert

# تنظیم logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.FileHandler('logs/telegram_bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class FlowAITelegramBot:
    def __init__(self):
        self.updater = None
        self.running = False
        self.start_time = datetime.now()
        
        # ایجاد فولدر logs
        os.makedirs('logs', exist_ok=True)
        
    def error_handler(self, update, context):
        """مدیریت خطاهای تلگرام"""
        logger.error(f"Update {update} caused error {context.error}")
        
        if update and update.effective_message:
            try:
                update.effective_message.reply_text(
                    "❌ خطایی رخ داده است. لطفاً دوباره تلاش کنید.\n\n"
                    "اگر مشکل ادامه داشت، با پشتیبانی تماس بگیرید."
                )
            except Exception as e:
                logger.error(f"Error sending error message: {e}")
        
        # ارسال هشدار به ادمین‌ها
        try:
            error_message = f"خطا در ربات تلگرام:\n{str(context.error)}"
            send_system_alert("error", error_message, admin_only=True)
        except Exception as e:
            logger.error(f"Failed to send error alert: {e}")
    
    def signal_handler(self, signum, frame):
        """مدیریت سیگنال‌های سیستم"""
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.shutdown()
    
    def shutdown(self):
        """خاموش کردن ایمن ربات"""
        logger.info("🛑 Shutting down FlowAI Telegram Bot...")
        
        try:
            # توقف نظارت سیگنال‌ها
            stop_signal_monitoring()
            logger.info("Signal monitoring stopped")
            
            # تولید گزارش نهایی
            try:
                final_report = generate_daily_report()
                logger.info("Final daily report generated")
            except Exception as e:
                logger.error(f"Error generating final report: {e}")
            
            # توقف updater
            if self.updater:
                self.updater.stop()
                logger.info("Telegram updater stopped")
            
            # ارسال اطلاع توقف به ادمین‌ها
            try:
                uptime = datetime.now() - self.start_time
                shutdown_message = f"ربات FlowAI متوقف شد.\n\nمدت فعالیت: {uptime}"
                send_system_alert("info", shutdown_message, admin_only=True)
            except Exception as e:
                logger.error(f"Error sending shutdown alert: {e}")
            
            self.running = False
            logger.info("✅ FlowAI Telegram Bot shutdown completed")
            
        except Exception as e:
            logger.error(f"Error during shutdown: {e}")
    
    def health_check_loop(self):
        """حلقه بررسی سلامت سیستم"""
        while self.running:
            try:
                # بررسی وضعیت کلی سیستم
                current_time = datetime.now()
                uptime = current_time - self.start_time
                
                # لاگ وضعیت هر ساعت
                if uptime.total_seconds() % 3600 < 60:  # هر ساعت
                    logger.info(f"Health check: Bot running for {uptime}")
                
                # بررسی‌های سلامت اضافی می‌تواند اینجا اضافه شود
                # مثل بررسی اتصال API، حافظه، CPU و غیره
                
                time.sleep(60)  # بررسی هر دقیقه
                
            except Exception as e:
                logger.error(f"Error in health check: {e}")
                time.sleep(60)
    
    def start(self):
        """شروع ربات تلگرام"""
        try:
            logger.info("🚀 Starting FlowAI Telegram Bot...")
            
            # بررسی توکن
            if not TELEGRAM_BOT_TOKEN:
                logger.error("❌ TELEGRAM_BOT_TOKEN not found in config!")
                return False
            
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
            self.updater.start_polling(drop_pending_updates=True)
            self.running = True
            
            logger.info("🤖 FlowAI Telegram Bot started successfully!")
            logger.info("📱 Bot is ready to receive messages...")
            
            # شروع نظارت خودکار سیگنال‌ها
            try:
                start_signal_monitoring()
                logger.info("📡 Automatic signal monitoring started")
            except Exception as e:
                logger.error(f"Error starting signal monitoring: {e}")
            
            # شروع health check در thread جداگانه
            health_thread = threading.Thread(target=self.health_check_loop, daemon=True)
            health_thread.start()
            
            # ارسال اطلاع شروع به ادمین‌ها
            try:
                startup_message = f"ربات FlowAI با موفقیت راه‌اندازی شد.\n\nزمان شروع: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}"
                send_system_alert("info", startup_message, admin_only=True)
            except Exception as e:
                logger.error(f"Error sending startup alert: {e}")
            
            # نگه داشتن ربات فعال
            self.updater.idle()
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Error starting bot: {e}")
            return False
        finally:
            self.shutdown()

def main():
    """تابع اصلی"""
    bot = FlowAITelegramBot()
    
    try:
        success = bot.start()
        if not success:
            sys.exit(1)
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
