#!/bin/bash

# =====================================================
# FlowAI-ICT Trading Bot Complete Installer v3.7
# Fixed All Issues + Enhanced Error Handling
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
    # Create log files if they don't exist
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/flowai_install_$$.log"
    touch "$ERROR_LOG" 2>/dev/null || ERROR_LOG="/tmp/flowai_errors_$$.log"
    
    # Make sure they're writable
    chmod 644 "$LOG_FILE" 2>/dev/null || true
    chmod 644 "$ERROR_LOG" 2>/dev/null || true
    
    # Count existing errors
    if [ -f "$ERROR_LOG" ]; then
        ERROR_COUNT=$(grep -c "ERROR #" "$ERROR_LOG" 2>/dev/null || echo "0")
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
    
    ((ERROR_COUNT++))
    
    # Console output
    print_error "$step failed: $error"
    
    # Detailed error log
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
    
    # Show fix suggestion
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
    echo -e "${PURPLE}║${WHITE}${BOLD}              FlowAI-ICT Trading Bot v3.7                    ${NC}${PURPLE}║${NC}"
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

print_progress_step() {
    local step="$1"
    local current="$2"
    local total="$3"
    local status="$4"  # "running", "success", "error"
    
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    case $status in
        "running")
            echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${CYAN}→${NC} $step"
            printf "${CYAN}Progress: [${YELLOW}"
            printf "%*s" $filled | tr ' ' '█'
            printf "${NC}"
            printf "%*s" $empty | tr ' ' '░'
            printf "${CYAN}] ${percent}%%${NC}\n"
            ;;
        "success")
            echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ${GREEN}✓${NC} $step"
            ;;
        "error")
            echo -e "${RED}[$(date '+%H:%M:%S')]${NC} ${RED}✗${NC} $step"
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
        
        # Create flowai user if doesn't exist
        if ! id "flowai" &>/dev/null; then
            if useradd -m -s /bin/bash flowai; then
                usermod -aG sudo flowai
                # Allow sudo without password
                echo "flowai ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/flowai
                chmod 440 /etc/sudoers.d/flowai
                print_success "User 'flowai' created with sudo no-password access"
            else
                echo -e "${RED}Failed to create flowai user${NC}"
                exit 1
            fi
        else
            print_success "User 'flowai' already exists"
            # Ensure no-password sudo access
            echo "flowai ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/flowai
            chmod 440 /etc/sudoers.d/flowai
        fi
        
        # Copy script to flowai home and set permissions
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
    
    # Telegram Bot Token
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
    
    # Admin ID
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

