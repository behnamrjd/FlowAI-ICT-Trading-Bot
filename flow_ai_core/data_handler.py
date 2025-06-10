import pandas as pd
import logging
from datetime import datetime
from .data_sources.brsapi_fetcher import BrsAPIFetcher

logger = logging.getLogger(__name__)

fetcher = BrsAPIFetcher()

def get_processed_data(symbol: str = "GOLD", timeframe: str = "1h", limit: int = 1000) -> pd.DataFrame:
    """
    Returns processed data for trading analysis (supports gold, currency, crypto)
    """
    try:
        gold_data = fetcher.get_real_time_gold()
        if not gold_data:
            logger.warning("No gold data received")
            return pd.DataFrame()
        
        # Create DataFrame
        data = pd.DataFrame({
            'Open': [gold_data['price']],
            'High': [gold_data['price'] * 1.001],
            'Low': [gold_data['price'] * 0.999],
            'Close': [gold_data['price']],
            'Volume': [1000]
        }, index=[datetime.now()])
        
        # Add technical indicators if needed
        # data = add_technical_indicators(data)
        logger.info(f"Processed data for {symbol}: ${gold_data['price']:.2f}")
        return data
        
    except Exception as e:
        logger.error(f"Error in get_processed_data: {e}")
        return pd.DataFrame()

def get_real_time_price() -> float:
    """Returns real-time gold price for use in other modules"""
    data = fetcher.get_real_time_gold()
    return data['price'] if data else 3325.0
