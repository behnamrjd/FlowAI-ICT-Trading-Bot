#!/bin/bash

# FlowAI-ICT-Trading-Bot Enhanced Installation Script (Conda for TA-Lib)

set -e 

# --- Configuration Variables ---
PROJECT_NAME="FlowAI-ICT-Trading-Bot"
GITHUB_REPO_URL="YOUR_GITHUB_REPO_URL_HERE" 
INSTALL_DIR_DEFAULT="/opt/$PROJECT_NAME"
BOT_USER_DEFAULT="flowaibot"
CONDA_ENV_NAME="flowai_env" 
SERVICE_NAME="flowai-bot" 
PYTHON_EXECUTABLE="python3" # Still useful for initial checks and creating system venv if not using conda

# --- Global Variables ---
INSTALL_DIR=""
BOT_USER=""
PROJECT_ROOT=$(pwd) 

# --- Helper Functions ---
# (log_info, log_warning, log_error, log_fatal, log_success, print_divider, check_root, prompt_with_default, install_package_if_missing - same as before)
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_warning() { echo -e "\033[33m[WARNING]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }
log_fatal() { echo -e "\033[31m[FATAL]\033[0m $1"; exit 1; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
print_divider() { echo "---------------------------------------------------------"; }
check_root() { if [ "$(id -u)" -ne 0 ]; then log_fatal "Root/sudo privileges required."; fi }
prompt_with_default() { local p=$1 d=$2 v=$3; read -p "$p [$d]: " i; eval "$v=\"${i:-$d}\""; }
install_package_if_missing() { 
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

install_talib_via_conda_or_fallback() {
    log_info "--- Attempting TA-Lib Installation (Priority: Conda) ---"
    # This function now expects BOT_USER to be already created and passed or available globally.

    local current_bot_user="${1:-$BOT_USER}" # Expect bot user as an argument
    if [ -z "$current_bot_user" ]; then
        log_fatal "Bot user not specified for TA-Lib Conda installation."
    fi
    log_info "Will perform Conda operations for user: $current_bot_user"

    local conda_exec_path="" # Will be determined

    # Check if conda command exists system-wide
    if command -v conda &> /dev/null; then
        log_info "System-wide Conda found. Using it to manage environment '$CONDA_ENV_NAME'."
        conda_exec_path="conda"
    else
        log_info "System-wide Conda not found. Installing Miniconda for user '$current_bot_user'..."
        local miniconda_install_path="/home/$current_bot_user/miniconda3"
        local miniconda_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
        
        # Download and install Miniconda as the bot_user
        # Ensure the home directory for bot_user exists if useradd didn't -m properly or was skipped
        if [ ! -d "/home/$current_bot_user" ]; then
            log_warning "Home directory /home/$current_bot_user not found. Attempting to create."
            sudo mkdir -p "/home/$current_bot_user"
            sudo chown "$current_bot_user":"$current_bot_user" "/home/$current_bot_user"
        fi

        # The sudo -u block for installing miniconda
        if ! sudo -H -u "$current_bot_user" bash -c "
            set -e;
            cd \"/home/$current_bot_user\"; # Go to user's home to install Miniconda
            MINICONDA_INSTALL_DIR=\"\$HOME/miniconda3\"; # Use \$HOME within the subshell
            if [ -d \"\$MINICONDA_INSTALL_DIR\" ]; then
                echo '[CONDA_INSTALLER] Miniconda directory already exists at \$MINICONDA_INSTALL_DIR. Skipping install.';
            else
                echo '[CONDA_INSTALLER] Downloading Miniconda...';
                wget -q '$miniconda_url' -O miniconda_installer.sh;
                echo '[CONDA_INSTALLER] Installing Miniconda to \$MINICONDA_INSTALL_DIR...';
                bash miniconda_installer.sh -b -p \"\$MINICONDA_INSTALL_DIR\";
                rm miniconda_installer.sh;
                echo '[CONDA_INSTALLER] Miniconda installed.';
                # Initialize conda for the bot user's bash (non-interactively for scripts)
                # This step is crucial for 'conda activate' or 'conda run' to work in subsequent scripts by this user
                echo '[CONDA_INSTALLER] Initializing Conda for user...';
                # Attempt to initialize without modifying .bashrc directly in non-interactive way
                eval \"\$(\"\$MINICONDA_INSTALL_DIR/bin/conda\" 'shell.bash' 'hook')\" || echo '[CONDA_INSTALLER_WARN] Conda hook eval failed, but might still work via full path.';
                # The above line makes 'conda' command available in *this current subshell*.
                # For systemd or future sudo -u calls, we'll rely on full path to conda binary.
            fi;
        "; then
            log_fatal "Miniconda installation failed for user $current_bot_user."
        fi
        conda_exec_path="/home/$current_bot_user/miniconda3/bin/conda"
        if [ ! -x "$conda_exec_path" ]; then log_fatal "Conda executable not found at $conda_exec_path after install attempt."; fi
        log_success "Miniconda setup for user $current_bot_user completed."
    fi


    log_info "Creating/updating Conda environment '$CONDA_ENV_NAME' and installing TA-Lib using $conda_exec_path..."
    PYTHON_VERSION_FOR_CONDA=$($PYTHON_EXECUTABLE -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

    # Run conda operations as the bot user, using the determined conda_exec_path
    # The heredoc provides the script to be run by bash -s
    # The arguments to 'bash -s' are then $1, $2, $3 etc. inside the heredoc script
    if ! sudo -H -u "$current_bot_user" bash -s -- "$conda_exec_path" "$CONDA_ENV_NAME" "$PYTHON_VERSION_FOR_CONDA" << 'EOF_CONDA_ENV_SETUP'
        set -e;
        CONDA_EXEC_SUB="$1"
        CONDA_ENV_NAME_SUB="$2"
        PYTHON_VERSION_SUB="$3"

        echo "[CONDA_SCRIPT] Running as user: $(whoami) with Conda: $CONDA_EXEC_SUB";
        
        # Source conda activate for this script if Miniconda was just installed for user AND not system-wide
        # This ensures the 'conda' command is available if it's a user-local install
        # The -H in sudo -u should set HOME correctly.
        if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
            echo "[CONDA_SCRIPT] Sourcing user's Miniconda profile..."
            source "$HOME/miniconda3/etc/profile.d/conda.sh";
        elif [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then # Common path for root/system conda
            echo "[CONDA_SCRIPT] Sourcing system Conda profile..."
            source "/opt/conda/etc/profile.d/conda.sh";
        fi
        
        # Check if env exists, if not create it. If exists, just ensure Python version and install ta-lib.
        if ! $CONDA_EXEC_SUB env list | grep -qw "$CONDA_ENV_NAME_SUB"; then # -w for whole word match
            echo "[CONDA_SCRIPT] Creating Conda environment $CONDA_ENV_NAME_SUB with Python $PYTHON_VERSION_SUB...";
            $CONDA_EXEC_SUB create -n "$CONDA_ENV_NAME_SUB" python="$PYTHON_VERSION_SUB" -y;
        else
            echo "[CONDA_SCRIPT] Conda environment $CONDA_ENV_NAME_SUB already exists.";
            # Optionally update python here if needed, or ensure it's the right version
        fi;
        
        echo "[CONDA_SCRIPT] Installing TA-Lib via conda-forge into $CONDA_ENV_NAME_SUB...";
        $CONDA_EXEC_SUB install -n "$CONDA_ENV_NAME_SUB" -c conda-forge ta-lib -y;
        
        echo "[CONDA_SCRIPT] Verifying TA-Lib import in $CONDA_ENV_NAME_SUB...";
        $CONDA_EXEC_SUB run -n "$CONDA_ENV_NAME_SUB" python -c "import talib; print(f'[CONDA_SCRIPT SUCCESS] TA-Lib {talib.__version__} imported in $CONDA_ENV_NAME_SUB.')" || \
            (echo "[CONDA_SCRIPT ERROR] TA-Lib import FAILED in $CONDA_ENV_NAME_SUB!" && exit 1);
EOF_CONDA_ENV_SETUP
    then
        log_fatal "TA-Lib installation using Conda FAILED."
    fi
    
    log_success "TA-Lib successfully configured using Conda in environment '$CONDA_ENV_NAME'."
    return 0
}

perform_installation() {
    set -e 
    log_info "Starting Core Installation Process..."
    prompt_with_default "Enter installation directory" "$INSTALL_DIR_DEFAULT" LOCAL_INSTALL_DIR
    prompt_with_default "Enter dedicated username for the bot" "$BOT_USER_DEFAULT" LOCAL_BOT_USER
    
    # Set global vars for other functions in the script to use
    INSTALL_DIR="$LOCAL_INSTALL_DIR"
    BOT_USER="$LOCAL_BOT_USER"
    PROJECT_ROOT="$INSTALL_DIR" 

    log_info "1. Installing System Prerequisites (git, python3, pip, build tools)..."
    # (Prerequisites installation - ensure python3-pip and pythonX.Y-venv are covered if not using conda's python for venv)
    # For Conda approach, primary need is wget/curl for Miniconda installer, and basic build tools if any other package needs them.
    install_package_if_missing "git" "git" "Git" || log_fatal "Git failed."
    install_package_if_missing "$PYTHON_EXECUTABLE" "python3" "Python 3" || log_fatal "Python 3 failed."
    # Pip and venv for system Python might not be strictly needed if all goes into Conda.
    # But good to have for general Python use or fallback.
    if ! $PYTHON_EXECUTABLE -m pip --version &> /dev/null; then
        install_package_if_missing "pip3" "python3-pip" "Pip for Python 3" || log_fatal "Pip3 failed."
    fi
    PYTHON_MAJMIN_FOR_SYS_VENV=$($PYTHON_EXECUTABLE -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    install_package_if_missing "python${PYTHON_MAJMIN_FOR_SYS_VENV}-venv" "python${PYTHON_MAJMIN_FOR_SYS_VENV}-venv" "System Python venv module" || log_warning "System python venv module not installed. Relying on Conda."

    if command -v apt-get &> /dev/null; then # Basic build tools that might be needed by other pip packages
        sudo apt-get install -y -qq build-essential libffi-dev python3-dev wget tar || log_warning "Some build tools (apt) failed to install."
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        YUM_DEV_PKGS="gcc make gcc-c++ libffi-devel python3-devel openssl-devel wget tar"
        sudo yum install -y $YUM_DEV_PKGS > /dev/null 2>&1 || sudo dnf install -y $YUM_DEV_PKGS > /dev/null 2>&1 || log_warning "Some build/dev pkgs (yum/dnf) failed."
    fi
    log_success "System prerequisites checked/installed."

    # --- Order Change: Create User FIRST ---
    log_info "2. Creating dedicated user '$BOT_USER'..."
    if id "$BOT_USER" &>/dev/null; then 
        log_info "User '$BOT_USER' already exists."
    else
        sudo useradd -r -m -d "/home/$BOT_USER" -s /bin/bash "$BOT_USER" || log_fatal "Failed to create user $BOT_USER."
        log_success "User '$BOT_USER' created with home directory /home/$BOT_USER."
    fi

    # --- Install TA-Lib (via Conda, now that BOT_USER exists) ---
    install_talib_via_conda_or_fallback "$BOT_USER" || log_fatal "TA-Lib installation main function failed. Cannot proceed."

    # --- The rest of the setup (Project clone, other deps, service) ---
    log_info "3. Setting up project directory at $INSTALL_DIR..."
    # (Clone/pull logic - ensure it works correctly if dir created by root then chowned)
    if [ ! -d "$INSTALL_DIR" ]; then # If directory doesn't exist, clone it
        sudo git clone "$GITHUB_REPO_URL" "$INSTALL_DIR" || log_fatal "Clone $GITHUB_REPO_URL failed."
        sudo chown -R "$BOT_USER":"$BOT_USER" "$INSTALL_DIR" # Chown after clone
    elif [ -d "$INSTALL_DIR/.git" ]; then # If it's a git repo, pull
        log_warning "Project dir $INSTALL_DIR exists. Pulling as $BOT_USER..."
        (cd "$INSTALL_DIR" && sudo -u "$BOT_USER" git pull) || log_warning "git pull failed."
        # Ensure ownership again in case root created some files during a previous failed script
        sudo chown -R "$BOT_USER":"$BOT_USER" "$INSTALL_DIR"
    else # Directory exists but not a git repo
        log_warning "Dir $INSTALL_DIR exists but is not a git repo. Using existing dir."
        # Ensure ownership
        sudo chown -R "$BOT_USER":"$BOT_USER" "$INSTALL_DIR"
    fi
    # Set permissions after ensuring ownership
    sudo find "$INSTALL_DIR" -type d -exec chmod 750 {} \; # User rwx, Group rx, Other ---
    sudo find "$INSTALL_DIR" -type f -exec chmod 640 {} \; # User rw, Group r, Other ---
    sudo chmod ug+x "$INSTALL_DIR"/*.sh "$INSTALL_DIR/main.py" "$INSTALL_DIR/train_model.py" || true
    log_success "Project in $INSTALL_DIR. Permissions set for $BOT_USER."


    log_info "4. Installing remaining Python dependencies into Conda env '$CONDA_ENV_NAME'..."
    CONDA_EXEC_FOR_DEPS="/home/$BOT_USER/miniconda3/bin/conda" # Default path for user-installed Miniconda
    if command -v conda &>/dev/null && ! [ -x "$CONDA_EXEC_FOR_DEPS" ]; then # If system conda exists and user one doesn't
        CONDA_EXEC_FOR_DEPS="conda" # Use system conda
    elif [ ! -x "$CONDA_EXEC_FOR_DEPS" ]; then # If neither system conda nor user-specific conda found
        log_fatal "Conda executable not found. Path used: $CONDA_EXEC_FOR_DEPS. Cannot install remaining dependencies."
    fi
    
    TMP_REQS="$INSTALL_DIR/tmp_requirements.txt" # Create in project dir
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        # Exclude TA-Lib and numpy as Conda handles them well.
        grep -vE "^TA-Lib|^numpy" "$INSTALL_DIR/requirements.txt" | sudo -u "$BOT_USER" tee "$TMP_REQS" > /dev/null
        
        # Pass arguments to the sub-script via 'bash -s -- arg1 arg2 ...'
        if ! sudo -H -u "$BOT_USER" bash -s -- "$CONDA_EXEC_FOR_DEPS" "$CONDA_ENV_NAME" "$TMP_REQS" << 'EOF_DEPS_INSTALL_SCRIPT'
            set -e;
            CONDA_EXEC_ARG="$1"
            CONDA_ENV_ARG="$2"
            TMP_REQS_ARG="$3"

            echo "[DEPS_SCRIPT] Running as user: $(whoami)";
            if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
                source "$HOME/miniconda3/etc/profile.d/conda.sh";
            elif [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
                source "/opt/conda/etc/profile.d/conda.sh";
            fi
            
            echo "[DEPS_SCRIPT] Upgrading pip in $CONDA_ENV_ARG...";
            "$CONDA_EXEC_ARG" run -n "$CONDA_ENV_ARG" pip install --upgrade pip;

            echo "[DEPS_SCRIPT] Installing from $TMP_REQS_ARG into $CONDA_ENV_ARG...";
            if [ -s "$TMP_REQS_ARG" ]; then 
                 "$CONDA_EXEC_ARG" run -n "$CONDA_ENV_ARG" pip install -r "$TMP_REQS_ARG";
            else
                 echo '[DEPS_SCRIPT] No other dependencies listed in tmp_requirements.txt.';
            fi
            echo '[DEPS_SCRIPT] Dependency installation into Conda env complete.';
EOF_DEPS_INSTALL_SCRIPT
        then 
            log_fatal "Failed to install remaining dependencies into Conda environment '$CONDA_ENV_NAME'."
        fi
        sudo -u "$BOT_USER" rm -f "$TMP_REQS" # Clean up
        log_success "Remaining Python dependencies installed in Conda env '$CONDA_ENV_NAME'."
    else
        log_warning "requirements.txt not found in $INSTALL_DIR. Skipping other dependencies."
    fi

    # (Steps 5, 6, 7: Directory structure, .env, systemd service setup - same as before,
    #  but ensure Systemd ExecStart uses the Conda environment correctly)
    log_info "5. Ensuring project directory structure..."
    sudo -u "$BOT_USER" bash -c "cd '$INSTALL_DIR' && mkdir -p flow_ai_core && touch flow_ai_core/__init__.py && mkdir -p data/historical_ohlcv && mkdir -p data/logs"
    log_success "Directory structure ensured."

    log_info "6. Configuration File (.env) Setup..."
    ENV_FILE="$INSTALL_DIR/.env"; ENV_EXAMPLE_FILE="$INSTALL_DIR/.env.example"
    if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE_FILE" ]; then
        sudo cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"; sudo chown "$BOT_USER":"$BOT_USER" "$ENV_FILE"; sudo chmod 600 "$ENV_FILE"
        log_warning "Copied .env.example to .env. EDIT $ENV_FILE with your settings."
    else log_info ".env file already exists at $ENV_FILE."; fi

    log_info "7. Setting up systemd service '$SERVICE_NAME'..."
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    CONDA_RUN_EXEC_FOR_SERVICE="/home/$BOT_USER/miniconda3/bin/conda" 
    if command -v conda &>/dev/null && [ ! -x "$CONDA_RUN_EXEC_FOR_SERVICE" ]; then CONDA_RUN_EXEC_FOR_SERVICE="conda"; fi
    if [ ! -x "$CONDA_RUN_EXEC_FOR_SERVICE" ]; then log_fatal "Conda for service not found at $CONDA_RUN_EXEC_FOR_SERVICE or system path."; fi
    
    # Determine Python executable within conda env for systemd
    # This is safer than relying on just 'python' in conda run
    PYTHON_IN_CONDA_ENV="/home/$BOT_USER/miniconda3/envs/$CONDA_ENV_NAME/bin/python"
    if [ ! -x "$PYTHON_IN_CONDA_ENV" ]; then
        # Try to find it if system conda was used and env is elsewhere
        CONDA_ENV_PATH_OUTPUT=$(sudo -u "$BOT_USER" $CONDA_RUN_EXEC_FOR_SERVICE env list | grep "$CONDA_ENV_NAME" | awk '{print $NF}')
        if [ -n "$CONDA_ENV_PATH_OUTPUT" ] && [ -d "$CONDA_ENV_PATH_OUTPUT" ]; then
            PYTHON_IN_CONDA_ENV="$CONDA_ENV_PATH_OUTPUT/bin/python"
        else
            log_fatal "Could not determine Python path within Conda environment $CONDA_ENV_NAME for systemd."
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
# ExecStart needs to point to the python within the conda environment directly, or use conda run.
# Using full path to python in conda env is often more robust for systemd.
ExecStart=$PYTHON_IN_CONDA_ENV main.py
# Alternative using conda run (might need PATH setup for conda if not system-wide for root)
# ExecStart=$CONDA_RUN_EXEC_FOR_SERVICE run -n $CONDA_ENV_NAME --no-capture-output $PYTHON_EXECUTABLE main.py
Restart=on-failure
RestartSec=10s
Environment=\"PYTHONUNBUFFERED=1\"
# PATH for conda environment if 'conda run' is used and conda is user-local
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
# (Ensure these are adapted to use Conda environment activation or 'conda run')
# (Pasted from previous complete script, may need minor adjustments for Conda paths)
train_ai_model_interactive() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$BOT_USER_DEFAULT")}
    
    local conda_exec_for_train="/home/$current_bot_user/miniconda3/bin/conda"
    if command -v conda &>/dev/null && [ ! -x "$conda_exec_for_train" ]; then conda_exec_for_train="conda"; fi
    if [ ! -x "$conda_exec_for_train" ]; then log_error "Conda for training not found."; read -p "[Enter]..."; return; fi

    log_info "Training AI as '$current_bot_user' in '$current_install_dir' using Conda env '$CONDA_ENV_NAME'..."
    # Using sudo -u to execute a bash script snippet that activates conda and runs python
    if ! sudo -H -u "$current_bot_user" bash -c "
        set -e;
        cd '$current_install_dir';
        echo '[TRAIN_CONDA] Sourcing Conda environment for training...';
        # Try to source user's conda init
        if [ -f \"\$HOME/miniconda3/etc/profile.d/conda.sh\" ]; then
            source \"\$HOME/miniconda3/etc/profile.d/conda.sh\";
        elif [ -f \"/opt/conda/etc/profile.d/conda.sh\" ]; then # System conda path
             source \"/opt/conda/etc/profile.d/conda.sh\";
        else
            echo '[TRAIN_CONDA_WARN] Could not source conda.sh, relying on direct conda exec path.';
        fi
        # Using conda run is safer for non-interactive execution
        echo '[TRAIN_CONDA] Starting train_model.py in env $CONDA_ENV_NAME...';
        \"$conda_exec_for_train\" run -n \"$CONDA_ENV_NAME\" --no-capture-output python train_model.py;
        echo '[TRAIN_CONDA] train_model.py finished.';
    "
    then log_error "AI Training FAILED."; else log_success "AI Training COMPLETED."; fi
    read -p "Press [Enter]..."
}

# (manage_service, view_logs, display_status_snapshot, edit_env_file, perform_uninstall, main_menu, execution logic - as before)
# Make sure perform_uninstall also has the Miniconda removal option.
# The main_menu and its calls should be fine.

# --- [PASTE THE REST OF THE MANAGEMENT FUNCTIONS, MAIN_MENU, and SCRIPT EXECUTION LOGIC HERE] ---
# --- from the previous "uninstall" version of the script.                       ---
# --- Ensure paths and user variables are handled consistently.                   ---
manage_service() { local ACTION=$1; if [ -z "$INSTALL_DIR" ]; then INSTALL_DIR=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT"); fi; sudo systemctl $ACTION $SERVICE_NAME; log_info "Service action '$ACTION'. Status:"; sudo systemctl status $SERVICE_NAME --no-pager -n 10; read -p "Press [Enter]..."; }
view_logs() { sudo journalctl -u $SERVICE_NAME -f -n 100; read -p "Press [Enter]..."; }
display_status_snapshot() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "N/A")}
    local current_bot_user=${BOT_USER:-$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "N/A")}
    local conda_python_path_part="/envs/$CONDA_ENV_NAME/bin/python"
    print_divider; log_info "System Resource Snapshot:"; 
    echo "CPU Load (1m): $(uptime | awk -F'average: ' '{ print $2 }' | cut -d, -f1), RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}), Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"})"
    log_info "Service '$SERVICE_NAME' (User: $current_bot_user, Dir: $current_install_dir, Conda Env: $CONDA_ENV_NAME):"; sudo systemctl status $SERVICE_NAME --no-pager -n 5 || log_warning "No status."
    if pgrep -u "$current_bot_user" -f "$conda_python_path_part main.py" > /dev/null || pgrep -u "$current_bot_user" -f "conda run -n $CONDA_ENV_NAME .* python main.py" > /dev/null ; then log_success "Bot (Conda) process RUNNING."; else log_warning "Bot (Conda) process NOT RUNNING."; fi
    print_divider; read -p "Press [Enter]..."
}
edit_env_file() { 
    local current_install_dir=${INSTALL_DIR:-$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null || echo "$INSTALL_DIR_DEFAULT")}
    sudo nano "$current_install_dir/.env"; log_info ".env edit closed."; read -p "Press [Enter]..."
}
perform_uninstall() {
    set -e 
    log_warning "--- Starting Full Uninstall Process ---"
    local current_install_dir=${INSTALL_DIR}
    local current_bot_user=${BOT_USER}
    if [ -z "$current_install_dir" ] && [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then current_install_dir=$(grep -Po 'WorkingDirectory=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null); fi
    if [ -z "$current_bot_user" ] && [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then current_bot_user=$(grep -Po 'User=\K.*' "/etc/systemd/system/$SERVICE_NAME.service" 2>/dev/null); fi
    if [ -z "$current_install_dir" ]; then prompt_with_default "Install directory to remove" "$INSTALL_DIR_DEFAULT" current_install_dir; fi
    if [ -z "$current_bot_user" ]; then prompt_with_default "Bot username to remove" "$BOT_USER_DEFAULT" current_bot_user; fi
    if [ -z "$current_install_dir" ] || [ -z "$current_bot_user" ]; then log_error "Cannot determine dir/user. Aborting."; return 1; fi

    log_warning "Uninstalling User: '$current_bot_user', Dir: '$current_install_dir', Service: '$SERVICE_NAME', Conda Env: '$CONDA_ENV_NAME'"
    read -p "ARE YOU SURE? This is irreversible. (yes/NO): " CONFIRM_UNINSTALL
    if [[ "$CONFIRM_UNINSTALL" != "yes" ]]; then log_info "Uninstall aborted."; return; fi

    log_info "Stopping/disabling service '$SERVICE_NAME'..." # (Service removal as before)
    if systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then sudo systemctl stop "$SERVICE_NAME" || true; sudo systemctl disable "$SERVICE_NAME" || true; sudo rm -f "/etc/systemd/system/$SERVICE_NAME.service"; sudo rm -f "/etc/systemd/system/multi-user.target.wants/$SERVICE_NAME.service"; sudo systemctl daemon-reload; sudo systemctl reset-failed; log_success "Service removed."; else log_warning "Service not found."; fi
    log_info "Deleting project dir '$current_install_dir'..."; if [ -d "$current_install_dir" ]; then sudo rm -rf "$current_install_dir"; log_success "Project dir deleted."; else log_warning "Project dir not found."; fi
    
    # Conda environment removal (as bot user)
    local conda_exec_for_uninstall="/home/$current_bot_user/miniconda3/bin/conda"
    if command -v conda &>/dev/null && [ ! -x "$conda_exec_for_uninstall" ]; then conda_exec_for_uninstall="conda"; fi
    if [ -x "$conda_exec_for_uninstall" ]; then
        log_info "Removing Conda environment '$CONDA_ENV_NAME' for user '$current_bot_user'..."
        sudo -u "$current_bot_user" "$conda_exec_for_uninstall" env remove -n "$CONDA_ENV_NAME" -y || log_warning "Failed to remove Conda env $CONDA_ENV_NAME. May need manual removal or Miniconda uninstall."
    else
        log_warning "Conda executable not found, cannot remove Conda environment $CONDA_ENV_NAME automatically."
    fi

    log_info "Deleting user '$current_bot_user'..." # (User deletion as before)
    if id "$current_bot_user" &>/dev/null; then sudo pkill -u "$current_bot_user" || true; sudo userdel -r "$current_bot_user" || log_warning "userdel failed."; log_success "User '$current_bot_user' deleted."; else log_warning "User not found."; fi
    
    log_info "Checking for user-specific Miniconda installation for $current_bot_user..."
    if [ -d "/home/$current_bot_user/miniconda3" ]; then
        read -p "Miniconda found at /home/$current_bot_user/miniconda3. Remove it? (yes/NO): " RM_CONDA
        if [[ "$RM_CONDA" == "yes" ]]; then sudo rm -rf "/home/$current_bot_user/miniconda3"; log_success "Removed Miniconda for $current_bot_user."; else log_info "Skipped Miniconda removal."; fi
    fi
    INSTALL_DIR=""; BOT_USER="" 
    set +e; log_success "--- Full Uninstall Complete ---"; read -p "Press [Enter]..."
}

main_menu() {
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