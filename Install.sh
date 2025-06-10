#!/bin/bash

# =====================================================
# FlowAI-ICT Trading Bot Complete Installer v3.5
# Enhanced User + Logging + Uninstall + Dev Tools
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
ERROR_LOG="/tmp/flowai_errors.log"
CURRENT_USER=""
TELEGRAM_TOKEN=""
ADMIN_ID=""
ERROR_COUNT=0

# Check if installation exists
INSTALLATION_EXISTS=false
if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/.env" ] && [ -f "/etc/systemd/system/flowai-ict-bot.service" ]; then
    INSTALLATION_EXISTS=true
fi

# Enhanced logging functions
log_action() {
    local action="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ACTION: $action" >> "$LOG_FILE"
}

log_error() {
    local step="$1"
    local error="$2"
    local command="${3:-$BASH_COMMAND}"
    local exit_code="${4:-$?}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    ((ERROR_COUNT++))
    
    # Console output
    print_error "$step failed: $error"
    
    # Detailed error log
    {
        echo "[$timestamp] ERROR #$ERROR_COUNT"
        echo "Step: $step"
        echo "Error: $error"
        echo "Command: $command"
        echo "Exit Code: $exit_code"
        echo "Working Directory: $(pwd)"
        echo "User: $(whoami)"
        echo "Environment: $(env | grep -E '(PATH|HOME|USER)' | head -3)"
        echo "---"
    } >> "$ERROR_LOG"
    
    # Show fix suggestion
    case "$step" in
        "System Update")
            echo -e "${CYAN}💡 Fix: Check internet connection and try: sudo apt update${NC}"
            ;;
        "Package Installation")
            echo -e "${CYAN}💡 Fix: Check disk space and package availability${NC}"
            ;;
        "Git Clone")
            echo -e "${CYAN}💡 Fix: Check GitHub access and network connectivity${NC}"
            ;;
        "Python Dependencies")
            echo -e "${CYAN}💡 Fix: Try: pip install --upgrade pip && pip install -r requirements.txt${NC}"
            ;;
        *)
            echo -e "${CYAN}💡 Check error log: $ERROR_LOG${NC}"
            ;;
    esac
}

log_success() {
    local action="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] SUCCESS: $action" >> "$LOG_FILE"
}

# Enhanced UI functions
print_banner() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}${BOLD}              FlowAI-ICT Trading Bot v3.5                    ${NC}${PURPLE}║${NC}"
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

print_install_menu() {
    echo -e "${CYAN}🚀 Installation Options:${NC}"
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}1.${NC} 🚀 ${WHITE}Quick Install (Recommended)${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}2.${NC} 🔧 ${WHITE}Custom Install (Advanced)${NC}                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 🔍 ${WHITE}System Check Only${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}4.${NC} 📋 ${WHITE}View Error Logs${NC}                                ${CYAN}│${NC}"
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

# Enhanced root user handling with no password
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
                log_error "User Creation" "Failed to create flowai user"
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
            log_error "Script Copy" "Failed to copy script to flowai home"
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
    sudo rm -f /tmp/flowai_*.log
    sudo rm -f /var/log/flowai*
    print_success "Logs cleaned"
    
    # Ask about removing flowai user
    echo ""
    echo -e "${YELLOW}Remove 'flowai' user account? (y/n):${NC}"
    read -r remove_user
    
    if [[ "$remove_user" =~ ^[Yy]$ ]]; then
        if id "flowai" &>/dev/null; then
            print_step "Removing flowai user..."
            sudo userdel -r flowai 2>/dev/null
            sudo rm -f /etc/sudoers.d/flowai
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
}

