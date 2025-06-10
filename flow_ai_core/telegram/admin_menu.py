from telegram import Update, ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import CallbackContext, CommandHandler, MessageHandler, Filters, CallbackQueryHandler
import logging
import asyncio
from ..data_sources.brsapi_fetcher import get_brsapi_status, get_brsapi_gold_price
from ..config import TELEGRAM_ADMIN_IDS
from ..telegram.signal_manager import signal_manager, start_signal_monitoring, stop_signal_monitoring, get_signal_stats
from ..ai_signal_engine import get_ai_trading_signal, get_market_status
from ..backtest_engine import run_backtest_analysis, get_backtest_summary
from ..telegram.premium_manager import premium_manager, get_premium_stats
from ..risk_manager import get_risk_status
from ..reporting_engine import export_daily_report_text, export_weekly_report_text
from ..notification_system import send_system_alert, get_notification_stats

logger = logging.getLogger(__name__)

class AdminMenu:
    def __init__(self):
        self.admin_ids = TELEGRAM_ADMIN_IDS
        self.pending_actions = {}  # برای ذخیره اقدامات در انتظار
        logger.info(f"Admin menu initialized with IDs: {self.admin_ids}")
    
    def is_admin(self, user_id: int) -> bool:
        """بررسی ادمین بودن کاربر"""
        is_admin = user_id in self.admin_ids
        logger.info(f"User {user_id} admin check: {is_admin}")
        return is_admin
    
    def main_menu_keyboard(self):
        """منوی اصلی ادمین با دکمه‌های زیبا"""
        keyboard = [
            [
                KeyboardButton("🤖 مدیریت ربات"),
                KeyboardButton("📊 آمار و گزارش")
            ],
            [
                KeyboardButton("🚨 مدیریت سیگنال‌ها"),
                KeyboardButton("👥 مدیریت کاربران")
            ],
            [
                KeyboardButton("🧪 بک‌تست"),
                KeyboardButton("⚠️ مدیریت ریسک")
            ],
            [
                KeyboardButton("📋 گزارش‌گیری"),
                KeyboardButton("🔔 اطلاع‌رسانی")
            ],
            [
                KeyboardButton("💰 قیمت فعلی"),
                KeyboardButton("📡 وضعیت API")
            ],
            [
                KeyboardButton("🔍 تحلیل فوری"),
                KeyboardButton("⚙️ تنظیمات سیستم")
            ]
        ]
        return ReplyKeyboardMarkup(keyboard, resize_keyboard=True, one_time_keyboard=False)
    
    def bot_management_keyboard(self):
        """منوی مدیریت ربات"""
        keyboard = [
            [
                InlineKeyboardButton("🟢 شروع ربات", callback_data="bot_start"),
                InlineKeyboardButton("🔴 توقف ربات", callback_data="bot_stop")
            ],
            [
                InlineKeyboardButton("📊 وضعیت API", callback_data="api_status"),
                InlineKeyboardButton("💰 قیمت فعلی", callback_data="current_price")
            ],
            [
                InlineKeyboardButton("📋 لاگ‌ها", callback_data="view_logs"),
                InlineKeyboardButton("🔄 ریستارت", callback_data="bot_restart")
            ],
            [
                InlineKeyboardButton("⚙️ تنظیمات", callback_data="bot_settings"),
                InlineKeyboardButton("🧪 بک‌تست", callback_data="backtest_menu")
            ],
            [
                InlineKeyboardButton("🔙 بازگشت", callback_data="main_menu")
            ]
        ]
        return InlineKeyboardMarkup(keyboard)
    
    def signal_management_keyboard(self):
        """منوی مدیریت سیگنال‌ها"""
        keyboard = [
            [
                InlineKeyboardButton("▶️ شروع نظارت", callback_data="start_monitoring"),
                InlineKeyboardButton("⏹️ توقف نظارت", callback_data="stop_monitoring")
            ],
            [
                InlineKeyboardButton("🔍 تحلیل فوری", callback_data="force_analysis"),
                InlineKeyboardButton("📊 آمار سیگنال‌ها", callback_data="signal_stats")
            ],
            [
                InlineKeyboardButton("📈 عملکرد", callback_data="signal_performance"),
                InlineKeyboardButton("⚙️ تنظیمات", callback_data="signal_settings")
            ],
            [
                InlineKeyboardButton("🔙 بازگشت", callback_data="main_menu")
            ]
        ]
        return InlineKeyboardMarkup(keyboard)
    
    def user_management_keyboard(self):
        """منوی مدیریت کاربران"""
        keyboard = [
            [
                InlineKeyboardButton("➕ اضافه کردن پریمیوم", callback_data="add_premium_user"),
                InlineKeyboardButton("➖ حذف پریمیوم", callback_data="remove_premium_user")
            ],
            [
                InlineKeyboardButton("📋 لیست پریمیوم", callback_data="list_premium_users"),
                InlineKeyboardButton("📊 آمار کاربران", callback_data="user_statistics")
            ],
            [
                InlineKeyboardButton("📜 تاریخچه", callback_data="premium_history"),
                InlineKeyboardButton("💾 پشتیبان‌گیری", callback_data="backup_users")
            ],
            [
                InlineKeyboardButton("🔙 بازگشت", callback_data="main_menu")
            ]
        ]
        return InlineKeyboardMarkup(keyboard)
    
    def backtest_keyboard(self):
        """منوی بک‌تست"""
        keyboard = [
            [
                InlineKeyboardButton("▶️ شروع بک‌تست", callback_data="start_backtest"),
                InlineKeyboardButton("⏹️ توقف بک‌تست", callback_data="stop_backtest")
            ],
            [
                InlineKeyboardButton("📊 نتایج آخرین", callback_data="last_backtest_results"),
                InlineKeyboardButton("📈 تاریخچه", callback_data="backtest_history")
            ],
            [
                InlineKeyboardButton("⚙️ تنظیم پارامترها", callback_data="backtest_settings"),
                InlineKeyboardButton("📁 دانلود گزارش", callback_data="download_backtest_report")
            ],
            [
                InlineKeyboardButton("🔙 بازگشت", callback_data="main_menu")
            ]
        ]
        return InlineKeyboardMarkup(keyboard)

