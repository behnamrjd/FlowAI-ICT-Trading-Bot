#!/bin/bash

# FlowAI Complete Installation & Management Script
# Handles installation check and provides management menu

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

# --- Function: Check Installation Status ---
check_installation() {
    local is_installed=true
    
    # Check if user exists
    if ! id "$TARGET_USER" &>/dev/null; then
        is_installed=false
    fi
    
    # Check if miniconda exists
    if [ ! -d "$MINICONDA_PATH" ]; then
        is_installed=false
    fi
    
    # Check if conda environment exists
    if [ "$is_installed" = true ]; then
        if ! sudo -u "$TARGET_USER" bash -c "source '$MINICONDA_PATH/etc/profile.d/conda.sh' && conda env list | grep -q '$CONDA_ENV_NAME'" 2>/dev/null; then
            is_installed=false
        fi
    fi
    
    # Check if activation script exists
    if [ ! -f "$USER_HOME/activate_flowai.sh" ]; then
        is_installed=false
    fi
    
    echo "$is_installed"
}

# --- Function: Activate Environment ---
activate_environment() {
    log_info "Activating FlowAI environment..."
    
    cat > /tmp/activate_env.sh << EOF
#!/bin/bash
export HOME="$USER_HOME"
export USER="$TARGET_USER"
source "$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate $CONDA_ENV_NAME

echo "🚀 FlowAI environment activated!"
echo "Python version: \$(python --version)"
echo "Environment: \$CONDA_DEFAULT_ENV"

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

# Start interactive shell with environment activated
exec bash
EOF

    chmod +x /tmp/activate_env.sh
    
    if [ "$(whoami)" = "root" ]; then
        sudo -u "$TARGET_USER" bash /tmp/activate_env.sh
    else
        bash /tmp/activate_env.sh
    fi
    
    rm -f /tmp/activate_env.sh
}

# --- Function: Run Trading Bot ---
run_trading_bot() {
    log_info "Starting FlowAI Trading Bot..."
    
    cat > /tmp/run_bot.sh << EOF
#!/bin/bash
export HOME="$USER_HOME"
export USER="$TARGET_USER"
source "$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate $CONDA_ENV_NAME

if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    
    if [ -f "main.py" ]; then
        echo "🤖 Starting FlowAI Trading Bot..."
        python main.py
    elif [ -f "bot.py" ]; then
        echo "🤖 Starting FlowAI Trading Bot..."
        python bot.py
    elif [ -f "run.py" ]; then
        echo "🤖 Starting FlowAI Trading Bot..."
        python run.py
    else
        echo "❌ Bot main file not found. Available Python files:"
        ls -la *.py 2>/dev/null || echo "No Python files found"
        echo ""
        echo "Please run manually: python <your_bot_file>.py"
    fi
else
    echo "❌ Project directory not found: $PROJECT_DIR"
    echo "Please ensure the FlowAI project is properly installed"
fi
EOF

    chmod +x /tmp/run_bot.sh
    
    if [ "$(whoami)" = "root" ]; then
        sudo -u "$TARGET_USER" bash /tmp/run_bot.sh
    else
        bash /tmp/run_bot.sh
    fi
    
    rm -f /tmp/run_bot.sh
}

# --- Function: Update Packages ---
update_packages() {
    log_info "Updating FlowAI packages..."
    
    cat > /tmp/update_packages.sh << EOF
#!/bin/bash
export HOME="$USER_HOME"
export USER="$TARGET_USER"
source "$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate $CONDA_ENV_NAME

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

    chmod +x /tmp/update_packages.sh
    
    if [ "$(whoami)" = "root" ]; then
        sudo -u "$TARGET_USER" bash /tmp/update_packages.sh
    else
        bash /tmp/update_packages.sh
    fi
    
    rm -f /tmp/update_packages.sh
    log_success "Packages updated successfully!"
}