# Developer Tools Function
developer_tools() {
    while true; do
        print_banner
        echo -e "${CYAN}🔧 Developer Tools & Debugging${NC}"
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}1.${NC} 🐛 ${WHITE}Toggle Debug Mode${NC}                               ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}2.${NC} 🧪 ${WHITE}Test API Connection${NC}                             ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}3.${NC} 📊 ${WHITE}Performance Monitor${NC}                            ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}4.${NC} 🔍 ${WHITE}Check Dependencies${NC}                             ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}5.${NC} 📋 ${WHITE}System Diagnostics${NC}                             ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}6.${NC} 🔄 ${WHITE}Reset Configuration${NC}                            ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}7.${NC} 📦 ${WHITE}Export Debug Info${NC}                              ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}8.${NC} 🧹 ${WHITE}Clean Logs${NC}                                    ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${GREEN}0.${NC} 🔙 ${WHITE}Back to Main Menu${NC}                              ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        
        echo -e "${WHITE}Choose option (0-8):${NC}"
        read -r dev_choice
        
        case $dev_choice in
            1)
                echo -e "${CYAN}🐛 Debug Mode Toggle${NC}"
                if [ -f "$INSTALL_DIR/.env" ]; then
                    cd "$INSTALL_DIR"
                    if grep -q "DEBUG_MODE=true" .env; then
                        sed -i 's/DEBUG_MODE=true/DEBUG_MODE=false/' .env
                        print_success "Debug mode disabled"
                    else
                        sed -i 's/DEBUG_MODE=false/DEBUG_MODE=true/' .env
                        print_success "Debug mode enabled"
                    fi
                else
                    print_error "Configuration file not found"
                fi
                wait_for_input
                ;;
            2)
                echo -e "${CYAN}🧪 Testing API Connection${NC}"
                cd "$INSTALL_DIR" 2>/dev/null
                if [ -d "venv" ]; then
                    source venv/bin/activate
                    python3 -c "
import requests
try:
    response = requests.get('https://api.github.com', timeout=5)
    print('✅ Internet: OK')
    
    response = requests.get('https://api.metals.live/v1/spot/gold', timeout=5)
    print('✅ BrsAPI: OK')
except Exception as e:
    print(f'❌ Connection failed: {e}')
