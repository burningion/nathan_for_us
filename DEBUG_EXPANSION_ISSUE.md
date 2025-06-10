# Frame Expansion Debug Guide

## Issue
- Enter key triggers multi-frame expansion
- Frame count updates in "FRAMES: X READY TO EXPORT" section
- BUT frames don't appear in the UI grid below

## Debugging Added

### 1. Parameter Debugging
Added logging to see what parameters are received:
```elixir
Logger.info("Received expand_sequence_backward_multiple event with params: #{inspect(params)}")
Logger.info("Extracted count_str: #{inspect(count_str)}")
Logger.info("Parsed count: #{count}")
```

### 2. Frame Count Debugging
Added logging to track frame counts before/after:
```elixir
Logger.info("Current sequence frames: #{length(frame_sequence.sequence_frames)}")
Logger.info("Final sequence frames: #{length(final_sequence.sequence_frames)}, added: #{total_added}")
```

### 3. Error Handling
Added proper error handling for:
- Empty form values
- Invalid numbers
- No frame sequence available

## How to Debug

1. **Open browser dev tools** → Console
2. **Start the Phoenix server** with logging
3. **Try expanding frames** by typing a number and pressing Enter
4. **Check the logs** to see:
   - Are parameters being received? 
   - Is the count being parsed correctly?
   - Are frames actually being added to the sequence?
   - Is the LiveView assigns being updated?

## Expected Log Flow
```
[info] Received expand_sequence_backward_multiple event with params: %{"value" => "3"}
[info] Extracted count_str: "3"
[info] Parsed count: 3
[info] Expanding backward by 3 frames
[info] Current sequence frames: 11
[info] Final sequence frames: 14, added: 3
```

## Possible Root Causes

1. **Form submission issue** - params are empty or malformed
2. **Database issue** - expand functions can't find more frames
3. **LiveView render issue** - assigns update but UI doesn't re-render  
4. **Component state issue** - frame grid not updating despite new data

The logs will tell us which case we're dealing with.