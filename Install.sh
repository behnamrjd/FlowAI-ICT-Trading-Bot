#!/bin/bash

# =====================================================
# FlowAI-ICT Trading Bot Interactive Installer v3.2
# Menu-Based Installation with User Control
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

# Enhanced UI functions
print_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}${BOLD}              FlowAI-ICT Trading Bot v3.2                    ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}║${WHITE}${BOLD}              Interactive Menu Installer                   ${NC}${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}🎯 ICT Features:${NC}"
    echo -e "${WHITE}  • Order Block Detection & Analysis${NC}"
    echo -e "${WHITE}  • Fair Value Gap Identification${NC}"
    echo -e "${WHITE}  • Liquidity Sweep Detection${NC}"
    echo -e "${WHITE}  • Market Structure Analysis${NC}"
    echo -e "${WHITE}  • AI-Powered Signal Generation${NC}"
    echo -e "${WHITE}  • Real-time BrsAPI Integration${NC}"
    echo -e "${WHITE}  • Advanced Risk Management${NC}"
    echo -e "${WHITE}  • Telegram Bot Interface${NC}"
    echo ""
}

print_main_menu() {
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${WHITE}${BOLD}                    Main Installation Menu                   ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}1.${NC} 🚀 ${WHITE}Full Automatic Installation${NC}                      ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}2.${NC} 🔧 ${WHITE}Custom Installation (Step by Step)${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 🔍 ${WHITE}System Requirements Check${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}4.${NC} ⚙️  ${WHITE}Configuration Only${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}5.${NC} 🔄 ${WHITE}Update Existing Installation${NC}                   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}6.${NC} 🗑️  ${WHITE}Uninstall FlowAI-ICT${NC}                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}7.${NC} 💊 ${WHITE}Health Check & Diagnostics${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}8.${NC} 📋 ${WHITE}View Installation Log${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}9.${NC} ❓ ${WHITE}Help & Documentation${NC}                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}0.${NC} 🚪 ${WHITE}Exit${NC}                                           ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

print_step_menu() {
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${WHITE}${BOLD}                 Step-by-Step Installation                  ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}1.${NC} 🔍 ${WHITE}Check System Requirements${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}2.${NC} 📦 ${WHITE}Install System Dependencies${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 📁 ${WHITE}Setup Project Directory${NC}                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}4.${NC} 🐍 ${WHITE}Setup Python Virtual Environment${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}5.${NC} 📚 ${WHITE}Install Python Dependencies${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}6.${NC} ⚙️  ${WHITE}Configure Environment${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}7.${NC} 🔧 ${WHITE}Setup System Service${NC}                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}8.${NC} 🧪 ${WHITE}Test Installation${NC}                              ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}9.${NC} 🔙 ${WHITE}Back to Main Menu${NC}                              ${CYAN}│${NC}"
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

# Wait for user input
wait_for_input() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# System requirements check
check_system_requirements() {
    print_banner
    echo -e "${CYAN}🔍 System Requirements Check${NC}"
    echo -e "${CYAN}═══════════════════════════${NC}"
    echo ""
    
    local all_good=true
    
    # Check OS
    print_step "Checking operating system..."
    if [[ "$OSTYPE" =~ linux-gnu.* ]]; then
        print_success "Linux system detected: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
    else
        print_error "This installer requires Linux"
        all_good=false
    fi
    
    # Check user
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root - will create non-root user"
    else
        print_success "Running as non-root user: $(whoami)"
    fi
    
    # Check internet
    print_step "Testing internet connectivity..."
    if ping -c 1 google.com &>/dev/null; then
        print_success "Internet connection verified"
    else
        print_error "No internet connection"
        all_good=false
    fi
    
    # Check disk space
    print_step "Checking disk space..."
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -gt 1048576 ]; then
        print_success "Sufficient disk space: $(df -h / | awk 'NR==2{print $4}') available"
    else
        print_error "Insufficient disk space (need at least 1GB)"
        all_good=false
    fi
    
    # Check Python
    print_step "Checking Python installation..."
    if command -v python3 &>/dev/null; then
        python_version=$(python3 --version | cut -d' ' -f2)
        print_success "Python $python_version found"
    else
        print_warning "Python3 not found - will be installed"
    fi
    
    # Check Git
    print_step "Checking Git installation..."
    if command -v git &>/dev/null; then
        git_version=$(git --version | cut -d' ' -f3)
        print_success "Git $git_version found"
    else
        print_warning "Git not found - will be installed"
    fi
    
    echo ""
    if [ "$all_good" = true ]; then
        print_success "All system requirements met!"
    else
        print_error "Some requirements not met - installation may fail"
    fi
    
    wait_for_input
}

