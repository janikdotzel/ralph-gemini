#!/bin/bash
# ralph-docker.sh - Run Ralph in Docker container (local fallback)
# Usage: ./ralph-docker.sh [args...]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="ralph-gemini"
CONTAINER_NAME="ralph-runner"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "[docker] $1"; }

# Check Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log "${RED}Docker not found${NC}"
        log "Install Docker Desktop from docker.com"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log "${RED}Docker daemon not running${NC}"
        log "Start Docker Desktop"
        exit 1
    fi
}

# Build image if needed
build_image() {
    if docker images | grep -q "$IMAGE_NAME"; then
        log "${CYAN}Image exists${NC}"
        return 0
    fi

    log "${CYAN}Building Docker image...${NC}"

    # Check for Dockerfile
    if [ -f ".ralph/templates/Dockerfile" ]; then
        docker build -t "$IMAGE_NAME" -f .ralph/templates/Dockerfile .
    elif [ -f "Dockerfile" ]; then
        docker build -t "$IMAGE_NAME" .
    else
        # Create minimal Dockerfile
        log "Creating minimal Dockerfile..."
        cat > /tmp/Dockerfile.ralph << 'EOF'
FROM node:20-slim

RUN apt-get update && apt-get install -y \
    git curl wget python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN npx playwright install --with-deps chromium || true

WORKDIR /app
ENV NODE_ENV=development
ENV CI=true

CMD ["./ralph", "--help"]
EOF
        docker build -t "$IMAGE_NAME" -f /tmp/Dockerfile.ralph .
        rm /tmp/Dockerfile.ralph
    fi

    log "${GREEN}Image built${NC}"
}

# Stop existing container
stop_container() {
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        log "Stopping existing container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    fi
}

# Run container
run_container() {
    local args="${*:-}"

    log "${CYAN}Starting container...${NC}"

    # Determine AI command to pass
    local ai_env=""
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        ai_env="-e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
    fi
    if [ -n "${GOOGLE_API_KEY:-}" ]; then
        ai_env="$ai_env -e GOOGLE_API_KEY=$GOOGLE_API_KEY"
    fi

    docker run -d \
        --name "$CONTAINER_NAME" \
        -v "$(pwd):/app" \
        $ai_env \
        "$IMAGE_NAME" \
        ./ralph $args

    log "${GREEN}Container started${NC}"
    log ""
    log "View logs:"
    log "  docker logs -f $CONTAINER_NAME"
    log ""
    log "Stop:"
    log "  docker stop $CONTAINER_NAME"
}

# Interactive shell
run_shell() {
    log "${CYAN}Starting interactive shell...${NC}"

    docker run -it --rm \
        -v "$(pwd):/app" \
        "$IMAGE_NAME" \
        /bin/bash
}

# Main
main() {
    check_docker
    build_image

    if [ "${1:-}" = "--shell" ]; then
        run_shell
    else
        stop_container
        run_container "$@"
    fi
}

main "$@"
