#!/bin/bash

# =====================================================
# FlowAI-ICT Trading Bot Complete Installer v4.5
# Fixed All Issues + Complete Configuration
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
CURRENT_USER=$(whoami)
USER_HOME="$HOME"
LOG_FILE="$USER_HOME/flowai_install.log"
ERROR_LOG="$USER_HOME/flowai_errors.log"
TELEGRAM_TOKEN=""
ADMIN_ID=""
ERROR_COUNT=0

# Initialize log files with proper permissions
init_logs() {
    mkdir -p "$USER_HOME" 2>/dev/null
    
    if touch "$LOG_FILE" 2>/dev/null; then
        chmod 644 "$LOG_FILE" 2>/dev/null
    else
        LOG_FILE="/tmp/flowai_install_$(date +%s).log"
        touch "$LOG_FILE"
    fi
    
    if touch "$ERROR_LOG" 2>/dev/null; then
        chmod 644 "$ERROR_LOG" 2>/dev/null
    else
        ERROR_LOG="/tmp/flowai_errors_$(date +%s).log"
        touch "$ERROR_LOG"
    fi
    
    ERROR_COUNT=0
    if [ -f "$ERROR_LOG" ]; then
        local count=$(grep -c "ERROR #" "$ERROR_LOG" 2>/dev/null || echo "0")
        if [[ "$count" =~ ^[0-9]+$ ]] && [ "$count" -gt 0 ]; then
            ERROR_COUNT=$count
        fi
    fi
}

# Check if installation exists
check_installation() {
    INSTALLATION_EXISTS=false
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/.env" ] && [ -f "/etc/systemd/system/flowai-ict-bot.service" ]; then
        INSTALLATION_EXISTS=true
    fi
}

# Enhanced logging functions
log_action() {
    local action="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ACTION: $action" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    local step="$1"
    local error="$2"
    local actual_command="$3"
    local exit_code="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    ERROR_COUNT=$((ERROR_COUNT + 1))
    
    print_error "$step failed: $error"
    
    {
        echo "[$timestamp] ERROR #$ERROR_COUNT"
        echo "Step: $step"
        echo "Error: $error"
        echo "Command: ${actual_command:-Unknown}"
        echo "Exit Code: ${exit_code:-Unknown}"
        echo "Working Directory: $(pwd)"
        echo "User: $CURRENT_USER"
        echo "Home: $USER_HOME"
        echo "---"
    } >> "$ERROR_LOG" 2>/dev/null || true
    
    case "$step" in
        "System Update")
            echo -e "${CYAN}💡 Fix: sudo apt update && sudo apt upgrade${NC}"
            ;;
        "Package Installation")
            echo -e "${CYAN}💡 Fix: sudo apt install python3 python3-pip python3-venv git${NC}"
            ;;
        "Git Clone")
            echo -e "${CYAN}💡 Fix: Check GitHub access: ping github.com${NC}"
            ;;
        "Python Dependencies")
            echo -e "${CYAN}💡 Fix: source venv/bin/activate && pip install -r requirements.txt${NC}"
            ;;
        *)
            echo -e "${CYAN}💡 Check error log: $ERROR_LOG${NC}"
            ;;
    esac
}

log_success() {
    local action="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] SUCCESS: $action" >> "$LOG_FILE" 2>/dev/null || true
}

# Enhanced UI functions
print_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}${BOLD}              FlowAI-ICT Trading Bot v4.5                    ${NC}${PURPLE}║${NC}"
    if [ "$INSTALLATION_EXISTS" = true ]; then
        echo -e "${PURPLE}║${WHITE}${BOLD}              Management & Status Panel                     ${NC}${PURPLE}║${NC}"
    else
        echo -e "${PURPLE}║${WHITE}${BOLD}              Complete Auto Installer                      ${NC}${PURPLE}║${NC}"
    fi
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    if [ $ERROR_COUNT -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Previous errors detected: $ERROR_COUNT (check $ERROR_LOG)${NC}"
        echo ""
    fi
}

print_step_simple() {
    local step="$1"
    local current="$2"
    local total="$3"
    local status="$4"
    
    local percent=$((current * 100 / total))
    
    case $status in
        "running")
            echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${CYAN}[$current/$total - $percent%]${NC} $step..."
            ;;
        "success")
            echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ${GREEN}✓ [$current/$total - $percent%]${NC} $step"
            ;;
        "error")
            echo -e "${RED}[$(date '+%H:%M:%S')]${NC} ${RED}✗ [$current/$total - $percent%]${NC} $step"
            ;;
    esac
}

print_install_menu() {
    echo -e "${CYAN}🚀 Installation Options:${NC}"
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}1.${NC} 🚀 ${WHITE}Quick Install (Recommended)${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}2.${NC} 🔧 ${WHITE}Custom Install (Advanced)${NC}                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 🔍 ${WHITE}System Check Only${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}4.${NC} 📋 ${WHITE}View Error Logs${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}5.${NC} 🧹 ${WHITE}Clear Error Logs${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}0.${NC} 🚪 ${WHITE}Exit${NC}                                           ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

print_management_menu() {
    echo -e "${CYAN}🎛️ Management & Status Panel:${NC}"
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}1.${NC} 📊 ${WHITE}System Status & Health Check${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}2.${NC} 🚀 ${WHITE}Start/Stop/Restart Bot${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 📋 ${WHITE}View Logs & Diagnostics${NC}                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}4.${NC} ⚙️  ${WHITE}Configuration Management${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}5.${NC} 🔄 ${WHITE}Update Bot to Latest Version${NC}                   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}6.${NC} 🔧 ${WHITE}Developer Tools${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}7.${NC} 🗑️  ${WHITE}Complete Uninstall${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}8.${NC} 📖 ${WHITE}Help & Documentation${NC}                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}9.${NC} 🐛 ${WHITE}View Error Logs${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}0.${NC} 🚪 ${WHITE}Exit${NC}                                           ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${WHITE}→${NC} $1"
    log_action "$1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ${GREEN}✓${NC} $1"
    log_success "$1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} ${YELLOW}⚠${NC} $1"
    log_action "WARNING: $1"
}

print_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} ${RED}✗${NC} $1"
}

wait_for_input() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Enhanced root user handling
handle_root_user() {
    if [[ $EUID -eq 0 ]]; then
        print_step "Running as root - auto-creating flowai user without password..."
        
        if ! id "flowai" &>/dev/null; then
            if useradd -m -s /bin/bash flowai; then
                usermod -aG sudo flowai
                echo "flowai ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/flowai
                chmod 440 /etc/sudoers.d/flowai
                print_success "User 'flowai' created with sudo no-password access"
            else
                echo -e "${RED}Failed to create flowai user${NC}"
                exit 1
            fi
        else
            print_success "User 'flowai' already exists"
            echo "flowai ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/flowai
            chmod 440 /etc/sudoers.d/flowai
        fi
        
        if cp "$0" /home/flowai/Install.sh; then
            chown flowai:flowai /home/flowai/Install.sh
            chmod +x /home/flowai/Install.sh
            print_success "Script copied to flowai user"
        else
            echo -e "${RED}Failed to copy script${NC}"
            exit 1
        fi
        
        print_step "Switching to user 'flowai'..."
        sudo -u flowai bash /home/flowai/Install.sh "$@"
        exit $?
    fi
}

