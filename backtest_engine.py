#!/usr/bin/env python3
"""
FlowAI Advanced Backtesting Engine v3.0
Smart configuration with defaults and user customization
Author: Behnam RJD
"""

import pandas as pd
import numpy as np
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import warnings
warnings.filterwarnings('ignore')

logger = logging.getLogger(__name__)

class SmartBacktestConfig:
    """Smart configuration system with defaults and explanations"""
    
    def __init__(self):
        self.defaults = {
            'risk_management': {
                'position_sizing': {
                    'default': 'percentage',
                    'value': 2.0,
                    'description': 'روش تعیین سایز معامله',
                    'explanation': '2% از سرمایه برای هر معامله (محافظه‌کارانه و ایمن)',
                    'options': {
                        'percentage': '2% از سرمایه (پیشنهادی)',
                        'fixed_amount': 'مبلغ ثابت ($1000)',
                        'kelly_criterion': 'Kelly Criterion (ریاضی پیشرفته)',
                        'volatility_adjusted': 'تنظیم با نوسان بازار'
                    }
                },
                'stop_loss': {
                    'default': 'atr_multiple',
                    'value': 2.0,
                    'description': 'روش تعیین حد ضرر',
                    'explanation': '2 برابر ATR (تنظیم خودکار با نوسان بازار)',
                    'options': {
                        'atr_multiple': '2×ATR (پیشنهادی - تطبیقی)',
                        'fixed_percentage': '2% ثابت',
                        'trailing_stop': 'Stop Loss دنبال‌کننده',
                        'support_resistance': 'بر اساس سطوح فنی'
                    }
                },
                'take_profit': {
                    'default': 'risk_reward_ratio',
                    'value': 3.0,
                    'description': 'روش تعیین حد سود',
                    'explanation': '3 برابر ریسک (نسبت ریسک به بازده 1:3)',
                    'options': {
                        'risk_reward_ratio': '1:3 ریسک به بازده (پیشنهادی)',
                        'fixed_percentage': '6% ثابت',
                        'atr_multiple': '4×ATR',
                        'resistance_levels': 'بر اساس مقاومت‌ها'
                    }
                }
            },
            'market_conditions': {
                'volatility_filter': {
                    'default': 'all_conditions',
                    'value': None,
                    'description': 'فیلتر شرایط نوسان بازار',
                    'explanation': 'همه شرایط (برای تست کامل استراتژی)',
                    'options': {
                        'all_conditions': 'همه شرایط (پیشنهادی)',
                        'low_vol': 'فقط نوسان کم (محافظه‌کارانه)',
                        'high_vol': 'فقط نوسان بالا (تهاجمی)',
                        'medium_vol': 'نوسان متوسط (متعادل)'
                    }
                },
                'trading_sessions': {
                    'default': 'overlap_london_us',
                    'value': '13:00-16:00',
                    'description': 'ساعات فعال معاملاتی',
                    'explanation': 'تداخل لندن-آمریکا (بیشترین نقدینگی و حرکت)',
                    'options': {
                        'overlap_london_us': '13:00-16:00 UTC (پیشنهادی)',
                        'london': '08:00-16:00 UTC (جلسه لندن)',
                        'us': '13:00-21:00 UTC (جلسه آمریکا)',
                        'asian': '20:00-02:00 UTC (جلسه آسیا)',
                        'all_sessions': '24 ساعته'
                    }
                },
                'trend_filter': {
                    'default': 'all_trends',
                    'value': None,
                    'description': 'فیلتر جهت روند بازار',
                    'explanation': 'همه جهات روند (تست کامل)',
                    'options': {
                        'all_trends': 'همه جهات روند (پیشنهادی)',
                        'uptrend_only': 'فقط روند صعودی',
                        'downtrend_only': 'فقط روند نزولی',
                        'sideways_only': 'فقط بازار خنثی'
                    }
                }
            },
            'ai_model': {
                'confidence_threshold': {
                    'default': 'moderate',
                    'value': 0.7,
                    'description': 'آستانه اطمینان مدل AI',
                    'explanation': '70% اطمینان (تعادل بین کیفیت و تعداد سیگنال)',
                    'options': {
                        'moderate': '70% اطمینان (پیشنهادی)',
                        'conservative': '85% اطمینان (کمتر اما دقیق‌تر)',
                        'aggressive': '60% اطمینان (بیشتر اما ریسکی‌تر)',
                        'custom': 'مقدار دلخواه'
                    }
                },
                'signal_filter': {
                    'default': 'all_signals',
                    'value': None,
                    'description': 'فیلتر نوع سیگنال‌ها',
                    'explanation': 'همه سیگنال‌ها (BUY, SELL, STRONG_BUY, STRONG_SELL)',
                    'options': {
                        'all_signals': 'همه سیگنال‌ها (پیشنهادی)',
                        'strong_only': 'فقط سیگنال‌های قوی',
                        'buy_only': 'فقط سیگنال‌های خرید',
                        'sell_only': 'فقط سیگنال‌های فروش'
                    }
                }
            },
            'transaction_costs': {
                'commission': {
                    'default': 'percentage_based',
                    'value': 0.1,
                    'description': 'کمیسیون معاملات',
                    'explanation': '0.1% هر معامله (متوسط کارگزاری‌های معتبر)',
                    'options': {
                        'percentage_based': '0.1% هر معامله (پیشنهادی)',
                        'fixed_per_trade': '$5 ثابت هر معامله',
                        'zero_commission': 'بدون کمیسیون',
                        'custom': 'مقدار دلخواه'
                    }
                },
                'slippage': {
                    'default': 'volatility_based',
                    'value': 0.05,
                    'description': 'لغزش قیمت هنگام اجرا',
                    'explanation': 'تنظیم خودکار با نوسان (واقع‌گرایانه‌تر)',
                    'options': {
                        'volatility_based': 'تنظیم با نوسان (پیشنهادی)',
                        'fixed_percentage': '0.05% ثابت',
                        'volume_based': 'بر اساس حجم معامله',
                        'zero_slippage': 'بدون لغزش (غیرواقعی)'
                    }
                }
            },
            'backtest_period': {
                'duration': {
                    'default': '3_months',
                    'value': 90,
                    'description': 'مدت زمان بک‌تست',
                    'explanation': '3 ماه گذشته (تعادل بین داده کافی و relevance)',
                    'options': {
                        '1_month': '1 ماه گذشته',
                        '3_months': '3 ماه گذشته (پیشنهادی)',
                        '6_months': '6 ماه گذشته',
                        '1_year': '1 سال گذشته',
                        'custom': 'بازه دلخواه'
                    }
                },
                'frequency': {
                    'default': 'weekly',
                    'value': 'weekly',
                    'description': 'تکرار خودکار بک‌تست',
                    'explanation': 'هفتگی (بررسی منظم عملکرد)',
                    'options': {
                        'daily': 'روزانه',
                        'weekly': 'هفتگی (پیشنهادی)',
                        'monthly': 'ماهانه',
                        'manual': 'دستی'
                    }
                }
            }
        }
    
    def interactive_configuration(self):
        """تنظیمات تعاملی با توضیحات و پیش‌فرض‌ها"""
        
        print("🎯 FlowAI Smart Backtest Configuration")
        print("=" * 60)
        print("💡 برای استفاده از تنظیم پیشنهادی، Enter بزنید")
        print("🔧 برای تغییر، شماره گزینه مورد نظر را وارد کنید")
        print("=" * 60)
        
        config = {}
        
        # Risk Management Section
        config['risk_management'] = self._configure_section(
            'risk_management', 
            "🛡️ مدیریت ریسک"
        )
        
        # Market Conditions Section  
        config['market_conditions'] = self._configure_section(
            'market_conditions',
            "📊 شرایط بازار"
        )
        
        # AI Model Section
        config['ai_model'] = self._configure_section(
            'ai_model',
            "🤖 تنظیمات مدل هوش مصنوعی"
        )
        
        # Transaction Costs Section
        config['transaction_costs'] = self._configure_section(
            'transaction_costs',
            "💰 هزینه‌های معاملاتی"
        )
        
        # Backtest Period Section
        config['backtest_period'] = self._configure_section(
            'backtest_period',
            "📅 دوره بک‌تست"
        )
        
        return config
    
    def _configure_section(self, section_name, section_title):
        """تنظیم هر بخش با نمایش توضیحات"""
        
        print(f"\n{section_title}")
        print("-" * 40)
        
        section_config = {}
        section_defaults = self.defaults[section_name]
        
        for param_name, param_data in section_defaults.items():
            section_config[param_name] = self._configure_parameter(
                param_name, param_data
            )
        
        return section_config
    
    def _configure_parameter(self, param_name, param_data):
        """تنظیم هر پارامتر با نمایش گزینه‌ها"""
        
        print(f"\n📋 {param_data['description']}:")
        print(f"💡 توضیح: {param_data['explanation']}")
        print(f"⭐ پیشنهادی: {param_data['options'][param_data['default']]}")
        
        print("\n🔧 گزینه‌های موجود:")
        options_list = list(param_data['options'].items())
        
        for i, (key, description) in enumerate(options_list, 1):
            marker = "⭐" if key == param_data['default'] else "  "
            print(f"{marker} {i}. {description}")
        
        while True:
            user_input = input(f"\nانتخاب شما (Enter برای پیشنهادی): ").strip()
            
            # استفاده از پیش‌فرض
            if not user_input:
                selected_key = param_data['default']
                selected_value = param_data['value']
                print(f"✅ انتخاب شد: {param_data['options'][selected_key]}")
                break
            
            # انتخاب کاربر
            try:
                choice_index = int(user_input) - 1
                if 0 <= choice_index < len(options_list):
                    selected_key = options_list[choice_index][0]
                    
                    # اگر custom انتخاب شد، مقدار بپرس
                    if selected_key == 'custom':
                        selected_value = self._get_custom_value(param_name, param_data)
                    else:
                        selected_value = param_data['value']
                    
                    print(f"✅ انتخاب شد: {param_data['options'][selected_key]}")
                    break
                else:
                    print("❌ شماره نامعتبر! دوباره تلاش کنید.")
            except ValueError:
                print("❌ لطفاً شماره معتبر وارد کنید!")
        
        return {
            'method': selected_key,
            'value': selected_value,
            'description': param_data['options'][selected_key]
        }
    
    def _get_custom_value(self, param_name, param_data):
        """دریافت مقدار سفارشی از کاربر"""
        
        while True:
            try:
                if 'percentage' in param_name or 'threshold' in param_name:
                    value = float(input("مقدار درصد (0-100): ")) / 100
                    if 0 <= value <= 1:
                        return value
                    else:
                        print("❌ مقدار باید بین 0 تا 100 باشد!")
                
                elif 'amount' in param_name:
                    value = float(input("مبلغ ($): "))
                    if value > 0:
                        return value
                    else:
                        print("❌ مبلغ باید مثبت باشد!")
                
                elif 'duration' in param_name:
                    value = int(input("تعداد روز: "))
                    if value > 0:
                        return value
                    else:
                        print("❌ تعداد روز باید مثبت باشد!")
                
                else:
                    value = float(input("مقدار: "))
                    return value
                    
            except ValueError:
                print("❌ لطفاً عدد معتبر وارد کنید!")
    
    def display_configuration_summary(self, config):
        """نمایش خلاصه تنظیمات انتخاب شده"""
        
        print("\n" + "=" * 60)
        print("📋 خلاصه تنظیمات بک‌تست FlowAI")
        print("=" * 60)
        
        print("\n🛡️ مدیریت ریسک:")
        risk = config['risk_management']
        print(f"  • سایز معامله: {risk['position_sizing']['description']}")
        print(f"  • حد ضرر: {risk['stop_loss']['description']}")
        print(f"  • حد سود: {risk['take_profit']['description']}")
        
        print("\n📊 شرایط بازار:")
        market = config['market_conditions']
        print(f"  • فیلتر نوسان: {market['volatility_filter']['description']}")
        print(f"  • ساعات معاملاتی: {market['trading_sessions']['description']}")
        print(f"  • فیلتر روند: {market['trend_filter']['description']}")
        
        print("\n🤖 مدل هوش مصنوعی:")
        ai = config['ai_model']
        print(f"  • آستانه اطمینان: {ai['confidence_threshold']['description']}")
        print(f"  • فیلتر سیگنال: {ai['signal_filter']['description']}")
        
        print("\n💰 هزینه‌های معاملاتی:")
        costs = config['transaction_costs']
        print(f"  • کمیسیون: {costs['commission']['description']}")
        print(f"  • لغزش: {costs['slippage']['description']}")
        
        print("\n📅 دوره بک‌تست:")
        period = config['backtest_period']
        print(f"  • مدت زمان: {period['duration']['description']}")
        print(f"  • تکرار: {period['frequency']['description']}")
        
        print("\n" + "=" * 60)
        
        confirm = input("آیا این تنظیمات را تأیید می‌کنید؟ (y/N): ")
        return confirm.lower() in ['y', 'yes', 'بله']
    
    def save_configuration(self, config, filename='advanced_backtest_config.json'):
        """ذخیره تنظیمات در فایل"""
        try:
            config['created_at'] = datetime.now().isoformat()
            config['version'] = '3.0'
            
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Configuration saved to {filename}")
            return True
        except Exception as e:
            logger.error(f"Failed to save configuration: {e}")
            return False
    
    def load_configuration(self, filename='advanced_backtest_config.json'):
        """بارگذاری تنظیمات از فایل"""
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                config = json.load(f)
            
            logger.info(f"Configuration loaded from {filename}")
            return config
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            return None

if __name__ == "__main__":
    # تست سیستم تنظیمات
    config_wizard = SmartBacktestConfig()
    user_config = config_wizard.interactive_configuration()
    
    if config_wizard.display_configuration_summary(user_config):
        config_wizard.save_configuration(user_config)
        print("\n✅ تنظیمات با موفقیت ذخیره شد!")
    else:
        print("\n❌ تنظیمات لغو شد")
