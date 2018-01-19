import importlib
import os

from .cv2 import *
from .data import *

# wildcard import above does not import "private" variables like __version__
# this makes them available
globals().update(importlib.import_module('cv2.cv2').__dict__)