"
                else
                    print_error "Virtual environment not found"
                fi
                wait_for_input
                ;;
            3)
                echo -e "${CYAN}📊 Performance Monitor${NC}"
                echo "💻 System Resources:"
                echo "Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
                echo "Disk: $(df -h / | awk 'NR==2{print $5}')"
                echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
                if systemctl is-active --quiet flowai-ict-bot; then
                    echo "Bot Memory: $(ps aux | grep telegram_bot.py | grep -v grep | awk '{print $4}')%"
                fi
                wait_for_input
                ;;
            4)
                echo -e "${CYAN}🔍 Checking Dependencies${NC}"
                cd "$INSTALL_DIR" 2>/dev/null
                if [ -d "venv" ]; then
                    source venv/bin/activate
                    echo "Python Version: $(python --version)"
                    echo ""
                    echo "Checking critical packages:"
                    for pkg in telegram pandas numpy ta requests; do
                        if python -c "import $pkg" 2>/dev/null; then
                            echo "✅ $pkg: OK"
                        else
                            echo "❌ $pkg: Missing"
                        fi
                    done
                else
                    print_error "Virtual environment not found"
                fi
                wait_for_input
                ;;
            5)
                echo -e "${CYAN}📋 System Diagnostics${NC}"
                echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
                echo "Kernel: $(uname -r)"
                echo "Architecture: $(uname -m)"
                echo "User: $(whoami)"
                echo "Home: $HOME"
                echo "Shell: $SHELL"
                echo ""
                echo "FlowAI Installation:"
                if [ -d "$INSTALL_DIR" ]; then
                    echo "✅ Directory: $INSTALL_DIR"
                    echo "Size: $(du -sh $INSTALL_DIR 2>/dev/null | cut -f1)"
                else
                    echo "❌ Directory: Not found"
                fi
                
                if systemctl list-unit-files | grep -q flowai-ict-bot; then
                    echo "✅ Service: Installed"
                else
                    echo "❌ Service: Not installed"
                fi
                wait_for_input
                ;;
            6)
                echo -e "${CYAN}🔄 Reset Configuration${NC}"
                echo -e "${YELLOW}This will reset .env to defaults. Continue? (y/n):${NC}"
                read -r reset_confirm
                if [[ "$reset_confirm" =~ ^[Yy]$ ]]; then
                    if [ -f "$INSTALL_DIR/.env" ]; then
                        cp "$INSTALL_DIR/.env" "$INSTALL_DIR/.env.backup"
                        print_success "Configuration backed up to .env.backup"
                        # Reset to defaults but keep tokens
                        print_warning "Manual reset required - edit $INSTALL_DIR/.env"
                    else
                        print_error "Configuration file not found"
                    fi
                fi
                wait_for_input
                ;;
            7)
                echo -e "${CYAN}📦 Exporting Debug Info${NC}"
                debug_file="/tmp/flowai_debug_$(date +%Y%m%d_%H%M%S).txt"
                {
                    echo "FlowAI-ICT Debug Info - $(date)"
                    echo "================================="
                    echo ""
                    echo "System Info:"
                    uname -a
                    echo ""
                    echo "Installation Status:"
                    [ -d "$INSTALL_DIR" ] && echo "✅ Directory exists" || echo "❌ Directory missing"
                    [ -f "$INSTALL_DIR/.env" ] && echo "✅ Config exists" || echo "❌ Config missing"
                    systemctl is-active --quiet flowai-ict-bot && echo "✅ Service running" || echo "❌ Service stopped"
                    echo ""
                    echo "Recent Logs:"
                    tail -20 "$LOG_FILE" 2>/dev/null || echo "No logs found"
                    echo ""
                    echo "Recent Errors:"
                    tail -10 "$ERROR_LOG" 2>/dev/null || echo "No errors found"
                } > "$debug_file"
                
                print_success "Debug info exported to: $debug_file"
                wait_for_input
                ;;
            8)
                echo -e "${CYAN}🧹 Cleaning Logs${NC}"
                echo -e "${YELLOW}This will remove all log files. Continue? (y/n):${NC}"
                read -r clean_confirm
                if [[ "$clean_confirm" =~ ^[Yy]$ ]]; then
                    rm -f /tmp/flowai_*.log
                    [ -d "$INSTALL_DIR/logs" ] && rm -f "$INSTALL_DIR/logs/*"
                    print_success "Logs cleaned"
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

