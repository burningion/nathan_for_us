# Speed Slider Removal

## Changes Made

### 1. Removed Speed Slider UI
- Removed the animation speed control slider from `compact_animation_section`
- Removed all `animation_speed` attributes from component function signatures
- Fixed animation speed to 150ms (hardcoded)

### 2. Updated Component Calls
- Removed `animation_speed={@animation_speed}` from all component calls:
  - `compact_animation_section`
  - `compact_info_footer` 
  - `animation_container`
  - `frame_sequence_modal`

### 3. Updated LiveView
- Removed `:animation_speed` assign from mount function
- Removed `animation_speed={@animation_speed}` from FrameSequence component call

### 4. Fixed Data Attributes
- Changed `data-animation-speed={@animation_speed}` to `data-animation-speed="150"`
- Updated status text from `@ <%= @animation_speed %>ms` to `@ 150ms`

### 5. Cleaned Up JavaScript
- Removed `AnimationSpeedSlider` hook (no longer needed)
- Removed `updateAnimationSpeed()` and `setAnimationSpeed()` methods from `FrameAnimator` hook
- Animation now runs at fixed 150ms intervals

## Result

The frame animations now run at a consistent 150ms speed without the user-controlled slider. This simplifies the UI and removes the complexity of dynamic speed control while maintaining smooth animation playback.

**Fixed animation speed:** 150ms between frames
**UI impact:** Cleaner, simpler frame sequence modal without speed controls
**Performance:** No change - animations still work the same, just at fixed speed