#!/bin/bash

# FlowAI-ICT-Trading-Bot Installation & Basic Management Script

# Exit immediately if a command exits with a non-zero status during setup.
# We'll handle errors differently in the menu.
# set -e # Disabled for menu interactivity

# --- Configuration Variables ---
PROJECT_NAME="FlowAI-ICT-Trading-Bot"
# IMPORTANT: Replace with your actual GitHub repository URL
GITHUB_REPO_URL="YOUR_GITHUB_REPO_URL_HERE"
# Default installation directory
INSTALL_DIR_DEFAULT="/opt/$PROJECT_NAME"
# Dedicated user for the bot
BOT_USER_DEFAULT="flowaibot"
PYTHON_EXECUTABLE="python3"
VENV_NAME=".venv"
SERVICE_NAME="flowai-bot" # Name for the systemd service

# --- Global Variables (for script state) ---
INSTALL_DIR=""
BOT_USER=""

# --- Helper Functions ---
log_info() { echo "[INFO] $1"; }
log_warning() { echo "[WARNING] $1"; }
log_error() { echo "[ERROR] $1"; } # Does not exit in menu mode
log_success() { echo "[SUCCESS] $1"; }
print_divider() { echo "---------------------------------------------------------"; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "[FATAL] This script needs root or sudo privileges for initial setup and service management."
        echo "Please run as: sudo $0"
        exit 1
    fi
}

# Function to prompt for user input with a default value
prompt_with_default() {
    local prompt_message=$1
    local default_value=$2
    local variable_name=$3
    local user_input
    read -p "$prompt_message [$default_value]: " user_input
    eval "$variable_name=\"${user_input:-$default_value}\""
}

install_package_if_missing() {
    local cmd_to_check=$1
    local package_name=$2
    local friendly_name=${3:-$package_name} # Optional friendly name for messages

    if ! command -v $cmd_to_check &> /dev/null; then
        log_warning "$friendly_name ($cmd_to_check) not found. Attempting to install..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y -qq $package_name || { log_error "Failed to install $friendly_name via apt-get."; return 1; }
        elif command -v yum &> /dev/null; then
            sudo yum install -y $package_name || { log_error "Failed to install $friendly_name via yum."; return 1; }
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y $package_name || { log_error "Failed to install $friendly_name via dnf."; return 1; }
        else
            log_error "Unsupported package manager. Please install $friendly_name manually."
            return 1
        fi
        log_success "$friendly_name installed."
    fi
    return 0
}

