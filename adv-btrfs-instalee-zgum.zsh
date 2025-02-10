#!/usr/bin/env zsh
# zgym-arch-installer.zsh - Advanced Arch Linux Installer using zgym TUI

autoload -Uz zcurses zui zparseopts

# --- Configuration, Theme, Keybindings (Installer Specific) ---
# ... (Include relevant theme and keybindings from previous zgym.zsh, adjust as needed for installer context)
ZGYM_CONFIG_FILE="$HOME/.zgym-arch-installer.rc" # Installer specific config
ZGYM_DEFAULT_THEME=( ... ) # Installer theme defaults
ZGYM_THEME=()
ZGYM_DEFAULT_KEYBINDINGS=( ... ) # Installer keybinding defaults, potentially add installer-specific actions
ZGYM_KEYBINDINGS=()

# --- Global Installer State ---
ZGYM_INSTALLER_RUNNING=true
ZGYM_INSTALLER_STAGE="welcome" # Current installer stage
ZGYM_INSTALLER_DATA=( # Store installer choices
  language="en_US"
  keyboard_layout="us"
  disk=""
  partitions=() # Array of partition configurations
  btrfs_subvolumes=()
  snapshot_tool="none"
  hostname="archlinux"
  username="user"
  root_password=""
  packages=("base") # Default base packages
  bootloader="grub"
)
ZGYM_INSTALLER_DEBUG_MODE=false

# --- Utility Functions (Extended for Installer) ---
_zgym_clear_screen() { clear }
_zgym_load_config() { ... } # (Adjust config loading for installer)
_zgym_save_config() { ... } # (Adjust config saving for installer)
_zgym_get_key() { ... }
_zgym_show_message_dialog() { ... }
_zgym_get_input_dialog() { ... }
_zgym_input_widget() { ... }

# --- Pane Management (as before) ---
_zgym_create_pane() { ... }
_zgym_delete_pane() { ... }
_zgym_resize_pane() { ... }
_zgym_move_pane() { ... }
_zgym_set_pane_content() { ... }
_zgym_get_pane_config() { ... }
_zgym_draw_panes() { ... } # (Adjust for installer panes)

# --- Pane Drawing Functions (Installer Specific) ---
_zgym_draw_installer_welcome_pane() {
  local pane_index=$1
  _zgym_set_pane_content $pane_index (
    "Welcome to the Advanced zgym Arch Linux Installer!"
    ""
    "This installer is designed for Btrfs file systems with snapshotting capabilities (Snapper, Timeshift-Btrfs, Yabsnap)."
    "It offers advanced partitioning and customization options."
    ""
    "Please use the keyboard to navigate. Press 'h' for help at any time."
    ""
    "WARNING: This installer will modify your disk. Ensure you have backups of important data!"
    ""
    "Press 'Next' to continue or 'Quit' to exit."
  )
}

_zgym_draw_installer_language_pane() {
  local pane_index=$1
  local languages=( "en_US" "de_DE" "fr_FR" "es_ES" "zh_CN" ) # Example languages, get from locale -a or similar
  _zgym_set_pane_content $pane_index "$languages[@]"
}

_zgym_draw_installer_keyboard_pane() {
  local pane_index=$1
  local keylayouts=( "us" "de" "gb" "fr" "es" "cn" ) # Example layouts, get from localectl list-keymaps
  _zgym_set_pane_content $pane_index "$keylayouts[@]"
}

_zgym_draw_installer_disk_select_pane() {
  local pane_index=$1
  local disks=($(lsblk -o NAME,SIZE,MODEL -n -p | awk '{print $1 " (" $2 ", " $3 ")"}')) # Example, refine with jq for better parsing
  _zgym_set_pane_content $pane_index "$disks[@]"
}

_zgym_draw_installer_partitioning_pane() {
  local pane_index=$1
  local partitioning_options=( "Guided Partitioning (Btrfs Subvolumes)" "Custom Partitioning" )
  _zgym_set_pane_content $pane_index "$partitioning_options[@]"
}

_zgym_draw_installer_guided_partitioning_options_pane() {
  local pane_index=$1
  local guided_options=(
    "Btrfs Root/Home (Recommended)"
    "Btrfs Root/Home/Var"
    "Btrfs Root/Home/Swapfile"
    "Btrfs Root Only (Advanced)"
  )
  _zgym_set_pane_content $pane_index "$guided_options[@]"
}

