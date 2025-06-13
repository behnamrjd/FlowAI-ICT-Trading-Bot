#!/bin/bash
# FlowAI-ICT Trading Bot Installation & Management Script
# Version: 4.0 - Complete Redesign

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
UPDATE_SCRIPT_PATH="$INSTALL_DIR/scripts/update_bot.sh"
UPDATE_LOCK_FILE="/tmp/flowai_update.lock"
BACKUP_RETENTION_DAYS=7
UPDATE_CHECK_URL="https://api.github.com/repos/behnamrjd/FlowAI-ICT-Trading-Bot/commits/main"
CURRENT_USER=$(whoami)
USER_HOME="$HOME"

# Unified Logging System
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

# ===== ERROR HANDLING FUNCTIONS =====
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

# Initialize log files with proper permissions
init_logs() {
    # Try to create log files in /tmp first, then fallback to user home
    local temp_log_dir="/tmp"
    local user_log_dir="$HOME"
    
    # Test write permissions for different directories
    if [[ -w "$temp_log_dir" ]]; then
        LOG_FILE="$temp_log_dir/flowai-install.log"
        ERROR_LOG="$temp_log_dir/flowai-errors.log"
        UPDATE_LOG="$temp_log_dir/flowai-update.log"
    elif [[ -w "$user_log_dir" ]]; then
        LOG_FILE="$user_log_dir/flowai-install.log"
        ERROR_LOG="$user_log_dir/flowai-errors.log"
        UPDATE_LOG="$user_log_dir/flowai-update.log"
    else
        # Create logs directory in current location
        mkdir -p logs 2>/dev/null || true
        if [[ -w "logs" ]]; then
            LOG_FILE="logs/flowai-install.log"
            ERROR_LOG="logs/flowai-errors.log"
            UPDATE_LOG="logs/flowai-update.log"
        else
            LOG_FILE="./flowai-install.log"
            ERROR_LOG="./flowai-errors.log"
            UPDATE_LOG="./flowai-update.log"
        fi
    fi
    
    # Create log files with proper error handling
    {
        touch "$LOG_FILE" "$ERROR_LOG" "$UPDATE_LOG" 2>/dev/null
    } || {
        # Final fallback - create in /tmp with unique names
        LOG_FILE="/tmp/flowai-install-$$.log"
        ERROR_LOG="/tmp/flowai-errors-$$.log"
        UPDATE_LOG="/tmp/flowai-update-$$.log"
        touch "$LOG_FILE" "$ERROR_LOG" "$UPDATE_LOG" 2>/dev/null || {
            echo "⚠️ Warning: Cannot create log files, logging disabled"
            LOG_FILE="/dev/null"
            ERROR_LOG="/dev/null"
            UPDATE_LOG="/dev/null"
        }
    }
    
    # Initialize log files if they're writable
    if [[ -w "$LOG_FILE" ]]; then
        echo "=== FlowAI-ICT Installation Log Started: $(date) ===" > "$LOG_FILE"
        echo "=== FlowAI-ICT Error Log Started: $(date) ===" > "$ERROR_LOG"
        echo "=== FlowAI-ICT Update Log Started: $(date) ===" > "$UPDATE_LOG"
        
        # Set proper permissions
        chmod 644 "$LOG_FILE" "$ERROR_LOG" "$UPDATE_LOG" 2>/dev/null || true
        
        echo "📝 Log files initialized:"
        echo "   Install: $LOG_FILE"
        echo "   Errors:  $ERROR_LOG"
        echo "   Updates: $UPDATE_LOG"
    else
        echo "⚠️ Warning: Logging disabled due to permission issues"
    fi
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
}

print_success() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ${RED}❌ $1${NC}"
}

