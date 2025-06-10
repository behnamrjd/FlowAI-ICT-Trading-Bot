from telegram import Update, ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import CallbackContext, CommandHandler, MessageHandler, Filters, CallbackQueryHandler
import logging
import asyncio
from ..data_sources.brsapi_fetcher import get_brsapi_status, get_brsapi_gold_price
from ..config import TELEGRAM_ADMIN_IDS, ICT_ENABLED, AI_MODEL_ENABLED
from ..data_handler import get_processed_data, get_ict_analysis, ict_data_handler
from ..telegram.signal_manager import signal_manager, start_signal_monitoring, stop_signal_monitoring, get_signal_stats
from ..ai_signal_engine import get_ai_trading_signal, get_market_status
from ..backtest_engine import run_backtest_analysis, get_backtest_summary
from ..telegram.premium_manager import premium_manager, get_premium_stats
from ..risk_manager import get_risk_status
from ..reporting_engine import export_daily_report_text, export_weekly_report_text
from ..notification_system import send_system_alert, get_notification_stats

logger = logging.getLogger(__name__)

class ICTAdminMenu:
    def __init__(self):
        self.admin_ids = TELEGRAM_ADMIN_IDS
        self.pending_actions = {}
        self.ict_settings = {
            'order_blocks': True,
            'fair_value_gaps': True,
            'liquidity_sweeps': True,
            'market_structure': True
        }
        logger.info(f"ICT Admin menu initialized with IDs: {self.admin_ids}")
    
    def is_admin(self, user_id: int) -> bool:
        """بررسی ادمین بودن کاربر"""
        is_admin = user_id in self.admin_ids
        logger.info(f"User {user_id} admin check: {is_admin}")
        return is_admin
    
    def main_menu_keyboard(self):
        """منوی اصلی ادمین ICT-Enhanced"""
        keyboard = [
            [
                KeyboardButton("🎯 ICT Dashboard"),
                KeyboardButton("🤖 AI & Signals")
            ],
            [
                KeyboardButton("📊 Market Analysis"),
                KeyboardButton("🧪 ICT Backtest")
            ],
            [
                KeyboardButton("👥 User Management"),
                KeyboardButton("⚠️ Risk Control")
            ],
            [
                KeyboardButton("📋 Reports & Analytics"),
                KeyboardButton("🔔 Notifications")
            ],
            [
                KeyboardButton("💰 Live Price"),
                KeyboardButton("⚙️ ICT Settings")
            ]
        ]
        return ReplyKeyboardMarkup(keyboard, resize_keyboard=True, one_time_keyboard=False)
    
    def ict_dashboard_keyboard(self):
        """منوی ICT Dashboard"""
        keyboard = [
            [
                InlineKeyboardButton("📈 Order Blocks", callback_data="ict_order_blocks"),
                InlineKeyboardButton("🔄 Fair Value Gaps", callback_data="ict_fvg")
            ],
            [
                InlineKeyboardButton("💧 Liquidity Sweeps", callback_data="ict_liquidity"),
                InlineKeyboardButton("🏗️ Market Structure", callback_data="ict_structure")
            ],
            [
                InlineKeyboardButton("🎯 ICT Signals", callback_data="ict_signals"),
                InlineKeyboardButton("📊 Pattern Stats", callback_data="ict_stats")
            ],
            [
                InlineKeyboardButton("⚙️ ICT Config", callback_data="ict_config"),
                InlineKeyboardButton("🔄 Refresh Data", callback_data="ict_refresh")
            ],
            [
                InlineKeyboardButton("🔙 Back", callback_data="main_menu")
            ]
        ]
        return InlineKeyboardMarkup(keyboard)
    
    def ai_signals_keyboard(self):
        """منوی AI & Signals"""
        keyboard = [
            [
                InlineKeyboardButton("🚀 Start Monitoring", callback_data="start_monitoring"),
                InlineKeyboardButton("⏹️ Stop Monitoring", callback_data="stop_monitoring")
            ],
            [
                InlineKeyboardButton("🔍 Force Analysis", callback_data="force_analysis"),
                InlineKeyboardButton("🎯 ICT + AI Signal", callback_data="ict_ai_signal")
            ],
            [
                InlineKeyboardButton("📊 Signal Stats", callback_data="signal_stats"),
                InlineKeyboardButton("🤖 AI Model Status", callback_data="ai_model_status")
            ],
            [
                InlineKeyboardButton("⚙️ Signal Settings", callback_data="signal_settings"),
                InlineKeyboardButton("🔄 Retrain Model", callback_data="retrain_model")
            ],
            [
                InlineKeyboardButton("🔙 Back", callback_data="main_menu")
            ]
        ]
        return InlineKeyboardMarkup(keyboard)
    
    def market_analysis_keyboard(self):
        """منوی تحلیل بازار"""
        keyboard = [
            [
                InlineKeyboardButton("📈 HTF Analysis", callback_data="htf_analysis"),
                InlineKeyboardButton("⏰ LTF Analysis", callback_data="ltf_analysis")
            ],
            [
                InlineKeyboardButton("🎯 Multi-Timeframe", callback_data="multi_tf_analysis"),
                InlineKeyboardButton("📊 Technical Indicators", callback_data="technical_indicators")
            ],
            [
                InlineKeyboardButton("🔍 Pattern Scanner", callback_data="pattern_scanner"),
                InlineKeyboardButton("💹 Market Sessions", callback_data="market_sessions")
            ],
            [
                InlineKeyboardButton("📋 Full Report", callback_data="full_market_report"),
                InlineKeyboardButton("🔄 Refresh", callback_data="refresh_analysis")
            ],
            [
                InlineKeyboardButton("🔙 Back", callback_data="main_menu")
            ]
        ]
        return InlineKeyboardMarkup(keyboard)

