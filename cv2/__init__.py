import sys
import os

# FFMPEG dll is not found on Windows without this
os.environ["PATH"] += os.pathsep + os.path.dirname(os.path.realpath(__file__))

from . import cv2
sys.modules['cv2'] = cv2
