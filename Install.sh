#!/bin/bash

# ===================================================================
# FlowAI XAU Trading Bot - Advanced Installation & Management Script
# Version: 2.0
# Author: Behnam RJD
# Repository: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot
# ===================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Project Configuration
PROJECT_NAME="FlowAI-ICT-Trading-Bot"
PROJECT_DIR="/opt/$PROJECT_NAME"
REPO_URL="https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git"
VENV_DIR="$PROJECT_DIR/.venv"
CONFIG_FILE="$PROJECT_DIR/.env"
INSTALL_FLAG="$PROJECT_DIR/.installed"
LOG_FILE="/var/log/flowai_install.log"

# System Information
OS=$(uname -s)
ARCH=$(uname -m)
PYTHON_VERSION=""
CURRENT_USER=$(whoami)

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                FlowAI XAU Trading Bot v2.0                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}            Advanced AI-Powered Gold Trading System             ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${GREEN} ✅ AI Model Training (84.3% accuracy)                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN} ✅ Advanced ICT Trading Strategy                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN} ✅ HTF Multi-timeframe Analysis                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN} ✅ Yahoo Finance Real-time Data                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN} ✅ Telegram Integration                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN} ✅ Professional Risk Management                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${GREEN} ✅ 24/7 Automated Trading Signals                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    log_message "SUCCESS" "$1"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log_message "ERROR" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log_message "WARNING" "$1"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    log_message "INFO" "$1"
}

print_step() {
    echo -e "${PURPLE}🔧 $1${NC}"
    log_message "STEP" "$1"
}

pause_with_message() {
    echo ""
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -n 1 -s
}

confirm_action() {
    local message=$1
    echo -e "${YELLOW}$message (y/N): ${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ===================================================================
# SYSTEM DETECTION AND VALIDATION
# ===================================================================

detect_system() {
    print_step "Detecting system information..."
    
    echo -e "${CYAN}System Information:${NC}"
    echo -e "  OS: $OS"
    echo -e "  Architecture: $ARCH"
    echo -e "  User: $CURRENT_USER"
    
    # Detect Python version
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        echo -e "  Python: $PYTHON_VERSION"
    else
        print_error "Python3 not found!"
        return 1
    fi
    
    # Check if running as root (recommended)
    if [[ $CURRENT_USER != "root" ]]; then
        print_warning "Not running as root. Some operations may require sudo."
    fi
    
    print_success "System detection completed"
    return 0
}

check_dependencies() {
    print_step "Checking system dependencies..."
    
    local missing_deps=()
    
    # Essential tools
    local deps=("git" "curl" "wget" "unzip" "python3" "python3-pip" "python3-venv")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        else
            print_success "$dep is available"
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        if confirm_action "Do you want to install missing dependencies?"; then
            install_system_dependencies "${missing_deps[@]}"
        else
            print_error "Cannot proceed without required dependencies"
            exit 1
        fi
    else
        print_success "All system dependencies are satisfied"
    fi
}

install_system_dependencies() {
    local deps=("$@")
    print_step "Installing system dependencies..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y "${deps[@]}" python3-dev build-essential
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        sudo yum install -y "${deps[@]}" python3-devel gcc
    elif command -v dnf &> /dev/null; then
        # Fedora
        sudo dnf install -y "${deps[@]}" python3-devel gcc
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        sudo pacman -S --noconfirm "${deps[@]}" base-devel
    else
        print_error "Unsupported package manager. Please install dependencies manually."
        exit 1
    fi
    
    print_success "System dependencies installed"
}

# ===================================================================
# PROJECT MANAGEMENT
# ===================================================================

check_installation_status() {
    if [[ -f "$INSTALL_FLAG" ]]; then
        return 0  # Already installed
    else
        return 1  # Not installed
    fi
}

download_project() {
    print_step "Downloading FlowAI XAU Trading Bot..."
    
    # Remove existing directory if it exists
    if [[ -d "$PROJECT_DIR" ]]; then
        if confirm_action "Project directory exists. Remove and reinstall?"; then
            rm -rf "$PROJECT_DIR"
        else
            print_error "Installation cancelled"
            exit 1
        fi
    fi
    
    # Create project directory
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Clone repository
    if git clone "$REPO_URL" .; then
        print_success "Project downloaded successfully"
    else
        print_error "Failed to download project"
        exit 1
    fi
}

setup_virtual_environment() {
    print_step "Setting up Python virtual environment..."
    
    cd "$PROJECT_DIR"
    
    # Create virtual environment
    if python3 -m venv "$VENV_DIR"; then
        print_success "Virtual environment created"
    else
        print_error "Failed to create virtual environment"
        exit 1
    fi
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    
    print_success "Virtual environment setup completed"
}

install_python_dependencies() {
    print_step "Installing Python dependencies..."
    
    cd "$PROJECT_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Install requirements
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt
        print_success "Python dependencies installed"
    else
        print_warning "requirements.txt not found, installing essential packages..."
        pip install pandas numpy scikit-learn yfinance ta requests python-dotenv schedule
        print_success "Essential packages installed"
    fi
    
    # Verify critical imports
    python3 -c "
import pandas as pd
import numpy as np
import sklearn
import yfinance as yf
import ta
import requests
import dotenv
import schedule
print('✅ All critical packages imported successfully')
" || {
        print_error "Failed to import critical packages"
        exit 1
    }
}

