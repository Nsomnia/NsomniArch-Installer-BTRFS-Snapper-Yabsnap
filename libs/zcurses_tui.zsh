#!/usr/bin/env zsh
#
# MIT License
#
# Copyright (c) 2023 Your Name or Organization
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

emulate -LR zsh
zmodload zsh/curses

# Initialize zsh/curses
init_zcurses() {
    # Start curses mode
    initscr
    # Enable special keys (like arrow keys)
    keypad "$stdscr" 1
    # Don't echo typed characters
    noecho
    # Make cursor invisible
    curs_set 0
    # React to keys instantly, without waiting for Enter
    #cbreak # Or raw, depending on needs. cbreak is usually preferred.
}

# Cleanup zsh/curses
cleanup_zcurses() {
    # Make cursor visible again
    curs_set 1
    # End curses mode
    endwin
}

### [ UI Constants ] ############################################################
typeset -gA box_chars=(
    light "╭─╮│ │╰─╯"
    heavy "┏━┓┃ ┃┗━┛"
    double "╔═╗║ ║╚═╝"
    rounded "╭─╮│ │╰─╯"
    none "   ││   "
)

### [ Box Drawing Utilities ] ###################################################
# Function to draw a box in a specified window
#
# Parameters:
#   $1: window_var   - Name of the variable holding the window identifier
#   $2: y            - Top row coordinate
#   $3: x            - Left column coordinate
#   $4: height       - Height of the box
#   $5: width        - Width of the box
#   $6: [style]      - (Optional) Box style ('light', 'heavy', 'double', 'rounded', 'none'). Defaults to 'light'.
#   $7: [color_pair] - (Optional) Color pair to use for the box. Defaults to standard.
draw_box() {
    local -r window_var_name="$1"
    local -i y="$2" x="$3" height="$4" width="$5"
    local -r style="${6:-light}"
    local -r color_pair_attr="${7:-}"

    # Ensure window_var_name is a valid reference to a curses window
    # This is tricky in zsh, as direct reference passing isn't straightforward for zcurses.
    # We'll assume $window_var_name holds the actual window identifier (e.g., stdscr or a subwin).
    # For simplicity, this example will use the variable name directly,
    # implying it's globally accessible or passed correctly by the caller.
    local -r win="${(P)window_var_name}"


    # Validate style
    if [[ -z "${box_chars[$style]}" ]]; then
        print -u2 "Error: Invalid box style '$style'. Using 'light'."
        style='light'
    fi

    local -Ar bc=(
        [tl]="${${=box_chars[$style]}[1]}"
        [tr]="${${=box_chars[$style]}[3]}" # Corrected index for top-right
        [bl]="${${=box_chars[$style]}[7]}" # Corrected index for bottom-left
        [br]="${${=box_chars[$style]}[9]}" # Corrected index for bottom-right
        [v]="${${=box_chars[$style]}[4]}"  # Corrected index for vertical
        [h]="${${=box_chars[$style]}[2]}"  # Corrected index for horizontal
    )

    # Apply color if specified
    [[ -n "$color_pair_attr" ]] && zcurses attr "$win" "$color_pair_attr"

    # Draw top border
    zcurses move "$win" "$y" "$x"
    zcurses string "$win" "${bc[tl]}${(pl:$((width-2))::${bc[h]}:)}${bc[tr]}"

    # Draw vertical borders
    for ((i=1; i<height-1; i++)); do
        zcurses move "$win" "$((y+i))" "$x"
        zcurses string "$win" "${bc[v]}"
        zcurses move "$win" "$((y+i))" "$((x+width-1))"
        zcurses string "$win" "${bc[v]}"
    done

    # Draw bottom border
    zcurses move "$win" "$((y+height-1))" "$x"
    zcurses string "$win" "${bc[bl]}${(pl:$((width-2))::${bc[h]}:)}${bc[br]}"

    # Reset color if it was applied
    [[ -n "$color_pair_attr" ]] && zcurses attr "$win" "normal"

    return 0
}


# Example of how to use (for testing, will be removed/commented out later)
# init_zcurses
# stdscr_ref="stdscr" # Assuming stdscr is the main window variable name
# draw_box "stdscr_ref" 5 10 5 20 "heavy"
# refresh # zcurses refresh stdscr is often just refresh
# getch # Wait for a key press
# cleanup_zcurses
# exit 0


