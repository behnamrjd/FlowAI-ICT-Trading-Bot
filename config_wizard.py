#!/usr/bin/env python3
"""
FlowAI Configuration Wizard - Standalone Script
Interactive backtest configuration with proper input handling
"""
import sys
import os

# اضافه کردن مسیر پروژه
sys.path.append('.')
sys.path.append('./flow_ai_core')

try:
    from flow_ai_core.backtest_engine import SmartBacktestConfig
except ImportError as e:
    print(f"❌ خطا در import: {e}")
    print("🔧 در حال تلاش برای import مستقیم...")
    
    # تلاش مستقیم
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "backtest_engine", 
        "./flow_ai_core/backtest_engine.py"
    )
    backtest_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(backtest_module)
    SmartBacktestConfig = backtest_module.SmartBacktestConfig

def main():
    """تابع اصلی ویزارد تنظیمات"""
    try:
        print("🚀 شروع ویزارد تنظیمات FlowAI...")
        
        # راه‌اندازی ویزارد تنظیمات
        config_wizard = SmartBacktestConfig()
        user_config = config_wizard.interactive_configuration()
        
        # نمایش خلاصه و تأیید
        if config_wizard.display_configuration_summary(user_config):
            # ذخیره تنظیمات
            if config_wizard.save_configuration(user_config):
                print('\n✅ تنظیمات با موفقیت ذخیره شد!')
                print('📁 فایل: advanced_backtest_config.json')
                return True
            else:
                print('\n❌ خطا در ذخیره تنظیمات')
                return False
        else:
            print('\n❌ تنظیمات لغو شد')
            return False
            
    except KeyboardInterrupt:
        print('\n\n❌ عملیات لغو شد توسط کاربر')
        return False
    except Exception as e:
        print(f'\n❌ خطا: {e}')
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = main()
    if success:
        print("\n🎯 ویزارد تنظیمات با موفقیت تکمیل شد!")
    else:
        print("\n⚠️ ویزارد تنظیمات ناتمام ماند.")
    
    # پایان
    input("\nPress Enter to continue...")
