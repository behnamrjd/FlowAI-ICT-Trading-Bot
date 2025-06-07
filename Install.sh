#!/bin/bash

# FlowAI Complete Installation & Management Script - Advanced Version
# Handles installation check and provides comprehensive bot management

set -e

# --- Color Functions ---
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }
log_fatal() { echo -e "\033[31m[FATAL]\033[0m $1"; exit 1; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }

# --- Configuration Variables ---
CONDA_ENV_NAME="flowai_env"
PYTHON_VERSION="3.12"
TARGET_USER="flowaibot"
USER_HOME="/home/$TARGET_USER"
MINICONDA_PATH="$USER_HOME/miniconda3"
PROJECT_DIR="/opt/FlowAI-ICT-Trading-Bot"
PROJECT_REPO="https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git"

# --- Function: Create Executable Directory ---
create_exec_dir() {
    EXEC_DIR="$USER_HOME/.flowai_scripts"
    if [ ! -d "$EXEC_DIR" ]; then
        mkdir -p "$EXEC_DIR"
        chown "$TARGET_USER:$TARGET_USER" "$EXEC_DIR"
        chmod 755 "$EXEC_DIR"
    fi
    echo "$EXEC_DIR"
}

# --- Function: Complete System Cleanup ---
complete_system_cleanup() {
    log_info "Performing complete system cleanup..."
    
    pkill -f conda || true
    pkill -f python || true
    
    if [ -d "$MINICONDA_PATH" ] && sudo -u "$TARGET_USER" bash -c "
        export HOME='$USER_HOME'
        export USER='$TARGET_USER'
        unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        source '$MINICONDA_PATH/etc/profile.d/conda.sh' 2>/dev/null &&
        conda env list | grep -q '$CONDA_ENV_NAME'
    " 2>/dev/null; then
        sudo -u "$TARGET_USER" bash -c "
            export HOME='$USER_HOME'
            export USER='$TARGET_USER'
            unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
            source '$MINICONDA_PATH/etc/profile.d/conda.sh'
            conda env remove -n '$CONDA_ENV_NAME' -y
        " 2>/dev/null || true
    fi
    
    rm -rf "$MINICONDA_PATH" 2>/dev/null || true
    rm -rf "$USER_HOME/.conda" 2>/dev/null || true
    rm -rf "$USER_HOME/.condarc" 2>/dev/null || true
    rm -rf "$USER_HOME/.cache/pip" 2>/dev/null || true
    rm -rf "$USER_HOME/.flowai_scripts" 2>/dev/null || true
    
    rm -f "$USER_HOME/activate_flowai.sh" 2>/dev/null || true
    rm -f "$USER_HOME/simple_activate.sh" 2>/dev/null || true
    
    for profile in "$USER_HOME/.bashrc" "$USER_HOME/.bash_profile" "$USER_HOME/.profile" "$USER_HOME/.zshrc"; do
        if [ -f "$profile" ]; then
            sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' "$profile" 2>/dev/null || true
            sed -i '/export.*conda/Id' "$profile" 2>/dev/null || true
            sed -i '/export.*CONDA/Id' "$profile" 2>/dev/null || true
            sed -i '/miniconda3/d' "$profile" 2>/dev/null || true
        fi
    done
    
    rm -rf /tmp/tmp*conda* 2>/dev/null || true
    rm -rf /tmp/tmp*miniconda* 2>/dev/null || true
    rm -rf /tmp/*conda* 2>/dev/null || true
    rm -rf /tmp/activate_env* 2>/dev/null || true
    rm -rf /tmp/install_* 2>/dev/null || true
    rm -rf /tmp/setup_* 2>/dev/null || true
    rm -rf /tmp/verify_* 2>/dev/null || true
    rm -rf /tmp/repair_* 2>/dev/null || true
    rm -rf /tmp/run_bot* 2>/dev/null || true
    rm -rf /tmp/update_* 2>/dev/null || true
    
    rm -f /etc/profile.d/conda.sh 2>/dev/null || true
    
    if id "$TARGET_USER" &>/dev/null; then
        chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME" 2>/dev/null || true
        chmod 755 "$USER_HOME" 2>/dev/null || true
    fi
    
    log_success "Complete system cleanup finished"
}

# --- Function: Enhanced Installation Check ---
check_installation() {
    local is_installed=true
    
    if ! id "$TARGET_USER" &>/dev/null; then
        is_installed=false
        echo "$is_installed"
        return
    fi
    
    if [ ! -d "$MINICONDA_PATH" ] || [ ! -f "$MINICONDA_PATH/bin/conda" ]; then
        is_installed=false
        echo "$is_installed"
        return
    fi
    
    if ! sudo -u "$TARGET_USER" bash -c "
        export HOME='$USER_HOME'
        export USER='$TARGET_USER'
        unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        cd '$USER_HOME'
        source '$MINICONDA_PATH/etc/profile.d/conda.sh' 2>/dev/null &&
        conda env list | grep -q '$CONDA_ENV_NAME' &&
        conda activate '$CONDA_ENV_NAME' &&
        command -v python >/dev/null 2>&1 &&
        python --version >/dev/null 2>&1
    " 2>/dev/null; then
        is_installed=false
        echo "$is_installed"
        return
    fi
    
    if [ ! -f "$USER_HOME/activate_flowai.sh" ] || [ ! -x "$USER_HOME/activate_flowai.sh" ]; then
        is_installed=false
        echo "$is_installed"
        return
    fi
    
    echo "$is_installed"
}

# --- Function: Fix Permissions ---
fix_permissions() {
    log_info "Fixing file permissions and ownership..."
    
    if [ ! -d "$USER_HOME" ]; then
        mkdir -p "$USER_HOME"
    fi
    
    chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME" 2>/dev/null || true
    
    if [ -d "$MINICONDA_PATH" ]; then
        chown -R "$TARGET_USER:$TARGET_USER" "$MINICONDA_PATH" 2>/dev/null || true
        chmod -R u+rwX "$MINICONDA_PATH" 2>/dev/null || true
    fi
    
    if [ -d "$USER_HOME/.conda" ]; then
        chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.conda" 2>/dev/null || true
        chmod -R u+rwX "$USER_HOME/.conda" 2>/dev/null || true
    fi
    
    if [ -f "$USER_HOME/.condarc" ]; then
        chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.condarc" 2>/dev/null || true
        chmod 644 "$USER_HOME/.condarc" 2>/dev/null || true
    fi
    
    chmod 755 "$USER_HOME" 2>/dev/null || true
    
    log_success "Permissions fixed"
}

# --- Function: Fix Project Directory Permissions ---
fix_project_permissions() {
    log_info "Fixing project directory permissions..."
    
    if [ -d "$PROJECT_DIR" ]; then
        chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"
        chmod -R 755 "$PROJECT_DIR"
        
        if [ -f "$PROJECT_DIR/.env" ]; then
            chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"
            chmod 644 "$PROJECT_DIR/.env"
        fi
        
        log_success "Project directory permissions fixed"
    else
        log_info "Project directory not found, will be created with correct permissions"
    fi
}

# --- Function: Install Build Dependencies ---
install_build_dependencies() {
    log_info "Installing build dependencies..."
    
    # Update package list
    apt-get update -qq
    
    # Install essential build tools + TA-Lib system package
    apt-get install -y build-essential gcc g++ make cmake wget tar autoconf automake libtool pkg-config git
    
    # Install TA-Lib system package (critical for avoiding compilation issues)
    # Remove libta-lib packages (not available in Ubuntu repos)
# TA-Lib will be installed from source in install_python_packages()
    
    # Install Python development headers
    PYTHON_MAJMIN=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    apt-get install -y python${PYTHON_MAJMIN}-dev
    
    # Verify critical installations
    if command -v gcc >/dev/null 2>&1; then
        log_success "GCC installed: $(gcc --version | head -1)"
    else
        log_error "GCC installation failed"
        return 1
    fi
    
    # Verify TA-Lib C library
    if ldconfig -p | grep -q libta_lib; then
        log_success "TA-Lib C library installed and available"
    else
        log_warning "TA-Lib C library not found in ldconfig, will install manually"
    fi
    
    log_success "Build dependencies installed"
}

# --- Function: Clone/Update Project ---
clone_or_update_project() {
    log_info "Setting up FlowAI project..."
    
    if [ ! -d "$PROJECT_DIR" ]; then
        log_info "Cloning FlowAI project..."
        mkdir -p "$PROJECT_DIR"
        chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"
        
        sudo -u "$TARGET_USER" git clone "$PROJECT_REPO" "$PROJECT_DIR" || {
            log_error "Failed to clone project"
            return 1
        }
    else
        log_info "Updating existing project..."
        sudo -u "$TARGET_USER" bash -c "cd '$PROJECT_DIR' && git pull origin main" || {
            log_warning "Failed to update project, continuing with existing version"
        }
    fi
    
    chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"
    log_success "Project setup completed"
}

# --- Function: Check Environment Status ---
check_env_status() {
    local status="unknown"
    
    if [ "$(check_installation)" = "true" ]; then
        status="ready"
    else
        status="not_installed"
    fi
    
    echo "$status"
}

# --- Function: Check Project Status ---
check_project_status() {
    local status="unknown"
    
    if [ ! -d "$PROJECT_DIR" ]; then
        status="not_cloned"
    elif [ ! -f "$PROJECT_DIR/.env" ]; then
        status="env_missing"
    elif ! grep -q "your_bot_token_here" "$PROJECT_DIR/.env" 2>/dev/null; then
        status="configured"
    else
        status="needs_config"
    fi
    
    echo "$status"
}

# --- Function: Check Bot Status ---
check_bot_status() {
    local status="stopped"
    
    if [ -f "$USER_HOME/.flowai_bot.pid" ]; then
        BOT_PID=$(cat "$USER_HOME/.flowai_bot.pid")
        if ps -p "$BOT_PID" > /dev/null 2>&1; then
            status="running"
        else
            status="stopped"
            rm -f "$USER_HOME/.flowai_bot.pid"
        fi
    fi
    
    # Check for paused status
    if [ -f "$USER_HOME/.flowai_bot_paused" ]; then
        status="paused"
    fi
    
    echo "$status"
}

# --- Function: Smart Start Bot ---
smart_start_bot() {
    log_info "🚀 Starting FlowAI Trading Bot with comprehensive checks..."
    
    # Step 1: Check environment
    log_info "Step 1/6: Checking environment status..."
    ENV_STATUS=$(check_env_status)
    
    if [ "$ENV_STATUS" != "ready" ]; then
        log_error "Environment not ready. Please install first."
        return 1
    fi
    log_success "Environment is ready"
    
    # Step 2: Check project
    log_info "Step 2/6: Checking project status..."
    PROJECT_STATUS=$(check_project_status)
    
    case $PROJECT_STATUS in
        "not_cloned")
            log_info "Project not found. Cloning..."
            clone_or_update_project
            ;;
        "env_missing")
            log_info "Creating .env file..."
            create_env_file
            ;;
        "needs_config")
            log_warning "Bot needs configuration!"
            echo ""
            echo "🔧 Your bot needs to be configured before starting."
            echo "Please set up your Telegram bot token and other settings."
            echo ""
            read -p "Do you want to configure now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                edit_env_file
            else
                log_error "Bot cannot start without proper configuration"
                return 1
            fi
            ;;
        "configured")
            log_success "Project is properly configured"
            ;;
    esac
    
    # Step 3: Check if already running
    log_info "Step 3/6: Checking bot status..."
    BOT_STATUS=$(check_bot_status)
    
    case $BOT_STATUS in
        "running")
            log_warning "Bot is already running!"
            show_bot_status
            return 0
            ;;
        "paused")
            log_info "Bot is paused. Resuming..."
            resume_bot
            return 0
            ;;
    esac
    
    # Step 4: Update packages if needed
    log_info "Step 4/6: Checking package updates..."
    read -p "Do you want to update packages before starting? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_packages
    fi
    
    # Step 5: Validate configuration
    log_info "Step 5/6: Validating configuration..."
    if ! validate_configuration; then
        log_error "Configuration validation failed"
        return 1
    fi
    
    # Step 6: Start the bot
    log_info "Step 6/6: Starting the bot..."
    start_trading_bot
    
    log_success "🎉 FlowAI Trading Bot started successfully!"
}

# --- Function: Validate Configuration ---
validate_configuration() {
    log_info "Validating bot configuration..."
    
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_error ".env file not found"
        return 1
    fi
    
    # Check for required variables
    local required_vars=("TELEGRAM_BOT_TOKEN" "TELEGRAM_CHAT_ID")
    local missing_vars=()
    
for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" "$PROJECT_DIR/.env"; then
        missing_vars+=("$var")
    elif grep -q "^${var}=your_bot_token_here\|^${var}=your_chat_id_here\|^${var}=your_.*_here" "$PROJECT_DIR/.env"; then
        missing_vars+=("$var")
    elif [ "$(grep "^${var}=" "$PROJECT_DIR/.env" | cut -d'=' -f2)" = "" ]; then
        missing_vars+=("$var")
    fi
done

    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing or unconfigured variables: ${missing_vars[*]}"
        return 1
    fi
    
    log_success "Configuration validation passed"
    return 0
}

# --- Function: Create .env File ---
create_env_file() {
    log_info "Creating .env configuration file..."
    
    ENV_FILE="$PROJECT_DIR/.env"
    
    sudo -u "$TARGET_USER" cat > "$ENV_FILE" << 'EOF'
# FlowAI Trading Bot Configuration

# Telegram Bot Settings (REQUIRED)
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here

# Trading Settings
TRADING_PAIR=XAUUSD
RISK_PERCENTAGE=2
MAX_DAILY_TRADES=5
TRADING_MODE=demo

# API Keys (if needed)
BROKER_API_KEY=your_broker_api_key
BROKER_SECRET=your_broker_secret

# Database Settings
DATABASE_URL=sqlite:///flowai.db

# Logging Level
LOG_LEVEL=INFO

# Bot Settings
AUTO_START=false
SEND_SIGNALS=true
RISK_MANAGEMENT=true
EOF
    
    chown "$TARGET_USER:$TARGET_USER" "$ENV_FILE"
    chmod 644 "$ENV_FILE"
    
    log_success ".env file created at $ENV_FILE"
}

# --- Function: Pause Bot ---
pause_bot() {
    log_info "Pausing FlowAI Trading Bot..."
    
    if [ ! -f "$USER_HOME/.flowai_bot.pid" ]; then
        log_error "Bot is not running"
        return 1
    fi
    
    BOT_PID=$(cat "$USER_HOME/.flowai_bot.pid")
    if ! ps -p "$BOT_PID" > /dev/null 2>&1; then
        log_error "Bot process not found"
        rm -f "$USER_HOME/.flowai_bot.pid"
        return 1
    fi
    
    # Send SIGSTOP to pause the process
    kill -STOP "$BOT_PID"
    
    # Create pause marker
    echo "$(date)" > "$USER_HOME/.flowai_bot_paused"
    
    log_success "Bot paused successfully (PID: $BOT_PID)"
}

# --- Function: Resume Bot ---
resume_bot() {
    log_info "Resuming FlowAI Trading Bot..."
    
    if [ ! -f "$USER_HOME/.flowai_bot.pid" ]; then
        log_error "Bot PID file not found"
        return 1
    fi
    
    BOT_PID=$(cat "$USER_HOME/.flowai_bot.pid")
    if ! ps -p "$BOT_PID" > /dev/null 2>&1; then
        log_error "Bot process not found"
        rm -f "$USER_HOME/.flowai_bot.pid"
        rm -f "$USER_HOME/.flowai_bot_paused"
        return 1
    fi
    
    # Send SIGCONT to resume the process
    kill -CONT "$BOT_PID"
    
    # Remove pause marker
    rm -f "$USER_HOME/.flowai_bot_paused"
    
    log_success "Bot resumed successfully (PID: $BOT_PID)"
}

# --- Function: Activate Environment ---
activate_environment() {
    log_info "Activating FlowAI environment..."
    
    if [ "$(check_installation)" != "true" ]; then
        log_error "FlowAI environment is not properly installed!"
        log_info "Please run option 9 (Repair Installation) first."
        return 1
    fi
    
    fix_permissions
    
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/activate_env_fixed.sh" << 'EOF'
#!/bin/bash

export HOME="$USER_HOME"
export USER="$TARGET_USER"
export SHELL="/bin/bash"

unset XDG_CONFIG_HOME
unset SUDO_USER
unset SUDO_UID
unset SUDO_GID
unset SUDO_COMMAND

cd "$HOME"

if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
    source "$MINICONDA_PATH/etc/profile.d/conda.sh"
else
    echo "❌ Conda not found at $MINICONDA_PATH"
    exit 1
fi

if conda env list | grep -q "$CONDA_ENV_NAME"; then
    conda activate "$CONDA_ENV_NAME"
    
    if command -v python >/dev/null 2>&1; then
        echo "🚀 FlowAI environment activated successfully!"
        echo "Python version: $(python --version)"
        echo "Environment: $CONDA_DEFAULT_ENV"
        echo "Python executable: $(which python)"
    else
        echo "⚠️ Environment activated but Python not found. Installing Python..."
        conda install python=$PYTHON_VERSION -y
        echo "✅ Python installed. Environment ready!"
    fi
else
    echo "❌ Environment '$CONDA_ENV_NAME' not found"
    exit 1
fi

if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    echo "📁 Changed to project directory: $PROJECT_DIR"
fi

echo ""
echo "💡 Available commands:"
echo "   python main.py          # Run the trading bot"
echo "   python -c 'import talib; print(talib.__version__)'  # Test TA-Lib"
echo "   pip list                # Show installed packages"
echo "   conda deactivate        # Exit environment"
echo ""
echo "🎯 You are now in the FlowAI environment. Type 'exit' to return to menu."

exec bash --login
EOF

    sed -i "s|\$USER_HOME|$USER_HOME|g" "$EXEC_DIR/activate_env_fixed.sh"
    sed -i "s|\$TARGET_USER|$TARGET_USER|g" "$EXEC_DIR/activate_env_fixed.sh"
    sed -i "s|\$MINICONDA_PATH|$MINICONDA_PATH|g" "$EXEC_DIR/activate_env_fixed.sh"
    sed -i "s|\$CONDA_ENV_NAME|$CONDA_ENV_NAME|g" "$EXEC_DIR/activate_env_fixed.sh"
    sed -i "s|\$PYTHON_VERSION|$PYTHON_VERSION|g" "$EXEC_DIR/activate_env_fixed.sh"
    sed -i "s|\$PROJECT_DIR|$PROJECT_DIR|g" "$EXEC_DIR/activate_env_fixed.sh"

    chmod +x "$EXEC_DIR/activate_env_fixed.sh"
    chown "$TARGET_USER:$TARGET_USER" "$EXEC_DIR/activate_env_fixed.sh"
    
    sudo -u "$TARGET_USER" -H "$EXEC_DIR/activate_env_fixed.sh"
    
    rm -f "$EXEC_DIR/activate_env_fixed.sh"
}

# --- Function: Run Trading Bot (Interactive) ---
run_trading_bot() {
    log_info "Starting FlowAI Trading Bot (Interactive Mode)..."
    
    if [ "$(check_installation)" != "true" ]; then
        log_error "FlowAI environment is not properly installed!"
        log_info "Please run option 9 (Repair Installation) first."
        return 1
    fi
    
    fix_permissions
    
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/run_bot_fixed.sh" << 'EOF'
#!/bin/bash

export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "$HOME"

source "$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate "$CONDA_ENV_NAME"

if ! command -v python >/dev/null 2>&1; then
    echo "⚠️ Python not found. Installing..."
    conda install python=$PYTHON_VERSION -y
fi

if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    
    echo "🤖 Looking for bot files..."
    
    if [ -f "main.py" ]; then
        echo "🚀 Starting FlowAI Trading Bot (main.py)..."
        python main.py
    elif [ -f "bot.py" ]; then
        echo "🚀 Starting FlowAI Trading Bot (bot.py)..."
        python bot.py
    elif [ -f "run.py" ]; then
        echo "🚀 Starting FlowAI Trading Bot (run.py)..."
        python run.py
    elif [ -f "app.py" ]; then
        echo "🚀 Starting FlowAI Trading Bot (app.py)..."
        python app.py
    else
        echo "❌ Bot main file not found. Available Python files:"
        ls -la *.py 2>/dev/null || echo "No Python files found"
        echo ""
        echo "📝 Please run manually: python <your_bot_file>.py"
        echo "📁 Current directory: $(pwd)"
        echo "📋 Directory contents:"
        ls -la
    fi
else
    echo "❌ Project directory not found: $PROJECT_DIR"
    echo "📁 Please ensure the FlowAI project is properly installed"
    echo "💡 You can clone it with: git clone $PROJECT_REPO $PROJECT_DIR"
fi
EOF

    sed -i "s|\$USER_HOME|$USER_HOME|g" "$EXEC_DIR/run_bot_fixed.sh"
    sed -i "s|\$TARGET_USER|$TARGET_USER|g" "$EXEC_DIR/run_bot_fixed.sh"
    sed -i "s|\$MINICONDA_PATH|$MINICONDA_PATH|g" "$EXEC_DIR/run_bot_fixed.sh"
    sed -i "s|\$CONDA_ENV_NAME|$CONDA_ENV_NAME|g" "$EXEC_DIR/run_bot_fixed.sh"
    sed -i "s|\$PYTHON_VERSION|$PYTHON_VERSION|g" "$EXEC_DIR/run_bot_fixed.sh"
    sed -i "s|\$PROJECT_DIR|$PROJECT_DIR|g" "$EXEC_DIR/run_bot_fixed.sh"
    sed -i "s|\$PROJECT_REPO|$PROJECT_REPO|g" "$EXEC_DIR/run_bot_fixed.sh"

    chmod +x "$EXEC_DIR/run_bot_fixed.sh"
    chown "$TARGET_USER:$TARGET_USER" "$EXEC_DIR/run_bot_fixed.sh"
    
    sudo -u "$TARGET_USER" -H "$EXEC_DIR/run_bot_fixed.sh"
    
    rm -f "$EXEC_DIR/run_bot_fixed.sh"
}

# --- Function: Start Trading Bot (Background Service) ---
start_trading_bot() {
    log_info "Starting FlowAI Trading Bot as background service..."
    
    if [ "$(check_installation)" != "true" ]; then
        log_error "FlowAI environment is not properly installed!"
        log_info "Please run option 9 (Repair Installation) first."
        return 1
    fi
    
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "Project directory not found: $PROJECT_DIR"
        log_info "Please clone the project first"
        return 1
    fi
    
    if pgrep -f "python.*main.py\|python.*bot.py\|python.*run.py" >/dev/null; then
        log_warning "Trading bot appears to be already running!"
        echo "Running Python processes:"
        pgrep -f "python.*main.py\|python.*bot.py\|python.*run.py" -l
        read -p "Do you want to stop existing processes and restart? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            stop_trading_bot
        else
            return 1
        fi
    fi
    
    EXEC_DIR=$(create_exec_dir)
    
    BOT_FILE=""
    for file in "main.py" "bot.py" "run.py" "app.py"; do
        if [ -f "$PROJECT_DIR/$file" ]; then
            BOT_FILE="$file"
            break
        fi
    done
    
    if [ -z "$BOT_FILE" ]; then
        log_error "No bot main file found in $PROJECT_DIR"
        echo "Available Python files:"
        ls -la "$PROJECT_DIR"/*.py 2>/dev/null || echo "No Python files found"
        return 1
    fi
    
    cat > "$EXEC_DIR/start_bot.sh" << 'EOF'
#!/bin/bash

export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "$HOME"

source "$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate "$CONDA_ENV_NAME"

cd "$PROJECT_DIR"

mkdir -p logs

echo "🚀 Starting FlowAI Trading Bot ($BOT_FILE)..."
echo "📁 Working directory: $(pwd)"
echo "🐍 Python: $(which python)"
echo "📝 Log file: logs/bot.log"
echo "🕒 Started at: $(date)"

nohup python "$BOT_FILE" > logs/bot.log 2>&1 &
BOT_PID=$!

echo $BOT_PID > "$USER_HOME/.flowai_bot.pid"

echo "✅ Bot started with PID: $BOT_PID"
echo "📋 To view logs: tail -f $PROJECT_DIR/logs/bot.log"
echo "🛑 To stop bot: use the stop option in management menu"
EOF

    sed -i "s|\$USER_HOME|$USER_HOME|g" "$EXEC_DIR/start_bot.sh"
    sed -i "s|\$TARGET_USER|$TARGET_USER|g" "$EXEC_DIR/start_bot.sh"
    sed -i "s|\$MINICONDA_PATH|$MINICONDA_PATH|g" "$EXEC_DIR/start_bot.sh"
    sed -i "s|\$CONDA_ENV_NAME|$CONDA_ENV_NAME|g" "$EXEC_DIR/start_bot.sh"
    sed -i "s|\$PROJECT_DIR|$PROJECT_DIR|g" "$EXEC_DIR/start_bot.sh"
    sed -i "s|\$BOT_FILE|$BOT_FILE|g" "$EXEC_DIR/start_bot.sh"

    chmod +x "$EXEC_DIR/start_bot.sh"
    chown "$TARGET_USER:$TARGET_USER" "$EXEC_DIR/start_bot.sh"
    
    sudo -u "$TARGET_USER" -H "$EXEC_DIR/start_bot.sh"
    
    rm -f "$EXEC_DIR/start_bot.sh"
    
    sleep 2
    if [ -f "$USER_HOME/.flowai_bot.pid" ]; then
        BOT_PID=$(cat "$USER_HOME/.flowai_bot.pid")
        if ps -p "$BOT_PID" > /dev/null 2>&1; then
            log_success "Trading bot started successfully! PID: $BOT_PID"
            echo "📋 View logs: tail -f $PROJECT_DIR/logs/bot.log"
        else
            log_error "Bot failed to start. Check logs: $PROJECT_DIR/logs/bot.log"
        fi
    else
        log_error "Failed to start bot"
    fi
}

# --- Function: Stop Trading Bot ---
stop_trading_bot() {
    log_info "Stopping FlowAI Trading Bot..."
    
    STOPPED_ANY=false
    
    if [ -f "$USER_HOME/.flowai_bot.pid" ]; then
        BOT_PID=$(cat "$USER_HOME/.flowai_bot.pid")
        if ps -p "$BOT_PID" > /dev/null 2>&1; then
            log_info "Stopping bot with PID: $BOT_PID"
            kill "$BOT_PID"
            sleep 2
            
            if ps -p "$BOT_PID" > /dev/null 2>&1; then
                log_warning "Force killing bot with PID: $BOT_PID"
                kill -9 "$BOT_PID"
            fi
            
            STOPPED_ANY=true
        fi
        rm -f "$USER_HOME/.flowai_bot.pid"
        rm -f "$USER_HOME/.flowai_bot_paused"
    fi
    
    PYTHON_PIDS=$(pgrep -f "python.*main.py\|python.*bot.py\|python.*run.py" 2>/dev/null || true)
    if [ -n "$PYTHON_PIDS" ]; then
        log_info "Found running Python bot processes: $PYTHON_PIDS"
        read -p "Stop these processes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for pid in $PYTHON_PIDS; do
                log_info "Stopping process: $pid"
                kill "$pid" 2>/dev/null || true
                sleep 1
                if ps -p "$pid" > /dev/null 2>&1; then
                    kill -9 "$pid" 2>/dev/null || true
                fi
            done
            STOPPED_ANY=true
        fi
    fi
    
    if [ "$STOPPED_ANY" = true ]; then
        log_success "Trading bot stopped successfully"
    else
        log_info "No running bot processes found"
    fi
    
    REMAINING=$(pgrep -f python 2>/dev/null || true)
    if [ -n "$REMAINING" ]; then
        echo ""
        echo "📋 Remaining Python processes:"
        ps -f -p $REMAINING 2>/dev/null || true
    fi
}

# --- Function: Bot Status ---
show_bot_status() {
    log_info "FlowAI Trading Bot Status:"
    echo ""
    
    if [ -f "$USER_HOME/.flowai_bot.pid" ]; then
        BOT_PID=$(cat "$USER_HOME/.flowai_bot.pid")
        if ps -p "$BOT_PID" > /dev/null 2>&1; then
            if [ -f "$USER_HOME/.flowai_bot_paused" ]; then
                echo "⏸️  Bot Status: Paused (PID: $BOT_PID)"
                echo "🕒 Paused at: $(cat "$USER_HOME/.flowai_bot_paused")"
            else
                echo "✅ Bot Status: Running (PID: $BOT_PID)"
                echo "🕒 Started: $(ps -o lstart= -p "$BOT_PID")"
            fi
            echo "💾 Memory: $(ps -o rss= -p "$BOT_PID" | awk '{print $1/1024 " MB"}')"
            echo "⏱️  CPU Time: $(ps -o time= -p "$BOT_PID")"
        else
            echo "❌ Bot Status: Stopped (PID file exists but process not running)"
            rm -f "$USER_HOME/.flowai_bot.pid"
            rm -f "$USER_HOME/.flowai_bot_paused"
        fi
    else
        echo "❌ Bot Status: Stopped"
    fi
    
    PYTHON_PIDS=$(pgrep -f "python.*main.py\|python.*bot.py\|python.*run.py" 2>/dev/null || true)
    if [ -n "$PYTHON_PIDS" ]; then
        echo ""
        echo "🔍 Found Python bot processes:"
        for pid in $PYTHON_PIDS; do
            echo "   PID: $pid - $(ps -o cmd= -p "$pid")"
        done
    fi
    
    if [ -f "$PROJECT_DIR/logs/bot.log" ]; then
        echo ""
        echo "📋 Recent log entries (last 10 lines):"
        echo "================================"
        tail -10 "$PROJECT_DIR/logs/bot.log" 2>/dev/null || echo "Cannot read log file"
        echo "================================"
        echo "📝 Full log: $PROJECT_DIR/logs/bot.log"
    fi
}

# --- Function: Edit .env File ---
edit_env_file() {
    log_info "Editing .env configuration file..."
    
    if [ "$(check_installation)" != "true" ]; then
        log_error "FlowAI environment is not properly installed!"
        log_info "Please run option 9 (Repair Installation) first."
        return 1
    fi
    
    fix_project_permissions
    
    if [ ! -d "$PROJECT_DIR" ]; then
        log_info "Project directory not found. Creating and cloning..."
        clone_or_update_project
    fi
    
    ENV_FILE="$PROJECT_DIR/.env"
    
    if [ ! -f "$ENV_FILE" ]; then
        log_info "Creating new .env file..."
        create_env_file
    fi
    
    chown "$TARGET_USER:$TARGET_USER" "$ENV_FILE"
    chmod 644 "$ENV_FILE"
    
    echo ""
    echo "📝 Current .env file content:"
    echo "================================"
    cat "$ENV_FILE"
    echo "================================"
    echo ""
    echo "Choose editing method:"
    echo "1) Edit with nano (recommended)"
    echo "2) Edit with vim"
    echo "3) Replace specific value"
    echo "4) View only (no changes)"
    echo ""
    read -p "Choose option (1-4): " edit_choice
    
    case $edit_choice in
        1)
            sudo -u "$TARGET_USER" nano "$ENV_FILE"
            ;;
        2)
            sudo -u "$TARGET_USER" vim "$ENV_FILE"
            ;;
        3)
            echo "Available variables:"
            grep -E "^[A-Z_]+" "$ENV_FILE" | cut -d'=' -f1
            echo ""
            read -p "Enter variable name to change: " var_name
            read -p "Enter new value: " var_value
            
            if grep -q "^${var_name}=" "$ENV_FILE"; then
                sed -i "s/^${var_name}=.*/${var_name}=${var_value}/" "$ENV_FILE"
                log_success "Updated $var_name"
            else
                echo "${var_name}=${var_value}" >> "$ENV_FILE"
                log_success "Added $var_name"
            fi
            ;;
        4)
            log_info "No changes made to .env file"
            ;;
        *)
            log_error "Invalid option"
            ;;
    esac
    
    chown "$TARGET_USER:$TARGET_USER" "$ENV_FILE"
    
    echo ""
    echo "📝 Updated .env file content:"
    echo "================================"
    cat "$ENV_FILE"
    echo "================================"
}

