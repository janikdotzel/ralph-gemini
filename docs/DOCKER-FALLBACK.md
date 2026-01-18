# Docker Fallback Guide

Run Ralph Gemini locally using Docker when VM execution is not available.

## Prerequisites

- Docker Desktop installed
- API key for Gemini or Claude

## Quick Start

```bash
# Install ralph-gemini
npx ralph-gemini install
# Select "Docker (local fallback)" when prompted

# Run discovery and planning
/ralph:discover
/ralph:plan

# Deploy to Docker
/ralph:deploy
# or
./ralph --docker
```

## How It Works

1. Ralph builds a Docker container with Node.js and Playwright
2. Your project is mounted as a volume
3. Ralph runs specs inside the container
4. Results are written back to your local files

## Configuration

Update `.ralph/config.json`:

```json
{
  "execution": "docker",
  "defaultModel": "gemini"
}
```

## Environment Variables

Pass API keys to the container:

```bash
# Set API key
export GOOGLE_API_KEY="your-key"
# or
export ANTHROPIC_API_KEY="sk-ant-..."

# Run Ralph
./ralph --docker
```

Or add to `.env.local`:
```
GOOGLE_API_KEY=your-key
ANTHROPIC_API_KEY=sk-ant-...
```

## Manual Docker Commands

### Build the image
```bash
docker build -t ralph-gemini -f .ralph/templates/Dockerfile .
```

### Run interactively
```bash
docker run -it --rm \
  -v $(pwd):/app \
  -e GOOGLE_API_KEY=$GOOGLE_API_KEY \
  ralph-gemini \
  ./ralph
```

### Run in background
```bash
docker run -d \
  --name ralph-runner \
  -v $(pwd):/app \
  -e GOOGLE_API_KEY=$GOOGLE_API_KEY \
  ralph-gemini \
  ./ralph
```

### View logs
```bash
docker logs -f ralph-runner
```

### Stop
```bash
docker stop ralph-runner
docker rm ralph-runner
```

## Custom Dockerfile

Create your own Dockerfile for specific needs:

```dockerfile
FROM node:20-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl wget python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Playwright browsers
RUN npx playwright install --with-deps chromium

# Install AI CLI
RUN npm install -g @google/gemini-cli

WORKDIR /app

# Copy project
COPY . .

# Install dependencies
RUN npm ci

CMD ["./ralph"]
```

## Limitations

Docker mode has some limitations compared to VM execution:

| Feature | VM | Docker |
|---------|-----|--------|
| Background execution | Yes | Limited |
| Multiple projects | Yes | One at a time |
| Persistent state | Yes | Volume mount |
| Network isolation | Full | Container |
| Resource limits | VM specs | Docker limits |

## Performance Tips

### Increase Docker resources
In Docker Desktop settings:
- CPUs: 4+
- Memory: 8GB+
- Disk: 50GB+

### Use BuildKit
```bash
DOCKER_BUILDKIT=1 docker build -t ralph-gemini .
```

### Cache node_modules
```dockerfile
COPY package*.json ./
RUN npm ci
COPY . .
```

## Troubleshooting

### Container exits immediately
```bash
# Check logs
docker logs ralph-runner

# Run interactively to debug
docker run -it ralph-gemini /bin/bash
```

### Permission denied
```bash
# Fix permissions on mounted volume
chmod -R 755 .
```

### Out of memory
```bash
# Increase Docker memory limit
# Or add swap inside container
docker run --memory=4g ralph-gemini ./ralph
```

### Playwright fails
```bash
# Install browsers manually
docker run -it ralph-gemini npx playwright install --with-deps
```