# Configuration setup
setup_configuration() {
    print_banner
    echo -e "${CYAN}⚙️ Bot Configuration Setup${NC}"
    echo -e "${CYAN}═══════════════════════════${NC}"
    echo ""
    
    # Telegram Bot Token
    while [ -z "$TELEGRAM_TOKEN" ]; do
        echo -e "${YELLOW}📱 Telegram Bot Token:${NC}"
        echo -e "${CYAN}   1. Go to @BotFather on Telegram${NC}"
        echo -e "${CYAN}   2. Create a new bot with /newbot${NC}"
        echo -e "${CYAN}   3. Copy the token here${NC}"
        echo ""
        echo -e "${WHITE}Enter your Telegram Bot Token:${NC}"
        read -r TELEGRAM_TOKEN
        
        if [ ${#TELEGRAM_TOKEN} -lt 40 ]; then
            print_error "Invalid token format (too short)"
            TELEGRAM_TOKEN=""
        else
            print_success "Telegram token configured"
        fi
    done
    
    # Admin ID
    while [ -z "$ADMIN_ID" ]; do
        echo ""
        echo -e "${YELLOW}👤 Admin User ID:${NC}"
        echo -e "${CYAN}   1. Send /start to @userinfobot on Telegram${NC}"
        echo -e "${CYAN}   2. Copy your numeric ID${NC}"
        echo ""
        echo -e "${WHITE}Enter your Telegram User ID:${NC}"
        read -r ADMIN_ID
        
        if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            print_error "Invalid ID format (must be numeric)"
            ADMIN_ID=""
        else
            print_success "Admin ID configured"
        fi
    done
    
    echo ""
    print_success "Configuration completed successfully!"
    wait_for_input
}

# Install system dependencies
install_system_dependencies() {
    print_banner
    echo -e "${CYAN}📦 Installing System Dependencies${NC}"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
    echo ""
    
    print_step "Updating package lists..."
    if sudo apt update; then
        print_success "Package lists updated"
    else
        print_error "Failed to update package lists"
        return 1
    fi
    
    local packages=(
        "python3" "python3-pip" "python3-venv" "python3-dev"
        "git" "curl" "wget" "unzip" "build-essential"
        "software-properties-common" "htop" "nano" "vim"
        "screen" "tmux" "tree" "jq" "sqlite3" "cron"
    )
    
    print_step "Installing essential packages..."
    for package in "${packages[@]}"; do
        echo -e "${CYAN}  Installing $package...${NC}"
        if sudo apt install -y "$package"; then
            echo -e "${GREEN}    ✓ $package installed${NC}"
        else
            echo -e "${YELLOW}    ⚠ $package installation failed${NC}"
        fi
    done
    
    print_success "System dependencies installation completed"
    wait_for_input
}

# Setup project directory
setup_project_directory() {
    print_banner
    echo -e "${CYAN}📁 Setting Up Project Directory${NC}"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
    echo ""
    
    # Handle existing installation
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}⚠ Existing installation found at $INSTALL_DIR${NC}"
        echo -e "${WHITE}What would you like to do?${NC}"
        echo -e "${GREEN}1.${NC} Backup and replace"
        echo -e "${GREEN}2.${NC} Update existing"
        echo -e "${GREEN}3.${NC} Cancel"
        echo ""
        echo -e "${WHITE}Choose option (1-3):${NC}"
        read -r choice
        
        case $choice in
            1)
                backup_dir="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
                print_step "Creating backup at $backup_dir"
                sudo mv "$INSTALL_DIR" "$backup_dir"
                print_success "Backup created"
                ;;
            2)
                print_step "Updating existing installation..."
                cd "$INSTALL_DIR"
                git pull origin main
                print_success "Project updated"
                wait_for_input
                return 0
                ;;
            3)
                print_warning "Operation cancelled"
                wait_for_input
                return 1
                ;;
        esac
    fi
    
    # Clone repository
    print_step "Cloning FlowAI-ICT repository..."
    if sudo git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git "$INSTALL_DIR"; then
        print_success "Repository cloned successfully"
    else
        print_error "Failed to clone repository"
        wait_for_input
        return 1
    fi
    
    # Set ownership
    print_step "Setting ownership and permissions..."
    CURRENT_USER=$(whoami)
    sudo chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    print_success "Ownership configured"
    
    wait_for_input
}

