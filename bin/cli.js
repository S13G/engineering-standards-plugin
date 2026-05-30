#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

const packageRoot = path.join(__dirname, '..');
const filesToCopy = ['AGENTS.md', 'CLAUDE.md', 'GEMINI.md', '.cursorrules', 'skills', '.cursor', '.github'];

function getHelp() {
  return `
Engineering Standards CLI - Automatically install software engineering standards.

Usage:
  npx engineering-standards-plugin [options]

Options:
  -g, --global    Install globally to the user's home directory (~/.engineering-standards)
                  and link/update global configurations for Claude and Gemini CLI.
  -h, --help      Show this help message.
  --force         Overwrite existing files without prompting.
  `;
}

// Helper to recursively copy directories
function copyRecursive(src, dest, force = false) {
  const exists = fs.existsSync(dest);
  const stats = fs.statSync(src);
  const isDirectory = stats.isDirectory();

  if (isDirectory) {
    if (!exists) {
      fs.mkdirSync(dest, { recursive: true });
    }
    const files = fs.readdirSync(src);
    for (const file of files) {
      copyRecursive(path.join(src, file), path.join(dest, file), force);
    }
  } else {
    if (exists && !force) {
      console.log(`  \x1b[33m⚠ Skipped (already exists):\x1b[0m ${path.basename(dest)}`);
      return;
    }
    fs.copyFileSync(src, dest);
    console.log(`  \x1b[32m✔ Installed:\x1b[0m ${path.basename(dest)}`);
  }
}

function run() {
  const args = process.argv.slice(2);
  
  if (args.includes('-h') || args.includes('--help')) {
    console.log(getHelp());
    process.exit(0);
  }

  const isGlobal = args.includes('-g') || args.includes('--global');
  const force = args.includes('--force');

  const targetDir = isGlobal 
    ? path.join(os.homedir(), '.engineering-standards')
    : process.cwd();

  // Print gorgeous banner
  console.log(`\n\x1b[36m\x1b[1m┌──────────────────────────────────────────────────┐`);
  console.log(`│         ENGINEERING STANDARDS INSTALLER          │`);
  console.log(`│    Optimizing for the next human to read code    │`);
  console.log(`└──────────────────────────────────────────────────┘\x1b[22m\x1b[0m`);

  console.log(`  Mode:             \x1b[1m${isGlobal ? 'Global 🌍' : 'Local (Project) 📁'}\x1b[22m`);
  console.log(`  Target Directory: \x1b[35m${targetDir}\x1b[0m\n`);

  if (isGlobal && !fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }

  for (const item of filesToCopy) {
    const srcPath = path.join(packageRoot, item);
    const destPath = path.join(targetDir, item);

    if (fs.existsSync(srcPath)) {
      copyRecursive(srcPath, destPath, force);
    } else {
      console.warn(`  \x1b[31m✗ Source file missing from package:\x1b[0m ${item}`);
    }
  }

  if (isGlobal) {
    setupGlobalIntegrations(targetDir);
  }

  console.log('\n\x1b[32m\x1b[1m★ Installation completed successfully!\x1b[22m\x1b[0m');
  if (!isGlobal) {
    console.log('  Standards are now local to this project and will be read automatically by your AI agents.\n');
  } else {
    console.log('  Standards are now globally installed. Your AI agents have been configured to use them.\n');
  }
}

function setupGlobalIntegrations(globalDir) {
  console.log('\n  \x1b[1mSetting up global AI agent references...\x1b[22m');
  
  const home = os.homedir();

  // 1. Setup Claude Code global pointer
  const claudeDir = path.join(home, '.claude');
  const claudeFile = path.join(claudeDir, 'CLAUDE.md');
  const globalClaudeSource = path.join(globalDir, 'CLAUDE.md');

  if (!fs.existsSync(claudeDir)) {
    try {
      fs.mkdirSync(claudeDir, { recursive: true });
    } catch (e) {}
  }

  try {
    let shouldWriteClaude = true;
    if (fs.existsSync(claudeFile)) {
      const content = fs.readFileSync(claudeFile, 'utf8');
      if (content.includes('engineering-standards')) {
        console.log('  \x1b[33m⚠ Global Claude Code rules already contain a reference to engineering-standards.\x1b[0m');
        shouldWriteClaude = false;
      }
    }

    if (shouldWriteClaude) {
      const referenceText = `\n# Engineering Standards\n\nThis workspace uses the global engineering standards plugin.\nTo load domain references, refer to rules inside \`${globalDir}\`.\n\n@${path.join(globalDir, 'AGENTS.md')}\n`;
      fs.appendFileSync(claudeFile, referenceText, 'utf8');
      console.log(`  \x1b[32m✔ Added reference to global CLAUDE.md at:\x1b[0m ${claudeFile}`);
    }
  } catch (err) {
    console.log(`  \x1b[31m✗ Failed to auto-configure Claude Code:\x1b[0m ${err.message}`);
  }

  // 2. Setup Gemini CLI global pointer
  const geminiDir = path.join(home, '.gemini');
  const geminiFile = path.join(geminiDir, 'GEMINI.md');

  if (!fs.existsSync(geminiDir)) {
    try {
      fs.mkdirSync(geminiDir, { recursive: true });
    } catch (e) {}
  }

  try {
    let shouldWriteGemini = true;
    if (fs.existsSync(geminiFile)) {
      const content = fs.readFileSync(geminiFile, 'utf8');
      if (content.includes('engineering-standards')) {
        console.log('  \x1b[33m⚠ Global Gemini CLI rules already contain a reference to engineering-standards.\x1b[0m');
        shouldWriteGemini = false;
      }
    }

    if (shouldWriteGemini) {
      const referenceText = `\n# Engineering Standards\n\nThis workspace uses the global engineering standards plugin.\nTo load domain references, refer to rules inside \`${globalDir}\`.\n\n@${path.join(globalDir, 'AGENTS.md')}\n`;
      fs.appendFileSync(geminiFile, referenceText, 'utf8');
      console.log(`  \x1b[32m✔ Added reference to global GEMINI.md at:\x1b[0m ${geminiFile}`);
    }
  } catch (err) {
    console.log(`  \x1b[31m✗ Failed to auto-configure Gemini CLI:\x1b[0m ${err.message}`);
  }
}

run();
