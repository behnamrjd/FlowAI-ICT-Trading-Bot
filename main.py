#!/usr/bin/env python3
"""
FlowAI ICT Trading Bot - Main Application
Advanced AI-Powered Gold Trading System with ICT Analysis
Version: 2.1 - Fixed All Issues
"""

import sys
import os
import signal
import schedule
import time
import logging
import traceback
import joblib
import pandas as pd
import numpy as np
from datetime import datetime
from typing import Optional, Dict, Any

# Add project root to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Import core modules
from flow_ai_core import config, data_handler, ict_analysis, telegram_bot, utils

# Setup logging
logger = utils.setup_logging(config.LOG_LEVEL)

# Global variables
ai_model = None
ai_features = None
bot_running = True

def load_ai_model():
    """Load the trained AI model with metadata"""
    global ai_model, ai_features
    
    try:
        logger.info("Attempting to load AI model pipeline from model.pkl...")
        ai_model = joblib.load(config.MODEL_PATH)
        logger.info(f"AI Model pipeline loaded: {type(ai_model)}")
        
        # Load metadata
        try:
            metadata = joblib.load(config.MODEL_METADATA_PATH)
            ai_features = metadata.get('feature_names', [])
            logger.info(f"AI Model metadata loaded: {len(ai_features)} features")
            logger.info(f"Training accuracy: {metadata.get('training_accuracy', 'N/A')}")
            logger.info(f"Training date: {metadata.get('training_date', 'N/A')}")
        except Exception as e:
            logger.warning(f"Could not load model metadata: {e}")
            # Fallback to old method
            if os.path.exists(config.MODEL_FEATURES_PATH):
                ai_features = joblib.load(config.MODEL_FEATURES_PATH)
                logger.info(f"AI Model features loaded: {len(ai_features)} features")
            else:
                logger.warning("Model features file not found")
                ai_features = []
                
    except Exception as e:
        logger.error(f"Failed to load AI model: {e}")
        ai_model = None
        ai_features = None


