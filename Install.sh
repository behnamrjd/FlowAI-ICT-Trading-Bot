#!/bin/bash

# =====================================================
# FlowAI-ICT Trading Bot Installation Script v3.0
# Enhanced with ICT Features & Virtual Environment
# =====================================================

# Colors for better display
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${PURPLE}=================================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}=================================================${NC}"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check root access
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Please do not run this script as root!"
        exit 1
    fi
}

# Check operating system
check_os() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_error "This script is designed for Linux systems only!"
        exit 1
    fi
}

# Check internet connection
check_internet() {
    print_step "Checking internet connection..."
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "No internet connection detected!"
        exit 1
    fi
    print_success "Internet connection verified"
}

# Main installation function
main() {
    clear
    print_header "FlowAI-ICT Trading Bot Installer v3.0"
    
    echo -e "${BLUE}🎯 Features:${NC}"
    echo "  • ICT Methodology (Order Blocks, FVG, Liquidity Sweeps)"
    echo "  • AI-Powered Signal Generation"
    echo "  • Real-time BrsAPI Integration"
    echo "  • Advanced Risk Management"
    echo "  • Telegram Bot Interface"
    echo "  • Virtual Environment Setup"
    echo "  • Developer Tools & Debugging"
    echo ""
    
    # Initial checks
    check_root
    check_os
    check_internet
    
    # Request confirmation
    echo -e "${YELLOW}Do you want to continue with installation? (y/n):${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # Installation steps
    install_system_dependencies
    setup_project
    setup_virtual_environment
    install_python_dependencies
    create_directories
    setup_environment_file
    setup_systemd_service
    setup_developer_tools
    final_setup
    show_completion_message
}

# Install system dependencies
install_system_dependencies() {
    print_step "Installing system dependencies..."
    
    # Update system
    sudo apt update && sudo apt upgrade -y
    
    # Install essential packages
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        git \
        curl \
        wget \
        unzip \
        build-essential \
        software-properties-common \
        htop \
        nano \
        vim \
        screen \
        tmux \
        tree \
        jq \
        sqlite3 \
        cron
    
    print_success "System dependencies installed"
}

# Setup project
setup_project() {
    print_step "Setting up FlowAI-ICT project..."
    
    # Set installation directory
    INSTALL_DIR="/opt/FlowAI-ICT-Trading-Bot"
    
    # Remove existing directory if exists
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Existing installation found. Backing up..."
        sudo mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Clone repository
    sudo git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git "$INSTALL_DIR"
    
    # Set ownership
    sudo chown -R $USER:$USER "$INSTALL_DIR"
    
    # Navigate to project directory
    cd "$INSTALL_DIR"
    
    print_success "Project cloned successfully"
}

# Setup virtual environment
setup_virtual_environment() {
    print_step "Setting up Python virtual environment..."
    
    cd /opt/FlowAI-ICT-Trading-Bot
    
    # Create virtual environment
    python3 -m venv venv
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    
    print_success "Virtual environment created and activated"
}

# Install Python dependencies
install_python_dependencies() {
    print_step "Installing Python dependencies..."
    
    cd /opt/FlowAI-ICT-Trading-Bot
    source venv/bin/activate
    
    # Create requirements.txt with exact versions
    cat > requirements.txt << EOF
# Core Telegram Bot
python-telegram-bot==13.15

# Data Processing & Analysis
pandas>=1.5.0
numpy>=1.21.0
requests>=2.28.0

# Configuration & Environment
python-dotenv>=0.19.0

# Technical Analysis (ICT Requirements) - KEEP EXISTING WORKING SETUP
ta==0.10.2
talib-binary>=0.4.24

# Date & Time Handling
jdatetime>=4.1.0
pytz>=2022.1

# Async Support
asyncio-mqtt>=0.11.1
aiohttp>=3.8.0

# Logging & Monitoring
colorlog>=6.6.0

# System Monitoring
psutil>=5.9.0

# Development Tools
pytest>=7.0.0
black>=22.0.0
flake8>=4.0.0
EOF
    
    # Install dependencies
    pip install -r requirements.txt
    
    print_success "Python dependencies installed"
}

