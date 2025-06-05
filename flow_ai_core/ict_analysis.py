import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Tuple 

# Use relative imports for modules within the same package
from .utils import logger
from . import config


# --- Helper Functions for ICT Elements ---
def identify_swing_points(df: pd.DataFrame, lookback: int = -1) -> pd.DataFrame:
    # Use config default if lookback not provided or explicitly set to -1
    _lookback = lookback if lookback != -1 else config.ICT_SWING_LOOKBACK_PERIODS
    
    df_out = df.copy()
    df_out['Swing_High'] = False
    df_out['Swing_Low'] = False
    
    # Ensure lookback is feasible with data length
    required_len = 2 * _lookback + 1
    if len(df_out) < required_len:
        # logger.debug(f"Not enough data ({len(df_out)}) for swing points with lookback {_lookback}. Min required: {required_len}")
        return df_out 

    for i in range(_lookback, len(df_out) - _lookback):
        is_sh = all(df_out['High'].iloc[i] >= df_out['High'].iloc[i-j] for j in range(1, _lookback + 1)) and \
                all(df_out['High'].iloc[i] > df_out['High'].iloc[i+j] for j in range(1, _lookback + 1)) # Stricter on right side for typical definition
        # Or allow equals on both sides then filter for unique highs if multiple candles have same high
        if is_sh: 
            # Ensure it's a strict peak if allowing equals on left side
            is_strict_peak_sh = True
            for j in range(1, _lookback + 1):
                if df_out['High'].iloc[i] == df_out['High'].iloc[i-j] and i-j > 0 and df_out['High'].iloc[i] <= df_out['High'].iloc[i-j-1]: # if equal, check if previous was lower
                    is_strict_peak_sh = False; break
                if df_out['High'].iloc[i] == df_out['High'].iloc[i+j] and i+j < len(df_out)-1 and df_out['High'].iloc[i] <= df_out['High'].iloc[i+j+1]:
                    is_strict_peak_sh = False; break
            if is_strict_peak_sh:
                df_out.loc[df_out.index[i], 'Swing_High'] = True


        is_sl = all(df_out['Low'].iloc[i] <= df_out['Low'].iloc[i-j] for j in range(1, _lookback + 1)) and \
                all(df_out['Low'].iloc[i] < df_out['Low'].iloc[i+j] for j in range(1, _lookback + 1))
        if is_sl:
            is_strict_peak_sl = True
            for j in range(1, _lookback + 1):
                if df_out['Low'].iloc[i] == df_out['Low'].iloc[i-j] and i-j > 0 and df_out['Low'].iloc[i] >= df_out['Low'].iloc[i-j-1]:
                    is_strict_peak_sl = False; break
                if df_out['Low'].iloc[i] == df_out['Low'].iloc[i+j] and i+j < len(df_out)-1 and df_out['Low'].iloc[i] >= df_out['Low'].iloc[i+j+1]:
                    is_strict_peak_sl = False; break
            if is_strict_peak_sl:
                 df_out.loc[df_out.index[i], 'Swing_Low'] = True
    # logger.debug(f"Identified {df_out['Swing_High'].sum()} SHs and {df_out['Swing_Low'].sum()} SLs with lookback {_lookback}.")
    return df_out