# Pre-flight system checks
check_prerequisites() {
    print_step "Running pre-flight checks..."
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        error_exit "Python3 is not installed"
    fi
    
    local python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    
    # Check Python version using built-in comparison
    local major=$(echo "$python_version" | cut -d. -f1)
    local minor=$(echo "$python_version" | cut -d. -f2)
    
    if [[ $major -lt 3 ]] || [[ $major -eq 3 && $minor -lt 8 ]]; then
        error_exit "Python 3.8+ required, found $python_version"
    fi
    print_success "Python $python_version detected"
    
    # Check python3-venv package
    if ! dpkg -l | grep -q python3.*-venv; then
        print_warning "python3-venv not found, installing..."
        apt update && apt install python3-venv python3.12-venv -y || error_exit "Failed to install python3-venv"
        print_success "python3-venv installed successfully"
    else
        print_success "python3-venv detected"
    fi
    
    # Check disk space (minimum 1GB)
    local available_space=$(df /opt 2>/dev/null | awk 'NR==2 {print $4}' || echo "1000000")
    if [[ $available_space -lt 1000000 ]]; then
        print_warning "Low disk space detected: $(($available_space/1024))MB available"
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null && ! ping -c 1 8.8.8.8 &> /dev/null; then
        error_exit "No internet connectivity detected"
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
    
    # Check pip3 with multiple methods and fallbacks
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
    print_success "Pre-flight checks completed"
}

# Check installation status
check_installation() {
    if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/.env" ]] && [[ -f "$SERVICE_FILE" ]]; then
        INSTALLATION_EXISTS=true
    else
        INSTALLATION_EXISTS=false
    fi
}

# Handle root user
handle_root_user() {
    if [[ $EUID -eq 0 ]]; then
        print_step "Running as root - auto-creating flowai user without password..."
        
        if ! id "flowai" &>/dev/null; then
            useradd -m -s /bin/bash flowai
            usermod -aG sudo flowai
            echo "flowai ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/flowai
            print_success "User 'flowai' created with sudo no-password access"
        else
            print_success "User 'flowai' already exists"
        fi
        
        # Copy script to flowai user
        cp "$0" /home/flowai/
        chown flowai:flowai /home/flowai/Install.sh
        chmod +x /home/flowai/Install.sh
        print_success "Script copied to flowai user"
        
        print_step "Switching to user 'flowai'..."
        exec sudo -u flowai bash /home/flowai/Install.sh "$@"
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
    echo -e "${WHITE}3) ${CYAN}Update Existing Installation${NC}"
    echo -e "   ${WHITE}• Update bot to latest version${NC}"
    echo ""
    echo -e "${WHITE}0) ${RED}Exit${NC}"
    echo ""
}