# --- Function: Update Packages ---
update_packages() {
    log_info "Updating FlowAI packages..."
    
    if [ "$(check_installation)" != "true" ]; then
        log_error "FlowAI environment is not properly installed!"
        log_info "Please run option 9 (Repair Installation) first."
        return 1
    fi
    
    install_build_dependencies
    fix_permissions
    
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/update_packages_fixed.sh" << 'EOF'
#!/bin/bash

export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "$HOME"

source "$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate "$CONDA_ENV_NAME"

if ! command -v python >/dev/null 2>&1; then
    echo "⚠️ Python not found. Installing..."
    conda install python=$PYTHON_VERSION -y
fi

echo "📦 Updating pip..."
python -m pip install --upgrade pip

echo "📦 Updating conda packages..."
conda update --all -y

echo "📦 Installing build tools..."
conda install -c anaconda gcc_linux-64 gxx_linux-64 -y || echo "⚠️ Could not install conda build tools"

if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    echo "📦 Updating project requirements..."
    pip install --upgrade -r "$PROJECT_DIR/requirements.txt" || echo "⚠️ Some requirements failed"
else
    echo "📦 Updating common packages..."
    pip install --upgrade numpy pandas matplotlib seaborn requests python-telegram-bot scikit-learn
fi

echo "📦 Checking TA-Lib..."
# Skip TA-Lib update to avoid breaking working installation
echo "⚠️ Skipping TA-Lib update to maintain stability"
echo "✅ Existing TA-Lib installation should continue working"

echo "✅ Package update completed!"

echo ""
echo "📋 Updated package versions:"
python -c "
import sys
packages = ['numpy', 'pandas', 'requests']
for pkg in packages:
    try:
        module = __import__(pkg)
        print(f'  {pkg}: {getattr(module, \"__version__\", \"unknown\")}')
    except ImportError:
        print(f'  {pkg}: not installed')

try:
    import talib
    print(f'  talib: {talib.__version__}')
except ImportError:
    print('  talib: not available')
"
EOF

    sed -i "s|\$USER_HOME|$USER_HOME|g" "$EXEC_DIR/update_packages_fixed.sh"
    sed -i "s|\$TARGET_USER|$TARGET_USER|g" "$EXEC_DIR/update_packages_fixed.sh"
    sed -i "s|\$MINICONDA_PATH|$MINICONDA_PATH|g" "$EXEC_DIR/update_packages_fixed.sh"
    sed -i "s|\$CONDA_ENV_NAME|$CONDA_ENV_NAME|g" "$EXEC_DIR/update_packages_fixed.sh"
    sed -i "s|\$PYTHON_VERSION|$PYTHON_VERSION|g" "$EXEC_DIR/update_packages_fixed.sh"
    sed -i "s|\$PROJECT_DIR|$PROJECT_DIR|g" "$EXEC_DIR/update_packages_fixed.sh"

    chmod +x "$EXEC_DIR/update_packages_fixed.sh"
    chown "$TARGET_USER:$TARGET_USER" "$EXEC_DIR/update_packages_fixed.sh"
    
    sudo -u "$TARGET_USER" -H "$EXEC_DIR/update_packages_fixed.sh"
    
    rm -f "$EXEC_DIR/update_packages_fixed.sh"
    log_success "Packages updated successfully!"
}

