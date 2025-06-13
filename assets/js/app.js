// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import client-side GIF generator hook
import ClientGifGenerator from './hooks/client_gif_generator.js'
import TimelineScrubber from './hooks/timeline_scrubber.js'
import FrameMultiSelect from './hooks/frame_multi_select.js'
import FrameSelection from './hooks/frame_selection.js'
import { SlidingBackground } from './hooks/sliding_background.js'

// Frame Animator Hook for cycling through frame sequences
let Hooks = {}

// Client-side GIF generator hook
Hooks.ClientGifGenerator = ClientGifGenerator

// Timeline scrubber hook
Hooks.TimelineScrubber = TimelineScrubber

// Frame multi-select hook
Hooks.FrameMultiSelect = FrameMultiSelect

// Individual frame selection hook
Hooks.FrameSelection = FrameSelection

// Sliding background hook
Hooks.SlidingBackground = SlidingBackground

// Welcome Dialog Hook for first-time visitors
Hooks.WelcomeDialog = {
  mounted() {
    // Check if this is the first visit to the chat room
    const hasVisited = localStorage.getItem('nathan-chat-visited')
    
    if (hasVisited) {
      // User has visited before, close the dialog immediately
      this.pushEvent('close_welcome_dialog', {})
    } else {
      // First-time visitor, allow clicking backdrop to close
      this.el.addEventListener('click', (e) => {
        // Only close if clicking the backdrop (not the dialog content)
        if (e.target === this.el) {
          localStorage.setItem('nathan-chat-visited', 'true')
          this.pushEvent('close_welcome_dialog', {})
        }
      })
    }
  }
}

// Welcome Dialog Button Hook to mark user as visited
Hooks.WelcomeDialogButton = {
  mounted() {
    this.el.addEventListener('click', () => {
      localStorage.setItem('nathan-chat-visited', 'true')
    })
  }
}

// Message Form Hook to handle clearing the textarea after sending
Hooks.MessageForm = {
  mounted() {
    this.textarea = this.el.querySelector('#message-textarea')
    
    // Listen for the clear event from the server
    this.handleEvent("clear_message_form", () => {
      if (this.textarea) {
        this.textarea.value = ''
        this.textarea.focus()
      }
    })
  },
  
  updated() {
    // Ensure textarea is cleared when form is reset
    if (this.textarea) {
      const formData = new FormData(this.el)
      const content = formData.get('chat_message[content]') || ''
      if (content.trim() === '') {
        this.textarea.value = ''
      }
    }
  }
}