# Instance global
admin_menu = AdminMenu()

# Handler Functions
def start_admin(update: Update, context: CallbackContext):
    """شروع منوی ادمین"""
    user_id = update.effective_user.id
    user_name = update.effective_user.first_name
    
    logger.info(f"Admin command received from user {user_id} ({user_name})")
    
    if not admin_menu.is_admin(user_id):
        update.message.reply_text(f"⛔ شما دسترسی ادمین ندارید!\n\nID شما: `{user_id}`", parse_mode='Markdown')
        logger.warning(f"Unauthorized admin access attempt by {user_id}")
        return
    
    try:
        # دریافت آمار real-time
        api_status = get_brsapi_status()
        current_price = get_brsapi_gold_price()
        signal_stats = get_signal_stats()
        risk_stats = get_risk_status()
        
        welcome_text = f"""
🎛️ **پنل مدیریت FlowAI Trading Bot**

سلام {user_name} عزیز! 👋
به پنل مدیریت ربات خوش آمدید.

📊 **وضعیت فعلی:**
💰 قیمت طلا: ${current_price:.2f}
📡 API calls: {api_status['daily_calls']}/{api_status['daily_limit']}
🔋 مصرف روزانه: {api_status['daily_usage_percent']:.1f}%
🚨 کل سیگنال‌ها: {signal_stats['total_signals']}
⚡ نظارت: {'فعال' if signal_manager.running else 'غیرفعال'}
💼 PnL روزانه: ${risk_stats['daily_pnl']:.2f}

از منوی زیر گزینه مورد نظر را انتخاب کنید:
"""
        
        update.message.reply_text(
            welcome_text,
            reply_markup=admin_menu.main_menu_keyboard(),
            parse_mode='Markdown'
        )
        
    except Exception as e:
        logger.error(f"Error in start_admin: {e}")
        update.message.reply_text(
            f"🎛️ **پنل مدیریت FlowAI**\n\nسلام {user_name}!\nخوش آمدید به پنل مدیریت.",
            reply_markup=admin_menu.main_menu_keyboard(),
            parse_mode='Markdown'
        )

