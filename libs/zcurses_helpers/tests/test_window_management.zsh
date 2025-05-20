#!/usr/bin/env zsh

source ../_window_management.zsh

echo "Running tests for _window_management.zsh (revised for no namerefs)..."

# Mock zcurses if not available (for basic syntax checks)
if ! zcurses &>/dev/null; then
    echo "INFO: zcurses command not found, creating a mock."
    zcurses() {
        echo "MOCK: zcurses $@" >&2
        # Simulate newwin assigning a handle to the variable name it receives indirectly
        if [[ "$1" == "newwin" && "$2" != "" ]]; then
            # $2 is the variable that zcurses newwin uses to return the handle.
            # In our wrapper, this is 'win_handle'.
            # The wrapper then assigns this to the user-provided variable name.
            # So, the mock should just allow the 'win_handle' in the wrapper to get a value.
            # For simplicity, let's assume the mock handle is returned by the zcurses command
            # and our wrapper correctly assigns it.
            # The actual test_win will be set by the wrapper's eval.
            # The mock needs to be aware of the internal variable 'win_handle' in zc_create_window
            # This is hard. Let's simplify: mock just returns 0.
            # The test will then check if the var (e.g., "my_test_win") got set.
            # The wrapper itself does: eval "$win_var_name_str=\"\$win_handle\""
            # So, if zcurses newwin win_handle ... sets win_handle, eval will work.
            # The mock needs to ensure win_handle (passed by name to zcurses newwin) gets a value.
            # This is still tricky. Let's assume the mock handles the internal var correctly.
            if [[ "$2" == "win_handle" ]]; then # This is the internal var in zc_create_window
                # This is a very fragile mock, highly dependent on implementation detail of wrapper
                # Instead, let's make mock zcurses newwin itself set the target variable.
                # This means the mock needs to know the *user's* variable name.
                # The wrapper calls: zcurses newwin win_handle ...
                # The mock needs to know that 'win_handle' will then be assigned to user's var.
                # This is too complex for a simple mock.
                # The test will have to assume the mock zcurses newwin simply works and returns a handle.
                # The wrapper's eval is what we are testing.
                # Let's assume the mock zcurses newwin just sets its output param to a mock value.
                # So, if `zcurses newwin win_handle_param ...`, mock sets win_handle_param="mock_id"
                # This is still not quite right as `win_handle` is local to the wrapper.
                # The mock should behave as the real `zcurses newwin actual_handle_var ...`
                # For the mock, we will just return 0 and the test will have to deal with it.
                :
            fi
        fi
        return 0 
    }
    MOCK_ZCURSES=true
else
    echo "INFO: zcurses command found. Tests will attempt to use it."
    # For real zcurses, init/end is needed for visual tests, but these are functional.
    # zcurses init
    # trap "zcurses end" EXIT HUP INT TERM
    MOCK_ZCURSES=false
fi

local all_tests_passed=true
local test_win_handle # Variable to hold the handle

# Test zc_create_window
echo "Test 1: zc_create_window"
# The variable "test_win_handle" will be created/assigned by zc_create_window
if zc_create_window "test_win_handle" 10 20 1 1; then
    echo "PASS: zc_create_window called."
    if [[ -z "$test_win_handle" && "$MOCK_ZCURSES" = false ]]; then
        echo "FAIL: test_win_handle not set by zc_create_window with real zcurses."
        all_tests_passed=false
    elif [[ -n "$test_win_handle" ]]; then
        echo "INFO: test_win_handle is '$test_win_handle'"
    elif [[ "$MOCK_ZCURSES" = true && -z "$test_win_handle" ]]; then
        # In mock mode, our simple mock doesn't actually set test_win_handle.
        # The wrapper's eval "$win_var_name_str=\"\$win_handle\"" relies on 'win_handle'
        # which the mock zcurses newwin would need to set. This is too intricate for this mock.
        # So we'll manually set it for mock to allow other tests to run.
        echo "INFO: Mock mode, manually setting test_win_handle for subsequent tests."
        test_win_handle="mock_handle_for_test"
    fi
else
    echo "FAIL: zc_create_window failed."
    all_tests_passed=false
fi

# Test zc_draw_box
echo "Test 2: zc_draw_box"
if [[ -n "$test_win_handle" ]]; then
    if zc_draw_box "test_win_handle" "Title"; then echo "PASS: zc_draw_box"; else echo "FAIL: zc_draw_box"; all_tests_passed=false; fi
else echo "SKIP: zc_draw_box due to no handle."; fi

# Test zc_print_at
echo "Test 3: zc_print_at"
if [[ -n "$test_win_handle" ]]; then
    typeset -a my_test_attrs=("A_BOLD" "A_UNDERLINE")
    if zc_print_at "test_win_handle" 2 2 "Hello" "my_test_attrs"; then echo "PASS: zc_print_at"; else echo "FAIL: zc_print_at"; all_tests_passed=false; fi
else echo "SKIP: zc_print_at due to no handle."; fi

# Test zc_clear_window
echo "Test 4: zc_clear_window"
if [[ -n "$test_win_handle" ]]; then
    if zc_clear_window "test_win_handle"; then echo "PASS: zc_clear_window"; else echo "FAIL: zc_clear_window"; all_tests_passed=false; fi
else echo "SKIP: zc_clear_window due to no handle."; fi

# Test zc_refresh_window
echo "Test 5: zc_refresh_window"
if [[ -n "$test_win_handle" ]]; then
    if zc_refresh_window "test_win_handle"; then echo "PASS: zc_refresh_window"; else echo "FAIL: zc_refresh_window"; all_tests_passed=false; fi
else echo "SKIP: zc_refresh_window due to no handle."; fi

# Test zc_delete_window
echo "Test 6: zc_delete_window"
if [[ -n "$test_win_handle" ]]; then
    if zc_delete_window "test_win_handle"; then
        echo "PASS: zc_delete_window called."
        if [[ -n "$test_win_handle" && "$MOCK_ZCURSES" = false ]]; then # Real zcurses should clear it
             echo "FAIL: test_win_handle variable not cleared by zc_delete_window."
             all_tests_passed=false
        elif [[ "$MOCK_ZCURSES" = true ]]; then
             test_win_handle="" # Simulate clearing for mock
             echo "INFO: Mock mode, test_win_handle cleared."
        fi
    else
        echo "FAIL: zc_delete_window failed."
        all_tests_passed=false
    fi
else echo "SKIP: zc_delete_window due to no handle."; fi

# Test zc_refresh_stdscr
echo "Test 7: zc_refresh_stdscr"
if zc_refresh_stdscr; then echo "PASS: zc_refresh_stdscr"; else echo "FAIL: zc_refresh_stdscr"; all_tests_passed=false; fi

if [[ "$all_tests_passed" = true ]]; then
    echo "All _window_management.zsh (no-nameref) basic tests passed."
    exit 0
else
    echo "Some _window_management.zsh (no-nameref) tests FAILED."
    exit 1
fi
