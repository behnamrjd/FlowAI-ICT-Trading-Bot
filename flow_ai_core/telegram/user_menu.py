from telegram import Update, ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import CallbackContext, CommandHandler, MessageHandler, Filters, CallbackQueryHandler
import logging
import asyncio
from ..data_sources.brsapi_fetcher import get_brsapi_gold_price
from ..config import TELEGRAM_PREMIUM_USERS
from ..telegram.signal_manager import send_manual_analysis, signal_manager
from ..ai_signal_engine import get_ai_trading_signal

logger = logging.getLogger(__name__)

class UserMenu:
    def __init__(self):
        self.premium_users = set(TELEGRAM_PREMIUM_USERS)
        logger.info(f"User menu initialized with premium users: {self.premium_users}")
    
    def is_premium(self, user_id: int) -> bool:
        """بررسی پریمیوم بودن کاربر"""
        return user_id in self.premium_users
    
    def add_premium_user(self, user_id: int):
        """اضافه کردن کاربر پریمیوم"""
        self.premium_users.add(user_id)
        signal_manager.add_subscriber(user_id, 'premium')
        logger.info(f"User {user_id} added to premium")
    
    def remove_premium_user(self, user_id: int):
        """حذف کاربر پریمیوم"""
        self.premium_users.discard(user_id)
        signal_manager.remove_subscriber(user_id, 'premium')
        signal_manager.add_subscriber(user_id, 'free')
        logger.info(f"User {user_id} removed from premium")
    
    def main_menu_keyboard(self, is_premium: bool = False):
        """منوی اصلی کاربر"""
        keyboard = [
            [
                KeyboardButton("💰 قیمت فعلی طلا"),
                KeyboardButton("🔍 تحلیل فوری")
            ],
            [
                KeyboardButton("📊 تحلیل بازار"),
                KeyboardButton("🔔 سیگنال‌های معاملاتی")
            ],
            [
                KeyboardButton("📈 نمودار قیمت"),
                KeyboardButton("📋 تاریخچه سیگنال‌ها")
            ]
        ]
        
        if is_premium:
            keyboard.extend([
                [
                    KeyboardButton("🧪 بک‌تست شخصی"),
                    KeyboardButton("⚙️ تنظیمات پیشرفته")
                ],
                [
                    KeyboardButton("📱 اطلاع‌رسانی VIP"),
                    KeyboardButton("🎯 سیگنال‌های اختصاصی")
                ],
                [
                    KeyboardButton("📊 گزارش عملکرد"),
                    KeyboardButton("🔍 تحلیل پیشرفته")
                ]
            ])
        else:
            keyboard.extend([
                [
                    KeyboardButton("💎 ارتقا به پریمیوم"),
                    KeyboardButton("ℹ️ راهنما")
                ],
                [
                    KeyboardButton("🎁 امتیازات رایگان"),
                    KeyboardButton("📋 محدودیت‌ها")
                ]
            ])
        
        keyboard.append([
            KeyboardButton("👤 پروفایل من"),
            KeyboardButton("📞 پشتیبانی")
        ])
        
        return ReplyKeyboardMarkup(keyboard, resize_keyboard=True, one_time_keyboard=False)

# Instance global
user_menu = UserMenu()

def start_user(update: Update, context: CallbackContext):
    """شروع ربات برای کاربر عادی"""
    user = update.effective_user
    user_id = user.id
    is_premium = user_menu.is_premium(user_id)
    
    # اضافه کردن کاربر به سیستم سیگنال
    if is_premium:
        signal_manager.add_subscriber(user_id, 'premium')
    else:
        signal_manager.add_subscriber(user_id, 'free')
    
    logger.info(f"User {user_id} ({user.first_name}) started bot. Premium: {is_premium}")
    
    try:
        # دریافت قیمت فعلی
        current_price = get_brsapi_gold_price()
        
        welcome_text = f"""
🎯 **FlowAI Trading Bot**

سلام {user.first_name} عزیز! 👋
به ربات هوش مصنوعی معاملات طلا خوش آمدید.

{'💎 شما کاربر **پریمیوم** هستید!' if is_premium else '🆓 شما کاربر **رایگان** هستید.'}

💰 **قیمت فعلی طلا:** ${current_price:.2f}

🔹 دریافت قیمت لحظه‌ای طلا
🔹 تحلیل‌های هوش مصنوعی
🔹 سیگنال‌های معاملاتی
{'🔹 بک‌تست شخصی' if is_premium else '🔹 امکان ارتقا به پریمیوم'}
{'🔹 اطلاع‌رسانی VIP' if is_premium else '🔹 محدودیت‌های رایگان'}

از منوی زیر گزینه مورد نظر را انتخاب کنید:
"""
        
    except Exception as e:
        logger.error(f"Error getting price in start_user: {e}")
        welcome_text = f"""
🎯 **FlowAI Trading Bot**

سلام {user.first_name} عزیز! 👋
به ربات هوش مصنوعی معاملات طلا خوش آمدید.

{'💎 شما کاربر **پریمیوم** هستید!' if is_premium else '🆓 شما کاربر **رایگان** هستید.'}

از منوی زیر گزینه مورد نظر را انتخاب کنید:
"""
    
    update.message.reply_text(
        welcome_text,
        reply_markup=user_menu.main_menu_keyboard(is_premium),
        parse_mode='Markdown'
    )

