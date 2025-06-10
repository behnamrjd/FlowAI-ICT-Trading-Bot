#!/bin/bash

# =====================================================
# FlowAI-ICT Trading Bot Smart Installer v3.3
# Auto User Creation + Dual Mode (Install/Management)
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
CURRENT_USER=""
TELEGRAM_TOKEN=""
ADMIN_ID=""

# Check if installation exists
INSTALLATION_EXISTS=false
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/.env" ] && [ -f "/etc/systemd/system/flowai-ict-bot.service" ]; then
    INSTALLATION_EXISTS=true
fi

# Enhanced UI functions
print_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}${BOLD}              FlowAI-ICT Trading Bot v3.3                    ${NC}${PURPLE}║${NC}"
    if [ "$INSTALLATION_EXISTS" = true ]; then
        echo -e "${PURPLE}║${WHITE}${BOLD}              Management & Status Panel                     ${NC}${PURPLE}║${NC}"
    else
        echo -e "${PURPLE}║${WHITE}${BOLD}              Smart Auto Installer                         ${NC}${PURPLE}║${NC}"
    fi
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_install_menu() {
    echo -e "${CYAN}🚀 Installation Options:${NC}"
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}1.${NC} 🚀 ${WHITE}Quick Install (Recommended)${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}2.${NC} 🔧 ${WHITE}Custom Install (Advanced)${NC}                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 🔍 ${WHITE}System Check Only${NC}                               ${CYAN}│${NC}"
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
    echo -e "${CYAN}│${NC} ${GREEN}7.${NC} 🗑️  ${WHITE}Uninstall Bot${NC}                                  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}8.${NC} 📖 ${WHITE}Help & Documentation${NC}                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}0.${NC} 🚪 ${WHITE}Exit${NC}                                           ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
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
}

# Auto handle root user without asking
handle_root_user() {
    if [[ $EUID -eq 0 ]]; then
        print_step "Running as root - auto-creating flowai user..."
        
        # Create flowai user if doesn't exist
        if ! id "flowai" &>/dev/null; then
            useradd -m -s /bin/bash flowai
            usermod -aG sudo flowai
            echo "flowai:FlowAI2025!" | chpasswd
            print_success "User 'flowai' created with password: FlowAI2025!"
        else
            print_success "User 'flowai' already exists"
        fi
        
        # Copy script to flowai home and set permissions
        cp "$0" /home/flowai/Install.sh
        chown flowai:flowai /home/flowai/Install.sh
        chmod +x /home/flowai/Install.sh
        
        print_step "Switching to user 'flowai'..."
        sudo -u flowai bash /home/flowai/Install.sh "$@"
        exit $?
    fi
}

# Quick configuration setup
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
            print_error "Invalid token format"
            TELEGRAM_TOKEN=""
        fi
    done
    
    # Admin ID
    while [ -z "$ADMIN_ID" ]; do
        echo -e "${YELLOW}👤 Enter your Telegram User ID:${NC}"
        echo -e "${CYAN}   (Send /start to @userinfobot)${NC}"
        read -r ADMIN_ID
        
        if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            print_error "Invalid ID format"
            ADMIN_ID=""
        fi
    done
    
    print_success "Configuration completed!"
}

