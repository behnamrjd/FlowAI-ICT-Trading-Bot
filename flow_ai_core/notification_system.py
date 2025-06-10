import logging
import smtplib
import requests
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart
from typing import Dict, List, Optional
from datetime import datetime
from telegram import Bot
from telegram.error import TelegramError
from .config import TELEGRAM_BOT_TOKEN

logger = logging.getLogger(__name__)

class NotificationSystem:
    def __init__(self):
        self.telegram_bot = Bot(token=TELEGRAM_BOT_TOKEN)
        self.email_config = {
            'smtp_server': 'smtp.gmail.com',
            'smtp_port': 587,
            'username': '',  # باید در config تنظیم شود
            'password': '',  # باید در config تنظیم شود
        }
        self.webhook_urls = []
        self.notification_history = []
        
    def send_telegram_notification(self, 
                                 user_ids: List[int], 
                                 message: str, 
                                 priority: str = "normal") -> Dict:
        """ارسال اطلاع‌رسانی تلگرام"""
        results = {
            'sent': 0,
            'failed': 0,
            'errors': []
        }
        
        try:
            # اضافه کردن emoji بر اساس اولویت
            priority_emojis = {
                'low': '🔵',
                'normal': '🟡',
                'high': '🟠',
                'critical': '🔴'
            }
            
            formatted_message = f"{priority_emojis.get(priority, '🟡')} {message}"
            
            for user_id in user_ids:
                try:
                    self.telegram_bot.send_message(
                        chat_id=user_id,
                        text=formatted_message,
                        parse_mode='Markdown'
                    )
                    results['sent'] += 1
                    logger.debug(f"Notification sent to {user_id}")
                    
                except TelegramError as e:
                    results['failed'] += 1
                    results['errors'].append(f"User {user_id}: {str(e)}")
                    logger.error(f"Failed to send notification to {user_id}: {e}")
            
            # ثبت در تاریخچه
            self._log_notification('telegram', message, priority, results)
            
        except Exception as e:
            logger.error(f"Error in telegram notification: {e}")
            results['errors'].append(f"System error: {str(e)}")
        
        return results
    
    def send_email_notification(self, 
                               email_addresses: List[str], 
                               subject: str, 
                               message: str, 
                               priority: str = "normal") -> Dict:
        """ارسال اطلاع‌رسانی ایمیل"""
        results = {
            'sent': 0,
            'failed': 0,
            'errors': []
        }
        
        if not self.email_config['username'] or not self.email_config['password']:
            results['errors'].append("Email configuration not set")
            return results
        
        try:
            # ایجاد پیام ایمیل
            msg = MimeMultipart()
            msg['From'] = self.email_config['username']
            msg['Subject'] = f"[FlowAI - {priority.upper()}] {subject}"
            
            # فرمت کردن پیام
            html_message = f"""
            <html>
                <body>
                    <h2>FlowAI Trading Bot Notification</h2>
                    <p><strong>Priority:</strong> {priority.upper()}</p>
                    <p><strong>Time:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
                    <hr>
                    <div>{message.replace('\n', '<br>')}</div>
                    <hr>
                    <p><small>This is an automated message from FlowAI Trading Bot</small></p>
                </body>
            </html>
            """
            
            msg.attach(MimeText(html_message, 'html'))
            
            # اتصال به سرور SMTP
            server = smtplib.SMTP(self.email_config['smtp_server'], self.email_config['smtp_port'])
            server.starttls()
            server.login(self.email_config['username'], self.email_config['password'])
            
            # ارسال به هر ایمیل
            for email in email_addresses:
                try:
                    msg['To'] = email
                    text = msg.as_string()
                    server.sendmail(self.email_config['username'], email, text)
                    results['sent'] += 1
                    logger.debug(f"Email sent to {email}")
                    
                except Exception as e:
                    results['failed'] += 1
                    results['errors'].append(f"Email {email}: {str(e)}")
                    logger.error(f"Failed to send email to {email}: {e}")
            
            server.quit()
            
            # ثبت در تاریخچه
            self._log_notification('email', f"{subject}: {message}", priority, results)
            
        except Exception as e:
            logger.error(f"Error in email notification: {e}")
            results['errors'].append(f"System error: {str(e)}")
        
        return results
    
    def send_webhook_notification(self, 
                                webhook_url: str, 
                                data: Dict, 
                                priority: str = "normal") -> Dict:
        """ارسال اطلاع‌رسانی webhook"""
        results = {
            'sent': 0,
            'failed': 0,
            'errors': []
        }
        
        try:
            # اضافه کردن metadata
            payload = {
                'timestamp': datetime.now().isoformat(),
                'priority': priority,
                'source': 'FlowAI_Trading_Bot',
                'data': data
            }
            
            response = requests.post(
                webhook_url,
                json=payload,
                timeout=10,
                headers={'Content-Type': 'application/json'}
            )
            
            if response.status_code == 200:
                results['sent'] = 1
                logger.debug(f"Webhook sent successfully to {webhook_url}")
            else:
                results['failed'] = 1
                results['errors'].append(f"HTTP {response.status_code}: {response.text}")
                logger.error(f"Webhook failed: {response.status_code}")
            
            # ثبت در تاریخچه
            self._log_notification('webhook', str(data), priority, results)
            
        except Exception as e:
            results['failed'] = 1
            results['errors'].append(f"System error: {str(e)}")
            logger.error(f"Error in webhook notification: {e}")
        
        return results
    
    def send_multi_channel_notification(self, 
                                      message: str, 
                                      channels: Dict, 
                                      priority: str = "normal") -> Dict:
        """ارسال اطلاع‌رسانی چند کاناله"""
        results = {
            'telegram': {'sent': 0, 'failed': 0, 'errors': []},
            'email': {'sent': 0, 'failed': 0, 'errors': []},
            'webhook': {'sent': 0, 'failed': 0, 'errors': []},
            'total_sent': 0,
            'total_failed': 0
        }
        
        try:
            # ارسال تلگرام
            if 'telegram' in channels and channels['telegram']:
                telegram_result = self.send_telegram_notification(
                    channels['telegram'], message, priority
                )
                results['telegram'] = telegram_result
                results['total_sent'] += telegram_result['sent']
                results['total_failed'] += telegram_result['failed']
            
            # ارسال ایمیل
            if 'email' in channels and channels['email']:
                email_result = self.send_email_notification(
                    channels['email']['addresses'], 
                    channels['email']['subject'], 
                    message, 
                    priority
                )
                results['email'] = email_result
                results['total_sent'] += email_result['sent']
                results['total_failed'] += email_result['failed']
            
            # ارسال webhook
            if 'webhook' in channels and channels['webhook']:
                for webhook_url in channels['webhook']:
                    webhook_result = self.send_webhook_notification(
                        webhook_url, {'message': message}, priority
                    )
                    results['webhook']['sent'] += webhook_result['sent']
                    results['webhook']['failed'] += webhook_result['failed']
                    results['webhook']['errors'].extend(webhook_result['errors'])
                
                results['total_sent'] += results['webhook']['sent']
                results['total_failed'] += results['webhook']['failed']
            
            logger.info(f"Multi-channel notification: {results['total_sent']} sent, {results['total_failed']} failed")
            
        except Exception as e:
            logger.error(f"Error in multi-channel notification: {e}")
        
        return results
    
    def send_system_alert(self, 
                         alert_type: str, 
                         message: str, 
                         admin_only: bool = True) -> Dict:
        """ارسال هشدار سیستم"""
        try:
            priority = 'critical' if alert_type in ['error', 'critical'] else 'high'
            
            # فرمت کردن پیام هشدار
            alert_message = f"""
🚨 **هشدار سیستم FlowAI**

🔸 **نوع:** {alert_type.upper()}
🔸 **زمان:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

📝 **پیام:**
{message}

⚠️ این هشدار نیاز به بررسی فوری دارد.
"""
            
            # تعیین مخاطبان
            if admin_only:
                from .config import TELEGRAM_ADMIN_IDS
                recipients = TELEGRAM_ADMIN_IDS
            else:
                from .telegram.signal_manager import signal_manager
                recipients = list(signal_manager.subscribers['admin']) + list(signal_manager.subscribers['premium'])
            
            # ارسال هشدار
            result = self.send_telegram_notification(recipients, alert_message, priority)
            
            logger.warning(f"System alert sent: {alert_type} - {message}")
            return result
            
        except Exception as e:
            logger.error(f"Error sending system alert: {e}")
            return {'sent': 0, 'failed': 1, 'errors': [str(e)]}
    
    def _log_notification(self, channel: str, message: str, priority: str, results: Dict):
        """ثبت اطلاع‌رسانی در تاریخچه"""
        try:
            log_entry = {
                'timestamp': datetime.now().isoformat(),
                'channel': channel,
                'message': message[:100] + '...' if len(message) > 100 else message,
                'priority': priority,
                'sent': results['sent'],
                'failed': results['failed'],
                'success_rate': results['sent'] / (results['sent'] + results['failed']) if (results['sent'] + results['failed']) > 0 else 0
            }
            
            self.notification_history.append(log_entry)
            
            # نگهداری آخرین 1000 رکورد
            if len(self.notification_history) > 1000:
                self.notification_history.pop(0)
                
        except Exception as e:
            logger.error(f"Error logging notification: {e}")
    
    def get_notification_statistics(self) -> Dict:
        """دریافت آمار اطلاع‌رسانی‌ها"""
        try:
            if not self.notification_history:
                return {
                    'total_notifications': 0,
                    'success_rate': 0,
                    'channel_breakdown': {},
                    'priority_breakdown': {}
                }
            
            total = len(self.notification_history)
            total_sent = sum(n['sent'] for n in self.notification_history)
            total_failed = sum(n['failed'] for n in self.notification_history)
            success_rate = total_sent / (total_sent + total_failed) if (total_sent + total_failed) > 0 else 0
            
            # تفکیک بر اساس کانال
            channel_breakdown = {}
            for notification in self.notification_history:
                channel = notification['channel']
                if channel not in channel_breakdown:
                    channel_breakdown[channel] = {'count': 0, 'sent': 0, 'failed': 0}
                
                channel_breakdown[channel]['count'] += 1
                channel_breakdown[channel]['sent'] += notification['sent']
                channel_breakdown[channel]['failed'] += notification['failed']
            
            # تفکیک بر اساس اولویت
            priority_breakdown = {}
            for notification in self.notification_history:
                priority = notification['priority']
                if priority not in priority_breakdown:
                    priority_breakdown[priority] = {'count': 0, 'sent': 0, 'failed': 0}
                
                priority_breakdown[priority]['count'] += 1
                priority_breakdown[priority]['sent'] += notification['sent']
                priority_breakdown[priority]['failed'] += notification['failed']
            
            return {
                'total_notifications': total,
                'total_sent': total_sent,
                'total_failed': total_failed,
                'success_rate': success_rate,
                'channel_breakdown': channel_breakdown,
                'priority_breakdown': priority_breakdown,
                'recent_notifications': self.notification_history[-10:]  # آخرین 10 مورد
            }
            
        except Exception as e:
            logger.error(f"Error getting notification statistics: {e}")
            return {}

# Global instance
notification_system = NotificationSystem()

def send_telegram_alert(user_ids: List[int], message: str, priority: str = "normal") -> Dict:
    """ارسال هشدار تلگرام"""
    return notification_system.send_telegram_notification(user_ids, message, priority)

def send_system_alert(alert_type: str, message: str, admin_only: bool = True) -> Dict:
    """ارسال هشدار سیستم"""
    return notification_system.send_system_alert(alert_type, message, admin_only)

def send_multi_channel_alert(message: str, channels: Dict, priority: str = "normal") -> Dict:
    """ارسال هشدار چند کاناله"""
    return notification_system.send_multi_channel_notification(message, channels, priority)

def get_notification_stats() -> Dict:
    """دریافت آمار اطلاع‌رسانی‌ها"""
    return notification_system.get_notification_statistics()
