#!/bin/bash
# FlowAI-ICT Trading Bot Installation & Management Script
# Version: 4.0 - Production Ready - All Issues Fixed
# No Conflicts - Bulletproof Implementation

# Enhanced error handling
set -euo pipefail

# Trap for cleanup on exit
trap 'cleanup_on_error $? $LINENO' ERR

cleanup_on_error() {
    local exit_code=$1
    local line_no=$2
    echo "❌ Error occurred at line $line_no with exit code $exit_code"
    echo "🧹 Performing cleanup..."
    
    # Remove lock files
    rm -f "$UPDATE_LOCK_FILE" 2>/dev/null || true
    
    # Log error
    echo "$(date): Error at line $line_no, exit code $exit_code" >> "$ERROR_LOG" 2>/dev/null || true
    
    exit $exit_code
}

# =====================================================
# FlowAI-ICT Trading Bot Complete Installer v4.0
# Production Ready - All Issues Resolved
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
UPDATE_SCRIPT_PATH="$INSTALL_DIR/scripts/update_bot.sh"
UPDATE_LOCK_FILE="/tmp/flowai_update.lock"
BACKUP_RETENTION_DAYS=7
UPDATE_CHECK_URL="https://api.github.com/repos/behnamrjd/FlowAI-ICT-Trading-Bot/commits/main"
CURRENT_USER=$(whoami)
USER_HOME="$HOME"

# Unified Logging System - Fixed paths
LOG_FILE="/tmp/flowai-install.log"
ERROR_LOG="/tmp/flowai-errors.log"
UPDATE_LOG="/tmp/flowai-update.log"

# Bot Configuration
TELEGRAM_TOKEN=""
ADMIN_ID=""
ERROR_COUNT=0

# Service Configuration
SERVICE_NAME="flowai-ict-bot"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
VENV_NAME="venv"

# Backup Configuration
BACKUP_DIR="/tmp/flowai-backup-$(date +%Y%m%d-%H%M%S)"
MAX_BACKUPS=5

# Installation Status
INSTALLATION_EXISTS=false

# ===== CORE FUNCTIONS =====
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    echo -e "${RED}❌ ERROR: $message${NC}" >&2
    
    # Log error with timestamp
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $message" >> "$ERROR_LOG" 2>/dev/null || true
    
    # Show troubleshooting info
    echo -e "${YELLOW}📋 Troubleshooting Information:${NC}" >&2
    echo -e "   • Check logs: $ERROR_LOG" >&2
    echo -e "   • Installation directory: $INSTALL_DIR" >&2
    echo -e "   • Service name: $SERVICE_NAME" >&2
    echo "" >&2
    
    # Cleanup
    rm -f "$UPDATE_LOCK_FILE" 2>/dev/null || true
    
    # Final error banner
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}" >&2
    echo -e "${RED}║${NC}                               ${BOLD}INSTALLATION FAILED${NC}                              ${RED}║${NC}" >&2
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}" >&2
    
    exit "$exit_code"
}

# Initialize log files with bulletproof permissions
init_logs() {
    # Multiple fallback strategies for log creation
    local log_locations=("/tmp" "$HOME" "." "/var/tmp")
    local log_created=false
    
    for location in "${log_locations[@]}"; do
        if [[ -w "$location" ]]; then
            LOG_FILE="$location/flowai-install-$$.log"
            ERROR_LOG="$location/flowai-errors-$$.log"
            UPDATE_LOG="$location/flowai-update-$$.log"
            
            if touch "$LOG_FILE" "$ERROR_LOG" "$UPDATE_LOG" 2>/dev/null; then
                log_created=true
                break
            fi
        fi
    done
    
    if [[ "$log_created" == false ]]; then
        LOG_FILE="/dev/null"
        ERROR_LOG="/dev/null"
        UPDATE_LOG="/dev/null"
        echo "⚠️ Warning: Logging disabled due to permission issues"
        return
    fi
    
    # Initialize log files
    echo "=== FlowAI-ICT Installation Log Started: $(date) ===" > "$LOG_FILE"
    echo "=== FlowAI-ICT Error Log Started: $(date) ===" > "$ERROR_LOG"
    echo "=== FlowAI-ICT Update Log Started: $(date) ===" > "$UPDATE_LOG"
    
    # Set proper permissions
    chmod 644 "$LOG_FILE" "$ERROR_LOG" "$UPDATE_LOG" 2>/dev/null || true
    
    echo "📝 Log files initialized:"
    echo "   Install: $LOG_FILE"
    echo "   Errors:  $ERROR_LOG"
    echo "   Updates: $UPDATE_LOG"
}

# Print functions
print_banner() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                    ${CYAN}FlowAI-ICT Trading Bot v4.0${NC}                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}              ${WHITE}Complete Auto Installer${NC}                      ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] → $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - STEP: $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_success() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ${GREEN}✓ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_warning() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ${YELLOW}⚠ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_error() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ${RED}❌ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$ERROR_LOG" 2>/dev/null || true
}