def handle_admin_menu(update: Update, context: CallbackContext):
    """مدیریت پیام‌های منوی ادمین"""
    user_id = update.effective_user.id
    
    if not admin_menu.is_admin(user_id):
        return
    
    text = update.message.text
    logger.info(f"Admin menu action: {text} by user {user_id}")
    
    if text == "🤖 مدیریت ربات":
        update.message.reply_text(
            "🤖 **مدیریت ربات FlowAI**\n\nگزینه مورد نظر را انتخاب کنید:",
            reply_markup=admin_menu.bot_management_keyboard(),
            parse_mode='Markdown'
        )
    
    elif text == "🚨 مدیریت سیگنال‌ها":
        try:
            stats = get_signal_stats()
            market_status = get_market_status()
            
            signal_text = f"""
🚨 **مدیریت سیگنال‌های AI**

📊 **آمار سیگنال‌ها:**
🔹 کل سیگنال‌ها: {stats['total_signals']}
🔹 سیگنال‌های خرید: {stats['buy_signals']}
🔹 سیگنال‌های فروش: {stats['sell_signals']}
🔹 میانگین اعتماد: {stats['avg_confidence']:.1%}

👥 **مشترکین:**
🔹 ادمین: {stats['subscribers_count']['admin']}
🔹 پریمیوم: {stats['subscribers_count']['premium']}
🔹 رایگان: {stats['subscribers_count']['free']}

🏪 **وضعیت بازار:**
🔹 فعالیت: {'فعال' if market_status['market_active'] else 'بسته'}
🔹 کولداون: {market_status['cooldown_remaining']:.0f}s

⚡ **نظارت خودکار:** {'فعال' if signal_manager.running else 'غیرفعال'}
"""
            
            update.message.reply_text(
                signal_text,
                reply_markup=admin_menu.signal_management_keyboard(),
                parse_mode='Markdown'
            )
        except Exception as e:
            update.message.reply_text(f"❌ خطا در دریافت اطلاعات سیگنال: {str(e)}")
    
    elif text == "👥 مدیریت کاربران":
        try:
            premium_stats = get_premium_stats()
            
            user_text = f"""
👥 **مدیریت کاربران**

📊 **آمار کاربران پریمیوم:**
🔹 کل کاربران پریمیوم: {premium_stats['total_premium_users']}
🔹 اضافه شده این ماه: {premium_stats['recent_additions']}
🔹 حذف شده این ماه: {premium_stats['recent_removals']}
🔹 کل تاریخچه: {premium_stats['total_history_entries']}

👥 **مشترکین سیگنال:**
🔹 ادمین: {len(signal_manager.subscribers['admin'])}
🔹 پریمیوم: {len(signal_manager.subscribers['premium'])}
🔹 رایگان: {len(signal_manager.subscribers['free'])}
"""
            
            update.message.reply_text(
                user_text,
                reply_markup=admin_menu.user_management_keyboard(),
                parse_mode='Markdown'
            )
        except Exception as e:
            update.message.reply_text(f"❌ خطا در دریافت آمار کاربران: {str(e)}")
    
    elif text == "🧪 بک‌تست":
        update.message.reply_text(
            "🧪 **مدیریت بک‌تست**\n\nگزینه مورد نظر را انتخاب کنید:",
            reply_markup=admin_menu.backtest_keyboard(),
            parse_mode='Markdown'
        )
    
    elif text == "📋 گزارش‌گیری":
        try:
            # تولید گزارش روزانه
            daily_report = export_daily_report_text()
            
            # ارسال گزارش
            update.message.reply_text(daily_report, parse_mode='Markdown')
            
            # منوی گزارش‌گیری
            keyboard = [
                [
                    InlineKeyboardButton("📊 گزارش روزانه", callback_data="daily_report"),
                    InlineKeyboardButton("📈 گزارش هفتگی", callback_data="weekly_report")
                ],
                [
                    InlineKeyboardButton("📁 دانلود گزارش", callback_data="download_report"),
                    InlineKeyboardButton("📧 ارسال ایمیل", callback_data="email_report")
                ]
            ]
            
            update.message.reply_text(
                "📋 **گزارش‌گیری سیستم**\n\nگزینه مورد نظر را انتخاب کنید:",
                reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode='Markdown'
            )
            
        except Exception as e:
            update.message.reply_text(f"❌ خطا در تولید گزارش: {str(e)}")
    
    elif text == "🔔 اطلاع‌رسانی":
        try:
            notification_stats = get_notification_stats()
            
            notification_text = f"""
🔔 **سیستم اطلاع‌رسانی**

📊 **آمار کلی:**
🔹 کل اطلاع‌رسانی‌ها: {notification_stats.get('total_notifications', 0)}
🔹 موفق: {notification_stats.get('total_sent', 0)}
🔹 ناموفق: {notification_stats.get('total_failed', 0)}
🔹 نرخ موفقیت: {notification_stats.get('success_rate', 0):.1%}

📱 **کانال‌های فعال:**
🔹 تلگرام: فعال
🔹 ایمیل: {'فعال' if notification_stats.get('channel_breakdown', {}).get('email') else 'غیرفعال'}
🔹 Webhook: {'فعال' if notification_stats.get('channel_breakdown', {}).get('webhook') else 'غیرفعال'}
"""
            
            keyboard = [
                [
                    InlineKeyboardButton("📱 تست تلگرام", callback_data="test_telegram"),
                    InlineKeyboardButton("📧 تست ایمیل", callback_data="test_email")
                ],
                [
                    InlineKeyboardButton("🚨 ارسال هشدار", callback_data="send_alert"),
                    InlineKeyboardButton("📊 آمار کامل", callback_data="notification_stats")
                ]
            ]
            
            update.message.reply_text(
                notification_text,
                reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode='Markdown'
            )
            
        except Exception as e:
            update.message.reply_text(f"❌ خطا در سیستم اطلاع‌رسانی: {str(e)}")
    
    elif text == "📊 آمار و گزارش":
        try:
            api_status = get_brsapi_status()
            current_price = get_brsapi_gold_price()
            signal_stats = get_signal_stats()
            risk_stats = get_risk_status()
            premium_stats = get_premium_stats()
            
            stats_text = f"""
📊 **آمار و گزارش کامل سیستم**

💰 **قیمت فعلی طلا:** ${current_price:.2f}

📡 **وضعیت API BrsAPI:**
🔹 درخواست‌های امروز: {api_status['daily_calls']}/{api_status['daily_limit']}
🔹 درخواست‌های این دقیقه: {api_status['minute_calls']}/{api_status['minute_limit']}
🔹 مصرف روزانه: {api_status['daily_usage_percent']:.1f}%
🔹 مصرف دقیقه‌ای: {api_status['minute_usage_percent']:.1f}%

🚨 **آمار سیگنال‌ها:**
🔹 کل سیگنال‌ها: {signal_stats['total_signals']}
🔹 سیگنال‌های خرید: {signal_stats['buy_signals']}
🔹 سیگنال‌های فروش: {signal_stats['sell_signals']}
🔹 میانگین اعتماد: {signal_stats['avg_confidence']:.1%}

⚠️ **مدیریت ریسک:**
🔹 PnL روزانه: ${risk_stats['daily_pnl']:.2f}
🔹 معاملات امروز: {risk_stats['daily_trades']}/{risk_stats['max_daily_trades']}
🔹 نرخ برد اخیر: {risk_stats['recent_win_rate']:.1f}%

👥 **کاربران:**
🔹 کاربران پریمیوم: {premium_stats['total_premium_users']}
🔹 مشترکین رایگان: {len(signal_manager.subscribers['free'])}

🤖 **وضعیت سیستم:**
🔹 نظارت سیگنال: {'فعال' if signal_manager.running else 'غیرفعال'}
🔹 آخرین آپدیت: اکنون
"""
            
            update.message.reply_text(stats_text, parse_mode='Markdown')
            
        except Exception as e:
            logger.error(f"Error getting comprehensive stats: {e}")
            update.message.reply_text(f"❌ خطا در دریافت آمار: {str(e)}")
    
    elif text == "🔍 تحلیل فوری":
        update.message.reply_text("🔄 **در حال انجام تحلیل فوری...**\n\nلطفاً صبر کنید...")
        
        try:
            signal = get_ai_trading_signal(force_analysis=True)
            
            if signal:
                action_emoji = {'BUY': '🟢', 'SELL': '🔴', 'HOLD': '🟡'}
                confidence_stars = '⭐' * int(signal['confidence'] * 5)
                
                analysis_text = f"""
🔍 **تحلیل فوری FlowAI**

{action_emoji.get(signal['action'], '🟡')} **سیگنال:** {signal['action']}
⭐ **اعتماد:** {signal['confidence']:.1%} {confidence_stars}

💰 **قیمت‌ها:**
🔹 قیمت فعلی: ${signal['current_price']:.2f}
🔹 قیمت ورود: ${signal['entry_price']:.2f}
🎯 هدف: ${signal['target_price']:.2f}
🛑 حد ضرر: ${signal['stop_loss']:.2f}

📊 **تحلیل تکنیکال:**
🔹 RSI: {signal['indicators']['rsi']:.1f}
🔹 MACD: {signal['indicators']['macd']:.3f}
🔹 SMA20: ${signal['indicators']['sma_20']:.2f}
🔹 امتیاز صعودی: {signal['bullish_score']}
🔹 امتیاز نزولی: {signal['bearish_score']}

⏰ **زمان:** {signal['timestamp'].strftime('%Y-%m-%d %H:%M:%S')}
{'🔄 **تحلیل اجباری**' if signal.get('forced') else ''}
"""
                
                update.message.reply_text(analysis_text, parse_mode='Markdown')
            else:
                update.message.reply_text(
                    "⚠️ **تحلیل انجام شد**\n\n"
                    "در حال حاضر شرایط مناسبی برای سیگنال وجود ندارد.\n"
                    "بازار ممکن است در حالت خنثی باشد."
                )
        except Exception as e:
            update.message.reply_text(f"❌ خطا در تحلیل فوری: {str(e)}")