async def handle_manual_analysis(update: Update, context: CallbackContext):
    """مدیریت تحلیل فوری"""
    user_id = update.effective_user.id
    
    # ارسال پیام انتظار
    waiting_message = update.message.reply_text("🔄 **در حال انجام تحلیل...**\n\nلطفاً صبر کنید...")
    
    try:
        # ارسال تحلیل فوری
        success = await send_manual_analysis(user_id)
        
        if success:
            # حذف پیام انتظار
            try:
                await context.bot.delete_message(
                    chat_id=update.effective_chat.id,
                    message_id=waiting_message.message_id
                )
            except:
                pass
        else:
            # به‌روزرسانی پیام انتظار
            try:
                await context.bot.edit_message_text(
                    chat_id=update.effective_chat.id,
                    message_id=waiting_message.message_id,
                    text="⚠️ **تحلیل انجام شد**\n\n"
                         "در حال حاضر شرایط مناسبی برای سیگنال وجود ندارد.\n"
                         "لطفاً دوباره تلاش کنید.",
                    parse_mode='Markdown'
                )
            except:
                pass
                
    except Exception as e:
        logger.error(f"Error in manual analysis for user {user_id}: {e}")
        try:
            await context.bot.edit_message_text(
                chat_id=update.effective_chat.id,
                message_id=waiting_message.message_id,
                text="❌ **خطا در تحلیل**\n\nلطفاً دوباره تلاش کنید.",
                parse_mode='Markdown'
            )
        except:
            pass

