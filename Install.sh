#!/bin/bash

# FlowAI-ICT-Trading-Bot Enhanced Installation & Management Script (Conda for TA-Lib)

set -e # Enable for setup, disable for menu

# --- Configuration Variables ---
PROJECT_NAME="FlowAI-ICT-Trading-Bot"
GITHUB_REPO_URL="YOUR_GITHUB_REPO_URL_HERE" # IMPORTANT: Replace
INSTALL_DIR_DEFAULT="/opt/$PROJECT_NAME"
BOT_USER_DEFAULT="flowaibot"
CONDA_ENV_NAME="flowai_env" # Name for the Conda environment for the bot
SERVICE_NAME="flowai-bot" 
PYTHON_EXECUTABLE="python3" # System Python, mainly for version check & initial venv if not using Conda

# --- Global Variables (for script state) ---
INSTALL_DIR=""
BOT_USER=""
PROJECT_ROOT=$(pwd) 

# --- Helper Functions ---
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; } # For menu mode, does not exit
log_fatal() { echo -e "\033[31m[FATAL]\033[0m $1"; exit 1; } # For setup phase
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
    local cmd_to_check=$1; local package_name=$2; local friendly_name=${3:-$package_name}
    if ! command -v $cmd_to_check &> /dev/null && ! (dpkg-query -W -f='${Status}' $package_name 2>/dev/null | grep -q "ok installed"); then
        log_warning "$friendly_name ($package_name) not found. Attempting to install..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y -qq $package_name || { log_error "Apt-get install $friendly_name failed."; return 1; }
        elif command -v yum &> /dev/null; then
            sudo yum install -y $package_name || { log_error "Yum install $friendly_name failed."; return 1; }
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y $package_name || { log_error "DNF install $friendly_name failed."; return 1; }
        else
            log_error "Unsupported OS for $friendly_name auto-install."; return 1
        fi
        log_success "$friendly_name installed."
    else
        log_info "$friendly_name already existing or command functional."
    fi
    return 0
}
# --- End Helper Functions ---