train_ai_model() {
    print_step "Training AI model..."
    
    cd "$PROJECT_DIR"
    source "$VENV_DIR/bin/activate"
    
    if [[ -f "simple_train_model.py" ]]; then
        echo -e "${CYAN}Training AI model (this may take a few minutes)...${NC}"
        if python3 simple_train_model.py; then
            print_success "AI model trained successfully"
            
            # Verify model files
            if [[ -f "model.pkl" && -f "model_features.pkl" ]]; then
                print_success "Model files created successfully"
            else
                print_error "Model files not found after training"
                return 1
            fi
        else
            print_error "AI model training failed"
            return 1
        fi
    else
        print_warning "AI training script not found, skipping model training"
    fi
}

# ===================================================================
# CONFIGURATION MANAGEMENT
# ===================================================================

collect_user_configuration() {
    print_step "Collecting user configuration..."
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                    Configuration Setup                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Trading Configuration
    echo -e "${YELLOW}📊 Trading Configuration:${NC}"
    
    read -p "Trading Symbol (default: GC=F): " SYMBOL
    SYMBOL=${SYMBOL:-"GC=F"}
    
    read -p "Timeframe (default: 1h): " TIMEFRAME
    TIMEFRAME=${TIMEFRAME:-"1h"}
    
    read -p "Analysis Interval in minutes (default: 60): " INTERVAL
    INTERVAL=${INTERVAL:-"60"}
    
    echo ""
    
    # Telegram Configuration
    echo -e "${YELLOW}🤖 Telegram Configuration:${NC}"
    echo -e "${CYAN}To get Telegram Bot Token:${NC}"
    echo -e "1. Message @BotFather on Telegram"
    echo -e "2. Send /newbot command"
    echo -e "3. Follow instructions to create your bot"
    echo -e "4. Copy the token provided"
    echo ""
    
    read -p "Telegram Bot Token: " TELEGRAM_TOKEN
    
    echo ""
    echo -e "${CYAN}To get Chat ID:${NC}"
    echo -e "1. Send a message to your bot"
    echo -e "2. Visit: https://api.telegram.org/bot$TELEGRAM_TOKEN/getUpdates"
    echo -e "3. Find 'chat':{'id': YOUR_CHAT_ID}"
    echo ""
    
    read -p "Telegram Chat ID: " TELEGRAM_CHAT_ID
    
    read -p "Enable Telegram notifications? (y/N): " TELEGRAM_ENABLED
    TELEGRAM_ENABLED=${TELEGRAM_ENABLED:-"False"}
    if [[ $TELEGRAM_ENABLED =~ ^[Yy]$ ]]; then
        TELEGRAM_ENABLED="True"
    else
        TELEGRAM_ENABLED="False"
    fi
    
    echo ""
    
    # AI Configuration
    echo -e "${YELLOW}🤖 AI Configuration:${NC}"
    
    read -p "AI Confidence Threshold (0.6-0.9, default: 0.7): " AI_CONFIDENCE
    AI_CONFIDENCE=${AI_CONFIDENCE:-"0.7"}
    
    read -p "Risk Management Enabled? (y/N): " RISK_ENABLED
    RISK_ENABLED=${RISK_ENABLED:-"False"}
    if [[ $RISK_ENABLED =~ ^[Yy]$ ]]; then
        RISK_ENABLED="True"
    else
        RISK_ENABLED="False"
    fi
    
    echo ""
    print_success "Configuration collected successfully"
}

