#!/usr/bin/env zsh

# Source the functions to be tested
source ../_loggers.zsh

exit_code=0

echo "Test 1: Checking _info logger"
expected_info_msg=$'\e[0;34m[INFO] Test info message\e[0m'
actual_info_msg=$(_info "Test info message")
if [[ "${actual_info_msg}" == "${expected_info_msg}" ]]; then
  echo "PASS: _info logger produced correct output."
else
  echo "FAIL: _info logger produced incorrect output."
  echo "Expected: '${expected_info_msg}'"
  echo "Actual:   '${actual_info_msg}'"
  exit_code=1
fi

echo "Test 2: Checking _success logger"
expected_success_msg=$'\e[0;32m[SUCCESS] Test success message\e[0m'
actual_success_msg=$(_success "Test success message")
if [[ "${actual_success_msg}" == "${expected_success_msg}" ]]; then
  echo "PASS: _success logger produced correct output."
else
  echo "FAIL: _success logger produced incorrect output."
  echo "Expected: '${expected_success_msg}'"
  echo "Actual:   '${actual_success_msg}'"
  exit_code=1
fi

echo "Test 3: Checking _warning logger"
expected_warning_msg=$'\e[0;33m[WARNING] Test warning message\e[0m'
actual_warning_msg=$(_warning "Test warning message")
if [[ "${actual_warning_msg}" == "${expected_warning_msg}" ]]; then
  echo "PASS: _warning logger produced correct output."
else
  echo "FAIL: _warning logger produced incorrect output."
  echo "Expected: '${expected_warning_msg}'"
  echo "Actual:   '${actual_warning_msg}'"
  exit_code=1
fi

echo "Test 4: Checking _error logger (stderr)"
expected_error_msg=$'\e[0;31m[ERROR] Test error message\e[0m'
actual_error_msg=$(_error "Test error message" 2>&1) 
if [[ "${actual_error_msg}" == "${expected_error_msg}" ]]; then
  echo "PASS: _error logger produced correct output to stderr."
else
  echo "FAIL: _error logger produced incorrect output to stderr."
  echo "Expected: '${expected_error_msg}'"
  echo "Actual:   '${actual_error_msg}'"
  exit_code=1
fi

echo "Test 5: Checking _error logger (stdout)"
actual_error_stdout=$(_error "Test error message" 2>/dev/null)
if [[ -z "${actual_error_stdout}" ]]; then
    echo "PASS: _error logger did not output to stdout."
else
    echo "FAIL: _error logger outputted to stdout: ${actual_error_stdout}"
    exit_code=1
fi

if [[ $exit_code -eq 0 ]]; then
    echo "All _loggers tests passed."
else
    echo "_loggers tests failed."
fi
exit $exit_code
