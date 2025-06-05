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
perform_installation() {
    # ... (initial parts of perform_installation as before) ...
    # ... (prerequisites, user creation, git clone, C library install) ...

    log_info "4. Setting up Python virtual environment..."
    # Using heredoc for bot user script
    # Ensure requirements.txt has "TA-Lib" and NOT "talib-binary"
    if ! sudo -u "$BOT_USER" bash -s -- "$INSTALL_DIR" "$VENV_NAME" "$PYTHON_EXECUTABLE" "$PIP_EXECUTABLE" << 'EOF_BOT_VENV_SCRIPT'
        set -e 
        INSTALL_DIR_SUB="$1"; VENV_NAME_SUB="$2"; PYTHON_EXEC_SUB="$3"; PIP_EXEC_SUB="$4"
        
        echo "[VENV] Current directory: $(pwd)" # Should be /tmp or similar for sudo -s
        # Ensure we are in the correct directory for the script
        cd "$INSTALL_DIR_SUB"
        echo "[VENV] Changed to directory: $(pwd)"

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
            # --- MODIFIED SECTION FOR TA-LIB INSTALL ---
            echo "[VENV] Attempting to install TA-Lib Python wrapper with explicit LDFLAGS..."
            # Since ldconfig found libta_lib.so in /lib, we point LDFLAGS there.
            # If it was in /usr/lib, it would be -L/usr/lib. If /usr/local/lib, then -L/usr/local/lib.
            # The TA-Lib C library headers are usually in /usr/include/ta-lib/ or /usr/local/include/ta-lib/
            # CFLAGS might be needed if headers are not found: CFLAGS="-I/usr/include/ta-lib" 
            # However, /usr/include is usually standard.
            
            # First, ensure numpy is installed as TA-Lib setup depends on it
            echo "[VENV] Ensuring numpy is installed first..."
            $PIP_EXEC_SUB install numpy --no-cache-dir

            echo "[VENV] Installing TA-Lib with LDFLAGS=-L/lib ..."
            LDFLAGS="-L/lib" $PIP_EXEC_SUB install TA-Lib --no-cache-dir --verbose
            # If the above fails, and headers are suspected, you could try:
            # CFLAGS="-I/usr/include/ta-lib" LDFLAGS="-L/lib" $PIP_EXEC_SUB install TA-Lib --no-cache-dir --verbose
            
            echo "[VENV] TA-Lib wrapper install attempt finished."
            echo "[VENV] Installing other requirements..."
            $PIP_EXEC_SUB install -r requirements.txt # This will re-check TA-Lib, but it should be satisfied
            # --- END OF MODIFIED SECTION ---
        else
            echo "[VENV ERROR] requirements.txt not found!"
            exit 1
        fi
        
        echo "[VENV] Verifying TA-Lib Python import..."
        python -c "import talib; print(\"[VENV SUCCESS] TA-Lib Python package imported successfully.\")" || \
            (echo "[VENV ERROR] TA-Lib Python import FAILED! This is the final check." && exit 1)
        
        deactivate
        echo "[VENV] Virtual environment setup complete."
EOF_BOT_VENV_SCRIPT
    then
        log_fatal "Virtual environment or dependency installation failed. Check output above."
    fi
    log_success "Python virtual environment and dependencies set up."

    # ... (rest of perform_installation: directory structure, .env, systemd) ...
    # ... (management functions, main_menu, script execution logic) ...
}

# --- Management Functions (manage_service, view_logs, etc. as before) ---
# (Paste the management functions from the previous version of install_and_manage.sh here)
# Make sure they use the global INSTALL_DIR and BOT_USER which are set in perform_installation
# or detected in main_menu.

manage_service() { 
    local ACTION=$1
    if [ -z "$INSTALL_DIR" ]; then INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT"); fi
    sudo systemctl $ACTION $SERVICE_NAME; log_info "Service action '$ACTION'. Status:"; sudo systemctl status $SERVICE_NAME --no-pager -n 10; read -p "Press [Enter]..."
}
view_logs() { 
    sudo journalctl -u $SERVICE_NAME -f -n 100; read -p "Press [Enter]..."
}
display_status_snapshot() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "N/A")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "N/A")}
    print_divider; log_info "System Resource Snapshot:"; 
    echo "CPU Load (1m): $(uptime | awk -F'average: ' '{ print $2 }' | cut -d, -f1), RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}), Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"})"
    log_info "Service '$SERVICE_NAME' (User: $current_bot_user, Dir: $current_install_dir):"; sudo systemctl status $SERVICE_NAME --no-pager -n 5 || log_warning "No status."
    if pgrep -u "$current_bot_user" -f "$current_install_dir/$VENV_NAME/bin/python main.py" > /dev/null; then log_success "Bot process RUNNING."; else log_warning "Bot process NOT RUNNING."; fi
    print_divider; read -p "Press [Enter]..."
}
edit_env_file() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    sudo nano "$current_install_dir/.env"; log_info ".env edit closed."; read -p "Press [Enter]..."
}
train_ai_model_interactive() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$BOT_USER_DEFAULT")}
    log_info "Training AI as '$current_bot_user' in '$current_install_dir'..."
    if ! sudo -u "$current_bot_user" bash -s -- "$current_install_dir" "$VENV_NAME" << 'EOF_TRAIN_CMD'
        set -e; cd "$1"; source "$2/bin/activate"; python train_model.py; deactivate
