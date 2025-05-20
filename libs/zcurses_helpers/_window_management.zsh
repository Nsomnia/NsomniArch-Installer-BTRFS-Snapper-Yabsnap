#!/usr/bin/env zsh

# Load zsh/curses module. Callers should ensure zcurses is initialized/ended.
zmodload zsh/curses

# Function to create a new curses window
# Args: <win_var_name_str> <height> <width> <row> <col>
# Example: zc_create_window "my_win" 10 20 5 5
zc_create_window() {
    local win_var_name_str="$1"
    local height="$2"
    local width="$3"
    local row="$4"
    local col="$5"
    local win_handle

    zcurses newwin win_handle "$height" "$width" "$row" "$col"
    if (( $? != 0 )); then
        echo "Error: zcurses newwin failed." >&2
        return 1
    fi
    eval "$win_var_name_str=\"\$win_handle\"" 
    return 0
}

# Function to draw a box around a window
# Args: <win_var_name_str> [title]
# Example: zc_draw_box "my_win" "My Window"
zc_draw_box() {
    local win_var_name_str="$1"
    local title="${2:-}"
    local win_handle
    eval "win_handle=\"\$$win_var_name_str\"" 

    if [[ -z "$win_handle" ]]; then
        echo "Error: Window handle for '$win_var_name_str' is not set." >&2
        return 1
    fi

    if [[ -n "$title" ]]; then
        zcurses box "$win_handle" 0 0 t "$title"
    else
        zcurses box "$win_handle" 0 0
    fi
    return $?
}

# Function to clear a window
# Args: <win_var_name_str>
zc_clear_window() {
    local win_var_name_str="$1"
    local win_handle
    eval "win_handle=\"\$$win_var_name_str\""
    if [[ -z "$win_handle" ]]; then echo "Error: Window handle for '$win_var_name_str' not set." >&2; return 1; fi
    zcurses erase "$win_handle"
    return $?
}

# Function to refresh a window
# Args: <win_var_name_str>
zc_refresh_window() {
    local win_var_name_str="$1"
    local win_handle
    eval "win_handle=\"\$$win_var_name_str\""
    if [[ -z "$win_handle" ]]; then echo "Error: Window handle for '$win_var_name_str' not set." >&2; return 1; fi
    zcurses refresh "$win_handle"
    return $?
}
    
# Function to refresh the main screen (stdscr)
zc_refresh_stdscr() {
    zcurses refresh # Refreshes stdscr by default
    return $?
}

# Function to print text at a specific position within a window
# Args: <win_var_name_str> <row> <col> <text> [attr_array_name_str]
zc_print_at() {
    local win_var_name_str="$1"
    local row="$2"
    local col="$3"
    local text="$4"
    local attr_array_name_str="${5:-}"
    local win_handle
    eval "win_handle=\"\$$win_var_name_str\""

    if [[ -z "$win_handle" ]]; then echo "Error: Window handle for '$win_var_name_str' not set." >&2; return 1; fi

    zcurses move "$win_handle" "$row" "$col"
    if (( $? != 0 )); then return 1; fi

    if [[ -n "$attr_array_name_str" ]]; then
        local -a attrs_to_apply=() 
        local element # Temporary variable for the loop

        # Use eval to iterate over the elements of the array named by attr_array_name_str
        # and assign them to the local attrs_to_apply array.
        # This construction is safer for handling elements that might contain spaces or special characters.
        eval "for element in \"\${${attr_array_name_str}[@]}\"; do attrs_to_apply+=(\"\$element\"); done"

        if (( ${#attrs_to_apply} > 0 )); then
             local cmd="zcurses attr \"\$win_handle\""
             local attr_val
             for attr_val in "\${(@)attrs_to_apply}"; do # Iterate over the local copy
                 cmd+=" ${(q)attr_val}" # Quote each attribute for safety in the command string
             done
             eval "$cmd"
            if (( $? != 0 )); then 
                # Attempt to reset attributes if setting failed.
                zcurses attr "$win_handle" A_NORMAL 2>/dev/null 
                return 1;
            fi
        fi
    fi
    
    zcurses addstr "$win_handle" "$text"
    local add_status=$?
    
    # If attributes were applied, reset to normal. This is a common practice.
    if [[ -n "$attr_array_name_str" && ${#attrs_to_apply} -gt 0 ]]; then
       zcurses attr "$win_handle" A_NORMAL 2>/dev/null
    fi
    
    return $add_status
}
    
# Function to delete a window
# Args: <win_var_name_str>
zc_delete_window() {
    local win_var_name_str="$1"
    local win_handle
    eval "win_handle=\"\$$win_var_name_str\""
    if [[ -z "$win_handle" ]]; then echo "Error: Window handle for '$win_var_name_str' not set." >&2; return 1; fi
    zcurses delwin "$win_handle"
    if (( $? == 0 )); then
        eval "$win_var_name_str=''" 
    fi
    return $?
}

: # Ensure file is sourceable