def identify_order_blocks(df_with_swings: pd.DataFrame, 
                          min_body_ratio: float = -1.0 # Default to use config
                         ) -> List[Dict]:
    _min_body_ratio = min_body_ratio if min_body_ratio != -1.0 else config.ICT_OB_MIN_BODY_RATIO
    order_blocks = []
    if len(df_with_swings) < 3: return order_blocks # Need current, next, and ideally one before context
    df = df_with_swings # Alias for brevity

    for i in range(1, len(df) - 1): # Iterate leaving space for next candle
        current_candle = df.iloc[i]
        # prev_candle = df.iloc[i-1] # For context if needed later (e.g. swept liquidity before OB)
        next_candle = df.iloc[i+1]
        
        candle_range = current_candle['High'] - current_candle['Low']
        if candle_range == 0: continue # Avoid division by zero for candles with no range

        body_size = abs(current_candle['Close'] - current_candle['Open'])
        body_ratio = body_size / candle_range
        
        # Basic displacement check: next candle's body should be decent and move strongly
        next_candle_body = abs(next_candle['Close'] - next_candle['Open'])
        # avg_body_lookback = 10
        # avg_body_size = df['Close'].rolling(window=avg_body_lookback).apply(lambda x: abs(x.iloc[-1] - x.iloc[0]), raw=True).shift(1).iloc[i] # Avg body of prev N
        # if pd.isna(avg_body_size): avg_body_size = body_size # fallback

        ob_details = {
            'timestamp': df.index[i], 
            'ob_top': current_candle['High'], 
            'ob_bottom': current_candle['Low'], 
            'ob_midpoint': (current_candle['High'] + current_candle['Low']) / 2,
            'open': current_candle['Open'], 'close': current_candle['Close'], 
            'body_ratio': round(body_ratio, 3)
        }

        # Bullish OB: Current is down-candle, next is strong up-move
        if current_candle['Open'] > current_candle['Close']: # Down-close candle
            if body_ratio >= _min_body_ratio: # OB candidate must have some body
                # Displacement: next candle is bullish, closes above OB's high, and has a decent body itself
                if next_candle['Close'] > next_candle['Open'] and \
                   next_candle['Close'] > current_candle['High'] and \
                   next_candle_body > candle_range * 0.3: # Next candle body is at least 30% of OB's range (heuristic)
                    order_blocks.append({**ob_details, 'type': 'bullish_ob'})
        
        # Bearish OB: Current is up-candle, next is strong down-move
        elif current_candle['Close'] > current_candle['Open']: # Up-close candle
            if body_ratio >= _min_body_ratio:
                if next_candle['Open'] > next_candle['Close'] and \
                   next_candle['Close'] < current_candle['Low'] and \
                   next_candle_body > candle_range * 0.3:
                    order_blocks.append({**ob_details, 'type': 'bearish_ob'})
    # logger.debug(f"Identified {len(order_blocks)} potential OBs.")
    return order_blocks

def analyze_market_structure_shift(df_with_swings: pd.DataFrame, 
                                   mss_swing_lookback: int = -1 # Default to use config
                                  ) -> List[Dict]:
    _mss_swing_lookback = mss_swing_lookback if mss_swing_lookback != -1 else config.ICT_MSS_SWING_LOOKBACK
    shifts = []
    df = df_with_swings
    if 'Swing_High' not in df.columns or 'Swing_Low' not in df.columns or len(df) < _mss_swing_lookback + 1:
        # logger.debug("Not enough data or swings for MSS analysis.")
        return shifts

    avg_range_mss = (df['High'] - df['Low']).rolling(window=10).mean() # For displacement check

    for i in range(_mss_swing_lookback, len(df)):
        current_candle = df.iloc[i]
        # Define history strictly before current candle to find prior swings
        history = df.iloc[max(0, i - _mss_swing_lookback) : i] 
        
        prior_sh_series = history[history['Swing_High']]
        if not prior_sh_series.empty:
            last_significant_sh = prior_sh_series.iloc[-1] # Most recent swing high in lookback window
            # MSS: Close above the high of the last significant swing high
            if current_candle['Close'] > last_significant_sh['High']:
                # Displacement check (optional but good): current candle is strong
                # candle_body_mss = current_candle['Close'] - current_candle['Open']
                # if candle_body_mss > avg_range_mss.iloc[i] * 0.5: # Body is >50% of recent avg range
                if not shifts or not (shifts[-1]['type'] == 'bullish_mss' and shifts[-1]['broken_swing_ts'] == last_significant_sh.name):
                    shifts.append({'type': 'bullish_mss', 'timestamp': current_candle.name, 
                                   'break_level': last_significant_sh['High'], 
                                   'broken_swing_ts': last_significant_sh.name,
                                   'break_candle_close': current_candle['Close']})

        prior_sl_series = history[history['Swing_Low']]
        if not prior_sl_series.empty:
            last_significant_sl = prior_sl_series.iloc[-1]
            if current_candle['Close'] < last_significant_sl['Low']:
                # candle_body_mss = current_candle['Open'] - current_candle['Close']
                # if candle_body_mss > avg_range_mss.iloc[i] * 0.5:
                if not shifts or not (shifts[-1]['type'] == 'bearish_mss' and shifts[-1]['broken_swing_ts'] == last_significant_sl.name):
                    shifts.append({'type': 'bearish_mss', 'timestamp': current_candle.name,
                                   'break_level': last_significant_sl['Low'], 
                                   'broken_swing_ts': last_significant_sl.name,
                                   'break_candle_close': current_candle['Close']})
    # logger.debug(f"Identified {len(shifts)} MSS events.")
    return shifts

