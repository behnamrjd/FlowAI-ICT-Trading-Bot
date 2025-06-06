#!/bin/bash

# FlowAI Complete Installation & Management Script - Permission Fixed Version
# Handles installation check and provides management menu with all permission fixes

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

# --- Function: Create Executable Directory ---
create_exec_dir() {
    # Use user home instead of /tmp to avoid noexec issues
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
    
    # Stop any running conda processes
    pkill -f conda || true
    pkill -f python || true
    
    # Remove conda environment
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
    
    # Remove all conda files and directories
    rm -rf "$MINICONDA_PATH" 2>/dev/null || true
    rm -rf "$USER_HOME/.conda" 2>/dev/null || true
    rm -rf "$USER_HOME/.condarc" 2>/dev/null || true
    rm -rf "$USER_HOME/.cache/pip" 2>/dev/null || true
    rm -rf "$USER_HOME/.flowai_scripts" 2>/dev/null || true
    
    # Remove activation scripts
    rm -f "$USER_HOME/activate_flowai.sh" 2>/dev/null || true
    rm -f "$USER_HOME/simple_activate.sh" 2>/dev/null || true
    
    # Clean shell profiles completely
    for profile in "$USER_HOME/.bashrc" "$USER_HOME/.bash_profile" "$USER_HOME/.profile" "$USER_HOME/.zshrc"; do
        if [ -f "$profile" ]; then
            # Remove conda initialization
            sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' "$profile" 2>/dev/null || true
            # Remove conda exports
            sed -i '/export.*conda/Id' "$profile" 2>/dev/null || true
            sed -i '/export.*CONDA/Id' "$profile" 2>/dev/null || true
            # Remove miniconda paths
            sed -i '/miniconda3/d' "$profile" 2>/dev/null || true
        fi
    done
    
    # Clean temporary files from both /tmp and user directory
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
    
    # Clean system conda references
    rm -f /etc/profile.d/conda.sh 2>/dev/null || true
    
    # Reset user permissions
    if id "$TARGET_USER" &>/dev/null; then
        chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME" 2>/dev/null || true
        chmod 755 "$USER_HOME" 2>/dev/null || true
    fi
    
    log_success "Complete system cleanup finished"
}

# --- Function: Enhanced Installation Check ---
check_installation() {
    local is_installed=true
    
    # Check if user exists
    if ! id "$TARGET_USER" &>/dev/null; then
        is_installed=false
        echo "$is_installed"
        return
    fi
    
    # Check if miniconda exists and is accessible
    if [ ! -d "$MINICONDA_PATH" ] || [ ! -f "$MINICONDA_PATH/bin/conda" ]; then
        is_installed=false
        echo "$is_installed"
        return
    fi
    
    # Check if conda environment exists and has Python
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
    
    # Check if activation script exists and is executable
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
    
    # Ensure user home directory exists and has correct permissions
    if [ ! -d "$USER_HOME" ]; then
        mkdir -p "$USER_HOME"
    fi
    
    # Fix ownership of all user files
    chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME" 2>/dev/null || true
    
    # Fix specific conda directories if they exist
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
    
    # Fix home directory permissions
    chmod 755 "$USER_HOME" 2>/dev/null || true
    
    log_success "Permissions fixed"
}

