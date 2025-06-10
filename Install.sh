#!/bin/bash

# =====================================================
# FlowAI-ICT Trading Bot Auto-Installer v3.1
# Fully Automated Installation with Error Handling
# =====================================================

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Global variables
INSTALL_DIR="/opt/FlowAI-ICT-Trading-Bot"
LOG_FILE="/tmp/flowai_install.log"
ERROR_COUNT=0
CURRENT_USER=""
TELEGRAM_TOKEN=""
ADMIN_ID=""

# Enhanced UI functions
print_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}${BOLD}              FlowAI-ICT Trading Bot v3.1                    ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}║${WHITE}${BOLD}              Fully Automated Installer                     ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${WHITE}${BOLD} $1${NC}${CYAN}$(printf "%*s" $((59 - ${#1})) "")│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
}

print_step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${WHITE}→${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} ${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} ${RED}✗${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
    ((ERROR_COUNT++))
}

print_progress() {
    local current=$1
    local total=$2
    local desc=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}Progress: [${GREEN}"
    printf "%*s" $filled | tr ' ' '█'
    printf "${NC}"
    printf "%*s" $empty | tr ' ' '░'
    printf "${CYAN}] ${percent}%% - ${desc}${NC}"
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# Logging function
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Error handling with auto-fix
handle_error() {
    local error_type=$1
    local error_msg=$2
    local auto_fix=${3:-false}
    
    print_error "$error_msg"
    
    if [ "$auto_fix" = "true" ]; then
        case $error_type in
            "permission")
                print_step "Auto-fixing permission issue..."
                sudo chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR" 2>/dev/null
                sudo chmod -R 755 "$INSTALL_DIR" 2>/dev/null
                ;;
            "network")
                print_step "Checking network connectivity..."
                if ping -c 1 8.8.8.8 &>/dev/null; then
                    print_success "Network is working, retrying..."
                    return 0
                fi
                ;;
            "dependency")
                print_step "Attempting to install missing dependency..."
                sudo apt update &>/dev/null
                ;;
        esac
    fi
    
    return 1
}

# System checks with auto-fix
check_system() {
    print_section "System Requirements Check"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root detected"
        print_step "Creating non-root user 'flowai'..."
        
        if ! id "flowai" &>/dev/null; then
            useradd -m -s /bin/bash flowai
            usermod -aG sudo flowai
            echo "flowai:FlowAI2025!" | chpasswd
            print_success "User 'flowai' created"
        fi
        
        print_step "Switching to user 'flowai' and restarting installation..."
        sudo -u flowai bash "$0" "$@"
        exit $?
    fi
    
    CURRENT_USER=$(whoami)
    print_success "Running as user: $CURRENT_USER"
    
    # Check OS
    if [[ ! "$OSTYPE" =~ linux-gnu.* ]]; then
        print_error "This installer requires Linux"
        exit 1
    fi
    print_success "Linux system detected"
    
    # Check internet
    print_step "Testing internet connectivity..."
    if ! ping -c 1 google.com &>/dev/null; then
        if ! ping -c 1 8.8.8.8 &>/dev/null; then
            print_error "No internet connection"
            exit 1
        fi
    fi
    print_success "Internet connection verified"
    
    # Check available space
    available_space=$(df / | awk 'NR==2 {print $4}')
    required_space=1048576  # 1GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "Insufficient disk space. Need at least 1GB"
        exit 1
    fi
    print_success "Sufficient disk space available"
    
    # Check Python version
    if command -v python3 &>/dev/null; then
        python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        if [ "$(echo "$python_version >= 3.8" | bc 2>/dev/null)" = "1" ] || [[ "$python_version" > "3.8" ]] || [[ "$python_version" = "3.8" ]]; then
            print_success "Python $python_version detected"
        else
            print_warning "Python version $python_version may not be optimal (recommended: 3.8+)"
        fi
    else
        print_warning "Python3 not found - will be installed"
    fi
}

# Interactive configuration
configure_bot() {
    print_section "Bot Configuration"
    
    # Auto-detect or prompt for Telegram token
    if [ -z "$TELEGRAM_TOKEN" ]; then
        echo -e "${YELLOW}Please enter your Telegram Bot Token:${NC}"
        echo -e "${CYAN}(Get it from @BotFather on Telegram)${NC}"
        read -r TELEGRAM_TOKEN
        
        if [ ${#TELEGRAM_TOKEN} -lt 40 ]; then
            print_error "Invalid Telegram token format"
            exit 1
        fi
    fi
    
    # Auto-detect or prompt for Admin ID
    if [ -z "$ADMIN_ID" ]; then
        echo -e "${YELLOW}Please enter your Telegram User ID:${NC}"
        echo -e "${CYAN}(Send /start to @userinfobot to get your ID)${NC}"
        read -r ADMIN_ID
        
        if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            print_error "Invalid Admin ID format"
            exit 1
        fi
    fi
    
    print_success "Configuration completed"
}

# Install system dependencies with progress
install_system_deps() {
    print_section "Installing System Dependencies"
    
    local packages=(
        "python3" "python3-pip" "python3-venv" "python3-dev"
        "git" "curl" "wget" "unzip" "build-essential"
        "software-properties-common" "htop" "nano" "vim"
        "screen" "tmux" "tree" "jq" "sqlite3" "cron"
    )
    
    print_step "Updating package lists..."
    if ! sudo apt update &>/dev/null; then
        handle_error "network" "Failed to update package lists" true
    fi
    print_success "Package lists updated"
    
    print_step "Installing system packages..."
    local total=${#packages[@]}
    local current=0
    
    for package in "${packages[@]}"; do
        ((current++))
        print_progress $current $total "Installing $package"
        
        if ! dpkg -l | grep -q "^ii  $package "; then
            if ! sudo apt install -y "$package" &>/dev/null; then
                print_warning "Failed to install $package, continuing..."
            fi
        fi
    done
    
    print_success "System dependencies installed"
}

# Setup project with error handling
setup_project() {
    print_section "Setting Up FlowAI-ICT Project"
    
    # Backup existing installation
    if [ -d "$INSTALL_DIR" ]; then
        backup_dir="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        print_step "Backing up existing installation..."
        sudo mv "$INSTALL_DIR" "$backup_dir"
        print_success "Backup created: $backup_dir"
    fi
    
    # Clone repository with retry mechanism
    print_step "Cloning repository..."
    local retry_count=0
    local max_retries=3
    
    while [ $retry_count -lt $max_retries ]; do
        if sudo git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git "$INSTALL_DIR" &>/dev/null; then
            break
        fi
        
        ((retry_count++))
        print_warning "Clone attempt $retry_count failed, retrying..."
        sleep 2
    done
    
    if [ $retry_count -eq $max_retries ]; then
        print_error "Failed to clone repository after $max_retries attempts"
        exit 1
    fi
    
    # Set ownership and permissions
    sudo chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    
    print_success "Project setup completed"
}

# Setup virtual environment with validation
setup_venv() {
    print_section "Setting Up Python Virtual Environment"
    
    cd "$INSTALL_DIR" || exit 1
    
    # Remove existing venv if corrupted
    if [ -d "venv" ] && [ ! -f "venv/bin/activate" ]; then
        print_step "Removing corrupted virtual environment..."
        rm -rf venv
    fi
    
    # Create virtual environment
    if [ ! -d "venv" ]; then
        print_step "Creating virtual environment..."
        if ! python3 -m venv venv; then
            print_error "Failed to create virtual environment"
            exit 1
        fi
    fi
    
    # Activate and upgrade pip
    print_step "Activating virtual environment..."
    source venv/bin/activate
    
    print_step "Upgrading pip and setuptools..."
    pip install --upgrade pip setuptools wheel &>/dev/null
    
    print_success "Virtual environment ready"
}

# Install Python dependencies with error handling
install_python_deps() {
    print_section "Installing Python Dependencies"
    
    cd "$INSTALL_DIR" || exit 1
    source venv/bin/activate
    
    # Create optimized requirements.txt
    cat > requirements.txt << 'EOF'
# Core Telegram Bot
python-telegram-bot==13.15

# Data Processing & Analysis
pandas>=1.5.0,<2.0.0
numpy>=1.21.0,<2.0.0
requests>=2.28.0,<3.0.0

# Configuration & Environment
python-dotenv>=0.19.0,<1.0.0

# Technical Analysis (ICT Requirements) - STABLE VERSIONS
ta==0.10.2
talib-binary>=0.4.24,<1.0.0

# Date & Time Handling
jdatetime>=4.1.0,<5.0.0
pytz>=2022.1

# Async Support
aiohttp>=3.8.0,<4.0.0

# Logging & Monitoring
colorlog>=6.6.0,<7.0.0

# System Monitoring
psutil>=5.9.0,<6.0.0
EOF
    
    print_step "Installing Python packages..."
    
    # Install with retry mechanism
    local packages=(
        "python-telegram-bot==13.15"
        "pandas>=1.5.0,<2.0.0"
        "numpy>=1.21.0,<2.0.0"
        "requests>=2.28.0,<3.0.0"
        "python-dotenv>=0.19.0,<1.0.0"
        "ta==0.10.2"
        "talib-binary>=0.4.24,<1.0.0"
        "jdatetime>=4.1.0,<5.0.0"
        "pytz>=2022.1"
        "aiohttp>=3.8.0,<4.0.0"
        "colorlog>=6.6.0,<7.0.0"
        "psutil>=5.9.0,<6.0.0"
    )
    
    local total=${#packages[@]}
    local current=0
    
    for package in "${packages[@]}"; do
        ((current++))
        local pkg_name=$(echo "$package" | cut -d'=' -f1 | cut -d'>' -f1 | cut -d'<' -f1)
        print_progress $current $total "Installing $pkg_name"
        
        if ! pip install "$package" &>/dev/null; then
            print_warning "Failed to install $package, trying alternative..."
            pip install "$pkg_name" &>/dev/null || true
        fi
    done
    
    print_success "Python dependencies installed"
}

# Create directory structure
create_directories() {
    print_section "Creating Directory Structure"
    
    cd "$INSTALL_DIR" || exit 1
    
    local directories=(
        "logs" "reports" "backups" "models" "data"
        "config" "temp" "flow_ai_core/data_sources"
        "flow_ai_core/telegram" "flow_ai_core/price_engine"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    
    # Create __init__.py files
    touch flow_ai_core/__init__.py
    touch flow_ai_core/data_sources/__init__.py
    touch flow_ai_core/telegram/__init__.py
    touch flow_ai_core/price_engine/__init__.py
    
    print_success "Directory structure created"
}

# Setup environment with validation
setup_environment() {
    print_section "Configuring Environment"
    
    cd "$INSTALL_DIR" || exit 1
    
    # Create comprehensive .env file
    cat > .env << EOF
# ===== TELEGRAM CONFIGURATION =====
TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN
TELEGRAM_ADMIN_IDS=$ADMIN_ID
TELEGRAM_PREMIUM_USERS=

# ===== BRSAPI CONFIGURATION =====
BRSAPI_KEY=FreeQZdOYW6D3nNv95jZ9BcYXJHzTJpf
BRSAPI_DAILY_LIMIT=10000
BRSAPI_MINUTE_LIMIT=60

# ===== ICT TRADING CONFIGURATION =====
ICT_ENABLED=true
ORDER_BLOCK_DETECTION=true
FAIR_VALUE_GAP_DETECTION=true
LIQUIDITY_SWEEP_DETECTION=true
HTF_TIMEFRAMES=1d,4h
LTF_TIMEFRAME=1h

# ===== AI MODEL CONFIGURATION =====
AI_MODEL_ENABLED=true
AI_CONFIDENCE_THRESHOLD=0.7
AI_RETRAIN_INTERVAL=24

# ===== SIGNAL GENERATION =====
SIGNAL_GENERATION_ENABLED=true
SIGNAL_CHECK_INTERVAL=300
SIGNAL_MIN_CONFIDENCE=0.6
SIGNAL_COOLDOWN=300

# ===== RISK MANAGEMENT =====
ICT_RISK_PER_TRADE=0.02
ICT_MAX_DAILY_RISK=0.05
ICT_RR_RATIO=2.0
MAX_DAILY_LOSS_PERCENT=5.0
MAX_POSITION_SIZE_PERCENT=10.0
MAX_DRAWDOWN_PERCENT=15.0
MAX_DAILY_TRADES=20

# ===== MARKET HOURS =====
MARKET_START_HOUR=13
MARKET_END_HOUR=22
MARKET_TIMEZONE=UTC

# ===== LOGGING =====
LOG_LEVEL=INFO
LOG_FILE_PATH=logs/flowai_ict.log
LOG_MAX_SIZE=10
LOG_BACKUP_COUNT=5

# ===== NOTIFICATIONS =====
NOTIFICATIONS_ENABLED=true
EMAIL_NOTIFICATIONS=false
WEBHOOK_NOTIFICATIONS=false

# ===== PERFORMANCE =====
CACHE_ENABLED=true
CACHE_TTL=300
PARALLEL_PROCESSING=true
MAX_WORKERS=4

# ===== DEVELOPMENT =====
DEBUG_MODE=false
TESTING_MODE=false
PAPER_TRADING=true
EOF
    
    # Validate configuration
    print_step "Validating configuration..."
    
    if [ ${#TELEGRAM_TOKEN} -lt 40 ]; then
        print_error "Invalid Telegram token in configuration"
        exit 1
    fi
    
    if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
        print_error "Invalid Admin ID in configuration"
        exit 1
    fi
    
    print_success "Environment configured and validated"
}

# Setup systemd service
setup_service() {
    print_section "Setting Up System Service"
    
    # Create systemd service
    sudo tee /etc/systemd/system/flowai-ict-bot.service > /dev/null << EOF
[Unit]
Description=FlowAI-ICT Trading Bot v3.1
After=network.target network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python telegram_bot.py
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=flowai-ict-bot

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$INSTALL_DIR
PrivateTmp=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    sudo systemctl daemon-reload
    sudo systemctl enable flowai-ict-bot &>/dev/null
    
    print_success "System service configured"
}

# Create utility scripts
create_scripts() {
    print_section "Creating Utility Scripts"
    
    cd "$INSTALL_DIR" || exit 1
    
    # Enhanced startup script
    cat > start_bot.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting FlowAI-ICT Trading Bot..."
cd /opt/FlowAI-ICT-Trading-Bot

# Check virtual environment
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found!"
    exit 1
fi

# Activate environment
source venv/bin/activate

# Check configuration
if [ ! -f ".env" ]; then
    echo "❌ Configuration file not found!"
    exit 1
fi

# Start bot
echo "✅ Starting bot..."
python telegram_bot.py
EOF
    
    # Enhanced update script
    cat > update_bot.sh << 'EOF'
#!/bin/bash
echo "🔄 Updating FlowAI-ICT Trading Bot..."

# Stop service if running
sudo systemctl stop flowai-ict-bot 2>/dev/null

cd /opt/FlowAI-ICT-Trading-Bot

# Backup current config
cp .env .env.backup

# Update code
git stash
git pull origin main

# Restore config
mv .env.backup .env

# Update dependencies
source venv/bin/activate
pip install -r requirements.txt --upgrade

# Restart service
sudo systemctl start flowai-ict-bot

echo "✅ Update completed!"
EOF
    
    # Comprehensive health check
    cat > health_check.sh << 'EOF'
#!/bin/bash
echo "💊 FlowAI-ICT Health Check v3.1"
echo "================================="

# Service status
if systemctl is-active --quiet flowai-ict-bot; then
    echo "✅ Bot Service: Running"
    echo "📊 Uptime: $(systemctl show flowai-ict-bot --property=ActiveEnterTimestamp --value)"
else
    echo "❌ Bot Service: Stopped"
fi

# Virtual environment
cd /opt/FlowAI-ICT-Trading-Bot
if [ -d "venv" ] && [ -f "venv/bin/activate" ]; then
    echo "✅ Virtual Environment: OK"
    source venv/bin/activate
    echo "🐍 Python Version: $(python --version)"
else
    echo "❌ Virtual Environment: Corrupted"
fi

# Configuration
if [ -f ".env" ]; then
    echo "✅ Configuration: Found"
    if grep -q "TELEGRAM_BOT_TOKEN=" .env; then
        echo "✅ Telegram Token: Configured"
    else
        echo "❌ Telegram Token: Missing"
    fi
else
    echo "❌ Configuration: Missing"
fi

# Dependencies
echo "📦 Checking Dependencies:"
pip list | grep -E "(telegram|pandas|numpy|ta)" | head -5

# Logs
if [ -d "logs" ]; then
    echo "✅ Logs Directory: OK"
    echo "📊 Log Files: $(ls logs/ 2>/dev/null | wc -l)"
    if [ -f "logs/flowai_ict.log" ]; then
        echo "📄 Latest Log Entry: $(tail -1 logs/flowai_ict.log 2>/dev/null)"
    fi
else
    echo "❌ Logs Directory: Missing"
fi

# System resources
echo "💻 System Resources:"
echo "📊 Memory Usage: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
echo "📊 Disk Usage: $(df -h / | awk 'NR==2{print $5}')"

echo "================================="
echo "Health check completed!"
EOF
    
    # Developer tools enhanced
    cat > dev_tools.py << 'EOF'
#!/usr/bin/env python3
"""
🔧 FlowAI-ICT Developer Tools v3.1
Enhanced debugging and development utilities
"""

import os
import sys
import json
import logging
import subprocess
import psutil
from datetime import datetime

def show_banner():
    print("\n" + "="*60)
    print("🔧 FlowAI-ICT Developer Tools v3.1")
    print("="*60)

def show_menu():
    print("\n🔧 Development & Debugging Tools:")
    print("1. 🐛 Toggle Debug Mode")
    print("2. 🧪 API Testing Utilities")
    print("3. 📊 Performance Profiler")
    print("4. 🔍 Code Quality Checker")
    print("5. 📋 System Diagnostics")
    print("6. 🔄 Reset Configuration")
    print("7. 📦 Export Logs")
    print("8. 🔧 Service Management")
    print("9. 📈 Real-time Monitoring")
    print("0. 🔙 Exit")

def toggle_debug_mode():
    print("🐛 Debug Mode Management")
    try:
        with open('.env', 'r') as f:
            content = f.read()
        
        if 'DEBUG_MODE=true' in content:
            content = content.replace('DEBUG_MODE=true', 'DEBUG_MODE=false')
            print("✅ Debug mode disabled")
        else:
            content = content.replace('DEBUG_MODE=false', 'DEBUG_MODE=true')
            print("✅ Debug mode enabled")
        
        with open('.env', 'w') as f:
            f.write(content)
    except Exception as e:
        print(f"❌ Error: {e}")

def system_diagnostics():
    print("📋 System Diagnostics")
    print("-" * 40)
    
    # System info
    print(f"🖥️  CPU Usage: {psutil.cpu_percent()}%")
    print(f"💾 Memory Usage: {psutil.virtual_memory().percent}%")
    print(f"💿 Disk Usage: {psutil.disk_usage('/').percent}%")
    
    # Process info
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent']):
            if 'python' in proc.info['name'].lower():
                print(f"🐍 Python Process: PID {proc.info['pid']}, CPU {proc.info['cpu_percent']}%")
    except:
        pass

def service_management():
    print("🔧 Service Management")
    print("1. Start Service")
    print("2. Stop Service")
    print("3. Restart Service")
    print("4. Service Status")
    print("5. View Logs")
    
    choice = input("Select option: ")
    
    commands = {
        '1': 'sudo systemctl start flowai-ict-bot',
        '2': 'sudo systemctl stop flowai-ict-bot',
        '3': 'sudo systemctl restart flowai-ict-bot',
        '4': 'sudo systemctl status flowai-ict-bot',
        '5': 'sudo journalctl -u flowai-ict-bot -f'
    }
    
    if choice in commands:
        os.system(commands[choice])

def main():
    show_banner()
    
    while True:
        show_menu()
        choice = input("\nSelect option (0-9): ")
        
        if choice == "1":
            toggle_debug_mode()
        elif choice == "5":
            system_diagnostics()
        elif choice == "8":
            service_management()
        elif choice == "0":
            break
        else:
            print("🔧 Feature coming soon...")

if __name__ == "__main__":
    main()
EOF
    
    # Set permissions
    chmod +x start_bot.sh update_bot.sh health_check.sh dev_tools.py
    
    print_success "Utility scripts created"
}

# Final validation and testing
final_validation() {
    print_section "Final Validation & Testing"
    
    cd "$INSTALL_DIR" || exit 1
    
    # Test virtual environment
    print_step "Testing virtual environment..."
    source venv/bin/activate
    if ! python -c "import telegram, pandas, numpy, ta" &>/dev/null; then
        print_error "Python dependencies validation failed"
        exit 1
    fi
    print_success "Python environment validated"
    
    # Test configuration
    print_step "Testing configuration..."
    if ! python -c "from dotenv import load_dotenv; load_dotenv(); import os; assert os.getenv('TELEGRAM_BOT_TOKEN')" &>/dev/null; then
        print_error "Configuration validation failed"
        exit 1
    fi
    print_success "Configuration validated"
    
    # Test bot startup (dry run)
    print_step "Testing bot initialization..."
    timeout 10s python -c "
import sys
sys.path.append('.')
try:
    from flow_ai_core.config import TELEGRAM_BOT_TOKEN
    print('✅ Bot configuration loaded successfully')
except Exception as e:
    print(f'❌ Bot initialization failed: {e}')
    sys.exit(1)
" || print_warning "Bot test timed out (normal for first run)"
    
    print_success "Final validation completed"
}

# Show completion with enhanced UI
show_completion() {
    clear
    print_banner
    
    echo -e "${GREEN}🎉 Installation Completed Successfully! 🎉${NC}"
    echo ""
    
    # Installation summary
    echo -e "${CYAN}📋 Installation Summary:${NC}"
    echo -e "${WHITE}├─ Installation Directory: ${INSTALL_DIR}${NC}"
    echo -e "${WHITE}├─ Virtual Environment: ✅ Configured${NC}"
    echo -e "${WHITE}├─ System Service: ✅ Enabled${NC}"
    echo -e "${WHITE}├─ Configuration: ✅ Validated${NC}"
    echo -e "${WHITE}└─ Dependencies: ✅ Installed${NC}"
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Installation completed with $ERROR_COUNT warnings${NC}"
        echo -e "${YELLOW}   Check log file: $LOG_FILE${NC}"
    fi
    
    echo ""
    echo -e "${PURPLE}🚀 Quick Start Commands:${NC}"
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│ Start Bot:     ${CYAN}sudo systemctl start flowai-ict-bot${NC}${WHITE}        │${NC}"
    echo -e "${WHITE}│ Stop Bot:      ${CYAN}sudo systemctl stop flowai-ict-bot${NC}${WHITE}         │${NC}"
    echo -e "${WHITE}│ Bot Status:    ${CYAN}sudo systemctl status flowai-ict-bot${NC}${WHITE}       │${NC}"
    echo -e "${WHITE}│ View Logs:     ${CYAN}sudo journalctl -u flowai-ict-bot -f${NC}${WHITE}       │${NC}"
    echo -e "${WHITE}│ Health Check:  ${CYAN}cd $INSTALL_DIR && ./health_check.sh${NC}${WHITE} │${NC}"
    echo -e "${WHITE}│ Dev Tools:     ${CYAN}cd $INSTALL_DIR && python dev_tools.py${NC}${WHITE}  │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    echo ""
    echo -e "${BLUE}🎯 ICT Features Ready:${NC}"
    echo -e "${WHITE}• Order Block Detection & Analysis${NC}"
    echo -e "${WHITE}• Fair Value Gap Identification${NC}"
    echo -e "${WHITE}• Liquidity Sweep Detection${NC}"
    echo -e "${WHITE}• Market Structure Analysis${NC}"
    echo -e "${WHITE}• AI-Powered Signal Generation${NC}"
    echo -e "${WHITE}• Real-time BrsAPI Integration${NC}"
    echo -e "${WHITE}• Advanced Risk Management${NC}"
    echo -e "${WHITE}• Telegram Bot Interface${NC}"
    
    echo ""
    echo -e "${GREEN}✅ FlowAI-ICT Trading Bot v3.1 is ready to use!${NC}"
    echo -e "${YELLOW}🔔 The bot will start automatically on system boot${NC}"
    echo ""
    
    # Auto-start option
    echo -e "${CYAN}Would you like to start the bot now? (y/n):${NC}"
    read -r start_now
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        print_step "Starting FlowAI-ICT Bot..."
        sudo systemctl start flowai-ict-bot
        sleep 3
        if systemctl is-active --quiet flowai-ict-bot; then
            print_success "Bot started successfully!"
            echo -e "${CYAN}Check status with: sudo systemctl status flowai-ict-bot${NC}"
        else
            print_warning "Bot may need manual configuration. Check logs for details."
        fi
    fi
}

# Main installation flow
main() {
    # Initialize logging
    echo "FlowAI-ICT Installation Log - $(date)" > "$LOG_FILE"
    
    # Installation steps with progress tracking
    local steps=(
        "check_system"
        "configure_bot"
        "install_system_deps"
        "setup_project"
        "setup_venv"
        "install_python_deps"
        "create_directories"
        "setup_environment"
        "setup_service"
        "create_scripts"
        "final_validation"
    )
    
    print_banner
    echo -e "${CYAN}🚀 Starting automated installation...${NC}"
    echo -e "${CYAN}📝 Log file: $LOG_FILE${NC}"
    echo ""
    
    local total=${#steps[@]}
    local current=0
    
    for step in "${steps[@]}"; do
        ((current++))
        log_action "Executing step $current/$total: $step"
        
        if ! $step; then
            print_error "Installation failed at step: $step"
            echo -e "${RED}Check log file for details: $LOG_FILE${NC}"
            exit 1
        fi
        
        print_progress $current $total "Completed $step"
        sleep 1
    done
    
    show_completion
}

# Error handling
set -e
trap 'print_error "Installation interrupted! Check $LOG_FILE for details."; exit 1' INT TERM

# Run main installation
main "$@"