# --- Core Installation Function ---
perform_installation() {
    set -e # Enable strict error checking for installation phase
    log_info "Starting Core Installation Process..."

    prompt_with_default "Enter installation directory" "$INSTALL_DIR_DEFAULT" INSTALL_DIR
    prompt_with_default "Enter dedicated username for the bot" "$BOT_USER_DEFAULT" BOT_USER

    # 1. System Prerequisites
    log_info "1. Installing System Prerequisites..."
    install_package_if_missing "git" "git" "Git" || exit 1
    install_package_if_missing "$PYTHON_EXECUTABLE" "python3" "Python 3" || exit 1
    # On some systems pip3 is separate, on others it's python3-pip linked to python3 -m pip
    if ! $PYTHON_EXECUTABLE -m pip --version &> /dev/null; then
        install_package_if_missing "pip3" "python3-pip" "Pip for Python 3" || exit 1
    fi
    PIP_EXECUTABLE="${PYTHON_EXECUTABLE} -m pip"
    install_package_if_missing "venv_check" "python3-venv" "Python 3 Venv module" # venv_check is a dummy name
    # Build tools
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y -qq build-essential libffi-dev python3-dev || log_error "Failed to install build tools (apt)."
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        sudo yum groupinstall -y "Development Tools" > /dev/null 2>&1 || sudo dnf groupinstall -y "Development Tools" > /dev/null 2>&1 || log_warning "Could not install Dev Tools group."
        sudo yum install -y libffi-devel python3-devel openssl-devel > /dev/null 2>&1 || sudo dnf install -y libffi-devel python3-devel openssl-devel > /dev/null 2>&1 || log_warning "Could not install -devel packages."
    fi
    log_success "System prerequisites checked/installed."

    # 2. Create Dedicated Bot User
    log_info "2. Creating dedicated user '$BOT_USER'..."
    if id "$BOT_USER" &>/dev/null; then
        log_info "User '$BOT_USER' already exists."
    else
        sudo useradd -r -m -d "/home/$BOT_USER" -s /bin/bash "$BOT_USER" || log_error "Failed to create user $BOT_USER."
        log_success "User '$BOT_USER' created with home /home/$BOT_USER."
    fi

    # 3. Download/Clone Project
    log_info "3. Setting up project directory at $INSTALL_DIR..."
    if [ -d "$INSTALL_DIR/.git" ]; then # Check if it's a git repo
        log_warning "Project directory $INSTALL_DIR seems to exist. Attempting to pull latest changes..."
        cd "$INSTALL_DIR"
        sudo -u "$BOT_USER" git pull || log_warning "git pull failed. Continuing with existing files."
        cd ..
    elif [ -d "$INSTALL_DIR" ]; then
         log_warning "Directory $INSTALL_DIR exists but is not a git repo or clone failed previously. Consider backing up manually."
         read -p "Proceed with setup in existing directory $INSTALL_DIR? (y/N): " -n 1 -r REPLY
         echo
         if [[ ! $REPLY =~ ^[Yy]$ ]]; then log_error "User aborted setup."; fi
    else
        sudo git clone "$GITHUB_REPO_URL" "$INSTALL_DIR" || log_error "Failed to clone repository from $GITHUB_REPO_URL."
    fi
    sudo chown -R "$BOT_USER":"$BOT_USER" "$INSTALL_DIR"
    sudo find "$INSTALL_DIR" -type d -exec chmod 750 {} \; # Dirs: user rwx, group rx, other ---
    sudo find "$INSTALL_DIR" -type f -exec chmod 640 {} \; # Files: user rw, group r, other ---
    sudo chmod +x "$INSTALL_DIR"/*.sh || true # Make shell scripts executable by owner
    log_success "Project in $INSTALL_DIR. Permissions set."

    # 4. Setup Python Virtual Environment & Install Dependencies
    log_info "4. Setting up Python virtual environment..."
    # Run commands as the bot user
    sudo -u "$BOT_USER" bash -c "
        set -e;
        cd '$INSTALL_DIR';
        if [ ! -d '$VENV_NAME' ]; then
            echo '[VENV] Creating virtual environment...';
            $PYTHON_EXECUTABLE -m venv '$VENV_NAME';
        fi;
        echo '[VENV] Activating virtual environment...';
        source '$VENV_NAME/bin/activate';
        echo '[VENV] Upgrading Pip...';
        $PIP_EXECUTABLE install --upgrade pip;
        echo '[VENV] Installing dependencies from requirements.txt...';
        if [ -f 'requirements.txt' ]; then
            $PIP_EXECUTABLE install -r requirements.txt;
        else
            echo '[VENV ERROR] requirements.txt not found!';
            exit 1; # This will be caught by the sudo -u bash -c wrapper
        fi;
        echo '[VENV] Verifying TA-Lib installation...';
        python -c 'import talib; print(\"[VENV SUCCESS] TA-Lib imported successfully.\")' || echo '[VENV WARNING] TA-Lib import test failed. Manual TA-Lib setup might be needed if bot errors.';
        deactivate;
        echo '[VENV] Setup complete.';
    " || log_error "Virtual environment setup or dependency installation failed."
    log_success "Python virtual environment and dependencies set up."

    # 5. Standardized Project Directory Structure
    log_info "5. Ensuring project directory structure..."
    sudo -u "$BOT_USER" bash -c "
        cd '$INSTALL_DIR' && \
        mkdir -p flow_ai_core && touch flow_ai_core/__init__.py && \
        mkdir -p data/historical_ohlcv && mkdir -p data/logs
    "
    log_success "Directory structure ensured."

    # 6. Configuration File Setup (.env)
    log_info "6. Configuration File (.env) Setup..."
    ENV_FILE="$INSTALL_DIR/.env"
    ENV_EXAMPLE_FILE="$INSTALL_DIR/.env.example"
    if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE_FILE" ]; then
        sudo cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
        sudo chown "$BOT_USER":"$BOT_USER" "$ENV_FILE"
        sudo chmod 600 "$ENV_FILE"
        log_warning "Copied .env.example to .env. YOU MUST EDIT $ENV_FILE with your actual settings."
    elif [ -f "$ENV_FILE" ]; then
        log_info ".env file already exists. Please ensure it's correctly configured."
    else
        log_warning ".env.example not found. Please create $ENV_FILE manually."
    fi

    # 7. Systemd Service Setup
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
# StandardOutput=journal # Default, good for 'journalctl -u service_name'
# StandardError=journal

# Resource Limits (Example - uncomment and adjust if needed)
# CPUQuota=75%
# MemoryMax=1G
# TasksMax=200

[Install]
WantedBy=multi-user.target
"
    echo "$SYSTEMD_SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null
    sudo chmod 644 "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    log_success "Systemd service '$SERVICE_NAME.service' created and enabled."
    log_info "To start it now: sudo systemctl start $SERVICE_NAME"

    set +e # Disable strict error checking for menu part
    log_info "--- Core Installation Finished ---"
    read -p "Press [Enter] to return to the main menu..."
}

# --- Management Functions ---
manage_service() {
    ACTION=$1
    sudo systemctl $ACTION $SERVICE_NAME
    log_info "Service action '$ACTION' executed. Current status:"
    sudo systemctl status $SERVICE_NAME --no-pager -n 20 # Show recent logs
    read -p "Press [Enter] to continue..."
}

view_logs() {
    log_info "Displaying live logs for $SERVICE_NAME (Press Ctrl+C to stop)..."
    sudo journalctl -u $SERVICE_NAME -f -n 100 # Show last 100 lines and follow
    read -p "Press [Enter] to return to menu (if Ctrl+C didn't exit script)..."
}

display_status_snapshot() {
    print_divider
    log_info "System Resource Snapshot:"
    echo "CPU Usage (last 1 min avg): $(uptime | awk -F'load average: ' '{ print $2 }' | cut -d, -f1)"
    free -h | grep "Mem:" | awk '{print "RAM Usage: " $3 "/" $2 " (Free: " $4 ")"}'
    df -h / | tail -n 1 | awk '{print "Root Disk Usage: " $3 "/" $2 " (" $5 " Used)"}'
    print_divider
    log_info "Service '$SERVICE_NAME' Status:"
    sudo systemctl status $SERVICE_NAME --no-pager -n 10 || log_warning "Could not get service status."
    print_divider
    # Basic check if process is running
    if pgrep -u "$BOT_USER" -f "$INSTALL_DIR/$VENV_NAME/bin/python main.py" > /dev/null; then
        log_success "Bot process seems to be RUNNING."
    else
        log_warning "Bot process seems to be NOT RUNNING."
    fi
    print_divider
    # Placeholder for Database Status - requires specific DB knowledge
    # Example if using PostgreSQL:
    # if command -v psql &> /dev/null; then
    #   log_info "PostgreSQL Service Status (if applicable):"
    #   sudo systemctl status postgresql --no-pager || log_warning "Could not get PostgreSQL status."
    # fi
    read -p "Press [Enter] to continue..."
}

edit_env_file() {
    if [ -z "$INSTALL_DIR" ] || [ ! -d "$INSTALL_DIR" ]; then
        prompt_with_default "Enter installation directory of the bot" "$INSTALL_DIR_DEFAULT" INSTALL_DIR
        if [ ! -d "$INSTALL_DIR" ]; then log_error "Installation directory $INSTALL_DIR not found."; return; fi
    fi
    log_info "Opening .env file for editing: $INSTALL_DIR/.env"
    log_warning "Ensure you have appropriate permissions or run editor with sudo if needed."
    sudo nano "$INSTALL_DIR/.env" # Or your preferred editor
    log_info ".env file editing session closed."
    read -p "Press [Enter] to continue..."
}

train_ai_model_interactive() {
    if [ -z "$INSTALL_DIR" ] || [ -z "$BOT_USER" ]; then
        log_warning "Installation directory or bot user not set. Please run full install first or set manually."
        prompt_with_default "Enter installation directory" "$INSTALL_DIR_DEFAULT" INSTALL_DIR
        prompt_with_default "Enter bot username" "$BOT_USER_DEFAULT" BOT_USER
        if [ ! -d "$INSTALL_DIR" ] || ! id "$BOT_USER" &>/dev/null; then
            log_error "Invalid directory or user."
            return
        fi
    fi
    log_info "Attempting to run AI model training as user '$BOT_USER'..."
    sudo -u "$BOT_USER" bash -c "
        set -e;
        cd '$INSTALL_DIR';
        echo '[TRAIN] Activating virtual environment...';
        source '$VENV_NAME/bin/activate';
        echo '[TRAIN] Starting train_model.py...';
        python train_model.py;
        echo '[TRAIN] train_model.py finished.';
        deactivate;
    " || log_error "AI Model training script failed."
    log_success "AI Model training process completed."
    read -p "Press [Enter] to continue..."
}


# --- Main Menu ---
main_menu() {
    # Try to auto-detect INSTALL_DIR and BOT_USER if service exists
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ] && [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service")
        BOT_USER=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service")
        log_info "Detected INSTALL_DIR: $INSTALL_DIR, BOT_USER: $BOT_USER from service file."
    fi


    while true; do
        clear
        echo "========================================================="
        echo " FlowAI-ICT-Trading-Bot Management Panel"
        echo " Project Directory: ${INSTALL_DIR:-Not Set}"
        echo " Bot User: ${BOT_USER:-Not Set}"
        echo " Service Name: $SERVICE_NAME"
        echo "========================================================="
        echo " --- Installation ---"
        echo "  1. Perform Full Installation / Re-check Prerequisites"
        echo " --- Service Management (systemd) ---"
        echo "  2. Start Bot Service"
        echo "  3. Stop Bot Service"
        echo "  4. Restart Bot Service"
        echo "  5. View Bot Service Status"
        echo " --- Monitoring & Logs ---"
        echo "  6. View Live Bot Logs (journalctl)"
        echo "  7. Display System & Service Status Snapshot"
        echo " --- Configuration ---"
        echo "  8. Edit .env Configuration File"
        echo " --- AI Model ---"
        echo "  9. Train AI Model"
        echo " --- Project Files ---"
        echo " 10. (Placeholder) Update Project from GitHub" # Needs careful implementation
        echo "---------------------------------------------------------"
        echo "  0. Exit"
        echo "========================================================="
        read -p "Enter your choice [0-10]: " choice

        case $choice in
            1) check_root; perform_installation ;;
            2) check_root; manage_service "start" ;;
            3) check_root; manage_service "stop" ;;
            4) check_root; manage_service "restart" ;;
            5) check_root; manage_service "status" ;;
            6) check_root; view_logs ;;
            7) display_status_snapshot ;; # Root not strictly needed for display, but some commands might be restricted
            8) check_root; edit_env_file ;; # Edit as root, or guide user
            9) check_root; train_ai_model_interactive ;; # Run as bot user after setup
            10) log_warning "Feature 'Update Project from GitHub' not fully implemented yet." 
                log_info "Manual update: cd $INSTALL_DIR; sudo -u $BOT_USER git pull; sudo systemctl restart $SERVICE_NAME"
                read -p "Press [Enter] to continue..." ;;
            0) echo "Exiting management panel."; exit 0 ;;
            *) log_warning "Invalid choice. Please try again." 
               read -p "Press [Enter] to continue..." ;;
        esac
    done
}

# --- Script Execution Logic ---
if [ "$1" == "--install-only" ]; then
    check_root
    perform_installation
    exit 0
fi

main_menu