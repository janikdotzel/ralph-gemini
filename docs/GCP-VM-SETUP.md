# GCP VM Setup Guide

Set up a Google Cloud VM for running Ralph Gemini autonomously.

## Prerequisites

- Google Cloud account with billing enabled
- `gcloud` CLI installed and authenticated
- SSH key configured

## Step 1: Create the VM

```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Create VM
gcloud compute instances create ralph-sandbox \
  --zone=europe-north1-a \
  --machine-type=e2-medium \
  --image-family=ubuntu-2404-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --tags=ralph

# Note the external IP from the output
```

### Recommended specs:
- **Machine type:** e2-medium (2 vCPU, 4GB RAM) - good balance
- **Disk:** 50GB SSD
- **Region:** Choose closest to you

## Step 2: Configure Firewall (optional)

If you need to access dev server from outside:

```bash
gcloud compute firewall-rules create allow-ralph-dev \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:5173,tcp:3000 \
  --source-ranges=YOUR_IP/32 \
  --target-tags=ralph
```

## Step 3: SSH to VM and Run Setup

```bash
# SSH to VM
gcloud compute ssh ralph-sandbox --zone=europe-north1-a

# Run setup script
curl -fsSL https://raw.githubusercontent.com/sandstream/ralph-gemini/main/core/scripts/vm-setup.sh | bash
```

Or manually:

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Node.js via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install gh jq -y

# Install Playwright dependencies
sudo apt-get install -y libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
  libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
  libxrandr2 libgbm1 libasound2

# Create projects directory
mkdir -p ~/projects
```

## Step 4: Authenticate GitHub

```bash
gh auth login
# Follow the prompts to authenticate via browser
```

## Step 5: Install AI CLI

### Option A: Gemini CLI (Recommended)
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
# For Gemini
echo 'export GOOGLE_API_KEY="your-api-key"' >> ~/.bashrc

# For Claude
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc

source ~/.bashrc
```

## Step 6: Update Local Config

On your local machine, update `.ralph/config.json`:

```json
{
  "execution": "gcp",
  "vm_name": "ralph-sandbox",
  "project": "YOUR_PROJECT_ID",
  "zone": "europe-north1-a",
  "user": "your-username",
  "defaultModel": "gemini"
}
```

## Step 7: Test Connection

```bash
# From local machine
gcloud compute ssh ralph-sandbox --zone=europe-north1-a --command="echo 'Connection OK'"
```

## Usage

Once set up, use the workflow:

```bash
/ralph:discover   # Create PRD
/ralph:plan       # Generate specs
/ralph:deploy     # Send to VM
/ralph:status     # Check progress
/ralph:review     # Review results
```

## Cost Management

**Stop VM when not in use:**
```bash
gcloud compute instances stop ralph-sandbox --zone=europe-north1-a
```

**Start VM:**
```bash
gcloud compute instances start ralph-sandbox --zone=europe-north1-a
```

**Estimated costs:**
- e2-medium running 24/7: ~$25/month
- e2-medium running 8h/day: ~$8/month
- Stopped VM: ~$2/month (disk only)

## Troubleshooting

### SSH connection fails
```bash
# Check VM status
gcloud compute instances describe ralph-sandbox --zone=europe-north1-a

# Reset SSH keys
gcloud compute config-ssh
```

### AI CLI not found
```bash
# Check PATH
which gemini || which claude

# Reinstall
npm install -g @google/gemini-cli
```

### Permission denied
```bash
# Ensure scripts are executable
chmod +x ralph .ralph/scripts/*.sh
```
