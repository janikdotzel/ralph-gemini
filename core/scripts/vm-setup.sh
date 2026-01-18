#!/bin/bash
# vm-setup.sh - Initialize a new VM for Ralph Gemini
# Run this on a fresh VM after SSH access is configured
#
# Usage: curl -fsSL <url>/vm-setup.sh | bash

set -e

echo "================================"
echo "Ralph Gemini VM Setup"
echo "================================"
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

echo "Detected OS: $OS"
echo ""

# Update system
echo "1. Updating system..."
case "$OS" in
    ubuntu|debian)
        sudo apt-get update
        sudo apt-get upgrade -y
        ;;
    fedora|centos|rhel)
        sudo dnf update -y
        ;;
    *)
        echo "  Warning: Unknown OS, skipping system update"
        ;;
esac

# Install Node.js (via nvm)
echo "2. Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 20
    nvm use 20
    nvm alias default 20
fi
echo "  Node: $(node --version)"

# Install GitHub CLI
echo "3. Installing GitHub CLI..."
if ! command -v gh &> /dev/null; then
    case "$OS" in
        ubuntu|debian)
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt-get update
            sudo apt-get install gh -y
            ;;
        fedora|centos|rhel)
            sudo dnf install gh -y
            ;;
        *)
            echo "  Warning: Install gh manually"
            ;;
    esac
fi
echo "  gh: $(gh --version | head -1)"

# Install jq
echo "4. Installing jq..."
if ! command -v jq &> /dev/null; then
    case "$OS" in
        ubuntu|debian)
            sudo apt-get install jq -y
            ;;
        fedora|centos|rhel)
            sudo dnf install jq -y
            ;;
    esac
fi
echo "  jq: $(jq --version)"

# Install Playwright dependencies
echo "5. Installing Playwright dependencies..."
case "$OS" in
    ubuntu|debian)
        sudo apt-get install -y \
            libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
            libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
            libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2
        ;;
    *)
        echo "  Warning: Install Playwright deps manually"
        ;;
esac

# Create projects directory
echo "6. Setting up directories..."
mkdir -p ~/projects

# Configure git
echo "7. Configuring git..."
if [ -z "$(git config --global user.name)" ]; then
    git config --global user.name "Ralph Gemini"
fi
if [ -z "$(git config --global user.email)" ]; then
    git config --global user.email "ralph@example.com"
fi

# Setup firewall (basic)
echo "8. Configuring firewall..."
if command -v ufw &> /dev/null; then
    sudo ufw allow ssh
    sudo ufw --force enable
    echo "  UFW enabled"
fi

# Done
echo ""
echo "================================"
echo "VM Setup Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Authenticate GitHub:"
echo "   gh auth login"
echo ""
echo "2. Install your AI CLI:"
echo ""
echo "   For Gemini:"
echo "   npm install -g @google/gemini-cli"
echo "   gemini auth login"
echo ""
echo "   For Claude:"
echo "   npm install -g @anthropic-ai/claude-code"
echo "   claude login"
echo ""
echo "   Or set API key:"
echo "   echo 'export ANTHROPIC_API_KEY=\"sk-...\"' >> ~/.bashrc"
echo "   echo 'export GOOGLE_API_KEY=\"...\"' >> ~/.bashrc"
echo "   source ~/.bashrc"
echo ""
echo "3. Clone your project and run /ralph:deploy"
echo ""
