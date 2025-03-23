#!/usr/bin/env zsh

# ZSH TUI Framework
# A modular textual user interface framework using zsh/curses

# Load required modules
zmodload zsh/curses
zmodload zsh/system
zmodload zsh/zutil

# Global variables
typeset -A CONFIG
typeset -A KEYBOARD_SHORTCUTS
typeset -a MENU_ITEMS
typeset -i CURRENT_SELECTION=0
typeset -i TOTAL_ITEMS=0
typeset -i SCROLL_POSITION=0
typeset -i VISIBLE_ITEMS=0
typeset -i WINDOW_HEIGHT=0
typeset -i WINDOW_WIDTH=0

# Box drawing characters
BOX_HORIZONTAL="─"
BOX_VERTICAL="│"
BOX_TOP_LEFT="┌"
BOX_TOP_RIGHT="┐"
BOX_BOTTOM_LEFT="└"
BOX_BOTTOM_RIGHT="┘"
BOX_T_DOWN="┬"
BOX_T_UP="┴"
BOX_T_RIGHT="├"
BOX_T_LEFT="┤"
BOX_CROSS="┼"
SHADOW_CHAR="░"
SELECTED_INDICATOR="▶"
UNSELECTED_INDICATOR=" "
SCROLLBAR_TOP="▲"
SCROLLBAR_MIDDLE="█"
SCROLLBAR_BOTTOM="▼"

# Default configuration
CONFIG=(
    [title]="ZSH TUI Framework"
    [action_bar_height]=1
    [status_bar_height]=1
    [shadow_enabled]=1
)

# Default keyboard shortcuts
KEYBOARD_SHORTCUTS=(
    [quit]="q"
    [select]="enter"
    [up]="k"
    [down]="j"
    [left]="h"
    [right]="l"
    [settings]="s"
    [help]="?"
)

# Parse command line options
function parse_options() {
    local -a opts
    zparseopts -D -E -a opts \
        h=help -help=help \
        t:=title -title:=title \
        -no-shadow=no_shadow

    if [[ -n "$help" ]]; then
        print_usage
        exit 0
    fi

    if [[ -n "$title" ]]; then
        CONFIG[title]="${title[2]}"
    fi

    if [[ -n "$no_shadow" ]]; then
        CONFIG[shadow_enabled]=0
    fi
}

# Print usage information
function print_usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -h, --help           Show this help message and exit
  -t, --title TITLE    Set the title of the TUI
  --no-shadow          Disable shadow effect

EOF
}

# Initialize the TUI
function init_tui() {
    # Initialize curses
    zcurses init
    zcurses addwin main $LINES $COLUMNS 0 0
    zcurses bg main white/black
    zcurses clear main
    
    # Get window dimensions
    WINDOW_HEIGHT=$LINES
    WINDOW_WIDTH=$COLUMNS
    VISIBLE_ITEMS=$((WINDOW_HEIGHT - CONFIG[action_bar_height] - CONFIG[status_bar_height] - 4))
}

# Clean up and exit
function cleanup() {
    zcurses delwin main
    zcurses end
    exit 0
}

