import unittest
import sys
import os
import numpy as np


class OpenCVTest(unittest.TestCase):
    """ Simple functionality tests. """

    def test_import(self):
        """ Test that the cv2 module can be imported. """
        import cv2

    def test_video_capture(self):
        import cv2

        cap = cv2.VideoCapture("SampleVideo_1280x720_1mb.mp4")
        self.assertTrue(cap.isOpened())

    def test_video_writer(self):
        """
        Test VideoWriter functionality to ensure frames are properly written.
        This test addresses issue #1194.
        """
        import cv2
        import tempfile
        
        # Create a temporary directory for test files
        with tempfile.TemporaryDirectory() as tmpdir:
            test_video = os.path.join(tmpdir, "test_video.mp4")
            output_video = os.path.join(tmpdir, "output_video.mp4")
            
            # Create a test video with known content
            width, height, fps = 320, 240, 24
            fourcc = cv2.VideoWriter_fourcc(*'mp4v')
            writer = cv2.VideoWriter(test_video, fourcc, fps, (width, height))
            
            self.assertTrue(writer.isOpened(), "Failed to open VideoWriter")
            
            # Write test frames
            num_frames = 30
            for i in range(num_frames):
                frame = np.zeros((height, width, 3), dtype=np.uint8)
                frame[:, :, 0] = (i * 8) % 256  # Blue
                frame[:, :, 1] = (i * 10) % 256  # Green
                frame[:, :, 2] = (i * 12) % 256  # Red
                
                success = writer.write(frame)
                self.assertTrue(success, f"Failed to write frame {i}")
            
            writer.release()
            
            # Verify the test video was created and has data
            self.assertTrue(os.path.exists(test_video), "Test video file not created")
            test_size = os.path.getsize(test_video)
            self.assertGreater(test_size, 0, "Test video file is empty")
            
            # Now test the VideoWriter reading from an actual video
            cap = cv2.VideoCapture(test_video)
            self.assertTrue(cap.isOpened(), "Failed to open test video for reading")
            
            # Get properties
            fps_read = cap.get(cv2.CAP_PROP_FPS)
            width_read = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height_read = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            
            # Create output writer with proper settings
            out_writer = cv2.VideoWriter(output_video, fourcc, float(fps_read), 
                                        (width_read, height_read))
            self.assertTrue(out_writer.isOpened(), "Failed to open output VideoWriter")
            
            # Read and write frames
            frame_count = 0
            while True:
                ret, frame = cap.read()
                if not ret or frame is None:
                    break
                
                # Handle frame format conversion
                if frame.ndim == 2:
                    frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)
                elif frame.shape[2] == 4:
                    frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
                
                # Ensure frame dimensions match
                if frame.shape[:2] != (height_read, width_read):
                    frame = cv2.resize(frame, (width_read, height_read))
                
                success = out_writer.write(frame)
                self.assertTrue(success, f"Failed to write frame {frame_count}")
                frame_count += 1
            
            cap.release()
            out_writer.release()
            
            # Verify output file
            self.assertTrue(os.path.exists(output_video), "Output video file not created")
            output_size = os.path.getsize(output_video)
            self.assertGreater(output_size, 0, "Output video file is empty")
            
            # Verify output can be read back
            verify_cap = cv2.VideoCapture(output_video)
            self.assertTrue(verify_cap.isOpened(), "Output video cannot be opened for reading")
            verify_cap.release()
