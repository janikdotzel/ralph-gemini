# Dockerfile for Ralph Gemini local execution
# Use this as a fallback when VM execution is not available

FROM node:20-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Playwright browsers
RUN npx playwright install --with-deps chromium

# Create working directory
WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy project files
COPY . .

# Set environment
ENV NODE_ENV=development
ENV CI=true

# Default command
CMD ["./ralph", "--help"]
