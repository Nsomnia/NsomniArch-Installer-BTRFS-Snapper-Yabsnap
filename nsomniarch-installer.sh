#!/usr/bin/env bash
# all Chris titles base10 is belonged to me.

#===============================================================================
# CONTANTS
#===============================================================================
readonly SELECTED="[x]"
readonly UNSELECTED="[ ]"

readonly WHITE="\033[2K\033[37m"
readonly BLUE="\033[2K\033[34m"
readonly RED="\033[2K\033[31m"
readonly GREEN="\033[2K\033[32m"

readonly INTERFACE_SIZE=6
readonly DEFAULT_OPTIONS=("Btrfs" "BCachefs" "Enable Snapper" "Configure makepkg.conf")

#===============================================================================
# VARIABLES
#===============================================================================
cursor=0
options_length=0
terminal_width=0
start_page=0
end_page=0

has_multiple_options=true
will_return_index=false
unselect_mode_on=false
select_mode_on=false
copy_in_message=false
invalid_parameter=false

options=("${DEFAULT_OPTIONS[@]}")
selected_options=()

content=""
message=""
separator=""
options_input=""
color=$WHITE
checkbox_output=()

#===============================================================================
# UTILS
#===============================================================================
array_without_value() {
    local value="$1" && shift
    local new_array=()

    for array in ${@}; do
        if [[ $value != $array ]]; then
            new_array+=("$array")
        fi
    done

    echo "${new_array[@]}"
}

value_in_array() {
    local element="$1" && shift
    local elements="$@"

    for elements; do
        [[ $elements == $element ]] && return 0
    done

    return 1
}

help_page_opt() {
    local output="(press q to quit)\n"
    output+="# Available options:\n\n\t--multiple:\n\t\tSelect multiple options\n\t\tExample:\n\t\t\t$ ./checkbox.sh --multiple\n\t--index:\n\t\tReturn index instead of value\n\t\tExample:\n\t\t\t$ ./checkbox.sh --index\n\t--message:\n\t\tCustom message\n\t\tExample:\n\t\t\t$ ./checkbox.sh --message=\"this message will be shown in the header\"\n\t--options:\n\t\tMenu options\n\t\tExample:\n\t\t\t$ ./checkbox.sh --options=\"checkbox 1\n\t\t\tcheckbox 2\n\t\t\tcheckbox 3\n\t\t\tcheckbox 4\n\t\t\tcheckbox 5\""
    output+="\n(press q to quit)"

    reset_screen
    printf "\033[2J\033[?25l%b\n" "$output"

    while true; do
        local key=$( get_pressed_key )
        case $key in
            _esc|q) return;;
        esac
    done
}

help_page_keys() {
    local output="(press q to quit)\n"
    output+="# Keybinds\n\n\t[ENTER]         or o: Close and return selected options\n\t[SPACE]         or x: Select current option\n\t[ESC]           or q: Exit\n\t[UP ARROW]      or k: Move cursor to option above\n\t[DOWN ARROW]    or j: Move cursor to option below\n\t[HOME]          or g: Move cursor to first option\n\t[END]           or G: Move cursor to last option\n\t[PAGE UP]       or u: Move cursor 5 options above\n\t[PAGE DOWN]     or d: Move cursor 5 options below\n\tc               or y: Copy current option\n\tr                   : Refresh renderization\n\th                   : Help page"

    if $has_multiple_options; then
        output+="\n\tA                   : Unselect all options\n\ta                   : Select all options\n\t[INSERT]        or v: On/Off select options during navigation (select mode)\n\t[BACKSPACE]     or V: On/Off unselect options during navigation (unselect mode)"
    fi

    output+="\n(press q to quit)"

    reset_screen
    printf "\033[2J\033[?25l%b\n" "$output"

    while true; do
        local key=$( get_pressed_key )
        case $key in
            _esc|q) return;;
        esac
    done
}

#===============================================================================
# AUXILIARY FUNCTIONS
#===============================================================================
handle_options() {
    content=""

    for index in ${!options[@]}; do
        if [[ $index -ge $start_page && $index -le $end_page ]]; then
            local option=${options[$index]}

            [[ ${options[$cursor]} == $option ]] && set_line_color
            handle_option "$index" "$option"
            color=$WHITE
        fi
    done
}

