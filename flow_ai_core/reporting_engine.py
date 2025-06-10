import pandas as pd
import numpy as np
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import json
import os
from .backtest_engine import backtest_engine
from .telegram.signal_manager import signal_manager
from .risk_manager import risk_manager

logger = logging.getLogger(__name__)

class ReportingEngine:
    def __init__(self):
        self.reports_dir = "reports"
        self.ensure_reports_directory()
        
    def ensure_reports_directory(self):
        """اطمینان از وجود پوشه گزارش‌ها"""
        if not os.path.exists(self.reports_dir):
            os.makedirs(self.reports_dir)
            logger.info("Reports directory created")
    
    def generate_daily_report(self) -> Dict:
        """تولید گزارش روزانه"""
        try:
            today = datetime.now().date()
            
            # آمار سیگنال‌ها
            signal_stats = signal_manager.get_signal_statistics()
            
            # آمار ریسک
            risk_stats = risk_manager.get_risk_statistics()
            
            # آمار بک‌تست (اگر موجود باشد)
            backtest_stats = {}
            if backtest_engine.results:
                backtest_stats = backtest_engine.results.get('statistics', {})
            
            report = {
                'date': today.isoformat(),
                'timestamp': datetime.now().isoformat(),
                'signal_statistics': signal_stats,
                'risk_statistics': risk_stats,
                'backtest_statistics': backtest_stats,
                'system_status': self._get_system_status(),
                'performance_metrics': self._calculate_performance_metrics()
            }
            
            # ذخیره گزارش
            filename = f"{self.reports_dir}/daily_report_{today.strftime('%Y%m%d')}.json"
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(report, f, ensure_ascii=False, indent=2)
            
            logger.info(f"Daily report generated: {filename}")
            return report
            
        except Exception as e:
            logger.error(f"Error generating daily report: {e}")
            return {}
    
    def generate_weekly_report(self) -> Dict:
        """تولید گزارش هفتگی"""
        try:
            end_date = datetime.now().date()
            start_date = end_date - timedelta(days=7)
            
            # جمع‌آوری گزارش‌های روزانه
            daily_reports = []
            for i in range(7):
                date = start_date + timedelta(days=i)
                filename = f"{self.reports_dir}/daily_report_{date.strftime('%Y%m%d')}.json"
                
                if os.path.exists(filename):
                    try:
                        with open(filename, 'r', encoding='utf-8') as f:
                            daily_reports.append(json.load(f))
                    except Exception as e:
                        logger.warning(f"Could not load daily report {filename}: {e}")
            
            # تجمیع آمار هفتگی
            weekly_stats = self._aggregate_weekly_stats(daily_reports)
            
            report = {
                'week_start': start_date.isoformat(),
                'week_end': end_date.isoformat(),
                'timestamp': datetime.now().isoformat(),
                'daily_reports_count': len(daily_reports),
                'weekly_statistics': weekly_stats,
                'trends': self._analyze_weekly_trends(daily_reports),
                'recommendations': self._generate_recommendations(weekly_stats)
            }
            
            # ذخیره گزارش هفتگی
            filename = f"{self.reports_dir}/weekly_report_{end_date.strftime('%Y%m%d')}.json"
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(report, f, ensure_ascii=False, indent=2)
            
            logger.info(f"Weekly report generated: {filename}")
            return report
            
        except Exception as e:
            logger.error(f"Error generating weekly report: {e}")
            return {}
    
    def _get_system_status(self) -> Dict:
        """دریافت وضعیت سیستم"""
        return {
            'signal_monitoring_active': signal_manager.running,
            'api_status': 'active',  # باید از BrsAPI بررسی شود
            'last_signal_time': signal_manager.signal_history[-1]['sent_time'].isoformat() if signal_manager.signal_history else None,
            'subscribers_count': {
                'admin': len(signal_manager.subscribers['admin']),
                'premium': len(signal_manager.subscribers['premium']),
                'free': len(signal_manager.subscribers['free'])
            }
        }
    
    def _calculate_performance_metrics(self) -> Dict:
        """محاسبه متریک‌های عملکرد"""
        try:
            # متریک‌های سیگنال
            if signal_manager.signal_history:
                signals = [s['signal'] for s in signal_manager.signal_history]
                
                total_signals = len(signals)
                buy_signals = len([s for s in signals if s['action'] == 'BUY'])
                sell_signals = len([s for s in signals if s['action'] == 'SELL'])
                avg_confidence = np.mean([s['confidence'] for s in signals])
                
                # محاسبه توزیع اعتماد
                confidence_distribution = {
                    'high_confidence': len([s for s in signals if s['confidence'] >= 0.8]),
                    'medium_confidence': len([s for s in signals if 0.6 <= s['confidence'] < 0.8]),
                    'low_confidence': len([s for s in signals if s['confidence'] < 0.6])
                }
            else:
                total_signals = buy_signals = sell_signals = 0
                avg_confidence = 0
                confidence_distribution = {'high_confidence': 0, 'medium_confidence': 0, 'low_confidence': 0}
            
            return {
                'signal_metrics': {
                    'total_signals': total_signals,
                    'buy_signals': buy_signals,
                    'sell_signals': sell_signals,
                    'buy_sell_ratio': buy_signals / max(sell_signals, 1),
                    'average_confidence': avg_confidence,
                    'confidence_distribution': confidence_distribution
                },
                'system_uptime': '99.9%',  # باید واقعی محاسبه شود
                'response_time': '< 1s',   # باید واقعی محاسبه شود
            }
            
        except Exception as e:
            logger.error(f"Error calculating performance metrics: {e}")
            return {}
    
    def _aggregate_weekly_stats(self, daily_reports: List[Dict]) -> Dict:
        """تجمیع آمار هفتگی"""
        if not daily_reports:
            return {}
        
        try:
            # تجمیع آمار سیگنال‌ها
            total_signals = sum(r.get('signal_statistics', {}).get('total_signals', 0) for r in daily_reports)
            total_buy = sum(r.get('signal_statistics', {}).get('buy_signals', 0) for r in daily_reports)
            total_sell = sum(r.get('signal_statistics', {}).get('sell_signals', 0) for r in daily_reports)
            
            # میانگین اعتماد
            confidences = []
            for r in daily_reports:
                if r.get('signal_statistics', {}).get('avg_confidence'):
                    confidences.append(r['signal_statistics']['avg_confidence'])
            
            avg_confidence = np.mean(confidences) if confidences else 0
            
            # تجمیع آمار ریسک
            daily_pnls = [r.get('risk_statistics', {}).get('daily_pnl', 0) for r in daily_reports]
            total_pnl = sum(daily_pnls)
            
            return {
                'signals': {
                    'total': total_signals,
                    'buy': total_buy,
                    'sell': total_sell,
                    'daily_average': total_signals / len(daily_reports),
                    'avg_confidence': avg_confidence
                },
                'risk': {
                    'total_pnl': total_pnl,
                    'daily_average_pnl': total_pnl / len(daily_reports),
                    'profitable_days': len([pnl for pnl in daily_pnls if pnl > 0]),
                    'losing_days': len([pnl for pnl in daily_pnls if pnl < 0])
                },
                'system': {
                    'active_days': len(daily_reports),
                    'total_days': 7,
                    'uptime_percentage': (len(daily_reports) / 7) * 100
                }
            }
            
        except Exception as e:
            logger.error(f"Error aggregating weekly stats: {e}")
            return {}
    
    def _analyze_weekly_trends(self, daily_reports: List[Dict]) -> Dict:
        """تحلیل روندهای هفتگی"""
        if len(daily_reports) < 2:
            return {}
        
        try:
            # روند تعداد سیگنال‌ها
            signal_counts = [r.get('signal_statistics', {}).get('total_signals', 0) for r in daily_reports]
            signal_trend = 'increasing' if signal_counts[-1] > signal_counts[0] else 'decreasing'
            
            # روند اعتماد
            confidences = [r.get('signal_statistics', {}).get('avg_confidence', 0) for r in daily_reports if r.get('signal_statistics', {}).get('avg_confidence')]
            confidence_trend = 'improving' if len(confidences) >= 2 and confidences[-1] > confidences[0] else 'declining'
            
            # روند PnL
            pnls = [r.get('risk_statistics', {}).get('daily_pnl', 0) for r in daily_reports]
            pnl_trend = 'improving' if pnls[-1] > pnls[0] else 'declining'
            
            return {
                'signal_count_trend': signal_trend,
                'confidence_trend': confidence_trend,
                'pnl_trend': pnl_trend,
                'volatility': np.std(signal_counts) if signal_counts else 0,
                'consistency_score': self._calculate_consistency_score(daily_reports)
            }
            
        except Exception as e:
            logger.error(f"Error analyzing weekly trends: {e}")
            return {}
    
    def _calculate_consistency_score(self, daily_reports: List[Dict]) -> float:
        """محاسبه امتیاز ثبات"""
        try:
            if len(daily_reports) < 3:
                return 0.5
            
            # بررسی ثبات در تولید سیگنال
            signal_counts = [r.get('signal_statistics', {}).get('total_signals', 0) for r in daily_reports]
            signal_consistency = 1 - (np.std(signal_counts) / max(np.mean(signal_counts), 1))
            
            # بررسی ثبات در کیفیت سیگنال
            confidences = [r.get('signal_statistics', {}).get('avg_confidence', 0) for r in daily_reports if r.get('signal_statistics', {}).get('avg_confidence')]
            confidence_consistency = 1 - (np.std(confidences) / max(np.mean(confidences), 1)) if confidences else 0.5
            
            # امتیاز کلی
            consistency_score = (signal_consistency + confidence_consistency) / 2
            return max(0, min(1, consistency_score))
            
        except Exception as e:
            logger.error(f"Error calculating consistency score: {e}")
            return 0.5
    
    def _generate_recommendations(self, weekly_stats: Dict) -> List[str]:
        """تولید توصیه‌ها بر اساس آمار"""
        recommendations = []
        
        try:
            signals = weekly_stats.get('signals', {})
            risk = weekly_stats.get('risk', {})
            
            # توصیه‌های مربوط به سیگنال
            if signals.get('daily_average', 0) < 2:
                recommendations.append("تعداد سیگنال‌های روزانه کم است. بررسی تنظیمات حساسیت AI")
            
            if signals.get('avg_confidence', 0) < 0.7:
                recommendations.append("میانگین اعتماد سیگنال‌ها پایین است. بهینه‌سازی الگوریتم تشخیص")
            
            # توصیه‌های مربوط به ریسک
            if risk.get('losing_days', 0) > risk.get('profitable_days', 0):
                recommendations.append("تعداد روزهای ضررده بیشتر از سودآور است. بررسی استراتژی ریسک")
            
            if risk.get('total_pnl', 0) < 0:
                recommendations.append("PnL کلی منفی است. نیاز به بازبینی کامل استراتژی")
            
            # توصیه‌های مربوط به سیستم
            system = weekly_stats.get('system', {})
            if system.get('uptime_percentage', 0) < 95:
                recommendations.append("درصد فعالیت سیستم کمتر از 95% است. بررسی پایداری سیستم")
            
            if not recommendations:
                recommendations.append("عملکرد سیستم در حد مطلوب است. ادامه نظارت توصیه می‌شود")
            
        except Exception as e:
            logger.error(f"Error generating recommendations: {e}")
            recommendations.append("خطا در تولید توصیه‌ها")
        
        return recommendations
    
    def export_report_to_text(self, report: Dict, report_type: str = "daily") -> str:
        """صادرات گزارش به متن"""
        try:
            if report_type == "daily":
                return self._format_daily_report_text(report)
            elif report_type == "weekly":
                return self._format_weekly_report_text(report)
            else:
                return "نوع گزارش نامشخص"
                
        except Exception as e:
            logger.error(f"Error exporting report to text: {e}")
            return f"خطا در صادرات گزارش: {str(e)}"
    
    def _format_daily_report_text(self, report: Dict) -> str:
        """فرمت کردن گزارش روزانه"""
        signal_stats = report.get('signal_statistics', {})
        risk_stats = report.get('risk_statistics', {})
        system_status = report.get('system_status', {})
        
        text = f"""
📊 **گزارش روزانه FlowAI**
📅 تاریخ: {report.get('date', 'نامشخص')}

🚨 **آمار سیگنال‌ها:**
🔹 کل سیگنال‌ها: {signal_stats.get('total_signals', 0)}
🔹 سیگنال‌های خرید: {signal_stats.get('buy_signals', 0)}
🔹 سیگنال‌های فروش: {signal_stats.get('sell_signals', 0)}
🔹 میانگین اعتماد: {signal_stats.get('avg_confidence', 0):.1%}

⚠️ **آمار ریسک:**
🔹 PnL روزانه: ${risk_stats.get('daily_pnl', 0):.2f}
🔹 تعداد معاملات: {risk_stats.get('daily_trades', 0)}
🔹 نرخ برد اخیر: {risk_stats.get('recent_win_rate', 0):.1f}%

🤖 **وضعیت سیستم:**
🔹 نظارت فعال: {'✅' if system_status.get('signal_monitoring_active') else '❌'}
🔹 کاربران پریمیوم: {system_status.get('subscribers_count', {}).get('premium', 0)}
🔹 کاربران رایگان: {system_status.get('subscribers_count', {}).get('free', 0)}

⏰ آخرین به‌روزرسانی: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
        return text
    
    def _format_weekly_report_text(self, report: Dict) -> str:
        """فرمت کردن گزارش هفتگی"""
        weekly_stats = report.get('weekly_statistics', {})
        trends = report.get('trends', {})
        recommendations = report.get('recommendations', [])
        
        text = f"""
