#!/usr/bin/env zsh

source ../_unicode_chars.zsh

echo "Running tests for _unicode_chars.zsh..."
local all_tests_passed=true

assert_defined_and_not_empty() {
    local var_name="$1"
    # Check if the variable is defined and not empty
    if [[ -z "${(P)var_name}" ]]; then
        echo "FAIL: Variable ${var_name} is not defined or is empty."
        all_tests_passed=false
        return 1
    fi
    # Optionally, print the character to visually inspect if the terminal supports it
    # echo "INFO: ${var_name} = '${(P)var_name}'" 
    echo "PASS: Variable ${var_name} ('${(P)var_name}') is defined and not empty."
    return 0
}

# Test a selection of variables
assert_defined_and_not_empty "BOX_LIGHT_HORIZ"
assert_defined_and_not_empty "BOX_HEAVY_VERT"
assert_defined_and_not_empty "BOX_DOUBLE_DOWN_RIGHT"
assert_defined_and_not_empty "BOX_ROUNDED_UP_LEFT"
assert_defined_and_not_empty "SHADE_MEDIUM"
assert_defined_and_not_empty "SHADE_SOLID"
assert_defined_and_not_empty "SYMBOL_SPADES"
assert_defined_and_not_empty "SYMBOL_CHECKMARK"
assert_defined_and_not_empty "SYMBOL_ELLIPSIS"

if [[ "$all_tests_passed" = true ]]; then
    echo "All _unicode_chars.zsh tests passed."
    exit 0
else
    echo "Some _unicode_chars.zsh tests FAILED."
    exit 1
fi
