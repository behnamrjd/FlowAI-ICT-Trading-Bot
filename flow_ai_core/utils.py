import logging
import sys
import os # To fetch LOG_LEVEL directly here to avoid circular import with config

# This logger instance will be configured by setup_logging
logger = logging.getLogger("FlowAI_Bot") # Give a specific name to the root logger of the app

def setup_logging():
    """Sets up basic logging configuration."""
    # Fetch LOG_LEVEL directly from environment or use a default
    # This avoids circular import: utils -> config -> utils (for logger)
    log_level_str = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, log_level_str, logging.INFO)
    
    if level == logging.NOTSET: # getattr returns 0 for NOTSET if string is invalid
        level = logging.INFO
        print(f"Warning: Invalid LOG_LEVEL '{log_level_str}'. Defaulting to INFO.", file=sys.stderr)

    # Configure the named logger
    logger.setLevel(level)

    # Prevent duplicating handlers if setup_logging is called multiple times (though it shouldn't be)
    if not logger.handlers:
        formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(module)s:%(lineno)d - %(message)s")
        
        # Console Handler
        ch = logging.StreamHandler(sys.stdout)
        ch.setFormatter(formatter)
        logger.addHandler(ch)

        # Optional: File Handler (uncomment to enable)
        # log_file_path = "flow_ai_bot.log" # Consider putting in data/logs/
        # try:
        #     fh = logging.FileHandler(log_file_path)
        #     fh.setFormatter(formatter)
        #     logger.addHandler(fh)
        # except Exception as e:
        #     logger.error(f"Failed to set up file logger at {log_file_path}: {e}", exc_info=True)

    # Silence overly verbose libraries if necessary by getting their loggers and setting level
    logging.getLogger("schedule").setLevel(logging.WARNING) # schedule library can be noisy
    # logging.getLogger("ccxt").setLevel(logging.INFO) # If ccxt is too verbose on DEBUG

    logger.info(f"Logging setup complete. Logger name: '{logger.name}', Level: {logging.getLevelName(logger.getEffectiveLevel())}")

# Note: setup_logging() should be called ONCE from main.py (or main_async_loop)
# *after* config.py might have been imported (though we made LOG_LEVEL independent here).