📈 **گزارش هفتگی FlowAI**
📅 هفته: {report.get('week_start')} تا {report.get('week_end')}

📊 **خلاصه هفتگی:**
🔹 کل سیگنال‌ها: {weekly_stats.get('signals', {}).get('total', 0)}
🔹 میانگین روزانه: {weekly_stats.get('signals', {}).get('daily_average', 0):.1f}
🔹 میانگین اعتماد: {weekly_stats.get('signals', {}).get('avg_confidence', 0):.1%}

💰 **عملکرد مالی:**
🔹 PnL کل: ${weekly_stats.get('risk', {}).get('total_pnl', 0):.2f}
🔹 روزهای سودآور: {weekly_stats.get('risk', {}).get('profitable_days', 0)}
🔹 روزهای ضررده: {weekly_stats.get('risk', {}).get('losing_days', 0)}

📈 **روندها:**
🔹 روند سیگنال‌ها: {trends.get('signal_count_trend', 'نامشخص')}
🔹 روند اعتماد: {trends.get('confidence_trend', 'نامشخص')}
🔹 امتیاز ثبات: {trends.get('consistency_score', 0):.1%}

💡 **توصیه‌ها:**
"""
        for i, rec in enumerate(recommendations, 1):
            text += f"{i}. {rec}\n"
        
        text += f"\n⏰ تاریخ تولید: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        
        return text

# Global instance
reporting_engine = ReportingEngine()

def generate_daily_report() -> Dict:
    """تولید گزارش روزانه"""
    return reporting_engine.generate_daily_report()

def generate_weekly_report() -> Dict:
    """تولید گزارش هفتگی"""
    return reporting_engine.generate_weekly_report()

def export_daily_report_text() -> str:
    """صادرات گزارش روزانه به متن"""
    report = generate_daily_report()
    return reporting_engine.export_report_to_text(report, "daily")

def export_weekly_report_text() -> str:
    """صادرات گزارش هفتگی به متن"""
    report = generate_weekly_report()
    return reporting_engine.export_report_to_text(report, "weekly")