# --- Function: Activate Environment (Fixed) ---
activate_environment() {
    log_info "Activating FlowAI environment..."
    
    # Check installation first
    if [ "$(check_installation)" != "true" ]; then
        log_error "FlowAI environment is not properly installed!"
        log_info "Please run option 5 (Repair Installation) first."
        return 1
    fi
    
    # Fix permissions first
    fix_permissions
    
    # Create executable directory
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/activate_env_fixed.sh" << EOF
#!/bin/bash

# Set proper environment variables
export HOME="$USER_HOME"
export USER="$TARGET_USER"
export SHELL="/bin/bash"

# Clear problematic variables
unset XDG_CONFIG_HOME
unset SUDO_USER
unset SUDO_UID
unset SUDO_GID
unset SUDO_COMMAND

# Change to user home directory
cd "\$HOME"

# Source conda with error handling
if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
    source "$MINICONDA_PATH/etc/profile.d/conda.sh"
else
    echo "❌ Conda not found at $MINICONDA_PATH"
    exit 1
fi

# Activate environment with error handling
if conda env list | grep -q "$CONDA_ENV_NAME"; then
    conda activate "$CONDA_ENV_NAME"
    
    # Verify Python is available
    if command -v python >/dev/null 2>&1; then
        echo "🚀 FlowAI environment activated successfully!"
        echo "Python version: \$(python --version)"
        echo "Environment: \$CONDA_DEFAULT_ENV"
        echo "Python executable: \$(which python)"
    else
        echo "⚠️ Environment activated but Python not found. Installing Python..."
        conda install python=$PYTHON_VERSION -y
        echo "✅ Python installed. Environment ready!"
    fi
else
    echo "❌ Environment '$CONDA_ENV_NAME' not found"
    exit 1
fi

# Change to project directory if exists
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

# Start interactive shell with environment activated
exec bash --login
EOF

    chmod +x "$EXEC_DIR/activate_env_fixed.sh"
    chown "$TARGET_USER:$TARGET_USER" "$EXEC_DIR/activate_env_fixed.sh"
    
    # Execute as target user with clean environment
    sudo -u "$TARGET_USER" -H "$EXEC_DIR/activate_env_fixed.sh"
    
    rm -f "$EXEC_DIR/activate_env_fixed.sh"
}

# --- Function: Run Trading Bot (Fixed) ---
run_trading_bot() {
    log_info "Starting FlowAI Trading Bot..."
    
    # Check installation first
    if [ "$(check_installation)" != "true" ]; then
        log_error "FlowAI environment is not properly installed!"
        log_info "Please run option 5 (Repair Installation) first."
        return 1
    fi
    
    # Fix permissions first
    fix_permissions
    
    # Create executable directory
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/run_bot_fixed.sh" << EOF
#!/bin/bash

# Set proper environment
export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "\$HOME"

# Source conda
source "$MINICONDA_PATH/etc/profile.d/conda.sh"

# Activate environment
conda activate "$CONDA_ENV_NAME"

# Verify Python
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
        echo "📁 Current directory: \$(pwd)"
        echo "📋 Directory contents:"
        ls -la
    fi
else
    echo "❌ Project directory not found: $PROJECT_DIR"
    echo "📁 Please ensure the FlowAI project is properly installed"
    echo "💡 You can clone it with: git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git $PROJECT_DIR"
fi
EOF

    chmod +x "$EXEC_DIR/run_bot_fixed.sh"
    chown "$TARGET_USER:$TARGET_USER" "$EXEC_DIR/run_bot_fixed.sh"
    
    sudo -u "$TARGET_USER" -H "$EXEC_DIR/run_bot_fixed.sh"
    
    rm -f "$EXEC_DIR/run_bot_fixed.sh"
}

