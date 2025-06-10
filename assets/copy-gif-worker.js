#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Copy gif.js worker file to static directory (root level)
const sourceDir = path.join(__dirname, 'node_modules', 'gif.js', 'dist');
const targetDir = path.join(__dirname, '..', 'priv', 'static');
const assetsTargetDir = path.join(__dirname, '..', 'priv', 'static', 'assets');

// Ensure target directories exist
if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}
if (!fs.existsSync(assetsTargetDir)) {
  fs.mkdirSync(assetsTargetDir, { recursive: true });
}

// Copy gif.worker.js to both locations
const workerSource = path.join(sourceDir, 'gif.worker.js');
const workerTargetRoot = path.join(targetDir, 'gif.worker.js');
const workerTargetAssets = path.join(assetsTargetDir, 'gif.worker.js');

if (fs.existsSync(workerSource)) {
  fs.copyFileSync(workerSource, workerTargetRoot);
  console.log('Copied gif.worker.js to static root');
  fs.copyFileSync(workerSource, workerTargetAssets);
  console.log('Copied gif.worker.js to static assets');
} else {
  console.warn('gif.worker.js not found in node_modules');
}

console.log('GIF.js worker file copied successfully!');