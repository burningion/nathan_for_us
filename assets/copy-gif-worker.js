#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Copy gif.js worker file directly to assets directory for esbuild processing
const sourceDir = path.join(__dirname, 'node_modules', 'gif.js', 'dist');
const assetsDir = path.join(__dirname, 'js');
const staticDir = path.join(__dirname, '..', 'priv', 'static');

// Ensure directories exist
[assetsDir, staticDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Copy gif.worker.js to both locations
const workerSource = path.join(sourceDir, 'gif.worker.js');
const workerTargetAssets = path.join(assetsDir, 'gif.worker.js');
const workerTargetStatic = path.join(staticDir, 'gif.worker.js');

console.log('🎬 WORKER COPY SCRIPT RUNNING');
console.log('Source:', workerSource);
console.log('Target 1 (assets):', workerTargetAssets);
console.log('Target 2 (static):', workerTargetStatic);

if (fs.existsSync(workerSource)) {
  // Copy to assets directory (for esbuild)
  fs.copyFileSync(workerSource, workerTargetAssets);
  console.log('✅ Copied gif.worker.js to assets directory');
  
  // Copy to static directory (for direct serving)
  fs.copyFileSync(workerSource, workerTargetStatic);
  console.log('✅ Copied gif.worker.js to static directory');
  
  // Verify both copies
  [workerTargetAssets, workerTargetStatic].forEach(target => {
    if (fs.existsSync(target)) {
      const stats = fs.statSync(target);
      console.log(`✅ Verified: ${path.basename(target)} exists at ${target} (${stats.size} bytes)`);
    } else {
      console.error(`❌ Failed to verify: ${target}`);
    }
  });
} else {
  console.error('❌ gif.worker.js not found in node_modules');
  try {
    console.log('Available files in dist:', fs.readdirSync(sourceDir));
  } catch (e) {
    console.error('Could not list files in dist directory:', e.message);
  }
}

console.log('GIF.js worker file copied successfully!');