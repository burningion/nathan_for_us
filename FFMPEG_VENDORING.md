# FFMPEG.wasm Local Vendoring Setup

## Overview
To avoid CORS issues with CDN-hosted FFMPEG.wasm files, we now vendor the FFMPEG core files locally.

## Setup Complete ✅

### Files Added:
- `assets/copy-ffmpeg.js` - Script to copy FFMPEG files to static directory
- `priv/static/ffmpeg/` - Directory containing vendored FFMPEG files:
  - `ffmpeg-core.js`
  - `ffmpeg-core.wasm` 
  - `ffmpeg-core.worker.js`

### Configuration Updated:
- `assets/package.json` - Added `@ffmpeg/core-st` dependency and copy script
- `lib/nathan_for_us_web.ex` - Added "ffmpeg" to static_paths
- `assets/js/gif_generator.js` - Updated to use local files instead of CDN

## Usage

### Development:
The files are automatically copied when you run:
```bash
mix assets.deploy
```

### Server Restart Required:
After updating `static_paths`, you need to restart the Phoenix server for the changes to take effect.

### Verification:
After restarting the server, these URLs should be accessible:
- `http://localhost:4001/ffmpeg/ffmpeg-core.js`
- `http://localhost:4001/ffmpeg/ffmpeg-core.wasm`
- `http://localhost:4001/ffmpeg/ffmpeg-core.worker.js`

## Production Deployment

### Gigalixir:
The vendored files will be included in the deployment automatically since they're in `priv/static/ffmpeg/` and the build process copies them.

### Benefits:
- ✅ No CORS issues
- ✅ Faster loading (local files)
- ✅ More reliable (no external CDN dependency)
- ✅ Works offline
- ✅ Consistent performance

## Troubleshooting

If client-side GIF generation still fails:
1. Restart the Phoenix server
2. Clear browser cache
3. Check browser console for detailed error messages
4. Verify files exist at `/ffmpeg/` URLs