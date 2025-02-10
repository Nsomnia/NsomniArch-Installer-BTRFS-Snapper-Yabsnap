#!/usr/bin/env zsh
# zgym.zsh - Zsh Gum - Advanced TUI Toolkit - Unified Key Input & Zcursestetris Inspired

autoload -Uz zcurses
zcurses || return 1
autoload -Uz zui
zui || return 1
autoload -Uz zparseopts

# --- Configuration and Theme ---
ZGYM_CONFIG_FILE="$HOME/.zgymrc"
ZGYM_DEFAULT_THEME=(
  menu_bar_bg="blue"
  menu_bar_fg="white"
  menu_item_selected_attr="bold,reverse"
  dialog_bg="cyan"
  dialog_fg="black"
  dialog_border_attr="bold"
  list_selected_attr="bold,reverse"
  # ... more theme elements ...
)
ZGYM_THEME=() # Will be loaded from config or use default

# --- Keybindings ---
ZGYM_DEFAULT_KEYBINDINGS=(
  quit="^C"
  settings="s"
  toggle_debug="d"
  menu_right="^[[C" # Right Arrow
  menu_left="^[[D"  # Left Arrow
  menu_select="^M"   # Enter
  list_up="^[[A"     # Up Arrow
  list_down="^[[B"   # Down Arrow
  confirm_yes_no_right="^[[C" # Right Arrow for Confirm dialog
  confirm_yes_no_left="^[[D"  # Left Arrow for Confirm dialog
  confirm_select="^M"        # Enter for Confirm dialog
  input_submit="^M"         # Enter for Input Dialog
  input_backspace="^?"      # Backspace
  input_cancel="^["         # Escape
  filter_backspace="^?"     # Backspace in filter
  filter_delete="^[[3~"    # Delete in filter
  filter_select_up="^[[A"  # Up in filter list
  filter_select_down="^[[B" # Down in filter list
  filter_confirm="^M"       # Enter in filter list
  multi_select_toggle=" "    # Space to toggle multi-select
  multi_select_confirm="^M" # Enter to confirm multi-select
)
ZGYM_KEYBINDINGS=() # Will be loaded from config or use default

# --- Global State ---
ZGYM_RUNNING=true
ZGYM_MENU_SELECTED_INDEX=0
ZGYM_DEBUG_WINDOW_VISIBLE=false

# --- Utility Functions ---
_zgym_clear_screen() {
  clear
}

_zgym_load_config() {
  if [[ -f "$ZGYM_CONFIG_FILE" ]]; then
    source "$ZGYM_CONFIG_FILE"
  else
    ZGYM_THEME=("${ZGYM_DEFAULT_THEME[@]}")
    ZGYM_KEYBINDINGS=("${ZGYM_DEFAULT_KEYBINDINGS[@]}")
    _zgym_save_config
  fi
  if [[ -z "${ZGYM_THEME[@]}" ]]; then
     ZGYM_THEME=("${ZGYM_DEFAULT_THEME[@]}")
  fi
  if [[ -z "${ZGYM_KEYBINDINGS[@]}" ]]; then
     ZGYM_KEYBINDINGS=("${ZGYM_DEFAULT_KEYBINDINGS[@]}")
  fi
}

_zgym_save_config() {
  cat <<EOF > "$ZGYM_CONFIG_FILE"
# zgym Configuration File

# Theme Settings (Example)
ZGYM_THEME=(
EOF
  for key in "${(@k)ZGYM_DEFAULT_THEME}"; do
    value="${ZGYM_THEME[$key]}"
    echo "  $key=\"$value\""
  done
cat <<EOF
)

# Keybindings
ZGYM_KEYBINDINGS=(
EOF
  for key in "${(@k)ZGYM_DEFAULT_KEYBINDINGS}"; do
    value="${ZGYM_KEYBINDINGS[$key]}"
    echo "  $key=\"$value\""
  done
cat <<EOF
)
EOF
  echo "Configuration saved to $ZGYM_CONFIG_FILE"
}

# --- Unified Key Input Function ---
_zgym_get_key() {
  local key
  read -k key
  echo "$key" # Return the key
}