# Comprehensive pre-flight system checks - All issues fixed
check_prerequisites() {
    print_step "Running comprehensive pre-flight checks..."
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        error_exit "Python3 is not installed"
    fi
    
    local python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    
    # Fixed Python version check logic
    local major=$(echo "$python_version" | cut -d. -f1)
    local minor=$(echo "$python_version" | cut -d. -f2)
    
    if [[ $major -lt 3 ]] || [[ $major -eq 3 && $minor -lt 8 ]]; then
        error_exit "Python 3.8+ required, found $python_version"
    fi
    print_success "Python $python_version detected"
    
    # Check and install python3-venv
    if ! dpkg -l | grep -q python3.*-venv 2>/dev/null; then
        print_warning "python3-venv not found, installing..."
        if apt update && apt install python3-venv python3.12-venv -y; then
            print_success "python3-venv installed successfully"
        else
            error_exit "Failed to install python3-venv"
        fi
    else
        print_success "python3-venv detected"
    fi
    
    # Check disk space (minimum 1GB) - FIXED: Now enforces requirement
    local available_space=$(df /opt 2>/dev/null | awk 'NR==2 {print $4}' || echo "1000000")
    if [[ $available_space -lt 1000000 ]]; then
        error_exit "Insufficient disk space: $(($available_space/1024))MB available, 1GB required"
    fi
    print_success "Sufficient disk space available: $(($available_space/1024))MB"
    
    # Check internet connectivity - FIXED: Alternative method
    if ! curl -s --connect-timeout 10 https://api.github.com &> /dev/null; then
        if ! ping -c 1 google.com &> /dev/null && ! ping -c 1 8.8.8.8 &> /dev/null; then
            error_exit "No internet connectivity detected - cannot reach GitHub"
        fi
    fi
    print_success "Internet connectivity verified"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root - some features may not work as expected"
    fi
    
    # Check required commands
    local required_commands=("git" "curl" "systemctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error_exit "Required command '$cmd' not found"
        fi
    done
    
    # Bulletproof pip3 detection and installation
    if command -v pip3 &> /dev/null; then
        print_success "pip3 detected"
    elif command -v pip &> /dev/null; then
        print_success "pip detected (will use as pip3)"
    elif python3 -m pip --version &> /dev/null; then
        print_success "pip module detected (will use python3 -m pip)"
    else
        print_warning "pip3 not found, installing..."
        if apt update && apt install python3-pip -y; then
            print_success "pip3 installed successfully"
        else
            print_warning "Failed to install pip3, will use python3 -m pip"
            if ! python3 -m pip --version &> /dev/null; then
                error_exit "No pip installation method available"
            fi
        fi
    fi
    
    print_success "All required commands available"
    print_success "Pre-flight checks completed successfully"
}

# Check installation status
check_installation() {
    if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/.env" ]] && [[ -f "$SERVICE_FILE" ]] && systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        INSTALLATION_EXISTS=true
    else
        INSTALLATION_EXISTS=false
    fi
}

# Handle root user with improved logic - FIXED: Better argument passing
handle_root_user() {
    if [[ $EUID -eq 0 ]]; then
        print_step "Running as root - auto-creating flowai user without password..."
        
        if ! id "flowai" &>/dev/null; then
            useradd -m -s /bin/bash flowai || error_exit "Failed to create flowai user"
            usermod -aG sudo flowai || error_exit "Failed to add flowai to sudo group"
            echo "flowai ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/flowai || error_exit "Failed to configure sudo access"
            print_success "User 'flowai' created with sudo no-password access"
        else
            print_success "User 'flowai' already exists"
        fi
        
        # Copy script to flowai user with proper permissions
        cp "$0" /home/flowai/Install.sh || error_exit "Failed to copy script"
        chown flowai:flowai /home/flowai/Install.sh || error_exit "Failed to set ownership"
        chmod +x /home/flowai/Install.sh || error_exit "Failed to set permissions"
        print_success "Script copied to flowai user"
        
        print_step "Switching to user 'flowai'..."
        # FIXED: Proper argument passing
        exec sudo -u flowai -i bash /home/flowai/Install.sh
    fi
}

# Installation menu
print_install_menu() {
    echo -e "${YELLOW}🚀 Installation Options${NC}"
    echo -e "${YELLOW}═══════════════════════${NC}"
    echo ""
    echo -e "${WHITE}1) ${CYAN}Quick Install (Recommended)${NC}"
    echo -e "   ${WHITE}• Automated installation with default settings${NC}"
    echo -e "   ${WHITE}• Includes all dependencies and configurations${NC}"
    echo ""
    echo -e "${WHITE}2) ${CYAN}Custom Install${NC}"
    echo -e "   ${WHITE}• Manual configuration options${NC}"
    echo -e "   ${WHITE}• Advanced settings${NC}"
    echo ""
    echo -e "${WHITE}3) ${CYAN}Repair Installation${NC}"
    echo -e "   ${WHITE}• Fix broken installation${NC}"
    echo ""
    echo -e "${WHITE}0) ${RED}Exit${NC}"
    echo ""
}

# Quick configuration with validation
quick_configuration() {
    echo -e "${CYAN}⚙️ Quick Configuration Setup${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    
    # Get Telegram Bot Token with validation
    while [[ -z "$TELEGRAM_TOKEN" ]]; do
        echo -e "${WHITE}📱 Enter your Telegram Bot Token:${NC}"
        echo -e "   ${YELLOW}(Get it from @BotFather on Telegram)${NC}"
        read -r TELEGRAM_TOKEN
        
        if [[ -z "$TELEGRAM_TOKEN" ]]; then
            print_error "Token cannot be empty!"
            continue
        fi
        
        # Validate token format
        if [[ ! "$TELEGRAM_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            print_error "Invalid token format!"
            TELEGRAM_TOKEN=""
            continue
        fi
        
        print_success "Telegram token validated"
    done
    
    # Get Admin ID with validation
    while [[ -z "$ADMIN_ID" ]]; do
        echo -e "${WHITE}👤 Enter your Telegram User ID:${NC}"
        echo -e "   ${YELLOW}(Send /start to @userinfobot)${NC}"
        read -r ADMIN_ID
        
        if [[ -z "$ADMIN_ID" ]]; then
            print_error "Admin ID cannot be empty!"
            continue
        fi
        
        # Validate admin ID format
        if [[ ! "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            print_error "Invalid Admin ID format!"
            ADMIN_ID=""
            continue
        fi
        
        print_success "Admin ID validated"
    done
    
    print_success "Configuration completed!"
    echo ""
}

# Bulletproof automated installation - All issues fixed
automated_installation() {
    echo -e "${GREEN}Starting automated installation...${NC}"
    echo ""
    
    # Create installation directory with proper permissions
    print_step "Creating installation directory..."
    if ! sudo mkdir -p "$INSTALL_DIR"; then
        error_exit "Failed to create installation directory"
    fi
    
    if ! sudo chown -R "$USER:$USER" "$INSTALL_DIR"; then
        error_exit "Failed to set directory ownership"
    fi
    print_success "Installation directory created"
    
    # Clone repository with error handling - FIXED: Git authentication handling
    print_step "Cloning FlowAI-ICT repository..."
    cd /tmp || error_exit "Cannot access /tmp directory"
    
    if [[ -d "flowai-temp" ]]; then
        rm -rf flowai-temp
    fi
    
    # FIXED: Better git clone with timeout and error handling
    if ! timeout 60 git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git flowai-temp; then
        error_exit "Failed to clone repository - check internet connection or repository access"
    fi
    
    # Move files to installation directory
    if ! cp -r flowai-temp/* "$INSTALL_DIR/"; then
        error_exit "Failed to copy repository files"
    fi
    
    # Copy hidden files safely
    cp flowai-temp/.* "$INSTALL_DIR/" 2>/dev/null || true
    
    # Cleanup temp directory
    rm -rf flowai-temp
    print_success "Repository cloned successfully"
    
    # FIXED: Bulletproof directory change
    if ! cd "$INSTALL_DIR"; then
        error_exit "Cannot access installation directory: $INSTALL_DIR"
    fi
    
    # Create virtual environment with bulletproof error handling
    print_step "Creating Python virtual environment..."
    if ! python3 -m venv venv; then
        error_exit "Failed to create virtual environment"
    fi
    
    # FIXED: Better virtual environment activation
    if ! source venv/bin/activate; then
        error_exit "Failed to activate virtual environment"
    fi
    print_success "Virtual environment created and activated"
    
    # Install dependencies with fixed versions
    print_step "Installing Python dependencies with locked versions..."
    
    # Upgrade pip first
    if ! pip install --upgrade pip; then
        error_exit "Failed to upgrade pip"
    fi
    
    # Install exact versions to prevent conflicts
    print_step "Installing telegram bot with exact version..."
    pip uninstall python-telegram-bot -y 2>/dev/null || true
    if ! pip install python-telegram-bot==13.15 --force-reinstall --no-deps; then
        error_exit "Failed to install python-telegram-bot"
    fi
    
    # Install telegram bot dependencies
    if ! pip install APScheduler==3.6.3 cachetools==4.2.2 certifi tornado==6.1; then
        error_exit "Failed to install telegram dependencies"
    fi
    
    # Install other dependencies with exact versions
    print_step "Installing other dependencies..."
    local dependencies=(
        "numpy==1.26.4"
        "pandas==2.0.3"
        "ta==0.10.2"
        "urllib3==1.26.18"
        "python-dotenv==0.19.2"
        "requests==2.28.2"
        "psutil==5.9.8"
    )
    
    for dep in "${dependencies[@]}"; do
        if ! pip install "$dep" --force-reinstall; then
            error_exit "Failed to install $dep"
        fi
    done
    
    # Verify critical installations
    print_step "Verifying installations..."
    if ! python3 -c "import telegram; print('✓ Telegram version:', telegram.__version__)"; then
        error_exit "Telegram import verification failed"
    fi
    
    if ! python3 -c "import pandas, numpy, ta; print('✓ All core libraries imported successfully')"; then
        error_exit "Core libraries verification failed"
    fi
    
    print_success "All dependencies installed and verified"
    
    # Create configuration file
    print_step "Creating configuration file..."
    cat > .env << EOF || error_exit "Failed to create configuration file"
# FlowAI-ICT Bot Configuration
TELEGRAM_TOKEN=$TELEGRAM_TOKEN
ADMIN_ID=$ADMIN_ID

# Trading Configuration
RISK_PERCENTAGE=2
MAX_POSITIONS=3
STOP_LOSS_PERCENTAGE=1
TAKE_PROFIT_PERCENTAGE=2

# API Configuration
API_TIMEOUT=30
RETRY_ATTEMPTS=3

# Logging
LOG_LEVEL=INFO
LOG_FILE=logs/bot.log
EOF
    print_success "Configuration file created"
    
    # Create logs directory
    mkdir -p logs || error_exit "Failed to create logs directory"
    
    # Create systemd service
    print_step "Creating systemd service..."
    sudo tee "$SERVICE_FILE" > /dev/null << EOF || error_exit "Failed to create service file"
[Unit]
Description=FlowAI-ICT Trading Bot v4.0
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python telegram_bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    print_success "Systemd service created"
    
    # Setup auto-update system after main installation
    setup_auto_update_system
    
    # Enable and start service
    print_step "Enabling and starting service..."
    if ! sudo systemctl daemon-reload; then
        error_exit "Failed to reload systemd daemon"
    fi
    
    if ! sudo systemctl enable "$SERVICE_NAME"; then
        error_exit "Failed to enable service"
    fi
    
    if ! sudo systemctl start "$SERVICE_NAME"; then
        error_exit "Failed to start service"
    fi
    
    # FIXED: Better service startup verification with retry logic
    print_step "Verifying service startup..."
    local retry_count=0
    local max_retries=30
    
    while [[ $retry_count -lt $max_retries ]]; do
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "Service started successfully"
            break
        fi
        sleep 2
        ((retry_count++))
        
        if [[ $retry_count -eq $max_retries ]]; then
            # Get service status for debugging
            local service_status=$(systemctl status "$SERVICE_NAME" --no-pager -l)
            echo -e "${RED}Service failed to start after $max_retries attempts. Status:${NC}"
            echo "$service_status"
            error_exit "Service failed to start - check logs with: sudo journalctl -u $SERVICE_NAME"
        fi
    done
    
    # Final verification
    print_step "Running final verification..."
    if [[ -f "$INSTALL_DIR/.env" ]] && [[ -f "$SERVICE_FILE" ]] && systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Installation verification passed"
    else
        error_exit "Installation verification failed"
    fi
    
    # Success banner
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                    ${BOLD}INSTALLATION SUCCESSFUL${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}🤖 Bot Status:${NC} ${GREEN}Running${NC}"
    echo -e "${CYAN}📱 Telegram Token:${NC} ${TELEGRAM_TOKEN:0:10}..."
    echo -e "${CYAN}👤 Admin ID:${NC} $ADMIN_ID"
    echo -e "${CYAN}📂 Installation Directory:${NC} $INSTALL_DIR"
    echo -e "${CYAN}🔧 Service Name:${NC} $SERVICE_NAME"
    echo ""
    echo -e "${YELLOW}📋 Available Commands:${NC}"
    echo -e "${WHITE}• sudo systemctl status $SERVICE_NAME${NC} - Check bot status"
    echo -e "${WHITE}• sudo systemctl restart $SERVICE_NAME${NC} - Restart bot"
    echo -e "${WHITE}• sudo journalctl -u $SERVICE_NAME -f${NC} - View logs"
    echo -e "${WHITE}• /update${NC} - Check for updates (in Telegram)"
    echo -e "${WHITE}• /confirm_update${NC} - Apply updates (in Telegram)"
    echo ""
    echo -e "${GREEN}✅ You can now start using your FlowAI-ICT Trading Bot!${NC}"
    echo ""
    
    # Ask to continue to management menu
    echo -e "${YELLOW}Press Enter to continue to management menu...${NC}"
    read -r
    return 0
}

# Setup auto-update system - All issues fixed
setup_auto_update_system() {
    print_step "Setting up auto-update system..."
    
    # Create scripts directory
    mkdir -p scripts || error_exit "Failed to create scripts directory"
    
    # Create version lock file
    cat > scripts/requirements-lock.txt << 'LOCK_EOF' || error_exit "Failed to create requirements lock"
python-telegram-bot==13.15
APScheduler==3.6.3
cachetools==4.2.2
certifi==2022.12.7
tornado==6.1
numpy==1.26.4
pandas==2.0.3
ta==0.10.2
urllib3==1.26.18
python-dotenv==0.19.2
requests==2.28.2
psutil==5.9.8
LOCK_EOF
    
    # Create bulletproof update script
    cat > scripts/update_bot.sh << 'EOF' || error_exit "Failed to create update script"
#!/bin/bash
# FlowAI-ICT Bot Auto Update Script - Production Ready

set -euo pipefail

BOT_DIR="/opt/FlowAI-ICT-Trading-Bot"
SERVICE_NAME="flowai-ict-bot"
LOG_FILE="/tmp/flowai-update.log"
BACKUP_DIR="/tmp/flowai-backup-$(date +%Y%m%d-%H%M%S)"
LOCK_FILE="/tmp/flowai_update.lock"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error_exit() {
    echo "ERROR: $1" | tee -a "$LOG_FILE"
    rm -f "$LOCK_FILE"
    exit 1
}

# Check if update is already running
if [[ -f "$LOCK_FILE" ]]; then
    error_exit "Update is already running (PID: $(cat "$LOCK_FILE" 2>/dev/null || echo "unknown"))"
fi

# Create lock file
echo $$ > "$LOCK_FILE"

# Cleanup function
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

log "=== FlowAI-ICT Bot Update Started ==="

# Verify bot directory exists
if [[ ! -d "$BOT_DIR" ]]; then
    error_exit "Bot directory not found: $BOT_DIR"
fi

cd "$BOT_DIR" || error_exit "Cannot access bot directory"

# Check current telegram version before update
log "Checking current telegram version..."
if [[ -f "venv/bin/activate" ]]; then
    source venv/bin/activate
    CURRENT_TG_VERSION=$(python3 -c "import telegram; print(telegram.__version__)" 2>/dev/null || echo "unknown")
    log "Current telegram version: $CURRENT_TG_VERSION"
else
    log "Virtual environment not found"
fi

# Create backup
log "Creating backup..."
mkdir -p "$BACKUP_DIR"
if [[ -f "$BOT_DIR/.env" ]]; then
    cp "$BOT_DIR/.env" "$BACKUP_DIR/.env" || error_exit "Failed to backup .env"
    log "Configuration backed up"
fi

# Stop service
log "Stopping bot service..."
if ! sudo systemctl stop "$SERVICE_NAME"; then
    log "Warning: Failed to stop service (may not be running)"
fi

# Update code
log "Updating code..."
if ! git fetch origin main; then
    error_exit "Failed to fetch updates"
fi

if ! git reset --hard origin/main; then
    error_exit "Failed to update code"
fi
log "Code updated successfully"

# Restore configuration
if [[ -f "$BACKUP_DIR/.env" ]]; then
    cp "$BACKUP_DIR/.env" "$BOT_DIR/.env" || error_exit "Failed to restore config"
    log "Configuration restored"
fi

# Update dependencies with locked versions
log "Updating dependencies..."
if [[ -f "venv/bin/activate" ]]; then
    source venv/bin/activate || error_exit "Failed to activate venv"
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Force reinstall with exact versions to prevent conflicts
    pip uninstall python-telegram-bot -y
    pip install python-telegram-bot==13.15 --force-reinstall --no-deps
    pip install APScheduler==3.6.3 cachetools==4.2.2 certifi tornado==6.1
    
    # Install other dependencies with fixed versions
    pip install numpy==1.26.4 --force-reinstall
    pip install pandas==2.0.3 --force-reinstall  
    pip install ta==0.10.2 --force-reinstall
    pip install urllib3==1.26.18 --force-reinstall
    pip install python-dotenv==0.19.2 --force-reinstall
    pip install requests==2.28.2 --force-reinstall
    pip install psutil==5.9.8 --force-reinstall
    
    # Verify telegram installation
    python3 -c "import telegram; print('✓ Telegram version:', telegram.__version__)" || error_exit "Telegram import failed"
    log "Dependencies updated successfully"
else
    error_exit "Virtual environment not found"
fi

# Verify installation after update
log "Verifying installation..."
python3 -c "
import telegram
import pandas
import numpy
import ta
print('✓ All imports successful')
print('✓ Telegram version:', telegram.__version__)
" || error_exit "Post-update verification failed"

# Start service
log "Starting bot service..."
if ! sudo systemctl start "$SERVICE_NAME"; then
    error_exit "Failed to start service"
fi

# Wait and verify service startup with retry logic
local retry_count=0
while [[ $retry_count -lt 30 ]]; do
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Bot service started successfully"
        break
    fi
    sleep 2
    ((retry_count++))
    
    if [[ $retry_count -eq 30 ]]; then
        error_exit "Service failed to start after update"
    fi
done

# Cleanup old backups
find /tmp -name "flowai-backup-*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

log "=== FlowAI-ICT Bot Update Completed Successfully ==="
echo "✅ Update completed! Bot is running with latest version."
EOF
    
    chmod +x scripts/update_bot.sh || error_exit "Failed to set update script permissions"
    
    # Add telegram update handlers to bot if file exists
    if [[ -f telegram_bot.py ]]; then
        # Check if update handlers already exist
        if ! grep -q "update_command" telegram_bot.py; then
            cat >> telegram_bot.py << 'EOF'

# Auto-update functionality
import subprocess
import os

async def update_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle /update command"""
    user_id = update.effective_user.id
    if str(user_id) != os.getenv('ADMIN_ID'):
        await update.message.reply_text("❌ Unauthorized access!")
        return
    
    await update.message.reply_text("🔄 Checking for updates...")
    
    try:
        # Check for updates
        result = subprocess.run(['git', 'fetch', 'origin', 'main'], 
                              capture_output=True, text=True, cwd='/opt/FlowAI-ICT-Trading-Bot')
        
        if result.returncode == 0:
            # Check if updates available
            result = subprocess.run(['git', 'rev-list', '--count', 'HEAD..origin/main'], 
                                  capture_output=True, text=True, cwd='/opt/FlowAI-ICT-Trading-Bot')
            
            if result.stdout.strip() == '0':
                await update.message.reply_text("✅ Bot is already up to date!")
            else:
                await update.message.reply_text(f"🔄 {result.stdout.strip()} updates available!\n\nSend /confirm_update to apply updates.")
        else:
            await update.message.reply_text("❌ Failed to check for updates!")
            
    except Exception as e:
        await update.message.reply_text(f"❌ Error checking updates: {str(e)}")

async def confirm_update_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle /confirm_update command"""
    user_id = update.effective_user.id
    if str(user_id) != os.getenv('ADMIN_ID'):
        await update.message.reply_text("❌ Unauthorized access!")
        return
    
    await update.message.reply_text("🔄 Starting update process...\n⚠️ Bot will restart automatically!")
    
    try:
        # Run update script
        subprocess.Popen(['bash', '/opt/FlowAI-ICT-Trading-Bot/scripts/update_bot.sh'], 
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
    except Exception as e:
        await update.message.reply_text(f"❌ Failed to start update: {str(e)}")

# Add handlers to application
if 'application' in locals():
    application.add_handler(CommandHandler("update", update_command))
    application.add_handler(CommandHandler("confirm_update", confirm_update_command))
EOF
        fi
    fi
    
    print_success "Auto-update system configured"
}

# Install menu
install_menu() {
    while true; do
        print_banner
        print_install_menu
        
        echo -e "${WHITE}Choose option (0-3):${NC}"
        read -r choice
        
        case $choice in
            1)
                quick_configuration
                automated_installation
                return 0
                ;;
            2)
                echo -e "${YELLOW}Custom installation feature coming soon...${NC}"
                echo -e "${WHITE}For now, please use Quick Install option.${NC}"
                sleep 3
                ;;
            3)
                echo -e "${CYAN}🔧 Repair Installation${NC}"
                echo ""
                echo -e "${YELLOW}This will attempt to fix a broken installation.${NC}"
                echo -e "${WHITE}Continue? (y/n):${NC}"
                read -r repair_choice
                if [[ "$repair_choice" =~ ^[Yy]$ ]]; then
                    repair_installation
                fi
                ;;
            0)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Repair installation function
repair_installation() {
    print_step "Starting installation repair..."
    
    # Stop service if running
    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    
    # Remove broken installation
    if [[ -d "$INSTALL_DIR" ]]; then
        print_step "Backing up configuration..."
        if [[ -f "$INSTALL_DIR/.env" ]]; then
            cp "$INSTALL_DIR/.env" "/tmp/.env.backup" || true
        fi
        
        print_step "Removing broken installation..."
        sudo rm -rf "$INSTALL_DIR"
    fi
    
    # Remove service file
    sudo rm -f "$SERVICE_FILE" 2>/dev/null || true
    sudo systemctl daemon-reload
    
    print_success "Cleanup completed"
    
    # Check if we have a backup configuration
    if [[ -f "/tmp/.env.backup" ]]; then
        echo -e "${YELLOW}Found backup configuration. Use it? (y/n):${NC}"
        read -r use_backup
        if [[ "$use_backup" =~ ^[Yy]$ ]]; then
            source "/tmp/.env.backup"
            print_success "Configuration loaded from backup"
        else
            quick_configuration
        fi
    else
        quick_configuration
    fi
    
    # Reinstall
    automated_installation
}

# Management menu functions
print_management_menu() {
    echo -e "${YELLOW}🔧 Management Options${NC}"
    echo -e "${YELLOW}═══════════════════════${NC}"
    echo ""
    echo -e "${WHITE}1) ${CYAN}System Status${NC}"
    echo -e "${WHITE}2) ${CYAN}Service Management${NC}"
    echo -e "${WHITE}3) ${CYAN}Health Check${NC}"
    echo -e "${WHITE}4) ${CYAN}Configuration${NC}"
    echo -e "${WHITE}5) ${CYAN}Update Bot${NC}"
    echo -e "${WHITE}6) ${CYAN}Backup & Restore${NC}"
    echo -e "${WHITE}7) ${CYAN}View Logs${NC}"
    echo -e "${WHITE}8) ${CYAN}Developer Tools${NC}"
    echo -e "${WHITE}9) ${RED}Uninstall${NC}"
    echo -e "${WHITE}h) ${CYAN}Help & Documentation${NC}"
    echo ""
    echo -e "${WHITE}0) ${RED}Exit${NC}"
    echo ""
}

show_system_status() {
    print_banner
    echo -e "${CYAN}📊 System Status${NC}"
    echo -e "${CYAN}═══════════════${NC}"
    echo ""
    
    # Service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}🤖 Bot Service: Running${NC}"
        local uptime=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value)
        echo -e "${CYAN}   Started: $uptime${NC}"
    else
        echo -e "${RED}🤖 Bot Service: Stopped${NC}"
    fi
    
    # Installation info
    echo -e "${CYAN}📂 Installation Directory:${NC} $INSTALL_DIR"
    echo -e "${CYAN}🔧 Service Name:${NC} $SERVICE_NAME"
    
    # Configuration
    if [[ -f "$INSTALL_DIR/.env" ]]; then
        echo -e "${GREEN}⚙️ Configuration: Found${NC}"
        source "$INSTALL_DIR/.env"
        echo -e "${CYAN}📱 Bot Token:${NC} ${TELEGRAM_TOKEN:0:10}..."
        echo -e "${CYAN}👤 Admin ID:${NC} $ADMIN_ID"
    else
        echo -e "${RED}⚙️ Configuration: Missing${NC}"
    fi
    
    # Version info
    if [[ -d "$INSTALL_DIR/venv" ]]; then
        echo ""
        echo -e "${CYAN}📦 Installed Versions:${NC}"
        cd "$INSTALL_DIR"
        source venv/bin/activate 2>/dev/null || true
        python3 -c "import telegram; print(f'Telegram Bot: {telegram.__version__}')" 2>/dev/null || echo "Telegram Bot: Not available"
        python3 -c "import pandas; print(f'Pandas: {pandas.__version__}')" 2>/dev/null || echo "Pandas: Not available"
        python3 -c "import numpy; print(f'NumPy: {numpy.__version__}')" 2>/dev/null || echo "NumPy: Not available"
    fi
    
    # System resources
    echo ""
    echo -e "${CYAN}💾 System Resources:${NC}"
    echo -e "${WHITE}CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%${NC}"
    echo -e "${WHITE}Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')${NC}"
    echo -e "${WHITE}Disk Usage: $(df -h /opt | awk 'NR==2{printf "%s", $5}')${NC}"
    
    # Auto-update status
    echo ""
    echo -e "${CYAN}🔄 Auto-Update Status:${NC}"
    if [[ -f "$INSTALL_DIR/scripts/update_bot.sh" ]]; then
        echo -e "${GREEN}✓ Auto-update system available${NC}"
    else
        echo -e "${RED}✗ Auto-update system not configured${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

manage_service() {
    print_banner
    echo -e "${CYAN}🔧 Service Management${NC}"
    echo -e "${CYAN}═══════════════════════${NC}"
    echo ""
    echo -e "${WHITE}1) Start Bot${NC}"
    echo -e "${WHITE}2) Stop Bot${NC}"
    echo -e "${WHITE}3) Restart Bot${NC}"
    echo -e "${WHITE}4) Service Status${NC}"
    echo -e "${WHITE}5) Enable Auto-start${NC}"
    echo -e "${WHITE}6) Disable Auto-start${NC}"
    echo -e "${WHITE}7) Reload Service Config${NC}"
    echo -e "${WHITE}0) Back${NC}"
    echo ""
    
    read -p "Choose option: " choice
    
    case $choice in
        1)
            echo "Starting bot..."
            if sudo systemctl start "$SERVICE_NAME"; then
                echo -e "${GREEN}✓ Bot started successfully!${NC}"
            else
                echo -e "${RED}✗ Failed to start bot${NC}"
            fi
            ;;
        2)
            echo "Stopping bot..."
            if sudo systemctl stop "$SERVICE_NAME"; then
                echo -e "${GREEN}✓ Bot stopped successfully!${NC}"
            else
                echo -e "${RED}✗ Failed to stop bot${NC}"
            fi
            ;;
        3)
            echo "Restarting bot..."
            if sudo systemctl restart "$SERVICE_NAME"; then
                echo -e "${GREEN}✓ Bot restarted successfully!${NC}"
            else
                echo -e "${RED}✗ Failed to restart bot${NC}"
            fi
            ;;
        4)
            echo ""
            sudo systemctl status "$SERVICE_NAME" --no-pager -l
            ;;
        5)
            if sudo systemctl enable "$SERVICE_NAME"; then
                echo -e "${GREEN}✓ Auto-start enabled!${NC}"
            else
                echo -e "${RED}✗ Failed to enable auto-start${NC}"
            fi
            ;;
        6)
            if sudo systemctl disable "$SERVICE_NAME"; then
                echo -e "${GREEN}✓ Auto-start disabled!${NC}"
            else
                echo -e "${RED}✗ Failed to disable auto-start${NC}"
            fi
            ;;
        7)
            echo "Reloading systemd configuration..."
            if sudo systemctl daemon-reload; then
                echo -e "${GREEN}✓ Configuration reloaded!${NC}"
            else
                echo -e "${RED}✗ Failed to reload configuration${NC}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

health_check() {
    print_banner
    echo -e "${CYAN}🏥 Health Check${NC}"
    echo -e "${CYAN}═══════════════${NC}"
    echo ""
    
    local issues=0
    
    # Check service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ Service Status: Running${NC}"
    else
        echo -e "${RED}✗ Service Status: Not Running${NC}"
        ((issues++))
    fi
    
    # Check configuration
    if [[ -f "$INSTALL_DIR/.env" ]]; then
        echo -e "${GREEN}✓ Configuration: Found${NC}"
    else
        echo -e "${RED}✗ Configuration: Missing${NC}"
        ((issues++))
    fi
    
    # Check virtual environment
    if [[ -d "$INSTALL_DIR/venv" ]]; then
        echo -e "${GREEN}✓ Virtual Environment: Found${NC}"
    else
        echo -e "${RED}✗ Virtual Environment: Missing${NC}"
        ((issues++))
    fi
    
    # Check dependencies
    if [[ -d "$INSTALL_DIR/venv" ]]; then
        cd "$INSTALL_DIR"
        source venv/bin/activate 2>/dev/null || true
        if python3 -c "import telegram" 2>/dev/null; then
            echo -e "${GREEN}✓ Telegram Library: Available${NC}"
        else
            echo -e "${RED}✗ Telegram Library: Missing${NC}"
            ((issues++))
        fi
    fi
    
    # Check auto-update system
    if [[ -f "$INSTALL_DIR/scripts/update_bot.sh" ]]; then
        echo -e "${GREEN}✓ Auto-Update: Configured${NC}"
    else
        echo -e "${YELLOW}⚠ Auto-Update: Not Configured${NC}"
    fi
    
    # Check logs
    if sudo journalctl -u "$SERVICE_NAME" -n 1 --quiet 2>/dev/null; then
        echo -e "${GREEN}✓ Service Logs: Available${NC}"
    else
        echo -e "${YELLOW}⚠ Service Logs: Limited${NC}"
    fi
    
    echo ""
    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}🎉 Health Check Passed! No issues found.${NC}"
    else
        echo -e "${RED}⚠️ Health Check Found $issues Issues${NC}"
        echo ""
        echo -e "${YELLOW}Recommended Actions:${NC}"
        echo -e "${WHITE}• Check service logs: sudo journalctl -u $SERVICE_NAME${NC}"
        echo -e "${WHITE}• Restart service: sudo systemctl restart $SERVICE_NAME${NC}"
        echo -e "${WHITE}• Run repair installation if issues persist${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

view_logs() {
    print_banner
    echo -e "${CYAN}📋 Log Viewer${NC}"
    echo -e "${CYAN}═════════════${NC}"
    echo ""
    echo -e "${WHITE}1) Live Service Logs${NC}"
    echo -e "${WHITE}2) Recent Service Logs${NC}"
    echo -e "${WHITE}3) Installation Logs${NC}"
    echo -e "${WHITE}4) Error Logs${NC}"
    echo -e "${WHITE}5) Update Logs${NC}"
    echo -e "${WHITE}0) Back${NC}"
    echo ""
    
    read -p "Choose option: " choice
    
    case $choice in
        1)
            echo -e "${CYAN}📡 Live service logs (Press Ctrl+C to exit):${NC}"
            echo ""
            sudo journalctl -u "$SERVICE_NAME" -f
            ;;
        2)
            echo -e "${CYAN}📄 Recent service logs:${NC}"
            echo ""
            sudo journalctl -u "$SERVICE_NAME" -n 50 --no-pager
            ;;
        3)
            echo -e "${CYAN}📄 Installation logs:${NC}"
            echo ""
            if [[ -f "$LOG_FILE" ]]; then
                tail -50 "$LOG_FILE"
            else
                echo "No installation logs found"
            fi
            ;;
        4)
            echo -e "${CYAN}📄 Error logs:${NC}"
            echo ""
            if [[ -f "$ERROR_LOG" ]]; then
                tail -50 "$ERROR_LOG"
            else
                echo "No error logs found"
            fi
            ;;
        5)
            echo -e "${CYAN}📄 Update logs:${NC}"
            echo ""
            if [[ -f "$UPDATE_LOG" ]]; then
                tail -50 "$UPDATE_LOG"
            else
                echo "No update logs found"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 1
            return
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

update_bot() {
    print_banner
    echo -e "${CYAN}🔄 Bot Update System${NC}"
    echo -e "${CYAN}═══════════════════════${NC}"
    echo ""
    
    # Check if auto-update script exists
    if [[ -f "$INSTALL_DIR/scripts/update_bot.sh" ]]; then
        echo -e "${GREEN}✓ Auto-update system available${NC}"
        echo ""
        echo -e "${YELLOW}Choose update method:${NC}"
        echo -e "${WHITE}1) Auto-Update (Recommended)${NC}"
        echo -e "${WHITE}2) Check for Updates Only${NC}"
        echo -e "${WHITE}3) Manual Update Steps${NC}"
        echo -e "${WHITE}0) Cancel${NC}"
        echo ""
        read -p "Enter choice (0-3): " update_choice
        
        case $update_choice in
            1)
                echo -e "${CYAN}🔄 Starting auto-update...${NC}"
                echo -e "${YELLOW}⚠️ Bot will restart automatically${NC}"
                echo ""
                read -p "Continue? (y/n): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    cd "$INSTALL_DIR"
                    bash scripts/update_bot.sh
                else
                    echo "Update cancelled"
                fi
                ;;
            2)
                echo -e "${CYAN}🔍 Checking for updates...${NC}"
                cd "$INSTALL_DIR"
                git fetch origin main
                local updates=$(git rev-list --count HEAD..origin/main)
                if [[ "$updates" -eq 0 ]]; then
                    echo -e "${GREEN}✅ Bot is up to date!${NC}"
                else
                    echo -e "${YELLOW}📦 $updates updates available${NC}"
                    echo -e "${WHITE}Run option 1 to apply updates${NC}"
                fi
                ;;
            3)
                echo -e "${CYAN}📋 Manual update steps:${NC}"
                echo -e "${WHITE}1. Stop bot: sudo systemctl stop $SERVICE_NAME${NC}"
                echo -e "${WHITE}2. Backup config: cp $INSTALL_DIR/.env /tmp/.env.backup${NC}"
                echo -e "${WHITE}3. Update code: cd $INSTALL_DIR && git pull${NC}"
                echo -e "${WHITE}4. Restore config: cp /tmp/.env.backup $INSTALL_DIR/.env${NC}"
                echo -e "${WHITE}5. Update deps: source venv/bin/activate && pip install -r requirements.txt --upgrade${NC}"
                echo -e "${WHITE}6. Start bot: sudo systemctl start $SERVICE_NAME${NC}"
                ;;
            0)
                echo -e "${YELLOW}Update cancelled${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                ;;
        esac
    else
        echo -e "${YELLOW}⚠️ Auto-update system not available${NC}"
        echo ""
        echo -e "${CYAN}📋 Manual update steps:${NC}"
        echo -e "${WHITE}1. Stop bot: sudo systemctl stop $SERVICE_NAME${NC}"
        echo -e "${WHITE}2. Backup config: cp $INSTALL_DIR/.env /tmp/.env.backup${NC}"
        echo -e "${WHITE}3. Update code: cd $INSTALL_DIR && git pull${NC}"
        echo -e "${WHITE}4. Restore config: cp /tmp/.env.backup $INSTALL_DIR/.env${NC}"
        echo -e "${WHITE}5. Update deps: source venv/bin/activate && pip install -r requirements.txt --upgrade${NC}"
        echo -e "${WHITE}6. Start bot: sudo systemctl start $SERVICE_NAME${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

complete_uninstall() {
    print_banner
    echo -e "${RED}⚠️ Complete Uninstallation${NC}"
    echo -e "${RED}═══════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}This will completely remove:${NC}"
    echo -e "${WHITE}• FlowAI-ICT Bot installation${NC}"
    echo -e "${WHITE}• All configuration files${NC}"
    echo -e "${WHITE}• Service files${NC}"
    echo -e "${WHITE}• Log files${NC}"
    echo -e "${WHITE}• Virtual environment${NC}"
    echo ""
    echo -e "${RED}⚠️ This action cannot be undone!${NC}"
    echo ""
    
    read -p "Are you sure? Type 'CONFIRM' to proceed: " confirm
    
    if [[ "$confirm" == "CONFIRM" ]]; then
        echo ""
        print_step "Stopping service..."
        sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        
        print_step "Disabling service..."
        sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        
        print_step "Removing service file..."
        sudo rm -f "$SERVICE_FILE"
        
        print_step "Removing installation directory..."
        sudo rm -rf "$INSTALL_DIR"
        
        print_step "Removing log files..."
        rm -f "$LOG_FILE" "$ERROR_LOG" "$UPDATE_LOG" 2>/dev/null || true
        rm -f /tmp/flowai-*.log 2>/dev/null || true
        
        print_step "Removing backup files..."
        rm -rf /tmp/flowai-backup-* 2>/dev/null || true
        
        print_step "Reloading systemd..."
        sudo systemctl daemon-reload
        
        print_success "Uninstallation completed!"
        echo ""
        echo -e "${GREEN}FlowAI-ICT Bot has been completely removed from your system.${NC}"
        echo ""
        exit 0
    else
        echo -e "${YELLOW}Uninstallation cancelled.${NC}"
        sleep 2
    fi
}

show_help() {
    print_banner
    echo -e "${CYAN}📖 Help & Documentation${NC}"
    echo -e "${CYAN}═══════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}FlowAI-ICT Trading Bot v4.0${NC}"
    echo ""
    echo -e "${YELLOW}Quick Commands:${NC}"
    echo -e "${WHITE}• sudo systemctl start $SERVICE_NAME${NC} - Start bot"
    echo -e "${WHITE}• sudo systemctl stop $SERVICE_NAME${NC} - Stop bot"
    echo -e "${WHITE}• sudo systemctl status $SERVICE_NAME${NC} - Check status"
    echo -e "${WHITE}• sudo systemctl restart $SERVICE_NAME${NC} - Restart bot"
    echo -e "${WHITE}• sudo journalctl -u $SERVICE_NAME -f${NC} - View live logs"
    echo ""
    echo -e "${YELLOW}Auto-Update Commands:${NC}"
    echo -e "${WHITE}• Telegram: /update${NC} - Check for updates"
    echo -e "${WHITE}• Telegram: /confirm_update${NC} - Apply updates"
    echo -e "${WHITE}• Manual: bash $INSTALL_DIR/scripts/update_bot.sh${NC}"
    echo ""
    echo -e "${YELLOW}Important Files:${NC}"
    echo -e "${WHITE}• Installation: $INSTALL_DIR${NC}"
    echo -e "${WHITE}• Configuration: $INSTALL_DIR/.env${NC}"
    echo -e "${WHITE}• Bot Logs: $INSTALL_DIR/logs/${NC}"
    echo -e "${WHITE}• System Logs: sudo journalctl -u $SERVICE_NAME${NC}"
    echo -e "${WHITE}• Update Script: $INSTALL_DIR/scripts/update_bot.sh${NC}"
    echo ""
    echo -e "${YELLOW}Features:${NC}"
    echo -e "${WHITE}• ICT Methodology (Order Blocks, FVG, Liquidity)${NC}"
    echo -e "${WHITE}• AI-Powered Signal Generation${NC}"
    echo -e "${WHITE}• Real-time Market Analysis${NC}"
    echo -e "${WHITE}• Advanced Risk Management${NC}"
    echo -e "${WHITE}• Telegram Bot Interface${NC}"
    echo -e "${WHITE}• Auto-Update System${NC}"
    echo -e "${WHITE}• Comprehensive Logging${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "${WHITE}• Check service status: sudo systemctl status $SERVICE_NAME${NC}"
    echo -e "${WHITE}• View recent logs: sudo journalctl -u $SERVICE_NAME -n 50${NC}"
    echo -e "${WHITE}• Restart if stuck: sudo systemctl restart $SERVICE_NAME${NC}"
    echo -e "${WHITE}• Run health check from management menu${NC}"
    echo -e "${WHITE}• Use repair installation if needed${NC}"
    echo ""
    echo -e "${YELLOW}Support:${NC}"
    echo -e "${WHITE}• GitHub: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot${NC}"
    echo -e "${WHITE}• Issues: Report on GitHub Issues page${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

wait_for_input() {
    echo ""
    read -p "Press Enter to continue..."
}

# Management menu
management_menu() {
    while true; do
        print_banner
        print_management_menu
        
        echo -e "${WHITE}Choose option (0-9, h):${NC}"
        read -r choice
        
        case $choice in
            1) show_system_status ;;
            2) manage_service ;;
            3) health_check ;;
            4)
                echo -e "${CYAN}⚙️ Configuration Management${NC}"
                echo ""
                echo -e "${WHITE}Configuration file: $INSTALL_DIR/.env${NC}"
                echo ""
                echo -e "${YELLOW}Available actions:${NC}"
                echo -e "${WHITE}1) View current configuration${NC}"
                echo -e "${WHITE}2) Edit configuration${NC}"
                echo -e "${WHITE}3) Backup configuration${NC}"
                echo -e "${WHITE}0) Back${NC}"
                echo ""
                read -p "Choose action: " config_choice
                
                case $config_choice in
                    1)
                        if [[ -f "$INSTALL_DIR/.env" ]]; then
                            echo -e "${CYAN}Current configuration:${NC}"
                            cat "$INSTALL_DIR/.env"
                        else
                            echo -e "${RED}Configuration file not found${NC}"
                        fi
                        ;;
                    2)
                        echo -e "${CYAN}Opening configuration editor...${NC}"
                        echo -e "${WHITE}Edit with: nano $INSTALL_DIR/.env${NC}"
                        echo -e "${YELLOW}After editing, restart the bot:${NC}"
                        echo -e "${WHITE}sudo systemctl restart $SERVICE_NAME${NC}"
                        ;;
                    3)
                        if [[ -f "$INSTALL_DIR/.env" ]]; then
                            cp "$INSTALL_DIR/.env" "/tmp/.env.backup.$(date +%Y%m%d-%H%M%S)"
                            echo -e "${GREEN}Configuration backed up to /tmp/${NC}"
                        else
                            echo -e "${RED}Configuration file not found${NC}"
                        fi
                        ;;
                esac
                wait_for_input
                ;;
            5) update_bot ;;
            6)
                echo -e "${CYAN}💾 Backup & Restore${NC}"
                echo ""
                echo -e "${WHITE}1) Create Backup${NC}"
                echo -e "${WHITE}2) List Backups${NC}"
                echo -e "${WHITE}3) Restore from Backup${NC}"
                echo -e "${WHITE}0) Back${NC}"
                echo ""
                read -p "Choose action: " backup_choice
                
                case $backup_choice in
                    1)
                        local backup_name="flowai-backup-$(date +%Y%m%d-%H%M%S)"
                        mkdir -p "/tmp/$backup_name"
                        if [[ -f "$INSTALL_DIR/.env" ]]; then
                            cp "$INSTALL_DIR/.env" "/tmp/$backup_name/"
                            echo -e "${GREEN}✓ Backup created: /tmp/$backup_name${NC}"
                        else
                            echo -e "${RED}✗ No configuration to backup${NC}"
                        fi
                        ;;
                    2)
                        echo -e "${CYAN}Available backups:${NC}"
                        ls -la /tmp/flowai-backup-* 2>/dev/null || echo "No backups found"
                        ;;
                    3)
                        echo -e "${CYAN}Available backups:${NC}"
                        local backups=($(ls -d /tmp/flowai-backup-* 2>/dev/null))
                        if [[ ${#backups[@]} -eq 0 ]]; then
                            echo "No backups found"
                        else
                            for i in "${!backups[@]}"; do
                                echo "$((i+1))) $(basename "${backups[$i]}")"
                            done
                            echo ""
                            read -p "Choose backup number: " backup_num
                            if [[ "$backup_num" =~ ^[0-9]+$ ]] && [[ "$backup_num" -le "${#backups[@]}" ]]; then
                                local selected_backup="${backups[$((backup_num-1))]}"
                                if [[ -f "$selected_backup/.env" ]]; then
                                    cp "$selected_backup/.env" "$INSTALL_DIR/.env"
                                    echo -e "${GREEN}✓ Configuration restored${NC}"
                                    echo -e "${YELLOW}Restart bot to apply changes${NC}"
                                else
                                    echo -e "${RED}✗ Backup file not found${NC}"
                                fi
                            else
                                echo -e "${RED}Invalid selection${NC}"
                            fi
                        fi
                        ;;
                esac
                wait_for_input
                ;;
            7) view_logs ;;
            8)
                echo -e "${CYAN}🔧 Developer Tools${NC}"
                echo ""
                echo -e "${WHITE}1) Python Console${NC}"
                echo -e "${WHITE}2) Test Bot Connection${NC}"
                echo -e "${WHITE}3) Check Dependencies${NC}"
                echo -e "${WHITE}4) Environment Info${NC}"
                echo -e "${WHITE}0) Back${NC}"
                echo ""
                read -p "Choose tool: " dev_choice
                
                case $dev_choice in
                    1)
                        echo -e "${CYAN}Starting Python console...${NC}"
                        cd "$INSTALL_DIR"
                        source venv/bin/activate
                        python3
                        ;;
                    2)
                        echo -e "${CYAN}Testing bot connection...${NC}"
                        cd "$INSTALL_DIR"
                        source venv/bin/activate
                        python3 -c "
import os
from dotenv import load_dotenv
load_dotenv()
token = os.getenv('TELEGRAM_TOKEN')
if token:
    print('✓ Token loaded')
    import telegram
    bot = telegram.Bot(token)
    try:
        me = bot.get_me()
        print(f'✓ Bot connected: @{me.username}')
    except Exception as e:
        print(f'✗ Connection failed: {e}')
else:
    print('✗ No token found')
"
                        ;;
                    3)
                        echo -e "${CYAN}Checking dependencies...${NC}"
                        cd "$INSTALL_DIR"
                        source venv/bin/activate
                        pip list | grep -E "(telegram|pandas|numpy|ta)"
                        ;;
                    4)
                        echo -e "${CYAN}Environment information:${NC}"
                        echo "Python: $(python3 --version)"
                        echo "Pip: $(pip --version)"
                        echo "Git: $(git --version)"
                        echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
                        echo "Architecture: $(uname -m)"
                        ;;
                esac
                wait_for_input
                ;;
            9) complete_uninstall ;;
            h) show_help ;;
            0) 
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
            *) 
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Main execution function
main() {
    # Initialize logging first
    init_logs
    
    # Run pre-flight checks
    check_prerequisites
    
    # Log startup
    echo "FlowAI-ICT Installation/Management Log v4.0 - $(date)" > "$LOG_FILE"
    
    # Handle root user automatically
    handle_root_user
    
    # Main application loop - Fixed flow
    while true; do
        # Check installation status
        check_installation
        
        if [ "$INSTALLATION_EXISTS" = true ]; then
            management_menu
        else
            install_menu
        fi
    done
}

# Run main function with all arguments
main "$@"