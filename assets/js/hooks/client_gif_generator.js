import GifGenerator from '../gif_generator.js';

const ClientGifGenerator = {
  mounted() {
    this.gifGenerator = new GifGenerator();
    this.isGenerating = false;
    
    // Pre-load FFmpeg when the hook mounts
    this.preloadFFmpeg();
    
    this.handleEvent("start_gif_generation", (payload) => {
      console.log("Received start_gif_generation event:", payload);
      this.generateGif(payload);
    });
  },

  async preloadFFmpeg() {
    try {
      this.pushEvent("gif_status_update", { status: "loading_ffmpeg", message: "Loading FFmpeg.wasm..." });
      await this.gifGenerator.loadFFmpeg();
      this.pushEvent("gif_status_update", { status: "ffmpeg_ready", message: "FFmpeg.wasm ready" });
    } catch (error) {
      console.error("Failed to preload FFmpeg:", error);
      this.pushEvent("gif_status_update", { 
        status: "ffmpeg_error", 
        message: `FFmpeg load failed: ${error.message}` 
      });
    }
  },

  async generateGif(payload) {
    if (this.isGenerating) {
      console.log("GIF generation already in progress");
      return;
    }

    const { frames, fps = 6, options = {} } = payload;
    console.log("Processing payload:", { frameCount: frames?.length, fps, options });
    
    if (!frames || frames.length === 0) {
      this.pushEvent("gif_status_update", { 
        status: "error", 
        message: "No frames provided" 
      });
      return;
    }

    this.isGenerating = true;

    try {
      // Update status
      this.pushEvent("gif_status_update", { 
        status: "generating", 
        message: `Generating GIF from ${frames.length} frames...` 
      });

      // Extract base64 image data from frames
      console.log("Processing frames:", frames.length);
      const frameDataArray = frames.map((frame, index) => {
        console.log(`Processing frame ${index}:`, frame.image_data ? frame.image_data.substring(0, 50) + '...' : 'No image_data');
        return frame.image_data; // The LiveView already sends base64 data
      });

      // Generate GIF with options
      const gifOptions = {
        framerate: fps || options.framerate || 6,
        width: options.width || 600,
        quality: options.quality || 'medium'
      };
      
      console.log("GIF options:", gifOptions);

      const gifData = await this.gifGenerator.generateGif(frameDataArray, gifOptions);
      
      // Convert to base64 for transmission
      const base64Gif = this.gifGenerator.uint8ArrayToBase64(gifData);
      
      // Create download URL
      const downloadUrl = this.gifGenerator.createDownloadUrl(gifData);
      console.log("Created download URL:", downloadUrl);
      
      // Try multiple ways to send the event
      console.log("Attempting to send gif_generation_complete event...");
      
      // Method 1: Standard pushEvent
      this.pushEvent("gif_generation_complete", { 
        download_url: downloadUrl
      });
      
      // Method 2: Try to target the parent LiveView directly  
      const liveSocket = window.liveSocket;
      if (liveSocket) {
        console.log("Attempting to send via liveSocket...");
        // Find the LiveView element
        const liveViewEl = this.el.closest('[data-phx-main]') || this.el.closest('[phx-session]');
        if (liveViewEl && liveViewEl.phxHook) {
          liveViewEl.phxHook.pushEvent("gif_generation_complete", { 
            download_url: downloadUrl
          });
        }
      }
      
      console.log("Sent gif_generation_complete event with download_url:", downloadUrl);

    } catch (error) {
      console.error("Client-side GIF generation failed:", error);
      this.pushEvent("gif_status_update", { 
        status: "error", 
        message: `GIF generation failed: ${error.message}` 
      });
    } finally {
      this.isGenerating = false;
    }
  },

  destroyed() {
    // Clean up any resources
    if (this.gifGenerator) {
      this.gifGenerator.clearFiles();
    }
  }
};

export default ClientGifGenerator;