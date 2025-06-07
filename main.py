#!/usr/bin/env python3
"""
FlowAI ICT Trading Bot - Main Application
Advanced AI-Powered Gold Trading System with ICT Analysis
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
    """Load the trained AI model"""
    global ai_model, ai_features
    
    try:
        logger.info("Attempting to load AI model pipeline from model.pkl...")
        ai_model = joblib.load(config.MODEL_PATH)
        logger.info(f"AI Model pipeline loaded: {type(ai_model)}")
        
        # Load feature names
        if os.path.exists(config.MODEL_FEATURES_PATH):
            ai_features = joblib.load(config.MODEL_FEATURES_PATH)
            logger.info(f"AI Model features loaded: {len(ai_features)} features")
        else:
            logger.warning("Model features file not found")
            
    except Exception as e:
        logger.error(f"Failed to load AI model: {e}")
        ai_model = None
        ai_features = None

def engineer_features(df):
    """Create simple features for AI model"""
    features = pd.DataFrame(index=df.index)
    
    # Basic price features
    features["price_change"] = df["Close"].pct_change().fillna(0)
    features["volatility"] = df["Close"].rolling(20).std().fillna(0)
    features["high_low_ratio"] = (df["High"] / df["Low"]).fillna(1)
    features["volume_norm"] = (df["Volume"] / df["Volume"].rolling(20).mean()).fillna(1)
    
    # Simple moving averages
    features["sma_5"] = df["Close"].rolling(5).mean().fillna(df["Close"])
    features["sma_20"] = df["Close"].rolling(20).mean().fillna(df["Close"])
    features["price_sma_ratio"] = (df["Close"] / features["sma_20"]).fillna(1)
    
    # RSI calculation
    delta = df["Close"].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    features["rsi_simple"] = 100 - (100 / (1 + rs))
    features["rsi_simple"] = features["rsi_simple"].fillna(50)
    
    # Momentum features
    features["momentum_5"] = df["Close"] / df["Close"].shift(5) - 1
    features["momentum_10"] = df["Close"] / df["Close"].shift(10) - 1
    
    return features.fillna(0)

def get_ai_prediction(processed_ltf_data: pd.DataFrame) -> Optional[Dict[str, Any]]:
    """Get AI model prediction"""
    global ai_model, ai_features
    
    try:
        logger.info(f"Getting AI prediction. LTF data shape for FE: {processed_ltf_data.shape}")
        
        # Engineer features
        X_live_features = engineer_features(processed_ltf_data.copy())
        
        if X_live_features.empty:
            logger.error("No features generated for AI prediction")
            return None
        
        # Use the last row for prediction
        X_latest = X_live_features.iloc[-1:].values
        
        if ai_model is None:
            logger.error("AI model not loaded")
            return None
        
        # Make prediction
        prediction = ai_model.predict(X_latest)[0]
        probabilities = ai_model.predict_proba(X_latest)[0]
        
        # Map prediction to label
        label_map = {0: 'HOLD', 1: 'BUY', 2: 'SELL'}
        predicted_label = label_map.get(prediction, 'HOLD')
        
        logger.info(f"AI raw: {prediction}, Label: {predicted_label}, Proba: {probabilities}")
        
        return {
            'prediction': prediction,
            'label': predicted_label,
            'probabilities': probabilities,
            'confidence': max(probabilities)
        }
        
    except Exception as e:
        logger.error(f"Error during AI prediction: {e}")
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
            
            if ai_signal['type'] != 'HOLD':
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

def main():
    """Main application entry point"""
    global bot_running
    
    try:
        # Setup signal handlers
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        logger.info("Bot starting up with HTF analysis and Key Level integration...")
        
        # Load AI model
        load_ai_model()
        
        # Test Telegram connection
        if config.TELEGRAM_ENABLED:
            telegram_bot.test_connection()
        
        # Run initial cycle
        logger.info("Running initial trading logic cycle on startup...")
        run_trading_logic()
        
        # Schedule regular analysis
        schedule.every(config.SCHEDULE_INTERVAL_MINUTES).minutes.do(run_trading_logic)
        
        logger.info(f"Scheduler started. Analysis every {config.SCHEDULE_INTERVAL_MINUTES} minutes.")
        logger.info("Bot is now running. Press Ctrl+C to stop.")
        
        # Main loop
        while bot_running:
            schedule.run_pending()
            time.sleep(1)
            
    except KeyboardInterrupt:
        logger.info("Bot stopped manually by user (Ctrl+C).")
    except Exception as e:
        logger.error(f"Critical error in main loop: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
    finally:
        logger.info("Bot shutdown.")

if __name__ == "__main__":
    main()