_zgym_draw_installer_custom_partitioning_pane() {
  local pane_index=$1
  local disk_name="${ZGYM_INSTALLER_DATA[disk]}" # Get selected disk
  local partitions=($(lsblk -o NAME,FSTYPE,MOUNTPOINT -n -p $disk_name)) # List partitions for selected disk
  _zgym_set_pane_content $pane_index "$partitions[@]" # Placeholder, needs interactive partition management UI
}

_zgym_draw_installer_btrfs_subvolumes_pane() {
  local pane_index=$1
  _zgym_set_pane_content $pane_index (
    "Enter Btrfs subvolume names (or leave defaults):"
    ""
    "Root Subvolume: @root"
    "Home Subvolume: @home"
    "Snapshots Subvolume: @snapshots (for snapper/timeshift)"
    "Var Subvolume: @var (optional)"
    "Swap Subvolume: @swap (optional - for swapfile)"
    ""
    "Edit the names above. Press 'Next' when done."
  ) # Needs interactive input fields for subvolume names
}

_zgym_draw_installer_snapshot_tool_pane() {
  local pane_index=$1
  local snapshot_tools=( "Snapper" "timeshift-btrfs" "Yabsnap" "None" )
  _zgym_set_pane_content $pane_index "$snapshot_tools[@]"
}

_zgym_draw_installer_system_config_pane() {
  local pane_index=$1
  _zgym_set_pane_content $pane_index (
    "System Configuration:"
    ""
    "Hostname: ${ZGYM_INSTALLER_DATA[hostname]}"
    "Username: ${ZGYM_INSTALLER_DATA[username]}"
    "Root Password: ****** (hidden)" # Indicate password input
    ""
    "Edit these settings. Press 'Next' when done."
  ) # Needs interactive input for hostname, username, password
}

_zgym_draw_installer_package_selection_pane() {
  local pane_index=$1
  local package_options=( "Basic Installation (base, base-devel)" "Custom Package Selection" )
  _zgym_set_pane_content $pane_index "$package_options[@]"
}

_zgym_draw_installer_custom_package_pane() {
  local pane_index=$1
  local package_groups=( "base" "base-devel" "desktop-gnome" "desktop-kde" "server" "development" ) # Example package groups, get from pacman -Sg
  _zgym_set_pane_content $pane_index "$package_groups[@]" # Multi-select list for package groups/individual packages
}

_zgym_draw_installer_bootloader_pane() {
  local pane_index=$1
  local bootloaders=( "GRUB" "systemd-boot" )
  _zgym_set_pane_content $pane_index "$bootloaders[@]"
}

_zgym_draw_installer_summary_pane() {
  local pane_index=$1
  _zgym_set_pane_content $pane_index (
    "Installation Summary:"
    ""
    "Language: ${ZGYM_INSTALLER_DATA[language]}"
    "Keyboard Layout: ${ZGYM_INSTALLER_DATA[keyboard_layout]}"
    "Disk: ${ZGYM_INSTALLER_DATA[disk]}"
    "Partitioning: ${ZGYM_INSTALLER_DATA[partitioning_type]}" # Store partitioning type in data
    "Btrfs Subvolumes: ..." # Summarize subvolumes if Btrfs
    "Snapshot Tool: ${ZGYM_INSTALLER_DATA[snapshot_tool]}"
    "Hostname: ${ZGYM_INSTALLER_DATA[hostname]}"
    "Username: ${ZGYM_INSTALLER_DATA[username]}"
    "Bootloader: ${ZGYM_INSTALLER_DATA[bootloader]}"
    "Packages: ..." # Summarize selected packages
    ""
    "WARNING: Proceeding will format partitions and install Arch Linux."
    "Press 'Install' to begin or 'Back' to review/change settings."
  ) # Summarize all choices from ZGYM_INSTALLER_DATA
}

_zgym_draw_installer_progress_pane() {
  local pane_index=$1
  _zgym_set_pane_content $pane_index ( "Installation in progress..." ) # Progress bar and log output in separate panes
  # Add progress bar pane and command output pane here in _zgym_draw_panes based on stage
}

