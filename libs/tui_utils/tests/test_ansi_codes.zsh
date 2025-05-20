#!/usr/bin/env zsh

source ../_ansi_codes.zsh

echo "Running tests for _ansi_codes.zsh..."
local all_tests_passed=true

# Test if a few key variables are defined and have expected prefixes
assert_defined_and_prefix() {
    local var_name="$1"
    local expected_prefix="$2"
    # Check if the variable is defined (has a value)
    if [[ -z "${(P)var_name}" ]]; then
        echo "FAIL: Variable ${var_name} is not defined."
        all_tests_passed=false
        return 1
    fi
    # Check if the variable starts with the expected prefix
    if [[ "${(P)var_name}" != "${expected_prefix}"* ]]; then
        echo "FAIL: Variable ${var_name} ('${(P)var_name}') does not start with prefix '${expected_prefix}'."
        all_tests_passed=false
        return 1
    fi
    echo "PASS: Variable ${var_name} is defined and has correct prefix."
    return 0
}

assert_defined_and_prefix "ANSI_RESET" "\e[0m"
assert_defined_and_prefix "ANSI_BOLD" "\e[1m"
assert_defined_and_prefix "ANSI_FG_RED" "\e[31m"
assert_defined_and_prefix "ANSI_BG_GREEN" "\e[42m"
assert_defined_and_prefix "ANSI_FG_BRIGHT_BLUE" "\e[94m"
assert_defined_and_prefix "ANSI_BG_BRIGHT_YELLOW" "\e[103m"


if [[ "$all_tests_passed" = true ]]; then
    echo "All _ansi_codes.zsh tests passed."
    exit 0
else
    echo "Some _ansi_codes.zsh tests FAILED."
    exit 1
fi