# Setup virtual environment
setup_virtual_environment() {
    print_banner
    echo -e "${CYAN}🐍 Setting Up Python Virtual Environment${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""
    
    cd "$INSTALL_DIR" || return 1
    
    # Create virtual environment
    print_step "Creating Python virtual environment..."
    if python3 -m venv venv; then
        print_success "Virtual environment created"
    else
        print_error "Failed to create virtual environment"
        wait_for_input
        return 1
    fi
    
    # Activate and upgrade
    print_step "Activating virtual environment..."
    source venv/bin/activate
    print_success "Virtual environment activated"
    
    print_step "Upgrading pip and setuptools..."
    pip install --upgrade pip setuptools wheel
    print_success "Pip upgraded"
    
    wait_for_input
}

# Install Python dependencies
install_python_dependencies() {
    print_banner
    echo -e "${CYAN}📚 Installing Python Dependencies${NC}"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
    echo ""
    
    cd "$INSTALL_DIR" || return 1
    source venv/bin/activate
    
    # Create requirements.txt
    print_step "Creating requirements.txt..."
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
    print_success "Requirements file created"
    
    # Install dependencies
    print_step "Installing Python packages..."
    echo -e "${CYAN}This may take a few minutes...${NC}"
    
    if pip install -r requirements.txt; then
        print_success "All Python dependencies installed successfully"
    else
        print_error "Some dependencies failed to install"
        echo -e "${YELLOW}Attempting individual installation...${NC}"
        
        # Try individual installation
        pip install python-telegram-bot==13.15
        pip install pandas numpy requests python-dotenv
        pip install ta==0.10.2 talib-binary
        pip install jdatetime pytz aiohttp colorlog psutil
    fi
    
    # Verify installation
    print_step "Verifying installation..."
    if python -c "import telegram, pandas, numpy, ta; print('✓ All imports successful')"; then
        print_success "Installation verified"
    else
        print_warning "Some imports failed - may need manual fixing"
    fi
    
    wait_for_input
}

# Configure environment
configure_environment() {
    print_banner
    echo -e "${CYAN}⚙️ Configuring Environment${NC}"
    echo -e "${CYAN}═══════════════════════════${NC}"
    echo ""
    
    cd "$INSTALL_DIR" || return 1
    
    # Get configuration if not set
    if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
        setup_configuration
    fi
    
    # Create .env file
    print_step "Creating environment configuration..."
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
    
    print_success "Environment configuration created"
    
    # Create directories
    print_step "Creating necessary directories..."
    mkdir -p logs reports backups models data config temp
    mkdir -p flow_ai_core/data_sources flow_ai_core/telegram
    touch flow_ai_core/__init__.py flow_ai_core/data_sources/__init__.py flow_ai_core/telegram/__init__.py
    print_success "Directory structure created"
    
    wait_for_input
}

# Setup system service
setup_system_service() {
    print_banner
    echo -e "${CYAN}🔧 Setting Up System Service${NC}"
    echo -e "${CYAN}═══════════════════════════${NC}"
    echo ""
    
    CURRENT_USER=$(whoami)
    
    print_step "Creating systemd service..."
    sudo tee /etc/systemd/system/flowai-ict-bot.service > /dev/null << EOF
[Unit]
Description=FlowAI-ICT Trading Bot v3.2
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
    
    print_success "Service file created"
    
    print_step "Enabling service..."
    sudo systemctl daemon-reload
    sudo systemctl enable flowai-ict-bot
    print_success "Service enabled"
    
    # Create utility scripts
    print_step "Creating utility scripts..."
    
    # Start script
    cat > start_bot.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting FlowAI-ICT Trading Bot..."
cd /opt/FlowAI-ICT-Trading-Bot
source venv/bin/activate
python telegram_bot.py
EOF
    
    # Health check script
    cat > health_check.sh << 'EOF'
#!/bin/bash
echo "💊 FlowAI-ICT Health Check"
echo "=========================="

if systemctl is-active --quiet flowai-ict-bot; then
    echo "✅ Service: Running"
else
    echo "❌ Service: Stopped"
fi

cd /opt/FlowAI-ICT-Trading-Bot
if [ -d "venv" ]; then
    echo "✅ Virtual Environment: OK"
else
    echo "❌ Virtual Environment: Missing"
fi

if [ -f ".env" ]; then
    echo "✅ Configuration: Found"
else
    echo "❌ Configuration: Missing"
fi

echo "=========================="
EOF
    
    chmod +x start_bot.sh health_check.sh
    print_success "Utility scripts created"
    
    wait_for_input
}

