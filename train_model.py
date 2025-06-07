import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import TimeSeriesSplit, RandomizedSearchCV
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, make_scorer, f1_score
from scipy.stats import randint

# Import از پکیج flow_ai_core
from flow_ai_core import config
from flow_ai_core import data_handler 
from flow_ai_core import ict_analysis 
from flow_ai_core.utils import logger, setup_logging


def engineer_features(df_input: pd.DataFrame):
    """
    Engineers features for the AI model, incorporating advanced ICT elements.
    `df_input` is expected to be the output of `data_handler.preprocess_data`
    (i.e., OHLCV + SMA + RSI).
    """
    logger.info(f"Starting advanced feature engineering. Initial data shape: {df_input.shape}")
    
    df = df_input.copy()
    features_df = pd.DataFrame(index=df.index)

    # --- 1. Basic TA features ---
    if 'RSI' in df.columns:
        features_df['RSI'] = df['RSI']
    else:
        features_df['RSI'] = np.nan 

    sma_col = f'SMA_{config.SMA_PERIOD}'
    if sma_col in df.columns and 'Close' in df.columns:
        features_df['SMA_diff_norm'] = (df['Close'] - df[sma_col]) / df[sma_col]
    else:
        features_df['SMA_diff_norm'] = np.nan

    for period in config.AI_RETURN_PERIODS: # Assumes AI_RETURN_PERIODS is a list of ints
        features_df[f'LogReturn_{period}'] = np.log(df['Close'] / df['Close'].shift(period))

    if config.AI_VOLATILITY_PERIOD > 0:
        log_returns_1p = np.log(df['Close'] / df['Close'].shift(1))
        features_df[f'Volatility_{config.AI_VOLATILITY_PERIOD}'] = log_returns_1p.rolling(window=config.AI_VOLATILITY_PERIOD).std()

    # --- 2. Generate ICT Elements across the entire DataFrame first ---
    df_with_swings = ict_analysis.identify_swing_points(df, lookback=config.ICT_SWING_LOOKBACK_PERIODS)
    all_fvgs = ict_analysis.identify_fvg(df_with_swings, fvg_threshold_percentage=config.FVG_THRESHOLD)
    all_order_blocks = ict_analysis.identify_order_blocks(df_with_swings, min_body_ratio=config.ICT_OB_MIN_BODY_RATIO)
    all_market_shifts = ict_analysis.analyze_market_structure_shift(df_with_swings, mss_swing_lookback=config.ICT_MSS_SWING_LOOKBACK)
    
    logger.debug(f"Total elements for feature eng: FVGs={len(all_fvgs)}, OBs={len(all_order_blocks)}, MSS={len(all_market_shifts)}")

    # --- 3. Create time-aware features from these ICT elements ---
    ict_feature_columns = [
        'FVG_bullish_recent', 'FVG_bearish_recent', 'Dist_bull_FVG_mid_norm', 'Dist_bear_FVG_mid_norm',
        'OB_bullish_recent', 'OB_bearish_recent', 'Dist_bull_OB_mid_norm', 'Dist_bear_OB_mid_norm',
        'Is_in_bull_OB_zone', 'Is_in_bear_OB_zone',
        'MSS_bullish_recent', 'MSS_bearish_recent', 'Time_since_bull_MSS', 'Time_since_bear_MSS'
    ]
    for col in ict_feature_columns:
        if 'Dist' in col or 'Time' in col : 
            features_df[col] = np.nan 
        else: 
            features_df[col] = 0

    df_freq_seconds = None
    if df.index.freq:
        df_freq_seconds = df.index.freq.delta.total_seconds()
    elif len(df.index) > 1:
        median_delta_seconds = (df.index.to_series().diff().median()).total_seconds()
        if median_delta_seconds > 0: df_freq_seconds = median_delta_seconds
    
    if not df_freq_seconds: 
        df_freq_seconds = 3600 
        logger.warning(f"DataFrame frequency undetermined for ICT features, defaulting to {df_freq_seconds}s.")

    ict_lookback_timedelta = pd.Timedelta(seconds=config.AI_ICT_FEATURE_LOOKBACK * df_freq_seconds)

    for i in range(len(df)):
        current_time = df.index[i]
        current_close = df['Close'].iloc[i]
        current_high = df['High'].iloc[i]
        current_low = df['Low'].iloc[i]

        if current_close <= 0: continue

        # FVG Features
        active_fvgs = [fvg for fvg in all_fvgs if fvg['detection_candle_timestamp'] <= current_time and \
                                                 (current_time - fvg['detection_candle_timestamp']) <= ict_lookback_timedelta]
        last_bull_fvg = next((fvg for fvg in reversed(active_fvgs) if fvg['type'] == 'bullish_fvg'), None)
        last_bear_fvg = next((fvg for fvg in reversed(active_fvgs) if fvg['type'] == 'bearish_fvg'), None)
        if last_bull_fvg:
            features_df.loc[current_time, 'FVG_bullish_recent'] = 1
            features_df.loc[current_time, 'Dist_bull_FVG_mid_norm'] = (current_close - last_bull_fvg['fvg_midpoint']) / current_close
        if last_bear_fvg:
            features_df.loc[current_time, 'FVG_bearish_recent'] = 1
            features_df.loc[current_time, 'Dist_bear_FVG_mid_norm'] = (current_close - last_bear_fvg['fvg_midpoint']) / current_close
            
        # Order Block (OB) Features
        active_obs = [ob for ob in all_order_blocks if ob['timestamp'] <= current_time and \
                                                     (current_time - ob['timestamp']) <= ict_lookback_timedelta]
        last_bull_ob = next((ob for ob in reversed(active_obs) if ob['type'] == 'bullish_ob'), None)
        last_bear_ob = next((ob for ob in reversed(active_obs) if ob['type'] == 'bearish_ob'), None)
        if last_bull_ob:
            features_df.loc[current_time, 'OB_bullish_recent'] = 1
            features_df.loc[current_time, 'Dist_bull_OB_mid_norm'] = (current_close - last_bull_ob['ob_midpoint']) / current_close
            if last_bull_ob['ob_bottom'] <= current_high and last_bull_ob['ob_top'] >= current_low:
                features_df.loc[current_time, 'Is_in_bull_OB_zone'] = 1
        if last_bear_ob:
            features_df.loc[current_time, 'OB_bearish_recent'] = 1
            features_df.loc[current_time, 'Dist_bear_OB_mid_norm'] = (current_close - last_bear_ob['ob_midpoint']) / current_close
            if last_bear_ob['ob_bottom'] <= current_high and last_bear_ob['ob_top'] >= current_low:
                features_df.loc[current_time, 'Is_in_bear_OB_zone'] = 1

        # Market Structure Shift (MSS) Features
        # Wider lookback for MSS relevance for "Time_since_..." features
        mss_relevance_timedelta = pd.Timedelta(seconds=config.AI_ICT_FEATURE_LOOKBACK * 2 * df_freq_seconds) 
        active_mss_events = [mss for mss in all_market_shifts if mss['timestamp'] <= current_time and \
                                                               (current_time - mss['timestamp']) <= mss_relevance_timedelta]
        last_bull_mss = next((mss for mss in reversed(active_mss_events) if mss['type'] == 'bullish_mss'), None)
        last_bear_mss = next((mss for mss in reversed(active_mss_events) if mss['type'] == 'bearish_mss'), None)
        if last_bull_mss:
            features_df.loc[current_time, 'MSS_bullish_recent'] = 1 # Flag if any recent bull_mss
            try:
                mss_idx = df.index.get_loc(last_bull_mss['timestamp'])
                features_df.loc[current_time, 'Time_since_bull_MSS'] = i - mss_idx
            except KeyError: 
                 features_df.loc[current_time, 'Time_since_bull_MSS'] = config.AI_ICT_FEATURE_LOOKBACK * 3 
        if last_bear_mss:
            features_df.loc[current_time, 'MSS_bearish_recent'] = 1
            try:
                mss_idx = df.index.get_loc(last_bear_mss['timestamp'])
                features_df.loc[current_time, 'Time_since_bear_MSS'] = i - mss_idx
            except KeyError:
                 features_df.loc[current_time, 'Time_since_bear_MSS'] = config.AI_ICT_FEATURE_LOOKBACK * 3

    # --- 4. Finalize features_df (handle NaNs) ---
    for col in features_df.columns:
        if 'Dist' in col: 
            features_df[col].fillna(0.0, inplace=True) 
        elif 'Time_since' in col: 
            features_df[col].fillna(config.AI_ICT_FEATURE_LOOKBACK * 3, inplace=True) 
    
    features_df.bfill(inplace=True) 
    features_df.fillna(0, inplace=True) 

    logger.info(f"Advanced feature engineering complete. Features shape: {features_df.shape}")
    # logger.debug(f"Feature columns: {features_df.columns.tolist()}")
    # logger.debug(f"Sample of engineered features (tail):\n{features_df.tail().to_string()}")
            
    return features_df