create_configuration_file() {
    print_step "Creating configuration file..."
    
    cat > "$CONFIG_FILE" << EOF
# ===================================================================
# FlowAI XAU Trading Bot Configuration
# Generated on: $(date)
# ===================================================================

# Basic Trading Configuration
SYMBOL=$SYMBOL
TIMEFRAME=$TIMEFRAME
CANDLE_LIMIT=1000
SCHEDULE_INTERVAL_MINUTES=$INTERVAL

# RSI Settings
RSI_PERIOD=14
RSI_OVERSOLD=30
RSI_OVERBOUGHT=70
RSI_CONFIRM_LOW=35
RSI_CONFIRM_HIGH=65

# SMA Settings
SMA_PERIOD=20

# FVG Settings
FVG_THRESHOLD=0.1

# HTF Analysis
HTF_TIMEFRAMES=1d,4h
HTF_LOOKBACK_CANDLES=1000
HTF_BIAS_CONSENSUS_REQUIRED=False

# ICT Analysis Settings
ICT_SWING_LOOKBACK_PERIODS=5
ICT_MSS_SWING_LOOKBACK=10
ICT_OB_MIN_BODY_RATIO=0.3
ICT_OB_LOOKBACK_FOR_MSS=15
ICT_PD_ARRAY_LOOKBACK_PERIODS=60
ICT_PD_RETRACEMENT_LEVELS=0.5,0.618,0.786
ICT_SWEEP_MSS_LOOKBACK_CANDLES=10
ICT_SWEEP_RETRACEMENT_TARGET_FVG=True

# AI Model Configuration
AI_RETURN_PERIODS=1,5,10
AI_VOLATILITY_PERIOD=20
AI_ICT_FEATURE_LOOKBACK=50
AI_TARGET_N_FUTURE_CANDLES=5
AI_TARGET_PROFIT_PCT=0.01
AI_TARGET_STOP_LOSS_PCT=0.01
AI_TRAINING_CANDLE_LIMIT=2000
AI_HPO_CV_FOLDS=3
AI_HPO_N_ITER=20
AI_CONFIDENCE_THRESHOLD=$AI_CONFIDENCE
MODEL_PATH=model.pkl
MODEL_FEATURES_PATH=model_features.pkl

# Telegram Configuration
TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN
TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID
TELEGRAM_ENABLED=$TELEGRAM_ENABLED

# Risk Management
RISK_MANAGEMENT_ENABLED=$RISK_ENABLED
MAX_DAILY_SIGNALS=5
SIGNAL_COOLDOWN_MINUTES=30

# Logging
LOG_LEVEL=INFO
LOG_RETENTION_DAYS=7

# System
DEBUG_MODE=False
ENABLE_BACKTESTING=False
EOF
    
    # Set appropriate permissions
    chmod 600 "$CONFIG_FILE"
    
    print_success "Configuration file created: $CONFIG_FILE"
}

# ===================================================================
# INSTALLATION PROCESS
# ===================================================================

run_installation() {
    print_header
    echo -e "${GREEN}🚀 Starting FlowAI XAU Trading Bot Installation...${NC}"
    echo ""
    
    # Pre-installation checks
    detect_system || exit 1
    pause_with_message
    
    check_dependencies || exit 1
    pause_with_message
    
    # Download and setup
    download_project || exit 1
    pause_with_message
    
    setup_virtual_environment || exit 1
    pause_with_message
    
    install_python_dependencies || exit 1
    pause_with_message
    
    # Configuration
    collect_user_configuration || exit 1
    create_configuration_file || exit 1
    pause_with_message
    
    # AI Model Training
    if confirm_action "Do you want to train the AI model now? (Recommended)"; then
        train_ai_model || print_warning "AI model training failed, you can train it later"
    fi
    
    # Create installation flag
    echo "$(date)" > "$INSTALL_FLAG"
    
    # Final verification
    verify_installation || exit 1
    
    print_success "Installation completed successfully!"
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${GREEN}                    Installation Complete!                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} FlowAI XAU Trading Bot is now ready to use!                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}                                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} Next steps:                                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 1. Run this script again to access management menu             ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 2. Start the bot from the management menu                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 3. Monitor logs and performance                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    pause_with_message
}

