import inquirer from 'inquirer';
import chalk from 'chalk';
import fs from 'fs-extra';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const CORE_DIR = join(__dirname, '..', 'core');
const TARGET_DIR = '.ralph';
const CONFIG_FILE = join(TARGET_DIR, 'config.json');
const PKG_JSON = join(__dirname, '..', 'package.json');

// Auto-detect GitHub username from gh CLI
function getGitHubUsername() {
  try {
    return execSync('gh api user --jq ".login"', { stdio: ['pipe', 'pipe', 'ignore'] })
      .toString()
      .trim();
  } catch {
    return '';
  }
}

// Get version from package.json
function getVersion() {
  try {
    const pkg = fs.readJsonSync(PKG_JSON);
    return pkg.version;
  } catch {
    return '1.0.0';
  }
}

// Check if CLI tool is installed
function checkCli(cmd) {
  try {
    execSync(`which ${cmd}`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

export async function install() {
  const fire = chalk.hex('#FF6B35');
  const brick = chalk.hex('#4285F4'); // Google blue
  const gold = chalk.hex('#FBBC04'); // Google yellow

  console.log(fire(`
  ====================================================

  `) + brick(`██████╗  █████╗ ██╗     ██████╗ ██╗  ██╗`) + fire(`
  `) + brick(`██╔══██╗██╔══██╗██║     ██╔══██╗██║  ██║`) + fire(`
  `) + brick(`██████╔╝███████║██║     ██████╔╝███████║`) + fire(`
  `) + brick(`██╔══██╗██╔══██║██║     ██╔═══╝ ██╔══██║`) + fire(`
  `) + brick(`██║  ██║██║  ██║███████╗██║     ██║  ██║`) + fire(`
  `) + brick(`╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝`) + fire(`

          `) + gold(`G E M I N I   E D I T I O N`) + fire(`

  `) + gold(`Build while you sleep. Wake to working code`) + fire(`
  `) + chalk.dim(`         Powered by Gemini CLI & Antigravity`) + fire(`

  ====================================================
`));

  // Disclaimer
  console.log(chalk.yellow(`
DISCLAIMER
------------------------------------------------------------

Ralph Gemini runs AI-driven autonomous code.

`), chalk.red(`
ALWAYS RUN RALPH IN AN EXTERNAL SANDBOX ENVIRONMENT!
Use a disposable VM that can be destroyed if something goes wrong.
NEVER run Ralph directly on your local machine.
`), chalk.yellow(`
- YOU are fully responsible for all actions performed
- Review generated code before running in production
- NEVER store sensitive credentials in code or config
- Ralph can make mistakes - monitor and verify results

By continuing, you accept full responsibility for usage.
------------------------------------------------------------
`));

  const { acceptDisclaimer } = await inquirer.prompt([{
    type: 'rawlist',
    name: 'acceptDisclaimer',
    message: 'Do you accept the terms above?',
    choices: [
      { name: 'Yes, I understand and accept', value: true },
      { name: 'No, cancel installation', value: false }
    ]
  }]);

  if (!acceptDisclaimer) {
    console.log(chalk.dim('Installation cancelled.'));
    return;
  }

  console.log('');

  // Check if already installed
  if (await fs.pathExists(CONFIG_FILE)) {
    const { overwrite } = await inquirer.prompt([{
      type: 'confirm',
      name: 'overwrite',
      message: 'Ralph is already installed. Reinstall? (config will be preserved)',
      default: false
    }]);

    if (!overwrite) {
      console.log(chalk.yellow('Use "ralph-gemini update" to update core files.'));
      return;
    }
  }

  // Collect configuration
  const answers = await inquirer.prompt([
    {
      type: 'rawlist',
      name: 'execution',
      message: 'Execution environment?',
      choices: [
        { name: 'GCP VM (recommended)', value: 'gcp' },
        { name: 'Self-hosted VM (SSH)', value: 'ssh' },
        { name: 'Docker (local fallback)', value: 'docker' },
        { name: 'Skip (configure later)', value: 'none' }
      ]
    }
  ]);

  // Check CLI if provider selected
  if (answers.execution === 'gcp') {
    if (!checkCli('gcloud')) {
      console.log(chalk.yellow(`\n  gcloud CLI not found.`));
      console.log(chalk.dim(`Install with: brew install --cask google-cloud-sdk`));
    } else {
      console.log(chalk.green(`  gcloud CLI found`));
    }
  } else if (answers.execution === 'docker') {
    if (!checkCli('docker')) {
      console.log(chalk.yellow(`\n  docker CLI not found.`));
      console.log(chalk.dim(`Install Docker Desktop from docker.com`));
    } else {
      console.log(chalk.green(`  docker CLI found`));
    }
  }

  // VM-specific questions
  let vmConfig = {};
  if (answers.execution === 'gcp') {
    const vmAnswers = await inquirer.prompt([
      {
        type: 'input',
        name: 'vm_name',
        message: 'VM name?',
        default: 'ralph-sandbox'
      },
      {
        type: 'input',
        name: 'project',
        message: 'GCP project ID?',
        default: ''
      },
      {
        type: 'input',
        name: 'zone',
        message: 'GCP zone?',
        default: 'europe-north1-a'
      }
    ]);
    vmConfig = vmAnswers;
  } else if (answers.execution === 'ssh') {
    const vmAnswers = await inquirer.prompt([
      {
        type: 'input',
        name: 'vm_ip',
        message: 'VM IP address?',
        default: ''
      },
      {
        type: 'input',
        name: 'vm_user',
        message: 'SSH user?',
        default: process.env.USER || 'ralph'
      }
    ]);
    vmConfig = vmAnswers;
  }

  // AI Model selection
  const modelAnswers = await inquirer.prompt([
    {
      type: 'rawlist',
      name: 'defaultModel',
      message: 'Default AI model for execution?',
      choices: [
        { name: 'Gemini CLI (recommended)', value: 'gemini' },
        { name: 'Claude via Antigravity', value: 'claude' },
        { name: 'Auto-detect (use AGENTS.md)', value: 'auto' }
      ]
    }
  ]);

  // GitHub - auto-detect from gh CLI
  const detectedGithub = getGitHubUsername();
  if (detectedGithub) {
    console.log(chalk.green(`  GitHub detected: ${detectedGithub}`));
  }

  const githubAnswers = await inquirer.prompt([
    {
      type: 'input',
      name: 'github_username',
      message: 'GitHub username?',
      default: detectedGithub
    }
  ]);

  // Show model-specific instructions
  if (modelAnswers.defaultModel === 'gemini') {
    console.log(chalk.cyan(`
------------------------------------------------------------
  Gemini CLI Setup
------------------------------------------------------------

  After VM is created, ensure Gemini CLI is installed:

    npm install -g @anthropic-ai/gemini-cli

  Authenticate:

    gemini auth login

  This will open a browser to authenticate.
------------------------------------------------------------
`));
  } else if (modelAnswers.defaultModel === 'claude') {
    console.log(chalk.cyan(`
------------------------------------------------------------
  Claude via Antigravity Setup
------------------------------------------------------------

  After VM is created, ensure Antigravity is installed:

    pip install antigravity

  Set your API key:

    export ANTHROPIC_API_KEY="sk-ant-..."

  Add to ~/.bashrc for persistence.
------------------------------------------------------------
`));
  }

  // Build config
  const config = {
    version: getVersion(),
    execution: answers.execution,
    ...vmConfig,
    user: vmConfig.vm_user || process.env.USER || '',
    defaultModel: modelAnswers.defaultModel,
    notifications: {
      enabled: true,
      type: 'os' // Use OS notifications
    },
    github: {
      username: githubAnswers.github_username
    }
  };

  // Install core files
  console.log(chalk.cyan('\nInstalling...'));

  await fs.ensureDir(TARGET_DIR);

  // Copy core directories
  const dirs = ['lib', 'scripts', 'templates', 'commands'];
  for (const dir of dirs) {
    const src = join(CORE_DIR, dir);
    const dest = join(TARGET_DIR, dir);
    if (await fs.pathExists(src)) {
      await fs.copy(src, dest);
      const files = await fs.readdir(dest).catch(() => []);
      console.log(chalk.green(`  ${dir}/ installed (${files.length} items)`));
    }
  }

  // Copy commands to .gemini/commands for Gemini CLI integration
  const geminiSrc = join(CORE_DIR, 'commands');
  const geminiDest = join('.gemini', 'commands');
  if (await fs.pathExists(geminiSrc)) {
    await fs.ensureDir('.gemini');
    await fs.copy(geminiSrc, geminiDest, { overwrite: true });
    console.log(chalk.green('  .gemini/commands/ synced for Gemini CLI'));
  }

  // Save version file for update checking
  await fs.writeFile(join(TARGET_DIR, 'version'), config.version);
  console.log(chalk.green(`  version ${config.version}`));

  // Save config
  await fs.writeJson(CONFIG_FILE, config, { spaces: 2 });
  console.log(chalk.green('  config.json created'));

  // Create ralph wrapper script
  const wrapperPath = 'ralph';
  await fs.writeFile(wrapperPath, `#!/bin/bash
# Ralph CLI wrapper
RALPH_DIR=".ralph"
exec "$RALPH_DIR/scripts/ralph.sh" "$@"
`);
  await fs.chmod(wrapperPath, '755');
  console.log(chalk.green('  ralph wrapper created'));

  // Done
  console.log(chalk.green(`
====================================================

          RALPH GEMINI INSTALLED!

====================================================
`));

  console.log(chalk.cyan('Next steps:'));
  console.log(chalk.dim('  1. Run /ralph:discover in Gemini CLI to set up your project'));
  console.log(chalk.dim('  2. Or run: ./ralph --help'));
  console.log('');
}