def define_target_variable(df: pd.DataFrame):
    """
    Defines the target variable (y) for the model.
    Predict: 0 (HOLD), 1 (BUY), 2 (SELL)
    """
    logger.info(f"Defining target variable. Data shape: {df.shape}")
    y = pd.Series(0, index=df.index, name="Target", dtype=int) 

    n_future = config.AI_TARGET_N_FUTURE_CANDLES
    profit_pct = config.AI_TARGET_PROFIT_PCT
    stop_loss_pct = config.AI_TARGET_STOP_LOSS_PCT

    for i in range(len(df) - n_future):
        current_close = df['Close'].iloc[i]
        future_slice = df.iloc[i+1 : i+1+n_future] 
        
        if future_slice.empty or current_close <= 0: continue

        buy_target_price = current_close * (1 + profit_pct)
        buy_stop_price = current_close * (1 - stop_loss_pct)
        sell_target_price = current_close * (1 - profit_pct)
        sell_stop_price = current_close * (1 + stop_loss_pct)

        buy_signal_triggered = False
        sell_signal_triggered = False

        for k in range(len(future_slice)):
            future_candle_high = future_slice['High'].iloc[k]
            future_candle_low = future_slice['Low'].iloc[k]

            # Check BUY scenario first
            if not buy_signal_triggered and not sell_signal_triggered:
                if future_candle_low <= buy_stop_price: # SL for BUY hit
                    break # Stop checking this path for BUY
                if future_candle_high >= buy_target_price: # TP for BUY hit
                    y.iloc[i] = 1 # BUY
                    buy_signal_triggered = True 
                    # If TP is hit, we consider it a successful BUY, regardless of later SL for SELL.
                    # Break from k loop to avoid re-assigning y.iloc[i]
                    break 
            
            # Check SELL scenario ONLY if BUY was not triggered in this k-loop pass
            # And no buy signal was already set for y.iloc[i]
            if not buy_signal_triggered and not sell_signal_triggered : 
                if future_candle_high >= sell_stop_price: # SL for SELL hit
                    break # Stop checking this path for SELL
                if future_candle_low <= sell_target_price: # TP for SELL hit
                    y.iloc[i] = 2 # SELL
                    sell_signal_triggered = True
                    break 
        # If loop finishes without break, y.iloc[i] remains 0 (HOLD)
                
    logger.info(f"Target variable defined. Value counts (0=HOLD,1=BUY,2=SELL):\n{y.value_counts(normalize=True).sort_index()}")
    return y


