#!/usr/bin/env bash
# cc.bash — Claude Code wrapper (bash port of ./cc) with session naming and
# cleanup prompts.
#
# Prompts for a session name before launch (colorized) and asks whether to keep
# the transcript on exit. Symlink it onto your PATH as `cc`:
#   ln -s "$(pwd)/cc.bash" ~/bin/cc
#
# Configuration (export in .bashrc):
#   CC_SKIP_NAME=1        — never prompt for name
#   CC_SKIP_EXIT=1        — never prompt on exit
#   CC_AUTO_CLEAN_DAYS=90 — days threshold for the 'clean' option

CC_SKIP_NAME="${CC_SKIP_NAME:-0}"
CC_SKIP_EXIT="${CC_SKIP_EXIT:-0}"
CC_AUTO_CLEAN_DAYS="${CC_AUTO_CLEAN_DAYS:-90}"

_cc_color_cyan='\033[1;36m'
_cc_color_yellow='\033[1;33m'
_cc_color_green='\033[1;32m'
_cc_color_dim='\033[2m'
_cc_color_reset='\033[0m'

_cc_has_flag() {
    local flag="$1"; shift
    local arg
    for arg in "$@"; do
        [[ "$arg" == "$flag" || "$arg" == "$flag="* ]] && return 0
    done
    return 1
}

_cc_main() {
    local claude_args=()
    local session_name=""
    local skip_name="$CC_SKIP_NAME"
    local skip_exit="$CC_SKIP_EXIT"

    # Passthrough: don't prompt if --name, -n, or -p/--print is already set
    if _cc_has_flag "--name" "$@" || _cc_has_flag "-n" "$@"; then
        skip_name=1
    fi
    if _cc_has_flag "-p" "$@" || _cc_has_flag "--print" "$@"; then
        skip_name=1
        skip_exit=1
    fi

    # Prompt for session name
    if [[ "$skip_name" != "1" ]]; then
        printf "${_cc_color_cyan}Session name ${_cc_color_dim}(enter to skip)${_cc_color_reset}${_cc_color_cyan}: ${_cc_color_reset}"
        read -r session_name
        if [[ -n "$session_name" ]]; then
            claude_args+=(-n "$session_name")
            printf "${_cc_color_green}→ ${session_name}${_cc_color_reset}\n"
        fi
    fi

    # Timestamp marker for finding the session transcript
    touch /tmp/.cc_session_start 2>/dev/null

    # Launch Claude Code
    claude "${claude_args[@]}" "$@"
    local exit_code=$?

    # Post-session prompt
    if [[ "$skip_exit" != "1" && $exit_code -eq 0 ]]; then
        echo ""
        printf "${_cc_color_yellow}Keep this session transcript? [Y/n/clean]: ${_cc_color_reset}"
        local keep_answer
        read -r keep_answer
        keep_answer=$(printf '%s' "$keep_answer" | tr '[:upper:]' '[:lower:]')

        case "$keep_answer" in
            n|no)
                # Find and remove the most recent transcript
                local latest
                latest=$(find ~/.claude/projects -name "*.jsonl" -not -path "*/subagents/*" -newer /tmp/.cc_session_start 2>/dev/null | head -1)
                if [[ -n "$latest" ]]; then
                    local sid dir
                    sid=$(basename "$latest" .jsonl)
                    dir=$(dirname "$latest")
                    rm -f "$latest"
                    [[ -d "${dir}/${sid}" ]] && rm -rf "${dir}/${sid}"
                    printf "${_cc_color_dim}Transcript removed.${_cc_color_reset}\n"
                else
                    printf "${_cc_color_dim}No transcript found to remove.${_cc_color_reset}\n"
                fi
                ;;
            clean|c)
                if command -v claude-recall >/dev/null 2>&1; then
                    claude-recall clean --older-than "$CC_AUTO_CLEAN_DAYS"
                else
                    printf "${_cc_color_dim}claude-recall not found in PATH. Install it for cleanup.${_cc_color_reset}\n"
                fi
                ;;
            *)
                printf "${_cc_color_dim}Session kept.${_cc_color_reset}\n"
                ;;
        esac
    fi

    return $exit_code
}

_cc_main "$@"
