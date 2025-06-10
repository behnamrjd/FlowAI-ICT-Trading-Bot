import pandas as pd
import numpy as np
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from .ai_signal_engine import AISignalEngine
from .data_handler import get_processed_data
import json

logger = logging.getLogger(__name__)

class BacktestEngine:
    def __init__(self):
        self.ai_engine = AISignalEngine()
        self.results = {}
        
    def run_backtest(self, 
                    symbol: str = "GOLD",
                    start_date: str = "2024-01-01",
                    end_date: str = "2024-12-31",
                    initial_balance: float = 10000,
                    timeframe: str = "1h",
                    risk_per_trade: float = 0.02) -> Dict:
        """اجرای بک‌تست کامل"""
        
        try:
            logger.info(f"Starting backtest: {symbol} from {start_date} to {end_date}")
            
            # تولید داده‌های شبیه‌سازی شده
            data = self._generate_historical_data(start_date, end_date, timeframe)
            
            if data.empty:
                raise ValueError("No historical data available")
            
            # اجرای بک‌تست
            trades = []
            balance = initial_balance
            position = None
            equity_curve = []
            
            for i in range(50, len(data)):  # شروع از ایندکس 50 برای اندیکاتورها
                current_data = data.iloc[:i+1]
                current_price = data.iloc[i]['Close']
                current_time = data.index[i]
                
                # محاسبه اندیکاتورها
                indicators = self.ai_engine.calculate_technical_indicators(current_data)
                
                if not indicators:
                    continue
                
                # تولید سیگنال
                signal = self.ai_engine._analyze_market_conditions(indicators, force_analysis=True)
                
                # مدیریت موقعیت
                if position is None and signal and signal['confidence'] >= 0.6:
                    # ورود به معامله
                    if signal['action'] in ['BUY', 'SELL']:
                        position_size = (balance * risk_per_trade) / abs(current_price - signal['stop_loss'])
                        position_size = min(position_size, balance * 0.1)  # حداکثر 10% سرمایه
                        
                        position = {
                            'action': signal['action'],
                            'entry_price': current_price,
                            'entry_time': current_time,
                            'size': position_size,
                            'stop_loss': signal['stop_loss'],
                            'target_price': signal['target_price'],
                            'confidence': signal['confidence']
                        }
                        
                        logger.debug(f"Opened {signal['action']} position at {current_price}")
                
                elif position is not None:
                    # بررسی خروج از معامله
                    exit_triggered = False
                    exit_reason = ""
                    exit_price = current_price
                    
                    if position['action'] == 'BUY':
                        if current_price >= position['target_price']:
                            exit_triggered = True
                            exit_reason = "Target reached"
                            exit_price = position['target_price']
                        elif current_price <= position['stop_loss']:
                            exit_triggered = True
                            exit_reason = "Stop loss"
                            exit_price = position['stop_loss']
                    
                    elif position['action'] == 'SELL':
                        if current_price <= position['target_price']:
                            exit_triggered = True
                            exit_reason = "Target reached"
                            exit_price = position['target_price']
                        elif current_price >= position['stop_loss']:
                            exit_triggered = True
                            exit_reason = "Stop loss"
                            exit_price = position['stop_loss']
                    
                    if exit_triggered:
                        # محاسبه سود/ضرر
                        if position['action'] == 'BUY':
                            pnl = (exit_price - position['entry_price']) * position['size']
                        else:
                            pnl = (position['entry_price'] - exit_price) * position['size']
                        
                        balance += pnl
                        
                        trade = {
                            'entry_time': position['entry_time'],
                            'exit_time': current_time,
                            'action': position['action'],
                            'entry_price': position['entry_price'],
                            'exit_price': exit_price,
                            'size': position['size'],
                            'pnl': pnl,
                            'pnl_percent': (pnl / (position['entry_price'] * position['size'])) * 100,
                            'exit_reason': exit_reason,
                            'confidence': position['confidence']
                        }
                        
                        trades.append(trade)
                        position = None
                        
                        logger.debug(f"Closed position: PnL = {pnl:.2f}")
                
                # ثبت equity curve
                equity_curve.append({
                    'time': current_time,
                    'balance': balance,
                    'price': current_price
                })
            
            # محاسبه آمار نهایی
            results = self._calculate_statistics(trades, initial_balance, balance, equity_curve)
            
            self.results = {
                'parameters': {
                    'symbol': symbol,
                    'start_date': start_date,
                    'end_date': end_date,
                    'initial_balance': initial_balance,
                    'timeframe': timeframe,
                    'risk_per_trade': risk_per_trade
                },
                'trades': trades,
                'statistics': results,
                'equity_curve': equity_curve,
                'timestamp': datetime.now()
            }
            
            logger.info(f"Backtest completed: {len(trades)} trades, Final balance: {balance:.2f}")
            return self.results
            
        except Exception as e:
            logger.error(f"Backtest error: {e}")
            raise
    
    def _generate_historical_data(self, start_date: str, end_date: str, timeframe: str) -> pd.DataFrame:
        """تولید داده‌های تاریخی شبیه‌سازی شده"""
        
        start = datetime.strptime(start_date, "%Y-%m-%d")
        end = datetime.strptime(end_date, "%Y-%m-%d")
        
        # تولید تاریخ‌ها
        if timeframe == "1h":
            freq = "1H"
        elif timeframe == "4h":
            freq = "4H"
        elif timeframe == "1d":
            freq = "1D"
        else:
            freq = "1H"
        
        dates = pd.date_range(start=start, end=end, freq=freq)
        
        # تولید قیمت‌های شبیه‌سازی شده (Random Walk با Trend)
        np.random.seed(42)  # برای تکرارپذیری
        
        base_price = 3300  # قیمت پایه طلا
        returns = np.random.normal(0.0001, 0.02, len(dates))  # بازده‌های تصادفی
        
        # اضافه کردن trend
        trend = np.linspace(0, 0.1, len(dates))
        returns += trend / len(dates)
        
        prices = [base_price]
        for ret in returns[1:]:
            new_price = prices[-1] * (1 + ret)
            prices.append(new_price)
        
        # تولید OHLC
        data = []
        for i, price in enumerate(prices):
            volatility = np.random.uniform(0.005, 0.02)
            
            open_price = price * (1 + np.random.uniform(-volatility/2, volatility/2))
            close_price = price * (1 + np.random.uniform(-volatility/2, volatility/2))
            high_price = max(open_price, close_price) * (1 + np.random.uniform(0, volatility))
            low_price = min(open_price, close_price) * (1 - np.random.uniform(0, volatility))
            volume = np.random.randint(1000, 10000)
            
            data.append({
                'Open': open_price,
                'High': high_price,
                'Low': low_price,
                'Close': close_price,
                'Volume': volume
            })
        
        df = pd.DataFrame(data, index=dates)
        return df
    
    def _calculate_statistics(self, trades: List[Dict], initial_balance: float, 
                            final_balance: float, equity_curve: List[Dict]) -> Dict:
        """محاسبه آمار عملکرد"""
        
        if not trades:
            return {
                'total_trades': 0,
                'winning_trades': 0,
                'losing_trades': 0,
                'win_rate': 0,
                'total_pnl': 0,
                'total_return': 0,
                'max_drawdown': 0,
                'profit_factor': 0,
                'sharpe_ratio': 0,
                'avg_win': 0,
                'avg_loss': 0,
                'largest_win': 0,
                'largest_loss': 0
            }
        
        # آمار پایه
        total_trades = len(trades)
        winning_trades = len([t for t in trades if t['pnl'] > 0])
        losing_trades = len([t for t in trades if t['pnl'] < 0])
        win_rate = (winning_trades / total_trades) * 100 if total_trades > 0 else 0
        
        # سود/ضرر
        total_pnl = sum(t['pnl'] for t in trades)
        total_return = ((final_balance - initial_balance) / initial_balance) * 100
        
        # محاسبه drawdown
        balances = [eq['balance'] for eq in equity_curve]
        peak = balances[0]
        max_drawdown = 0
        
        for balance in balances:
            if balance > peak:
                peak = balance
            drawdown = ((peak - balance) / peak) * 100
            max_drawdown = max(max_drawdown, drawdown)
        
        # Profit Factor
        gross_profit = sum(t['pnl'] for t in trades if t['pnl'] > 0)
        gross_loss = abs(sum(t['pnl'] for t in trades if t['pnl'] < 0))
        profit_factor = gross_profit / gross_loss if gross_loss > 0 else 0
        
        # Sharpe Ratio (ساده شده)
        returns = [t['pnl_percent'] for t in trades]
        if len(returns) > 1:
            avg_return = np.mean(returns)
            std_return = np.std(returns)
            sharpe_ratio = avg_return / std_return if std_return > 0 else 0
        else:
            sharpe_ratio = 0
        
        # آمار معاملات
        winning_pnls = [t['pnl'] for t in trades if t['pnl'] > 0]
        losing_pnls = [t['pnl'] for t in trades if t['pnl'] < 0]
        
        avg_win = np.mean(winning_pnls) if winning_pnls else 0
        avg_loss = np.mean(losing_pnls) if losing_pnls else 0
        largest_win = max(winning_pnls) if winning_pnls else 0
        largest_loss = min(losing_pnls) if losing_pnls else 0
        
        return {
            'total_trades': total_trades,
            'winning_trades': winning_trades,
            'losing_trades': losing_trades,
            'win_rate': win_rate,
            'total_pnl': total_pnl,
            'total_return': total_return,
            'max_drawdown': max_drawdown,
            'profit_factor': profit_factor,
            'sharpe_ratio': sharpe_ratio,
            'avg_win': avg_win,
            'avg_loss': avg_loss,
            'largest_win': largest_win,
            'largest_loss': largest_loss,
            'gross_profit': gross_profit,
            'gross_loss': gross_loss
        }
    
    def export_results(self, format: str = "json") -> str:
        """صادرات نتایج"""
        if not self.results:
            raise ValueError("No backtest results available")
        
        if format == "json":
            # تبدیل datetime به string برای JSON
            results_copy = self.results.copy()
            results_copy['timestamp'] = results_copy['timestamp'].isoformat()
            
            for trade in results_copy['trades']:
                trade['entry_time'] = trade['entry_time'].isoformat()
                trade['exit_time'] = trade['exit_time'].isoformat()
            
            for eq in results_copy['equity_curve']:
                eq['time'] = eq['time'].isoformat()
            
            return json.dumps(results_copy, indent=2, ensure_ascii=False)
        
        elif format == "summary":
            stats = self.results['statistics']
            params = self.results['parameters']
            
            summary = f"""
📊 **گزارش بک‌تست FlowAI**

⚙️ **پارامترها:**
🔹 نماد: {params['symbol']}
🔹 تاریخ: {params['start_date']} تا {params['end_date']}
🔹 سرمایه اولیه: ${params['initial_balance']:,.0f}
🔹 تایم فریم: {params['timeframe']}
🔹 ریسک هر معامله: {params['risk_per_trade']:.1%}

📈 **نتایج کلی:**
🔹 تعداد معاملات: {stats['total_trades']}
🔹 معاملات سودآور: {stats['winning_trades']} ({stats['win_rate']:.1f}%)
🔹 معاملات ضررده: {stats['losing_trades']}
🔹 سود کل: ${stats['total_pnl']:,.2f} ({stats['total_return']:+.1f}%)

📊 **آمار عملکرد:**
🔹 حداکثر ضرر: {stats['max_drawdown']:.1f}%
🔹 ضریب سود: {stats['profit_factor']:.2f}
🔹 نسبت شارپ: {stats['sharpe_ratio']:.2f}
🔹 میانگین سود: ${stats['avg_win']:,.2f}
🔹 میانگین ضرر: ${stats['avg_loss']:,.2f}
🔹 بزرگترین سود: ${stats['largest_win']:,.2f}
🔹 بزرگترین ضرر: ${stats['largest_loss']:,.2f}

⏰ **تاریخ گزارش:** {self.results['timestamp'].strftime('%Y-%m-%d %H:%M:%S')}
"""
            return summary
        
        else:
            raise ValueError(f"Unsupported format: {format}")

# Global instance
backtest_engine = BacktestEngine()

def run_backtest_analysis(symbol: str = "GOLD", 
                         start_date: str = "2024-01-01",
                         end_date: str = "2024-12-31",
                         initial_balance: float = 10000,
                         timeframe: str = "1h",
                         risk_per_trade: float = 0.02) -> Dict:
    """تابع global برای اجرای بک‌تست"""
    return backtest_engine.run_backtest(
        symbol=symbol,
        start_date=start_date,
        end_date=end_date,
        initial_balance=initial_balance,
        timeframe=timeframe,
        risk_per_trade=risk_per_trade
    )

def get_backtest_summary() -> str:
    """دریافت خلاصه آخرین بک‌تست"""
    return backtest_engine.export_results("summary")
