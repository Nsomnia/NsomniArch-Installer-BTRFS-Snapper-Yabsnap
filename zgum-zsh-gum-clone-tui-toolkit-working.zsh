#!/usr/bin/env zsh
# SPDX-License-Identifier: MIT or do wtf you want with it
# Copyright (c) 2025 ZSH UI Toolkit Developer - Nsomnia

emulate -LR zsh
zmodload zsh/curses
setopt extended_glob no_prompt_subst warn_create_global

### [ Configuration Constants ] #################################################
typeset -A config=(
    [cursor]="❯ "
    [selected]=0
    [height]=10
    [multi]=0
    [min]=0
    [max]=0
    [header]=""
    [footer]=""
    [selected_color]="1;32"
    [header_color]="1;34"
    [footer_color]="2"
    [layout]="list"
    [shadow_style]="light"
)

typeset -A keybinds=(
    [up]="up k"
    [down]="down j"
    [select]="enter"
    [toggle]="space"
    [settings]="s"
    [help]="/"
    [command]=":"
    [quit]="q"
)

### [ UI Constants ] ############################################################
local -A box_chars=(
    light "╭─╮│ │╰─╯"
    heavy "┏━┓┃ ┃┗━┛"
    double "╔═╗║ ║╚═╝"
    rounded "╭─╮│ │╰─╯"
    none "   ││   "
)

local -A shadow_gradient=(
    chars " ░▒▓█"
    depth 4
)

### [ XDG Configuration Handling ] ##############################################
function load_config() {
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/zsh-ui-toolkit.conf"
    [[ -f $config_file ]] || return 0
    
    while IFS='=' read -r key value; do
        case $key in
            shadow_style|layout|cursor)
                config[$key]=$value ;;
            height|selected|min|max)
                config[$key]=$((value)) ;;
            keybind_*)
                local action=${key#keybind_}
                keybinds[$action]=${value//,/ } ;;
        esac
    done < $config_file
}

function save_config() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
    local config_file="$config_dir/zsh-ui-toolkit.conf"
    mkdir -p $config_dir
    
    {
        for key in ${(k)config}; do
            [[ $key == (shadow_style|layout|cursor|height|selected|min|max) ]] &&
            print "$key=$config[$key]"
        done
        
        for action in ${(k)keybinds}; do
            print "keybind_$action=${keybinds[$action]// /,}"
        done
    } >| $config_file
}

### [ Box Drawing Utilities ] ###################################################
function draw_box() {
    local win=$1 x=$2 y=$3 w=$4 h=$5
    local -A bc=(
        tl ${${=box_chars[$config[shadow_style]]}[1]}
        tr ${${=box_chars[$config[shadow_style]]}[2]}
        bl ${${=box_chars[$config[shadow_style]]}[3]}
        br ${${=box_chars[$config[shadow_style]]}[4]}
        v  ${${=box_chars[$config[shadow_style]]}[5]}
        h  ${${=box_chars[$config[shadow_style]]}[6]}
    )

    # Main box
    zcurses move $win $y $x
    zcurses string $win "$bc[tl]${(pl:$w-2::$bc[h]:)}$bc[tr]"
    for ((i=1; i<h-1; i++)); do
        zcurses move $win $((y+i)) $x
        zcurses string $win "$bc[v]"
        zcurses move $win $((y+i)) $((x+w-1))
        zcurses string $win "$bc[v]"
    done
    zcurses move $win $((y+h-1)) $x
    zcurses string $win "$bc[bl]${(pl:$w-2::$bc[h]:)}$bc[br]"
}

