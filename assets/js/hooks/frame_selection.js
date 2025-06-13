const FrameSelection = {
  mounted() {
    this.frameIndex = parseInt(this.el.dataset.frameIndex);
    this.isMobile = 'ontouchstart' in window;
    this.touchStartTime = null;
    this.longPressTimer = null;
    this.longPressActive = false;
    
    // Get parent container to access multi-select state
    this.container = this.el.closest('[phx-hook="FrameMultiSelect"]');
    
    this.setupEventListeners();
    
    console.log('FrameSelection hook mounted for frame', this.frameIndex, '- Mobile:', this.isMobile);
  },
  
  updated() {
    this.frameIndex = parseInt(this.el.dataset.frameIndex);
  },
  
  destroyed() {
    this.cleanupEventListeners();
  },
  
  setupEventListeners() {
    this.cleanupEventListeners();
    
    if (this.isMobile) {
      // Touch-based interaction for mobile
      this.boundTouchStart = this.handleTouchStart.bind(this);
      this.boundTouchEnd = this.handleTouchEnd.bind(this);
      this.boundTouchMove = this.handleTouchMove.bind(this);
      
      this.el.addEventListener('touchstart', this.boundTouchStart, { passive: false });
      this.el.addEventListener('touchend', this.boundTouchEnd, { passive: false });
      this.el.addEventListener('touchmove', this.boundTouchMove, { passive: false });
    } else {
      // Mouse-based interaction for desktop
      this.boundClick = this.handleClick.bind(this);
      this.el.addEventListener('click', this.boundClick);
    }
    
    // Prevent default drag behavior
    this.boundDragStart = (e) => e.preventDefault();
    this.el.addEventListener('dragstart', this.boundDragStart);
  },
  
  cleanupEventListeners() {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }
    
    if (this.boundClick) {
      this.el.removeEventListener('click', this.boundClick);
    }
    
    if (this.boundTouchStart) {
      this.el.removeEventListener('touchstart', this.boundTouchStart);
      this.el.removeEventListener('touchend', this.boundTouchEnd);
      this.el.removeEventListener('touchmove', this.boundTouchMove);
    }
    
    if (this.boundDragStart) {
      this.el.removeEventListener('dragstart', this.boundDragStart);
    }
  },
  
  handleClick(e) {
    // Check if modal button was clicked
    if (e.target.closest('button[phx-click="show_frame_modal"]')) {
      return; // Let the modal button handle its own click
    }
    
    e.preventDefault();
    e.stopPropagation();
    
    const shiftKey = e.shiftKey;
    
    if (shiftKey) {
      // Try to get the last clicked index from the multi-select hook
      const multiSelectHook = this.container?.phxHook;
      if (multiSelectHook && multiSelectHook.lastClickedIndex !== null) {
        this.handleRangeSelection(multiSelectHook.lastClickedIndex, this.frameIndex);
        return;
      }
    }
    
    // Regular single frame selection
    this.selectFrame(shiftKey);
    
    // Update last clicked index in multi-select hook if available
    if (this.container?.phxHook) {
      this.container.phxHook.lastClickedIndex = this.frameIndex;
    }
  },
  
  handleTouchStart(e) {
    this.touchStartTime = Date.now();
    this.longPressActive = false;
    
    // Start long press timer for range selection
    this.longPressTimer = setTimeout(() => {
      this.longPressActive = true;
      this.startRangeSelection();
      
      // Haptic feedback if available
      if (navigator.vibrate) {
        navigator.vibrate(50);
      }
      
      // Visual feedback
      this.showLongPressFeedback();
    }, 500); // 500ms long press
  },
  
  handleTouchMove(e) {
    // Cancel long press if finger moves too much
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }
  },
  
  handleTouchEnd(e) {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }
    
    if (this.longPressActive) {
      // Long press selection completed
      this.longPressActive = false;
      return;
    }
    
    // Check if modal button was touched
    if (e.target.closest('button[phx-click="show_frame_modal"]')) {
      return; // Let the modal button handle its own touch
    }
    
    const touchDuration = Date.now() - this.touchStartTime;
    
    // Only trigger tap if it was a quick touch (not a long press)
    if (touchDuration < 500) {
      e.preventDefault();
      e.stopPropagation();
      
      this.handleFrameTap();
    }
  },
  
  handleFrameTap() {
    // Show tap feedback
    this.showTapFeedback();
    
    // Regular selection
    this.selectFrame(false);
    
    // Update last clicked index in multi-select hook if available
    if (this.container?.phxHook) {
      this.container.phxHook.lastClickedIndex = this.frameIndex;
    }
  },
  
  startRangeSelection() {
    const multiSelectHook = this.container?.phxHook;
    if (multiSelectHook && multiSelectHook.lastClickedIndex !== null) {
      this.handleRangeSelection(multiSelectHook.lastClickedIndex, this.frameIndex);
    } else {
      // No previous selection, just select this frame
      this.selectFrame(false);
      if (multiSelectHook) {
        multiSelectHook.lastClickedIndex = this.frameIndex;
      }
    }
  },
  
  handleRangeSelection(startIndex, endIndex) {
    const minIndex = Math.min(startIndex, endIndex);
    const maxIndex = Math.max(startIndex, endIndex);
    
    // Create array of indices in the range
    const rangeIndices = [];
    for (let i = minIndex; i <= maxIndex; i++) {
      rangeIndices.push(i);
    }
    
    console.log('Range selection from', startIndex, 'to', endIndex, ':', rangeIndices);
    
    this.pushEvent('select_frame_range', {
      start_index: minIndex.toString(),
      end_index: maxIndex.toString(),
      indices: rangeIndices.map(i => i.toString())
    });
  },
  
  selectFrame(shiftKey) {
    this.pushEvent('select_frame', { 
      frame_index: this.frameIndex.toString(),
      shift_key: shiftKey.toString()
    });
  },
  
  showTapFeedback() {
    const frameCard = this.el.closest('.frame-card');
    if (frameCard) {
      frameCard.classList.add('tap-feedback');
      setTimeout(() => {
        frameCard.classList.remove('tap-feedback');
      }, 150);
    }
  },
  
  showLongPressFeedback() {
    const frameCard = this.el.closest('.frame-card');
    if (frameCard) {
      frameCard.classList.add('long-press-feedback');
      setTimeout(() => {
        frameCard.classList.remove('long-press-feedback');
      }, 300);
    }
  }
};

export default FrameSelection;