def handle_admin_callbacks(update: Update, context: CallbackContext):
    """مدیریت callback های ادمین"""
    query = update.callback_query
    query.answer()
    
    user_id = query.from_user.id
    if not admin_menu.is_admin(user_id):
        query.edit_message_text("⛔ شما دسترسی ادمین ندارید!")
        return
    
    data = query.data
    logger.info(f"Admin callback: {data} by user {user_id}")
    
    if data == "start_monitoring":
        start_signal_monitoring()
        query.edit_message_text("✅ **نظارت خودکار سیگنال‌ها شروع شد**\n\nسیستم هر 5 دقیقه بازار را بررسی می‌کند.", parse_mode='Markdown')
    
    elif data == "stop_monitoring":
        stop_signal_monitoring()
        query.edit_message_text("⏹️ **نظارت خودکار سیگنال‌ها متوقف شد**", parse_mode='Markdown')
    
    elif data == "force_analysis":
        try:
            signal = get_ai_trading_signal(force_analysis=True)
            if signal:
                asyncio.run(signal_manager.send_manual_signal(user_id, force=True))
                query.edit_message_text("✅ **تحلیل فوری انجام شد و سیگنال ارسال شد**", parse_mode='Markdown')
            else:
                query.edit_message_text("⚠️ **تحلیل انجام شد اما سیگنالی تولید نشد**", parse_mode='Markdown')
        except Exception as e:
            query.edit_message_text(f"❌ خطا در تحلیل فوری: {str(e)}")
    
    elif data == "start_backtest":
        query.edit_message_text("🔄 **شروع بک‌تست...**\n\nلطفاً صبر کنید، این فرآیند ممکن است چند دقیقه طول بکشد.")
        
        try:
            # اجرای بک‌تست با پارامترهای پیش‌فرض
            results = run_backtest_analysis(
                symbol="GOLD",
                start_date="2024-01-01",
                end_date="2024-12-31",
                initial_balance=10000,
                timeframe="1h",
                risk_per_trade=0.02
            )
            
            if results:
                summary = get_backtest_summary()
                query.edit_message_text(summary, parse_mode='Markdown')
            else:
                query.edit_message_text("❌ **خطا در اجرای بک‌تست**")
                
        except Exception as e:
            query.edit_message_text(f"❌ خطا در بک‌تست: {str(e)}")
    
    elif data == "add_premium_user":
        query.edit_message_text(
            "➕ **اضافه کردن کاربر پریمیوم**\n\n"
            "لطفاً ID کاربر را ارسال کنید:\n"
            "مثال: 123456789",
            parse_mode='Markdown'
        )
        admin_menu.pending_actions[user_id] = "add_premium"
    
    elif data == "remove_premium_user":
        query.edit_message_text(
            "➖ **حذف کاربر پریمیوم**\n\n"
            "لطفاً ID کاربر را ارسال کنید:\n"
            "مثال: 123456789",
            parse_mode='Markdown'
        )
        admin_menu.pending_actions[user_id] = "remove_premium"
    
    elif data == "list_premium_users":
        try:
            premium_list = premium_manager.format_premium_list()
            query.edit_message_text(premium_list, parse_mode='Markdown')
        except Exception as e:
            query.edit_message_text(f"❌ خطا در دریافت لیست: {str(e)}")
    
    elif data == "daily_report":
        try:
            daily_report = export_daily_report_text()
            query.edit_message_text(daily_report, parse_mode='Markdown')
        except Exception as e:
            query.edit_message_text(f"❌ خطا در تولید گزارش روزانه: {str(e)}")
    
    elif data == "weekly_report":
        try:
            weekly_report = export_weekly_report_text()
            query.edit_message_text(weekly_report, parse_mode='Markdown')
        except Exception as e:
            query.edit_message_text(f"❌ خطا در تولید گزارش هفتگی: {str(e)}")
    
    elif data == "send_alert":
        query.edit_message_text(
            "🚨 **ارسال هشدار سیستم**\n\n"
            "لطفاً متن هشدار را ارسال کنید:",
            parse_mode='Markdown'
        )
        admin_menu.pending_actions[user_id] = "send_alert"

