import sys
import os

from . import cv2
sys.modules['cv2'] = cv2


# FFMPEG dll is not found on Windows without this
os.environ["PATH"] += os.pathsep + os.path.dirname(os.path.realpath(__file__))