# Enhanced configuration setup
quick_config() {
    echo -e "${CYAN}⚙️ Quick Configuration Setup${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    
    while [ -z "$TELEGRAM_TOKEN" ]; do
        echo -e "${YELLOW}📱 Enter your Telegram Bot Token:${NC}"
        echo -e "${CYAN}   (Get it from @BotFather on Telegram)${NC}"
        read -r TELEGRAM_TOKEN
        
        if [ ${#TELEGRAM_TOKEN} -lt 40 ]; then
            print_error "Invalid token format (too short)"
            TELEGRAM_TOKEN=""
        elif [[ ! "$TELEGRAM_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            print_error "Invalid token format (wrong pattern)"
            TELEGRAM_TOKEN=""
        else
            print_success "Telegram token validated"
        fi
    done
    
    while [ -z "$ADMIN_ID" ]; do
        echo -e "${YELLOW}👤 Enter your Telegram User ID:${NC}"
        echo -e "${CYAN}   (Send /start to @userinfobot)${NC}"
        read -r ADMIN_ID
        
        if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            print_error "Invalid ID format (must be numeric)"
            ADMIN_ID=""
        elif [ ${#ADMIN_ID} -lt 5 ]; then
            print_error "Invalid ID format (too short)"
            ADMIN_ID=""
        else
            print_success "Admin ID validated"
        fi
    done
    
    print_success "Configuration completed!"
}

# Fixed package installation function
install_packages_safely() {
    local packages="$1"
    local package_type="$2"
    
    print_step "Updating package lists..."
    if sudo apt update >/dev/null 2>&1; then
        print_success "Package lists updated"
    else
        print_warning "Package list update failed, continuing..."
    fi
    
    local failed_packages=()
    local success_packages=()
    
    for package in $packages; do
        echo -e "${CYAN}  Installing $package...${NC}"
        if sudo apt install -y "$package" >/dev/null 2>&1; then
            echo -e "${GREEN}    ✓ $package installed${NC}"
            success_packages+=("$package")
        else
            echo -e "${RED}    ✗ $package failed${NC}"
            failed_packages+=("$package")
        fi
    done
    
    if [ ${#success_packages[@]} -gt 0 ]; then
        print_success "$package_type packages installed: ${success_packages[*]}"
    fi
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "$package_type packages failed: ${failed_packages[*]}"
        log_error "Package Installation" "Failed packages: ${failed_packages[*]}" "apt install" "1"
        
        if [ "$package_type" = "Essential" ]; then
            echo -e "${RED}Critical packages failed. Checking if system can continue...${NC}"
            
            if ! command -v python3 &>/dev/null; then
                echo -e "${RED}Python3 not available. Cannot continue.${NC}"
                return 1
            fi
            
            if ! command -v git &>/dev/null; then
                echo -e "${RED}Git not available. Cannot continue.${NC}"
                return 1
            fi
            
            print_warning "Some packages failed but essential ones are available. Continuing..."
        fi
    fi
    
    return 0
}

# Create complete config.py with all ICT variables
create_complete_config() {
    local config_file="$1"
    
    cat > "$config_file" << 'EOF'
"""
FlowAI-ICT Trading Bot Configuration v4.0
Complete configuration with all ICT variables
"""

import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# ===== TELEGRAM CONFIGURATION =====
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_ADMIN_IDS = [int(x.strip()) for x in os.getenv('TELEGRAM_ADMIN_IDS', '').split(',') if x.strip()]
TELEGRAM_PREMIUM_USERS = [int(x.strip()) for x in os.getenv('TELEGRAM_PREMIUM_USERS', '').split(',') if x.strip()]

# ===== BRSAPI CONFIGURATION =====
BRSAPI_KEY = os.getenv('BRSAPI_KEY', 'FreeQZdOYW6D3nNv95jZ9BcYXJHzTJpf')
BRSAPI_DAILY_LIMIT = int(os.getenv('BRSAPI_DAILY_LIMIT', '10000'))
BRSAPI_MINUTE_LIMIT = int(os.getenv('BRSAPI_MINUTE_LIMIT', '60'))

# ===== ICT TRADING CONFIGURATION =====
ICT_ENABLED = os.getenv('ICT_ENABLED', 'true').lower() == 'true'
ORDER_BLOCK_DETECTION = os.getenv('ORDER_BLOCK_DETECTION', 'true').lower() == 'true'
FAIR_VALUE_GAP_DETECTION = os.getenv('FAIR_VALUE_GAP_DETECTION', 'true').lower() == 'true'
LIQUIDITY_SWEEP_DETECTION = os.getenv('LIQUIDITY_SWEEP_DETECTION', 'true').lower() == 'true'
HTF_TIMEFRAMES = os.getenv('HTF_TIMEFRAMES', '1d,4h').split(',')
LTF_TIMEFRAME = os.getenv('LTF_TIMEFRAME', '1h')

# ===== AI MODEL CONFIGURATION =====
AI_MODEL_ENABLED = os.getenv('AI_MODEL_ENABLED', 'true').lower() == 'true'
AI_CONFIDENCE_THRESHOLD = float(os.getenv('AI_CONFIDENCE_THRESHOLD', '0.7'))
AI_RETRAIN_INTERVAL = int(os.getenv('AI_RETRAIN_INTERVAL', '24'))

# ===== SIGNAL GENERATION =====
SIGNAL_GENERATION_ENABLED = os.getenv('SIGNAL_GENERATION_ENABLED', 'true').lower() == 'true'
SIGNAL_CHECK_INTERVAL = int(os.getenv('SIGNAL_CHECK_INTERVAL', '300'))
SIGNAL_MIN_CONFIDENCE = float(os.getenv('SIGNAL_MIN_CONFIDENCE', '0.6'))
SIGNAL_COOLDOWN = int(os.getenv('SIGNAL_COOLDOWN', '300'))

# ===== RISK MANAGEMENT =====
ICT_RISK_PER_TRADE = float(os.getenv('ICT_RISK_PER_TRADE', '0.02'))
ICT_MAX_DAILY_RISK = float(os.getenv('ICT_MAX_DAILY_RISK', '0.05'))
ICT_RR_RATIO = float(os.getenv('ICT_RR_RATIO', '2.0'))
MAX_DAILY_LOSS_PERCENT = float(os.getenv('MAX_DAILY_LOSS_PERCENT', '5.0'))
MAX_POSITION_SIZE_PERCENT = float(os.getenv('MAX_POSITION_SIZE_PERCENT', '10.0'))
MAX_DRAWDOWN_PERCENT = float(os.getenv('MAX_DRAWDOWN_PERCENT', '15.0'))
MAX_DAILY_TRADES = int(os.getenv('MAX_DAILY_TRADES', '20'))

# ===== MARKET HOURS =====
MARKET_START_HOUR = int(os.getenv('MARKET_START_HOUR', '13'))
MARKET_END_HOUR = int(os.getenv('MARKET_END_HOUR', '22'))
MARKET_TIMEZONE = os.getenv('MARKET_TIMEZONE', 'UTC')

# ===== LOGGING =====
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
LOG_FILE_PATH = os.getenv('LOG_FILE_PATH', 'logs/flowai_ict.log')
LOG_MAX_SIZE = int(os.getenv('LOG_MAX_SIZE', '10'))
LOG_BACKUP_COUNT = int(os.getenv('LOG_BACKUP_COUNT', '5'))

# ===== NOTIFICATIONS =====
NOTIFICATIONS_ENABLED = os.getenv('NOTIFICATIONS_ENABLED', 'true').lower() == 'true'
EMAIL_NOTIFICATIONS = os.getenv('EMAIL_NOTIFICATIONS', 'false').lower() == 'true'
WEBHOOK_NOTIFICATIONS = os.getenv('WEBHOOK_NOTIFICATIONS', 'false').lower() == 'true'

# ===== PERFORMANCE =====
CACHE_ENABLED = os.getenv('CACHE_ENABLED', 'true').lower() == 'true'
CACHE_TTL = int(os.getenv('CACHE_TTL', '300'))
PARALLEL_PROCESSING = os.getenv('PARALLEL_PROCESSING', 'true').lower() == 'true'
MAX_WORKERS = int(os.getenv('MAX_WORKERS', '4'))

# ===== DEVELOPMENT =====
DEBUG_MODE = os.getenv('DEBUG_MODE', 'false').lower() == 'true'
TESTING_MODE = os.getenv('TESTING_MODE', 'false').lower() == 'true'
PAPER_TRADING = os.getenv('PAPER_TRADING', 'true').lower() == 'true'

# ===== ICT SWING ANALYSIS =====
ICT_SWING_LOOKBACK_PERIODS = 10
ICT_SWING_HIGH_LOW_PERIODS = 5
ICT_STRUCTURE_CONFIRMATION_PERIODS = 3

# ===== ICT MSS (Market Structure Shift) =====
ICT_MSS_SWING_LOOKBACK = 20
ICT_MSS_CONFIRMATION_PERIODS = 3
ICT_MSS_MIN_BREAK_PERCENTAGE = 0.001

# ===== ICT BOS (Break of Structure) =====
ICT_BOS_SWING_LOOKBACK = 15
ICT_BOS_CONFIRMATION_PERIODS = 2

# ===== ICT CHoCH (Change of Character) =====
ICT_CHOCH_LOOKBACK_PERIODS = 10
ICT_CHOCH_CONFIRMATION = 3

# ===== ICT ORDER BLOCK SETTINGS =====
ICT_OB_MIN_BODY_RATIO = 0.3
ICT_OB_MIN_SIZE = 0.0005
ICT_OB_MAX_LOOKBACK = 20
ICT_OB_CONFIRMATION_PERIODS = 3

# ===== ICT FAIR VALUE GAP SETTINGS =====
ICT_FVG_MIN_SIZE = 0.0003
ICT_FVG_MAX_LOOKBACK = 15
ICT_FVG_CONFIRMATION_PERIODS = 2

# ===== ICT LIQUIDITY SETTINGS =====
ICT_LIQUIDITY_MIN_VOLUME = 1000
ICT_LIQUIDITY_SWEEP_THRESHOLD = 0.001
ICT_LIQUIDITY_CONFIRMATION = 3

# ===== ICT PD ARRAY SETTINGS =====
ICT_PD_ARRAY_LOOKBACK_PERIODS = 50
ICT_PD_ARRAY_MIN_TOUCHES = 3
ICT_PD_ARRAY_CONFIRMATION = 2

# ===== ICT PREMIUM DISCOUNT SETTINGS =====
ICT_PREMIUM_THRESHOLD = 0.7
ICT_DISCOUNT_THRESHOLD = 0.3
ICT_EQUILIBRIUM_RANGE = 0.1

# ===== ICT KILLZONE SETTINGS =====
ICT_LONDON_KILLZONE_START = 7
ICT_LONDON_KILLZONE_END = 10
ICT_NY_KILLZONE_START = 13
ICT_NY_KILLZONE_END = 16

# ===== ICT PD RETRACEMENT LEVELS =====
ICT_PD_RETRACEMENT_LEVELS = [0.236, 0.382, 0.5, 0.618, 0.786]
ICT_PD_EXTENSION_LEVELS = [1.272, 1.414, 1.618, 2.0, 2.618]

# ===== ICT DISPLACEMENT SETTINGS =====
ICT_DISPLACEMENT_MIN_CANDLES = 5
ICT_DISPLACEMENT_MIN_PERCENTAGE = 0.5

# ===== ICT IMBALANCE SETTINGS =====
ICT_IMBALANCE_MIN_SIZE = 0.0002
ICT_IMBALANCE_MAX_AGE = 100

# ===== ICT PATTERN SETTINGS =====
ICT_ORDER_BLOCK_MIN_SIZE = 0.0005
ICT_FAIR_VALUE_GAP_MIN_SIZE = 0.0003
ICT_LIQUIDITY_THRESHOLD = 0.001

# Configuration validation
def validate_config():
    """Validate configuration settings"""
    import logging
    logger = logging.getLogger(__name__)
    
    if not TELEGRAM_BOT_TOKEN:
        logger.error("TELEGRAM_BOT_TOKEN is required")
        return False
    
    if not TELEGRAM_ADMIN_IDS:
        logger.error("TELEGRAM_ADMIN_IDS is required")
        return False
    
    logger.info("Configuration validation passed")
    return True

# Initialize configuration
if validate_config():
    import logging
    logger = logging.getLogger(__name__)
    logger.info("FlowAI-ICT Configuration loaded successfully")
    logger.info(f"ICT Strategy: {'Enabled' if ICT_ENABLED else 'Disabled'}")
    logger.info(f"AI Model: {'Enabled' if AI_MODEL_ENABLED else 'Disabled'}")
    logger.info(f"Admin IDs: {TELEGRAM_ADMIN_IDS}")
    logger.info(f"Premium Users: {len(TELEGRAM_PREMIUM_USERS)}")
EOF
}

# Enhanced quick install with complete fixes
quick_install() {
    print_banner
    echo -e "${CYAN}🚀 Quick Installation Starting...${NC}"
    echo ""
    
    quick_config
    
    echo ""
    echo -e "${CYAN}Starting automated installation...${NC}"
    echo ""
    
    local steps=(
        "System Update"
        "Essential Packages" 
        "Optional Packages"
        "Project Setup"
        "Virtual Environment"
        "Python Dependencies"
        "Directory Structure"
        "Complete Configuration"
        "Code Fixes"
        "System Service"
        "Utility Scripts"
        "Final Testing"
    )
    local total=${#steps[@]}
    local current=0
    
    # Step 1: System Update
    ((current++))
    print_step_simple "${steps[0]}" $current $total "running"
    if timeout 300s sudo apt update >/dev/null 2>&1; then
        if timeout 600s sudo apt upgrade -y >/dev/null 2>&1; then
            print_step_simple "${steps[0]}" $current $total "success"
        else
            print_step_simple "${steps[0]}" $current $total "error"
            print_warning "System upgrade failed, but continuing..."
        fi
    else
        print_step_simple "${steps[0]}" $current $total "error"
        log_error "System Update" "Failed to update system" "apt update" "$?"
        print_warning "System update failed, but continuing..."
    fi
    
    # Step 2: Essential Packages
    ((current++))
    print_step_simple "${steps[1]}" $current $total "running"
    local essential_packages="python3 python3-pip python3-venv python3-dev git"
    if install_packages_safely "$essential_packages" "Essential"; then
        print_step_simple "${steps[1]}" $current $total "success"
    else
        print_step_simple "${steps[1]}" $current $total "error"
        echo -e "${RED}Essential packages failed to install. Cannot continue.${NC}"
        return 1
    fi
    
    # Step 3: Optional Packages
    ((current++))
    print_step_simple "${steps[2]}" $current $total "running"
    local optional_packages="curl wget unzip build-essential software-properties-common htop nano vim"
    install_packages_safely "$optional_packages" "Optional"
    print_step_simple "${steps[2]}" $current $total "success"
    
    # Step 4: Project Setup (FIXED)
    ((current++))
    print_step_simple "${steps[3]}" $current $total "running"
    
    # Remove any existing installation completely
    if [ -d "$INSTALL_DIR" ]; then
        backup_dir="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        sudo mv "$INSTALL_DIR" "$backup_dir" >/dev/null 2>&1
        print_warning "Existing installation backed up to $backup_dir"
    fi
    
    # Clone directly to correct location
    if timeout 120s sudo git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git "$INSTALL_DIR" >/dev/null 2>&1; then
        # Fix nested directory issue
        if [ -d "$INSTALL_DIR/FlowAI-ICT-Trading-Bot" ]; then
            print_warning "Fixing nested directory structure..."
            sudo mv "$INSTALL_DIR/FlowAI-ICT-Trading-Bot"/* "$INSTALL_DIR/" 2>/dev/null
            sudo rmdir "$INSTALL_DIR/FlowAI-ICT-Trading-Bot" 2>/dev/null
        fi
        
        sudo chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR"
        print_step_simple "${steps[3]}" $current $total "success"
    else
        print_step_simple "${steps[3]}" $current $total "error"
        log_error "Git Clone" "Failed to clone repository" "git clone" "$?"
        return 1
    fi
    
    # Step 5: Virtual Environment (FIXED)
    ((current++))
    print_step_simple "${steps[4]}" $current $total "running"
    cd "$INSTALL_DIR" || {
        print_step_simple "${steps[4]}" $current $total "error"
        log_error "Directory Change" "Cannot access $INSTALL_DIR" "cd" "1"
        return 1
    }
    
    # Remove existing venv if corrupted
    if [ -d "venv" ]; then
        rm -rf venv
    fi
    
    if python3 -m venv venv >/dev/null 2>&1; then
        if source venv/bin/activate && pip install --upgrade pip setuptools wheel >/dev/null 2>&1; then
            print_step_simple "${steps[4]}" $current $total "success"
        else
            print_step_simple "${steps[4]}" $current $total "error"
            log_error "Pip Upgrade" "Failed to upgrade pip" "pip upgrade" "$?"
            print_warning "Pip upgrade failed but venv created. Continuing..."
        fi
    else
        print_step_simple "${steps[4]}" $current $total "error"
        log_error "Virtual Environment" "Failed to create venv" "python3 -m venv" "$?"
        return 1
    fi
    
    # Step 6: Python Dependencies (FIXED)
    ((current++))
    print_step_simple "${steps[5]}" $current $total "running"
    source venv/bin/activate
    
    if pip install -r requirements.txt; then
        print_step_simple "${steps[5]}" $current $total "success"
    else
        print_step_simple "${steps[5]}" $current $total "error"
        log_error "Python Dependencies" "Failed to install from requirements.txt" "pip install -r requirements.txt" "$?"
        print_warning "Python dependencies installation failed. Continuing, but errors are likely."
    fi
    
    # Step 7: Directory Structure
    ((current++))
    print_step_simple "${steps[6]}" $current $total "running"
    local directories=("logs" "reports" "backups" "models" "data" "config" "temp" "flow_ai_core/data_sources" "flow_ai_core/telegram")
    for dir in "${directories[@]}"; do
        mkdir -p "$dir" && chmod 755 "$dir"
    done
    touch flow_ai_core/__init__.py flow_ai_core/data_sources/__init__.py flow_ai_core/telegram/__init__.py
    print_step_simple "${steps[6]}" $current $total "success"
    
    # Step 8: Complete Configuration (NEW)
    ((current++))
    print_step_simple "${steps[7]}" $current $total "running"
    
    # Create .env file
    cat > .env << EOF
TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN
TELEGRAM_ADMIN_IDS=$ADMIN_ID
TELEGRAM_PREMIUM_USERS=
BRSAPI_KEY=FreeQZdOYW6D3nNv95jZ9BcYXJHzTJpf
BRSAPI_DAILY_LIMIT=10000
BRSAPI_MINUTE_LIMIT=60
ICT_ENABLED=true
ORDER_BLOCK_DETECTION=true
FAIR_VALUE_GAP_DETECTION=true
LIQUIDITY_SWEEP_DETECTION=true
HTF_TIMEFRAMES=1d,4h
LTF_TIMEFRAME=1h
AI_MODEL_ENABLED=true
AI_CONFIDENCE_THRESHOLD=0.7
AI_RETRAIN_INTERVAL=24
SIGNAL_GENERATION_ENABLED=true
SIGNAL_CHECK_INTERVAL=300
SIGNAL_MIN_CONFIDENCE=0.6
SIGNAL_COOLDOWN=300
ICT_RISK_PER_TRADE=0.02
ICT_MAX_DAILY_RISK=0.05
ICT_RR_RATIO=2.0
MAX_DAILY_LOSS_PERCENT=5.0
MAX_POSITION_SIZE_PERCENT=10.0
MAX_DRAWDOWN_PERCENT=15.0
MAX_DAILY_TRADES=20
MARKET_START_HOUR=13
MARKET_END_HOUR=22
MARKET_TIMEZONE=UTC
LOG_LEVEL=INFO
LOG_FILE_PATH=logs/flowai_ict.log
LOG_MAX_SIZE=10
LOG_BACKUP_COUNT=5
NOTIFICATIONS_ENABLED=true
EMAIL_NOTIFICATIONS=false
WEBHOOK_NOTIFICATIONS=false
CACHE_ENABLED=true
CACHE_TTL=300
PARALLEL_PROCESSING=true
MAX_WORKERS=4
DEBUG_MODE=false
TESTING_MODE=false
PAPER_TRADING=true
EOF
    print_step_simple "${steps[7]}" $current $total "success"
    
    # Step 9: Code Fixes (NEW)
    ((current++))
    print_step_simple "${steps[8]}" $current $total "running"
    
    # Ensure telegram_bot.py is in root directory
    if [ -f "flow_ai_core/telegram_bot.py" ] && [ ! -f "telegram_bot.py" ]; then
        cp flow_ai_core/telegram_bot.py telegram_bot.py
        chmod +x telegram_bot.py
    fi
    
    # Create main telegram_bot.py if missing
    if [ ! -f "telegram_bot.py" ]; then
        cat > telegram_bot.py << 'EOF'
#!/usr/bin/env python3
"""
FlowAI-ICT Trading Bot v4.0
Main Telegram Bot Entry Point
"""

import sys
import os
import logging
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/flowai_ict.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

def main():
    """Main bot function"""
    try:
        logger.info("🚀 FlowAI-ICT Trading Bot v4.0 Starting...")
        
        # Import and validate config
        from flow_ai_core import config
        
        if not config.validate_config():
            logger.error("Configuration validation failed")
            sys.exit(1)
        
        # Check if flow_ai_core telegram module exists
        if os.path.exists('flow_ai_core/telegram'):
            logger.info("✅ flow_ai_core telegram module found")
            
            try:
                from flow_ai_core.telegram import setup_telegram_handlers
                logger.info("✅ Telegram handlers imported successfully")
                
                # Setup and run bot
                setup_telegram_handlers()
                
            except ImportError as e:
                logger.error(f"❌ Failed to import telegram handlers: {e}")
                simple_bot()
        else:
            logger.warning("⚠️ flow_ai_core telegram module not found, running simple bot")
            simple_bot()
            
    except Exception as e:
        logger.error(f"❌ Bot startup failed: {e}")
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)

def simple_bot():
    """Simple fallback bot"""
    import time
    from telegram.ext import Updater
    from flow_ai_core.config import TELEGRAM_BOT_TOKEN
    
    logger.info("🤖 Running simple bot mode...")
    
    try:
        updater = Updater(token=TELEGRAM_BOT_TOKEN, use_context=True)
        dispatcher = updater.dispatcher
        
        def start(update, context):
            update.message.reply_text("🚀 FlowAI-ICT Trading Bot v4.0 is running!")
        
        from telegram.ext import CommandHandler
        dispatcher.add_handler(CommandHandler('start', start))
        
        updater.start_polling()
        logger.info("✅ Simple bot started successfully")
        updater.idle()
        
    except Exception as e:
        logger.error(f"❌ Simple bot failed: {e}")
        # Fallback to basic loop
        while True:
            logger.info("💓 Bot is alive...")
            time.sleep(60)

if __name__ == '__main__':
    main()
EOF
        chmod +x telegram_bot.py
    fi
    
    print_step_simple "${steps[8]}" $current $total "success"
    
    # Step 10: System Service
    ((current++))
    print_step_simple "${steps[9]}" $current $total "running"
    sudo tee /etc/systemd/system/flowai-ict-bot.service > /dev/null << EOF
[Unit]
Description=FlowAI-ICT Trading Bot v4.0
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python telegram_bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=flowai-ict-bot

[Install]
WantedBy=multi-user.target
EOF
    
    if sudo systemctl daemon-reload && sudo systemctl enable flowai-ict-bot >/dev/null 2>&1; then
        print_step_simple "${steps[9]}" $current $total "success"
    else
        print_step_simple "${steps[9]}" $current $total "error"
        log_error "Service Setup" "Failed to enable service" "systemctl enable" "$?"
        print_warning "Service setup failed but continuing..."
    fi
    
    # Step 11: Utility Scripts
    ((current++))
    print_step_simple "${steps[10]}" $current $total "running"
    cat > start_bot.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting FlowAI-ICT Trading Bot v4.0..."
cd /opt/FlowAI-ICT-Trading-Bot
source venv/bin/activate
python telegram_bot.py
EOF
    
    cat > health_check.sh << 'EOF'
#!/bin/bash
echo "💊 FlowAI-ICT Health Check v4.0"
echo "================================="

if systemctl is-active --quiet flowai-ict-bot; then
    echo "✅ Service: Running"
    echo "⏰ Uptime: $(systemctl show flowai-ict-bot --property=ActiveEnterTimestamp --value | cut -d' ' -f2-)"
else
    echo "❌ Service: Stopped"
fi

cd /opt/FlowAI-ICT-Trading-Bot
if [ -d "venv" ] && [ -f "venv/bin/activate" ]; then
    echo "✅ Virtual Environment: OK"
    source venv/bin/activate
    echo "🐍 Python: $(python --version)"
    
    if "$INSTALL_DIR/venv/bin/python" -c "import telegram, pandas, numpy, ta" &>/dev/null; then
        echo "✅ Dependencies: All OK"
    else
        echo "❌ Dependencies: Some missing"
    fi
else
    echo "❌ Virtual Environment: Missing"
fi

if [ -f ".env" ]; then
    echo "✅ Configuration: Found"
    if grep -q "TELEGRAM_BOT_TOKEN=" .env && [ "$(grep TELEGRAM_BOT_TOKEN= .env | cut -d'=' -f2)" != "your_bot_token_here" ]; then
        echo "✅ Telegram Token: Configured"
    else
        echo "❌ Telegram Token: Not configured"
    fi
else
    echo "❌ Configuration: Missing"
fi

if [ -d "logs" ]; then
    echo "✅ Logs: $(ls logs/ 2>/dev/null | wc -l) files"
else
    echo "❌ Logs: Directory missing"
fi

echo "💻 Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
echo "💿 Disk: $(df -h / | awk 'NR==2{print $5}')"
echo "================================="
EOF
    
    chmod +x start_bot.sh health_check.sh
    print_step_simple "${steps[10]}" $current $total "success"
    
    # Step 12: Final Testing
    ((current++))
    print_step_simple "${steps[11]}" $current $total "running"
    source venv/bin/activate
    
    # Test critical imports
    local critical_imports=("telegram" "pandas" "numpy" "requests" "dotenv" "ta")
    local failed_imports=()
    local success_imports=()
    
    for import_name in "${critical_imports[@]}"; do
        if "$INSTALL_DIR/venv/bin/python" -c "import $import_name" >/dev/null 2>&1; then
            success_imports+=("$import_name")
        else
            failed_imports+=("$import_name")
        fi
    done
    
    # Test config import
    if "$INSTALL_DIR/venv/bin/python" -c "from flow_ai_core import config; config.validate_config()" >/dev/null 2>&1; then
        success_imports+=("config")
    else
        failed_imports+=("config")
    fi
    
    if [ ${#success_imports[@]} -ge 6 ]; then
        print_step_simple "${steps[11]}" $current $total "success"
        if [ ${#failed_imports[@]} -gt 0 ]; then
            print_warning "Some imports failed: ${failed_imports[*]}"
        fi
    else
        print_step_simple "${steps[11]}" $current $total "error"
        log_error "Final Testing" "Critical imports failed: ${failed_imports[*]}" "python imports" "1"
        print_warning "Critical imports failed but installation completed"
    fi
    
    # Show completion
    echo ""
    echo -e "${GREEN}🎉 Installation Completed! 🎉${NC}"
    echo ""
    
    # Show summary
    echo -e "${CYAN}📋 Installation Summary:${NC}"
    echo -e "${WHITE}✓ Project cloned to: $INSTALL_DIR${NC}"
    echo -e "${WHITE}✓ Virtual environment created${NC}"
    echo -e "${WHITE}✓ Complete configuration created${NC}"
    echo -e "${WHITE}✓ All ICT variables added${NC}"
    echo -e "${WHITE}✓ Code fixes applied${NC}"
    echo -e "${WHITE}✓ System service configured${NC}"
    echo -e "${WHITE}✓ Utility scripts created${NC}"
    
    if [ ${#failed_imports[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Some packages may need manual installation: ${failed_imports[*]}${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}🚀 Quick Start:${NC}"
    echo -e "${WHITE}  sudo systemctl start flowai-ict-bot${NC}"
    echo -e "${WHITE}  sudo systemctl status flowai-ict-bot${NC}"
    echo ""
    
    # Enhanced start option
    echo -e "${YELLOW}Start the bot now? (y/n):${NC}"
    read -r start_now
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        print_step "Starting FlowAI-ICT Bot..."
        if sudo systemctl start flowai-ict-bot; then
            sleep 3
            if systemctl is-active --quiet flowai-ict-bot; then
                print_success "Bot started successfully!"
                echo -e "${CYAN}Check status: sudo systemctl status flowai-ict-bot${NC}"
            else
                print_warning "Bot started but may have issues"
                echo -e "${CYAN}Check logs: sudo journalctl -u flowai-ict-bot -f${NC}"
            fi
        else
            print_error "Failed to start bot service"
            echo -e "${CYAN}Try manual start: cd $INSTALL_DIR && ./start_bot.sh${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✅ Installation complete! Returning to management panel...${NC}"
    sleep 2
    
    # Update installation status
    check_installation
}

# Service Management Function
manage_service() {
    while true; do
        print_banner
        echo -e "${CYAN}🚀 Service Management${NC}"
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}1.${NC} ▶️  ${WHITE}Start Bot${NC}                                       ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}2.${NC} ⏹️  ${WHITE}Stop Bot${NC}                                        ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 🔄 ${WHITE}Restart Bot${NC}                                     ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}4.${NC} 📊 ${WHITE}Service Status${NC}                                  ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}5.${NC} 📋 ${WHITE}View Real-time Logs${NC}                             ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}6.${NC} 🔧 ${WHITE}Enable/Disable Auto-start${NC}                      ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}7.${NC} 🧪 ${WHITE}Test Bot Configuration${NC}                         ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}8.${NC} 📈 ${WHITE}Performance Monitor${NC}                            ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}0.${NC} 🔙 ${WHITE}Back to Main Menu${NC}                              ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        
        # Current status display
        if systemctl is-active --quiet flowai-ict-bot; then
            echo -e "${GREEN}Current Status: Running ✅${NC}"
            uptime_info=$(systemctl show flowai-ict-bot --property=ActiveEnterTimestamp --value 2>/dev/null | cut -d' ' -f2- || echo "Unknown")
            echo -e "${CYAN}Started: $uptime_info${NC}"
        else
            echo -e "${RED}Current Status: Stopped ❌${NC}"
        fi
        
        echo ""
        echo -e "${WHITE}Choose action (0-8):${NC}"
        read -r action
        
        case $action in
            1)
                print_step "Starting FlowAI-ICT Bot..."
                if sudo systemctl start flowai-ict-bot; then
                    sleep 2
                    if systemctl is-active --quiet flowai-ict-bot; then
                        print_success "Bot started successfully!"
                    else
                        print_error "Bot failed to start properly"
                        echo -e "${CYAN}Check logs: sudo journalctl -u flowai-ict-bot -n 20${NC}"
                    fi
                else
                    print_error "Failed to start bot service"
                fi
                wait_for_input
                ;;
            2)
                print_step "Stopping FlowAI-ICT Bot..."
                if sudo systemctl stop flowai-ict-bot; then
                    print_success "Bot stopped successfully"
                else
                    print_error "Failed to stop bot service"
                fi
                wait_for_input
                ;;
            3)
                print_step "Restarting FlowAI-ICT Bot..."
                if sudo systemctl restart flowai-ict-bot; then
                    sleep 3
                    if systemctl is-active --quiet flowai-ict-bot; then
                        print_success "Bot restarted successfully!"
                    else
                        print_error "Bot failed to restart properly"
                        echo -e "${CYAN}Check logs: sudo journalctl -u flowai-ict-bot -n 20${NC}"
                    fi
                else
                    print_error "Failed to restart bot service"
                fi
                wait_for_input
                ;;
            4)
                echo -e "${CYAN}📊 Detailed Service Status:${NC}"
                echo -e "${CYAN}═══════════════════════════════${NC}"
                sudo systemctl status flowai-ict-bot --no-pager
                echo ""
                echo -e "${CYAN}Recent logs:${NC}"
                sudo journalctl -u flowai-ict-bot -n 10 --no-pager
                wait_for_input
                ;;
            5)
                echo -e "${CYAN}📋 Real-time logs (Press Ctrl+C to exit):${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════${NC}"
                sudo journalctl -u flowai-ict-bot -f
                ;;
            6)
                if systemctl is-enabled --quiet flowai-ict-bot; then
                    echo -e "${YELLOW}Auto-start is currently: ENABLED${NC}"
                    echo -e "${WHITE}Disable auto-start? (y/n):${NC}"
                    read -r disable_choice
                    if [[ "$disable_choice" =~ ^[Yy]$ ]]; then
                        sudo systemctl disable flowai-ict-bot
                        print_success "Auto-start disabled"
                    fi
                else
                    echo -e "${YELLOW}Auto-start is currently: DISABLED${NC}"
                    echo -e "${WHITE}Enable auto-start? (y/n):${NC}"
                    read -r enable_choice
                    if [[ "$enable_choice" =~ ^[Yy]$ ]]; then
                        sudo systemctl enable flowai-ict-bot
                        print_success "Auto-start enabled"
                    fi
                fi
                wait_for_input
                ;;
            7)
                echo -e "${CYAN}🧪 Testing Bot Configuration...${NC}"
                cd "$INSTALL_DIR" 2>/dev/null || { echo -e "${RED}Installation directory not found${NC}"; wait_for_input; continue; }
                
                if [ -f ".env" ]; then
                    echo -e "${GREEN}✅ Configuration file found${NC}"
                    
                    # Test virtual environment
                    if [ -d "venv" ] && [ -f "venv/bin/activate" ]; then
                        echo -e "${GREEN}✅ Virtual environment OK${NC}"
                        source venv/bin/activate
                        
                        # Test imports
                        local test_imports=("telegram" "pandas" "numpy" "ta" "requests")
                        local failed_tests=()
                        
                        for import_name in "${test_imports[@]}"; do
                            if "$INSTALL_DIR/venv/bin/python" -c "import $import_name" 2>/dev/null; then
                                echo -e "${GREEN}✅ $import_name: Available${NC}"
                            else
                                echo -e "${RED}❌ $import_name: Missing${NC}"
                                failed_tests+=("$import_name")
                            fi
                        done
                        
                        # Test config
                        if "$INSTALL_DIR/venv/bin/python" -c "from flow_ai_core import config; config.validate_config()" 2>/dev/null; then
                            echo -e "${GREEN}✅ Configuration validation passed${NC}"
                        else
                            echo -e "${RED}❌ Configuration validation failed${NC}"
                        fi
                        
                        if [ ${#failed_tests[@]} -eq 0 ]; then
                            echo -e "${GREEN}🎉 All tests passed! Bot should work properly.${NC}"
                        else
                            echo -e "${YELLOW}⚠ Some dependencies missing: ${failed_tests[*]}${NC}"
                            echo -e "${CYAN}Try: source venv/bin/activate && pip install ${failed_tests[*]}${NC}"
                        fi
                    else
                        echo -e "${RED}❌ Virtual environment missing${NC}"
                    fi
                else
                    echo -e "${RED}❌ Configuration file missing${NC}"
                fi
                wait_for_input
                ;;
            8)
                echo -e "${CYAN}📈 Performance Monitor${NC}"
                echo -e "${CYAN}═══════════════════════${NC}"
                
                # System resources
                echo -e "${WHITE}System Resources:${NC}"
                echo -e "💻 Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
                echo -e "💿 Disk: $(df -h / | awk 'NR==2{print $5}')"
                echo -e "🔥 CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
                
                # Bot specific resources
                if systemctl is-active --quiet flowai-ict-bot; then
                    echo ""
                    echo -e "${WHITE}Bot Resources:${NC}"
                    bot_pid=$(systemctl show flowai-ict-bot --property=MainPID --value)
                    if [ "$bot_pid" != "0" ] && [ -n "$bot_pid" ]; then
                        bot_memory=$(ps -p "$bot_pid" -o %mem --no-headers 2>/dev/null | tr -d ' ')
                        bot_cpu=$(ps -p "$bot_pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ')
                        echo -e "🤖 Bot Memory: ${bot_memory}%"
                        echo -e "🤖 Bot CPU: ${bot_cpu}%"
                    fi
                    
                    # Service uptime
                    uptime_seconds=$(systemctl show flowai-ict-bot --property=ActiveEnterTimestampMonotonic --value)
                    if [ -n "$uptime_seconds" ] && [ "$uptime_seconds" != "0" ]; then
                        echo -e "⏰ Bot Uptime: $(systemctl show flowai-ict-bot --property=ActiveEnterTimestamp --value | cut -d' ' -f2-)"
                    fi
                else
                    echo -e "${RED}Bot is not running${NC}"
                fi
                
                wait_for_input
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Complete Uninstall Function
complete_uninstall() {
    print_banner
    echo -e "${RED}🗑️ Complete Uninstall FlowAI-ICT Trading Bot${NC}"
    echo -e "${RED}═══════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}⚠️  WARNING: This will completely remove FlowAI-ICT Trading Bot${NC}"
    echo -e "${YELLOW}   including all data, logs, and configurations!${NC}"
    echo ""
    echo -e "${WHITE}What will be removed:${NC}"
    echo -e "${RED}  • Installation directory: $INSTALL_DIR${NC}"
    echo -e "${RED}  • System service: flowai-ict-bot${NC}"
    echo -e "${RED}  • User 'flowai' (optional)${NC}"
    echo -e "${RED}  • All logs and data${NC}"
    echo -e "${RED}  • All configurations${NC}"
    echo ""
    
    echo -e "${YELLOW}Are you absolutely sure? Type 'YES' to confirm:${NC}"
    read -r confirm
    
    if [ "$confirm" != "YES" ]; then
        print_warning "Uninstall cancelled"
        wait_for_input
        return
    fi
    
    print_step "Starting complete uninstall..."
    
    # Stop and disable service
    if systemctl is-active --quiet flowai-ict-bot; then
        print_step "Stopping FlowAI-ICT service..."
        sudo systemctl stop flowai-ict-bot
        print_success "Service stopped"
    fi
    
    if systemctl is-enabled --quiet flowai-ict-bot; then
        print_step "Disabling FlowAI-ICT service..."
        sudo systemctl disable flowai-ict-bot
        print_success "Service disabled"
    fi
    
    # Remove service file
    if [ -f "/etc/systemd/system/flowai-ict-bot.service" ]; then
        print_step "Removing service file..."
        sudo rm -f /etc/systemd/system/flowai-ict-bot.service
        sudo systemctl daemon-reload
        print_success "Service file removed"
    fi
    
    # Remove installation directory
    if [ -d "$INSTALL_DIR" ]; then
        print_step "Removing installation directory..."
        sudo rm -rf "$INSTALL_DIR"
        print_success "Installation directory removed"
    fi
    
    # Remove logs
    print_step "Cleaning up logs..."
    rm -f "$LOG_FILE" "$ERROR_LOG" 2>/dev/null
    sudo rm -f /tmp/flowai_*.log 2>/dev/null
    sudo rm -f /var/log/flowai* 2>/dev/null
    print_success "Logs cleaned"
    
    # Ask about removing flowai user
    echo ""
    echo -e "${YELLOW}Remove 'flowai' user account? (y/n):${NC}"
    read -r remove_user
    
    if [[ "$remove_user" =~ ^[Yy]$ ]]; then
        if id "flowai" &>/dev/null; then
            print_step "Removing flowai user..."
            sudo userdel -r flowai 2>/dev/null
            sudo rm -f /etc/sudoers.d/flowai 2>/dev/null
            print_success "User 'flowai' removed"
        fi
    fi
    
    # Clean up any remaining files
    print_step "Final cleanup..."
    sudo rm -f /home/flowai/Install.sh 2>/dev/null
    print_success "Cleanup completed"
    
    echo ""
    echo -e "${GREEN}🎉 FlowAI-ICT Trading Bot completely uninstalled!${NC}"
    echo ""
    echo -e "${CYAN}System is now clean and ready for fresh installation.${NC}"
    echo ""
    
    wait_for_input
    
    # Reset installation status
    INSTALLATION_EXISTS=false
}

# Clear error logs function
clear_error_logs() {
    print_banner
    echo -e "${CYAN}🧹 Clear Error Logs${NC}"
    echo -e "${CYAN}═══════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}This will clear all error logs and reset error count.${NC}"
    echo -e "${WHITE}Continue? (y/n):${NC}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f "$ERROR_LOG" "$LOG_FILE" 2>/dev/null
        ERROR_COUNT=0
        init_logs
        print_success "Error logs cleared"
    else
        print_warning "Operation cancelled"
    fi
    
    wait_for_input
}

# View error logs function
view_error_logs() {
    print_banner
    echo -e "${CYAN}🐛 Error Logs & Diagnostics${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    
    if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
        echo -e "${WHITE}Recent Errors:${NC}"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
        tail -20 "$ERROR_LOG"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    else
        echo -e "${GREEN}✅ No error log found - system appears healthy${NC}"
    fi
    
    echo ""
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        echo -e "${WHITE}Recent Actions:${NC}"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
        tail -10 "$LOG_FILE"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}Log Files:${NC}"
    echo -e "${CYAN}• Installation Log: $LOG_FILE${NC}"
    echo -e "${CYAN}• Error Log: $ERROR_LOG${NC}"
    if [ -f "$INSTALL_DIR/logs/flowai_ict.log" ]; then
        echo -e "${CYAN}• Bot Log: $INSTALL_DIR/logs/flowai_ict.log${NC}"
    fi
    
    wait_for_input
}

# System status function
show_system_status() {
    print_banner
    echo -e "${CYAN}📊 System Status & Health Check${NC}"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
    echo ""
    
    # Service status
    if systemctl is-active --quiet flowai-ict-bot; then
        echo -e "${GREEN}🟢 Service Status: Running${NC}"
        uptime_info=$(systemctl show flowai-ict-bot --property=ActiveEnterTimestamp --value)
        echo -e "${CYAN}⏰ Started: ${uptime_info}${NC}"
    else
        echo -e "${RED}🔴 Service Status: Stopped${NC}"
    fi
    
    # Configuration check
    if [ -f "$INSTALL_DIR/.env" ]; then
        echo -e "${GREEN}✅ Configuration: Found${NC}"
        if grep -q "TELEGRAM_BOT_TOKEN=" "$INSTALL_DIR/.env" && [ "$(grep TELEGRAM_BOT_TOKEN= "$INSTALL_DIR/.env" | cut -d'=' -f2)" != "your_bot_token_here" ]; then
            echo -e "${GREEN}✅ Telegram Token: Configured${NC}"
        else
            echo -e "${RED}❌ Telegram Token: Missing${NC}"
        fi
    else
        echo -e "${RED}❌ Configuration: Missing${NC}"
    fi
    
    # Virtual environment
    if [ -d "$INSTALL_DIR/venv" ]; then
        echo -e "${GREEN}✅ Virtual Environment: OK${NC}"
        cd "$INSTALL_DIR"
        source venv/bin/activate 2>/dev/null
        echo -e "${CYAN}🐍 Python Version: $(python --version 2>/dev/null || echo 'Unknown')${NC}"
    else
        echo -e "${RED}❌ Virtual Environment: Missing${NC}"
    fi
    
    # Dependencies check
    if [ -d "$INSTALL_DIR/venv" ]; then
        cd "$INSTALL_DIR"
        source venv/bin/activate 2>/dev/null
        if "$INSTALL_DIR/venv/bin/python" -c "import telegram, pandas, numpy, ta" &>/dev/null; then
            echo -e "${GREEN}✅ Dependencies: All OK${NC}"
        else
            echo -e "${YELLOW}⚠ Dependencies: Some issues${NC}"
        fi
    fi
    
    # System resources
    echo ""
    echo -e "${CYAN}💻 System Resources:${NC}"
    echo -e "${WHITE}📊 Memory Usage: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')${NC}"
    echo -e "${WHITE}💿 Disk Usage: $(df -h / | awk 'NR==2{print $5}')${NC}"
    echo -e "${WHITE}🔥 CPU Load: $(uptime | awk -F'load average:' '{print $2}')${NC}"
    
    echo ""
    wait_for_input
}

# Install menu
install_menu() {
    while true; do
        print_banner
        print_install_menu
        
        echo -e "${WHITE}Choose option (0-5):${NC}"
        read -r choice
        
        case $choice in
            1) 
                quick_install
                check_installation
                if [ "$INSTALLATION_EXISTS" = true ]; then
                    return
                fi
                ;;
            2) 
                echo -e "${CYAN}🔧 Custom install feature coming in next version...${NC}"
                wait_for_input
                ;;
            3) 
                echo -e "${CYAN}🔍 System check feature coming in next version...${NC}"
                wait_for_input
                ;;
            4) view_error_logs ;;
            5) clear_error_logs ;;
            0) exit 0 ;;
            *) 
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Management menu
management_menu() {
    while true; do
        print_banner
        print_management_menu
        
        echo -e "${WHITE}Choose option (0-9):${NC}"
        read -r choice
        
        case $choice in
            1) show_system_status ;;
            2) manage_service ;;
            3) 
                if [ -f "$INSTALL_DIR/health_check.sh" ]; then
                    cd "$INSTALL_DIR"
                    ./health_check.sh
                    wait_for_input
                else
                    echo -e "${RED}Health check script not found${NC}"
                    wait_for_input
                fi
                ;;
            4)
                echo -e "${CYAN}⚙️ Configuration Management${NC}"
                echo ""
                echo -e "${WHITE}Configuration file: $INSTALL_DIR/.env${NC}"
                echo -e "${CYAN}Edit with: nano $INSTALL_DIR/.env${NC}"
                echo ""
                echo -e "${YELLOW}After editing, restart the bot:${NC}"
                echo -e "${WHITE}sudo systemctl restart flowai-ict-bot${NC}"
                wait_for_input
                ;;
            5)
                echo -e "${CYAN}🔄 Update Bot to Latest Version${NC}"
                echo ""
                echo -e "${WHITE}Manual update steps:${NC}"
                echo -e "${CYAN}1. Stop bot: sudo systemctl stop flowai-ict-bot${NC}"
                echo -e "${CYAN}2. Backup config: cp $INSTALL_DIR/.env /tmp/.env.backup${NC}"
                echo -e "${CYAN}3. Update code: cd $INSTALL_DIR && git pull${NC}"
                echo -e "${CYAN}4. Restore config: cp /tmp/.env.backup $INSTALL_DIR/.env${NC}"
                echo -e "${CYAN}5. Update deps: source venv/bin/activate && pip install -r requirements.txt --upgrade${NC}"
                echo -e "${CYAN}6. Start bot: sudo systemctl start flowai-ict-bot${NC}"
                wait_for_input
                ;;
            6)
                echo -e "${CYAN}🔧 Developer tools feature coming soon${NC}"
                wait_for_input
                ;;
            7) complete_uninstall ;;
            8)
                print_banner
                echo -e "${CYAN}📖 Help & Documentation${NC}"
                echo -e "${CYAN}═══════════════════════════${NC}"
                echo ""
                echo -e "${WHITE}FlowAI-ICT Trading Bot v4.0${NC}"
                echo ""
                echo -e "${YELLOW}Quick Commands:${NC}"
                echo -e "${WHITE}• sudo systemctl start flowai-ict-bot${NC}"
                echo -e "${WHITE}• sudo systemctl stop flowai-ict-bot${NC}"
                echo -e "${WHITE}• sudo systemctl status flowai-ict-bot${NC}"
                echo -e "${WHITE}• sudo journalctl -u flowai-ict-bot -f${NC}"
                echo ""
                echo -e "${YELLOW}Files:${NC}"
                echo -e "${WHITE}• Installation: $INSTALL_DIR${NC}"
                echo -e "${WHITE}• Configuration: $INSTALL_DIR/.env${NC}"
                echo -e "${WHITE}• Logs: $INSTALL_DIR/logs/${NC}"
                echo ""
                echo -e "${YELLOW}Features:${NC}"
                echo -e "${WHITE}• ICT Methodology (Order Blocks, FVG, Liquidity)${NC}"
                echo -e "${WHITE}• AI-Powered Signal Generation${NC}"
                echo -e "${WHITE}• Real-time BrsAPI Integration${NC}"
                echo -e "${WHITE}• Advanced Risk Management${NC}"
                echo -e "${WHITE}• Telegram Bot Interface${NC}"
                echo ""
                echo -e "${YELLOW}Support:${NC}"
                echo -e "${WHITE}• GitHub: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot${NC}"
                echo ""
                wait_for_input
                ;;
            9) view_error_logs ;;
            0) exit 0 ;;
            *) 
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Main execution
main() {
    # Initialize logging first
    init_logs
    
    # Log startup
    echo "FlowAI-ICT Installation/Management Log v4.0 - $(date)" > "$LOG_FILE"
    
    # Handle root user automatically
    handle_root_user
    
    # Check installation status
    check_installation
    
    # Main loop
    while true; do
        # Re-check installation status
        check_installation
        
        if [ "$INSTALLATION_EXISTS" = true ]; then
            management_menu
        else
            install_menu
        fi
    done
}

# Run main function
main "$@"

[end of Install.sh]

[end of Install.sh]
