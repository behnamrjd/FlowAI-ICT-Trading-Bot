import pandas as pd
import numpy as np
import ccxt
import ta as talib
from typing import Dict, List, Optional 

# Use relative imports for modules within the same package
from .utils import logger
from . import config # Allows access to config.SYMBOL, config.RSI_PERIOD etc.

# Global cache for HTF data (simple in-memory cache)
HTF_DATA_CACHE: Dict[str, pd.DataFrame] = {}
CACHE_EXPIRY_SECONDS = 3600 # Cache HTF data for 1 hour (adjust based on HTF)
LAST_FETCH_TIMES: Dict[str, pd.Timestamp] = {}


def fetch_ohlcv_data(symbol: str, timeframe: str, limit: int, 
                     exchange_id: str = config.CCXT_EXCHANGE_ID, # Use config directly
                     params: Optional[Dict] = None,
                     use_cache: bool = False
                    ) -> pd.DataFrame:
    """
    Fetches OHLCV data. Can now optionally use a simple cache for HTF data.
    """
    # Use a more specific cache key if limit can vary for the same TF (though usually fixed for HTF)
    cache_key = f"{exchange_id}_{symbol}_{timeframe}" 
    current_time_utc = pd.Timestamp.now(tz='UTC')

    if use_cache and cache_key in HTF_DATA_CACHE:
        last_fetch_time = LAST_FETCH_TIMES.get(cache_key)
        # Check if cache has expired or if the requested limit is significantly different (might indicate stale cache for a new need)
        # For simplicity, only time-based expiry is checked here.
        if last_fetch_time and (current_time_utc - last_fetch_time).total_seconds() < CACHE_EXPIRY_SECONDS:
            # Additionally, ensure the cached data has enough records if limit has changed
            # This simplistic cache doesn't handle varying limits well; assumes limit for HTF is consistent.
            # If config.HTF_LOOKBACK_CANDLES changes, cache will still serve old data until expiry.
            # A more robust cache would include `limit` in the key or have smarter invalidation.
            if len(HTF_DATA_CACHE[cache_key]) >= limit * 0.9: # Ensure cached data is reasonably close to requested limit
                logger.info(f"Using cached data for {symbol} {timeframe} (fetched at {last_fetch_time})")
                return HTF_DATA_CACHE[cache_key].copy() # Return a copy
            else:
                logger.info(f"Cache for {symbol} {timeframe} has insufficient data ({len(HTF_DATA_CACHE[cache_key])} vs {limit}). Re-fetching.")
        else:
            logger.info(f"Cache for {symbol} {timeframe} expired or not found. Re-fetching.")


    logger.info(f"Fetching OHLCV: {symbol} ({timeframe}), {limit} candles from {exchange_id}...")
    
    try:
        exchange_class = getattr(ccxt, exchange_id)
    except AttributeError:
        logger.error(f"Exchange '{exchange_id}' not found in CCXT.")
        return pd.DataFrame()

    exchange_config = {
        'enableRateLimit': True,
        # Add API keys from config if they exist (for exchanges that might need them even for public data, or for future private calls)
    }
    if config.CCXT_API_KEY and config.CCXT_API_SECRET:
        exchange_config['apiKey'] = config.CCXT_API_KEY
        exchange_config['secret'] = config.CCXT_API_SECRET
        
    exchange = exchange_class(exchange_config)
    fetch_params = params.copy() if params else {} # Work on a copy

    try:
        # Load markets once if not already loaded by the exchange instance potentially
        if not exchange.markets: # Some ccxt versions/exchanges might need explicit load
             logger.debug(f"Loading markets for {exchange_id}...")
             exchange.load_markets()

        # Symbol adjustment logic (XAU/USD vs XAU/USDT etc.)
        adjusted_symbol = symbol
        if symbol not in exchange.markets:
            potential_symbol_no_slash = symbol.replace('/', '')
            if potential_symbol_no_slash in exchange.markets:
                adjusted_symbol = potential_symbol_no_slash
            else:
                base_currency = symbol.split('/')[0]
                potential_symbol_usdt = f"{base_currency}/USDT"
                if potential_symbol_usdt in exchange.markets:
                    adjusted_symbol = potential_symbol_usdt
                else:
                    potential_symbol_usd = f"{base_currency}/USD" # Some exchanges might use /USD
                    if potential_symbol_usd in exchange.markets:
                        adjusted_symbol = potential_symbol_usd
                    else:
                        logger.error(f"Symbol {symbol} (and variants) not found on {exchange_id}.")
                        return pd.DataFrame()
        if adjusted_symbol != symbol:
            logger.info(f"Adjusted symbol from '{symbol}' to '{adjusted_symbol}' for exchange {exchange_id}.")


        ohlcv = exchange.fetch_ohlcv(adjusted_symbol, timeframe, limit=limit, params=fetch_params)
        if not ohlcv:
            logger.warning(f"No data returned from {exchange_id} for {adjusted_symbol} {timeframe}.")
            return pd.DataFrame()

        df = pd.DataFrame(ohlcv, columns=['Timestamp', 'Open', 'High', 'Low', 'Close', 'Volume'])
        df['Timestamp'] = pd.to_datetime(df['Timestamp'], unit='ms', utc=True)
        df.set_index('Timestamp', inplace=True)
        
        numeric_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
        for col in numeric_cols:
            df[col] = pd.to_numeric(df[col], errors='coerce')
        
        # Remove rows where essential OHLC data might be NaN after coercion (e.g. if exchange returned non-numeric string)
        df.dropna(subset=['Open', 'High', 'Low', 'Close'], inplace=True)
        df['Volume'].fillna(0, inplace=True) # Fill NaN volume with 0

        if df.empty:
            logger.warning(f"DataFrame became empty after numeric conversion/NaN drop for {adjusted_symbol} {timeframe}.")
            return pd.DataFrame()

        logger.info(f"Successfully fetched {len(df)} candles for {adjusted_symbol} {timeframe}.")
        
        if use_cache:
            HTF_DATA_CACHE[cache_key] = df.copy()
            LAST_FETCH_TIMES[cache_key] = current_time_utc
            logger.info(f"Cached data for {adjusted_symbol} {timeframe} at {current_time_utc}.")

        return df
    except ccxt.NetworkError as e:
        logger.error(f"CCXT NetworkError fetching {symbol} ({timeframe}): {e}")
    except ccxt.ExchangeError as e:
        logger.error(f"CCXT ExchangeError fetching {symbol} ({timeframe}): {e}")
    except Exception as e:
        logger.error(f"Unexpected error in fetch_ohlcv_data for {symbol} ({timeframe}): {e}", exc_info=True)
    
    return pd.DataFrame()


