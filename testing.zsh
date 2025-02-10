#!/usr/bin/env zsh
# zgym.zsh - Zsh Gum - Advanced TUI Toolkit - Enhanced Windowing System

autoload -Uz zcurses
zcurses || return 1
autoload -Uz zui
zui || return 1
autoload -Uz zparseopts

# --- Configuration, Theme, Keybindings (as before) ---
ZGYM_CONFIG_FILE="$HOME/.zgymrc"
ZGYM_DEFAULT_THEME=(
  menu_bar_bg="blue"
  menu_bar_fg="white"
  menu_item_selected_attr="bold,reverse"
  dialog_bg="cyan"
  dialog_fg="black"
  dialog_border_attr="bold"
  list_selected_attr="bold,reverse"
  pane_border_attr="dim"
  pane_title_attr="bold"
  scrollable_list_selected_attr="bold,reverse"
  scrollable_list_item_attr=""
  scrollable_list_scrollbar_attr="reverse"
  textarea_border_attr="dim"
  textarea_text_attr=""
  button_border_attr="dim"
  button_selected_attr="bold,reverse"
)
ZGYM_THEME=()

ZGYM_DEFAULT_KEYBINDINGS=(
  quit="^C"
  settings="s"
  toggle_debug="d"
  menu_right="^[[C"
  menu_left="^[[D"
  menu_select="^M"
  list_up="^[[A"
  list_down="^[[B"
  confirm_yes_no_right="^[[C"
  confirm_yes_no_left="^[[D"
  confirm_select="^M"
  input_submit="^M"
  input_backspace="^?"
  input_cancel="^["
  filter_backspace="^?"
  filter_delete="^[[3~"
  filter_select_up="^[[A"
  filter_select_down="^[[B"
  filter_confirm="^M"
  multi_select_toggle=" "
  multi_select_confirm="^M"
  scroll_up="^[[A"
  scroll_down="^[[B"
  next_pane="^[[6~" # PgDn
  prev_pane="^[[5~" # PgUp
  pane_resize_mode="r"
  pane_resize_up="^[[A"
  pane_resize_down="^[[B"
  pane_resize_left="^[[D"
  pane_resize_right="^[[C"
  pane_resize_confirm="^M"
  pane_resize_cancel="^["
)
ZGYM_KEYBINDINGS=()

# --- Global State ---
ZGYM_RUNNING=true
ZGYM_MENU_SELECTED_INDEX=0
ZGYM_DEBUG_WINDOW_VISIBLE=false
ZGYM_PANES=()       # Array of pane configurations
ZGYM_ACTIVE_PANE_INDEX=0 # Index of the currently active pane for input
ZGYM_PANE_RESIZE_MODE=false # Flag for pane resize mode
ZGYM_PANE_RESIZE_INDEX=-1  # Index of the pane being resized

# --- Utility Functions (as before) ---
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

# Theme Settings
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

_zgym_get_key() {
  local key
  read -k key
  echo "$key"
}

# --- Pane Management ---

