import sys
import os
import importlib

# FFmpeg dll is not found on Windows without this
os.environ["PATH"] += os.pathsep + os.path.dirname(os.path.realpath(__file__))

# make IDE's (PyCharm) autocompletion happy
from .cv2 import *

# wildcard import above does not import "private" variables like __version__
# this makes them available
globals().update(importlib.import_module('cv2.cv2').__dict__)