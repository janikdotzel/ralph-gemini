#!/bin/bash
# ralph-deploy.sh - Deploy to VM via GitHub
# Usage: ./ralph-deploy.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
CONFIG_FILE=".ralph/config.json"

source "$LIB_DIR/vm.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "[deploy] $1"; }

# Validate prerequisites
validate() {
    log "${CYAN}Validating...${NC}"

    # 1. Specs must exist
    local spec_count=$(ls -1 specs/*.md 2>/dev/null | grep -v "CR-" | wc -l | tr -d ' ')
    if [ "$spec_count" -eq 0 ]; then
        log "${RED}FATAL: No specs found in specs/${NC}"
        log "Run /ralph:plan first to generate specs"
        exit 1
    fi
    log "${GREEN}Found $spec_count specs${NC}"

    # 2. PRD should exist
    if [ ! -f "docs/PRD.md" ] && [ ! -f "docs/prd.md" ]; then
        log "${YELLOW}WARNING: No PRD found in docs/${NC}"
        log "Recommended: Run /ralph:discover first"
    fi

    # 3. AGENTS.md should exist
    if [ ! -f "AGENTS.md" ]; then
        log "${YELLOW}WARNING: No AGENTS.md found${NC}"
        log "Ralph works better with project instructions"
    fi

    # 4. Config must exist
    if [ ! -f "$CONFIG_FILE" ]; then
        log "${RED}FATAL: No config found ($CONFIG_FILE)${NC}"
        log "Run: npx ralph-gemini install"
        exit 1
    fi

    local execution=$(vm_execution)
    log "${GREEN}Execution: $execution${NC}"

    # 5. Git remote
    if ! git remote get-url origin > /dev/null 2>&1; then
        log "${RED}FATAL: No git remote 'origin'${NC}"
        log "Add with: git remote add origin <url>"
        exit 1
    fi
    log "${GREEN}Git remote OK${NC}"

    log ""
    log "${GREEN}=== VALIDATION PASSED ===${NC}"
}

# Push to GitHub
push_to_github() {
    log "${CYAN}Pushing to GitHub...${NC}"

    git add -A
    git commit -m "Deploy: $(date +%Y-%m-%d_%H:%M)" || true
    git push origin main

    log "${GREEN}Pushed to GitHub${NC}"
}

# Start on VM
start_on_vm() {
    local execution=$(vm_execution)
    local name=$(vm_name)

    log "${CYAN}Starting on VM ($execution)...${NC}"

    # Get repo URL
    local repo_url=$(git remote get-url origin)
    local repo_name=$(basename "$repo_url" .git)

    vm_ssh << EOF
# Cleanup old processes
echo "Cleaning up old processes..."
pkill -f "vite|next|node.*dev" 2>/dev/null || true
sleep 2

cd ~/projects

# Clone or update repo
if [ -d "$repo_name" ]; then
    cd "$repo_name"
    git pull origin main
else
    gh repo clone $repo_url "$repo_name" 2>/dev/null || git clone $repo_url "$repo_name"
    cd "$repo_name"
fi

# Install dependencies if needed
[ -f "package.json" ] && [ ! -d "node_modules" ] && npm install

# Make ralph executable
chmod +x ralph .ralph/scripts/*.sh 2>/dev/null || true

# Start Ralph in background
nohup ./.ralph/scripts/ralph.sh > ralph-deploy.log 2>&1 &
echo "Ralph started with PID: \$!"
EOF

    log "${GREEN}Ralph started on VM${NC}"
}

# Start in Docker
start_in_docker() {
    log "${CYAN}Starting in Docker...${NC}"

    # Build image if needed
    if ! docker images | grep -q "ralph-gemini"; then
        log "Building Docker image..."
        docker build -t ralph-gemini -f .ralph/templates/Dockerfile .
    fi

    # Run container
    docker run -d \
        --name ralph-runner \
        -v "$(pwd):/app" \
        ralph-gemini \
        ./ralph

    log "${GREEN}Ralph started in Docker${NC}"
    log "View logs: docker logs -f ralph-runner"
}

# Main
main() {
    log "${CYAN}Ralph Gemini Deploy${NC}"
    log ""

    validate

    local execution=$(vm_execution)

    # Push to GitHub first
    push_to_github

    case "$execution" in
        gcp|ssh)
            start_on_vm
            ;;
        docker)
            start_in_docker
            ;;
        none)
            log "${YELLOW}No execution environment configured${NC}"
            log "Run: npx ralph-gemini install"
            exit 1
            ;;
        *)
            log "${RED}Unknown execution type: $execution${NC}"
            exit 1
            ;;
    esac

    log ""
    log "${GREEN}=== DEPLOY COMPLETE ===${NC}"
    log ""
    log "Follow progress:"
    if [ "$execution" = "docker" ]; then
        log "  docker logs -f ralph-runner"
    else
        log "  $(vm_execution) ssh to VM and: tail -f ~/projects/*/ralph-deploy.log"
    fi
    log ""
    log "When done:"
    log "  /ralph:review    # Review results"
}

main "$@"
