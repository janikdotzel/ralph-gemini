# Ralph Gemini

AI-driven autonomous development workflow for Gemini CLI and Antigravity.

Build while you sleep. Wake to working code.

## Overview

Ralph Gemini is an autonomous development system that:
- **Discovers** requirements through interactive PRD creation
- **Plans** implementation with executable spec files
- **Executes** specs on a VM using Gemini CLI or Claude
- **Verifies** with build checks and E2E tests
- **Self-heals** by generating fix specs when tests fail

## Quick Start

```bash
# Install in your project
npx ralph-gemini install

# Start the guided workflow
/ralph:discover    # Create PRD
/ralph:plan        # Generate specs
/ralph:deploy      # Send to VM
/ralph:status      # Check progress
/ralph:review      # Review results
```

## Workflow

```
/ralph:discover  → "PRD created! Next: /ralph:plan"
/ralph:plan      → "8 specs created. Next: /ralph:deploy"
/ralph:deploy    → "Started on VM. Run /ralph:status to monitor"
/ralph:status    → "3/8 complete. Check again or /ralph:review when done"
/ralph:review    → "Found issues? Run /ralph:change-request"
/ralph:change-request → "2 fix specs created. Run /ralph:deploy"
```

## Execution Environments

### 1. GCP VM (Recommended)
```bash
# During install, select "GCP VM"
# See docs/GCP-VM-SETUP.md for setup
```

### 2. Self-Hosted VM
```bash
# During install, select "Self-hosted VM (SSH)"
# See docs/SELF-HOSTED-VM.md for setup
```

### 3. Docker (Local Fallback)
```bash
# During install, select "Docker (local fallback)"
# See docs/DOCKER-FALLBACK.md for setup
```

## AI Model Support

Ralph Gemini supports multiple AI backends:

| Model | Command | Setup |
|-------|---------|-------|
| Gemini CLI | `gemini` | `npm install -g @google/gemini-cli` |
| Claude Code | `claude` | `npm install -g @anthropic-ai/claude-code` |
| Antigravity | `antigravity claude` | `pip install antigravity` |

Configure in `.ralph/config.json`:
```json
{
  "defaultModel": "gemini"  // or "claude" or "auto"
}
```

## Project Structure

After installation:
```
your-project/
├── .ralph/
│   ├── config.json          # Configuration
│   ├── lib/                  # Shell utilities
│   ├── scripts/              # Main scripts
│   ├── templates/            # PRD, SPEC templates
│   └── commands/             # Workflow commands
├── .gemini/
│   └── commands/             # Gemini CLI commands
├── ralph                     # CLI wrapper
├── AGENTS.md                 # AI context file
├── docs/
│   └── PRD.md               # Product requirements
└── specs/
    └── *.md                  # Executable specs
```

## Key Features

### Spec-Based Execution
- Each spec is a focused task (max 20 lines)
- MD5 checksums track completion
- Specs can be re-run if modified

### Build Verification
- Automatic `npm run build` after each spec
- Self-healing for common errors
- Retry logic with configurable attempts

### E2E Testing
- Playwright integration
- Auto-generates fix specs on test failure
- Design review with screenshots

### Security
- Dangerous pattern detection
- Secret scanning before commits
- VM isolation for safe execution

## Commands Reference

| Command | Description |
|---------|-------------|
| `/ralph:discover` | Interactive PRD creation |
| `/ralph:plan` | Generate specs from PRD |
| `/ralph:deploy` | Deploy to VM/Docker |
| `/ralph:status` | Check execution progress |
| `/ralph:review` | Review completed work |
| `/ralph:change-request` | Create fix specs |

## Configuration

`.ralph/config.json`:
```json
{
  "version": "1.0.0",
  "execution": "gcp",           // gcp, ssh, docker, none
  "vm_name": "ralph-sandbox",
  "project": "my-gcp-project",
  "zone": "europe-north1-a",
  "user": "ralph",
  "defaultModel": "gemini",
  "notifications": {
    "enabled": true,
    "type": "os"
  },
  "github": {
    "username": "myuser"
  }
}
```

## Safety

**ALWAYS run Ralph in a sandbox environment:**
- Use a disposable VM
- Never run on production systems
- Review generated code before deploying
- Monitor execution and verify results

## Documentation

- [GCP VM Setup](docs/GCP-VM-SETUP.md)
- [Self-Hosted VM Setup](docs/SELF-HOSTED-VM.md)
- [Docker Fallback](docs/DOCKER-FALLBACK.md)

## License

MIT

## Credits

Based on [Ralph Inferno](https://github.com/sandstream/ralph-inferno) - adapted for Gemini CLI and multi-model support.