# Instance global
admin_menu = ICTAdminMenu()

def start_admin(update: Update, context: CallbackContext):
    """شروع منوی ادمین ICT"""
    user_id = update.effective_user.id
    user_name = update.effective_user.first_name
    
    logger.info(f"ICT Admin command received from user {user_id} ({user_name})")
    
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
        
        # دریافت تحلیل ICT
        ict_analysis = get_ict_analysis()
        
        welcome_text = f"""
🎯 **FlowAI-ICT Trading Bot Admin Panel**

سلام {user_name} عزیز! 👋
به پنل مدیریت ربات ICT خوش آمدید.

💰 **Market Data:**
🔹 Gold Price: ${current_price:.2f}
🔹 ICT Signal: {ict_analysis.get('signal', 'HOLD')}
🔹 Confidence: {ict_analysis.get('confidence', 0):.1%}

📡 **System Status:**
🔹 API Calls: {api_status['daily_calls']}/{api_status['daily_limit']}
🔹 Usage: {api_status['daily_usage_percent']:.1f}%
🔹 Signals Today: {signal_stats['total_signals']}
🔹 Monitoring: {'🟢 Active' if signal_manager.running else '🔴 Inactive'}

🎯 **ICT Features:**
🔹 ICT Engine: {'🟢 Enabled' if ICT_ENABLED else '🔴 Disabled'}
🔹 AI Model: {'🟢 Active' if AI_MODEL_ENABLED else '🔴 Inactive'}
🔹 Order Blocks: {'✅' if admin_menu.ict_settings['order_blocks'] else '❌'}
🔹 Fair Value Gaps: {'✅' if admin_menu.ict_settings['fair_value_gaps'] else '❌'}

⚠️ **Risk Status:**
🔹 Daily PnL: ${risk_stats['daily_pnl']:.2f}
🔹 Trades Today: {risk_stats['daily_trades']}/{risk_stats['max_daily_trades']}

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
            f"🎯 **FlowAI-ICT Admin Panel**\n\nسلام {user_name}!\nخوش آمدید به پنل مدیریت ICT.",
            reply_markup=admin_menu.main_menu_keyboard(),
            parse_mode='Markdown'
        )

def handle_admin_menu(update: Update, context: CallbackContext):
    """مدیریت پیام‌های منوی ادمین"""
    user_id = update.effective_user.id
    
    if not admin_menu.is_admin(user_id):
        return
    
    text = update.message.text
    logger.info(f"ICT Admin menu action: {text} by user {user_id}")
    
    if text == "🎯 ICT Dashboard":
        try:
            # دریافت آمار ICT
            data = get_processed_data("GOLD", "1h", 100)
            ict_analysis = get_ict_analysis()
            
            if not data.empty:
                # شمارش patterns
                order_blocks = data['Bullish_OB'].sum() + data['Bearish_OB'].sum()
                fvgs = data['Bullish_FVG'].sum() + data['Bearish_FVG'].sum()
                liquidity_sweeps = data['Buy_Side_Liquidity_Sweep'].sum() + data['Sell_Side_Liquidity_Sweep'].sum()
                
                latest = data.iloc[-1]
                
                ict_text = f"""