handle_option() {
    local index="$1" option="$2"

    if value_in_array "$index" "${selected_options[@]}"; then
        content+="$color    $SELECTED $option\n"

    else
        content+="$color    $UNSELECTED $option\n"
    fi
}

set_line_color() {
    if $has_multiple_options && $select_mode_on; then
        color=$GREEN

    elif $has_multiple_options && $unselect_mode_on; then
        color=$RED

    else
        color=$BLUE
    fi
}

select_many_options() {
    if ! value_in_array "$cursor" "${selected_options[@]}" \
        && $has_multiple_options && $select_mode_on; then
            selected_options+=("$cursor")

        elif value_in_array "$cursor" "${selected_options[@]}" \
            && $has_multiple_options && $unselect_mode_on; then
                    selected_options=($( array_without_value "$cursor" "${selected_options[@]}" ))
    fi
}

set_options() {
    if ! [[ $options_input == "" ]]; then
        options=()

        local temp_options=$( echo "${options_input#*=}" | sed "s/\\a//g;s/\\b//g;s/\\f//g;s/\\n//g;s/\\r//g;s/\\t//g" )
        temp_options=$( echo "$temp_options" | sed "s/|\+/|/g" )
        temp_options=$( echo "$temp_options" | tr "\n" "|" )
        IFS="|" read -a temp_options <<< "$temp_options"

        for index in ${!temp_options[@]}; do
            local option=${temp_options[index]}

            if [[ ${option::1} == "+" ]]; then
                if $has_multiple_options || [[ -z $selected_options ]]; then
                    selected_options+=("$index")
                fi
                option=${option:1}
            fi

            options+=("$option")
        done
    fi
}

validate_terminal_size() {
    if [[ $terminal_width -lt 8 ]]; then
        reset_screen
        printf "Resize the terminal to at least 8 lines and press r to refresh. The current terminal has $terminal_width lines"
    fi
}

get_footer() {
    local footer="$(( $cursor + 1 ))/$options_length"

    if $has_multiple_options; then
        footer+="  |  ${#selected_options[@]} selected"
    fi

    if $copy_in_message; then
        footer+="  |  current line copied"
        copy_in_message=false
    fi

    echo "$footer"
}

get_output() {
    terminal_width=$( tput lines )
    handle_options
    local footer="$( get_footer )"

    local output="  $message\n"
    output+="$WHITE$separator\n"
    output+="$content"
    output+="$WHITE$separator\n"
    output+="  $footer\n"

    echo "$output"
}

#===============================================================================
# KEY PRESS FUNCTIONS
#===============================================================================
toggle_select_mode() {
    if $has_multiple_options; then
        unselect_mode_on=false

        if $select_mode_on; then
            select_mode_on=false

        else
            select_mode_on=true
            if ! value_in_array "$cursor" "${selected_options[@]}"; then
                selected_options+=("$cursor")
            fi
        fi
    fi
}

toggle_unselect_mode() {
    if $has_multiple_options; then
        select_mode_on=false

        if $unselect_mode_on; then
            unselect_mode_on=false

        else
            unselect_mode_on=true
            selected_options=($( array_without_value "$cursor" "${selected_options[@]}" ))
        fi
    fi
}

select_all() {
    if $has_multiple_options; then
        selected_options=()

        for index in ${!options[@]}; do
            selected_options+=(${index})
        done
    fi
}

unselect_all() {
    [[ $has_multiple_options ]] && selected_options=()
}

page_up() {
    cursor=$(( $cursor - 5 ))

    [[ $cursor -le $start_page ]] \
        && start_page=$(( $cursor - 1 ))

    [[ $start_page -le 0 ]] \
        && start_page=0

    [[ $cursor -le 0 ]] \
        && cursor=0

    end_page=$(( $start_page + $terminal_width - $INTERFACE_SIZE ))
}

page_down() {
    cursor=$(( $cursor + 5 ))

    [[ $cursor -ge $end_page ]] \
        && end_page=$(( $cursor + 1 ))

    [[ $end_page -ge $options_length ]] \
        && end_page=$(( $options_length - 1 ))

    [[ $cursor -ge $options_length ]] \
        && cursor=$(( $options_length - 1 ))

    start_page=$(( $end_page + $INTERFACE_SIZE - $terminal_width ))
}

