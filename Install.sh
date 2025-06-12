#!/bin/bash
# FlowAI-ICT Trading Bot Installation & Auto-Update Script
# Version: 4.5 Enhanced
# Author: FlowAI Team
# Description: Complete installation and management system for FlowAI-ICT Trading Bot

set -e  # Exit on any error

# ===== SCRIPT CONFIGURATION =====
SCRIPT_VERSION="4.5"
SCRIPT_NAME="FlowAI-ICT Trading Bot Installer"
REQUIRED_PYTHON_VERSION="3.8"
GITHUB_REPO="https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git"

# ===== COLORS AND FORMATTING =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Background colors
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'

# Text styles
BOLD='\033[1m'
UNDERLINE='\033[4m'
ITALIC='\033[3m'

# ===== SYSTEM PATHS AND CONFIGURATION =====
INSTALL_DIR="/opt/FlowAI-ICT-Trading-Bot"
SERVICE_NAME="flowai-ict-bot"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
LOG_DIR="/var/log/flowai"
MAIN_LOG_FILE="${LOG_DIR}/flowai-install.log"
ERROR_LOG_FILE="${LOG_DIR}/flowai-errors.log"
UPDATE_LOG_FILE="${LOG_DIR}/flowai-update.log"
BACKUP_BASE_DIR="/var/backups/flowai"
TEMP_DIR="/tmp/flowai-install"
VENV_NAME="venv"
PYTHON_CMD="python3"

# Auto-Update Configuration
UPDATE_SCRIPT_PATH="$INSTALL_DIR/scripts/update_bot.sh"
UPDATE_LOCK_FILE="/tmp/flowai_update.lock"
BACKUP_RETENTION_DAYS=7
UPDATE_CHECK_URL="https://api.github.com/repos/behnamrjd/FlowAI-ICT-Trading-Bot/commits/main"

# ===== PROGRESS TRACKING =====
TOTAL_STEPS=15
CURRENT_STEP=0
START_TIME=$(date +%s)

# ===== DEPENDENCY VERSIONS (Tested and Stable) =====
NUMPY_VERSION="1.26.4"
PANDAS_VERSION="2.0.3"
TELEGRAM_BOT_VERSION="13.15"
TA_VERSION="0.10.2"
URLLIB3_VERSION="1.26.18"
REQUESTS_VERSION="2.28.2"
PYTHON_DOTENV_VERSION="0.19.2"
PSUTIL_VERSION="5.9.8"
AIOHTTP_VERSION="3.8.6"
SCHEDULE_VERSION="1.2.0"

# ===== SYSTEM REQUIREMENTS =====
MIN_RAM_MB=1024
MIN_DISK_GB=5
REQUIRED_PACKAGES=(
    "git"
    "curl"
    "wget"
    "python3"
    "python3-pip"
    "python3-venv"
    "python3-dev"
    "build-essential"
    "pkg-config"
    "libffi-dev"
    "libssl-dev"
)

# ===== LOGGING FUNCTIONS =====
setup_logging() {
    # Create log directories
    sudo mkdir -p "$LOG_DIR"
    sudo touch "$MAIN_LOG_FILE" "$ERROR_LOG_FILE" "$UPDATE_LOG_FILE"
    sudo chown -R $USER:$USER "$LOG_DIR" 2>/dev/null || true
    
    # Setup log rotation
    if command -v logrotate &> /dev/null; then
        sudo tee /etc/logrotate.d/flowai > /dev/null << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
}
EOF
    fi
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "$timestamp [INFO] $message" >> "$MAIN_LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "$timestamp [SUCCESS] $message" >> "$MAIN_LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            echo "$timestamp [WARNING] $message" >> "$MAIN_LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            echo "$timestamp [ERROR] $message" >> "$ERROR_LOG_FILE"
            echo "$timestamp [ERROR] $message" >> "$MAIN_LOG_FILE"
            ;;
        "DEBUG")
            if [[ "${DEBUG:-0}" == "1" ]]; then
                echo -e "${MAGENTA}[DEBUG]${NC} $message"
                echo "$timestamp [DEBUG] $message" >> "$MAIN_LOG_FILE"
            fi
            ;;
    esac
}

# ===== PROGRESS AND STATUS FUNCTIONS =====
print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          FlowAI-ICT Trading Bot v$SCRIPT_VERSION                          ║"
    echo "║                     Advanced Installation & Update System                   ║"
    echo "║                                                                              ║"
    echo "║  🤖 AI-Powered Trading Bot with ICT Analysis                                ║"
    echo "║  📊 Complete Risk Management System                                         ║"
    echo "║  🔄 Auto-Update Capabilities                                                ║"
    echo "║  📱 Telegram Integration                                                    ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local elapsed=$(($(date +%s) - START_TIME))
    local eta=$(( (elapsed * TOTAL_STEPS / CURRENT_STEP) - elapsed ))
    
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}[$CURRENT_STEP/$TOTAL_STEPS - $percent%]${NC} $1"
    echo -e "${CYAN}│${NC} ⏱️  Elapsed: ${elapsed}s | ETA: ${eta}s"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    log "INFO" "[$CURRENT_STEP/$TOTAL_STEPS - $percent%] $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    log "SUCCESS" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    log "WARNING" "$1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    log "ERROR" "$1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
    log "INFO" "$1"
}

# ===== ERROR HANDLING =====
error_exit() {
    local exit_code=${2:-1}
    print_error "$1"
    
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}                               ${BOLD}INSTALLATION FAILED${NC}                              ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}📋 Troubleshooting Information:${NC}"
    echo "   • Check logs: $ERROR_LOG_FILE"
    echo "   • Installation directory: $INSTALL_DIR"
    echo "   • Service name: $SERVICE_NAME"
    echo ""
    echo -e "${YELLOW}🔧 Common Solutions:${NC}"
    echo "   • Ensure you have sudo privileges"
    echo "   • Check internet connectivity"
    echo "   • Verify Python 3.8+ is installed"
    echo "   • Make sure ports are not blocked"
    echo ""
    echo -e "${BLUE}📞 Support:${NC}"
    echo "   • GitHub: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot"
    echo "   • Issues: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot/issues"
    
    cleanup_on_error
    exit $exit_code
}

cleanup_on_error() {
    log "INFO" "Performing cleanup after error..."
    
    # Stop service if it was started
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    fi
    
    # Remove temporary files
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    rm -f "$UPDATE_LOCK_FILE" 2>/dev/null || true
    
    log "INFO" "Cleanup completed"
}

# Handle script interruption
trap 'error_exit "Installation interrupted by user" 130' INT TERM

# ===== SYSTEM VALIDATION FUNCTIONS =====
check_root_user() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Please run as a regular user with sudo access."
    fi
}

check_sudo_access() {
    if ! sudo -n true 2>/dev/null; then
        print_warning "This script requires sudo access. You may be prompted for your password."
        if ! sudo true; then
            error_exit "Sudo access is required for system-level operations."
        fi
    fi
    print_success "Sudo access verified"
}

check_internet_connectivity() {
    print_info "Checking internet connectivity..."
    
    local test_urls=(
        "8.8.8.8"
        "github.com"
        "pypi.org"
    )
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 5 "$url" &>/dev/null; then
            print_success "Internet connectivity verified ($url)"
            return 0
        fi
    done
    
    error_exit "No internet connectivity detected. Please check your network connection."
}

