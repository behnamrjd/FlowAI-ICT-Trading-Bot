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

# ... (script above this point, including install_talib_c_library as previously refined) ...

# --- Core Installation Function ---
# ... (script above this point, including install_talib_c_library) ...

# --- Core Installation Function ---
# --- Core Installation Function ---
perform_installation() {
    set -e 
    log_info "Starting Core Installation Process..."
    prompt_with_default "Enter installation directory" "$INSTALL_DIR_DEFAULT" LOCAL_INSTALL_DIR
    prompt_with_default "Enter dedicated username for the bot" "$BOT_USER_DEFAULT" LOCAL_BOT_USER
    
    INSTALL_DIR="$LOCAL_INSTALL_DIR"
    BOT_USER="$LOCAL_BOT_USER"
    PROJECT_ROOT="$INSTALL_DIR" 

    # ... (Prerequisites, TA-Lib C install, User creation, Git clone - same as before) ...
    # (Ensure these steps are correct and complete from previous versions)
    log_info "1. Installing System Prerequisites..."
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

# ... (within perform_installation function in install_and_manage.sh) ...

# ... (within perform_installation function in install_and_manage.sh) ...
# ... (after PROJECT_ROOT is set and prerequisites, C library install, user, git clone are done) ...

    log_info "4. Setting up Python virtual environment..."
    
    VENV_SETUP_SCRIPT_CONTENT=$(cat << 'EOF_INNER_SCRIPT'
#!/bin/bash
set -ex # Add -x for xtrace to see commands being run, -e for exit on error

echo "[VENV_SCRIPT] Running as user: $(whoami) in dir: $(pwd)"
echo "[VENV_SCRIPT] Received INSTALL_DIR_SUB: $1"
echo "[VENV_SCRIPT] Received VENV_NAME_SUB: $2"
echo "[VENV_SCRIPT] Received PYTHON_EXEC_SUB: $3"
echo "[VENV_SCRIPT] Received PIP_EXEC_SUB: $4"

cd "$1" 
echo "[VENV_SCRIPT] Changed to directory: $(pwd)"

if [ ! -d "$2" ]; then
    echo "[VENV_SCRIPT] Creating venv '$2'..."
    "$3" -m venv "$2" 
fi
echo "[VENV_SCRIPT] Activating venv..."
source "$2/bin/activate"

echo "[VENV_SCRIPT] Upgrading Pip..."
"$4" install --upgrade pip

echo "[VENV_SCRIPT] Installing dependencies from requirements.txt..."
if [ -f "requirements.txt" ]; then
    echo "[VENV_SCRIPT] Ensuring numpy is installed first..."
    "$4" install numpy --no-cache-dir

    echo "[VENV_SCRIPT] Attempting to install TA-Lib Python wrapper..."
    # Check if ta-lib-config exists and provides useful info
    if command -v ta-lib-config &> /dev/null; then
        echo "[VENV_SCRIPT] Found ta-lib-config. Output:"
        echo "ta-lib-config --cflags: $(ta-lib-config --cflags)"
        echo "ta-lib-config --libs: $(ta-lib-config --libs)"
    else
        echo "[VENV_SCRIPT] ta-lib-config not found in PATH for user $(whoami). Will try manual flags."
    fi

    # Set environment variables for the TA-Lib build
    # These tell the compiler where to find headers and the linker where to find the library.
    # Based on your ldconfig output, libta_lib.so is in /lib
    export C_INCLUDE_PATH="/usr/include/ta-lib:$C_INCLUDE_PATH" # Headers often here after --prefix=/usr
    export CPLUS_INCLUDE_PATH="/usr/include/ta-lib:$CPLUS_INCLUDE_PATH"
    export LIBRARY_PATH="/lib:/usr/lib:/usr/local/lib:$LIBRARY_PATH" 
    export LD_RUN_PATH="/lib:/usr/lib:/usr/local/lib:$LD_RUN_PATH"   

    export LDFLAGS="-L/lib -L/usr/lib -L/usr/local/lib"
    export CFLAGS="-I/usr/include -I/usr/local/include -I/usr/include/ta-lib" # Add all likely header locations

    echo "[VENV_SCRIPT] Environment for TA-Lib build:"
    echo "LDFLAGS: $LDFLAGS"
    echo "CFLAGS: $CFLAGS"
    echo "C_INCLUDE_PATH: $C_INCLUDE_PATH"
    echo "LIBRARY_PATH: $LIBRARY_PATH"

    echo "[VENV_SCRIPT] Installing TA-Lib (forcing source build attempt)..."
    "$4" install TA-Lib --no-cache-dir --no-binary TA-Lib --compile --verbose

    echo "[VENV_SCRIPT] TA-Lib wrapper install attempt finished."
    
    echo "[VENV_SCRIPT] Verifying TA-Lib Python import immediately after install..."
    python -c "import talib; print(\"[VENV_SCRIPT SUCCESS] TA-Lib Python package imported successfully after direct install.\")" || \
        (echo "[VENV_SCRIPT ERROR] TA-Lib Python import FAILED after direct install! Check verbose pip output above." && exit 1)

    echo "[VENV_SCRIPT] Installing other requirements..."
    "$4" install -r requirements.txt 
else
    echo "[VENV_SCRIPT ERROR] requirements.txt not found!"
    exit 1
fi

deactivate
echo "[VENV_SCRIPT] Virtual environment setup complete."
EOF_INNER_SCRIPT
)

    TMP_SCRIPT_PATH="/tmp/flowai_venv_setup.sh" 
    echo "$VENV_SETUP_SCRIPT_CONTENT" | sudo tee "$TMP_SCRIPT_PATH" > /dev/null
    sudo chmod 755 "$TMP_SCRIPT_PATH" 

    log_info "Executing venv setup script as user '$BOT_USER' with args: $INSTALL_DIR $VENV_NAME $PYTHON_EXECUTABLE $PIP_EXECUTABLE"
    if ! sudo -H -u "$BOT_USER" bash "$TMP_SCRIPT_PATH" "$INSTALL_DIR" "$VENV_NAME" "$PYTHON_EXECUTABLE" "$PIP_EXECUTABLE"; then
        log_fatal "Virtual environment setup or dependency installation failed using temporary script. Check output above."
    fi
    sudo rm -f "$TMP_SCRIPT_PATH" 
    
    log_success "Python virtual environment and dependencies set up."
    # ... (rest of perform_installation)

# ... (rest of the install_and_manage.sh script: management functions, main_menu, etc.)

    # ... (Rest of perform_installation: directory structure, .env, systemd) ...
    # (Same as before)
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

# ... (Rest of the script: management functions, main_menu, execution logic as before) ...
# (Make sure perform_uninstall, manage_service, view_logs, display_status_snapshot, 
#  edit_env_file, train_ai_model_interactive are defined as in the previous complete script version)
# I'll re-paste train_ai_model_interactive with the same temp script fix for consistency

train_ai_model_interactive() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$BOT_USER_DEFAULT")}
    
    log_info "Attempting AI model training as '$current_bot_user' in '$current_install_dir'..."

    TRAIN_SCRIPT_INNER_CONTENT=$(cat << EOF_TRAIN_INNER
#!/bin/bash
set -e
# \$1: INSTALL_DIR_TRAIN, \$2: VENV_NAME_TRAIN
echo "[TRAIN_SCRIPT] Running as user: \$(whoami) in dir: \$(pwd)"
cd "\$1"
echo "[TRAIN_SCRIPT] Activating venv '\$2'..."
source "\$2/bin/activate"
echo "[TRAIN_SCRIPT] Starting train_model.py..."
python train_model.py
echo "[TRAIN_SCRIPT] train_model.py finished."
deactivate
EOF_TRAIN_INNER
)
    TMP_TRAIN_SCRIPT_PATH="/tmp/flowai_train_model_temp.sh"
    echo "$TRAIN_SCRIPT_INNER_CONTENT" | sudo tee "$TMP_TRAIN_SCRIPT_PATH" > /dev/null
    sudo chmod 755 "$TMP_TRAIN_SCRIPT_PATH"

    if ! sudo -H -u "$current_bot_user" bash "$TMP_TRAIN_SCRIPT_PATH" "$current_install_dir" "$VENV_NAME";
    then log_error "AI Training FAILED."; else log_success "AI Training COMPLETED."; fi
    sudo rm -f "$TMP_TRAIN_SCRIPT_PATH"
    read -p "Press [Enter]..."
}

