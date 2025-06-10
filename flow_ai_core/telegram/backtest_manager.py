from telegram import Update, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import CallbackContext
import logging

logger = logging.getLogger(__name__)

class BacktestManager:
    def __init__(self):
        self.running_backtests = {}  # ذخیره بک‌تست‌های در حال اجرا
    
    def start_backtest(self, update: Update, context: CallbackContext):
        """شروع بک‌تست جدید"""
        query = update.callback_query
        query.answer()
        
        # پارامترهای پیش‌فرض
        backtest_params = {
            'symbol': 'GOLD',
            'timeframe': '1h',
            'start_date': '2024-01-01',
            'end_date': '2024-12-31',
            'initial_balance': 10000
        }
        
        # شروع بک‌تست (شبیه‌سازی)
        result_text = f"""
🧪 **بک‌تست شروع شد**

📊 **پارامترها:**
🔹 نماد: {backtest_params['symbol']}
🔹 تایم فریم: {backtest_params['timeframe']}
🔹 تاریخ شروع: {backtest_params['start_date']}
🔹 تاریخ پایان: {backtest_params['end_date']}
🔹 سرمایه اولیه: ${backtest_params['initial_balance']:,}

⏳ در حال پردازش... (30 ثانیه)
"""
        
        keyboard = [
            [InlineKeyboardButton("📊 مشاهده نتایج", callback_data="show_backtest_results")],
            [InlineKeyboardButton("🔙 بازگشت", callback_data="backtest_menu")]
        ]
        
        query.edit_message_text(
            result_text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode='Markdown'
        )
    
    def show_results(self, update: Update, context: CallbackContext):
        """نمایش نتایج بک‌تست"""
        query = update.callback_query
        query.answer()
        
        # نتایج شبیه‌سازی شده
        results_text = """
📈 **نتایج بک‌تست**

💰 **عملکرد مالی:**
🔹 سرمایه اولیه: $10,000
🔹 سرمایه نهایی: $12,450
🔹 سود خالص: $2,450 (24.5%)
🔹 حداکثر ضرر: -$850 (8.5%)

📊 **آمار معاملات:**
🔹 تعداد معاملات: 45
🔹 معاملات سودآور: 28 (62%)
🔹 معاملات ضررده: 17 (38%)
🔹 میانگین سود: $87.5

⭐ **امتیاز کلی: 8.2/10**
"""
        
        keyboard = [
            [InlineKeyboardButton("📁 دانلود گزارش", callback_data="download_backtest_report")],
            [InlineKeyboardButton("🔄 بک‌تست جدید", callback_data="start_backtest")],
            [InlineKeyboardButton("🔙 بازگشت", callback_data="backtest_menu")]
        ]
        
        query.edit_message_text(
            results_text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode='Markdown'
        )

# Instance global
backtest_manager = BacktestManager()

def setup_backtest_handlers(dispatcher):
    """راه‌اندازی handler های بک‌تست"""
    from telegram.ext import CallbackQueryHandler
    
    dispatcher.add_handler(CallbackQueryHandler(
        backtest_manager.start_backtest,
        pattern=r'^start_backtest$'
    ))
    
    dispatcher.add_handler(CallbackQueryHandler(
        backtest_manager.show_results,
        pattern=r'^(show_backtest_results|last_results)$'
    ))