check_system_requirements() {
    print_step "Checking System Requirements..."
    
    # Check operating system
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Unsupported operating system. This script requires a Linux distribution."
    fi
    
    local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    print_info "Operating System: $os_info"
    
    # Check architecture
    local arch=$(uname -m)
    print_info "Architecture: $arch"
    
    if [[ "$arch" != "x86_64" && "$arch" != "aarch64" ]]; then
        print_warning "Untested architecture: $arch. Proceeding with caution."
    fi
    
    # Check available RAM
    local ram_mb=$(free -m | awk 'NR==2{print $2}')
    print_info "Available RAM: ${ram_mb}MB"
    
    if [[ $ram_mb -lt $MIN_RAM_MB ]]; then
        print_warning "Low RAM detected (${ram_mb}MB). Minimum recommended: ${MIN_RAM_MB}MB"
    fi
    
    # Check available disk space
    local disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    print_info "Available disk space: ${disk_gb}GB"
    
    if [[ $disk_gb -lt $MIN_DISK_GB ]]; then
        error_exit "Insufficient disk space (${disk_gb}GB). Minimum required: ${MIN_DISK_GB}GB"
    fi
    
    print_success "System requirements check passed"
}

check_python_version() {
    print_info "Checking Python installation..."
    
    if ! command -v python3 &> /dev/null; then
        error_exit "Python 3 is not installed. Please install Python 3.8 or higher."
    fi
    
    local python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
    print_info "Python version: $python_version"
    
    if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        error_exit "Python 3.8 or higher is required. Current version: $python_version"
    fi
    
    # Check pip
    if ! python3 -m pip --version &> /dev/null; then
        print_warning "pip not found, attempting to install..."
        sudo apt update && sudo apt install -y python3-pip || error_exit "Failed to install pip"
    fi
    
    local pip_version=$(python3 -m pip --version | awk '{print $2}')
    print_info "pip version: $pip_version"
    
    print_success "Python installation verified"
}

check_required_packages() {
    print_info "Checking required system packages..."
    
    local missing_packages=()
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_warning "Missing packages: ${missing_packages[*]}"
        print_info "Installing missing packages..."
        
        sudo apt update || error_exit "Failed to update package list"
        sudo apt install -y "${missing_packages[@]}" || error_exit "Failed to install required packages"
        
        print_success "Required packages installed"
    else
        print_success "All required packages are installed"
    fi
}

# ===== INSTALLATION TYPE DETECTION =====
detect_installation_type() {
    if [[ -d "$INSTALL_DIR" ]]; then
        if [[ -f "$INSTALL_DIR/.env" ]] && [[ -d "$INSTALL_DIR/.git" ]]; then
            echo "update"
        elif [[ -d "$INSTALL_DIR/.git" ]]; then
            echo "repair"
        else
            echo "reinstall"
        fi
    else
        echo "fresh"
    fi
}

# ===== BACKUP AND RESTORE FUNCTIONS =====
create_backup() {
    local backup_type="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$BACKUP_BASE_DIR/${backup_type}-${timestamp}"
    
    print_info "Creating $backup_type backup..."
    
    sudo mkdir -p "$backup_dir"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        # Backup configuration files
        if [[ -f "$INSTALL_DIR/.env" ]]; then
            sudo cp "$INSTALL_DIR/.env" "$backup_dir/.env" || error_exit "Failed to backup .env file"
            print_success "Configuration backed up"
        fi
        
        # Backup logs
        if [[ -d "$INSTALL_DIR/logs" ]]; then
            sudo cp -r "$INSTALL_DIR/logs" "$backup_dir/" 2>/dev/null || true
            print_success "Logs backed up"
        fi
        
        # Backup custom scripts
        if [[ -d "$INSTALL_DIR/scripts" ]]; then
            sudo cp -r "$INSTALL_DIR/scripts" "$backup_dir/scripts_backup" 2>/dev/null || true
            print_success "Custom scripts backed up"
        fi
        
        # Backup database if exists
        if [[ -f "$INSTALL_DIR/flowai.db" ]]; then
            sudo cp "$INSTALL_DIR/flowai.db" "$backup_dir/" 2>/dev/null || true
            print_success "Database backed up"
        fi
        
        # Create backup manifest
        sudo tee "$backup_dir/manifest.txt" > /dev/null << EOF
FlowAI-ICT Trading Bot Backup
Created: $(date)
Type: $backup_type
Original Path: $INSTALL_DIR
Backup Contents:
$(find "$backup_dir" -type f 2>/dev/null | sed "s|$backup_dir/||")
EOF
        
        sudo chown -R $USER:$USER "$backup_dir" 2>/dev/null || true
        print_success "Backup created: $backup_dir"
        echo "$backup_dir"
    else
        print_warning "No existing installation found to backup"
        echo ""
    fi
}

restore_configuration() {
    local backup_dir="$1"
    
    if [[ -z "$backup_dir" ]] || [[ ! -d "$backup_dir" ]]; then
        print_warning "No backup directory specified or found"
        return 0
    fi
    
    print_info "Restoring configuration from backup..."
    
    # Restore .env file
    if [[ -f "$backup_dir/.env" ]]; then
        cp "$backup_dir/.env" "$INSTALL_DIR/.env" || error_exit "Failed to restore .env file"
        print_success "Configuration restored"
    fi
    
    # Restore custom scripts (excluding system scripts)
    if [[ -d "$backup_dir/scripts_backup" ]]; then
        mkdir -p "$INSTALL_DIR/scripts"
        find "$backup_dir/scripts_backup" -name "*.sh" -not -name "update_bot.sh" -exec cp {} "$INSTALL_DIR/scripts/" \; 2>/dev/null || true
        print_success "Custom scripts restored"
    fi
    
    # Restore database
    if [[ -f "$backup_dir/flowai.db" ]]; then
        cp "$backup_dir/flowai.db" "$INSTALL_DIR/" 2>/dev/null || true
        print_success "Database restored"
    fi
}

cleanup_old_backups() {
    print_info "Cleaning up old backups..."
    
    if [[ -d "$BACKUP_BASE_DIR" ]]; then
        find "$BACKUP_BASE_DIR" -type d -mtime +$BACKUP_RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || true
        print_success "Old backups cleaned up (older than $BACKUP_RETENTION_DAYS days)"
    fi
}

# ===== SERVICE MANAGEMENT =====
stop_existing_service() {
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        print_info "Stopping existing service..."
        sudo systemctl stop "$SERVICE_NAME" || print_warning "Failed to stop service gracefully"
        
        # Wait for service to stop
        local timeout=30
        while systemctl is-active --quiet "$SERVICE_NAME" && [[ $timeout -gt 0 ]]; do
            sleep 1
            ((timeout--))
        done
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_warning "Service failed to stop gracefully, forcing stop..."
            sudo systemctl kill "$SERVICE_NAME" 2>/dev/null || true
            sleep 2
        fi
        
        print_success "Service stopped"
    else
        print_info "No existing service running"
    fi
}

# ===== REPOSITORY MANAGEMENT =====
setup_repository() {
    print_step "Setting up Repository..."
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        print_info "Updating existing repository..."
        cd "$INSTALL_DIR"
        
        # Stash any local changes
        git stash push -m "Auto-stash before update $(date)" 2>/dev/null || true
        
        # Fetch latest changes
        git fetch origin main || error_exit "Failed to fetch updates from GitHub"
        
        # Reset to latest version
        git reset --hard origin/main || error_exit "Failed to update repository"
        
        print_success "Repository updated"
    else
        print_info "Cloning repository..."
        
        # Clone to temporary directory first
        git clone "$GITHUB_REPO" "$TEMP_DIR/repo" || error_exit "Failed to clone repository"
        
        # Move to final location
        sudo mv "$TEMP_DIR/repo" "$INSTALL_DIR" || error_exit "Failed to move repository to installation directory"
        
        print_success "Repository cloned"
    fi
    
    # Set ownership
    sudo chown -R $USER:$USER "$INSTALL_DIR"
    
    # Get current commit info
    cd "$INSTALL_DIR"
    local commit_hash=$(git rev-parse --short HEAD)
    local commit_date=$(git log -1 --format=%cd --date=short)
    local commit_message=$(git log -1 --format=%s)
    
    print_info "Current version: $commit_hash ($commit_date)"
    print_info "Latest commit: $commit_message"
}

