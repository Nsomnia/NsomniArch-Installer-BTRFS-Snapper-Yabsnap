#!/usr/bin/env zsh

# TUI String Manipulation Utilities

# Repeats a string a given number of times
# Args: <string_to_repeat> <count>
string_repeat() {
    local str="$1"
    local count="$2"
    local result=""
    integer i
    for ((i=0; i<count; i++)); do
        result+="$str"
    done
    echo "$result"
}

# Pads a string on the right to a certain width
# Args: <text> <width> [pad_char]
string_pad_right() {
    local text="$1"
    local width="$2"
    local pad_char="${3:- }" # Default padding character is space
    local text_len=${#text}
    local pad_len=$((width - text_len))

    if ((pad_len <= 0)); then
        echo "$text"
        return
    fi
    local padding
    padding=$(string_repeat "$pad_char" "$pad_len")
    echo "${text}${padding}"
}

# Pads a string on the left to a certain width
# Args: <text> <width> [pad_char]
string_pad_left() {
    local text="$1"
    local width="$2"
    local pad_char="${3:- }"
    local text_len=${#text}
    local pad_len=$((width - text_len))

    if ((pad_len <= 0)); then
        echo "$text"
        return
    fi
    local padding
    padding=$(string_repeat "$pad_char" "$pad_len")
    echo "${padding}${text}"
}

# Centers a string within a certain width
# Args: <text> <width> [pad_char]
string_align_center() {
    local text="$1"
    local width="$2"
    local pad_char="${3:- }"
    local text_len=${#text}
    local pad_total=$((width - text_len))

    if ((pad_total <= 0)); then
        echo "$text"
        return
    fi

    local pad_left=$((pad_total / 2))
    local pad_right=$((pad_total - pad_left))
    
    local left_padding
    left_padding=$(string_repeat "$pad_char" "$pad_left")
    local right_padding
    right_padding=$(string_repeat "$pad_char" "$pad_right")
    
    echo "${left_padding}${text}${right_padding}"
}

# Truncates a string to a max width, optionally adding an ellipsis
# Args: <text> <max_width> [ellipsis_char]
string_truncate() {
    local text="$1"
    local max_width="$2"
    local ellipsis="${3:-…}" # Default ellipsis is "…" (Unicode U+2026)

    # Condition 1: Ellipsis itself is too long for max_width.
    # In this case, the output can only be a truncated ellipsis.
    if (( ${#ellipsis} > max_width )); then
        echo "${ellipsis[1,max_width]}"
        return 0 # Success
    fi

    # Condition 2: Text fits, no ellipsis needed.
    if (( ${#text} <= max_width )); then
        echo "$text"
        return 0 # Success
    fi

    # Condition 3: Text needs truncation.
    # Now, ellipsis length is guaranteed to be <= max_width.
    local trunc_len=$((max_width - ${#ellipsis}))
    # Ensure trunc_len is not negative (e.g. if max_width is 0 and ellipsis is empty, though covered by Cond 1 if ellipsis is not empty)
    if (( trunc_len < 0 )); then 
        trunc_len=0
    fi

    echo "${text[1,trunc_len]}${ellipsis}"
    return 0 # Success
}

: # Ensure file is sourceable
