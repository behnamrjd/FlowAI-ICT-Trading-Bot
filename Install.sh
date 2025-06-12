#!/bin/bash
# FlowAI-ICT Trading Bot Installation & Update Script
# Version: 4.5 with Auto-Update

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/opt/FlowAI-ICT-Trading-Bot"
SERVICE_NAME="flowai-ict-bot"
LOG_FILE="/var/log/flowai-install.log"
BACKUP_DIR="/tmp/flowai-backup-$(date +%Y%m%d-%H%M%S)"

# Progress tracking
TOTAL_STEPS=13
CURRENT_STEP=0

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Progress function
progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo -e "${CYAN}[$CURRENT_STEP/$TOTAL_STEPS - $percent%] $1${NC}"
    log "[$CURRENT_STEP/$TOTAL_STEPS - $percent%] $1"
}

# Error handling
error_exit() {
    echo -e "${RED}ERROR: $1${NC}"
    log "ERROR: $1"
    exit 1
}

# Success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Please run as a regular user with sudo access."
    fi
}

# Check system requirements
check_requirements() {
    progress "Checking System Requirements..."
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        error_exit "Python 3 is not installed. Please install Python 3.8 or higher."
    fi
    
    local python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local required_version="3.8"
    
    if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        error_exit "Python 3.8 or higher is required. Current version: $python_version"
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        error_exit "Git is not installed. Please install git first."
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        warning "This script requires sudo access for system service management."
    fi
    
    success "System requirements check passed"
}

# Detect if this is an update or fresh install
detect_installation_type() {
    if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/.env" ]]; then
        echo "update"
    else
        echo "install"
    fi
}

# Backup existing installation
backup_installation() {
    if [[ ! -d "$INSTALL_DIR" ]]; then
        return 0
    fi
    
    progress "Creating backup of existing installation..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup configuration
    if [[ -f "$INSTALL_DIR/.env" ]]; then
        cp "$INSTALL_DIR/.env" "$BACKUP_DIR/.env" || error_exit "Failed to backup .env file"
    fi
    
    # Backup logs
    if [[ -d "$INSTALL_DIR/logs" ]]; then
        cp -r "$INSTALL_DIR/logs" "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    # Backup custom scripts
    if [[ -d "$INSTALL_DIR/scripts" ]]; then
        cp -r "$INSTALL_DIR/scripts" "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    success "Backup created at $BACKUP_DIR"
}

# Stop existing service
stop_service() {
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        progress "Stopping existing service..."
        sudo systemctl stop "$SERVICE_NAME" || warning "Failed to stop service"
        
        # Wait for service to stop
        local timeout=30
        while systemctl is-active --quiet "$SERVICE_NAME" && [[ $timeout -gt 0 ]]; do
            sleep 1
            ((timeout--))
        done
        
        success "Service stopped"
    fi
}

# Clone or update repository
setup_repository() {
    progress "Setting up repository..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        # Update existing repository
        cd "$INSTALL_DIR"
        git fetch origin main || error_exit "Failed to fetch updates"
        git reset --hard origin/main || error_exit "Failed to update repository"
        success "Repository updated"
    else
        # Clone new repository
        sudo git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git "$INSTALL_DIR" || error_exit "Failed to clone repository"
        success "Repository cloned"
    fi
    
    # Set ownership
    sudo chown -R $USER:$USER "$INSTALL_DIR"
}

# Setup virtual environment
setup_virtual_environment() {
    progress "Setting up virtual environment..."
    
    cd "$INSTALL_DIR"
    
    # Remove old virtual environment if exists
    if [[ -d "venv" ]]; then
        rm -rf venv
    fi
    if [[ -d "flowai_env" ]]; then
        rm -rf flowai_env
    fi
    
    # Create new virtual environment
    python3 -m venv venv || error_exit "Failed to create virtual environment"
    source venv/bin/activate || error_exit "Failed to activate virtual environment"
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel || error_exit "Failed to upgrade pip"
    
    success "Virtual environment created"
}

# Install Python dependencies
install_dependencies() {
    progress "Installing Python dependencies..."
    
    cd "$INSTALL_DIR"
    source venv/bin/activate || error_exit "Failed to activate virtual environment"
    
    # Install specific working versions
    pip install numpy==1.26.4 || error_exit "Failed to install numpy"
    pip install pandas==2.0.3 || error_exit "Failed to install pandas"
    pip install python-telegram-bot==13.15 || error_exit "Failed to install python-telegram-bot"
    pip install ta==0.10.2 || error_exit "Failed to install ta"
    pip install urllib3==1.26.18 || error_exit "Failed to install urllib3"
    
    # Install other requirements
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt || warning "Some dependencies may have failed to install"
    fi
    
    success "Python dependencies installed"
}

# Setup directory structure
setup_directories() {
    progress "Setting up directory structure..."
    
    cd "$INSTALL_DIR"
    
    # Create necessary directories
    mkdir -p logs
    mkdir -p data
    mkdir -p models
    mkdir -p scripts
    mkdir -p backups
    
    # Set permissions
    chmod 755 logs data models scripts backups
    
    success "Directory structure created"
}

