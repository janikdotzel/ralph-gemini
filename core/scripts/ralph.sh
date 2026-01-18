#!/bin/bash
# =============================================================================
# ralph.sh - Ralph Gemini Main Script
#
# Usage:
#   ./ralph.sh                    # Sequential loop (default)
#   ./ralph.sh --status           # Show status
#   ./ralph.sh --docker           # Run in Docker container
#   ./ralph.sh --help             # Help
#
# Supports both Gemini CLI and Claude via Antigravity
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
CONFIG_FILE=".ralph/config.json"

# Detect AI command based on config
detect_ai_cmd() {
    local model="auto"
    if [ -f "$CONFIG_FILE" ]; then
        model=$(jq -r '.defaultModel // "auto"' "$CONFIG_FILE" 2>/dev/null)
    fi

    case "$model" in
        gemini)
            if command -v gemini &> /dev/null; then
                echo "gemini"
            else
                echo "Error: Gemini CLI not found" >&2
                exit 1
            fi
            ;;
        claude)
            if command -v claude &> /dev/null; then
                echo "claude --dangerously-skip-permissions"
            elif command -v antigravity &> /dev/null; then
                echo "antigravity claude"
            else
                echo "Error: Claude/Antigravity not found" >&2
                exit 1
            fi
            ;;
        auto|*)
            # Auto-detect: prefer gemini, fallback to claude
            if command -v gemini &> /dev/null; then
                echo "gemini"
            elif command -v claude &> /dev/null; then
                echo "claude --dangerously-skip-permissions"
            elif command -v antigravity &> /dev/null; then
                echo "antigravity claude"
            else
                echo "Error: No AI CLI found (gemini, claude, or antigravity)" >&2
                exit 1
            fi
            ;;
    esac
}

AI_CMD=$(detect_ai_cmd)
export AI_CMD

