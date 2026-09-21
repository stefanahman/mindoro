# notify.sh — one notification, through whatever is listening.
#
# The multiplexer first, because its banner lands where you are
# looking and it knows which workspace the timer belongs to; then the
# desktop; then stderr, so a headless run still says what happened.

notify() {
    local title=$1 body=$2
    # MINDORO_NOTIFY=stderr keeps a headless run, or a test, off the
    # desktop.
    if [[ "${MINDORO_NOTIFY:-}" == stderr ]]; then
        printf 'mindoro: %s — %s\n' "$title" "$body" >&2
        return 0
    fi
    if [[ -n "${CMUX_WORKSPACE_ID:-}" ]] && command -v cmux >/dev/null 2>&1; then
        CMUX_QUIET=1 cmux notify --title "$title" --body "$body" >/dev/null 2>&1 && return 0
    fi
    if [[ "${HERDR_ENV:-}" == 1 ]] && command -v herdr >/dev/null 2>&1; then
        herdr notification show "$title" --body "$body" --sound 'done' >/dev/null 2>&1 && return 0
    fi
    case $(uname -s) in
    Darwin)
        osascript -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\" sound name \"Glass\"" >/dev/null 2>&1 && return 0
        ;;
    *)
        command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$body" >/dev/null 2>&1 && return 0
        ;;
    esac
    printf 'mindoro: %s — %s\n' "$title" "$body" >&2
}