up() {
    [[ $cursor -gt 0 ]] \
        && cursor=$(( $cursor - 1 ))

    [[ $cursor -eq $start_page ]] \
        && start_page=$(( $cursor - 1 ))

    [[ $cursor -gt 0 ]] \
        && end_page=$(( $start_page + $terminal_width - $INTERFACE_SIZE ))

    select_many_options
}

down() {
    [[ $cursor -lt $(( $options_length - 1 )) ]] \
        && cursor=$(( $cursor + 1 ))

    [[ $cursor -eq $end_page ]] \
        && end_page=$(( $cursor + 1 ))

    [[ $cursor -lt $(( $options_length - 1 )) ]] \
        && start_page=$(( $end_page + $INTERFACE_SIZE - $terminal_width ))

    select_many_options
}

home() {
    cursor=0
    start_page=0
    end_page=$(( $start_page + $terminal_width - $INTERFACE_SIZE ))
}

end() {
    cursor=$(( $options_length - 1 ))
    end_page=$(( $options_length - 1 ))
    start_page=$(( $end_page + $INTERFACE_SIZE - $terminal_width ))
}

select_option() {
    if ! value_in_array "$cursor" "${selected_options[@]}"; then
        $has_multiple_options \
            && selected_options+=("$cursor") \
            || selected_options=("$cursor")

    else
        selected_options=($( array_without_value "$cursor" "${selected_options[@]}" ))
    fi
}

confirm() {
    if $will_return_index; then
        checkbox_output="${selected_options[@]}"

    else
        for index in ${!options[@]}; do
            if value_in_array "$index" "${selected_options[@]}"; then
                checkbox_output+=("${options[index]}")
            fi
        done
    fi
}

copy() {
    echo "${options[$cursor]}" | xclip -sel clip
    echo "${options[$cursor]}" | xclip
    copy_in_message=true
}

refresh() {
    terminal_width=$( tput lines )
    start_page=$(( $cursor - 1 ))
    end_page=$(( $start_page + $terminal_width - $INTERFACE_SIZE ))
}

#===============================================================================
# CORE FUNCTIONS
#===============================================================================
render() {
    printf "\033[1;%dH"
    printf "\033[2J\033[?25l%b\n" "$(get_output)"
}

reset_screen() {
    printf "\033[2J\033[?25h\033[1;%dH"
}

get_pressed_key() {
    IFS= read -sn1 key 2>/dev/null >&2

    read -sn1 -t 0.0001 k1
    read -sn1 -t 0.0001 k2
    read -sn1 -t 0.0001 k3
    key+="$k1$k2$k3"

    case $key in
        '') key=_enter;;
        ' ') key=_space;;
        $'\x1b') key=_esc;;
        $'\e[F') key=_end;;
        $'\e[H') key=_home;;
        $'\x7f') key=_backspace;;
        $'\x1b\x5b\x32\x7e') key=_insert;;
        $'\x1b\x5b\x41') key=_up;;
        $'\x1b\x5b\x42') key=_down;;
        $'\x1b\x5b\x35\x7e') key=_pgup;;
        $'\x1b\x5b\x36\x7e') key=_pgdown;;
    esac

    echo "$key"
}

get_opt() {
    while [[ $# -gt 0 ]]; do
        opt=$1
        shift

        case $opt in
            --index) will_return_index=true;;
            --multiple) has_multiple_options=true;;
            --message=*) message="${opt#*=}";;
            --options=*) options_input="$opt";;
            *) help_page_opt && invalid_parameter=true;;
        esac
    done
}

