#!/usr/bin/env zsh

# Source the function to be tested
source ../_check_euid_is_root.zsh

echo "Running tests for _check_euid_is_root..."
tests_passed=true

# Test case 1: Effective UID is 0 (root)
echo "Test 1: Effective UID is 0"
if _check_euid_is_root 0; then
  echo "PASS: _check_euid_is_root correctly returned 0 for EUID 0."
else
  echo "FAIL: _check_euid_is_root incorrectly returned non-zero for EUID 0."
  tests_passed=false
fi

# Test case 2: Effective UID is non-zero (non-root)
echo "Test 2: Effective UID is 1000"
if ! _check_euid_is_root 1000 >/dev/null 2>&1; then
  echo "PASS: _check_euid_is_root correctly returned non-zero for EUID 1000."
else
  echo "FAIL: _check_euid_is_root incorrectly returned 0 for EUID 1000."
  tests_passed=false
fi

# Test case 3: No argument (should use actual EUID, which is non-root in sandbox)
# This test assumes the sandbox runs as non-root.
echo "Test 3: No argument (defaults to actual EUID - expected non-root)"
if ! _check_euid_is_root >/dev/null 2>&1; then
    echo "PASS: _check_euid_is_root correctly returned non-zero when no argument is passed (ran as non-root)."
else
    echo "FAIL: _check_euid_is_root incorrectly returned 0 when no argument is passed (ran as non-root)."
    tests_passed=false
fi

# Test case 4: Check error message for non-root
echo "Test 4: Check error message for EUID 1000"
expected_error_msg="Error: Effective UID is 1000, not 0. Root privileges required."
actual_error_msg=$(_check_euid_is_root 1000 2>&1) # Capture stderr
if [[ "${actual_error_msg}" == "${expected_error_msg}" ]]; then
    echo "PASS: Correct error message for non-root EUID."
else
    echo "FAIL: Incorrect error message. Expected: '${expected_error_msg}', Got: '${actual_error_msg}'"
    tests_passed=false
fi


if [[ "${tests_passed}" = true ]]; then
  echo "All _check_euid_is_root tests passed."
  exit 0
else
  echo "Some _check_euid_is_root tests FAILED."
  exit 1
fi
