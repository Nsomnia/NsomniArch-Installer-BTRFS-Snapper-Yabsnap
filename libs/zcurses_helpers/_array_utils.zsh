#!/usr/bin/env zsh

# TUI Array Manipulation Utilities
# Revised: Modifying functions output the new array; caller reassigns.

# Get item at 1-based index. Outputs item or nothing if out of bounds.
# Args: <array_name_str> <index>
array_get_item() {
    setopt localoptions nonomatch 
    local array_name_str="$1"
    local index="$2"
    local -a target_array
    eval "target_array=("\${(@)${array_name_str}}")" 

    if (( index < 1 || index > ${#target_array[@]} )); then
        return 1 
    fi
    echo "${target_array[index]}"
    return 0
}

# Find 1-based index of the first occurrence of a value. Outputs index or 0 if not found.
# Args: <array_name_str> <value>
array_find_item() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local value="$2"
    local -a target_array
    eval "target_array=("\${(@)${array_name_str}}")"
    
    local i
    for i in {1..${#target_array[@]}}; do
        if [[ "${target_array[i]}" == "$value" ]]; then
            echo "$i"
            return 0
        fi
    done
    echo "0" 
    return 1
}
    
# Check if an array contains a specific value. Returns 0 if found, 1 if not. (Exit code only)
# Args: <array_name_str> <value>
array_contains_value() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local value="$2"
    local -a target_array
    eval "target_array=("\${(@)${array_name_str}}")"
    
    local element
    for element in "\${(@)target_array}"; do
        if [[ "$element" == "$value" ]]; then
            return 0 # Found
        fi
    done
    return 1 # Not found
}

# Convert a simple array to an associative array.
# Outputs a string that, when eval'd, declares and populates the associative array.
# Args: <source_array_name_str> <output_assoc_array_name_str>
# Example output: typeset -A my_assoc_output; my_assoc_output=(k1 v1 k2 v2 ...)
array_to_associative() {
    setopt localoptions nonomatch
    local source_array_name_str="$1"
    local output_assoc_name="$2" # Name for the output assoc array
    local -a source_array
    eval "source_array=("\${(@)${source_array_name_str}}")"
    
    local output_string="typeset -A $output_assoc_name; $output_assoc_name=("
    local i=1
    for item in "\${(@)source_array}"; do
        # Sanitize item for use as a value in the string
        local sanitized_item="${item//"/\"}" # Escape double quotes
        sanitized_item="${sanitized_item//\`/\\`}" # Escape backticks
        sanitized_item="${sanitized_item//\$/\\$}" # Escape dollar signs
        output_string+=" "$i" "$sanitized_item"" # Key is 1-based index
        ((i++))
    done
    output_string+=")"
    echo "$output_string"
    return 0
}

# Sort an array. Outputs the sorted array.
# Args: <array_name_str>
array_sort() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local -a temp_array
    eval "temp_array=("\${(@o)${array_name_str}}")" 
    echo "\${(@)temp_array}" 
}

# Sort an array in reverse order. Outputs the sorted array.
# Args: <array_name_str>
array_sort_reverse() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local -a temp_array
    eval "temp_array=("\${(@Oo)${array_name_str}}")" 
    echo "\${(@)temp_array}"
}
    
# Reverse the order of elements in an array. Outputs the reversed array.
# Args: <array_name_str>
array_reverse_order() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local -a current_array
    eval "current_array=("\${(@)${array_name_str}}")"
    
    local -a reversed_array
    local i
    for ((i=${#current_array[@]}; i>=1; i--)); do
        reversed_array+=("${current_array[i]}")
    done
    echo "\${(@)reversed_array}"
}

# Remove element at 1-based index. Outputs the modified array.
# Args: <array_name_str> <index>
array_remove_by_index() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local index="$2"
    local -a current_array
    eval "current_array=("\${(@)${array_name_str}}")"

    if (( index < 1 || index > ${#current_array[@]} )); then
         # Output original array if index is bad, and return error
        echo "\${(@)current_array}"
        return 1 
    fi
    unset "current_array[index]"
    echo "\${(@)current_array}" # Array after unsetting (auto-reindexed by echo)
    return 0
}

# Remove first occurrence of a value. Outputs the modified array.
# Args: <array_name_str> <value>
array_remove_by_value() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local value_to_remove="$2"
    local -a current_array
    eval "current_array=("\${(@)${array_name_str}}")"
    
    local i
    local found=0
    for i in {1..${#current_array[@]}}; do
        if [[ "${current_array[i]}" == "$value_to_remove" ]]; then
            unset "current_array[i]"
            found=1
            break
        fi
    done
    
    echo "\${(@)current_array}" # Output array (modified or original if not found)
    if (( found == 0 )); then return 1; fi # Value not found
    return 0
}

# Add element at the beginning of the array. Outputs the modified array.
# Args: <array_name_str> <value>
array_add_at_start() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local value="$2"
    local -a current_array
    eval "current_array=("\${(@)${array_name_str}}")"
    current_array=("$value" "\${(@)current_array}") 
    echo "\${(@)current_array}"
}

# Add element at the end of the array. Outputs the modified array.
# Args: <array_name_str> <value>
array_add_at_end() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local value="$2"
    local -a current_array
    eval "current_array=("\${(@)${array_name_str}}")"
    current_array+=("$value") 
    echo "\${(@)current_array}"
}
    
# Add element at a specific 1-based index. Outputs the modified array.
# Args: <array_name_str> <index> <value>
array_add_at_index() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local index="$2"
    local value="$3"
    local -a current_array
    eval "current_array=("\${(@)${array_name_str}}")"

    if (( index < 1 || index > ${#current_array[@]} + 1 )); then
        echo "\${(@)current_array}" # Output original on error
        return 1 
    fi

    local -a new_array
    if (( index == 1 )); then
        new_array=("$value" "\${(@)current_array}")
    elif (( index > ${#current_array[@]} )); then 
        new_array=("\${(@)current_array}" "$value")
    else
        new_array=("\${(@)current_array[1,index-1]}" "$value" "\${(@)current_array[index,-1]}")
    fi
    echo "\${(@)new_array}"
    return 0
}

# Get unique elements from an array. Outputs the unique array.
# Args: <array_name_str>
array_unique() {
    setopt localoptions nonomatch
    local array_name_str="$1"
    local -a current_array
    eval "current_array=("\${(@)${array_name_str}}")"
    
    typeset -aU unique_temp_array 
    unique_temp_array=("${(@)current_array}") 
    
    echo "\${(@)unique_temp_array}"
}
    
:
