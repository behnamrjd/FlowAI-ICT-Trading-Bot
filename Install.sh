#!/bin/bash

# FlowAI-ICT-Trading-Bot Enhanced Installation & Management Script

# --- Configuration Variables ---
PROJECT_NAME="FlowAI-ICT-Trading-Bot"
GITHUB_REPO_URL="YOUR_GITHUB_REPO_URL_HERE" # IMPORTANT: Replace
INSTALL_DIR_DEFAULT="/opt/$PROJECT_NAME"
BOT_USER_DEFAULT="flowaibot"
PYTHON_EXECUTABLE="python3"
VENV_NAME=".venv"
SERVICE_NAME="flowai-bot"

# --- Global Variables (for script state) ---
# These will be set by perform_installation or detected by main_menu
INSTALL_DIR=""
BOT_USER=""
PROJECT_ROOT=$(pwd) 

# --- Helper Functions (log_info, log_warning, etc. as before) ---
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }
log_fatal() { echo -e "\033[31m[FATAL]\033[0m $1"; exit 1; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
print_divider() { echo "---------------------------------------------------------"; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_fatal "This script needs root or sudo privileges. Please run as: sudo $0"
    fi
}

prompt_with_default() {
    local prompt_message=$1; local default_value=$2; local variable_name=$3; local user_input
    read -p "$prompt_message [$default_value]: " user_input
    eval "$variable_name=\"${user_input:-$default_value}\""
}

install_package_if_missing() {
    # (Same as previous version)
    local cmd_to_check=$1; local package_name=$2; local friendly_name=${3:-$package_name}
    if ! command -v $cmd_to_check &> /dev/null && ! (dpkg-query -W -f='${Status}' $package_name 2>/dev/null | grep -q "ok installed"); then
        log_warning "$friendly_name ($package_name) not found. Attempting to install..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y -qq $package_name || { log_error "Failed to install $friendly_name via apt-get."; return 1; }
        elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
            sudo yum install -y $package_name || sudo dnf install -y $package_name || { log_error "Failed to install $friendly_name via yum/dnf."; return 1; }
        else
            log_error "Unsupported package manager for $friendly_name. Please install manually."; return 1
        fi
        log_success "$friendly_name installed."
    else
        log_info "$friendly_name already existing or command functional."
    fi
    return 0
}

install_talib_c_library() {
    # (Same as previous version with single-threaded make)
    log_info "Checking for existing TA-Lib C library..."
    if ldconfig -p | grep -q libta_lib || command -v ta-lib-config &> /dev/null; then
        log_info "TA-Lib C library seems to be already installed."
        if ! ( $PYTHON_EXECUTABLE -m pip install --dry-run TA-Lib &> /dev/null && \
               (ldconfig -p | grep -q libta_lib || find /usr/lib /usr/local/lib /lib /usr/lib64 /usr/local/lib64 /lib64 -name "libta_lib.so*" -print -quit 2>/dev/null | grep -q .) ); then
            log_warning "Existing TA-Lib C found, but Python linkage might be an issue. Forcing re-check of ldconfig."
            sudo ldconfig
        else
            log_info "Existing TA-Lib C library seems correctly linked for Python."
            return 0
        fi
    fi
    log_warning "TA-Lib C library not found or link uncertain. Attempting installation from source..."
    TA_LIB_VERSION="0.4.0"; TA_LIB_SRC_URL="http://prdownloads.sourceforge.net/ta-lib/ta-lib-${TA_LIB_VERSION}-src.tar.gz"
    TEMP_DIR=$(mktemp -d); CURRENT_DIR=$(pwd); cd "$TEMP_DIR"
    log_info "Downloading TA-Lib source: $TA_LIB_SRC_URL"
    wget -O "ta-lib-src.tar.gz" "$TA_LIB_SRC_URL" || { log_error "Download TA-Lib failed."; cd "$CURRENT_DIR"; rm -rf "$TEMP_DIR"; return 1; }
    tar -xzf "ta-lib-src.tar.gz" || { log_error "Extract TA-Lib failed."; cd "$CURRENT_DIR"; rm -rf "$TEMP_DIR"; return 1; }
    cd "ta-lib" || { log_error "TA-Lib source dir not found."; cd "$CURRENT_DIR"; rm -rf "$TEMP_DIR"; return 1; }
    log_info "Configuring TA-Lib (./configure --prefix=/usr)..."
    echo "--- Configure Output (See $TEMP_DIR/ta-lib/configure.log on error) ---"
    if ! ./configure --prefix=/usr > configure.log 2>&1; then 
        log_error "TA-Lib ./configure failed. Log content:"; cat configure.log; cd "$CURRENT_DIR"; rm -rf "$TEMP_DIR"; return 1; fi
    log_info "Building TA-Lib (make)..."
    echo "--- Make Output (See $TEMP_DIR/ta-lib/make.log on error) ---"
    if ! make; then 
        log_error "TA-Lib make failed. Log content:"; if [ -s make.log ]; then cat make.log; else echo "Make output not redirected, check terminal."; fi
        cd "$CURRENT_DIR"; rm -rf "$TEMP_DIR"; return 1; fi
    log_info "Installing TA-Lib (sudo make install)..."
    echo "--- Make Install Output (See $TEMP_DIR/ta-lib/make_install.log on error) ---"
    if ! sudo make install > make_install.log 2>&1; then 
        log_error "TA-Lib sudo make install failed. Log content:"; cat make_install.log; cd "$CURRENT_DIR"; rm -rf "$TEMP_DIR"; return 1; fi
    log_info "Updating library cache with ldconfig..."; sudo ldconfig
    if ! ldconfig -p | grep -q libta_lib && ! command -v ta-lib-config &> /dev/null; then
         log_error "TA-Lib C library installed, but NOT FOUND by ldconfig/ta-lib-config. Critical linking issue."; cd "$CURRENT_DIR"; rm -rf "$TEMP_DIR"; return 1; fi
    cd "$CURRENT_DIR"; rm -rf "$TEMP_DIR"; log_success "TA-Lib C library compiled and installed successfully."; return 0
}

perform_installation() {
    # (Same as the fully corrected version from the previous step)
    # This function now sets global INSTALL_DIR and BOT_USER upon successful completion of prompts.
    set -e 
    log_info "Starting Core Installation Process..."
    prompt_with_default "Enter installation directory" "$INSTALL_DIR_DEFAULT" LOCAL_INSTALL_DIR
    prompt_with_default "Enter dedicated username for the bot" "$BOT_USER_DEFAULT" LOCAL_BOT_USER
    
    # Set global vars after successful prompt for menu use
    INSTALL_DIR="$LOCAL_INSTALL_DIR"
    BOT_USER="$LOCAL_BOT_USER"
    PROJECT_ROOT="$INSTALL_DIR" 

    log_info "1. Installing System Prerequisites..." # ... (rest of prerequisite logic)
    install_package_if_missing "git" "git" "Git" || log_fatal "Git failed."
    install_package_if_missing "$PYTHON_EXECUTABLE" "python3" "Python 3" || log_fatal "Python 3 failed."
    if ! $PYTHON_EXECUTABLE -m pip --version &> /dev/null; then
        install_package_if_missing "pip3" "python3-pip" "Pip for Python 3" || log_fatal "Pip3 failed."
    fi
    PIP_EXECUTABLE="${PYTHON_EXECUTABLE} -m pip"
    if ! $PYTHON_EXECUTABLE -m venv -h &> /dev/null; then
         install_package_if_missing "python3-venv" "python3-venv" || \
         install_package_if_missing "python-virtualenv" "python-virtualenv" || \
         log_fatal "Python3 venv module failed."
    fi
    BUILD_TOOLS_APT="build-essential libffi-dev python3-dev wget tar automake autoconf pkg-config"
    BUILD_TOOLS_YUM="gcc make gcc-c++ autoconf automake libtool libffi-devel python3-devel openssl-devel wget tar pkgconfig"
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y -qq $BUILD_TOOLS_APT || log_fatal "Build tools (apt) failed."
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        sudo yum install -y $BUILD_TOOLS_YUM > /dev/null 2>&1 || sudo dnf install -y $BUILD_TOOLS_YUM > /dev/null 2>&1 || log_warning "Some build/dev pkgs (yum/dnf) failed."
    fi
    log_success "System prerequisites checked/installed."

    install_talib_c_library || log_fatal "TA-Lib C library installation FAILED. Cannot proceed."

    log_info "2. Creating dedicated user '$BOT_USER'..."
    if id "$BOT_USER" &>/dev/null; then log_info "User '$BOT_USER' exists."; else
        sudo useradd -r -m -d "/home/$BOT_USER" -s /bin/bash "$BOT_USER" || log_fatal "User create failed."
        log_success "User '$BOT_USER' created."; fi

    log_info "3. Setting up project directory at $INSTALL_DIR..."
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
    sudo chmod u+x "$INSTALL_DIR"/*.sh "$INSTALL_DIR/main.py" "$INSTALL_DIR/train_model.py" || true
    log_success "Project in $INSTALL_DIR. Permissions set."

    log_info "4. Setting up Python virtual environment..."
    if ! sudo -u "$BOT_USER" bash -s -- "$INSTALL_DIR" "$VENV_NAME" "$PYTHON_EXECUTABLE" "$PIP_EXECUTABLE" << 'EOF_BOT_VENV_SCRIPT'
        set -e 
        INSTALL_DIR_SUB="$1"; VENV_NAME_SUB="$2"; PYTHON_EXEC_SUB="$3"; PIP_EXEC_SUB="$4"
        cd "$INSTALL_DIR_SUB"
        if [ ! -d "$VENV_NAME_SUB" ]; then
            echo "[VENV] Creating venv '$VENV_NAME_SUB'..."
            $PYTHON_EXEC_SUB -m venv "$VENV_NAME_SUB"
        fi
        echo "[VENV] Activating venv..."
        source "$VENV_NAME_SUB/bin/activate"
        echo "[VENV] Upgrading Pip..."
        $PIP_EXEC_SUB install --upgrade pip
        echo "[VENV] Installing dependencies from requirements.txt..."
        if [ -f "requirements.txt" ]; then
            $PIP_EXEC_SUB install -r requirements.txt # Assumes TA-Lib C is installed, and TA-Lib (not talib-binary) is in reqs
        else echo "[VENV ERROR] requirements.txt not found!"; exit 1; fi
        echo "[VENV] Verifying TA-Lib Python import..."
        python -c "import talib; print(\"[VENV SUCCESS] TA-Lib Python package imported.\")" || \
            (echo "[VENV ERROR] TA-Lib Python import FAILED!" && exit 1)
        deactivate; echo "[VENV] Setup complete."
EOF_BOT_VENV_SCRIPT
    then log_fatal "Virtual environment or dependency installation failed."; fi
    log_success "Python virtual environment and dependencies set up."

    log_info "5. Ensuring project directory structure..."
    sudo -u "$BOT_USER" bash -c "cd '$INSTALL_DIR' && mkdir -p flow_ai_core && touch flow_ai_core/__init__.py && mkdir -p data/historical_ohlcv && mkdir -p data/logs"
    log_success "Directory structure ensured."

    log_info "6. Configuration File (.env) Setup..."
    ENV_FILE="$INSTALL_DIR/.env"; ENV_EXAMPLE_FILE="$INSTALL_DIR/.env.example"
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_EXAMPLE_FILE" ]; then
            sudo cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"; sudo chown "$BOT_USER":"$BOT_USER" "$ENV_FILE"; sudo chmod 600 "$ENV_FILE"
            log_warning "Copied .env.example to .env. EDIT $ENV_FILE with your settings."
        else log_warning ".env.example not found. Create $ENV_FILE manually."; fi
    else log_info ".env file already exists at $ENV_FILE."; fi

    log_info "7. Setting up systemd service '$SERVICE_NAME'..."
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    # (Systemd service content as before)
    SYSTEMD_SERVICE_CONTENT="[Unit]
Description=$PROJECT_NAME Service
After=network.target
[Service]
Type=simple
User=$BOT_USER
Group=$BOT_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$VENV_NAME/bin/python main.py
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

# --- New Uninstall Function ---
perform_uninstall() {
    set -e # Enable error checking for this critical operation
    log_warning "--- Starting Full Uninstall Process ---"
    log_warning "This will REMOVE the bot, its user, service, and installation directory."

    # Try to get current settings if not already set (for safety)
    local current_install_dir=${INSTALL_DIR}
    local current_bot_user=${BOT_USER}

    if [ -z "$current_install_dir" ] && [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        current_install_dir=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
    fi
    if [ -z "$current_bot_user" ] && [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        current_bot_user=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
    fi
    
    # If still not found, ask user
    if [ -z "$current_install_dir" ]; then
        prompt_with_default "Enter installation directory to remove" "$INSTALL_DIR_DEFAULT" current_install_dir
    fi
    if [ -z "$current_bot_user" ]; then
        prompt_with_default "Enter bot username to remove" "$BOT_USER_DEFAULT" current_bot_user
    fi

    if [ -z "$current_install_dir" ] || [ -z "$current_bot_user" ]; then
        log_error "Installation directory or bot user could not be determined. Aborting uninstall."
        return 1
    fi

    log_warning "Uninstalling for User: '$current_bot_user', Directory: '$current_install_dir', Service: '$SERVICE_NAME'"
    read -p "ARE YOU ABSOLUTELY SURE you want to proceed? This cannot be undone. (yes/NO): " CONFIRM_UNINSTALL
    if [[ "$CONFIRM_UNINSTALL" != "yes" ]]; then
        log_info "Uninstall aborted by user."
        return
    fi

    # 1. Stop and disable systemd service
    log_info "1. Stopping and disabling systemd service '$SERVICE_NAME'..."
    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then # Check if service exists
        sudo systemctl stop "$SERVICE_NAME" || log_warning "Failed to stop service (maybe not running)."
        sudo systemctl disable "$SERVICE_NAME" || log_warning "Failed to disable service."
        sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        sudo rm -f "/etc/systemd/system/multi-user.target.wants/$SERVICE_NAME.service" # Clean symlinks
        sudo systemctl daemon-reload
        sudo systemctl reset-failed # Clear failed state if any
        log_success "Systemd service '$SERVICE_NAME' removed."
    else
        log_warning "Systemd service '$SERVICE_NAME.service' not found. Skipping."
    fi

    # 2. Delete the project directory
    log_info "2. Deleting project directory '$current_install_dir'..."
    if [ -d "$current_install_dir" ]; then
        sudo rm -rf "$current_install_dir"
        log_success "Project directory '$current_install_dir' deleted."
    else
        log_warning "Project directory '$current_install_dir' not found. Skipping."
    fi

    # 3. Delete the dedicated bot user and its home directory
    log_info "3. Deleting user '$current_bot_user' and its home directory..."
    if id "$current_bot_user" &>/dev/null; then
        # Kill any remaining processes by the user
        sudo pkill -u "$current_bot_user" || true 
        sudo userdel -r "$current_bot_user" || log_warning "Failed to delete user '$current_bot_user' (maybe processes still active or group issues)."
        # The -r flag should remove the home directory. If not, an explicit rm -rf /home/$current_bot_user might be needed, but userdel -r is safer.
        log_success "User '$current_bot_user' deleted."
    else
        log_warning "User '$current_bot_user' not found. Skipping."
    fi
    
    # Reset global vars as settings are now gone
    INSTALL_DIR=""
    BOT_USER=""

    set +e
    log_success "--- Full Uninstall Process Complete ---"
    read -p "Press [Enter] to return to the main menu..."
}


# --- Management Functions (manage_service, view_logs, etc. as before) ---
# (Ensure they use the global INSTALL_DIR and BOT_USER, or re-detect them)
manage_service() { # ... (same as before) ... 
    local ACTION=$1
    if [ -z "$INSTALL_DIR" ]; then INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT"); fi
    sudo systemctl $ACTION $SERVICE_NAME; log_info "Service action '$ACTION'. Status:"; sudo systemctl status $SERVICE_NAME --no-pager -n 10; read -p "Press [Enter]..."
}
view_logs() { # ... (same as before) ... 
    sudo journalctl -u $SERVICE_NAME -f -n 100; read -p "Press [Enter]..."
}
display_status_snapshot() { # ... (same as before, but ensure local vars for dir/user) ... 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "N/A")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "N/A")}
    print_divider; log_info "System Resource Snapshot:"; # ... (rest of display logic) ...
    echo "CPU: $(uptime | awk -F'average: ' '{ print $2 }' | cut -d, -f1), RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}), Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"})"
    log_info "Service '$SERVICE_NAME' (User: $current_bot_user, Dir: $current_install_dir):"; sudo systemctl status $SERVICE_NAME --no-pager -n 5 || log_warning "No status."
    if pgrep -u "$current_bot_user" -f "$current_install_dir/$VENV_NAME/bin/python main.py" > /dev/null; then log_success "Bot process RUNNING."; else log_warning "Bot process NOT RUNNING."; fi
    print_divider; read -p "Press [Enter]..."
}
edit_env_file() { # ... (same as before) ... 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    sudo nano "$current_install_dir/.env"; log_info ".env edit closed."; read -p "Press [Enter]..."
}
train_ai_model_interactive() { # ... (same as before) ...
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$BOT_USER_DEFAULT")}
    log_info "Training AI as '$current_bot_user' in '$current_install_dir'..."
    if ! sudo -u "$current_bot_user" bash -s -- "$current_install_dir" "$VENV_NAME" << 'EOF_TRAIN_CMD'
        set -e; cd "$1"; source "$2/bin/activate"; python train_model.py; deactivate
EOF_TRAIN_CMD
    then log_error "AI Training FAILED."; else log_success "AI Training COMPLETED."; fi
    read -p "Press [Enter]..."
}

# --- Main Menu (add Uninstall option) ---
main_menu() {
    # (Auto-detection logic for INSTALL_DIR and BOT_USER as before)
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        DETECTED_INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        DETECTED_BOT_USER=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        if [ -z "$INSTALL_DIR" ] && [ -n "$DETECTED_INSTALL_DIR" ]; then INSTALL_DIR="$DETECTED_INSTALL_DIR"; fi
        if [ -z "$BOT_USER" ] && [ -n "$DETECTED_BOT_USER" ]; then BOT_USER="$DETECTED_BOT_USER"; fi
    fi


    while true; do
        clear
        # (Menu header as before)
        echo "========================================================="
        echo " FlowAI-ICT-Trading-Bot Management Panel"
        echo " Project Dir: ${INSTALL_DIR:-Not Set/Run Install First}"
        echo " Bot User   : ${BOT_USER:-Not Set/Run Install First}"
        echo " Service    : $SERVICE_NAME"
        echo "========================================================="
        echo " --- Installation & Setup ---"
        echo "  1. Perform Full Installation / Re-check Prerequisites"
        echo " --- Service Management (systemd) ---"
        echo "  2. Start Bot Service"; echo "  3. Stop Bot Service"
        echo "  4. Restart Bot Service"; echo "  5. View Bot Service Status"
        echo " --- Monitoring & Logs ---"
        echo "  6. View Live Bot Logs (journalctl)"
        echo "  7. Display System & Service Status Snapshot"
        echo " --- Configuration & Model ---"
        echo "  8. Edit .env Configuration File"
        echo "  9. Train AI Model"
        echo " --- Maintenance ---"
        echo " 10. (Info) Update Project from GitHub"
        echo " 11. Full Uninstall (Remove Bot, User, Service, Files)"
        echo "---------------------------------------------------------"
        echo "  0. Exit"
        echo "========================================================="
        read -p "Enter your choice [0-11]: " choice

        case $choice in
            1) check_root; perform_installation ;;
            2) check_root; manage_service "start" ;;
            3) check_root; manage_service "stop" ;;
            4) check_root; manage_service "restart" ;;
            5) check_root; manage_service "status" ;;
            6) check_root; view_logs ;;
            7) display_status_snapshot ;; # No root needed if commands are sudo'd inside
            8) check_root; edit_env_file ;;
            9) check_root; train_ai_model_interactive ;;
            10) log_info "To update: cd ${INSTALL_DIR:-/path/to/bot}; sudo -u ${BOT_USER:-flowaibot} git pull; sudo systemctl restart $SERVICE_NAME"; read -p "Press [Enter]..." ;;
            11) check_root; perform_uninstall ;; # New Uninstall Option
            0) echo "Exiting management panel."; exit 0 ;;
            *) log_warning "Invalid choice."; read -p "Press [Enter]..." ;;
        esac
    done
}

# --- Script Execution Logic (as before) ---
SCRIPT_CWD=$(pwd)
if [[ "$1" != "--help" && "$1" != "-h" ]]; then
    check_root 
fi

if [ "$1" == "--install-only" ]; then
    if [ "$GITHUB_REPO_URL" == "YOUR_GITHUB_REPO_URL_HERE" ]; then
        read -p "Enter GitHub Repository URL: " GITHUB_REPO_URL_INPUT
        if [ -z "$GITHUB_REPO_URL_INPUT" ]; then log_fatal "GitHub URL cannot be empty."; fi
        GITHUB_REPO_URL="$GITHUB_REPO_URL_INPUT"
    fi
    perform_installation
    exit 0
elif [ "$1" == "--uninstall" ]; then # New command line flag for direct uninstall
    perform_uninstall
    exit 0
fi

main_menu