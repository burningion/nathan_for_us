/**
 * SlidingBackground hook for creating a sliding background of video frames
 * Similar to the timeline view but for the main page background
 */
export const SlidingBackground = {
  mounted() {
    this.frameIndex = 0;
    this.frames = [];
    this.isPlaying = false;
    this.intervalId = null;
    this.transitionDuration = 1500; // 1.5 seconds per frame for more activity
    this.userActive = false;
    this.activityTimeout = null;
    
    // Parse frames data with error handling
    try {
      const framesData = this.el.dataset.frames;
      console.log('Raw frames data:', framesData?.substring(0, 100) + '...');
      this.frames = JSON.parse(framesData || '[]');
      console.log('Parsed frames:', this.frames.length, 'frames loaded');
    } catch (error) {
      console.error('Error parsing frames data:', error);
      this.frames = [];
    }
    
    this.playButton = this.el.querySelector('.play-button');
    this.backgroundElement = this.el.querySelector('.sliding-background');
    
    console.log('Play button found:', !!this.playButton);
    console.log('Background element found:', !!this.backgroundElement);
    
    if (this.playButton) {
      this.playButton.addEventListener('click', () => this.togglePlay());
    }
    
    // Initialize with first frame if available
    if (this.frames.length > 0) {
      console.log('Setting initial frame');
      this.setBackgroundFrame(0);
    } else {
      console.log('No frames available to display');
    }
    
    // Set up user activity detection
    this.setupActivityDetection();
    
    // Auto-start after a short delay to let the page settle
    setTimeout(() => {
      if (this.frames.length > 0) {
        this.play();
      }
    }, 2000);
  },
  
  destroyed() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
    if (this.activityTimeout) {
      clearTimeout(this.activityTimeout);
    }
    // Remove event listeners
    document.removeEventListener('click', this.onUserActivity);
    document.removeEventListener('keydown', this.onUserActivity);
    document.removeEventListener('scroll', this.onUserActivity);
    document.removeEventListener('mousemove', this.onUserActivity);
  },
  
  setupActivityDetection() {
    // Bind the activity handler to maintain 'this' context
    this.onUserActivity = this.handleUserActivity.bind(this);
    
    // Listen for various user interactions
    document.addEventListener('click', this.onUserActivity);
    document.addEventListener('keydown', this.onUserActivity);
    document.addEventListener('scroll', this.onUserActivity);
    
    // Listen for mouse movement but throttle it
    let mouseMoveThrottle = null;
    const throttledMouseMove = () => {
      if (!mouseMoveThrottle) {
        mouseMoveThrottle = setTimeout(() => {
          this.onUserActivity();
          mouseMoveThrottle = null;
        }, 500); // Only trigger every 500ms
      }
    };
    document.addEventListener('mousemove', throttledMouseMove);
  },
  
  handleUserActivity() {
    const wasActive = this.userActive;
    this.userActive = true;
    
    // Start animation if not already playing
    if (!this.isPlaying && this.frames.length > 0) {
      console.log('User activity detected - starting animation');
      this.play();
    } else if (this.isPlaying && !wasActive) {
      // Restart with faster speed if becoming active
      console.log('User became active - speeding up animation');
      this.pause();
      this.play();
    }
    
    // Reset activity timeout
    if (this.activityTimeout) {
      clearTimeout(this.activityTimeout);
    }
    
    // Slow down animation after period of lower activity (10 seconds)
    this.activityTimeout = setTimeout(() => {
      const wasUserActive = this.userActive;
      this.userActive = false;
      console.log('User less active - slowing animation');
      
      // Restart animation with slower speed if still playing
      if (this.isPlaying && wasUserActive) {
        this.pause();
        this.play();
      }
      
      // Stop completely after longer inactivity
      setTimeout(() => {
        if (!this.userActive) {
          console.log('User inactive - pausing animation');
          this.pause();
        }
      }, 20000);
    }, 10000);
  },
  
  togglePlay() {
    if (this.isPlaying) {
      this.pause();
    } else {
      this.play();
    }
  },
  
  play() {
    if (this.frames.length === 0) return;
    
    this.isPlaying = true;
    this.updatePlayButton();
    
    // Use faster animation during user activity
    const animationSpeed = this.userActive ? 1000 : this.transitionDuration;
    
    this.intervalId = setInterval(() => {
      this.nextFrame();
    }, animationSpeed);
  },
  
  pause() {
    this.isPlaying = false;
    this.updatePlayButton();
    
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  },
  
  nextFrame() {
    if (this.frames.length === 0) return;
    
    this.frameIndex = (this.frameIndex + 1) % this.frames.length;
    this.setBackgroundFrame(this.frameIndex);
  },
  
  setBackgroundFrame(index) {
    if (!this.backgroundElement || !this.frames[index]) {
      console.log('Cannot set background frame - missing element or frame');
      return;
    }
    
    const frame = this.frames[index];
    const imageDataUrl = `data:image/jpeg;base64,${frame.image_data}`;
    
    // Create smooth transition effect
    this.backgroundElement.style.backgroundImage = `url(${imageDataUrl})`;
  },
  
  updatePlayButton() {
    if (!this.playButton) return;
    
    const icon = this.playButton.querySelector('svg');
    if (this.isPlaying) {
      // Show pause icon
      icon.innerHTML = `
        <rect x="6" y="4" width="4" height="16"></rect>
        <rect x="14" y="4" width="4" height="16"></rect>
      `;
      this.playButton.setAttribute('title', 'Pause slideshow');
    } else {
      // Show play icon
      icon.innerHTML = `
        <polygon points="5,3 19,12 5,21"></polygon>
      `;
      this.playButton.setAttribute('title', 'Play slideshow');
    }
  }
};