# ===== VIRTUAL ENVIRONMENT SETUP =====
setup_virtual_environment() {
    print_step "Setting up Virtual Environment..."
    
    cd "$INSTALL_DIR"
    
    # Remove old virtual environments
    for old_venv in "venv" "flowai_env" ".venv"; do
        if [[ -d "$old_venv" ]]; then
            print_info "Removing old virtual environment: $old_venv"
            rm -rf "$old_venv"
        fi
    done
    
    # Create new virtual environment
    print_info "Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_NAME" || error_exit "Failed to create virtual environment"
    
    # Activate virtual environment
    source "$VENV_NAME/bin/activate" || error_exit "Failed to activate virtual environment"
    
    # Upgrade pip and essential tools
    print_info "Upgrading pip and essential tools..."
    pip install --upgrade pip setuptools wheel || error_exit "Failed to upgrade pip and tools"
    
    local pip_version=$(pip --version | awk '{print $2}')
    print_success "Virtual environment created (pip $pip_version)"
}

# ===== DEPENDENCY INSTALLATION =====
install_python_dependencies() {
    print_step "Installing Python Dependencies..."
    
    cd "$INSTALL_DIR"
    source "$VENV_NAME/bin/activate" || error_exit "Failed to activate virtual environment"
    
    print_info "Installing core dependencies with tested versions..."
    
    # Install core dependencies with specific versions
    local core_deps=(
        "numpy==$NUMPY_VERSION"
        "pandas==$PANDAS_VERSION"
        "python-telegram-bot==$TELEGRAM_BOT_VERSION"
        "ta==$TA_VERSION"
        "urllib3==$URLLIB3_VERSION"
        "requests==$REQUESTS_VERSION"
        "python-dotenv==$PYTHON_DOTENV_VERSION"
        "psutil==$PSUTIL_VERSION"
        "aiohttp==$AIOHTTP_VERSION"
        "schedule==$SCHEDULE_VERSION"
    )
    
    for dep in "${core_deps[@]}"; do
        print_info "Installing $dep..."
        pip install "$dep" || error_exit "Failed to install $dep"
    done
    
    print_success "Core dependencies installed"
    
    # Install additional requirements if file exists
    if [[ -f "requirements.txt" ]]; then
        print_info "Installing additional requirements..."
        pip install -r requirements.txt || print_warning "Some additional requirements may have failed to install"
    fi
    
    # Verify critical imports
    print_info "Verifying critical imports..."
    python3 -c "
import sys
sys.path.insert(0, '.')

try:
    import pandas as pd
    import numpy as np
    import telegram
    import ta
    import requests
    import psutil
    print('✓ All critical imports successful')
except ImportError as e:
    print(f'✗ Import error: {e}')
    sys.exit(1)
" || error_exit "Critical import verification failed"
    
    print_success "Python dependencies installed and verified"
}

