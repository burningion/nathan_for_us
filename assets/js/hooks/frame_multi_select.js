const FrameMultiSelect = {
  mounted() {
    this.isSelecting = false;
    this.startIndex = null;
    this.lastClickedIndex = null;
    this.selectionBox = null;
    
    // Store reference to the container
    this.container = this.el;
    
    // Bind event handlers to store references for cleanup
    this.boundFrameClick = this.handleFrameClick.bind(this);
    this.boundMouseDown = this.handleMouseDown.bind(this);
    this.boundMouseMove = this.handleMouseMove.bind(this);
    this.boundMouseUp = this.handleMouseUp.bind(this);
    this.boundDragStart = (e) => e.preventDefault();
    
    this.setupEventListeners();
    
    console.log('FrameMultiSelect hook mounted');
  },
  
  updated() {
    // Re-setup event listeners after updates
    this.setupEventListeners();
  },
  
  destroyed() {
    this.cleanupEventListeners();
  },
  
  setupEventListeners() {
    // Remove existing listeners first
    this.cleanupEventListeners();
    
    // Handle frame selection with shift-click
    this.container.addEventListener('click', this.boundFrameClick);
    
    // Handle drag selection
    this.container.addEventListener('mousedown', this.boundMouseDown);
    document.addEventListener('mousemove', this.boundMouseMove);
    document.addEventListener('mouseup', this.boundMouseUp);
    
    // Prevent default drag behavior on images
    this.container.addEventListener('dragstart', this.boundDragStart);
    
    console.log('FrameMultiSelect event listeners setup');
  },
  
  cleanupEventListeners() {
    if (this.boundFrameClick) {
      this.container.removeEventListener('click', this.boundFrameClick);
      this.container.removeEventListener('mousedown', this.boundMouseDown);
      document.removeEventListener('mousemove', this.boundMouseMove);
      document.removeEventListener('mouseup', this.boundMouseUp);
      this.container.removeEventListener('dragstart', this.boundDragStart);
    }
    
    // Clean up any existing selection box
    if (this.selectionBox) {
      this.selectionBox.remove();
      this.selectionBox = null;
    }
    
    console.log('Cleaned up FrameMultiSelect event listeners');
  },
  
  handleFrameClick(e) {
    const frameBtn = e.target.closest('.frame-select-btn');
    if (!frameBtn) return;
    
    const frameIndex = parseInt(frameBtn.dataset.frameIndex);
    const shiftKey = e.shiftKey;
    
    e.preventDefault();
    e.stopPropagation();
    
    if (shiftKey && this.lastClickedIndex !== null) {
      // Shift-click range selection
      this.handleRangeSelection(frameIndex);
    } else {
      // Single click selection
      this.lastClickedIndex = frameIndex;
      this.pushEvent('select_frame', { 
        frame_index: frameIndex.toString(),
        shift_key: shiftKey.toString()
      });
    }
  },
  
  handleRangeSelection(endIndex) {
    const startIndex = this.lastClickedIndex;
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
  
  handleMouseDown(e) {
    // Only start drag selection if clicking on empty space in the grid
    if (e.target.closest('.frame-card') || e.target.closest('.frame-select-btn')) {
      console.log('Click on frame card or button - not starting drag selection');
      return;
    }
    
    // Check if clicking on the frame grid container or its children
    const frameGrid = e.target.closest('.grid') || e.target.closest('[phx-hook="FrameMultiSelect"]');
    if (!frameGrid) {
      console.log('Click not on frame grid - not starting drag selection');
      return;
    }
    
    e.preventDefault();
    
    this.isSelecting = true;
    this.startX = e.clientX;
    this.startY = e.clientY;
    
    // Create selection box
    this.createSelectionBox(e.clientX, e.clientY);
    
    console.log('Started drag selection at', e.clientX, e.clientY);
  },
  
  handleMouseMove(e) {
    if (!this.isSelecting || !this.selectionBox) return;
    
    e.preventDefault();
    
    const currentX = e.clientX;
    const currentY = e.clientY;
    
    // Update selection box
    this.updateSelectionBox(this.startX, this.startY, currentX, currentY);
    
    // Find frames within selection box
    this.updateFrameSelection();
  },
  
  handleMouseUp(e) {
    if (!this.isSelecting) return;
    
    e.preventDefault();
    
    this.isSelecting = false;
    
    // Get final selection and commit it
    const selectedIndices = this.getFinalSelectedIndices();
    if (selectedIndices.length > 0) {
      this.pushEvent('select_frame_range', {
        start_index: Math.min(...selectedIndices).toString(),
        end_index: Math.max(...selectedIndices).toString(),
        indices: selectedIndices.map(i => i.toString())
      });
    }
    
    // Clean up drag selecting classes
    this.container.querySelectorAll('.drag-selecting').forEach(card => {
      card.classList.remove('drag-selecting');
    });
    
    // Remove selection box
    if (this.selectionBox) {
      this.selectionBox.remove();
      this.selectionBox = null;
    }
    
    console.log('Ended drag selection with indices:', selectedIndices);
  },
  
  createSelectionBox(x, y) {
    this.selectionBox = document.createElement('div');
    this.selectionBox.className = 'frame-selection-box';
    this.selectionBox.style.cssText = `
      position: fixed;
      border: 2px dashed #3b82f6;
      background: rgba(59, 130, 246, 0.1);
      pointer-events: none;
      z-index: 1000;
      left: ${x}px;
      top: ${y}px;
      width: 0px;
      height: 0px;
    `;
    
    document.body.appendChild(this.selectionBox);
  },
  
  updateSelectionBox(startX, startY, currentX, currentY) {
    if (!this.selectionBox) return;
    
    const left = Math.min(startX, currentX);
    const top = Math.min(startY, currentY);
    const width = Math.abs(currentX - startX);
    const height = Math.abs(currentY - startY);
    
    this.selectionBox.style.left = left + 'px';
    this.selectionBox.style.top = top + 'px';
    this.selectionBox.style.width = width + 'px';
    this.selectionBox.style.height = height + 'px';
  },
  
  updateFrameSelection() {
    if (!this.selectionBox) return;
    
    const boxRect = this.selectionBox.getBoundingClientRect();
    const frameCards = this.container.querySelectorAll('.frame-card');
    const selectedIndices = [];
    
    frameCards.forEach((card, index) => {
      const cardRect = card.getBoundingClientRect();
      
      // Check if frame card intersects with selection box
      if (this.rectsIntersect(boxRect, cardRect)) {
        selectedIndices.push(index);
        card.classList.add('drag-selecting');
      } else {
        card.classList.remove('drag-selecting');
      }
    });
    
    // Send intermediate selection update (without committing)
    if (selectedIndices.length > 0) {
      this.pushEvent('preview_frame_selection', {
        indices: selectedIndices.map(i => i.toString())
      });
    }
  },
  
  rectsIntersect(rect1, rect2) {
    return !(
      rect1.right < rect2.left ||
      rect1.left > rect2.right ||
      rect1.bottom < rect2.top ||
      rect1.top > rect2.bottom
    );
  },
  
  getFinalSelectedIndices() {
    const dragSelectedCards = this.container.querySelectorAll('.frame-card.drag-selecting');
    const selectedIndices = [];
    
    dragSelectedCards.forEach((card, index) => {
      // Find the actual index of this card in the grid
      const frameSelectBtn = card.querySelector('.frame-select-btn');
      if (frameSelectBtn && frameSelectBtn.dataset.frameIndex) {
        selectedIndices.push(parseInt(frameSelectBtn.dataset.frameIndex));
      }
    });
    
    return selectedIndices.sort((a, b) => a - b);
  }
};

export default FrameMultiSelect;