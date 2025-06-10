import GIF from 'gif.js';

class GifGenerator {
  constructor() {
    this.isReady = true; // gif.js doesn't need loading
  }

  async loadFFmpeg() {
    // gif.js doesn't need loading, just return immediately
    console.log('GIF.js ready - no loading required');
    return Promise.resolve();
  }

  async generateGif(frameDataArray, options = {}) {
    const {
      framerate = 6,
      width = 600,
      height = 'auto',
      quality = 'medium'
    } = options;

    console.log(`Generating GIF with ${frameDataArray.length} frames using gif.js`);

    // Validate input
    if (!frameDataArray || frameDataArray.length === 0) {
      return Promise.reject(new Error('No frame data provided'));
    }

    console.log('Frame data sample:', frameDataArray[0] ? frameDataArray[0].substring(0, 50) + '...' : 'No data');

    return new Promise((resolve, reject) => {
      try {
        // Create GIF instance with correct worker path
        const gif = new GIF({
          workers: 1, // Reduce to 1 worker to simplify
          quality: quality === 'high' ? 1 : quality === 'low' ? 20 : 10,
          width: width,
          height: height === 'auto' ? null : height,
          debug: true, // Enable debug logging
          workerScript: '/gif.worker.js' // Try root path first
        });

        // Track progress
        gif.on('progress', (p) => {
          console.log(`GIF generation progress: ${Math.round(p * 100)}%`);
        });

        gif.on('finished', (blob) => {
          console.log('GIF generation completed');
          clearTimeout(timeout); // Clear the timeout
          try {
            // Convert blob to Uint8Array
            const reader = new FileReader();
            reader.onload = () => {
              const arrayBuffer = reader.result;
              const uint8Array = new Uint8Array(arrayBuffer);
              resolve(uint8Array);
            };
            reader.onerror = () => {
              reject(new Error('Failed to read generated GIF blob'));
            };
            reader.readAsArrayBuffer(blob);
          } catch (error) {
            reject(error);
          }
        });

        gif.on('error', (error) => {
          console.error('GIF generation error:', error);
          reject(error);
        });

        // Add timeout to prevent hanging
        const timeout = setTimeout(() => {
          reject(new Error('GIF generation timed out after 30 seconds'));
        }, 30000);

        // Load each frame as an image and add to GIF
        let loadedFrames = 0;
        const delay = Math.round(1000 / framerate); // Convert FPS to delay in ms

        console.log('Starting to load frames...');
        
        frameDataArray.forEach((frameData, index) => {
          console.log(`Loading frame ${index + 1}/${frameDataArray.length}`);
          
          const img = new Image();
          
          img.onload = () => {
            console.log(`Frame ${index + 1} loaded successfully`);
            
            try {
              // Create canvas to resize image if needed
              const canvas = document.createElement('canvas');
              const ctx = canvas.getContext('2d');
              
              // Set canvas size
              canvas.width = width;
              canvas.height = height === 'auto' ? (width * img.height / img.width) : height;
              
              // Draw and resize image
              ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
              
              // Add frame to GIF
              gif.addFrame(canvas, { delay: delay });
              
              loadedFrames++;
              console.log(`Frames loaded: ${loadedFrames}/${frameDataArray.length}`);
              
              if (loadedFrames === frameDataArray.length) {
                console.log('All frames loaded, rendering GIF...');
                gif.render();
              }
            } catch (error) {
              console.error(`Error processing frame ${index}:`, error);
              clearTimeout(timeout);
              reject(error);
            }
          };
          
          img.onerror = (error) => {
            console.error(`Failed to load frame ${index}:`, error);
            clearTimeout(timeout);
            reject(new Error(`Failed to load frame ${index}`));
          };
          
          // Validate frame data before setting src
          if (!frameData || frameData.trim() === '') {
            console.error(`Frame ${index} has empty data`);
            clearTimeout(timeout);
            reject(new Error(`Frame ${index} has empty data`));
            return;
          }
          
          img.src = `data:image/jpeg;base64,${frameData}`;
        });

      } catch (error) {
        console.error('GIF generation failed:', error);
        reject(error);
      }
    });
  }

  // Convert Uint8Array to base64 for display
  uint8ArrayToBase64(uint8Array) {
    let binary = '';
    const len = uint8Array.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(uint8Array[i]);
    }
    return btoa(binary);
  }

  // Create downloadable blob URL
  createDownloadUrl(uint8Array) {
    const blob = new Blob([uint8Array], { type: 'image/gif' });
    return URL.createObjectURL(blob);
  }
}

export default GifGenerator;