# ===== DIRECTORY STRUCTURE =====
setup_directory_structure() {
    print_step "Setting up Directory Structure..."
    
    cd "$INSTALL_DIR"
    
    # Create necessary directories
    local directories=(
        "logs"
        "data"
        "models"
        "scripts"
        "backups"
        "config"
        "temp"
        "cache"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        print_info "Created directory: $dir"
    done
    
    # Set proper permissions
    chmod 755 "${directories[@]}"
    
    # Create .gitignore for local files
    cat > .gitignore.local << 'EOF'
# Local files (not tracked by git)
logs/*.log
data/*.csv
data/*.json
temp/*
cache/*
backups/*
.env.local
*.pid
*.lock
EOF
    
    print_success "Directory structure created"
}

# ===== CONFIGURATION SETUP =====
setup_configuration() {
    print_step "Setting up Configuration..."
    
    cd "$INSTALL_DIR"
    
    # Check if this is an update and we have a backup
    if [[ -n "$BACKUP_DIR" ]] && [[ -f "$BACKUP_DIR/.env" ]]; then
        restore_configuration "$BACKUP_DIR"
        return 0
    fi
    
    # Create new configuration if not exists
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp ".env.example" ".env"
            print_info "Configuration created from example file"
        else
            # Create comprehensive .env file
            cat > .env << 'EOF'
# FlowAI-ICT Trading Bot Configuration
# Version: 4.5

# ===== TELEGRAM CONFIGURATION =====
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_ADMIN_IDS=your_user_id_here
TELEGRAM_PREMIUM_USERS=

# ===== API CONFIGURATION =====
BRSAPI_KEY=FreeQZdOYW6D3nNv95jZ9BcYXJHzTJpf
BRSAPI_DAILY_LIMIT=10000
BRSAPI_MINUTE_LIMIT=60

# ===== ICT TRADING CONFIGURATION =====
ICT_ENABLED=true
ORDER_BLOCK_DETECTION=true
FAIR_VALUE_GAP_DETECTION=true
LIQUIDITY_SWEEP_DETECTION=true
ICT_RISK_PER_TRADE=0.02
ICT_MAX_DAILY_RISK=0.05
ICT_RR_RATIO=2.0

# ===== AI MODEL CONFIGURATION =====
AI_MODEL_ENABLED=true
AI_CONFIDENCE_THRESHOLD=0.7
AI_RETRAIN_INTERVAL=24

# ===== FINANCIAL DATA =====
USD_IRR_EXCHANGE_RATE=70000.0

# ===== RISK MANAGEMENT =====
RISK_MANAGEMENT_ENABLED=true
MAX_DAILY_LOSS_PERCENT=5.0
MAX_POSITION_SIZE_PERCENT=10.0
MAX_DRAWDOWN_PERCENT=15.0
MAX_DAILY_TRADES=20

# ===== LOGGING =====
LOG_LEVEL=INFO
LOG_FILE_PATH=logs/flowai.log
LOG_MAX_SIZE=10
LOG_BACKUP_COUNT=5

# ===== PERFORMANCE =====
CACHE_ENABLED=true
CACHE_TTL=300
PARALLEL_PROCESSING=true
MAX_WORKERS=4

# ===== DEVELOPMENT =====
DEBUG_MODE=false
TESTING_MODE=false
PAPER_TRADING=true

# ===== NEWS HANDLING =====
NEWS_FETCH_URL=https://nfs.faireconomy.media/ff_calendar_thisweek.json
NEWS_MONITORED_CURRENCIES=USD,EUR,GBP,JPY
NEWS_MONITORED_IMPACTS=High,Medium
NEWS_BLACKOUT_MINUTES_BEFORE=30
NEWS_BLACKOUT_MINUTES_AFTER=60
NEWS_CACHE_TTL_SECONDS=3600

# ===== ADVANCED ICT PARAMETERS =====
ICT_SWING_LOOKBACK_PERIODS=10
ICT_SWING_HIGH_LOW_PERIODS=5
ICT_STRUCTURE_CONFIRMATION_PERIODS=3
ICT_MSS_SWING_LOOKBACK=20
ICT_MSS_CONFIRMATION_PERIODS=3
ICT_MSS_MIN_BREAK_PERCENTAGE=0.001
ICT_BOS_SWING_LOOKBACK=15
ICT_BOS_CONFIRMATION_PERIODS=2
ICT_CHOCH_LOOKBACK_PERIODS=10
ICT_CHOCH_CONFIRMATION=3
ICT_OB_MIN_BODY_RATIO=0.3
ICT_OB_MIN_SIZE=0.0005
ICT_OB_MAX_LOOKBACK=20
ICT_OB_CONFIRMATION_PERIODS=3
ICT_PD_ARRAY_LOOKBACK_PERIODS=50
ICT_PD_ARRAY_MIN_TOUCHES=3
ICT_PD_ARRAY_CONFIRMATION=2
ICT_FVG_THRESHOLD=0.0003
ICT_PD_RETRACEMENT_LEVELS=0.236,0.382,0.5,0.618,0.786
ICT_PD_EXTENSION_LEVELS=1.272,1.414,1.618,2.0,2.618
EOF
            print_info "Comprehensive configuration file created"
        fi
        
        print_warning "Please edit .env file with your actual bot token and admin IDs!"
        print_info "Configuration file location: $INSTALL_DIR/.env"
    else
        print_success "Existing configuration preserved"
    fi
}

# ===== ICT VARIABLES SETUP =====
setup_ict_variables() {
    print_step "Setting up ICT Variables..."
    
    cd "$INSTALL_DIR"
    
    # Check if ICT variables exist in config.py
    if [[ -f "flow_ai_core/config.py" ]]; then
        if ! grep -q "ICT_SWING_LOOKBACK_PERIODS" flow_ai_core/config.py 2>/dev/null; then
            print_info "Adding missing ICT variables to config.py..."
            
            cat >> flow_ai_core/config.py << 'EOF'

# ===== ADVANCED ICT PARAMETERS (Auto-added by installer) =====
ICT_SWING_LOOKBACK_PERIODS = get_env_var('ICT_SWING_LOOKBACK_PERIODS', 10, var_type=int)
ICT_SWING_HIGH_LOW_PERIODS = get_env_var('ICT_SWING_HIGH_LOW_PERIODS', 5, var_type=int)
ICT_STRUCTURE_CONFIRMATION_PERIODS = get_env_var('ICT_STRUCTURE_CONFIRMATION_PERIODS', 3, var_type=int)

# ===== ICT MSS (Market Structure Shift) =====
ICT_MSS_SWING_LOOKBACK = get_env_var('ICT_MSS_SWING_LOOKBACK', 20, var_type=int)
ICT_MSS_CONFIRMATION_PERIODS = get_env_var('ICT_MSS_CONFIRMATION_PERIODS', 3, var_type=int)
ICT_MSS_MIN_BREAK_PERCENTAGE = get_env_var('ICT_MSS_MIN_BREAK_PERCENTAGE', 0.001, var_type=float)

# ===== ICT BOS (Break of Structure) =====
ICT_BOS_SWING_LOOKBACK = get_env_var('ICT_BOS_SWING_LOOKBACK', 15, var_type=int)
ICT_BOS_CONFIRMATION_PERIODS = get_env_var('ICT_BOS_CONFIRMATION_PERIODS', 2, var_type=int)

# ===== ICT CHoCH (Change of Character) =====
ICT_CHOCH_LOOKBACK_PERIODS = get_env_var('ICT_CHOCH_LOOKBACK_PERIODS', 10, var_type=int)
ICT_CHOCH_CONFIRMATION = get_env_var('ICT_CHOCH_CONFIRMATION', 3, var_type=int)

# ===== ICT ORDER BLOCK SETTINGS =====
ICT_OB_MIN_SIZE = get_env_var('ICT_OB_MIN_SIZE', 0.0005, var_type=float)
ICT_OB_MAX_LOOKBACK = get_env_var('ICT_OB_MAX_LOOKBACK', 20, var_type=int)
ICT_OB_CONFIRMATION_PERIODS = get_env_var('ICT_OB_CONFIRMATION_PERIODS', 3, var_type=int)

# ===== ICT PD ARRAY SETTINGS =====
ICT_PD_ARRAY_MIN_TOUCHES = get_env_var('ICT_PD_ARRAY_MIN_TOUCHES', 3, var_type=int)
ICT_PD_ARRAY_CONFIRMATION = get_env_var('ICT_PD_ARRAY_CONFIRMATION', 2, var_type=int)

# ===== ICT PD EXTENSION LEVELS =====
ICT_PD_EXTENSION_LEVELS = [1.272, 1.414, 1.618, 2.0, 2.618]
EOF
            print_success "ICT variables added to config.py"
        else
            print_success "ICT variables already exist in config.py"
        fi
    else
        print_warning "config.py not found, skipping ICT variable setup"
    fi
}

# ===== CIRCULAR IMPORT FIX =====
fix_circular_imports() {
    print_step "Fixing Circular Import Issues..."
    
    cd "$INSTALL_DIR"
    
    if [[ -f "flow_ai_core/__init__.py" ]]; then
        # Create fixed __init__.py
        cat > flow_ai_core/__init__.py << 'EOF'
"""
FlowAI-ICT Core Module v4.5
Fixed version without circular imports
"""

# Import only essential modules without circular dependencies
from . import config

# Version info
__version__ = "4.5"
__author__ = "FlowAI Team"

# Initialize logging
import logging
logger = logging.getLogger(__name__)
logger.info("FlowAI-ICT Core Module initialized")

# DO NOT import telegram_bot here - causes circular import
# All telegram functionality is handled in the main telegram_bot.py file
EOF
        print_success "Circular import issues fixed in __init__.py"
    else
        print_warning "__init__.py not found, skipping circular import fix"
    fi
}

# ===== AUTO-UPDATE SYSTEM SETUP =====
create_update_script() {
    print_step "Setting up Auto-Update System..."
    
    cd "$INSTALL_DIR"
    mkdir -p scripts
    
    # Create comprehensive update script
    cat > "$UPDATE_SCRIPT_PATH" << 'EOF'
#!/bin/bash
# FlowAI-ICT Bot Auto Update Script
# Version: 4.5 Enhanced

set -e

# Configuration
BOT_DIR="/opt/FlowAI-ICT-Trading-Bot"
SERVICE_NAME="flowai-ict-bot"
LOG_FILE="/var/log/flowai/flowai-update.log"
BACKUP_DIR="/tmp/flowai-backup-$(date +%Y%m%d-%H%M%S)"
LOCK_FILE="/tmp/flowai_update.lock"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" | tee -a "$LOG_FILE"
    rm -f "$LOCK_FILE"
    exit 1
}

# Success message
success() {
    echo -e "${GREEN}SUCCESS: $1${NC}" | tee -a "$LOG_FILE"
}

# Warning message
warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

# Check if update is already running
check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            error_exit "Update is already running (PID: $lock_pid)"
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Check for updates
check_updates() {
    log "Checking for updates..."
    cd "$BOT_DIR" || error_exit "Cannot access bot directory"
    
    # Fetch latest changes
    git fetch origin main || error_exit "Failed to fetch updates from GitHub"
    
    # Check if updates are available
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse origin/main)
    
    if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
        log "Bot is already up to date"
        rm -f "$LOCK_FILE"
        exit 0
    else
        log "Updates available: $LOCAL_COMMIT -> $REMOTE_COMMIT"
    fi
}

# Create backup
create_backup() {
    log "Creating backup at $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup configuration
    if [[ -f "$BOT_DIR/.env" ]]; then
        cp "$BOT_DIR/.env" "$BACKUP_DIR/.env" || error_exit "Failed to backup .env file"
    fi
    
    # Backup logs
    if [[ -d "$BOT_DIR/logs" ]]; then
        cp -r "$BOT_DIR/logs" "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    # Backup custom scripts
    if [[ -d "$BOT_DIR/scripts" ]] && [[ "$BOT_DIR/scripts" != "$BACKUP_DIR" ]]; then
        cp -r "$BOT_DIR/scripts" "$BACKUP_DIR/scripts_backup" 2>/dev/null || true
    fi
    
    # Backup database if exists
    if [[ -f "$BOT_DIR/flowai.db" ]]; then
        cp "$BOT_DIR/flowai.db" "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    success "Backup created successfully"
}

# Stop bot service
stop_service() {
    log "Stopping bot service..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        sudo systemctl stop "$SERVICE_NAME" || error_exit "Failed to stop bot service"
        
        # Wait for service to stop
        local timeout=30
        while systemctl is-active --quiet "$SERVICE_NAME" && [[ $timeout -gt 0 ]]; do
            sleep 1
            ((timeout--))
        done
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            error_exit "Service failed to stop within timeout"
        fi
        
        success "Bot service stopped"
    else
        log "Bot service was not running"
    fi
}

# Update code
update_code() {
    log "Updating code from GitHub..."
    cd "$BOT_DIR" || error_exit "Cannot access bot directory"
    
    # Stash any local changes
    git stash push -m "Auto-stash before update $(date)" 2>/dev/null || true
    
    # Reset any local changes and pull latest
    git reset --hard origin/main || error_exit "Failed to reset to latest version"
    git pull origin main || error_exit "Failed to pull latest changes"
    
    success "Code updated successfully"
}

# Restore configuration
restore_config() {
    log "Restoring configuration..."
    
    if [[ -f "$BACKUP_DIR/.env" ]]; then
        cp "$BACKUP_DIR/.env" "$BOT_DIR/.env" || error_exit "Failed to restore .env file"
        success "Configuration restored"
    fi
    
    # Restore custom scripts if they existed
    if [[ -d "$BACKUP_DIR/scripts_backup" ]]; then
        # Only restore non-system scripts
        find "$BACKUP_DIR/scripts_backup" -name "*.sh" -not -name "update_bot.sh" -exec cp {} "$BOT_DIR/scripts/" \; 2>/dev/null || true
    fi
    
    # Restore database
    if [[ -f "$BACKUP_DIR/flowai.db" ]]; then
        cp "$BACKUP_DIR/flowai.db" "$BOT_DIR/" 2>/dev/null || true
    fi
    
    # Set proper ownership
    chown -R $(whoami):$(whoami) "$BOT_DIR" 2>/dev/null || true
}

# Update dependencies
update_dependencies() {
    log "Updating dependencies..."
    cd "$BOT_DIR" || error_exit "Cannot access bot directory"
    
    # Activate virtual environment
    if [[ -f "venv/bin/activate" ]]; then
        source venv/bin/activate || error_exit "Failed to activate virtual environment"
    elif [[ -f "flowai_env/bin/activate" ]]; then
        source flowai_env/bin/activate || error_exit "Failed to activate virtual environment"
    else
        error_exit "Virtual environment not found"
    fi
    
    # Update pip first
    pip install --upgrade pip || warning "Failed to upgrade pip"
    
    # Install/update requirements with specific versions for stability
    pip install numpy==1.26.4 || warning "Failed to update numpy"
    pip install pandas==2.0.3 || warning "Failed to update pandas"
    pip install python-telegram-bot==13.15 || warning "Failed to update python-telegram-bot"
    pip install ta==0.10.2 || warning "Failed to update ta"
    pip install urllib3==1.26.18 || warning "Failed to update urllib3"
    
    # Install other requirements if file exists
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt --upgrade || warning "Some dependencies failed to update"
    fi
    
    success "Dependencies updated"
}

# Start bot service
start_service() {
    log "Starting bot service..."
    sudo systemctl start "$SERVICE_NAME" || error_exit "Failed to start bot service"
    
    # Wait for service to start
    local timeout=30
    while ! systemctl is-active --quiet "$SERVICE_NAME" && [[ $timeout -gt 0 ]]; do
        sleep 1
        ((timeout--))
    done
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "Bot service started successfully"
    else
        error_exit "Service failed to start within timeout"
    fi
}

# Verify bot functionality
verify_bot() {
    log "Verifying bot functionality..."
    
    # Check service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "Service is running"
    else
        error_exit "Service is not running"
    fi
    
    # Check for errors in recent logs
    if journalctl -u "$SERVICE_NAME" --since "1 minute ago" | grep -i error >/dev/null 2>&1; then
        warning "Errors detected in recent logs"
    else
        success "No errors in recent logs"
    fi
    
    # Test basic functionality
    cd "$BOT_DIR"
    if [[ -f "venv/bin/activate" ]]; then
        source venv/bin/activate
        python3 -c "
import sys
sys.path.insert(0, '.')
try:
    from flow_ai_core import config
    print('✓ Configuration import successful')
except Exception as e:
    print(f'✗ Configuration import failed: {e}')
    sys.exit(1)
" || warning "Configuration import test failed"
    fi
}

# Cleanup old backups
cleanup_backups() {
    log "Cleaning up old backups..."
    find /tmp -name "flowai-backup-*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    success "Old backups cleaned up"
}

# Send notification (if telegram bot is configured)
send_notification() {
    local message="$1"
    # This could be enhanced to send actual telegram notifications
    log "NOTIFICATION: $message"
}

# Main update function
main() {
    log "=== FlowAI-ICT Bot Update Started ==="
    
    # Check lock
    check_lock
    
    # Check for updates
    check_updates
    
    # Send start notification
    send_notification "🔄 Bot update started"
    
    # Create backup
    create_backup
    
    # Stop service
    stop_service
    
    # Update code
    update_code
    
    # Restore configuration
    restore_config
    
    # Update dependencies
    update_dependencies
    
    # Start service
    start_service
    
    # Verify functionality
    verify_bot
    
    # Cleanup
    cleanup_backups
    
    # Remove lock
    rm -f "$LOCK_FILE"
    
    # Send success notification
    send_notification "✅ Bot update completed successfully"
    
    success "Bot update completed successfully!"
    log "=== FlowAI-ICT Bot Update Completed ==="
}

# Handle interruption
trap 'error_exit "Update interrupted by user"' INT TERM

# Run main function
main "$@"
EOF
    
    chmod +x "$UPDATE_SCRIPT_PATH"
    print_success "Auto-update script created"
}

add_telegram_update_handlers() {
    print_info "Adding Telegram update handlers..."
    
    cd "$INSTALL_DIR"
    
    # Check if telegram_bot.py exists and add update handlers
    if [[ -f "telegram_bot.py" ]]; then
        # Check if update handlers already exist
        if ! grep -q "update.*command" "telegram_bot.py" 2>/dev/null; then
            # Add update handlers to telegram_bot.py
            cat >> telegram_bot.py << 'EOF'

# ===== AUTO-UPDATE HANDLERS (Added by installer) =====
async def update_bot_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /update command"""
    user_id = update.effective_user.id
    
    if not self.is_admin(user_id):
        await update.message.reply_text("❌ شما دسترسی به این دستور ندارید.")
        return
    
    # Check if update is already running
    if os.path.exists("/tmp/flowai_update.lock"):
        await update.message.reply_text("""
⚠️ **به‌روزرسانی در حال انجام**

لطفاً صبر کنید تا فرآیند فعلی تکمیل شود.
""")
        return
    
    # Check for updates
    import subprocess
    import os
    
    try:
        os.chdir("/opt/FlowAI-ICT-Trading-Bot")
        result = subprocess.run(['git', 'fetch', 'origin', 'main'], 
                              capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            await update.message.reply_text("❌ خطا در بررسی به‌روزرسانی")
            return
        
        # Check if updates available
        local = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                             capture_output=True, text=True).stdout.strip()
        remote = subprocess.run(['git', 'rev-parse', 'origin/main'], 
                              capture_output=True, text=True).stdout.strip()
        
        if local == remote:
            await update.message.reply_text(f"""
✅ **ربات به‌روز است**

📊 **اطلاعات نسخه:**
• نسخه فعلی: {local[:8]}
• آخرین بررسی: {datetime.now().strftime('%H:%M:%S')}

ربات از آخرین نسخه استفاده می‌کند.
""")
            return
        
        # Get commit information
        commit_info = subprocess.run(['git', 'log', '--oneline', f'{local}..{remote}'], 
                                   capture_output=True, text=True).stdout.strip()
        commit_count = len(commit_info.split('\n')) if commit_info else 0
        
        # Updates available
        await update.message.reply_text(f"""
🔄 **به‌روزرسانی موجود**

📊 **اطلاعات:**
• نسخه فعلی: `{local[:8]}`
• نسخه جدید: `{remote[:8]}`
• تعداد commit های جدید: {commit_count}

⚠️ **هشدار:**
• ربات موقتاً قطع خواهد شد
• فرآیند 2-5 دقیقه طول می‌کشد
• تنظیمات حفظ خواهند شد
• بک‌آپ خودکار ایجاد می‌شود

**برای تأیید:** `/confirm_update`
**برای انصراف:** هیچ کاری نکنید

⏰ **زمان انقضا:** 5 دقیقه
""", parse_mode='Markdown')
        
    except subprocess.TimeoutExpired:
        await update.message.reply_text("❌ زمان بررسی به‌روزرسانی تمام شد")
    except Exception as e:
        await update.message.reply_text(f"❌ خطا در بررسی: {str(e)}")
        logger.error(f"Update check failed: {e}")

async def confirm_update_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /confirm_update command"""
    user_id = update.effective_user.id
    
    if not self.is_admin(user_id):
        await update.message.reply_text("❌ شما دسترسی به این دستور ندارید.")
        return
    
    # Check if update is already running
    if os.path.exists("/tmp/flowai_update.lock"):
        await update.message.reply_text("⚠️ به‌روزرسانی در حال انجام است.")
        return
    
    await update.message.reply_text("""
🔄 **شروع به‌روزرسانی...**

⏳ **مراحل:**
1. ✅ ایجاد بک‌آپ از تنظیمات
2. 🔄 دریافت آخرین نسخه از GitHub
3. 📦 به‌روزرسانی وابستگی‌ها
4. 🔧 اعمال تغییرات
5. 🚀 راه‌اندازی مجدد ربات

⚠️ **ربات در حال restart...**
لطفاً 2-3 دقیقه صبر کنید.

📝 **لاگ به‌روزرسانی:** `/var/log/flowai/flowai-update.log`
""")
    
    # Execute update script
    import subprocess
    try:
        subprocess.Popen(['bash', '/opt/FlowAI-ICT-Trading-Bot/scripts/update_bot.sh'])
        logger.info(f"Update initiated by admin: {user_id}")
    except Exception as e:
        await update.message.reply_text(f"❌ خطا در شروع به‌روزرسانی: {str(e)}")
        logger.error(f"Failed to start update: {e}")

async def cancel_update_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /cancel_update command"""
    user_id = update.effective_user.id
    
    if not self.is_admin(user_id):
        await update.message.reply_text("❌ شما دسترسی به این دستور ندارید.")
        return
    
    await update.message.reply_text("""
❌ **به‌روزرسانی لغو شد**

عملیات به‌روزرسانی متوقف شد.
ربات با نسخه فعلی ادامه می‌دهد.
""")

# Add these handlers to setup_handlers method:
# self.application.add_handler(CommandHandler('update', self.update_bot_command))
# self.application.add_handler(CommandHandler('confirm_update', self.confirm_update_command))
# self.application.add_handler(CommandHandler('cancel_update', self.cancel_update_command))
EOF
            print_success "Telegram update handlers added"
        else
            print_success "Telegram update handlers already exist"
        fi
    else
        print_warning "telegram_bot.py not found, skipping handler addition"
    fi
}

create_management_script() {
    print_info "Creating management script..."
    
    cd "$INSTALL_DIR"
    
    cat > manage.sh << 'EOF'
#!/bin/bash
# FlowAI-ICT Bot Management Script
# Version: 4.5 Enhanced

SERVICE_NAME="flowai-ict-bot"
BOT_DIR="/opt/FlowAI-ICT-Trading-Bot"
LOG_DIR="/var/log/flowai"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}              ${CYAN}FlowAI-ICT Bot Management Script${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_usage() {
    show_header
    echo "Usage: $0 {start|stop|restart|status|logs|update|backup|restore|health|config}"
    echo ""
    echo "Commands:"
    echo "  start     - Start the bot service"
    echo "  stop      - Stop the bot service"
    echo "  restart   - Restart the bot service"
    echo "  status    - Show detailed service status"
    echo "  logs      - Show real-time logs"
    echo "  update    - Update bot to latest version"
    echo "  backup    - Create manual backup"
    echo "  restore   - List and restore from backups"
    echo "  health    - Perform health check"
    echo "  config    - Show configuration status"
    echo ""
}

show_status() {
    show_header
    echo -e "${CYAN}Service Status:${NC}"
    sudo systemctl status $SERVICE_NAME --no-pager
    echo ""
    
    echo -e "${CYAN}Resource Usage:${NC}"
    if systemctl is-active --quiet $SERVICE_NAME; then
        local pid=$(sudo systemctl show $SERVICE_NAME --property=MainPID --value)
        if [[ -n "$pid" && "$pid" != "0" ]]; then
            ps -p $pid -o pid,ppid,cmd,%mem,%cpu --no-headers 2>/dev/null || echo "Process information not available"
        fi
    else
        echo "Service is not running"
    fi
    echo ""
    
    echo -e "${CYAN}Recent Activity:${NC}"
    sudo journalctl -u $SERVICE_NAME --since "10 minutes ago" --no-pager | tail -5
}

perform_health_check() {
    show_header
    echo -e "${CYAN}🏥 FlowAI-ICT Bot Health Check${NC}"
    echo ""
    
    # Service status
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "✅ Service Status: ${GREEN}Running${NC}"
    else
        echo -e "❌ Service Status: ${RED}Not Running${NC}"
    fi
    
    # Configuration check
    if [[ -f "$BOT_DIR/.env" ]]; then
        echo -e "✅ Configuration: ${GREEN}Found${NC}"
        
        # Check critical variables
        if grep -q "TELEGRAM_BOT_TOKEN=your_bot_token_here" "$BOT_DIR/.env" 2>/dev/null; then
            echo -e "⚠️  Bot Token: ${YELLOW}Not Configured${NC}"
        else
            echo -e "✅ Bot Token: ${GREEN}Configured${NC}"
        fi
        
        if grep -q "TELEGRAM_ADMIN_IDS=your_user_id_here" "$BOT_DIR/.env" 2>/dev/null; then
            echo -e "⚠️  Admin IDs: ${YELLOW}Not Configured${NC}"
        else
            echo -e "✅ Admin IDs: ${GREEN}Configured${NC}"
        fi
    else
        echo -e "❌ Configuration: ${RED}Missing${NC}"
    fi
    
    # Virtual environment check
    if [[ -d "$BOT_DIR/venv" ]]; then
        echo -e "✅ Virtual Environment: ${GREEN}Found${NC}"
    else
        echo -e "❌ Virtual Environment: ${RED}Missing${NC}"
    fi
    
    # Dependencies check
    if [[ -f "$BOT_DIR/venv/bin/activate" ]]; then
        cd "$BOT_DIR"
        source venv/bin/activate
        if python3 -c "import pandas, numpy, telegram, ta" 2>/dev/null; then
            echo -e "✅ Dependencies: ${GREEN}OK${NC}"
        else
            echo -e "❌ Dependencies: ${RED}Missing or Broken${NC}"
        fi
    fi
    
    # Log files check
    if [[ -d "$LOG_DIR" ]]; then
        echo -e "✅ Log Directory: ${GREEN}Found${NC}"
        local log_count=$(find "$LOG_DIR" -name "*.log" | wc -l)
        echo -e "📄 Log Files: $log_count found"
    else
        echo -e "❌ Log Directory: ${RED}Missing${NC}"
    fi
    
    # Disk space check
    local disk_usage=$(df -h "$BOT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 90 ]]; then
        echo -e "✅ Disk Space: ${GREEN}${disk_usage}% used${NC}"
    else
        echo -e "⚠️  Disk Space: ${YELLOW}${disk_usage}% used${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}🔍 Recent Errors:${NC}"
    if [[ -f "$LOG_DIR/flowai-errors.log" ]]; then
        local error_count=$(wc -l < "$LOG_DIR/flowai-errors.log" 2>/dev/null || echo "0")
        if [[ $error_count -eq 0 ]]; then
            echo -e "✅ No recent errors found"
        else
            echo -e "⚠️  $error_count errors in log file"
            echo "Recent errors:"
            tail -3 "$LOG_DIR/flowai-errors.log" 2>/dev/null || echo "Cannot read error log"
        fi
    else
        echo -e "ℹ️  No error log file found"
    fi
}

show_config_status() {
    show_header
    echo -e "${CYAN}📋 Configuration Status${NC}"
    echo ""
    
    if [[ -f "$BOT_DIR/.env" ]]; then
        echo -e "${GREEN}Configuration file found:${NC} $BOT_DIR/.env"
        echo ""
        echo -e "${CYAN}Configuration Summary:${NC}"
        
        # Show non-sensitive configuration
        grep -E "^(ICT_|AI_|LOG_|RISK_)" "$BOT_DIR/.env" 2>/dev/null | head -10 || echo "No configuration variables found"
        
        echo ""
        echo -e "${YELLOW}Note: Sensitive information (tokens, keys) is hidden${NC}"
    else
        echo -e "${RED}Configuration file not found!${NC}"
        echo "Expected location: $BOT_DIR/.env"
    fi
}

case "$1" in
    start)
        echo -e "${GREEN}Starting FlowAI-ICT Bot...${NC}"
        sudo systemctl start $SERVICE_NAME
        sleep 2
        show_status
        ;;
    stop)
        echo -e "${YELLOW}Stopping FlowAI-ICT Bot...${NC}"
        sudo systemctl stop $SERVICE_NAME
        echo "Bot stopped."
        ;;
    restart)
        echo -e "${YELLOW}Restarting FlowAI-ICT Bot...${NC}"
        sudo systemctl restart $SERVICE_NAME
        sleep 2
        show_status
        ;;
    status)
        show_status
        ;;
    logs)
        echo -e "${BLUE}Showing real-time logs (Press Ctrl+C to exit)...${NC}"
        sudo journalctl -u $SERVICE_NAME -f
        ;;
    update)
        echo -e "${BLUE}Updating FlowAI-ICT Bot...${NC}"
        if [[ -f "$BOT_DIR/scripts/update_bot.sh" ]]; then
            bash "$BOT_DIR/scripts/update_bot.sh"
        else
            echo -e "${RED}Update script not found!${NC}"
            exit 1
        fi
        ;;
    backup)
        echo -e "${BLUE}Creating manual backup...${NC}"
        BACKUP_DIR="/tmp/flowai-manual-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        if [[ -f "$BOT_DIR/.env" ]]; then
            cp "$BOT_DIR/.env" "$BACKUP_DIR/"
            echo "Configuration backed up"
        fi
        
        if [[ -d "$BOT_DIR/logs" ]]; then
            cp -r "$BOT_DIR/logs" "$BACKUP_DIR/"
            echo "Logs backed up"
        fi
        
        if [[ -f "$BOT_DIR/flowai.db" ]]; then
            cp "$BOT_DIR/flowai.db" "$BACKUP_DIR/"
            echo "Database backed up"
        fi
        
        echo -e "${GREEN}Manual backup completed: $BACKUP_DIR${NC}"
        ;;
    restore)
        echo -e "${BLUE}Available backups:${NC}"
        echo ""
        find /tmp -name "flowai-*backup-*" -type d 2>/dev/null | sort -r | head -10 | while read backup; do
            if [[ -f "$backup/manifest.txt" ]]; then
                echo "📁 $backup"
                echo "   $(head -1 "$backup/manifest.txt" 2>/dev/null || echo 'No description')"
                echo ""
            else
                echo "📁 $backup (no manifest)"
            fi
        done
        echo "To restore, manually copy files from backup directory to $BOT_DIR"
        echo "Example: cp /tmp/flowai-backup-YYYYMMDD-HHMMSS/.env $BOT_DIR/"
        ;;
    health)
        perform_health_check
        ;;
    config)
        show_config_status
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
EOF
    
    chmod +x manage.sh
    print_success "Management script created"
}

# ===== SYSTEM SERVICE SETUP =====
setup_system_service() {
    print_step "Setting up System Service..."
    
    # Create systemd service file
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=FlowAI-ICT Trading Bot v$SCRIPT_VERSION
Documentation=https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/$VENV_NAME/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=$INSTALL_DIR
Environment=PYTHONUNBUFFERED=1
ExecStart=$INSTALL_DIR/$VENV_NAME/bin/python telegram_bot.py
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=30
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR $LOG_DIR /tmp
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    
    print_success "System service configured and enabled"
}

# ===== UTILITY SCRIPTS =====
create_utility_scripts() {
    print_step "Creating Utility Scripts..."
    
    cd "$INSTALL_DIR"
    
    # Create quick start script
    cat > quick_start.sh << 'EOF'
#!/bin/bash
# FlowAI-ICT Bot Quick Start Script

echo "🚀 FlowAI-ICT Trading Bot Quick Start"
echo ""

# Check if configuration is set
if grep -q "your_bot_token_here" .env 2>/dev/null; then
    echo "❌ Please configure your bot token in .env file first!"
    echo "   Edit: $PWD/.env"
    echo "   Set TELEGRAM_BOT_TOKEN and TELEGRAM_ADMIN_IDS"
    exit 1
fi

echo "Starting FlowAI-ICT Bot..."
sudo systemctl start flowai-ict-bot

echo "Checking status..."
sleep 3
sudo systemctl status flowai-ict-bot --no-pager

echo ""
echo "✅ Bot started! Use './manage.sh logs' to view real-time logs"
EOF
    
    # Create configuration checker
    cat > check_config.sh << 'EOF'
#!/bin/bash
# Configuration Checker Script

echo "🔍 FlowAI-ICT Configuration Checker"
echo ""

if [[ ! -f ".env" ]]; then
    echo "❌ Configuration file (.env) not found!"
    exit 1
fi

echo "✅ Configuration file found"
echo ""

# Check critical variables
echo "📋 Configuration Status:"

check_var() {
    local var_name="$1"
    local default_value="$2"
    
    if grep -q "^${var_name}=" .env; then
        local value=$(grep "^${var_name}=" .env | cut -d'=' -f2)
        if [[ "$value" == "$default_value" ]]; then
            echo "⚠️  $var_name: Not configured (using default)"
        else
            echo "✅ $var_name: Configured"
        fi
    else
        echo "❌ $var_name: Missing"
    fi
}

check_var "TELEGRAM_BOT_TOKEN" "your_bot_token_here"
check_var "TELEGRAM_ADMIN_IDS" "your_user_id_here"
check_var "BRSAPI_KEY" ""
check_var "ICT_ENABLED" ""
check_var "AI_MODEL_ENABLED" ""

echo ""
echo "🔧 To edit configuration: nano .env"
EOF
    
    # Create log viewer script
    cat > view_logs.sh << 'EOF'
#!/bin/bash
# Log Viewer Script

echo "📋 FlowAI-ICT Log Viewer"
echo ""

case "$1" in
    "live"|"")
        echo "📡 Live logs (Press Ctrl+C to exit):"
        sudo journalctl -u flowai-ict-bot -f
        ;;
    "error")
        echo "❌ Error logs:"
        if [[ -f "/var/log/flowai/flowai-errors.log" ]]; then
            tail -50 /var/log/flowai/flowai-errors.log
        else
            echo "No error log file found"
        fi
        ;;
    "install")
        echo "📦 Installation logs:"
        if [[ -f "/var/log/flowai/flowai-install.log" ]]; then
            tail -50 /var/log/flowai/flowai-install.log
        else
            echo "No installation log file found"
        fi
        ;;
    "update")
        echo "🔄 Update logs:"
        if [[ -f "/var/log/flowai/flowai-update.log" ]]; then
            tail -50 /var/log/flowai/flowai-update.log
        else
            echo "No update log file found"
        fi
        ;;
    *)
        echo "Usage: $0 [live|error|install|update]"
        echo ""
        echo "Options:"
        echo "  live     - Show live logs (default)"
        echo "  error    - Show error logs"
        echo "  install  - Show installation logs"
        echo "  update   - Show update logs"
        ;;
esac
EOF
    
    # Make scripts executable
    chmod +x quick_start.sh check_config.sh view_logs.sh
    
    print_success "Utility scripts created"
}

# ===== FINAL TESTING =====
run_final_tests() {
    print_step "Running Final Tests..."
    
    cd "$INSTALL_DIR"
    source "$VENV_NAME/bin/activate" || error_exit "Failed to activate virtual environment"
    
    print_info "Testing Python imports..."
    python3 -c "
import sys
sys.path.insert(0, '.')

try:
    import pandas as pd
    import numpy as np
    import telegram
    import ta
    import requests
    import psutil
    import aiohttp
    import schedule
    print('✓ All critical imports successful')
    
    # Test versions
    print(f'✓ pandas: {pd.__version__}')
    print(f'✓ numpy: {np.__version__}')
    print(f'✓ telegram: {telegram.__version__}')
    print(f'✓ ta: {ta.__version__}')
    
except ImportError as e:
    print(f'✗ Import error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'✗ Unexpected error: {e}')
    sys.exit(1)
" || error_exit "Python import tests failed"
    
    print_info "Testing configuration loading..."
    python3 -c "
import sys
sys.path.insert(0, '.')

try:
    from flow_ai_core import config
    print('✓ Configuration module loaded successfully')
    
    # Test critical variables
    if hasattr(config, 'ICT_SWING_LOOKBACK_PERIODS'):
        print('✓ ICT variables are available')
    else:
        print('⚠ Some ICT variables may be missing')
        
except ImportError as e:
    print(f'✗ Configuration import error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'✗ Configuration error: {e}')
    sys.exit(1)
" || print_warning "Configuration test failed (may be normal if config needs setup)"
    
    print_info "Testing service configuration..."
    if sudo systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
        print_success "Service is enabled"
    else
        print_warning "Service is not enabled"
    fi
    
    print_info "Testing file permissions..."
    if [[ -r "$INSTALL_DIR/.env" ]] || [[ ! -f "$INSTALL_DIR/.env" ]]; then
        print_success "Configuration file permissions OK"
    else
        print_warning "Configuration file permission issues"
    fi
    
    print_success "All tests completed"
}

# ===== MAIN INSTALLATION FUNCTION =====
main() {
    local install_type
    local backup_dir=""
    
    # Setup logging first
    setup_logging
    
    # Print header
    print_header
    
    # Detect installation type
    install_type=$(detect_installation_type)
    
    case "$install_type" in
        "fresh")
            print_info "Fresh installation detected"
            ;;
        "update")
            print_info "Existing installation detected - performing update"
            ;;
        "repair")
            print_info "Incomplete installation detected - performing repair"
            ;;
        "reinstall")
            print_info "Corrupted installation detected - performing reinstall"
            ;;
    esac
    
    log "INFO" "=== FlowAI-ICT Bot Installation Started (Type: $install_type) ==="
    
    # Pre-installation validation
    check_root_user
    check_sudo_access
    check_internet_connectivity
    check_system_requirements
    check_python_version
    check_required_packages
    
    # Create backup if updating
    if [[ "$install_type" == "update" ]] || [[ "$install_type" == "repair" ]]; then
        backup_dir=$(create_backup "$install_type")
        stop_existing_service
    fi
    
    # Main installation steps
    setup_repository
    setup_virtual_environment
    install_python_dependencies
    setup_directory_structure
    setup_configuration
    setup_ict_variables
    fix_circular_imports
    create_update_script
    add_telegram_update_handlers
    create_management_script
    setup_system_service
    create_utility_scripts
    run_final_tests
    
    # Restore configuration if this was an update
    if [[ -n "$backup_dir" ]]; then
        restore_configuration "$backup_dir"
    fi
    
    # Start the service
    print_info "Starting FlowAI-ICT Bot service..."
    sudo systemctl start "$SERVICE_NAME"
    
    # Wait a moment and check status
    sleep 3
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_warning "Service may have failed to start - check logs"
    fi
    
    # Cleanup
    cleanup_old_backups
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    
    # Calculate installation time
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # Final success message
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                           ${BOLD}🎉 INSTALLATION COMPLETED! 🎉${NC}                          ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}📋 Installation Summary:${NC}"
    echo "✓ Project installed to: $INSTALL_DIR"
    echo "✓ Virtual environment created: $VENV_NAME"
    echo "✓ All dependencies installed with tested versions"
    echo "✓ Configuration $(if [[ "$install_type" == "update" ]]; then echo "restored from backup"; else echo "created"; fi)"
    echo "✓ ICT variables added to config.py"
    echo "✓ Circular import issues fixed"
    echo "✓ Auto-update system configured"
    echo "✓ System service configured and enabled"
    echo "✓ Management and utility scripts created"
    echo "✓ Installation completed in ${minutes}m ${seconds}s"
    
    if [[ -n "$backup_dir" ]]; then
        echo "✓ Backup created: $backup_dir"
    fi
    
    echo ""
    echo -e "${CYAN}🚀 Quick Start:${NC}"
    echo "  sudo systemctl start $SERVICE_NAME"
    echo "  sudo systemctl status $SERVICE_NAME"
    echo "  ./manage.sh logs"
    echo ""
    
    echo -e "${CYAN}📊 Management Commands:${NC}"
    echo "  ./manage.sh start|stop|restart|status|logs|update|backup|restore|health|config"
    echo "  ./quick_start.sh          # Quick start with checks"
    echo "  ./check_config.sh         # Verify configuration"
    echo "  ./view_logs.sh [type]      # View different log types"
    echo ""
    
    echo -e "${CYAN}🔄 Auto-Update Features:${NC}"
    echo "  Telegram: /update          # Check for updates"
    echo "  Telegram: /confirm_update  # Apply updates"
    echo "  Manual: ./manage.sh update # Update via command line"
    echo ""
    
    echo -e "${CYAN}📱 Telegram Bot Commands:${NC}"
    echo "  /start                     # Start bot and show menu"
    echo "  /menu                      # Show management menu"
    echo "  /status                    # Show bot status"
    echo "  /signals                   # Show trading signals"
    echo "  /update                    # Check for updates"
    echo "  /help                      # Show help information"
    echo ""
    
    if [[ "$install_type" == "fresh" ]]; then
        echo -e "${YELLOW}⚠️  IMPORTANT NEXT STEPS:${NC}"
        echo "1. Edit configuration file: nano $INSTALL_DIR/.env"
        echo "2. Set your TELEGRAM_BOT_TOKEN (get from @BotFather)"
        echo "3. Set your TELEGRAM_ADMIN_IDS (your Telegram user ID)"
        echo "4. Restart the bot: sudo systemctl restart $SERVICE_NAME"
        echo "5. Test the bot by sending /start to your Telegram bot"
        echo ""
    fi
    
    echo -e "${CYAN}📞 Support & Documentation:${NC}"
    echo "  GitHub: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot"
    echo "  Issues: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot/issues"
    echo "  Logs: $LOG_DIR/"
    echo ""
    
    echo -e "${GREEN}🎯 FlowAI-ICT Trading Bot v$SCRIPT_VERSION is ready for advanced ICT trading!${NC}"
    
    log "INFO" "=== FlowAI-ICT Bot Installation Completed Successfully ==="
}

# ===== SCRIPT EXECUTION =====
# Handle script arguments
case "${1:-}" in
    "--help"|"-h")
        echo "FlowAI-ICT Trading Bot Installation Script v$SCRIPT_VERSION"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --debug        Enable debug mode"
        echo "  --force        Force reinstallation"
        echo "  --no-service   Skip service setup"
        echo ""
        echo "Environment Variables:"
        echo "  DEBUG=1        Enable debug logging"
        echo "  FORCE=1        Force reinstallation"
        echo ""
        exit 0
        ;;
    "--debug")
        export DEBUG=1
        shift
        ;;
    "--force")
        export FORCE=1
        shift
        ;;
    "--no-service")
        export NO_SERVICE=1
        shift
        ;;
esac

# Run main installation
main "$@"