🎯 **ICT Dashboard - Live Analysis**

📊 **Current Market State:**
🔹 Signal: {ict_analysis.get('signal', 'HOLD')}
🔹 Confidence: {ict_analysis.get('confidence', 0):.1%}
🔹 Market Structure: {latest.get('Market_Structure', 'NEUTRAL')}

📈 **Pattern Detection (Last 100 Candles):**
🔹 Order Blocks: {order_blocks}
🔹 Fair Value Gaps: {fvgs}
🔹 Liquidity Sweeps: {liquidity_sweeps}

🎯 **Latest Candle Analysis:**
🔹 Bullish OB: {'✅' if latest.get('Bullish_OB', False) else '❌'}
🔹 Bearish OB: {'✅' if latest.get('Bearish_OB', False) else '❌'}
🔹 Bullish FVG: {'✅' if latest.get('Bullish_FVG', False) else '❌'}
🔹 Bearish FVG: {'✅' if latest.get('Bearish_FVG', False) else '❌'}
🔹 Buy Liquidity Sweep: {'✅' if latest.get('Buy_Side_Liquidity_Sweep', False) else '❌'}
🔹 Sell Liquidity Sweep: {'✅' if latest.get('Sell_Side_Liquidity_Sweep', False) else '❌'}

📊 **Technical Indicators:**
🔹 RSI: {latest.get('RSI', 0):.1f}
🔹 MACD: {latest.get('MACD', 0):.3f}
🔹 ATR: {latest.get('ATR', 0):.4f}

⏰ **Last Update:** {data.index[-1].strftime('%Y-%m-%d %H:%M')}
"""
            else:
                ict_text = "❌ **ICT Dashboard**\n\nNo data available for analysis."
            
            update.message.reply_text(
                ict_text,
                reply_markup=admin_menu.ict_dashboard_keyboard(),
                parse_mode='Markdown'
            )
            
        except Exception as e:
            update.message.reply_text(f"❌ خطا در ICT Dashboard: {str(e)}")
    
    elif text == "🤖 AI & Signals":
        try:
            signal_stats = get_signal_stats()
            market_status = get_market_status()
            
            ai_text = f"""
🤖 **AI & Signal Management**

🚨 **Signal Statistics:**
🔹 Total Signals: {signal_stats['total_signals']}
🔹 Buy Signals: {signal_stats['buy_signals']}
🔹 Sell Signals: {signal_stats['sell_signals']}
🔹 Average Confidence: {signal_stats['avg_confidence']:.1%}

👥 **Subscribers:**
🔹 Admins: {signal_stats['subscribers_count']['admin']}
🔹 Premium: {signal_stats['subscribers_count']['premium']}
🔹 Free: {signal_stats['subscribers_count']['free']}

🏪 **Market Status:**
🔹 Active: {'✅' if market_status['market_active'] else '❌'}
🔹 Cooldown: {market_status['cooldown_remaining']:.0f}s

🤖 **AI Model:**
🔹 Status: {'🟢 Active' if AI_MODEL_ENABLED else '🔴 Inactive'}
🔹 ICT Integration: {'🟢 Enabled' if ICT_ENABLED else '🔴 Disabled'}

⚡ **Monitoring:** {'🟢 Active' if signal_manager.running else '🔴 Inactive'}
"""
            
            update.message.reply_text(
                ai_text,
                reply_markup=admin_menu.ai_signals_keyboard(),
                parse_mode='Markdown'
            )
            
        except Exception as e:
            update.message.reply_text(f"❌ خطا در AI & Signals: {str(e)}")
    
    elif text == "📊 Market Analysis":
        update.message.reply_text(
            "📊 **Market Analysis Center**\n\nSelect analysis type:",
            reply_markup=admin_menu.market_analysis_keyboard(),
            parse_mode='Markdown'
        )
    
    elif text == "💰 Live Price":
        try:
            current_price = get_brsapi_gold_price()
            api_status = get_brsapi_status()
            ict_analysis = get_ict_analysis()
            
            price_text = f"""