verify_installation() {
    print_step "Verifying installation..."
    
    local errors=0
    
    # Check project directory
    if [[ -d "$PROJECT_DIR" ]]; then
        print_success "Project directory exists"
    else
        print_error "Project directory not found"
        ((errors++))
    fi
    
    # Check virtual environment
    if [[ -d "$VENV_DIR" ]]; then
        print_success "Virtual environment exists"
    else
        print_error "Virtual environment not found"
        ((errors++))
    fi
    
    # Check configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        print_success "Configuration file exists"
    else
        print_error "Configuration file not found"
        ((errors++))
    fi
    
    # Check main script
    if [[ -f "$PROJECT_DIR/main.py" ]]; then
        print_success "Main script exists"
    else
        print_error "Main script not found"
        ((errors++))
    fi
    
    # Test Python environment
    cd "$PROJECT_DIR"
    if source "$VENV_DIR/bin/activate" && python3 -c "import sys; print('Python environment OK')"; then
        print_success "Python environment working"
    else
        print_error "Python environment issues"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_success "Installation verification passed"
        return 0
    else
        print_error "Installation verification failed with $errors errors"
        return 1
    fi
}

# ===================================================================
# MANAGEMENT FUNCTIONS
# ===================================================================

start_bot() {
    print_step "Starting FlowAI XAU Trading Bot..."
    
    cd "$PROJECT_DIR"
    
    # Check if already running
    if pgrep -f "python.*main.py" > /dev/null; then
        print_warning "Bot is already running!"
        if confirm_action "Do you want to restart it?"; then
            stop_bot
            sleep 2
        else
            return 0
        fi
    fi
    
    # Start bot in background
    source "$VENV_DIR/bin/activate"
    nohup python3 main.py > logs/bot.log 2>&1 &
    local pid=$!
    
    # Wait a moment and check if it started successfully
    sleep 3
    if kill -0 $pid 2>/dev/null; then
        echo $pid > "$PROJECT_DIR/.bot_pid"
        print_success "Bot started successfully (PID: $pid)"
        echo -e "${CYAN}Log file: $PROJECT_DIR/logs/bot.log${NC}"
    else
        print_error "Failed to start bot"
        return 1
    fi
}

stop_bot() {
    print_step "Stopping FlowAI XAU Trading Bot..."
    
    local pid_file="$PROJECT_DIR/.bot_pid"
    
    # Try to stop using saved PID
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            sleep 2
            if kill -0 $pid 2>/dev/null; then
                kill -9 $pid
            fi
            rm -f "$pid_file"
            print_success "Bot stopped (PID: $pid)"
        else
            print_warning "Bot was not running (stale PID file)"
            rm -f "$pid_file"
        fi
    fi
    
    # Fallback: kill any python main.py processes
    pkill -f "python.*main.py" 2>/dev/null || true
    
    print_success "Bot stop command completed"
}

restart_bot() {
    print_step "Restarting FlowAI XAU Trading Bot..."
    stop_bot
    sleep 3
    start_bot
}

check_bot_status() {
    print_step "Checking bot status..."
    
    local pid_file="$PROJECT_DIR/.bot_pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 $pid 2>/dev/null; then
            print_success "Bot is running (PID: $pid)"
            
            # Show recent log entries
            echo ""
            echo -e "${CYAN}Recent log entries:${NC}"
            tail -10 "$PROJECT_DIR/logs/bot.log" 2>/dev/null || echo "No log file found"
            
            return 0
        else
            print_warning "Bot is not running (stale PID file)"
            rm -f "$pid_file"
            return 1
        fi
    else
        if pgrep -f "python.*main.py" > /dev/null; then
            print_warning "Bot process found but no PID file"
            return 0
        else
            print_info "Bot is not running"
            return 1
        fi
    fi
}