Hooks.FrameAnimator = {
  mounted() {
    // Store reference to this hook instance for external access
    this.el.phxHook = this
    this.isPlaying = true
    this.transitionDuration = 150 // ms for smooth crossfade
    
    this.updateAnimationRange()
    
    if (this.animationFrameCount > 1) {
      this.startAnimation()
    }
  },
  
  updated() {
    // Stop current animation and restart with new range
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout)
    }
    
    this.updateAnimationRange()
    
    if (this.animationFrameCount > 1) {
      this.startAnimation()
    }
  },
  
  destroyed() {
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout)
    }
  },
  
  updateAnimationRange() {
    this.frames = JSON.parse(this.el.dataset.frames).filter(frame => frame !== null)
    this.selectedIndices = JSON.parse(this.el.dataset.selectedIndices || '[]')
    this.frameTimestamps = JSON.parse(this.el.dataset.frameTimestamps || '[]')
    this.animationSpeed = parseInt(this.el.dataset.animationSpeed) || 300
    
    this.animationFrameCount = this.selectedIndices.length
    this.currentFrameIndex = 0  // Index within selectedIndices array
    this.frameElements = Array.from(this.el.querySelectorAll('[data-frame-index]'))
    this.counter = document.getElementById(this.el.id.replace('animation-container', 'frame-counter'))
    
    // Set up smooth transitions on all frame elements
    this.frameElements.forEach(el => {
      el.style.transition = `opacity ${this.transitionDuration}ms ease-in-out, transform ${this.transitionDuration}ms ease-in-out`
      el.classList.remove('opacity-100')
      el.classList.add('opacity-0')
      el.style.transform = 'scale(1)'
    })
    
    // Show the first selected frame with smooth entry
    if (this.selectedIndices.length > 0 && this.frameElements[this.selectedIndices[0]]) {
      const firstFrame = this.frameElements[this.selectedIndices[0]]
      // Use requestAnimationFrame for smooth initial transition
      requestAnimationFrame(() => {
        firstFrame.classList.remove('opacity-0')
        firstFrame.classList.add('opacity-100')
        firstFrame.style.transform = 'scale(1.02)' // Slight emphasis
        
        // Reset scale after transition
        setTimeout(() => {
          firstFrame.style.transform = 'scale(1)'
        }, this.transitionDuration)
      })
    }
    
    // Update counter with smooth fade
    if (this.counter) {
      this.updateCounterWithTransition(`1/${this.animationFrameCount}`)
    }
  },
  
  updateCounterWithTransition(text) {
    if (!this.counter) return
    
    this.counter.style.transition = 'opacity 100ms ease-in-out'
    this.counter.style.opacity = '0'
    
    setTimeout(() => {
      this.counter.textContent = text
      this.counter.style.opacity = '1'
    }, 100)
  },
  
  startAnimation() {
    this.scheduleNextFrame()
  },
  
  scheduleNextFrame() {
    if (this.animationFrameCount <= 1 || !this.isPlaying) return
    
    const currentElement = this.frameElements[this.selectedIndices[this.currentFrameIndex]]
    
    // Move to next frame within selected indices
    this.currentFrameIndex = (this.currentFrameIndex + 1) % this.selectedIndices.length
    const nextElement = this.frameElements[this.selectedIndices[this.currentFrameIndex]]
    
    if (currentElement && nextElement) {
      // Smooth crossfade transition
      this.performCrossfade(currentElement, nextElement)
    }
    
    // Update counter with transition
    if (this.counter) {
      this.updateCounterWithTransition(`${this.currentFrameIndex + 1}/${this.animationFrameCount}`)
    }
    
    // Schedule next frame with user-controlled speed plus transition time
    this.animationTimeout = setTimeout(() => {
      this.scheduleNextFrame()
    }, Math.max(this.animationSpeed, this.transitionDuration + 50))
  },
  
  performCrossfade(currentElement, nextElement) {
    // Start hiding current element
    currentElement.style.opacity = '0'
    currentElement.style.transform = 'scale(0.98)'
    
    // Show next element with slight delay for smoother transition
    setTimeout(() => {
      nextElement.style.opacity = '1'
      nextElement.style.transform = 'scale(1.02)'
      
      // Reset transform after transition
      setTimeout(() => {
        currentElement.style.transform = 'scale(1)'
        nextElement.style.transform = 'scale(1)'
      }, this.transitionDuration)
    }, this.transitionDuration * 0.3)
  },
  
  // New methods for user control
  pause() {
    this.isPlaying = false
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout)
    }
  },
  
  play() {
    this.isPlaying = true
    if (this.animationFrameCount > 1) {
      this.scheduleNextFrame()
    }
  },
  
  setSpeed(speedMs) {
    this.animationSpeed = speedMs
  },
  
  // Navigate to specific frame
  goToFrame(frameIndex) {
    if (frameIndex >= 0 && frameIndex < this.selectedIndices.length) {
      const currentElement = this.frameElements[this.selectedIndices[this.currentFrameIndex]]
      const targetElement = this.frameElements[this.selectedIndices[frameIndex]]
      
      if (currentElement && targetElement) {
        this.currentFrameIndex = frameIndex
        this.performCrossfade(currentElement, targetElement)
        
        if (this.counter) {
          this.updateCounterWithTransition(`${frameIndex + 1}/${this.animationFrameCount}`)
        }
      }
    }
  }
}

// Video Search Welcome Hook for first-time visitors
Hooks.VideoSearchWelcome = {
  mounted() {
    // Check if this is the first visit to video search
    const hasVisited = localStorage.getItem('video-search-visited')
    
    if (!hasVisited) {
      // First-time visitor, show the modal
      this.pushEvent('show_welcome_for_first_visit', {})
    }
  }
}

// Mark video search as visited
Hooks.VideoSearchVisited = {
  mounted() {
    this.el.addEventListener('click', () => {
      localStorage.setItem('video-search-visited', 'true')
    })
  }
}