# Quick configuration
quick_configuration() {
    echo -e "${CYAN}⚙️ Quick Configuration Setup${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    
    # Get Telegram Bot Token
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
    
    # Get Admin ID
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

# Automated installation
automated_installation() {
    echo -e "${GREEN}Starting automated installation...${NC}"
    echo ""
    
    # Create installation directory
    print_step "Creating installation directory..."
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown -R "$USER:$USER" "$INSTALL_DIR"
    
    # Clone repository
    print_step "Cloning FlowAI-ICT repository..."
    cd /tmp
    git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git flowai-temp
    
    # Move files to installation directory
    cp -r flowai-temp/* "$INSTALL_DIR/"
    cp flowai-temp/.* "$INSTALL_DIR/" 2>/dev/null || true
    rm -rf flowai-temp
    
    cd "$INSTALL_DIR"
    
    # Create virtual environment
    print_step "Creating Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    
    # Install dependencies with fixed versions
    print_step "Installing Python dependencies..."
    pip install --upgrade pip
    
    # Install exact versions to prevent conflicts
    pip install python-telegram-bot==13.15 --force-reinstall --no-deps
    pip install APScheduler==3.6.3 cachetools==4.2.2 certifi tornado==6.1
    pip install numpy==1.26.4 pandas==2.0.3 ta==0.10.2 urllib3==1.26.18
    pip install python-dotenv==0.19.2 requests==2.28.2 psutil==5.9.8
    
    # Verify installation
    python3 -c "import telegram; print('✓ Telegram version:', telegram.__version__)"
    
    # Create configuration file
    print_step "Creating configuration file..."
    cat > .env << EOF
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
    
    # Create logs directory
    mkdir -p logs
    
    # Create systemd service
    print_step "Creating systemd service..."
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
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

[Install]
WantedBy=multi-user.target
EOF
    
    # Setup auto-update system
    print_step "Setting up auto-update system..."
    mkdir -p scripts
    
    # Create update script
    cat > scripts/update_bot.sh << 'EOF'
#!/bin/bash
# FlowAI-ICT Bot Auto Update Script

set -e

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

# Remove old lock file
rm -f "$LOCK_FILE"
echo $$ > "$LOCK_FILE"

log "=== FlowAI-ICT Bot Update Started ==="

# Create backup
mkdir -p "$BACKUP_DIR"
if [[ -f "$BOT_DIR/.env" ]]; then
    cp "$BOT_DIR/.env" "$BACKUP_DIR/.env" || error_exit "Failed to backup .env"
    log "Configuration backed up"
fi

# Stop service
log "Stopping bot service..."
sudo systemctl stop "$SERVICE_NAME" || error_exit "Failed to stop service"

# Update code
log "Updating code..."
cd "$BOT_DIR" || error_exit "Cannot access bot directory"
git fetch origin main || error_exit "Failed to fetch updates"
git reset --hard origin/main || error_exit "Failed to update code"
log "Code updated successfully"

# Restore configuration
if [[ -f "$BACKUP_DIR/.env" ]]; then
    cp "$BACKUP_DIR/.env" "$BOT_DIR/.env" || error_exit "Failed to restore config"
    log "Configuration restored"
fi

# Update dependencies
log "Updating dependencies..."
source venv/bin/activate || error_exit "Failed to activate venv"
pip install --upgrade pip
pip uninstall python-telegram-bot -y
pip install python-telegram-bot==13.15 --force-reinstall --no-deps
pip install APScheduler==3.6.3 cachetools==4.2.2 certifi tornado==6.1
pip install numpy==1.26.4 pandas==2.0.3 ta==0.10.2 urllib3==1.26.18 --upgrade
pip install python-dotenv==0.19.2 requests==2.28.2 psutil==5.9.8 --upgrade

# Verify installation
python3 -c "import telegram; print('✓ Telegram version:', telegram.__version__)" || error_exit "Telegram import failed"
log "Dependencies updated"

# Start service
log "Starting bot service..."
sudo systemctl start "$SERVICE_NAME" || error_exit "Failed to start service"

# Wait and verify
sleep 5
if systemctl is-active --quiet "$SERVICE_NAME"; then
    log "Bot service started successfully"
else
    error_exit "Service failed to start"
fi

# Cleanup
rm -f "$LOCK_FILE"
find /tmp -name "flowai-backup-*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

log "=== FlowAI-ICT Bot Update Completed Successfully ==="
echo "✅ Update completed! Bot is running with latest version."
EOF
    
    chmod +x scripts/update_bot.sh
    
    # Add telegram update handlers to bot
    if [[ -f telegram_bot.py ]]; then
        # Add update functionality to telegram bot
        cat >> telegram_bot.py << 'EOF'

# Auto-update functionality
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
application.add_handler(CommandHandler("update", update_command))
application.add_handler(CommandHandler("confirm_update", confirm_update_command))
EOF
    fi
    
    # Enable and start service
    print_step "Enabling and starting service..."
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
    
    # Wait for service to start
    sleep 5
    
    # Verify installation
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Installation completed successfully!"
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}                    ${BOLD}INSTALLATION SUCCESSFUL${NC}                    ${GREEN}║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}🤖 Bot Status:${NC} ${GREEN}Running${NC}"
        echo -e "${CYAN}📱 Telegram Token:${NC} ${TELEGRAM_TOKEN}"
        echo -e "${CYAN}👤 Admin ID:${NC} ${ADMIN_ID}"
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
        
        # Ask to start management menu
        echo -e "${YELLOW}Would you like to open the management menu? (y/n):${NC}"
        read -r choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            return 0
        else
            exit 0
        fi
    else
        error_exit "Service failed to start. Check logs with: sudo journalctl -u $SERVICE_NAME"
    fi
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
                echo -e "${YELLOW}Custom installation coming soon...${NC}"
                sleep 2
                ;;
            3)
                echo -e "${YELLOW}Update feature coming soon...${NC}"
                sleep 2
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
    echo -e "${WHITE}6) ${CYAN}Developer Tools${NC}"
    echo -e "${WHITE}7) ${RED}Uninstall${NC}"
    echo -e "${WHITE}8) ${CYAN}Help & Documentation${NC}"
    echo -e "${WHITE}9) ${CYAN}View Logs${NC}"
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
    
    # System resources
    echo ""
    echo -e "${CYAN}💾 System Resources:${NC}"
    echo -e "${WHITE}CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%${NC}"
    echo -e "${WHITE}Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')${NC}"
    echo -e "${WHITE}Disk Usage: $(df -h /opt | awk 'NR==2{printf "%s", $5}')${NC}"
    
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
    echo -e "${WHITE}0) Back${NC}"
    echo ""
    
    read -p "Choose option: " choice
    
    case $choice in
        1)
            echo "Starting bot..."
            sudo systemctl start "$SERVICE_NAME"
            echo "Bot started!"
            ;;
        2)
            echo "Stopping bot..."
            sudo systemctl stop "$SERVICE_NAME"
            echo "Bot stopped!"
            ;;
        3)
            echo "Restarting bot..."
            sudo systemctl restart "$SERVICE_NAME"
            echo "Bot restarted!"
            ;;
        4)
            sudo systemctl status "$SERVICE_NAME" --no-pager
            ;;
        5)
            sudo systemctl enable "$SERVICE_NAME"
            echo "Auto-start enabled!"
            ;;
        6)
            sudo systemctl disable "$SERVICE_NAME"
            echo "Auto-start disabled!"
            ;;
        0)
            return
            ;;
        *)
            echo "Invalid option!"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

view_error_logs() {
    print_banner
    echo -e "${CYAN}📋 Error Logs${NC}"
    echo -e "${CYAN}═══════════${NC}"
    echo ""
    
    if [[ -f "$ERROR_LOG" ]]; then
        echo -e "${YELLOW}Recent errors:${NC}"
        tail -20 "$ERROR_LOG"
    else
        echo -e "${GREEN}No error logs found!${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}System logs:${NC}"
    sudo journalctl -u "$SERVICE_NAME" -n 10 --no-pager
    
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

wait_for_input() {
    echo ""
    read -p "Press Enter to continue..."
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
                if [[ -f "$INSTALL_DIR/health_check.sh" ]]; then
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
                echo -e "${WHITE}sudo systemctl restart $SERVICE_NAME${NC}"
                wait_for_input
                ;;
            5)
                echo -e "${CYAN}🔄 Auto-Update Bot to Latest Version${NC}"
                echo ""
                echo -e "${WHITE}Checking for updates...${NC}"
                
                # Check if auto-update script exists
                if [[ -f "$INSTALL_DIR/scripts/update_bot.sh" ]]; then
                    echo -e "${GREEN}✓ Auto-update system available${NC}"
                    echo ""
                    echo -e "${YELLOW}Choose update method:${NC}"
                    echo -e "${WHITE}1) Auto-Update (Recommended)${NC}"
                    echo -e "${WHITE}2) Manual Update Steps${NC}"
                    echo -e "${WHITE}3) Cancel${NC}"
                    echo ""
                    read -p "Enter choice (1-3): " update_choice
                    
                    case $update_choice in
                        1)
                            echo -e "${CYAN}🔄 Starting auto-update...${NC}"
                            echo -e "${YELLOW}⚠️ Bot will restart automatically${NC}"
                            echo ""
                            cd "$INSTALL_DIR"
                            bash scripts/update_bot.sh
                            ;;
                        2)
                            echo -e "${CYAN}📋 Manual update steps:${NC}"
                            echo -e "${WHITE}1. Stop bot: sudo systemctl stop $SERVICE_NAME${NC}"
                            echo -e "${WHITE}2. Backup config: cp $INSTALL_DIR/.env /tmp/.env.backup${NC}"
                            echo -e "${WHITE}3. Update code: cd $INSTALL_DIR && git pull${NC}"
                            echo -e "${WHITE}4. Restore config: cp /tmp/.env.backup $INSTALL_DIR/.env${NC}"
                            echo -e "${WHITE}5. Update deps: source venv/bin/activate && pip install -r requirements.txt --upgrade${NC}"
                            echo -e "${WHITE}6. Start bot: sudo systemctl start $SERVICE_NAME${NC}"
                            ;;
                        3)
                            echo -e "${YELLOW}Update cancelled${NC}"
                            ;;
                        *)
                            echo -e "${RED}Invalid choice${NC}"
                            ;;
                    esac
                else
                    echo -e "${YELLOW}⚠️ Auto-update not available${NC}"
                    echo ""
                    echo -e "${CYAN}📋 Manual update steps:${NC}"
                    echo -e "${WHITE}1. Stop bot: sudo systemctl stop $SERVICE_NAME${NC}"
                    echo -e "${WHITE}2. Backup config: cp $INSTALL_DIR/.env /tmp/.env.backup${NC}"
                    echo -e "${WHITE}3. Update code: cd $INSTALL_DIR && git pull${NC}"
                    echo -e "${WHITE}4. Restore config: cp /tmp/.env.backup $INSTALL_DIR/.env${NC}"
                    echo -e "${WHITE}5. Update deps: source venv/bin/activate && pip install -r requirements.txt --upgrade${NC}"
                    echo -e "${WHITE}6. Start bot: sudo systemctl start $SERVICE_NAME${NC}"
                fi
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
                echo -e "${WHITE}• sudo systemctl start $SERVICE_NAME${NC}"
                echo -e "${WHITE}• sudo systemctl stop $SERVICE_NAME${NC}"
                echo -e "${WHITE}• sudo systemctl status $SERVICE_NAME${NC}"
                echo -e "${WHITE}• sudo journalctl -u $SERVICE_NAME -f${NC}"
                echo ""
                echo -e "${YELLOW}Auto-Update Commands:${NC}"
                echo -e "${WHITE}• Telegram: /update (check for updates)${NC}"
                echo -e "${WHITE}• Telegram: /confirm_update (apply updates)${NC}"
                echo -e "${WHITE}• Manual: bash $INSTALL_DIR/scripts/update_bot.sh${NC}"
                echo ""
                echo -e "${YELLOW}Files:${NC}"
                echo -e "${WHITE}• Installation: $INSTALL_DIR${NC}"
                echo -e "${WHITE}• Configuration: $INSTALL_DIR/.env${NC}"
                echo -e "${WHITE}• Logs: $INSTALL_DIR/logs/${NC}"
                echo -e "${WHITE}• Update Script: $INSTALL_DIR/scripts/update_bot.sh${NC}"
                echo ""
                echo -e "${YELLOW}Features:${NC}"
                echo -e "${WHITE}• ICT Methodology (Order Blocks, FVG, Liquidity)${NC}"
                echo -e "${WHITE}• AI-Powered Signal Generation${NC}"
                echo -e "${WHITE}• Real-time BrsAPI Integration${NC}"
                echo -e "${WHITE}• Advanced Risk Management${NC}"
                echo -e "${WHITE}• Telegram Bot Interface${NC}"
                echo -e "${WHITE}• Auto-Update System${NC}"
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
    
    # Run pre-flight checks
    check_prerequisites
    
    # Log startup
    echo "FlowAI-ICT Installation/Management Log v4.0 - $(date)" > "$LOG_FILE"
    
    # Handle root user automatically
    handle_root_user
    
    # Main loop
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

# Run main function
main "$@"