# Create necessary directories
create_directories() {
    print_step "Creating necessary directories..."
    
    cd /opt/FlowAI-ICT-Trading-Bot
    
    # Create directories
    mkdir -p logs
    mkdir -p reports
    mkdir -p backups
    mkdir -p models
    mkdir -p data
    mkdir -p config
    mkdir -p temp
    
    # Set permissions
    chmod 755 logs reports backups models data config temp
    
    print_success "Directories created"
}

# Setup environment file
setup_environment_file() {
    print_step "Setting up environment configuration..."
    
    cd /opt/FlowAI-ICT-Trading-Bot
    
    # Create .env file
    cat > .env << EOF
# ===== TELEGRAM CONFIGURATION =====
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_ADMIN_IDS=262182607
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
    
    print_success "Environment file created"
    print_warning "Please edit .env file with your actual settings!"
}

# Setup systemd service
setup_systemd_service() {
    print_step "Setting up systemd service..."
    
    # Create systemd service file
    sudo tee /etc/systemd/system/flowai-ict-bot.service > /dev/null << EOF
[Unit]
Description=FlowAI-ICT Trading Bot v3.0
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/FlowAI-ICT-Trading-Bot
Environment=PATH=/opt/FlowAI-ICT-Trading-Bot/venv/bin
ExecStart=/opt/FlowAI-ICT-Trading-Bot/venv/bin/python telegram_bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=flowai-ict-bot

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/opt/FlowAI-ICT-Trading-Bot

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    print_success "Systemd service created"
}

# Setup developer tools
setup_developer_tools() {
    print_step "Setting up developer tools..."
    
    cd /opt/FlowAI-ICT-Trading-Bot
    
    # Create developer tools script
    cat > dev_tools.py << 'EOF'
#!/usr/bin/env python3
"""
🔧 FlowAI-ICT Developer Tools v3.0
"""

import os
import sys
import json
import logging
import subprocess
from datetime import datetime

def show_menu():
    """Show developer tools menu"""
    print("\n🔧 Development & Debugging Tools:")
    print("1. 🐛 Toggle Debug Mode")
    print("2. 🧪 API Testing Utilities")
    print("3. 📊 Performance Profiler")
    print("4. 🔍 Code Quality Checker")
    print("5. 📋 System Diagnostics")
    print("6. 🔄 Reset Configuration")
    print("7. 📦 Export Logs")
    print("8. 🔙 Back to Main Menu")

def toggle_debug_mode():
    """Toggle debug mode in .env file"""
    print("🐛 Toggling Debug Mode...")
    # Implementation here

def api_testing():
    """API testing utilities"""
    print("🧪 API Testing Utilities...")
    # Implementation here

def performance_profiler():
    """Performance profiling tools"""
    print("📊 Performance Profiler...")
    # Implementation here

def code_quality_checker():
    """Code quality checking tools"""
    print("🔍 Running Code Quality Checker...")
    try:
        subprocess.run(["flake8", ".", "--max-line-length=120"])
        subprocess.run(["black", ".", "--check"])
    except Exception as e:
        print(f"Error: {e}")

def system_diagnostics():
    """System diagnostics"""
    print("📋 System Diagnostics...")
    # Implementation here

def reset_configuration():
    """Reset configuration to defaults"""
    print("🔄 Reset Configuration...")
    # Implementation here

def export_logs():
    """Export logs for analysis"""
    print("📦 Exporting Logs...")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = f"logs_export_{timestamp}.tar.gz"
    subprocess.run(["tar", "-czf", log_file, "logs/"])
    print(f"Logs exported to: {log_file}")

def main():
    """Main developer tools function"""
    while True:
        show_menu()
        choice = input("\nSelect option (1-8): ")
        
        if choice == "1":
            toggle_debug_mode()
        elif choice == "2":
            api_testing()
        elif choice == "3":
            performance_profiler()
        elif choice == "4":
            code_quality_checker()
        elif choice == "5":
            system_diagnostics()
        elif choice == "6":
            reset_configuration()
        elif choice == "7":
            export_logs()
        elif choice == "8":
            break
        else:
            print("Invalid option!")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x dev_tools.py
    
    print_success "Developer tools setup completed"
}