view_logs() {
    local log_file="$PROJECT_DIR/logs/bot.log"
    
    if [[ -f "$log_file" ]]; then
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${WHITE}                        Bot Logs                                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}                   (Press 'q' to exit)                          ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        tail -f "$log_file"
    else
        print_error "Log file not found: $log_file"
        pause_with_message
    fi
}

edit_configuration() {
    print_step "Configuration Editor"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found!"
        pause_with_message
        return 1
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                   Configuration Editor                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo "1. Edit with nano"
    echo "2. Edit with vi"
    echo "3. Reconfigure interactively"
    echo "4. Back to main menu"
    echo ""
    
    read -p "Choose option (1-4): " choice
    
    case $choice in
        1)
            nano "$CONFIG_FILE"
            ;;
        2)
            vi "$CONFIG_FILE"
            ;;
        3)
            collect_user_configuration
            create_configuration_file
            ;;
        4)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    print_success "Configuration updated"
    
    if check_bot_status; then
        if confirm_action "Bot is running. Restart to apply changes?"; then
            restart_bot
        fi
    fi
    
    pause_with_message
}

retrain_ai_model() {
    print_step "Retraining AI Model..."
    
    cd "$PROJECT_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Backup existing model
    if [[ -f "model.pkl" ]]; then
        cp model.pkl "model_backup_$(date +%Y%m%d_%H%M%S).pkl"
        print_info "Existing model backed up"
    fi
    
    # Train new model
    if [[ -f "simple_train_model.py" ]]; then
        echo -e "${CYAN}Training new AI model (this may take a few minutes)...${NC}"
        if python3 simple_train_model.py; then
            print_success "AI model retrained successfully"
            
            if check_bot_status; then
                if confirm_action "Bot is running. Restart to use new model?"; then
                    restart_bot
                fi
            fi
        else
            print_error "AI model training failed"
            
            # Restore backup if available
            local backup=$(ls -t model_backup_*.pkl 2>/dev/null | head -1)
            if [[ -n "$backup" ]]; then
                cp "$backup" model.pkl
                print_info "Restored previous model from backup"
            fi
        fi
    else
        print_error "Training script not found"
    fi
    
    pause_with_message
}

update_project() {
    print_step "Updating FlowAI XAU Trading Bot..."
    
    cd "$PROJECT_DIR"
    
    # Check if bot is running
    local was_running=false
    if check_bot_status; then
        was_running=true
        if confirm_action "Bot is running. Stop it for update?"; then
            stop_bot
        else
            print_warning "Update cancelled"
            return 1
        fi
    fi
    
    # Backup current configuration
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        print_info "Configuration backed up"
    fi
    
    # Backup AI model
    if [[ -f "model.pkl" ]]; then
        cp model.pkl "model_backup_$(date +%Y%m%d_%H%M%S).pkl"
        print_info "AI model backed up"
    fi
    
    # Update from git
    if git fetch origin && git reset --hard origin/main; then
        print_success "Project updated from GitHub"
        
        # Restore configuration
        if [[ -f "${CONFIG_FILE}.backup" ]]; then
            cp "${CONFIG_FILE}.backup" "$CONFIG_FILE"
            print_info "Configuration restored"
        fi
        
        # Update dependencies
        source "$VENV_DIR/bin/activate"
        pip install -r requirements.txt --upgrade
        print_success "Dependencies updated"
        
        # Restart bot if it was running
        if [[ "$was_running" == true ]]; then
            if confirm_action "Restart bot with updated code?"; then
                start_bot
            fi
        fi
        
    else
        print_error "Failed to update project"
        
        # Restore backups
        if [[ -f "${CONFIG_FILE}.backup" ]]; then
            cp "${CONFIG_FILE}.backup" "$CONFIG_FILE"
        fi
    fi
    
    pause_with_message
}