def preprocess_data(df: pd.DataFrame, 
                    rsi_period: Optional[int] = None, 
                    sma_period: Optional[int] = None) -> pd.DataFrame:
    """
    Preprocesses OHLCV data: Calculates SMA and RSI.
    Uses config values if periods are not provided.
    """
    if df.empty:
        # logger.debug("Preprocess_data: Input DataFrame is empty.") # Debug as this can be normal for failed HTF fetches
        return pd.DataFrame()
    
    df_out = df.copy()

    # Use config values if specific periods are not passed
    _rsi_period = rsi_period if rsi_period is not None else config.RSI_PERIOD
    _sma_period = sma_period if sma_period is not None else config.SMA_PERIOD

    if 'Close' not in df_out.columns or not pd.api.types.is_numeric_dtype(df_out['Close']):
        logger.error("'Close' column missing or not numeric in preprocess_data.")
        return pd.DataFrame() # Return empty if essential data is bad

    try:
        # Ensure enough data for indicator calculation
        if len(df_out) >= _sma_period:
            df_out[f'SMA_{_sma_period}'] = talib.SMA(df_out['Close'], timeperiod=_sma_period)
        else:
            logger.warning(f"Not enough data ({len(df_out)}) for SMA_{_sma_period}. Skipping SMA calculation.")
            df_out[f'SMA_{_sma_period}'] = np.nan
    except Exception as e:
        logger.error(f"Error calculating SMA_{_sma_period}: {e}")
        df_out[f'SMA_{_sma_period}'] = np.nan # Ensure column exists even if calculation fails

    try:
        if len(df_out) >= _rsi_period:
            df_out['RSI'] = talib.RSI(df_out['Close'], timeperiod=_rsi_period)
        else:
            logger.warning(f"Not enough data ({len(df_out)}) for RSI_{_rsi_period}. Skipping RSI calculation.")
            df_out['RSI'] = np.nan 
    except Exception as e:
        logger.error(f"Error calculating RSI_{_rsi_period}: {e}")
        df_out['RSI'] = np.nan

    # Drop initial NaNs created by indicators.
    # This might significantly shorten the DataFrame if periods are large and df is short.
    df_out.dropna(inplace=True) 
    
    # logger.debug(f"Preprocessed. Original shape: {df.shape}, New shape: {df_out.shape}")
    return df_out