# --- Function: Enhanced Uninstall ---
uninstall_flowai() {
    log_warning "This will completely remove FlowAI installation!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return
    fi
    
    log_info "Performing complete FlowAI uninstallation..."
    
    complete_system_cleanup
    
    read -p "Remove user '$TARGET_USER' completely? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        userdel -r "$TARGET_USER" 2>/dev/null || true
        log_success "User removed"
    fi
    
    if [ -d "$PROJECT_DIR" ]; then
        read -p "Remove project directory '$PROJECT_DIR'? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$PROJECT_DIR"
            log_success "Project directory removed"
        fi
    fi
    
    log_success "FlowAI completely uninstalled!"
    log_info "System is now clean and ready for fresh installation."
}

# --- Function: Show System Status ---
show_status() {
    log_info "FlowAI System Status:"
    echo ""
    
    if id "$TARGET_USER" &>/dev/null; then
        echo "✅ User: $TARGET_USER (exists)"
    else
        echo "❌ User: $TARGET_USER (not found)"
        return
    fi
    
    if [ -d "$MINICONDA_PATH" ] && [ -f "$MINICONDA_PATH/bin/conda" ]; then
        echo "✅ Miniconda: Installed at $MINICONDA_PATH"
    else
        echo "❌ Miniconda: Not found or corrupted"
        return
    fi
    
    if sudo -u "$TARGET_USER" bash -c "
        export HOME='$USER_HOME'
        export USER='$TARGET_USER'
        unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        cd '$USER_HOME'
        source '$MINICONDA_PATH/etc/profile.d/conda.sh' 2>/dev/null &&
        conda env list | grep -q '$CONDA_ENV_NAME'
    " 2>/dev/null; then
        echo "✅ Conda Environment: $CONDA_ENV_NAME (exists)"
        
        echo ""
        echo "📦 Package Status:"
        sudo -u "$TARGET_USER" bash -c "
            export HOME='$USER_HOME'
            export USER='$TARGET_USER'
            unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
            cd '$USER_HOME'
            source '$MINICONDA_PATH/etc/profile.d/conda.sh'
            conda activate '$CONDA_ENV_NAME'
            
            if command -v python >/dev/null 2>&1; then
                python -c \"
import sys
print(f'   🐍 Python: {sys.version.split()[0]} ({sys.executable})')

packages = ['numpy', 'pandas', 'requests', 'telegram']
for pkg in packages:
    try:
        module = __import__(pkg)
        print(f'   ✅ {pkg}: {getattr(module, \\\"__version__\\\", \\\"unknown\\\")}')
    except ImportError:
        print(f'   ❌ {pkg}: not installed')

try:
    import talib
    print(f'   ✅ talib: {talib.__version__}')
except ImportError:
    print('   ⚠️  talib: not available')
\"
            else
                echo '   ❌ Python: not found in environment'
            fi
        " 2>/dev/null || echo "   ❌ Cannot check packages - environment may need repair"
    else
        echo "❌ Conda Environment: $CONDA_ENV_NAME (not found)"
    fi
    
    if [ -d "$PROJECT_DIR" ]; then
        echo "✅ Project Directory: $PROJECT_DIR"
        if [ -f "$PROJECT_DIR/main.py" ] || [ -f "$PROJECT_DIR/bot.py" ] || [ -f "$PROJECT_DIR/run.py" ]; then
            echo "   ✅ Bot files found"
        else
            echo "   ⚠️  Bot main file not found"
        fi
        
        if [ -f "$PROJECT_DIR/.env" ]; then
            echo "   ✅ Configuration file (.env) exists"
        else
            echo "   ⚠️  Configuration file (.env) missing"
        fi
    else
        echo "❌ Project Directory: Not found"
        echo "   💡 Clone with: git clone $PROJECT_REPO $PROJECT_DIR"
    fi
    
    echo ""
    if [ "$(check_installation)" = "true" ]; then
        echo "🎉 Overall Status: ✅ FlowAI is properly installed and ready to use!"
    else
        echo "⚠️  Overall Status: ❌ FlowAI installation has issues - use Repair Installation"
    fi
    
    echo ""
}

