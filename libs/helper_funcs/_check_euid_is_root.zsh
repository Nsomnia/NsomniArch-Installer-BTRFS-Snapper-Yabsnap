#!/usr/bin/env zsh

# Function to check if the effective UID is 0 (root)
# Usage: _check_euid_is_root [euid_to_check]
# If no argument is provided, it defaults to current ${EUID}.

_check_euid_is_root() {
  local euid_to_check="${1:-${EUID}}" # Default to ${EUID} if no argument is given
  if [[ "${euid_to_check}" -ne 0 ]]; then
    echo "Error: Effective UID is ${euid_to_check}, not 0. Root privileges required." >&2
    return 1
  fi
  return 0
}
