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

// Frame Animator Hook for cycling through frame sequences
let Hooks = {}

// Client-side GIF generator hook
Hooks.ClientGifGenerator = ClientGifGenerator

// Timeline scrubber hook
Hooks.TimelineScrubber = TimelineScrubber

// Frame multi-select hook
Hooks.FrameMultiSelect = FrameMultiSelect

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

