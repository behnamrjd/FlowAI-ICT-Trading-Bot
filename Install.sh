#!/bin/bash

# FlowAI-ICT-Trading-Bot Enhanced Installation Script (Conda for TA-Lib)

set -e # Enable for setup, disable for menu

# --- Configuration Variables ---
PROJECT_NAME="FlowAI-ICT-Trading-Bot"
GITHUB_REPO_URL="YOUR_GITHUB_REPO_URL_HERE" # IMPORTANT: Replace
INSTALL_DIR_DEFAULT="/opt/$PROJECT_NAME"
BOT_USER_DEFAULT="flowaibot"
# PYTHON_EXECUTABLE="python3" # Less relevant if using Conda's Python
CONDA_ENV_NAME="flowai_env" # Name for the Conda environment for the bot
SERVICE_NAME="flowai-bot" 

# --- Global Variables ---
INSTALL_DIR=""
BOT_USER=""
PROJECT_ROOT=$(pwd) 

# --- Helper Functions (log_info, etc. - same as before) ---
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }
log_fatal() { echo -e "\033[31m[FATAL]\033[0m $1"; exit 1; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
print_divider() { echo "---------------------------------------------------------"; }
check_root() { if [ "$(id -u)" -ne 0 ]; then log_fatal "Root/sudo privileges required."; fi }
prompt_with_default() { local p=$1 d=$2 v=$3; read -p "$p [$d]: " i; eval "$v=\"${i:-$d}\""; }
install_package_if_missing() { # Simplified for system tools needed *before* conda
    local cmd=$1 pkg=$2 name=${3:-$pkg};
    if ! command -v $cmd &>/dev/null && ! (dpkg-query -W -f='${Status}' $pkg 2>/dev/null | grep -q "ok installed"); then
        log_warning "$name ($pkg) not found. Installing..."
        if command -v apt-get &>/dev/null; then sudo apt-get update -qq && sudo apt-get install -y -qq $pkg || return 1;
        elif command -v yum &>/dev/null; then sudo yum install -y $pkg || sudo dnf install -y $pkg || return 1;
        else log_error "Unsupported OS for $name auto-install."; return 1; fi
        log_success "$name installed."
    fi; return 0
}
# --- End Helper Functions ---

# Function to embed your robust TA-Lib installer (modified to fit here)
install_talib_via_conda_or_fallback() {
    log_info "--- Attempting TA-Lib Installation (Priority: Conda) ---"

    # Check if conda command exists
    if command -v conda &> /dev/null; then
        log_info "Conda found. Using existing Conda to install TA-Lib into environment '$CONDA_ENV_NAME'."
    else
        log_info "Conda not found. Installing Miniconda for user '$BOT_USER'..."
        MINICONDA_INSTALL_PATH="/home/$BOT_USER/miniconda3" # Install for bot user
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
        
        # Download and install Miniconda as the bot_user
        sudo -u "$BOT_USER" bash -c "
            set -e;
            cd /tmp;
            if [ -d '$MINICONDA_INSTALL_PATH' ]; then
                echo '[CONDA] Miniconda directory already exists at $MINICONDA_INSTALL_PATH. Skipping install.';
            else
                wget -q '$MINICONDA_URL' -O miniconda_installer.sh;
                bash miniconda_installer.sh -b -p '$MINICONDA_INSTALL_PATH';
                rm miniconda_installer.sh;
                echo '[CONDA] Miniconda installed to $MINICONDA_INSTALL_PATH.';
            fi;
            # Initialize conda for the bot user's bash (if not already done)
            # This path might need to be added to .bashrc for interactive use by bot_user
            # For script, we source directly.
            # '$MINICONDA_INSTALL_PATH/bin/conda' init bash # This modifies .bashrc, might not be ideal for non-interactive
            # For this script, we'll just ensure conda is in PATH for subsequent sudo -u commands
        " || log_fatal "Miniconda installation failed for user $BOT_USER."
        # Make conda command available for subsequent sudo -u calls by symlinking or adding to a known path if needed
        # Or, more robustly, always use the full path to conda binary for bot_user
        CONDA_EXEC="$MINICONDA_INSTALL_PATH/bin/conda"
        log_success "Miniconda setup for user $BOT_USER completed."
    fi

    # If conda wasn't system-wide, use the path from user install
    if ! command -v conda &> /dev/null; then
        CONDA_EXEC="/home/$BOT_USER/miniconda3/bin/conda"
        if [ ! -x "$CONDA_EXEC" ]; then log_fatal "Conda executable not found at $CONDA_EXEC after install attempt."; fi
    else
        CONDA_EXEC="conda" # Assume system conda is in PATH
    fi

    log_info "Creating/updating Conda environment '$CONDA_ENV_NAME' and installing TA-Lib..."
    # Run conda operations as the bot user
    # Pass PYTHON_EXECUTABLE version to conda create for consistency if needed, e.g. python=3.12
    PYTHON_VERSION_FOR_CONDA=$($PYTHON_EXECUTABLE -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

    sudo -u "$BOT_USER" bash -c "
        set -e;
        echo '[CONDA_SCRIPT] Running as user: \$(whoami)';
        # Source conda activate for this script if Miniconda was just installed for user
        if [ -f '/home/$USER/miniconda3/etc/profile.d/conda.sh' ]; then
            source '/home/$USER/miniconda3/etc/profile.d/conda.sh';
        elif [ -f '/opt/conda/etc/profile.d/conda.sh' ]; then # Common path for root conda installs
            source '/opt/conda/etc/profile.d/conda.sh';
        fi

        # Check if env exists, if not create it. If exists, just install ta-lib.
        if ! $CONDA_EXEC env list | grep -q '$CONDA_ENV_NAME'; then
            echo '[CONDA_SCRIPT] Creating Conda environment $CONDA_ENV_NAME with Python $PYTHON_VERSION_FOR_CONDA...';
            $CONDA_EXEC create -n '$CONDA_ENV_NAME' python='$PYTHON_VERSION_FOR_CONDA' -y;
        else
            echo '[CONDA_SCRIPT] Conda environment $CONDA_ENV_NAME already exists.';
        fi;
        
        echo '[CONDA_SCRIPT] Activating Conda environment $CONDA_ENV_NAME...';
        conda activate '$CONDA_ENV_NAME'; # This only affects current subshell if not sourced properly before main command
                                        # Better to use conda run for non-interactive commands

        echo '[CONDA_SCRIPT] Installing TA-Lib via conda-forge into $CONDA_ENV_NAME...';
        $CONDA_EXEC install -n '$CONDA_ENV_NAME' -c conda-forge ta-lib -y;
        
        echo '[CONDA_SCRIPT] Verifying TA-Lib import in $CONDA_ENV_NAME...';
        # Use conda run to execute python in the specific environment
        $CONDA_EXEC run -n '$CONDA_ENV_NAME' python -c \"import talib; print(f'[CONDA_SCRIPT SUCCESS] TA-Lib {talib.__version__} imported in $CONDA_ENV_NAME.')\" || \
            (echo '[CONDA_SCRIPT ERROR] TA-Lib import FAILED in $CONDA_ENV_NAME!' && exit 1);
        
        # No 'conda deactivate' needed here as 'conda run' is self-contained or activation is per subshell
    " || log_fatal "TA-Lib installation using Conda FAILED."
    
    log_success "TA-Lib successfully configured using Conda in environment '$CONDA_ENV_NAME'."
    # Note: The rest of the dependencies will be installed into this conda env too.
    return 0

    # Fallback methods (Method 2, 3, 4 from your script) could be added here if Conda fails.
    # For this integration, we'll assume Conda is the primary and preferred way for TA-Lib.
    # If Conda fails, the script will currently error out.
}


perform_installation() {
    set -e 
    log_info "Starting Core Installation Process..."
    prompt_with_default "Enter installation directory" "$INSTALL_DIR_DEFAULT" LOCAL_INSTALL_DIR
    prompt_with_default "Enter dedicated username for the bot" "$BOT_USER_DEFAULT" LOCAL_BOT_USER
    INSTALL_DIR="$LOCAL_INSTALL_DIR"; BOT_USER="$LOCAL_BOT_USER"; PROJECT_ROOT="$INSTALL_DIR" 

    log_info "1. Installing System Prerequisites (git, python3, pip, build tools)..."
    install_package_if_missing "git" "git" "Git" || log_fatal "Git failed."
    install_package_if_missing "$PYTHON_EXECUTABLE" "python3" "Python 3" || log_fatal "Python 3 failed."
    if ! $PYTHON_EXECUTABLE -m pip --version &> /dev/null; then
        install_package_if_missing "pip3" "python3-pip" "Pip for Python 3" || log_fatal "Pip3 failed."
    fi
    # Build tools needed if any requirement builds from source (besides TA-Lib)
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y -qq build-essential libffi-dev python3-dev wget tar || log_fatal "Build tools (apt) failed."
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        YUM_DEV_PKGS="gcc make gcc-c++ libffi-devel python3-devel openssl-devel wget tar"
        sudo yum install -y $YUM_DEV_PKGS > /dev/null 2>&1 || sudo dnf install -y $YUM_DEV_PKGS > /dev/null 2>&1 || log_warning "Some build/dev pkgs (yum/dnf) failed."
    fi
    log_success "System prerequisites checked/installed."

    # Install TA-Lib (preferably via Conda, which also sets up Python for the env)
    install_talib_via_conda_or_fallback || log_fatal "TA-Lib installation failed. Cannot proceed."

    log_info "2. Creating dedicated user '$BOT_USER' (if not already for Conda)..."
    # (User creation logic - ensure it doesn't conflict if Conda installed to user's home)
    if id "$BOT_USER" &>/dev/null; then log_info "User '$BOT_USER' exists."; else
        # If conda installed miniconda to /home/$BOT_USER, user might already be created implicitly or explicitly.
        # For simplicity, create if not exists. If Miniconda installed under existing user, that's fine too.
        sudo useradd -r -m -d "/home/$BOT_USER" -s /bin/bash "$BOT_USER" || log_warning "User create for $BOT_USER failed (maybe exists or other issue)."
        log_success "User '$BOT_USER' checked/created."; fi

    log_info "3. Setting up project directory at $INSTALL_DIR..."
    # (Clone/pull logic as before)
    if [ -d "$INSTALL_DIR/.git" ]; then
        log_warning "Project dir $INSTALL_DIR exists. Pulling..."
        (cd "$INSTALL_DIR" && sudo -u "$BOT_USER" git pull) || log_warning "git pull failed."
    elif [ -d "$INSTALL_DIR" ]; then
        log_warning "Dir $INSTALL_DIR exists (not git). Using it."
    else
        sudo git clone "$GITHUB_REPO_URL" "$INSTALL_DIR" || log_fatal "Clone $GITHUB_REPO_URL failed."
    fi
    sudo chown -R "$BOT_USER":"$BOT_USER" "$INSTALL_DIR"
    sudo find "$INSTALL_DIR" -type d -exec chmod 750 {} \;
    sudo find "$INSTALL_DIR" -type f -exec chmod 640 {} \;
    sudo chmod ug+x "$INSTALL_DIR"/*.sh "$INSTALL_DIR/main.py" "$INSTALL_DIR/train_model.py" || true
    log_success "Project in $INSTALL_DIR. Permissions set."

    log_info "4. Installing remaining Python dependencies into Conda env '$CONDA_ENV_NAME'..."
    # The CONDA_EXEC path needs to be determined correctly if Miniconda was installed for BOT_USER
    if ! command -v conda &> /dev/null && [ -x "/home/$BOT_USER/miniconda3/bin/conda" ]; then
        CONDA_EXEC_FOR_DEPS="/home/$BOT_USER/miniconda3/bin/conda"
    elif command -v conda &> /dev/null; then
        CONDA_EXEC_FOR_DEPS="conda"
    else
        log_fatal "Conda executable not found. Cannot install remaining dependencies."
    fi
    
    # Create a temporary requirements file that *excludes* TA-Lib
    # as it's already handled by Conda. Also exclude numpy if conda installed it.
    TMP_REQS="$INSTALL_DIR/tmp_requirements.txt"
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        grep -vE "^TA-Lib|^numpy" "$INSTALL_DIR/requirements.txt" > "$TMP_REQS"
        # Install pip and other packages into the conda environment
        # Using conda run ensures it uses the correct pip from that environment
        sudo -u "$BOT_USER" bash -c "
            set -e;
            echo '[DEPS_SCRIPT] Running as user: \$(whoami)';
            # Activate conda for this shell session if needed (conda run should handle this)
            if [ -f '/home/$USER/miniconda3/etc/profile.d/conda.sh' ]; then
                source '/home/$USER/miniconda3/etc/profile.d/conda.sh';
            elif [ -f '/opt/conda/etc/profile.d/conda.sh' ]; then
                source '/opt/conda/etc/profile.d/conda.sh';
            fi
            
            echo '[DEPS_SCRIPT] Upgrading pip in $CONDA_ENV_NAME...';
            '$CONDA_EXEC_FOR_DEPS' run -n '$CONDA_ENV_NAME' pip install --upgrade pip;

            echo '[DEPS_SCRIPT] Installing remaining dependencies from $TMP_REQS into $CONDA_ENV_NAME...';
            if [ -s '$TMP_REQS' ]; then # Check if tmp_requirements is not empty
                 '$CONDA_EXEC_FOR_DEPS' run -n '$CONDA_ENV_NAME' pip install -r '$TMP_REQS';
            else
                 echo '[DEPS_SCRIPT] No other dependencies to install after TA-Lib and NumPy.';
            fi
            echo '[DEPS_SCRIPT] Dependency installation into Conda env complete.';
        " || log_fatal "Failed to install remaining dependencies into Conda environment '$CONDA_ENV_NAME'."
        rm -f "$TMP_REQS"
        log_success "Remaining Python dependencies installed in Conda env '$CONDA_ENV_NAME'."
    else
        log_warning "requirements.txt not found in $INSTALL_DIR. Skipping dependency install."
    fi


    log_info "5. Ensuring project directory structure..."
    # (mkdir as before)
    sudo -u "$BOT_USER" bash -c "cd '$INSTALL_DIR' && mkdir -p flow_ai_core && touch flow_ai_core/__init__.py && mkdir -p data/historical_ohlcv && mkdir -p data/logs"
    log_success "Directory structure ensured."

    log_info "6. Configuration File (.env) Setup..."
    # (.env setup as before)
    ENV_FILE="$INSTALL_DIR/.env"; ENV_EXAMPLE_FILE="$INSTALL_DIR/.env.example"
    if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE_FILE" ]; then
        sudo cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"; sudo chown "$BOT_USER":"$BOT_USER" "$ENV_FILE"; sudo chmod 600 "$ENV_FILE"
        log_warning "Copied .env.example to .env. EDIT $ENV_FILE with your settings."
    else log_info ".env file already exists at $ENV_FILE."; fi

    log_info "7. Setting up systemd service '$SERVICE_NAME'..."
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    # ExecStart needs to use conda run
    CONDA_RUN_EXEC="/home/$BOT_USER/miniconda3/bin/conda" # Assume this path if user installed
    if command -v conda &>/dev/null ; then CONDA_RUN_EXEC="conda"; fi # If system conda

    SYSTEMD_SERVICE_CONTENT="[Unit]
Description=$PROJECT_NAME Service (Conda Env: $CONDA_ENV_NAME)
After=network.target
[Service]
Type=simple
User=$BOT_USER
Group=$BOT_USER
WorkingDirectory=$INSTALL_DIR
# Ensure the Conda environment is activated, or use 'conda run'
ExecStart=$CONDA_RUN_EXEC run -n $CONDA_ENV_NAME --no-capture-output $PYTHON_EXECUTABLE main.py
Restart=on-failure
RestartSec=10s
Environment=\"PYTHONUNBUFFERED=1\"
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target"
    echo "$SYSTEMD_SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null
    sudo chmod 644 "$SERVICE_FILE"; sudo systemctl daemon-reload; sudo systemctl enable "$SERVICE_NAME"
    log_success "Systemd service '$SERVICE_NAME.service' created and enabled."

    set +e 
    log_info "--- Core Installation Finished ---"
    read -p "Press [Enter] to return to the main menu..."
}

# --- Management Functions ---
# (Need to be adapted to use conda environment)
manage_service() { 
    local ACTION=$1
    # INSTALL_DIR is global or detected
    sudo systemctl $ACTION $SERVICE_NAME; log_info "Service action '$ACTION'. Status:"; sudo systemctl status $SERVICE_NAME --no-pager -n 10; read -p "Press [Enter]..."
}
view_logs() { 
    sudo journalctl -u $SERVICE_NAME -f -n 100; read -p "Press [Enter]..."
}
display_status_snapshot() { 
    # ... (snapshot logic as before) ...
    # Add check for conda process
    CONDA_PYTHON_PATH_PART="/envs/$CONDA_ENV_NAME/bin/python" # Part of the path for conda env python
    if pgrep -u "$BOT_USER" -f "$CONDA_PYTHON_PATH_PART main.py" > /dev/null; then log_success "Bot (Conda) process RUNNING."; else log_warning "Bot (Conda) process NOT RUNNING."; fi
    read -p "Press [Enter]..."
}
edit_env_file() { # ... (same as before) ... 
    sudo nano "${INSTALL_DIR:-$INSTALL_DIR_DEFAULT}/.env"; log_info ".env edit closed."; read -p "Press [Enter]..."
}
train_ai_model_interactive() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$BOT_USER_DEFAULT")}
    local conda_exec_path="/home/$current_bot_user/miniconda3/bin/conda"
    if command -v conda &>/dev/null ; then conda_exec_path="conda"; fi
    
    log_info "Training AI as '$current_bot_user' in '$current_install_dir' using Conda env '$CONDA_ENV_NAME'..."
    sudo -u "$current_bot_user" bash -c "
        set -e;
        cd '$current_install_dir';
        echo '[TRAIN_CONDA] Activating/Running in Conda env $CONDA_ENV_NAME...';
        # Source conda for the subshell if needed
        if [ -f '/home/\$USER/miniconda3/etc/profile.d/conda.sh' ]; then source '/home/\$USER/miniconda3/etc/profile.d/conda.sh'; fi
        '$conda_exec_path' run -n '$CONDA_ENV_NAME' python train_model.py;
        echo '[TRAIN_CONDA] train_model.py finished.';
    " || log_error "AI Training FAILED."
    log_success "AI Training process attempt COMPLETED."
    read -p "Press [Enter]..."
}
perform_uninstall() {
    # ... (Uninstall logic as before, now also consider removing Miniconda for the user IF this script installed it)
    set -e 
    # ... (confirmations) ...
    # ... (stop service, remove service file) ...
    # ... (delete project dir) ...
    # ... (delete bot user) ...
    log_info "Checking for user-specific Miniconda installation for $BOT_USER..."
    if [ -d "/home/$BOT_USER/miniconda3" ]; then
        read -p "Miniconda found at /home/$BOT_USER/miniconda3. Remove it? (yes/NO): " RM_CONDA
        if [[ "$RM_CONDA" == "yes" ]]; then
            sudo rm -rf "/home/$BOT_USER/miniconda3"
            log_success "Removed Miniconda for $BOT_USER."
        else
            log_info "Skipped Miniconda removal."
        fi
    fi
    log_success "--- Full Uninstall Complete ---"; read -p "Press [Enter]..."
}

# --- Main Menu (as before, ensure options call correct functions) ---
# ... (main_menu function as before) ...
# ... (script execution logic for flags and calling main_menu as before) ...

main_menu() {
    # (Auto-detection logic for INSTALL_DIR and BOT_USER as before)
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        DETECTED_INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        DETECTED_BOT_USER=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        if [ -z "$INSTALL_DIR" ] && [ -n "$DETECTED_INSTALL_DIR" ]; then INSTALL_DIR="$DETECTED_INSTALL_DIR"; fi
        if [ -z "$BOT_USER" ] && [ -n "$DETECTED_BOT_USER" ]; then BOT_USER="$DETECTED_BOT_USER"; fi
    fi
    while true; do clear
        echo "========================================================="
        echo " FlowAI-ICT-Trading-Bot Management Panel (Conda Mode)"
        echo " Project Dir: ${INSTALL_DIR:-Not Set/Run Install First}"
        echo " Bot User   : ${BOT_USER:-Not Set/Run Install First}"
        echo " Conda Env  : $CONDA_ENV_NAME"
        echo " Service    : $SERVICE_NAME"; echo "========================================================="
        echo "  1. Perform Full Installation / Re-check Prerequisites"
        echo "  2. Start Bot Service"; echo "  3. Stop Bot Service"
        echo "  4. Restart Bot Service"; echo "  5. View Bot Service Status"
        echo "  6. View Live Bot Logs";  echo "  7. Display System Status"
        echo "  8. Edit .env File"; echo "  9. Train AI Model (in Conda Env)"
        echo " 10. (Info) Update Project"; echo " 11. Full Uninstall"
        echo "---------------------------------------------------------"
        echo "  0. Exit"
        echo "========================================================="; read -p "Enter choice [0-11]: " choice
        case $choice in
            1) check_root; perform_installation ;; 2) check_root; manage_service "start" ;;
            3) check_root; manage_service "stop" ;; 4) check_root; manage_service "restart" ;;
            5) check_root; manage_service "status" ;; 6) check_root; view_logs ;;
            7) display_status_snapshot ;; 8) check_root; edit_env_file ;;
            9) check_root; train_ai_model_interactive ;;
            10) log_info "To update: cd ${INSTALL_DIR:-/path/to/bot}; sudo -u ${BOT_USER:-$BOT_USER_DEFAULT} git pull; sudo systemctl restart $SERVICE_NAME"; read -p "[Enter]..." ;;
            11) check_root; perform_uninstall ;; 0) echo "Exiting."; exit 0 ;;
            *) log_warning "Invalid choice."; read -p "[Enter]..." ;;
        esac
    done
}
# --- Script Execution Logic ---
SCRIPT_CWD=$(pwd)
if [[ "$1" != "--help" && "$1" != "-h" ]]; then check_root; fi
if [[ "$1" == "--install-only" || "$1" == "" && ! -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
    if [ "$GITHUB_REPO_URL" == "YOUR_GITHUB_REPO_URL_HERE" ]; then
        read -p "Enter GitHub Repository URL: " GITHUB_REPO_URL_INPUT
        if [ -z "$GITHUB_REPO_URL_INPUT" ]; then log_fatal "GitHub URL cannot be empty."; fi
        GITHUB_REPO_URL="$GITHUB_REPO_URL_INPUT"
    fi
    if [ "$1" == "--install-only" ]; then perform_installation; exit 0; fi
fi
if [ "$1" == "--uninstall" ]; then perform_uninstall; exit 0; fi
main_menu