# Check for --status
if [[ "${1:-}" == "--status" ]] || [[ "${1:-}" == "-s" ]]; then
    echo "=== Ralph Status ==="
    echo ""
    echo "AI: $AI_CMD"
    if [ -d "specs" ]; then
        total=$(ls -1 specs/*.md 2>/dev/null | wc -l | tr -d ' ')
        done=$(ls -1 .spec-checksums/*.md5 2>/dev/null | wc -l | tr -d ' ')
        echo "Specs: $done/$total done"
    fi
    if [ -d ".spec-checksums" ]; then
        echo ""
        echo "Completed:"
        ls -1 .spec-checksums/*.md5 2>/dev/null | xargs -I{} basename {} .md5 | sed 's/^/  [done] /'
    fi
    exit 0
fi

# Check for --docker
if [[ "${1:-}" == "--docker" ]] || [[ "${1:-}" == "-d" ]]; then
    shift
    exec "$SCRIPT_DIR/ralph-docker.sh" "$@"
fi

# Check for --help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << 'EOF'
ralph.sh - Ralph Gemini Main Script

USAGE:
  ./ralph.sh                    Sequential loop (default)
  ./ralph.sh spec.md            Run single spec
  ./ralph.sh --status           Show progress
  ./ralph.sh --docker           Run in Docker container
  ./ralph.sh --help             This help

ENVIRONMENT:
  AI_CMD                        Override AI command (gemini, claude, etc.)

EOF
    exit 0
fi

# =============================================================================
# MAIN LOOP
# =============================================================================

# Load libraries
source "$LIB_DIR/spec-utils.sh"
source "$LIB_DIR/verify.sh"
source "$LIB_DIR/notify.sh"
source "$LIB_DIR/git-utils.sh"
source "$LIB_DIR/test-loop.sh"

# Config
MAX_RETRIES=3
TIMEOUT=1800
COMPLETION_MARKER="<promise>DONE</promise>"

# Logs
LOG_DIR=".ralph/logs"
mkdir -p "$LOG_DIR"
RAW_LOG="$LOG_DIR/ai-raw.log"
ERROR_LOG="$LOG_DIR/errors.log"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "[$(date +%H:%M:%S)] $1"; }

# Log AI output to file
log_ai_output() {
    local spec_name="$1"
    local output="$2"
    local exit_code="${3:-0}"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Always append to raw log
    echo "=== [$timestamp] $spec_name ===" >> "$RAW_LOG"
    echo "$output" >> "$RAW_LOG"
    echo "" >> "$RAW_LOG"

    # On error, also write to error log with context
    if [ "$exit_code" -ne 0 ] || ! echo "$output" | grep -q "$COMPLETION_MARKER"; then
        echo "=== [$timestamp] $spec_name FAILED ===" >> "$ERROR_LOG"
        echo "$output" | tail -100 >> "$ERROR_LOG"
        echo "" >> "$ERROR_LOG"
    fi
}

# Run a single spec
run_spec() {
    local spec="$1"
    local attempt=1
    local spec_name=$(basename "$spec" .md)

    log "${GREEN}=== $spec_name ===${NC}"
    notify_spec_start "$spec"

    if is_spec_done "$spec"; then
        log "${CYAN}Already done${NC}"
        return 0
    fi

    while [ $attempt -le $MAX_RETRIES ]; do
        log "${YELLOW}Attempt $attempt/$MAX_RETRIES${NC}"

        local output exit_code=0
        local prompt="$(cat "$spec")

---
When complete: write $COMPLETION_MARKER
Before DONE: run 'npm run build' and verify it passes."

        output=$(echo "$prompt" | timeout $TIMEOUT $AI_CMD -p 2>&1) || exit_code=$?

        # Log output to file
        log_ai_output "$spec_name" "$output" "$exit_code"

        if [ $exit_code -eq 124 ]; then
            log "${RED}Timeout${NC}"
            ((attempt++))
            continue
        fi

        if echo "$output" | grep -q "$COMPLETION_MARKER"; then
            if verify_build; then
                # Run E2E tests if available
                if ! run_e2e_tests; then
                    local cr_spec="specs/CR-fix-${spec_name}.md"
                    if generate_cr "$spec_name" && [ -f "$cr_spec" ]; then
                        log "${YELLOW}Running CR fix...${NC}"
                        run_spec "$cr_spec"
                        rm -f "$cr_spec"
                    fi
                    ((attempt++))
                    continue
                fi

                # Run design review (optional)
                take_screenshots ".screenshots"
                if ! run_design_review "$spec_name"; then
                    local design_cr="specs/CR-design-${spec_name}.md"
                    if generate_design_cr "$spec_name" && [ -f "$design_cr" ]; then
                        log "${YELLOW}Running design fix...${NC}"
                        run_spec "$design_cr"
                        rm -f "$design_cr"
                    fi
                    ((attempt++))
                    continue
                fi

                log "${GREEN}Verified${NC}"
                check_dangerous && check_secrets && commit_and_push "Ralph: $spec_name"
                mark_spec_done "$spec"
                notify_spec_done "$spec"
                return 0
            fi
        fi

        ((attempt++))
        sleep 5
    done

    log "${RED}Failed after $MAX_RETRIES attempts${NC}"
    log "${YELLOW}See logs: $ERROR_LOG${NC}"
    notify_spec_failed "$spec"
    return 1
}

# Main
main() {
    log "${CYAN}Ralph Gemini Starting${NC}"
    log "Using: $AI_CMD"
    notify "Ralph starting" "Ralph Gemini"

    local specs_done=0 specs_failed=0

    # Sequential mode
    if [ $# -gt 0 ]; then
        for spec in "$@"; do
            run_spec "$spec" && ((specs_done++)) || ((specs_failed++))
        done
    else
        while true; do
            local spec=$(next_incomplete_spec)
            [ -z "$spec" ] && break
            run_spec "$spec" && ((specs_done++)) || ((specs_failed++))
        done
    fi

    # Count total specs (excluding CR-* files)
    local total_specs=$(ls -1 specs/*.md 2>/dev/null | grep -v "/CR-" | wc -l | tr -d ' ')

    if [ "$total_specs" -eq 0 ]; then
        log "${RED}No specs found in specs/*.md${NC}"
        notify "No specs found" "Ralph Error"
        exit 1
    fi

    local total_done=$(ls -1 .spec-checksums/*.md5 2>/dev/null | wc -l | tr -d ' ')
    log "${GREEN}=== Done: $total_done/$total_specs specs ===${NC}"
    log "${GREEN}=== This run: $specs_done completed, $specs_failed failed ===${NC}"

    notify_complete "$specs_done" "$total_specs"

    [ $specs_failed -eq 0 ]
}

main "$@"
