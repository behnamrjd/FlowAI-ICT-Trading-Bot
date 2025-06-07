#!/usr/bin/env python3
"""
FlowAI ICT Trading Bot - Advanced AI Model Trainer v2.0
Professional trading model with time-based and volatility features
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import classification_report, accuracy_score, confusion_matrix
import joblib
import sys
import logging
from datetime import datetime, time
import warnings
warnings.filterwarnings('ignore')

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Add project root to path
sys.path.append('.')
from flow_ai_core import data_handler, config

class AdvancedFeatureEngineer:
    """Advanced feature engineering for professional trading"""
    
    def __init__(self):
        self.high_volatility_hours = [
            (8, 10),   # London Open
            (13, 15),  # US Open
            (20, 22),  # Asian Session
        ]
        
    def create_advanced_features(self, df):
        """Create professional trading features"""
        features = pd.DataFrame(index=df.index)
        
        # === BASIC PRICE FEATURES ===
        features['price_change'] = df['Close'].pct_change().fillna(0)
        features['high_low_ratio'] = (df['High'] / df['Low']).fillna(1)
        features['close_position'] = (df['Close'] - df['Low']) / (df['High'] - df['Low'])
        features['close_position'] = features['close_position'].fillna(0.5)
        
        # === VOLATILITY FEATURES ===
        features['volatility_5'] = df['Close'].rolling(5).std().fillna(0)
        features['volatility_20'] = df['Close'].rolling(20).std().fillna(0)
        features['volatility_ratio'] = (features['volatility_5'] / features['volatility_20']).fillna(1)
        
        # ATR (Average True Range)
        high_low = df['High'] - df['Low']
        high_close = np.abs(df['High'] - df['Close'].shift())
        low_close = np.abs(df['Low'] - df['Close'].shift())
        true_range = np.maximum(high_low, np.maximum(high_close, low_close))
        features['atr'] = true_range.rolling(14).mean().fillna(0)
        features['atr_ratio'] = (true_range / features['atr']).fillna(1)
        
        # === VOLUME FEATURES ===
        features['volume_sma'] = df['Volume'].rolling(20).mean().fillna(df['Volume'])
        features['volume_ratio'] = (df['Volume'] / features['volume_sma']).fillna(1)
        features['volume_volatility'] = df['Volume'].rolling(10).std().fillna(0)
        
        # Price-Volume Relationship
        features['pv_trend'] = (features['price_change'] * np.log1p(features['volume_ratio'])).fillna(0)
        
        # === TECHNICAL INDICATORS ===
        # Moving Averages
        features['sma_5'] = df['Close'].rolling(5).mean().fillna(df['Close'])
        features['sma_20'] = df['Close'].rolling(20).mean().fillna(df['Close'])
        features['sma_50'] = df['Close'].rolling(50).mean().fillna(df['Close'])
        
        features['price_sma5_ratio'] = (df['Close'] / features['sma_5']).fillna(1)
        features['price_sma20_ratio'] = (df['Close'] / features['sma_20']).fillna(1)
        features['sma_cross'] = (features['sma_5'] / features['sma_20']).fillna(1)
        
        # RSI
        delta = df['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        features['rsi'] = 100 - (100 / (1 + rs))
        features['rsi'] = features['rsi'].fillna(50)
        features['rsi_normalized'] = (features['rsi'] - 50) / 50  # -1 to 1
        
        # Bollinger Bands
        bb_period = 20
        bb_std = 2
        bb_middle = df['Close'].rolling(bb_period).mean()
        bb_std_dev = df['Close'].rolling(bb_period).std()
        bb_upper = bb_middle + (bb_std_dev * bb_std)
        bb_lower = bb_middle - (bb_std_dev * bb_std)
        
        features['bb_position'] = (df['Close'] - bb_lower) / (bb_upper - bb_lower)
        features['bb_position'] = features['bb_position'].fillna(0.5)
        features['bb_width'] = ((bb_upper - bb_lower) / bb_middle).fillna(0)
        
        # === MOMENTUM FEATURES ===
        features['momentum_3'] = (df['Close'] / df['Close'].shift(3) - 1).fillna(0)
        features['momentum_5'] = (df['Close'] / df['Close'].shift(5) - 1).fillna(0)
        features['momentum_10'] = (df['Close'] / df['Close'].shift(10) - 1).fillna(0)
        
        # Rate of Change
        features['roc_5'] = ((df['Close'] - df['Close'].shift(5)) / df['Close'].shift(5) * 100).fillna(0)
        
        # === TIME-BASED FEATURES ===
        features['hour'] = df.index.hour
        features['day_of_week'] = df.index.dayofweek
        features['is_high_vol_time'] = features['hour'].apply(self._is_high_volatility_time)
        
        # Session indicators
        features['london_session'] = ((features['hour'] >= 8) & (features['hour'] <= 16)).astype(int)
        features['us_session'] = ((features['hour'] >= 13) & (features['hour'] <= 21)).astype(int)
        features['asian_session'] = ((features['hour'] >= 20) | (features['hour'] <= 2)).astype(int)
        
        # === MARKET STRUCTURE FEATURES ===
        # Support/Resistance proximity
        features['recent_high'] = df['High'].rolling(20).max()
        features['recent_low'] = df['Low'].rolling(20).min()
        features['distance_to_high'] = (features['recent_high'] - df['Close']) / df['Close']
        features['distance_to_low'] = (df['Close'] - features['recent_low']) / df['Close']
        
        # Trend strength
        features['trend_strength'] = features['sma_cross'] - 1  # Deviation from 1
        
        # === VOLATILITY REGIME ===
        vol_ma = features['volatility_20'].rolling(50).mean()
        features['vol_regime'] = (features['volatility_20'] > vol_ma).astype(int)
        
        # Fill any remaining NaN values
        features = features.fillna(method='ffill').fillna(0)
        
        logger.info(f"Created {len(features.columns)} advanced features")
        return features
    
    def _is_high_volatility_time(self, hour):
        """Check if hour is in high volatility periods"""
        for start, end in self.high_volatility_hours:
            if start <= hour <= end:
                return 1
        return 0

class AdvancedTargetCreator:
    """Create sophisticated trading targets"""
    
    def __init__(self):
        self.thresholds = {
            'strong_buy': 0.008,    # 0.8%
            'buy': 0.003,           # 0.3%
            'hold_upper': 0.002,    # 0.2%
            'hold_lower': -0.002,   # -0.2%
            'sell': -0.003,         # -0.3%
            'strong_sell': -0.008,  # -0.8%
        }
    
    def create_dynamic_targets(self, df, features, lookforward=5):
        """Create dynamic targets based on market conditions"""
        future_returns = df['Close'].shift(-lookforward) / df['Close'] - 1
        
        # Adjust thresholds based on volatility
        volatility = features['volatility_20']
        vol_multiplier = np.clip(volatility / volatility.median(), 0.5, 2.0)
        
        labels = []
        for i, ret in enumerate(future_returns):
            if pd.isna(ret):
                labels.append(2)  # HOLD
                continue
            
            # Dynamic thresholds based on volatility
            vol_mult = vol_multiplier.iloc[i] if i < len(vol_multiplier) else 1.0
            
            strong_buy_thresh = self.thresholds['strong_buy'] * vol_mult
            buy_thresh = self.thresholds['buy'] * vol_mult
            hold_upper_thresh = self.thresholds['hold_upper'] * vol_mult
            hold_lower_thresh = self.thresholds['hold_lower'] * vol_mult
            sell_thresh = self.thresholds['sell'] * vol_mult
            strong_sell_thresh = self.thresholds['strong_sell'] * vol_mult
            
            if ret > strong_buy_thresh:
                labels.append(4)  # STRONG_BUY
            elif ret > buy_thresh:
                labels.append(3)  # BUY
            elif ret > hold_upper_thresh:
                labels.append(2)  # HOLD
            elif ret > hold_lower_thresh:
                labels.append(2)  # HOLD
            elif ret > sell_thresh:
                labels.append(1)  # SELL
            else:
                labels.append(0)  # STRONG_SELL
        
        return np.array(labels)

def train_advanced_ai_model():
    """Train advanced AI model with professional features"""
    logger.info("🚀 Starting Advanced AI Model Training...")
    
    try:
        # Initialize components
        feature_engineer = AdvancedFeatureEngineer()
        target_creator = AdvancedTargetCreator()
        
        # Fetch training data
        logger.info("📊 Fetching training data...")
        symbol = config.SYMBOL
        timeframe = config.TIMEFRAME
        
        # Get more data for training
        df = data_handler.fetch_ohlcv_data(symbol, timeframe, limit=2000)
        
        if df.empty:
            logger.error("❌ No data available for training!")
            return False
        
        logger.info(f"✅ Fetched {len(df)} candles for training")
        
        # Create advanced features
        logger.info("🔧 Creating advanced features...")
        X = feature_engineer.create_advanced_features(df)
        
        # Create dynamic targets
        logger.info("🎯 Creating dynamic targets...")
        y = target_creator.create_dynamic_targets(df, X)
        
        # Remove last rows (no future data for labels)
        X = X[:-5]
        y = y[:-5]
        
        logger.info(f"📈 Features shape: {X.shape}")
        
        # Analyze target distribution
        unique, counts = np.unique(y, return_counts=True)
        target_names = ['STRONG_SELL', 'SELL', 'HOLD', 'BUY', 'STRONG_BUY']
        for i, count in enumerate(counts):
            if i < len(target_names):
                logger.info(f"🎯 {target_names[i]}: {count} samples ({count/len(y)*100:.1f}%)")
        
        # Check for valid data
        if len(X) < 200:
            logger.error("❌ Not enough data for training!")
            return False
        
        # Filter high-quality samples (high volatility times)
        high_vol_mask = X['is_high_vol_time'] == 1
        if high_vol_mask.sum() > 100:
            logger.info(f"🔥 Using {high_vol_mask.sum()} high-volatility samples for training")
            X_filtered = X[high_vol_mask]
            y_filtered = y[high_vol_mask]
        else:
            X_filtered = X
            y_filtered = y
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X_filtered, y_filtered, test_size=0.2, random_state=42, stratify=y_filtered
        )
        
        # Train model with balanced weights
        logger.info("🚀 Training Advanced Random Forest model...")
        
        # Calculate class weights
        unique_classes, class_counts = np.unique(y_train, return_counts=True)
        total_samples = len(y_train)
        class_weights = {}
        
        for cls, count in zip(unique_classes, class_counts):
            if cls == 2:  # HOLD
                class_weights[cls] = 1.0
            else:  # BUY/SELL variants
                class_weights[cls] = total_samples / (len(unique_classes) * count) * 2
        
        logger.info(f"📊 Class weights: {class_weights}")
        
        model = RandomForestClassifier(
            n_estimators=200,
            max_depth=15,
            min_samples_split=10,
            min_samples_leaf=5,
            random_state=42,
            class_weight=class_weights,
            n_jobs=-1
        )
        
        model.fit(X_train, y_train)
        
        # Evaluate
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        logger.info(f"🎯 Model Accuracy: {accuracy:.3f}")
        
        # Cross-validation
        cv_scores = cross_val_score(model, X_train, y_train, cv=5)
        logger.info(f"📊 Cross-validation scores: {cv_scores.mean():.3f} (+/- {cv_scores.std() * 2:.3f})")
        
        # Detailed classification report
        logger.info("\n📊 Classification Report:")
        print(classification_report(y_test, y_pred, target_names=target_names[:len(unique)]))
        
        # Feature importance
        feature_importance = pd.DataFrame({
            'feature': X.columns,
            'importance': model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        logger.info("🔝 Top 10 Important Features:")
        print(feature_importance.head(10))
        
        # Save model and metadata
        logger.info("💾 Saving model and metadata...")
        
        model_metadata = {
            'feature_names': list(X.columns),
            'target_names': target_names,
            'class_weights': class_weights,
            'thresholds': target_creator.thresholds,
            'training_accuracy': accuracy,
            'cv_score': cv_scores.mean(),
            'training_date': datetime.now().isoformat(),
            'feature_count': len(X.columns),
            'training_samples': len(X_train)
        }
        
        joblib.dump(model, 'model.pkl')
        joblib.dump(model_metadata, 'model_metadata.pkl')
        
        logger.info("✅ Advanced AI Model training completed successfully!")
        logger.info("📁 Model saved as: model.pkl")
        logger.info("📁 Metadata saved as: model_metadata.pkl")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Error during training: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return False

if __name__ == "__main__":
    success = train_advanced_ai_model()
    if success:
        print("\n🎉 Advanced AI Model ready for professional trading!")
    else:
        print("\n❌ Training failed!")
