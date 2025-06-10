#!/usr/bin/env node

// Standalone worker copy script that can be run independently
const fs = require('fs');
const path = require('path');

console.log('🚀 STANDALONE WORKER COPY STARTING');

// Worker copy function
function copyWorkerFile() {
  const workerSource = path.join(__dirname, 'node_modules', 'gif.js', 'dist', 'gif.worker.js');
  const staticTarget = path.join(__dirname, '..', 'priv', 'static', 'gif.worker.js');
  
  console.log('Source path:', workerSource);
  console.log('Target path:', staticTarget);
  
  // Ensure target directory exists
  const targetDir = path.dirname(staticTarget);
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
    console.log('Created target directory:', targetDir);
  }
  
  if (fs.existsSync(workerSource)) {
    fs.copyFileSync(workerSource, staticTarget);
    console.log('✅ Successfully copied gif.worker.js');
    
    // Verify
    if (fs.existsSync(staticTarget)) {
      const stats = fs.statSync(staticTarget);
      console.log(`✅ Verified: ${stats.size} bytes written to ${staticTarget}`);
      return true;
    } else {
      console.error('❌ Verification failed - file not found after copy');
      return false;
    }
  } else {
    console.error('❌ Source file not found:', workerSource);
    
    // Try to find where the file actually is
    const nodeModulesGif = path.join(__dirname, 'node_modules', 'gif.js');
    if (fs.existsSync(nodeModulesGif)) {
      console.log('gif.js module found, looking for worker file...');
      function findGifWorker(dir, level = 0) {
        if (level > 3) return; // Prevent deep recursion
        
        try {
          const items = fs.readdirSync(dir);
          for (const item of items) {
            const fullPath = path.join(dir, item);
            const stat = fs.statSync(fullPath);
            
            if (stat.isFile() && item === 'gif.worker.js') {
              console.log('Found gif.worker.js at:', fullPath);
              return fullPath;
            } else if (stat.isDirectory() && level < 3) {
              const found = findGifWorker(fullPath, level + 1);
              if (found) return found;
            }
          }
        } catch (e) {
          // Ignore permission errors
        }
      }
      
      const foundWorker = findGifWorker(nodeModulesGif);
      if (foundWorker) {
        console.log('Attempting copy from found location...');
        fs.copyFileSync(foundWorker, staticTarget);
        console.log('✅ Successfully copied from alternative location');
        return true;
      }
    }
    
    return false;
  }
}

// Run the copy
const success = copyWorkerFile();
console.log('🚀 STANDALONE WORKER COPY', success ? 'COMPLETED' : 'FAILED');
process.exit(success ? 0 : 1);