# --- Menu Bar ---
_zgym_draw_menu_bar() {
  local menu_items=("File" "Edit" "View" "Settings" "Help" "Quit")
  local selected_index=$ZGYM_MENU_SELECTED_INDEX
  local menu_bar_bg="${ZGYM_THEME[menu_bar_bg]:-$ZGYM_DEFAULT_THEME[menu_bar_bg]:-blue}"
  local menu_bar_fg="${ZGYM_THEME[menu_bar_fg]:-$ZGYM_DEFAULT_THEME[menu_bar_fg]:-white}"
  local menu_item_selected_attr="${ZGYM_THEME[menu_item_selected_attr]:-$ZGYM_DEFAULT_THEME[menu_item_selected_attr]:-bold,reverse}"

  zui row background="$menu_bar_bg" foreground="$menu_bar_fg" {
    zui columns {
      local index=0
      for item in "${menu_items[@]}"; do
        local attributes=""
        if [[ $index -eq $selected_index ]]; then
          attributes="$menu_item_selected_attr"
        fi
        zui col text="  $item  " attributes="$attributes"
        ((index++))
      done
    }
  }
}

_zgym_handle_menu_input() {
  local key=$1
  local menu_right_key="${ZGYM_KEYBINDINGS[menu_right]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_right]}"
  local menu_left_key="${ZGYM_KEYBINDINGS[menu_left]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_left]}"
  local menu_select_key="${ZGYM_KEYBINDINGS[menu_select]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_select]}"

  case "$key" in
    "$menu_right_key")
      ((ZGYM_MENU_SELECTED_INDEX++))
      if [[ $ZGYM_MENU_SELECTED_INDEX -ge 6 ]]; then
        ZGYM_MENU_SELECTED_INDEX=0
      fi
      ;;
    "$menu_left_key")
      ((ZGYM_MENU_SELECTED_INDEX--))
      if [[ $ZGYM_MENU_SELECTED_INDEX -lt 0 ]]; then
        ZGYM_MENU_SELECTED_INDEX=$((6 - 1))
      fi
      ;;
    "$menu_select_key")
      case $ZGYM_MENU_SELECTED_INDEX in
        3) # Settings
          _zgym_open_settings_dialog
          ;;
        5) # Quit
          ZGYM_RUNNING=false
          ;;
        *) # Other menu items - Placeholder
          _zgym_show_message_dialog "Menu Item Selected" "You selected menu item: ${menu_items[$ZGYM_MENU_SELECTED_INDEX]}"
          ;;
      esac
      ;;
    *)
      ;; # Ignore other keys for menu navigation
  esac
}


# --- Dialog System ---
_zgym_show_message_dialog() {
  local title=$1
  local message=$2
  local dialog_bg="${ZGYM_THEME[dialog_bg]:-$ZGYM_DEFAULT_THEME[dialog_bg]:-cyan}"
  local dialog_fg="${ZGYM_THEME[dialog_fg]:-$ZGYM_DEFAULT_THEME[dialog_fg]:-black}"
  local dialog_border_attr="${ZGYM_THEME[dialog_border_attr]:-$ZGYM_DEFAULT_THEME[dialog_border_attr]:-bold}"

  _zgym_clear_screen

  zui border title="$title" attributes="$dialog_border_attr" background="$dialog_bg" foreground="$dialog_fg" {
    zui rows {
      zui row text="$message"
      zui row {
        zui columns {
          zui col { } # Spacer
          zui col text="<Press Enter to Continue>"
          zui col { } # Spacer
        }
      }
    }
  }
  zui refresh

  _zgym_get_key # Wait for any key press (Enter is implied by message but any key works now)
}

