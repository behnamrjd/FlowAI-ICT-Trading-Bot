import logging
from typing import Dict, Optional, List
from datetime import datetime, timedelta
import numpy as np

logger = logging.getLogger(__name__)

class RiskManager:
    def __init__(self):
        self.max_daily_loss = 0.05  # 5% حداکثر ضرر روزانه
        self.max_position_size = 0.1  # 10% حداکثر اندازه موقعیت
        self.max_drawdown = 0.15  # 15% حداکثر drawdown
        self.daily_pnl = 0
        self.daily_trades = 0
        self.max_daily_trades = 20
        self.equity_curve = []
        self.last_reset = datetime.now().date()
        
    def reset_daily_counters(self):
        """ریست کردن شمارنده‌های روزانه"""
        today = datetime.now().date()
        if today != self.last_reset:
            self.daily_pnl = 0
            self.daily_trades = 0
            self.last_reset = today
            logger.info("Daily risk counters reset")
    
    def calculate_position_size(self, 
                               balance: float,
                               entry_price: float,
                               stop_loss: float,
                               risk_per_trade: float = 0.02) -> float:
        """محاسبه اندازه موقعیت بر اساس ریسک"""
        
        try:
            # ریسک بر اساس stop loss
            risk_amount = balance * risk_per_trade
            price_risk = abs(entry_price - stop_loss)
            
            if price_risk == 0:
                return 0
            
            # محاسبه اندازه موقعیت
            position_size = risk_amount / price_risk
            
            # اعمال محدودیت حداکثر اندازه موقعیت
            max_position_value = balance * self.max_position_size
            max_position_size = max_position_value / entry_price
            
            position_size = min(position_size, max_position_size)
            
            logger.debug(f"Calculated position size: {position_size:.4f}")
            return position_size
            
        except Exception as e:
            logger.error(f"Error calculating position size: {e}")
            return 0
    
    def check_daily_limits(self, balance: float) -> Dict[str, bool]:
        """بررسی محدودیت‌های روزانه"""
        self.reset_daily_counters()
        
        checks = {
            'daily_loss_ok': True,
            'daily_trades_ok': True,
            'can_trade': True
        }
        
        # بررسی ضرر روزانه
        daily_loss_percent = abs(self.daily_pnl / balance) if balance > 0 else 0
        if self.daily_pnl < 0 and daily_loss_percent >= self.max_daily_loss:
            checks['daily_loss_ok'] = False
            checks['can_trade'] = False
            logger.warning(f"Daily loss limit reached: {daily_loss_percent:.2%}")
        
        # بررسی تعداد معاملات روزانه
        if self.daily_trades >= self.max_daily_trades:
            checks['daily_trades_ok'] = False
            checks['can_trade'] = False
            logger.warning(f"Daily trades limit reached: {self.daily_trades}")
        
        return checks
    
    def check_drawdown(self, current_balance: float, initial_balance: float) -> bool:
        """بررسی drawdown"""
        if initial_balance <= 0:
            return True
        
        drawdown = (initial_balance - current_balance) / initial_balance
        
        if drawdown >= self.max_drawdown:
            logger.warning(f"Maximum drawdown reached: {drawdown:.2%}")
            return False
        
        return True
    
    def validate_trade(self, 
                      signal: Dict,
                      balance: float,
                      initial_balance: float,
                      current_positions: int = 0) -> Dict:
        """اعتبارسنجی کامل معامله"""
        
        validation = {
            'approved': False,
            'reasons': [],
            'position_size': 0,
            'adjusted_signal': signal.copy()
        }
        
        try:
            # بررسی محدودیت‌های روزانه
            daily_checks = self.check_daily_limits(balance)
            if not daily_checks['can_trade']:
                validation['reasons'].append("Daily limits exceeded")
                return validation
            
            # بررسی drawdown
            if not self.check_drawdown(balance, initial_balance):
                validation['reasons'].append("Maximum drawdown exceeded")
                return validation
            
            # بررسی کیفیت سیگنال
            if signal['confidence'] < 0.6:
                validation['reasons'].append("Signal confidence too low")
                return validation
            
            # محاسبه اندازه موقعیت
            position_size = self.calculate_position_size(
                balance=balance,
                entry_price=signal['entry_price'],
                stop_loss=signal['stop_loss'],
                risk_per_trade=0.02
            )
            
            if position_size <= 0:
                validation['reasons'].append("Invalid position size")
                return validation
            
            # بررسی حداقل اندازه موقعیت
            min_position_value = 100  # حداقل $100
            if position_size * signal['entry_price'] < min_position_value:
                validation['reasons'].append("Position size too small")
                return validation
            
            # تنظیم stop loss و take profit بهینه
            optimized_signal = self.optimize_exit_levels(signal, balance)
            
            validation['approved'] = True
            validation['position_size'] = position_size
            validation['adjusted_signal'] = optimized_signal
            
            logger.info(f"Trade validated: {signal['action']} with size {position_size:.4f}")
            
        except Exception as e:
            logger.error(f"Error validating trade: {e}")
            validation['reasons'].append(f"Validation error: {str(e)}")
        
        return validation
    
    def optimize_exit_levels(self, signal: Dict, balance: float) -> Dict:
        """بهینه‌سازی سطوح خروج"""
        optimized = signal.copy()
        
        try:
            entry_price = signal['entry_price']
            current_sl = signal['stop_loss']
            current_tp = signal['target_price']
            
            # محاسبه ATR تقریبی (Average True Range)
            atr_percent = 0.015  # 1.5% تقریبی برای طلا
            atr_value = entry_price * atr_percent
            
            if signal['action'] == 'BUY':
                # بهینه‌سازی stop loss
                optimal_sl = entry_price - (2 * atr_value)
                optimized['stop_loss'] = max(optimal_sl, current_sl)
                
                # بهینه‌سازی take profit (Risk:Reward = 1:2)
                risk = entry_price - optimized['stop_loss']
                optimal_tp = entry_price + (2 * risk)
                optimized['target_price'] = min(optimal_tp, current_tp * 1.1)  # حداکثر 10% بیشتر
                
            elif signal['action'] == 'SELL':
                # بهینه‌سازی stop loss
                optimal_sl = entry_price + (2 * atr_value)
                optimized['stop_loss'] = min(optimal_sl, current_sl)
                
                # بهینه‌سازی take profit
                risk = optimized['stop_loss'] - entry_price
                optimal_tp = entry_price - (2 * risk)
                optimized['target_price'] = max(optimal_tp, current_tp * 0.9)  # حداکثر 10% کمتر
            
            logger.debug(f"Exit levels optimized: SL={optimized['stop_loss']:.2f}, TP={optimized['target_price']:.2f}")
            
        except Exception as e:
            logger.error(f"Error optimizing exit levels: {e}")
        
        return optimized
    
    def update_trade_result(self, pnl: float):
        """به‌روزرسانی نتیجه معامله"""
        self.reset_daily_counters()
        self.daily_pnl += pnl
        self.daily_trades += 1
        
        # به‌روزرسانی equity curve
        self.equity_curve.append({
            'timestamp': datetime.now(),
            'pnl': pnl,
            'daily_pnl': self.daily_pnl,
            'daily_trades': self.daily_trades
        })
        
        # نگهداری آخرین 1000 رکورد
        if len(self.equity_curve) > 1000:
            self.equity_curve.pop(0)
        
        logger.info(f"Trade result updated: PnL={pnl:.2f}, Daily PnL={self.daily_pnl:.2f}")
    
    def get_risk_statistics(self) -> Dict:
        """دریافت آمار ریسک"""
        self.reset_daily_counters()
        
        # محاسبه آمار از equity curve
        if len(self.equity_curve) >= 2:
            recent_pnls = [eq['pnl'] for eq in self.equity_curve[-30:]]  # آخرین 30 معامله
            win_rate = len([p for p in recent_pnls if p > 0]) / len(recent_pnls) * 100
            avg_win = np.mean([p for p in recent_pnls if p > 0]) if any(p > 0 for p in recent_pnls) else 0
            avg_loss = np.mean([p for p in recent_pnls if p < 0]) if any(p < 0 for p in recent_pnls) else 0
            profit_factor = abs(sum(p for p in recent_pnls if p > 0) / sum(p for p in recent_pnls if p < 0)) if any(p < 0 for p in recent_pnls) else 0
        else:
            win_rate = 0
            avg_win = 0
            avg_loss = 0
            profit_factor = 0
        
        return {
            'daily_pnl': self.daily_pnl,
            'daily_trades': self.daily_trades,
            'max_daily_trades': self.max_daily_trades,
            'max_daily_loss_percent': self.max_daily_loss * 100,
            'max_position_size_percent': self.max_position_size * 100,
            'max_drawdown_percent': self.max_drawdown * 100,
            'recent_win_rate': win_rate,
            'recent_avg_win': avg_win,
            'recent_avg_loss': avg_loss,
            'recent_profit_factor': profit_factor,
            'total_trades_recorded': len(self.equity_curve)
        }

# Global instance
risk_manager = RiskManager()

def validate_trading_signal(signal: Dict, balance: float, initial_balance: float) -> Dict:
    """اعتبارسنجی سیگنال معاملاتی"""
    return risk_manager.validate_trade(signal, balance, initial_balance)

def calculate_safe_position_size(balance: float, entry_price: float, stop_loss: float) -> float:
    """محاسبه اندازه موقعیت ایمن"""
    return risk_manager.calculate_position_size(balance, entry_price, stop_loss)

def update_trade_pnl(pnl: float):
    """به‌روزرسانی نتیجه معامله"""
    risk_manager.update_trade_result(pnl)

def get_risk_status() -> Dict:
    """دریافت وضعیت ریسک"""
    return risk_manager.get_risk_statistics()