_zgym_create_pane() {
  local type=$1 # Type of pane (e.g., "scrollable_list", "textarea", "command_output")
  local title=$2
  local content=$3 # Initial content (if applicable)
  local x=$4 y=$5 width=$6 height=$7

  local pane=(
    type="$type"
    title="$title"
    content=("${(@)content}") # Array for content
    scroll_position=0 # For scrollable content
    x="$x" y="$y" width="$width" height="$height"
  )
  ZGYM_PANES+=("$pane")
  return $(( ${#ZGYM_PANES[@]} - 1 )) # Return index of the new pane
}

_zgym_delete_pane() {
  local index=$1
  if [[ $index -ge 0 && $index -lt ${#ZGYM_PANES[@]} ]]; then
    unset ZGYM_PANES[$index]
    ZGYM_PANES=("${(@)ZGYM_PANES}") # Re-index array
    if [[ $ZGYM_ACTIVE_PANE_INDEX -ge ${#ZGYM_PANES[@]} ]]; then
      ZGYM_ACTIVE_PANE_INDEX=$(( ${#ZGYM_PANES[@]} - 1 )) # Adjust active pane index if needed
      if [[ $ZGYM_ACTIVE_PANE_INDEX -lt 0 ]]; then ZGYM_ACTIVE_PANE_INDEX=0; fi # Prevent negative index if no panes left
    fi
  fi
}

_zgym_resize_pane() {
  local index=$1
  local new_width=$2
  local new_height=$3
  if [[ $index -ge 0 && $index -lt ${#ZGYM_PANES[@]} ]]; then
    ZGYM_PANES[$index][width]="$new_width"
    ZGYM_PANES[$index][height]="$new_height"
  fi
}

_zgym_move_pane() {
  local index=$1
  local new_x=$2
  local new_y=$3
  if [[ $index -ge 0 && $index -lt ${#ZGYM_PANES[@]} ]]; then
    ZGYM_PANES[$index][x]="$new_x"
    ZGYM_PANES[$index][y]="$new_y"
  fi
}

_zgym_set_pane_content() {
  local index=$1
  local new_content=$2 # Array of lines
  if [[ $index -ge 0 && $index -lt ${#ZGYM_PANES[@]} ]]; then
    ZGYM_PANES[$index][content]=("$new_content")
    ZGYM_PANES[$index][scroll_position]=0 # Reset scroll position on content change
  fi
}

_zgym_get_pane_config() {
  local index=$1
  if [[ $index -ge 0 && $index -lt ${#ZGYM_PANES[@]} ]]; then
    echo "${ZGYM_PANES[$index]}" # Returns the associative array string representation
  fi
}

_zgym_draw_panes() {
  local pane_border_attr="${ZGYM_THEME[pane_border_attr]:-$ZGYM_DEFAULT_THEME[pane_border_attr]:-dim}"
  local pane_title_attr="${ZGYM_THEME[pane_title_attr]:-$ZGYM_DEFAULT_THEME[pane_title_attr]:-bold}"

  local pane_index=0
  for pane_config in "${ZGYM_PANES[@]}"; do
    local pane_type="${pane_config[type]}"
    local pane_title="${pane_config[title]}"
    local pane_content=("${pane_config[content]}")
    local pane_scroll_position="${pane_config[scroll_position]}"
    local pane_x="${pane_config[x]}"
    local pane_y="${pane_config[y]}"
    local pane_width="${pane_config[width]}"
    local pane_height="${pane_config[height]}"

    zui region x=$pane_x y=$pane_y width=$pane_width height=$pane_height {
      zui border title="$pane_title" attributes="$pane_border_attr" title_attributes="$pane_title_attr" {
        case "$pane_type" in
          scrollable_list)
            _zgym_draw_scrollable_list_pane "$pane_content" $pane_scroll_position $pane_height $pane_width
            ;;
          textarea)
            _zgym_draw_textarea_pane "$pane_content" $pane_height $pane_width
            ;;
          command_output)
            _zgym_draw_command_output_pane "$pane_content" $pane_scroll_position $pane_height $pane_width
            ;;
          *)
            zui row text="[Unknown Pane Type: $pane_type]"
            ;;
        esac
      }
    }
    ((pane_index++))
  done
}

# --- Pane Content Drawing Functions ---

_zgym_draw_scrollable_list_pane() {
  local list_items=$1 # Array of items
  local scroll_position=$2
  local pane_height=$3
  local pane_width=$4
  local scrollable_list_selected_attr="${ZGYM_THEME[scrollable_list_selected_attr]:-$ZGYM_DEFAULT_THEME[scrollable_list_selected_attr]:-bold,reverse}"
  local scrollable_list_item_attr="${ZGYM_THEME[scrollable_list_item_attr]:-$ZGYM_DEFAULT_THEME[scrollable_list_item_attr]:-}"
  local scrollable_list_scrollbar_attr="${ZGYM_THEME[scrollable_list_scrollbar_attr]:-$ZGYM_DEFAULT_THEME[scrollable_list_scrollbar_attr]:-reverse}"

  zui rows {
    local visible_items_count=$((pane_height - 2)) # Account for border
    local start_index=$scroll_position
    local end_index=$((start_index + visible_items_count))
    local item_index=0

    for ((i=start_index; i<end_index; i++)); do
      if [[ $i -lt ${#list_items[@]} ]]; then
        local item="${list_items[$i]}"
        if [[ $item_index -eq 0 ]]; then # Placeholder for selected item logic (needs state management)
          zui row text="$item" attributes="$scrollable_list_selected_attr"
        else
          zui row text="$item" attributes="$scrollable_list_item_attr"
        fi
      else
        zui row text="" # Fill empty lines if list is shorter than pane height
      fi
      ((item_index++))
    done

    # Scrollbar (basic text-based)
    local total_items=${#list_items[@]}
    if [[ $total_items -gt $visible_items_count ]]; then
      local scrollbar_height=$visible_items_count
      local scrollbar_position=$(( scroll_position * scrollbar_height / total_items ))
      local scrollbar_segment="█" # You can use other characters like '▒' or '▓'
      local scrollbar=""
      for ((i=0; i<scrollbar_height; i++)); do
        if [[ $i -eq $scrollbar_position ]]; then
          scrollbar+="%{$scrollable_list_scrollbar_attr%}$scrollbar_segment%{%f%}"
        else
          scrollbar+=" "
        fi
      done
      zui col width=1 text="$scrollbar"
    fi
  }
}

_zgym_draw_textarea_pane() {
  local text_lines=$1 # Array of lines
  local pane_height=$2
  local pane_width=$3
  local textarea_text_attr="${ZGYM_THEME[textarea_text_attr]:-$ZGYM_DEFAULT_THEME[textarea_text_attr]:-}"

  zui rows {
    local visible_lines_count=$((pane_height - 2))
    local line_index=0
    for ((i=0; i<visible_lines_count; i++)); do
      if [[ $i -lt ${#text_lines[@]} ]]; then
        zui row text="${text_lines[$i]}" attributes="$textarea_text_attr"
      else
        zui row text=""
      fi
      ((line_index++))
    done
  }
}

_zgym_draw_command_output_pane() {
  local output_lines=$1 # Array of lines
  local scroll_position=$2
  local pane_height=$3
  local pane_width=$4
  local textarea_text_attr="${ZGYM_THEME[textarea_text_attr]:-$ZGYM_DEFAULT_THEME[textarea_text_attr]:-}" # Reuse textarea style for now

  zui rows {
    local visible_lines_count=$((pane_height - 2))
    local start_index=$scroll_position
    local end_index=$((start_index + visible_lines_count))
    local line_index=0

    for ((i=start_index; i<end_index; i++)); do
      if [[ $i -lt ${#output_lines[@]} ]]; then
        zui row text="${output_lines[$i]}" attributes="$textarea_text_attr"
      else
        zui row text=""
      fi
      ((line_index++))
    done
     # Scrollbar - similar to scrollable list
    local total_lines=${#output_lines[@]}
    if [[ $total_lines -gt $visible_lines_count ]]; then
      local scrollbar_height=$visible_lines_count
      local scrollbar_position=$(( scroll_position * scrollbar_height / total_lines ))
      local scrollbar_segment="█"
      local scrollbar=""
      for ((i=0; i<scrollbar_height; i++)); do
        if [[ $i -eq $scrollbar_position ]]; then
          scrollbar+="%{$scrollable_list_scrollbar_attr%}$scrollbar_segment%{%f%}"
        else
          scrollbar+=" "
        fi
      done
      zui col width=1 text="$scrollbar"
    fi
  }
}

# --- Pane Input Handling ---

_zgym_handle_pane_input() {
  local key=$1
  local active_pane_index=$ZGYM_ACTIVE_PANE_INDEX
  local active_pane_config="${ZGYM_PANES[$active_pane_index]}"
  local active_pane_type="${active_pane_config[type]}"

  case "$active_pane_type" in
    scrollable_list)
      _zgym_handle_scrollable_list_pane_input "$key" $active_pane_index
      ;;
    textarea)
      _zgym_handle_textarea_pane_input "$key" $active_pane_index
      ;;
    command_output)
      _zgym_handle_command_output_pane_input "$key" $active_pane_index # If any input handling needed
      ;;
    *)
      ;; # No input handling for unknown pane types
  esac
}

_zgym_handle_scrollable_list_pane_input() {
  local key=$1
  local pane_index=$2
  local scroll_up_key="${ZGYM_KEYBINDINGS[scroll_up]:-$ZGYM_DEFAULT_KEYBINDINGS[scroll_up]}"
  local scroll_down_key="${ZGYM_KEYBINDINGS[scroll_down]:-$ZGYM_DEFAULT_KEYBINDINGS[scroll_down]}"
  local pane_config="${ZGYM_PANES[$pane_index]}"
  local content=("${pane_config[content]}")
  local scroll_position="${pane_config[scroll_position]}"


  case "$key" in
    "$scroll_up_key")
      if [[ $scroll_position -gt 0 ]]; then
        ZGYM_PANES[$pane_index][scroll_position]=$((scroll_position - 1))
      fi
      ;;
    "$scroll_down_key")
      local pane_height="${pane_config[height]}"
      local visible_items_count=$((pane_height - 2))
      local max_scroll=$(( ${#content[@]} - visible_items_count ))
      if [[ $max_scroll -lt 0 ]]; then max_scroll=0; fi # Prevent negative max_scroll
      if [[ $scroll_position -lt $max_scroll ]]; then
          ZGYM_PANES[$pane_index][scroll_position]=$((scroll_position + 1))
      fi
      ;;
    *)
      ;; # Other keys for list pane (selection etc. - to be implemented)
  esac
}

_zgym_handle_textarea_pane_input() {
  local key=$1
  local pane_index=$2
  local input_submit_key="${ZGYM_KEYBINDINGS[input_submit]:-$ZGYM_DEFAULT_KEYBINDINGS[input_submit]}"
  local input_backspace_key="${ZGYM_KEYBINDINGS[input_backspace]:-$ZGYM_DEFAULT_KEYBINDINGS[input_backspace]}"
  local input_cancel_key="${ZGYM_KEYBINDINGS[input_cancel]:-$ZGYM_DEFAULT_KEYBINDINGS[input_cancel]}"
  local pane_config="${ZGYM_PANES[$pane_index]}"
  local content=("${pane_config[content]}")

  local current_text="${content[-1]}" # Assume last line is being edited

  case "$key" in
    "$input_submit_key")
      ZGYM_PANES[$pane_index][content]+=("") # Add a new empty line for next input
      ;;
    "$input_backspace_key")
      current_text=${current_text%?}
      ZGYM_PANES[$pane_index][content][-1]="$current_text"
      ;;
    "$input_cancel_key")
      : # Handle cancel for textarea if needed
      ;;
    *) # Regular characters
      current_text+="$key"
      ZGYM_PANES[$pane_index][content][-1]="$current_text"
      ;;
  esac
}

_zgym_handle_command_output_pane_input() {
  local key=$1
  local pane_index=$2
  local scroll_up_key="${ZGYM_KEYBINDINGS[scroll_up]:-$ZGYM_DEFAULT_KEYBINDINGS[scroll_up]}"
  local scroll_down_key="${ZGYM_KEYBINDINGS[scroll_down]:-$ZGYM_DEFAULT_KEYBINDINGS[scroll_down]}"
  local pane_config="${ZGYM_PANES[$pane_index]}"
  local scroll_position="${pane_config[scroll_position]}"
  local content=("${pane_config[content]}")

  case "$key" in
    "$scroll_up_key")
      if [[ $scroll_position -gt 0 ]]; then
        ZGYM_PANES[$pane_index][scroll_position]=$((scroll_position - 1))
      fi
      ;;
    "$scroll_down_key")
      local pane_height="${pane_config[height]}"
      local visible_lines_count=$((pane_height - 2))
      local max_scroll=$(( ${#content[@]} - visible_lines_count ))
      if [[ $max_scroll -lt 0 ]]; then max_scroll=0; fi # Prevent negative max_scroll
      if [[ $scroll_position -lt $max_scroll ]]; then
          ZGYM_PANES[$pane_index][scroll_position]=$((scroll_position + 1))
      fi
      ;;
    *)
      ;; # No other input for command output pane (for now - could add copy/select etc. later)
  esac
}


# --- Pane Focus & Navigation ---
_zgym_next_pane() {
  ((ZGYM_ACTIVE_PANE_INDEX++))
  if [[ $ZGYM_ACTIVE_PANE_INDEX -ge ${#ZGYM_PANES[@]} ]]; then
    ZGYM_ACTIVE_PANE_INDEX=0
  fi
}

_zgym_prev_pane() {
  ((ZGYM_ACTIVE_PANE_INDEX--))
  if [[ $ZGYM_ACTIVE_PANE_INDEX -lt 0 ]]; then
    ZGYM_ACTIVE_PANE_INDEX=$(( ${#ZGYM_PANES[@]} - 1 ))
    if [[ $ZGYM_ACTIVE_PANE_INDEX -lt 0 ]]; then ZGYM_ACTIVE_PANE_INDEX=0; fi # Handle no panes case
  fi
}

# --- Pane Resize Mode ---

_zgym_enter_pane_resize_mode() {
  ZGYM_PANE_RESIZE_MODE=true
  ZGYM_PANE_RESIZE_INDEX=$ZGYM_ACTIVE_PANE_INDEX
  _zgym_show_message_dialog "Pane Resize Mode" "Use arrow keys to resize, Enter to confirm, Esc to cancel."
}

_zgym_exit_pane_resize_mode() {
  ZGYM_PANE_RESIZE_MODE=false
  ZGYM_PANE_RESIZE_INDEX=-1
}

_zgym_handle_pane_resize_input() {
  local key=$1
  local resize_up_key="${ZGYM_KEYBINDINGS[pane_resize_up]:-$ZGYM_DEFAULT_KEYBINDINGS[pane_resize_up]}"
  local resize_down_key="${ZGYM_KEYBINDINGS[pane_resize_down]:-$ZGYM_DEFAULT_KEYBINDINGS[pane_resize_down]}"
  local resize_left_key="${ZGYM_KEYBINDINGS[pane_resize_left]:-$ZGYM_DEFAULT_KEYBINDINGS[pane_resize_left]}"
  local resize_right_key="${ZGYM_KEYBINDINGS[pane_resize_right]:-$ZGYM_DEFAULT_KEYBINDINGS[pane_resize_right]}"
  local resize_confirm_key="${ZGYM_KEYBINDINGS[pane_resize_confirm]:-$ZGYM_DEFAULT_KEYBINDINGS[pane_resize_confirm]}"
  local resize_cancel_key="${ZGYM_KEYBINDINGS[pane_resize_cancel]:-$ZGYM_DEFAULT_KEYBINDINGS[pane_resize_cancel]}"

  local resize_pane_index=$ZGYM_PANE_RESIZE_INDEX
  local current_width="${ZGYM_PANES[$resize_pane_index][width]}"
  local current_height="${ZGYM_PANES[$resize_pane_index][height]}"

  case "$key" in
    "$resize_up_key")
      if [[ $current_height -gt 3 ]]; then # Minimum height
        _zgym_resize_pane $resize_pane_index $current_width $((current_height - 1))
      fi
      ;;
    "$resize_down_key")
      _zgym_resize_pane $resize_pane_index $current_width $((current_height + 1))
      ;;
    "$resize_left_key")
      if [[ $current_width -gt 5 ]]; then # Minimum width
        _zgym_resize_pane $resize_pane_index $((current_width - 1)) $current_height
      fi
      ;;
    "$resize_right_key")
      _zgym_resize_pane $resize_pane_index $((current_width + 1)) $current_height
      ;;
    "$resize_confirm_key")
      _zgym_exit_pane_resize_mode
      ;;
    "$resize_cancel_key")
      _zgym_exit_pane_resize_mode
      # Revert pane size to original (if needed, store original size before resize mode)
      ;;
    *)
      ;;
  esac
}


# --- Menu Bar, Dialogs, Settings (mostly as before, with keybinding updates) ---
_zgym_draw_menu_bar() { ... } # (Same as before, uses keybindings)
_zgym_handle_menu_input() { ... } # (Same as before, uses keybindings)
_zgym_show_message_dialog() { ... } # (Same as before, uses _zgym_get_key)
_zgym_get_input_dialog() { ... } # (Same as before, uses _zgym_input_widget with keybindings)
_zgym_input_widget() { ... } # (Same as before, uses keybindings)
_zgym_open_settings_dialog() { ... } # (Same as before, uses keybindings)
_zgym_edit_theme_settings() { ... } # (Same as before, uses keybindings)
_zgym_edit_keybindings_settings() { ... } # (Same as before, uses keybindings, expanded list)
_zgym_toggle_debug_window() { ... } # (Same as before, uses _zgym_show_message_dialog)
_zgym_draw_debug_window() { ... } # (Same as before)


# --- Main Event Loop ---
_zgym_main_loop() {
  local quit_key="${ZGYM_KEYBINDINGS[quit]:-$ZGYM_DEFAULT_KEYBINDINGS[quit]}"
  local settings_key="${ZGYM_KEYBINDINGS[settings]:-$ZGYM_DEFAULT_KEYBINDINGS[settings]}"
  local toggle_debug_key="${ZGYM_KEYBINDINGS[toggle_debug]:-$ZGYM_DEFAULT_KEYBINDINGS[toggle_debug]}"
  local next_pane_key="${ZGYM_KEYBINDINGS[next_pane]:-$ZGYM_DEFAULT_KEYBINDINGS[next_pane]}"
  local prev_pane_key="${ZGYM_KEYBINDINGS[prev_pane]:-$ZGYM_DEFAULT_KEYBINDINGS[prev_pane]}"
  local pane_resize_mode_key="${ZGYM_KEYBINDINGS[pane_resize_mode]:-$ZGYM_DEFAULT_KEYBINDINGS[pane_resize_mode]}"


  while $ZGYM_RUNNING; do
    _zgym_clear_screen
    _zgym_draw_menu_bar
    _zgym_draw_panes # Draw panes based on current configuration
    _zgym_draw_debug_window
    zui refresh

    local key=$(_zgym_get_key)

    local handled=false

    if [[ $ZGYM_PANE_RESIZE_MODE == true ]]; then
      _zgym_handle_pane_resize_input "$key"
      handled=true
    else
      # Menu input handling
      _zgym_handle_menu_input "$key"
      handled=$?
      if [[ $handled -eq 0 ]]; then continue; fi # Menu input handled

      # Pane input handling
      _zgym_handle_pane_input "$key"
      handled=$?
      if [[ $handled -eq 0 ]]; then continue; fi # Pane input handled


      # Global Keybindings (after menu and pane handling)
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
        "$next_pane_key")
          _zgym_next_pane
          handled=true
          ;;
        "$prev_pane_key")
          _zgym_prev_pane
          handled=true
          ;;
        "$pane_resize_mode_key")
          _zgym_enter_pane_resize_mode
          handled=true
          ;;
        *) # Mode-specific or default input handling
          : # Placeholder for other global actions or fallback input
      esac
    fi

  done
}


# --- Main zgym function (entry point) ---
zgym() {
  _zgym_load_config

  # --- Example Pane Setup on Startup ---
  _zgym_create_pane "scrollable_list" "Options" ("Option A" "Option B" "Option C" "Option D" "Option E" "Option F" "Option G" "Option H" "Option I" "Option J") 1 2 20 10
  _zgym_create_pane "textarea" "Text Input" ("Line 1" "Line 2" "") 25 2 30 8
  pane_index=$(_zgym_create_pane "command_output" "Command Output" () 1 15 54 6)
  _zgym_set_pane_content $pane_index ("Running: ls -l" "$(ls -l)") # Example command output - static for now


  _zgym_main_loop
  _zgym_clear_screen
  echo "Exiting zgym."
  return 0
}

# --- Entry point for script execution ---
zgym "$@"