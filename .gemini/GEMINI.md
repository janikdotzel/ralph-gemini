# Project: Ralph Gemini

## Overview
Ralph Gemini is an AI-driven autonomous development workflow tailored for Gemini CLI and Antigravity. It enables users to discover requirements, plan implementations, execute specs on a VM, and verify results with build checks and E2E tests.

## Tech Stack
- **Language**: JavaScript/Node.js (ES Modules)
- **Key Libraries**:
  - `commander` (CLI framework)
  - `inquirer` (Interactive prompts)
  - `chalk` (Terminal styling)
  - `fs-extra` (File system operations)
  - `node-notifier` (System notifications)

## Project Structure
- `bin/`: Entry point for the CLI (`ralph-gemini`).
- `cli/`: Installation and update logic.
  - `install.js`
  - `update.js`
- `core/`: Core application logic.
  - `commands/`: Workflow command implementations (e.g., discover, plan, deploy).
  - `lib/`: Shared utilities and helper functions.
  - `scripts/`: Main execution scripts.
  - `templates/`: Templates for PRDs and Specs.
- `docs/`: Documentation files.
- `package.json`: Dependency and script definitions.

## Key Features
- **Requirements Discovery**: Interactive PRD creation.
- **Spec Generation**: Creates focused, executable implementation specs.
- **VM Execution**: Runs specs in an isolated environment (GCP, Self-hosted, or Docker).
- **Self-Healing**: Automatically generates fix specs upon test failure.
- **Multi-Model Support**: Supports Gemini, Claude, and Antigravity.

## Workflow
1. `/ralph:discover`: Create PRD.
2. `/ralph:plan`: Generate specs.
3. `/ralph:deploy`: Execute specs.
4. `/ralph:status`: Check progress.
5. `/ralph:review`: Review work.
6. `/ralph:change-request`: Fix issues.

## Setup
Configured via `.ralph/config.json`. Supports GCP VM, SSH, and Docker execution environments.

---
*Created by Antigravity on 2026-01-19*
