"""
FlowAI ICT Trading Bot Telegram Integration
Handles all Telegram bot functionality and notifications
"""

import requests
import logging
from typing import Optional, Dict, Any
from datetime import datetime
from . import config

# Setup logger
logger = logging.getLogger("FlowAI_Bot")

class TelegramBot:
    """
    Handles Telegram bot operations
    """
    
    def __init__(self):
        self.bot_token = config.TELEGRAM_BOT_TOKEN
        self.chat_id = config.TELEGRAM_CHAT_ID
        self.enabled = config.TELEGRAM_ENABLED
        self.base_url = f"https://api.telegram.org/bot{self.bot_token}"
        
    def send_message(self, message: str, parse_mode: str = "Markdown") -> bool:
        """
        Send message to Telegram chat
        """
        if not self.enabled or not self.bot_token or not self.chat_id:
            logger.debug("Telegram not configured or disabled")
            return False
        
        try:
            url = f"{self.base_url}/sendMessage"
            data = {
                'chat_id': self.chat_id,
                'text': message,
                'parse_mode': parse_mode,
                'disable_web_page_preview': True
            }
            
            response = requests.post(url, data=data, timeout=10)
            
            if response.status_code == 200:
                logger.info("Telegram message sent successfully")
                return True
            else:
                logger.error(f"Failed to send Telegram message: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending Telegram message: {e}")
            return False
    
    def send_signal(self, signal_type: str, symbol: str, price: float, 
                   confidence: float, analysis: Dict[str, Any]) -> bool:
        """
        Send trading signal to Telegram
        """
        try:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            # Determine emoji based on signal type
            signal_emoji = {
                'BUY': '🟢',
                'SELL': '🔴', 
                'HOLD': '🟡'
            }.get(signal_type.upper(), '⚪')
            
            message = f"""
🚨 **FlowAI XAU Trading Signal** 🚨

{signal_emoji} **Signal:** {signal_type.upper()}
📊 **Symbol:** {symbol}
💰 **Price:** ${price:,.2f}
⏰ **Time:** {timestamp}

🤖 **AI Analysis:**
   • Confidence: {confidence*100:.1f}%
   • HTF Bias: {analysis.get('htf_bias', 'N/A')}
   • Risk Level: {analysis.get('risk_level', 'MEDIUM')}

📋 **Technical Analysis:**
   • RSI: {analysis.get('rsi', 'N/A')}
   • Trend: {analysis.get('trend', 'N/A')}
   • Volume: {analysis.get('volume_status', 'N/A')}

⚠️ **Risk Management:**
   • Stop Loss: {analysis.get('stop_loss', 'Calculate based on ATR')}
   • Take Profit: {analysis.get('take_profit', 'Calculate based on R:R')}

🎯 **Powered by FlowAI v2.0**
            """.strip()
            
            return self.send_message(message)
            
        except Exception as e:
            logger.error(f"Error sending signal message: {e}")
            return False
    
    def send_status_update(self, status: str, details: Dict[str, Any] = None) -> bool:
        """
        Send bot status update
        """
        try:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            message = f"""
🤖 **FlowAI Bot Status Update**

📊 **Status:** {status}
⏰ **Time:** {timestamp}
            """
            
            if details:
                message += "\n\n📋 **Details:**"
                for key, value in details.items():
                    message += f"\n   • {key}: {value}"
            
            message += "\n\n🎯 **FlowAI XAU Trading Bot v2.0**"
            
            return self.send_message(message.strip())
            
        except Exception as e:
            logger.error(f"Error sending status update: {e}")
            return False
    
    def send_error_notification(self, error_message: str, context: str = "") -> bool:
        """
        Send error notification
        """
        try:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            message = f"""
🚨 **FlowAI Bot Error Alert** 🚨

❌ **Error:** {error_message}
📍 **Context:** {context}
⏰ **Time:** {timestamp}

🔧 **Action Required:** Please check bot logs and restart if necessary.

🎯 **FlowAI XAU Trading Bot v2.0**
            """.strip()
            
            return self.send_message(message)
            
        except Exception as e:
            logger.error(f"Error sending error notification: {e}")
            return False
    
    def test_connection(self) -> bool:
        """
        Test Telegram bot connection
        """
        try:
            test_message = f"""
🧪 **FlowAI Bot Connection Test**

✅ **Status:** Connection successful!
⏰ **Time:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

🎯 **FlowAI XAU Trading Bot v2.0**
            """.strip()
            
            return self.send_message(test_message)
            
        except Exception as e:
            logger.error(f"Telegram connection test failed: {e}")
            return False

# Create global instance
telegram_bot = TelegramBot()

# Convenience functions
def send_telegram_message(message: str) -> bool:
    """Convenience function to send Telegram message"""
    return telegram_bot.send_message(message)

def send_trading_signal(signal_type: str, symbol: str, price: float, 
                       confidence: float, analysis: Dict[str, Any]) -> bool:
    """Convenience function to send trading signal"""
    return telegram_bot.send_signal(signal_type, symbol, price, confidence, analysis)

def send_status_update(status: str, details: Dict[str, Any] = None) -> bool:
    """Convenience function to send status update"""
    return telegram_bot.send_status_update(status, details)

def send_error_notification(error_message: str, context: str = "") -> bool:
    """Convenience function to send error notification"""
    return telegram_bot.send_error_notification(error_message, context)
