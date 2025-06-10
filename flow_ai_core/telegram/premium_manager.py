import logging
from datetime import datetime, timedelta
from typing import Dict, List, Set
from telegram import Update, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import CallbackContext
from ..config import TELEGRAM_PREMIUM_USERS, TELEGRAM_ADMIN_IDS
from .signal_manager import signal_manager
import json
import os

logger = logging.getLogger(__name__)

class PremiumManager:
    def __init__(self):
        self.premium_users = set(TELEGRAM_PREMIUM_USERS)
        self.premium_history = []
        self.data_file = "premium_users.json"
        self.load_premium_data()
        
    def load_premium_data(self):
        """بارگذاری داده‌های کاربران پریمیوم"""
        try:
            if os.path.exists(self.data_file):
                with open(self.data_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    self.premium_users = set(data.get('users', []))
                    self.premium_history = data.get('history', [])
                    logger.info(f"Loaded {len(self.premium_users)} premium users")
        except Exception as e:
            logger.error(f"Error loading premium data: {e}")
    
    def save_premium_data(self):
        """ذخیره داده‌های کاربران پریمیوم"""
        try:
            data = {
                'users': list(self.premium_users),
                'history': self.premium_history,
                'last_updated': datetime.now().isoformat()
            }
            with open(self.data_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            logger.info("Premium data saved successfully")
        except Exception as e:
            logger.error(f"Error saving premium data: {e}")
    
    def is_premium(self, user_id: int) -> bool:
        """بررسی پریمیوم بودن کاربر"""
        return user_id in self.premium_users
    
    def add_premium_user(self, user_id: int, admin_id: int, duration_days: int = 30) -> bool:
        """اضافه کردن کاربر پریمیوم"""
        try:
            if user_id not in self.premium_users:
                self.premium_users.add(user_id)
                
                # اضافه کردن به سیستم سیگنال
                signal_manager.add_subscriber(user_id, 'premium')
                
                # ثبت در تاریخچه
                self.premium_history.append({
                    'user_id': user_id,
                    'action': 'added',
                    'admin_id': admin_id,
                    'timestamp': datetime.now().isoformat(),
                    'duration_days': duration_days,
                    'expires_at': (datetime.now() + timedelta(days=duration_days)).isoformat()
                })
                
                self.save_premium_data()
                logger.info(f"User {user_id} added to premium by admin {admin_id}")
                return True
            else:
                logger.warning(f"User {user_id} is already premium")
                return False
                
        except Exception as e:
            logger.error(f"Error adding premium user {user_id}: {e}")
            return False
    
    def remove_premium_user(self, user_id: int, admin_id: int) -> bool:
        """حذف کاربر پریمیوم"""
        try:
            if user_id in self.premium_users:
                self.premium_users.discard(user_id)
                
                # حذف از سیستم سیگنال پریمیوم و اضافه به رایگان
                signal_manager.remove_subscriber(user_id, 'premium')
                signal_manager.add_subscriber(user_id, 'free')
                
                # ثبت در تاریخچه
                self.premium_history.append({
                    'user_id': user_id,
                    'action': 'removed',
                    'admin_id': admin_id,
                    'timestamp': datetime.now().isoformat()
                })
                
                self.save_premium_data()
                logger.info(f"User {user_id} removed from premium by admin {admin_id}")
                return True
            else:
                logger.warning(f"User {user_id} is not premium")
                return False
                
        except Exception as e:
            logger.error(f"Error removing premium user {user_id}: {e}")
            return False
    
    def get_premium_statistics(self) -> Dict:
        """دریافت آمار کاربران پریمیوم"""
        total_premium = len(self.premium_users)
        
        # آمار تاریخچه
        recent_additions = len([h for h in self.premium_history 
                               if h['action'] == 'added' and 
                               datetime.fromisoformat(h['timestamp']) > datetime.now() - timedelta(days=30)])
        
        recent_removals = len([h for h in self.premium_history 
                              if h['action'] == 'removed' and 
                              datetime.fromisoformat(h['timestamp']) > datetime.now() - timedelta(days=30)])
        
        return {
            'total_premium_users': total_premium,
            'recent_additions': recent_additions,
            'recent_removals': recent_removals,
            'total_history_entries': len(self.premium_history),
            'premium_users_list': list(self.premium_users)
        }
    
    def get_user_management_keyboard(self):
        """کیبورد مدیریت کاربران"""
        keyboard = [
            [
                InlineKeyboardButton("➕ اضافه کردن کاربر", callback_data="add_premium_user"),
                InlineKeyboardButton("➖ حذف کاربر", callback_data="remove_premium_user")
            ],
            [
                InlineKeyboardButton("📋 لیست کاربران", callback_data="list_premium_users"),
                InlineKeyboardButton("📊 آمار کاربران", callback_data="premium_statistics")
            ],
            [
                InlineKeyboardButton("📜 تاریخچه", callback_data="premium_history"),
                InlineKeyboardButton("💾 پشتیبان‌گیری", callback_data="backup_premium_data")
            ],
            [
                InlineKeyboardButton("🔙 بازگشت", callback_data="main_menu")
            ]
        ]
        return InlineKeyboardMarkup(keyboard)
    
    def format_premium_list(self, page: int = 0, page_size: int = 10) -> str:
        """فرمت کردن لیست کاربران پریمیوم"""
        if not self.premium_users:
            return "📋 **لیست کاربران پریمیوم**\n\nهیچ کاربر پریمیومی وجود ندارد."
        
        users_list = list(self.premium_users)
        total_users = len(users_list)
        total_pages = (total_users + page_size - 1) // page_size
        
        start_idx = page * page_size
        end_idx = min(start_idx + page_size, total_users)
        page_users = users_list[start_idx:end_idx]
        
        text = f"📋 **لیست کاربران پریمیوم**\n\n"
        text += f"📊 **آمار:** {total_users} کاربر پریمیوم\n"
        text += f"📄 **صفحه:** {page + 1} از {total_pages}\n\n"
        
        for i, user_id in enumerate(page_users, start=start_idx + 1):
            text += f"{i}. `{user_id}`\n"
        
        return text
    
    def format_premium_history(self, limit: int = 20) -> str:
        """فرمت کردن تاریخچه کاربران پریمیوم"""
        if not self.premium_history:
            return "📜 **تاریخچه کاربران پریمیوم**\n\nتاریخچه‌ای وجود ندارد."
        
        # مرتب‌سازی بر اساس زمان (جدیدترین اول)
        sorted_history = sorted(self.premium_history, 
                               key=lambda x: x['timestamp'], 
                               reverse=True)[:limit]
        
        text = f"📜 **تاریخچه کاربران پریمیوم**\n\n"
        text += f"📊 **نمایش:** {len(sorted_history)} مورد از {len(self.premium_history)}\n\n"
        
        for entry in sorted_history:
            action_emoji = "➕" if entry['action'] == 'added' else "➖"
            timestamp = datetime.fromisoformat(entry['timestamp'])
            
            text += f"{action_emoji} **{entry['action'].title()}**\n"
            text += f"👤 کاربر: `{entry['user_id']}`\n"
            text += f"👨‍💼 ادمین: `{entry['admin_id']}`\n"
            text += f"⏰ زمان: {timestamp.strftime('%Y-%m-%d %H:%M')}\n"
            
            if 'duration_days' in entry:
                text += f"📅 مدت: {entry['duration_days']} روز\n"
            
            text += "\n"
        
        return text

# Global instance
premium_manager = PremiumManager()

def is_user_premium(user_id: int) -> bool:
    """بررسی پریمیوم بودن کاربر"""
    return premium_manager.is_premium(user_id)

def add_premium_user(user_id: int, admin_id: int, duration_days: int = 30) -> bool:
    """اضافه کردن کاربر پریمیوم"""
    return premium_manager.add_premium_user(user_id, admin_id, duration_days)

def remove_premium_user(user_id: int, admin_id: int) -> bool:
    """حذف کاربر پریمیوم"""
    return premium_manager.remove_premium_user(user_id, admin_id)

def get_premium_stats() -> Dict:
    """دریافت آمار کاربران پریمیوم"""
    return premium_manager.get_premium_statistics()