install_talib_via_conda_or_fallback() {
    log_info "--- Attempting TA-Lib Installation (Priority: Conda) ---"
    local current_bot_user="${1}" # Expect bot user as the first argument
    if [ -z "$current_bot_user" ]; then
        log_fatal "Bot user not specified for TA-Lib Conda installation."
    fi
    log_info "Will perform Conda operations for user: $current_bot_user"

    local conda_exec_path=""
    local bot_home="/home/$current_bot_user"

    if command -v conda &> /dev/null; then
        log_info "System-wide Conda found. Using it."
        conda_exec_path="conda"
    else
        log_info "System-wide Conda not found. Installing Miniconda for user '$current_bot_user' in $bot_home/miniconda3..."
        local miniconda_install_path="$bot_home/miniconda3"
        local miniconda_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
        
        if [ ! -d "$bot_home" ]; then
            log_warning "Home directory $bot_home not found. Attempting to create."
            sudo mkdir -p "$bot_home"
            sudo chown "$current_bot_user":"$current_bot_user" "$bot_home"
            sudo chmod 750 "$bot_home" # User rwx, group rx, other ---
        fi

        MINICONDA_INSTALL_SCRIPT_CONTENT=$(cat << EOF_MINICONDA_INSTALL
#!/bin/bash
set -e
MINICONDA_INSTALL_DIR="\$HOME/miniconda3" 
MINICONDA_URL_ARG="\$1"

echo "[MINICONDA_INSTALLER] Running as user: \$(whoami) in dir: \$(pwd)"
# Explicitly cd to user's home, which sudo -H should have set
if [ "\$(pwd)" != "\$HOME" ]; then
    cd "\$HOME" || { echo "[MINICONDA_INSTALLER_ERROR] Failed to cd to \$HOME"; exit 1; }
fi
echo "[MINICONDA_INSTALLER] Changed to \$(pwd) for Miniconda installation."

if [ -d "\$MINICONDA_INSTALL_DIR" ]; then
    echo "[MINICONDA_INSTALLER] Miniconda directory already exists at \$MINICONDA_INSTALL_DIR."
else
    echo "[MINICONDA_INSTALLER] Downloading Miniconda from \$MINICONDA_URL_ARG..."
    wget -q "\$MINICONDA_URL_ARG" -O miniconda_installer.sh
    echo "[MINICONDA_INSTALLER] Installing Miniconda to \$MINICONDA_INSTALL_DIR..."
    bash miniconda_installer.sh -b -p "\$MINICONDA_INSTALL_DIR"
    rm miniconda_installer.sh
    echo "[MINICONDA_INSTALLER] Miniconda installed."
    
    echo "[MINICONDA_INSTALLER] Initializing Conda for current shell (hook)..."
    # This makes 'conda' command available in the PATH for *this specific script execution*
    # The eval is important here.
    eval "\$(\"\$MINICONDA_INSTALL_DIR/bin/conda\" 'shell.bash' 'hook')" || echo '[MINICONDA_INSTALLER_WARN] Conda hook eval failed slightly, but might still work via full path or if init bash ran.';
    # Initialize for future login shells (modifies .bashrc)
    # "\$MINICONDA_INSTALL_DIR/bin/conda" init bash || echo "[MINICONDA_INSTALLER_WARN] conda init bash had an issue."
fi
EOF_MINICONDA_INSTALL
)
        TMP_MINICONDA_SCRIPT_PATH="/tmp/miniconda_install_temp.sh"
        echo "$MINICONDA_INSTALL_SCRIPT_CONTENT" | sudo tee "$TMP_MINICONDA_SCRIPT_PATH" > /dev/null
        sudo chmod 755 "$TMP_MINICONDA_SCRIPT_PATH"

        if ! sudo -H -u "$current_bot_user" bash "$TMP_MINICONDA_SCRIPT_PATH" "$miniconda_url"; then
            log_fatal "Miniconda installation failed for user $current_bot_user."
        fi
        sudo rm -f "$TMP_MINICONDA_SCRIPT_PATH"
        conda_exec_path="$miniconda_install_path/bin/conda" # Full path to user's conda
        if [ ! -x "$conda_exec_path" ]; then log_fatal "Conda executable not found at $conda_exec_path post-install."; fi
        log_success "Miniconda setup for user $current_bot_user completed."
    fi

    log_info "Creating/updating Conda environment '$CONDA_ENV_NAME' and installing TA-Lib using '$conda_exec_path'..."
    PYTHON_VERSION_FOR_CONDA=$($PYTHON_EXECUTABLE -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

    CONDA_ENV_SETUP_SCRIPT_CONTENT=$(cat << EOF_CONDA_ENV_SETUP
#!/bin/bash
set -e
CONDA_EXEC_SUB="\$1"
CONDA_ENV_NAME_SUB="\$2"
PYTHON_VERSION_SUB="\$3"
# BOT_HOME_SUB="/home/$current_bot_user" # Not needed if sudo -H sets HOME

echo "[CONDA_SCRIPT] Running as user: \$(whoami) with Conda: \$CONDA_EXEC_SUB";
echo "[CONDA_SCRIPT] Target Conda Env: \$CONDA_ENV_NAME_SUB, Python: \$PYTHON_VERSION_SUB"
echo "[CONDA_SCRIPT] Effective HOME: \$HOME"

cd "\$HOME" || { echo "[CONDA_SCRIPT_ERROR] Failed to cd to \$HOME (\$(whoami))"; exit 1; }
echo "[CONDA_SCRIPT] Changed CWD to: \$(pwd)"
unset XDG_CONFIG_HOME # Force use of ~/.condarc
echo "[CONDA_SCRIPT] XDG_CONFIG_HOME unset."

# Source conda shell hooks if conda command is not found directly (e.g. user-local miniconda)
if ! command -v conda &> /dev/null && [ -f "\$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    echo "[CONDA_SCRIPT] Sourcing user's Miniconda profile: \$HOME/miniconda3/etc/profile.d/conda.sh"
    source "\$HOME/miniconda3/etc/profile.d/conda.sh";
fi
# After sourcing, 'conda' might be available, but $CONDA_EXEC_SUB is more reliable (full path)

if ! \$CONDA_EXEC_SUB env list | grep -qw "\$CONDA_ENV_NAME_SUB"; then
    echo "[CONDA_SCRIPT] Creating Conda environment \$CONDA_ENV_NAME_SUB with Python \$PYTHON_VERSION_SUB...";
    \$CONDA_EXEC_SUB create -n "\$CONDA_ENV_NAME_SUB" python="\$PYTHON_VERSION_SUB" -y;
else
    echo "[CONDA_SCRIPT] Conda environment \$CONDA_ENV_NAME_SUB already exists.";
fi;
    
echo "[CONDA_SCRIPT] Installing TA-Lib via conda-forge into \$CONDA_ENV_NAME_SUB...";
\$CONDA_EXEC_SUB install -n "\$CONDA_ENV_NAME_SUB" -c conda-forge ta-lib numpy -y; # Install numpy with ta-lib here
    
echo "[CONDA_SCRIPT] Verifying TA-Lib import in \$CONDA_ENV_NAME_SUB...";
\$CONDA_EXEC_SUB run -n "\$CONDA_ENV_NAME_SUB" --no-capture-output python -c "import talib; import numpy; print(f'[CONDA_SCRIPT SUCCESS] TA-Lib {talib.__version__} and NumPy {numpy.__version__} imported in \$CONDA_ENV_NAME_SUB.')" || \
    (echo "[CONDA_SCRIPT ERROR] TA-Lib or NumPy import FAILED in \$CONDA_ENV_NAME_SUB!" && exit 1);
EOF_CONDA_ENV_SETUP
)
    TMP_CONDA_SCRIPT_PATH="/tmp/flowai_conda_env_setup.sh"
    echo "$CONDA_ENV_SETUP_SCRIPT_CONTENT" | sudo tee "$TMP_CONDA_SCRIPT_PATH" > /dev/null
    sudo chmod 755 "$TMP_CONDA_SCRIPT_PATH"

    if ! sudo -H -u "$current_bot_user" bash "$TMP_CONDA_SCRIPT_PATH" "$conda_exec_path" "$CONDA_ENV_NAME" "$PYTHON_VERSION_FOR_CONDA"; then
        log_fatal "TA-Lib installation using Conda FAILED."
    fi
    sudo rm -f "$TMP_CONDA_SCRIPT_PATH"
    
    log_success "TA-Lib & NumPy successfully configured using Conda in environment '$CONDA_ENV_NAME'."
    return 0
}

perform_installation() {
    set -e 
    log_info "Starting Core Installation Process..."
    prompt_with_default "Enter installation directory" "$INSTALL_DIR_DEFAULT" LOCAL_INSTALL_DIR
    prompt_with_default "Enter dedicated username for the bot" "$BOT_USER_DEFAULT" LOCAL_BOT_USER
    INSTALL_DIR="$LOCAL_INSTALL_DIR"; BOT_USER="$LOCAL_BOT_USER"; PROJECT_ROOT="$INSTALL_DIR" 

    log_info "1. Installing System Prerequisites (git, python3, basic build tools, wget)..."
    install_package_if_missing "git" "git" "Git" || log_fatal "Git failed."
    install_package_if_missing "$PYTHON_EXECUTABLE" "python3" "Python 3" || log_fatal "Python 3 failed."
    # For system python, pip and venv might still be useful for other non-conda things or script setup
    if ! $PYTHON_EXECUTABLE -m pip --version &> /dev/null; then
        install_package_if_missing "pip3" "python3-pip" "System Pip for Python 3" || log_warning "System Pip3 failed to install."
    fi
    PYTHON_MAJMIN_FOR_SYS_VENV=$($PYTHON_EXECUTABLE -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    install_package_if_missing "python${PYTHON_MAJMIN_FOR_SYS_VENV}-venv" "python${PYTHON_MAJMIN_FOR_SYS_VENV}-venv" "System Python venv module" || log_warning "System python venv module not installed."
    
    # Basic build tools that might be needed by other pip packages if any are built from source
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y -qq build-essential libffi-dev python3-dev wget tar || log_warning "Some build tools (apt) failed to install."
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        YUM_DEV_PKGS="gcc make gcc-c++ libffi-devel python3-devel openssl-devel wget tar"
        sudo yum install -y $YUM_DEV_PKGS > /dev/null 2>&1 || sudo dnf install -y $YUM_DEV_PKGS > /dev/null 2>&1 || log_warning "Some build/dev pkgs (yum/dnf) failed."
    fi
    log_success "System prerequisites checked/installed."

    log_info "2. Creating dedicated user '$BOT_USER'..."
    if id "$BOT_USER" &>/dev/null; then 
        log_info "User '$BOT_USER' already exists."
    else
        sudo useradd -r -m -d "/home/$BOT_USER" -s /bin/bash "$BOT_USER" || log_fatal "Failed to create user $BOT_USER."
        log_success "User '$BOT_USER' created with home directory /home/$BOT_USER."
    fi

    install_talib_via_conda_or_fallback "$BOT_USER" || log_fatal "TA-Lib setup via Conda failed. Cannot proceed."

    log_info "3. Setting up project directory at $INSTALL_DIR..."
    if [ ! -d "$INSTALL_DIR" ]; then 
        sudo git clone "$GITHUB_REPO_URL" "$INSTALL_DIR" || log_fatal "Clone $GITHUB_REPO_URL failed."
        sudo chown -R "$BOT_USER":"$BOT_USER" "$INSTALL_DIR" 
    elif [ -d "$INSTALL_DIR/.git" ]; then 
        log_warning "Project dir $INSTALL_DIR exists. Pulling as $BOT_USER..."
        (cd "$INSTALL_DIR" && sudo -u "$BOT_USER" git pull) || log_warning "git pull failed."
        sudo chown -R "$BOT_USER":"$BOT_USER" "$INSTALL_DIR"
    else 
        log_warning "Dir $INSTALL_DIR exists but is not a git repo. Using existing dir and ensuring ownership."
        sudo chown -R "$BOT_USER":"$BOT_USER" "$INSTALL_DIR"
    fi
    sudo find "$INSTALL_DIR" -type d -exec chmod 750 {} \; 
    sudo find "$INSTALL_DIR" -type f -exec chmod 640 {} \; 
    sudo chmod ug+x "$INSTALL_DIR"/*.sh "$INSTALL_DIR/main.py" "$INSTALL_DIR/train_model.py" || true
    log_success "Project in $INSTALL_DIR. Permissions set for $BOT_USER."

    log_info "4. Installing remaining Python dependencies into Conda env '$CONDA_ENV_NAME'..."
    CONDA_EXEC_FOR_DEPS="/home/$BOT_USER/miniconda3/bin/conda" 
    if command -v conda &>/dev/null && [ ! -x "$CONDA_EXEC_FOR_DEPS" ]; then 
        CONDA_EXEC_FOR_DEPS="conda"; 
    elif [ ! -x "$CONDA_EXEC_FOR_DEPS" ]; then 
        log_fatal "Conda executable not found ($CONDA_EXEC_FOR_DEPS). Cannot install deps."
    fi
    
    TMP_REQS="$INSTALL_DIR/tmp_requirements.txt" 
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        grep -vE "^TA-Lib|^numpy" "$INSTALL_DIR/requirements.txt" | sudo -u "$BOT_USER" tee "$TMP_REQS" > /dev/null
        
        DEPS_INSTALL_SCRIPT_CONTENT=$(cat << 'EOF_DEPS_INSTALL_SCRIPT'
#!/bin/bash
set -e;
CONDA_EXEC_ARG="$1"
CONDA_ENV_ARG="$2"
TMP_REQS_ARG="$3"
BOT_HOME_ARG="$4" # Pass bot home for sourcing conda.sh

echo "[DEPS_SCRIPT] Running as user: $(whoami)";
if [ -f "$BOT_HOME_ARG/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$BOT_HOME_ARG/miniconda3/etc/profile.d/conda.sh";
elif [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then # System conda
    source "/opt/conda/etc/profile.d/conda.sh";
fi

echo "[DEPS_SCRIPT] Upgrading pip in $CONDA_ENV_ARG...";
"$CONDA_EXEC_ARG" run -n "$CONDA_ENV_ARG" --no-capture-output pip install --upgrade pip;

echo "[DEPS_SCRIPT] Installing from $TMP_REQS_ARG into $CONDA_ENV_ARG...";
if [ -s "$TMP_REQS_ARG" ]; then 
     "$CONDA_EXEC_ARG" run -n "$CONDA_ENV_ARG" --no-capture-output pip install -r "$TMP_REQS_ARG";
else
     echo '[DEPS_SCRIPT] No other dependencies listed in tmp_requirements.txt.';
fi
echo '[DEPS_SCRIPT] Dependency installation into Conda env complete.';
EOF_DEPS_INSTALL_SCRIPT
)
        TMP_DEPS_SCRIPT_PATH="/tmp/flowai_deps_install.sh"
        echo "$DEPS_INSTALL_SCRIPT_CONTENT" | sudo tee "$TMP_DEPS_SCRIPT_PATH" > /dev/null
        sudo chmod 755 "$TMP_DEPS_SCRIPT_PATH"

        if ! sudo -H -u "$BOT_USER" bash "$TMP_DEPS_SCRIPT_PATH" "$CONDA_EXEC_FOR_DEPS" "$CONDA_ENV_NAME" "$TMP_REQS" "/home/$BOT_USER"; then 
            log_fatal "Failed to install remaining dependencies into Conda environment '$CONDA_ENV_NAME'."
        fi
        sudo -u "$BOT_USER" rm -f "$TMP_REQS" 
        sudo rm -f "$TMP_DEPS_SCRIPT_PATH"
        log_success "Remaining Python dependencies installed in Conda env '$CONDA_ENV_NAME'."
    else
        log_warning "requirements.txt not found in $INSTALL_DIR. Skipping other dependencies."
    fi

    log_info "5. Ensuring project directory structure..."
    sudo -u "$BOT_USER" bash -c "cd '$INSTALL_DIR' && mkdir -p flow_ai_core && touch flow_ai_core/__init__.py && mkdir -p data/historical_ohlcv && mkdir -p data/logs"
    log_success "Directory structure ensured."

    log_info "6. Configuration File (.env) Setup..."
    # (.env setup as before)
    ENV_FILE="$INSTALL_DIR/.env"; ENV_EXAMPLE_FILE="$INSTALL_DIR/.env.example"
    if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE_FILE" ]; then
        sudo cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"; sudo chown "$BOT_USER":"$BOT_USER" "$ENV_FILE"; sudo chmod 600 "$ENV_FILE"
        log_warning "Copied .env.example to .env. EDIT $ENV_FILE with your settings."
    elif [ -f "$ENV_FILE" ]; then log_info ".env file already exists at $ENV_FILE."; 
    else log_warning ".env.example not found. Create $ENV_FILE manually."; fi

    log_info "7. Setting up systemd service '$SERVICE_NAME'..."
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    CONDA_RUN_EXEC_FOR_SERVICE="/home/$BOT_USER/miniconda3/bin/conda" 
    if command -v conda &>/dev/null && [ ! -x "$CONDA_RUN_EXEC_FOR_SERVICE" ]; then CONDA_RUN_EXEC_FOR_SERVICE="conda"; fi
    if [ ! -x "$CONDA_RUN_EXEC_FOR_SERVICE" ]; then log_fatal "Conda for service not found at $CONDA_RUN_EXEC_FOR_SERVICE or system path."; fi
    
    PYTHON_IN_CONDA_ENV="/home/$BOT_USER/miniconda3/envs/$CONDA_ENV_NAME/bin/python"
    if [ ! -x "$PYTHON_IN_CONDA_ENV" ]; then
        CONDA_ENV_PATH_OUTPUT=$(sudo -H -u "$BOT_USER" "$CONDA_RUN_EXEC_FOR_SERVICE" env list | grep "$CONDA_ENV_NAME" | awk '{print $NF}' | tail -n 1)
        if [ -n "$CONDA_ENV_PATH_OUTPUT" ] && [ -d "$CONDA_ENV_PATH_OUTPUT" ]; then
            PYTHON_IN_CONDA_ENV="$CONDA_ENV_PATH_OUTPUT/bin/python"
        else
            log_fatal "Could not determine Python path in Conda env $CONDA_ENV_NAME for systemd (Path: $CONDA_ENV_PATH_OUTPUT)."
        fi
    fi
    if [ ! -x "$PYTHON_IN_CONDA_ENV" ]; then log_fatal "Python in Conda env $PYTHON_IN_CONDA_ENV not executable/found."; fi

    SYSTEMD_SERVICE_CONTENT="[Unit]
Description=$PROJECT_NAME Service (Conda Env: $CONDA_ENV_NAME)
After=network.target
[Service]
Type=simple
User=$BOT_USER
Group=$BOT_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON_IN_CONDA_ENV main.py
Restart=on-failure
RestartSec=10s
Environment=\"PYTHONUNBUFFERED=1\"
# If Miniconda was installed for user and not system-wide, PATH might need adjustment for systemd
# Environment=\"PATH=/home/$BOT_USER/miniconda3/envs/$CONDA_ENV_NAME/bin:/home/$BOT_USER/miniconda3/bin:\$PATH\"
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

# --- Management Functions (train_ai_model_interactive, perform_uninstall, main_menu, etc.) ---
# (Pasted from previous full script version, ensure they are complete and correct)
manage_service() { local ACTION=$1; if [ -z "$INSTALL_DIR" ]; then INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT"); fi; sudo systemctl $ACTION $SERVICE_NAME; log_info "Service action '$ACTION'. Status:"; sudo systemctl status $SERVICE_NAME --no-pager -n 10; read -p "Press [Enter]..."; }
view_logs() { sudo journalctl -u $SERVICE_NAME -f -n 100; read -p "Press [Enter]..."; }
display_status_snapshot() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "N/A")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "N/A")}
    local conda_python_path_part_check="/envs/$CONDA_ENV_NAME/bin/python" # Check for this string in process list
    print_divider; log_info "System Resource Snapshot:"; 
    echo "CPU Load (1m): $(uptime | awk -F'average: ' '{ print $2 }' | cut -d, -f1), RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}), Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"})"
    log_info "Service '$SERVICE_NAME' (User: $current_bot_user, Dir: $current_install_dir, Conda Env: $CONDA_ENV_NAME):"; sudo systemctl status $SERVICE_NAME --no-pager -n 5 || log_warning "No status."
    # Updated pgrep to be more flexible with conda paths
    if pgrep -u "$current_bot_user" -f "miniconda3/envs/$CONDA_ENV_NAME/bin/python $current_install_dir/main.py" > /dev/null || \
       pgrep -u "$current_bot_user" -f "conda run -n $CONDA_ENV_NAME .* python main.py" > /dev/null ; then 
       log_success "Bot (Conda) process RUNNING."; 
    else 
       log_warning "Bot (Conda) process NOT RUNNING."; 
    fi
    print_divider; read -p "Press [Enter]..."
}
edit_env_file() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    sudo nano "$current_install_dir/.env"; log_info ".env edit closed."; read -p "Press [Enter]..."
}
train_ai_model_interactive() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$BOT_USER_DEFAULT")}
    
    local conda_exec_for_train="/home/$current_bot_user/miniconda3/bin/conda"
    if command -v conda &>/dev/null && [ ! -x "$conda_exec_for_train" ]; then conda_exec_for_train="conda"; fi
    if [ ! -x "$conda_exec_for_train" ]; then log_error "Conda for training not found."; read -p "[Enter]..."; return; fi

    log_info "Training AI as '$current_bot_user' in '$current_install_dir' using Conda env '$CONDA_ENV_NAME'..."
    # Using sudo -u to execute a bash script snippet that activates conda and runs python
    TRAIN_SCRIPT_CONTENT_INNER=$(cat << EOF_TRAIN_INNER_HEREDOC
#!/bin/bash
set -e;
cd "$1"; # $1 is current_install_dir
CONDA_EXEC_PATH_INNER="\$2" # $2 is conda_exec_for_train
CONDA_ENV_NAME_INNER="\$3" # $3 is CONDA_ENV_NAME

echo '[TRAIN_CONDA] Effective user: \$(whoami), Effective HOME: \$HOME';
echo '[TRAIN_CONDA] Sourcing Conda environment for training...';
if [ -f "\$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "\$HOME/miniconda3/etc/profile.d/conda.sh";
elif [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then 
     source "/opt/conda/etc/profile.d/conda.sh";
else
    echo '[TRAIN_CONDA_WARN] Could not source conda.sh automatically.';
fi
echo '[TRAIN_CONDA] Starting train_model.py in env \$CONDA_ENV_NAME_INNER...';
"\$CONDA_EXEC_PATH_INNER" run -n "\$CONDA_ENV_NAME_INNER" --no-capture-output python train_model.py;
echo '[TRAIN_CONDA] train_model.py finished.';
EOF_TRAIN_INNER_HEREDOC
)
    TMP_TRAIN_SCRIPT_PATH_INNER="/tmp/flowai_train_temp.sh"
    echo "$TRAIN_SCRIPT_CONTENT_INNER" | sudo tee "$TMP_TRAIN_SCRIPT_PATH_INNER" > /dev/null
    sudo chmod 755 "$TMP_TRAIN_SCRIPT_PATH_INNER"

    if ! sudo -H -u "$current_bot_user" bash "$TMP_TRAIN_SCRIPT_PATH_INNER" "$current_install_dir" "$conda_exec_for_train" "$CONDA_ENV_NAME";
    then log_error "AI Training FAILED."; else log_success "AI Training COMPLETED."; fi
    sudo rm -f "$TMP_TRAIN_SCRIPT_PATH_INNER"
    read -p "Press [Enter]..."
}
perform_uninstall() {
    set -e 
    log_warning "--- Starting Full Uninstall Process ---"
    local current_install_dir=${INSTALL_DIR}
    local current_bot_user=${BOT_USER} # These should be set if install was run
    if [ -z "$current_install_dir" ] && [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then current_install_dir=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null); fi
    if [ -z "$current_bot_user" ] && [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then current_bot_user=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null); fi
    if [ -z "$current_install_dir" ]; then prompt_with_default "Install directory to remove" "$INSTALL_DIR_DEFAULT" current_install_dir; fi
    if [ -z "$current_bot_user" ]; then prompt_with_default "Bot username to remove" "$BOT_USER_DEFAULT" current_bot_user; fi
    if [ -z "$current_install_dir" ] || [ -z "$current_bot_user" ]; then log_error "Cannot determine dir/user. Aborting."; return 1; fi

    log_warning "Uninstalling User: '$current_bot_user', Dir: '$current_install_dir', Service: '$SERVICE_NAME', Conda Env: '$CONDA_ENV_NAME'"
    read -p "ARE YOU SURE? This is irreversible. (yes/NO): " CONFIRM_UNINSTALL
    if [[ "$CONFIRM_UNINSTALL" != "yes" ]]; then log_info "Uninstall aborted."; return; fi

    log_info "Stopping/disabling service '$SERVICE_NAME'..."
    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then sudo systemctl stop "$SERVICE_NAME" || true; sudo systemctl disable "$SERVICE_NAME" || true; sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"; sudo rm -f "/etc/systemd/system/multi-user.target.wants/$SERVICE_NAME.service"; sudo systemctl daemon-reload; sudo systemctl reset-failed; log_success "Service removed."; else log_warning "Service not found."; fi
    
    local conda_exec_for_uninstall="/home/$current_bot_user/miniconda3/bin/conda"
    if command -v conda &>/dev/null && [ ! -x "$conda_exec_for_uninstall" ]; then conda_exec_for_uninstall="conda"; fi
    if [ -x "$conda_exec_for_uninstall" ]; then
        log_info "Removing Conda environment '$CONDA_ENV_NAME' for user '$current_bot_user'..."
        # Need to ensure the user running this (root) can tell the bot_user's conda to remove env
        # Or, bot_user removes its own env
        sudo -H -u "$current_bot_user" bash -c "
            if [ -f \"\$HOME/miniconda3/etc/profile.d/conda.sh\" ]; then source \"\$HOME/miniconda3/etc/profile.d/conda.sh\"; fi;
            \"$conda_exec_for_uninstall\" env remove -n \"$CONDA_ENV_NAME\" -y || echo 'Warning: Conda env remove command failed, may not have existed.'
        " || log_warning "Conda env removal command block had issues."
    else log_warning "Conda exec not found, cannot remove Conda env $CONDA_ENV_NAME automatically."; fi

    log_info "Deleting project dir '$current_install_dir'..."; if [ -d "$current_install_dir" ]; then sudo rm -rf "$current_install_dir"; log_success "Project dir deleted."; else log_warning "Project dir not found."; fi
    log_info "Deleting user '$current_bot_user'..."
    if id "$current_bot_user" &>/dev/null; then 
        sudo pkill -u "$current_bot_user" || true # Kill processes before userdel
        # Check if user has running processes - userdel -r might fail
        if ps -u "$current_bot_user" | grep -q "[^PID]"; then log_warning "User $current_bot_user still has running processes. userdel -r might fail."; fi
        sudo userdel -r "$current_bot_user" || log_warning "userdel -r for $current_bot_user failed. Home dir /home/$current_bot_user might need manual removal if not gone."; 
        if [ -d "/home/$current_bot_user" ]; then log_warning "User home /home/$current_bot_user still exists after userdel -r. Please check."; fi
        log_success "Attempted deletion of user '$current_bot_user'."; 
    else log_warning "User not found."; fi
    
    log_info "Checking for user-specific Miniconda installation for $current_bot_user..."
    if [ -d "/home/$current_bot_user/miniconda3" ]; then # Check if dir still exists (userdel -r should remove /home/user)
        read -p "Miniconda installation directory /home/$current_bot_user/miniconda3 might still exist if userdel -r didn't fully clean. Remove it? (yes/NO): " RM_CONDA
        if [[ "$RM_CONDA" == "yes" ]]; then sudo rm -rf "/home/$current_bot_user/miniconda3"; log_success "Removed /home/$current_bot_user/miniconda3."; else log_info "Skipped Miniconda directory removal."; fi
    fi
    INSTALL_DIR=""; BOT_USER="" 
    set +e; log_success "--- Full Uninstall Complete ---"; read -p "Press [Enter]..."
}

main_menu() {
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ] && [ -z "$INSTALL_DIR" ]; then # Only if INSTALL_DIR not set by perform_installation
        INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        BOT_USER=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null)
        if [ -n "$INSTALL_DIR" ]; then log_info "Detected active INSTALL_DIR: $INSTALL_DIR from service file."; fi
    fi
    while true; do clear
        echo "========================================================="
        echo " FlowAI-ICT-Trading-Bot Management Panel (Conda Mode)"
        echo " Project Dir: ${INSTALL_DIR:-Not Set/Run Install First}"
        echo " Bot User   : ${BOT_USER:-Not Set/Run Install First}"
        echo " Conda Env  : $CONDA_ENV_NAME"; echo " Service    : $SERVICE_NAME"; echo "========================================================="
        echo "  1. Install/Re-check"; echo "  2. Start Service"; echo "  3. Stop Service"; echo "  4. Restart Service"; echo "  5. Service Status"
        echo "  6. View Logs";  echo "  7. System Status"; echo "  8. Edit .env"; echo "  9. Train AI Model"
        echo " 10. (Info) Update Project"; echo " 11. Full Uninstall"; echo "---------------------------------------------------------"; echo "  0. Exit"
        echo "========================================================="; read -p "Enter choice [0-11]: " choice
        case $choice in
            1) check_root; perform_installation ;; 2) check_root; manage_service "start" ;; 3) check_root; manage_service "stop" ;; 
            4) check_root; manage_service "restart" ;; 5) check_root; manage_service "status" ;; 6) check_root; view_logs ;;
            7) display_status_snapshot ;; 8) check_root; edit_env_file ;; 9) check_root; train_ai_model_interactive ;;
            10) log_info "To update: cd ${INSTALL_DIR:-/path}; sudo -u ${BOT_USER:-$BOT_USER_DEFAULT} git pull; sudo systemctl restart $SERVICE_NAME"; read -p "[Enter]..." ;;
            11) check_root; perform_uninstall ;; 0) echo "Exiting."; exit 0 ;; *) log_warning "Invalid choice."; read -p "[Enter]..." ;;
        esac; done
}
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