def get_multiple_timeframe_data(symbol: str, primary_timeframe: str, htf_strings: List[str], 
                                primary_limit: int, htf_limit: int) -> Dict[str, pd.DataFrame]:
    """
    Fetches and preprocesses data for the primary timeframe and specified higher timeframes.
    """
    all_tf_data: Dict[str, pd.DataFrame] = {}

    logger.info(f"Fetching primary TF ({primary_timeframe}, {primary_limit} candles) data for {symbol}...")
    primary_df_raw = fetch_ohlcv_data(symbol, primary_timeframe, primary_limit, use_cache=False)
    if not primary_df_raw.empty:
        processed_primary = preprocess_data(primary_df_raw)
        if not processed_primary.empty:
            all_tf_data[primary_timeframe] = processed_primary
        else:
            logger.error(f"Preprocessing failed for primary TF {primary_timeframe}. It's empty.")
            all_tf_data[primary_timeframe] = pd.DataFrame() # Store empty to indicate attempt
    else:
        logger.error(f"Failed to fetch primary TF data for {symbol} {primary_timeframe}. Critical.")
        return {primary_timeframe: pd.DataFrame()} # Return dict with empty primary if critical fetch fails

    for htf in htf_strings:
        if htf == primary_timeframe: # Already fetched if primary_timeframe is in htf_strings
            if primary_timeframe not in all_tf_data or all_tf_data[primary_timeframe].empty:
                 logger.warning(f"Primary TF {primary_timeframe} (also listed as HTF) data missing or empty.")
            continue 
        
        logger.info(f"Fetching HTF ({htf}, {htf_limit} candles) data for {symbol}...")
        # For HTFs, we might want to fetch slightly more than htf_limit to ensure enough data after TA lib's NaN generation
        # if preprocess_data is called with different periods, but usually HTF indicators use standard periods.
        htf_df_raw = fetch_ohlcv_data(symbol, htf, htf_limit, use_cache=True)
        if not htf_df_raw.empty:
            processed_htf = preprocess_data(htf_df_raw) # Using default RSI/SMA periods from config for HTFs
            if not processed_htf.empty:
                all_tf_data[htf] = processed_htf
            else:
                logger.warning(f"Preprocessing failed for HTF {htf}. It's empty.")
                all_tf_data[htf] = pd.DataFrame()
        else:
            logger.warning(f"Failed to fetch data for HTF: {htf}. It will be skipped.")
            all_tf_data[htf] = pd.DataFrame() # Store empty to indicate attempt and failure

    # Log summary of fetched data
    for tf, df_check in all_tf_data.items():
        logger.debug(f"Data summary for TF '{tf}': {'Not Empty' if not df_check.empty else 'EMPTY'}, Shape: {df_check.shape if not df_check.empty else '(0,0)'}")

    return all_tf_data

# (The __main__ block from data_handler.py can be kept for direct testing of this module)
if __name__ == '__main__':
    from flow_ai_core.utils import setup_logging # For direct testing
    setup_logging()
    logger.info("Testing multi-timeframe data fetching in data_handler.py...")
    
    symbol_to_test = config.SYMBOL
    primary_tf = config.TIMEFRAME
    htfs_to_test = config.HTF_TIMEFRAMES
    
    primary_candles = 200 
    htf_candles = config.HTF_LOOKBACK_CANDLES 

    multi_tf_dataframes = get_multiple_timeframe_data(
        symbol_to_test, primary_tf, htfs_to_test, primary_candles, htf_candles
    )

    for tf, df_data in multi_tf_dataframes.items():
        if not df_data.empty:
            logger.info(f"Data for {tf} (first 3 rows):\n{df_data.head(3).to_string()}")
            logger.info(f"Data for {tf} (last 3 rows):\n{df_data.tail(3).to_string()}")
        else:
            logger.warning(f"No data retrieved for timeframe: {tf}")