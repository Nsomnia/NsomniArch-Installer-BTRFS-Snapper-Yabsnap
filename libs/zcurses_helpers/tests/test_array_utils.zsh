#!/usr/bin/env zsh

source ../_array_utils.zsh

echo "Running tests for _array_utils.zsh..."
local all_tests_passed=true
local test_counter=1

# Helper to run a test
run_test() {
    setopt localoptions nonomatch # Mitigate issues with NOMATCH option in this test helper
    local description="$1"
    local command_to_run="$2"
    local expected_stdout="${3:-}"
    local expected_array_state_str="${4:-}" # e.g., "arr=(a b c)"
    local target_array_name_for_state_check="${5:-}" # e.g., "my_arr"

    echo "Test $test_counter: $description"
    ((test_counter++))
    
    local actual_stdout
    # For commands that modify arrays, they don't produce stdout.
    # For commands that retrieve values, they echo to stdout.
    # Eval the command. If it's an assignment or void function, actual_stdout will be empty.
    actual_stdout=$(eval "$command_to_run")
    local exit_code=$? # Capture exit code of the eval'd command

    local pass=true
    # Check stdout only if expected_stdout is provided.
    # This allows tests for functions that only modify arrays and return no stdout.
    if [[ -n "$expected_stdout" ]]; then
        if [[ "$actual_stdout" != "$expected_stdout" ]]; then
            echo "FAIL: Stdout mismatch. Expected: '$expected_stdout', Got: '$actual_stdout'"
            pass=false
        fi
    elif [[ -z "$expected_stdout" && -n "$actual_stdout" && "$command_to_run" != array_contains_value* && "$command_to_run" != array_to_associative* ]]; then
        # If expected_stdout is empty, typically means no output.
        # However, some functions like array_contains_value might echo on success/failure if not carefully constructed.
        # The current array_contains_value returns 0/1, doesn't echo.
        # array_to_associative also doesn't echo.
        # So, if expected is empty and actual is not, it's usually a failure unless it's a specific case.
        # For now, let's assume empty expected means empty actual.
        # This part of the condition might need refinement if tests are tricky.
        # The original test for array_contains_value expects "found" or "not_found", so expected_stdout is not empty.
        # The original test for array_to_associative expects specific grep'd output.
        # Let's refine: if expected_stdout is explicitly given as "", then actual_stdout must be "".
        if [[ "$expected_stdout" == "" && "$actual_stdout" != "" ]]; then
             echo "FAIL: Expected empty stdout, Got: '$actual_stdout'"
             pass=false
        fi
    fi

    # Check array state if requested
    if [[ -n "$target_array_name_for_state_check" && -n "$expected_array_state_str" ]]; then
        local current_array_state_str
        # Construct what the array content should look like, e.g., "(a b c)"
        local expected_values_part="${expected_array_state_str#*=}" 
        
        local actual_array_values_str
        # Get the actual array content as a string like "(elem1 elem2 elem3)"
        eval "actual_array_values_str=\"(\${(@)${target_array_name_for_state_check}})\""

        if [[ "$actual_array_values_str" != "$expected_values_part" ]]; then
            echo "FAIL: Array state mismatch for $target_array_name_for_state_check."
            echo "Expected content: $expected_values_part"
            echo "Actual content  : $actual_array_values_str"
            pass=false
        fi
    fi
    
    # Also consider exit codes for functions that signal error via non-zero exit
    # e.g., array_get_item out of bounds should return 1.
    # This is not fully implemented in all test calls yet.
    # Example: if description contains "out of bounds", expect exit_code != 0

    if [[ "$pass" = true ]]; then
        echo "PASS"
    else
        all_tests_passed=false
    fi
    echo "------------------------------------"
}

# Initialize test arrays
typeset -a my_arr=("apple" "banana" "cherry")
typeset -a num_arr=(30 10 20)
typeset -a dup_arr=("foo" "bar" "foo" "baz" "bar" "bar")

# Tests for array_get_item
run_test "array_get_item: get existing item" "array_get_item my_arr 2" "banana"
run_test "array_get_item: get first item" "array_get_item my_arr 1" "apple"
run_test "array_get_item: get last item" "array_get_item my_arr 3" "cherry"
# For out of bounds, the function returns 1 and echoes nothing.
# The run_test helper needs to be smarter or tests need to check $?
# For now, expecting empty stdout is the main check.
run_test "array_get_item: out of bounds (upper)" "array_get_item my_arr 4" "" 
run_test "array_get_item: out of bounds (lower)" "array_get_item my_arr 0" "" 

# Tests for array_find_item
run_test "array_find_item: find existing" "array_find_item my_arr banana" "2"
run_test "array_find_item: find non-existing" "array_find_item my_arr grape" "0"
run_test "array_find_item: find in numeric" "array_find_item num_arr 10" "2"

# Tests for array_contains_value
# array_contains_value returns 0 for found, 1 for not found. It does not echo.
# The test command needs to echo based on return code.
my_arr_contains=("apple" "banana")
run_test "array_contains_value: existing" "array_contains_value my_arr_contains banana && echo found" "found"
run_test "array_contains_value: non-existing" "array_contains_value my_arr_contains grape || echo not_found" "not_found"