### [ Confirmation Dialog ] #####################################################
# Displays a confirmation dialog with "Yes" and "No" options.
#
# Parameters:
#   $1: prompt_string - The message to display to the user.
#
# Returns:
#   0 if "Yes" is selected.
#   1 if "No" is selected.
#   130 if 'q' is pressed (optional, for consistency with gum).
zcurses_confirm() {
    local prompt_string="$1"
    local -i selected_option=0 # 0 for Yes, 1 for No
    local -i key_pressed
    local -i dialog_height=7 # Min height for prompt, options, and borders
    local -i dialog_width
    local -i term_height term_width
    local -i dialog_y dialog_x
    local confirm_win
    local stdscr_ref="stdscr" # Reference to stdscr

    # Calculate dialog width based on prompt length, ensure min width
    dialog_width=$(( ${#prompt_string} + 8 )) # Prompt + padding + Yes/No
    (( dialog_width < 20 )) && dialog_width=20 # Minimum width

    # Get terminal dimensions
    term_height=$(tput lines)
    term_width=$(tput cols)

    # Calculate dialog position (centered)
    dialog_y=$(( (term_height - dialog_height) / 2 ))
    dialog_x=$(( (term_width - dialog_width) / 2 ))

    # Create a new window for the dialog
    zcurses newwin confirm_win $dialog_height $dialog_width $dialog_y $dialog_x
    keypad "$confirm_win" 1 # Enable special keys for the new window

    # Loop until Enter or 'q' is pressed
    while true; do
        zcurses erase "$confirm_win" # Clear the dialog window
        draw_box "confirm_win" 0 0 "$dialog_height" "$dialog_width" "rounded"

        # Display the prompt string (centered within the dialog's width)
        local prompt_display_x=$(( (dialog_width - ${#prompt_string}) / 2 ))
        (( prompt_display_x < 1 )) && prompt_display_x=1
        zcurses move "$confirm_win" 2 "$prompt_display_x"
        zcurses string "$confirm_win" "$prompt_string"

        # Display options
        local option_y=4
        local yes_x=$(( dialog_width / 2 - 7 )) # Position "Yes"
        local no_x=$(( dialog_width / 2 + 3 ))  # Position "No"

        # Highlight "Yes"
        if (( selected_option == 0 )); then
            zcurses attr "$confirm_win" "reverse"
            zcurses move "$confirm_win" "$option_y" "$yes_x"
            zcurses string "$confirm_win" " Yes "
            zcurses attr "$confirm_win" "normal"
            zcurses move "$confirm_win" "$option_y" "$no_x"
            zcurses string "$confirm_win" " No  "
        else # Highlight "No"
            zcurses move "$confirm_win" "$option_y" "$yes_x"
            zcurses string "$confirm_win" " Yes "
            zcurses attr "$confirm_win" "reverse"
            zcurses move "$confirm_win" "$option_y" "$no_x"
            zcurses string "$confirm_win" " No  "
            zcurses attr "$confirm_win" "normal"
        fi

        zcurses refresh "$confirm_win"
        zcurses input "$confirm_win" key_pressed # Get key press (integer value)

        case "$key_pressed" in
            # Enter key (likely 10 or 13, curses KEY_ENTER is more reliable)
            $KEY_ENTER|10|13)
                zcurses delwin "$confirm_win"
                return $selected_option
                ;;
            # Left arrow or 'h' or 'j' (for left option)
            $KEY_LEFT|h|H|j|J)
                selected_option=0 # Yes
                ;;
            # Right arrow or 'l' or 'k' (for right option)
            $KEY_RIGHT|l|L|k|K)
                selected_option=1 # No
                ;;
            # 'q' or 'Q' to quit
            q|Q)
                zcurses delwin "$confirm_win"
                return 130 # SIGINT by user
                ;;
        esac
    done
}

### [ Spinner Function ] ########################################################
# Displays an animated spinner while a command executes in the background.
#
# Parameters:
#   $1: spinner_type    - String of characters to cycle for animation (e.g., "|/-\").
#                         Or a predefined type: "line", "dots", "braille".
#   $2: message_string  - Text to display next to the spinner.
#   $3: --              - Separator.
#   $4...: command      - The command and its arguments to execute.
#
# Returns:
#   The exit code of the executed command.
#
# Notes:
#   - Assumes zsh/curses (stdscr) is initialized.
#   - Takes over the current line for the spinner display.
#   - stdout/stderr of the command are redirected to /dev/null.
zcurses_spin() {
    local spinner_definition="$1"
    local message_string="$2"
    shift 2
    if [[ "$1" != "--" ]]; then
        print -u2 "Error: zcurses_spin requires '--' separator before the command."
        return 255 # Argument error
    fi
    shift # Remove --

    local -a command_to_execute=("$@")
    local -a spinner_chars_array
    local spinner_char
    local -i spinner_idx=0
    local -i cmd_pid
    local -i cmd_status=0 # Default to success
    local current_line current_col
    local -A predefined_spinners

    predefined_spinners=(
        [line]="|/-\\"
        [dots]="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏" # Braille dots are better than ASCII dots
        [braille]="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    )

    if [[ -n "${predefined_spinners[$spinner_definition]}" ]]; then
        spinner_definition="${predefined_spinners[$spinner_definition]}"
    fi

    if [[ -z "$spinner_definition" ]]; then # Default if empty or not found
        spinner_definition="|/-\\"
    fi

    integer i
    for ((i=1; i <= ${#spinner_definition}; i++)); do
        spinner_chars_array+=("${spinner_definition:$i-1:1}")
    done

    # Get current cursor position
    zcurses getyx stdscr current_line current_col

    # Execute command in background, redirecting its output
    # Consider creating a temporary file for command output if needed for debugging
    # For now, redirect to /dev/null to keep TUI clean.
    ("${command_to_execute[@]}" >/dev/null 2>&1 &)
    cmd_pid=$!

    zcurses curs_set 0 # Hide cursor during animation
    local display_line_cleared=0

    while kill -0 "$cmd_pid" 2>/dev/null; do
        spinner_char="${spinner_chars_array[(spinner_idx % #spinner_chars_array) + 1]}"
        
        zcurses move stdscr "$current_line" "$current_col"
        # Clear the line segment by printing spaces. Estimate max length needed.
        # This prevents artifacts from previous, longer messages or spinner characters.
        # Add a buffer for safety.
        local clear_len=$(( ${#message_string} + ${#spinner_char} + 5 )) 
        zcurses string stdscr "${(pl:$clear_len:: :)}" 
        
        # Move again to print the spinner and message
        zcurses move stdscr "$current_line" "$current_col"
        zcurses string stdscr "${spinner_char} ${message_string}"
        zcurses refresh stdscr
        
        ((spinner_idx++))
        sleep 0.1 # Animation speed
    done
    zcurses curs_set 1 # Restore cursor visibility

    if ! wait "$cmd_pid"; then
        cmd_status=$?
    fi
    
    # Final status update on the same line
    zcurses move stdscr "$current_line" "$current_col"
    local final_msg_clear_len=$((${#message_string} + 20)) # Icon + message + status + buffer
    zcurses string stdscr "${(pl:$final_msg_clear_len:: :)}" # Clear area for final message
    zcurses move stdscr "$current_line" "$current_col" # Reposition cursor

    local status_icon
    local status_message
    if (( cmd_status == 0 )); then
        status_icon="✔" # Green checkmark (UTF-8)
        status_message="Done."
        # Apply green color if possible (pseudo-code for color)
        # zcurses attron stdscr "COLOR_GREEN_ATTR" 
        zcurses string stdscr "${status_icon} ${message_string} ${status_message}"
        # zcurses attroff stdscr "COLOR_GREEN_ATTR"
    else
        status_icon="✘" # Red X (UTF-8)
        status_message="Failed (code: $cmd_status)."
        # Apply red color if possible (pseudo-code for color)
        # zcurses attron stdscr "COLOR_RED_ATTR"
        zcurses string stdscr "${status_icon} ${message_string} ${status_message}"
        # zcurses attroff stdscr "COLOR_RED_ATTR"
    fi
    zcurses refresh stdscr
    # Consider moving to next line after completion:
    # zcurses move stdscr $((current_line + 1)) 0
    # zcurses refresh stdscr

    return $cmd_status
}

### [ Message Display Functions ] ###############################################

# Internal helper for displaying styled messages.
# Parameters:
#   $1: prefix_icon   - e.g., "•", "⚠", "✘", "=="
#   $2: message_string - The core message.
#   $3: [color_pair_name] - (Optional) Name of a pre-defined color pair or attribute.
#                           Actual color application depends on zcurses setup and available pairs.
_zcurses_display_message() {
    local prefix_icon="$1"
    local message_string="$2"
    local color_name="$3" # This is symbolic; actual color needs setup
    local current_line current_col

    zcurses getyx stdscr current_line current_col

    # If not at the start of a line, move to the next line to prevent overwriting existing text.
    if (( current_col > 0 )); then
        current_line=$((current_line + 1))
        current_col=0
    fi
    zcurses move stdscr "$current_line" "$current_col"
    zcurses clrtoeol stdscr # Clear the line before printing the new message

    # Placeholder for applying color/attributes
    # Example: if typeset -gA ZCURSES_COLORS; ZCURSES_COLORS[green_bold]="pair_index_or_attribute_value"
    # then: zcurses attr stdscr "${ZCURSES_COLORS[$color_name]}"
    # For now, no actual color change, just structure.

    zcurses string stdscr "${prefix_icon} ${message_string}"

    # Placeholder for resetting color/attributes
    # zcurses attr stdscr "normal" 
    
    zcurses refresh stdscr
    
    # Move cursor to the beginning of the next line for subsequent terminal output
    # This makes it behave like `echo`.
    zcurses move stdscr $((current_line + 1)) 0
    zcurses refresh stdscr # Refresh again after moving cursor
}

# Displays a title message.
# Example: Bold, or a specific color like blue.
zcurses_title() {
    # For titles, often no icon, just styled text.
    # The prefix here is for consistency with _zcurses_display_message, adjust as needed.
    _zcurses_display_message "===" "$1" "title_color_attr" # Symbolic color
}

# Displays an informational message.
# Example: Green, prefixed with "• ".
zcurses_info() {
    _zcurses_display_message "•" "$1" "info_color_attr" # Symbolic color
}

# Displays a warning message.
# Example: Yellow, prefixed with "⚠ ".
zcurses_warn() {
    _zcurses_display_message "⚠" "$1" "warn_color_attr" # Symbolic color
}

# Displays a failure/error message.
# Example: Red, prefixed with "✘ ".
zcurses_fail() {
    _zcurses_display_message "✘" "$1" "fail_color_attr" # Symbolic color
}

### [ Filter Dialog ] ###########################################################
# Displays a dialog with a filter input and a list of choices that dynamically update.
#
# Parameters:
#   $1: header_string - The message/header to display above the filter input.
#   $2...: choices    - The list of choices to filter and select from.
#
# Output to STDOUT:
#   The selected choice string if the user confirms with Enter.
#
# Returns:
#   0 if the user confirms with Enter.
#   1 if the initial list of choices is empty.
#   130 if the user cancels (e.g., 'q', 'Q', Escape).
#
# Notes:
#   - Matching is case-insensitive.
#   - Focus switching between input and list is implicit: typing targets filter,
#     Up/Down/PgUp/PgDown/Home/End target list navigation.
zcurses_filter() {
    local header_string="$1"
    shift
    local -a all_choices=("$@")
    local -i num_all_choices=${#all_choices[@]}

    if (( num_all_choices == 0 )); then
        print -u2 "Error: zcurses_filter requires at least one choice."
        return 1
    fi

    local filter_query=""
    local -a filtered_choices=()
    local -i num_filtered_choices=0
    local -i selected_filtered_index=0 # Index in filtered_choices
    local -i list_scroll_offset=0
    local -i filter_cursor_pos=0
    local -i key_code

    local -i dialog_height term_height term_width dialog_y dialog_x dialog_width
    local -i list_display_height input_field_y
    local filter_win
    local -r cursor_char="❯ "
    local -i header_lines=1 # For the main header
    local -i input_field_lines=1 # For the filter input field
    local -i padding_lines=4 # Top border, line below header, line below input, bottom border

    # --- Helper function to update filtered_choices ---
    _update_filtered_list() {
        filtered_choices=()
        selected_filtered_index=0 # Reset selection
        list_scroll_offset=0      # Reset scroll

        if [[ -z "$filter_query" ]]; then
            filtered_choices=(${all_choices[@]})
        else
            # Case-insensitive matching: convert both query and item to lowercase for comparison
            local lower_query="${filter_query:l}" 
            local item
            for item in "${all_choices[@]}"; do
                if [[ "${item:l}" == *"$lower_query"* ]]; then
                    filtered_choices+=("$item")
                fi
            done
        fi
        num_filtered_choices=${#filtered_choices[@]}
    }
    # --- End Helper ---

    _update_filtered_list # Initial population with all choices

    # Calculate dialog dimensions
    term_height=$(tput lines)
    term_width=$(tput cols)

    dialog_width=$(( term_width * 8 / 10 )) # 80% of term width
    (( dialog_width < 40 )) && dialog_width=40 # Min width
    (( dialog_width > term_width - 4 )) && dialog_width=$((term_width - 4))

    list_display_height=$(( term_height / 2 ))
    (( list_display_height < 5 )) && list_display_height=5
    dialog_height=$(( header_lines + input_field_lines + list_display_height + padding_lines ))
    (( dialog_height > term_height - 2 )) && dialog_height=$((term_height - 2))
    list_display_height=$(( dialog_height - header_lines - input_field_lines - padding_lines ))
    (( list_display_height < 1 )) && list_display_height=1 # Ensure at least one line for the list

    dialog_y=$(( (term_height - dialog_height) / 2 ))
    dialog_x=$(( (term_width - dialog_width) / 2 ))

    zcurses newwin filter_win $dialog_height $dialog_width $dialog_y $dialog_x
    keypad "$filter_win" 1

    while true; do
        zcurses erase "$filter_win"
        draw_box "filter_win" 0 0 "$dialog_height" "$dialog_width" "rounded"

        # 1. Display Header
        local header_display_x=$(( (dialog_width - ${#header_string}) / 2 ))
        (( header_display_x < 1 )) && header_display_x=1
        zcurses move "$filter_win" 1 "$header_display_x"
        zcurses string "$filter_win" "$header_string"

        # 2. Display Filter Input Field (line below header)
        input_field_y=2 # Line directly below the header text line
        local input_field_prompt="Filter: "
        local input_field_x=2 # Start after border
        zcurses move "$filter_win" "$input_field_y" "$input_field_x"
        zcurses string "$filter_win" "$input_field_prompt"
        
        local current_input_display_x=$(( input_field_x + ${#input_field_prompt} ))
        local input_field_width=$(( dialog_width - current_input_display_x - 2 )) # -2 for right border
        
        # Display the filter query string (similar to zcurses_input)
        # Basic display, no scrolling of query text for now for simplicity
        local displayed_query="${filter_query:0:$input_field_width}"
        zcurses string "$filter_win" "$displayed_query"
        
        # Fill remaining space in input field line
        local fill_len=$(( input_field_width - ${#displayed_query} ))
          if (( fill_len > 0 )); then
            zcurses string "$filter_win" "${(pl:$fill_len:: :)}"
        fi
        # Place cursor in filter input
        zcurses move "$filter_win" "$input_field_y" "$(( current_input_display_x + filter_cursor_pos ))"
        zcurses curs_set 1 # Show cursor for input field

        # 3. Display Filtered Choices List (below input field)
        local list_start_y=$((input_field_y + 2)) # Line below input field, plus a separator line
        if (( num_filtered_choices == 0 )); then
            local no_match_msg="No matches found."
            local no_match_x=$(( (dialog_width - ${#no_match_msg}) / 2 ))
            zcurses move "$filter_win" "$list_start_y" "$no_match_x"
            zcurses string "$filter_win" "$no_match_msg"
        else
            for (( i=0; i < list_display_height; i++ )); do
                local current_item_index=$((list_scroll_offset + i))
                if (( current_item_index >= num_filtered_choices )); then
                    break
                fi

                local display_y=$((list_start_y + i))
                local item_display_x=2 # Padding from left border
                zcurses move "$filter_win" "$display_y" "$item_display_x"

                local item_text="${filtered_choices[current_item_index+1]}" # Zsh arrays 1-indexed
                local display_string

                if (( current_item_index == selected_filtered_index )); then
                    zcurses attr "$filter_win" "reverse"
                    display_string="$cursor_char$item_text"
                else
                    display_string="  $item_text"
                fi
                
                local max_item_width=$((dialog_width - 4))
                if (( ${#display_string} > max_item_width )); then
                    display_string="${display_string:0:$max_item_width}"
                fi
                zcurses string "$filter_win" "$display_string"
                (( current_item_index == selected_filtered_index )) && zcurses attr "$filter_win" "normal"
            done

            # Scroll indicators for list
            if (( list_scroll_offset > 0 )); then
                zcurses move "$filter_win" "$list_start_y" "$((dialog_width - 2))"
                zcurses string "$filter_win" "↑"
            fi
            if (( list_scroll_offset + list_display_height < num_filtered_choices )); then
                zcurses move "$filter_win" "$((list_start_y + list_display_height - 1))" "$((dialog_width - 2))"
                zcurses string "$filter_win" "↓"
            fi
        fi
        zcurses refresh "$filter_win"
        zcurses input -k "$filter_win" key_code
        zcurses curs_set 0 # Hide cursor during processing

        case "$key_code" in
            # --- List Navigation ---
            $KEY_UP|k|K)
                if (( num_filtered_choices > 0 && selected_filtered_index > 0 )); then
                    selected_filtered_index=$((selected_filtered_index - 1))
                    if (( selected_filtered_index < list_scroll_offset )); then
                        list_scroll_offset=$selected_filtered_index
                    fi
                fi
                ;;
            $KEY_DOWN|j|J)
                if (( num_filtered_choices > 0 && selected_filtered_index < num_filtered_choices - 1 )); then
                    selected_filtered_index=$((selected_filtered_index + 1))
                    if (( selected_filtered_index >= list_scroll_offset + list_display_height )); then
                        list_scroll_offset=$((selected_filtered_index - list_display_height + 1))
                    fi
                fi
                ;;
            $KEY_PPAGE|339) # Page Up
                if (( num_filtered_choices > 0 )); then
                    selected_filtered_index=$((selected_filtered_index - list_display_height))
                    (( selected_filtered_index < 0 )) && selected_filtered_index=0
                    list_scroll_offset=$((list_scroll_offset - list_display_height))
                    (( list_scroll_offset < 0 )) && list_scroll_offset=0
                    if (( selected_filtered_index < list_scroll_offset )); then
                         list_scroll_offset=$selected_filtered_index
                    fi
                fi
                ;;
            $KEY_NPAGE|338) # Page Down
                if (( num_filtered_choices > 0 )); then
                    selected_filtered_index=$((selected_filtered_index + list_display_height))
                    (( selected_filtered_index >= num_filtered_choices )) && selected_filtered_index=$((num_filtered_choices - 1))
                    list_scroll_offset=$((list_scroll_offset + list_display_height))
                    local max_scroll=$((num_filtered_choices - list_display_height))
                    (( max_scroll < 0 )) && max_scroll=0
                    (( list_scroll_offset > max_scroll )) && list_scroll_offset=$max_scroll
                    if (( selected_filtered_index >= list_scroll_offset + list_display_height )); then
                        list_scroll_offset=$((selected_filtered_index - list_display_height + 1))
                        (( list_scroll_offset < 0 )) && list_scroll_offset=0
                    fi
                fi
                ;;
            $KEY_HOME|262) # Home
                if (( num_filtered_choices > 0 )); then
                    selected_filtered_index=0
                    list_scroll_offset=0
                fi
                ;;
            $KEY_END|358) # End
                if (( num_filtered_choices > 0 )); then
                    selected_filtered_index=$((num_filtered_choices - 1))
                    list_scroll_offset=$((num_filtered_choices - list_display_height))
                    (( list_scroll_offset < 0 )) && list_scroll_offset=0
                fi
                ;;

            # --- Selection ---
            $KEY_ENTER|10|13)
                if (( num_filtered_choices > 0 && selected_filtered_index < num_filtered_choices )); then
                    zcurses delwin "$filter_win"
                    print -rn -- "${filtered_choices[selected_filtered_index+1]}"
                    return 0
                fi
                ;;

            # --- Filter Input Editing ---
            $KEY_BACKSPACE|127|8)
                if (( filter_cursor_pos > 0 )); then
                    filter_query="${filter_query:0:$((filter_cursor_pos-1))}${filter_query:$filter_cursor_pos}"
                    (( filter_cursor_pos-- ))
                    _update_filtered_list
                fi
                ;;
            $KEY_DC|330) # Delete
                if (( filter_cursor_pos < ${#filter_query} )); then
                    filter_query="${filter_query:0:$filter_cursor_pos}${filter_query:$((filter_cursor_pos+1))}"
                    _update_filtered_list
                fi
                ;;
            # For simplicity, $KEY_LEFT & $KEY_RIGHT for filter input cursor not implemented here.
            # Assume cursor always at end of input for additions, or moves with backspace.

            # --- Cancellation ---
            27|q|Q) # Escape, q, Q
                zcurses delwin "$filter_win"
                return 130
                ;;
            
            # --- Printable Characters for Filter ---
            *)
                # This is a simplified way to handle printable chars.
                # A more robust method would check ranges or use `isprint` if available.
                if (( key_code >= 32 && key_code <= 126 )); then # Basic printable ASCII
                    local char_val=$(printf "\\$(printf '%03o' "$key_code")")
                    if [[ -n "$char_val" ]] && [[ ${#char_val} -eq 1 ]]; then
                        filter_query="${filter_query:0:$filter_cursor_pos}${char_val}${filter_query:$filter_cursor_pos}"
                        (( filter_cursor_pos += ${#char_val} ))
                        _update_filtered_list
                    fi
                fi
                ;;
        esac
    done
}

### [ Write (Multi-line Text Editor) ] ########################################
# Displays a multi-line text input area.
#
# Parameters:
#   $1: initial_content_string - String to populate the text area, newlines respected.
#
# Output to STDOUT:
#   The edited text content if the user confirms.
#
# Returns:
#   0 if the user confirms (e.g., Ctrl+D or Ctrl+S).
#   130 if the user cancels (e.g., Escape, 'q').
#
# Keybindings:
#   Ctrl+D or Ctrl+S: Save and exit.
#   Escape or 'q': Cancel and exit.
#   Arrow keys: Navigate text.
#   Enter: Insert newline.
#   Backspace: Delete char before cursor / merge lines.
#   Delete (KEY_DC): Delete char at cursor / merge lines.
zcurses_write() {
    local initial_content_string="$1"
    local -a lines=() # Array to hold each line of text
    local -i cursor_y=0 # Line number (0-indexed)
    local -i cursor_x=0 # Column number on the current line (0-indexed)
    local -i top_visible_line=0 # First line visible in the editor pane
    local -i left_visible_col=0  # First column visible for horizontal scrolling
    local -i key_code

    local -i editor_win_height editor_win_width
    local -i text_area_height text_area_width
    local -i line_number_width=0 # Width for line numbers (0 if disabled)
    local -i term_height term_width dialog_y dialog_x dialog_width dialog_height
    local write_win

    # --- Initialize lines array from initial_content_string ---
    # Split by newline. IFS is used to control splitting.
    local OLD_IFS="$IFS"
    IFS=$'\n'
    lines=(${(f)initial_content_string}) # (f) flag ensures empty lines are preserved
    IFS="$OLD_IFS"
    # If initial string is empty or ends with newline, lines array might need adjustment
    if [[ -z "$initial_content_string" ]] || [[ "$initial_content_string" == *$'\n' ]]; then
      # Ensure there's at least one empty line to start with if input is empty
      # or if it ends with a newline (which implies an empty line after it)
      [[ ${#lines[@]} -eq 0 || ( ${#lines[@]} -gt 0 && -n "${lines[-1]}" ) ]] && lines+=("")
    fi


    # --- Configuration (can be made dynamic later) ---
    local show_line_numbers=1 # Set to 1 to enable, 0 to disable
    if (( show_line_numbers )); then
        line_number_width=4 # e.g., "999|"
    fi

    # --- Calculate dialog dimensions ---
    term_height=$(tput lines)
    term_width=$(tput cols)

    dialog_width=$(( term_width * 9 / 10 ))  # 90% of term width
    dialog_height=$(( term_height * 9 / 10 )) # 90% of term height
    (( dialog_width < 60 )) && dialog_width=60   # Min width
    (( dialog_height < 10 )) && dialog_height=10 # Min height
    (( dialog_width > term_width - 2 )) && dialog_width=$((term_width - 2))
    (( dialog_height > term_height - 2 )) && dialog_height=$((term_height - 2))
    
    dialog_y=$(( (term_height - dialog_height) / 2 ))
    dialog_x=$(( (term_width - dialog_width) / 2 ))

    editor_win_height=$((dialog_height - 2)) # -2 for box borders
    editor_win_width=$((dialog_width - 2))
    text_area_height=$editor_win_height
    text_area_width=$((editor_win_width - line_number_width))

    zcurses newwin write_win $dialog_height $dialog_width $dialog_y $dialog_x
    keypad "$write_win" 1
    # zcurses cbreak "$write_win" # Potentially useful for Ctrl keys, but check compatibility

    # --- Main Loop ---
    while true; do
        zcurses erase "$write_win" # Clear the entire dialog window
        draw_box "write_win" 0 0 "$dialog_height" "$dialog_width" "rounded"
        
        # Adjust scrolling if cursor is out of view
        # Vertical scroll
        if (( cursor_y < top_visible_line )); then
            top_visible_line=$cursor_y
        elif (( cursor_y >= top_visible_line + text_area_height )); then
            top_visible_line=$((cursor_y - text_area_height + 1))
        fi
        # Horizontal scroll
        if (( cursor_x < left_visible_col )); then
            left_visible_col=$cursor_x
        elif (( cursor_x >= left_visible_col + text_area_width )); then
            left_visible_col=$((cursor_x - text_area_width + 1))
        fi

        # Display text area content
        local -i current_line_idx
        for (( i=0; i < text_area_height; i++ )); do
            current_line_idx=$((top_visible_line + i))
            if (( current_line_idx >= ${#lines[@]} )); then
                break # No more lines to draw
            fi

            local line_content="${lines[current_line_idx+1]}" # Zsh arrays are 1-indexed
            local display_line
            
            # Line numbers
            if (( show_line_numbers )); then
                local line_num_str="${(r:$((line_number_width-1)):: :)current_line_idx+1}|"
                zcurses move "$write_win" $((i+1)) 1 # +1 for box border
                zcurses string "$write_win" "$line_num_str"
            fi

            # Line content (with horizontal scrolling)
            display_line="${line_content:$left_visible_col:$text_area_width}"
            zcurses move "$write_win" $((i+1)) $((1 + line_number_width)) # +1 for box border
            zcurses string "$write_win" "$display_line"
            
            # Fill rest of the line within text_area_width if display_line is shorter
            local displayed_len=${#display_line}
            if (( displayed_len < text_area_width )); then
                zcurses string "$write_win" "${(pl:$((text_area_width - displayed_len)):: :)}"
            fi
        done

        # Set cursor position in the window
        # Window y = (cursor_y - top_visible_line) + 1 (for border)
        # Window x = (cursor_x - left_visible_col) + 1 (for border) + line_number_width
        zcurses move "$write_win" $((cursor_y - top_visible_line + 1)) $((cursor_x - left_visible_col + 1 + line_number_width))
        zcurses curs_set 1 # Show cursor

        zcurses refresh "$write_win"
        zcurses input -k "$write_win" key_code
        zcurses curs_set 0 # Hide cursor during processing

        # --- Key Handling ---
        case "$key_code" in
            # --- Navigation ---
            $KEY_UP)
                (( cursor_y > 0 )) && cursor_y=$((cursor_y - 1))
                # Adjust cursor_x if new line is shorter
                (( cursor_x > ${#lines[cursor_y+1]} )) && cursor_x=${#lines[cursor_y+1]}
                ;;
            $KEY_DOWN)
                (( cursor_y < ${#lines[@]} - 1 )) && cursor_y=$((cursor_y + 1))
                # Adjust cursor_x if new line is shorter
                (( cursor_x > ${#lines[cursor_y+1]} )) && cursor_x=${#lines[cursor_y+1]}
                ;;
            $KEY_LEFT)
                if (( cursor_x > 0 )); then
                    cursor_x=$((cursor_x - 1))
                elif (( cursor_y > 0 )); then # Move to end of previous line
                    cursor_y=$((cursor_y - 1))
                    cursor_x=${#lines[cursor_y+1]}
                fi
                ;;
            $KEY_RIGHT)
                if (( cursor_x < ${#lines[cursor_y+1]} )); then
                    cursor_x=$((cursor_x + 1))
                elif (( cursor_y < ${#lines[@]} - 1 )); then # Move to start of next line
                    cursor_y=$((cursor_y + 1))
                    cursor_x=0
                fi
                ;;
            
            # --- Editing ---
            $KEY_ENTER|10|13) # Enter
                local current_line_content="${lines[cursor_y+1]}"
                local first_part="${current_line_content:0:$cursor_x}"
                local second_part="${current_line_content:$cursor_x}"
                lines[cursor_y+1]="$first_part" # Update current line
                # Insert new line: zsh array slice and insert
                lines=(${lines[1,cursor_y+1]} "$second_part" ${lines[cursor_y+2,-1]})
                cursor_y=$((cursor_y + 1))
                cursor_x=0
                ;;
            $KEY_BACKSPACE|127|8) # Backspace
                if (( cursor_x > 0 )); then # Delete char before cursor
                    local current_line_content="${lines[cursor_y+1]}"
                    lines[cursor_y+1]="${current_line_content:0:$((cursor_x-1))}${current_line_content:$cursor_x}"
                    cursor_x=$((cursor_x - 1))
                elif (( cursor_y > 0 )); then # Merge with previous line
                    local prev_line_content="${lines[cursor_y]}" # This is y-1 in 0-indexed
                    local current_line_content="${lines[cursor_y+1]}"
                    cursor_x=${#prev_line_content}
                    lines[cursor_y]="${prev_line_content}${current_line_content}"
                    # Remove current line: zsh array slice
                    lines=(${lines[1,cursor_y]} ${lines[cursor_y+2,-1]})
                    cursor_y=$((cursor_y - 1))
                fi
                ;;
            $KEY_DC|330) # Delete
                local current_line_content="${lines[cursor_y+1]}"
                if (( cursor_x < ${#current_line_content} )); then # Delete char at cursor
                    lines[cursor_y+1]="${current_line_content:0:$cursor_x}${current_line_content:$((cursor_x+1))}"
                elif (( cursor_y < ${#lines[@]} - 1 )); then # Merge with next line
                    local next_line_content="${lines[cursor_y+2]}"
                    lines[cursor_y+1]="${current_line_content}${next_line_content}"
                    # Remove next line
                    lines=(${lines[1,cursor_y+1]} ${lines[cursor_y+3,-1]})
                fi
                ;;

            # --- Save & Exit ---
            # Ctrl+D is 4, Ctrl+S is 19 (common terminal raw codes)
            4|$KEY_CTRL_D|19|$KEY_CTRL_S) # Ctrl+D or Ctrl+S
                zcurses delwin "$write_win"
                local final_content
                final_content=$(IFS=$'\n'; echo "${lines[*]}")
                # Ensure final newline if last line is not empty or if original had it
                # This logic might need refinement based on desired exact output behavior
                if [[ -n "${lines[-1]}" ]] || ( [[ "$initial_content_string" == *$'\n' ]] && [[ ${#lines[@]} -eq 1 && -z "${lines[1]}" ]] ); then
                    # if the last line has content, or if the original string ended with \n and now it's just one empty line
                     if [[ "$initial_content_string" != "" || ${#lines[@]} -gt 1 || -n "${lines[1]}" ]]; then # Avoid double newline for purely empty initial and final
                        final_content+=$'\n'
                     fi
                fi
                # A simpler rule: always end with a newline if there's any content.
                # if [[ -n "$final_content" && "$final_content" != *$'\n' ]]; then
                #    final_content+=$'\n'
                # fi

                print -rn -- "$final_content"
                return 0
                ;;

            # --- Cancellation ---
            27|q|Q) # Escape, q, Q
                zcurses delwin "$write_win"
                return 130
                ;;

            # --- Printable Characters ---
            *)
                # Simplified: assumes key_code is ASCII if it's in printable range
                if (( key_code >= 32 && key_code <= 126 )) || (( key_code >= 128 )); then # Basic printable + extended
                    local char_val=$(printf "\\$(printf '%03o' "$key_code")")
                    # Check if char_val is a single valid character (might be multi-byte)
                    if [[ -n "$char_val" ]] && ([[ ${#char_val} -eq 1 ]] || ! [[ "$char_val" =~ "\\" ]]); then
                        local current_line_content="${lines[cursor_y+1]}"
                        lines[cursor_y+1]="${current_line_content:0:$cursor_x}${char_val}${current_line_content:$cursor_x}"
                        cursor_x=$((cursor_x + ${#char_val}))
                    fi
                fi
                ;;
        esac
    done
}

### [ Input Dialog ] ############################################################
# Displays an input dialog with a prompt and a text field.

### [ Choose Dialog ] ###########################################################
# Displays a dialog with a list of choices for the user to select from.
#
# Parameters:
#   $1: header_string - The message/header to display above the list.
#   $2...: choices    - The list of choices to display.
#
# Output to STDOUT:
#   The selected choice string if the user confirms with Enter.
#
# Returns:
#   0 if the user confirms with Enter.
#   1 if the list of choices is empty.
#   130 if the user cancels (e.g., 'q', 'Q', Escape).
zcurses_choose() {
    local header_string="$1"
    shift
    local -a choices=("$@")
    local -i num_choices=${#choices[@]}

    if (( num_choices == 0 )); then
        print -u2 "Error: zcurses_choose requires at least one choice."
        return 1
    fi

    local -i selected_index=0 # Current selected item index
    local -i scroll_offset=0  # For scrolling long lists
    local -i key_code
    local -i dialog_height
    local -i dialog_width
    local -i list_display_height # How many items can be shown at once
    local -i term_height term_width
    local -i dialog_y dialog_x
    local choose_win
    local -r cursor_char="❯ " # Or any other cursor/indicator

    # Calculate dialog dimensions
    term_height=$(tput lines)
    term_width=$(tput cols)

    # Dialog width: max of header length, longest choice + cursor, or a min width
    dialog_width=$(( ${#header_string} + 4 ))
    local longest_choice_len=0
    for choice in "${choices[@]}"; do
        (( ${#choice} > longest_choice_len )) && longest_choice_len=${#choice}
    done
    (( (longest_choice_len + ${#cursor_char} + 4) > dialog_width )) && dialog_width=$((longest_choice_len + ${#cursor_char} + 4))
    (( dialog_width < 30 )) && dialog_width=30 # Min width
    (( dialog_width > term_width - 4 )) && dialog_width=$((term_width - 4)) # Max width

    # Dialog height: header + list area + borders. List area is adaptive.
    list_display_height=$(( term_height / 2 )) # Use half terminal height for list
    (( list_display_height < 5 )) && list_display_height=5 # Min 5 items visible
    (( list_display_height > num_choices && num_choices > 0 )) && list_display_height=$num_choices
    dialog_height=$(( list_display_height + 4 )) # Header + list + top/bottom borders/padding
    (( dialog_height > term_height - 2 )) && dialog_height=$((term_height - 2)) # Max height
    list_display_height=$((dialog_height - 4)) # Recalculate based on final dialog_height

    # Calculate dialog position (centered)
    dialog_y=$(( (term_height - dialog_height) / 2 ))
    dialog_x=$(( (term_width - dialog_width) / 2 ))

    # Create a new window for the dialog
    zcurses newwin choose_win $dialog_height $dialog_width $dialog_y $dialog_x
    keypad "$choose_win" 1 # Enable special keys

    while true; do
        zcurses erase "$choose_win"
        draw_box "choose_win" 0 0 "$dialog_height" "$dialog_width" "rounded"

        # Display header (line 1, padded)
        local header_display_x=$(( (dialog_width - ${#header_string}) / 2 ))
        (( header_display_x < 1 )) && header_display_x=1
        zcurses move "$choose_win" 1 "$header_display_x"
        # Example: Use a color for header (assuming color pairs are set up)
        # zcurses attr "$choose_win" "COLOR_PAIR_BLUE_BOLD" # Replace with actual color attribute
        zcurses string "$choose_win" "$header_string"
        # zcurses attr "$choose_win" "normal"

        # Display choices
        local list_start_y=2 # Line below header
        for (( i=0; i < list_display_height; i++ )); do
            local current_item_index=$((scroll_offset + i))
            if (( current_item_index >= num_choices )); then
                break # No more items to display
            fi

            local display_y=$((list_start_y + i))
            local display_x=2 # Padding from left border
            zcurses move "$choose_win" "$display_y" "$display_x"

            local item_text="${choices[current_item_index+1]}" # Zsh arrays are 1-indexed
            local display_string

            if (( current_item_index == selected_index )); then
                zcurses attr "$choose_win" "reverse" # Highlight selected
                display_string="$cursor_char$item_text"
            else
                display_string="  $item_text" # Indent non-selected items to align with cursor
            fi
            
            # Truncate if too long for the window
            local max_item_width=$((dialog_width - 4)) # accounting for borders and padding
            if (( ${#display_string} > max_item_width )); then
                display_string="${display_string:0:$max_item_width}"
            fi

            zcurses string "$choose_win" "$display_string"
            (( current_item_index == selected_index )) && zcurses attr "$choose_win" "normal"
        done
        
        # Display scroll indicators if needed
        if (( scroll_offset > 0 )); then
            zcurses move "$choose_win" "$list_start_y" "$((dialog_width - 2))"
            zcurses string "$choose_win" "↑"
        fi
        if (( scroll_offset + list_display_height < num_choices )); then
            zcurses move "$choose_win" "$((list_start_y + list_display_height -1))" "$((dialog_width - 2))"
            zcurses string "$choose_win" "↓"
        fi

        zcurses refresh "$choose_win"
        zcurses input -k "$choose_win" key_code

        case "$key_code" in
            # Enter
            $KEY_ENTER|10|13)
                zcurses delwin "$choose_win"
                print -rn -- "${choices[selected_index+1]}"
                return 0
                ;;
            # Up arrow or 'k'
            $KEY_UP|k|K)
                (( selected_index > 0 )) && selected_index=$((selected_index - 1))
                # Adjust scroll offset if selection moves out of view upwards
                if (( selected_index < scroll_offset )); then
                    scroll_offset=$selected_index
                fi
                ;;
            # Down arrow or 'j'
            $KEY_DOWN|j|J)
                (( selected_index < num_choices - 1 )) && selected_index=$((selected_index + 1))
                # Adjust scroll offset if selection moves out of view downwards
                if (( selected_index >= scroll_offset + list_display_height )); then
                    scroll_offset=$((selected_index - list_display_height + 1))
                fi
                ;;
            # Page Up (KEY_PPAGE is usually 339)
            $KEY_PPAGE|339)
                selected_index=$((selected_index - list_display_height))
                (( selected_index < 0 )) && selected_index=0
                scroll_offset=$((scroll_offset - list_display_height))
                (( scroll_offset < 0 )) && scroll_offset=0
                if (( selected_index < scroll_offset )); then # Ensure selected is visible
                     scroll_offset=$selected_index
                fi
                ;;
            # Page Down (KEY_NPAGE is usually 338)
            $KEY_NPAGE|338)
                selected_index=$((selected_index + list_display_height))
                (( selected_index >= num_choices )) && selected_index=$((num_choices - 1))
                scroll_offset=$((scroll_offset + list_display_height))
                local max_scroll=$((num_choices - list_display_height))
                (( max_scroll < 0 )) && max_scroll=0 # handle case where num_choices < list_display_height
                (( scroll_offset > max_scroll )) && scroll_offset=$max_scroll
                if (( selected_index >= scroll_offset + list_display_height )); then # Ensure selected is visible
                    scroll_offset=$((selected_index - list_display_height + 1))
                    (( scroll_offset < 0 )) && scroll_offset=0
                fi
                ;;
            # Home key (KEY_HOME is usually 262)
            $KEY_HOME|262)
                selected_index=0
                scroll_offset=0
                ;;
            # End key (KEY_END is usually 358)
            $KEY_END|358)
                selected_index=$((num_choices - 1))
                scroll_offset=$((num_choices - list_display_height))
                (( scroll_offset < 0 )) && scroll_offset=0
                ;;
            # Escape, 'q', or 'Q'
            27|q|Q)
                zcurses delwin "$choose_win"
                return 130 # User cancellation
                ;;
        esac
    done
}

### [ Input Dialog ] ############################################################
# Displays an input dialog with a prompt and a text field.
#
# Parameters:
#   $1: prompt_string   - The message to display to the user.
#   $2: [default_value] - (Optional) The initial value for the input field.
#
# Output to STDOUT:
#   The entered text if the user confirms with Enter.
#
# Returns:
#   0 if the user confirms with Enter.
#   1 if the user cancels (e.g., Esc).
#   130 if 'q' or Ctrl+C is pressed (for consistency).
zcurses_input() {
    local prompt_string="$1"
    local input_value="${2:-}" # Default to empty if not provided
    local -i key_code
    local -i cursor_pos=${#input_value} # Cursor position within input_value
    local -i dialog_height=7 # Prompt, input field, borders
    local -i dialog_width
    local -i term_height term_width
    local -i dialog_y dialog_x
    local input_win
    local input_field_width
    local input_field_display_start=0 # For scrolling text within the field

    # Calculate dialog width
    dialog_width=$(( ${#prompt_string} + 10 )) # Initial estimate
    (( dialog_width < 40 )) && dialog_width=40  # Minimum width
    input_field_width=$(( dialog_width - 4 )) # Width of the actual input area

    # Get terminal dimensions
    term_height=$(tput lines)
    term_width=$(tput cols)

    # Calculate dialog position (centered)
    dialog_y=$(( (term_height - dialog_height) / 2 ))
    dialog_x=$(( (term_width - dialog_width) / 2 ))

    # Create a new window for the dialog
    zcurses newwin input_win $dialog_height $dialog_width $dialog_y $dialog_x
    keypad "$input_win" 1 # Enable special keys
    # zcurses cbreak "$input_win" # Process keys immediately (optional, can conflict with signals)

    while true; do
        zcurses erase "$input_win"
        draw_box "input_win" 0 0 "$dialog_height" "$dialog_width" "rounded"

        # Display prompt (first line, padded)
        local prompt_display_x=2
        zcurses move "$input_win" 2 "$prompt_display_x"
        zcurses string "$input_win" "$prompt_string"

        # Display input field (line below prompt)
        local input_field_y=4
        local input_field_x=2

        # Adjust display start if cursor is out of view
        if (( cursor_pos < input_field_display_start )); then
            input_field_display_start=$cursor_pos
        elif (( cursor_pos >= input_field_display_start + input_field_width )); then
            input_field_display_start=$((cursor_pos - input_field_width + 1))
        fi
        
        # Ensure input_field_display_start is not negative
        (( input_field_display_start < 0 )) && input_field_display_start=0

        # Get the visible part of the input_value
        local displayed_text="${input_value:$input_field_display_start:$input_field_width}"
        zcurses move "$input_win" "$input_field_y" "$input_field_x"
        
        # Print char by char to handle potential multi-byte characters and place cursor
        local current_x=$input_field_x
        for (( i=0; i < ${#displayed_text}; i++ )); do
            zcurses move "$input_win" "$input_field_y" "$current_x"
            zcurses addch "$input_win" "${displayed_text:$i:1}"
            (( current_x++ ))
        done
        
        # Fill remaining space in input field
        local fill_len=$(( input_field_width - ${#displayed_text} ))
        if (( fill_len > 0 )); then
            zcurses move "$input_win" "$input_field_y" "$current_x"
            zcurses string "$input_win" "${(pl:$fill_len:: :)}"
        fi

        # Place cursor at the correct position within the visible part
        zcurses move "$input_win" "$input_field_y" "$((input_field_x + cursor_pos - input_field_display_start))"
        zcurses curs_set 1 # Make cursor visible for input

        zcurses refresh "$input_win"
        zcurses input -k "$input_win" key_code # Get key code (integer)

        zcurses curs_set 0 # Make cursor invisible during processing

        case "$key_code" in
            # Enter
            $KEY_ENTER|10|13)
                zcurses delwin "$input_win"
                print -rn -- "$input_value" # Output to stdout
                return 0
                ;;
            # Backspace (KEY_BACKSPACE is usually 263, stty erase ^?)
            $KEY_BACKSPACE|127|8) # 127 for typical BSD/macOS, 8 for some Linux
                if (( cursor_pos > 0 )); then
                    input_value="${input_value:0:$((cursor_pos-1))}${input_value:$cursor_pos}"
                    (( cursor_pos-- ))
                fi
                ;;
            # Delete (KEY_DC is usually 330)
            $KEY_DC|330)
                if (( cursor_pos < ${#input_value} )); then
                    input_value="${input_value:0:$cursor_pos}${input_value:$((cursor_pos+1))}"
                fi
                ;;
            # Left arrow
            $KEY_LEFT)
                (( cursor_pos > 0 )) && (( cursor_pos-- ))
                ;;
            # Right arrow
            $KEY_RIGHT)
                (( cursor_pos < ${#input_value} )) && (( cursor_pos++ ))
                ;;
            # Home key (KEY_HOME is usually 262)
            $KEY_HOME|262)
                cursor_pos=0
                ;;
            # End key (KEY_END is usually 358)
            $KEY_END|358)
                cursor_pos=${#input_value}
                ;;
            # Escape key (usually 27) or 'q'
            27|q|Q)
                zcurses delwin "$input_win"
                return 1 # Standard cancel
                ;;
            # Ctrl+C (SIGINT - typically zsh/curses handles this by exiting script)
            # We might not catch this here if zsh/curses default handler exits first.
            # Add 'q' or other explicit quit bindings if needed.
            # For now, Esc is the primary cancel. A return code of 130 could be used for Ctrl+C if trapped.

            # Printable characters (heuristic: check if it's a single char and not special)
            *)
                # Attempt to convert key_code to character if it's likely a char code
                local char_val
                # This is a bit of a hack for zsh/curses; direct char input is complex
                # zcurses input -s reads string, but we want char by char
                # We assume key_code for printable chars are their ASCII values
                # This might not be robust for all terminals/locales
                if (( key_code >= 32 && key_code <= 126 )) || (( key_code >= 128 )); then # Basic printable ASCII + extended
                    # Convert integer key_code to character
                    char_val=$(printf "\\$(printf '%03o' "$key_code")")
                    if [[ -n "$char_val" ]] && [[ ${#char_val} -eq 1 || ${#char_val} -gt 1 && $char_val != *"\\"* ]]; then # Check if it's a single char
                        input_value="${input_value:0:$cursor_pos}${char_val}${input_value:$cursor_pos}"
                        (( cursor_pos += ${#char_val} ))
                    fi
                fi
                ;;
        esac
    done
}
