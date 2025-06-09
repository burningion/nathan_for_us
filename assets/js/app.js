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
    this.currentFrame = 0
    this.frames = JSON.parse(this.el.dataset.frames).filter(frame => frame !== null)
    this.frameCount = this.frames.length
    this.frameElements = Array.from(this.el.querySelectorAll('[data-frame-index]'))
    this.counter = document.getElementById(this.el.id.replace('animation-container', 'frame-counter'))
    
    if (this.frameCount > 1) {
      this.startAnimation()
    }
  },
  
  destroyed() {
    if (this.animationInterval) {
      clearInterval(this.animationInterval)
    }
  },
  
  startAnimation() {
    this.animationInterval = setInterval(() => {
      // Hide current frame
      this.frameElements.forEach(el => {
        el.classList.remove('opacity-100')
        el.classList.add('opacity-0')
      })
      
      // Move to next frame
      this.currentFrame = (this.currentFrame + 1) % this.frameCount
      
      // Show next frame
      if (this.frameElements[this.currentFrame]) {
        this.frameElements[this.currentFrame].classList.remove('opacity-0')
        this.frameElements[this.currentFrame].classList.add('opacity-100')
      }
      
      // Update counter
      if (this.counter) {
        this.counter.textContent = `${this.currentFrame + 1}/${this.frameCount}`
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

