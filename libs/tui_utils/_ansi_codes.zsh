#!/usr/bin/env zsh

# ANSI Escape Codes

# Reset all attributes
ANSI_RESET='\e[0m'

# Text Attributes
ANSI_BOLD='\e[1m'
ANSI_DIM='\e[2m'       # Faint, decreased intensity
ANSI_ITALIC='\e[3m'    # Not widely supported
ANSI_UNDERLINE='\e[4m'
ANSI_BLINK='\e[5m'     # Slow blink
ANSI_FAST_BLINK='\e[6m' # Fast blink, not widely supported
ANSI_REVERSE='\e[7m'   # Swap foreground and background
ANSI_HIDDEN='\e[8m'    # Conceal, invisible
ANSI_STRIKETHROUGH='\e[9m' # Not widely supported

# Foreground Colors (30-37)
ANSI_FG_BLACK='\e[30m'
ANSI_FG_RED='\e[31m'
ANSI_FG_GREEN='\e[32m'
ANSI_FG_YELLOW='\e[33m'
ANSI_FG_BLUE='\e[34m'
ANSI_FG_MAGENTA='\e[35m'
ANSI_FG_CYAN='\e[36m'
ANSI_FG_WHITE='\e[37m'
ANSI_FG_DEFAULT='\e[39m' # Reset foreground color

# Bright Foreground Colors (90-97)
ANSI_FG_BRIGHT_BLACK='\e[90m'  # Often Gray
ANSI_FG_BRIGHT_RED='\e[91m'
ANSI_FG_BRIGHT_GREEN='\e[92m'
ANSI_FG_BRIGHT_YELLOW='\e[93m'
ANSI_FG_BRIGHT_BLUE='\e[94m'
ANSI_FG_BRIGHT_MAGENTA='\e[95m'
ANSI_FG_BRIGHT_CYAN='\e[96m'
ANSI_FG_BRIGHT_WHITE='\e[97m'

# Background Colors (40-47)
ANSI_BG_BLACK='\e[40m'
ANSI_BG_RED='\e[41m'
ANSI_BG_GREEN='\e[42m'
ANSI_BG_YELLOW='\e[43m'
ANSI_BG_BLUE='\e[44m'
ANSI_BG_MAGENTA='\e[45m'
ANSI_BG_CYAN='\e[46m'
ANSI_BG_WHITE='\e[47m'
ANSI_BG_DEFAULT='\e[49m' # Reset background color

# Bright Background Colors (100-107)
ANSI_BG_BRIGHT_BLACK='\e[100m' # Often Gray
ANSI_BG_BRIGHT_RED='\e[101m'
ANSI_BG_BRIGHT_GREEN='\e[102m'
ANSI_BG_BRIGHT_YELLOW='\e[103m'
ANSI_BG_BRIGHT_BLUE='\e[104m'
ANSI_BG_BRIGHT_MAGENTA='\e[105m'
ANSI_BG_BRIGHT_CYAN='\e[106m'
ANSI_BG_BRIGHT_WHITE='\e[107m'

# Example of how to use:
# echo "${ANSI_BOLD}${ANSI_FG_RED}This is bold red text${ANSI_RESET}"
