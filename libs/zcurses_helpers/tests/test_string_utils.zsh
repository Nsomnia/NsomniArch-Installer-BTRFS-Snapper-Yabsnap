#!/usr/bin/env zsh

# Ensure the utils script is sourced relative to this test script's directory
source "${0:A:h}/../_string_utils.zsh"

echo "Running tests for _string_utils.zsh..."
local all_tests_passed=true
local test_counter=1

run_test() {
    local description="$1"
    local command_to_run="$2"
    local expected_stdout="$3"
    local expected_exit_code="${4:-0}"

    echo "Test $test_counter: $description"
    ((test_counter++))
    
    local actual_stdout
    actual_stdout=$(eval "$command_to_run")
    local actual_exit_code=$?

    local pass=true
    if [[ "$actual_stdout" != "$expected_stdout" ]]; then
        echo "FAIL: Stdout mismatch."
        echo "Expected: '$expected_stdout'"
        echo "Got     : '$actual_stdout'"
        pass=false
    fi

    if (( actual_exit_code != expected_exit_code )); then
        echo "FAIL: Exit code mismatch. Expected: $expected_exit_code, Got: $actual_exit_code"
        pass=false
    fi
    
    if [[ "$pass" = true ]]; then echo "PASS"; else all_tests_passed=false; fi
    echo "------------------------------------"
}

# string_repeat
run_test "string_repeat: repeat char" "string_repeat x 3" "xxx"
run_test "string_repeat: repeat string" "string_repeat 'ab' 2" "abab"
run_test "string_repeat: repeat zero times" "string_repeat 'a' 0" ""
run_test "string_repeat: repeat with empty string" "string_repeat '' 5" ""

# string_pad_right
run_test "string_pad_right: basic padding" "string_pad_right 'abc' 5" "abc  "
run_test "string_pad_right: no padding needed" "string_pad_right 'abcde' 5" "abcde"
run_test "string_pad_right: text longer than width" "string_pad_right 'abcdef' 5" "abcdef"
run_test "string_pad_right: custom pad char" "string_pad_right 'hi' 4 '-'" "hi--"
run_test "string_pad_right: empty string" "string_pad_right '' 3 '.'" "..."

# string_pad_left
run_test "string_pad_left: basic padding" "string_pad_left 'abc' 5" "  abc"
run_test "string_pad_left: no padding needed" "string_pad_left 'abcde' 5" "abcde"
run_test "string_pad_left: text longer than width" "string_pad_left 'abcdef' 5" "abcdef"
run_test "string_pad_left: custom pad char" "string_pad_left 'hi' 4 '-'" "--hi"
run_test "string_pad_left: empty string" "string_pad_left '' 3 '.'" "..."

# string_align_center
run_test "string_align_center: even padding" "string_align_center 'abc' 7" "  abc  "
run_test "string_align_center: odd padding (left gets less typically, my impl gives more to right)" "string_align_center 'abc' 6" " abc  "
run_test "string_align_center: no padding needed" "string_align_center 'abc' 3" "abc"
run_test "string_align_center: text longer" "string_align_center 'abcdef' 3" "abcdef"
run_test "string_align_center: custom pad" "string_align_center 'x' 5 '-'" "--x--"
run_test "string_align_center: empty string" "string_align_center '' 3 '.'" "..."

# string_truncate
run_test "string_truncate: no truncation" "string_truncate 'hello' 10" "hello"
run_test "string_truncate: exact width" "string_truncate 'hello' 5" "hello"
run_test "string_truncate: basic truncation with default ellipsis" "string_truncate 'helloworld' 5" "hell…"
run_test "string_truncate: custom ellipsis" "string_truncate 'helloworld' 7 '***'" "hell***"
run_test "string_truncate: ellipsis longer than width, truncate ellipsis" "string_truncate 'hi' 2 '***'" "**" 
run_test "string_truncate: width allows only ellipsis" "string_truncate 'hello' 3 '***'" "***"
run_test "string_truncate: width smaller than ellipsis" "string_truncate 'hello' 1 '***'" "*"


if [[ "$all_tests_passed" = true ]]; then
    echo "All _string_utils.zsh tests passed."
    exit 0
else
    echo "Some _string_utils.zsh tests FAILED."
    exit 1
fi