# --- Function: Uninstall FlowAI ---
uninstall_flowai() {
    log_warning "This will completely remove FlowAI installation!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return
    fi
    
    log_info "Uninstalling FlowAI..."
    
    # Remove conda environment
    if sudo -u "$TARGET_USER" bash -c "source '$MINICONDA_PATH/etc/profile.d/conda.sh' && conda env list | grep -q '$CONDA_ENV_NAME'" 2>/dev/null; then
        sudo -u "$TARGET_USER" bash -c "source '$MINICONDA_PATH/etc/profile.d/conda.sh' && conda env remove -n '$CONDA_ENV_NAME' -y"
        log_success "Conda environment removed"
    fi
    
    # Remove miniconda (optional)
    read -p "Remove Miniconda completely? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$MINICONDA_PATH"
        rm -rf "$USER_HOME/.conda"
        rm -f "$USER_HOME/.condarc"
        
        # Clean shell profiles
        for profile in "$USER_HOME/.bashrc" "$USER_HOME/.bash_profile" "$USER_HOME/.profile"; do
            if [ -f "$profile" ]; then
                sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' "$profile" 2>/dev/null || true
            fi
        done
        
        log_success "Miniconda removed completely"
    fi
    
    # Remove activation script
    rm -f "$USER_HOME/activate_flowai.sh"
    
    # Remove user (optional)
    read -p "Remove user '$TARGET_USER'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        userdel -r "$TARGET_USER" 2>/dev/null || true
        log_success "User removed"
    fi
    
    log_success "FlowAI uninstallation completed!"
}

# --- Function: Show System Status ---
show_status() {
    log_info "FlowAI System Status:"
    echo ""
    
    # Check user
    if id "$TARGET_USER" &>/dev/null; then
        echo "✅ User: $TARGET_USER (exists)"
    else
        echo "❌ User: $TARGET_USER (not found)"
    fi
    
    # Check miniconda
    if [ -d "$MINICONDA_PATH" ]; then
        echo "✅ Miniconda: Installed at $MINICONDA_PATH"
    else
        echo "❌ Miniconda: Not found"
    fi
    
    # Check conda environment
    if sudo -u "$TARGET_USER" bash -c "source '$MINICONDA_PATH/etc/profile.d/conda.sh' && conda env list | grep -q '$CONDA_ENV_NAME'" 2>/dev/null; then
        echo "✅ Conda Environment: $CONDA_ENV_NAME (active)"
        
        # Show package status
        echo ""
        echo "📦 Package Status:"
        sudo -u "$TARGET_USER" bash -c "
            export HOME='$USER_HOME'
            source '$MINICONDA_PATH/etc/profile.d/conda.sh'
            conda activate '$CONDA_ENV_NAME'
            python -c \"
import sys
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
        " 2>/dev/null || echo "   ❌ Cannot check packages"
    else
        echo "❌ Conda Environment: $CONDA_ENV_NAME (not found)"
    fi
    
    # Check project directory
    if [ -d "$PROJECT_DIR" ]; then
        echo "✅ Project Directory: $PROJECT_DIR"
        if [ -f "$PROJECT_DIR/main.py" ] || [ -f "$PROJECT_DIR/bot.py" ]; then
            echo "   ✅ Bot files found"
        else
            echo "   ⚠️  Bot main file not found"
        fi
    else
        echo "❌ Project Directory: Not found"
    fi
    
    echo ""
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
        echo "5) 🗑️  Uninstall FlowAI"
        echo "6) 🚪 Exit"
        echo ""
        read -p "Choose an option (1-6): " choice
        
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
                uninstall_flowai
                if [ ! -d "$MINICONDA_PATH" ]; then
                    echo "FlowAI has been uninstalled. Exiting..."
                    exit 0
                fi
                ;;
            6)
                log_info "Exiting FlowAI Management..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please choose 1-6."
                ;;
        esac
    done
}

# --- Installation Functions (Previous Code) ---
# [Include all the installation functions from the previous script here]

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

complete_cleanup() {
    log_info "Performing complete cleanup..."
    
    if [ -d "$MINICONDA_PATH" ]; then
        log_info "Removing existing miniconda installation..."
        rm -rf "$MINICONDA_PATH"
    fi
    
    rm -rf "$USER_HOME/.conda" 2>/dev/null || true
    rm -f "$USER_HOME/.condarc" 2>/dev/null || true
    
    for profile in "$USER_HOME/.bashrc" "$USER_HOME/.bash_profile" "$USER_HOME/.profile"; do
        if [ -f "$profile" ]; then
            sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' "$profile" 2>/dev/null || true
        fi
    done
    
    log_success "Cleanup completed"
}