def handle_user_menu(update: Update, context: CallbackContext):
    """مدیریت پیام‌های منوی کاربر"""
    text = update.message.text
    user_id = update.effective_user.id
    user_name = update.effective_user.first_name
    is_premium = user_menu.is_premium(user_id)
    
    logger.info(f"User menu action: {text} by user {user_id} (Premium: {is_premium})")
    
    if text == "🔍 تحلیل فوری":
        # استفاده از asyncio برای اجرای تابع async
        asyncio.run(handle_manual_analysis(update, context))
        return
    
    elif text == "💰 قیمت فعلی طلا":
        try:
            price = get_brsapi_gold_price()
            price_text = f"""
💰 **قیمت فعلی طلا**

🏆 **قیمت:** ${price:.2f}
📊 **منبع:** BrsAPI Pro
⏰ **آخرین به‌روزرسانی:** اکنون

📈 **تحلیل سریع:**
{'🔹 تحلیل پیشرفته در دسترس است' if is_premium else '🔹 برای تحلیل پیشرفته، پریمیوم شوید'}
{'🔹 اطلاع‌رسانی خودکار فعال' if is_premium else '🔹 اطلاع‌رسانی محدود'}

💡 **نکته:** قیمت هر 10 ثانیه به‌روزرسانی می‌شود.
"""
            update.message.reply_text(price_text, parse_mode='Markdown')
        except Exception as e:
            logger.error(f"Error getting price: {e}")
            update.message.reply_text(f"❌ خطا در دریافت قیمت: لطفاً دوباره تلاش کنید.")
    
    elif text == "📊 تحلیل بازار":
        if is_premium:
            # تحلیل واقعی برای کاربران پریمیوم
            try:
                price = get_brsapi_gold_price()
                signal = get_ai_trading_signal(force_analysis=True)
                
                if signal:
                    analysis_text = f"""
📊 **تحلیل بازار طلا - ویژه پریمیوم**

💰 **قیمت فعلی:** ${price:.2f}

🔍 **تحلیل تکنیکال:**
🔹 RSI: {signal['indicators']['rsi']:.1f}
🔹 MACD: {signal['indicators']['macd']:.3f}
🔹 SMA 20: ${signal['indicators']['sma_20']:.2f}
🔹 SMA 50: ${signal['indicators']['sma_50']:.2f}
🔹 Bollinger Upper: ${signal['indicators']['bb_upper']:.2f}
🔹 Bollinger Lower: ${signal['indicators']['bb_lower']:.2f}

📈 **سیگنال AI:**
🔹 عمل پیشنهادی: {signal['action']}
🔹 اعتماد: {signal['confidence']:.1%}
🔹 امتیاز صعودی: {signal['bullish_score']}
🔹 امتیاز نزولی: {signal['bearish_score']}

🎯 **اهداف قیمتی:**
🔹 هدف: ${signal['target_price']:.2f}
🔹 حد ضرر: ${signal['stop_loss']:.2f}

⚠️ **هشدار:** این تحلیل صرفاً جنبه آموزشی دارد.
"""
                else:
                    analysis_text = """
📊 **تحلیل بازار طلا - ویژه پریمیوم**

🔍 تحلیل انجام شد اما در حال حاضر سیگنال مشخصی وجود ندارد.
لطفاً دوباره تلاش کنید.
"""
                
                update.message.reply_text(analysis_text, parse_mode='Markdown')
            except Exception as e:
                logger.error(f"Error in premium analysis: {e}")
                update.message.reply_text("🔄 در حال تحلیل بازار... لطفاً صبر کنید.")
        else:
            update.message.reply_text(
                "💎 **تحلیل بازار - ویژه پریمیوم**\n\n"
                "این ویژگی فقط برای کاربران پریمیوم در دسترس است.\n\n"
                "🎯 **مزایای پریمیوم:**\n"
                "🔹 تحلیل‌های پیشرفته هوش مصنوعی\n"
                "🔹 سیگنال‌های اختصاصی\n"
                "🔹 بک‌تست شخصی\n"
                "🔹 اطلاع‌رسانی VIP\n\n"
                "برای ارتقا به پریمیوم، گزینه 'ارتقا به پریمیوم' را انتخاب کنید.",
                parse_mode='Markdown'
            )
    
    elif text == "💎 ارتقا به پریمیوم":
        premium_text = f"""
💎 **ارتقا به پریمیوم**

🎯 **مزایای ویژه پریمیوم:**
🔹 تحلیل‌های پیشرفته هوش مصنوعی
🔹 سیگنال‌های اختصاصی و دقیق
🔹 بک‌تست شخصی با پارامترهای دلخواه
🔹 اطلاع‌رسانی VIP و فوری
🔹 پشتیبانی اولویت‌دار 24/7
🔹 گزارش‌های تفصیلی عملکرد
🔹 دسترسی به ابزارهای پیشرفته
🔹 تحلیل فوری نامحدود

💰 **قیمت:** 50,000 تومان/ماه
🎁 **تخفیف ویژه:** 30% برای 3 ماه اول

📞 **برای خرید:**
🔹 با پشتیبانی تماس بگیرید
🔹 یا از گزینه 'پشتیبانی' استفاده کنید

👤 **ID شما:** `{user_id}`
"""
        update.message.reply_text(premium_text, parse_mode='Markdown')
    
    elif text == "🔔 سیگنال‌های معاملاتی":
        if is_premium:
            # دریافت آخرین سیگنال‌ها برای کاربران پریمیوم
            try:
                stats = signal_manager.get_signal_statistics()
                last_signal = None
                
                if signal_manager.signal_history:
                    last_signal = signal_manager.signal_history[-1]['signal']
                
                if last_signal:
                    action_emoji = {'BUY': '🟢', 'SELL': '🔴', 'HOLD': '🟡'}
                    signals_text = f"""
🔔 **سیگنال‌های معاملاتی VIP**

📊 **آخرین سیگنال:**
{action_emoji.get(last_signal['action'], '🟡')} **{last_signal['action']}**
💰 قیمت ورود: ${last_signal['entry_price']:.2f}
🎯 هدف: ${last_signal['target_price']:.2f}
🛑 حد ضرر: ${last_signal['stop_loss']:.2f}
⭐ اعتماد: {last_signal['confidence']:.1%}
⏰ زمان: {last_signal['timestamp'].strftime('%H:%M')}

📈 **عملکرد امروز:**
🔹 تعداد سیگنال‌ها: {stats['total_signals']}
🔹 سیگنال‌های خرید: {stats['buy_signals']}
🔹 سیگنال‌های فروش: {stats['sell_signals']}
🔹 میانگین اعتماد: {stats['avg_confidence']:.1%}

🔔 **اطلاع‌رسانی:** فعال
"""
                else:
                    signals_text = """
🔔 **سیگنال‌های معاملاتی VIP**

📊 **وضعیت:**
هنوز سیگنالی تولید نشده است.
سیستم به‌طور خودکار بازار را نظارت می‌کند.

🔔 **اطلاع‌رسانی:** فعال
💡 **نکته:** از گزینه 'تحلیل فوری' برای دریافت سیگنال استفاده کنید.
"""
        else:
            signals_text = """
🔔 **سیگنال‌های معاملاتی**

📊 **نمونه سیگنال رایگان:**
🟡 **مشاهده طلا**
💰 قیمت فعلی: دریافت شود
📈 روند کلی: خنثی

💎 **برای دریافت سیگنال‌های دقیق:**
🔹 ارتقا به پریمیوم
🔹 دسترسی به 5-10 سیگنال روزانه
🔹 دقت بالای 70%
🔹 اطلاع‌رسانی فوری
🔹 تحلیل‌های کامل
"""
        
        update.message.reply_text(signals_text, parse_mode='Markdown')
    
    elif text == "👤 پروفایل من":
        profile_text = f"""
👤 **پروفایل کاربری**

🆔 **ID:** `{user_id}`
👤 **نام:** {user_name}
{'💎 **وضعیت:** پریمیوم' if is_premium else '🆓 **وضعیت:** رایگان'}
📅 **عضویت:** امروز
🔔 **اطلاع‌رسانی:** {'فعال' if is_premium else 'محدود'}

📊 **آمار شما:**
🔹 تعداد بازدید: 1
🔹 سیگنال‌های دریافتی: {len(signal_manager.signal_history)}
{'🔹 تحلیل‌های انجام شده: نامحدود' if is_premium else '🔹 محدودیت‌های رایگان فعال'}

⚙️ **تنظیمات:**
🔹 زبان: فارسی
🔹 منطقه زمانی: تهران
🔹 اطلاع‌رسانی: {'VIP' if is_premium else 'محدود'}
"""
        update.message.reply_text(profile_text, parse_mode='Markdown')
    
    elif text == "📞 پشتیبانی":
        support_text = f"""
📞 **پشتیبانی FlowAI**

🎯 **راه‌های ارتباط:**
📧 ایمیل: support@flowai.ir
📱 تلگرام: @FlowAI_Support
📞 تلفن: 021-12345678

⏰ **ساعات کاری:**
🔹 شنبه تا چهارشنبه: 9-18
🔹 پنج‌شنبه: 9-14
{'🔹 پشتیبانی 24/7 برای کاربران پریمیوم' if is_premium else '🔹 پاسخ‌گویی در ساعات اداری'}

📝 **درخواست پشتیبانی:**
لطفاً ID خود را ارسال کنید: `{user_id}`

💡 **سوالات متداول:**
🔹 نحوه ارتقا به پریمیوم
🔹 تفسیر سیگنال‌ها
🔹 مشکلات فنی
🔹 نحوه استفاده از تحلیل فوری
"""
        update.message.reply_text(support_text, parse_mode='Markdown')

# Setup handlers
def setup_user_handlers(dispatcher):
    """راه‌اندازی handler های کاربر"""
    dispatcher.add_handler(CommandHandler('start', start_user))
    dispatcher.add_handler(MessageHandler(
        Filters.text & Filters.regex(r'^(💰 قیمت فعلی طلا|📊 تحلیل بازار|💎 ارتقا به پریمیوم|🔔 سیگنال‌های معاملاتی|👤 پروفایل من|📞 پشتیبانی|🔍 تحلیل فوری)$'), 
        handle_user_menu
    ))
