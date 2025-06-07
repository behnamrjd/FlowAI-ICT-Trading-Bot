#!/usr/bin/env python3
"""
FlowAI ICT Trading Bot - Simple AI Model Trainer
Train basic machine learning model without complex indicator objects
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score
import joblib
import sys
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Add project root to path
sys.path.append('.')
from flow_ai_core import data_handler, config

def create_simple_features(df):
    """Create simple numeric features without indicator objects"""
    features = pd.DataFrame(index=df.index)
    
    # Basic price features
    features['price_change'] = df['Close'].pct_change().fillna(0)
    features['volatility'] = df['Close'].rolling(20).std().fillna(0)
    features['high_low_ratio'] = (df['High'] / df['Low']).fillna(1)
    features['volume_norm'] = (df['Volume'] / df['Volume'].rolling(20).mean()).fillna(1)
    
    # Simple moving averages (calculate manually)
    features['sma_5'] = df['Close'].rolling(5).mean().fillna(df['Close'])
    features['sma_20'] = df['Close'].rolling(20).mean().fillna(df['Close'])
    features['price_sma_ratio'] = (df['Close'] / features['sma_20']).fillna(1)
    
    # RSI calculation (simple version)
    delta = df['Close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
    rs = gain / loss
    features['rsi_simple'] = 100 - (100 / (1 + rs))
    features['rsi_simple'] = features['rsi_simple'].fillna(50)
    
    # Momentum features
    features['momentum_5'] = df['Close'] / df['Close'].shift(5) - 1
    features['momentum_10'] = df['Close'] / df['Close'].shift(10) - 1
    
    # Fill any remaining NaN values
    features = features.fillna(0)
    
    logger.info(f"Created {len(features.columns)} simple features")
    return features

def create_simple_targets(df):
    """Create simple target labels based on future price movement"""
    future_returns = df['Close'].shift(-5) / df['Close'] - 1
    labels = []
    
    for ret in future_returns:
        if pd.isna(ret):
            labels.append(0)  # HOLD
        elif ret > 0.01:  # 1% gain
            labels.append(1)  # BUY
        elif ret < -0.01:  # 1% loss
            labels.append(2)  # SELL
        else:
            labels.append(0)  # HOLD
    
    return np.array(labels)

def train_simple_ai_model():
    """Train simple AI model without complex indicators"""
    logger.info("🤖 Starting Simple AI Model Training...")
    
    try:
        # Fetch training data
        logger.info("📊 Fetching training data...")
        symbol = config.SYMBOL
        timeframe = config.TIMEFRAME
        
        # Get more data for training
        df = data_handler.fetch_ohlcv_data(symbol, timeframe, limit=1500)
        
        if df.empty:
            logger.error("❌ No data available for training!")
            return False
        
        logger.info(f"✅ Fetched {len(df)} candles for training")
        
        # Create features and targets
        logger.info("🔧 Creating features...")
        X = create_simple_features(df)
        y = create_simple_targets(df)
        
        # Remove last 5 rows (no future data for labels)
        X = X[:-5]
        y = y[:-5]
        
        logger.info(f"📈 Features shape: {X.shape}")
        logger.info(f"🎯 Target distribution: BUY={sum(y==1)}, SELL={sum(y==2)}, HOLD={sum(y==0)}")
        
        # Check for valid data
        if len(X) < 100:
            logger.error("❌ Not enough data for training!")
            return False
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        # Train model
        logger.info("🚀 Training Random Forest model...")
        model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=42,
            class_weight='balanced'
        )
        
        model.fit(X_train, y_train)
        
        # Evaluate
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        logger.info(f"🎯 Model Accuracy: {accuracy:.3f}")
        logger.info("\n📊 Classification Report:")
        print(classification_report(y_test, y_pred, target_names=['HOLD', 'BUY', 'SELL']))
        
        # Feature importance
        feature_importance = pd.DataFrame({
            'feature': X.columns,
            'importance': model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        logger.info("🔝 Top 5 Important Features:")
        print(feature_importance.head())
        
        # Save model
        logger.info("💾 Saving model...")
        joblib.dump(model, 'model.pkl')
        joblib.dump(list(X.columns), 'model_features.pkl')
        
        logger.info("✅ Simple AI Model training completed successfully!")
        logger.info("📁 Model saved as: model.pkl")
        logger.info("📁 Features saved as: model_features.pkl")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Error during training: {e}")
        return False

if __name__ == "__main__":
    success = train_simple_ai_model()
    if success:
        print("\n🎉 AI Model ready for production!")
    else:
        print("\n❌ Training failed!")