# --- Function: Repair Installation ---
repair_installation() {
    log_info "Repairing FlowAI installation..."
    
    fix_permissions
    
    if ! id "$TARGET_USER" &>/dev/null; then
        log_error "User $TARGET_USER does not exist. Please reinstall completely."
        return 1
    fi
    
    if [ ! -d "$MINICONDA_PATH" ] || [ ! -f "$MINICONDA_PATH/bin/conda" ]; then
        log_error "Miniconda not found. Please reinstall completely."
        return 1
    fi
    
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/repair_env.sh" << 'EOF'
#!/bin/bash

export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "$HOME"

source "$MINICONDA_PATH/etc/profile.d/conda.sh"

if conda env list | grep -q "$CONDA_ENV_NAME"; then
    echo "✅ Environment exists, checking Python..."
    conda activate "$CONDA_ENV_NAME"
    
    if ! command -v python >/dev/null 2>&1; then
        echo "🔧 Installing Python..."
        conda install python=$PYTHON_VERSION -y
    fi
    
    echo "🔧 Installing essential packages..."
    pip install --upgrade pip
    pip install numpy pandas requests python-telegram-bot
    
    conda install -c conda-forge ta-lib -y || pip install TA-Lib || echo "⚠️ TA-Lib installation failed"
    
    echo "✅ Environment repaired successfully!"
else
    echo "❌ Environment not found. Creating new environment..."
    conda create -n "$CONDA_ENV_NAME" python=$PYTHON_VERSION -y
    conda activate "$CONDA_ENV_NAME"
    
    pip install --upgrade pip
    pip install numpy pandas requests python-telegram-bot
    conda install -c conda-forge ta-lib -y || pip install TA-Lib || echo "⚠️ TA-Lib installation failed"
    
    echo "✅ Environment created and configured!"
fi
EOF

    sed -i "s|\$USER_HOME|$USER_HOME|g" "$EXEC_DIR/repair_env.sh"
    sed -i "s|\$TARGET_USER|$TARGET_USER|g" "$EXEC_DIR/repair_env.sh"
    sed -i "s|\$MINICONDA_PATH|$MINICONDA_PATH|g" "$EXEC_DIR/repair_env.sh"
    sed -i "s|\$CONDA_ENV_NAME|$CONDA_ENV_NAME|g" "$EXEC_DIR/repair_env.sh"
    sed -i "s|\$PYTHON_VERSION|$PYTHON_VERSION|g" "$EXEC_DIR/repair_env.sh"

    chmod +x "$EXEC_DIR/repair_env.sh"
    chown "$TARGET_USER:$TARGET_USER" "$EXEC_DIR/repair_env.sh"
    
    sudo -u "$TARGET_USER" -H "$EXEC_DIR/repair_env.sh"
    
    rm -f "$EXEC_DIR/repair_env.sh"
    
    create_activation_script
    
    log_success "Installation repaired!"
}