_zgym_draw_installer_complete_pane() {
  local pane_index=$1
  _zgym_set_pane_content $pane_index (
    "Installation Complete!"
    ""
    "Arch Linux has been successfully installed."
    ""
    "You can now reboot your system."
    ""
    "Press 'Reboot' to reboot now or 'Quit' to exit."
  )
}


# --- Pane Input Handling (Installer Specific) ---
_zgym_handle_installer_input() {
  local key=$1
  local current_stage=$ZGYM_INSTALLER_STAGE

  case "$current_stage" in
    welcome) _zgym_handle_installer_welcome_input "$key"; ;;
    language) _zgym_handle_installer_language_input "$key"; ;;
    keyboard) _zgym_handle_installer_keyboard_input "$key"; ;;
    disk_select) _zgym_handle_installer_disk_select_input "$key"; ;;
    partitioning_options) _zgym_handle_installer_partitioning_options_input "$key"; ;;
    guided_partitioning_options) _zgym_handle_installer_guided_partitioning_options_input "$key"; ;;
    custom_partitioning) _zgym_handle_installer_custom_partitioning_input "$key"; ;;
    btrfs_subvolumes) _zgym_handle_installer_btrfs_subvolumes_input "$key"; ;;
    snapshot_tool) _zgym_handle_installer_snapshot_tool_input "$key"; ;;
    system_config) _zgym_handle_installer_system_config_input "$key"; ;;
    package_selection) _zgym_handle_installer_package_selection_input "$key"; ;;
    custom_package) _zgym_handle_installer_custom_package_input "$key"; ;;
    bootloader) _zgym_handle_installer_bootloader_input "$key"; ;;
    summary) _zgym_handle_installer_summary_input "$key"; ;;
    progress) _zgym_handle_installer_progress_input "$key"; ;;
    complete) _zgym_handle_installer_complete_input "$key"; ;;
    *) ;; # Unknown stage
  esac
}

_zgym_handle_installer_welcome_input() {
  local key=$1
  local menu_select_key="${ZGYM_KEYBINDINGS[menu_select]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  case "$key" in
    "$menu_select_key") ZGYM_INSTALLER_STAGE="language"; ;; # Next stage on Enter (Next button equivalent)
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;; # Quit on Quit key
    *) ;;
  esac
}