# Setup configuration
setup_configuration() {
    progress "Setting up configuration..."
    
    cd "$INSTALL_DIR"
    
    # Restore backup if this is an update
    if [[ -f "$BACKUP_DIR/.env" ]]; then
        cp "$BACKUP_DIR/.env" ".env" || warning "Failed to restore configuration"
        success "Configuration restored from backup"
        return 0
    fi
    
    # Create new configuration if not exists
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp ".env.example" ".env"
        else
            # Create basic .env file
            cat > .env << 'EOF'
# FlowAI-ICT Trading Bot Configuration
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_ADMIN_IDS=your_user_id_here
BRSAPI_KEY=FreeQZdOYW6D3nNv95jZ9BcYXJHzTJpf
ICT_ENABLED=true
AI_MODEL_ENABLED=true
LOG_LEVEL=INFO
USD_IRR_EXCHANGE_RATE=70000.0
EOF
        fi
        
        warning "Please edit .env file with your actual configuration"
    fi
    
    success "Configuration setup completed"
}

# Add missing ICT variables to config.py
fix_ict_variables() {
    progress "Adding missing ICT variables..."
    
    cd "$INSTALL_DIR"
    
    # Check if variables exist in config.py
    if ! grep -q "ICT_SWING_LOOKBACK_PERIODS" flow_ai_core/config.py 2>/dev/null; then
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
        success "ICT variables added to config.py"
    else
        success "ICT variables already exist"
    fi
}

# Fix circular import in __init__.py
fix_circular_import() {
    progress "Fixing circular import issues..."
    
    cd "$INSTALL_DIR"
    
    # Fix __init__.py
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
EOF
    
    success "Circular import issues fixed"
}

# Setup update functionality
setup_update_system() {
    progress "Setting up auto-update system..."
    
    cd "$INSTALL_DIR"
    
    # Create update script
    cat > scripts/update_bot.sh << 'EOF'
#!/bin/bash
# FlowAI-ICT Bot Auto Update Script

set -e

BOT_DIR="/opt/FlowAI-ICT-Trading-Bot"
SERVICE_NAME="flowai-ict-bot"
LOG_FILE="/var/log/flowai-update.log"
BACKUP_DIR="/tmp/flowai-backup-$(date +%Y%m%d-%H%M%S)"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "=== FlowAI-ICT Bot Update Started ==="

# Create backup
mkdir -p "$BACKUP_DIR"
if [[ -f "$BOT_DIR/.env" ]]; then
    cp "$BOT_DIR/.env" "$BACKUP_DIR/.env"
fi

# Stop service
log "Stopping bot service..."
sudo systemctl stop "$SERVICE_NAME"

# Update code
log "Updating code..."
cd "$BOT_DIR"
git fetch origin main
git reset --hard origin/main

# Restore configuration
if [[ -f "$BACKUP_DIR/.env" ]]; then
    cp "$BACKUP_DIR/.env" "$BOT_DIR/.env"
fi

# Update dependencies
log "Updating dependencies..."
source venv/bin/activate
pip install -r requirements.txt --upgrade

# Start service
log "Starting bot service..."
sudo systemctl start "$SERVICE_NAME"

# Verify
sleep 5
if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    log "Bot updated successfully!"
else
    log "Bot update failed!"
    exit 1
fi

log "=== FlowAI-ICT Bot Update Completed ==="
EOF
    
    chmod +x scripts/update_bot.sh
    
    # Add update commands to telegram_bot.py if not exists
    if ! grep -q "update.*command" telegram_bot.py 2>/dev/null; then
        # Add update handler to telegram_bot.py
        cat >> telegram_bot.py << 'EOF'

# Auto-Update Functionality (Added by installer)
async def update_bot_command(self, update, context):
    """Handle /update command"""
    user_id = update.effective_user.id
    
    if not self.is_admin(user_id):
        await update.message.reply_text("❌ شما دسترسی به این دستور ندارید.")
        return
    
    # Check for updates
    import subprocess
    import os
    
    try:
        os.chdir("/opt/FlowAI-ICT-Trading-Bot")
        result = subprocess.run(['git', 'fetch', 'origin', 'main'], capture_output=True, text=True)
        
        if result.returncode != 0:
            await update.message.reply_text("❌ خطا در بررسی به‌روزرسانی")
            return
        
        # Check if updates available
        local = subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
        remote = subprocess.run(['git', 'rev-parse', 'origin/main'], capture_output=True, text=True).stdout.strip()
        
        if local == remote:
            await update.message.reply_text("✅ ربات از آخرین نسخه استفاده می‌کند.")
            return
        
        # Updates available
        await update.message.reply_text(f"""
🔄 **به‌روزرسانی موجود**

آخرین commit: {remote[:8]}
نسخه فعلی: {local[:8]}

⚠️ ربات موقتاً قطع خواهد شد.

برای تأیید: `/confirm_update`
""")
        
    except Exception as e:
        await update.message.reply_text(f"❌ خطا: {str(e)}")

async def confirm_update_command(self, update, context):
    """Handle /confirm_update command"""
    user_id = update.effective_user.id
    
    if not self.is_admin(user_id):
        await update.message.reply_text("❌ شما دسترسی به این دستور ندارید.")
        return
    
    await update.message.reply_text("""
🔄 **شروع به‌روزرسانی...**

⏳ در حال دریافت آخرین نسخه...
⚠️ ربات در حال restart...
""")
    
    # Execute update script
    import subprocess
    subprocess.Popen(['sudo', 'bash', '/opt/FlowAI-ICT-Trading-Bot/scripts/update_bot.sh'])

# Add handlers in setup_handlers method
# self.application.add_handler(CommandHandler('update', self.update_bot_command))
# self.application.add_handler(CommandHandler('confirm_update', self.confirm_update_command))
EOF
    fi
    
    success "Auto-update system configured"
}