💰 **Live Gold Price Analysis**

🏆 **Current Price:** ${current_price:.2f}
📊 **Source:** BrsAPI Pro
⏰ **Last Update:** Now

🎯 **ICT Analysis:**
🔹 Signal: {ict_analysis.get('signal', 'HOLD')}
🔹 Confidence: {ict_analysis.get('confidence', 0):.1%}
🔹 Patterns Detected: {len(ict_analysis.get('reasons', []))}

📡 **API Status:**
🔹 Calls Today: {api_status['daily_calls']}/{api_status['daily_limit']}
🔹 Usage: {api_status['daily_usage_percent']:.1f}%
🔹 Remaining: {api_status['daily_remaining']}

🔄 **Auto-refresh:** Every 10 seconds
"""
            
            update.message.reply_text(price_text, parse_mode='Markdown')
            
        except Exception as e:
            update.message.reply_text(f"❌ خطا در دریافت قیمت: {str(e)}")

def handle_admin_callbacks(update: Update, context: CallbackContext):
    """مدیریت callback های ادمین ICT"""
    query = update.callback_query
    query.answer()
    
    user_id = query.from_user.id
    if not admin_menu.is_admin(user_id):
        query.edit_message_text("⛔ شما دسترسی ادمین ندارید!")
        return
    
    data = query.data
    logger.info(f"ICT Admin callback: {data} by user {user_id}")
    
    if data == "ict_signals":
        try:
            ict_analysis = get_ict_analysis()
            data_df = get_processed_data("GOLD", "1h", 50)
            
            if not data_df.empty:
                latest = data_df.iloc[-1]
                
                signal_text = f"""
🎯 **ICT Signals Analysis**

📊 **Current Signal:**
🔹 Action: {ict_analysis.get('signal', 'HOLD')}
🔹 Confidence: {ict_analysis.get('confidence', 0):.1%}
🔹 Reasons: {', '.join(ict_analysis.get('reasons', []))}

🎯 **ICT Patterns Active:**
🔹 Order Blocks: {'✅' if ict_analysis.get('ict_patterns', {}).get('order_blocks') else '❌'}
🔹 Fair Value Gaps: {'✅' if ict_analysis.get('ict_patterns', {}).get('fair_value_gaps') else '❌'}
🔹 Liquidity Sweeps: {'✅' if ict_analysis.get('ict_patterns', {}).get('liquidity_sweeps') else '❌'}
🔹 Market Structure: {ict_analysis.get('ict_patterns', {}).get('market_structure', 'NEUTRAL')}

📈 **Latest Candle:**
🔹 Open: ${latest.get('Open', 0):.2f}
🔹 High: ${latest.get('High', 0):.2f}
🔹 Low: ${latest.get('Low', 0):.2f}
🔹 Close: ${latest.get('Close', 0):.2f}

⏰ **Analysis Time:** {data_df.index[-1].strftime('%Y-%m-%d %H:%M')}
"""
                
                query.edit_message_text(signal_text, parse_mode='Markdown')
            else:
                query.edit_message_text("❌ No data available for ICT signals analysis")
                
        except Exception as e:
            query.edit_message_text(f"❌ خطا در تحلیل ICT: {str(e)}")
    
    elif data == "ict_ai_signal":
        try:
            # ترکیب ICT + AI
            ict_analysis = get_ict_analysis()
            ai_signal = get_ai_trading_signal(force_analysis=True)
            
            if ai_signal and ict_analysis:
                combined_text = f"""
🎯 **ICT + AI Combined Signal**

🤖 **AI Analysis:**
🔹 Signal: {ai_signal.get('action', 'HOLD')}
🔹 Confidence: {ai_signal.get('confidence', 0):.1%}
🔹 Entry: ${ai_signal.get('entry_price', 0):.2f}
🔹 Target: ${ai_signal.get('target_price', 0):.2f}
🔹 Stop Loss: ${ai_signal.get('stop_loss', 0):.2f}

🎯 **ICT Analysis:**
🔹 Signal: {ict_analysis.get('signal', 'HOLD')}
🔹 Confidence: {ict_analysis.get('confidence', 0):.1%}
🔹 Patterns: {len(ict_analysis.get('reasons', []))}

