The issue is that production frames for videos 3 and 4 exist but don't have image_data.

Here's the step-by-step process I'm following to sync the image data:

1. Check current state:
   - Production has frames for videos 3,4 but no image_data
   - Local has frames with image_data for videos 3,4

2. Challenge: Binary data encoding issues in PostgreSQL exports

3. Solution: Use selective image data migration