# Setup system service
setup_service() {
    progress "Setting up system service..."
    
    # Create systemd service file
    sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << EOF
[Unit]
Description=FlowAI-ICT Trading Bot v4.5
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
    
    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    
    success "System service configured"
}

# Create utility scripts
create_utility_scripts() {
    progress "Creating utility scripts..."
    
    cd "$INSTALL_DIR"
    
    # Create management script
    cat > manage.sh << 'EOF'
#!/bin/bash
# FlowAI-ICT Bot Management Script

SERVICE_NAME="flowai-ict-bot"

case "$1" in
    start)
        echo "Starting FlowAI-ICT Bot..."
        sudo systemctl start $SERVICE_NAME
        ;;
    stop)
        echo "Stopping FlowAI-ICT Bot..."
        sudo systemctl stop $SERVICE_NAME
        ;;
    restart)
        echo "Restarting FlowAI-ICT Bot..."
        sudo systemctl restart $SERVICE_NAME
        ;;
    status)
        sudo systemctl status $SERVICE_NAME
        ;;
    logs)
        sudo journalctl -u $SERVICE_NAME -f
        ;;
    update)
        echo "Updating FlowAI-ICT Bot..."
        bash scripts/update_bot.sh
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac
EOF
    
    chmod +x manage.sh
    
    success "Utility scripts created"
}

# Final testing
final_testing() {
    progress "Running final tests..."
    
    cd "$INSTALL_DIR"
    source venv/bin/activate
    
    # Test Python imports
    python3 -c "
import sys
sys.path.insert(0, '.')

try:
    import pandas as pd
    import numpy as np
    import telegram
    import ta
    from flow_ai_core import config
    print('✓ All critical imports successful')
except ImportError as e:
    print(f'✗ Import error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'✗ Configuration error: {e}')
    sys.exit(1)
" || error_exit "Python import tests failed"
    
    success "All tests passed"
}

# Main installation function
main() {
    local install_type=$(detect_installation_type)
    
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                FlowAI-ICT Trading Bot v4.5                  ║"
    echo "║              Installation & Update Script                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [[ "$install_type" == "update" ]]; then
        echo -e "${YELLOW}Existing installation detected. Performing update...${NC}"
    else
        echo -e "${GREEN}Fresh installation starting...${NC}"
    fi
    
    log "=== FlowAI-ICT Bot Installation Started (Type: $install_type) ==="
    
    # Pre-installation checks
    check_root
    check_requirements
    
    # Backup if updating
    if [[ "$install_type" == "update" ]]; then
        backup_installation
        stop_service
    fi
    
    # Main installation steps
    setup_repository
    setup_virtual_environment
    install_dependencies
    setup_directories
    setup_configuration
    fix_ict_variables
    fix_circular_import
    setup_update_system
    setup_service
    create_utility_scripts
    final_testing
    
    # Start service
    sudo systemctl start $SERVICE_NAME
    
    echo -e "${GREEN}"
    echo "🎉 Installation Completed! 🎉"
    echo -e "${NC}"
    
    echo "📋 Installation Summary:"
    echo "✓ Project installed to: $INSTALL_DIR"
    echo "✓ Virtual environment created"
    echo "✓ All dependencies installed"
    echo "✓ Configuration $(if [[ "$install_type" == "update" ]]; then echo "restored"; else echo "created"; fi)"
    echo "✓ ICT variables added"
    echo "✓ Circular import issues fixed"
    echo "✓ Auto-update system configured"
    echo "✓ System service configured"
    echo "✓ Utility scripts created"
    echo ""
    echo "🚀 Quick Start:"
    echo "  sudo systemctl start $SERVICE_NAME"
    echo "  sudo systemctl status $SERVICE_NAME"
    echo ""
    echo "📊 Management Commands:"
    echo "  ./manage.sh start|stop|restart|status|logs|update"
    echo ""
    echo "🔄 Auto-Update Commands (via Telegram):"
    echo "  /update - Check for updates"
    echo "  /confirm_update - Apply updates"
    echo ""
    if [[ "$install_type" == "install" ]]; then
        echo -e "${YELLOW}⚠️  Don't forget to edit .env file with your bot token and admin IDs!${NC}"
    fi
    
    log "=== FlowAI-ICT Bot Installation Completed ==="
}

# Handle script interruption
trap 'error_exit "Installation interrupted by user"' INT TERM

# Run main function
main "$@"