def handle_pending_actions(update: Update, context: CallbackContext):
    """مدیریت اقدامات در انتظار"""
    user_id = update.effective_user.id
    
    if not admin_menu.is_admin(user_id):
        return
    
    if user_id not in admin_menu.pending_actions:
        return
    
    action = admin_menu.pending_actions[user_id]
    text = update.message.text
    
    if action == "add_premium":
        try:
            target_user_id = int(text)
            success = premium_manager.add_premium_user(target_user_id, user_id, 30)
            
            if success:
                update.message.reply_text(f"✅ کاربر {target_user_id} به پریمیوم اضافه شد")
            else:
                update.message.reply_text(f"❌ خطا در اضافه کردن کاربر {target_user_id}")
                
        except ValueError:
            update.message.reply_text("❌ ID کاربر نامعتبر است")
        except Exception as e:
            update.message.reply_text(f"❌ خطا: {str(e)}")
        
        del admin_menu.pending_actions[user_id]
    
    elif action == "remove_premium":
        try:
            target_user_id = int(text)
            success = premium_manager.remove_premium_user(target_user_id, user_id)
            
            if success:
                update.message.reply_text(f"✅ کاربر {target_user_id} از پریمیوم حذف شد")
            else:
                update.message.reply_text(f"❌ خطا در حذف کاربر {target_user_id}")
                
        except ValueError:
            update.message.reply_text("❌ ID کاربر نامعتبر است")
        except Exception as e:
            update.message.reply_text(f"❌ خطا: {str(e)}")
        
        del admin_menu.pending_actions[user_id]
    
    elif action == "send_alert":
        try:
            result = send_system_alert("admin", text, admin_only=False)
            
            if result['sent'] > 0:
                update.message.reply_text(f"✅ هشدار به {result['sent']} کاربر ارسال شد")
            else:
                update.message.reply_text("❌ خطا در ارسال هشدار")
                
        except Exception as e:
            update.message.reply_text(f"❌ خطا: {str(e)}")
        
        del admin_menu.pending_actions[user_id]

# Setup handlers
def setup_admin_handlers(dispatcher):
    """راه‌اندازی handler های ادمین"""
    dispatcher.add_handler(CommandHandler('admin', start_admin))
    dispatcher.add_handler(MessageHandler(
        Filters.text & Filters.regex(r'^(🤖 مدیریت ربات|📊 آمار و گزارش|🚨 مدیریت سیگنال‌ها|👥 مدیریت کاربران|🧪 بک‌تست|📋 گزارش‌گیری|🔔 اطلاع‌رسانی|💰 قیمت فعلی|📡 وضعیت API|🔍 تحلیل فوری|⚠️ مدیریت ریسک|⚙️ تنظیمات سیستم)$'), 
        handle_admin_menu
    ))
    dispatcher.add_handler(CallbackQueryHandler(handle_admin_callbacks))
    dispatcher.add_handler(MessageHandler(
        Filters.text & ~Filters.regex(r'^[🎯🤖📊🚨👥🧪📋🔔💰📡🔍⚠️⚙️]'),
        handle_pending_actions
    ))
