import unittest
import sys


class OpenCVTest(unittest.TestCase):
    """ Simple functionality tests. """

    def test_import(self):
        """ Test that the cv2 module can be imported. """
        import cv2

    def test_cuda(self):
        import cv2
        assert hasattr(cv2.cuda, "createBackgroundSubtractorMOG2"), "Missing expected function!"

    def test_video_capture(self):

        import cv2

        cap = cv2.VideoCapture("SampleVideo_1280x720_1mb.mp4")
        self.assertTrue(cap.isOpened())
