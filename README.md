# FlowAI ICT Trading Bot

## Advanced AI-Powered Gold Trading System with ICT Analysis

**Version:** 2.1 (Fixed All Issues - July 2024)

**FlowAI** is an innovative trading bot designed for the gold market (XAUUSD), leveraging advanced AI techniques and Inner Circle Trader (ICT) methodologies to identify high-probability trading setups. This system aims to provide intelligent trading signals and can be configured for automated execution (future feature).

---

### 🔑 Key Features:

1.  **🧠 AI-Powered Predictions:**
    *   Utilizes a machine learning model (details in `models/`) for predictive analysis.
    *   Advanced feature engineering based on price action, volatility, volume, and technical indicators.
    *   Adaptive learning capabilities (planned for future versions).

2.  **📊 ICT Analysis Core:**
    *   **Order Blocks (OB):** Automatic detection of bullish and bearish order blocks.
    *   **Fair Value Gaps (FVG):** Identification of market imbalances and inefficiencies.
    *   **Liquidity Sweeps:** Detection of stop hunts and liquidity grabs.
    *   **Market Structure Shifts (MSS):** Recognition of changes in market direction.
    *   **Premium/Discount Arrays:** Analysis of price levels relative to recent trading ranges.

3.  **📈 Multi-Timeframe Analysis:**
    *   Configurable Higher Time Frame (HTF) analysis to establish directional bias.
    *   Lower Time Frame (LTF) entries aligned with HTF context.

4.  **⚙️ Comprehensive Configuration:**
    *   Detailed settings via `.env` file and `flow_ai_core/config.py`.
    *   Interactive configuration wizard for backtesting parameters (`config_wizard.py`).

5.  **🤖 Telegram Integration (`telegram_bot.py`):**
    *   Real-time trading signals with detailed analysis.
    *   User commands for status, manual analysis, and (admin) controls.
    *   Tiered access for signals (Free, Premium, Admin).
    *   System health and status notifications.

6.  **⏱️ Backtesting Engine (`flow_ai_core/backtest_engine.py`):**
    *   Simulate trading strategies on historical data (currently uses generated data, historical API integration planned).
    *   Performance metrics and equity curve generation.

7.  **🛡️ Risk Management (Conceptual - Needs Full Implementation):**
    *   Parameters for risk per trade, max daily loss, etc. (defined in config).
    *   (Note: Full execution logic for risk management needs to be built into the trading execution layer).

8.  **📄 Logging & Monitoring:**
    *   Detailed logging throughout the application.
    *   System status updates via Telegram.

---

### 🚀 Getting Started:

1.  **Clone the Repository:**
    ```bash
    git clone <repository_url>
    cd FlowAI-ICT-Trading-Bot
    ```

2.  **Installation (Using `Install.sh`):**
    The `Install.sh` script attempts to automate the setup of a virtual environment and installation of dependencies.
    ```bash
    bash Install.sh
    ```
    *   Ensure you have Python 3.8+ installed.
    *   The script will create a virtual environment named `flowai_env`.

3.  **Manual Installation (Alternative):**
    *   Create a virtual environment:
        ```bash
        python3 -m venv flowai_env
        source flowai_env/bin/activate
        ```
    *   Install dependencies:
        ```bash
        pip install -r requirements.txt
        ```
        *Note: You might need to install the TA-Lib C library manually before `pip install TA-Lib` can succeed. Refer to TA-Lib documentation for your OS.*

4.  **Configuration:**
    *   Rename `.env.example` to `.env`.
    *   Fill in your API keys and Telegram bot token in the `.env` file:
        *   `TELEGRAM_BOT_TOKEN`
        *   `BRSAPI_KEY` (from BrsApi.ir)
        *   `TELEGRAM_ADMIN_IDS` (your Telegram user ID)
    *   Review and adjust other parameters in `flow_ai_core/config.py` or via environment variables.

5.  **Running the Bot:**
    *   **Main Trading Bot (with AI and ICT analysis for potential future execution):**
        ```bash
        python main.py
        ```
    *   **Telegram Bot (for signals and interaction):**
        ```bash
        python telegram_bot.py
        ```
    *   **Configuration Wizard (for backtest settings):**
        ```bash
        python config_wizard.py
        ```

---

### 🛠️ Project Structure:

*   `main.py`: Main application entry point for the core trading logic.
*   `telegram_bot.py`: Entry point for the Telegram bot interface.
*   `config_wizard.py`: Interactive wizard for backtest configuration.
*   `flow_ai_core/`: Core modules of the bot.
    *   `config.py`: Application configuration.
    *   `data_handler.py`: Data fetching and processing (including ICT features).
    *   `ict_analysis.py`: ICT specific analysis functions.
    *   `ai_signal_engine.py`: Rule-based AI signal generation for Telegram.
    *   `backtest_engine.py`: Backtesting functionality.
    *   `model_definition.py`: (Intended for ML model structure).
    *   `data_sources/`: Modules for fetching data from external APIs (e.g., `brsapi_fetcher.py`).
    *   `telegram/`: Modules for Telegram bot functionality.
*   `models/`: (Intended for storing trained ML models, e.g., `flowai_model.pkl`).
*   `data/`: (Intended for storing historical data, etc.).
*   `logs/`: For log files.
*   `notebooks/`: Jupyter notebooks for experimentation and analysis.
*   `requirements.txt`: Python dependencies.
*   `Install.sh`: Installation script.
*   `README.md`: This file.

---

### 📜 Disclaimer:

*   **For Educational Purposes Only:** This software is provided for educational and research purposes.
*   **No Financial Advice:** The information and signals generated by this bot do not constitute financial advice.
*   **High Risk:** Trading, especially in markets like gold, carries a high level of risk. You could lose some or all of your investment.
*   **Use at Your Own Risk:** The developers and contributors are not responsible for any financial losses incurred by using this software.
*   **Thorough Testing Recommended:** Always backtest extensively and paper trade before considering any live deployment.

---

### 🤝 Contributing:

Contributions are welcome! Please follow standard Git practices (fork, branch, pull request).
Ensure code is well-commented and, if possible, include tests for new features.

---

**TODO / Future Enhancements:**

*   [ ] Implement real historical data fetching for `data_handler.py` instead of relying on generated data for live analysis.
*   [ ] Restore or retrain and integrate the primary ML model (`model.pkl`).
*   [ ] Implement full trade execution logic with broker integration.
*   [ ] Enhance risk management module with active position monitoring.
*   [ ] Add more comprehensive automated tests (unit, integration).
*   [ ] Improve documentation and code comments, standardize language to English.
*   [ ] Consider database integration for storing trades, signals, and market data.

```