def engineer_features(df):
    """Create advanced features for AI model - v3.0 Compatible"""
    from datetime import datetime
    
    features = pd.DataFrame(index=df.index)
    
    # === BASIC PRICE FEATURES ===
    features['price_change'] = df['Close'].pct_change().fillna(0)
    features['high_low_ratio'] = (df['High'] / df['Low']).fillna(1)
    features['close_position'] = (df['Close'] - df['Low']) / (df['High'] - df['Low'])
    features['close_position'] = features['close_position'].fillna(0.5)
    
    # === VOLATILITY FEATURES ===
    features['volatility_5'] = df['Close'].rolling(5).std().fillna(0)
    features['volatility_20'] = df['Close'].rolling(20).std().fillna(0)
    features['volatility_50'] = df['Close'].rolling(50).std().fillna(0)
    features['volatility_ratio'] = (features['volatility_5'] / features['volatility_20']).fillna(1)
    
    # ATR with safe division
    high_low = df['High'] - df['Low']
    high_close = np.abs(df['High'] - df['Close'].shift())
    low_close = np.abs(df['Low'] - df['Close'].shift())
    true_range = np.maximum(high_low, np.maximum(high_close, low_close))
    features['atr'] = true_range.rolling(14).mean().fillna(0)
    features['atr_normalized'] = features['atr'] / df['Close']
    
    # Safe ATR ratio
    atr_values = features['atr'].values
    atr_ratio = np.where(atr_values != 0, true_range / atr_values, 1.0)
    features['atr_ratio'] = pd.Series(atr_ratio, index=df.index).fillna(1)
    
    # === VOLUME FEATURES ===
    features['volume_sma'] = df['Volume'].rolling(20).mean().fillna(df['Volume'])
    features['volume_ema'] = df['Volume'].ewm(span=20).mean().fillna(df['Volume'])
    
    # Safe volume ratios
    volume_sma_values = features['volume_sma'].values
    volume_ratio = np.where(volume_sma_values != 0, df['Volume'] / volume_sma_values, 1.0)
    features['volume_ratio'] = pd.Series(volume_ratio, index=df.index).fillna(1)
    
    features['volume_volatility'] = df['Volume'].rolling(10).std().fillna(0)
    features['volume_trend'] = (features['volume_ema'] / features['volume_sma']).fillna(1)
    features['pv_trend'] = (features['price_change'] * np.log1p(features['volume_ratio'])).fillna(0)
    
    # === TECHNICAL INDICATORS ===
    # Moving Averages
    features['sma_5'] = df['Close'].rolling(5).mean().fillna(df['Close'])
    features['sma_20'] = df['Close'].rolling(20).mean().fillna(df['Close'])
    features['sma_50'] = df['Close'].rolling(50).mean().fillna(df['Close'])
    features['ema_12'] = df['Close'].ewm(span=12).mean().fillna(df['Close'])
    features['ema_26'] = df['Close'].ewm(span=26).mean().fillna(df['Close'])
    
    # Safe ratios
    sma5_values = features['sma_5'].values
    sma20_values = features['sma_20'].values
    sma50_values = features['sma_50'].values
    
    features['price_sma5_ratio'] = np.where(sma5_values != 0, df['Close'] / sma5_values, 1.0)
    features['price_sma20_ratio'] = np.where(sma20_values != 0, df['Close'] / sma20_values, 1.0)
    features['price_sma50_ratio'] = np.where(sma50_values != 0, df['Close'] / sma50_values, 1.0)
    features['sma_cross_short'] = np.where(sma20_values != 0, sma5_values / sma20_values, 1.0)
    features['sma_cross_long'] = np.where(sma50_values != 0, sma20_values / sma50_values, 1.0)
    
    # MACD
    features['macd'] = features['ema_12'] - features['ema_26']
    features['macd_signal'] = features['macd'].ewm(span=9).mean()
    features['macd_histogram'] = features['macd'] - features['macd_signal']
    
    # RSI with safe calculation
    delta = df['Close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    
    rs = np.where(loss != 0, gain / loss, 0)
    features['rsi'] = 100 - (100 / (1 + rs))
    features['rsi'] = pd.Series(features['rsi'], index=df.index).fillna(50)
    features['rsi_normalized'] = (features['rsi'] - 50) / 50
    features['rsi_overbought'] = (features['rsi'] > 70).astype(int)
    features['rsi_oversold'] = (features['rsi'] < 30).astype(int)
    
    # Bollinger Bands
    bb_middle = df['Close'].rolling(20).mean()
    bb_std_dev = df['Close'].rolling(20).std()
    bb_upper = bb_middle + (bb_std_dev * 2)
    bb_lower = bb_middle - (bb_std_dev * 2)
    
    bb_range = bb_upper - bb_lower
    features['bb_position'] = np.where(bb_range != 0, (df['Close'] - bb_lower) / bb_range, 0.5)
    features['bb_width'] = np.where(bb_middle != 0, bb_range / bb_middle, 0)
    features['bb_squeeze'] = (features['bb_width'] < features['bb_width'].rolling(20).mean()).astype(int)
    
    # === MOMENTUM FEATURES ===
    features['momentum_3'] = (df['Close'] / df['Close'].shift(3) - 1).fillna(0)
    features['momentum_5'] = (df['Close'] / df['Close'].shift(5) - 1).fillna(0)
    features['momentum_10'] = (df['Close'] / df['Close'].shift(10) - 1).fillna(0)
    features['momentum_20'] = (df['Close'] / df['Close'].shift(20) - 1).fillna(0)
    
    # Rate of Change
    for period in [5, 10, 20]:
        close_shifted = df['Close'].shift(period)
        features[f'roc_{period}'] = np.where(close_shifted != 0, 
                                           (df['Close'] - close_shifted) / close_shifted * 100, 0)
    
    # === TIME-BASED FEATURES ===
    features['hour'] = df.index.hour
    features['day_of_week'] = df.index.dayofweek
    features['is_weekend'] = (features['day_of_week'] >= 5).astype(int)
    
    # High volatility time detection
    high_vol_hours = [(8, 10), (13, 15), (20, 22)]
    extended_hours = [(6, 12), (12, 18), (18, 24)]
    
    features['is_high_vol_time'] = 0
    features['is_extended_time'] = 0
    features['session_strength'] = 0.3  # Default
    
    for start, end in high_vol_hours:
        mask = (features['hour'] >= start) & (features['hour'] <= end)
        features.loc[mask, 'is_high_vol_time'] = 1
        features.loc[mask, 'session_strength'] = 0.8
    
    for start, end in extended_hours:
        mask = (features['hour'] >= start) & (features['hour'] <= end)
        features.loc[mask, 'is_extended_time'] = 1
    
    # Peak overlap hours
    overlap_mask = (features['hour'] >= 13) & (features['hour'] <= 16)
    features.loc[overlap_mask, 'session_strength'] = 1.0
    
    # Session indicators
    features['london_session'] = ((features['hour'] >= 8) & (features['hour'] <= 16)).astype(int)
    features['us_session'] = ((features['hour'] >= 13) & (features['hour'] <= 21)).astype(int)
    features['asian_session'] = ((features['hour'] >= 20) | (features['hour'] <= 2)).astype(int)
    features['overlap_london_us'] = ((features['hour'] >= 13) & (features['hour'] <= 16)).astype(int)
    
    # === MARKET STRUCTURE FEATURES ===
    # Support/Resistance levels
    for period in [10, 20, 50]:
        features[f'recent_high_{period}'] = df['High'].rolling(period).max()
        features[f'recent_low_{period}'] = df['Low'].rolling(period).min()
        
        close_values = df['Close'].values
        features[f'distance_to_high_{period}'] = np.where(close_values != 0, 
                                                        (features[f'recent_high_{period}'] - close_values) / close_values, 0)
        features[f'distance_to_low_{period}'] = np.where(close_values != 0,
                                                       (close_values - features[f'recent_low_{period}']) / close_values, 0)
    
    # Trend strength indicators
    features['trend_strength_short'] = features['sma_cross_short'] - 1
    features['trend_strength_long'] = features['sma_cross_long'] - 1
    
    # === VOLATILITY REGIME ===
    vol_ma_short = features['volatility_20'].rolling(20).mean()
    vol_ma_long = features['volatility_20'].rolling(50).mean()
    features['vol_regime_short'] = (features['volatility_20'] > vol_ma_short).astype(int)
    features['vol_regime_long'] = (features['volatility_20'] > vol_ma_long).astype(int)
    features['vol_expansion'] = (features['volatility_20'] > features['volatility_20'].shift(5)).astype(int)
    
    # === FINAL CLEANING ===
    # Replace infinity values
    features = features.replace([np.inf, -np.inf], np.nan)
    
    # Fill NaN values
    features = features.ffill().fillna(0)
    
    # Clip extreme values
    numeric_columns = features.select_dtypes(include=[np.number]).columns
    for col in numeric_columns:
        features[col] = np.clip(features[col], -10, 10)
    
    return features

def get_ai_prediction(processed_ltf_data: pd.DataFrame) -> Optional[Dict[str, Any]]:
    """Get advanced AI model prediction with adaptive filtering"""
    global ai_model, ai_features
    
    try:
        logger.info(f"Getting AI prediction. LTF data shape for FE: {processed_ltf_data.shape}")
        
        # Engineer advanced features
        X_live_features = engineer_features(processed_ltf_data.copy())
        
        if X_live_features.empty:
            logger.error("No features generated for AI prediction")
            return None
        
        # Get current market conditions
        current_time = processed_ltf_data.index[-1]
        current_hour = current_time.hour
        current_volume = processed_ltf_data['Volume'].iloc[-1]
        volume_ma = processed_ltf_data['Volume'].rolling(20).mean().iloc[-1]
        current_volatility = X_live_features['volatility_20'].iloc[-1] if 'volatility_20' in X_live_features.columns else 0
        volatility_ma = X_live_features['volatility_20'].rolling(50).mean().iloc[-1] if 'volatility_20' in X_live_features.columns else 1
        
        # === ADAPTIVE TIME-BASED FILTERING ===
        high_vol_hours = [(8, 10), (13, 15), (20, 22)]
        extended_hours = [(6, 12), (12, 18), (18, 24)]
        
        is_high_vol_time = any(start <= current_hour <= end for start, end in high_vol_hours)
        is_extended_time = any(start <= current_hour <= end for start, end in extended_hours)
        
        # Calculate session strength
        if 13 <= current_hour <= 16:  # London/US overlap
            session_strength = 1.0
        elif current_hour in [8, 9, 10, 20, 21, 22]:  # Session opens
            session_strength = 0.8
        elif is_extended_time:
            session_strength = 0.6
        else:
            session_strength = 0.3
        
        # === MARKET CONDITION ANALYSIS ===
        volume_ratio = current_volume / volume_ma if volume_ma > 0 else 1
        volatility_ratio = current_volatility / volatility_ma if volatility_ma > 0 else 1
        
        # Adaptive confidence multiplier
        confidence_multiplier = 1.0
        
        if is_high_vol_time:
            confidence_multiplier = 1.0
            logger.info(f"High volatility trading hours (current: {current_hour})")
        elif is_extended_time and volatility_ratio > 1.2 and volume_ratio > 1.3:
            confidence_multiplier = 0.7
            logger.info(f"Extended hours with good conditions (current: {current_hour})")
        elif volatility_ratio > 2.0 and volume_ratio > 2.0:
            confidence_multiplier = 0.5
            logger.info(f"Emergency high volatility trading (current: {current_hour})")
        else:
            logger.info(f"Outside optimal trading hours (current: {current_hour}). Skipping prediction.")
            return {
                'prediction': 2,  # HOLD
                'label': 'HOLD',
                'probabilities': [0.1, 0.1, 0.8, 0.0, 0.0],
                'confidence': 0.8,
                'reason': f'Outside trading hours (Hour: {current_hour})',
                'session_strength': session_strength
            }
        
        # === VOLUME & VOLATILITY FILTERING ===
        min_volume_mult = getattr(config, 'MIN_VOLUME_MULTIPLIER', 1.2)
        min_vol_mult = getattr(config, 'MIN_VOLATILITY_MULTIPLIER', 1.1)
        
        if volume_ratio < min_volume_mult:
            logger.info(f"Low volume detected ({volume_ratio:.2f}x). Reducing signal strength.")
            confidence_multiplier *= 0.8
        
        if volatility_ratio < min_vol_mult:
            logger.info(f"Low volatility detected ({volatility_ratio:.2f}x). Reducing signal strength.")
            confidence_multiplier *= 0.9
        
        # Use the last row for prediction
        X_latest = X_live_features.iloc[-1:].values
        
        if ai_model is None:
            logger.error("AI model not loaded")
            return None
        
        # Make prediction
        prediction = ai_model.predict(X_latest)[0]
        probabilities = ai_model.predict_proba(X_latest)[0]
        
        # Load metadata for label mapping
        try:
            metadata = joblib.load(getattr(config, 'MODEL_METADATA_PATH', 'model_metadata.pkl'))
            target_names = metadata.get('target_names', ['STRONG_SELL', 'SELL', 'HOLD', 'BUY', 'STRONG_BUY'])
            model_version = metadata.get('model_version', '2.0')
        except:
            target_names = ['STRONG_SELL', 'SELL', 'HOLD', 'BUY', 'STRONG_BUY']
            model_version = '2.0'
        
        predicted_label = target_names[prediction] if prediction < len(target_names) else 'HOLD'
        final_confidence = max(probabilities) * confidence_multiplier * session_strength
        
        logger.info(f"AI raw: {prediction}, Label: {predicted_label}, Confidence: {final_confidence:.3f}")
        logger.info(f"Market conditions - Volume: {volume_ratio:.2f}x, Volatility: {volatility_ratio:.2f}x")
        logger.info(f"Session strength: {session_strength:.1f}, Model version: {model_version}")
        
        return {
            'prediction': prediction,
            'label': predicted_label,
            'probabilities': probabilities.tolist(),
            'confidence': final_confidence,
            'volume_ratio': volume_ratio,
            'volatility_ratio': volatility_ratio,
            'is_high_vol_time': is_high_vol_time,
            'is_extended_time': is_extended_time,
            'session_strength': session_strength,
            'model_version': model_version
        }
        
    except Exception as e:
        logger.error(f"Error during AI prediction: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        return None

def run_trading_logic():
    """Main trading logic execution"""
    try:
        logger.info(f"--- Starting Trading Logic Cycle for {config.SYMBOL} (Primary TF: {config.TIMEFRAME}) ---")
        
        # Fetch primary timeframe data
        processed_ltf_data = data_handler.get_processed_data(
            config.SYMBOL, 
            config.TIMEFRAME
        )
        
        if processed_ltf_data.empty:
            logger.error("No primary timeframe data available")
            return
        
        # Fetch HTF data
        htf_data = data_handler.get_htf_data(config.SYMBOL, config.HTF_TIMEFRAMES)
        
        if not htf_data:
            logger.warning("No HTF data available, proceeding with LTF only")
        
        # Analyze HTF bias
        htf_bias = ict_analysis.analyze_htf_bias(htf_data)
        
        # Generate ICT signals
        ict_signals = ict_analysis.generate_ict_signals(processed_ltf_data, htf_bias)
        
        # Get AI prediction
        ai_prediction = get_ai_prediction(processed_ltf_data)
        
        # Combine signals and make trading decision
        final_signals = []
        
        # Add ICT signals
        final_signals.extend(ict_signals)
        
        # Add AI signal if available
        if ai_prediction and ai_prediction['confidence'] > config.AI_CONFIDENCE_THRESHOLD:
            ai_signal = {
                'type': ai_prediction['label'],
                'reason': f"AI Model prediction (confidence: {ai_prediction['confidence']:.3f})",
                'price': processed_ltf_data['Close'].iloc[-1],
                'time': processed_ltf_data.index[-1],
                'confidence': ai_prediction['confidence'],
                'source': 'AI'
            }
            
            if ai_signal['type'] not in ['HOLD']:
                final_signals.append(ai_signal)
        
        # Process and send signals
        if final_signals:
            # Take the highest confidence signal
            best_signal = max(final_signals, key=lambda x: x.get('confidence', 0))
            
            logger.info(f"Best signal: {best_signal['type']} - {best_signal['reason']}")
            
            # Send Telegram notification
            if config.TELEGRAM_ENABLED:
                analysis_data = {
                    'htf_bias': htf_bias,
                    'confidence': best_signal['confidence'],
                    'risk_level': 'MEDIUM',
                    'rsi': processed_ltf_data['RSI'].iloc[-1] if 'RSI' in processed_ltf_data.columns else 'N/A',
                    'trend': htf_bias,
                    'volume_status': 'Normal',
                    'stop_loss': best_signal.get('stop_loss', 'Calculate based on ATR'),
                    'take_profit': best_signal.get('take_profit', 'Calculate based on R:R')
                }
                
                telegram_bot.send_trading_signal(
                    best_signal['type'],
                    config.SYMBOL,
                    best_signal['price'],
                    best_signal['confidence'],
                    analysis_data
                )
        else:
            logger.info("No LTF signals generated (after HTF filtering & level checks).")
        
    except Exception as e:
        logger.error(f"Unhandled error in trading logic cycle: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        
        # Send error notification
        try:
            telegram_bot.send_error_notification(str(e), "Trading Logic Cycle")
        except Exception as telegram_error:
            logger.error(f"Failed to send error notification via Telegram: {telegram_error}")
    
    finally:
        logger.info(f"--- Trading Logic Cycle for {config.SYMBOL} Complete ---")

def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    global bot_running
    logger.info("Bot stopped manually by user (Ctrl+C).")
    bot_running = False
    
    # Cleanup operations
    try:
        # Stop any running processes
        logger.info("Performing cleanup operations...")
        
        # Send shutdown notification
        if config.TELEGRAM_ENABLED:
            telegram_bot.send_status_update("Bot Shutdown", {
                "Reason": "Manual stop by user",
                "Time": datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                "Status": "Graceful shutdown"
            })
        
        logger.info("Cleanup completed successfully")
        
    except Exception as e:
        logger.error(f"Error during cleanup: {e}")
    
    finally:
        sys.exit(0)

def main():
    """Main application entry point"""
    global bot_running
    
    try:
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        logger.info("Bot starting up with HTF analysis and Key Level integration...")
        
        # Load AI model
        load_ai_model()
        
        # Test Telegram connection
        if config.TELEGRAM_ENABLED:
            try:
                logger.info("Telegram notifications enabled")
                # Send startup notification
                telegram_bot.send_status_update("Bot Started", {
                    "Version": "FlowAI v2.1",
                    "Symbol": config.SYMBOL,
                    "Timeframe": config.TIMEFRAME,
                    "AI Model": "Loaded" if ai_model else "Not Available",
                    "Time": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                })
            except Exception as e:
                logger.warning(f"Telegram setup issue: {e}")
        
        logger.info("Running initial trading logic cycle on startup...")
        run_trading_logic()
        
        # Schedule regular analysis
        schedule.every(config.SCHEDULE_INTERVAL_MINUTES).minutes.do(run_trading_logic)
        
        logger.info(f"Scheduler started. Analysis every {config.SCHEDULE_INTERVAL_MINUTES} minutes.")
        logger.info("Bot is now running. Press Ctrl+C to stop.")
        
        # Main loop
        while bot_running:
            try:
                schedule.run_pending()
                time.sleep(1)
            except KeyboardInterrupt:
                logger.info("Keyboard interrupt received")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                logger.error(f"Traceback: {traceback.format_exc()}")
                
                # Send error notification
                try:
                    telegram_bot.send_error_notification(str(e), "Main Loop")
                except:
                    pass
                
                # Continue running unless it's a critical error
                time.sleep(5)
                
    except KeyboardInterrupt:
        logger.info("Bot stopped manually by user (Ctrl+C).")
    except Exception as e:
        logger.error(f"Critical error in main loop: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        
        # Send critical error notification
        try:
            telegram_bot.send_error_notification(f"Critical Error: {str(e)}", "Main Application")
        except:
            pass
            
    finally:
        logger.info("Bot shutdown.")
        bot_running = False

if __name__ == "__main__":
    main()
