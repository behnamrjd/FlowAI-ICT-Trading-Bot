"""
FlowAI ICT Trading Bot ICT Analysis Module
Implements Inner Circle Trader (ICT) concepts and analysis
"""

import pandas as pd
import numpy as np
import logging
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime, timedelta
from . import config
from . import utils

# Setup logger
logger = logging.getLogger("FlowAI_Bot")

class ICTAnalysis:
    """
    Implements ICT (Inner Circle Trader) analysis concepts
    """
    
    def __init__(self):
        self.swing_lookback = config.ICT_SWING_LOOKBACK_PERIODS
        self.mss_lookback = config.ICT_MSS_SWING_LOOKBACK
        self.ob_min_body_ratio = config.ICT_OB_MIN_BODY_RATIO
        self.pd_array_lookback = config.ICT_PD_ARRAY_LOOKBACK_PERIODS
        self.retracement_levels = config.ICT_PD_RETRACEMENT_LEVELS
        
    def analyze_market_structure(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Comprehensive ICT market structure analysis
        """
        try:
            analysis = {
                'market_structure': self.detect_market_structure_shift(df),
                'order_blocks': self.identify_order_blocks(df),
                'fair_value_gaps': self.detect_fair_value_gaps(df),
                'liquidity_sweeps': self.detect_liquidity_sweeps(df),
                'premium_discount': self.analyze_premium_discount_arrays(df),
                'bias': self.determine_market_bias(df)
            }
            
            return analysis
            
        except Exception as e:
            logger.error(f"Error in ICT market structure analysis: {e}")
            return {}
    
    def detect_market_structure_shift(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Detect Market Structure Shifts (MSS) and Break of Structure (BOS)
        """
        try:
            # Detect swing points
            swing_points = utils.detect_swing_points(
                df['High'], df['Low'], self.swing_lookback
            )
            
            swing_highs = swing_points['swing_highs']
            swing_lows = swing_points['swing_lows']
            
            # Find recent swing points
            recent_highs = df[swing_highs].tail(self.mss_lookback)
            recent_lows = df[swing_lows].tail(self.mss_lookback)
            
            mss_signals = []
            
            # Check for bullish MSS (break above recent swing high)
            if len(recent_highs) > 0:
                last_swing_high = recent_highs['High'].iloc[-1]
                last_swing_high_time = recent_highs.index[-1]
                
                # Check if price has broken above this level
                recent_data = df[df.index > last_swing_high_time]
                if len(recent_data) > 0 and recent_data['High'].max() > last_swing_high:
                    mss_signals.append({
                        'type': 'bullish_mss',
                        'level': last_swing_high,
                        'time': last_swing_high_time,
                        'break_time': recent_data[recent_data['High'] > last_swing_high].index[0]
                    })
            
            # Check for bearish MSS (break below recent swing low)
            if len(recent_lows) > 0:
                last_swing_low = recent_lows['Low'].iloc[-1]
                last_swing_low_time = recent_lows.index[-1]
                
                # Check if price has broken below this level
                recent_data = df[df.index > last_swing_low_time]
                if len(recent_data) > 0 and recent_data['Low'].min() < last_swing_low:
                    mss_signals.append({
                        'type': 'bearish_mss',
                        'level': last_swing_low,
                        'time': last_swing_low_time,
                        'break_time': recent_data[recent_data['Low'] < last_swing_low].index[0]
                    })
            
            return {
                'mss_signals': mss_signals,
                'swing_highs': recent_highs,
                'swing_lows': recent_lows,
                'last_mss': mss_signals[-1] if mss_signals else None
            }
            
        except Exception as e:
            logger.error(f"Error detecting market structure shift: {e}")
            return {}
    
    def identify_order_blocks(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Identify Order Blocks (OB) - areas where institutions placed large orders
        """
        try:
            order_blocks = []
            
            # Look for strong directional moves
            for i in range(len(df) - 1):
                current = df.iloc[i]
                next_candle = df.iloc[i + 1]
                
                # Calculate body size
                current_body = abs(current['Close'] - current['Open'])
                current_range = current['High'] - current['Low']
                body_ratio = current_body / current_range if current_range > 0 else 0
                
                # Check for strong bullish candle (potential bearish OB above)
                if (next_candle['Close'] > current['High'] and 
                    body_ratio > self.ob_min_body_ratio and
                    current['Close'] > current['Open']):
                    
                    order_blocks.append({
                        'type': 'bearish_ob',
                        'high': current['High'],
                        'low': current['Open'],
                        'time': current.name,
                        'strength': body_ratio
                    })
                
                # Check for strong bearish candle (potential bullish OB below)
                elif (next_candle['Close'] < current['Low'] and 
                      body_ratio > self.ob_min_body_ratio and
                      current['Close'] < current['Open']):
                    
                    order_blocks.append({
                        'type': 'bullish_ob',
                        'high': current['Open'],
                        'low': current['Low'],
                        'time': current.name,
                        'strength': body_ratio
                    })
            
            # Keep only recent and untested order blocks
            recent_obs = order_blocks[-20:] if len(order_blocks) > 20 else order_blocks
            
            return recent_obs
            
        except Exception as e:
            logger.error(f"Error identifying order blocks: {e}")
            return []
    
    def detect_fair_value_gaps(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Detect Fair Value Gaps (FVG) - price gaps that need to be filled
        """
        try:
            fvgs = []
            
            for i in range(1, len(df) - 1):
                prev_candle = df.iloc[i - 1]
                current = df.iloc[i]
                next_candle = df.iloc[i + 1]
                
                # Bullish FVG: gap between prev low and next high
                if (prev_candle['Low'] > next_candle['High'] and
                    current['Close'] > current['Open']):
                    
                    gap_size = prev_candle['Low'] - next_candle['High']
                    gap_percentage = gap_size / current['Close'] * 100
                    
                    if gap_percentage > config.FVG_THRESHOLD:
                        fvgs.append({
                            'type': 'bullish_fvg',
                            'high': prev_candle['Low'],
                            'low': next_candle['High'],
                            'time': current.name,
                            'size': gap_size,
                            'percentage': gap_percentage,
                            'filled': False
                        })
                
                # Bearish FVG: gap between prev high and next low
                elif (prev_candle['High'] < next_candle['Low'] and
                      current['Close'] < current['Open']):
                    
                    gap_size = next_candle['Low'] - prev_candle['High']
                    gap_percentage = gap_size / current['Close'] * 100
                    
                    if gap_percentage > config.FVG_THRESHOLD:
                        fvgs.append({
                            'type': 'bearish_fvg',
                            'high': next_candle['Low'],
                            'low': prev_candle['High'],
                            'time': current.name,
                            'size': gap_size,
                            'percentage': gap_percentage,
                            'filled': False
                        })
            
            # Check which FVGs have been filled
            current_price = df['Close'].iloc[-1]
            for fvg in fvgs:
                if fvg['type'] == 'bullish_fvg':
                    fvg['filled'] = current_price <= fvg['low']
                else:
                    fvg['filled'] = current_price >= fvg['high']
            
            # Return only unfilled FVGs
            unfilled_fvgs = [fvg for fvg in fvgs if not fvg['filled']]
            
            return unfilled_fvgs[-10:]  # Keep last 10 unfilled FVGs
            
        except Exception as e:
            logger.error(f"Error detecting fair value gaps: {e}")
            return []
    
    def detect_liquidity_sweeps(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Detect liquidity sweeps - when price briefly breaks key levels to grab liquidity
        """
        try:
            sweeps = []
            
            # Get recent swing points
            swing_points = utils.detect_swing_points(df['High'], df['Low'], 5)
            swing_highs = df[swing_points['swing_highs']].tail(10)
            swing_lows = df[swing_points['swing_lows']].tail(10)
            
            # Check for liquidity sweeps above swing highs
            for idx, swing_high in swing_highs.iterrows():
                high_level = swing_high['High']
                
                # Look for price action after this swing high
                future_data = df[df.index > idx]
                
                for future_idx, candle in future_data.iterrows():
                    # Check if price swept above the high but closed back below
                    if (candle['High'] > high_level and 
                        candle['Close'] < high_level):
                        
                        sweeps.append({
                            'type': 'liquidity_sweep_high',
                            'level': high_level,
                            'sweep_time': future_idx,
                            'sweep_high': candle['High'],
                            'close': candle['Close'],
                            'original_time': idx
                        })
                        break
            
            # Check for liquidity sweeps below swing lows
            for idx, swing_low in swing_lows.iterrows():
                low_level = swing_low['Low']
                
                # Look for price action after this swing low
                future_data = df[df.index > idx]
                
                for future_idx, candle in future_data.iterrows():
                    # Check if price swept below the low but closed back above
                    if (candle['Low'] < low_level and 
                        candle['Close'] > low_level):
                        
                        sweeps.append({
                            'type': 'liquidity_sweep_low',
                            'level': low_level,
                            'sweep_time': future_idx,
                            'sweep_low': candle['Low'],
                            'close': candle['Close'],
                            'original_time': idx
                        })
                        break
            
            return sweeps[-5:]  # Return last 5 sweeps
            
        except Exception as e:
            logger.error(f"Error detecting liquidity sweeps: {e}")
            return []
    
    def analyze_premium_discount_arrays(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Analyze Premium and Discount arrays based on recent range
        """
        try:
            # Get recent high and low
            recent_data = df.tail(self.pd_array_lookback)
            range_high = recent_data['High'].max()
            range_low = recent_data['Low'].min()
            range_size = range_high - range_low
            
            if range_size == 0:
                return {}
            
            current_price = df['Close'].iloc[-1]
            
            # Calculate position in range (0 = low, 1 = high)
            position_in_range = (current_price - range_low) / range_size
            
            # Define premium/discount levels
            levels = {}
            for level in self.retracement_levels:
                price_level = range_low + (range_size * level)
                levels[f"{level:.1%}"] = price_level
            
            # Determine if in premium or discount
            if position_in_range > 0.5:
                array_type = "premium"
                bias = "bearish"
            else:
                array_type = "discount"
                bias = "bullish"
            
            return {
                'range_high': range_high,
                'range_low': range_low,
                'range_size': range_size,
                'current_price': current_price,
                'position_in_range': position_in_range,
                'array_type': array_type,
                'bias': bias,
                'levels': levels
            }
            
        except Exception as e:
            logger.error(f"Error analyzing premium/discount arrays: {e}")
            return {}
    
    def determine_market_bias(self, df: pd.DataFrame) -> str:
        """
        Determine overall market bias based on ICT concepts
        """
        try:
            # Analyze market structure
            mss = self.detect_market_structure_shift(df)
            
            # Check last MSS
            if mss.get('last_mss'):
                last_mss_type = mss['last_mss']['type']
                if 'bullish' in last_mss_type:
                    structure_bias = 'bullish'
                else:
                    structure_bias = 'bearish'
            else:
                structure_bias = 'neutral'
            
            # Analyze premium/discount
            pd_analysis = self.analyze_premium_discount_arrays(df)
            pd_bias = pd_analysis.get('bias', 'neutral')
            
            # Combine biases
            if structure_bias == pd_bias:
                overall_bias = structure_bias
            else:
                overall_bias = 'neutral'
            
            return overall_bias.upper()
            
        except Exception as e:
            logger.error(f"Error determining market bias: {e}")
            return 'NEUTRAL'
    
    def generate_ict_signals(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Generate trading signals based on ICT analysis
        """
        try:
            signals = []
            
            # Get comprehensive analysis
            analysis = self.analyze_market_structure(df)
            
            current_price = df['Close'].iloc[-1]
            current_time = df.index[-1]
            
            # Signal based on Order Block interaction
            order_blocks = analysis.get('order_blocks', [])
            for ob in order_blocks[-3:]:  # Check last 3 OBs
                if ob['type'] == 'bullish_ob':
                    if ob['low'] <= current_price <= ob['high']:
                        signals.append({
                            'type': 'BUY',
                            'reason': 'Bullish Order Block interaction',
                            'price': current_price,
                            'time': current_time,
                            'confidence': 0.7,
                            'stop_loss': ob['low'],
                            'take_profit': current_price + (current_price - ob['low']) * 2
                        })
                
                elif ob['type'] == 'bearish_ob':
                    if ob['low'] <= current_price <= ob['high']:
                        signals.append({
                            'type': 'SELL',
                            'reason': 'Bearish Order Block interaction',
                            'price': current_price,
                            'time': current_time,
                            'confidence': 0.7,
                            'stop_loss': ob['high'],
                            'take_profit': current_price - (ob['high'] - current_price) * 2
                        })
            
            # Signal based on FVG fill
            fvgs = analysis.get('fair_value_gaps', [])
            for fvg in fvgs[-2:]:  # Check last 2 FVGs
                if fvg['type'] == 'bullish_fvg':
                    if fvg['low'] <= current_price <= fvg['high']:
                        signals.append({
                            'type': 'BUY',
                            'reason': 'Bullish Fair Value Gap fill',
                            'price': current_price,
                            'time': current_time,
                            'confidence': 0.6,
                            'stop_loss': fvg['low'],
                            'take_profit': current_price + fvg['size']
                        })
                
                elif fvg['type'] == 'bearish_fvg':
                    if fvg['low'] <= current_price <= fvg['high']:
                        signals.append({
                            'type': 'SELL',
                            'reason': 'Bearish Fair Value Gap fill',
                            'price': current_price,
                            'time': current_time,
                            'confidence': 0.6,
                            'stop_loss': fvg['high'],
                            'take_profit': current_price - fvg['size']
                        })
            
            return signals
            
        except Exception as e:
            logger.error(f"Error generating ICT signals: {e}")
            return []

def analyze_htf_bias(htf_data: Dict[str, pd.DataFrame]) -> str:
    """
    Analyze Higher Time Frame bias using ICT concepts
    """
    try:
        ict_analyzer = ICTAnalysis()
        biases = []
        
        for timeframe, df in htf_data.items():
            if df.empty:
                continue
                
            # Get market structure analysis
            mss = ict_analyzer.detect_market_structure_shift(df)
            
            if mss.get('last_mss'):
                last_mss = mss['last_mss']
                mss_type = last_mss['type']
                mss_time = last_mss['time']
                mss_level = last_mss['level']
                
                # Determine bias based on MSS type
                if 'bullish' in mss_type:
                    bias = 'bullish'
                else:
                    bias = 'bearish'
                
                biases.append({
                    'timeframe': timeframe,
                    'bias': bias,
                    'mss_type': mss_type,
                    'level': mss_level,
                    'time': mss_time
                })
        
        if not biases:
            return 'NEUTRAL'
        
        # Determine overall bias
        bullish_count = sum(1 for b in biases if b['bias'] == 'bullish')
        bearish_count = sum(1 for b in biases if b['bias'] == 'bearish')
        
        if bullish_count > bearish_count:
            overall_bias = 'BULLISH'
        elif bearish_count > bullish_count:
            overall_bias = 'BEARISH'
        else:
            overall_bias = 'NEUTRAL'
        
        # Log HTF analysis
        bias_components = []
        for b in biases:
            bias_components.append(f"{b['timeframe']} Last MSS: {b['mss_type']} @ {b['level']:.2f} ({b['time'].strftime('%Y-%m-%d')})")
        
        logger.info(f"Overall HTF Bias: {overall_bias}. Components: {' | '.join(bias_components)}")
        
        return overall_bias
        
    except Exception as e:
        logger.error(f"Error analyzing HTF bias: {e}")
        return 'NEUTRAL'

def generate_ict_signals(df: pd.DataFrame, htf_bias: str) -> List[Dict[str, Any]]:
    """
    Generate ICT-based trading signals
    """
    try:
        ict_analyzer = ICTAnalysis()
        
        # Generate base ICT signals
        signals = ict_analyzer.generate_ict_signals(df)
        
        # Filter signals based on HTF bias
        filtered_signals = []
        
        for signal in signals:
            signal_type = signal['type']
            
            # Only take signals aligned with HTF bias
            if htf_bias == 'BULLISH' and signal_type == 'BUY':
                filtered_signals.append(signal)
            elif htf_bias == 'BEARISH' and signal_type == 'SELL':
                filtered_signals.append(signal)
            elif htf_bias == 'NEUTRAL':
                # In neutral bias, take all signals but with lower confidence
                signal['confidence'] *= 0.8
                filtered_signals.append(signal)
        
        if filtered_signals:
            logger.info(f"Generated {len(filtered_signals)} ICT signals aligned with {htf_bias} HTF bias")
        else:
            logger.info(f"No ICT signals generated after all checks (HTF Bias: {htf_bias})")
        
        return filtered_signals
        
    except Exception as e:
        logger.error(f"Error generating ICT signals: {e}")
        return []

# Create global instance
ict_analysis = ICTAnalysis()