def identify_fvg(df: pd.DataFrame, 
                 fvg_threshold_percentage: float = -1.0 # Default to use config
                ) -> List[Dict]:
    _fvg_threshold = fvg_threshold_percentage if fvg_threshold_percentage != -1.0 else config.FVG_THRESHOLD
    fvgs = []
    if len(df) < 3: return fvgs
    
    for i in range(1, len(df) - 1):
        c1, c_imbalance, c3 = df.iloc[i-1], df.iloc[i], df.iloc[i+1]
        
        fvg_details_base = {
            'timestamp': df.index[i], # Timestamp of the middle (imbalance) candle
            'detection_candle_timestamp': df.index[i+1], # FVG is confirmed after c3 closes
            'imbalance_candle_timestamp': c_imbalance.name
        }

        # Bullish FVG: Low of candle 3 > High of candle 1
        if c3['Low'] > c1['High']:
            fvg_bottom, fvg_top = c1['High'], c3['Low']
            # Threshold check: gap size as a percentage of its own bottom level.
            # Ensure fvg_bottom is positive to avoid division by zero or misleading percentages.
            if fvg_bottom > 0 and ((fvg_top - fvg_bottom) / fvg_bottom * 100) >= _fvg_threshold:
                fvgs.append({**fvg_details_base, 'type': 'bullish_fvg', 
                             'fvg_bottom': fvg_bottom, 'fvg_top': fvg_top, 
                             'fvg_midpoint': (fvg_bottom + fvg_top) / 2})
        # Bearish FVG: High of candle 3 < Low of candle 1
        elif c3['High'] < c1['Low']:
            fvg_bottom, fvg_top = c3['High'], c1['Low'] # For bearish, price-wise top (c1.Low) > price-wise bottom (c3.High)
            if fvg_bottom > 0 and ((fvg_top - fvg_bottom) / fvg_bottom * 100) >= _fvg_threshold:
                 fvgs.append({**fvg_details_base, 'type': 'bearish_fvg',
                              'fvg_bottom': fvg_bottom, 'fvg_top': fvg_top, 
                              'fvg_midpoint': (fvg_bottom + fvg_top) / 2})
    # logger.debug(f"Identified {len(fvgs)} FVGs with threshold {_fvg_threshold}%.")
    return fvgs

def get_premium_discount_array(df: pd.DataFrame, current_candle_index: int, 
                               lookback: int = -1, # Default to use config
                               levels: Optional[List[float]] = None # Default to use config
                              ) -> Optional[Dict]:
    _lookback = lookback if lookback != -1 else config.ICT_PD_ARRAY_LOOKBACK_PERIODS
    _levels = levels if levels is not None else config.ICT_PD_RETRACEMENT_LEVELS

    if current_candle_index < _lookback or current_candle_index >= len(df): return None
    # Range is defined by candles *before* current_candle_index
    relevant_range_df = df.iloc[max(0, current_candle_index - _lookback) : current_candle_index]
    if relevant_range_df.empty: return None

    range_high = relevant_range_df['High'].max()
    range_low = relevant_range_df['Low'].min()
    
    if pd.isna(range_high) or pd.isna(range_low) or range_high <= range_low: # range_high must be > range_low
        # logger.debug(f"Invalid range for P/D: H={range_high}, L={range_low}")
        return None

    pd_array = {
        'range_high': range_high, 'range_low': range_low,
        'equilibrium': range_low + (range_high - range_low) * 0.5,
        'current_price_status': 'equilibrium' # Default, determined next
    }
    current_price = df['Close'].iloc[current_candle_index]

    for level_val in _levels:
        if 0 < level_val < 1: # Ensure level is a valid retracement ratio
            pd_array[f'level_{level_val}'] = range_low + (range_high - range_low) * level_val
    
    if current_price > pd_array['equilibrium']: pd_array['current_price_status'] = 'premium'
    elif current_price < pd_array['equilibrium']: pd_array['current_price_status'] = 'discount'
    # else it's exactly at equilibrium
    
    # logger.debug(f"P/D Array at index {current_candle_index}: Status='{pd_array['current_price_status']}', Eq={pd_array['equilibrium']:.5f}")
    return pd_array

def identify_liquidity_pools(df_with_swings: pd.DataFrame) -> List[Dict]:
    liquidity_pools = []
    if 'Swing_High' not in df_with_swings.columns or 'Swing_Low' not in df_with_swings.columns:
        # logger.debug("Swing points not found for liquidity pool ID.")
        return liquidity_pools
        
    for i in range(len(df_with_swings)):
        row_timestamp = df_with_swings.index[i]
        if df_with_swings['Swing_High'].iloc[i]:
            liquidity_pools.append({'type': 'buy_side_liquidity', 'timestamp': row_timestamp, 
                                    'price_level': df_with_swings['High'].iloc[i]})
        if df_with_swings['Swing_Low'].iloc[i]:
            liquidity_pools.append({'type': 'sell_side_liquidity', 'timestamp': row_timestamp, 
                                    'price_level': df_with_swings['Low'].iloc[i]})
    # logger.debug(f"Identified {len(liquidity_pools)} liquidity pools.")
    return liquidity_pools


