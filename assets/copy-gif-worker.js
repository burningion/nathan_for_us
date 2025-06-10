#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Copy gif.js worker file to static directory (root level)
const sourceDir = path.join(__dirname, 'node_modules', 'gif.js', 'dist');
const targetDir = path.join(__dirname, '..', 'priv', 'static');

// Ensure target directory exists
if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}

// Copy gif.worker.js to static root (where Phoenix serves static files)
const workerSource = path.join(sourceDir, 'gif.worker.js');
const workerTargetRoot = path.join(targetDir, 'gif.worker.js');

console.log('Checking source:', workerSource);
console.log('Target path:', workerTargetRoot);

if (fs.existsSync(workerSource)) {
  fs.copyFileSync(workerSource, workerTargetRoot);
  console.log('✅ Copied gif.worker.js to static root');
  
  // Verify the copy
  if (fs.existsSync(workerTargetRoot)) {
    const stats = fs.statSync(workerTargetRoot);
    console.log(`✅ Verified: gif.worker.js exists (${stats.size} bytes)`);
  } else {
    console.error('❌ Failed to verify copied file');
  }
} else {
  console.error('❌ gif.worker.js not found in node_modules');
  console.log('Available files in dist:', fs.readdirSync(sourceDir));
}

console.log('GIF.js worker file copied successfully!');