# --- Function: Management Menu ---
show_management_menu() {
    while true; do
        echo ""
        echo "🤖 =================================="
        echo "🤖  FlowAI Trading Bot Management"
        echo "🤖 =================================="
        echo ""
        echo "1) 🚀 Smart Start Bot (Recommended)"
        echo "2) 🤖 Run Trading Bot (Interactive)"
        echo "3) ⏸️  Pause Bot"
        echo "4) ▶️  Resume Bot"
        echo "5) ⏹️  Stop Bot"
        echo "6) 📊 Bot Status & Logs"
        echo "7) ⚙️  Edit .env Configuration"
        echo "8) 🔄 Clone/Update Project"
        echo "9) 📦 Update Packages"
        echo "10) 🔧 Activate Environment"
        echo "11) 📋 Show System Status"
        echo "12) 🛠️  Repair Installation"
        echo "13) 🗑️ Complete Uninstall"
        echo "14) 🚪 Exit"
        echo ""
        read -p "Choose an option (1-14): " choice
        
        case $choice in
            1)
                smart_start_bot
                read -p "Press Enter to continue..."
                ;;
            2)
                run_trading_bot
                read -p "Press Enter to continue..."
                ;;
            3)
                pause_bot
                read -p "Press Enter to continue..."
                ;;
            4)
                resume_bot
                read -p "Press Enter to continue..."
                ;;
            5)
                stop_trading_bot
                read -p "Press Enter to continue..."
                ;;
            6)
                show_bot_status
                read -p "Press Enter to continue..."
                ;;
            7)
                edit_env_file
                read -p "Press Enter to continue..."
                ;;
            8)
                clone_or_update_project
                read -p "Press Enter to continue..."
                ;;
            9)
                update_packages
                read -p "Press Enter to continue..."
                ;;
            10)
                activate_environment
                ;;
            11)
                show_status
                read -p "Press Enter to continue..."
                ;;
            12)
                repair_installation
                read -p "Press Enter to continue..."
                ;;
            13)
                uninstall_flowai
                if [ ! -d "$USER_HOME" ] || [ "$(check_installation)" != "true" ]; then
                    echo "FlowAI has been uninstalled. Exiting..."
                    exit 0
                fi
                ;;
            14)
                log_info "Exiting FlowAI Management..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please choose 1-14."
                ;;
        esac
    done
}

