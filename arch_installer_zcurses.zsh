#!/usr/bin/env zsh

# Ensure the script is run with zsh
if [ -z "$ZSH_VERSION" ]; then
  echo "This script must be run with zsh."
  exit 1
fi

emulate -LR zsh
setopt extended_glob warn_create_global errexit pipefail nounset

# Source the TUI library
# Assuming the script is run from the root of the repository
if [[ -f "./libs/zcurses_tui.zsh" ]]; then
    source "./libs/zcurses_tui.zsh"
else
    print -u2 "Error: zcurses_tui.sh not found in ./libs/"
    exit 1
fi

# --- Global Variables & Configuration ---
SCRIPT_CONFIG="./installer.conf"
SCRIPT_LOG="./installer.log"
SCRIPT_VERSION="0.1.0-zcurses" # Placeholder version

# Temporary files (can be refined)
ERROR_MSG_FILE=$(mktemp) # For capturing error messages for display
LAST_ERROR_INFO_FILE=$(mktemp) # For trap_error details

# Color Definitions (Primarily for logging, TUI will use its own mechanisms)
# These are kept for direct porting of logging functions.
# zcurses functions themselves don't use these directly yet.
COLOR_NC='\033[0m'
COLOR_BLACK='\033[0;30m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[0;37m'
COLOR_ORANGE='\033[0;91m' # Changed from just 91 to 0;91 for consistency
# Bold
COLOR_BOLD_BLACK='\033[1;30m'
COLOR_BOLD_RED='\033[1;31m'
COLOR_BOLD_GREEN='\033[1;32m'
COLOR_BOLD_YELLOW='\033[1;33m'
COLOR_BOLD_BLUE='\033[1;34m'
COLOR_BOLD_PURPLE='\033[1;35m'
COLOR_BOLD_CYAN='\033[1;36m'
COLOR_BOLD_WHITE='\033[1;37m'
# Background
COLOR_BG_BLACK='\033[40m'
COLOR_BG_RED='\033[41m'
COLOR_BG_GREEN='\033[42m'
COLOR_BG_YELLOW='\033[43m'
COLOR_BG_BLUE='\033[44m'
COLOR_BG_PURPLE='\033[45m'
COLOR_BG_CYAN='\033[46m'
COLOR_BG_WHITE='\033[47m'

# --- Trap Functions ---
trap_exit() {
    local exit_status=$?
    # Ensure cleanup_zcurses is called if curses was initialized
    # Need a flag to check if init_zcurses was successful.
    # For now, call it unconditionally, it should be safe.
    cleanup_zcurses
    
    # Restore terminal state if modified by zcurses (though cleanup_zcurses should handle most)
    stty sane # Restore sensible terminal settings

    if [[ $exit_status -ne 0 ]]; then
        # Log last error details if available
        if [[ -f "$LAST_ERROR_INFO_FILE" ]] && [[ -s "$LAST_ERROR_INFO_FILE" ]]; then
            log_fail "Installer exited with error $exit_status. Last error context:"
            cat "$LAST_ERROR_INFO_FILE" >> "$SCRIPT_LOG"
            # Display error in TUI if possible, or just print
            # zcurses_fail "Installer exited with error $exit_status. See log for details."
            # zcurses_pager "$LAST_ERROR_INFO_FILE" # Or simple cat
        else
            log_fail "Installer exited with error $exit_status."
            # zcurses_fail "Installer exited with error $exit_status."
        fi
    else
        log_info "Installer exited successfully."
        # zcurses_info "Installation process finished."
    fi
    
    # Clean up temporary files
    rm -f "$ERROR_MSG_FILE" "$LAST_ERROR_INFO_FILE"
    
    print "\n${COLOR_BOLD_GREEN}Log file available at: ${SCRIPT_LOG}${COLOR_NC}"
    exit $exit_status
}