_zgym_get_input_dialog() {
  local title=$1
  local prompt=$2
  local dialog_bg="${ZGYM_THEME[dialog_bg]:-$ZGYM_DEFAULT_THEME[dialog_bg]:-cyan}"
  local dialog_fg="${ZGYM_THEME[dialog_fg]:-$ZGYM_DEFAULT_THEME[dialog_fg]:-black}"
  local dialog_border_attr="${ZGYM_THEME[dialog_border_attr]:-$ZGYM_DEFAULT_THEME[dialog_border_attr]:-bold}"
  local input_text=""

  _zgym_clear_screen

  zui border title="$title" attributes="$dialog_border_attr" background="$dialog_bg" foreground="$dialog_fg" {
    zui rows {
      zui row text="$prompt "
      zui row text="%{$dialog_fg%}> %{$dialog_fg%}$input_text%{%f%}" id=input_line
    }
  }
  zui refresh

  zle -N _zgym_input_widget _zgym_input_widget
  zle -M "Input Dialog" _zgym_input_widget
  input_text=$(vared -p '' INPUT_RESULT)
  zle -U $input_text
  zle -M ""
  unset INPUT_RESULT
  echo "$input_text"
}

_zgym_input_widget() {
  local key
  local input_line_id="input_line"
  local input_text=$INPUT_RESULT
  local input_submit_key="${ZGYM_KEYBINDINGS[input_submit]:-$ZGYM_DEFAULT_KEYBINDINGS[input_submit]}"
  local input_backspace_key="${ZGYM_KEYBINDINGS[input_backspace]:-$ZGYM_DEFAULT_KEYBINDINGS[input_backspace]}"
  local input_cancel_key="${ZGYM_KEYBINDINGS[input_cancel]:-$ZGYM_DEFAULT_KEYBINDINGS[input_cancel]}"


  while true; do
    zui update input_line text="%{$dialog_fg%}> %{$dialog_fg%}$input_text%{%f%}"
    zui refresh
    key=$(_zgym_get_key) # Use unified key input

    case "$key" in
      "$input_submit_key")
        INPUT_RESULT="$input_text"
        return 0
        ;;
      "$input_backspace_key")
        input_text=${input_text%?}
        ;;
      "$input_cancel_key")
        INPUT_RESULT=""
        return 1
        ;;
      *) # Regular characters
        input_text+="$key"
        ;;
    esac
    INPUT_RESULT="$input_text"
  done
}


# --- Settings Dialog ---
_zgym_open_settings_dialog() {
  local settings_options=("Theme" "Keybindings" "Back")
  local selected_setting_index=0
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local menu_select_key="${ZGYM_KEYBINDINGS[menu_select]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_select]}"
  local input_cancel_key="${ZGYM_KEYBINDINGS[input_cancel]:-$ZGYM_DEFAULT_KEYBINDINGS[input_cancel]}"


  while true; do
    _zgym_clear_screen
    zui border title="Settings" attributes="${ZGYM_THEME[dialog_border_attr]:-$ZGYM_DEFAULT_THEME[dialog_border_attr]:-bold}" background="${ZGYM_THEME[dialog_bg]:-$ZGYM_DEFAULT_THEME[dialog_bg]:-cyan}" foreground="${ZGYM_THEME[dialog_fg]:-$ZGYM_DEFAULT_THEME[dialog_fg]:-black}" {
      zui rows {
        local index=0
        for option in "${settings_options[@]}"; do
          local attr=""
          if [[ $index -eq $selected_setting_index ]]; then
            attr="${ZGYM_THEME[list_selected_attr]:-$ZGYM_DEFAULT_THEME[list_selected_attr]:-bold,reverse}"
          fi
          zui row text="  $option  " attributes="$attr"
          ((index++))
        done
      }
    }
    zui refresh

    key=$(_zgym_get_key) # Use unified key input

    case "$key" in
      "$list_up_key")
        ((selected_setting_index--))
        if [[ $selected_setting_index -lt 0 ]]; then
          selected_setting_index=$(( ${#settings_options[@]} - 1 ))
        fi
        ;;
      "$list_down_key")
        ((selected_setting_index++))
        if [[ $selected_setting_index -ge ${#settings_options[@]} ]]; then
          selected_setting_index=0
        fi
        ;;
      "$menu_select_key")
        case $selected_setting_index in
          0) # Theme Settings
            _zgym_edit_theme_settings
            ;;
          1) # Keybinding Settings
            _zgym_edit_keybindings_settings
            ;;
          2) # Back
            return 0
            ;;
        esac
        ;;
      "$input_cancel_key")
        return 0
        ;;
    esac
  done
}

