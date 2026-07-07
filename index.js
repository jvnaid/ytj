#!/usr/bin/env node
const { spawnSync } = require('child_process');
const path = require('path');

// Determine the path to the powershell script
const scriptPath = path.join(__dirname, 'ytj.ps1');

// Grab all arguments passed to the CLI (ignoring the first 2 which are 'node' and 'index.js')
const args = process.argv.slice(2);

// Spawn PowerShell and execute the script
// Note: We try 'pwsh' (Core) first, and fallback to 'powershell.exe' (Windows native)
const command = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
const commandArgs = ['-ExecutionPolicy', 'Bypass', '-NoProfile', '-File', scriptPath, ...args];

const result = spawnSync(command, commandArgs, { stdio: 'inherit' });

// Exit with the exact same code your PowerShell script exited with
process.exit(result.status ?? 1);