# Test installation
test_installation() {
    print_banner
    echo -e "${CYAN}🧪 Testing Installation${NC}"
    echo -e "${CYAN}═══════════════════════${NC}"
    echo ""
    
    cd "$INSTALL_DIR" || return 1
    
    # Test virtual environment
    print_step "Testing virtual environment..."
    source venv/bin/activate
    if python -c "import sys; print(f'Python {sys.version}')"; then
        print_success "Virtual environment working"
    else
        print_error "Virtual environment test failed"
    fi
    
    # Test dependencies
    print_step "Testing Python dependencies..."
    if python -c "import telegram, pandas, numpy, ta; print('All imports successful')"; then
        print_success "Dependencies working"
    else
        print_error "Dependencies test failed"
    fi
    
    # Test configuration
    print_step "Testing configuration..."
    if python -c "from dotenv import load_dotenv; load_dotenv(); import os; assert os.getenv('TELEGRAM_BOT_TOKEN'); print('Configuration valid')"; then
        print_success "Configuration working"
    else
        print_error "Configuration test failed"
    fi
    
    # Test bot initialization
    print_step "Testing bot initialization..."
    timeout 5s python -c "
import sys
sys.path.append('.')
try:
    from flow_ai_core.config import TELEGRAM_BOT_TOKEN
    print('Bot configuration loaded successfully')
except Exception as e:
    print(f'Bot test failed: {e}')
" || print_warning "Bot test timed out (normal)"
    
    print_success "Installation testing completed"
    wait_for_input
}

# Full automatic installation
full_automatic_installation() {
    print_banner
    echo -e "${CYAN}🚀 Full Automatic Installation${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    
    print_step "Starting full automatic installation..."
    echo -e "${YELLOW}This will install everything automatically.${NC}"
    echo -e "${WHITE}Continue? (y/n):${NC}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Installation cancelled"
        return
    fi
    
    # Get configuration first
    setup_configuration
    
    # Run all steps
    local steps=(
        "check_system_requirements"
        "install_system_dependencies"
        "setup_project_directory"
        "setup_virtual_environment"
        "install_python_dependencies"
        "configure_environment"
        "setup_system_service"
        "test_installation"
    )
    
    for step in "${steps[@]}"; do
        echo ""
        print_step "Executing: $step"
        if ! $step; then
            print_error "Step failed: $step"
            echo -e "${WHITE}Continue anyway? (y/n):${NC}"
            read -r continue_choice
            if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                print_error "Installation aborted"
                return 1
            fi
        fi
    done
    
    # Show completion
    print_banner
    echo -e "${GREEN}🎉 Installation Completed Successfully! 🎉${NC}"
    echo ""
    echo -e "${CYAN}🚀 Quick Start:${NC}"
    echo -e "${WHITE}  sudo systemctl start flowai-ict-bot${NC}"
    echo -e "${WHITE}  sudo systemctl status flowai-ict-bot${NC}"
    echo ""
    echo -e "${CYAN}📋 Management Commands:${NC}"
    echo -e "${WHITE}  cd $INSTALL_DIR${NC}"
    echo -e "${WHITE}  ./health_check.sh${NC}"
    echo -e "${WHITE}  ./start_bot.sh${NC}"
    echo ""
    
    wait_for_input
}