install_miniconda_as_user() {
    log_info "Installing Miniconda as user $TARGET_USER..."
    
    cat > /tmp/install_miniconda.sh << 'EOF'
#!/bin/bash
set -e

USER_HOME="$1"
MINICONDA_PATH="$2"

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

    chmod +x /tmp/install_miniconda.sh
    
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$TARGET_USER" bash /tmp/install_miniconda.sh "$USER_HOME" "$MINICONDA_PATH"
    else
        bash /tmp/install_miniconda.sh "$USER_HOME" "$MINICONDA_PATH"
    fi
    
    rm /tmp/install_miniconda.sh
    log_success "Miniconda installed successfully"
}

setup_conda_environment() {
    log_info "Setting up conda environment..."
    
    cat > /tmp/setup_conda_env.sh << EOF
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
PYTHON_VERSION="$PYTHON_VERSION"

export HOME="\$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME
unset SUDO_USER
unset SUDO_UID
unset SUDO_GID

cd "\$USER_HOME"

source "\$MINICONDA_PATH/etc/profile.d/conda.sh"

if conda env list | grep -q "\$CONDA_ENV_NAME"; then
    echo "Removing existing environment..."
    conda env remove -n "\$CONDA_ENV_NAME" -y
fi

echo "Creating conda environment: \$CONDA_ENV_NAME"
conda create -n "\$CONDA_ENV_NAME" python="\$PYTHON_VERSION" -y

conda activate "\$CONDA_ENV_NAME"

echo "Python version in environment:"
python --version

echo "Conda environment setup completed"
EOF

    chmod +x /tmp/setup_conda_env.sh
    
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$TARGET_USER" bash /tmp/setup_conda_env.sh
    else
        bash /tmp/setup_conda_env.sh
    fi
    
    rm /tmp/setup_conda_env.sh
    log_success "Conda environment created successfully"
}

install_python_packages() {
    log_info "Installing Python packages..."
    
    cat > /tmp/install_packages.sh << EOF
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
PROJECT_DIR="$PROJECT_DIR"

export HOME="\$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME
unset SUDO_USER
unset SUDO_UID
unset SUDO_GID

cd "\$USER_HOME"

source "\$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate "\$CONDA_ENV_NAME"

echo "Upgrading pip..."
python -m pip install --upgrade pip

echo "Installing essential packages..."
pip install numpy pandas matplotlib seaborn requests aiohttp

echo "Installing ML packages..."
pip install scikit-learn

echo "Installing TA-Lib..."
conda install -c conda-forge ta-lib -y || {
    echo "Conda TA-Lib failed, trying pip..."
    pip install TA-Lib || echo "TA-Lib installation failed, continuing..."
}

echo "Installing python-telegram-bot..."
pip install python-telegram-bot

if [ -f "\$PROJECT_DIR/requirements.txt" ]; then
    echo "Installing from requirements.txt..."
    pip install -r "\$PROJECT_DIR/requirements.txt" || echo "Some requirements failed, continuing..."
fi

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

    chmod +x /tmp/install_packages.sh
    
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$TARGET_USER" bash /tmp/install_packages.sh
    else
        bash /tmp/install_packages.sh
    fi
    
    rm /tmp/install_packages.sh
    log_success "Python packages installed successfully"
}

create_activation_script() {
    log_info "Creating activation script..."
    
    cat > "$USER_HOME/activate_flowai.sh" << EOF
#!/bin/bash
# FlowAI Environment Activation Script

export HOME="$USER_HOME"
export USER="$TARGET_USER"
source "$MINICONDA_PATH/etc/profile.d/conda.sh"
conda activate $CONDA_ENV_NAME

echo "FlowAI environment activated!"
echo "Python version: \$(python --version)"
echo "Environment: \$CONDA_DEFAULT_ENV"

if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    echo "Changed to project directory: $PROJECT_DIR"
fi
EOF

    chmod +x "$USER_HOME/activate_flowai.sh"
    
    if [ "$EUID" -eq 0 ]; then
        chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/activate_flowai.sh"
    fi
    
    log_success "Activation script created at $USER_HOME/activate_flowai.sh"
}

# --- Function: Perform Installation ---
perform_installation() {
    log_info "Starting FlowAI installation process..."
    
    ensure_user_exists
    complete_cleanup
    install_miniconda_as_user
    setup_conda_environment
    install_python_packages
    create_activation_script
    
    log_success "=== FlowAI Installation Completed Successfully ==="
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
