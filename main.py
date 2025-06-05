import asyncio
import schedule
import time
import os
import joblib
import pandas as pd # Keep for type hints if needed, or direct use
# numpy typically imported by pandas or scikit-learn, direct import often not needed here

# Import from the new package structure
from flow_ai_core import config
from flow_ai_core import data_handler
from flow_ai_core import ict_analysis
from flow_ai_core import telegram_bot
from flow_ai_core import utils
from flow_ai_core.model_definition import get_model_info # Example if model_definition.py had something
# If train_model.engineer_features is used by get_ai_prediction, it needs careful import
# Assuming get_ai_prediction becomes part of flow_ai_core.ai_predictor or similar later
# For now, if train_model.py is in root and contains engineer_features:
from train_model import engineer_features


# Global variable for the AI model instance (pipeline)
ai_model_pipeline_instance = None
AI_PREDICTION_MAP = {0: "HOLD", 1: "BUY", 2: "SELL"} # Ensure this map is correct for your AI model's output


def load_ai_model(model_path: str):
    global ai_model_pipeline_instance
    if not model_path or not os.path.exists(model_path):
        utils.logger.error(f"AI Model file not found at '{model_path}'. AI features disabled.")
        ai_model_pipeline_instance = None; return None
    try:
        utils.logger.info(f"Attempting to load AI model pipeline from {model_path}...")
        ai_model_pipeline_instance = joblib.load(model_path)
        utils.logger.info(f"AI Model pipeline loaded: {type(ai_model_pipeline_instance)}")
        return ai_model_pipeline_instance
    except Exception as e:
        utils.logger.error(f"Error loading AI model: {e}", exc_info=True)
        ai_model_pipeline_instance = None; return None

def get_ai_prediction(processed_ltf_data: pd.DataFrame, model_pipeline):
    # This function uses `engineer_features` from `train_model.py`
    if model_pipeline is None: return None, None
    if processed_ltf_data.empty: 
        utils.logger.warning("Processed LTF data is empty for AI prediction.")
        return None, None
        
    utils.logger.info(f"Getting AI prediction. LTF data shape for FE: {processed_ltf_data.shape}")
    try:
        X_live_features = engineer_features(processed_ltf_data.copy()) # from train_model.py
        if X_live_features.empty: 
            utils.logger.warning("Feature engineering for AI prediction resulted in empty DataFrame.")
            return None, None
            
        latest_features = X_live_features.iloc[-1:]
        if latest_features.isnull().values.any():
            utils.logger.warning(f"NaNs in latest features for AI pred:\n{latest_features.to_string()}")
            latest_features = latest_features.fillna(0) # Basic imputation

        prediction_numeric = model_pipeline.predict(latest_features)
        prediction_proba = None
        if hasattr(model_pipeline, "predict_proba"): # Check if the model has predict_proba
            try:
                prediction_proba = model_pipeline.predict_proba(latest_features)
            except Exception as e_proba:
                utils.logger.warning(f"Could not get predict_proba: {e_proba}")
        
        predicted_label = AI_PREDICTION_MAP.get(prediction_numeric[0], "UNKNOWN")
        proba_to_log = prediction_proba[0] if prediction_proba is not None and len(prediction_proba) > 0 else 'N/A'
        utils.logger.info(f"AI raw: {prediction_numeric[0]}, Label: {predicted_label}, Proba: {proba_to_log}")
        return predicted_label, prediction_proba[0] if prediction_proba is not None and len(prediction_proba) > 0 else None
    except Exception as e:
        utils.logger.error(f"Error during AI prediction: {e}", exc_info=True)
        return None, None


