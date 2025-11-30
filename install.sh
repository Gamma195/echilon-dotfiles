#!/bin/bash

# --- Configuration ---
REPO_NAME="echilon-dotfiles"
REPO_URL="https://github.com/Gamma195/$REPO_NAME.git"
INSTALL_DIR="$HOME/Source/$REPO_NAME"
CONFIG_DIR="$HOME/.config"

# --- Unified Package List (Installed via yay) ---
# Includes official repository packages (Hyprland, Kitty, Fish, etc.)
# and AUR packages (noctalia-shell-git, missioncenter, etc.).
ALL_PACKAGES=(
    hyprland hyprctl rofi nemo vivaldi code
    grim slurp wayland-protocols wget imagemagick
    fish starship kitty fastfetch
    noctalia-shell-git missioncenter yt-dlp warehouse
    linux-wallpaperengine-git upscaler video-downloader
)

# List of configuration directories/files to back up and link
CONFIG_TARGETS=(
    "hypr"
    "rofi"
    "kitty"
    "fish"
    "starship"
    "fastfetch"
)

# --- Functions ---

# Function to prompt the user with choices
user_choice() {
    local prompt_message="$1"
    local default_action="${2:-P}" # P=Proceed, S=Skip, E=Exit

    echo -e "\n========================================================================="
    echo -e "$prompt_message"
    echo -e "-------------------------------------------------------------------------"
    echo -e "Choices: (P) Proceed | (S) Skip this step | (E) Exit the script"
    read -r -p "Enter your choice [${default_action}]: " response
    response=${response:-$default_action} # Use default if empty
    RESPONSE_UCASE=$(echo "$response" | tr '[:lower:]' '[:upper:]')
    echo "========================================================================="

    case "$RESPONSE_UCASE" in
        P) return 0 ;; # Proceed
        S) return 1 ;; # Skip
        E) echo "Script terminated by user. Exiting." ; exit 0 ;;
        *) echo "Invalid choice. Please try again." ; user_choice "$1" "$2" ;;
    esac
}

# Check for and install yay (AUR helper)
check_and_install_yay() {
    if ! command -v yay &> /dev/null; then
        echo "Yay (AUR helper) not found. This is required for installation."
        echo "Installing prerequisite packages: base-devel and git."
        sudo pacman -S --noconfirm base-devel git

        echo "Cloning and building yay. You may be prompted for your password."
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        rm -rf /tmp/yay

        if command -v yay &> /dev/null; then
            echo "SUCCESS: Yay installed successfully."
        else
            echo "ERROR: Failed to install yay. Cannot proceed with package installation. Exiting."
            exit 1
        fi
    else
        echo "Yay is already installed. Skipping yay installation check."
    fi
}

# Install necessary packages using yay
install_packages() {
    local message="--- STEP 1: INSTALLING ALL REQUIRED PACKAGES ---\n"
    message+="This step will install all system packages needed for Hyprland and all accompanying tools (Kitty, Rofi, Fish, etc.) using 'yay'.\n"
    message+="This includes both official Arch packages and AUR packages. You may be prompted for your password multiple times."

    if user_choice "$message"; then
        check_and_install_yay # Ensure yay is available before trying to use it

        echo "Executing: yay -Syu --noconfirm ${ALL_PACKAGES[@]}"
        yay -Syu --noconfirm "${ALL_PACKAGES[@]}"

        echo "SUCCESS: All packages installed."
    else
        echo "Skipping package installation (Step 1)."
    fi
}

# Deploy dotfiles, creating backups of existing files
deploy_dots() {
    local message="--- STEP 2: DEPLOYING DOTFILES (CREATING BACKUPS) ---\n"
    message+="This step will clone the configuration files from the repository ($REPO_URL).\n"
    message+="If any existing configuration folders (e.g., ~/.config/hypr) are found, they will be backed up by renaming them with a timestamp (e.g., ~/.config/hypr.bak.YYYYMMDD).\n"
    message+="New symbolic links will be created, pointing to the cloned repository files."

    if user_choice "$message"; then

        echo "--- Executing Deployment ---"

        # Clone the repository
        if [ -d "$INSTALL_DIR" ]; then
            echo "Repository already cloned at $INSTALL_DIR. Skipping clone."
        else
            echo "Cloning $REPO_URL to $INSTALL_DIR..."
            git clone "$REPO_URL" "$INSTALL_DIR"
        fi

        # Create symlinks and backups
        for target in "${CONFIG_TARGETS[@]}"; do
            FULL_PATH="$CONFIG_DIR/$target"

            # CRITICAL: If the target exists (is a file or directory), back it up.
            if [ -d "$FULL_PATH" ] || [ -f "$FULL_PATH" ] || [ -L "$FULL_PATH" ]; then
                # Create a timestamped backup
                TIMESTAMP=$(date +%Y%m%d%H%M%S)
                BACKUP_NAME="$target.bak.$TIMESTAMP"

                echo "-> Backing up existing $target to $BACKUP_NAME"
                mv "$FULL_PATH" "$CONFIG_DIR/$BACKUP_NAME"
            fi

            # Create the new symbolic link
            echo "-> Creating symlink for $target: $INSTALL_DIR/.config/$target -> $FULL_PATH"
            ln -s "$INSTALL_DIR/.config/$target" "$FULL_PATH"
        done

        echo "SUCCESS: Dotfiles deployed. Original configurations backed up in $CONFIG_DIR."
    else
        echo "Skipping dotfiles deployment (Step 2)."
    fi
}

# Final permission adjustments
set_permissions() {
    local message="--- STEP 3: SETTING SCRIPT PERMISSIONS ---\n"
    message+="This step ensures necessary scripts, like the Hyprland keyhints and startup scripts, have executable permissions (chmod +x) to function correctly."

    if user_choice "$message"; then

        echo "--- Executing Permission Setup ---"
        # Set execution permissions for Hyprland scripts
        chmod +x "$CONFIG_DIR/hypr/Scripts/keyhints"
        chmod +x "$CONFIG_DIR/hypr/Scripts/show-keyhints.sh"

        echo "SUCCESS: Script permissions set."
    else
        echo "Skipping permission setup (Step 3)."
    fi
}


# --- Main Execution ---

echo "=========================================="
echo " Starting Interactive Hyprland Dotfiles Installation "
echo "=========================================="

# 1. Install all packages via yay
install_packages

# 2. Deploy dotfiles and set up symlinks
deploy_dots

# 3. Set script permissions
set_permissions

echo "=========================================="
echo "Installation Complete!"
echo "All selected steps are finished. Please follow the final steps:"
echo "1. Reboot or log out and select the Hyprland session."
echo "2. Remember to check your monitor settings and theming notes in the configurations!"
