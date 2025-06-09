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
Hooks.FrameAnimator = {
  mounted() {
    this.updateAnimationRange()
    
    if (this.animationFrameCount > 1) {
      this.startAnimation()
    }
  },
  
  updated() {
    // Stop current animation and restart with new range
    if (this.animationInterval) {
      clearInterval(this.animationInterval)
    }
    
    this.updateAnimationRange()
    
    if (this.animationFrameCount > 1) {
      this.startAnimation()
    }
  },
  
  destroyed() {
    if (this.animationInterval) {
      clearInterval(this.animationInterval)
    }
  },
  
  updateAnimationRange() {
    this.frames = JSON.parse(this.el.dataset.frames).filter(frame => frame !== null)
    this.selectedIndices = JSON.parse(this.el.dataset.selectedIndices || '[]')
    
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
    this.animationInterval = setInterval(() => {
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
    }, 134) // 134ms per frame (~7.5fps simulation)
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