# Tests for array_to_associative
typeset -a assoc_src_arr=("one" "two")
# The old test for array_to_associative was problematic due to typeset -p order.
# New test checks content directly.
echo "Test $test_counter: array_to_associative (content check)"
((test_counter++))
typeset -A check_assoc # Ensure it's declared for this scope
array_to_associative assoc_src_arr check_assoc # Function populates test_assoc_result
if [[ "${check_assoc[1]}" == "one" && "${check_assoc[2]}" == "two" && ${#check_assoc[@]} -eq 2 ]]; then
    echo "PASS"
else
    echo "FAIL: Associative array content mismatch."
    typeset -p check_assoc # Print details on failure
    all_tests_passed=false
fi
echo "------------------------------------"


# Tests for array_sort (modifies array, no stdout)
sort_arr=(c b a)
run_test "array_sort: sort strings" "array_sort sort_arr" "" "(a b c)" "sort_arr"
sort_num_arr=(3 1 2) # Numbers sort lexicographically by default with (o)
run_test "array_sort: sort numbers (lexicographical)" "array_sort sort_num_arr" "" "(1 2 3)" "sort_num_arr"

# Tests for array_sort_reverse (modifies array, no stdout)
sort_rev_arr=(a b c)
run_test "array_sort_reverse: sort strings desc" "array_sort_reverse sort_rev_arr" "" "(c b a)" "sort_rev_arr"
sort_rev_num_arr=(1 3 2)
run_test "array_sort_reverse: sort numbers desc (lexicographical)" "array_sort_reverse sort_rev_num_arr" "" "(3 2 1)" "sort_rev_num_arr"

# Tests for array_reverse_order (modifies array, no stdout)
rev_ord_arr=(a b c d)
run_test "array_reverse_order: reverse elements" "array_reverse_order rev_ord_arr" "" "(d c b a)" "rev_ord_arr"

# Tests for array_remove_by_index (modifies array, no stdout)
rem_idx_arr=(x y z)
run_test "array_remove_by_index: remove middle" "array_remove_by_index rem_idx_arr 2" "" "(x z)" "rem_idx_arr"
rem_idx_arr2=(x y z)
run_test "array_remove_by_index: remove first" "array_remove_by_index rem_idx_arr2 1" "" "(y z)" "rem_idx_arr2"
rem_idx_arr3=(x y z)
run_test "array_remove_by_index: remove last" "array_remove_by_index rem_idx_arr3 3" "" "(x y)" "rem_idx_arr3"

# Tests for array_remove_by_value (modifies array, no stdout)
rem_val_arr=(alfa bravo charlie bravo delta)
run_test "array_remove_by_value: remove existing (first bravo)" "array_remove_by_value rem_val_arr bravo" "" "(alfa charlie bravo delta)" "rem_val_arr"
# Test removing non-existing value (array should not change)
typeset -a rem_val_arr_nochange=("echo" "foxtrot")
run_test "array_remove_by_value: remove non-existing" "array_remove_by_value rem_val_arr_nochange golf" "" "(echo foxtrot)" "rem_val_arr_nochange"


# Tests for array_add_at_start (modifies array, no stdout)
add_start_arr=(b c)
run_test "array_add_at_start: add to existing" "array_add_at_start add_start_arr a" "" "(a b c)" "add_start_arr"
typeset -a add_start_empty_arr=()
run_test "array_add_at_start: add to empty" "array_add_at_start add_start_empty_arr x" "" "(x)" "add_start_empty_arr"

# Tests for array_add_at_end (modifies array, no stdout)
add_end_arr=(a b)
run_test "array_add_at_end: add to existing" "array_add_at_end add_end_arr c" "" "(a b c)" "add_end_arr"
typeset -a add_end_empty_arr=()
run_test "array_add_at_end: add to empty" "array_add_at_end add_end_empty_arr x" "" "(x)" "add_end_empty_arr"

# Tests for array_add_at_index (modifies array, no stdout)
add_idx_arr=(a c d)
run_test "array_add_at_index: insert middle" "array_add_at_index add_idx_arr 2 b" "" "(a b c d)" "add_idx_arr"
add_idx_arr2=(b c)
run_test "array_add_at_index: insert beginning" "array_add_at_index add_idx_arr2 1 a" "" "(a b c)" "add_idx_arr2"
add_idx_arr3=(a b)
run_test "array_add_at_index: insert end (index is size+1)" "array_add_at_index add_idx_arr3 3 c" "" "(a b c)" "add_idx_arr3"


# Tests for array_unique (modifies array, no stdout)
uniq_arr=(a b a c b b d)
# Zsh's typeset -U preserves first seen order: a, b, c, d
run_test "array_unique: make unique" "array_unique uniq_arr" "" "(a b c d)" "uniq_arr"
uniq_arr2=(x x x)
run_test "array_unique: all same" "array_unique uniq_arr2" "" "(x)" "uniq_arr2"

# Omitted array_change_index test as function is marked complex/omitted in _array_utils.zsh

if [[ "$all_tests_passed" = true ]]; then
    echo "All _array_utils.zsh tests passed."
    exit 0
else
    echo "Some _array_utils.zsh tests FAILED."
    exit 1
fi