# --- Function: Update Packages (Fixed) ---
update_packages() {
    log_info "Updating FlowAI packages..."
    
    # Check installation first
    if [ "$(check_installation)" != "true" ]; then
        log_error "FlowAI environment is not properly installed!"
        log_info "Please run option 5 (Repair Installation) first."
        return 1
    fi
    
    # Fix permissions first
    fix_permissions
    
    # Create executable directory
    EXEC_DIR=$(create_exec_dir)
    
    cat > "$EXEC_DIR/update_packages_fixed.sh" << EOF
#!/bin/bash

# Set proper environment
export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "\$HOME"

# Source conda
source "$MINICONDA_PATH/etc/profile.d/conda.sh"

# Activate environment
conda activate "$CONDA_ENV_NAME"

# Verify Python
if ! command -v python >/dev/null 2>&1; then
    echo "⚠️ Python not found. Installing..."
    conda install python=$PYTHON_VERSION -y
fi

echo "📦 Updating pip..."
python -m pip install --upgrade pip

echo "📦 Updating conda packages..."
conda update --all -y

if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    echo "📦 Updating project requirements..."
    pip install --upgrade -r "$PROJECT_DIR/requirements.txt"
else
    echo "📦 Updating common packages..."
    pip install --upgrade numpy pandas matplotlib seaborn requests python-telegram-bot scikit-learn
    
    # Update TA-Lib if possible
    echo "📦 Updating TA-Lib..."
    conda install -c conda-forge ta-lib -y || pip install --upgrade TA-Lib || echo "⚠️ TA-Lib update failed"
fi

echo "✅ Package update completed!"

# Show updated package versions
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
    
    # Use the complete cleanup function
    complete_system_cleanup
    
    # Remove user (optional)
    read -p "Remove user '$TARGET_USER' completely? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        userdel -r "$TARGET_USER" 2>/dev/null || true
        log_success "User removed"
    fi
    
    # Remove project directory (optional)
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

# --- Function: Show System Status (Fixed) ---
show_status() {
    log_info "FlowAI System Status:"
    echo ""
    
    # Check user
    if id "$TARGET_USER" &>/dev/null; then
        echo "✅ User: $TARGET_USER (exists)"
    else
        echo "❌ User: $TARGET_USER (not found)"
        return
    fi
    
    # Check miniconda
    if [ -d "$MINICONDA_PATH" ] && [ -f "$MINICONDA_PATH/bin/conda" ]; then
        echo "✅ Miniconda: Installed at $MINICONDA_PATH"
    else
        echo "❌ Miniconda: Not found or corrupted"
        return
    fi
    
    # Check conda environment with fixed permissions
    if sudo -u "$TARGET_USER" bash -c "
        export HOME='$USER_HOME'
        export USER='$TARGET_USER'
        unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        cd '$USER_HOME'
        source '$MINICONDA_PATH/etc/profile.d/conda.sh' 2>/dev/null &&
        conda env list | grep -q '$CONDA_ENV_NAME'
    " 2>/dev/null; then
        echo "✅ Conda Environment: $CONDA_ENV_NAME (exists)"
        
        # Show package status
        echo ""
        echo "📦 Package Status:"
        sudo -u "$TARGET_USER" bash -c "
            export HOME='$USER_HOME'
            export USER='$TARGET_USER'
            unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
            cd '$USER_HOME'
            source '$MINICONDA_PATH/etc/profile.d/conda.sh'
            conda activate '$CONDA_ENV_NAME'
            
            # Check if Python is available
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
    
    # Check project directory
    if [ -d "$PROJECT_DIR" ]; then
        echo "✅ Project Directory: $PROJECT_DIR"
        if [ -f "$PROJECT_DIR/main.py" ] || [ -f "$PROJECT_DIR/bot.py" ] || [ -f "$PROJECT_DIR/run.py" ]; then
            echo "   ✅ Bot files found"
        else
            echo "   ⚠️  Bot main file not found"
        fi
    else
        echo "❌ Project Directory: Not found"
        echo "   💡 Clone with: git clone https://github.com/behnamrjd/FlowAI-ICT-Trading-Bot.git $PROJECT_DIR"
    fi
    
    # Check overall installation status
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
    
    # Fix permissions first
    fix_permissions
    
    # Check if user exists
    if ! id "$TARGET_USER" &>/dev/null; then
        log_error "User $TARGET_USER does not exist. Please reinstall completely."
        return 1
    fi
    
    # Check if miniconda exists
    if [ ! -d "$MINICONDA_PATH" ] || [ ! -f "$MINICONDA_PATH/bin/conda" ]; then
        log_error "Miniconda not found. Please reinstall completely."
        return 1
    fi
    
    # Create executable directory
    EXEC_DIR=$(create_exec_dir)
    
    # Repair conda environment
    cat > "$EXEC_DIR/repair_env.sh" << EOF
#!/bin/bash

export HOME="$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "\$HOME"

# Source conda
source "$MINICONDA_PATH/etc/profile.d/conda.sh"

# Check if environment exists
if conda env list | grep -q "$CONDA_ENV_NAME"; then
    echo "✅ Environment exists, checking Python..."
    conda activate "$CONDA_ENV_NAME"
    
    # Install Python if missing
    if ! command -v python >/dev/null 2>&1; then
        echo "🔧 Installing Python..."
        conda install python=$PYTHON_VERSION -y
    fi
    
    # Install essential packages
    echo "🔧 Installing essential packages..."
    pip install --upgrade pip
    pip install numpy pandas requests python-telegram-bot
    
    # Try to install TA-Lib
    conda install -c conda-forge ta-lib -y || pip install TA-Lib || echo "⚠️ TA-Lib installation failed"
    
    echo "✅ Environment repaired successfully!"
else
    echo "❌ Environment not found. Creating new environment..."
    conda create -n "$CONDA_ENV_NAME" python=$PYTHON_VERSION -y
    conda activate "$CONDA_ENV_NAME"
    
    # Install packages
    pip install --upgrade pip
    pip install numpy pandas requests python-telegram-bot
    conda install -c conda-forge ta-lib -y || pip install TA-Lib || echo "⚠️ TA-Lib installation failed"
    
    echo "✅ Environment created and configured!"
fi
EOF

    chmod +x "$EXEC_DIR/repair_env.sh"
    chown "$TARGET_USER:$TARGET_USER" "$EXEC_DIR/repair_env.sh"
    
    sudo -u "$TARGET_USER" -H "$EXEC_DIR/repair_env.sh"
    
    rm -f "$EXEC_DIR/repair_env.sh"
    
    # Recreate activation script
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
        echo "1) 🚀 Activate Environment"
        echo "2) 🤖 Run Trading Bot"
        echo "3) 📦 Update Packages"
        echo "4) 📊 Show System Status"
        echo "5) 🔧 Repair Installation"
        echo "6) 🗑️  Complete Uninstall"
        echo "7) 🚪 Exit"
        echo ""
        read -p "Choose an option (1-7): " choice
        
        case $choice in
            1)
                activate_environment
                ;;
            2)
                run_trading_bot
                read -p "Press Enter to continue..."
                ;;
            3)
                update_packages
                read -p "Press Enter to continue..."
                ;;
            4)
                show_status
                read -p "Press Enter to continue..."
                ;;
            5)
                repair_installation
                read -p "Press Enter to continue..."
                ;;
            6)
                uninstall_flowai
                if [ ! -d "$USER_HOME" ] || [ "$(check_installation)" != "true" ]; then
                    echo "FlowAI has been uninstalled. Exiting..."
                    exit 0
                fi
                ;;
            7)
                log_info "Exiting FlowAI Management..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please choose 1-7."
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
}

