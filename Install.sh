#!/bin/bash

# FlowAI Complete Installation Script - Final Corrected Version
# Handles all permission issues and conda installation problems

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

# --- Detect Current Execution Context ---
CURRENT_USER=$(whoami)
IS_ROOT=false
if [ "$EUID" -eq 0 ]; then
    IS_ROOT=true
fi

log_info "=== FlowAI Installation Script - Starting ==="
log_info "Current user: $CURRENT_USER"
log_info "Target user: $TARGET_USER"
log_info "Running as root: $IS_ROOT"

# --- Function: Create User if Not Exists ---
ensure_user_exists() {
    if ! id "$TARGET_USER" &>/dev/null; then
        log_info "Creating user: $TARGET_USER"
        if [ "$IS_ROOT" = true ]; then
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

# --- Function: Complete Cleanup ---
complete_cleanup() {
    log_info "Performing complete cleanup..."
    
    # Remove existing conda installation
    if [ -d "$MINICONDA_PATH" ]; then
        log_info "Removing existing miniconda installation..."
        rm -rf "$MINICONDA_PATH"
    fi
    
    # Remove conda config files
    rm -rf "$USER_HOME/.conda" 2>/dev/null || true
    rm -f "$USER_HOME/.condarc" 2>/dev/null || true
    
    # Clean conda from shell profiles
    for profile in "$USER_HOME/.bashrc" "$USER_HOME/.bash_profile" "$USER_HOME/.profile"; do
        if [ -f "$profile" ]; then
            sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' "$profile" 2>/dev/null || true
        fi
    done
    
    log_success "Cleanup completed"
}

# --- Function: Install Miniconda as User ---
install_miniconda_as_user() {
    log_info "Installing Miniconda as user $TARGET_USER..."
    
    # Create installation script for user execution
    cat > /tmp/install_miniconda.sh << 'EOF'
#!/bin/bash
set -e

USER_HOME="$1"
MINICONDA_PATH="$2"

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

    chmod +x /tmp/install_miniconda.sh
    
    # Execute as target user
    if [ "$IS_ROOT" = true ]; then
        sudo -u "$TARGET_USER" bash /tmp/install_miniconda.sh "$USER_HOME" "$MINICONDA_PATH"
    else
        bash /tmp/install_miniconda.sh "$USER_HOME" "$MINICONDA_PATH"
    fi
    
    rm /tmp/install_miniconda.sh
    log_success "Miniconda installed successfully"
}

# --- Function: Setup Conda Environment ---
setup_conda_environment() {
    log_info "Setting up conda environment..."
    
    # Create environment setup script
    cat > /tmp/setup_conda_env.sh << EOF
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
PYTHON_VERSION="$PYTHON_VERSION"

# Set proper environment
export HOME="\$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME
unset SUDO_USER
unset SUDO_UID
unset SUDO_GID

cd "\$USER_HOME"

# Source conda
source "\$MINICONDA_PATH/etc/profile.d/conda.sh"

# Remove existing environment if exists
if conda env list | grep -q "\$CONDA_ENV_NAME"; then
    echo "Removing existing environment..."
    conda env remove -n "\$CONDA_ENV_NAME" -y
fi

# Create new environment
echo "Creating conda environment: \$CONDA_ENV_NAME"
conda create -n "\$CONDA_ENV_NAME" python="\$PYTHON_VERSION" -y

# Activate environment
conda activate "\$CONDA_ENV_NAME"

# Verify environment
echo "Python version in environment:"
python --version

echo "Conda environment setup completed"
EOF

    chmod +x /tmp/setup_conda_env.sh
    
    # Execute as target user
    if [ "$IS_ROOT" = true ]; then
        sudo -u "$TARGET_USER" bash /tmp/setup_conda_env.sh
    else
        bash /tmp/setup_conda_env.sh
    fi
    
    rm /tmp/setup_conda_env.sh
    log_success "Conda environment created successfully"
}

# --- Function: Install Python Packages ---
install_python_packages() {
    log_info "Installing Python packages..."
    
    # Create package installation script
    cat > /tmp/install_packages.sh << EOF
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
PROJECT_DIR="$PROJECT_DIR"

# Set proper environment
export HOME="\$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME
unset SUDO_USER
unset SUDO_UID
unset SUDO_GID

cd "\$USER_HOME"

# Source conda
source "\$MINICONDA_PATH/etc/profile.d/conda.sh"

# Activate environment
conda activate "\$CONDA_ENV_NAME"

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

    chmod +x /tmp/install_packages.sh
    
    # Execute as target user
    if [ "$IS_ROOT" = true ]; then
        sudo -u "$TARGET_USER" bash /tmp/install_packages.sh
    else
        bash /tmp/install_packages.sh
    fi
    
    rm /tmp/install_packages.sh
    log_success "Python packages installed successfully"
}

# --- Function: Create Activation Script ---
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

# Change to project directory if exists
if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    echo "Changed to project directory: $PROJECT_DIR"
fi
EOF

    chmod +x "$USER_HOME/activate_flowai.sh"
    
    if [ "$IS_ROOT" = true ]; then
        chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/activate_flowai.sh"
    fi
    
    log_success "Activation script created at $USER_HOME/activate_flowai.sh"
}

# --- Function: Final Verification ---
final_verification() {
    log_info "Performing final verification..."
    
    # Create verification script
    cat > /tmp/verify_installation.sh << EOF
#!/bin/bash
set -e

USER_HOME="$USER_HOME"
MINICONDA_PATH="$MINICONDA_PATH"
CONDA_ENV_NAME="$CONDA_ENV_NAME"

export HOME="\$USER_HOME"
export USER="$TARGET_USER"
unset XDG_CONFIG_HOME

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

    chmod +x /tmp/verify_installation.sh
    
    # Execute verification
    if [ "$IS_ROOT" = true ]; then
        sudo -u "$TARGET_USER" bash /tmp/verify_installation.sh
    else
        bash /tmp/verify_installation.sh
    fi
    
    rm /tmp/verify_installation.sh
    log_success "Installation verification completed"
}

# --- Main Execution Flow ---
main() {
    log_info "Starting FlowAI installation process..."
    
    # Step 1: Ensure user exists
    ensure_user_exists
    
    # Step 2: Complete cleanup
    complete_cleanup
    
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

# --- Script Entry Point ---
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