_zgym_handle_installer_language_input() {
  local key=$1
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local list_select_key="${ZGYM_KEYBINDINGS[list_select]:-$ZGYM_DEFAULT_KEYBINDINGS[list_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local pane_config="${ZGYM_PANES[$active_pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"
  local selected_index=$scroll_position # For simple list selection, scroll position can serve as index

  case "$key" in
    "$list_up_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_down_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_select_key")
      ZGYM_INSTALLER_DATA[language]="${content[$selected_index]}" # Store selected language
      ZGYM_INSTALLER_STAGE="keyboard"; # Next stage
      ;;
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_keyboard_input() {
  local key=$1
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local list_select_key="${ZGYM_KEYBINDINGS[list_select]:-$ZGYM_DEFAULT_KEYBINDINGS[list_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local pane_config="${ZGYM_PANES[$active_pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"
  local selected_index=$scroll_position

  case "$key" in
    "$list_up_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_down_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_select_key")
      ZGYM_INSTALLER_DATA[keyboard_layout]="${content[$selected_index]}"
      ZGYM_INSTALLER_STAGE="disk_select";
      ;;
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_disk_select_input() {
  local key=$1
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local list_select_key="${ZGYM_KEYBINDINGS[list_select]:-$ZGYM_DEFAULT_KEYBINDINGS[list_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local pane_config="${ZGYM_PANES[$active_pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"
  local selected_index=$scroll_position

  case "$key" in
    "$list_up_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_down_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_select_key")
      ZGYM_INSTALLER_DATA[disk]="${content[$selected_index]%% *}" # Extract disk name (e.g., /dev/sda from "/dev/sda (size, model)")
      ZGYM_INSTALLER_STAGE="partitioning_options";
      ;;
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_partitioning_options_input() {
  local key=$1
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local list_select_key="${ZGYM_KEYBINDINGS[list_select]:-$ZGYM_DEFAULT_KEYBINDINGS[list_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local pane_config="${ZGYM_PANES[$active_pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"
  local selected_index=$scroll_position

  case "$key" in
    "$list_up_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_down_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_select_key")
      local selected_option="${content[$selected_index]}"
      ZGYM_INSTALLER_DATA[partitioning_type]="$selected_option" # Store partitioning type
      if [[ "$selected_option" == "Guided Partitioning (Btrfs Subvolumes)" ]]; then
        ZGYM_INSTALLER_STAGE="guided_partitioning_options";
      elif [[ "$selected_option" == "Custom Partitioning" ]]; then
        ZGYM_INSTALLER_STAGE="custom_partitioning";
      fi
      ;;
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_guided_partitioning_options_input() {
  local key=$1
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local list_select_key="${ZGYM_KEYBINDINGS[list_select]:-$ZGYM_DEFAULT_KEYBINDINGS[list_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local pane_config="${ZGYM_PANES[$active_pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"
  local selected_index=$scroll_position

  case "$key" in
    "$list_up_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_down_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_select_key")
      ZGYM_INSTALLER_DATA[guided_partition_scheme]="${content[$selected_index]}" # Store guided scheme
      ZGYM_INSTALLER_STAGE="btrfs_subvolumes"; # Next stage after guided partitioning config
      ;;
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_custom_partitioning_input() {
  local key=$1
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"
  # ... (Implement input handling for custom partitioning: list navigation, partition operations, input dialogs for size, format, mount points etc.)
  # This is a complex stage, requiring more detailed UI and logic for partition management
  case "$key" in
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_btrfs_subvolumes_input() {
  local key=$1
  local menu_select_key="${ZGYM_KEYBINDINGS[menu_select]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"
  # ... (Implement interactive input fields using _zgym_get_input_dialog or similar for subvolume names)
  case "$key" in
    "$menu_select_key") ZGYM_INSTALLER_STAGE="snapshot_tool"; ;; # Next stage after subvolume config
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_snapshot_tool_input() {
  local key=$1
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local list_select_key="${ZGYM_KEYBINDINGS[list_select]:-$ZGYM_DEFAULT_KEYBINDINGS[list_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local pane_config="${ZGYM_PANES[$active_pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"
  local selected_index=$scroll_position

  case "$key" in
    "$list_up_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_down_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_select_key")
      ZGYM_INSTALLER_DATA[snapshot_tool]="${content[$selected_index]}"
      ZGYM_INSTALLER_STAGE="system_config";
      ;;
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_system_config_input() {
  local key=$1
  local menu_select_key="${ZGYM_KEYBINDINGS[menu_select]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"
  # ... (Implement interactive input fields for hostname, username, password using _zgym_get_input_dialog or similar)
  case "$key" in
    "$menu_select_key") ZGYM_INSTALLER_STAGE="package_selection"; ;; # Next stage after system config
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_package_selection_input() {
  local key=$1
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local list_select_key="${ZGYM_KEYBINDINGS[list_select]:-$ZGYM_DEFAULT_KEYBINDINGS[list_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local pane_config="${ZGYM_PANES[$active_pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"
  local selected_index=$scroll_position

  case "$key" in
    "$list_up_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_down_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_select_key")
      local selected_option="${content[$selected_index]}"
      if [[ "$selected_option" == "Basic Installation (base, base-devel)" ]]; then
        ZGYM_INSTALLER_DATA[packages]=("base" "base-devel") # Set basic packages
        ZGYM_INSTALLER_STAGE="bootloader";
      elif [[ "$selected_option" == "Custom Package Selection" ]]; then
        ZGYM_INSTALLER_STAGE="custom_package";
      fi
      ;;
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_custom_package_input() {
  local key=$1
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local multi_select_toggle_key="${ZGYM_KEYBINDINGS[multi_select_toggle]:-$ZGYM_DEFAULT_KEYBINDINGS[multi_select_toggle]}"
  local multi_select_confirm_key="${ZGYM_KEYBINDINGS[multi_select_confirm]:-$ZGYM_DEFAULT_KEYBINDINGS[multi_select_confirm]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local pane_config="${ZGYM_PANES[$active_pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"
  local selected_index=$scroll_position
  # ... (Implement multi-select logic for package groups, update ZGYM_INSTALLER_DATA[packages])
  case "$key" in
    "$list_up_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_down_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$multi_select_toggle_key") : # Toggle selection of current item; ;;
    "$multi_select_confirm_key") ZGYM_INSTALLER_STAGE="bootloader"; ;; # Next stage after package selection
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_bootloader_input() {
  local key=$1
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local list_select_key="${ZGYM_KEYBINDINGS[list_select]:-$ZGYM_DEFAULT_KEYBINDINGS[list_select]}"
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"

  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local pane_config="${ZGYM_PANES[$active_pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"
  local selected_index=$scroll_position

  case "$key" in
    "$list_up_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_down_key") _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index; ;;
    "$list_select_key")
      ZGYM_INSTALLER_DATA[bootloader]="${content[$selected_index]}"
      ZGYM_INSTALLER_STAGE="summary";
      ;;
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;;
    *) ;;
  esac
}

_zgym_handle_installer_summary_input() {
  local key=$1
  local menu_select_key="${ZGYM_KEYBINDINGS[menu_select]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_select]}" # "Install" button
  local prev_pane_key="${ZGYM_KEYBINDINGS[prev_pane]:-$ZGYM_DEFAULT_KEYBINDINGS[prev_pane]}" # "Back" - PgUp example
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}" # "Cancel" - Quit key

  case "$key" in
    "$menu_select_key") ZGYM_INSTALLER_STAGE="progress"; _zgym_start_installation; ;; # Start installation on Enter (Install button)
    "$prev_pane_key") # Go back to previous stage (example - needs stage history management for proper "Back" functionality)
      ZGYM_INSTALLER_STAGE="bootloader"; # Example - go back to bootloader stage
      ;;
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;; # Quit on Quit key
    *) ;;
  esac
}

_zgym_handle_installer_progress_input() {
  local key=$1
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}" # "Cancel" - Quit key

  case "$key" in
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;; # Allow canceling installation (needs actual cancellation logic)
    *) ;;
  esac
}

_zgym_handle_installer_complete_input() {
  local key=$1
  local menu_select_key="${ZGYM_KEYBINDINGS[menu_select]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_select]}" # "Reboot" button
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}" # "Quit" button

  case "$key" in
    "$menu_select_key") _zgym_reboot_system; ;; # Reboot on Enter (Reboot button)
    "$quit_key") ZGYM_INSTALLER_RUNNING=false; ;; # Quit on Quit key
    *) ;;
  esac
}


# --- Installer Stage Drawing ---
_zgym_draw_installer_stage() {
  local stage=$ZGYM_INSTALLER_STAGE
  _zgym_clear_screen
  ZGYM_PANES=() # Clear existing panes for new stage
  ZGYM_ACTIVE_PANE_INDEX=0 # Reset active pane

  case "$stage" in
    welcome)
      _zgym_create_pane "textarea" "Welcome" () 1 2 76 15;
      _zgym_draw_installer_welcome_pane 0;
      ;;
    language)
      _zgym_create_pane "scrollable_list" "Select Language" () 1 2 30 15;
      _zgym_draw_installer_language_pane 0;
      ;;
    keyboard)
      _zgym_create_pane "scrollable_list" "Select Keyboard Layout" () 1 2 30 15;
      _zgym_draw_installer_keyboard_pane 0;
      ;;
    disk_select)
      _zgym_create_pane "scrollable_list" "Select Installation Disk" () 1 2 76 15;
      _zgym_draw_installer_disk_select_pane 0;
      ;;
    partitioning_options)
      _zgym_create_pane "scrollable_list" "Partitioning Options" () 1 2 50 10;
      _zgym_draw_installer_partitioning_pane 0;
      ;;
    guided_partitioning_options)
      _zgym_create_pane "scrollable_list" "Guided Partitioning Schemes" () 1 2 50 10;
      _zgym_draw_installer_guided_partitioning_options_pane 0;
      ;;
    custom_partitioning)
      _zgym_create_pane "textarea" "Custom Partitioning (Advanced)" () 1 2 76 20; # Placeholder - needs more complex UI
      _zgym_draw_installer_custom_partitioning_pane 0;
      ;;
    btrfs_subvolumes)
      _zgym_create_pane "textarea" "Btrfs Subvolume Configuration" () 1 2 76 15; # Placeholder - needs input fields
      _zgym_draw_installer_btrfs_subvolumes_pane 0;
      ;;
    snapshot_tool)
      _zgym_create_pane "scrollable_list" "Select Snapshot Tool" () 1 2 30 10;
      _zgym_draw_installer_snapshot_tool_pane 0;
      ;;
    system_config)
      _zgym_create_pane "textarea" "System Configuration" () 1 2 76 15; # Placeholder - needs input fields
      _zgym_draw_installer_system_config_pane 0;
      ;;
    package_selection)
      _zgym_create_pane "scrollable_list" "Package Selection Type" () 1 2 50 10;
      _zgym_draw_installer_package_selection_pane 0;
      ;;
    custom_package)
      _zgym_create_pane "scrollable_list" "Select Packages (Multi-select)" () 1 2 76 20; # Placeholder - multi-select list
      _zgym_draw_installer_custom_package_pane 0;
      ;;
    bootloader)
      _zgym_create_pane "scrollable_list" "Select Bootloader" () 1 2 30 10;
      _zgym_draw_installer_bootloader_pane 0;
      ;;
    summary)
      _zgym_create_pane "textarea" "Installation Summary" () 1 2 76 20;
      _zgym_draw_installer_summary_pane 0;
      ;;
    progress)
      _zgym_create_pane "textarea" "Installation Progress" () 1 2 76 10; # Progress bar and log output panes needed
      _zgym_draw_installer_progress_pane 0;
      ;;
    complete)
      _zgym_create_pane "textarea" "Installation Complete" () 1 2 76 10;
      _zgym_draw_installer_complete_pane 0;
      ;;
    *)
      _zgym_create_pane "textarea" "Error" () 1 2 76 10;
      _zgym_set_pane_content 0 ("Unknown installer stage: $stage");
      ;;
  esac
  _zgym_draw_panes
}

