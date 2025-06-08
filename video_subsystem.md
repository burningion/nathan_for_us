# Video Subsystem

## Goal
We are going to have a way to have a search form.

This search form will have an input for some text.

The user will enter some text, say, "choo choo".

The system will now search the phrase "choo choo" across a full text search database of "phrase" records

There is a "phrase" record for each frame in a given video.

This will return the records in which the phrase was present.

These will be returned as raw image frames (whatever format, png seems fine to start) as an array.

This will be v0. 

v1 will go further and allow us to combine the frames into a GIF and output that to the user in the browser.

For now, we just display the frames.

## Implementation
First, we will use ffmpeg to turn the video sample we have into frames for a first example.

We will then write a parser for SRT files that will allow us to map words to a given second timestamp.

We will then create a series of database tables to represent a frame (with its binary blob, its timestamp, and whatever else) and a caption (its text, its timestamp, the frame its linked to) that we will be able to begin making the structure we see above.


## Sample Data
The srt file and video file are in vid/