_zgym_edit_theme_settings() {
  local theme_keys=("menu_bar_bg" "menu_bar_fg" "menu_item_selected_attr" "dialog_bg" "dialog_fg" "dialog_border_attr" "list_selected_attr")
  local selected_theme_index=0
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local menu_select_key="${ZGYM_KEYBINDINGS[menu_select]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_select]}"
  local input_cancel_key="${ZGYM_KEYBINDINGS[input_cancel]:-$ZGYM_DEFAULT_KEYBINDINGS[input_cancel]}"


  while true; do
    _zgym_clear_screen
    zui border title="Theme Settings" attributes="${ZGYM_THEME[dialog_border_attr]:-$ZGYM_DEFAULT_THEME[dialog_border_attr]:-bold}" background="${ZGYM_THEME[dialog_bg]:-$ZGYM_DEFAULT_THEME[dialog_bg]:-cyan}" foreground="${ZGYM_THEME[dialog_fg]:-$ZGYM_DEFAULT_THEME[dialog_fg]:-black}" {
      zui rows {
        local index=0
        for key in "${theme_keys[@]}"; do
          local attr=""
          if [[ $index -eq $selected_theme_index ]]; then
            attr="${ZGYM_THEME[list_selected_attr]:-$ZGYM_DEFAULT_THEME[list_selected_attr]:-bold,reverse}"
          fi
          zui row text="  $key: ${ZGYM_THEME[$key]:-$ZGYM_DEFAULT_THEME[$key]}  " attributes="$attr"
          ((index++))
        done
      }
    }
    zui refresh

    key=$(_zgym_get_key) # Use unified key input

    case "$key" in
      "$list_up_key")
        ((selected_theme_index--))
        if [[ $selected_theme_index -lt 0 ]]; then
          selected_theme_index=$(( ${#theme_keys[@]} - 1 ))
        fi
        ;;
      "$list_down_key")
        ((selected_theme_index++))
        if [[ $selected_theme_index -ge ${#theme_keys[@]} ]]; then
          selected_theme_index=0
        fi
        ;;
      "$menu_select_key")
        local key_to_edit="${theme_keys[$selected_theme_index]}"
        local current_value="${ZGYM_THEME[$key_to_edit]:-$ZGYM_DEFAULT_THEME[$key_to_edit]}"
        local new_value=$(_zgym_get_input_dialog "Edit Theme Setting" "Enter new value for $key_to_edit (current: $current_value):")
        if [[ -n "$new_value" ]]; then
          ZGYM_THEME[$key_to_edit]="$new_value"
          _zgym_save_config
        fi
        ;;
      "$input_cancel_key")
        return 0
        ;;
    esac
  done
}

_zgym_edit_keybindings_settings() {
  local keybinding_keys=("quit" "settings" "toggle_debug" "menu_right" "menu_left" "menu_select" "list_up" "list_down" "confirm_yes_no_right" "confirm_yes_no_left" "confirm_select" "input_submit" "input_backspace" "input_cancel" "filter_backspace" "filter_delete" "filter_select_up" "filter_select_down" "filter_confirm" "multi_select_toggle" "multi_select_confirm")
  local selected_keybinding_index=0
  local list_up_key="${ZGYM_KEYBINDINGS[list_up]:-$ZGYM_DEFAULT_KEYBINDINGS[list_up]}"
  local list_down_key="${ZGYM_KEYBINDINGS[list_down]:-$ZGYM_DEFAULT_KEYBINDINGS[list_down]}"
  local menu_select_key="${ZGYM_KEYBINDINGS[menu_select]:-$ZGYM_DEFAULT_KEYBINDINGS[menu_select]}"
  local input_cancel_key="${ZGYM_KEYBINDINGS[input_cancel]:-$ZGYM_DEFAULT_KEYBINDINGS[input_cancel]}"


  while true; do
    _zgym_clear_screen
    zui border title="Keybinding Settings" attributes="${ZGYM_THEME[dialog_border_attr]:-$ZGYM_DEFAULT_THEME[dialog_border_attr]:-bold}" background="${ZGYM_THEME[dialog_bg]:-$ZGYM_DEFAULT_THEME[dialog_bg]:-cyan}" foreground="${ZGYM_THEME[dialog_fg]:-$ZGYM_DEFAULT_THEME[dialog_fg]:-black}" {
      zui rows {
        local index=0
        for key in "${keybinding_keys[@]}"; do
          local attr=""
          if [[ $index -eq $selected_keybinding_index ]]; then
            attr="${ZGYM_THEME[list_selected_attr]:-$ZGYM_DEFAULT_THEME[list_selected_attr]:-bold,reverse}"
          fi
          zui row text="  $key: ${ZGYM_KEYBINDINGS[$key]:-$ZGYM_DEFAULT_KEYBINDINGS[$key]}  " attributes="$attr"
          ((index++))
        done
      }
    }
    zui refresh

    key=$(_zgym_get_key) # Use unified key input

    case "$key" in
      "$list_up_key")
        ((selected_keybinding_index--))
        if [[ $selected_keybinding_index -lt 0 ]]; then
          selected_keybinding_index=$(( ${#keybinding_keys[@]} - 1 ))
        fi
        ;;
      "$list_down_key")
        ((selected_keybinding_index++))
        if [[ $selected_keybinding_index -ge ${#keybinding_keys[@]} ]]; then
          selected_keybinding_index=0
        fi
        ;;
      "$menu_select_key")
        local key_to_edit="${keybinding_keys[$selected_keybinding_index]}"
        local current_value="${ZGYM_KEYBINDINGS[$key_to_edit]:-$ZGYM_DEFAULT_KEYBINDINGS[$key_to_edit]}"
        local new_value=$(_zgym_get_input_dialog "Edit Keybinding" "Press new key for '$key_to_edit' (current: '$current_value'):")
        if [[ -n "$new_value" ]]; then
          ZGYM_KEYBINDINGS[$key_to_edit]="$new_value"
          _zgym_save_config
        fi
        ;;
      "$input_cancel_key")
        return 0
        ;;
    esac
  done
}


# --- Debug Window (Placeholder) ---
_zgym_toggle_debug_window() {
  ZGYM_DEBUG_WINDOW_VISIBLE=$(( 1 - ZGYM_DEBUG_WINDOW_VISIBLE ))
  if [[ $ZGYM_DEBUG_WINDOW_VISIBLE -eq 1 ]]; then
    _zgym_show_message_dialog "Debug Window" "Debug window is now enabled (Placeholder - no actual debug output yet)."
  else
    _zgym_show_message_dialog "Debug Window" "Debug window is now disabled."
  fi
}

_zgym_draw_debug_window() {
  if [[ $ZGYM_DEBUG_WINDOW_VISIBLE -eq 1 ]]; then
    zui row title="Debug Output (Placeholder)" {
      zui row text="...Debug info will appear here..."
    }
  fi
}


# --- Main Event Loop ---
_zgym_main_loop() {
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"
  local settings_key="${ZGYM_KEYBINDINGS[settings]:-$ZGYM_DEFAULT_KEYBINDINGS[settings]}"
  local toggle_debug_key="${ZGYM_KEYBINDINGS[toggle_debug]:-$ZGYM_DEFAULT_KEYBINDINGS[toggle_debug]}"


  while $ZGYM_RUNNING; do
    _zgym_clear_screen
    _zgym_draw_menu_bar
    _zgym_draw_debug_window # Placeholder debug window drawing
    zui refresh

    local key=$(_zgym_get_key) # Use unified key input

    local handled=false

    # Menu input handling
    _zgym_handle_menu_input "$key"
    handled=$?

    if [[ $handled -eq 0 ]]; then
      continue
    fi


    # Global Keybindings (after menu handling)
    case "$key" in
      "$quit_key")
        ZGYM_RUNNING=false
        handled=true
        ;;
      "$settings_key")
        _zgym_open_settings_dialog
        handled=true
        ;;
      "$toggle_debug_key")
        _zgym_toggle_debug_window
        handled=true
        ;;
      *) # Mode-specific input handling (if any - future modes like choose, etc.)
        : # Placeholder for mode-specific input - to be added later
    esac


  done
}


# --- Main zgym function (entry point) ---
zgym() {
  _zgym_load_config
  _zgym_main_loop
  _zgym_clear_screen
  echo "Exiting zgym."
  return 0
}

# --- Entry point for script execution ---
zgym "$@"