install_miniconda_as_user() {
    log_info "Installing Miniconda as user $TARGET_USER..."
    
    # Create executable directory
    EXEC_DIR=$(create_exec_dir)
    
    # Create installation script for user execution
    cat > "$EXEC_DIR/install_miniconda.sh" << 'EOF'
#!/bin/bash
set -e

USER_HOME="$1"
MINICONDA_PATH="$2"

# Set proper environment
export HOME="$USER_HOME"
export USER="flowaibot"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "$USER_HOME"

# Download Miniconda
echo "Downloading Miniconda..."
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh

# Install Miniconda
echo "Installing Miniconda..."
bash miniconda.sh -b -p "$MINICONDA_PATH"
rm miniconda.sh

# Initialize conda for bash
echo "Initializing conda..."
"$MINICONDA_PATH/bin/conda" init bash

echo "Miniconda installation completed"
EOF

    chmod +x "$EXEC_DIR/install_miniconda.sh"
    
    # Execute as target user with clean environment
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$TARGET_USER" -H "$EXEC_DIR/install_miniconda.sh" "$USER_HOME" "$MINICONDA_PATH"
    else
        "$EXEC_DIR/install_miniconda.sh" "$USER_HOME" "$MINICONDA_PATH"
    fi
    
    rm "$EXEC_DIR/install_miniconda.sh"
    
    # Fix permissions after installation
    fix_permissions
    
    log_success "Miniconda installed successfully"
}