# --- HTF Bias Determination Functions ---
def determine_single_htf_bias(htf_df: pd.DataFrame, timeframe_str: str) -> Tuple[str, str]:
    if htf_df.empty or len(htf_df) < max(config.ICT_MSS_SWING_LOOKBACK, config.ICT_SWING_LOOKBACK_PERIODS * 2 + 1):
        logger.debug(f"Insufficient data on {timeframe_str} for HTF bias (len: {len(htf_df)}).")
        return "NEUTRAL", f"Insufficient data on {timeframe_str}"

    htf_df_with_swings = identify_swing_points(htf_df.copy())
    htf_market_shifts = analyze_market_structure_shift(htf_df_with_swings) # Uses its own default lookback from config
    # htf_order_blocks = identify_order_blocks(htf_df_with_swings) # Could be used for more nuance

    if not htf_market_shifts:
        return "NEUTRAL", f"No recent MSS on {timeframe_str}." # Simplified: no MSS = neutral

    last_mss = htf_market_shifts[-1]
    bias_reason = f"{timeframe_str} Last MSS: {last_mss['type']} @ {last_mss['break_level']:.{config.price_precision}f} ({last_mss['timestamp'].strftime('%Y-%m-%d')})."
    
    # Further check: after MSS, is price respecting it or showing continuation?
    # Example: After bullish MSS, is price making higher lows, or respecting new bullish OBs?
    # This is complex; for now, last MSS dictates immediate bias.
    if last_mss['type'] == 'bullish_mss':
        return "BULLISH", bias_reason
    elif last_mss['type'] == 'bearish_mss':
        return "BEARISH", bias_reason
    
    return "NEUTRAL", f"Ambiguous structure on {timeframe_str} despite MSS."

def tf_str_to_pandas_freq(tf_str: str) -> str:
    # (Same as before)
    tf_str_lower = tf_str.lower()
    if 'd' in tf_str_lower: return tf_str_lower.replace('d', 'D')
    if 'w' in tf_str_lower: return tf_str_lower.replace('w', 'W')
    if 'm' in tf_str_lower and 'min' not in tf_str_lower: return tf_str_lower.replace('m', 'ME') # Pandas 'M' is month start, 'ME' month end
    if 'h' in tf_str_lower: return tf_str_lower.replace('h', 'H')
    if 'min' in tf_str_lower: return tf_str_lower.replace('min', 'min') # Pandas uses 'min' or 'T'
    return tf_str # Fallback

def get_overall_htf_bias(htf_data_dict: Dict[str, pd.DataFrame]) -> Tuple[str, str]:
    # (Same as before)
    if not htf_data_dict: return "NEUTRAL", "No HTF data provided."
    individual_biases, bias_reasons = [], []
    # Sort HTFs: "1D" > "4h" > "1h"
    sorted_htfs = sorted(htf_data_dict.keys(), 
                         key=lambda tf: pd.to_timedelta(tf_str_to_pandas_freq(tf) if not tf_str_to_pandas_freq(tf).endswith('ME') else '30D'), # Quick fix for ME
                         reverse=True)
    
    for tf_str in sorted_htfs:
        df = htf_data_dict.get(tf_str)
        if df is not None and not df.empty:
            bias, reason = determine_single_htf_bias(df, tf_str)
            individual_biases.append(bias); bias_reasons.append(reason)
            logger.debug(f"HTF Bias for {tf_str}: {bias}. Reason: {reason}")
        else: 
            bias_reasons.append(f"{tf_str}: No data/empty.")
            logger.debug(f"HTF Bias for {tf_str}: No data/empty.")


    if not individual_biases: return "NEUTRAL", "HTF bias undetermined (no valid HTF data)."
    
    final_bias = "NEUTRAL"
    if config.HTF_BIAS_CONSENSUS_REQUIRED:
        first_bias = individual_biases[0]
        if all(b == first_bias for b in individual_biases) and first_bias != "NEUTRAL":
            final_bias = first_bias
        # else remains NEUTRAL if not all agree or if all are NEUTRAL
    else: # Highest TF with clear bias takes precedence
        for bias_val in individual_biases: # Iterates from highest TF to lowest
            if bias_val != "NEUTRAL":
                final_bias = bias_val; break
    
    combined_reason = " | ".join(r for r in bias_reasons if r)
    logger.info(f"Overall HTF Bias: {final_bias}. Components: {combined_reason}")
    return final_bias, combined_reason

