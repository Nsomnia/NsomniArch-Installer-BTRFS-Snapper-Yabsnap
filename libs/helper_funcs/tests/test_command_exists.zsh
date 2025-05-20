#!/usr/bin/env zsh

# Source the function to be tested
source ../_command_exists.zsh

# Test case 1: Command that exists (e.g., 'ls')
echo "Test 1: Checking for existing command 'ls'"
if _command_exists ls; then
  echo "PASS: _command_exists correctly found 'ls'."
else
  echo "FAIL: _command_exists did not find 'ls'."
  exit 1
fi

# Test case 2: Command that does not exist
echo "Test 2: Checking for non-existing command 'nonexistentcommand123'"
if _command_exists nonexistentcommand123 >/dev/null 2>&1; then
  echo "FAIL: _command_exists did not return error for 'nonexistentcommand123'."
  exit 1
else
  echo "PASS: _command_exists correctly returned error for 'nonexistentcommand123'."
fi

# Test case 3: Ensure error message for non-existing command
echo "Test 3: Checking error message for non-existing command"
expected_error_msg="Error: Command 'nonexistentcommand123' not found."
actual_error_msg=$(_command_exists nonexistentcommand123 2>&1) # Capture stderr
if [[ "${actual_error_msg}" == "${expected_error_msg}" ]]; then
    echo "PASS: Correct error message for non-existing command."
else
    echo "FAIL: Incorrect error message. Expected: '${expected_error_msg}', Got: '${actual_error_msg}'"
    exit 1
fi

echo "All _command_exists tests passed."
exit 0