async def run_trading_logic():
    utils.logger.info(f"--- Starting Trading Logic Cycle for {config.SYMBOL} (Primary TF: {config.TIMEFRAME}) ---")
    global ai_model_pipeline_instance

    try:
        primary_tf_feature_lookback = max(config.AI_RETURN_PERIODS, default=0) + \
                                      config.AI_VOLATILITY_PERIOD + \
                                      config.AI_ICT_FEATURE_LOOKBACK + \
                                      config.ICT_SWING_LOOKBACK_PERIODS + \
                                      config.ICT_MSS_SWING_LOOKBACK + \
                                      config.ICT_PD_ARRAY_LOOKBACK_PERIODS + \
                                      50 
        primary_tf_total_limit = config.CANDLE_LIMIT + primary_tf_feature_lookback

        multi_tf_data = data_handler.get_multiple_timeframe_data(
            symbol=config.SYMBOL, primary_timeframe=config.TIMEFRAME,
            htf_strings=config.HTF_TIMEFRAMES,
            primary_limit=primary_tf_total_limit, htf_limit=config.HTF_LOOKBACK_CANDLES
        )

        ltf_df = multi_tf_data.get(config.TIMEFRAME)
        if ltf_df is None or ltf_df.empty:
            utils.logger.error(f"Primary TF ({config.TIMEFRAME}) data missing. Aborting.")
            return
        
        current_ltf_timestamp = ltf_df.index[-1]
        htf_data_for_analysis = {tf: df for tf, df in multi_tf_data.items() if tf != config.TIMEFRAME and not df.empty}

        overall_htf_bias, htf_bias_reason = "NEUTRAL", "HTF data unavailable"
        if htf_data_for_analysis:
            overall_htf_bias, htf_bias_reason = ict_analysis.get_overall_htf_bias(htf_data_for_analysis)
        else:
            utils.logger.warning("No valid HTF data for bias. Defaulting to NEUTRAL HTF bias.")

        key_htf_levels = []
        if htf_data_for_analysis:
            key_htf_levels = ict_analysis.identify_key_htf_levels(htf_data_for_analysis, current_ltf_timestamp)
        else:
            utils.logger.warning("No valid HTF data for identifying key levels.")
        
        ltf_signals = ict_analysis.get_ltf_signals(ltf_df.copy(), overall_htf_bias, htf_bias_reason, key_htf_levels)

        ai_confirmation_label, ai_probabilities = None, None
        if ai_model_pipeline_instance and not ltf_df.empty : 
            ai_confirmation_label, ai_probabilities = get_ai_prediction(ltf_df.copy(), ai_model_pipeline_instance)
            # Logging is now inside get_ai_prediction

        if not ltf_signals:
            utils.logger.info("No LTF signals generated (after HTF filtering & level checks).")
        
        active_trade_signal_sent = False
        for signal in ltf_signals:
            utils.logger.info(f"Evaluating LTF Signal (HTF Bias: {signal.get('htf_bias_at_signal', overall_htf_bias)}): {signal.get('type')}")
            
            trade_type_emoji = "📈" if signal.get('trade_type') == 'buy' else "📉"
            price_precision = config.price_precision 
            title = f"{trade_type_emoji} *{config.SYMBOL} ({config.TIMEFRAME}) - {signal.get('trade_type', 'N/A').upper()} Signal* {trade_type_emoji}"
            
            message_parts = [title]
            message_parts.append(f"🔹 *HTF Bias ({'/'.join(config.HTF_TIMEFRAMES) if config.HTF_TIMEFRAMES else 'N/A'})*: `{signal.get('htf_bias_at_signal', overall_htf_bias)}`")
            message_parts.append(f"🔹 *LTF Signal Type*: `{signal.get('type', 'Unknown ICT')}`")
            message_parts.append(f"🔹 *Entry Level (approx)*: `{signal.get('price_level', 0.0):.{price_precision}f}`")
            if 'stop_loss_suggestion' in signal:
                message_parts.append(f"🔹 *Stop Loss (suggested)*: `{signal.get('stop_loss_suggestion'):.{price_precision}f}`")
            message_parts.append(f"🔹 *Current LTF Close*: `{ltf_df['Close'].iloc[-1]:.{price_precision}f}`")
            message_parts.append(f"🔹 *LTF RSI*: `{signal.get('rsi_at_signal', 'N/A')}`")

            ict_reason = signal.get('message_reason', 'N/A')
            if ict_reason != 'N/A':
                message_parts.append(f"\n*ICT Analysis & Reason*:\n _{ict_reason}_")

            if signal.get('potential_obstacles'):
                message_parts.append(f"*Nearby HTF Obstacles*:")
                for obs in signal['potential_obstacles'][:2]: message_parts.append(f"  - _{obs}_")
            if signal.get('potential_targets'):
                message_parts.append(f"*Potential HTF Targets Further Out*:")
                for tar in signal['potential_targets'][:2]: message_parts.append(f"  - _{tar}_")
            
            message_parts.append("\n---") 
            message_parts.append("*AI Assistant Insights*:")
            
            should_send_signal_final = True 
            rsi_val = signal.get('rsi_at_signal', 50.0) # Ensure it's float for comparison
            if not isinstance(rsi_val, (int, float)): rsi_val = 50.0 # Default if not numeric

            if signal.get('trade_type') == 'buy' and rsi_val > config.RSI_OVERBOUGHT + 5 : should_send_signal_final = False
            if signal.get('trade_type') == 'sell' and rsi_val < config.RSI_OVERSOLD - 5 : should_send_signal_final = False
            
            if not should_send_signal_final:
                 utils.logger.info(f"LTF signal ({signal.get('type')}) fails basic RSI pre-check. RSI: {rsi_val}. Suppressing.")

            if should_send_signal_final and ai_model_pipeline_instance and ai_confirmation_label:
                ai_prob_str = ""
                if ai_probabilities is not None and len(ai_probabilities) == 3:
                     ai_prob_str = f"(H:{ai_probabilities[0]:.0%}, B:{ai_probabilities[1]:.0%}, S:{ai_probabilities[2]:.0%})"
                
                message_parts.append(f"  - Suggestion: `{ai_confirmation_label}` {ai_prob_str}")
                
                ai_confirms_trade = (signal.get('trade_type') == 'buy' and ai_confirmation_label == "BUY") or \
                                    (signal.get('trade_type') == 'sell' and ai_confirmation_label == "SELL")

                if ai_confirms_trade:
                    confidence_msg = "  - Verdict: *AI Confirms Trade Direction!* 👍"
                    if ai_probabilities is not None and len(ai_probabilities) == 3:
                        prob_of_action = ai_probabilities[1] if signal.get('trade_type') == 'buy' else ai_probabilities[2]
                        if prob_of_action >= 0.70: confidence_msg = "  - Verdict: *AI Strongly Confirms!* 🔥"
                        elif prob_of_action >= 0.55: confidence_msg = "  - Verdict: *AI Confirms.* 👍"
                        else: 
                            confidence_msg = "  - Verdict: *AI Confirms (Low Confidence).* 🤔"
                            # Option: should_send_signal_final = False # Suppress if AI confidence is too low
                    message_parts.append(confidence_msg)
                elif ai_confirmation_label == "HOLD":
                    message_parts.append("  - Verdict: *AI Suggests HOLD. Signal Suppressed.* ⚠️")
                    should_send_signal_final = False 
                else: # AI conflicts
                    message_parts.append("  - Verdict: *AI Suggests Opposite! Signal Suppressed.* 🛑")
                    should_send_signal_final = False 
            elif ai_model_pipeline_instance and not ai_confirmation_label :
                 message_parts.append("  - _Prediction currently unavailable (AI model error or no data)._")
            elif not ai_model_pipeline_instance: 
                message_parts.append("  - _AI Not Consulted (model unavailable)._")
            # else: # No AI model loaded or no signal, but should_send_signal_final might still be true if only based on ICT
            #     pass # No AI insight to add if AI wasn't consulted and should_send_signal_final is true from ICT

            if should_send_signal_final:
                final_message = "\n".join(message_parts)
                await telegram_bot.send_telegram_message(config.TELEGRAM_TOKEN, config.TELEGRAM_CHAT_ID, final_message)
                active_trade_signal_sent = True
                utils.logger.info(f"Sent combined signal message for {signal.get('type')}")
            else:
                utils.logger.info(f"LTF signal ({signal.get('type')}) was generated but suppressed by AI or other final conditions.")

        if not active_trade_signal_sent and ltf_signals: 
            utils.logger.info("LTF signals were generated, but none met sending criteria after AI/final checks.")
        
        utils.logger.info(f"--- Trading Logic Cycle for {config.SYMBOL} Complete ---")

    except Exception as e:
        utils.logger.error(f"Unhandled error in trading logic cycle: {e}", exc_info=True)
        try:
            await telegram_bot.send_telegram_message(
                config.TELEGRAM_TOKEN, 
                config.TELEGRAM_CHAT_ID, 
                f"⚠️ *Bot Error in {config.SYMBOL} Cycle* ⚠️\n`{str(e)}`\nCheck logs for details."
            )
        except Exception as tel_e:
            utils.logger.error(f"Failed to send error notification via Telegram: {tel_e}")