// Form clearing hook for expand frame inputs
Hooks.ExpandFrameForm = {
  mounted() {
    // Listen for successful frame expansion to clear the form
    this.handleEvent("clear_expand_form", () => {
      const input = this.el.querySelector('input[type="number"]')
      if (input) {
        input.value = ''
        input.blur()
      }
    })
  }
}

// Timeline Tutorial Hook for first-time visitors
Hooks.TimelineTutorial = {
  mounted() {
    // Check if this is the first visit to the timeline
    const hasVisited = localStorage.getItem('timeline-tutorial-visited')
    
    if (!hasVisited) {
      // First-time visitor, show the tutorial modal
      this.pushEvent('show_tutorial_modal', {})
    }
  }
}

// Timeline Tutorial Button Hook to mark user as visited
Hooks.TimelineTutorialButton = {
  mounted() {
    this.el.addEventListener('click', () => {
      localStorage.setItem('timeline-tutorial-visited', 'true')
    })
  }
}

// GIF Preview Hook for timeline frame selection
Hooks.GifPreview = {
  mounted() {
    this.frames = JSON.parse(this.el.dataset.frames || '[]')
    this.currentIndex = 0
    this.isPlaying = true
    this.speed = 150 // milliseconds between frames
    
    this.playPauseBtn = this.el.querySelector('#gif-play-pause')
    this.speedSelect = this.el.querySelector('#gif-speed')
    this.frameCounter = this.el.querySelector('#frame-counter')
    
    // Set up controls
    if (this.playPauseBtn) {
      this.playPauseBtn.addEventListener('click', () => this.togglePlayback())
    }
    
    if (this.speedSelect) {
      this.speedSelect.addEventListener('change', (e) => {
        this.speed = parseInt(e.target.value)
      })
    }
    
    // Start the animation if we have frames
    if (this.frames.length > 0) {
      this.createImageElement()
      this.startAnimation()
    }
  },
  
  updated() {
    // Stop current animation
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout)
    }
    
    // Update frames from new data
    this.frames = JSON.parse(this.el.dataset.frames || '[]')
    this.currentIndex = 0
    
    // Restart animation if we have frames
    if (this.frames.length > 0) {
      this.createImageElement()
      this.startAnimation()
    }
  },
  
  destroyed() {
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout)
    }
  },
  
  createImageElement() {
    // Remove existing image
    const existingImg = this.el.querySelector('img')
    if (existingImg) {
      existingImg.remove()
    }
    
    // Create new image element
    this.img = document.createElement('img')
    this.img.className = 'w-full h-full object-cover'
    this.img.style.transition = 'opacity 0.1s ease-in-out'
    
    // Insert before the loading text
    const loadingDiv = this.el.querySelector('.absolute.inset-0')
    if (loadingDiv) {
      loadingDiv.style.display = 'none'
    }
    
    this.el.appendChild(this.img)
    this.displayCurrentFrame()
  },
  
  displayCurrentFrame() {
    if (this.frames.length === 0 || !this.img) return
    
    const frame = this.frames[this.currentIndex]
    if (frame && frame.image_data) {
      this.img.src = `data:image/jpeg;base64,${frame.image_data}`
    }
    
    // Update counter
    if (this.frameCounter) {
      this.frameCounter.textContent = `${this.currentIndex + 1} / ${this.frames.length}`
    }
  },
  
  startAnimation() {
    if (this.frames.length <= 1) return
    
    this.scheduleNextFrame()
  },
  
  scheduleNextFrame() {
    if (!this.isPlaying || this.frames.length <= 1) return
    
    this.animationTimeout = setTimeout(() => {
      this.currentIndex = (this.currentIndex + 1) % this.frames.length
      this.displayCurrentFrame()
      this.scheduleNextFrame()
    }, this.speed)
  },
  
  togglePlayback() {
    this.isPlaying = !this.isPlaying
    
    if (this.playPauseBtn) {
      this.playPauseBtn.textContent = this.isPlaying ? 'Pause' : 'Play'
    }
    
    if (this.isPlaying) {
      this.scheduleNextFrame()
    } else if (this.animationTimeout) {
      clearTimeout(this.animationTimeout)
    }
  }
}


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