# --- Installation Functions ---
ensure_user_exists() {
    if ! id "$TARGET_USER" &>/dev/null; then
        log_info "Creating user: $TARGET_USER"
        if [ "$EUID" -eq 0 ]; then
            useradd -m -s /bin/bash "$TARGET_USER"
            usermod -aG sudo "$TARGET_USER"
            log_success "User $TARGET_USER created successfully"
        else
            log_fatal "User $TARGET_USER does not exist and cannot create without root privileges"
        fi
    else
        log_info "User $TARGET_USER already exists"
    fi
    
    fix_project_permissions
}

install_miniconda_as_user() {
    log_info "Installing Miniconda as user $TARGET_USER..."
    
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/install_miniconda.sh" << 'EOF'
#!/bin/bash
set -e

USER_HOME="$1"
MINICONDA_PATH="$2"

export HOME="$USER_HOME"
export USER="flowaibot"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "$USER_HOME"

echo "Downloading Miniconda..."
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh

echo "Installing Miniconda..."
bash miniconda.sh -b -p "$MINICONDA_PATH"
rm miniconda.sh

echo "Initializing conda..."
"$MINICONDA_PATH/bin/conda" init bash

echo "Miniconda installation completed"
EOF

    chmod +x "$EXEC_DIR/install_miniconda.sh"
    
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$TARGET_USER" -H "$EXEC_DIR/install_miniconda.sh" "$USER_HOME" "$MINICONDA_PATH"
    else
        "$EXEC_DIR/install_miniconda.sh" "$USER_HOME" "$MINICONDA_PATH"
    fi
    
    rm "$EXEC_DIR/install_miniconda.sh"
    
    fix_permissions
    
    log_success "Miniconda installed successfully"
}