def train_ai_model():
    """
    Main function to fetch data, engineer features, define target,
    train the AI model (RandomForest with HPO), and save it.
    """
    setup_logging() # Called from main.py already, but good for standalone run
    logger.info("--- Starting AI Model Training (Advanced ICT Features & HPO) ---")

    safety_margin_for_features = max(config.AI_RETURN_PERIODS, default=0) + \
                                 config.AI_VOLATILITY_PERIOD + \
                                 config.AI_ICT_FEATURE_LOOKBACK + \
                                 config.ICT_SWING_LOOKBACK_PERIODS + \
                                 config.ICT_PD_ARRAY_LOOKBACK_PERIODS + \
                                 config.ICT_MSS_SWING_LOOKBACK + 50 
    
    raw_data_df = data_handler.fetch_ohlcv_data(
        symbol=config.SYMBOL, timeframe=config.TIMEFRAME,
        limit=config.AI_TRAINING_CANDLE_LIMIT + safety_margin_for_features,
        exchange_id=config.CCXT_EXCHANGE_ID
    )
    if raw_data_df.empty or len(raw_data_df) < config.AI_TRAINING_CANDLE_LIMIT / 2:
        logger.error("Insufficient data fetched for training. Aborting.")
        return

    processed_data_df = data_handler.preprocess_data(raw_data_df.copy())
    if processed_data_df.empty:
        logger.error("Preprocessing resulted in empty data. Aborting training.")
        return

    logger.info(f"Processed data for feature engineering shape: {processed_data_df.shape}")
    X_features = engineer_features(processed_data_df.copy()) 
    y_target = define_target_variable(processed_data_df.copy()) 

    common_index = X_features.index.intersection(y_target.index)
    X = X_features.loc[common_index] 
    y = y_target.loc[common_index] 

    # Drop rows if y is still NaN (e.g., end of series where target cannot be computed)
    # or if X has NaNs that persist after its internal filling (should be rare now)
    combined_df = pd.concat([X, y], axis=1).dropna(subset=X.columns.tolist() + [y.name]) # Drop if NaN in X or y
    
    if combined_df.empty:
        logger.error("No data left after aligning features and target and dropping NaNs. Aborting.")
        return

    X = combined_df.drop(columns=['Target'])
    y = combined_df['Target']

    if X.empty or y.empty or len(X) != len(y) or len(np.unique(y)) < 2: # Need at least two classes for classifier
        logger.error(f"Data integrity issue or <2 classes in y. X:{len(X)}, y:{len(y)}, unique_y:{np.unique(y)}. Aborting.")
        return

    logger.info(f"Final aligned data for training: X shape {X.shape}, y shape {y.shape}")
    
    # Chronological split
    train_size = int(len(X) * 0.8)
    X_train, X_test = X.iloc[:train_size], X.iloc[train_size:]
    y_train, y_test = y.iloc[:train_size], y.iloc[train_size:]

    if X_train.empty or X_test.empty:
        logger.error("Training or testing set is empty after split. Aborting.")
        return

    logger.info(f"Train size: {len(X_train)}, Test size: {len(X_test)}")
    logger.info(f"y_train distribution:\n{y_train.value_counts(normalize=True).sort_index()}")
    logger.info(f"y_test distribution:\n{y_test.value_counts(normalize=True).sort_index()}")

    pipeline = Pipeline([
        ('scaler', StandardScaler()),
        ('classifier', RandomForestClassifier(random_state=42, class_weight='balanced_subsample')) # 'balanced_subsample' for RF
    ])

    param_dist = {
        'classifier__n_estimators': randint(75, 300),
        'classifier__max_depth': [None] + list(randint(5, 35).rvs(5)), # Deeper trees
        'classifier__min_samples_split': randint(2, 20),
        'classifier__min_samples_leaf': randint(1, 20),
        'classifier__max_features': ['sqrt', 'log2', None] 
    }
    
    tscv = TimeSeriesSplit(n_splits=config.AI_HPO_CV_FOLDS)
    # Use F1 weighted for imbalanced classes, or macro if classes are somewhat balanced
    f1_scorer = make_scorer(f1_score, average='weighted', zero_division=0) 

    random_search = RandomizedSearchCV(
        pipeline, param_distributions=param_dist,
        n_iter=config.AI_HPO_N_ITER, cv=tscv,
        scoring=f1_scorer, random_state=42, n_jobs=-1, verbose=1 # n_jobs=-1 uses all cores
    )

    logger.info("Starting Hyperparameter Optimization with RandomizedSearchCV...")
    try:
        random_search.fit(X_train, y_train)
    except Exception as e:
        logger.error(f"Error during RandomizedSearchCV: {e}", exc_info=True)
        return
    
    best_model_pipeline = random_search.best_estimator_
    logger.info(f"Best parameters found: {random_search.best_params_}")
    logger.info(f"Best cross-validation F1 (weighted) score: {random_search.best_score_:.4f}")

    y_pred_test = best_model_pipeline.predict(X_test)
    logger.info("Best Model Evaluation on Test Set:")
    try:
        report = classification_report(y_test, y_pred_test, target_names=['HOLD (0)', 'BUY (1)', 'SELL (2)'], zero_division=0)
        logger.info(f"\n{report}")
    except Exception as e:
        logger.error(f"Could not generate classification report for test set: {e}")

    try:
        # Ensure the classifier step exists and is a RandomForest
        if 'classifier' in best_model_pipeline.named_steps and \
           isinstance(best_model_pipeline.named_steps['classifier'], RandomForestClassifier):
            rf_model = best_model_pipeline.named_steps['classifier']
            importances = rf_model.feature_importances_
            feature_names = X_train.columns # Should match features used for training
            feature_importance_df = pd.DataFrame({'feature': feature_names, 'importance': importances})
            feature_importance_df = feature_importance_df.sort_values(by='importance', ascending=False)
            logger.info("Feature Importances (from best model):")
            for _, row in feature_importance_df.head(15).iterrows(): # Log top 15
                 logger.info(f"- {row['feature']}: {row['importance']:.4f}")
        else:
            logger.warning("Classifier step not found or not a RandomForest, cannot log feature importances.")
    except Exception as e:
        logger.error(f"Could not extract/log feature importances: {e}")

    try:
        joblib.dump(best_model_pipeline, config.MODEL_PATH)
        logger.info(f"Trained AI model pipeline (best from HPO) saved to: {config.MODEL_PATH}")
    except Exception as e:
        logger.error(f"Error saving model: {e}", exc_info=True)

    logger.info("--- AI Model Training (Advanced ICT Features & HPO) Finished ---")

if __name__ == "__main__":
    train_ai_model()