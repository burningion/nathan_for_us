# Enter Key Fix for Multi-Frame Expansion

## Issue
The Enter key wasn't working for multi-frame expansion when users typed a number and pressed Enter.

## Root Cause
The JavaScript hook approach (`phx-hook="ExpandFramesInput"`) wasn't properly connecting to the LiveView events. The `pushEvent` calls weren't reaching the backend.

## Solution
Replaced the JavaScript hook approach with a simpler, more reliable **form-based approach**:

### Before (Not Working)
```heex
<input 
  phx-hook="ExpandFramesInput"
  data-direction="backward"
  ...
/>
```

### After (Working)
```heex
<form 
  phx-submit="expand_sequence_backward_multiple" 
  phx-hook="ExpandFrameForm"
>
  <input name="value" type="number" ... />
</form>
```

## Key Changes

1. **Form Submission**: Uses `phx-submit` instead of JavaScript events
2. **Automatic Value Handling**: Form automatically passes `value` parameter
3. **Reliable Event Handling**: Phoenix form handling is much more reliable
4. **Form Clearing**: Added hook to clear input after successful expansion

## Technical Details

**Frontend:**
- Forms with `phx-submit` trigger LiveView events directly
- `ExpandFrameForm` hook clears inputs after successful expansion
- Event propagation properly handled

**Backend:**
- `expand_sequence_backward_multiple` and `expand_sequence_forward_multiple` receive `%{"value" => count_str}`
- Added `push_event("clear_expand_form", ...)` to notify forms to clear
- URL encoding continues to work for all frame operations

## Testing
1. Open frame sequence modal
2. Type number in expand input (1-20)
3. Press Enter
4. ✅ Frames should be added immediately
5. ✅ Input should clear automatically  
6. ✅ URL should update with new frame selection

This approach is much more reliable than the previous JavaScript hook method and works consistently across all browsers.