setup_conda_environment() {
    log_info "Setting up conda environment..."
    
    # Create executable directory
    EXEC_DIR=$(create_exec_dir)
    
    # Create environment setup script
    cat > "$EXEC_DIR/setup_conda_env.sh" << EOF
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
PYTHON_VERSION="$PYTHON_VERSION"

# Set proper environment
export HOME="\$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "\$USER_HOME"

# Source conda
source "\$MINICONDA_PATH/etc/profile.d/conda.sh"

# Remove existing environment if exists
if conda env list | grep -q "\$CONDA_ENV_NAME"; then
    echo "Removing existing environment..."
    conda env remove -n "\$CONDA_ENV_NAME" -y
fi

# Create new environment with Python
echo "Creating conda environment: \$CONDA_ENV_NAME"
conda create -n "\$CONDA_ENV_NAME" python="\$PYTHON_VERSION" -y

# Activate environment
conda activate "\$CONDA_ENV_NAME"

# Verify environment
echo "Python version in environment:"
python --version
echo "Python executable: \$(which python)"

echo "Conda environment setup completed"
EOF

    chmod +x "$EXEC_DIR/setup_conda_env.sh"
    
    # Execute as target user
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
    
    # Create executable directory
    EXEC_DIR=$(create_exec_dir)
    
    # Create package installation script
    cat > "$EXEC_DIR/install_packages.sh" << EOF
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
PROJECT_DIR="$PROJECT_DIR"

# Set proper environment
export HOME="\$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "\$USER_HOME"

# Source conda
source "\$MINICONDA_PATH/etc/profile.d/conda.sh"

# Activate environment
conda activate "\$CONDA_ENV_NAME"

# Verify Python is available
if ! command -v python >/dev/null 2>&1; then
    echo "Installing Python..."
    conda install python=$PYTHON_VERSION -y
fi

# Upgrade pip
echo "Upgrading pip..."
python -m pip install --upgrade pip

# Install essential packages
echo "Installing essential packages..."
pip install numpy pandas matplotlib seaborn requests aiohttp

# Install machine learning packages
echo "Installing ML packages..."
pip install scikit-learn

# Install TA-Lib via conda (most reliable method)
echo "Installing TA-Lib..."
conda install -c conda-forge ta-lib -y || {
    echo "Conda TA-Lib failed, trying pip..."
    pip install TA-Lib || echo "TA-Lib installation failed, continuing..."
}

# Install Telegram bot library
echo "Installing python-telegram-bot..."
pip install python-telegram-bot

# Install requirements.txt if exists
if [ -f "\$PROJECT_DIR/requirements.txt" ]; then
    echo "Installing from requirements.txt..."
    pip install -r "\$PROJECT_DIR/requirements.txt" || echo "Some requirements failed, continuing..."
fi

# Verify critical imports
echo "Verifying installations..."
python -c "
try:
    import numpy; print('✓ NumPy:', numpy.__version__)
    import pandas; print('✓ Pandas:', pandas.__version__)
    import requests; print('✓ Requests installed')
    try:
        import talib; print('✓ TA-Lib:', talib.__version__)
    except ImportError:
        print('⚠ TA-Lib not available')
    print('✓ All critical packages verified')
except Exception as e:
    print('✗ Package verification failed:', e)
    exit(1)
"

echo "Package installation completed successfully"
EOF

    chmod +x "$EXEC_DIR/install_packages.sh"
    
    # Execute as target user
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
    
    # Create improved activation script
    cat > "$USER_HOME/activate_flowai.sh" << EOF
#!/bin/bash
# FlowAI Environment Activation Script - Fixed Version

# Set proper environment
export HOME="$USER_HOME"
export USER="$TARGET_USER"
export SHELL="/bin/bash"

# Clear problematic variables
unset XDG_CONFIG_HOME
unset SUDO_USER
unset SUDO_UID
unset SUDO_GID
unset SUDO_COMMAND

# Change to user home
cd "\$HOME"

# Source conda
if [ -f "$MINICONDA_PATH/etc/profile.d/conda.sh" ]; then
    source "$MINICONDA_PATH/etc/profile.d/conda.sh"
else
    echo "❌ Conda not found!"
    exit 1
fi

# Activate environment
if conda env list | grep -q "$CONDA_ENV_NAME"; then
    conda activate "$CONDA_ENV_NAME"
    
    # Verify Python
    if command -v python >/dev/null 2>&1; then
        echo "✅ FlowAI environment activated!"
        echo "Python version: \$(python --version)"
        echo "Environment: \$CONDA_DEFAULT_ENV"
    else
        echo "⚠️ Installing Python..."
        conda install python=$PYTHON_VERSION -y
    fi
else
    echo "❌ Environment not found!"
    exit 1
fi

# Change to project directory if exists
if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    echo "📁 Changed to project directory: $PROJECT_DIR"
fi

echo "🎯 FlowAI environment is ready!"
EOF

    chmod +x "$USER_HOME/activate_flowai.sh"
    
    if [ "$EUID" -eq 0 ]; then
        chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/activate_flowai.sh"
    fi
    
    log_success "Activation script created at $USER_HOME/activate_flowai.sh"
}

