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

// Frame Animator Hook for cycling through frame sequences
let Hooks = {}

// Animation Speed Slider Hook for real-time speed control
Hooks.AnimationSpeedSlider = {
  mounted() {
    // Prevent all mouse events from bubbling up to prevent modal closure
    this.el.addEventListener('mousedown', (e) => e.stopPropagation())
    this.el.addEventListener('mouseup', (e) => e.stopPropagation())
    this.el.addEventListener('click', (e) => e.stopPropagation())
    this.el.addEventListener('touchstart', (e) => e.stopPropagation())
    this.el.addEventListener('touchend', (e) => e.stopPropagation())
    
    this.el.addEventListener('input', (e) => {
      e.stopPropagation()
      const newSpeed = parseInt(e.target.value)
      const containerSelector = this.el.dataset.animationContainer
      const animationContainer = document.getElementById(containerSelector)
      
      if (animationContainer && animationContainer.phxHook) {
        // Update the animation speed directly in the FrameAnimator hook
        animationContainer.phxHook.updateAnimationSpeed(newSpeed)
      }
      
      // Update the display text
      const speedDisplay = document.getElementById('speed-display')
      if (speedDisplay) {
        speedDisplay.textContent = `${newSpeed}ms`
      }
    })
    
    // Handle change event for when user releases the slider
    this.el.addEventListener('change', (e) => {
      e.stopPropagation()
      const newSpeed = parseInt(e.target.value)
      const containerSelector = this.el.dataset.animationContainer
      const animationContainer = document.getElementById(containerSelector)
      
      if (animationContainer && animationContainer.phxHook) {
        // Ensure the speed is set when user releases slider
        animationContainer.phxHook.setAnimationSpeed(newSpeed)
      }
    })
  }
}

Hooks.FrameAnimator = {
  mounted() {
    // Store reference to this hook instance for external access
    this.el.phxHook = this
    
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
    this.animationSpeed = parseInt(this.el.dataset.animationSpeed) || 150
    
    this.animationFrameCount = this.selectedIndices.length
    this.currentFrameIndex = 0  // Index within selectedIndices array
    this.frameElements = Array.from(this.el.querySelectorAll('[data-frame-index]'))
    this.counter = document.getElementById(this.el.id.replace('animation-container', 'frame-counter'))
    
    // Hide all frames initially
    this.frameElements.forEach(el => {
      el.classList.remove('opacity-100')
      el.classList.add('opacity-0')
    })
    
    // Show the first selected frame
    if (this.selectedIndices.length > 0 && this.frameElements[this.selectedIndices[0]]) {
      this.frameElements[this.selectedIndices[0]].classList.remove('opacity-0')
      this.frameElements[this.selectedIndices[0]].classList.add('opacity-100')
    }
    
    // Update counter
    if (this.counter) {
      this.counter.textContent = `1/${this.animationFrameCount}`
    }
  },
  
  
  startAnimation() {
    this.scheduleNextFrame()
  },
  
  scheduleNextFrame() {
    if (this.animationFrameCount <= 1) return
    
    // Hide current frame
    if (this.selectedIndices.length > 0 && this.frameElements[this.selectedIndices[this.currentFrameIndex]]) {
      this.frameElements[this.selectedIndices[this.currentFrameIndex]].classList.remove('opacity-100')
      this.frameElements[this.selectedIndices[this.currentFrameIndex]].classList.add('opacity-0')
    }
    
    // Move to next frame within selected indices
    this.currentFrameIndex = (this.currentFrameIndex + 1) % this.selectedIndices.length
    
    // Show next frame
    if (this.selectedIndices.length > 0 && this.frameElements[this.selectedIndices[this.currentFrameIndex]]) {
      this.frameElements[this.selectedIndices[this.currentFrameIndex]].classList.remove('opacity-0')
      this.frameElements[this.selectedIndices[this.currentFrameIndex]].classList.add('opacity-100')
    }
    
    // Update counter
    if (this.counter) {
      this.counter.textContent = `${this.currentFrameIndex + 1}/${this.animationFrameCount}`
    }
    
    // Schedule next frame with user-controlled speed
    this.animationTimeout = setTimeout(() => {
      this.scheduleNextFrame()
    }, this.animationSpeed)
  },
  
  updateAnimationSpeed(newSpeed) {
    // Update the animation speed and restart animation with new timing
    this.animationSpeed = newSpeed
    
    // If animation is currently running, restart it with the new speed
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout)
      
      // Only restart if we have frames to animate
      if (this.animationFrameCount > 1) {
        this.scheduleNextFrame()
      }
    }
  },
  
  setAnimationSpeed(newSpeed) {
    // Set the animation speed and ensure it persists
    this.animationSpeed = newSpeed
    
    // If animation is currently running, restart it with the new speed
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout)
      
      // Only restart if we have frames to animate
      if (this.animationFrameCount > 1) {
        this.scheduleNextFrame()
      }
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