# Step by step installation
step_by_step_installation() {
    while true; do
        print_banner
        print_step_menu
        
        echo -e "${WHITE}Choose step to execute (1-9):${NC}"
        read -r choice
        
        case $choice in
            1) check_system_requirements ;;
            2) install_system_dependencies ;;
            3) setup_project_directory ;;
            4) setup_virtual_environment ;;
            5) install_python_dependencies ;;
            6) configure_environment ;;
            7) setup_system_service ;;
            8) test_installation ;;
            9) break ;;
            *) 
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Health check
health_check() {
    print_banner
    echo -e "${CYAN}💊 Health Check & Diagnostics${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    
    if [ -f "$INSTALL_DIR/health_check.sh" ]; then
        cd "$INSTALL_DIR"
        ./health_check.sh
    else
        print_error "Health check script not found"
        print_step "Basic system check..."
        
        if systemctl is-active --quiet flowai-ict-bot; then
            print_success "Service is running"
        else
            print_warning "Service is not running"
        fi
        
        if [ -d "$INSTALL_DIR" ]; then
            print_success "Installation directory exists"
        else
            print_error "Installation directory not found"
        fi
    fi
    
    wait_for_input
}

# Main menu loop
main_menu() {
    while true; do
        print_banner
        print_main_menu
        
        echo -e "${WHITE}Choose an option (0-9):${NC}"
        read -r choice
        
        case $choice in
            1) full_automatic_installation ;;
            2) step_by_step_installation ;;
            3) check_system_requirements ;;
            4) setup_configuration ;;
            5) 
                print_step "Update feature coming soon..."
                wait_for_input
                ;;
            6)
                print_step "Uninstall feature coming soon..."
                wait_for_input
                ;;
            7) health_check ;;
            8)
                if [ -f "$LOG_FILE" ]; then
                    echo -e "${CYAN}📋 Installation Log:${NC}"
                    cat "$LOG_FILE"
                else
                    print_warning "No log file found"
                fi
                wait_for_input
                ;;
            9)
                print_banner
                echo -e "${CYAN}❓ Help & Documentation${NC}"
                echo -e "${CYAN}═══════════════════════${NC}"
                echo ""
                echo -e "${WHITE}FlowAI-ICT Trading Bot Installation Help${NC}"
                echo ""
                echo -e "${YELLOW}Quick Start:${NC}"
                echo -e "${WHITE}1. Choose 'Full Automatic Installation'${NC}"
                echo -e "${WHITE}2. Enter your Telegram Bot Token${NC}"
                echo -e "${WHITE}3. Enter your Telegram User ID${NC}"
                echo -e "${WHITE}4. Wait for installation to complete${NC}"
                echo ""
                echo -e "${YELLOW}Manual Installation:${NC}"
                echo -e "${WHITE}Use 'Custom Installation' for step-by-step control${NC}"
                echo ""
                echo -e "${YELLOW}Support:${NC}"
                echo -e "${WHITE}GitHub: https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot${NC}"
                echo ""
                wait_for_input
                ;;
            0)
                echo -e "${GREEN}Thank you for using FlowAI-ICT Trading Bot!${NC}"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 0-9."
                sleep 1
                ;;
        esac
    done
}

# Initialize logging
echo "FlowAI-ICT Installation Log - $(date)" > "$LOG_FILE"

# Handle root user
if [[ $EUID -eq 0 ]]; then
    print_banner
    print_warning "Running as root detected"
    echo -e "${YELLOW}For security reasons, it's recommended to run as non-root user.${NC}"
    echo -e "${WHITE}Options:${NC}"
    echo -e "${GREEN}1.${NC} Create new user 'flowai' and switch"
    echo -e "${GREEN}2.${NC} Continue as root (not recommended)"
    echo -e "${GREEN}3.${NC} Exit"
    echo ""
    echo -e "${WHITE}Choose option (1-3):${NC}"
    read -r root_choice
    
    case $root_choice in
        1)
            if ! id "flowai" &>/dev/null; then
                useradd -m -s /bin/bash flowai
                usermod -aG sudo flowai
                echo "flowai:FlowAI2025!" | chpasswd
                print_success "User 'flowai' created"
            fi
            print_step "Switching to user 'flowai'..."
            sudo -u flowai bash "$0" "$@"
            exit $?
            ;;
        2)
            print_warning "Continuing as root..."
            ;;
        3)
            exit 0
            ;;
    esac
fi

# Start main menu
main_menu