perform_uninstall() {
    # (Uninstall logic as before)
    set -e 
    log_warning "--- Starting Full Uninstall Process ---"
    local current_install_dir=${INSTALL_DIR}
    local current_bot_user=${BOT_USER}
    if [ -z "$current_install_dir" ] && [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then current_install_dir=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null); fi
    if [ -z "$current_bot_user" ] && [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then current_bot_user=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null); fi
    if [ -z "$current_install_dir" ]; then prompt_with_default "Install directory to remove" "$INSTALL_DIR_DEFAULT" current_install_dir; fi
    if [ -z "$current_bot_user" ]; then prompt_with_default "Bot username to remove" "$BOT_USER_DEFAULT" current_bot_user; fi
    if [ -z "$current_install_dir" ] || [ -z "$current_bot_user" ]; then log_error "Cannot determine dir/user. Aborting uninstall."; return 1; fi

    log_warning "Uninstalling User: '$current_bot_user', Dir: '$current_install_dir', Service: '$SERVICE_NAME'"
    read -p "ARE YOU SURE? This is irreversible. (yes/NO): " CONFIRM_UNINSTALL
    if [[ "$CONFIRM_UNINSTALL" != "yes" ]]; then log_info "Uninstall aborted."; return; fi

    log_info "Stopping/disabling service '$SERVICE_NAME'..."
    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        sudo systemctl stop "$SERVICE_NAME" || true; sudo systemctl disable "$SERVICE_NAME" || true
        sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"; sudo rm -f "/etc/systemd/system/multi-user.target.wants/$SERVICE_NAME.service"
        sudo systemctl daemon-reload; sudo systemctl reset-failed; log_success "Service removed."
    else log_warning "Service '$SERVICE_NAME.service' not found."; fi

    log_info "Deleting project dir '$current_install_dir'..."
    if [ -d "$current_install_dir" ]; then sudo rm -rf "$current_install_dir"; log_success "Project dir deleted."; else log_warning "Project dir not found."; fi

    log_info "Deleting user '$current_bot_user'..."
    if id "$current_bot_user" &>/dev/null; then
        sudo pkill -u "$current_bot_user" || true; sudo userdel -r "$current_bot_user" || log_warning "userdel failed."
        log_success "User '$current_bot_user' deleted."; else log_warning "User not found."; fi
    
    INSTALL_DIR=""; BOT_USER="" 
    set +e; log_success "--- Full Uninstall Complete ---"; read -p "Press [Enter]..."
}

