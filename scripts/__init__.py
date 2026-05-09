"""
OpenCV Python bindings

This module provides Python bindings for OpenCV.

Important notes for multiprocessing:
- OpenCV is not fork-safe. Using cv2 functions after fork() can cause
  "corrupted double-linked list" errors and memory corruption.
- If you use multiprocessing with fork (the default on Linux/macOS),
  either:
  1. Use spawn mode: multiprocessing.set_start_method('spawn')
  2. Call cv2.setNumThreads(0) in each worker before using cv2
- See: https://github.com/opencv/opencv-python/issues/1166
"""

import os
import sys
import warnings

PYTHON_EXTENSIONS_PATHS = [
    LOADER_DIR
] + PYTHON_EXTENSIONS_PATHS

ci_and_not_headless = False

try:
    from .version import ci_build, headless

    ci_and_not_headless = ci_build and not headless
except:
    pass

# the Qt plugin is included currently only in the pre-built wheels
if sys.platform.startswith("linux") and ci_and_not_headless:
    os.environ["QT_QPA_PLATFORM_PLUGIN_PATH"] = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "qt", "plugins"
    )

# Qt will throw warning on Linux if fonts are not found
if sys.platform.startswith("linux") and ci_and_not_headless:
    os.environ["QT_QPA_FONTDIR"] = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "qt", "fonts"
    )