### [ Shadow Drawing ] ##########################################################
function calculate_shadow_gradient() {
    local distance=$1
    local index=$(( (distance * $#shadow_gradient[chars]) / shadow_gradient[depth] ))
    (( index = index > $#shadow_gradient[chars] ? $#shadow_gradient[chars] : index ))
    print -n $shadow_gradient[chars][$((index + 1))]
}

function draw_shadow() {
    local win=$1 x=$2 y=$3 w=$4 h=$5
    local max_depth=$shadow_gradient[depth]
    
    # Right shadow
    for ((i=0; i<h+max_depth; i++)); do
        for ((d=0; d<max_depth; d++)); do
            local py=$((y + i - d))
            local px=$((x + w + d))
            (( py >= y && py < y+h+max_depth )) && {
                zcurses move $win $py $px
                zcurses string $win $(calculate_shadow_gradient $d)
            }
        done
    done

    # Bottom shadow
    for ((i=0; i<w+max_depth; i++)); do
        for ((d=0; d<max_depth; d++)); do
            local px=$((x + i - d))
            local py=$((y + h + d))
            (( px >= x && px < x+w+max_depth )) && {
                zcurses move $win $py $px
                zcurses string $win $(calculate_shadow_gradient $d)
            }
        done
    done
}

### [ Keybind Management ] ######################################################
typeset -A modal_stack=()
typeset -g input_buffer=""

function show_keybind_editor() {
    local actions=(${(k)keybinds}) selected=0
    local -A original_binds=(${(kv)keybinds})

    while true; do
        zcurses clear $win
        draw_box $win 5 2 50 $((#actions + 3))
        draw_shadow $win 5 2 50 $((#actions + 3))
        
        zcurses move $win 3 7
        zcurses string $win "Keybind Configuration"
        
        for ((i=0; i<$#actions; i++)); do
            zcurses move $win $((5+i)) 7
            (( i == selected )) && zcurses attr $win reverse
            zcurses string $win " ${actions[i+1]}: $keybinds[${actions[i+1]}]"
            (( i == selected )) && zcurses attr $win normal
        done

        zcurses refresh $win
        zcurses input $win key

        case $key in
            up) ((selected > 0)) && ((selected--)) ;;
            down) ((selected < $#actions-1)) && ((selected++)) ;;
            enter)
                local action=${actions[selected+1]}
                zcurses move $win $((5+selected)) 7
                zcurses string $win "Press new key: "
                zcurses refresh $win
                
                local newkey=""
                zcurses timeout 1000
                zcurses input $win newkey
                zcurses timeout -1
                
                if [[ -n $newkey ]]; then
                    for a in ${(k)keybinds}; do
                        if [[ " $keybinds[$a] " = *" $newkey "* ]]; then
                            show_confirm "Overwrite existing binding?" && break
                        fi
                    done
                    keybinds[$action]+=" $newkey"
                fi ;;
            q) keybinds=(${(kv)original_binds}); return ;;
            s) save_config; return ;;
        esac
    done
}

zsh
### [ Main UI Components ] ######################################################
function draw_main() {
    local win=$MAIN_WIN
    zcurses clear $win
    
    # Header
    [[ -n $config[header] ]] && {
        zcurses attr $win $config[header_color]
        zcurses move $win 1 3
        zcurses string $win $config[header]
    }

    # Items
    local start=0 end=$((start + config[height]))
    for ((i=start; i<end && i<${#choices}; i++)); do
        zcurses move $win $((i-start+3)) 3
        (( i == config[selected] )) && {
            zcurses attr $win $config[selected_color]
            zcurses string $win "$config[cursor]${choices[i+1]}"
        } || {
            zcurses attr $win normal
            zcurses string $win "  ${choices[i+1]}"
        }
    done

    # Footer
    [[ -n $config[footer] ]] && {
        zcurses attr $win $config[footer_color]
        zcurses move $win $((config[height]+4)) 3
        zcurses string $win $config[footer]
    }
    
    draw_shadow $win 0 0 $(tput cols) $(tput lines)
    zcurses refresh $win
}

function handle_input() {
    zcurses input $MAIN_WIN key
    case ${modal_stack[-1]} in
        confirm) handle_confirm_input ;;
        input) handle_text_input ;;
        *) handle_main_input ;;
    esac
}

### [ Initialization ] ##########################################################
function init_ui() {
    zcurses init
    zcurses addwin $MAIN_WIN $(tput lines) $(tput cols) 0 0
    load_config
}

function cleanup() {
    zcurses delwin $MAIN_WIN
    zcurses end
}

### [ Main Loop ] ###############################################################
function main() {
    init_ui
    parse_args "$@"
    
    while true; do
        draw_main
        handle_input
    done
}

trap cleanup EXIT
main "$@"