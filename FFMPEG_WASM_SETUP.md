# FFMPEG.wasm Client-side GIF Generation Setup

## Overview
This setup moves GIF generation from the server to the client browser using FFMPEG.wasm, reducing server load and improving scalability.

## Local Development Setup

### 1. Install Node.js Dependencies
```bash
cd assets
npm install
```

### 2. Build Assets
```bash
# Development build with watch
npm run watch

# Or production build
npm run build
```

### 3. Update Phoenix Config
Make sure your `config/dev.exs` has the proper asset watching:

```elixir
config :nathan_for_us, NathanForUsWeb.Endpoint,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    # Add npm watcher if needed
    npm: ["run", "watch", cd: Path.expand("../assets", __DIR__)]
  ]
```

## Gigalixir Deployment Setup

### 1. Add Node.js Buildpack
Create or update `.buildpacks` file in your project root:

```
https://github.com/HashNuke/heroku-buildpack-elixir
https://github.com/heroku/heroku-buildpack-nodejs
```

### 2. Add Node.js Version
Create `assets/.nvmrc`:

```
18.17.0
```

### 3. Update Gigalixir Build Config
Create or update `elixir_buildpack.config`:

```
erlang_version=25.3
elixir_version=1.15.7
always_rebuild=true
runtime_path=/app
```

### 4. Add Build Scripts to package.json
The `assets/package.json` should have:

```json
{
  "scripts": {
    "build": "esbuild js/app.js --bundle --outdir=../priv/static/assets --external:/fonts/* --external:/images/*",
    "deploy": "npm run build"
  },
  "engines": {
    "node": "18.17.0",
    "npm": "9.6.7"
  }
}
```

### 5. Update Phoenix Deployment Config
In `config/runtime.exs`, ensure assets are properly configured:

```elixir
if config_env() == :prod do
  # ... existing config ...
  
  config :nathan_for_us, NathanForUsWeb.Endpoint,
    # ... other config ...
    static_url: [
      scheme: "https", 
      host: host, 
      port: 443
    ],
    # Ensure MIME types for wasm files
    static_extensions: ~w(.js .css .wasm .png .svg .ico .txt)
end
```

### 6. Deploy to Gigalixir
```bash
# Add files to git
git add .
git commit -m "Add FFMPEG.wasm client-side GIF generation"

# Deploy
git push gigalixir main
```

## HTTPS Requirement
⚠️ **Important**: FFMPEG.wasm requires HTTPS to load WebAssembly files due to browser security policies. Gigalixir provides HTTPS by default, so this should work out of the box.

## Browser Compatibility

### Supported Browsers:
- ✅ Chrome 57+
- ✅ Firefox 52+
- ✅ Safari 11+
- ✅ Edge 79+

### Fallback Strategy:
The implementation includes a server-side fallback button for:
- Older browsers that don't support WebAssembly
- Cases where FFMPEG.wasm fails to load
- Users who prefer server-side processing

## Performance Benefits

### Client-side Advantages:
- 🚀 **Zero server load** for GIF generation
- 📱 **Better UX** - progress indicators and immediate feedback
- 🌐 **Scalability** - unlimited concurrent GIF generation
- 💰 **Cost savings** - reduced server CPU usage

### Quality Features:
- High-quality palette generation
- Adaptive frame rates based on source video FPS
- Optimized compression settings
- No file size limits from server constraints

## Troubleshooting

### Common Issues:

1. **FFMPEG.wasm fails to load**
   - Ensure HTTPS is enabled
   - Check browser console for CORS errors
   - Verify CDN URLs are accessible

2. **Build fails on Gigalixir**
   - Check Node.js version compatibility
   - Ensure all dependencies are in package.json
   - Verify buildpack order

3. **Large GIFs cause memory issues**
   - Browser memory limits apply
   - Consider frame count limits in UI
   - Add client-side validation

### Debug Commands:
```bash
# Test local build
cd assets && npm run build

# Check Gigalixir logs
gigalixir logs

# Test in browser console
console.log(window.liveSocket)
```

## Usage

### For Users:
1. Select frames in the admin interface
2. Click "🚀 Create GIF (Client-side)" for fast, local processing
3. Use "Server Fallback" if client-side generation fails
4. Download the generated GIF with a single click

### For Developers:
- Monitor client-side errors in browser console
- Server fallback ensures 100% success rate
- Status messages provide real-time feedback
- No server resources consumed for successful client-side generations

This setup provides a robust, scalable solution that dramatically reduces server load while maintaining full compatibility and fallback options.