main_menu() {
    # (Main menu logic as before)
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        DETECTED_INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        DETECTED_BOT_USER=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        if [ -z "$INSTALL_DIR" ] && [ -n "$DETECTED_INSTALL_DIR" ]; then INSTALL_DIR="$DETECTED_INSTALL_DIR"; fi
        if [ -z "$BOT_USER" ] && [ -n "$DETECTED_BOT_USER" ]; then BOT_USER="$DETECTED_BOT_USER"; fi
    fi
    while true; do clear
        echo "========================================================="
        echo " FlowAI-ICT-Trading-Bot Management Panel"
        echo " Project Dir: ${INSTALL_DIR:-Not Set/Run Install First}"
        echo " Bot User   : ${BOT_USER:-Not Set/Run Install First}"
        echo " Service    : $SERVICE_NAME"; echo "========================================================="
        echo "  1. Perform Full Installation / Re-check Prerequisites"
        echo "  2. Start Bot Service"; echo "  3. Stop Bot Service"
        echo "  4. Restart Bot Service"; echo "  5. View Bot Service Status"
        echo "  6. View Live Bot Logs";  echo "  7. Display System Status"
        echo "  8. Edit .env File"; echo "  9. Train AI Model"
        echo " 10. (Info) Update Project"; echo " 11. Full Uninstall"
        echo "---------------------------------------------------------"; echo "  0. Exit"
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
        read -p "Enter GitHub Repository URL (e.g., https://github.com/user/repo.git): " GITHUB_REPO_URL_INPUT
        if [ -z "$GITHUB_REPO_URL_INPUT" ]; then log_fatal "GitHub URL cannot be empty."; fi
        GITHUB_REPO_URL="$GITHUB_REPO_URL_INPUT"
    fi
    if [ "$1" == "--install-only" ]; then perform_installation; exit 0; fi
fi

if [ "$1" == "--uninstall" ]; then perform_uninstall; exit 0; fi

main_menu