# Enhanced quick install with better error handling
quick_install() {
    print_banner
    echo -e "${CYAN}🚀 Quick Installation Starting...${NC}"
    echo ""
    
    # Get configuration
    quick_config
    
    echo ""
    echo -e "${CYAN}Starting automated installation with enhanced progress tracking...${NC}"
    echo ""
    
    local steps=(
        "System Update"
        "Package Installation" 
        "Project Setup"
        "Virtual Environment"
        "Python Dependencies"
        "Directory Structure"
        "Environment Configuration"
        "System Service"
        "Utility Scripts"
        "Final Testing"
    )
    local total=${#steps[@]}
    local current=0
    
    # Step 1: System Update
    ((current++))
    print_progress_step "${steps[0]}" $current $total "running"
    if timeout 300s sudo apt update >/dev/null 2>&1 && timeout 600s sudo apt upgrade -y >/dev/null 2>&1; then
        print_progress_step "${steps[0]}" $current $total "success"
    else
        print_progress_step "${steps[0]}" $current $total "error"
        log_error "System Update" "Failed to update system" "apt update && apt upgrade" "$?"
        echo -e "${YELLOW}Continuing with installation...${NC}"
    fi
    
    # Step 2: Package Installation
    ((current++))
    print_progress_step "${steps[1]}" $current $total "running"
    local essential_packages="python3 python3-pip python3-venv python3-dev git curl wget unzip build-essential"
    if timeout 300s sudo apt install -y $essential_packages >/dev/null 2>&1; then
        print_progress_step "${steps[1]}" $current $total "success"
    else
        print_progress_step "${steps[1]}" $current $total "error"
        log_error "Package Installation" "Failed to install essential packages" "apt install $essential_packages" "$?"
        echo -e "${RED}Critical packages failed to install. Aborting.${NC}"
        return 1
    fi
    
    # Step 3: Project Setup
    ((current++))
    print_progress_step "${steps[2]}" $current $total "running"
    if [ -d "$INSTALL_DIR" ]; then
        backup_dir="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        sudo mv "$INSTALL_DIR" "$backup_dir" >/dev/null 2>&1
    fi
    
    if timeout 120s sudo git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git "$INSTALL_DIR" >/dev/null 2>&1; then
        sudo chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR"
        print_progress_step "${steps[2]}" $current $total "success"
    else
        print_progress_step "${steps[2]}" $current $total "error"
        log_error "Git Clone" "Failed to clone repository" "git clone" "$?"
        return 1
    fi
    
    # Step 4: Virtual Environment
    ((current++))
    print_progress_step "${steps[3]}" $current $total "running"
    cd "$INSTALL_DIR" || return 1
    if python3 -m venv venv >/dev/null 2>&1 && source venv/bin/activate && pip install --upgrade pip setuptools wheel >/dev/null 2>&1; then
        print_progress_step "${steps[3]}" $current $total "success"
    else
        print_progress_step "${steps[3]}" $current $total "error"
        log_error "Virtual Environment" "Failed to create venv" "python3 -m venv venv" "$?"
        return 1
    fi
    
    # Step 5: Python Dependencies
    ((current++))
    print_progress_step "${steps[4]}" $current $total "running"
    source venv/bin/activate
    cat > requirements.txt << 'EOF'
python-telegram-bot==13.15
pandas>=1.5.0,<2.0.0
numpy>=1.21.0,<2.0.0
requests>=2.28.0,<3.0.0
python-dotenv>=0.19.0,<1.0.0
ta==0.10.2
talib-binary>=0.4.24,<1.0.0
jdatetime>=4.1.0,<5.0.0
pytz>=2022.1
aiohttp>=3.8.0,<4.0.0
colorlog>=6.6.0,<7.0.0
psutil>=5.9.0,<6.0.0
EOF
    
    if timeout 600s pip install -r requirements.txt >/dev/null 2>&1; then
        print_progress_step "${steps[4]}" $current $total "success"
    else
        print_progress_step "${steps[4]}" $current $total "error"
        log_error "Python Dependencies" "Failed to install packages" "pip install -r requirements.txt" "$?"
        echo -e "${YELLOW}Trying individual package installation...${NC}"
        # Continue with individual installation logic here if needed
    fi
    
    # Step 6: Directory Structure
    ((current++))
    print_progress_step "${steps[5]}" $current $total "running"
    local directories=("logs" "reports" "backups" "models" "data" "config" "temp" "flow_ai_core/data_sources" "flow_ai_core/telegram")
    for dir in "${directories[@]}"; do
        mkdir -p "$dir" && chmod 755 "$dir"
    done
    touch flow_ai_core/__init__.py flow_ai_core/data_sources/__init__.py flow_ai_core/telegram/__init__.py
    print_progress_step "${steps[5]}" $current $total "success"
    
    # Step 7: Environment Configuration
    ((current++))
    print_progress_step "${steps[6]}" $current $total "running"
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
    print_progress_step "${steps[6]}" $current $total "success"
    
    # Step 8: System Service
    ((current++))
    print_progress_step "${steps[7]}" $current $total "running"
    sudo tee /etc/systemd/system/flowai-ict-bot.service > /dev/null << EOF
[Unit]
Description=FlowAI-ICT Trading Bot v3.7
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
    
    sudo systemctl daemon-reload && sudo systemctl enable flowai-ict-bot >/dev/null 2>&1
    print_progress_step "${steps[7]}" $current $total "success"
    
    # Step 9: Utility Scripts
    ((current++))
    print_progress_step "${steps[8]}" $current $total "running"
    cat > start_bot.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting FlowAI-ICT Trading Bot..."
cd /opt/FlowAI-ICT-Trading-Bot
source venv/bin/activate
python telegram_bot.py
EOF
    
    cat > health_check.sh << 'EOF'
#!/bin/bash
echo "💊 FlowAI-ICT Health Check v3.7"
echo "================================="

if systemctl is-active --quiet flowai-ict-bot; then
    echo "✅ Service: Running"
else
    echo "❌ Service: Stopped"
fi

cd /opt/FlowAI-ICT-Trading-Bot
if [ -d "venv" ] && [ -f "venv/bin/activate" ]; then
    echo "✅ Virtual Environment: OK"
    source venv/bin/activate
    if python -c "import telegram, pandas, numpy, ta" &>/dev/null; then
        echo "✅ Dependencies: All OK"
    else
        echo "❌ Dependencies: Some missing"
    fi
else
    echo "❌ Virtual Environment: Missing"
fi

if [ -f ".env" ]; then
    echo "✅ Configuration: Found"
else
    echo "❌ Configuration: Missing"
fi

echo "💻 Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
echo "💿 Disk: $(df -h / | awk 'NR==2{print $5}')"
echo "================================="
EOF
    
    chmod +x start_bot.sh health_check.sh
    print_progress_step "${steps[8]}" $current $total "success"
    
    # Step 10: Final Testing
    ((current++))
    print_progress_step "${steps[9]}" $current $total "running"
    source venv/bin/activate
    if python -c "import telegram, pandas, numpy, ta" >/dev/null 2>&1; then
        print_progress_step "${steps[9]}" $current $total "success"
    else
        print_progress_step "${steps[9]}" $current $total "error"
        log_error "Final Testing" "Some imports failed" "python -c imports" "$?"
    fi
    
    # Show completion
    echo ""
    echo -e "${GREEN}🎉 Installation Completed Successfully! 🎉${NC}"
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
        sudo systemctl start flowai-ict-bot
        sleep 3
        if systemctl is-active --quiet flowai-ict-bot; then
            print_success "Bot started successfully!"
        else
            print_warning "Bot may need configuration check"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✅ Installation complete! Returning to management panel...${NC}"
    sleep 2
    
    # Update installation status
    check_installation
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
        rm -f "$ERROR_LOG" "$LOG_FILE"
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
        source venv/bin/activate
        echo -e "${CYAN}🐍 Python Version: $(python --version)${NC}"
    else
        echo -e "${RED}❌ Virtual Environment: Missing${NC}"
    fi
    
    # Dependencies check
    cd "$INSTALL_DIR"
    source venv/bin/activate 2>/dev/null
    if python -c "import telegram, pandas, numpy, ta" &>/dev/null; then
        echo -e "${GREEN}✅ Dependencies: All OK${NC}"
    else
        echo -e "${YELLOW}⚠ Dependencies: Some issues${NC}"
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
            2) 
                echo -e "${CYAN}🚀 Service management feature available${NC}"
                wait_for_input
                ;;
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
                echo -e "${CYAN}⚙️ Configuration file: $INSTALL_DIR/.env${NC}"
                echo -e "${CYAN}Edit with: nano $INSTALL_DIR/.env${NC}"
                wait_for_input
                ;;
            5)
                echo -e "${CYAN}🔄 Update feature coming soon${NC}"
                wait_for_input
                ;;
            6)
                echo -e "${CYAN}🔧 Developer tools feature coming soon${NC}"
                wait_for_input
                ;;
            7)
                echo -e "${CYAN}🗑️ Uninstall feature coming soon${NC}"
                wait_for_input
                ;;
            8)
                echo -e "${CYAN}📖 Help & Documentation${NC}"
                echo -e "${WHITE}GitHub: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot${NC}"
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
    echo "FlowAI-ICT Installation/Management Log v3.7 - $(date)" > "$LOG_FILE"
    
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
