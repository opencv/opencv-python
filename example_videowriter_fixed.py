"""
Fixed VideoWriter Example - Issue #1194
VideoWriter not writing anything

The original issue had several problems:
1. Missing isOpened() checks after creating VideoWriter
2. No validation of frame dimensions before writing
3. Missing float() conversion for fps parameter
4. No error handling for failed write operations
5. Missing verification that VideoWriter was properly initialized

This fixed version addresses all these issues.
"""

import cv2
import os


def capture_and_write_video(input_path: str, output_path: str) -> bool:
    """
    Properly capture video and write to output file.
    
    Args:
        input_path: Path to input video file
        output_path: Path to output video file
        
    Returns:
        True if successful, False otherwise
    """
    # Open input video
    video = cv2.VideoCapture(input_path)
    
    # Check if video opened successfully
    if not video.isOpened():
        print(f"ERROR: Could not open input video: {input_path}")
        return False
    
    try:
        # Get video properties
        fps = video.get(cv2.CAP_PROP_FPS)
        width = int(video.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(video.get(cv2.CAP_PROP_FRAME_HEIGHT))
        frame_count = int(video.get(cv2.CAP_PROP_FRAME_COUNT))
        
        # Validate properties
        if fps <= 0 or width <= 0 or height <= 0:
            print("ERROR: Invalid video properties")
            return False
        
        print(f"Input video properties:")
        print(f"  Resolution: {width}x{height}")
        print(f"  FPS: {fps}")
        print(f"  Total frames: {frame_count}")
        
        # Create VideoWriter with proper settings
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(output_path, fourcc, float(fps), (width, height))
        
        # Check if writer opened successfully
        if not writer.isOpened():
            print(f"ERROR: Could not open VideoWriter for output: {output_path}")
            return False
        
        print(f"\nWriting to output video: {output_path}")
        
        # Read and write frames
        frame_idx = 0
        written_count = 0
        
        while True:
            ret, frame = video.read()
            
            # Check if frame was read successfully
            if not ret or frame is None:
                break
            
            # Handle different frame formats
            if frame.ndim == 2:
                # Convert grayscale to BGR
                frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)
            elif frame.shape[2] == 4:
                # Convert BGRA to BGR
                frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
            
            # Ensure frame dimensions match writer expectations
            if frame.shape[:2] != (height, width):
                frame = cv2.resize(frame, (width, height))
            
            # Write frame to output
            success = writer.write(frame)
            
            if success:
                written_count += 1
            else:
                print(f"Warning: Failed to write frame {frame_idx}")
            
            frame_idx += 1
        
        # Release resources
        video.release()
        writer.release()
        
        # Verify output
        if not os.path.exists(output_path):
            print("ERROR: Output file was not created")
            return False
        
        output_size = os.path.getsize(output_path)
        
        print(f"\nOutput results:")
        print(f"  Frames read: {frame_idx}")
        print(f"  Frames written: {written_count}")
        print(f"  Output file size: {output_size} bytes")
        
        if output_size == 0:
            print("ERROR: Output file is empty!")
            return False
        
        # Optional: Verify output can be read
        verify_video = cv2.VideoCapture(output_path)
        if not verify_video.isOpened():
            print("WARNING: Output file cannot be opened for reading")
            return False
        
        verify_count = int(verify_video.get(cv2.CAP_PROP_FRAME_COUNT))
        verify_video.release()
        
        print(f"  Verified frames in output: {verify_count}")
        print("SUCCESS: Video written and verified!")
        
        return True
        
    except Exception as e:
        print(f"ERROR: {e}")
        return False
    
    finally:
        # Ensure resources are released
        video.release()
        writer.release()


def create_sample_video(output_path: str, width: int = 640, height: int = 480, 
                       fps: int = 24, num_frames: int = 100) -> bool:
    """
    Create a sample video file for testing.
    
    Args:
        output_path: Path to output video file
        width: Frame width in pixels
        height: Frame height in pixels
        fps: Frames per second
        num_frames: Number of frames to create
        
    Returns:
        True if successful, False otherwise
    """
    import numpy as np
    
    try:
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(output_path, fourcc, float(fps), (width, height))
        
        if not writer.isOpened():
            print(f"ERROR: Could not create VideoWriter for {output_path}")
            return False
        
        print(f"Creating sample video: {output_path}")
        
        for i in range(num_frames):
            # Create a frame with animation
            frame = np.zeros((height, width, 3), dtype=np.uint8)
            
            # Add color gradient
            frame[:, :, 0] = (i * 2) % 256  # Blue
            frame[:, :, 1] = (i * 3) % 256  # Green
            frame[:, :, 2] = (i * 5) % 256  # Red
            
            # Add text
            cv2.putText(frame, f"Frame {i+1}/{num_frames}", (50, 50),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
            
            if not writer.write(frame):
                print(f"Warning: Failed to write frame {i}")
        
        writer.release()
        
        # Verify
        if os.path.exists(output_path):
            size = os.path.getsize(output_path)
            print(f"Sample video created successfully ({size} bytes)")
            return True
        else:
            print("ERROR: Sample video file was not created")
            return False
            
    except Exception as e:
        print(f"ERROR: {e}")
        return False


if __name__ == "__main__":
    print("="*60)
    print("VideoWriter Fixed Example - Issue #1194")
    print("="*60)
    print(f"OpenCV available\n")
    
    # Create a sample input video
    sample_input = "sample_input.mp4"
    sample_output = "sample_output.mp4"
    
    try:
        # Create sample video for demonstration
        if create_sample_video(sample_input, num_frames=50):
            print()
            # Process the video
            if capture_and_write_video(sample_input, sample_output):
                print("\n✓ Video processing completed successfully!")
            else:
                print("\n✗ Video processing failed!")
        else:
            print("Failed to create sample video")
    
    finally:
        # Cleanup
        for f in [sample_input, sample_output]:
            if os.path.exists(f):
                os.remove(f)
                print(f"Cleaned up: {f}")