EOF_TRAIN_CMD
    then log_error "AI Training FAILED."; else log_success "AI Training COMPLETED."; fi
    read -p "Press [Enter]..."
}

# --- Main Menu (as before, with Uninstall option) ---
main_menu() {
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        DETECTED_INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        DETECTED_BOT_USER=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        if [ -z "$INSTALL_DIR" ] && [ -n "$DETECTED_INSTALL_DIR" ]; then INSTALL_DIR="$DETECTED_INSTALL_DIR"; fi
        if [ -z "$BOT_USER" ] && [ -n "$DETECTED_BOT_USER" ]; then BOT_USER="$DETECTED_BOT_USER"; fi
    fi

    while true; do
        clear
        echo "========================================================="
        echo " FlowAI-ICT-Trading-Bot Management Panel"
        echo " Project Dir: ${INSTALL_DIR:-Not Set/Run Install First}"
        echo " Bot User   : ${BOT_USER:-Not Set/Run Install First}"
        echo " Service    : $SERVICE_NAME"
        echo "========================================================="
        echo "  1. Perform Full Installation / Re-check Prerequisites"
        echo "  2. Start Bot Service"; echo "  3. Stop Bot Service"
        echo "  4. Restart Bot Service"; echo "  5. View Bot Service Status"
        echo "  6. View Live Bot Logs";  echo "  7. Display System Status"
        echo "  8. Edit .env File"; echo "  9. Train AI Model"
        echo " 10. (Info) Update Project"; echo " 11. Full Uninstall"
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
            7) display_status_snapshot ;;
            8) check_root; edit_env_file ;;
            9) check_root; train_ai_model_interactive ;;
            10) log_info "To update: cd ${INSTALL_DIR:-/path/to/bot}; sudo -u ${BOT_USER:-flowaibot} git pull; sudo systemctl restart $SERVICE_NAME"; read -p "[Enter]..." ;;
            11) check_root; perform_uninstall ;; # Make sure perform_uninstall is defined
            0) echo "Exiting."; exit 0 ;;
            *) log_warning "Invalid choice."; read -p "[Enter]..." ;;
        esac
    done
}

# --- Uninstall Function (ensure it's defined if called by menu) ---
perform_uninstall() {
    set -e 
    log_warning "--- Starting Full Uninstall Process ---"
    # (Full uninstall logic as previously provided)
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
        sudo pkill -u "$current_bot_user" || true; sudo userdel -r "$current_bot_user" || log_warning "userdel failed (maybe groups/processes)."
        log_success "User '$current_bot_user' deleted."; else log_warning "User not found."; fi
    
    INSTALL_DIR=""; BOT_USER="" # Reset globals
    set +e; log_success "--- Full Uninstall Complete ---"; read -p "Press [Enter]..."
}


# --- Script Execution Logic ---
SCRIPT_CWD=$(pwd)
if [[ "$1" != "--help" && "$1" != "-h" ]]; then
    check_root 
fi

# Ensure GITHUB_REPO_URL is set before calling perform_installation if it's not hardcoded
if [[ "$1" == "--install-only" || "$1" == "" && ! -d "$INSTALL_DIR_DEFAULT/.git" ]]; then # Also if running first time via menu
    if [ "$GITHUB_REPO_URL" == "YOUR_GITHUB_REPO_URL_HERE" ]; then
        read -p "Enter GitHub Repository URL (e.g., https://github.com/user/repo.git): " GITHUB_REPO_URL_INPUT
        if [ -z "$GITHUB_REPO_URL_INPUT" ]; then log_fatal "GitHub URL cannot be empty for installation."; fi
        GITHUB_REPO_URL="$GITHUB_REPO_URL_INPUT"
    fi
fi

if [ "$1" == "--install-only" ]; then
    perform_installation
    exit 0
elif [ "$1" == "--uninstall" ]; then 
    perform_uninstall
    exit 0
fi

main_menu