#!/usr/bin/env python3
"""
FlowAI ICT Trading Bot - Advanced AI Model Trainer v3.0
Professional trading model with SMOTE, adaptive thresholds, and class balancing
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, cross_val_score, StratifiedKFold
from sklearn.metrics import classification_report, accuracy_score, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight
from imblearn.over_sampling import SMOTE
from imblearn.combine import SMOTETomek
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
        self.extended_hours = [
            (6, 12),   # Extended London
            (12, 18),  # Extended US
            (18, 24),  # Extended Asian
        ]
        
    def create_advanced_features(self, df):
        """Create professional trading features with infinity handling"""
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
        features['volatility_regime'] = (features['volatility_20'] / features['volatility_50']).fillna(1)
        
        # ATR with safe division
        high_low = df['High'] - df['Low']
        high_close = np.abs(df['High'] - df['Close'].shift())
        low_close = np.abs(df['Low'] - df['Close'].shift())
        true_range = np.maximum(high_low, np.maximum(high_close, low_close))
        features['atr'] = true_range.rolling(14).mean().fillna(0)
        features['atr_normalized'] = features['atr'] / df['Close'].squeeze()
        
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
        
        # Stochastic
        low_14 = df['Low'].rolling(14).min()
        high_14 = df['High'].rolling(14).max()
        features['stoch_k'] = 100 * ((df['Close'] - low_14) / (high_14 - low_14))
        features['stoch_k'] = features['stoch_k'].fillna(50)
        features['stoch_d'] = features['stoch_k'].rolling(3).mean()
        
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
        
        # Trading session indicators
        features['is_high_vol_time'] = features['hour'].apply(self._is_high_volatility_time)
        features['is_extended_time'] = features['hour'].apply(self._is_extended_time)
        features['session_strength'] = features['hour'].apply(self._get_session_strength)
        
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
        
        # Price action patterns
        features['doji'] = (np.abs(df['Open'] - df['Close']) / (df['High'] - df['Low']) < 0.1).astype(int)
        features['hammer'] = ((df['Close'] > df['Open']) & 
                            ((df['Open'] - df['Low']) > 2 * (df['Close'] - df['Open']))).astype(int)
        features['shooting_star'] = ((df['Open'] > df['Close']) & 
                                   ((df['High'] - df['Open']) > 2 * (df['Open'] - df['Close']))).astype(int)
        
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
        
        logger.info(f"Created {len(features.columns)} advanced features")
        return features
    
    def _is_high_volatility_time(self, hour):
        """Check if hour is in high volatility periods"""
        for start, end in self.high_volatility_hours:
            if start <= hour <= end:
                return 1
        return 0
    
    def _is_extended_time(self, hour):
        """Check if hour is in extended trading periods"""
        for start, end in self.extended_hours:
            if start <= hour <= end:
                return 1
        return 0
    
    def _get_session_strength(self, hour):
        """Get session strength score (0-1)"""
        # Peak hours get higher scores
        if 13 <= hour <= 16:  # London/US overlap
            return 1.0
        elif 8 <= hour <= 10 or 20 <= hour <= 22:  # Session opens
            return 0.8
        elif 10 <= hour <= 13 or 16 <= hour <= 20:  # Active sessions
            return 0.6
        else:  # Quiet hours
            return 0.3

class AdaptiveTargetCreator:
    """Create sophisticated trading targets with adaptive thresholds"""
    
    def __init__(self):
        self.base_thresholds = {
            'strong_buy': 0.008,    # 0.8%
            'buy': 0.003,           # 0.3%
            'hold_upper': 0.001,    # 0.1%
            'hold_lower': -0.001,   # -0.1%
            'sell': -0.003,         # -0.3%
            'strong_sell': -0.008,  # -0.8%
        }
    
    def create_adaptive_targets(self, df, features, lookforward=5):
        """Create adaptive targets based on market conditions"""
        future_returns = df['Close'].shift(-lookforward) / df['Close'] - 1
        
        # Market condition adjustments
        volatility = features['volatility_20']
        volume_ratio = features['volume_ratio']
        session_strength = features['session_strength']
        
        labels = []
        threshold_history = []
        
        for i, ret in enumerate(future_returns):
            if pd.isna(ret):
                labels.append(2)  # HOLD
                threshold_history.append(self.base_thresholds)
                continue
            
            # Adaptive threshold calculation
            if i < len(volatility):
                vol_mult = np.clip(volatility.iloc[i] / volatility.median(), 0.3, 2.5)
                vol_ratio = np.clip(volume_ratio.iloc[i], 0.5, 2.0)
                session_mult = session_strength.iloc[i]
                
                # Combine multipliers
                adaptive_mult = vol_mult * vol_ratio * session_mult
                adaptive_mult = np.clip(adaptive_mult, 0.2, 3.0)
            else:
                adaptive_mult = 1.0
            
            # Calculate adaptive thresholds
            adaptive_thresholds = {}
            for key, base_val in self.base_thresholds.items():
                adaptive_thresholds[key] = base_val * adaptive_mult
            
            threshold_history.append(adaptive_thresholds)
            
            # Apply thresholds
            if ret > adaptive_thresholds['strong_buy']:
                labels.append(4)  # STRONG_BUY
            elif ret > adaptive_thresholds['buy']:
                labels.append(3)  # BUY
            elif ret > adaptive_thresholds['hold_upper']:
                labels.append(2)  # HOLD
            elif ret > adaptive_thresholds['hold_lower']:
                labels.append(2)  # HOLD
            elif ret > adaptive_thresholds['sell']:
                labels.append(1)  # SELL
            else:
                labels.append(0)  # STRONG_SELL
        
        return np.array(labels), threshold_history

class AdvancedClassBalancer:
    """Advanced class balancing with SMOTE and intelligent sampling"""
    
    def __init__(self):
        self.target_distribution = {
            0: 0.15,  # STRONG_SELL: 15%
            1: 0.20,  # SELL: 20%
            2: 0.30,  # HOLD: 30%
            3: 0.20,  # BUY: 20%
            4: 0.15,  # STRONG_BUY: 15%
        }
    
    def balance_classes(self, X, y):
        """Apply advanced class balancing techniques"""
        logger.info("Applying advanced class balancing...")
        
        # Original distribution
        unique, counts = np.unique(y, return_counts=True)
        original_dist = dict(zip(unique, counts))
        logger.info(f"Original distribution: {original_dist}")
        
        # Calculate target counts
        total_samples = len(y)
        target_counts = {}
        for class_label in unique:
            if class_label in self.target_distribution:
                target_counts[class_label] = int(total_samples * self.target_distribution[class_label])
            else:
                target_counts[class_label] = counts[list(unique).index(class_label)]
        
        logger.info(f"Target distribution: {target_counts}")
        
        # Apply SMOTE for minority classes
        smote_strategy = {}
        for class_label, current_count in original_dist.items():
            target_count = target_counts.get(class_label, current_count)
            if target_count > current_count:
                smote_strategy[class_label] = target_count
        
        if smote_strategy:
            logger.info(f"Applying SMOTE with strategy: {smote_strategy}")
            smote = SMOTE(
                sampling_strategy=smote_strategy,
                random_state=42,
                k_neighbors=min(3, min(original_dist.values()) - 1)
            )
            X_resampled, y_resampled = smote.fit_resample(X, y)
            
            # Clean up with Tomek links
            smotetomek = SMOTETomek(random_state=42)
            X_final, y_final = smotetomek.fit_resample(X_resampled, y_resampled)
        else:
            X_final, y_final = X, y
        
        # Final distribution
        unique_final, counts_final = np.unique(y_final, return_counts=True)
        final_dist = dict(zip(unique_final, counts_final))
        logger.info(f"Final distribution: {final_dist}")
        
        return X_final, y_final
    
    def calculate_class_weights(self, y):
        """Calculate intelligent class weights"""
        classes = np.unique(y)
        
        # Compute balanced weights
        balanced_weights = compute_class_weight(
            'balanced',
            classes=classes,
            y=y
        )
        
        # Apply custom adjustments
        custom_weights = {}
        for i, class_label in enumerate(classes):
            base_weight = balanced_weights[i]
            
            # Boost trading signals (non-HOLD classes)
            if class_label != 2:  # Not HOLD
                custom_weights[class_label] = base_weight * 1.5
            else:
                custom_weights[class_label] = base_weight * 0.8
        
        logger.info(f"Custom class weights: {custom_weights}")
        return custom_weights

def train_advanced_ai_model():
    """Train advanced AI model with SMOTE and adaptive features"""
    logger.info("🚀 Starting Advanced AI Model Training v3.0...")
    
    try:
        # Initialize components
        feature_engineer = AdvancedFeatureEngineer()
        target_creator = AdaptiveTargetCreator()
        class_balancer = AdvancedClassBalancer()
        
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
        
        # Create adaptive targets
        logger.info("🎯 Creating adaptive targets...")
        y, threshold_history = target_creator.create_adaptive_targets(df, X)
        
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
        
        # Apply advanced class balancing
        X_balanced, y_balanced = class_balancer.balance_classes(X.values, y)
        
        # Calculate custom class weights
        class_weights = class_balancer.calculate_class_weights(y_balanced)
        
        # Split data with stratification
        X_train, X_test, y_train, y_test = train_test_split(
            X_balanced, y_balanced, 
            test_size=0.2, 
            random_state=42, 
            stratify=y_balanced
        )
        
        # Train advanced model
        logger.info("🚀 Training Advanced Random Forest model...")
        
        model = RandomForestClassifier(
            n_estimators=300,
            max_depth=20,
            min_samples_split=5,
            min_samples_leaf=2,
            max_features='sqrt',
            random_state=42,
            class_weight=class_weights,
            n_jobs=-1,
            bootstrap=True,
            oob_score=True
        )
        
        model.fit(X_train, y_train)
        
        # Evaluate
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        logger.info(f"🎯 Model Accuracy: {accuracy:.3f}")
        logger.info(f"🎯 OOB Score: {model.oob_score_:.3f}")
        
        # Cross-validation with stratification
        skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
        cv_scores = cross_val_score(model, X_train, y_train, cv=skf)
        logger.info(f"📊 Cross-validation scores: {cv_scores.mean():.3f} (+/- {cv_scores.std() * 2:.3f})")
        
        # Detailed classification report
        logger.info("\n📊 Classification Report:")
        available_targets = target_names[:len(unique)]
        print(classification_report(y_test, y_pred, target_names=available_targets))
        
        # Feature importance analysis
        feature_importance = pd.DataFrame({
            'feature': X.columns,
            'importance': model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        logger.info("🔝 Top 15 Important Features:")
        print(feature_importance.head(15))
        
        # Save model and enhanced metadata
        logger.info("💾 Saving model and metadata...")
        
        model_metadata = {
            'feature_names': list(X.columns),
            'target_names': target_names,
            'class_weights': class_weights,
            'adaptive_thresholds': target_creator.base_thresholds,
            'training_accuracy': accuracy,
            'oob_score': model.oob_score_,
            'cv_score': cv_scores.mean(),
            'cv_std': cv_scores.std(),
            'training_date': datetime.now().isoformat(),
            'feature_count': len(X.columns),
            'training_samples': len(X_train),
            'balanced_samples': len(X_balanced),
            'model_version': '3.0',
            'improvements': [
                'SMOTE class balancing',
                'Adaptive thresholds',
                'Extended feature set',
                'Custom class weights',
                'Enhanced time features'
            ]
        }
        
        joblib.dump(model, 'model.pkl')
        joblib.dump(model_metadata, 'model_metadata.pkl')
        
        # Backward compatibility
        joblib.dump(list(X.columns), 'model_features.pkl')
        
        logger.info("✅ Advanced AI Model training completed successfully!")
        logger.info("📁 Model saved as: model.pkl")
        logger.info("📁 Metadata saved as: model_metadata.pkl")
        logger.info("📁 Features saved as: model_features.pkl")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Error during training: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return False

if __name__ == "__main__":
    success = train_advanced_ai_model()
    if success:
        print("\n🎉 Advanced AI Model v3.0 ready for professional trading!")
    else:
        print("\n❌ Training failed!")