setup_conda_environment() {
    log_info "Setting up conda environment..."
    
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/setup_conda_env.sh" << 'EOF'
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
PYTHON_VERSION="$PYTHON_VERSION"

export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "$USER_HOME"

source "$MINICONDA_PATH/etc/profile.d/conda.sh"

if conda env list | grep -q "$CONDA_ENV_NAME"; then
    echo "Removing existing environment..."
    conda env remove -n "$CONDA_ENV_NAME" -y
fi

echo "Creating conda environment: $CONDA_ENV_NAME"
conda create -n "$CONDA_ENV_NAME" python="$PYTHON_VERSION" -y

conda activate "$CONDA_ENV_NAME"

echo "Python version in environment:"
python --version
echo "Python executable: $(which python)"

echo "Conda environment setup completed"
EOF

    sed -i "s|\$USER_HOME|$USER_HOME|g" "$EXEC_DIR/setup_conda_env.sh"
    sed -i "s|\$TARGET_USER|$TARGET_USER|g" "$EXEC_DIR/setup_conda_env.sh"
    sed -i "s|\$MINICONDA_PATH|$MINICONDA_PATH|g" "$EXEC_DIR/setup_conda_env.sh"
    sed -i "s|\$CONDA_ENV_NAME|$CONDA_ENV_NAME|g" "$EXEC_DIR/setup_conda_env.sh"
    sed -i "s|\$PYTHON_VERSION|$PYTHON_VERSION|g" "$EXEC_DIR/setup_conda_env.sh"

    chmod +x "$EXEC_DIR/setup_conda_env.sh"
    
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$TARGET_USER" -H "$EXEC_DIR/setup_conda_env.sh"
    else
        "$EXEC_DIR/setup_conda_env.sh"
    fi
    
    rm "$EXEC_DIR/setup_conda_env.sh"
    log_success "Conda environment created successfully"
}

install_python_packages() {
    log_info "Installing Python packages..."
    
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/install_packages.sh" << 'EOF'
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
PROJECT_DIR="$PROJECT_DIR"

export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "$USER_HOME"

source "$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate "$CONDA_ENV_NAME"

if ! command -v python >/dev/null 2>&1; then
    echo "Installing Python..."
    conda install python=$PYTHON_VERSION -y
fi

echo "Upgrading pip..."
python -m pip install --upgrade pip

echo "Installing essential packages..."
pip install numpy pandas matplotlib seaborn requests aiohttp

echo "Installing ML packages..."
pip install scikit-learn

echo "Installing TA-Lib with comprehensive checks..."

# Step 1: Check if TA-Lib C library is available
if ldconfig -p | grep -q libta_lib; then
    echo "✅ TA-Lib C library found in system"
    TA_LIB_AVAILABLE=true
else
    echo "⚠️ TA-Lib C library not found, installing manually..."
    TA_LIB_AVAILABLE=false
fi

# Step 2: Install TA-Lib C library if needed
if [ "$TA_LIB_AVAILABLE" = false ]; then
echo "Installing TA-Lib C library from source..."
cd /tmp

# Clean any previous attempts
rm -rf ta-lib ta-lib-0.4.0-src.tar.gz

wget -q http://prdownloads.sourceforge.net/ta-lib/ta-lib-0.4.0-src.tar.gz
tar -xzf ta-lib-0.4.0-src.tar.gz
cd ta-lib/

wget 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD' -O './config.guess'
wget 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD' -O './config.sub'

# Configure and install (بر اساس نتایج جستجو[6])
./configure --prefix=/usr
make
sudo make install
sudo ldconfig
    
    # Verify installation
    if ldconfig -p | grep -q libta_lib; then
        echo "✅ TA-Lib C library installed successfully"
    else
        echo "❌ TA-Lib C library installation failed"
        cd "$USER_HOME"
        exit 1
    fi
    
    # Clean up
    cd /tmp
    rm -rf ta-lib ta-lib-0.4.0-src.tar.gz
    cd "$USER_HOME"
fi

# Step 3: Set environment variables for Python wrapper
export TA_LIBRARY_PATH="/usr/local/lib:/usr/lib/x86_64-linux-gnu"
export TA_INCLUDE_PATH="/usr/local/include:/usr/include"
export CFLAGS="-I/usr/local/include -I/usr/include"
export LDFLAGS="-L/usr/local/lib -L/usr/lib/x86_64-linux-gnu"

# Step 4: Install Python TA-Lib wrapper
echo "Installing TA-Lib Python wrapper..."
if pip install TA-Lib --no-cache-dir --verbose; then
    echo "✅ TA-Lib Python wrapper installed successfully"
else
    echo "❌ TA-Lib Python wrapper installation failed"
    echo "Trying alternative installation methods..."
    
    # Try with specific flags
    if pip install TA-Lib --no-cache-dir --global-option=build_ext --global-option="-I/usr/local/include" --global-option="-L/usr/local/lib"; then
        echo "✅ TA-Lib installed with custom flags"
    else
        echo "⚠️ TA-Lib installation failed, continuing without it"
    fi
fi

echo "Installing python-telegram-bot..."
pip install python-telegram-bot

if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    echo "Installing from requirements.txt..."
    pip install -r "$PROJECT_DIR/requirements.txt" || echo "Some requirements failed, continuing..."
fi

echo "Verifying installations..."
python -c "
import sys
print('Python executable:', sys.executable)
print('Python version:', sys.version)

packages = ['numpy', 'pandas', 'requests']
for pkg in packages:
    try:
        module = __import__(pkg)
        print(f'✓ {pkg}: {getattr(module, \"__version__\", \"unknown\")}')
    except ImportError:
        print(f'✗ {pkg}: not installed')

# Test TA-Lib specifically
try:
    import talib
    print(f'✅ TA-Lib: {talib.__version__}')
    
    # Test a simple function
    import numpy as np
    test_data = np.random.random(100)
    sma = talib.SMA(test_data, timeperiod=10)
    print('✅ TA-Lib functionality test passed')
except ImportError as e:
    print(f'⚠️ TA-Lib not available: {e}')
except Exception as e:
    print(f'⚠️ TA-Lib test failed: {e}')

print('✓ Package verification completed')
"

echo "Package installation completed successfully"
EOF

    sed -i "s|\$USER_HOME|$USER_HOME|g" "$EXEC_DIR/install_packages.sh"
    sed -i "s|\$TARGET_USER|$TARGET_USER|g" "$EXEC_DIR/install_packages.sh"
    sed -i "s|\$MINICONDA_PATH|$MINICONDA_PATH|g" "$EXEC_DIR/install_packages.sh"
    sed -i "s|\$CONDA_ENV_NAME|$CONDA_ENV_NAME|g" "$EXEC_DIR/install_packages.sh"
    sed -i "s|\$PYTHON_VERSION|$PYTHON_VERSION|g" "$EXEC_DIR/install_packages.sh"
    sed -i "s|\$PROJECT_DIR|$PROJECT_DIR|g" "$EXEC_DIR/install_packages.sh"

    chmod +x "$EXEC_DIR/install_packages.sh"
    
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$TARGET_USER" -H "$EXEC_DIR/install_packages.sh"
    else
        "$EXEC_DIR/install_packages.sh"
    fi
    
    rm "$EXEC_DIR/install_packages.sh"
    log_success "Python packages installed successfully"
}