system_info() {
    print_step "System Information"
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                      System Information                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}System:${NC}"
    echo "  OS: $OS"
    echo "  Architecture: $ARCH"
    echo "  User: $CURRENT_USER"
    echo "  Python: $(python3 --version 2>/dev/null || echo 'Not found')"
    echo ""
    
    echo -e "${YELLOW}Project:${NC}"
    echo "  Directory: $PROJECT_DIR"
    echo "  Virtual Environment: $VENV_DIR"
    echo "  Configuration: $CONFIG_FILE"
    echo ""
    
    echo -e "${YELLOW}Status:${NC}"
    if check_bot_status >/dev/null 2>&1; then
        echo -e "  Bot Status: ${GREEN}Running${NC}"
    else
        echo -e "  Bot Status: ${RED}Stopped${NC}"
    fi
    
    if [[ -f "$PROJECT_DIR/model.pkl" ]]; then
        echo -e "  AI Model: ${GREEN}Available${NC}"
        local model_size=$(du -h "$PROJECT_DIR/model.pkl" | cut -f1)
        echo "  Model Size: $model_size"
    else
        echo -e "  AI Model: ${RED}Not found${NC}"
    fi
    
    echo ""
    
    echo -e "${YELLOW}Disk Usage:${NC}"
    df -h "$PROJECT_DIR" 2>/dev/null || echo "  Unable to get disk usage"
    
    echo ""
    
    echo -e "${YELLOW}Memory Usage:${NC}"
    free -h 2>/dev/null || echo "  Unable to get memory usage"
    
    echo ""
    pause_with_message
}

uninstall_project() {
    print_step "Uninstalling FlowAI XAU Trading Bot..."
    
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${WHITE}                         WARNING!                                ${RED}║${NC}"
    echo -e "${RED}║${WHITE}                                                                 ${RED}║${NC}"
    echo -e "${RED}║${WHITE}  This will completely remove FlowAI XAU Trading Bot and all    ${RED}║${NC}"
    echo -e "${RED}║${WHITE}  associated data including:                                     ${RED}║${NC}"
    echo -e "${RED}║${WHITE}  - Project files                                                ${RED}║${NC}"
    echo -e "${RED}║${WHITE}  - Configuration                                                ${RED}║${NC}"
    echo -e "${RED}║${WHITE}  - AI models                                                    ${RED}║${NC}"
    echo -e "${RED}║${WHITE}  - Logs                                                         ${RED}║${NC}"
    echo -e "${RED}║${WHITE}                                                                 ${RED}║${NC}"
    echo -e "${RED}║${WHITE}  This action cannot be undone!                                 ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if ! confirm_action "Are you absolutely sure you want to uninstall?"; then
        print_info "Uninstall cancelled"
        return 0
    fi
    
    echo ""
    if ! confirm_action "Last chance! Type 'yes' to confirm uninstall"; then
        print_info "Uninstall cancelled"
        return 0
    fi
    
    # Stop bot if running
    stop_bot 2>/dev/null || true
    
    # Remove project directory
    if [[ -d "$PROJECT_DIR" ]]; then
        rm -rf "$PROJECT_DIR"
        print_success "Project directory removed"
    fi
    
    # Remove log file
    if [[ -f "$LOG_FILE" ]]; then
        rm -f "$LOG_FILE"
        print_success "Log file removed"
    fi
    
    print_success "FlowAI XAU Trading Bot uninstalled successfully"
    echo ""
    echo -e "${CYAN}Thank you for using FlowAI XAU Trading Bot!${NC}"
    echo ""
    
    exit 0
}

# ===================================================================
# MENU SYSTEMS
# ===================================================================

show_installation_menu() {
    while true; do
        print_header
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${WHITE}                     Installation Menu                           ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${WHITE}1.${NC} 🚀 Start Installation"
        echo -e "${WHITE}2.${NC} 📋 System Requirements Check"
        echo -e "${WHITE}3.${NC} ℹ️  Installation Guide"
        echo -e "${WHITE}4.${NC} 🚪 Exit"
        echo ""
        read -p "Choose option (1-4): " choice
        
        case $choice in
            1)
                if confirm_action "Start FlowAI XAU Trading Bot installation?"; then
                    run_installation
                    break
                fi
                ;;
            2)
                detect_system
                check_dependencies
                pause_with_message
                ;;
            3)
                show_installation_guide
                ;;
            4)
                echo -e "${CYAN}Installation cancelled. Goodbye!${NC}"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-4."
                sleep 2
                ;;
        esac
    done
}

