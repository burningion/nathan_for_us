const TimelineScrubber = {
  mounted() {
    this.isDragging = false;
    this.timeline = this.el;
    this.scrubber = this.timeline.querySelector('.timeline-scrubber');
    this.tooltip = this.timeline.querySelector('.timeline-tooltip');
    
    // Get initial position from data attribute
    this.currentPosition = parseFloat(this.timeline.dataset.position) || 0;
    
    // Bind events
    this.timeline.addEventListener('mousedown', this.handleMouseDown.bind(this));
    this.timeline.addEventListener('mousemove', this.handleMouseMove.bind(this));
    this.timeline.addEventListener('mouseup', this.handleMouseUp.bind(this));
    this.timeline.addEventListener('mouseleave', this.handleMouseLeave.bind(this));
    
    // Global mouse events for dragging
    document.addEventListener('mousemove', this.handleGlobalMouseMove.bind(this));
    document.addEventListener('mouseup', this.handleGlobalMouseUp.bind(this));
    
    // Touch events for mobile
    this.timeline.addEventListener('touchstart', this.handleTouchStart.bind(this));
    this.timeline.addEventListener('touchmove', this.handleTouchMove.bind(this));
    this.timeline.addEventListener('touchend', this.handleTouchEnd.bind(this));
    
    console.log('Timeline scrubber mounted at position:', this.currentPosition);
  },
  
  updated() {
    // Update position from server
    const newPosition = parseFloat(this.timeline.dataset.position) || 0;
    if (Math.abs(newPosition - this.currentPosition) > 0.001) {
      this.currentPosition = newPosition;
      this.updateVisualPosition(newPosition);
    }
  },
  
  destroyed() {
    // Clean up global event listeners
    document.removeEventListener('mousemove', this.handleGlobalMouseMove.bind(this));
    document.removeEventListener('mouseup', this.handleGlobalMouseUp.bind(this));
  },
  
  handleMouseDown(e) {
    if (e.button !== 0) return; // Only left mouse button
    
    e.preventDefault();
    this.isDragging = true;
    this.timeline.classList.add('cursor-grabbing');
    
    const position = this.getPositionFromEvent(e);
    this.updatePosition(position);
    
    console.log('Timeline scrub started at position:', position);
  },
  
  handleMouseMove(e) {
    if (!this.isDragging) {
      // Show tooltip on hover
      const position = this.getPositionFromEvent(e);
      this.updateTooltipPosition(position);
      return;
    }
    
    e.preventDefault();
    const position = this.getPositionFromEvent(e);
    this.updatePosition(position);
  },
  
  handleMouseUp(e) {
    if (!this.isDragging) return;
    
    this.isDragging = false;
    this.timeline.classList.remove('cursor-grabbing');
    
    const position = this.getPositionFromEvent(e);
    this.finalizePosition(position);
    
    console.log('Timeline scrub ended at position:', position);
  },
  
  handleMouseLeave(e) {
    if (!this.isDragging) {
      // Hide tooltip when leaving timeline
      if (this.tooltip) {
        this.tooltip.style.opacity = '0';
      }
    }
  },
  
  handleGlobalMouseMove(e) {
    if (!this.isDragging) return;
    
    e.preventDefault();
    const position = this.getPositionFromEvent(e);
    this.updatePosition(position);
  },
  
  handleGlobalMouseUp(e) {
    if (!this.isDragging) return;
    
    this.isDragging = false;
    this.timeline.classList.remove('cursor-grabbing');
    
    const position = this.getPositionFromEvent(e);
    this.finalizePosition(position);
  },
  
  // Touch event handlers
  handleTouchStart(e) {
    if (e.touches.length !== 1) return;
    
    e.preventDefault();
    this.isDragging = true;
    
    const position = this.getPositionFromTouch(e.touches[0]);
    this.updatePosition(position);
  },
  
  handleTouchMove(e) {
    if (!this.isDragging || e.touches.length !== 1) return;
    
    e.preventDefault();
    const position = this.getPositionFromTouch(e.touches[0]);
    this.updatePosition(position);
  },
  
  handleTouchEnd(e) {
    if (!this.isDragging) return;
    
    this.isDragging = false;
    
    // Use the last known position
    this.finalizePosition(this.currentPosition);
  },
  
  getPositionFromEvent(e) {
    return this.getPositionFromCoordinates(e.clientX);
  },
  
  getPositionFromTouch(touch) {
    return this.getPositionFromCoordinates(touch.clientX);
  },
  
  getPositionFromCoordinates(clientX) {
    const rect = this.timeline.getBoundingClientRect();
    const relativeX = clientX - rect.left;
    const position = relativeX / rect.width;
    
    // Clamp between 0 and 1
    return Math.max(0, Math.min(1, position));
  },
  
  updatePosition(position) {
    this.currentPosition = position;
    this.updateVisualPosition(position);
    
    // Send immediate feedback to server (debounced)
    clearTimeout(this.scrubTimeout);
    this.scrubTimeout = setTimeout(() => {
      this.pushEvent('timeline_scrub', { position: position.toString() });
    }, 50);
  },
  
  finalizePosition(position) {
    this.currentPosition = position;
    this.updateVisualPosition(position);
    
    // Clear any pending scrub events and send final position
    clearTimeout(this.scrubTimeout);
    this.pushEvent('timeline_click', { position: position.toString() });
  },
  
  updateVisualPosition(position) {
    if (this.scrubber) {
      this.scrubber.style.left = `${position * 100}%`;
    }
    
    if (this.tooltip) {
      this.tooltip.style.left = `${position * 100}%`;
      this.tooltip.style.opacity = '1';
    }
  },
  
  updateTooltipPosition(position) {
    if (this.tooltip) {
      this.tooltip.style.left = `${position * 100}%`;
      this.tooltip.style.opacity = '1';
    }
  }
};

export default TimelineScrubber;