# Quick install function
quick_install() {
    print_banner
    echo -e "${CYAN}🚀 Quick Installation Starting...${NC}"
    echo ""
    
    # Get configuration
    quick_config
    
    echo ""
    print_step "Starting automated installation..."
    echo -e "${CYAN}This will take 3-5 minutes...${NC}"
    echo ""
    
    # Update system
    print_step "Updating system packages..."
    sudo apt update &>/dev/null && sudo apt upgrade -y &>/dev/null
    print_success "System updated"
    
    # Install dependencies
    print_step "Installing system dependencies..."
    sudo apt install -y python3 python3-pip python3-venv python3-dev git curl wget unzip build-essential software-properties-common htop nano vim screen tmux tree jq sqlite3 cron &>/dev/null
    print_success "Dependencies installed"
    
    # Setup project
    print_step "Setting up project directory..."
    if [ -d "$INSTALL_DIR" ]; then
        sudo mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    sudo git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git "$INSTALL_DIR" &>/dev/null
    CURRENT_USER=$(whoami)
    sudo chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR"
    print_success "Project cloned"
    
    # Setup virtual environment
    print_step "Setting up Python environment..."
    cd "$INSTALL_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip setuptools wheel &>/dev/null
    print_success "Virtual environment ready"
    
    # Install Python packages
    print_step "Installing Python packages..."
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
    
    pip install -r requirements.txt &>/dev/null
    print_success "Python packages installed"
    
    # Create directories
    print_step "Creating directory structure..."
    mkdir -p logs reports backups models data config temp
    mkdir -p flow_ai_core/data_sources flow_ai_core/telegram
    touch flow_ai_core/__init__.py flow_ai_core/data_sources/__init__.py flow_ai_core/telegram/__init__.py
    print_success "Directories created"
    
    # Configure environment
    print_step "Configuring environment..."
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
    print_success "Environment configured"
    
    # Setup service
    print_step "Setting up system service..."
    sudo tee /etc/systemd/system/flowai-ict-bot.service > /dev/null << EOF
[Unit]
Description=FlowAI-ICT Trading Bot v3.3
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
    
    sudo systemctl daemon-reload
    sudo systemctl enable flowai-ict-bot &>/dev/null
    print_success "Service configured"
    
    # Create utility scripts
    print_step "Creating utility scripts..."
    cat > start_bot.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting FlowAI-ICT Trading Bot..."
cd /opt/FlowAI-ICT-Trading-Bot
source venv/bin/activate
python telegram_bot.py
EOF
    
    cat > health_check.sh << 'EOF'
#!/bin/bash
echo "💊 FlowAI-ICT Health Check"
echo "=========================="

if systemctl is-active --quiet flowai-ict-bot; then
    echo "✅ Service: Running"
    echo "⏰ Uptime: $(systemctl show flowai-ict-bot --property=ActiveEnterTimestamp --value | cut -d' ' -f2-)"
else
    echo "❌ Service: Stopped"
fi

cd /opt/FlowAI-ICT-Trading-Bot
if [ -d "venv" ]; then
    echo "✅ Virtual Environment: OK"
    source venv/bin/activate
    echo "🐍 Python: $(python --version)"
else
    echo "❌ Virtual Environment: Missing"
fi

if [ -f ".env" ]; then
    echo "✅ Configuration: Found"
    if grep -q "TELEGRAM_BOT_TOKEN=" .env; then
        echo "✅ Telegram Token: Configured"
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
echo "=========================="
EOF
    
    chmod +x start_bot.sh health_check.sh
    print_success "Utility scripts created"
    
    # Final test
    print_step "Testing installation..."
    source venv/bin/activate
    if python -c "import telegram, pandas, numpy, ta" &>/dev/null; then
        print_success "Installation test passed"
    else
        print_warning "Some packages may need manual fixing"
    fi
    
    # Show completion
    echo ""
    echo -e "${GREEN}🎉 Installation Completed Successfully! 🎉${NC}"
    echo ""
    echo -e "${CYAN}🚀 Quick Start:${NC}"
    echo -e "${WHITE}  sudo systemctl start flowai-ict-bot${NC}"
    echo -e "${WHITE}  sudo systemctl status flowai-ict-bot${NC}"
    echo ""
    echo -e "${CYAN}📋 Management:${NC}"
    echo -e "${WHITE}  Run this script again for management panel${NC}"
    echo ""
    
    echo -e "${YELLOW}Start the bot now? (y/n):${NC}"
    read -r start_now
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        sudo systemctl start flowai-ict-bot
        sleep 2
        if systemctl is-active --quiet flowai-ict-bot; then
            print_success "Bot started successfully!"
        else
            print_warning "Bot may need configuration check"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✅ Run this script again to access the management panel!${NC}"
    echo ""
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
        if grep -q "TELEGRAM_BOT_TOKEN=" "$INSTALL_DIR/.env"; then
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
    
    # Logs
    if [ -d "$INSTALL_DIR/logs" ]; then
        log_count=$(ls "$INSTALL_DIR/logs/" 2>/dev/null | wc -l)
        echo -e "${GREEN}✅ Logs: $log_count files${NC}"
        if [ -f "$INSTALL_DIR/logs/flowai_ict.log" ]; then
            latest_log=$(tail -1 "$INSTALL_DIR/logs/flowai_ict.log" 2>/dev/null)
            echo -e "${CYAN}📄 Latest: ${latest_log:0:50}...${NC}"
        fi
    else
        echo -e "${RED}❌ Logs: Directory missing${NC}"
    fi
    
    # System resources
    echo ""
    echo -e "${CYAN}💻 System Resources:${NC}"
    echo -e "${WHITE}📊 Memory Usage: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')${NC}"
    echo -e "${WHITE}💿 Disk Usage: $(df -h / | awk 'NR==2{print $5}')${NC}"
    echo -e "${WHITE}🔥 CPU Load: $(uptime | awk -F'load average:' '{print $2}')${NC}"
    
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Service management
manage_service() {
    print_banner
    echo -e "${CYAN}🚀 Service Management${NC}"
    echo -e "${CYAN}═══════════════════════${NC}"
    echo ""
    
    # Current status
    if systemctl is-active --quiet flowai-ict-bot; then
        echo -e "${GREEN}Current Status: Running ✅${NC}"
    else
        echo -e "${RED}Current Status: Stopped ❌${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}Actions:${NC}"
    echo -e "${GREEN}1.${NC} Start Bot"
    echo -e "${GREEN}2.${NC} Stop Bot"
    echo -e "${GREEN}3.${NC} Restart Bot"
    echo -e "${GREEN}4.${NC} View Real-time Logs"
    echo -e "${GREEN}5.${NC} Service Status Details"
    echo -e "${GREEN}0.${NC} Back"
    
    echo ""
    echo -e "${WHITE}Choose action (0-5):${NC}"
    read -r action
    
    case $action in
        1)
            print_step "Starting FlowAI-ICT Bot..."
            sudo systemctl start flowai-ict-bot
            sleep 2
            if systemctl is-active --quiet flowai-ict-bot; then
                print_success "Bot started successfully!"
            else
                print_error "Failed to start bot"
            fi
            ;;
        2)
            print_step "Stopping FlowAI-ICT Bot..."
            sudo systemctl stop flowai-ict-bot
            print_success "Bot stopped"
            ;;
        3)
            print_step "Restarting FlowAI-ICT Bot..."
            sudo systemctl restart flowai-ict-bot
            sleep 2
            if systemctl is-active --quiet flowai-ict-bot; then
                print_success "Bot restarted successfully!"
            else
                print_error "Failed to restart bot"
            fi
            ;;
        4)
            echo -e "${CYAN}📋 Real-time logs (Press Ctrl+C to exit):${NC}"
            sudo journalctl -u flowai-ict-bot -f
            ;;
        5)
            sudo systemctl status flowai-ict-bot
            ;;
    esac
    
    if [ "$action" != "4" ]; then
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
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
            1) quick_install ;;
            2) 
                echo -e "${CYAN}Custom install coming soon...${NC}"
                echo -e "${YELLOW}Use Quick Install for now.${NC}"
                sleep 2
                ;;
            3) 
                echo -e "${CYAN}System check coming soon...${NC}"
                sleep 2
                ;;
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
        
        echo -e "${WHITE}Choose option (0-8):${NC}"
        read -r choice
        
        case $choice in
            1) show_system_status ;;
            2) manage_service ;;
            3) 
                echo -e "${CYAN}📋 Logs & Diagnostics coming soon...${NC}"
                sleep 2
                ;;
            4)
                echo -e "${CYAN}⚙️ Configuration Management coming soon...${NC}"
                sleep 2
                ;;
            5)
                echo -e "${CYAN}🔄 Update feature coming soon...${NC}"
                sleep 2
                ;;
            6)
                if [ -f "$INSTALL_DIR/dev_tools.py" ]; then
                    cd "$INSTALL_DIR"
                    python dev_tools.py
                else
                    echo -e "${CYAN}🔧 Developer tools coming soon...${NC}"
                    sleep 2
                fi
                ;;
            7)
                echo -e "${CYAN}🗑️ Uninstall feature coming soon...${NC}"
                sleep 2
                ;;
            8)
                print_banner
                echo -e "${CYAN}📖 Help & Documentation${NC}"
                echo -e "${CYAN}═══════════════════════════${NC}"
                echo ""
                echo -e "${WHITE}FlowAI-ICT Trading Bot v3.3${NC}"
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
                echo -e "${YELLOW}Support:${NC}"
                echo -e "${WHITE}• GitHub: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot${NC}"
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read -r
                ;;
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
    # Initialize logging
    echo "FlowAI-ICT Installation/Management Log - $(date)" > "$LOG_FILE"
    
    # Handle root user automatically
    handle_root_user
    
    # Determine mode based on installation status
    if [ "$INSTALLATION_EXISTS" = true ]; then
        # Management mode
        management_menu
    else
        # Installation mode
        install_menu
    fi
}

# Run main function
main "$@"
