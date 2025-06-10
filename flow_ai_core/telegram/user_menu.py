from telegram import Update, ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import CallbackContext, CommandHandler, MessageHandler, Filters, CallbackQueryHandler
import logging
import asyncio
from ..data_sources.brsapi_fetcher import get_brsapi_gold_price
from ..config import TELEGRAM_PREMIUM_USERS, ICT_ENABLED, AI_MODEL_ENABLED
from ..data_handler import get_ict_analysis, get_processed_data
from ..telegram.signal_manager import send_manual_analysis, signal_manager
from ..ai_signal_engine import get_ai_trading_signal
from ..telegram.premium_manager import premium_manager

logger = logging.getLogger(__name__)

class ICTUserMenu:
    def __init__(self):
        self.premium_users = set(TELEGRAM_PREMIUM_USERS)
        logger.info(f"ICT User menu initialized with premium users: {self.premium_users}")
    
    def is_premium(self, user_id: int) -> bool:
        """بررسی پریمیوم بودن کاربر"""
        return premium_manager.is_premium(user_id)
    
    def main_menu_keyboard(self, is_premium: bool = False):
        """منوی اصلی کاربر ICT-Enhanced"""
        keyboard = [
            [
                KeyboardButton("💰 Live Gold Price"),
                KeyboardButton("🎯 ICT Analysis")
            ],
            [
                KeyboardButton("🔍 Quick Analysis"),
                KeyboardButton("🚨 Trading Signals")
            ]
        ]
        
        if is_premium:
            keyboard.extend([
                [
                    KeyboardButton("📈 HTF Analysis"),
                    KeyboardButton("🎯 ICT Patterns")
                ],
                [
                    KeyboardButton("🧪 Personal Backtest"),
                    KeyboardButton("⚙️ Advanced Settings")
                ],
                [
                    KeyboardButton("📱 VIP Alerts"),
                    KeyboardButton("🎯 Exclusive Signals")
                ],
                [
                    KeyboardButton("📊 Performance Report"),
                    KeyboardButton("🔍 Deep Analysis")
                ]
            ])
        else:
            keyboard.extend([
                [
                    KeyboardButton("💎 Upgrade to Premium"),
                    KeyboardButton("ℹ️ ICT Guide")
                ],
                [
                    KeyboardButton("🎁 Free Features"),
                    KeyboardButton("📋 Limitations")
                ]
            ])
        
        keyboard.append([
            KeyboardButton("👤 My Profile"),
            KeyboardButton("📞 Support")
        ])
        
        return ReplyKeyboardMarkup(keyboard, resize_keyboard=True, one_time_keyboard=False)

# Instance global
user_menu = ICTUserMenu()

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
    
    logger.info(f"ICT User {user_id} ({user.first_name}) started bot. Premium: {is_premium}")
    
    try:
        # دریافت قیمت فعلی
        current_price = get_brsapi_gold_price()
        
        # دریافت تحلیل ICT
        ict_analysis = get_ict_analysis()
        
        welcome_text = f"""
🎯 **FlowAI-ICT Trading Bot**

سلام {user.first_name} عزیز! 👋
به ربات هوش مصنوعی ICT خوش آمدید.

{'💎 شما کاربر **پریمیوم** هستید!' if is_premium else '🆓 شما کاربر **رایگان** هستید.'}

💰 **Live Market Data:**
🔹 Gold Price: ${current_price:.2f}
🔹 ICT Signal: {ict_analysis.get('signal', 'HOLD')}
🔹 Confidence: {ict_analysis.get('confidence', 0):.1%}

🎯 **ICT Features Available:**
🔹 Order Block Detection: {'✅' if ICT_ENABLED else '❌'}
🔹 Fair Value Gap Analysis: {'✅' if ICT_ENABLED else '❌'}
🔹 Liquidity Sweep Detection: {'✅' if ICT_ENABLED else '❌'}
🔹 Market Structure Analysis: {'✅' if ICT_ENABLED else '❌'}
{'🔹 AI Model Integration: ✅' if AI_MODEL_ENABLED else ''}

🚀 **What You Get:**
{'🔹 Real-time ICT analysis' if is_premium else '🔹 Basic ICT signals'}
{'🔹 HTF multi-timeframe analysis' if is_premium else '🔹 Limited timeframes'}
{'🔹 Personal backtesting' if is_premium else '🔹 Upgrade for backtesting'}
{'🔹 VIP instant alerts' if is_premium else '🔹 Standard notifications'}

از منوی زیر گزینه مورد نظر را انتخاب کنید:
"""
        
    except Exception as e:
        logger.error(f"Error getting data in start_user: {e}")
        welcome_text = f"""
🎯 **FlowAI-ICT Trading Bot**

سلام {user.first_name} عزیز! 👋
به ربات هوش مصنوعی ICT خوش آمدید.

{'💎 شما کاربر **پریمیوم** هستید!' if is_premium else '🆓 شما کاربر **رایگان** هستید.'}

🎯 **ICT Trading Features Ready!**

از منوی زیر گزینه مورد نظر را انتخاب کنید:
"""
    
    update.message.reply_text(
        welcome_text,
        reply_markup=user_menu.main_menu_keyboard(is_premium),
        parse_mode='Markdown'
    )