trap_error() {
    local func_name="$1"
    local line_no="$2"
    local error_message="${3:-"Unknown error"}" # Zsh specific way to get error message might be needed
    
    # Capture error information for trap_exit to use
    print "Error in function '$func_name' at line $line_no: $error_message" > "$LAST_ERROR_INFO_FILE"
    
    # Minimal TUI interaction within trap_error to avoid complexity/recursion
    # cleanup_zcurses # Potentially risky here, might interfere with trap_exit
    # zcurses_fail "Critical error in $func_name:$line_no. Exiting."
    # sleep 3 # Give user time to see message if TUI is still up

    # Let trap_exit handle the final cleanup and logging
    # The 'exit' command here will trigger trap_exit
}

# Setup traps
# trap 'trap_exit' EXIT # EXIT trap will be set in main after init_zcurses
# trap 'trap_error \${funcstack[1]} \${LINENO} "$?"' ERR # ERR trap as well

# --- Logging Functions (Simplified) ---
# Usage: write_log <level> <message>
write_log() {
    local level="$1"
    local message="$2"
    local datetime=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$datetime] [$level] $message" >> "$SCRIPT_LOG"
}

log_info() { write_log "INFO" "$1"; }
log_warn() { write_log "WARN" "$1"; }
log_fail() { write_log "FAIL" "$1"; }
log_head() { # For major sections in the log
    write_log "HEAD" "============================================================"
    write_log "HEAD" "$1"
    write_log "HEAD" "============================================================"
}
log_proc() { write_log "PROC" "$1"; } # For process steps/commands
log_prop() { write_log "PROP" "$1: $2"; } # For properties set

# --- TUI Helper Functions ---
print_header() {
    local title="$1"
    # This function might evolve to draw a more complex header.
    # For now, using zcurses_title or simple zcurses commands.
    # Clear screen or specific area if needed before drawing.
    # zcurses clear stdscr # If you want to clear the whole screen
    # For now, zcurses_title will print on a new line.
    # If zcurses_title is not available or doesn't fit, use direct zcurses:
    zcurses move stdscr 1 1 # Move to top-left
    zcurses clrtoeol stdscr
    zcurses attr stdscr "bold" # Example for bold
    zcurses string stdscr "$title"
    zcurses attr stdscr "normal"
    zcurses refresh stdscr
    # Or simply:
    # zcurses_title "$title" # Assuming zcurses_title handles positioning and clearing.
}

# --- Properties Functions ---
properties_generate() {
    log_head "Generating Default Properties File"
    cat > "$SCRIPT_CONFIG" <<-EOF
ARCH_OS_USERNAME=""
ARCH_OS_PASSWORD=""
ARCH_OS_HOSTNAME=""
ARCH_OS_SHELL="/bin/zsh"
ARCH_OS_TIMEZONE="UTC"
ARCH_OS_LOCALE="en_US.UTF-8"
ARCH_OS_KEYMAP="us"
ARCH_OS_SWAP_SIZE="2G"
ARCH_OS_INSTALL_TYPE="FULL"
ARCH_OS_DESKTOP_ENVIRONMENT="gnome"
ARCH_OS_ADDITIONAL_PACKAGES=""
ARCH_OS_AUR_HELPER="yay"
ARCH_OS_DOTFILES_REPO=""
ARCH_OS_EFI_PARTITION=""
ARCH_OS_ROOT_PARTITION=""
ARCH_OS_BOOT_LOADER="grub"
ARCH_OS_DISK_ENCRYPTION="0"
ARCH_OS_ENCRYPTION_PASSWORD=""
EOF
    log_info "Default properties file '$SCRIPT_CONFIG' generated."
    # zcurses_info "Default configuration file generated." # Optional TUI feedback
}

properties_source() {
    if [[ -f "$SCRIPT_CONFIG" ]]; then
        log_info "Sourcing properties from '$SCRIPT_CONFIG'."
        # set -a # Export all variables defined from now on
        source "$SCRIPT_CONFIG"
        # set +a # Stop exporting
        # zcurses_info "Configuration sourced from '$SCRIPT_CONFIG'." # Optional
        return 0
    else
        log_warn "Properties file '$SCRIPT_CONFIG' not found. Cannot source."
        # zcurses_warn "Configuration file not found. Cannot source." # Optional
        return 1
    fi
}