# --- Installer Actions (Placeholders - Implement actual installation logic) ---
_zgym_start_installation() {
  ZGYM_INSTALLER_STAGE="progress" # Switch to progress stage
  _zgym_draw_installer_stage # Redraw UI

  # --- Placeholder Installation Script ---
  sleep 2 # Simulate installation time
  echo "Simulating partitioning..."
  sleep 1
  echo "Simulating formatting..."
  sleep 1
  echo "Simulating package installation..."
  sleep 3
  echo "Simulating bootloader installation..."
  sleep 1
  echo "Installation simulated."
  # --- End Placeholder ---

  ZGYM_INSTALLER_STAGE="complete" # Switch to complete stage after simulation
  _zgym_draw_installer_stage # Redraw UI
}

_zgym_reboot_system() {
  echo "Rebooting system..."
  reboot # Requires sudo or root privileges
}


# --- Main Installer Loop ---
_zgym_installer_loop() {
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"
  local help_key="${ZGYM_KEYBINDINGS[help]:-$ZGYM_DEFAULT_KEYBINDINGS[help]}"

  while $ZGYM_INSTALLER_RUNNING; do
    _zgym_draw_installer_stage # Draw UI for current stage
    _zgym_draw_debug_window # (Optional debug window)
    _zgym_draw_help_dialog # (Optional help dialog)
    zui refresh

    local key=$(_zgym_get_key)

    local handled=false

    if [[ $ZGYM_HELP_VISIBLE == true ]]; then
      ZGYM_HELP_VISIBLE=false
      handled=true
    else
      _zgym_handle_installer_input "$key" # Handle input for current installer stage
      handled=$?
    fi

    if [[ "$key" == "$help_key" ]]; then
      _zgym_toggle_help_dialog
      handled=true
    fi
    if [[ "$key" == "$quit_key" ]]; then
      ZGYM_INSTALLER_RUNNING=false
      handled=true
    fi

  done
}


# --- Main zgym Installer Function (Entry Point) ---
zgym_arch_installer() {
  _zgym_load_config # Load installer config
  ZGYM_INSTALLER_RUNNING=true
  ZGYM_INSTALLER_STAGE="welcome" # Start at welcome stage

  _zgym_installer_loop # Run the installer loop

  _zgym_clear_screen # Clear screen on exit
  echo "Exiting zgym Arch Linux Installer."
  return 0
}


# --- Entry point for script execution ---
zgym_arch_installer "$@"