async def handle_manual_analysis(update: Update, context: CallbackContext):
    """مدیریت تحلیل فوری ICT"""
    user_id = update.effective_user.id
    
    # ارسال پیام انتظار
    waiting_message = update.message.reply_text("🔄 **Performing ICT Analysis...**\n\nPlease wait...")
    
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
                    text="⚠️ **Analysis Complete**\n\n"
                         "No clear ICT patterns detected at the moment.\n"
                         "Market may be in consolidation phase.",
                    parse_mode='Markdown'
                )
            except:
                pass
                
    except Exception as e:
        logger.error(f"Error in ICT manual analysis for user {user_id}: {e}")
        try:
            await context.bot.edit_message_text(
                chat_id=update.effective_chat.id,
                message_id=waiting_message.message_id,
                text="❌ **Analysis Error**\n\nPlease try again later.",
                parse_mode='Markdown'
            )
        except:
            pass

def handle_user_menu(update: Update, context: CallbackContext):
    """مدیریت پیام‌های منوی کاربر ICT"""
    text = update.message.text
    user_id = update.effective_user.id
    user_name = update.effective_user.first_name
    is_premium = user_menu.is_premium(user_id)
    
    logger.info(f"ICT User menu action: {text} by user {user_id} (Premium: {is_premium})")
    
    if text == "🔍 Quick Analysis":
        # استفاده از asyncio برای اجرای تابع async
        asyncio.run(handle_manual_analysis(update, context))
        return
    
    elif text == "💰 Live Gold Price":
        try:
            price = get_brsapi_gold_price()
            ict_analysis = get_ict_analysis()
            
            price_text = f"""
💰 **Live Gold Price - ICT Enhanced**

🏆 **Current Price:** ${price:.2f}
📊 **Source:** BrsAPI Pro
⏰ **Last Update:** Now

🎯 **ICT Quick Analysis:**
🔹 Signal: {ict_analysis.get('signal', 'HOLD')}
🔹 Confidence: {ict_analysis.get('confidence', 0):.1%}
🔹 Market Structure: {ict_analysis.get('ict_patterns', {}).get('market_structure', 'NEUTRAL')}

📈 **Pattern Detection:**
🔹 Order Blocks: {'✅' if ict_analysis.get('ict_patterns', {}).get('order_blocks') else '❌'}
🔹 Fair Value Gaps: {'✅' if ict_analysis.get('ict_patterns', {}).get('fair_value_gaps') else '❌'}
🔹 Liquidity Sweeps: {'✅' if ict_analysis.get('ict_patterns', {}).get('liquidity_sweeps') else '❌'}

{'🎯 **Premium Features Available**' if is_premium else '💎 **Upgrade for Advanced Analysis**'}

💡 **Note:** Price updates every 10 seconds with ICT analysis.
"""
            update.message.reply_text(price_text, parse_mode='Markdown')
        except Exception as e:
            logger.error(f"Error getting price: {e}")
            update.message.reply_text(f"❌ Error getting price data. Please try again.")
    
    elif text == "🎯 ICT Analysis":
        if is_premium:
            # تحلیل کامل ICT برای کاربران پریمیوم
            try:
                ict_analysis = get_ict_analysis()
                data = get_processed_data("GOLD", "1h", 100)
                
                if ict_analysis and not data.empty:
                    latest = data.iloc[-1]
                    
                    analysis_text = f"""
🎯 **Complete ICT Analysis - Premium**

📊 **Current Signal:**
🔹 Action: {ict_analysis.get('signal', 'HOLD')}
🔹 Confidence: {ict_analysis.get('confidence', 0):.1%}
🔹 Reasons: {', '.join(ict_analysis.get('reasons', []))}

📈 **Market Structure:**
🔹 Current Structure: {latest.get('Market_Structure', 'NEUTRAL')}
🔹 Structure Strength: {latest.get('Structure_Strength', 0):.1%}
🔹 Swing High: {'✅' if latest.get('Swing_High') else '❌'}
🔹 Swing Low: {'✅' if latest.get('Swing_Low') else '❌'}

🎯 **Order Block Analysis:**
🔹 Bullish OB: {'✅' if latest.get('Bullish_OB') else '❌'}
🔹 Bearish OB: {'✅' if latest.get('Bearish_OB') else '❌'}
🔹 OB Strength: {latest.get('OB_Strength', 0):.2f}

🔄 **Fair Value Gap Analysis:**
🔹 Bullish FVG: {'✅' if latest.get('Bullish_FVG') else '❌'}
🔹 Bearish FVG: {'✅' if latest.get('Bearish_FVG') else '❌'}
🔹 FVG Size: {latest.get('FVG_Size', 0):.4f}

💧 **Liquidity Analysis:**
🔹 Buy Side Sweep: {'✅' if latest.get('Buy_Side_Liquidity_Sweep') else '❌'}
🔹 Sell Side Sweep: {'✅' if latest.get('Sell_Side_Liquidity_Sweep') else '❌'}
🔹 Liquidity Strength: {latest.get('Liquidity_Strength', 0):.4f}

📊 **Technical Confluence:**
🔹 RSI: {latest.get('RSI', 0):.1f}
🔹 MACD: {latest.get('MACD', 0):.3f}
🔹 ATR: {latest.get('ATR', 0):.4f}

⚠️ **Risk Notice:** This analysis is for educational purposes only.
"""
                else:
                    analysis_text = """
🎯 **ICT Analysis - Premium**

🔄 Analysis in progress...
Please try again in a moment.
"""
                
                update.message.reply_text(analysis_text, parse_mode='Markdown')
            except Exception as e:
                logger.error(f"Error in premium ICT analysis: {e}")
                update.message.reply_text("🔄 Analyzing market... Please wait a moment.")
        else:
            update.message.reply_text(
                "🎯 **ICT Analysis - Premium Feature**\n\n"
                "This advanced ICT analysis is available for Premium users only.\n\n"
                "🎯 **Premium ICT Features:**\n"
                "🔹 Complete Order Block analysis\n"
                "🔹 Fair Value Gap detection\n"
                "🔹 Liquidity sweep identification\n"
                "🔹 Market structure analysis\n"
                "🔹 Multi-timeframe confluence\n"
                "🔹 Real-time pattern alerts\n\n"
                "💎 Upgrade to Premium for full ICT analysis!",
                parse_mode='Markdown'
            )
    
    elif text == "📈 HTF Analysis":
        if is_premium:
            try:
                # تحلیل Higher Time Frame
                htf_4h = get_processed_data("GOLD", "4h", 50)
                htf_1d = get_processed_data("GOLD", "1d", 30)
                
                if not htf_4h.empty and not htf_1d.empty:
                    latest_4h = htf_4h.iloc[-1]
                    latest_1d = htf_1d.iloc[-1]
                    
                    htf_text = f"""
📈 **Higher Time Frame Analysis - Premium**

📊 **4H Analysis:**
🔹 Market Structure: {latest_4h.get('Market_Structure', 'NEUTRAL')}
🔹 Order Blocks: {'✅' if latest_4h.get('Bullish_OB') or latest_4h.get('Bearish_OB') else '❌'}
🔹 Fair Value Gaps: {'✅' if latest_4h.get('Bullish_FVG') or latest_4h.get('Bearish_FVG') else '❌'}
🔹 RSI: {latest_4h.get('RSI', 0):.1f}

📊 **Daily Analysis:**
🔹 Market Structure: {latest_1d.get('Market_Structure', 'NEUTRAL')}
🔹 Trend Direction: {'Bullish' if latest_1d.get('Close', 0) > latest_1d.get('SMA_20', 0) else 'Bearish'}
🔹 RSI: {latest_1d.get('RSI', 0):.1f}

🎯 **HTF Bias:**
"""
                    
                    # تعیین bias کلی
                    if (latest_4h.get('Market_Structure') == 'BULLISH' and 
                        latest_1d.get('Market_Structure') == 'BULLISH'):
                        htf_text += "🟢 **STRONG BULLISH BIAS**\n"
                        htf_text += "Look for bullish ICT setups on lower timeframes."
                    elif (latest_4h.get('Market_Structure') == 'BEARISH' and 
                          latest_1d.get('Market_Structure') == 'BEARISH'):
                        htf_text += "🔴 **STRONG BEARISH BIAS**\n"
                        htf_text += "Look for bearish ICT setups on lower timeframes."
                    else:
                        htf_text += "🟡 **MIXED/NEUTRAL BIAS**\n"
                        htf_text += "Wait for clearer directional bias."
                    
                    update.message.reply_text(htf_text, parse_mode='Markdown')
                else:
                    update.message.reply_text("❌ Insufficient data for HTF analysis")
                    
            except Exception as e:
                update.message.reply_text("🔄 Loading HTF analysis... Please wait.")
        else:
            update.message.reply_text(
                "📈 **HTF Analysis - Premium Feature**\n\n"
                "Higher Time Frame analysis with ICT methodology is available for Premium users.\n\n"
                "💎 Upgrade to access multi-timeframe ICT analysis!",
                parse_mode='Markdown'
            )
    
    elif text == "💎 Upgrade to Premium":
        premium_text = f"""
💎 **Upgrade to FlowAI-ICT Premium**

🎯 **Exclusive ICT Features:**
🔹 Complete Order Block analysis with strength ratings
🔹 Fair Value Gap detection and validation
🔹 Liquidity sweep identification and tracking
🔹 Market structure analysis across all timeframes
🔹 HTF (Higher Time Frame) bias analysis
🔹 Real-time ICT pattern alerts
🔹 Personal backtesting with ICT strategies
🔹 Advanced confluences and setups
🔹 VIP instant notifications
🔹 24/7 priority support

🤖 **AI Integration:**
🔹 ICT + AI combined signals
🔹 Machine learning pattern recognition
🔹 Automated trade setups
🔹 Risk management integration

💰 **Pricing:** 50,000 Toman/month
🎁 **Special Offer:** 30% off first 3 months

📞 **To Purchase:**
🔹 Contact support
🔹 Use 'Support' button below

👤 **Your ID:** `{user_id}`
"""
        update.message.reply_text(premium_text, parse_mode='Markdown')
    
    elif text == "🚨 Trading Signals":
        if is_premium:
            # سیگنال‌های کامل برای کاربران پریمیوم
            try:
                stats = signal_manager.get_signal_statistics()
                last_signal = None
                
                if signal_manager.signal_history:
                    last_signal = signal_manager.signal_history[-1]['signal']
                
                if last_signal:
                    action_emoji = {'BUY': '🟢', 'SELL': '🔴', 'HOLD': '🟡'}
                    signals_text = f"""
🚨 **ICT Trading Signals - VIP**

📊 **Latest Signal:**
{action_emoji.get(last_signal['action'], '🟡')} **{last_signal['action']}**
💰 Entry: ${last_signal['entry_price']:.2f}
🎯 Target: ${last_signal['target_price']:.2f}
🛑 Stop Loss: ${last_signal['stop_loss']:.2f}
⭐ Confidence: {last_signal['confidence']:.1%}
⏰ Time: {last_signal['timestamp'].strftime('%H:%M')}

🎯 **ICT Context:**
🔹 Based on: {', '.join(last_signal.get('analysis_details', [])[:3])}
🔹 Market Structure: {last_signal.get('indicators', {}).get('market_structure', 'N/A')}

📈 **Today's Performance:**
🔹 Total Signals: {stats['total_signals']}
🔹 Buy Signals: {stats['buy_signals']}
🔹 Sell Signals: {stats['sell_signals']}
🔹 Average Confidence: {stats['avg_confidence']:.1%}

🔔 **VIP Alerts:** Active
"""
                else:
                    signals_text = """
🚨 **ICT Trading Signals - VIP**

📊 **Status:**
No signals generated yet today.
System is monitoring ICT patterns continuously.

🔔 **VIP Alerts:** Active
💡 **Note:** You'll receive instant notifications when ICT setups appear.
"""
        else:
            signals_text = """
🚨 **Trading Signals**

📊 **Free Sample Signal:**
🟡 **WATCH Gold**
💰 Current Price: Check live price
📈 General Bias: Monitor ICT patterns

💎 **For Premium ICT Signals:**
🔹 Precise entry/exit points
🔹 ICT-based setups
🔹 5-10 signals daily
🔹 70%+ accuracy rate
🔹 Instant VIP alerts
🔹 Complete trade management

👆 Upgrade to Premium for full ICT signals!
"""
        
        update.message.reply_text(signals_text, parse_mode='Markdown')
    
    elif text == "👤 My Profile":
        profile_text = f"""
👤 **Your FlowAI-ICT Profile**

🆔 **ID:** `{user_id}`
👤 **Name:** {user_name}
{'💎 **Status:** Premium' if is_premium else '🆓 **Status:** Free'}
📅 **Member Since:** Today
🔔 **Notifications:** {'VIP Active' if is_premium else 'Standard'}

📊 **Your ICT Stats:**
🔹 Sessions: 1
🔹 Signals Received: {len(signal_manager.signal_history)}
{'🔹 Backtests Run: 0' if is_premium else '🔹 Free Limitations Active'}
{'🔹 HTF Analysis Access: ✅' if is_premium else '🔹 HTF Analysis: Upgrade Required'}

🎯 **ICT Features:**
🔹 Order Block Detection: {'Full Access' if is_premium else 'Basic'}
🔹 Fair Value Gaps: {'Full Access' if is_premium else 'Limited'}
🔹 Liquidity Analysis: {'Full Access' if is_premium else 'Basic'}
🔹 Market Structure: {'Multi-TF' if is_premium else 'Single TF'}

⚙️ **Settings:**
🔹 Language: Persian
🔹 Timezone: Tehran
🔹 Notifications: {'VIP' if is_premium else 'Standard'}
🔹 ICT Methodology: Enabled
"""
        update.message.reply_text(profile_text, parse_mode='Markdown')
    
    elif text == "📞 Support":
        support_text = f"""
📞 **FlowAI-ICT Support**

🎯 **Contact Methods:**
📧 Email: support@flowai-ict.ir
📱 Telegram: @FlowAI_ICT_Support
📞 Phone: 021-12345678

⏰ **Support Hours:**
🔹 Saturday-Wednesday: 9AM-6PM
🔹 Thursday: 9AM-2PM
{'🔹 24/7 VIP Support for Premium users' if is_premium else '🔹 Business hours for Free users'}

📝 **For Support Request:**
Please include your ID: `{user_id}`

💡 **Common Questions:**
🔹 How to upgrade to Premium
🔹 Understanding ICT signals
🔹 Technical issues
🔹 ICT methodology questions
🔹 Account management

🎯 **ICT Learning Resources:**
🔹 Order Block guide
🔹 Fair Value Gap tutorial
🔹 Market structure basics
🔹 Liquidity concepts

{'🎓 **Premium Learning Center Available**' if is_premium else '💎 **Upgrade for Advanced ICT Education**'}
"""
        update.message.reply_text(support_text, parse_mode='Markdown')

# Setup handlers
def setup_user_handlers(dispatcher):
    """راه‌اندازی handler های کاربر ICT"""
    dispatcher.add_handler(CommandHandler('start', start_user))
    dispatcher.add_handler(MessageHandler(
        Filters.text & Filters.regex(r'^(💰 Live Gold Price|🎯 ICT Analysis|🔍 Quick Analysis|🚨 Trading Signals|📈 HTF Analysis|🎯 ICT Patterns|🧪 Personal Backtest|⚙️ Advanced Settings|📱 VIP Alerts|🎯 Exclusive Signals|📊 Performance Report|🔍 Deep Analysis|💎 Upgrade to Premium|ℹ️ ICT Guide|🎁 Free Features|📋 Limitations|👤 My Profile|📞 Support)$'), 
        handle_user_menu
    ))