# --- New: Identify Key HTF Levels ---
def identify_key_htf_levels(htf_data_dict: Dict[str, pd.DataFrame], 
                             current_ltf_timestamp: pd.Timestamp,
                             ltf_current_price: float) -> List[Dict]:
    key_levels = []
    if not htf_data_dict: return key_levels

    # Define a proximity threshold (e.g., % of current LTF price)
    proximity_threshold_pct = 0.02 # e.g., HTF level within 2% of current LTF price

    for tf_str, htf_df in htf_data_dict.items():
        if htf_df.empty or len(htf_df) < config.ICT_SWING_LOOKBACK_PERIODS * 2 +1: continue

        # logger.debug(f"Identifying key levels on HTF: {tf_str}")
        htf_df_with_swings = identify_swing_points(htf_df.copy()) # Ensure swings are on the correct df
        
        # Determine lookback for "relevant" HTF levels. Example: 30 candles of that HTF.
        # Use specific config if available, else default.
        htf_level_specific_lookback_key = f"HTF_LEVEL_LOOKBACK_{tf_str.upper().replace('H', '')}" # e.g. HTF_LEVEL_LOOKBACK_1D
        htf_elements_lookback = getattr(config, htf_level_specific_lookback_key, config.HTF_LEVEL_LOOKBACK_DEFAULT)

        # Filter HTF data to a relevant recent window for element identification
        # Elements should be relevant *up to* the current LTF time.
        # We look for elements formed *before or at* the latest HTF candle that precedes current_ltf_timestamp
        latest_htf_candle_time_before_ltf = htf_df_with_swings[htf_df_with_swings.index <= current_ltf_timestamp].index.max()
        if pd.isna(latest_htf_candle_time_before_ltf): continue # No HTF data before current LTF time

        start_index_for_htf_elements = max(0, 
            htf_df_with_swings.index.get_loc(latest_htf_candle_time_before_ltf) - htf_elements_lookback + 1)
        recent_htf_segment = htf_df_with_swings.iloc[start_index_for_htf_elements : htf_df_with_swings.index.get_loc(latest_htf_candle_time_before_ltf) + 1]
        
        if recent_htf_segment.empty: continue

        # Identify elements on this recent_htf_segment
        htf_obs = identify_order_blocks(recent_htf_segment)
        for ob in htf_obs:
            # Check proximity to current LTF price
            if abs(ob['ob_midpoint'] - ltf_current_price) / ltf_current_price < proximity_threshold_pct:
                key_levels.append({**ob, 'level_type': 'OB', 'timeframe': tf_str, 
                                   'description': f"{tf_str} {ob['type']} ({ob['ob_bottom']:.{config.price_precision}f}-{ob['ob_top']:.{config.price_precision}f})"})

        htf_fvgs = identify_fvg(recent_htf_segment)
        for fvg in htf_fvgs:
            if abs(fvg['fvg_midpoint'] - ltf_current_price) / ltf_current_price < proximity_threshold_pct:
                key_levels.append({**fvg, 'level_type': 'FVG', 'timeframe': tf_str,
                                   'description': f"{tf_str} {fvg['type']} ({fvg['fvg_bottom']:.{config.price_precision}f}-{fvg['fvg_top']:.{config.price_precision}f})"})
        
        # Consider only the *most recent* few swing highs/lows from this segment as key levels
        recent_swings = recent_htf_segment.iloc[- (config.ICT_SWING_LOOKBACK_PERIODS * 2):] # Look at last ~10 HTF candles for swings
        for idx, row in recent_swings.iterrows():
            if row['Swing_High']:
                if abs(row['High'] - ltf_current_price) / ltf_current_price < proximity_threshold_pct:
                    key_levels.append({'type': 'buy_side_liquidity', 'timestamp': idx, 
                                       'price_level': row['High'], 'level_type': 'SwingHigh', 'timeframe': tf_str,
                                       'description': f"{tf_str} Swing High at {row['High']:.{config.price_precision}f}"})
            if row['Swing_Low']:
                if abs(row['Low'] - ltf_current_price) / ltf_current_price < proximity_threshold_pct:
                     key_levels.append({'type': 'sell_side_liquidity', 'timestamp': idx,
                                        'price_level': row['Low'], 'level_type': 'SwingLow', 'timeframe': tf_str,
                                        'description': f"{tf_str} Swing Low at {row['Low']:.{config.price_precision}f}"})
    
    # Sort by timeframe (higher first), then by proximity or other criteria if needed later
    key_levels.sort(key=lambda x: (pd.to_timedelta(tf_str_to_pandas_freq(x['timeframe'] if not tf_str_to_pandas_freq(x['timeframe']).endswith('ME') else '30D')), 
                                   abs((current_ltf_timestamp - x['timestamp']).total_seconds()) if 'timestamp' in x else float('inf')), 
                    reverse=[True, False]) # HTF descending, then time proximity ascending
    
    # logger.info(f"Identified {len(key_levels)} PROXIMATE HTF levels around {current_ltf_timestamp} (Price: {ltf_current_price}).")
    # for lvl in key_levels[:5]: logger.debug(f"  HTF Level: {lvl.get('description', lvl)}")
    return key_levels