# Enhanced quick install with proper menu return
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
    
    # [Previous installation code remains the same until the end...]
    # Update system with error handling
    print_step "Updating system packages..."
    if timeout 300s sudo apt update &>/dev/null; then
        print_success "Package lists updated"
        if timeout 600s sudo apt upgrade -y &>/dev/null; then
            print_success "System upgraded"
        else
            log_error "System Upgrade" "Upgrade failed or timed out"
            print_warning "System upgrade failed, continuing..."
        fi
    else
        log_error "System Update" "Update failed or timed out"
        echo -e "${RED}Failed to update system. Check internet connection.${NC}"
        return 1
    fi
    
    # Install dependencies with error handling
    print_step "Installing system dependencies..."
    local essential_packages="python3 python3-pip python3-venv python3-dev git curl wget unzip"
    local optional_packages="build-essential software-properties-common htop nano vim screen tmux tree jq sqlite3 cron"
    
    if timeout 300s sudo apt install -y $essential_packages; then
        print_success "Essential packages installed"
        
        # Try optional packages
        if timeout 300s sudo apt install -y $optional_packages &>/dev/null; then
            print_success "Optional packages installed"
        else
            print_warning "Some optional packages failed to install"
        fi
    else
        log_error "Package Installation" "Failed to install essential packages"
        echo -e "${RED}Failed to install essential packages${NC}"
        return 1
    fi
    
    # Setup project with error handling
    print_step "Setting up project directory..."
    if [ -d "$INSTALL_DIR" ]; then
        backup_dir="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        if sudo mv "$INSTALL_DIR" "$backup_dir"; then
            print_success "Existing installation backed up to $backup_dir"
        else
            log_error "Backup" "Failed to backup existing installation"
        fi
    fi
    
    if timeout 120s sudo git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git "$INSTALL_DIR"; then
        CURRENT_USER=$(whoami)
        sudo chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR"
        print_success "Project cloned successfully"
    else
        log_error "Git Clone" "Failed to clone repository"
        echo -e "${RED}Failed to clone repository. Check GitHub access.${NC}"
        return 1
    fi
    
    # Setup virtual environment with error handling
    print_step "Setting up Python environment..."
    cd "$INSTALL_DIR" || {
        log_error "Directory Change" "Cannot access $INSTALL_DIR"
        return 1
    }
    
    if python3 -m venv venv; then
        print_success "Virtual environment created"
        
        if source venv/bin/activate; then
            print_success "Virtual environment activated"
            
            if pip install --upgrade pip setuptools wheel &>/dev/null; then
                print_success "Pip upgraded"
            else
                log_error "Pip Upgrade" "Failed to upgrade pip"
                print_warning "Pip upgrade failed, continuing..."
            fi
        else
            log_error "VEnv Activation" "Failed to activate virtual environment"
            return 1
        fi
    else
        log_error "VEnv Creation" "Failed to create virtual environment"
        return 1
    fi
    
    # Install Python packages with enhanced error handling
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
    
    # Try to install all packages
    if timeout 600s pip install -r requirements.txt &>/dev/null; then
        print_success "All Python packages installed"
    else
        log_error "Python Dependencies" "Bulk installation failed, trying individual packages"
        print_warning "Bulk installation failed, trying individual packages..."
        
        # Try individual packages
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
        
        local failed_packages=()
        for package in "${packages[@]}"; do
            if timeout 60s pip install "$package" &>/dev/null; then
                echo -e "${GREEN}  ✓ $package${NC}"
            else
                echo -e "${RED}  ✗ $package${NC}"
                failed_packages+=("$package")
            fi
        done
        
        if [ ${#failed_packages[@]} -gt 0 ]; then
            log_error "Package Installation" "Failed packages: ${failed_packages[*]}"
            print_warning "Some packages failed to install: ${failed_packages[*]}"
        else
            print_success "All packages installed individually"
        fi
    fi
    
    # Verify critical imports
    print_step "Verifying Python dependencies..."
    if python -c "import telegram, pandas, numpy, ta" &>/dev/null; then
        print_success "Critical dependencies verified"
    else
        log_error "Dependency Verification" "Critical imports failed"
        print_error "Critical dependencies missing - installation may not work properly"
    fi
    
    # Create directories
    print_step "Creating directory structure..."
    local directories=("logs" "reports" "backups" "models" "data" "config" "temp" "flow_ai_core/data_sources" "flow_ai_core/telegram")
    
    for dir in "${directories[@]}"; do
        if mkdir -p "$dir"; then
            chmod 755 "$dir"
        else
            log_error "Directory Creation" "Failed to create $dir"
        fi
    done
    
    # Create __init__.py files
    touch flow_ai_core/__init__.py flow_ai_core/data_sources/__init__.py flow_ai_core/telegram/__init__.py
    print_success "Directory structure created"
    
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
    
    if [ -f ".env" ]; then
        print_success "Environment configured"
    else
        log_error "Environment Configuration" "Failed to create .env file"
        return 1
    fi
    
    # Setup service
    print_step "Setting up system service..."
    if sudo tee /etc/systemd/system/flowai-ict-bot.service > /dev/null << EOF
[Unit]
Description=FlowAI-ICT Trading Bot v3.5
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
    then
        if sudo systemctl daemon-reload && sudo systemctl enable flowai-ict-bot &>/dev/null; then
            print_success "Service configured and enabled"
        else
            log_error "Service Enable" "Failed to enable service"
            print_warning "Service created but not enabled"
        fi
    else
        log_error "Service Creation" "Failed to create systemd service"
        return 1
    fi
    
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
echo "💊 FlowAI-ICT Health Check v3.5"
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
    
    # Test imports
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
    
    # Enhanced start option with proper menu return
    echo -e "${YELLOW}Start the bot now? (y/n):${NC}"
    read -r start_now
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        print_step "Starting FlowAI-ICT Bot..."
        sudo systemctl start flowai-ict-bot
        sleep 3
        if systemctl is-active --quiet flowai-ict-bot; then
            print_success "Bot started successfully!"
            echo -e "${CYAN}Check status: sudo systemctl status flowai-ict-bot${NC}"
        else
            print_warning "Bot may need configuration check"
            echo -e "${CYAN}Check logs: sudo journalctl -u flowai-ict-bot -f${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✅ Installation complete! Returning to management panel...${NC}"
    sleep 2
    
    # Update installation status and return to menu
    INSTALLATION_EXISTS=true
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
    wait_for_input
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
        wait_for_input
    fi
}

# View error logs
view_error_logs() {
    print_banner
    echo -e "${CYAN}🐛 Error Logs & Diagnostics${NC}"
    echo -e "${CYAN}═══════════════════════════════${NC}"
    echo ""
    
    if [ -f "$ERROR_LOG" ]; then
        echo -e "${WHITE}Recent Errors:${NC}"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
        tail -20 "$ERROR_LOG"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    else
        echo -e "${GREEN}✅ No error log found - system appears healthy${NC}"
    fi
    
    echo ""
    if [ -f "$LOG_FILE" ]; then
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

# Install menu
install_menu() {
    while true; do
        print_banner
        print_install_menu
        
        echo -e "${WHITE}Choose option (0-4):${NC}"
        read -r choice
        
        case $choice in
            1) 
                quick_install
                # After installation, check if it was successful and switch to management mode
                if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/.env" ] && [ -f "/etc/systemd/system/flowai-ict-bot.service" ]; then
                    INSTALLATION_EXISTS=true
                    return  # Return to main to switch to management menu
                fi
                ;;
            2) 
                echo -e "${CYAN}🔧 Custom install feature coming in next version...${NC}"
                echo -e "${YELLOW}Use Quick Install for now - it covers all needs.${NC}"
                wait_for_input
                ;;
            3) 
                echo -e "${CYAN}🔍 System check feature coming in next version...${NC}"
                wait_for_input
                ;;
            4)
                view_error_logs
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
                echo -e "${CYAN}🔄 Update Bot${NC}"
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
            6) developer_tools ;;
            7) complete_uninstall ;;
            8)
                print_banner
                echo -e "${CYAN}📖 Help & Documentation${NC}"
                echo -e "${CYAN}═══════════════════════════${NC}"
                echo ""
                echo -e "${WHITE}FlowAI-ICT Trading Bot v3.5${NC}"
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
    # Initialize logging
    echo "FlowAI-ICT Installation/Management Log v3.5 - $(date)" > "$LOG_FILE"
    
    # Handle root user automatically
    handle_root_user
    
    # Main loop - always return to appropriate menu
    while true; do
        # Re-check installation status
        if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/.env" ] && [ -f "/etc/systemd/system/flowai-ict-bot.service" ]; then
            INSTALLATION_EXISTS=true
        else
            INSTALLATION_EXISTS=false
        fi
        
        # Determine mode based on installation status
        if [ "$INSTALLATION_EXISTS" = true ]; then
            # Management mode
            management_menu
        else
            # Installation mode
            install_menu
        fi
    done
}

# Run main function
main "$@"
