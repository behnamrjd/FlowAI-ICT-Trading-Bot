#!/usr/bin/env python3
"""
FlowAI Configuration Wizard - Standalone Script
"""
import sys
sys.path.append('.')

from flow_ai_core.backtest_engine import SmartBacktestConfig

if __name__ == "__main__":
    try:
        # راه‌اندازی ویزارد تنظیمات
        config_wizard = SmartBacktestConfig()
        user_config = config_wizard.interactive_configuration()
        
        # نمایش خلاصه و تأیید
        if config_wizard.display_configuration_summary(user_config):
            # ذخیره تنظیمات
            if config_wizard.save_configuration(user_config):
                print('\n✅ تنظیمات با موفقیت ذخیره شد!')
                print('📁 فایل: advanced_backtest_config.json')
            else:
                print('\n❌ خطا در ذخیره تنظیمات')
        else:
            print('\n❌ تنظیمات لغو شد')
            
    except KeyboardInterrupt:
        print('\n\n❌ عملیات لغو شد توسط کاربر')
    except Exception as e:
        print(f'\n❌ خطا: {e}')
