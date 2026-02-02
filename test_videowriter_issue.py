"""
Test case to reproduce and fix VideoWriter issue #1194
The issue: VideoWriter creates a file but doesn't write frames properly
"""

import cv2
import os
import numpy as np
from pathlib import Path


def create_test_video(filename: str, width: int = 640, height: int = 480, fps: int = 24, num_frames: int = 100) -> None:
    """
    Create a simple test video file for testing purposes.
    
    Args:
        filename: Output video file path
        width: Frame width
        height: Frame height
        fps: Frames per second
        num_frames: Number of frames to write
    """
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    writer = cv2.VideoWriter(filename, fourcc, fps, (width, height))
    
    if not writer.isOpened():
        raise RuntimeError(f"Failed to open VideoWriter for {filename}")
    
    # Create colored frames
    for i in range(num_frames):
        # Create a frame with changing colors
        frame = np.zeros((height, width, 3), dtype=np.uint8)
        
        # Add color variation based on frame number
        frame[:, :, 0] = (i * 2) % 256  # Blue channel
        frame[:, :, 1] = (i * 3) % 256  # Green channel
        frame[:, :, 2] = (i * 5) % 256  # Red channel
        
        # Add some text to verify frame content
        cv2.putText(frame, f"Frame {i}", (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 
                    1, (255, 255, 255), 2)
        
        success = writer.write(frame)
        if not success:
            print(f"Warning: Failed to write frame {i}")
    
    writer.release()
    print(f"Test video created: {filename}")


def test_videowriter_original_issue():
    """
    Reproduce the original issue from #1194
    """
    print("\n=== Testing Original Issue ===")
    
    # Create a test input video
    input_video = "test_input.mp4"
    output_video = "test_output.mp4"
    
    try:
        create_test_video(input_video)
        
        # Now test the problematic code from the issue
        video = cv2.VideoCapture(input_video)
        
        if not video.isOpened():
            print(f"ERROR: Could not open {input_video}")
            return
        
        fps = video.get(cv2.CAP_PROP_FPS)
        width = int(video.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(video.get(cv2.CAP_PROP_FRAME_HEIGHT))
        shape = (width, height)
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        
        print(f"OpenCV Version: {cv2.__version__}")
        print(f"Input codec: {fourcc}")
        print(f"Shape: {shape}")
        print(f"FPS: {fps}")
        
        # Create the writer
        writer = cv2.VideoWriter(output_video, fourcc, fps, shape)
        
        if not writer.isOpened():
            print(f"ERROR: Could not open VideoWriter")
            video.release()
            return
        
        # Read and write frames
        frame_count = 0
        while True:
            ret, frame = video.read()
            
            if not ret or frame is None:
                break
            
            # Handle grayscale frames
            if frame.ndim == 2:
                frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)
            
            # Ensure frame size matches
            if frame.shape[:2] != (height, width):
                frame = cv2.resize(frame, (width, height))
            
            success = writer.write(frame)
            if not success:
                print(f"Warning: Failed to write frame {frame_count}")
            
            frame_count += 1
        
        video.release()
        writer.release()
        
        # Check output file
        output_size = os.path.getsize(output_video) if os.path.exists(output_video) else 0
        print(f"\nFrames written: {frame_count}")
        print(f"Output file size: {output_size} bytes")
        
        if output_size == 0:
            print("ERROR: Output file is empty!")
        else:
            print("SUCCESS: Output file contains data")
        
    finally:
        # Cleanup
        for f in [input_video, output_video]:
            if os.path.exists(f):
                os.remove(f)


def test_videowriter_fixed_issue():
    """
    Test with fixes applied
    """
    print("\n=== Testing Fixed Version ===")
    
    input_video = "test_input_fixed.mp4"
    output_video = "test_output_fixed.mp4"
    
    try:
        create_test_video(input_video)
        
        # Read source video
        video = cv2.VideoCapture(input_video)
        
        if not video.isOpened():
            print(f"ERROR: Could not open {input_video}")
            return
        
        # Get video properties
        fps = video.get(cv2.CAP_PROP_FPS)
        width = int(video.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(video.get(cv2.CAP_PROP_FRAME_HEIGHT))
        
        print(f"Source video properties:")
        print(f"  Size: {width}x{height}")
        print(f"  FPS: {fps}")
        
        # Create writer with proper settings
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(output_video, fourcc, float(fps), (width, height))
        
        # Verify writer is opened
        if not writer.isOpened():
            print(f"ERROR: Could not open VideoWriter")
            video.release()
            return
        
        frame_count = 0
        
        while True:
            ret, frame = video.read()
            
            if not ret or frame is None:
                break
            
            # Ensure frame is BGR and has correct dimensions
            if frame.ndim == 2:
                frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)
            elif frame.shape[2] == 4:
                frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
            
            # Resize if necessary
            if frame.shape[:2] != (height, width):
                frame = cv2.resize(frame, (width, height))
            
            # Write frame
            if not writer.write(frame):
                print(f"Warning: Failed to write frame {frame_count}")
            
            frame_count += 1
        
        # Properly release resources
        video.release()
        writer.release()
        
        # Verify output
        output_size = os.path.getsize(output_video) if os.path.exists(output_video) else 0
        print(f"\nOutput results:")
        print(f"  Total frames written: {frame_count}")
        print(f"  Output file size: {output_size} bytes")
        
        if output_size > 0:
            # Verify the output can be read back
            verify_video = cv2.VideoCapture(output_video)
            if verify_video.isOpened():
                verify_frames = int(verify_video.get(cv2.CAP_PROP_FRAME_COUNT))
                print(f"  Frames readable from output: {verify_frames}")
                verify_video.release()
                print("SUCCESS: Output file is valid and readable")
            else:
                print("ERROR: Output file cannot be opened for reading")
        else:
            print("ERROR: Output file is empty!")
        
    finally:
        for f in [input_video, output_video]:
            if os.path.exists(f):
                os.remove(f)


if __name__ == "__main__":
    print(f"Testing VideoWriter Issue #1194")
    print(f"OpenCV available")
    
    test_videowriter_original_issue()
    test_videowriter_fixed_issue()