show_management_menu() {
    while true; do
        print_header
        
        # Show current status
        echo -e "${CYAN}Current Status:${NC}"
        if check_bot_status >/dev/null 2>&1; then
            echo -e "  Bot: ${GREEN}Running${NC}"
        else
            echo -e "  Bot: ${RED}Stopped${NC}"
        fi
        
        if [[ -f "$PROJECT_DIR/model.pkl" ]]; then
            echo -e "  AI Model: ${GREEN}Available${NC}"
        else
            echo -e "  AI Model: ${RED}Not found${NC}"
        fi
        echo ""
        
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${WHITE}                     Management Menu                             ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${WHITE}Bot Control:${NC}"
        echo -e "${WHITE}1.${NC} ▶️  Start Bot"
        echo -e "${WHITE}2.${NC} ⏹️  Stop Bot"
        echo -e "${WHITE}3.${NC} 🔄 Restart Bot"
        echo -e "${WHITE}4.${NC} 📊 Bot Status"
        echo -e "${WHITE}5.${NC} 📋 View Logs"
        echo ""
        echo -e "${WHITE}Configuration:${NC}"
        echo -e "${WHITE}6.${NC} ⚙️  Edit Configuration"
        echo -e "${WHITE}7.${NC} 🤖 Retrain AI Model"
        echo ""
        echo -e "${WHITE}Maintenance:${NC}"
        echo -e "${WHITE}8.${NC} 🔄 Update Project"
        echo -e "${WHITE}9.${NC} ℹ️  System Information"
        echo -e "${WHITE}10.${NC} 🗑️ Uninstall"
        echo ""
        echo -e "${WHITE}11.${NC} 🚪 Exit"
        echo ""
        read -p "Choose option (1-11): " choice
        
        case $choice in
            1) start_bot; pause_with_message ;;
            2) stop_bot; pause_with_message ;;
            3) restart_bot; pause_with_message ;;
            4) check_bot_status; pause_with_message ;;
            5) view_logs ;;
            6) edit_configuration ;;
            7) retrain_ai_model ;;
            8) update_project ;;
            9) system_info ;;
            10) uninstall_project ;;
            11) 
                echo -e "${CYAN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-11."
                sleep 2
                ;;
        esac
    done
}

show_installation_guide() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                    Installation Guide                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Prerequisites:${NC}"
    echo "• Linux/Unix system (Ubuntu, Debian, CentOS, etc.)"
    echo "• Python 3.8 or higher"
    echo "• Internet connection"
    echo "• At least 2GB free disk space"
    echo "• Root or sudo access (recommended)"
    echo ""
    
    echo -e "${YELLOW}What this installer does:${NC}"
    echo "1. 🔍 Checks system requirements"
    echo "2. 📦 Installs missing dependencies"
    echo "3. 📥 Downloads FlowAI XAU Trading Bot"
    echo "4. 🐍 Sets up Python virtual environment"
    echo "5. 📚 Installs Python packages"
    echo "6. ⚙️  Configures the bot (interactive)"
    echo "7. 🤖 Trains AI model"
    echo "8. ✅ Verifies installation"
    echo ""
    
    echo -e "${YELLOW}Telegram Bot Setup:${NC}"
    echo "• Message @BotFather on Telegram"
    echo "• Send /newbot command"
    echo "• Choose bot name and username"
    echo "• Copy the token provided"
    echo "• Send a message to your bot"
    echo "• Get chat ID from bot API"
    echo ""
    
    echo -e "${YELLOW}After Installation:${NC}"
    echo "• Run this script again for management menu"
    echo "• Start/stop bot as needed"
    echo "• Monitor logs for performance"
    echo "• Update when new versions available"
    echo ""
    
    pause_with_message
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Log script start
    log_message "INFO" "FlowAI Installation Script Started"
    
    # Check if already installed
    if check_installation_status; then
        # Already installed - show management menu
        show_management_menu
    else
        # Not installed - show installation menu
        show_installation_menu
    fi
}

# Trap to handle script interruption
trap 'echo -e "\n${YELLOW}Script interrupted by user${NC}"; exit 1' INT

# Run main function
main "$@"