async def main_async_loop():
    global ai_model_pipeline_instance
    utils.setup_logging() # Call setup_logging here after config (and its LOG_LEVEL) is loaded.
    utils.logger.info("Bot starting up with HTF analysis and Key Level integration...")
    
    # Load AI model once at startup
    ai_model_pipeline_instance = load_ai_model(config.MODEL_PATH)
    if not ai_model_pipeline_instance:
        utils.logger.warning(f"Continuing without AI features as model '{config.MODEL_PATH}' could not be loaded.")
    
    utils.logger.info("Running initial trading logic cycle on startup...")
    await run_trading_logic() 

    # Schedule periodic runs
    def job_wrapper():
        # This wrapper is needed because 'schedule' library executes the job in the main thread,
        # but our run_trading_logic is async. We need to get the event loop of the main thread
        # where asyncio.run(main_async_loop()) was called and run the coroutine there.
        # However, a simpler approach if the main loop is already async is to use asyncio.create_task
        # or ensure the scheduler itself is async-compatible (APScheduler).
        # For 'schedule' library, a common pattern is to run it in a separate thread that has its own loop,
        # or use `asyncio.run_coroutine_threadsafe` if interacting with an existing loop.
        # Given our structure, a simple lambda with create_task should work if the scheduler's thread
        # can access the main event loop correctly, or if run_pending() is awaited in the main async loop.
        asyncio.create_task(run_trading_logic())


    schedule.every(config.SCHEDULE_INTERVAL_MINUTES).minutes.do(job_wrapper)
    utils.logger.info(f"Scheduler started. Analysis every {config.SCHEDULE_INTERVAL_MINUTES} minutes.")
    utils.logger.info("Bot is now running. Press Ctrl+C to stop.")
    
    while True:
        schedule.run_pending()
        await asyncio.sleep(1) # Check schedule every second without blocking the loop hard

if __name__ == "__main__":
    # utils.setup_logging() # Moved to main_async_loop to ensure config is loaded first
    try:
        asyncio.run(main_async_loop())
    except KeyboardInterrupt:
        utils.logger.info("Bot stopped manually by user (Ctrl+C).")
    except Exception as e:
        utils.logger.critical(f"Critical error in main application scope: {e}", exc_info=True)
    finally:
        utils.logger.info("Bot shutdown.")