🔄 **Combined Decision:**
"""
                
                # ترکیب سیگنال‌ها
                if ai_signal['action'] == ict_analysis['signal']:
                    combined_confidence = (ai_signal['confidence'] + ict_analysis['confidence']) / 2
                    combined_text += f"✅ **STRONG {ai_signal['action']}** - Confidence: {combined_confidence:.1%}\n"
                    combined_text += "🎯 Both AI and ICT agree on direction!"
                else:
                    combined_text += f"⚠️ **CONFLICTED** - AI: {ai_signal['action']}, ICT: {ict_analysis['signal']}\n"
                    combined_text += "🤔 Consider waiting for alignment"
                
                query.edit_message_text(combined_text, parse_mode='Markdown')
            else:
                query.edit_message_text("❌ Unable to generate combined signal")
                
        except Exception as e:
            query.edit_message_text(f"❌ خطا در سیگنال ترکیبی: {str(e)}")
    
    elif data == "start_monitoring":
        start_signal_monitoring()
        query.edit_message_text("✅ **ICT Signal Monitoring Started**\n\nSystem will check market every 5 minutes with ICT analysis.", parse_mode='Markdown')
    
    elif data == "stop_monitoring":
        stop_signal_monitoring()
        query.edit_message_text("⏹️ **ICT Signal Monitoring Stopped**", parse_mode='Markdown')
    
    elif data == "htf_analysis":
        try:
            # تحلیل Higher Time Frame
            htf_data = get_processed_data("GOLD", "4h", 100)
            daily_data = get_processed_data("GOLD", "1d", 50)
            
            if not htf_data.empty and not daily_data.empty:
                htf_latest = htf_data.iloc[-1]
                daily_latest = daily_data.iloc[-1]
                
                htf_text = f"""
📈 **Higher Time Frame Analysis**

📊 **4H Timeframe:**
🔹 Market Structure: {htf_latest.get('Market_Structure', 'NEUTRAL')}
🔹 RSI: {htf_latest.get('RSI', 0):.1f}
🔹 MACD: {htf_latest.get('MACD', 0):.3f}
🔹 Order Blocks: {'✅' if htf_latest.get('Bullish_OB') or htf_latest.get('Bearish_OB') else '❌'}

📊 **Daily Timeframe:**
🔹 Market Structure: {daily_latest.get('Market_Structure', 'NEUTRAL')}
🔹 RSI: {daily_latest.get('RSI', 0):.1f}
🔹 Trend Direction: {'Bullish' if daily_latest.get('Close', 0) > daily_latest.get('SMA_20', 0) else 'Bearish'}

🎯 **HTF Bias:**
"""
                
                # تعیین bias کلی
                if (htf_latest.get('Market_Structure') == 'BULLISH' and 
                    daily_latest.get('Market_Structure') == 'BULLISH'):
                    htf_text += "🟢 **STRONG BULLISH BIAS**"
                elif (htf_latest.get('Market_Structure') == 'BEARISH' and 
                      daily_latest.get('Market_Structure') == 'BEARISH'):
                    htf_text += "🔴 **STRONG BEARISH BIAS**"
                else:
                    htf_text += "🟡 **MIXED/NEUTRAL BIAS**"
                
                query.edit_message_text(htf_text, parse_mode='Markdown')
            else:
                query.edit_message_text("❌ Insufficient data for HTF analysis")
                
        except Exception as e:
            query.edit_message_text(f"❌ خطا در تحلیل HTF: {str(e)}")

# Setup handlers
def setup_admin_handlers(dispatcher):
    """راه‌اندازی handler های ادمین ICT"""
    dispatcher.add_handler(CommandHandler('admin', start_admin))
    dispatcher.add_handler(MessageHandler(
        Filters.text & Filters.regex(r'^(🎯 ICT Dashboard|🤖 AI & Signals|📊 Market Analysis|🧪 ICT Backtest|👥 User Management|⚠️ Risk Control|📋 Reports & Analytics|🔔 Notifications|💰 Live Price|⚙️ ICT Settings)$'), 
        handle_admin_menu
    ))
    dispatcher.add_handler(CallbackQueryHandler(handle_admin_callbacks))