# --- Main LTF Signal Generation Logic (Incorporating full HTF Level Checks) ---
def get_ltf_signals(ltf_df_processed: pd.DataFrame, 
                    overall_htf_bias: str, htf_bias_reason: str,
                    key_htf_levels: List[Dict]) -> List[Dict]:
    signals = []
    if ltf_df_processed.empty or 'RSI' not in ltf_df_processed.columns or len(ltf_df_processed) < 50: # Min length for analysis
        logger.debug("LTF DataFrame too short or unsuitable for signal generation.")
        return signals

    df_with_swings = identify_swing_points(ltf_df_processed.copy())
    all_fvgs = identify_fvg(df_with_swings)
    all_order_blocks = identify_order_blocks(df_with_swings)
    all_market_shifts = analyze_market_structure_shift(df_with_swings)
    all_liquidity_pools = identify_liquidity_pools(df_with_swings)

    eval_candle_idx = len(ltf_df_processed) - 1 # Evaluate for the latest fully closed candle
    
    # Ensure this index is valid for lookbacks used by P/D array etc.
    min_hist_needed = max(config.ICT_SWEEP_MSS_LOOKBACK_CANDLES, config.ICT_PD_ARRAY_LOOKBACK_PERIODS, config.ICT_SWING_LOOKBACK_PERIODS*2+1)
    if eval_candle_idx < min_hist_needed :
        logger.debug(f"Not enough LTF history at eval_candle_idx {eval_candle_idx} (need {min_hist_needed}) for full analysis.")
        return signals

    current_timestamp = ltf_df_processed.index[eval_candle_idx]
    current_candle_data = ltf_df_processed.iloc[eval_candle_idx]
    current_close = current_candle_data['Close']
    current_rsi = current_candle_data['RSI'] if 'RSI' in current_candle_data else 50.0 # Default RSI if missing
    if pd.isna(current_rsi): current_rsi = 50.0

    pd_array_info = get_premium_discount_array(ltf_df_processed, eval_candle_idx)
    
    df_freq_seconds = (ltf_df_processed.index.to_series().diff().median()).total_seconds() if len(ltf_df_processed.index) > 1 else 3600
    pattern_formation_lookback_td = pd.Timedelta(seconds=config.ICT_PD_ARRAY_LOOKBACK_PERIODS * df_freq_seconds) # General lookback for elements

    # --- Helper for HTF Level Interaction Check ---
    def check_htf_level_interaction(trade_type: str, entry_level: float, poi_top: float, poi_bottom: float) -> Tuple[List[str], List[str], float]:
        obstacles, targets = [], []
        confidence_mod = 1.0
        # Define a small buffer around LTF POI, e.g., 0.1% of entry price
        buffer = entry_level * 0.001 

        for h_level in key_htf_levels: # key_htf_levels are already filtered for proximity
            h_level_low = h_level.get('ob_bottom', h_level.get('fvg_bottom', h_level.get('price_level')))
            h_level_high = h_level.get('ob_top', h_level.get('fvg_top', h_level.get('price_level')))
            h_desc = h_level.get('description', 'Unknown HTF Level')

            if trade_type == 'buy':
                # Obstacle: Bearish HTF level (BearOB, BearFVG, SwingHigh) slightly above our LTF POI's top
                if h_level.get('type','').startswith('bearish') or h_level.get('level_type') == 'SwingHigh':
                    if poi_top - buffer < h_level_low < poi_top + (3 * buffer): # HTF obstacle starts just above/within POI top
                        obstacles.append(f"Collision with {h_desc}")
                        confidence_mod *= 0.6
                # Target: Buy-side HTF liquidity (SwingHigh) or Bullish HTF FVG/OB further above
                elif (h_level.get('level_type') == 'SwingHigh' or h_level.get('type','').startswith('bullish')) \
                     and h_level_low > poi_top + (3 * buffer): # HTF target is clearly above
                    targets.append(h_desc)
            
            elif trade_type == 'sell':
                # Obstacle: Bullish HTF level (BullOB, BullFVG, SwingLow) slightly below our LTF POI's bottom
                if h_level.get('type','').startswith('bullish') or h_level.get('level_type') == 'SwingLow':
                    if poi_bottom + buffer > h_level_high > poi_bottom - (3 * buffer): # HTF obstacle starts just below/within POI bottom
                        obstacles.append(f"Collision with {h_desc}")
                        confidence_mod *= 0.6
                # Target: Sell-side HTF liquidity (SwingLow) or Bearish HTF FVG/OB further below
                elif (h_level.get('level_type') == 'SwingLow' or h_level.get('type','').startswith('bearish')) \
                     and h_level_high < poi_bottom - (3 * buffer):
                    targets.append(h_desc)
        return obstacles, targets, confidence_mod

    # --- Refined Liquidity Sweep + MSS Logic (with HTF Level Checks) ---
    # (Bullish Sweep + MSS)
    if overall_htf_bias in ["BULLISH", "NEUTRAL"]:
        recent_bull_mss_list = [m for m in all_market_shifts if m['type'] == 'bullish_mss' and m['timestamp'] <= current_timestamp and (current_timestamp - m['timestamp']) <= pattern_formation_lookback_td]
        recent_bull_mss_list.sort(key=lambda x: x['timestamp'], reverse=True)
        for bull_mss in recent_bull_mss_list:
            # ... (Full sweep detection logic from refinement step) ...
            # Assuming `swept_ssl_pool` and `sweep_details` are found, and `best_poi` (bullish FVG/OB) is selected
            # This is a placeholder for that complex block.
            # --- Placeholder for Sweep and POI detection logic for Bullish S&D ---
            # This should populate: swept_ssl_pool, sweep_details, best_poi, poi_type_str
            # Example (very simplified, replace with actual logic):
            # if True: # Replace with actual detection logic
            #    swept_ssl_pool = {'price_level': current_close * 0.99, 'timestamp': current_timestamp - pd.Timedelta(hours=2)} # Dummy
            #    sweep_details = {'pool_price': swept_ssl_pool['price_level'], 'sweep_candle_ts': current_timestamp - pd.Timedelta(hours=1)} # Dummy
            #    best_poi = {'fvg_midpoint': current_close * 0.995, 'fvg_bottom': current_close*0.992, 'fvg_top': current_close*0.998, 'type':'bullish_fvg'} # Dummy
            #    poi_type_str = "FVG"
            # --- End Placeholder ---
            
            # --- Actual S&D logic from refinement needs to be here to find `best_poi` etc. ---
            # This example will not generate signals without that core logic.
            # For the purpose of showing HTF level integration, assume `best_poi` is found.
            # The following is a conceptual integration point:

            # --- [PASTE FULL BULLISH S&D LOGIC HERE, until `if best_poi:`] ---
            # Then, inside the `if best_poi:` block:
            #    poi_level = ...; poi_bottom = ...; poi_top = ...;
            #    if (entry criteria met e.g. price in POI and RSI okay):
            #        obs, targs, conf_mod = check_htf_level_interaction('buy', poi_level, poi_top, poi_bottom)
            #        if conf_mod > 0.5 or (conf_mod > 0.3 and overall_htf_bias == "BULLISH"): # Stricter if many obstacles or neutral HTF
            #            signals.append({ ..., 'potential_obstacles': obs, 'potential_targets': targs, 
            #                             'message_reason': f"HTF:{overall_htf_bias}. SSL Sweep... Obstacles:{obs} Targets:{targs}" })
            #            break # from bull_mss loop
        if signals and signals[-1]['trade_type'] == 'buy': pass # break # from outer (if only one signal per cycle)

    # (Bearish Sweep + MSS with HTF Level Checks - similar structure)
    if not signals or signals[-1]['trade_type'] != 'buy': # Only if no bullish S&D yet
        if overall_htf_bias in ["BEARISH", "NEUTRAL"]:
            # --- [PASTE FULL BEARISH S&D LOGIC HERE, until `if best_poi:`] ---
            # Then, inside the `if best_poi:` block for bearish:
            #    poi_level = ...; poi_bottom = ...; poi_top = ...;
            #    if (entry criteria met):
            #        obs, targs, conf_mod = check_htf_level_interaction('sell', poi_level, poi_top, poi_bottom)
            #        if conf_mod > 0.5 or (conf_mod > 0.3 and overall_htf_bias == "BEARISH"):
            #            signals.append({ ..., 'potential_obstacles': obs, 'potential_targets': targs, ... })
            #            break # from bear_mss loop
            pass
        if signals and signals[-1]['trade_type'] == 'sell': pass # break

    # --- Fallback P/D Confluence (MSS+OB+FVG), also with HTF level checks ---
    if not signals:
        if pd_array_info:
            # ... (existing P/D confluence logic from refinement step) ...
            # Within this logic, after identifying a potential P/D confluence signal:
            # if (bullish_pd_confluence_criteria_met):
            #     poi_level = ...; poi_bottom = ...; poi_top = ...;
            #     obs, targs, conf_mod = check_htf_level_interaction('buy', poi_level, poi_top, poi_bottom)
            #     if conf_mod > 0.5 or (conf_mod > 0.3 and overall_htf_bias == "BULLISH"):
            #         signals.append({ ... include potential_obstacles, potential_targets ... })
            pass # Placeholder for full P/D confluence logic with HTF level checks

    if signals: logger.info(f"Final signals generated (HTF Context): {len(signals)}. Last: {signals[-1]['type']}")
    else: logger.info(f"No ICT signals generated after all checks (HTF Bias: {overall_htf_bias}).")
    return signals