create_activation_script() {
    log_info "Creating activation script..."
    
    cat > "$USER_HOME/activate_flowai.sh" << 'EOF'
#!/bin/bash
# FlowAI Environment Activation Script - Fixed Version

export HOME="$USER_HOME"
export USER="$TARGET_USER"
export SHELL="/bin/bash"

unset XDG_CONFIG_HOME
unset SUDO_USER
unset SUDO_UID
unset SUDO_GID
unset SUDO_COMMAND

cd "$HOME"

if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
    source "$MINICONDA_PATH/etc/profile.d/conda.sh"
else
    echo "❌ Conda not found!"
    exit 1
fi

if conda env list | grep -q "$CONDA_ENV_NAME"; then
    conda activate "$CONDA_ENV_NAME"
    
    if command -v python >/dev/null 2>&1; then
        echo "✅ FlowAI environment activated!"
        echo "Python version: $(python --version)"
        echo "Environment: $CONDA_DEFAULT_ENV"
    else
        echo "⚠️ Installing Python..."
        conda install python=$PYTHON_VERSION -y
    fi
else
    echo "❌ Environment not found!"
    exit 1
fi

if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    echo "📁 Changed to project directory: $PROJECT_DIR"
fi

echo "🎯 FlowAI environment is ready!"
EOF

    sed -i "s|\$USER_HOME|$USER_HOME|g" "$USER_HOME/activate_flowai.sh"
    sed -i "s|\$TARGET_USER|$TARGET_USER|g" "$USER_HOME/activate_flowai.sh"
    sed -i "s|\$MINICONDA_PATH|$MINICONDA_PATH|g" "$USER_HOME/activate_flowai.sh"
    sed -i "s|\$CONDA_ENV_NAME|$CONDA_ENV_NAME|g" "$USER_HOME/activate_flowai.sh"
    sed -i "s|\$PYTHON_VERSION|$PYTHON_VERSION|g" "$USER_HOME/activate_flowai.sh"
    sed -i "s|\$PROJECT_DIR|$PROJECT_DIR|g" "$USER_HOME/activate_flowai.sh"

    chmod +x "$USER_HOME/activate_flowai.sh"
    
    if [ "$EUID" -eq 0 ]; then
        chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/activate_flowai.sh"
    fi
    
    log_success "Activation script created at $USER_HOME/activate_flowai.sh"
}

final_verification() {
    log_info "Performing final verification..."
    
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/verify_installation.sh" << 'EOF'
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"

export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "$USER_HOME"

source "$MINICONDA_PATH/etc/profile.d/conda.sh"

if ! conda env list | grep -q "$CONDA_ENV_NAME"; then
    echo "ERROR: Environment $CONDA_ENV_NAME not found"
    exit 1
fi

conda activate "$CONDA_ENV_NAME"

echo "=== Installation Verification ==="
echo "Conda version: $(conda --version)"
echo "Python version: $(python --version)"
echo "Pip version: $(pip --version)"
echo "Active environment: $CONDA_DEFAULT_ENV"
echo "Python executable: $(which python)"

echo "=== Package Verification ==="
python -c "
import sys
print('Python executable:', sys.executable)

packages = ['numpy', 'pandas', 'requests', 'sklearn']
for pkg in packages:
    try:
        __import__(pkg)
        print(f'✓ {pkg}')
    except ImportError:
        print(f'✗ {pkg}')

try:
    import talib
    print(f'✓ talib: {talib.__version__}')
except ImportError:
    print('⚠ talib: Not available')
"

echo "=== Verification Completed ==="
EOF

    sed -i "s|\$USER_HOME|$USER_HOME|g" "$EXEC_DIR/verify_installation.sh"
    sed -i "s|\$TARGET_USER|$TARGET_USER|g" "$EXEC_DIR/verify_installation.sh"
    sed -i "s|\$MINICONDA_PATH|$MINICONDA_PATH|g" "$EXEC_DIR/verify_installation.sh"
    sed -i "s|\$CONDA_ENV_NAME|$CONDA_ENV_NAME|g" "$EXEC_DIR/verify_installation.sh"

    chmod +x "$EXEC_DIR/verify_installation.sh"
    
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$TARGET_USER" -H "$EXEC_DIR/verify_installation.sh"
    else
        "$EXEC_DIR/verify_installation.sh"
    fi
    
    rm "$EXEC_DIR/verify_installation.sh"
    log_success "Installation verification completed"
}

# --- Function: Perform Installation ---
perform_installation() {
    log_info "Starting FlowAI installation process..."
    
    install_build_dependencies
    complete_system_cleanup
    ensure_user_exists
    install_miniconda_as_user
    setup_conda_environment
    install_python_packages
    create_activation_script
    fix_project_permissions
    final_verification
    
    log_success "=== FlowAI Installation Completed Successfully ==="
    log_info ""
    log_info "🎉 Installation Summary:"
    log_info "   ✓ User: $TARGET_USER"
    log_info "   ✓ Conda environment: $CONDA_ENV_NAME"
    log_info "   ✓ Python version: $PYTHON_VERSION"
    log_info "   ✓ Miniconda path: $MINICONDA_PATH"
    log_info "   ✓ Build tools: GCC, Make, CMake installed"
    log_info ""
    log_info "🚀 To activate the environment:"
    log_info "   Method 1: source $USER_HOME/activate_flowai.sh"
    log_info "   Method 2: su - $TARGET_USER && conda activate $CONDA_ENV_NAME"
    log_info ""
    log_info "📁 Project directory: $PROJECT_DIR"
    log_info ""
}

# --- Main Function ---
main() {
    echo "🤖 FlowAI Trading Bot - Advanced Installation & Management Script"
    echo "================================================================="
    
    if [ "$(check_installation)" = "true" ]; then
        log_success "FlowAI environment is already installed!"
        show_management_menu
    else
        log_info "FlowAI environment not found. Starting installation..."
        
        if [ "$EUID" -ne 0 ]; then
            log_fatal "Installation requires root privileges. Please run with sudo."
        fi
        
        perform_installation
        
        log_info "Installation completed! Starting management menu..."
        show_management_menu
    fi
}

# --- Script Entry Point ---
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
