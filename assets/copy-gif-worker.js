#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Copy gif.js worker file to static assets directory
const sourceDir = path.join(__dirname, 'node_modules', 'gif.js', 'dist');
const targetDir = path.join(__dirname, '..', 'priv', 'static', 'assets');

// Ensure target directory exists
if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}

// Copy gif.worker.js
const workerSource = path.join(sourceDir, 'gif.worker.js');
const workerTarget = path.join(targetDir, 'gif.worker.js');

if (fs.existsSync(workerSource)) {
  fs.copyFileSync(workerSource, workerTarget);
  console.log('Copied gif.worker.js to static assets');
} else {
  console.warn('gif.worker.js not found in node_modules');
}

console.log('GIF.js worker file copied successfully!');