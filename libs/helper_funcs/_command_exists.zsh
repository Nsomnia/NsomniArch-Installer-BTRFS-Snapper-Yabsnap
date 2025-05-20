#!/usr/bin/env zsh

# Function to check if a command exists
# Usage: _command_exists <command_name>

_command_exists() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: Command '$1' not found." >&2
    return 1
  fi
  return 0
}
