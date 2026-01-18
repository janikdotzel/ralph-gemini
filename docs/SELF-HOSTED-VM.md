# Self-Hosted VM Setup Guide

Set up your own VM (VPS, home server, etc.) for running Ralph Gemini.

## Prerequisites

- Ubuntu 22.04+ or Debian 12+ server
- SSH access configured
- At least 2GB RAM, 20GB disk

## Step 1: Prepare the Server

SSH to your server and run the setup script:

```bash
# Run setup script
curl -fsSL https://raw.githubusercontent.com/sandstream/ralph-gemini/main/core/scripts/vm-setup.sh | bash
```

Or manually install:

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Node.js via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20

# Install required tools
sudo apt-get install -y git curl jq

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install gh -y

# Install Playwright dependencies
sudo apt-get install -y libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
  libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
  libxrandr2 libgbm1 libasound2

# Create projects directory
mkdir -p ~/projects
```

## Step 2: Configure Security

```bash
# Disable password authentication (use SSH keys only)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Enable firewall
sudo ufw allow ssh
sudo ufw enable
```

## Step 3: Authenticate GitHub

```bash
gh auth login
```

## Step 4: Install AI CLI

### Option A: Gemini CLI
```bash
npm install -g @google/gemini-cli
gemini auth login
```

### Option B: Claude Code
```bash
npm install -g @anthropic-ai/claude-code
claude login
```

### Option C: API Key
```bash
echo 'export GOOGLE_API_KEY="your-key"' >> ~/.bashrc
# or
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
source ~/.bashrc
```

## Step 5: Update Local Config

On your local machine, update `.ralph/config.json`:

```json
{
  "execution": "ssh",
  "vm_ip": "YOUR_SERVER_IP",
  "user": "your-username",
  "defaultModel": "gemini"
}
```

## Step 6: Test Connection

```bash
# From local machine
ssh your-username@YOUR_SERVER_IP "echo 'Connection OK'"
```

## Step 7: Set Up SSH Key (if needed)

```bash
# Generate key on local machine
ssh-keygen -t ed25519 -C "ralph@local"

# Copy to server
ssh-copy-id your-username@YOUR_SERVER_IP
```

## Usage

```bash
/ralph:discover   # Create PRD
/ralph:plan       # Generate specs
/ralph:deploy     # Send to VM
/ralph:status     # Check progress
/ralph:review     # Review results
```

## VPS Providers

Affordable options for running Ralph:

| Provider | Specs | Price |
|----------|-------|-------|
| Hetzner | 2 vCPU, 4GB | €4/mo |
| DigitalOcean | 2 vCPU, 4GB | $24/mo |
| Vultr | 2 vCPU, 4GB | $24/mo |
| Linode | 2 vCPU, 4GB | $24/mo |

## Running on Home Server

If using a home server:

1. Set up port forwarding for SSH (port 22)
2. Use dynamic DNS if you don't have static IP
3. Consider using Tailscale for secure access

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Use Tailscale IP in config
```

## Troubleshooting

### Connection refused
```bash
# Check SSH is running
sudo systemctl status sshd

# Check firewall
sudo ufw status
```

### Permission denied
```bash
# Check SSH key
ssh -v your-username@YOUR_SERVER_IP

# Ensure key is added
ssh-add ~/.ssh/id_ed25519
```

### AI CLI not working
```bash
# Check it's installed
which gemini || which claude

# Check API key
echo $GOOGLE_API_KEY
echo $ANTHROPIC_API_KEY
```