# Final setup
final_setup() {
    print_step "Performing final setup..."
    
    cd /opt/FlowAI-ICT-Trading-Bot
    
    # Set executable permissions
    chmod +x telegram_bot.py
    chmod +x dev_tools.py
    
    # Create startup script
    cat > start_bot.sh << 'EOF'
#!/bin/bash
cd /opt/FlowAI-ICT-Trading-Bot
source venv/bin/activate
python telegram_bot.py
EOF
    
    chmod +x start_bot.sh
    
    # Create update script
    cat > update_bot.sh << 'EOF'
#!/bin/bash
echo "🔄 Updating FlowAI-ICT Trading Bot..."
cd /opt/FlowAI-ICT-Trading-Bot
git pull origin main
source venv/bin/activate
pip install -r requirements.txt --upgrade
echo "✅ Update completed!"
EOF
    
    chmod +x update_bot.sh
    
    # Health check script
    cat > health_check.sh << 'EOF'
#!/bin/bash
echo "💊 FlowAI-ICT Health Check"
echo "=========================="

# Check if bot is running
if systemctl is-active --quiet flowai-ict-bot; then
    echo "✅ Bot Service: Running"
else
    echo "❌ Bot Service: Stopped"
fi

# Check Python environment
cd /opt/FlowAI-ICT-Trading-Bot
if [ -d "venv" ]; then
    echo "✅ Virtual Environment: OK"
else
    echo "❌ Virtual Environment: Missing"
fi

# Check configuration
if [ -f ".env" ]; then
    echo "✅ Configuration: Found"
else
    echo "❌ Configuration: Missing"
fi

# Check logs
if [ -d "logs" ]; then
    echo "✅ Logs Directory: OK"
    echo "📊 Log Files: $(ls logs/ | wc -l)"
else
    echo "❌ Logs Directory: Missing"
fi

echo "=========================="
echo "Health check completed!"
EOF
    
    chmod +x health_check.sh
    
    print_success "Final setup completed"
}

# Show completion message
show_completion_message() {
    clear
    print_header "FlowAI-ICT Trading Bot v3.0 Installation Complete!"
    
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📁 Installation Directory:${NC} /opt/FlowAI-ICT-Trading-Bot"
    echo -e "${BLUE}🐍 Virtual Environment:${NC} venv/"
    echo -e "${BLUE}⚙️ Configuration File:${NC} .env"
    echo -e "${BLUE}📋 Service Name:${NC} flowai-ict-bot"
    echo ""
    
    echo -e "${YELLOW}📝 Next Steps:${NC}"
    echo "1. Edit configuration file:"
    echo "   nano /opt/FlowAI-ICT-Trading-Bot/.env"
    echo ""
    echo "2. Set your Telegram Bot Token in .env file"
    echo ""
    echo "3. Start the bot:"
    echo "   cd /opt/FlowAI-ICT-Trading-Bot"
    echo "   ./start_bot.sh"
    echo ""
    echo "   OR use systemd service:"
    echo "   sudo systemctl enable flowai-ict-bot"
    echo "   sudo systemctl start flowai-ict-bot"
    echo ""
    
    echo -e "${CYAN}🔧 Available Commands:${NC}"
    echo "• ./start_bot.sh          - Start bot manually"
    echo "• ./update_bot.sh         - Update bot to latest version"
    echo "• ./health_check.sh       - Check system health"
    echo "• python dev_tools.py     - Developer tools menu"
    echo ""
    echo "• sudo systemctl status flowai-ict-bot    - Check service status"
    echo "• sudo systemctl logs flowai-ict-bot      - View service logs"
    echo ""
    
    echo -e "${PURPLE}🎯 ICT Features Ready:${NC}"
    echo "• Order Block Detection"
    echo "• Fair Value Gap Analysis"
    echo "• Liquidity Sweep Detection"
    echo "• Market Structure Analysis"
    echo "• AI-Powered Signal Generation"
    echo "• Real-time BrsAPI Integration"
    echo "• Advanced Risk Management"
    echo "• Developer Tools & Debugging"
    echo ""
    
    echo -e "${GREEN}✅ FlowAI-ICT Trading Bot v3.0 is ready to use!${NC}"
    echo -e "${YELLOW}⚠️  Don't forget to configure your .env file before starting!${NC}"
}

# Error handling
trap 'print_error "Installation failed! Check the error messages above."; exit 1' ERR

# Run main function
main "$@"
