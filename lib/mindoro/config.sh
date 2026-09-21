# config.sh — the config file, as variables.
#
# ${XDG_CONFIG_HOME:-~/.config}/mindoro/config, one `key = value` per
# line, `#` comments. Every key has a default, so no file is a valid
# config. The file is parsed, never sourced: a config is data.
#
#   focus = 25          minutes of focus
#   short_break = 5     minutes of short break
#   long_break = 20     minutes of long break, after `cycles` focuses
#   cycles = 4          focuses per long break
#   wake_gap = 5        seconds without a tick that count as the
#                       machine having been asleep
#   phrases = <path>    one phrase per line; typing one ends a break
#   prompts = <dir>     one file per prompt: first line the message,
#                       the rest the art

MINDORO_CONFIG=${MINDORO_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/mindoro/config}

config_load() {
    cfg_focus=25
    cfg_short_break=5
    cfg_long_break=20
    cfg_cycles=4
    cfg_wake_gap=5
    cfg_phrases=$MINDORO_HOME/share/mindoro/phrases
    cfg_prompts=$MINDORO_HOME/share/mindoro/prompts

    [[ -f "$MINDORO_CONFIG" ]] || return 0

    local line key value n=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        n=$(( n + 1 ))
        line=${line%%#*}
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        if [[ ! "$line" =~ ^[[:space:]]*([a-z_]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]]; then
            echo "mindoro: $MINDORO_CONFIG:$n: expected key = value" >&2
            return 65
        fi
        key=${BASH_REMATCH[1]}
        value=${BASH_REMATCH[2]}
        case $key in
        focus | short_break | long_break | cycles | wake_gap)
            if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value == 0 )); then
                echo "mindoro: $MINDORO_CONFIG:$n: $key must be a positive integer" >&2
                return 65
            fi
            ;;
        phrases | prompts)
            value=${value/#\~/$HOME}
            ;;
        *)
            echo "mindoro: $MINDORO_CONFIG:$n: unknown key $key" >&2
            return 65
            ;;
        esac
        printf -v "cfg_$key" '%s' "$value"
    done < "$MINDORO_CONFIG"
}

# Seconds for a phase's duration, from the minutes in the config.
# MINDORO_MINUTE is how long a minute is, in seconds: 60, except in
# tests, where a two-minute focus that takes two seconds is the point.
config_duration() {
    local minute=${MINDORO_MINUTE:-60}
    case $1 in
    focus)       echo $(( cfg_focus * minute )) ;;
    short_break) echo $(( cfg_short_break * minute )) ;;
    long_break)  echo $(( cfg_long_break * minute )) ;;
    esac
}
