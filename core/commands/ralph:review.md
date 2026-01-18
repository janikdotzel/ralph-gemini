# /ralph:review - Review Ralph's Work

Check if Ralph is done and review the results.

## Usage
```
/ralph:review
/ralph:review --tunnel   # Also open SSH tunnel for testing
```

## Instructions

**STEP 1: CHECK IF RALPH IS RUNNING**

Based on execution type:

**If `gcp` or `ssh`:**
```bash
# Check if ralph process is running
ssh user@ip 'pgrep -f "ralph.sh|gemini|claude" && echo "RUNNING" || echo "NOT_RUNNING"'
```

If RUNNING:
```
Ralph is still running!

Follow progress:
  ssh user@ip 'tail -f ~/projects/REPO/ralph-deploy.log'

Come back when Ralph is done.
```
**STOP HERE** - don't give more options.

**If `docker`:**
```bash
docker ps | grep ralph-runner && echo "RUNNING" || echo "NOT_RUNNING"
```

If NOT_RUNNING → continue to step 2.

**STEP 2: CHECK RESULTS**

```bash
# Fetch latest from VM
git pull origin main
```

Show:
- Number of commits Ralph made
- Which specs were completed

```bash
# Show recent commits
git log --oneline -10

# Show completed specs
ls -1 .spec-checksums/*.md5 2>/dev/null | xargs -I{} basename {} .md5
```

**STEP 3: LIST PRs (if any)**

```bash
gh pr list
```

**STEP 4: OPEN TUNNEL (if --tunnel)**

```bash
# Open SSH tunnel to test the app
ssh -L 5173:localhost:5173 -L 54321:localhost:54321 user@ip
```

Show:
```
Tunnels open!
- App: http://localhost:5173
- Supabase: http://localhost:54321

Press Ctrl+C to close tunnels.
```

**STEP 5: OUTPUT THIS EXACT MESSAGE:**

```
Review complete!

Commits by Ralph: {count}
Specs completed: {done}/{total}

Found issues? Run /ralph:change-request to create fix specs
All good? Your project is ready!
```