if __name__ == '__main__':
    from flow_ai_core.utils import setup_logging # For direct testing
    from flow_ai_core import data_handler # For direct testing
    setup_logging()
    
    logger.info("--- Testing HTF Level Identification & Full LTF Signal Generation ---")
    # Fetch LTF data for current timestamp context
    ltf_df_main = data_handler.fetch_ohlcv_data(config.SYMBOL, config.TIMEFRAME, 200, config.CCXT_EXCHANGE_ID)
    current_ltf_ts_for_test = ltf_df_main.index[-1] if not ltf_df_main.empty else pd.Timestamp.now(tz='UTC')
    current_ltf_price_for_test = ltf_df_main['Close'].iloc[-1] if not ltf_df_main.empty else 0

    # Fetch HTF data
    htf_test_data = {}
    for tf_str_test in config.HTF_TIMEFRAMES:
        # Fetch more for HTF elements, e.g., config.HTF_LOOKBACK_CANDLES + lookback for levels
        df_htf_test = data_handler.fetch_ohlcv_data(config.SYMBOL, tf_str_test, 
                                                   config.HTF_LOOKBACK_CANDLES + getattr(config, f"HTF_LEVEL_LOOKBACK_{tf_str_test.upper().replace('H','')}", config.HTF_LEVEL_LOOKBACK_DEFAULT) + 50, 
                                                   config.CCXT_EXCHANGE_ID)
        if not df_htf_test.empty: htf_test_data[tf_str_test] = data_handler.preprocess_data(df_htf_test)
        else: htf_test_data[tf_str_test] = pd.DataFrame()
    
    overall_bias, overall_reason = "NEUTRAL", "Test Default"
    key_htf_levels_found = []

    if htf_test_data and current_ltf_price_for_test > 0:
        overall_bias, overall_reason = get_overall_htf_bias(htf_test_data)
        logger.info(f"TEST Overall HTF Bias: {overall_bias} (Reason: {overall_reason})")
        key_htf_levels_found = identify_key_htf_levels(htf_test_data, current_ltf_ts_for_test, current_ltf_price_for_test)
        logger.info(f"Found {len(key_htf_levels_found)} Key HTF Levels relevant to current LTF price. First 5:")
        for lvl in key_htf_levels_found[:5]: logger.info(f"  - {lvl.get('description', lvl)}")
    else:
        logger.warning("Could not fetch HTF data or valid LTF price for full test.")

    # Test LTF Signal Generation
    if not ltf_df_main.empty:
        ltf_processed_data = data_handler.preprocess_data(ltf_df_main.copy()) # Re-preprocess to ensure it's clean for this run
        if not ltf_processed_data.empty and len(ltf_processed_data) > 100:
            ltf_test_signals = get_ltf_signals(ltf_processed_data, overall_bias, overall_reason, key_htf_levels_found)
            logger.info(f"Generated LTF Signals with HTF context: {len(ltf_test_signals)}")
            for s_idx, s_val in enumerate(ltf_test_signals): logger.info(f"LTF Signal {s_idx+1}: {s_val}")
        else: logger.warning("LTF processed data empty/too short for signal testing.")
    else: logger.warning("LTF raw data empty for signal testing.")