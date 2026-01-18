# /ralph:deploy - Deploy to VM or Docker

Push project to GitHub and start Ralph on VM or Docker.

## Usage
```
/ralph:deploy
/ralph:deploy --local   # Use Docker locally
```

## Prerequisites
- IMPLEMENTATION_PLAN.md or specs/*.md must exist
- VM or Docker must be configured (.ralph/config.json)
- GitHub repo must exist

## Instructions

You are a deployment assistant. Run these steps:

**STEP 1: VALIDATE**

Run this validation and STOP if anything is missing:

```bash
echo "=== PRE-DEPLOY VALIDATION ==="

# 1. Specs must exist
SPEC_COUNT=$(ls -1 specs/*.md 2>/dev/null | grep -v "CR-" | wc -l | tr -d ' ')
if [ "$SPEC_COUNT" -eq 0 ]; then
    echo "FATAL: No specs found in specs/"
    echo "   Run /ralph:plan first to generate specs"
    exit 1
fi
echo "Found $SPEC_COUNT specs"

# 2. PRD should exist
if [ ! -f "docs/PRD.md" ] && [ ! -f "docs/prd.md" ]; then
    echo "WARNING: No PRD found in docs/"
    echo "   Recommended: Run /ralph:discover first"
fi

# 3. AGENTS.md should exist
if [ ! -f "AGENTS.md" ]; then
    echo "WARNING: No AGENTS.md found"
    echo "   Ralph works better with project instructions"
fi

# 4. Config
if [ ! -f ".ralph/config.json" ]; then
    echo "FATAL: No config found (.ralph/config.json)"
    echo "   Run: npx ralph-gemini install"
    exit 1
fi
echo "Config OK"

# 5. Git remote
if ! git remote get-url origin > /dev/null 2>&1; then
    echo "FATAL: No git remote 'origin'"
    echo "   Add with: git remote add origin <url>"
    exit 1
fi
echo "Git remote OK"

echo ""
echo "=== VALIDATION PASSED ==="
```

If anything is FATAL → **STOP** and ask user to fix it.
If anything is WARNING → Ask if they want to continue anyway.

**STEP 2: CHECK AI ON VM**

Read `.ralph/config.json` to see the execution type:

If `gcp` or `ssh`:
Check if AI CLI is configured on VM:
```bash
# For GCP
gcloud compute ssh user@vm --command="which gemini || which claude"

# For SSH
ssh user@ip "which gemini || which claude"
```

If not found:
```
AI CLI needs to be installed on VM

SSH to VM and run:
  npm install -g @google/gemini-cli && gemini auth login
OR
  npm install -g @anthropic-ai/claude-code && claude login

Then run /ralph:deploy again
```
**STOP** and wait for user.

**STEP 3: PUSH TO GITHUB**
```bash
git add -A
git commit -m "Deploy: $(date +%Y-%m-%d_%H:%M)" || true
git push origin main
```

**STEP 4: START ON VM/DOCKER**

Based on config.execution:

**If `gcp`:**
```bash
gcloud compute ssh user@vm --command="
  cd ~/projects
  REPO=\$(basename \$(git remote get-url origin) .git)
  if [ -d \"\$REPO\" ]; then
    cd \$REPO && git pull
  else
    gh repo clone \$(git remote get-url origin) \$REPO
    cd \$REPO
  fi
  [ -f package.json ] && [ ! -d node_modules ] && npm install
  chmod +x ralph .ralph/scripts/*.sh
  nohup ./ralph > ralph-deploy.log 2>&1 &
  echo 'Ralph started'
"
```

**If `ssh`:**
```bash
ssh user@ip "
  cd ~/projects
  REPO=\$(basename \$(git remote get-url origin) .git)
  if [ -d \"\$REPO\" ]; then
    cd \$REPO && git pull
  else
    git clone \$(git remote get-url origin) \$REPO
    cd \$REPO
  fi
  [ -f package.json ] && [ ! -d node_modules ] && npm install
  chmod +x ralph .ralph/scripts/*.sh
  nohup ./ralph > ralph-deploy.log 2>&1 &
  echo 'Ralph started'
"
```

**If `docker`:**
```bash
docker build -t ralph-gemini -f .ralph/templates/Dockerfile .
docker run -d --name ralph-runner -v $(pwd):/app ralph-gemini ./ralph
```

**STEP 5: OUTPUT THIS EXACT MESSAGE:**
```
Started on {execution type}!

Follow progress:
  {appropriate command for checking logs}

Next: Run /ralph:status to check progress
```

**IMPORTANT:**
- Use `gh repo clone` NOT `git clone` on VM (handles auth)
- Run ralph.sh in background with nohup
- Give user commands to follow progress
