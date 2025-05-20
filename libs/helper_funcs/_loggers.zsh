#!/usr/bin/env zsh

# Logging functions with color support
# Usage:
# _info "This is an info message"
# _success "This is a success message"
# _warning "This is a warning message"
# _error "This is an error message"

# Define colors
COLOR_RESET="\e[0m"
COLOR_INFO="\e[0;34m"    # Blue
COLOR_SUCCESS="\e[0;32m" # Green
COLOR_WARNING="\e[0;33m" # Yellow
COLOR_ERROR="\e[0;31m"   # Red

_info() {
  echo -e "${COLOR_INFO}[INFO] ${1}${COLOR_RESET}"
}

_success() {
  echo -e "${COLOR_SUCCESS}[SUCCESS] ${1}${COLOR_RESET}"
}

_warning() {
  echo -e "${COLOR_WARNING}[WARNING] ${1}${COLOR_RESET}"
}

_error() {
  echo -e "${COLOR_ERROR}[ERROR] ${1}${COLOR_RESET}" >&2
}