constructor() {
    set_options

    options_length=${#options[@]}
    terminal_width=$( tput lines )
    start_page=0
    end_page=$(( $start_page + $terminal_width - $INTERFACE_SIZE ))

    [[ ${#message} -gt 40 ]] \
        && message_length=$(( ${#message} + 10 )) \
        || message_length=50

    separator=$( perl -E "say '-' x $message_length" )
}

install_arch_linux() {
    local selected_file_system=""
    local enable_snapper=false

    for option in "${checkbox_output[@]}"; do
        case "$option" in
            "Btrfs")
                selected_file_system="btrfs"
                ;;
            "BCachefs")
                selected_file_system="bcachefs"
                ;;
            "Enable Snapper")
                enable_snapper=true
                ;;
        esac
    done

    if [[ -z "$selected_file_system" ]]; then
        echo "No file system selected. Exiting."
        exit 1
    fi

    echo "Starting Arch Linux installation with $selected_file_system file system..."

    # Add your installation commands here
    # Example:
    # pacstrap /mnt base base-devel linux linux-firmware vim
    # genfstab -U /mnt >> /mnt/etc/fstab
    # arch-chroot /mnt

    if $enable_snapper; then
        echo "Enabling Snapper..."
        # Add Snapper setup commands here
        # Example:
        # pacman -S snapper
        # snapper -c root create-config /
    fi

    echo "Installation complete!"
}

configure_makepkg_conf() {
    local makepkg_conf="/etc/makepkg.conf"
    local backup_conf="${makepkg_conf}.bak"

    if [[ -f "$makepkg_conf" ]]; then
        cp "$makepkg_conf" "$backup_conf"
        echo "Backup created: $backup_conf"
    else
        echo "makepkg.conf not found. Exiting."
        return 1
    fi

    echo "Configuring makepkg.conf..."

    # Prompt for parallel jobs
    local parallel_jobs
    read -p "Enter the number of parallel jobs (e.g., 4 for 4 cores): " parallel_jobs
    sed -i "s/^#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${parallel_jobs}\"/" "$makepkg_conf"

    # Prompt for compiler flags
    local compiler_flags
    read -p "Enter compiler flags (e.g., -O2 -pipe -fno-plt): " compiler_flags
    sed -i "s/^#CFLAGS=\"/CFLAGS=\"$compiler_flags /" "$makepkg_conf"

    # Prompt for linker
    local linker
    PS3="Select the linker to use: "
    options=("ld.lld" "gold" "ld")
    select linker in "${options[@]}"; do
        case "$linker" in
            "ld.lld"|"gold"|"ld")
                sed -i "s/^#LDFLAGS=\"/LDFLAGS=\"$linker /" "$makepkg_conf"
                break
                ;;
            *) echo "Invalid option. Please try again.";;
        esac
    done

    # Prompt for debug information
    local debug_info
    PS3="Include debug information? (y/n): "
    options=("y" "n")
    select debug_info in "${options[@]}"; do
        case "$debug_info" in
            "y")
                sed -i "s/^#DEBUG_FLAGS=\"/DEBUG_FLAGS=\"/g" "$makepkg_conf"
                break
                ;;
            "n")
                sed -i "s/^DEBUG_FLAGS=\"/DEBUG_FLAGS=\"-g\"/g" "$makepkg_conf"
                break
                ;;
            *) echo "Invalid option. Please try again.";;
        esac
    done

    echo "makepkg.conf configured successfully."
}

#===============================================================================
# MAIN
#===============================================================================
main() {
    get_opt "$@"

    if $invalid_parameter; then
        reset_screen
        return
    fi

    constructor
    render

    while true; do
        validate_terminal_size
        local key=$( get_pressed_key )

        case $key in
            _up|k) up;;
            _down|j) down;;
            _home|g) home;;
            _end|G) end;;
            _pgup|u) page_up;;
            _pgdown|d) page_down;;
            _esc|q) break;;
            _enter|o) confirm && break;;
            _space|x) select_option;;
            _insert|v) toggle_select_mode;;
            _backspace|V) toggle_unselect_mode;;
            c|y) copy;;
            r) refresh;;
            a) select_all;;
            A) unselect_all;;
            h) help_page_keys;;
        esac

        render
    done

    reset_screen

    if [[ ${#checkbox_output[@]} -gt 0 ]]; then
        printf "Selected:\n"
        for option in "${checkbox_output[@]}"; do
            printf "$option\n"
            case "$option" in
                "Configure makepkg.conf")
                    configure_makepkg_conf
                    ;;
            esac
        done
        install_arch_linux
    else
        printf "None selected\n"
    fi

    return
}

main "$@"