properties_preset_source() {
    log_head "Choosing Setup Preset"
    local options=("Exit to Main Menu")
    local preset_dir="./presets" # Assuming presets are in a 'presets' subdirectory
    
    if [[ -d "$preset_dir" ]]; then
        options+=($(find "$preset_dir" -maxdepth 1 -type f -name "*.conf" -printf "%f\n" | sed 's/\.conf$//'))
    else
        log_warn "Preset directory '$preset_dir' not found."
    fi

    if (( ${#options[@]} == 1 )); then # Only "Exit to Main Menu"
        zcurses_warn "No preset configuration files found in '$preset_dir'."
        log_warn "No preset files found."
        # trap_gum_exit_confirm # This would be a return 1 in zcurses context
        return 1 # Indicate no choice made or error
    fi

    zcurses_choose "+ Choose Setup Preset" "${options[@]}"
    local choice_rc=$?
    local preset_choice_name=$(cat "$REPLY") # zcurses_choose writes to $REPLY

    if (( choice_rc == 130 )); then # User cancelled
        log_info "User cancelled preset selection."
        return 1 # Propagate cancellation
    fi

    if [[ "$preset_choice_name" == "Exit to Main Menu" ]]; then
        log_info "User chose to exit to main menu from preset selection."
        return 1 # Or a specific code indicating exit to menu
    fi

    if [[ -n "$preset_choice_name" ]]; then
        local preset_file_path="$preset_dir/$preset_choice_name.conf"
        if [[ -f "$preset_file_path" ]]; then
            cp "$preset_file_path" "$SCRIPT_CONFIG"
            log_info "Preset '$preset_choice_name' loaded from '$preset_file_path' to '$SCRIPT_CONFIG'."
            zcurses_info "Setup preset loaded from: $preset_choice_name.conf"
            
            # Source the newly copied config
            properties_source
            return $?
        else
            log_warn "Chosen preset file '$preset_file_path' not found (this shouldn't happen)."
            zcurses_warn "Error: Selected preset file not found."
            return 1
        fi
    else
        log_warn "No preset chosen or invalid choice."
        # This case might not be reachable with zcurses_choose if it always returns a selection or cancels.
        return 1
    fi
}

# --- User Setup Functions ---
select_username() {
    log_head "Selecting Username"
    local current_username="${ARCH_OS_USERNAME:-}" # Use existing if set, else empty
    
    zcurses_input "+ Enter Username" "$current_username"
    local input_rc=$?
    local username_input=$(cat "$REPLY")

    if (( input_rc == 130 )); then # User cancelled
        log_warn "Username selection cancelled by user."
        return 1 # Propagate cancellation
    fi

    if [[ -z "$username_input" ]]; then
        zcurses_warn "Username cannot be empty."
        log_warn "Attempted to set empty username."
        return 1
    fi

    # Validate username (simple validation)
    if ! [[ "$username_input" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        zcurses_warn "Invalid username format."
        log_warn "Invalid username format: $username_input"
        return 1
    fi

    ARCH_OS_USERNAME="$username_input"
    log_prop "Username" "$ARCH_OS_USERNAME"
    zcurses_info "Username set to: $ARCH_OS_USERNAME"
    return 0
}

select_password() {
    log_head "Selecting Password"
    local password_1 password_2

    while true; do
        zcurses_input "+ Enter Password" "" # No default value for password input
        local input_rc1=$?
        password_1=$(cat "$REPLY")

        if (( input_rc1 == 130 )); then
            log_warn "Password selection cancelled by user (first input)."
            return 1
        fi
        
        if [[ -z "$password_1" ]]; then
            zcurses_warn "Password cannot be empty."
            log_warn "Attempted to set empty password."
            # No return 1 here, loop will restart
            continue 
        fi

        zcurses_input "+ Confirm Password" ""
        local input_rc2=$?
        password_2=$(cat "$REPLY")

        if (( input_rc2 == 130 )); then
            log_warn "Password selection cancelled by user (confirmation input)."
            return 1
        fi

        if [[ "$password_1" == "$password_2" ]]; then
            ARCH_OS_PASSWORD="$password_1"
            log_prop "Password" "*******" # Log obfuscated password
            zcurses_info "Password successfully set."
            return 0
        else
            zcurses_warn "Passwords do not match. Please try again."
            log_warn "Password mismatch during confirmation."
            # Loop will continue
        fi
    done
}

# --- Locale and Disk Setup Functions ---

select_timezone() {
    log_head "Selecting Timezone"
    local tz_auto current_timezone zones_array user_input
    
    # Auto-detect timezone
    # Ensure curl is available, if not, skip auto-detection
    if command -v curl &>/dev/null; then
        tz_auto=$(curl -s http://ip-api.com/line?fields=timezone)
        log_info "Auto-detected timezone: $tz_auto"
    else
        tz_auto=""
        log_warn "curl is not installed. Cannot auto-detect timezone."
    fi

    current_timezone="${ARCH_OS_TIMEZONE:-$tz_auto}"
    current_timezone="${current_timezone:-"UTC"}" # Default to UTC if still empty

    while true; do
        zcurses_input "+ Enter Timezone (auto-detected: $tz_auto)" "$current_timezone"
        local input_rc=$?
        user_input=$(cat "$REPLY")

        if (( input_rc == 130 )); then # User cancelled
            log_warn "Timezone selection cancelled by user."
            return 1
        fi

        if [[ -z "$user_input" ]]; then
            zcurses_warn "Timezone cannot be empty."
            log_warn "Attempted to set empty timezone."
            continue
        fi
        
        # Validate timezone (check if file exists in /usr/share/zoneinfo)
        # This is a basic check. A more robust check might involve `timedatectl list-timezones`.
        if [[ -f "/usr/share/zoneinfo/$user_input" ]]; then
            ARCH_OS_TIMEZONE="$user_input"
            log_prop "Timezone" "$ARCH_OS_TIMEZONE"
            zcurses_info "Timezone set to: $ARCH_OS_TIMEZONE"
            return 0
        else
            zcurses_confirm "Timezone '${user_input}' is not valid or not found. Continue anyway?"
            if (( $? == 0 )); then # User chose to continue with potentially invalid input
                 ARCH_OS_TIMEZONE="$user_input"
                 log_warn "User opted to use potentially invalid timezone: $ARCH_OS_TIMEZONE"
                 zcurses_warn "Using timezone: $ARCH_OS_TIMEZONE (validation failed)"
                 return 0
            fi
            # If user does not confirm, loop continues to ask for input again.
            log_warn "Invalid timezone rejected by user: $user_input"
        fi
    done
}

select_language() {
    log_head "Selecting Language (Locale)"
    local options=() current_locale_lang locale_choice_name
    local locale_gen_file="/etc/locale.gen" # Standard path for locale.gen

    # Fetch available locales (simplified: using common ones if system files are not accessible in non-Arch env)
    # In a real Arch environment, parse /etc/locale.gen or /usr/share/i18n/locales
    # For this script, we'll use a predefined list and allow manual input.
    # Or, if locale.gen exists, try to parse it.
    if [[ -f "$locale_gen_file" ]]; then
        # Extract uncommented locales from locale.gen (simple version)
        # Format is usually "en_US.UTF-8 UTF-8" or just "en_US.UTF-8"
        options=($(awk '!/^#/ && NF > 0 {print $1}' "$locale_gen_file" | sort -u))
        if (( ${#options[@]} == 0 )); then # Fallback if parsing failed or file is empty/all commented
            log_warn "Could not parse any active locales from $locale_gen_file. Using fallback list."
            options=("en_US.UTF-8" "en_GB.UTF-8" "de_DE.UTF-8" "fr_FR.UTF-8" "es_ES.UTF-8" "C.UTF-8")
        fi
    else
        log_warn "$locale_gen_file not found. Using a fallback list of common locales."
        options=("en_US.UTF-8" "en_GB.UTF-8" "de_DE.UTF-8" "fr_FR.UTF-8" "es_ES.UTF-8" "C.UTF-8")
    fi
    
    options+=("Enter manually...") # Allow manual input

    current_locale_lang="${ARCH_OS_LOCALE:-"en_US.UTF-8"}"

    # zcurses_filter does not support pre-fill. We can use zcurses_choose or have user type.
    # For now, using zcurses_choose as it's simpler than a filter if no pre-fill.
    # Or, let user type in zcurses_input if list is too long for zcurses_choose.
    # Let's try zcurses_filter and user can type to narrow down.
    
    zcurses_filter "+ Choose Language/Locale (or type to filter)" "${options[@]}"
    local filter_rc=$?
    locale_choice_name=$(cat "$REPLY")

    if (( filter_rc == 130 )); then # User cancelled
        log_warn "Language selection cancelled by user."
        return 1
    fi

    if [[ "$locale_choice_name" == "Enter manually..." ]]; then
        zcurses_input "+ Enter Locale Manually (e.g., en_US.UTF-8)" "$current_locale_lang"
        local manual_rc=$?
        locale_choice_name=$(cat "$REPLY")
        if (( manual_rc == 130 )); then
            log_warn "Manual language entry cancelled."
            return 1
        fi
        if [[ -z "$locale_choice_name" ]]; then
            zcurses_warn "Locale cannot be empty."
            return 1
        fi
    fi
    
    if [[ -z "$locale_choice_name" ]]; then # Should not happen if filter returns something or manual input is validated
        log_warn "No language/locale selected."
        return 1
    fi

    ARCH_OS_LOCALE="$locale_choice_name"
    # Extract language part for some settings if needed (e.g., en from en_US.UTF-8)
    ARCH_OS_LOCALE_LANG="${ARCH_OS_LOCALE%%.*}" 
    ARCH_OS_LOCALE_LANG="${ARCH_OS_LOCALE_LANG%%@*}"
    # ARCH_OS_LOCALE_GEN_LIST will be a list of locales to uncomment in /etc/locale.gen
    # For simplicity, we often just add the chosen one and perhaps a common UTF-8 English one.
    ARCH_OS_LOCALE_GEN_LIST=("${ARCH_OS_LOCALE}" "en_US.UTF-8") # Ensure en_US.UTF-8 is often available
    # Remove duplicates if any
    typeset -U ARCH_OS_LOCALE_GEN_LIST

    log_prop "Locale" "$ARCH_OS_LOCALE"
    log_prop "Language (derived)" "$ARCH_OS_LOCALE_LANG"
    log_prop "Locales to generate" "${ARCH_OS_LOCALE_GEN_LIST[*]}"
    zcurses_info "Language/Locale set to: $ARCH_OS_LOCALE"
    return 0
}

select_keyboard() {
    log_head "Selecting Keyboard Layout"
    local options=() keymap_choice_name current_keymap
    
    # Get available keymaps
    if command -v localectl &>/dev/null; then
        # Use try-catch block for system commands that might fail
        { options=($(localectl list-keymaps)) } 2>/dev/null || {
            log_warn "localectl list-keymaps failed. Using fallback list."
        }
    fi
    if (( ${#options[@]} == 0 )); then
        log_warn "Could not retrieve keymaps via localectl. Using common fallback list."
        options=("us" "uk" "de" "fr" "es") # Common keymaps
    fi
    options+=("Enter manually...")

    current_keymap="${ARCH_OS_KEYMAP:-"us"}"

    zcurses_filter "+ Choose Keyboard Layout (or type to filter)" "${options[@]}"
    local filter_rc=$?
    keymap_choice_name=$(cat "$REPLY")

    if (( filter_rc == 130 )); then
        log_warn "Keyboard layout selection cancelled."
        return 1
    fi

    if [[ "$keymap_choice_name" == "Enter manually..." ]]; then
        zcurses_input "+ Enter Keyboard Layout Manually" "$current_keymap"
        local manual_rc=$?
        keymap_choice_name=$(cat "$REPLY")
        if (( manual_rc == 130 )); then
            log_warn "Manual keyboard layout entry cancelled."
            return 1
        fi
         if [[ -z "$keymap_choice_name" ]]; then
            zcurses_warn "Keyboard layout cannot be empty."
            return 1
        fi
    fi
    
    if [[ -z "$keymap_choice_name" ]]; then
        log_warn "No keyboard layout selected."
        return 1
    fi

    ARCH_OS_KEYMAP="$keymap_choice_name"
    # For vconsole, this is usually the same. Some systems differentiate X11 and console.
    ARCH_OS_VCONSOLE_KEYMAP="$ARCH_OS_KEYMAP" 
    ARCH_OS_X11_KEYMAP="$ARCH_OS_KEYMAP"

    log_prop "Keyboard Layout (Console)" "$ARCH_OS_VCONSOLE_KEYMAP"
    log_prop "Keyboard Layout (X11)" "$ARCH_OS_X11_KEYMAP"
    zcurses_info "Keyboard layout set to: $ARCH_OS_KEYMAP"
    return 0
}

select_disk() {
    log_head "Selecting Target Disk"
    local disks_raw disks_array options=() disk_choice_name disk_choice_path
    
    # List block devices, filtering for common disk types (sd, hd, vd, nvme, xvd)
    # lsblk -I 8,259,254 filters for typical disk major numbers.
    # -d for disks only (no partitions), -o KNAME,SIZE for name and size, -n for no headers.
    disks_raw=$(lsblk -I 8,259,254,7 -d -o KNAME,SIZE -n 2>/dev/null || echo "")
    if [[ -z "$disks_raw" ]]; then
        log_warn "Could not list disks using lsblk."
        zcurses_warn "Could not list available disks. Check system or permissions."
        # Attempt to provide manual entry as a last resort
        zcurses_input "+ Enter target disk path MANUALLY (e.g., /dev/sda)" ""
        local manual_rc=$?
        disk_choice_path=$(cat "$REPLY")
        if (( manual_rc == 130 )) || [[ -z "$disk_choice_path" ]]; then
            log_fail "Disk selection cancelled or empty during manual fallback."
            return 1
        fi
        # Basic validation for /dev/ prefix
        if ! [[ "$disk_choice_path" =~ ^/dev/.* ]]; then
            zcurses_warn "Invalid disk path. Must start with /dev/."
            return 1
        fi
        # No further validation here, user is on their own with manual entry
        ARCH_OS_DISK="$disk_choice_path"
    else
        # Process lsblk output into an array for zcurses_choose
        local line kname size
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                # Extract KNAME and SIZE. Assuming KNAME is first, SIZE is second.
                kname=$(echo "$line" | awk '{print $1}')
                size=$(echo "$line" | awk '{print $2}')
                options+=("/dev/$kname ($size)")
            fi
        done <<< "$disks_raw"

        if (( ${#options[@]} == 0 )); then
            log_warn "No suitable disks found by lsblk."
            zcurses_warn "No disks found. Please check your system."
            return 1
        fi
        options+=("Enter manually...")

        zcurses_choose "+ Choose Target Disk for Installation" "${options[@]}"
        local choice_rc=$?
        disk_choice_name=$(cat "$REPLY") # e.g., "/dev/sda (100G)" or "Enter manually..."

        if (( choice_rc == 130 )); then
            log_warn "Disk selection cancelled."
            return 1
        fi
        
        if [[ "$disk_choice_name" == "Enter manually..." ]]; then
            zcurses_input "+ Enter target disk path MANUALLY (e.g., /dev/sda)" "${ARCH_OS_DISK:-/dev/sda}"
            local manual_rc_disk=$?
            disk_choice_path=$(cat "$REPLY")
            if (( manual_rc_disk == 130 )) || [[ -z "$disk_choice_path" ]]; then
                log_fail "Disk selection cancelled or empty during manual input."
                return 1
            fi
            if ! [[ "$disk_choice_path" =~ ^/dev/.* ]]; then
                zcurses_warn "Invalid disk path. Must start with /dev/."
                return 1
            fi
            ARCH_OS_DISK="$disk_choice_path"
        elif [[ -n "$disk_choice_name" ]]; then
            # Extract the path like /dev/sda from "/dev/sda (100G)"
            ARCH_OS_DISK="${${disk_choice_name%% (*)}%% }"
        else
            log_warn "No disk selected."
            return 1 # Should not happen if zcurses_choose works as expected
        fi
    fi

    # Set default partition names based on disk type
    if [[ "$ARCH_OS_DISK" == *"nvme"* ]]; then
        ARCH_OS_EFI_PARTITION="${ARCH_OS_DISK}p1"
        ARCH_OS_ROOT_PARTITION="${ARCH_OS_DISK}p2"
    else
        ARCH_OS_EFI_PARTITION="${ARCH_OS_DISK}1"
        ARCH_OS_ROOT_PARTITION="${ARCH_OS_DISK}2"
    fi

    log_prop "Target Disk" "$ARCH_OS_DISK"
    log_prop "EFI Partition (default)" "$ARCH_OS_EFI_PARTITION"
    log_prop "Root Partition (default)" "$ARCH_OS_ROOT_PARTITION"
    zcurses_info "Target disk set to: $ARCH_OS_DISK"
    zcurses_info "Default EFI partition: $ARCH_OS_EFI_PARTITION"
    zcurses_info "Default Root partition: $ARCH_OS_ROOT_PARTITION"
    return 0
}


# --- Main Function ---
main() {
    # Move old log file
    if [[ -f "$SCRIPT_LOG" ]]; then
        mv "$SCRIPT_LOG" "${SCRIPT_LOG}.old" 2>/dev/null || true
    fi
    log_head "Arch OS Installer Zcurses Initializing"
    log_info "Version: $SCRIPT_VERSION"
    log_info "Log file: $SCRIPT_LOG"
    log_info "Config file: $SCRIPT_CONFIG"

    # Initialize zcurses TUI
    init_zcurses
    # Set traps after TUI initialization, so they can use TUI if needed (carefully)
    trap 'trap_exit' EXIT
    trap 'trap_error "${funcstack[1]}" "${LINENO}" "$?"' ERR


    # Main application loop (scaffolding)
    while true; do
        # Clear screen before drawing main interface
        zcurses erase stdscr # or clear
        
        print_header "Arch OS Installer Zcurses - Version $SCRIPT_VERSION"

        zcurses_info "Welcome to the Arch Linux Zcurses Installer."
        zcurses_info "Please ensure you have backed up any important data."
        zcurses_info "A stable internet connection is recommended."
        # zcurses_info will move cursor to next line. Add a small delay or wait for key.
        # zcurses_info "Press any key to continue..."
        # local dummy_key
        # zcurses input stdscr dummy_key # Or getch if available directly

        if [[ -f "$SCRIPT_CONFIG" ]]; then
            zcurses_confirm "Load existing configuration from '$SCRIPT_CONFIG'?"
            local load_config_choice=$?
            if (( load_config_choice == 0 )); then # Yes
                log_info "User chose to load existing config '$SCRIPT_CONFIG'."
                zcurses_info "Existing configuration loaded."
                # source "$SCRIPT_CONFIG" # This would be done later, after properties are defined
            elif (( load_config_choice == 1 )); then # No
                log_info "User chose not to load existing config '$SCRIPT_CONFIG'."
                zcurses_confirm "Remove existing configuration file '$SCRIPT_CONFIG'?"
                local remove_config_choice=$?
                if (( remove_config_choice == 0 )); then # Yes to remove
                    rm -f "$SCRIPT_CONFIG"
                    log_info "Existing config '$SCRIPT_CONFIG' removed by user."
                    zcurses_info "Configuration file '$SCRIPT_CONFIG' removed."
                else # No to remove
                    log_info "User chose to keep existing config '$SCRIPT_CONFIG' (but not load it now)."
                    zcurses_warn "Existing configuration file '$SCRIPT_CONFIG' kept but not loaded for this session."
                fi
            else # User pressed 'q' or Esc during confirm
                log_info "User cancelled loading/removing config. Exiting."
                zcurses_warn "Configuration decision cancelled. Exiting installer."
                # cleanup_zcurses # trap_exit will handle this
                return 1 # Exit main loop and script
            fi
        else
            log_info "No existing config file found at '$SCRIPT_CONFIG'."
            zcurses_info "No existing configuration file found. Starting fresh."
        fi
        
        # Placeholder for further steps - to be implemented in next subtasks
        zcurses_info "Press 'Enter' to proceed to next step (not implemented yet) or 'q' to quit."
        local next_step_key
        zcurses input stdscr next_step_key # Using zcurses input for a single key
                                          # This will need to be adapted for actual char input.
                                          # `zcurses input -k var` is better for key codes.
        if [[ "$next_step_key" == "q" ]] || [[ "$next_step_key" == "Q" ]]; then
             log_info "User chose to quit at placeholder step."
             # break # Exit main loop
        fi
        # For now, just loop once for this subtask
        # break # Comment out to allow proceeding

        # --- Property Presets ---
        print_header "Property Presets"
        zcurses_info "You can load a preset configuration or proceed with defaults/manual setup."
        until properties_preset_source; do
            local preset_choice_rc=$?
            if (( preset_choice_rc != 0 )); then # Assuming 0 is success, 1 might mean "Exit to Main Menu" or actual error
                zcurses_confirm "Return to the main menu (or previous step)?"
                if (( $? == 0 )); then
                    # This logic needs to be refined based on how main menu will work.
                    # For now, if they confirm, we might just re-run the preset selection
                    # or break this part of the loop.
                    # Let's assume for now "Exit to Main Menu" from preset selection means try again or skip.
                    zcurses_info "Preset selection skipped or failed. Continuing with current/default settings."
                    break # Break the until loop for presets
                fi
                # If they don't confirm, the until loop continues
                 zcurses_warn "Please select a preset or choose 'Exit to Main Menu'."
            fi
        done
        log_info "Preset selection process completed."

        # --- Core Setup ---
        print_header "Core Setup"
        zcurses_title "Core System Configuration" # Using zcurses_title for subsection

        until select_username; do
            # If select_username returns 1 (cancel/fail), this loop continues.
            # trap_gum_exit_confirm behavior is effectively "try again or quit current operation"
            zcurses_confirm "Username setup failed or was cancelled. Try again?"
            if (( $? != 0 )); then # User chose No or cancelled confirm
                log_warn "User chose not to retry username setup. Exiting installer."
                zcurses_fail "Username setup is required. Exiting."
                return 1 # Exit main function, triggers trap_exit
            fi
        done
        log_info "Username selection completed."

        until select_password; do
            zcurses_confirm "Password setup failed or was cancelled. Try again?"
            if (( $? != 0 )); then
                log_warn "User chose not to retry password setup. Exiting installer."
                zcurses_fail "Password setup is required. Exiting."
                return 1 # Exit main function
            fi
        done
        log_info "Password selection completed."

        # Placeholder for next steps
        zcurses_info "Core setup finished. Next steps would be disk partitioning, etc."
        zcurses_info "Press 'q' to quit for now."
        local temp_key
        zcurses input -k stdscr temp_key
        if [[ "$temp_key" == "q" ]] || [[ "$temp_key" == "Q" ]]; then
            # break # Exit the main while loop
        fi

        # --- Locale and Keyboard ---
        print_header "Localization"
        zcurses_title "Localization Settings"

        until select_timezone; do
            zcurses_confirm "Timezone selection failed or cancelled. Try again?"
            if (( $? != 0 )); then log_fail "User aborted at timezone selection."; return 1; fi
        done
        log_info "Timezone selection completed."

        until select_language; do
            zcurses_confirm "Language/Locale selection failed or cancelled. Try again?"
            if (( $? != 0 )); then log_fail "User aborted at language selection."; return 1; fi
        done
        log_info "Language selection completed."
        
        until select_keyboard; do
            zcurses_confirm "Keyboard layout selection failed or cancelled. Try again?"
            if (( $? != 0 )); then log_fail "User aborted at keyboard selection."; return 1; fi
        done
        log_info "Keyboard selection completed."
        
        # --- Disk Setup ---
        print_header "Disk Setup"
        zcurses_title "Target Disk Configuration"

        until select_disk; do
            zcurses_confirm "Disk selection failed or cancelled. Try again?"
            if (( $? != 0 )); then log_fail "User aborted at disk selection."; return 1; fi
        done
        log_info "Disk selection completed."

        # Placeholder for next steps
        zcurses_info "Core setup and disk selection finished."
        zcurses_info "Next: Partitioning, formatting, and installation."
        zcurses_info "Press 'q' to quit for now."
        local final_key
        zcurses input -k stdscr final_key
        if [[ "$final_key" == "q" ]] || [[ "$final_key" == "Q" ]]; then
            break # Exit the main while loop
        fi

    done

    # cleanup_zcurses will be called by trap_exit
    log_info "Main function finished."
}

# --- Script Entry Point ---
main "$@"
# trap_exit will handle final exit status and cleanup
