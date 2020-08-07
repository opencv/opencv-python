import importlib
import os
import sys

from .cv2 import *
from .data import *

# wildcard import above does not import "private" variables like __version__
# this makes them available
globals().update(importlib.import_module("cv2.cv2").__dict__)

ci_and_not_headless = False

try:
    from .version import ci_build, headless

    ci_and_not_headless = ci_build and not headless
except:
    pass

# the Qt plugin is included currently only in the pre-built wheels
if (
    sys.platform == "darwin" or sys.platform.startswith("linux")
) and ci_and_not_headless:
    os.environ["QT_QPA_PLATFORM_PLUGIN_PATH"] = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "qt", "plugins"
    )

# Qt will throw warning on Linux if fonts are not found
if sys.platform.startswith("linux") and ci_and_not_headless:
    os.environ["QT_QPA_FONTDIR"] = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "qt", "fonts"
    )