# Draw a box with shadow
function draw_box() {
    local top=$1
    local left=$2
    local height=$3
    local width=$4
    local title=$5
    local has_shadow=${6:-$CONFIG[shadow_enabled]}
    
    # Draw top border with title
    zcurses move main $top $left
    zcurses string main "$BOX_TOP_LEFT"
    
    local title_start=$(( left + (width - ${#title} - 2) / 2 ))
    for ((i = left + 1; i < left + width - 1; i++)); do
        if [[ $i == $title_start && -n "$title" ]]; then
            zcurses string main " $title "
            i=$((i + ${#title} + 1))
        else
            zcurses string main "$BOX_HORIZONTAL"
        fi
    done
    
    zcurses string main "$BOX_TOP_RIGHT"
    
    # Draw sides
    for ((i = top + 1; i < top + height - 1; i++)); do
        zcurses move main $i $left
        zcurses string main "$BOX_VERTICAL"
        zcurses move main $i $((left + width - 1))
        zcurses string main "$BOX_VERTICAL"
    done
    
    # Draw bottom border
    zcurses move main $((top + height - 1)) $left
    zcurses string main "$BOX_BOTTOM_LEFT"
    for ((i = left + 1; i < left + width - 1; i++)); do
        zcurses string main "$BOX_HORIZONTAL"
    done
    zcurses string main "$BOX_BOTTOM_RIGHT"
    
    # Draw shadow if enabled
    if [[ $has_shadow -eq 1 ]]; then
        # Right side shadow (skip first two characters)
        for ((i = top + 2; i < top + height; i++)); do
            zcurses move main $i $((left + width))
            zcurses string main "$SHADOW_CHAR"
        done
        
        # Bottom shadow (skip first three characters)
        zcurses move main $((top + height)) $((left + 3))
        for ((i = left + 3; i < left + width + 1; i++)); do
            zcurses string main "$SHADOW_CHAR"
        done
    fi
}

# Draw the top actions bar
function draw_actions_bar() {
    local actions=("File" "Settings" "View" "Help")
    local shortcuts=("F" "S" "V" "H")
    
    # Draw the bar background
    zcurses move main 1 1
    zcurses clear main 1 $((WINDOW_WIDTH - 2)) 1 1
    
    # Draw the actions
    local pos=2
    for ((i = 0; i < ${#actions[@]}; i++)); do
        local action=${actions[$i]}
        local shortcut=${shortcuts[$i]}
        
        zcurses move main 1 $pos
        if [[ $i -eq $CURRENT_ACTION ]]; then
            zcurses attr main bold
        fi
        
        zcurses string main "[$shortcut]${action:1}"
        zcurses attr main -bold
        
        pos=$((pos + ${#action} + 3))
    done
}

# Draw the main menu
function draw_main_menu() {
    local start_row=3
    local start_col=2
    local menu_width=$((WINDOW_WIDTH - 6))  # Account for borders and scrollbar
    
    # Clear the menu area
    for ((i = start_row; i < start_row + VISIBLE_ITEMS; i++)); do
        zcurses move main $i $start_col
        zcurses clear main 1 $menu_width $i $start_col
    done
    
    # Calculate visible range
    local end_idx=$((SCROLL_POSITION + VISIBLE_ITEMS))
    [[ $end_idx -gt $TOTAL_ITEMS ]] && end_idx=$TOTAL_ITEMS
    
    # Draw menu items
    local row=$start_row
    for ((i = SCROLL_POSITION; i < end_idx; i++)); do
        local indicator=$UNSELECTED_INDICATOR
        if [[ $i -eq $CURRENT_SELECTION ]]; then
            indicator=$SELECTED_INDICATOR
            zcurses attr main bold
        fi
        
        zcurses move main $row $start_col
        zcurses string main "$indicator ${MENU_ITEMS[$i]}"
        zcurses attr main -bold
        
        row=$((row + 1))
    done
    
    # Draw scrollbar if needed
    if [[ $TOTAL_ITEMS -gt $VISIBLE_ITEMS ]]; then
        draw_scrollbar $start_row $((start_col + menu_width + 1)) $VISIBLE_ITEMS $SCROLL_POSITION $TOTAL_ITEMS
    fi
}

# Draw a scrollbar
function draw_scrollbar() {
    local top=$1
    local left=$2
    local height=$3
    local position=$4
    local total=$5
    
    # Calculate scrollbar position and size
    local scrollbar_height=$((height - 2))
    local scrollbar_pos=0
    local scrollbar_size=0
    
    if [[ $total -gt 0 ]]; then
        scrollbar_size=$((scrollbar_height * height / total))
        [[ $scrollbar_size -lt 1 ]] && scrollbar_size=1
        scrollbar_pos=$((top + 1 + (position * (scrollbar_height - scrollbar_size) / (total - height))))
    fi
    
    # Draw scrollbar
    zcurses move main $top $left
    zcurses string main "$SCROLLBAR_TOP"
    
    for ((i = top + 1; i < top + height - 1; i++)); do
        zcurses move main $i $left
        if [[ $i -ge $scrollbar_pos && $i -lt $((scrollbar_pos + scrollbar_size)) ]]; then
            zcurses string main "$SCROLLBAR_MIDDLE"
        else
            zcurses string main " "
        fi
    done
    
    zcurses move main $((top + height - 1)) $left
    zcurses string main "$SCROLLBAR_BOTTOM"
}

# Draw the status bar
function draw_status_bar() {
    local row=$((WINDOW_HEIGHT - 2))
    
    # Clear the status bar
    zcurses move main $row 1
    zcurses clear main 1 $((WINDOW_WIDTH - 2)) $row 1
    
    # Draw selection info
    zcurses move main $row 2
    zcurses string main "Item $((CURRENT_SELECTION + 1))/$TOTAL_ITEMS"
    
    # Draw keyboard shortcuts
    local shortcuts="q:Quit  ↑/↓:Navigate  Enter:Select"
    zcurses move main $row $((WINDOW_WIDTH - ${#shortcuts} - 2))
    zcurses string main "$shortcuts"
}

# Draw a dialog window
function draw_dialog() {
    local title=$1
    local message=$2
    local width=$((${#message} + 10))
    [[ $width -lt 40 ]] && width=40
    [[ $width -gt $((WINDOW_WIDTH - 10)) ]] && width=$((WINDOW_WIDTH - 10))
    
    local height=6
    local top=$(((WINDOW_HEIGHT - height) / 2))
    local left=$(((WINDOW_WIDTH - width) / 2))
    
    # Draw the dialog box
    draw_box $top $left $height $width "$title" 1
    
    # Draw the message
    zcurses move main $((top + 2)) $((left + 5))
    zcurses string main "$message"
    
    # Draw buttons
    zcurses move main $((top + 4)) $((left + width - 16))
    zcurses string main "[ OK ]  [Cancel]"
    
    # Wait for user input
    local key
    while true; do
        zcurses refresh main
        read -k 1 key
        
        case $key in
            $'\n'|$'\r')  # Enter key
                return 0
                ;;
            $'\e'|'q')    # Escape or q key
                return 1
                ;;
        esac
    done
}

# Handle keyboard input
function handle_input() {
    local key
    read -k 1 key
    
    case $key in
        $KEYBOARD_SHORTCUTS[quit])
            return 1
            ;;
        $KEYBOARD_SHORTCUTS[up]|$'\e'[A)  # Up arrow
            if [[ $CURRENT_SELECTION -gt 0 ]]; then
                CURRENT_SELECTION=$((CURRENT_SELECTION - 1))
                if [[ $CURRENT_SELECTION -lt $SCROLL_POSITION ]]; then
                    SCROLL_POSITION=$CURRENT_SELECTION
                fi
            fi
            ;;
        $KEYBOARD_SHORTCUTS[down]|$'\e'[B)  # Down arrow
            if [[ $CURRENT_SELECTION -lt $((TOTAL_ITEMS - 1)) ]]; then
                CURRENT_SELECTION=$((CURRENT_SELECTION + 1))
                if [[ $CURRENT_SELECTION -ge $((SCROLL_POSITION + VISIBLE_ITEMS)) ]]; then
                    SCROLL_POSITION=$((CURRENT_SELECTION - VISIBLE_ITEMS + 1))
                fi
            fi
            ;;
        $KEYBOARD_SHORTCUTS[left]|$'\e'[D)  # Left arrow
            # Handle left navigation
            ;;
        $KEYBOARD_SHORTCUTS[right]|$'\e'[C)  # Right arrow
            # Handle right navigation
            ;;
        $KEYBOARD_SHORTCUTS[select]|$'\n'|$'\r')  # Enter
            # Handle selection
            ;;
        $KEYBOARD_SHORTCUTS[settings])
            show_settings_menu
            ;;
        $KEYBOARD_SHORTCUTS[help])
            show_help_dialog
            ;;
    esac
    
    return 0
}

# Show settings menu
function show_settings_menu() {
    local old_menu_items=("${MENU_ITEMS[@]}")
    local old_selection=$CURRENT_SELECTION
    local old_scroll=$SCROLL_POSITION
    
    # Create settings menu
    MENU_ITEMS=(
        "Keyboard Shortcuts"
        "Display Options"
        "Colors"
        "Back to Main Menu"
    )
    TOTAL_ITEMS=${#MENU_ITEMS[@]}
    CURRENT_SELECTION=0
    SCROLL_POSITION=0
    
    local exit_settings=0
    while [[ $exit_settings -eq 0 ]]; do
        draw_main_menu
        draw_status_bar
        zcurses refresh main
        
        read -k 1 key
        case $key in
            $KEYBOARD_SHORTCUTS[quit])
                exit_settings=1
                ;;
            $KEYBOARD_SHORTCUTS[up]|$'\e'[A)  # Up arrow
                if [[ $CURRENT_SELECTION -gt 0 ]]; then
                    CURRENT_SELECTION=$((CURRENT_SELECTION - 1))
                fi
                ;;
            $KEYBOARD_SHORTCUTS[down]|$'\e'[B)  # Down arrow
                if [[ $CURRENT_SELECTION -lt $((TOTAL_ITEMS - 1)) ]]; then
                    CURRENT_SELECTION=$((CURRENT_SELECTION + 1))
                fi
                ;;
            $KEYBOARD_SHORTCUTS[select]|$'\n'|$'\r')  # Enter
                case $CURRENT_SELECTION in
                    0)  # Keyboard Shortcuts
                        configure_keyboard_shortcuts
                        ;;
                    1)  # Display Options
                        # Handle display options
                        ;;
                    2)  # Colors
                        # Handle colors
                        ;;
                    3)  # Back to Main Menu
                        exit_settings=1
                        ;;
                esac
                ;;
        esac
    done
    
    # Restore main menu
    MENU_ITEMS=("${old_menu_items[@]}")
    TOTAL_ITEMS=${#MENU_ITEMS[@]}
    CURRENT_SELECTION=$old_selection
    SCROLL_POSITION=$old_scroll
}

# Configure keyboard shortcuts
function configure_