final_verification() {
    log_info "Performing final verification..."
    
    # Create executable directory
    EXEC_DIR=$(create_exec_dir)
    
    # Create verification script
    cat > "$EXEC_DIR/verify_installation.sh" << EOF
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"

export HOME="\$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND

cd "\$USER_HOME"

# Source conda
source "\$MINICONDA_PATH/etc/profile.d/conda.sh"

# Check if environment exists
if ! conda env list | grep -q "\$CONDA_ENV_NAME"; then
    echo "ERROR: Environment \$CONDA_ENV_NAME not found"
    exit 1
fi

# Activate and test
conda activate "\$CONDA_ENV_NAME"

echo "=== Installation Verification ==="
echo "Conda version: \$(conda --version)"
echo "Python version: \$(python --version)"
echo "Pip version: \$(pip --version)"
echo "Active environment: \$CONDA_DEFAULT_ENV"
echo "Python executable: \$(which python)"

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

    chmod +x "$EXEC_DIR/verify_installation.sh"
    
    # Execute verification
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
    
    # Step 1: Complete cleanup first
    complete_system_cleanup
    
    # Step 2: Ensure user exists
    ensure_user_exists
    
    # Step 3: Install Miniconda
    install_miniconda_as_user
    
    # Step 4: Setup conda environment
    setup_conda_environment
    
    # Step 5: Install Python packages
    install_python_packages
    
    # Step 6: Create activation script
    create_activation_script
    
    # Step 7: Final verification
    final_verification
    
    log_success "=== FlowAI Installation Completed Successfully ==="
    log_info ""
    log_info "🎉 Installation Summary:"
    log_info "   ✓ User: $TARGET_USER"
    log_info "   ✓ Conda environment: $CONDA_ENV_NAME"
    log_info "   ✓ Python version: $PYTHON_VERSION"
    log_info "   ✓ Miniconda path: $MINICONDA_PATH"
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
    echo "🤖 FlowAI Trading Bot - Installation & Management Script"
    echo "=================================================="
    
    # Check if already installed
    if [ "$(check_installation)" = "true" ]; then
        log_success "FlowAI environment is already installed!"
        show_management_menu
    else
        log_info "FlowAI environment not found. Starting installation..."
        
        # Check if running as root for installation
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
